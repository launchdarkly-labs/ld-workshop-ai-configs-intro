# PHASES-coordinate.md

Build sequence for **Track 3 / Coordinate** (`instruqt-coordinate/`), the third of the workshop's three sibling tracks. Mirrors the structure of `PHASES-evaluate.md`: phases group related challenges, Claude Code works one phase at a time, operator review gates each phase boundary.

> **Status (2026-10-07, evening):** Phases 0–10 are done and the track has been through three live Instruqt runs: a full participant pass (ch01–ch11 green) and skip passes exercising every solve script. The welcome challenge was dropped to match Build and Evaluate (11 challenges). Fixes made during the runs, and the few items still open for the operator, are in `OPERATOR-CHECKLIST-coordinate.md`; design changes (lab-token minting, no Mustache placeholders in agent tasks, explicit edge traversal, synthetic rollout traffic) are in DECISIONS.md.

Coordinate starts where Evaluate ends — Otto is built, judged, experimented on, and guarded. Now he becomes part of a team. The track introduces the **Concierge**: a multi-agent system where a triage agent routes customers to specialists (product, sizing, orders), each specialist responds, and Otto polishes the final response for brand voice.

---

## Track 3 / Coordinate — scope

By the end of Coordinate, the learner has used every major Lesson-3 surface of AgentControl:

- Built an **agent-mode Config** and felt the mode-permanence constraint that necessitated the whole Concierge framing.
- Built three more agent-mode specialists, each with its own variation.
- Connected them into an **agent graph** with handoff data on every edge.
- Traversed the graph from Python using `ai_client.agent_graph(...)` + `reverse_traverse`.
- Wrapped the system with a **per-agent guarded rollout** that affects only one node (Otto-the-rewriter) without disturbing the others.
- Implemented **self-healing** — a synchronous judge call inside Otto's response path that regenerates with a fallback model if the response scores below threshold.

### Challenge list (11 challenges, ~2h; the welcome was dropped 2026-10-07 to match Build and Evaluate)

| # | Slug | Type |
|---|---|---|
| 01 | toggle | challenge (build first agent-mode Config) |
| 02 | the-curator | challenge (product specialist) |
| 03 | the-tailor | challenge (sizing specialist) |
| 04 | the-tracker | challenge (order-status specialist) |
| 05 | otto-returns | challenge (brand-voice rewriter agent) |
| 06 | build-the-graph | challenge (UI graph definition) |
| 07 | wire-the-sdk | challenge (Python traversal) |
| 08 | quiz-coordinate | quiz |
| 09 | per-agent-rollout | challenge (guarded rollout on Otto-the-rewriter node) |
| 10 | self-healing | challenge (synchronous judge + Haiku fallback) |
| 11 | wrap-up | quiz |

Slugs are drafts; final slugs lock during Phase 1 authoring.

---

## Source-of-truth notes

- `CLAUDE.md` — operational spec. Conventions apply across all tracks unchanged.
- `DECISIONS.md` — see the "Workshop splits into three sibling Instruqt tracks" entry for the cast/topology rationale.
- `NARRATIVE.md` — Otto's voice, ToggleWear brand. Concierge cast (Toggle, Curator, Tailor, Tracker, Otto-as-rewriter) introduced here and built out during Coordinate's authoring.
- `PHASES.md` / `PHASES-evaluate.md` — historical scope docs for Build / Evaluate.

---

## Phase 0: Verification spike

**Goal:** Confirm the agent-mode + agent-graph surface is stable enough to author against. Several questions were unanswered when the three-track split was scoped; this phase resolves them via docs review + an optional live-fire minimal-graph run against a real LD project.

### What's known (resolved 2026-06-02 from LD docs)

- **SDK availability**: agent graphs are **Python-SDK-only** at present. Node.js is not mentioned. ToggleWear is Python, so this is acceptable for the workshop.
- **Runtime model**: the application controls traversal. The SDK exposes metadata + helpers; LaunchDarkly does **not** execute graphs or call model providers. Quote from the docs: *"LaunchDarkly does not execute agent graphs or call model providers. The SDK does not manage graph state or traversal decisions."*
- **Two traversal modes**:
  - **`traverse` / `reverse_traverse`** — application-controlled. Each call returns nodes; the app's code interprets them and decides what to do next. Use `reverse_traverse` when child agents must be instantiated before their parent agents (typical when wrapping graph nodes in framework objects like OpenAI Agents).
  - **`graph.run()`** — framework-integrated. Works with **LangGraph** and the **OpenAI Agents SDK**. The framework handles orchestration; the SDK auto-collects metrics.
