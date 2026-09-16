# PHASES-evaluate.md

Build sequence for **Track 2 / Evaluate** (`instruqt-evaluate/`), the second of the workshop's three sibling tracks. Mirrors the structure of the original `PHASES.md`: phases group related challenges, Claude Code works one phase at a time, and operator review gates each phase boundary.

Track 2 starts where Track 1 ends — the learner's LD project already has the post-Build state (Otto created, snippets in place, premium variation, monitoring populated). The track-level `setup-workstation` runs Build's solve scripts to materialize that baseline before any Evaluate-specific work runs.

---

## Track 2 / Evaluate — scope

By the end of Evaluate, the learner has used every major Lesson-2 surface of AgentControl:

- Built a labeled dataset and run an **offline evaluation** against a known-good Otto.
- Attached **built-in judges** (accuracy + relevance) to Otto and watched scores populate.
- Authored a **custom brand-voice judge** that reuses the L1 `brand-voice` snippet so the same snippet drives both Otto's prompt and the judge's grading criteria.
- Authored a **custom product-claim judge** that uses the ToggleWear catalog as ground truth — different judge shape than brand-voice, demonstrating accuracy-against-data vs voice-against-style.
- Run a **prompt experiment** comparing two variations on live lab traffic and promoted the winner.
- Configured a **guarded rollout** of a risky variation (the deliberately-bad Nova Pro Formal variation from the former Build ch07), watching the brand-voice judge metric auto-rollback the regression.
- Wired an **adaptive switching** loop in the app — a request-time fallback that flips Otto's targeting via REST when the judge score crosses a threshold.

Final challenge list (10 challenges, ~2h):

| # | Slug | Type |
|---|---|---|
| 00 | welcome | challenge |
| 01 | otto-on-the-bench | challenge (golden dataset + offline eval) |
| 02 | quick-takes | challenge (built-in judges) |
| 03 | otto-sounds-like-otto | challenge (custom brand-voice judge) |
| 04 | otto-checks-his-facts | challenge (custom product-claim judge) |
| 05 | quiz-judging-otto | quiz |
| 06 | a-vs-b | challenge (prompt experiment) |
| 07 | trust-but-verify | challenge (guarded rollout — lifts from `instruqt-build/`) |
| 08 | otto-knows-when-to-fold | challenge (adaptive switching) |
| 09 | wrap-up | challenge |

Slugs are draft and may shift during authoring; final slugs lock in Phase 1.

---

## Source-of-truth notes

- `CLAUDE.md` — operational spec. The conventions in there apply across all three tracks unchanged.
- `DECISIONS.md` — see the "Workshop splits into three sibling Instruqt tracks" entry for the rationale that produced this scope.
- `NARRATIVE.md` — Otto's voice, ToggleWear brand, product list. Evaluate's prose must stay consistent with it. The `brand-voice` and `safety-rules` snippets defined there are reused inside Evaluate.
- `PHASES.md` — historical record for Track 1 / Build. Path conventions in there predate the `instruqt-build/` rename.

---

## Phase 0: Verification spike

**Goal:** Pin down the API/UI shape of each new surface before authoring touches it. Several Evaluate concepts were not exercised in Build, and AgentControl is still evolving fast enough that training-data assumptions will be stale.

**What needs verification:**

1. **Datasets + evaluations** (challenge 01)
   - Dataset shape — CSV upload? JSON via REST? Both? Required columns?
   - Evaluation run — does an evaluation invoke the live model for each row, or does the learner supply expected responses?
   - Where do results appear in the UI; can they be exported as CSV/JSON?
   - Does the Terraform provider expose `launchdarkly_dataset` / `launchdarkly_evaluation`, or are we REST-only via `null_resource`?
   - MCP tools `create-dataset` / `create-evaluation` / `run-evaluation` / `get-evaluation-run-summary` exist — confirm REST endpoints + payload shapes from them.

2. **Built-in judges** (challenge 02)
   - Which built-in judges does AgentControl ship today? At minimum confirm "accuracy" and "relevance" land; note any others worth mentioning.
   - Attachment flow — UI path on a Config's page; Terraform resource (if any); REST endpoint.
   - Sampling rate — is the percentage configured per-judge or per-Config? Where does the rate live?
   - Does the LD SDK do the sampling automatically, or does the app need to opt in? (Probably automatic, but confirm.)
   - Where do scores appear — same monitoring view as L1, or a new judges-specific view?

3. **Custom judges** (challenges 03 + 04)
   - Largely known from the former Build ch07. The `otto-response-judge` Config (mode=`judge`) pattern works.
   - **Critical to verify:** can a judge's prompt reference a snippet via `{{ldsnippet.<key>}}` (or whatever the canonical syntax is — see the `DECISIONS.md` entry "Config snippet-reference syntax: deferred to operator verification"). The brand-voice judge's whole pedagogical hook depends on this working.
   - Can a single Config have multiple custom judges attached at once? Challenge 04 stacks the product-claim judge on top of the brand-voice judge — confirm that's allowed and that both metrics flow independently.

