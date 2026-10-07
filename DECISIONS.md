# DECISIONS.md

This file records every meaningful decision made during planning, with the reasoning behind it. When Claude Code (or any contributor) is tempted to reopen a decision, they should read the rationale here first.

Format: one decision per section, dated, with options considered and reason for the chosen path. Add new decisions to the bottom as they arise.

---

## Track scope and audience

**Decision:** Six substantive hands-on labs (plus welcome, two quizzes, wrap-up = nine challenges total) covering: Config creation, prompt iteration, prompt snippets, variations & targeting, monitoring, and guarded rollout.

**Audience:** Developers — both LaunchDarkly evaluators and existing LD customers expanding into AI use cases. Assumes LD fundamentals are known.

**Rationale:** This is a 100-level introduction to AgentControl. The six concepts above are the product's core surface area minus agents (deferred). Targeting developers rather than mixed audiences lets us assume technical literacy and skip foundational LD content.

**Options considered:**
- *Comprehensive intro covering everything including agents.* Rejected: too much for 2 hours; agent configs deserve their own 200-level track.
- *Narrow focus on a single concept (e.g. "swap models without redeploying").* Rejected: doesn't give a complete enough picture for evaluators to understand the product.

---

## Track length and cadence

**Decision:** 2-hour presenter-led format with slide-based lecture interleaved between labs; same content runs ~1 hour self-paced. 6 labs + 2 quizzes + welcome + wrap-up = 9 total Instruqt challenges.

**Rationale:** Matches the reference track's pattern and the requested delivery profile. Quizzes serve as natural break points for presenters and as mental consolidation for self-paced learners.

---

## App architecture: single Python process serving frontend + API

**Decision:** One FastAPI process serves both the HTML/JS frontend (as static files) and the `/chat` API endpoint on port 3000. Config evaluation and Bedrock calls happen server-side in Python; the JS frontend only handles UI.

**Rationale:**
- The reference track's app is a single process on port 3000; matching this means learners' muscle memory carries over.
- Config evaluation belongs server-side regardless — prompts and SDK keys shouldn't be in the browser.
- Single repo, single language to edit per challenge (server-side Python for AgentControl concepts; the JS exists but learners barely touch it).
- One process = simpler VM image, fewer ports, fewer ways to break.

**Options considered:**
- *Separate Python API + static JS frontend on different ports.* Rejected: more moving parts for no learning gain.
- *Node/Next.js stack matching the reference track exactly.* Rejected: the operator chose Python for server-side, and that's the more idiomatic stack for AgentControl SDK usage anyway.

---

## Tech stack: Python (FastAPI) + vanilla JavaScript

**Decision:** Server is FastAPI. Client is vanilla JS — no framework, no build step.

**Rationale:** The operator specified Python and "plain JavaScript" for simplicity, given learners will copy/paste code in some challenges. Vanilla JS is easier to read and modify in a code editor without tooling. FastAPI was chosen over Flask because of native async support (Bedrock calls benefit) and cleaner type-hint ergonomics.

---

## LLM provider: AWS Bedrock

**Decision:** AWS Bedrock is the sole LLM provider. Models used: Claude Haiku (default Otto), Claude Sonnet (premium Otto), Amazon Nova Pro (cross-vendor variation in the guarded-rollout challenge).

**Rationale:**
- Single AWS account with IAM-controlled access means easier credential management for Instruqt's secrets system.
- Bedrock's catalog lets us tell the "swap models without redeploying" story credibly with three distinct options.
- Mixing Anthropic Claude (Haiku, Sonnet) with Amazon Nova in challenge 7 gives the cross-family demo real teeth — the judge catches a regression from a genuinely different model family, not just a different size.

**Options considered:**
- *Direct Anthropic API.* Rejected: only one model family available, weaker variation story.
- *Cross-family from the start (e.g. Haiku vs Nova in challenge 5).* Rejected: in challenge 5 we want to show "premium variation with better model"; same-family-different-size (Haiku → Sonnet) tells that story more clearly. Save the family swap for challenge 7 where it serves the judge/guarded-rollout narrative.

---

## Retail-shop fiction: ToggleWear, single page, no commerce

**Decision:** The site is "ToggleWear," a fictional retailer selling LaunchDarkly-branded apparel. Single page: header (logo + user-tier dropdown), product grid of 6-8 items, Otto the shopping-assistant chat widget. No cart, checkout, auth, or commerce.

**Rationale:**
- A retail shop is instantly legible — every learner understands the use cases (recommendations, support, brand voice).
- LaunchDarkly-branded apparel keeps the demo "in-family" — the brand reference is amusing without being distracting.
- Single page minimizes UI surface area; the app exists to host Otto, not to be a real store.
- No commerce functionality avoids scope creep into payment forms, user accounts, etc.
- ToggleWear is deliberately *not* a fork of the legacy Toggle Outfitters app — fresh codebase, no library-rot inheritance.

---

## Otto: a shopping assistant chatbot

**Decision:** The AI surface is a chat widget named "Otto" embedded on the ToggleWear page. Otto can answer questions about products, ToggleWear policies, sizing, etc.

**Rationale:** Naming the AI gives the narrative a character. Each lab is a beat in Otto's development — born, given voice, branded, personalized, measured, governed. This carries the learner through the track with a story rather than a checklist.

