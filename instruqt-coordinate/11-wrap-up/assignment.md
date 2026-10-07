---
slug: wrap-up
id: 93vszvsvpmfq
type: quiz
title: Wrap-Up
teaser: Otto's arc, across all three tracks. One last question.
notes:
- type: text
  contents: >-
    Otto is measured, judged, experimented on, guarded, and now part of a team. One last question closes the three-track arc.
answers:
- A guarded rollout protects every request synchronously, so once it's configured the self-healing judge in Coordinate 10 is redundant.
- The three nets differ by timescale: a guarded rollout protects the next customers at release time, adaptive switching protects the next customers between requests, and self-healing protects the current customer on this request, at the cost of extra latency.
- Self-healing is the cheapest net because it never calls a model; it reads the guarded rollout's metric instead.
- All three nets act on the same event: a judge score below threshold immediately rolls back the release, flips targeting, and regenerates the response.
solution:
- 1
difficulty: basic
timelimit: 600
enhanced_loading: null
---

# Otto's arc, three tracks long

Build: Otto was born plain, got his voice from the `brand-voice` snippet, learned Free from Premium, and started reporting on himself.

Evaluate: Otto was graded offline against a dataset, judged online by built-in and custom judges, A/B tested on live traffic, guarded during a risky rollout, and taught to pull himself back when his scores slipped.

Coordinate: Otto became part of a team. Toggle triages, three specialists answer, and Otto rewrites every response in his own voice, which still comes from the same snippet he got in Build. The team is an agent graph; the server traverses it; a rollout can put one node on trial without touching the others; and a judge now stands between Otto and the customer on every request.

# Three safety nets, three timescales

| Timescale | Mechanism | Demonstrated in |
|---|---|---|
| Release time | Guarded rollout with automatic rollback | Evaluate 07, Coordinate 09 |
| Between requests | Adaptive switching in the app | Evaluate 08 |
| Per request | Synchronous judge and regenerate | Coordinate 10 |

Each one catches a different kind of failure at a different cost. You've built all three.

# Where to go next

- **AgentControl documentation**: launchdarkly.com/docs/home/agentcontrol
- **Tools and skills on agent Configs**: the specialists here answered from instructions alone; give them tools and the Tracker can look up a real order.
- **Framework runners**: the same graph you built can drive LangGraph or the OpenAI Agents SDK through the SDK's framework integrations, with the same per-node metrics.
- **Your own use case**: pick one job your assistant does badly, make it a specialist, and put Otto's equivalent in front of it.

# Otto says

> Thanks for letting me bring some friends. We'll take it from here.

One last question below, then you're done.