4. **Prompt experiment** (challenge 06)
   - Does AgentControl expose first-class experiments on Configs, or do experiments still run on feature flags that gate Configs?
   - MCP tools `create-experiment` / `start-experiment-iteration` / `update-experiment` exist — read their payload shapes.
   - Which metric kinds qualify as experiment outcomes? (Token cost? Latency? Custom feedback? Judge score?)
   - How is the winner promoted — UI button, REST patch, or both? Does promoting a variation in an experiment update the Config's targeting fallthrough?
   - "Non-obvious winner" design question (operator flagged): pick two Otto variations whose winner the learner couldn't predict. Candidates land in Phase 5's deliverables.

5. **Adaptive switching** (challenge 08)
   - Confirmed pattern, not product feature. The lab is the app code.
   - REST endpoint for updating a Config's targeting rules — confirmed via the `update-ai-config-targeting-rules` MCP tool, but confirm the exact semantic-patch instruction kinds.
   - Design choice for the trigger: does the app *poll* LD's metric API for the judge score, or does it accumulate scores locally and act on its own threshold? Local accumulation is simpler; polling is more realistic. Lean local but verify polling is feasible if the operator prefers.
   - How does the loop "switch back" once the regression clears? Or does it not — the lab demo can be one-way.

6. **Guarded rollout rewire** (challenge 07)
   - The former Build ch07 creates its own `otto-response-judge` Config. Evaluate's version uses the brand-voice judge introduced in challenge 03 (whose metric is already wired to `otto-quality-score`, or whatever we name it). Confirm the `evaluationMetricKey` PATCH on the otto-assistant Config can be re-pointed mid-track without breaking prior monitoring data.

**Deliverables:**

- A `PHASES-evaluate-verification.md` (or appended section at the bottom of this file) capturing what each verification produced. Same shape as the "Phase 1 verification notes" appendix at the bottom of the existing `PHASES.md`.
- Concrete REST payloads / Terraform snippets / UI step counts for each of the six verification topics above.
- A go/no-go for each upcoming phase. Any phase whose surface verification reveals product gaps gets re-scoped before authoring starts.

**Done-when:**

- Operator and Claude Code agree the surface area is well-understood enough to author against confidently.
- Any product gaps surfaced (e.g., a feature not yet shipped, a UI flow that's pre-release) are escalated to the LD product team before authoring the affected challenge.

---

## Phase 1: Track foundation

**Goal:** Scaffold `instruqt-evaluate/` to the same skeleton that `instruqt-build/` had at its Phase 1.

**Deliverables:**

- `instruqt-evaluate/track.yml` — slug, ID, title (track-2-specific), teaser, description, 2h time limit, lab config. Mirror `instruqt-build/track.yml` structure.
- `instruqt-evaluate/config.yml` — virtual browser, the shared `launchdarkly/workshop-ai-configs` VM image, secrets. Mirror Build's `config.yml` except the secrets list (no need for `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` since federation replaced them — see [[project-aws-credentials]] in memory; cross-check with what Build's `config.yml` currently declares).
- `instruqt-evaluate/track_scripts/setup-workstation` — runs `terraform/student-bootstrap/` then applies the prior-track solves (`terraform/challenge-01/` through `terraform/challenge-06/`) to materialize Otto's post-Build state in the learner's fresh LD project. Also runs the Challenge 01 server-paste patch so `server.py` is in its post-Build "Otto wired up" state.
- `instruqt-evaluate/track_scripts/cleanup-workstation` — same idiom as Build's.
- Empty `instruqt-evaluate/00-welcome/` through `09-wrap-up/` directories, each with a placeholder `assignment.md` containing only front-matter (no body).
- `instruqt-evaluate/assets/` directory created (empty for now; populated as challenges are authored).

**Verification steps:**

- `track.yml` and `config.yml` parse as valid YAML.
- Placeholder `assignment.md` files all have valid front-matter (slug, id, type, title, teaser, notes, tabs, difficulty, timelimit).
- Track-level `setup-workstation` is idempotent — running it twice doesn't break the bootstrap or duplicate state.
- Manually validate the bootstrap loop end-to-end: spin a fresh sandbox, run setup, confirm Otto exists with the snippets + premium variation + monitoring traffic that Build leaves behind.

**Done-when:**

- Operator confirms the scaffold mirrors Build's conventions.
- The bootstrap delay (running all Build solves) is timed and confirmed acceptable. If too slow (>60s), consider a pre-baked snapshot in a later phase.

---

## Phase 2: Golden dataset + offline eval (challenge 01)

**Goal:** Author challenge 01 — `otto-on-the-bench`. Learner uploads a labeled dataset of customer questions with expected response criteria, runs an offline evaluation against Otto's current variation, and reviews the results.

