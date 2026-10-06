# OPERATOR-CHECKLIST-evaluate.md

Per-challenge verification items for **Track 2 / Evaluate** (`instruqt-evaluate/`). All ten challenges (00–09) are authored. Remaining work below is verification that requires either the live LaunchDarkly UI or a real sandbox run — Claude Code drafted from docs but can't drive a browser.

Author-side polish (`PHASES-evaluate.md` Phase 9) is complete as of 2026-06-01.

---

## Cross-cutting items

- [ ] **Live-fire end-to-end smoke test** against a fresh sandbox: bootstrap → click through every challenge → solve every challenge → confirm every check passes. Time each challenge.
- [ ] **Track-level `setup-workstation` timing.** It applies the bootstrap + Build's challenge-01/02/03/05/06 solves + ch01's `patch-server.py`. PHASES-evaluate.md flagged 60s as the threshold above which the operator should consider pre-baking the post-Build state into the VM image instead.
- [ ] **VM image re-bake** to pick up the new `realchat_traffic.py`, `experiment_traffic.py`, and updated `background_traffic.py` / `sabotage.py`. Bump `vm-image/build-image.sh`'s `REPO_REF` and the image's `-N` suffix in `instruqt-build/config.yml` / `instruqt-evaluate/config.yml`.
- [ ] **Three open Phase 0 / Phase 8 questions to live-verify against a real LD project:**
  - [x] Dataset upload contract: confirmed 2026-10-06 via the live UI — `POST /internal/.../datasets` returns `upload.uploadUrl`; `PUT` with `Content-Type: application/x-ndjson` works; status flips to `ready` in seconds. Shapes in `instruqt-evaluate/INTERNAL-API.md`.
  - [ ] Built-in judge discovery: confirm built-in Accuracy/Relevance/Toxicity judges surface via `GET /ai-configs?limit=100&mode=judge` filter; if not, ch02's Terraform falls back to logging and exits non-zero (ch02 / `terraform/evaluate-02/main.tf`).
  - [ ] Whether built-in judges run their model on LD's backend or in the app process. If the latter, the lab may need an OpenAI/Anthropic-direct credential added to Instruqt secrets.
