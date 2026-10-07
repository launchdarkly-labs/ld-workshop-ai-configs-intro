---
slug: quiz-coordinate
id: 2uyiyzmfyrrj
type: quiz
title: Quiz — Coordinating Otto
teaser: A quick check on what you've built — agent mode, graphs, handoffs, and SDK
  traversal.
notes:
- type: text
  contents: >-
    One question on agent mode, graphs, and handoffs before the last two labs.
answers:
- The graph runs on LaunchDarkly's servers: the SDK sends the customer's message and receives Otto's final answer.
- The graph is topology plus handoff data. The SDK returns the nodes, their resolved agent Configs, and the edges; your application decides what to call and in what order.
- Each edge calls the target agent's model automatically as soon as the source agent finishes, so the server only has to call the root node.
- Agent graphs can only connect completion-mode Configs, which is why Otto Assistant had to be converted to agent mode first.
solution:
- 1
difficulty: basic
timelimit: 600
enhanced_loading: null
---

# Quick check

One question on what the Concierge taught you so far. Pick the best answer and click **Check**.
