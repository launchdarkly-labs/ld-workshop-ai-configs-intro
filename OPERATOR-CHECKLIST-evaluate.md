# OPERATOR-CHECKLIST-evaluate.md

Per-challenge verification items for **Track 2 / Evaluate** (`instruqt-evaluate/`). All ten challenges (00–09) are authored. Remaining work below is verification that requires either the live LaunchDarkly UI or a real sandbox run — Claude Code drafted from docs but can't drive a browser.

Author-side polish (`PHASES-evaluate.md` Phase 9) is complete as of 2026-06-01.

---

## Cross-cutting items

- [ ] **Live-fire end-to-end smoke test** against a fresh sandbox: bootstrap → click through every challenge → solve every challenge → confirm every check passes. Time each challenge.
- [ ] **Track-level `setup-workstation` timing.** It applies the bootstrap + Build's challenge-01/02/03/05/06 solves + ch01's `patch-server.py`. PHASES-evaluate.md flagged 60s as the threshold above which the operator should consider pre-baking the post-Build state into the VM image instead.
- [ ] **VM image re-bake** to pick up the new `realchat_traffic.py`, `experiment_traffic.py`, and updated `background_traffic.py` / `sabotage.py`. Bump `vm-image/build-image.sh`'s `REPO_REF` and the image's `-N` suffix in `instruqt-build/config.yml` / `instruqt-evaluate/config.yml`.
- [ ] **Three open Phase 0 / Phase 8 questions to live-verify against a real LD project:**
  - [ ] Dataset upload contract: `create-dataset` returns a pre-signed URL; confirm the PUT works with `Content-Type: application/x-ndjson` (ch01 / `terraform/evaluate-01/main.tf`).
  - [ ] Built-in judge discovery: confirm built-in Accuracy/Relevance/Toxicity judges surface via `GET /ai-configs?limit=100&mode=judge` filter; if not, ch02's Terraform falls back to logging and exits non-zero (ch02 / `terraform/evaluate-02/main.tf`).
  - [ ] Whether built-in judges run their model on LD's backend or in the app process. If the latter, the lab may need an OpenAI/Anthropic-direct credential added to Instruqt secrets.
- [ ] **Acceptance criteria REST API**: PHASES-evaluate.md noted this is likely UI-only at authoring time. If a PATCH endpoint exists on evaluations, wire it into `terraform/evaluate-01/main.tf` so ch01's solve produces graded results too.
- [ ] **Experiment fallthrough ruleId**: `terraform/evaluate-06/setup-experiment.py` tries the literal string `"fallthrough"` and falls back to parsing the targeting response. Confirm which form actually works.

---

## Per-challenge verification

For each challenge: confirm UI labels in `assignment.md` against the live LD UI; capture screenshots into `instruqt-evaluate/assets/`; add `![alt](../assets/<file>)` image references at the right beats; complete the lab as a real learner; click Check (expect pass); run solve from a fresh state and confirm check still passes; deliberately fail one assertion to confirm `fail-message` output is helpful.

### 00 Welcome

- [ ] No tasks; confirm copy reads cleanly. Recap of where Otto stands at track start should match what the track-level setup actually materializes.

### 01 Otto on the bench

- [ ] Verify UI for **Datasets** left-nav location and the dataset detail view. ch01 marks this VERIFY because the docs suggest evals are "in the playground" — confirm whether Datasets is its own section.
- [ ] Verify **Create evaluation** flow: dataset picker, Config picker, variation picker, Acceptance criteria panel, LLM-as-a-judge option, judge-prompt input.
- [ ] Confirm `{{expected_output}}` and `{{response}}` are the actual template variable names the acceptance-criteria surface substitutes.
- [ ] Run the evaluation against the post-Build Otto and confirm the results panel produces visibly mixed pass/fail rows. If too clean (all-pass), adjust the dataset.
- [ ] Capture screenshots of: Datasets list, dataset detail, eval creation, criterion config, results panel.

### 02 Quick takes (built-in judges)

- [ ] Verify the **Judges** section on a variation's detail page. **Attach judges** button label, sampling-rate UI (slider? input?).
- [ ] Confirm three built-in judges appear in the attach picker named Accuracy, Relevance, Toxicity.
- [ ] Confirm the monitoring view shows evaluator-metric lines for each attached judge.
- [ ] Verify that ~25% sampling × ~20 req/min produces visible scores within a couple of minutes.
- [ ] Capture screenshots of: Judges section, attach picker, monitoring view with built-in scores.

### 03 Otto sounds like Otto (custom brand-voice judge)