---

## User-tier dropdown in the header

**Decision:** A header dropdown ("Logged in as: Free user / Premium user") that updates the LD context client-side and triggers re-evaluation server-side.

**Rationale:**
- Targeting in challenge 5 needs a way for the learner to flip user contexts.
- A dropdown looks polished on a presenter's screen and tells the targeting story visibly.
- Hardcoded URL params would work but feel hacky for a demo meant to impress.

**Options considered:**
- *Query parameter (`?user=premium`).* Rejected as too unpolished for presenter demos.
- *A full mock login flow.* Rejected: adds scope for no learning value.

---

## Cost protection: configurable turn cap per session

**Decision:** Python server enforces a turn cap per chat session, configurable via env var. Default to a value generous enough to complete the track comfortably. When exceeded, Otto returns a graceful "demo limit reached" message instead of calling Bedrock.

**Rationale:** Bedrock costs scale linearly with usage; an unattended Instruqt track being run by many learners in parallel could rack up bills via runaway loops, accidental retries, or curious learners spamming the chat. Per-session cap with env-var control gives operators a knob without redeployment.

**Open knob:** The specific default value should be set during implementation based on a realistic walkthrough of the track. Err high initially; tune down with real data.

---

## Cost protection at the model level

**Decision:** Use the cheapest viable model (Haiku) as the default; reserve Sonnet for premium-tier targeting; Nova Pro appears only in challenge 7's pre-built scenario. Traffic generator (challenge 6) sends short messages to keep token counts low.

**Rationale:** Stacking architectural choices for cost control: cheap default model + tight turn cap + short generated traffic. Cumulative protection against bill surprises.

---

## Challenge 7: judge + guarded rollout, all pre-built

**Decision:** Challenge 7's setup script creates *everything*: the Nova Pro variation with a deliberately-poor prompt, a second Config that acts as a "judge" scoring responses for brand-voice adherence, a metric wired to the judge's output, and the guarded rollout configuration. The learner observes the rollout proceed and watches the auto-rollback fire. A sabotage script is included for presenters to trigger the rollback dramatically on demand.

**Rationale:**
- Teaching the judge pattern from scratch would consume the entire 2-hour budget on its own. Pre-building keeps the learner focused on the *outcome* (guarded rollouts protect AI quality) not the mechanics.
- The bad prompt regression is *organic* — the judge legitimately catches a quality problem, not a contrived flag flip. This makes the demo feel real.
- A sabotage trigger lets presenters force the rollback within a class timeframe instead of waiting for organic traffic to accumulate.

**Options considered:**
- *Learner builds the judge.* Rejected: too much for one lab.
- *Skip guarded rollouts entirely, end on monitoring.* Rejected: guarded rollouts are the strongest "wow" moment for AI use cases specifically, and they're the natural narrative ending — "now you can trust the system to protect itself."
- *Simulate the regression rather than serve a real bad prompt.* Rejected: serving real bad responses through the live model is more impressive and only marginally more complex to set up.

---

## Challenge 6: traffic generator runs automatically in setup

**Decision:** Challenge 6's `setup-workstation` runs the traffic generator script automatically. The learner arrives at a populated monitoring view, no manual step required.

**Rationale:** The lesson is "use monitoring to understand AI behavior," not "run a script." Surfacing populated data immediately lets the learner spend their lab time on observation and interpretation.

---

## Lecture content: out of scope for the track

**Decision:** The track contains no lecture content. Presenters deliver conceptual framing via slides between labs. The `notes` field in each challenge's front-matter contains only a one-paragraph orientation, mirroring the reference track.

**Rationale:** The operator delivers the lecture content via PowerPoint. Embedding lectures in the track would duplicate effort, force the self-paced flow to read material a presenter would deliver verbally, and make the track harder to update.

---

## Lecture-lab split delivers the same content at 2hr or 1hr

**Decision:** Labs stand alone — they're written so a self-paced learner can complete them without the lecture preamble. The 2hr format adds slide-based lecture between labs; the 1hr format skips lecture and runs labs back-to-back.

**Rationale:** Two delivery modes, one source of truth. The constraint this places on labs: `assignment.md` prose must carry enough conceptual context that an unsupervised learner can follow it without a presenter setting up each lab.

---

## File pairing convention: `.remote` files are not authored

**Decision:** Claude Code creates only the non-`.remote` versions of each file. The Instruqt CLI generates `.remote` mirrors on publish.

**Rationale:** Extracted from inspection of the reference track — all `.remote` files were byte-identical to their counterparts, indicating CLI-generated mirrors. Authoring both creates merge conflicts on publish.

---

## VM image inputs in repo, image build done by humans

**Decision:** Claude Code produces the *inputs* for VM image building (app source, Dockerfile or Packer config, install scripts, systemd unit files) in `vm-image/`. The actual image build is performed by a human operator and registered with Instruqt.

