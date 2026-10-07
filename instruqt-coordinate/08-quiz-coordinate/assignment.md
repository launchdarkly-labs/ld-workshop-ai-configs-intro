---
slug: quiz-coordinate
id: 2uyiyzmfyrrj
type: quiz
title: Quiz — Coordinating Otto
teaser: A quick check on what you've built — agent mode, graphs, handoffs, and SDK
  traversal.
notes:
- type: text
  contents: One question on agent mode, graphs, and handoffs before the last two labs.
answers:
- 'The graph runs on LaunchDarkly''s servers: the SDK sends the message and gets Otto''s
  final answer back.'
- The graph is topology plus handoff data. The SDK returns nodes, their resolved Configs
  and edges; your app decides what to call, and when.
- Each edge calls the target agent's model as soon as the source agent finishes, so
  the server only calls the root node.
- Agent graphs only connect completion-mode Configs, which is why Otto Assistant had
  to be converted to agent mode first.
solution:
- 1
difficulty: basic
timelimit: 600
enhanced_loading: null
---

# Quick check

One question on what the Concierge taught you so far. Pick the best answer and click **Check**.
