---
slug: otto-knows-when-to-fold
id: fkopss12xbgi
type: challenge
title: Otto Knows When to Fold
teaser: Wire an in-app loop that flips Otto's targeting to a safe variation when judge
  scores tank — request-time protection, no rollout required.
notes:
- type: text
  contents: Guarded rollouts protect Otto at release time — they catch a regression
    before it reaches 100% of traffic. But what if a regression sneaks through, or
    a model degrades gradually, or you want a faster response than a rollout's monitoring
    window? This challenge adds a request-time safety net — a small loop in the app
    that watches the brand-voice score and flips the fallthrough to a safe variation
    when things go sideways.
tabs:
- id: zgxams3ntxzb
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: hpelrrybsjag
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: jj25c7jkiout
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 1200
enhanced_loading: null
---

# Three safety nets, three timescales

You've now seen two ways to protect Otto:

| Timescale | Mechanism | Demonstrated in |
|---|---|---|
| **Release time** | Guarded rollout watches a metric while ramping traffic; rolls back on regression. | Challenge 07 |
| **Request time** | Something watches the judge score between requests and switches the active variation when it slips: LaunchDarkly's own **adaptive trigger**, or a loop in your app. | This challenge |
| **Per-request** | Synchronous fallback: if THIS response fails a check, regenerate before it reaches the user. | Track 3 / Coordinate (self-healing) |

Each is appropriate at a different speed of failure. Guarded rollouts catch a known-bad change going into production. Adaptive switching catches a slowly-degrading production state. Self-healing catches a single bad response in flight.

Today you'll wire the middle one, twice: first by letting LaunchDarkly do it with an **adaptive trigger** (no code), then by building the same loop yourself inside the app so you can see what the platform is doing for you.

# Setup deliberately put Otto in a bad state