**Deliverables:**

- `instruqt-evaluate/01-otto-on-the-bench/assignment.md` — learner-facing instructions. Dataset upload steps, evaluation run steps, results-review prompts.
- `instruqt-evaluate/01-otto-on-the-bench/setup-workstation` — uploads a starter dataset to the learner's project if the lab benefits from one being pre-seeded; otherwise empty.
- `instruqt-evaluate/01-otto-on-the-bench/check-workstation` — validates dataset exists in the project (via `GET /api/v2/projects/{key}/datasets/{key}` or the equivalent) and that at least one evaluation run has completed against Otto.
- `instruqt-evaluate/01-otto-on-the-bench/solve-workstation` — applies the per-challenge Terraform module to create the dataset + run an evaluation programmatically.
- `terraform/evaluate-01/main.tf` — creates the dataset and triggers an evaluation run via either provider-native resources (if supported by Phase 0's findings) or `null_resource` + `local-exec curl` against the REST API.
- `terraform/evaluate-01/datasets/customer-questions.json` (or `.csv`) — the dataset itself, 20-40 labeled questions. Each row has a customer question, an expected-content rubric, and tags. Content drawn from ToggleWear's product catalog and common-policy concerns. See [[project-concierge-team]] if any of the questions need agent-routing flavor, otherwise stay Build-flavored.

**Specific notes:**

- The dataset content design matters — it should produce visibly mixed results (some pass, some fail) so the eval view tells a story. All-pass is boring; all-fail makes Otto look broken.
- Expected response criteria should be specific enough to grade automatically but flexible enough to allow Otto's voice variation (e.g., "mentions the Rocket Tee," "doesn't invent a price").
- The learner doesn't need to author the dataset — they upload the starter and inspect it. Authoring datasets is a future-track concern.

**Verification steps Claude Code performs:**

- Run setup, then solve, confirm check passes against the solved state.
- Run the eval against the current post-Build Otto and confirm the results panel is populated and tells a coherent story.
- Mark UI-specific instructions with `<!-- VERIFY: ... -->` per `CLAUDE.md`.

**Operator verification:**

- Walk through the lab with the draft open, correct UI steps, capture screenshots.
- Confirm the dataset shape feels right (size, variety, difficulty).

**Done-when:**

- Operator click-through verified.
- Markers resolved, screenshots placed.
- Check passes on solve; fails helpfully on a no-dataset-uploaded state.

---

## Phase 3: Built-in judges (challenge 02)

**Goal:** Author challenge 02 — `quick-takes`. Learner attaches AgentControl's built-in judges (accuracy + relevance) to Otto with a ~25% sample rate, watches scores populate in the monitoring view.

**Deliverables:**

- `instruqt-evaluate/02-quick-takes/assignment.md` — UI walkthrough for attaching built-in judges, setting sample rate, and finding scores in monitoring.
- `instruqt-evaluate/02-quick-takes/setup-workstation` — kicks off a background traffic generator at low rate so there's something for the judges to grade (similar pattern to Build's ch07 sabotage idiom — see `traffic-generator/background_traffic.py`).
- `instruqt-evaluate/02-quick-takes/check-workstation` — confirms Otto has at least one built-in judge attached via the API. Also confirms metric events flowing.
- `instruqt-evaluate/02-quick-takes/solve-workstation` — applies the Terraform module that attaches both built-in judges.
- `terraform/evaluate-02/main.tf` — attaches `accuracy` and `relevance` judges to the otto-assistant Config (provider-native if supported, else REST PATCH). Sets sample rate.

**Specific notes:**

- No app code changes for this challenge. The SDK does the sampling automatically (verify in Phase 0).
- The 25% sample rate is operator-tunable. Keep it low enough that judge invocation cost stays modest, high enough that scores accumulate visibly in the ~5min the learner spends on the challenge.
- The assignment.md is exploratory — learner navigates, observes, no extensive code edits.

**Verification steps:**

- Setup runs, judges attach, traffic generator produces enough samples for visible scores.
- Mark UI navigation with verify markers as needed.

**Operator verification:**

- Walk through, confirm the monitoring view actually shows judge scores within the challenge's time budget.
- Capture screenshots.

**Done-when:**

- Operator click-through verified.
- Built-in judges produce visible scores in the lab's time window.

---

## Phase 4: Custom judges (challenges 03 + 04)

**Goal:** Author two custom-judge challenges that share a pattern. Challenge 03 introduces the custom-judge mechanics and the brand-voice judge whose prompt reuses the L1 `brand-voice` snippet. Challenge 04 stacks a second custom judge (product-claim accuracy) on top.

This is the only Evaluate phase that changes `server.py` — the learner pastes the judge-invocation block into the server (same paste-block pattern Build used in ch01 and the old ch07).

**Deliverables for challenge 03 (`otto-sounds-like-otto`):**