- [x] **Acceptance criteria REST API**: confirmed 2026-10-06 — criteria are a `criteria[]` array on the evaluation (`PATCH /internal/.../evaluations/{id}`), e.g. `{"criterionType":"answer_relevancy","kind":"deepeval","options":{"threshold":0.5,"passRateThreshold":0.95}}`. Wired into `terraform/evaluate-01/main.tf`.
- [ ] **Bedrock BYOK for playground runs (BLOCKER for ch01).** Playground runs execute on LD's backend using the account-level **Manage API keys** integration (`aiconfig-test-run`). Bedrock there is an IAM role + external ID that LaunchDarkly assumes, configured once per LD *account*, not per project. In the `kevinc-instruqt` sandbox on 2026-10-06 the only Bedrock entry (a colleague's `eu-north-1` role) fails with `Bedrock request failed: AccessDenied (HTTP 403). Check that the role's trust policy allows LaunchDarkly to assume it and that the external ID matches.` Action: in the account the IdP simulator logs learners into, open any playground → **Manage API keys** → **Add API key** → provider **Bedrock**, create the IAM role with the generated external ID and Bedrock invoke permissions for Haiku 4.5 / Sonnet 4.6 in the chosen region, and confirm a run completes. Also confirm an **Anthropic** key is present and enabled — the playground's default *evaluation model* is `Anthropic.claude-sonnet-4-5` (direct Anthropic, not Bedrock), which grades the criteria.
- [ ] **`echo "$JSON" | jq` under dash corrupts prompt text (Build track).** Ubuntu's `/bin/sh` is dash, whose `echo` expands `\n` escapes, so any JSON payload carrying prompt text breaks jq with "control characters must be escaped". All Evaluate scripts were switched to `printf '%s' "$VAR" | jq` on 2026-10-06. Three Build check scripts still use `echo` (`instruqt-build/01-otto-is-born/check-workstation` ×6, `05-otto-for-everyone` ×1, `06-how-is-otto-doing` ×1); convert them the same way.
- [ ] **Duplicate Haiku model configs in the picker.** The model search shows two identical `anthropic.claude-haiku-4-5-20251001-v1:0` entries; one resolves to `Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0`, the other to a hashed `…-v1-0-cb7c4314`. Learners can't tell them apart, so no check asserts an exact model key. Consider asking LD to dedupe.
- [x] **Custom-judge scores vs the Monitoring card.** Resolved 2026-10-06: the ch03/ch04 server pastes (Terraform copies and assignment code blocks) now build a `JudgeResult` and call `tracker.track_judge_result(...)` in addition to `ld_client.track("otto-…-score")`, mirroring the ch02 pattern. Confirm on a live VM that the `$ld:ai:judge:<key>` cards populate.
- [ ] **Metrics are now pre-created by setup.** ch03/ch04 setup-workstation apply `-target=launchdarkly_metric.*` so `otto-brand-voice-score` / `otto-claim-accuracy-score` exist in the learner path (the UI flow never creates them, and ch06/ch07 need them). Confirm you're happy with this vs. adding a "create the metric" UI section.
- [ ] **Native "Add adaptive trigger" on the Default rule.** LaunchDarkly now offers an adaptive trigger directly on the targeting rule (`GET …/adaptive-triggers?resourceKind=ai-config`). ch08 teaches the in-app loop deliberately; decide whether the wrap-up should mention the built-in alternative.
- [ ] **Completed-run state name.** Runs start as `state: PENDING` and error as `PERMANENT_ERROR`; the success value was never observed because of the Bedrock blocker above. Once a run completes, note the state string in `instruqt-evaluate/INTERNAL-API.md`. `check-workstation` doesn't depend on it (it uses `/summary` statusCounts), but it's useful to know.
- [ ] **Token auth on `/internal` endpoints.** The ch01 scripts assume `Authorization: $LAUNCHDARKLY_ACCESS_TOKEN` works on `/internal/projects/...` like it does on `/api/v2` (earlier operator curls against `kcochran-ld-demo` suggest it does). Claude Code only verified the shapes through the browser session. Smoke-test once:
  `curl -fsS -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" -H 'LD-API-Version: beta' https://app.launchdarkly.com/internal/projects/<key>/playgrounds?sortBy=createdAt`
- [ ] **Experiment fallthrough ruleId**: `terraform/evaluate-06/setup-experiment.py` tries the literal string `"fallthrough"` and falls back to parsing the targeting response. Confirm which form actually works.

---

## Per-challenge verification

For each challenge: confirm UI labels in `assignment.md` against the live LD UI; capture screenshots into `instruqt-evaluate/assets/`; add `![alt](../assets/<file>)` image references at the right beats; complete the lab as a real learner; click Check (expect pass); run solve from a fresh state and confirm check still passes; deliberately fail one assertion to confirm `fail-message` output is helpful.

### 00 Welcome

- [ ] No tasks; confirm copy reads cleanly. Recap of where Otto stands at track start should match what the track-level setup actually materializes.

### 01 Otto on the bench

Click-through completed by Claude Code via Chrome DevTools MCP on 2026-10-06 in `kevinc-instruqt`; `assignment.md` labels updated to match. Remaining items need a working Bedrock BYOK connection (see cross-cutting blocker).

