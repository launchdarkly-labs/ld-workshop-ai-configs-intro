# OPERATOR-CHECKLIST-coordinate.md

Operator verification pass for **Track 3 / Coordinate** (`instruqt-coordinate/`). Same shape as the Build and Evaluate checklists: cross-cutting items first, then one section per challenge with the UI steps that still carry `<!-- VERIFY -->` markers in `assignment.md`.

Authored 2026-10-07 in one pass (Phases 2–10 of PHASES-coordinate.md). Everything API-shaped was verified live (sandbox `kevinc-instruqt` + the Python AI SDK 0.20.1 that the VM image ships). Everything UI-shaped for **agent-mode variations** and the **graph builder** is a draft from the docs until the first lab run; the Create config dialog itself was inspected live.

## Cross-cutting items

- [ ] **First live run.** Launch `ld-agentcontrol-coordinate`, play ch01–ch11 as a participant, then once more with Skip. Expect the same class of issues the Evaluate runs surfaced: label drift in assignments, and solve/check assumptions about API shapes.
- [ ] **Track-level setup timing.** Coordinate's setup applies Build's 5 solves + Evaluate's 5 solves + 4 server patches before the learner sees ch01. Evaluate's bootstrap already took ~90 s; expect 2–3 minutes here. If that is too long, pre-bake the post-Evaluate state into the image (PHASES-coordinate.md Phase 10).
- [ ] **Agent-mode variation editor labels.** Assignments assume fields named **Description** and **Instructions**, a **Select model** picker identical to completion mode, and **Load snippet** available in the Instructions editor. Verified: snippet references and `{{variables}}` *expand* in agent instructions (SDK returns the substituted text). Unverified: the editor's exact labels. ch01–ch05 carry the markers.
- [ ] **Graph builder flow.** ch06's steps for adding nodes, marking the root, drawing edges and entering handoff JSON are drafts from the docs ("click the + on an edge, enter JSON, click outside to save"). The REST shape is verified (`POST /api/v2/projects/{proj}/agent-graphs` with `rootConfigKey` + `edges[{key,sourceConfig,targetConfig,handoff}]`), so the solve and check are solid; the UI prose is not.
- [ ] **Key derivation for agent Configs.** Checks require exact keys (`concierge-toggle`, `concierge-curator`, `concierge-tailor`, `concierge-tracker`, `concierge-otto-rewriter`). The Create config dialog (inspected live) has a **Name** field and derives the key; confirm the derived key for "Concierge Otto Rewriter" is `concierge-otto-rewriter` and whether an **Edit key** control exists to fix mistakes.
- [ ] **Model config keys.** Agent variations use the account-global `Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0` (as Evaluate ch03 does) and the Lite variation uses `Bedrock.amazon.nova-lite-v1:0`. Both exist as globals in the sandbox; confirm they exist in the workshop account (they should — same catalog).
- [ ] **Bedrock access for Nova Lite.** The app maps `amazon.nova-lite-v1:0` to `us.amazon.nova-lite-v1:0`. Confirm the federated BedrockProfile role may invoke it.
- [ ] **Traversal API choice (DECISIONS.md 2026-10-07).** The lab uses `agent_graph()` + `root()` + `get_edges()` + `get_node()` and follows handoff data per request, rather than `reverse_traverse`. Both exist in the SDK; the former shows the wiring the docs describe ("the application controls traversal"). Reword PHASES/NARRATIVE if you disagree.
- [ ] **ch07 paste size.** The Concierge dispatch replaces ~55 lines of the Otto block with ~100 lines. The assignment gives exact start/end anchors; the solve installs it with `terraform/coordinate-07/patch-server.py`. Decide whether learners paste by hand (as in Build ch01) or whether a presenter should narrate it.
- [ ] **Graph monitoring page.** ch07's last section points at **Agents → Graphs → Concierge** for per-node metrics tagged with `graphKey`. Confirm what the page actually shows.
- [ ] **Self-heal latency.** ch10 adds one judge call (~1 s) and occasionally a regenerate (~2 s) to the rewriter step. Observed end-to-end `/chat` latency with the Concierge is already ~3 model calls; confirm the demo pacing is acceptable.
- [ ] **Instruqt sandbox idle.** Lessons from the Evaluate runs apply: a sandbox that naps comes back as a new project; a retry Start does not re-run a failed setup; the code-server git toast steals the first keystrokes.

## Per-challenge verification

### 01 Toggle
- [ ] Create config → **Agent** → Name "Concierge Toggle" → key `concierge-toggle`.
- [ ] Variation editor: name field, **Select model**, **Description**, **Instructions**. Model picker same as completion mode.
- [ ] Targeting: config **On**, Default rule → **Serve → Default**. Check reads `environments.test.enabled` and the fallthrough index.

### 02–04 Curator / Tailor / Tracker
- [ ] **Load snippet** works inside agent Instructions (ch02 inserts `{{snippet.product-catalog#1}}`).
- [ ] Checks grep the latest variation's `instructions` for the snippet reference (02) and role words (03: "Tailor", "size"; 04: "Tracker", "order").

### 05 Otto returns
- [ ] Instructions keep `{{question}}` and `{{draft}}` verbatim; check requires both.

### 06 Build the graph
- [ ] Agents → **Graphs** → **Create new graph**; name "Concierge" → key `concierge`.
- [ ] Builder: add 5 nodes, root = Toggle, 6 edges, handoff JSON on each. Check validates root, the six source→target pairs, and `handoff.route` on Toggle's edges.
- [ ] Solve (REST POST) is skipped if the graph exists.

### 07 Wire the SDK
- [ ] Learner replaces the block between the ch01 comment and the ch07 marker. Check: `ai_client.agent_graph("concierge"` present, old `completion_config(OTTO_CONFIG_KEY` gone, hook comment present, file compiles, `/chat` answers.
- [ ] Judge blocks (Evaluate 02/03/04) still run on the rewrite and record against the rewriter's tracker.

### 08 Quiz
- [ ] Answer index 1.

### 09 Per-agent rollout
- [ ] Setup creates **Otto Rewriter (Lite)** (Nova Lite) and starts `concierge_traffic.py` (synthetic, biased scores; see DECISIONS).
- [ ] Guarded rollout form as in Evaluate ch07: original **Default**, target **Otto Rewriter (Lite)**, metric Otto Brand Voice Score + Automatic rollback, Custom 4×1 min.
- [ ] Check passes on an active `measuredRollout` or a release in history; fails if any of the other four nodes has a rollout.
- [ ] Observe the rollback wording on the rewriter's card.

### 10 Self-healing
- [ ] Setup creates metric `concierge-self-heal`; paste goes under the ch07 hook. Check: `SELF_HEAL_THRESHOLD` and `concierge-self-heal` in server.py, compiles, metric exists, `/chat` answers.
- [ ] Forcing a heal: Serve → Otto Rewriter (Lite) on the rewriter, watch `journalctl -u togglewear -f | grep self-heal`. Put Default back afterwards.
- [ ] **Metrics → Concierge self-heal** shows the count.

### 11 Wrap-up
- [ ] Answer index 1.