- `instruqt-evaluate/03-otto-sounds-like-otto/assignment.md` — UI steps to create a new Config with `mode: judge`, prompt that interpolates `{{response}}` and references `{{ldsnippet.brand-voice}}` (or canonical syntax per Phase 0 finding), and a 1-5 scoring rubric. Then a code-paste step that adds the judge invocation block to `server.py` between the existing markers.
- `instruqt-evaluate/03-otto-sounds-like-otto/setup-workstation` — places the judge-paste source file on the workstation and seeds any prerequisites.
- `instruqt-evaluate/03-otto-sounds-like-otto/check-workstation` — confirms a `mode: judge` Config exists referencing the brand-voice snippet AND that `server.py` contains the judge invocation block (`grep -q "ai_client.judge_config" /opt/ld/ai-configs-intro/app/server.py`).
- `instruqt-evaluate/03-otto-sounds-like-otto/solve-workstation` — applies the Terraform module + runs the patch-server.py to inject the judge block.
- `terraform/evaluate-03/main.tf` — creates the brand-voice judge Config + variation. References the brand-voice snippet in the variation's system message.
- `terraform/evaluate-03/judge-server-paste.py` — the canonical judge invocation block to paste into `server.py`. May be a near-clone of `terraform/challenge-07/judge-server-paste.py` (the old ch07 paste); the differences if any come from Phase 0's snippet-syntax finding and from naming.
- `terraform/evaluate-03/patch-server.py` — finds the `# ─── Challenge 07 judge injects below this marker ──────` marker (note: marker text is legacy; rename or keep — operator decision) and inserts the judge block.

**Deliverables for challenge 04 (`otto-checks-his-facts`):**

- `instruqt-evaluate/04-otto-checks-his-facts/assignment.md` — same shape as 03, but the new judge grades responses for product-claim accuracy against the ToggleWear catalog. Learner creates a second `mode: judge` Config whose prompt includes the catalog inline (or via a snippet — Phase 0 to confirm whether snippet-as-data is supported) and grades whether Otto invented prices/materials/policies.
- `instruqt-evaluate/04-otto-checks-his-facts/setup-workstation` — installs the second judge-paste source.
- `instruqt-evaluate/04-otto-checks-his-facts/check-workstation` — confirms second judge Config exists AND `server.py` contains the second invocation block.
- `instruqt-evaluate/04-otto-checks-his-facts/solve-workstation` — applies Terraform + patches `server.py` for the second judge.
- `terraform/evaluate-04/main.tf` — creates the product-claim judge Config + variation. The catalog content is inlined into the variation's system message (or stored as a snippet — Phase 0 dictates).
- `terraform/evaluate-04/judge-server-paste.py` — second judge invocation block.
- `terraform/evaluate-04/patch-server.py` — inserts second block, idempotent against the first.

**Specific notes:**

- The judges-emit-metrics convention: brand-voice judge emits `otto-brand-voice-score`, product-claim judge emits `otto-claim-accuracy-score`. Both flow as numeric custom metrics to the otto-assistant Config. The brand-voice metric is what ch07's guarded rollout watches.
- For challenge 04, the catalog needs to be machine-readable inside the judge prompt. Options: inline the product list as JSON in the system message, OR define a `product-catalog` snippet and reference it. Lean snippet — it reinforces the snippet-as-data pattern.
- The two judges-as-snippet-driven Configs validate the user's design hypothesis ("a snippet can drive both prompt content and judge criteria").

**Verification steps Claude Code performs:**

- Run setup → solve for both; confirm checks pass.
- Test the judge prompts manually with several known-good and known-bad responses; confirm scores are stable.

**Operator verification:**

- Click-through for both challenges. Capture screenshots.
- Confirm judge scoring is stable enough to demo without judges contradicting themselves run-to-run.

**Done-when:**

- Both challenges' click-throughs verified.
- Both judges produce stable, non-contradictory scores.
- The marker pattern still works after two consecutive paste injections.

---

## Phase 5: Prompt experiment (challenge 06)

**Goal:** Author challenge 06 — `a-vs-b`. Learner creates a second Otto variation (alongside the existing born variation), sets up a prompt experiment comparing them on a metric, reads the results panel, promotes the winner.

**Deliverables:**

- `instruqt-evaluate/06-a-vs-b/assignment.md` — UI steps to create the contender variation, configure the experiment (metric, allocation, duration), read results, promote winner.
- `instruqt-evaluate/06-a-vs-b/setup-workstation` — kicks off a higher-volume traffic generator so the experiment can collect enough data to converge inside the challenge's time budget.
- `instruqt-evaluate/06-a-vs-b/check-workstation` — confirms a second variation exists, an experiment is started, and (after reasonable time) confirms a winner has been promoted (variation reflected in fallthrough).
- `instruqt-evaluate/06-a-vs-b/solve-workstation` — applies Terraform that creates the variation + starts the experiment + (optionally) promotes the predetermined winner.
- `terraform/evaluate-06/main.tf` — creates the second variation, the experiment config, and (via REST `null_resource` if no provider support) starts the iteration. Promotion REST call optional in solve.
- `terraform/evaluate-06/traffic-generator-config.json` — weights for the traffic generator so the experiment's metric resolves to a clear winner inside the time budget without it being obvious from the prompts themselves.