Open the [LaunchDarkly](#tab-0) tab. Go to **Configs → Otto Assistant → Targeting**.

The **Default rule** is currently serving **Otto (Formal)** to all users. (Ignore the note on the card about an experiment; that's Challenge 06's stopped experiment.) The realchat traffic generator is sending real customer questions through; Formal's corporate prompt makes the brand-voice judge unhappy on most of them, so `otto-brand-voice-score` is sitting well below 0.5.

# Let LaunchDarkly fold for Otto: add an adaptive trigger

An adaptive trigger watches a metric and, when it crosses a threshold you set, switches a rule to a variation you choose. No code, no deploy, no human on call.

1. Under the **Default rule** card (not under Rule 1), click **Add adaptive trigger**.
2. Choose **Custom trigger**.
3. **Source**: leave **LaunchDarkly hosted metrics**. Click **Select a metric**, type `Otto Brand` in the search box, and pick **Otto Brand Voice Score**.
4. **Threshold**: **Type** **Constant**, **Condition** **Below**, **Alert threshold** `0.5`, **Alert window** **1 minute**. Leave **Advanced threshold settings** alone (Cooldown 30 minutes, Evaluation delay 0).
5. **Switch variation to**: **Otto (Born)**. The summary line reads **When Otto Brand Voice Score drops below 0.5 score over 1 minute → serve Otto (Born)**.
6. Click **Add**. A toast reads **Trigger created**, and the trigger appears under the Default rule with **Edit trigger** and **Remove trigger** controls.

Now watch. Refresh the Targeting tab every 30 seconds or so. It takes two to four minutes: the alert needs a full minute of judge scores averaging below 0.5, then the trigger fires and the **Default rule** reads **Serve Otto (Born)**. The trigger stays in place, armed again after its 30-minute cooldown.

That is the whole platform-native version. Everything below builds the same loop by hand.

# Put Otto back in the bad state

So that you can watch your own code catch it, break Otto again:

1. On the **Default rule**, click **Edit**, open **Serve**, and choose **Otto (Formal)**.
2. Click **Review and save**, then **Save**.

The trigger you just added is in its 30-minute cooldown, so this time only the code you write next will fold for Otto.

# Create the adaptive module

Open the [Code Editor](#tab-2). Create a new file at `app/adaptive.py` with the following content:

```python
"""Adaptive switching for Otto.

Watches a rolling window of brand-voice scores. When the window's mean
drops below a threshold and we haven't recently flipped, calls the LD
REST API to set otto-assistant's fallthrough to a known-safe variation.
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
        log.warning("adaptive: fetch failed: %s", e)
    return None


def _flip_to_safe() -> None:
    variation_id = _fetch_safe_variation_id()
    if not variation_id:
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
    """Record a score; flip to safe mode if the rolling window's mean drops."""
    if score is None:
        return False
    global _last_flip_time
    with _lock:
        _scores.append(float(score))
        if len(_scores) < MIN_SAMPLES:
            return False
        mean = sum(_scores) / len(_scores)
        now = time.monotonic()
        if mean >= THRESHOLD or now - _last_flip_time < COOLDOWN_S:
            return False
        _last_flip_time = now
        _scores.clear()
    log.info("adaptive: mean=%.2f below %.2f; flipping in background", mean, THRESHOLD)
    threading.Thread(target=_flip_to_safe, daemon=True).start()
    return True
```

Save the file.

A few things to notice:

- **Rolling window** of 20 scores (`deque(maxlen=20)`). Old scores fall off as new ones arrive.
- **Minimum samples** of 10 before the loop even considers flipping — protects against early-life noise.
- **Threshold** of 0.5 (mean below this triggers a flip).
- **Cooldown** of 60 seconds between flips, so a single bad window doesn't trigger repeatedly.
- The actual REST PATCH runs on a **daemon thread** so the /chat handler returns immediately.

# Wire it into server.py

Open `app/server.py`.

1. Near the top of the file, after the existing `import boto3` line, add:
```python
from adaptive import observe as adaptive_observe
```

2. Inside the brand-voice judge block (the one you pasted in Challenge 03), find the line:
```python
                ld_client.track("otto-brand-voice-score", bv_ctx, None, score)
```
   Add a new line **immediately after it**:
```python
                adaptive_observe(score)
```

Save the file. The togglewear service auto-reloads.

# Watch your loop work

The realchat traffic generator is sending real customer questions through `/chat`. Each one triggers a brand-voice judge invocation, which emits a score, which feeds your `adaptive_observe` call.

1. Open the [LaunchDarkly](#tab-0) tab. Stay on **Otto Assistant → Targeting**.
2. Refresh every 15-30 seconds. Within about a minute (10 samples × ~5 seconds per request), the rolling window should drop below 0.5 and your loop should flip the **Default rule** back to **Otto (Born)**.
3. The flip happens silently — no notifications. Otto just starts being on-brand again.

If you want to see the loop's reasoning, tail the app log:

```bash
journalctl -u togglewear -f
```

You should see a line like:

```text
adaptive: mean=0.34 below 0.50; flipping in background
adaptive: flipped fallthrough to otto-born
```

# What you built

Two versions of the same request-time controller, closing the loop between an observation signal (the judge score) and a control surface (Otto's Default rule):

- **The adaptive trigger** runs in LaunchDarkly. It watches the metric over an alert window, fires once per cooldown, writes the targeting change for you, and is visible to everyone on the Targeting tab. Reach for it first.
- **The in-app loop** runs in your process. It sees every score the instant it's emitted, so it can react faster and with any policy you can code (rolling window, minimum samples, cooldown, which variation is "safe"). It costs you code, and nobody can see it from the LaunchDarkly UI.

The pattern transfers either way. Anywhere you have an observation metric and a control surface (a flag, a Config, a targeting rule, a feature gate), the same loop applies. The hard part is picking the right threshold and window so you protect customers without flapping.

Click **Check** when the fallthrough has flipped back to otto-born.
