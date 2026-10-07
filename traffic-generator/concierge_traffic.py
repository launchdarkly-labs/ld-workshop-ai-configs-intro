"""Low-rate background traffic for the per-agent guarded rollout (Coordinate ch09).

Runs in a loop emitting one simulated Concierge session every ~2 seconds so
the guarded rollout on `concierge-otto-rewriter` has organic-looking data to
judge. Each session:

  1. Builds a fresh user context (so the rollout can bucket it).
  2. Evaluates the `concierge-otto-rewriter` agent Config for that context —
     this is what attributes the metric event below to whichever variation
     (Default on Haiku, or the Lite variation on Nova Lite) the rollout
     served.
  3. Emits an `otto-brand-voice-score` event biased by the served model: the
     Haiku-backed Default scores high, Nova Lite scores well below Otto's
     bar. Also emits the usual tracker metrics (duration, tokens, success).

Why synthetic rather than real /chat calls: the rollout has to be able to
fire inside the lab's time budget regardless of how Nova Lite happens to
phrase a given rewrite. realchat_traffic.py drives the real pipeline (and
the real judges) in the other Coordinate challenges.

Exits cleanly on SIGTERM/SIGINT; safe to kill with
`pkill -f concierge_traffic.py`.
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

from ldai import LDAIClient  # noqa: E402
from ldai.models import AIAgentConfigDefault  # noqa: E402
from ldai.tracker import TokenUsage  # noqa: E402
from ldclient import Context, LDClient  # noqa: E402
from ldclient.config import Config as LDConfig  # noqa: E402

REWRITER_CONFIG_KEY = "concierge-otto-rewriter"
METRIC_KEY = "otto-brand-voice-score"
RATE_SECONDS = float(os.getenv("TRAFFIC_RATE_SECONDS", "2.0"))

# (mean, stddev) of the brand-voice score per served model. Keys are matched
# as substrings of cfg.model.name so both the global and project-level
# Bedrock model names resolve.
BRAND_VOICE = {
    "claude-haiku-4-5": (0.80, 0.06),
    "nova-lite": (0.28, 0.10),
}
DEFAULT_BRAND_VOICE = (0.65, 0.10)

_running = True


def _stop(_signum, _frame) -> None:
    global _running
    _running = False


def _profile(model_name: str) -> tuple[float, float]:
    for needle, stats in BRAND_VOICE.items():
        if needle in (model_name or ""):
            return stats
    return DEFAULT_BRAND_VOICE


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

    print(f"Concierge traffic running (rate ≈ {RATE_SECONDS}s/session). Ctrl-C to stop.")
    sessions = 0
    while _running:
        ctx = Context.builder(f"concierge-{uuid4().hex[:8]}").set("tier", "free").build()
        cfg = ai_client.agent_config(
            REWRITER_CONFIG_KEY, ctx, AIAgentConfigDefault(enabled=False)
        )
        if cfg.enabled and cfg.model is not None:
            model_name = cfg.model.name or ""
            mean, std = _profile(model_name)
            score = max(0.0, min(1.0, random.gauss(mean, std)))

            tracker = cfg.create_tracker()
            is_lite = "nova-lite" in model_name
            latency_ms = random.randint(500, 1400) if is_lite else random.randint(900, 2200)
            tracker.track_duration(latency_ms)
            tracker.track_tokens(
                TokenUsage(
                    input=random.randint(280, 420),
                    output=random.randint(40, 110),
                    total=0,
                )
            )
            tracker.track_success()
            ld_client.track(METRIC_KEY, ctx, None, score)

            sessions += 1
            if sessions % 25 == 0:
                print(f"[{sessions}] model={model_name} score={score:.2f}", flush=True)
        time.sleep(RATE_SECONDS)

    ld_client.flush()
    ld_client.close()
    print(f"concierge_traffic: exiting after {sessions} sessions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
