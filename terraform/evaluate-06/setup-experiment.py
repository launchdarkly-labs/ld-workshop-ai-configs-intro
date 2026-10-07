#!/usr/bin/env python3
"""Create and start the Evaluate ch06 prompt experiment.

Discovers the variationIds for otto-born and otto-recommender, the test
environment's targeting version, and a maintainer member id, then POSTs to
/experiments and starts the first iteration with a semantic patch.
Idempotent: if an experiment with the target key already exists, exit
cleanly without touching it.

Verified against the live API on 2026-10-06 (kevinc-instruqt sandbox):

  * The experiment create body needs `maintainerId`. The operator token is a
    service token, so /members/me is not available; we look up the learner's
    bootstrap member (instruqt+<project>@launchdarkly.com) and fall back to
    the first owner/admin member.
  * `flags.<key>.ruleId` for the default rule is the literal "fallthrough".
    The GET response echoes it as `targetingRule: "fallthrough"`.
  * `flags.<key>.flagConfigVersion` is the TARGETING version of the config in
    the experiment's environment (`environments.test._version` on
    GET .../ai-configs/{key}/targeting), not the config's own `version`.
  * The targeting response identifies variations by `name` and
    `value._ldMeta.variationKey`; there is no top-level `key` field.
  * Starting the iteration is PATCH /experiments/{key} with
    {"instructions":[{"kind":"startIteration","changeJustification":"..."}]},
    not POST .../iterations. It fails with optimistic_locking_error if the
    config's fallthrough is already in another running experiment.
  * GET returns `currentIteration.status` = not_started | running | stopped.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API_BASE = "https://app.launchdarkly.com/api/v2"
EXPERIMENT_KEY = "otto-prompt-experiment"
EXPERIMENT_NAME = "Otto Prompt Experiment"
HYPOTHESIS = (
    "Adding a one-sentence prompt to suggest a complementary item improves "
    "brand-voice score without going off-brand."
)
METRIC_KEY = "otto-brand-voice-score"
CONFIG_KEY = "otto-assistant"
ENV_KEY = "test"
CONTROL_VARIATION = "otto-born"
CONTENDER_VARIATION = "otto-recommender"


def request(method: str, path: str, body: dict | None = None) -> dict:
    token = os.environ["LAUNCHDARKLY_ACCESS_TOKEN"]
    url = f"{API_BASE}{path}"
    headers = {
        "Authorization": token,
        "Content-Type": "application/json",
        "LD-API-Version": "beta",
    }
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            text = resp.read().decode()
            # strict=False: prompt text in targeting payloads can carry raw
            # control characters that the strict parser rejects.
            return json.loads(text, strict=False) if text else {}
    except urllib.error.HTTPError as e:
        text = e.read().decode() if e.fp else ""
        raise SystemExit(f"{method} {path} -> HTTP {e.code}: {text}")


def targeting(project_key: str) -> dict:
    return request("GET", f"/projects/{project_key}/ai-configs/{CONFIG_KEY}/targeting")


def variation_ids(t: dict) -> tuple[str, str]:
    by_key = {
        (v.get("value") or {}).get("_ldMeta", {}).get("variationKey"): v["_id"]
        for v in t.get("variations", [])
    }
    if CONTROL_VARIATION not in by_key:
        raise SystemExit(f"Could not find control variation {CONTROL_VARIATION}")
    if CONTENDER_VARIATION not in by_key:
        raise SystemExit(f"Could not find contender variation {CONTENDER_VARIATION}")
    return by_key[CONTROL_VARIATION], by_key[CONTENDER_VARIATION]


def targeting_version(t: dict) -> int:
    return int(t["environments"][ENV_KEY]["_version"])


def maintainer_id(project_key: str) -> str:
    email = f"instruqt+{project_key}@launchdarkly.com"
    res = request("GET", f"/members?filter={urllib.parse.quote('email:' + email)}")
    items = res.get("items") or []
    if items:
        return items[0]["_id"]
    res = request("GET", "/members?limit=50")
    for role in ("owner", "admin"):
        for m in res.get("items") or []:
            if m.get("role") == role:
                return m["_id"]
    raise SystemExit("Could not resolve a maintainer member id for the experiment.")


def experiment(project_key: str) -> dict | None:
    try:
        return request("GET", f"/projects/{project_key}/environments/{ENV_KEY}/experiments/{EXPERIMENT_KEY}")
    except SystemExit as e:
        if "404" in str(e):
            return None
        raise


def create_experiment(project_key: str, control_id: str, contender_id: str, version: int, maintainer: str) -> None:
    payload = {
        "key": EXPERIMENT_KEY,
        "name": EXPERIMENT_NAME,
        "description": "Otto (Born) vs Otto (Recommender), graded on the brand-voice judge.",
        "maintainerId": maintainer,
        "iteration": {
            "hypothesis": HYPOTHESIS,
            "metrics": [{"key": METRIC_KEY, "isGroup": False, "primary": True}],
            "primarySingleMetricKey": METRIC_KEY,
            "treatments": [
                {
                    "name": "Otto (Born)",
                    "baseline": True,
                    "allocationPercent": "50",
                    "parameters": [{"flagKey": CONFIG_KEY, "variationId": control_id}],
                },
                {
                    "name": "Otto (Recommender)",
                    "baseline": False,
                    "allocationPercent": "50",
                    "parameters": [{"flagKey": CONFIG_KEY, "variationId": contender_id}],
                },
            ],
            "flags": {
                CONFIG_KEY: {
                    "ruleId": "fallthrough",
                    "flagConfigVersion": version,
                    "notInExperimentVariationId": control_id,
                },
            },
            "randomizationUnit": "user",
        },
    }
    request("POST", f"/projects/{project_key}/environments/{ENV_KEY}/experiments", body=payload)
    print(f"Created experiment {EXPERIMENT_KEY}")


def stop_if_running(project_key: str, winner_name: str = "Otto (Recommender)") -> bool:
    """Stop a running iteration and ship `winner_name` (verified live 2026-10-06:
    PATCH stopIteration with winningTreatmentId + winningReason -> 200, the
    iteration goes to `stopped` and the config's fallthrough is set to the
    winning variation, exactly like the UI's Stop -> ship flow).

    Returns True if an iteration was stopped. Used by the ch06 solve (so the
    skip path ends in the learner's end state) and defensively by ch07/ch08
    setup+solve, because a running experiment owns the fallthrough and makes
    startAutomatedRelease / updateFallthroughVariationOrRollout return 409.
    """
    try:
        existing = request(
            "GET",
            f"/projects/{project_key}/environments/{ENV_KEY}/experiments/{EXPERIMENT_KEY}?expand=treatments",
        )
    except SystemExit as e:
        if "404" in str(e):
            return False
        raise
    iteration = existing.get("currentIteration") or {}
    if iteration.get("status") != "running":
        return False
    treatments = iteration.get("treatments") or []
    winner = next((t for t in treatments if t.get("name") == winner_name), None)
    if winner is None:
        winner = next((t for t in treatments if not t.get("baseline")), None)
    if winner is None:
        raise SystemExit("Running experiment has no treatments to ship")
    request(
        "PATCH",
        f"/projects/{project_key}/environments/{ENV_KEY}/experiments/{EXPERIMENT_KEY}",
        body={
            "comment": "Evaluate solve: stop the experiment and ship the contender",
            "instructions": [{
                "kind": "stopIteration",
                "winningTreatmentId": winner["_id"],
                "winningReason": f"{winner_name} wins on {METRIC_KEY}",
            }],
        },
    )
    print(f"Stopped {EXPERIMENT_KEY}; shipped {winner.get('name')}")
    return True


def start_iteration(project_key: str) -> None:
    request(
        "PATCH",
        f"/projects/{project_key}/environments/{ENV_KEY}/experiments/{EXPERIMENT_KEY}",
        body={"instructions": [{"kind": "startIteration", "changeJustification": "Evaluate ch06 solve"}]},
    )
    print(f"Started iteration on {EXPERIMENT_KEY}")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--project", required=True)
    p.add_argument(
        "--stop-if-running",
        action="store_true",
        help="Only stop a running iteration (shipping Otto (Recommender)); never create/start.",
    )
    p.add_argument(
        "--ship-winner",
        action="store_true",
        help="After creating/starting, stop the iteration and ship Otto (Recommender).",
    )
    args = p.parse_args()

    if args.stop_if_running:
        if not stop_if_running(args.project):
            print(f"No running iteration on {EXPERIMENT_KEY} — nothing to stop.")
        return 0

    existing = experiment(args.project)
    if existing:
        status = (existing.get("currentIteration") or {}).get("status")
        if status == "not_started":
            start_iteration(args.project)
        else:
            print(f"Experiment {EXPERIMENT_KEY} already exists (status={status}) — no-op.")
        if args.ship_winner:
            stop_if_running(args.project)
        return 0

    t = targeting(args.project)
    control_id, contender_id = variation_ids(t)
    version = targeting_version(t)
    maintainer = maintainer_id(args.project)

    create_experiment(args.project, control_id, contender_id, version, maintainer)
    start_iteration(args.project)
    if args.ship_winner:
        stop_if_running(args.project)
    return 0


if __name__ == "__main__":
    sys.exit(main())