- **Invocation pattern**:
  ```python
  ai_client = LDAIClient(client)
  context = Context.builder("example-user").build()
  agent_graph = ai_client.agent_graph("example-graph-key", context)
  ```
- **Agent variation shape**: each agent-mode variation has a **`description`** field and an **`instructions`** field (a single string, replacing the message array used by completion-mode variations). Optional: tools, skills.
- **Tools**: project-level resources, attachable to both agent and completion variations. Created via `create-ai-tool` MCP / REST.
- **Multiple variations per agent**: yes, supported. Targeting rules choose which variation a context gets.
- **Mode-permanence**: confirmed. A Config's mode is set at creation and cannot change. This is the framing for Coordinate's pedagogical centerpiece — Otto from Build/Evaluate is completion-mode and can't be converted, which is why Coordinate introduces new agent-mode configs around him.
- **Judges on agent-mode variations**: **not supported via the UI.** Direct quote: *"Online evaluations are not supported for agent-based configs. You cannot attach judges to agent-based config variations."* For agent-mode self-healing (challenge 10), the judge must be invoked programmatically — same pattern Evaluate ch03/04 use. The brand-voice judge from Evaluate is itself a completion-mode Config (mode=judge), and it's invoked from server.py via `ai_client.judge_config(...)`. That pattern carries forward into Coordinate.

### MCP surface

The `agent-graphs` skill plus six MCP tools cover graph CRUD:

- `create-agent-graph(projectKey, key, name, description?, rootConfigKey?, edges?)`. If `rootConfigKey` is provided, `edges` must be too (and vice versa). A graph can be created with metadata only and have edges added later via update.
- `update-agent-graph(...)` — replaces edges (not incremental).
- `get-agent-graph`, `list-agent-graphs`, `delete-agent-graph(confirm=true)`.
- `preview-graph` exists but is a different surface (dashboard charts, not agent graphs — name collision).

### Edge data shape

Each edge: `{key, sourceConfig, targetConfig, handoff}`. `handoff` is an arbitrary JSON object accessible at runtime via `node.get_edges()`.

### Still pending — operator's live-fire minimal-graph spike

Before Coordinate authoring kicks off, the operator should run this minimal end-to-end test against a sandbox LD project:

1. **Create two agent-mode AI Configs** via the LD UI:
   - `triage-spike` — instructions: "You are the triage agent. Decide if the user wants product info, sizing, or orders. Pick one and respond with just the category name."
   - `specialist-spike` — instructions: "You are a product specialist. Answer the user's question."
2. **Create a graph** linking them:
   - Root: `triage-spike`
   - One edge: `triage-spike` → `specialist-spike`, handoff `{"category": "product"}`
3. **Write a 10-line Python script** that:
   - Initializes the LD client + LDAIClient
   - Calls `ai_client.agent_graph("spike-graph", context)`
   - Calls `agent_graph.reverse_traverse(...)` (or `traverse(...)`)
   - Prints what each returned node looks like
4. **Verify** the script returns sensible objects — at minimum the root config's instructions, and the edge's handoff data.
5. **(Stretch)** install the OpenAI Agents SDK and try `agent_graph.run("How big is the Rocket Tee?")`. Document what auto-metrics fire.

**Done-when:**
- The minimal graph runs end-to-end against a real project without surprises.
- The operator confirms which traversal API to use for Coordinate's lab challenges (`reverse_traverse` vs `run`). Lab pedagogy prefers `reverse_traverse` because it shows the wiring; `run` is more realistic for production code but opaque to the workshop.
- A go/no-go for each Coordinate content phase. Any phase whose surface verification reveals product gaps gets re-scoped before authoring.

### Open questions deferred to specific content phases

| Question | Where it lands | Pedagogical impact |
|---|---|---|
| Does the OpenAI Agents SDK pip-install cleanly into the existing app venv? | Phase 6 (wire-the-sdk) | If not, the lab uses `reverse_traverse` only and skips the framework-integrated path. |
| How does per-agent guarded rollout interact with graphs? Is it a property of the node Config, the edge, or the graph as a whole? | Phase 7 (per-agent-rollout) | If only node-level (which is the most likely interpretation given guarded rollouts are a Config-level concept), the lab targets Otto-the-rewriter's Config directly. |
| Can `tracker.track_judge_result` be used with judges invoked programmatically against agent Configs, or must we emit raw `ld_client.track(...)` events as Evaluate does? | Phase 8 (self-healing) | Affects how the self-healing pattern emits its quality signal. |
| Where does `graph_key` show up on per-request metric events for graph traversal? (Original PHASES-evaluate.md mentioned `graph_key` as a tracker parameter — confirm this in the SDK source.) | Phase 6 + 8 | Affects how metrics roll up to the graph view in monitoring. |

