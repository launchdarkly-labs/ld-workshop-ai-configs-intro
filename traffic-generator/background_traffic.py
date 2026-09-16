#!/usr/bin/env python3
"""Low-rate, long-running traffic for the guarded-rollout lab (Evaluate ch07).

Runs in a loop emitting one simulated session every ~2 seconds so the
guarded rollout has organic data to evaluate against. Designed to be
launched in the background from setup-workstation and left running for
the duration of the challenge.

Sessions emit the same kind of synthetic events as generate_traffic.py
(duration, tokens, success, feedback) PLUS an otto-brand-voice-score
event biased per model. The per-model brand-voice mean includes a
deliberately-low value for Nova Pro (the Formal variation) so the
guarded rollout's metric drifts below threshold when traffic flows
to it.

Exits cleanly on SIGTERM/SIGINT; safe to kill with `pkill -f background_traffic.py`.
"""
from __future__ import annotations

import os
import random
import signal
import sys
import time
from pathlib import Path
from uuid import uuid4

from dotenv import load_dotenv

APP_ENV = Path(__file__).resolve().parent.parent / "app" / ".env"
load_dotenv(dotenv_path=APP_ENV, override=True)

from ldai import AICompletionConfigDefault, LDAIClient  # noqa: E402
from ldai.tracker import FeedbackKind, TokenUsage  # noqa: E402
from ldclient import Context, LDClient  # noqa: E402
from ldclient.config import Config as LDConfig  # noqa: E402

OTTO_CONFIG_KEY = "otto-assistant"
RATE_SECONDS = float(os.getenv("TRAFFIC_RATE_SECONDS", "2.0"))
PREMIUM_RATIO = float(os.getenv("TRAFFIC_PREMIUM_RATIO", "0.30"))

# Per-model positive-feedback rates. Formal (Nova Pro) scores low so its
# brand-voice metric drifts below baseline when traffic flows to it.
POSITIVE_RATE = {
    "claude-sonnet-4-5": 0.92,
    "claude-haiku-4-5":  0.78,
    "nova-pro":          0.30,
}
DEFAULT_POSITIVE_RATE = 0.70

# Per-model brand-voice score distributions (mean, std). All clipped to
# [0.0, 1.0]. Nova Pro's mean is well below the others to drive a
# regression detection on the guarded rollout.
BRAND_VOICE = {
    "claude-sonnet-4-5": (0.85, 0.06),
    "claude-haiku-4-5":  (0.72, 0.08),
    "nova-pro":          (0.22, 0.10),
}
DEFAULT_BRAND_VOICE = (0.65, 0.10)

_running = True


def _stop(_signum, _frame):
    global _running
    _running = False


def main() -> int:
    sdk_key = os.environ.get("LD_SDK_KEY")
    if not sdk_key:
        print("ERROR: LD_SDK_KEY not set", file=sys.stderr)
        return 1

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    ld_client = LDClient(LDConfig(sdk_key))
    if not ld_client.is_initialized():
        print("WARN: LD client did not initialize", file=sys.stderr)
    ai_client = LDAIClient(ld_client)

    print(
        f"Background traffic running (rate ≈ {RATE_SECONDS}s/session, "
        f"{int(PREMIUM_RATIO * 100)}% premium). Ctrl-C to stop."
    )

    sessions = 0
    while _running:
        session_id = f"bg-{uuid4().hex[:8]}"
        tier = "premium" if random.random() < PREMIUM_RATIO else "free"
        ctx = Context.builder(session_id).set("tier", tier).build()

        cfg = ai_client.completion_config(
            OTTO_CONFIG_KEY, ctx, AICompletionConfigDefault(enabled=False)
        )
        if cfg.enabled and cfg.model is not None:
            tracker = cfg.create_tracker()
            is_sonnet = cfg.model.name == "claude-sonnet-4-5"
            is_nova = cfg.model.name == "nova-pro"
            if is_sonnet:
                latency_ms = random.randint(2200, 5800)
                out_tokens = random.randint(120, 360)
            elif is_nova:
                latency_ms = random.randint(1400, 3800)
                out_tokens = random.randint(120, 320)
            else:
                latency_ms = random.randint(700, 2400)
                out_tokens = random.randint(40, 180)
            in_tokens = random.randint(60, 200)
            tracker.track_duration(latency_ms)
            tracker.track_tokens(
                TokenUsage(total=in_tokens + out_tokens, input=in_tokens, output=out_tokens)
            )
            tracker.track_success()
            pos_rate = POSITIVE_RATE.get(cfg.model.name, DEFAULT_POSITIVE_RATE)
            kind = FeedbackKind.Positive if random.random() < pos_rate else FeedbackKind.Negative
            tracker.track_feedback({"kind": kind})

            # Emit a brand-voice score weighted by model. Formal (Nova Pro)
            # drifts the metric below threshold so the guarded rollout fires.
            mean, std = BRAND_VOICE.get(cfg.model.name, DEFAULT_BRAND_VOICE)
            score = max(0.0, min(1.0, random.gauss(mean, std)))
            ld_client.track("otto-brand-voice-score", ctx, None, score)

            sessions += 1
            if sessions % 10 == 0:
                print(f"  emitted {sessions} sessions...")

        time.sleep(RATE_SECONDS)

    ld_client.flush()
    ld_client.close()
    print(f"Background traffic stopped after {sessions} sessions.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
