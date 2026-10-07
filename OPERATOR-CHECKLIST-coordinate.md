# OPERATOR-CHECKLIST-coordinate.md

Operator verification pass for **Track 3 / Coordinate** (`instruqt-coordinate/`). Same shape as the Build and Evaluate checklists: cross-cutting items first, then one section per challenge with the UI steps that still carry `<!-- VERIFY -->` markers in `assignment.md`.

Authored 2026-10-07 in one pass (Phases 2–10 of PHASES-coordinate.md). Everything API-shaped was verified live (sandbox `kevinc-instruqt` + the Python AI SDK 0.20.1 that the VM image ships). Everything UI-shaped for **agent-mode variations** and the **graph builder** is a draft from the docs until the first lab run; the Create config dialog itself was inspected live.

## Live-run status (2026-10-07)

Three Instruqt runs on the pushed track (`instruqt track push`, lab projects `flexible-oarfish`, `divine-bull`, plus a skip-only run):

- **Participant pass, ch01–ch11: green.** Every Check passed as a learner would do it (configs built in the UI, graph built in the builder, ch07/ch10 pastes applied, guarded rollout rolled back automatically at ~3.5 min, forced heal observed).
- **Skip pass: ch01–ch11 green** (two skip runs; the second confirmed the ch09 fix below).
- **Fixed during the runs:** track setup minted the lab token with an inline role (403; now the custom-role form used by Build/Evaluate); the welcome challenge was dropped to match the sibling tracks; the rewriter's `{{question}}`/`{{draft}}` placeholders were being rendered to empty strings by the SDK (now sent in the user turn; DECISIONS.md); ch01–ch10 assignment prose now reflects the live UI.
- **Still open for the operator:** the items below that are unchecked. Everything checked was verified in these runs.

## Cross-cutting items

- [x] **First live run.** Launch `ld-agentcontrol-coordinate`, play ch01–ch11 as a participant, then once more with Skip. Expect the same class of issues the Evaluate runs surfaced: label drift in assignments, and solve/check assumptions about API shapes.
- [x] **Track-level setup timing.** Measured: ~90 s from `Syncing` to the final patch (bootstrap + 10 applies + 4 patches). Coordinate's setup applies Build's 5 solves + Evaluate's 5 solves + 4 server patches before the learner sees ch01. Evaluate's bootstrap already took ~90 s; expect 2–3 minutes here. If that is too long, pre-bake the post-Evaluate state into the image (PHASES-coordinate.md Phase 10).
- [x] **Agent-mode variation editor labels.** Verified: one **Agent task** box (no variation Description field), **Select model** picker with a **Region** pill, **Load snippet** / **Save snippet as** appear in a toolbar once the box is focused. Markdown list auto-continuation bites when *typing* `- ` bullets; pasting is fine. Assignments assume fields named **Description** and **Instructions**, a **Select model** picker identical to completion mode, and **Load snippet** available in the Instructions editor. Verified: snippet references and `{{variables}}` *expand* in agent instructions (SDK returns the substituted text). Unverified: the editor's exact labels. ch01–ch05 carry the markers.
- [x] **Graph builder flow.** Verified: **Add your first agent** → node with **Select an agent...**; the **↓** handle under a node adds a connected child; **Edit** on an edge opens the **Handoff data** JSON dialog with **Save**; a second node for an already-placed config merges on save; graph **Save** top right. ch06's steps for adding nodes, marking the root, drawing edges and entering handoff JSON are drafts from the docs ("click the + on an edge, enter JSON, click outside to save"). The REST shape is verified (`POST /api/v2/projects/{proj}/agent-graphs` with `rootConfigKey` + `edges[{key,sourceConfig,targetConfig,handoff}]`), so the solve and check are solid; the UI prose is not.
- [x] **Key derivation for agent Configs.** Verified for all five names; **Edit key** link present. Checks require exact keys (`concierge-toggle`, `concierge-curator`, `concierge-tailor`, `concierge-tracker`, `concierge-otto-rewriter`). The Create config dialog (inspected live) has a **Name** field and derives the key; confirm the derived key for "Concierge Otto Rewriter" is `concierge-otto-rewriter` and whether an **Edit key** control exists to fix mistakes.
- [x] **Model config keys.** Lab projects list the Bedrock globals; the UI pick `us.anthropic.claude-haiku-4-5-20251001-v1:0` creates a project model config and the SDK reports `us.anthropic.claude-haiku-4-5-20251001-v1:0` as the model name (passes through to Bedrock unchanged). Agent variations use the account-global `Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0` (as Evaluate ch03 does) and the Lite variation uses `Bedrock.amazon.nova-lite-v1:0`. Both exist as globals in the sandbox; confirm they exist in the workshop account (they should — same catalog).
- [x] **Bedrock access for Nova Lite.** Nova Lite rewrites served and were judged (scores 0.6–0.85). The app maps `amazon.nova-lite-v1:0` to `us.amazon.nova-lite-v1:0`. Confirm the federated BedrockProfile role may invoke it.
- [ ] **Traversal API choice (DECISIONS.md 2026-10-07).** The lab uses `agent_graph()` + `root()` + `get_edges()` + `get_node()` and follows handoff data per request, rather than `reverse_traverse`. Both exist in the SDK; the former shows the wiring the docs describe ("the application controls traversal"). Reword PHASES/NARRATIVE if you disagree.
- [ ] **ch07 paste size.** The Concierge dispatch replaces ~55 lines of the Otto block with ~100 lines. The assignment gives exact start/end anchors; the solve installs it with `terraform/coordinate-07/patch-server.py`. Decide whether learners paste by hand (as in Build ch01) or whether a presenter should narrate it.
- [x] **Graph monitoring page.** Graph tab shows Global values + per-node Invocations (with % share), Avg. duration, Error rate, tokens; Monitoring tab has Global metrics / Node-level metrics. ch07's last section points at **Agents → Graphs → Concierge** for per-node metrics tagged with `graphKey`. Confirm what the page actually shows.
- [x] **Self-heal latency.** `/chat` through the Concierge took ~7 s end to end with the judge in place; acceptable for the demo. ch10 adds one judge call (~1 s) and occasionally a regenerate (~2 s) to the rewriter step. Observed end-to-end `/chat` latency with the Concierge is already ~3 model calls; confirm the demo pacing is acceptable.
- [x] **Instruqt sandbox idle.** Confirmed again: with the Instruqt tab in the background the sandbox was stopped after ~5 min (cleanup ran, project destroyed). Keep the lab tab in the foreground. Lessons from the Evaluate runs apply: a sandbox that naps comes back as a new project; a retry Start does not re-run a failed setup; the code-server git toast steals the first keystrokes.