**Specific notes on the non-obvious winner:**

The operator flagged this as a design challenge — the experiment landing flat if the winner is obvious. Candidate variation pairs (operator picks one during this phase):

- **Terse Otto vs. explainer Otto** — both warm + on-brand, but one keeps answers short and the other adds product details unprompted. The winner on a session-completion metric is non-obvious.
- **Question-asking Otto vs. answer-first Otto** — both helpful, but one asks a clarifying question before answering ambiguous queries while the other guesses and pivots if corrected.
- **Recommend-the-popular-thing vs. recommend-by-occasion** — both warm + helpful, but one defaults to top-sellers and the other tries to read context.

In each pair the operator picks weights for the traffic generator so the metric movement is real but not predictable from a quick read of the prompt.

**Verification steps:**

- Run setup, then solve, confirm check passes.
- Run the traffic generator and confirm the experiment converges within ~30s of generation time (typical lab budget for the convergence step).
- Mark UI navigation with verify markers as needed.

**Operator verification:**

- Click-through; pick the variation pair; confirm winner is non-obvious from prompt-reading alone.
- Capture screenshots of the results panel showing the convergence.

**Done-when:**

- Operator verified the lab works end-to-end.
- Variation pair lands with the desired "you wouldn't have guessed that" property.

---

## Phase 6: Guarded rollout — lift + rewire (challenge 07)

**Goal:** Lift the former `instruqt-build/07-trust-but-verify/` into `instruqt-evaluate/07-trust-but-verify/` and rewire its guarded rollout to consume the brand-voice judge metric introduced in challenge 03, instead of creating a fresh `otto-response-judge` Config.

**Deliverables:**

- `instruqt-evaluate/07-trust-but-verify/assignment.md` — adapted from the current Build version. The flow is unchanged (configure guarded rollout in UI, watch it auto-rollback the Formal Nova Pro variation), but the "judge" the rollout consumes is the brand-voice judge already in the project — not freshly created in this challenge. The prose needs updating to call back to challenge 03 rather than introduce judging cold.
- `instruqt-evaluate/07-trust-but-verify/setup-workstation` — same idiom as the old one (apply Terraform, start background traffic). Adjust paths.
- `instruqt-evaluate/07-trust-but-verify/check-workstation` — adapted; the judge already exists by this point.
- `instruqt-evaluate/07-trust-but-verify/solve-workstation` — apply Terraform.
- `terraform/evaluate-07/main.tf` — creates the Nova Pro model_config (if not already there) + the Formal variation + the `otto-quality-score` (or whatever-it's-named) metric + wires the otto-assistant Config's `evaluationMetricKey` to the brand-voice judge's metric. Does NOT create a fresh judge Config — that one was created in challenge 03's Terraform.
- `terraform/evaluate-07/patch-server.py` — likely unchanged from the legacy version, or trivially adjusted.
- `traffic-generator/sabotage.py` and `traffic-generator/background_traffic.py` — likely unchanged; verify they reference the right metric key after the rewire.

**Cleanup work in Build:**

- `instruqt-build/07-trust-but-verify/` directory deletes once the Evaluate version is verified working.
- `terraform/challenge-07/` may stay in place if some of its files (`judge-server-paste.py`, `patch-server.py`) are referenced by Evaluate's challenge 07 — verify and consolidate.
- `instruqt-build/08-wrap-up/` and `instruqt-build/00-welcome/` need their prose adjusted — they reference Otto's "trust but verify" arc as part of Build, but Build now ends at the monitoring challenge. Update both to close Build's arc at monitoring and tee up Evaluate as the next track.

**Specific notes:**

- The rewire is the whole point of this phase — the eval narrative is now one continuous arc (write your own judge → use it to guard a rollout) instead of two parallel intros (introduce judging twice, once in 03 and once in 07).
- Keep the sabotage script as a presenter escape hatch.

**Verification steps:**

- Run setup → solve, confirm check passes.
- Confirm the guarded rollout fires when the Formal variation is served with organic traffic. Sabotage path still works.
- Confirm Build's updated welcome + wrap-up still lands cleanly (no orphan references to ch07).

**Operator verification:**

- Click-through against the rewired flow. Capture new screenshots (the old Build ch07 screenshots may be reusable for the rollout view but assignment-specific shots need re-takes).
- Confirm both Build and Evaluate read well end-to-end after the lift.

**Done-when:**

- Lift complete, Build directory cleaned up.
- Click-through verified for both rewired Evaluate ch07 and updated Build welcome/wrap-up.

---

## Phase 7: Adaptive switching (challenge 08)

**Goal:** Author challenge 08 — `otto-knows-when-to-fold`. Learner adds an application-side loop that watches a metric or local judge-score running average and flips Otto's targeting rule via REST when a threshold trips. The pattern sits between guarded rollout (release-time) and request-time fallback (Coordinate's self-healing) — important to teach the distinction.