- [x] Datasets live at **Library → Datasets** tab (not their own left-nav entry). Upload dialog: **New dataset → Upload dataset**, fields **Name**, **Key**, drag/drop or **Browse**, **Save dataset**. The list shows Upload status **Ready** and row count.
- [x] Playground flow verified: **Agents** → **Playgrounds** → **New playground**; inline rename; per-column **Load config** dialog (config list on the left, **Select a variation** dropdown, **SYSTEM** preview, **Load config**); **Add message** (defaults to **User** role); dataset bar **Select a dataset (optional)** with **All rows / Top / Random**, **Rows**, **#/%**, **Seed**; right pane **Variables / Evaluation model / Acceptance criteria → Add criteria** (Likeness, Accuracy, Answer Relevancy, Toxicity, Bias, Misinformation); **Run all** (a11y label "Save and run all").
- [x] Load config carries the variation's model over (A shows `anthropic.claude-haiku-4-5-20251001-v1:0`, B shows `anthropic.claude-sonnet-4-6`, both Bedrock). The "search for the model" step is now a verification step.
- [x] Switching **Top → Random** resets **Rows** to the full row count (30); assignment tells the learner to type 15 after.
- [ ] `{{expected_output}}` / `{{response}}` template names: the dataset-bound variables panel shows **From dataset: expected_output, input**. Confirm how the built-in criteria consume `expected_output` (no judge-prompt input is exposed for built-ins).
- [ ] Run the playground once Bedrock BYOK works and confirm visibly mixed pass/fail rows. If too clean (all-pass), adjust the dataset.
- [ ] Run `solve-workstation` from a fresh project and confirm `check-workstation` passes; then delete the playground and confirm the check fails with the "haven't created a playground" message.
- [ ] Capture screenshots of: Datasets list, Upload dataset dialog, New playground, Load config dialog, dataset bar with Random/15, Acceptance criteria panel, results table. Reference `assets/otto-load-config.png` already exists.

### 02 Quick takes (built-in judges)

Click-through completed 2026-10-06; `assignment.md`, `check-workstation`, and `terraform/evaluate-02` updated.

- [x] Judges live on the **Variations** tab: expand **Otto (Born)** → **+ Add judges** (next to Add message / Add tools) → dialog lists **Accuracy**, **Relevance**, **Toxicity** with an **All judges** tick → **Add 3 judges**. A **Judges** table appears (Event key `$ld:ai:judge:*`, **Provider** dropdown, **Sampling percentage** default 10%). **Review and save** → **Save changes**.
- [x] Adding built-ins creates three judge-mode configs in the project (`accuracy`, `relevance`, `toxicity`). Terraform now creates them from captured templates (`builtin-judges/*.json`) before attaching.
- [x] Monitoring has no "Evaluator metrics" dropdown; judge cards appear automatically under the **Charts** selector.
- [ ] Confirm the realchat traffic + ch02 paste actually populate the judge cards (needs a live VM).
- [ ] Capture screenshots: Add judges dialog, Judges table, Monitoring judge cards.

### 03 Otto sounds like Otto (custom brand-voice judge)

Click-through completed 2026-10-06; assignment rewritten around the generator flow, check re-enabled, Terraform attaches the judge to both Otto variations.

- [x] **Create config** dialog: mode selector (Completion / Agent / **Judge**), **What should this judge evaluate?**, **Judge model** provider dropdown (Anthropic default → **Bedrock**), **Edit config key** (this is what makes `otto-brand-voice-judge` deterministic), **Generate judge**.
- [x] Generate judge lands on a populated **Default** variation (Sonnet 4.5, three messages, `{{message_history}}` / `{{response_to_evaluate}}`), an AI-generated name, and **Desired direction** possibly *Lower is better*. Assignment now has the learner replace the model and prompt, delete the two helper messages, rename, and set **Higher is better**.
- [x] **Load snippet** dialog lists snippets by name (**Brand voice**, **Safety rules**).
- [x] Judge configs come up On in both environments with Default rule → Default; "Turn the judge on" is now a confirmation step.
- [x] **+ Add judges** on Otto lists **Otto Brand Voice Judge** alongside the built-ins.
- [ ] Confirm on a live VM that the `$ld:ai:judge:otto-brand-voice-judge` card populates after the paste (emission added 2026-10-06).
- [ ] Capture screenshots: Create config (Judge), generated Default variation, Edit config key, Desired direction editor, Add judges with the custom judge.

### 04 Otto checks his facts (custom product-claim judge)

Snippet flow verified 2026-10-06; judge flow mirrors ch03. Assignment, check, Terraform (Bedrock model key, attach step), and setup (metric pre-create) updated.