## Per-challenge verification

### 01 Toggle
- [x] Create config → **Agent** → Name "Concierge Toggle" → key `concierge-toggle`.
- [x] Variation editor: name field, **Select model**, **Agent task**. Model picker same as completion mode (plus a Region pill).
- [x] Targeting: the first saved variation is auto-served (On, Default rule → Default); assignments now say "confirm". Check reads `environments.test.enabled` and the fallthrough index.

### 02–04 Curator / Tailor / Tracker
- [x] **Load snippet** works inside the Agent task box (ch02 inserts `{{snippet.product-catalog#1}}`; the SDK returns the expanded catalog).
- [x] Checks grep the latest variation's `instructions` for the snippet reference (02) and role words (03: "Tailor", "size"; 04: "Tracker", "order").

### 05 Otto returns
- [x] Agent task ends with the "message you receive contains the customer's question followed by the specialist's draft" sentence; check greps for "specialist's draft".

### 06 Build the graph
- [x] Agents → **Graphs** → **Create new graph**; name "Concierge" → key `concierge`; Description field; builder opens on Create.
- [x] Builder: add 5 nodes, root = Toggle, 6 edges, handoff JSON on each. Check validates root, the six source→target pairs, and `handoff.route` on Toggle's edges.
- [x] Solve (REST POST) is skipped if the graph exists (skip run after a UI-built graph not retested; the create path ran clean in the skip-only run).

### 07 Wire the SDK
- [x] Learner replaces the block between the ch01 comment and the ch07 marker. Check: `ai_client.agent_graph("concierge"` present, old `completion_config(OTTO_CONFIG_KEY` gone, hook comment present, file compiles, `/chat` answers.
- [x] Judge blocks (Evaluate 02/03/04) still run on the rewrite and record against the rewriter's tracker.

### 08 Quiz
- [x] Answer index 1.

### 09 Per-agent rollout
- [x] Setup creates **Otto Rewriter (Lite)** (Nova Lite) and starts `concierge_traffic.py` (synthetic, biased scores; see DECISIONS).
- [x] Guarded rollout form as in Evaluate ch07: original **Default**, target **Otto Rewriter (Lite)**, metric Otto Brand Voice Score + Automatic rollback, Custom 4×1 min.
- [x] Check passes on an active `measuredRollout` or a release in history; fails if any of the other four nodes has a rollout.
- [x] **Skip path for ch09.** Re-verified in a fourth run after the fix: setup created the Lite variation, solve skipped Terraform ("already exists") and started the guarded rollout via REST (`measuredRollout` live on the rewriter).
- [x] Rollback observed at ~3.5 min (50% stage): "Default rule rolled back automatically after detecting a regression for Otto Brand Voice Score" + Review regression.

### 10 Self-healing
- [x] Setup creates metric `concierge-self-heal`; paste goes under the ch07 hook. Check: `SELF_HEAL_THRESHOLD` and `concierge-self-heal` in server.py, compiles, metric exists, `/chat` answers.
- [x] Forcing a heal: real Nova Lite rewrites score 0.6–0.85 and mostly pass, so the lab raises `SELF_HEAL_THRESHOLD` to 0.9 for a deterministic heal (`score=0.85 below 0.90: regenerated on us.anthropic…`). Put 0.5 and Default back afterwards.
- [ ] **Metrics → Concierge self-heal** shows the count.

### 11 Wrap-up
- [x] Answer index 1.