---

## Phase 1: Track foundation

**Goal:** Scaffold `instruqt-coordinate/` to the same skeleton as Build and Evaluate.

**Deliverables:**

- `instruqt-coordinate/track.yml` — slug `ld-agentcontrol-coordinate`, ID, title (Coordinate-specific), teaser, description. Mirror Evaluate's `track.yml` structure.
- `instruqt-coordinate/config.yml` — virtual browser, shared `launchdarkly/workshop-ai-configs` image, secrets `LAUNCHDARKLY_ACCESS_TOKEN` + `AWS_REGION` (federation provides AWS).
- `instruqt-coordinate/track_scripts/setup-workstation` — bootstraps the LD project, applies Build's solves (01/02/03/05/06) + the Challenge-01 patch-server.py + Evaluate's solves (01/02/03/04/06/07/08) so the learner arrives with everything Evaluate produced. The bootstrap delay will be larger than Evaluate's — likely warrants pre-baking by Phase 9.
- `instruqt-coordinate/track_scripts/cleanup-workstation` — destroy the bootstrap project.
- 12 empty challenge directories with placeholder `assignment.md` (front-matter only) and trivial setup/check/solve scripts.
- `instruqt-coordinate/assets/.gitkeep`.

**Done-when:**

- Operator confirms the scaffold mirrors Evaluate's conventions.
- The bootstrap loop runs end-to-end against a fresh sandbox. Timing is captured; if too slow, escalate before content authoring starts.

---

## Phase 2: Toggle the triage agent (challenge 01)

**Goal:** Author challenge 01 — `toggle`. Learner creates their first agent-mode Config, with a triage instructions prompt that classifies an incoming customer question into one of three categories (product / sizing / orders). The mode-permanence constraint is the lesson; the welcome (Phase 9) sets it up, this challenge makes it concrete.

**Deliverables:**

- `instruqt-coordinate/01-toggle/{assignment, setup, check, solve}-workstation`
- `terraform/coordinate-01/{versions, variables, main}.tf` — creates the `concierge-toggle` Config in `mode: agent` with one variation backed by Haiku, instructions text drawn from `NARRATIVE.md`. Sets fallthrough.

**Specific notes:**

- The triage agent's job is to *classify*, not respond. Its instructions should be very tight: "Respond with one of {product, sizing, orders}. Nothing else."
- Choosing mode=agent for a single-step classification is technically overkill, but it's the right place to introduce mode-permanence — the learner can't ever turn this Config back into a completion config.

---

## Phase 3: Three specialists (challenges 02, 03, 04 — paired)

**Goal:** Author the three specialist agents in a single phase. They share the same authoring pattern; the only deltas are instructions content and (eventually) tool attachments.

**Deliverables (per challenge):**

- `instruqt-coordinate/0N-the-{curator,tailor,tracker}/{assignment, setup, check, solve}-workstation`
- `terraform/coordinate-0N/{versions, variables, main}.tf` — creates an agent-mode Config with the specialist's instructions. May attach a tool if Phase 0's tools-feasibility check passes; otherwise instructions are self-contained.

**Specific notes:**

