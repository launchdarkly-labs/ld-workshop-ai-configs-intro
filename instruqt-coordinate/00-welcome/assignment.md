---
slug: welcome
id: cw4os0nfzj4t
type: challenge
title: Welcome to AgentControl — Coordinate
teaser: Otto is alive and well-measured. Now grow him into a team.
notes:
- type: text
  contents: >-
    You've built Otto and you've evaluated him. Now grow him into a team. This short stop frames the one rule that shapes the whole track (a Config's mode is permanent), introduces the Concierge cast, and shows you where everything from Build and Evaluate already lives in your project.
tabs:
- id: 04lc24accux8
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: hbncxe1je8g9
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: 5fc9s7esfowx
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 300
enhanced_loading: null
---

# Where Otto is now

Otto has had quite a run. In Build he was born, got his voice from the `brand-voice` snippet, learned to tell Free from Premium customers, and started reporting on himself. In Evaluate he was graded offline, judged online, experimented on, guarded during a risky rollout, and taught to pull himself back to a safe variation when his scores slipped.

He's good at his job. He's also alone. Every customer question, whatever it's about, lands on one prompt and one model.

# The constraint that shapes this track

Otto is a **completion-mode** Config, and a Config's mode is permanent. Agent mode, which gives a Config a single `instructions` string, tools, and a place in an **agent graph**, is a different kind of Config. You can't flip Otto over; you can only build around him.

That constraint is the whole design of this track. Instead of upgrading Otto, you'll build a team around him: the **Concierge**.

| Agent | Role | Mode |
|---|---|---|
| **Toggle** | Front desk. Reads the customer's message and names the specialist who should handle it. | agent |
| **Curator** | Product specialist. Answers from the catalog, and only from the catalog. | agent |
| **Tailor** | Sizing specialist. Honest about what it doesn't know. | agent |
| **Tracker** | Orders and shipping specialist. Never invents an order status. | agent |
| **Otto** | Brand-voice rewriter. Every specialist's draft passes through him before the customer sees it. | agent (a new Config; the original Otto stays as he is) |

Topology: `Toggle → (Curator | Tailor | Tracker) → Otto → customer`

# What you'll do

1. Build Toggle, your first agent-mode Config, and feel the mode-permanence rule first hand.
2. Build the three specialists the same way.
3. Bring Otto back as the rewriter, reusing the very same `brand-voice` snippet from Build.
4. Wire the five Configs into an agent graph with handoff data on every edge.
5. Replace Otto's single call in `server.py` with graph-driven dispatch from the Python SDK.
6. Roll out a cheaper model to one node only, behind a guarded rollout.
7. Add the third safety net: a synchronous judge inside the rewriter that regenerates an off-brand response before anyone sees it.

# Your workspace

Your LaunchDarkly project already contains everything Build and Evaluate produced: Otto Assistant with his variations, the three snippets, the two custom judges, their metrics, and the Formal variation. The [ToggleWear](#tab-1) app is running and answering as Otto. The [Code Editor](#tab-2) has `server.py` open with the judge blocks you pasted in Evaluate still in place.

Take a quick look at each tab, then click **Check** to begin.