**Deliverables:**

- `instruqt-evaluate/08-otto-knows-when-to-fold/assignment.md` — explains the pattern, then walks the learner through pasting a small adaptive-switching block into `server.py` and verifying it triggers in response to bad-scoring traffic.
- `instruqt-evaluate/08-otto-knows-when-to-fold/setup-workstation` — starts background bad-quality traffic to give the loop something to react to.
- `instruqt-evaluate/08-otto-knows-when-to-fold/check-workstation` — verifies the new code block is in `server.py` AND that Otto's targeting actually switched (the fallthrough variation changed during the lab).
- `instruqt-evaluate/08-otto-knows-when-to-fold/solve-workstation` — applies the Terraform + patches `server.py`.
- `terraform/evaluate-08/main.tf` — likely minimal; the targeting flip happens in app code, not Terraform. May only need to seed an alternate "safe-mode" variation if one isn't already present.
- `terraform/evaluate-08/adaptive-server-paste.py` — the adaptive-switching code block. Maintains a per-Config rolling window of recent judge scores; when the window's average crosses a threshold, calls the REST API to update the Config's fallthrough variation. Reverts after a cool-down. Bounded and conservative.
- `terraform/evaluate-08/patch-server.py` — inserts the adaptive block at a new marker (`# ─── Evaluate ch08 adaptive switching injects below this marker ──────`) added to `server.py` between the judge marker and the end of the `/chat` handler.

**Specific notes:**

- The lab's drama is watching the targeting flip live. The assignment should explicitly cue the learner to refresh the LD UI Targeting tab and observe the variation switch.
- Threshold and window size are operator-tuned in the Terraform default; the assignment may have the learner experiment with the threshold to see how sensitive the loop is.
- The reverting behavior matters — if the loop only flips one way, it's a one-shot trick. Two-way switching is the realistic pattern. Operator confirms during Phase 0 which the lab teaches.

**Verification steps:**

- Confirm the bad-traffic generator produces low-enough scores to trip the threshold within the challenge's time budget.
- Confirm targeting flip is observable via the REST API and reflected in the next eval.

**Operator verification:**

- Click-through. Capture screenshots of the moment the targeting changes.
- Confirm the experience is dramatic enough to land the "request-time self-healing is the next step beyond this" handoff to Coordinate.

**Done-when:**

- Lab verified end-to-end.
- The adaptive-vs-guarded-vs-self-healing distinction is articulable from the assignment prose alone — operator gut-check.

---

## Phase 8: Welcome + quiz + wrap-up (challenges 00, 05, 09)

**Goal:** Author the non-lab challenges. These come after the substantive content is in place so they can reference what the learner actually did.

**Deliverables:**

- `instruqt-evaluate/00-welcome/assignment.md` — orient the learner. Recap where Otto is at the start (post-Build state), preview the eval surface, set expectations. No task; click Check to begin. Mirror Build's welcome conventions.
- `instruqt-evaluate/05-quiz-judging-otto/assignment.md` — 1-3 questions covering challenges 01-04 (offline eval, built-in judges, custom judges). Mirror Build's quiz at ch04.
- `instruqt-evaluate/09-wrap-up/assignment.md` — close the eval arc. Reference the L1 brand-voice snippet's reuse in the brand-voice judge as the pedagogical highlight. 1-3 quiz questions covering ch06-08. Tee up Coordinate as "what if Otto needs to grow into a team?"

**Specific notes:**

- Voice and narrative consistency owned by `NARRATIVE.md`.
- Welcome must not spoil specific challenge mechanics.
- Wrap-up should explicitly contrast guarded rollout (release-time) with adaptive switching (request-time) so the learner internalizes the difference — this is the lesson's load-bearing distinction.

**Done-when:**

- Welcome sets the scene without spoiling.
- Quizzes are answerable from track content alone.
- Wrap-up closes Evaluate's arc and points forward to Coordinate.

---

## Phase 9: Polish

**Goal:** Final pass for consistency, voice, idempotency, and operator experience.

**Deliverables:**

- Pass through every `assignment.md` for narrative consistency against `NARRATIVE.md`.
- Pass through every `check-workstation` for `fail-message` quality — every reasonable wrong path produces specific guidance.
- Pass through every `solve-workstation` to confirm it leaves the workstation in the right state and is idempotent.
- Pass through every `setup-workstation` to confirm idempotency.
- Confirm the track-level `setup-workstation` end-to-end timing fits the lab budget (bootstrap delay timed; if too slow, escalate to operator before re-baking the image with pre-applied solves).
- Add or refine images in `instruqt-evaluate/assets/` referenced from `assignment.md` files.
- Final review of `track.yml` description and teaser.
- Update `DECISIONS.md` with any decisions made during implementation that weren't captured during scoping.