- **Curator** — product specialist. Instructions instruct the agent to answer product-knowledge questions, referencing the `product-catalog` snippet from Evaluate ch04 if the snippet-in-agent-instructions syntax works the same way.
- **Tailor** — sizing specialist. Instructions instruct the agent to handle sizing questions honestly (acknowledging Otto's "I don't have your specific sizing" patterns from Build).
- **Tracker** — order-status specialist. Instructions instruct the agent to handle order/shipping/policy questions, also acknowledging when data isn't available.
- The trio is paired in a single phase because each one teaches the same pattern. Phase 5 (Otto returns) is a fourth agent-mode Config but its role (brand-voice rewriter) is functionally different.

---

## Phase 4: Otto returns as the rewriter (challenge 05)

**Goal:** Author challenge 05 — `otto-returns`. Otto joins the Concierge team as the brand-voice rewriter — a fifth agent-mode Config that receives a specialist's response and rewrites it in Otto's voice using the L1 `brand-voice` snippet.

**Deliverables:**

- `instruqt-coordinate/05-otto-returns/{assignment, setup, check, solve}-workstation`
- `terraform/coordinate-05/{versions, variables, main}.tf` — creates `concierge-otto-rewriter` Config in agent mode. Instructions reference `{{snippet.brand-voice#1}}` (assuming snippets work the same way in agent instructions as in completion messages — VERIFY).

**Specific notes:**

- This is the narrative payoff for Otto. The Build/Evaluate Otto (completion mode) survives untouched; this new agent-mode Config is Otto in his new role.
- The instructions take an input (the specialist's response) and produce an output (the same response rewritten in Otto's voice).
- The brand-voice snippet reuse from L1 closes a long arc — the same snippet now drives Otto's prompt (Build), the brand-voice judge (Evaluate), AND the rewriter agent (Coordinate). One source of truth across three tracks.

---

## Phase 5: Build the graph in the UI (challenge 06)

**Goal:** Author challenge 06 — `build-the-graph`. The five configs now exist; the learner wires them into an agent graph via the LD UI, with handoff data on each edge.

**Deliverables:**

- `instruqt-coordinate/06-build-the-graph/{assignment, setup, check, solve}-workstation`
- `terraform/coordinate-06/main.tf` — uses the `launchdarkly_*` provider if a graph resource exists by authoring time; otherwise REST via `null_resource` (the `create-agent-graph` MCP tool confirms a REST endpoint exists). Topology: `concierge-toggle` is root; edges to each of `concierge-curator`, `concierge-tailor`, `concierge-tracker`; each of those has an edge to `concierge-otto-rewriter`.

**Specific notes:**

- Five nodes, seven edges. The handoff JSON on each Toggle→specialist edge carries the routing category (`{"route": "product"}` etc.); the specialist→rewriter edges carry the specialist's raw output (rendered via a template variable the rewriter's instructions reference).
- The lab's UI flow walks the learner through the graph editor — confirming each edge's source/target/handoff. The check script reads the graph back via `get-agent-graph` and validates topology.

---

## Phase 6: Wire the SDK (challenge 07)

**Goal:** Author challenge 07 — `wire-the-sdk`. Learner pastes a block into `server.py` that replaces the current single-Otto `/chat` handler with graph-driven multi-agent dispatch.

**Deliverables:**

- `instruqt-coordinate/07-wire-the-sdk/{assignment, setup, check, solve}-workstation`
- `terraform/coordinate-07/main.tf` — minimal (server.py is what changes)
- `terraform/coordinate-07/concierge-server-paste.py` — the paste block: initializes `ai_client.agent_graph(...)`, traverses via `reverse_traverse` or `run` (decided by the Phase 0 spike), and orchestrates Triage → Specialist → Otto-rewriter.
- `terraform/coordinate-07/patch-server.py` — install the paste at a new marker (probably `# ─── Coordinate orchestration replaces /chat below ────`) or by replacing the `/chat` body entirely.

**Specific notes:**

- This is the structurally largest server.py change in the workshop — `/chat`'s handler goes from "evaluate Otto + call Bedrock" to "evaluate graph + traverse + dispatch + collect."
- Existing Evaluate-era integrations (brand-voice judge, claim-accuracy judge, adaptive_observe) stay in place but now grade the final rewritten response instead of the raw specialist response.
- The graph-traversal code emits `graph_key` on tracker calls so per-request metrics roll up to the graph view in monitoring (assuming Phase 0 confirms this API).

---

## Phase 7: Per-agent guarded rollout (challenge 09)

**Goal:** Author challenge 09 — `per-agent-rollout`. Learner rolls out a cheaper variation of just the Otto-rewriter node (e.g., Haiku → Nova Lite) behind a guarded rollout that watches a per-rewriter quality metric. Blast radius is bounded — Triage and specialists are unaffected.

**Deliverables:**