**Rationale:** Image builds require AWS/GCP credentials and Instruqt registry access that Claude Code doesn't have. Separating "what goes in the image" (Claude Code's job) from "build and register the image" (human's job) makes the handoff explicit.

---

## Terraform provider vs. REST API for Config resources

**Decision:** Prefer the `launchdarkly/launchdarkly` Terraform provider for Config resources where supported. Where the provider lacks Config support, fall back to REST API calls via `null_resource` + `local-exec curl`.

**Rationale:** AgentControl is a relatively new product. The Terraform provider may not yet cover every resource type. Provider-native is preferred (cleaner code, drift detection), but the REST fallback is unblocked while waiting for provider updates.

**Verification step:** During Phase 1, check the current Terraform provider documentation for Config resource support and record findings in `PHASES.md` Phase 1 notes.

---

## SDK version pinning

**Decision:** Pin specific versions of `launchdarkly-server-sdk`, `launchdarkly-server-sdk-ai` (`ldai`), `boto3`, `fastapi`, and `uvicorn` in `requirements.txt`. Verify latest stable versions at implementation time via web search; do not guess from training data.

**Rationale:** AgentControl SDK is evolving rapidly. Unpinned versions cause non-reproducible failures when learners run the track months after authoring.

---

## Narrative consistency owned by NARRATIVE.md

**Decision:** A separate `NARRATIVE.md` file holds Otto's story arc, voice guide, ToggleWear brand details, and product list. All `assignment.md` files should be consistent with it.

**Rationale:** Across 9 challenges authored over multiple sessions, voice drift is a real risk. A single source of truth for narrative concerns prevents it.

---

## Phase-by-phase build with operator review gates

**Decision:** Claude Code works one phase at a time per `PHASES.md`. After each phase, work pauses for operator review before the next phase begins.

**Rationale:** Catching architecture or convention drift early is much cheaper than catching it after 9 challenges are written. Phase gates also let the operator validate against real Instruqt deployment between phases if desired.

---

## UI instructions in assignment.md: drafts subject to operator verification

**Decision:** Claude Code drafts click-by-click LaunchDarkly UI instructions in `assignment.md` files based on reading the public AgentControl docs. The operator then walks through each flow with the draft open, corrects UI specifics (button labels, menu paths, step ordering), captures screenshots, and removes `<!-- VERIFY: ... -->` markers. Phase done-when conditions require this operator verification pass before sign-off.

**Rationale:** Claude Code cannot drive a browser in this environment — it can't click through the LaunchDarkly UI to verify flows itself. Options considered:

- *Operator screen-records each flow first, Claude Code transcribes.* Higher first-draft accuracy, but expensive operator time upfront and dependent on flow being known before authoring.
- *Operator gives Claude Code an LD account.* Doesn't help in this environment — Claude Code still can't drive a browser from a chat session. Would only help with a separate browser-agent product (e.g. Claude in Chrome), which is a workflow change.
- *Claude Code hedges in prose ("navigate to roughly the configs area").* Rejected — produces unusable instructions. Learners need specifics.
- *Hybrid: confident drafts from docs + operator click-through pass.* Chosen. Lowest total operator time, highest first-draft quality given the tooling constraint.

This decision is enforced in `CLAUDE.md` ("UI instructions in assignment.md are drafts pending operator verification") and in every UI-touching phase's done-when in `PHASES.md`.

---

## LD model name → Bedrock model ID lives in the app, not the Config

**Decision:** LaunchDarkly's model config registry stores vendor-neutral model names like `claude-haiku-4-5`, `nova-pro`. The app's `server.py` maintains a `BEDROCK_MODEL_IDS` dict that maps each to the corresponding Bedrock model or inference-profile ID (e.g. `us.anthropic.claude-haiku-4-5-20251001-v1:0`). Adding a new model means a row in that dict — no Config changes needed.

**Rationale:** Discovered the hard way during Phase 3: the `modelName` passed when creating a variation is a hint, but what `cfg.model.name` returns from the SDK is the model config's vendor-neutral `modelId`. Bedrock needs the full model/profile ID. The cleanest place for that translation is the boundary where we leave LD-land and enter AWS-land — in the app's Bedrock client wrapper.

**Side benefit:** The LD Config stays vendor-agnostic. If we ever swap Bedrock for OpenAI direct, only `BEDROCK_MODEL_IDS` (or its OpenAI equivalent) changes — the Configs and variations don't.

---

## Per-challenge Terraform modules are independent and hybrid

**Decision:** Each challenge has its own `terraform/challenge-NN/` module with its own state. Modules use:

- `launchdarkly_*` resources for NEW resources introduced by that challenge (e.g. challenge-01 creates the Haiku model_config, the Config, and the first variation; challenge-05 creates the Sonnet variation; challenge-07 creates Nova Pro model_config, the Formal variation, the judge config, and the metric).
- `null_resource` + `local-exec curl` for: updates to resources owned by earlier challenges' modules (which Terraform can't touch from a different module without `terraform import`), and for resources the provider doesn't yet expose (snippets, Config targeting rules, guarded rollouts, Config `evaluationMetricKey`).

**Rationale:** Each challenge's solve must produce the END STATE of that challenge regardless of whether prior challenges were completed in code or skipped. Terraform's per-module state model doesn't share resources across modules, so updates to "already-managed" resources need to go through either `terraform import` (operationally heavy) or REST API (lightweight). REST via `null_resource` won.

**Side effect:** Some idempotency is on us — for example, challenge-03's snippet POST has `|| echo "(may already exist)"` because the second apply would 409. Worth the trade-off for state simplicity.

---

## server.py BEFORE state + marker-based paste pattern