**Verification steps:**

- Full track run-through in both 2h presenter mode (with slides) and 1h self-paced mode.
- Time each challenge to confirm fit within budgets.
- Capture remaining screenshots.

**Done-when:**

- Operator runs both delivery modes end-to-end without intervention.
- All polish items checked.
- Track is ready for publishing via the Instruqt CLI.

---

## Open questions surfaced during scoping

These belong to Phase 0 but are worth listing up top:

1. **Marker comment rename.** The legacy marker in `server.py` is `# ─── Challenge 07 judge injects below this marker ──────`. After the lift it should be a generic marker that doesn't reference a specific challenge number across tracks. Proposed: `# ─── Judge integration injects below this marker ──────`. Operator confirms during Phase 4.
2. **Snippet as data, not just voice.** Challenge 04 puts the catalog inside a snippet to give the product-claim judge ground truth. If snippets are designed primarily for voice content and don't comfortably hold data, fall back to inlining the catalog in the judge variation's system message. Phase 0 confirms.
3. **Adaptive-switching trigger source.** Local per-process rolling window vs. polling LD's metric API. Lean local for simplicity. Phase 0 confirms feasibility of polling if the operator wants the more-realistic version.
4. **Metric key naming for the brand-voice judge.** Build's ch07 used `otto-quality-score`. Evaluate's brand-voice judge could reuse that name (lifts cleanly into ch07's rewire) or use a more-specific name like `otto-brand-voice-score`. Operator picks during Phase 4; ripples into Phase 6's rewire.
5. **Two judges sampling overlap.** Built-in (ch02) and custom (ch03+04) judges both sample Otto's responses. Does running both at once cause double-billing of judge inference, or do they share a sample? Phase 0 verifies. If they don't share, the lab may want to lower built-in sample rate when custom judges activate.
6. **Time budget for bootstrap.** Applying Build's six solves at the start of Evaluate could exceed acceptable startup time. If so, the alternative is pre-baking the post-Build state into a snapshot the VM image carries. Phase 1 measures and decides.

---

## Phase 0 verification notes

Recorded by Claude Code on 2026-05-28.

### Resolved

- **Snippet template syntax** — confirmed from the official LD docs at `https://launchdarkly.com/docs/home/agentcontrol/snippets`: the literal token is `{{snippet.<key>#<version>}}`. Version-pinning appears in the canonical example, so the syntax is version-aware. Whether omitting the version resolves to "latest" needs a small test in Phase 1.
  - **Side effect:** the legacy Build ch03 uses the placeholder `{{ldsnippet.<key>}}` (see `terraform/challenge-03/main.tf` and `instruqt-build/03-otto-on-brand/assignment.md`). The marker `# VERIFY: the exact snippet-reference syntax inside a variation message is not clearly documented as of authoring` is still in the file. Build is currently shipping with the wrong syntax. Fix needs to land in Build before or alongside Evaluate's authoring. Tracked separately.
  - Evaluate's brand-voice judge prompt references the existing `brand-voice` snippet via `{{snippet.brand-voice#1}}` (or whatever version Build's solve creates).

- **Built-in judges** — three judges ship: **Accuracy** (`$ld:ai:judge:accuracy`), **Relevance** (`$ld:ai:judge:relevance`), and **Toxicity** (`$ld:ai:judge:toxicity` with `isInverted: true`). The Evaluate scope mentioned only accuracy + relevance; toxicity is bonus material worth including in ch02. Judges can only attach to **completion-mode** Configs in the UI (Otto qualifies). Attachment is via REST PATCH on the variation: `judgeConfiguration: { judges: [{ judgeConfigKey, samplingRate }, ...] }`. The `judges` array **replaces** the existing set per call — multi-judge attachments are a single call, not incremental. The MCP `create-ai-config-variation` and `update-ai-config-variation` both accept `judgeConfiguration`.

- **Multi-custom-judge on one variation** — supported as long as the judges have **distinct `evaluationMetricKey` values**. 422 if two judges share a metric key. Challenge 03's brand-voice judge and challenge 04's product-claim judge use different metric keys, so they coexist fine.

- **Prompt experiment shape** — first-class on AgentControl Configs via the `create-experiment` MCP tool. The iteration's `treatments` reference `{flagKey, variationId}` pairs where `flagKey` is the Config key. Treatments must sum to 100% allocation; one must be `baseline: true`. Metrics array specifies the experiment outcome metric key. A `primarySingleMetricKey` or `primaryFunnelKey` picks the headline metric. `start-experiment-iteration` begins data collection.