- `instruqt-coordinate/09-per-agent-rollout/{assignment, setup, check, solve}-workstation`
- `terraform/coordinate-09/main.tf` — creates a Nova Lite variation on the Otto-rewriter Config. The learner configures the guarded rollout in the LD UI (same UI as Evaluate ch07).
- Sabotage-style traffic generator (analogous to Evaluate ch07's pattern) so the rollout can fire within lab budget.

**Specific notes:**

- The teachable moment: in completion mode (Evaluate ch07), a guarded rollout on Otto affects every customer-facing message. In agent-mode multi-agent (here), a rollout on one node affects only that node's contribution — the Triage and specialists keep using their current variations.
- The metric: a per-rewriter brand-voice score, computed by the synchronous judge wired in Phase 8 (self-healing) — so phases 7 and 8 are best authored together if their wiring overlaps.

---

## Phase 8: Self-healing (challenge 10)

**Goal:** Author challenge 10 — `self-healing`. Learner adds a synchronous quality check inside the Otto-rewriter dispatch: invoke the brand-voice judge on the rewriter's output; if the score is below threshold, regenerate using a vetted fallback model (Haiku 4.5) before the user sees a bad response.

**Deliverables:**

- `instruqt-coordinate/10-self-healing/{assignment, setup, check, solve}-workstation`
- `terraform/coordinate-10/main.tf` — may add a fallback variation key on the rewriter (a stable Haiku-backed variant that's pinned).
- `terraform/coordinate-10/concierge-selfheal-paste.py` — the paste: wraps the rewriter call with judge invocation + optional regenerate.
- `terraform/coordinate-10/patch-server.py` — installs the paste inside the graph dispatch in server.py.

**Specific notes:**

- This challenge is the natural conclusion of the three-safety-nets arc introduced in Evaluate. The wrap-up quiz tests the learner's understanding of how all three relate.
- Latency impact: a synchronous judge call adds ~500ms-1s to each rewriter-served response. The assignment frames this as a deliberate tradeoff (latency for quality).

---

## Phase 9: Welcome + quiz + wrap-up (challenges 00, 08, 11)

**Goal:** Author the non-lab challenges last so they can reference what the learner did.

**Deliverables:**

- `instruqt-coordinate/00-welcome/assignment.md` — frames mode-permanence, introduces the Concierge cast (Toggle, Curator, Tailor, Tracker, Otto-as-rewriter), recaps Otto's journey through Build + Evaluate.
- `instruqt-coordinate/08-quiz-coordinate/assignment.md` — 1-2 questions covering challenges 01-07 (agent mode, graphs, handoffs, SDK traversal).
- `instruqt-coordinate/11-wrap-up/assignment.md` — type=quiz. Closes Otto's arc across all three tracks. Final question synthesizes the three-safety-nets framing (release / between-requests / per-request) and where each lab demonstrated it.

---

## Phase 10: Polish

**Goal:** Final pass — same as Evaluate's Phase 9.

**Deliverables:**

- Pass through every `assignment.md` for narrative consistency with `NARRATIVE.md`.
- `check-workstation` `fail-message` quality pass.
- `setup-workstation` / `solve-workstation` idempotency pass.
- Time the track-level setup-workstation end-to-end. If applying Build+Evaluate solves at lab start is too slow, escalate to pre-baking the post-Evaluate state into the VM image.
- New `OPERATOR-CHECKLIST-coordinate.md` for the operator's UI verification pass.
- Update `DECISIONS.md` with anything that landed differently from the scope.

---

## Open questions surfaced during scoping

1. **Snippets in agent instructions.** Do `{{snippet.<key>#<version>}}` references work inside an agent Config's `instructions` field the same way they do inside a completion Config's `messages.content`? If so, Otto-the-rewriter's instructions can reference `{{snippet.brand-voice#1}}` for the long-form snippet-reuse closure. Phase 4 verifies.
2. **Tool feasibility timing.** Do tools need to be created before they're attached to agent variations, or can they be inline? The `create-ai-tool` MCP exists; need to test the attach flow during Phase 3.
3. **OpenAI Agents SDK install.** If `pip install openai-agents` (or whatever the package is) clashes with the existing app venv, Phase 6 falls back to `reverse_traverse`-only and skips the framework path.
4. **Per-request `graph_key` attribution.** When the app evaluates a node's Config inside the graph traversal, does the tracker need a `graph_key` parameter for monitoring to roll up by graph? The original PHASES-evaluate.md note mentioned this; not yet documented in the LD docs page I fetched. Phase 6 confirms.
5. **Self-healing latency budget.** A synchronous judge call adds visible latency. Operator picks an acceptable target during Phase 8 authoring (probably ≤1.5s end-to-end including the regenerate path).
6. **Bootstrap timing under cumulative solves.** Coordinate's track-level setup applies Build's solves + Evaluate's solves + Coordinate's prior solves. Likely 60-90s+ end-to-end. If unacceptable, pre-bake into the image during Phase 10.