**Decision:** `server.py` ships from the VM image in a BEFORE state: imports/init/helpers/turn-cap pre-wired, but `/chat`'s body is a clearly-marked stub block returning a canned "not wired yet" response. Challenge 01 has the learner replace the stub with ~30 lines of Config + Bedrock eval logic. The solve script applies the same paste programmatically using a Python script that finds the markers and substitutes the block.

A second marker (`# ─── Challenge 07 judge injects below this marker ──────`) sits at the bottom of the post-Challenge-01 code. Challenge 07's setup script finds it and injects the judge integration block.

**Rationale:** Two-step staged code injection keeps each challenge's setup self-contained while making it possible for later challenges to extend the same file. Pure Python `find/replace` on stable comment markers is more robust than line-number-based patching and survives the learner doing the paste manually vs. via solve.

**Trade-off:** The marker comments persist in the final server.py code. Acceptable — they're inert single-line comments with clear purpose.

---

## Config snippet-reference syntax — RESOLVED 2026-05-28

**Original decision (2026-04):** Phase 4 / Challenge 03 introduced prompt snippets via REST (the Terraform provider doesn't expose them yet). The reference syntax for embedding a snippet in a variation message wasn't documented anywhere findable at authoring time. The placeholder `{{ldsnippet.<key>}}` was used throughout, with `<!-- VERIFY -->` markers in the assignment and Terraform calling it out.

**Resolution (2026-05-28, Phase 0 of Track 2 / Evaluate scoping):** Confirmed via the official LD docs at `https://launchdarkly.com/docs/home/agentcontrol/snippets`. The literal syntax is:

```
{{snippet.<key>#<version>}}
```

Version-pinned. Whether omitting the version resolves to "latest" is not documented in the canonical example; the safe convention is to pin (the example uses `#version-number` explicitly). For Build, the snippets are created at version 1 by `terraform/challenge-03/main.tf`'s REST POST, so all references pin to `#1`.

**Hotfix applied:** Replaced placeholders in `terraform/challenge-03/main.tf`, `terraform/challenge-05/main.tf`, and `instruqt-build/03-otto-on-brand/assignment.md` (challenge 05's assignment.md doesn't quote the literal markup — the learner gets it inserted via the UI's **Load snippet** button). VERIFY comments in the two .tf files removed.

**Side benefit:** Evaluate's brand-voice judge prompt now has a clean reference convention (`{{snippet.brand-voice#1}}`) baked into the scope before authoring starts.

---

## Guarded rollout configured by the learner, not pre-built

**Decision:** Phase 7's setup pre-builds everything *except* the guarded rollout itself: the Nova Pro Formal variation, the judge Config + metric, the server-side judge integration, and a low-rate background traffic generator. The learner configures the guarded rollout in the LD UI as the lab's actionable centerpiece.

**Rationale:** Two reasons. First, LaunchDarkly's REST API for starting a guarded rollout was not publicly documented at authoring time. Second, configuring the rollout in the UI *is* the most important learning moment of the track — making the learner do it themselves reinforces the workshop's main lesson.

**Update (2026-05-29, Phase 0 of Track 2 / Evaluate):** The REST surface IS now documented — `start-guarded-rollout` is a published LD MCP tool with `testVariationId`, `controlVariationId`, `stages` (rolloutWeight + monitoringWindowMilliseconds), and `metrics` (with `regressionThreshold` and `onRegression: {notify, rollback}`). The first part of the rationale is obsolete. The second part — keeping the rollout learner-driven for pedagogical reasons — still stands. Evaluate's ch07 (which lifts this challenge from Build) continues to have the learner start the rollout in the UI; the API existence just gives presenters a scripted fallback rather than forcing a UI-only path.

**Side script:** `traffic-generator/sabotage.py` exists as a presenter escape hatch — emits low judge scores directly via `ld_client.track()` to force a regression detection when organic background traffic is too slow.

**Side benefit:** Makes the lab demonstrably "real" — the learner can see the rollback fire from their own configuration, not from a pre-built one that magically works.

---

## Judge invocation: SDK eval + manual Bedrock call

**Decision:** The judge integration in `server.py` (added by Challenge 07's setup patch) calls `ai_client.judge_config(...)` to evaluate the `otto-response-judge` Config (which interpolates the `{{response}}` template variable with Otto's answer), then calls `bedrock.converse()` manually with the resulting model and messages. The 1-5 score is parsed from the response text and emitted via raw `ld_client.track("otto-quality-score", ...)` rather than `tracker.track_judge_result(...)`.

**Rationale:** The `ldai` SDK supports a higher-level judge flow via `create_judge()` + `judge.evaluate()`, but it relies on an AI Provider plugin system (langchain, openai). There's no `ldai_bedrock` provider as of authoring. Writing a custom provider was scoped out. Manual Bedrock invocation works fine and stays transparent to the workshop's audience — the code reads exactly like the regular Otto eval.

---

## Traffic generator skips Bedrock entirely

**Decision:** `traffic-generator/generate_traffic.py` and `background_traffic.py` evaluate the Config to get a real tracker, then emit synthetic `track_duration`, `track_tokens`, `track_success`, and `track_feedback` events with values weighted per model. They do NOT call Bedrock.

**Rationale:** Real Bedrock calls would make 120 sessions take ~10 minutes and cost real money per learner. The monitoring view only consumes the LD-side metric events, so skipping Bedrock costs nothing in terms of what the lab shows. Weights are tuned so Sonnet looks visibly better than Haiku in the dashboard, and Nova Pro Formal looks worse — the comparison is what matters, not the absolute numbers.

**Side benefit:** Same generator works as a sabotage tool — see `sabotage.py`, which is just the metric-emission path without the eval boilerplate.

---

## Workshop splits into three sibling Instruqt tracks (2026-05-28)

**Decision:** What was originally one 9-challenge Instruqt track becomes **three sibling tracks** that each map 1:1 to a lesson in the AgentControl cert:

- **Build (L1)** — `instruqt-build/`. The original track, near-final. Otto's lifecycle from first Config to monitoring.
- **Evaluate (L2)** — `instruqt-evaluate/`. Golden datasets, built-in judges, custom judges, prompt experiments, guarded rollout (the former `07-trust-but-verify` lifts here and rewires to consume the brand-voice judge introduced earlier in L2), adaptive switching.
- **Coordinate (L3)** — `instruqt-coordinate/`. Multi-agent **Concierge** team (Toggle → Curator | Tailor | Tracker → Otto → customer). Otto's character survives as the brand-voice rewriter. Agent-mode Configs, agent graphs, SDK traversal with `reverse_traverse` + `graph_key`, per-agent guarded rollout, self-healing.

All three tracks live in this repo and share a **single VM image**. Each track's track-level `setup-workstation` runs prior-track solve scripts to materialize the starting state, so a learner can land in any track and arrive at a known good baseline.

**Rationale:**

- One mega-track at 22 challenges would be ~6h self-paced and far past the 2h presenter budget that the original track was designed for. Three ~2h tracks let learners pick a level and finish it in one sitting, and they map cleanly to the cert lessons.
- The cert (Lessons 1-3) was being rewritten to mirror this content 1:1; explicit per-track artifacts give the cert team something concrete to reference per lesson rather than asking them to slice across one big track.
- The existing Build track stays self-contained for evaluators who only want the basics — no scope-creep from adding eval/multi-agent content in front of them.

**Trade-offs accepted:**

- A learner starting Evaluate or Coordinate cold pays a small startup delay while prior-track solves materialize their workspace. Acceptable for the simplicity of one image.
- The `terraform/challenge-NN/` directory naming is Build-centric; Evaluate and Coordinate will get sibling directory conventions (e.g. `terraform/evaluate-NN/`, `terraform/coordinate-NN/`) when authored. The original `terraform/challenge-NN/` won't be renamed — it stays as Build's record.

**Concierge cast naming:**

The L3 cast is a deliberate naming pattern: customer-facing agents get personal names (**Toggle** the triage receptionist, **Otto** the brand-voice rewriter), back-of-house specialists get functional role names (**Curator**, **Tailor**, **Tracker**). Mirrors how a real concierge team feels and makes the graph topology readable from the names alone. Otto's character is preserved by giving him a role inside the team rather than retiring him or creating a parallel "Concierge Otto."

**Why not refactor Otto into agent mode in L3 instead:**

AgentControl Configs are mode-permanent — once created in `completion` mode, a Config can't be converted to `agent` mode. Option A (deprecate Otto, replace with an agent-mode version) was rejected because:
1. It breaks Build/L1's "Otto is grown" wrap-up arc retroactively.
2. It tries to evade the mode-permanence rule rather than teach it.
3. The Concierge-team framing turns mode-permanence into a teachable moment (here's why we built a new system instead of upgrading Otto's Config in place).

---

## Custom judges score 0.0–1.0, not 1–5 (2026-06-01)

**Decision:** Every custom judge in Evaluate scores responses on a 0.0–1.0 scale. The score parsing in each judge's server.py paste reads `float(text.split()[0])` with a try/except fallback. The legacy Build ch07 used a 1–5 integer scale; that was changed when ch07 lifted into Evaluate.

**Rationale:**
- LD's built-in judges (Accuracy, Relevance, Toxicity) score 0.0–1.0. Mixing 1–5 custom judges with 0.0–1.0 built-ins in the same monitoring view was inconsistent.
- Float scoring gives the LLM judge more resolution to express degrees of correctness ("borderline" = 0.5) without retraining learners on what a "3" means versus a "4".
- The threshold values for guarded rollouts and adaptive switching are simpler in 0.0–1.0 ("watch for the mean dropping below 0.5") than they would be in 1–5 ("below 3.0").

**Side effect:** The legacy `traffic-generator/background_traffic.py` and `sabotage.py` were updated during Phase 6 of `PHASES-evaluate.md` to emit floats instead of ints, and to use the new `otto-brand-voice-score` metric key instead of the legacy `otto-quality-score`.

---

## Snippet-as-data: snippets hold structured content, not just voice (2026-06-01)

**Decision:** Evaluate Challenge 04 puts the ToggleWear product catalog inside a `product-catalog` snippet. The claim-accuracy judge's prompt references it via `{{snippet.product-catalog#1}}` so the same catalog text drives the judge's ground truth. Adding or changing a product means editing one snippet.

**Rationale:**
- The LD snippets docs frame snippets as "tone, formatting, or governance language" — voice-flavored. Using a snippet for *data* (a structured product list) is a stretch of the apparent design intent but works in practice; the snippet is just text inserted into a prompt at evaluation time.
- The "one source of truth for the catalog" property is valuable beyond the lab: in production, adding a product becomes a single-snippet edit rather than coordinated changes across multiple prompt variations and grading configs.
- This pattern composes with the brand-voice snippet's reuse in ch03 — both demonstrate that a snippet drives both "what Otto says" *and* "what we measure" if you reference it from both sides.

**Trade-offs accepted:**
- Catalog content lives in two places — the snippet (for the judge's ground truth) and the app's `static/index.html` (for the actual storefront display). They could drift. For the workshop's ~30-row catalog this is acceptable; a production app would derive both from a single source.

---

## Three safety nets, three timescales (2026-06-01)

**Decision:** Evaluate teaches three distinct AI-safety mechanisms across challenges 06–08, framed by the timescale at which they react:

| Timescale | Mechanism | Challenge |
|---|---|---|
| Release time | Guarded rollout (LD watches a metric while ramping; rolls back on regression) | ch07 |
| Request time (between requests) | In-app adaptive loop (rolling window + REST PATCH on the targeting rule) | ch08 |
| Per request (synchronous) | Self-healing judge-then-regenerate | Coordinate / Track 3 |

**Rationale:**
- These three mechanisms are easy to conflate. Naming the timescale makes the distinction concrete. The wrap-up quiz tests the release-vs-between-requests boundary directly.
- The adaptive-switching pattern in ch08 isn't a packaged LD feature — it's an application-level loop the operator wires using documented SDK + REST primitives. Teaching it explicitly closes a real gap: learners often try to use guarded rollouts as request-time controllers, which doesn't work.
- Self-healing belongs in Coordinate (L3) because the per-request fallback shape requires the judge to be invoked synchronously inside the request handler — natural fit with the agent-graph rewriter node where a brand-voice check before sending the response is the obvious wiring.

**Trade-offs accepted:**
- The lab introduces three distinct in-app generators (`realchat_traffic.py`, `experiment_traffic.py`, `background_traffic.py`) to drive each mechanism's lab — each setup-workstation swaps to the right one for the challenge. Slight operational complexity in exchange for each lab having appropriate signal characteristics.

---

## Evaluate uses LaunchDarkly's undocumented `/internal` REST surface for datasets, playgrounds, and runs (2026-10-06)

**Decision:** Evaluate ch01's setup/check/solve scripts and `terraform/evaluate-01` call `https://app.launchdarkly.com/internal/projects/{key}/{datasets,evaluations,playgrounds}` directly. The request/response shapes are captured from the LD web app's own traffic and recorded in `instruqt-evaluate/INTERNAL-API.md`.

**Rationale:**
- Offline evaluation (datasets, playgrounds, evaluation runs) has no `/api/v2` surface and no Terraform resources as of 2026-10-06. The UI is the only documented path.
- The internal endpoints accept the same `Authorization: <api token>` + `LD-API-Version: beta` headers as `/api/v2`, so operator-context scripts can drive them without a browser session.
- The alternative (make ch01 UI-only with no Skip and a weak Check) violates the definition of done for solve/check parity.

**Trade-offs accepted:**
- No stability guarantee. If LD changes the shapes, ch01's check/solve break silently. Mitigation: `INTERNAL-API.md` documents exactly what was captured and how, so re-capturing is a 15-minute job with the browser's network panel (or Claude Code driving Chrome via the DevTools MCP plugin, which is how this capture was done).
- The "evaluation" noun in the internal API means one playground *column*, not the whole exercise. Scripts and comments use the UI's object model (dataset → evaluation/column → playground → run) to avoid confusion.
- The completed-run `state` string was not observed (see below), so `check-workstation` tests for graded rows via the `/summary` endpoint instead of matching an enum.

**Operator-side dependency surfaced by this work:** playground runs execute on LD's backend using the **account-level** "Manage API keys" BYOK integration (`aiconfig-test-run`). For Bedrock this is an IAM role LD assumes with an external ID, configured once per LD account. The Instruqt account the IdP simulator logs learners into must have a working Bedrock configuration or every ch01 run ends in `PERMANENT_ERROR: Bedrock request failed: AccessDenied (HTTP 403)`. Added to `OPERATOR-CHECKLIST-evaluate.md`.

---

## Custom judge keys are set explicitly via "Edit config key" (2026-10-06)

**Decision:** Evaluate ch03 and ch04 have the learner click **Edit config key** in the Create config dialog and type `otto-brand-voice-judge` / `otto-claim-accuracy-judge` before **Generate judge**. The server pastes, check scripts, and Terraform all key off those literal keys again.

**Rationale:** The judge generator otherwise derives the key from an AI-generated name, which made the keys non-deterministic and forced the check scripts to be disabled. The dialog exposes the key field (verified in the live UI), so determinism costs one click.

**Side effects:** Generated judges arrive with an AI name, a Sonnet 4.5 Default variation carrying `{{message_history}}` / `{{response_to_evaluate}}` helper messages, and a possibly inverted desired direction. The assignments now walk the learner through replacing the model and prompt, deleting the helper messages, renaming, and setting **Higher is better**. We keep `{{response}}` as the template variable because the server pastes supply it; the LD-native `{{response_to_evaluate}}` convention is noted in `INTERNAL-API.md` for a future revision.

---

## Custom metrics are pre-created by challenge setup, not by the learner (2026-10-06)

**Decision:** ch03 and ch04 `setup-workstation` apply `terraform apply -target=launchdarkly_metric.<name>` so `otto-brand-voice-score` and `otto-claim-accuracy-score` exist before the learner starts. The assignments mention the metric exists; they do not add a "create a metric" section.

**Rationale:** No revision of the ch03/ch04 UI flow ever created these metrics (the old "Evaluation metric" step set the judge's event key, which is a different thing), yet the server pastes emit to them and ch06's experiment and ch07's guarded rollout select them by name. Pre-creating keeps the judge labs focused on judges. Operator may still choose to teach metric creation; see the checklist.

---

## Evaluate solve scripts drive experiments and guarded rollouts through the public API (2026-10-06)

**Decision:** `terraform/evaluate-06/setup-experiment.py` creates the experiment with `maintainerId`, `ruleId: "fallthrough"`, and the targeting environment `_version`, then starts it with the `startIteration` semantic patch. `instruqt-evaluate/07-trust-but-verify/solve-workstation` starts a real guarded rollout with the `startAutomatedRelease` instruction on the ai-config targeting endpoint (stages 10/25/50% at one minute each, auto-rollback on `otto-brand-voice-score`). Both payloads were captured from the UI and replayed with the operator token.

**Rationale:** The previous solve for ch07 fell back to a plain percentage rollout, which the rewritten check correctly rejects as "not guarded". Skip must land in the same state as a successful learner.

**Trade-offs accepted:** `startAutomatedRelease` is a public endpoint but the guarded-release history used by the check lives on an internal endpoint; the check only needs it when the rollout has already finished or rolled back.

## The track-level setup syncs the VM's repo clone to `main` on every lab start (2026-10-06)

**Decision:** `instruqt-evaluate/track_scripts/setup-workstation` now runs `git fetch --depth 1 origin main && git reset --hard FETCH_HEAD` on `/opt/ld/ai-configs-intro` before applying any Terraform or server patches. If the fetch fails the lab continues with the baked copy.

**Why:** the VM image bakes a shallow clone and nothing pulled it afterwards. The first live run (2026-10-06) ran today's assignments against a clone from Sep 16 (a26c6ea), so every Terraform/paste fix pushed since was invisible until an image re-bake. Re-baking for each script change is slow and easy to forget; a sync at lab start makes pushes take effect on the next launch.

**Consequences:** the lab tracks `main` live, so a broken push breaks the next lab start (keep `main` releasable, or pin `REPO_REF` to a tag when the workshop is being delivered). Only tracked files change: `app/.env` is gitignored and the Challenge-01 `server.py` patch is re-applied after the sync. Challenge setup/check/solve scripts are not affected by this at all; they come from `instruqt track push`. The Build track does not have the sync yet.

## ch01 playground columns run on the Anthropic provider, not Bedrock (2026-10-07)

**Decision:** in Evaluate ch01 the learner switches both playground columns from the Bedrock model that **Load config** copies in to the same model on the **Anthropic** provider (`claude-haiku-4-5-20251001`, `claude-sonnet-4-6`). The ch01 solve (`terraform/evaluate-01/main.tf`) creates its columns with `Anthropic.*` model config keys and `generationProvider: "Anthropic"`.

**Why:** playground runs execute on LaunchDarkly's backend through the account-level Manage API keys integration. The operator confirmed on 2026-10-07 that the Bedrock entry in the Hands-on Workshops account is broken on LaunchDarkly's side; every run ended `PERMANENT_ERROR: Bedrock request failed: AccessDenied`. The Anthropic key in the same account works and already grades the acceptance criteria.

**Consequences:** the model the learner evaluates is the same Claude model Otto runs on, reached through a different API key; the assignment says so in one sentence. Otto's production variations stay on Bedrock. Revert the assignment steps and the two Terraform locals when LaunchDarkly fixes the Bedrock connection.

## Coordinate's dispatch follows edges explicitly instead of using `reverse_traverse` (2026-10-07)

**Decision:** `terraform/coordinate-07/concierge-server-paste.py` evaluates the graph with `ai_client.agent_graph("concierge", context)`, calls the root node, picks the outgoing edge whose `handoff["route"]` matches Toggle's one-word answer, calls that specialist, then follows its single edge to the rewriter. It does not use `traverse`/`reverse_traverse`.

**Why:** both exist in the SDK (0.20.1), but they visit *every* reachable node in depth order. The Concierge visits one specialist per request, chosen at runtime from Toggle's answer, which is exactly the "application controls traversal; handoff data is interpreted by your application logic" model the docs describe. Explicit edge-following shows the learner the wiring (`root()`, `get_edges()`, `handoff`, `get_node()`) with nothing hidden. The scope doc's preference for `reverse_traverse` predates the live spike.

**Consequences:** the assignment names `traverse`/`reverse_traverse` and the framework runners as the production alternatives. Node trackers come from `node.get_config().create_tracker()`, which the SDK tags with `graphKey` automatically because the graph evaluated the node Configs; the graph tracker records one success/failure per request.

## Agent Configs are created with the Terraform provider; the graph with REST (2026-10-07)

**Decision:** `terraform/coordinate-01..05` use `launchdarkly_ai_config` (`mode = "agent"`) and `launchdarkly_ai_config_variation` with `description` + `instructions`, plus the usual `null_resource` fallthrough PATCH. `terraform/coordinate-06` creates the graph through `POST /api/v2/projects/{proj}/agent-graphs` (body in `graph.json`) because provider ~> 2.29 has no agent-graph resource. Create-only: if the graph exists, the solve leaves the learner's version alone and the check validates topology.

**Why:** verified live in the sandbox on 2026-10-07: the provider accepts agent mode and `instructions`; the REST endpoint returns the graph with `rootConfigKey` and `edges[{key,sourceConfig,targetConfig,handoff}]`; the SDK evaluates it immediately with no extra targeting step.

## Otto's rewriter receives the question and draft in the user turn, not via placeholders (2026-10-07, revised after the first live run)

**Decision:** the rewriter's agent task carries the brand-voice snippet reference plus static rewriting rules; the customer's question and the specialist's draft are sent as the user message (`Customer's question: … / Specialist's draft: …`). No `{{question}}`/`{{draft}}` placeholders anywhere.

**Rationale:** the first live run returned "I don't see the customer's question or the specialist's draft" from the rewriter. In `launchdarkly-server-sdk-ai` 0.20.1, `agent_graph()` evaluates every node through the same path as `agent_config()` and renders `instructions` with `chevron.render(template, variables)`; `agent_graph()` has no `variables` parameter and `AgentGraphNode.get_config()` cannot re-render, so Mustache renders unknown tags as empty strings before the server ever sees the text. The earlier plan (server-side `str.replace`) was wrong. Snippet references still expand (verified again live).

**Teaching value:** ch05 and ch07 now say it plainly: an agent task is a Mustache template rendered by the SDK, so per-request data belongs in the user turn.

## Coordinate ch09 uses a synthetic traffic generator biased by served model (2026-10-07)

**Decision:** `traffic-generator/concierge_traffic.py` evaluates `concierge-otto-rewriter` per simulated user and emits `otto-brand-voice-score` from a per-model distribution (Haiku ≈ 0.80, Nova Lite ≈ 0.28), the same approach as Evaluate ch07's `background_traffic.py`.

**Why:** the rollout must fire inside the lab's time budget regardless of how Nova Lite happens to phrase any given rewrite. Real `/chat` traffic (and the real judges) run in every other Coordinate challenge, including ch10 where the self-heal is demonstrated on genuine rewrites.

## Coordinate ch07 replaces the Otto block rather than wrapping it (2026-10-07)

**Decision:** the Concierge paste replaces everything from the `# ─── Challenge 01: wire Otto to /chat` comment to the `# ─── Challenge 07 judge injects below this marker` comment. The Evaluate judge blocks below the marker are kept and now grade the rewriter's output; the paste defines the `assistant_text`, `model_id`, `tracker` and `context` names they rely on.

**Why:** Python has no way to guard the existing block without re-indenting it, and a second Bedrock call to Otto Assistant per request would muddle the lesson (two Ottos answering). A clean replacement with exact anchors is the smallest honest edit; `patch-server.py` does the same replacement for Skip.


## Coordinate has no welcome challenge; the lab token is minted from the bootstrap custom role (2026-10-07)

**Decision:** Drop `instruqt-coordinate/00-welcome/` and open the track on ch01 (`toggle`), whose intro now carries the "where Otto is", mode-permanence and Concierge-cast framing. Mint the scoped `LD_API_TOKEN` exactly as Build and Evaluate do: look up the bootstrap-created `<project>-admin` custom role and `POST /api/v2/tokens` with `customRoleIds` + `serviceToken: true`.

**Rationale:** The operator removed the welcome challenges from Build (2026-09-10) and Evaluate (2026-09-29); Coordinate should match. Independently, the Instruqt CLI never pushed the `00-*` directory (remote pull showed 01–11 only, even after a rename and `--force`), so a welcome would have been invisible anyway. The first live Coordinate run failed in track setup with `curl: (22) … 403` on the token mint: the operator token cannot create tokens with an `inlineRole`, only from existing custom roles. That aborted setup (`set -e`), so no `.env`, Build/Evaluate solves or server patches ran.

**Alternatives considered:**
- *Keep the welcome and debug the CLI.* Rejected: diverges from the sibling tracks and the CLI behaviour had no visible cause.
- *Fall back to `inlineRole` on 403.* Rejected: the custom-role path already exists and is proven in two tracks.

## Variation resources carry no `description`; ch09 guards its Terraform apply (2026-10-07, after the skip run)

**Decision:** drop the `description` attribute from every `launchdarkly_ai_config_variation` in `terraform/coordinate-*`, and make ch09's setup/solve apply `terraform/coordinate-09` only when `otto-rewriter-lite` does not exist yet.

**Rationale:** the skip run showed the provider (2.30.x) creating the Lite variation fine on the first apply, then failing every later apply with `waiting for variation version to advance past 1`: the API does not persist a variation description, so the provider plans `+ description` forever and its PATCH never bumps the version it polls for. ch09's solve runs after its setup, so the second apply always hit this; `set -e` then skipped the traffic generator and the guarded-rollout REST call. The config-level `description` (what the UI and graph cards show) is untouched.