- **Adaptive-switching REST surface** — `update-ai-config-targeting-rules` exposes semantic-patch instructions: `addRule`, `removeRule`, `addClauses`, `removeClauses`, `reorderRules`, `replaceRules`, `updateClause` (+ others). `update-ai-config-rollout` updates the fallthrough (percentage or single-variation). For ch08, leaning toward `update-ai-config-rollout` with `rolloutType: "variation"` to flip Otto's fallthrough to a safe-mode variation when the rolling-window threshold trips. Trigger source: in-process rolling window (simplest; avoids the polling round-trip).

- **Guarded rollout API** — `start-guarded-rollout` MCP tool exists (`testVariationId`, `controlVariationId`, `randomizationUnit`, `stages` with `rolloutWeight` in thousandths + `monitoringWindowMilliseconds`, `metrics` array with `regressionThreshold` + `onRegression: {notify, rollback}`). The DECISIONS.md entry "Guarded rollout configured by the learner, not pre-built" stated the API was not publicly documented at authoring time — that finding is **now obsolete**. The Evaluate ch07 can either pre-start the rollout via Terraform (cleaner setup but removes a UI-driven lab beat) or keep the original "learner clicks the button in the UI" approach (pedagogically richer; recommend keeping). Either way, the scripted-fallback path now exists.

- **`create_judge()` + `judge.evaluate()` provider plugins (the SDK auto-eval flow)** — confirmed obsolete pattern from the legacy `DECISIONS.md` entry "Judge invocation: SDK eval + manual Bedrock call." The auto-eval flow relies on a provider plugin system (langchain, openai); as of the current SDK version, **no Bedrock provider plugin exists**. The legacy Build ch07 sidesteps this by calling `ai_client.judge_config(...)` to fetch the judge's prompt/model and then invoking `bedrock.converse()` manually. Evaluate's custom judges (ch03 + ch04) follow the same manual pattern — clean for the workshop, no new credentials.

- **Custom judge invocation in the app process** — confirmed via the LD docs ("Online evaluations run using your configured model provider credentials") and the online-evals skill examples. The judge model runs in the app's process, billed against the app's credentials. For ToggleWear that means Bedrock — fine.

### Implications for the scope doc

- **Built-in judges (ch02)** — the implicit question of whether built-in judges trigger auto-eval (and therefore need a non-Bedrock provider) remains. If LD hosts the built-in judges server-side and they don't need an app-side provider, ch02 works as written. If they invoke a model in the app's process via auto-eval, ch02 needs either an OpenAI/Anthropic-direct credential added to the lab or a fallback to the manual flow. **Verify in Phase 1's smoke test** before committing to the ch02 design.
- **Custom judges (ch03 + ch04)** — confirmed to use the manual invocation pattern (`judge_config()` + `bedrock.converse()` + emit metric via `tracker.track_judge_result()` or raw `ld_client.track()`). Pattern reuses the legacy Build ch07 `judge-server-paste.py` mostly unchanged. No new credentials.
- **ch07 guarded rollout lift** — `start-guarded-rollout` MCP availability means we have a scripted fallback if the UI flow has issues during click-through. Keep the "learner starts it from the UI" approach as primary; the scripted path is a presenter escape hatch.

### Still pending

- **Dataset upload mechanics** (Task #3) — `create-dataset` returns a pre-signed upload URL according to the tool description; the upload mechanics (HTTP PUT? required headers? content-type per format?) aren't documented in the tool schema. Plan: invoke `create-dataset` against a sandbox project in Phase 1 to inspect the returned URL and probe the upload contract.
- **Built-in judge evaluation execution location** — does LD host built-in judge models, or do they run in the app process via the SDK provider plugin system? Affects whether ch02 needs a new credential. Defer to Phase 1 smoke test.
- **Operator-only UI verification items** — UI step counts and button labels for: dataset upload page, evaluation results panel, built-in judge attachment UI, experiment results panel, guarded rollout configuration UI. None of these block scoping; they're verified during each phase's click-through pass.

### Bonus surface improvements over the legacy DECISIONS.md notes

- The `DECISIONS.md` entry "Guarded rollout configured by the learner, not pre-built" is **partially obsolete** as of this Phase 0 — the API exists. Pedagogically the entry still stands (the lab is more useful when the learner configures the rollout themselves), but the operator escape-hatch is now scripted-clean rather than UI-only.
- The `DECISIONS.md` entry "AI Config snippet-reference syntax: deferred to operator verification" is **now resolved** — `{{snippet.<key>#<version>}}` is the literal token. The four files listed in that entry (`instruqt-build/03-otto-on-brand/assignment.md`, `instruqt-build/05-otto-for-everyone/assignment.md`, `terraform/challenge-03/main.tf`, `terraform/challenge-05/main.tf`) need updating to the real syntax. Surface this to the operator as a Build hotfix.
