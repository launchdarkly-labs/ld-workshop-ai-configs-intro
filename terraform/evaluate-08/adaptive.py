"""Adaptive switching for Otto.

Watches a rolling window of brand-voice scores. When the window's mean
drops below a threshold and we haven't recently flipped, calls the LD
REST API to set otto-assistant's fallthrough to a known-safe variation.

The flip itself runs on a daemon thread so the /chat handler isn't
blocked on a REST round-trip.

Process-local state — a single app instance. For production, you'd
back the window and last-flip timestamp with a shared store (Redis,
etc.) so multiple instances coordinate.

Environment knobs (all have sane defaults):
  ADAPTIVE_WINDOW_SIZE   default 20   - max samples kept in rolling window
  ADAPTIVE_MIN_SAMPLES   default 10   - min samples before the loop fires
  ADAPTIVE_THRESHOLD     default 0.5  - mean below this triggers a flip
  ADAPTIVE_COOLDOWN_S    default 60   - seconds between flips
"""
from __future__ import annotations

import json
import logging
import os
import threading
import time
import urllib.error
import urllib.request
from collections import deque
from typing import Optional

log = logging.getLogger("togglewear.adaptive")

WINDOW_SIZE = int(os.getenv("ADAPTIVE_WINDOW_SIZE", "20"))
MIN_SAMPLES = int(os.getenv("ADAPTIVE_MIN_SAMPLES", "10"))
THRESHOLD = float(os.getenv("ADAPTIVE_THRESHOLD", "0.5"))
COOLDOWN_S = float(os.getenv("ADAPTIVE_COOLDOWN_S", "60"))

SAFE_VARIATION_KEY = "otto-born"
CONFIG_KEY = "otto-assistant"
ENV_KEY = "test"
LD_API = "https://app.launchdarkly.com/api/v2"

LD_PROJECT_KEY = os.environ.get("LD_PROJECT_KEY")
LD_TOKEN = os.environ.get("LD_API_TOKEN")

_scores: deque[float] = deque(maxlen=WINDOW_SIZE)
_lock = threading.Lock()
_last_flip_time = 0.0
_safe_variation_id: Optional[str] = None


def _fetch_safe_variation_id() -> Optional[str]:
    global _safe_variation_id
    if _safe_variation_id:
        return _safe_variation_id
    if not LD_PROJECT_KEY or not LD_TOKEN:
        log.warning("adaptive: missing LD_PROJECT_KEY or LD_API_TOKEN")
        return None
    url = f"{LD_API}/projects/{LD_PROJECT_KEY}/ai-configs/{CONFIG_KEY}/targeting"
    req = urllib.request.Request(url, headers={"Authorization": LD_TOKEN})
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
        # The targeting payload has no top-level `key` on variations; the
        # variation key lives under value._ldMeta.variationKey.
        for v in data.get("variations", []):
            meta = (v.get("value") or {}).get("_ldMeta") or {}
            if meta.get("variationKey") == SAFE_VARIATION_KEY:
                _safe_variation_id = v.get("_id")
                return _safe_variation_id
    except urllib.error.URLError as e:
        log.warning("adaptive: fetch safe variation failed: %s", e)
    return None


def _flip_to_safe() -> None:
    variation_id = _fetch_safe_variation_id()
    if not variation_id:
        log.warning("adaptive: no safe variation id; skipping flip")
        return
    url = f"{LD_API}/projects/{LD_PROJECT_KEY}/ai-configs/{CONFIG_KEY}/targeting"
    body = json.dumps({
        "environmentKey": ENV_KEY,
        "instructions": [{
            "kind": "updateFallthroughVariationOrRollout",
            "variationId": variation_id,
        }],
    }).encode()
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Authorization": LD_TOKEN,
            "Content-Type": "application/json; domain-model=launchdarkly.semanticpatch",
        },
        method="PATCH",
    )
    try:
        urllib.request.urlopen(req, timeout=5).read()
        log.info("adaptive: flipped fallthrough to %s", SAFE_VARIATION_KEY)
    except urllib.error.URLError as e:
        log.warning("adaptive: flip failed: %s", e)


def observe(score: Optional[float]) -> bool:
    """Record a brand-voice score and flip to safe mode if the window drops.

    Returns True if this observation triggered a flip.
    """
    if score is None:
        return False
    global _last_flip_time
    with _lock:
        _scores.append(float(score))
        if len(_scores) < MIN_SAMPLES:
            return False
        mean = sum(_scores) / len(_scores)
        now = time.monotonic()
        if mean >= THRESHOLD:
            return False
        if now - _last_flip_time < COOLDOWN_S:
            return False
        _last_flip_time = now
        # Clear so we don't re-flip on the next observation post-cooldown
        # until a new window accumulates.
        _scores.clear()
    log.info("adaptive: mean=%.2f < threshold=%.2f; flipping in background", mean, THRESHOLD)
    threading.Thread(target=_flip_to_safe, daemon=True).start()
    return True