- [x] **Library → Snippets → Create snippet** dialog has **Name**, **Description (optional)**, **Body**, maintainer, tags, **Save**. No key field: `Product catalog` → `product-catalog`.
- [x] Judge creation identical to ch03 with key `otto-claim-accuracy-judge` via **Edit config key**.
- [ ] Stack-test: with both pastes applied, both `ld_client.track` events fire on each chat (needs live VM).
- [ ] Capture screenshots: Create snippet dialog, second judge, Monitoring with both judge cards.

### 05 Quiz — judging Otto

- [ ] Read through the question; confirm exactly one correct answer (option 1, 0-indexed: "Both Otto's prompt AND the judge's grading criteria reference the same `brand-voice` snippet").
- [ ] Confirm Instruqt renders the answer markup without artifacts.

### 06 A vs. B (prompt experiment)

Full click-through completed 2026-10-06 (variation → experiment → start → stop/ship). Assignment, check, and `setup-experiment.py` rewritten.

- [x] **Add variation** opens an **Untitled variation** card in **Draft**; no key field (`Otto (Recommender)` → `otto-recommender`). Model search box matches across providers.
- [x] **Experimentation → Experiments → Create experiment** dialog: name, hypothesis, maintainer, tags → **Create experiment**. Lands on **Design** with "Experiment design is not complete". The hypothesis did **not** carry over into the Design page in the sandbox; the assignment tells learners to re-enter it.
- [x] Design labels: **Assignment method**, **Flag or config** (Find a flag or config by name or key), **Targeting rule** (Default Rule), **Randomize by**, **Audience allocation** (percent buttons 5/10/50/100/Custom), **Variations split → Edit → Variation Split dialog** (Include in experiment ticks, **Split equally**, **Save audience split changes**), **Metrics → Select metrics or metric groups** (lists **Otto Brand Voice Score** by name) → **Done**, **Statistical approach** (Frequentist default, **Bayesian**), **Save**.
- [x] Start: banner **Start** → **Start experiment** dialog; page switches to **Results**. Stop: **Stop** menu lists each variation (+ **Request approval to stop**) → **Stop experiment** dialog (variation to ship, reason, type `test`).
- [x] API: create needs `maintainerId`; `ruleId: "fallthrough"`; `flagConfigVersion` = targeting env `_version`; start via `startIteration` semantic patch. Validated end-to-end with a scratch experiment (archived afterwards).
- [ ] Time the experiment to convergence with synthetic traffic (needs live VM).
- [ ] Capture screenshots: Add variation, Create experiment, Design page, Variation Split dialog, Results, Stop menu.

### 07 Trust but verify (guarded rollout)

Full click-through completed 2026-10-06 (start → stop/roll back). Assignment, check, and solve rewritten; solve now starts a real guarded rollout via `startAutomatedRelease`.

- [x] Entry point is **Default rule → Edit (pencil) → Serve dropdown → Rollout → Guarded rollout** (the ⋮ menu only has "Create experiment from rule"). No "Start guarded rollout" button.
- [x] Form: **Original variation**, **Target variation**, **Metrics to monitor → Select metrics or metric groups** (row gains an **Automatic rollback** tick), **Target by**, **Rollout duration** (1 hour / 12 / 24 / 48 / 1 week / **Custom** → four stages 5/10/25/50% each with interval + unit days/hours/**minutes**). No separate "regression direction" or "on regression" controls; direction comes from the metric's success criterion.
- [x] **Review and save** → **Save changes** dialog titled "Start release on default rule" with a **Health check warnings** notice (expected with thin data). Live rule shows **In progress**, the split, remaining stages, and **Stop release** (→ **Roll forward** / **Roll back**).
- [x] Targeting shape: `fallthrough.rollout.experimentAllocation.type == "measuredRollout"`; release history on the internal `automated-releases` endpoint (`status: manually_reverted` observed).
- [ ] Observe an actual auto-rollback with background traffic + sabotage and record the timeline wording (`VERIFY` left in the assignment).
- [ ] Capture screenshots: Serve dropdown, guarded rollout form, Custom duration stages, Save changes dialog, In-progress rule, Stop release dialog.

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