- [ ] Verify the **Create config** mode picker shows **Judge** as an option.
- [ ] Verify the **Evaluation metric** field on a judge config — when it's set on the Config vs on the variation.
- [ ] Verify the **Load snippet** button works inside judge variations (not just completion variations) and inserts the brand-voice snippet markup.
- [ ] Verify the `evaluationMetricKey` setting location on the **Otto Assistant** config — likely the Config detail page or Targeting tab.
- [ ] Verify the server.py paste-block step lands cleanly (marker still in place from Build ch01).
- [ ] Capture screenshots of: judge-mode picker, judge variation editor with snippet, otto-assistant evaluationMetricKey setting.

### 04 Otto checks his facts (custom product-claim judge)

- [ ] Same UI flows as ch03 for the second judge, plus snippet creation for `product-catalog`.
- [ ] Confirm a single Config can have multiple custom judges attached at different metric keys (per the Phase 0 finding — distinct metric keys = OK; same metric key = 422).
- [ ] Stack-test: with both ch03's and ch04's judge integrations pasted, both `ld_client.track` events fire on each chat.
- [ ] Capture screenshots of: second judge variation, monitoring view showing both custom-judge scores.

### 05 Quiz — judging Otto

- [ ] Read through the question; confirm exactly one correct answer (option 1, 0-indexed: "Both Otto's prompt AND the judge's grading criteria reference the same `brand-voice` snippet").
- [ ] Confirm Instruqt renders the answer markup without artifacts.

### 06 A vs. B (prompt experiment)

- [ ] Verify **Experiments** left-nav location.
- [ ] Verify experiment-creation flow: name/key, hypothesis, flag picker (Otto Assistant should appear), rule picker (Default rule = fallthrough), treatments (control + contender with allocation), randomization unit (user), primary metric (otto-brand-voice-score).
- [ ] Verify the **Start iteration** button location and any required confirmation.
- [ ] Verify the **Results** tab and **Promote winner** flow.
- [ ] Time the experiment to convergence with the synthetic traffic: should land within 60-90s.
- [ ] Capture screenshots of: experiment creation, treatments config, results panel, promote-winner flow.

### 07 Trust but verify (guarded rollout)

- [ ] Verify the **Start guarded rollout** entry point on the Default rule menu.
- [ ] Verify the rollout configuration UI: test/control variation pickers, metric picker (otto-brand-voice-score), regression-direction setting, stages (rolloutWeight + monitoring window), `onRegression: rollback`.
- [ ] Confirm the rollout fires a regression-detection event when background_traffic.py drives the metric below threshold.
- [ ] Confirm the sabotage script forces a rollback within a presenter-friendly timeframe.
- [ ] Capture screenshots of: rollout configuration dialog, in-progress rollout view, regression-detected event, post-rollback fallthrough.

### 08 Otto knows when to fold (adaptive switching)

- [ ] Confirm `adaptive.py` source compiles and imports cleanly when copied into `app/`.
- [ ] Confirm the patch-server.py's two anchors (`import boto3` and the ch03 `ld_client.track("otto-brand-voice-score"...)` line) are present in server.py after the prior phases have been applied.
- [ ] Time the adaptive loop's first flip: with ~5s/request from realchat_traffic and the window of 10 samples + threshold 0.5, the flip should fire within ~60-90s of setup.
- [ ] Confirm the LD UI Targeting view updates within a few seconds of the REST PATCH firing.
- [ ] Capture screenshots of: server.py with adaptive_observe paste, journalctl log showing the flip event, Targeting view before and after the flip.

### 09 Wrap-up

- [ ] Read through the recap; confirm it accurately reflects what the learner just did.
- [ ] Read through the question; confirm exactly one correct answer (option 2, 0-indexed: "Guarded rollout reacts at release time, while traffic is ramping; adaptive switching reacts between requests in production").
- [ ] Confirm Otto's closing line lands.

---

## Known stale-context items recently resolved (no operator action needed)

These are recorded for context — recent commits already addressed them.

- Dataset shape (input/expected_output/metadata) confirmed from LD docs and locked in `terraform/evaluate-01/datasets/customer-questions.jsonl` (commit `82fcbab`).
- Built-in judges' `judgeConfigKey` value isn't published; the lookup approach in `terraform/evaluate-02/main.tf` discovers them at apply-time via the configs-list API filtered by metric key (commit `2227921`).
- Custom judges use the manual `judge_config + bedrock.converse` invocation pattern from legacy Build ch07, not the SDK's `create_judge + evaluate` flow (which needs a Bedrock provider plugin that doesn't exist; see the "Judge invocation: SDK eval + manual Bedrock call" entry in `DECISIONS.md`).
- Variation numbering: Otto v1 (Born), Otto v2 (Premium), Otto v3 (Recommender), Otto v4 (Formal). Consistent across all of Evaluate's authored content.

---

## How to mark progress

Tick items as `[x]` when verified. Capture per-item gotchas inline as plain prose under the bullet (e.g. UI label differs from the docs draft; alternative wording the operator chose). When all per-challenge items are ticked and the cross-cutting smoke test passes, Evaluate is genuinely ship-ready.
