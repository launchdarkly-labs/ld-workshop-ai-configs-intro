---
slug: wrap-up
id: ucsbqsx1cmod
type: quiz
title: Wrap-Up
teaser: Otto is measured, judged, experimented on, and guarded. So are you.
notes:
- type: text
  contents: You started Evaluate with a working Otto and ended with three safety nets
    running at three different timescales. One last question, then on to Coordinate.
answers:
- A guarded rollout reacts on every request; adaptive switching reacts only at release
  time.
- They both react on every request — the only difference is which LaunchDarkly surface
  each one uses.
- A guarded rollout reacts at release time, while traffic is ramping; adaptive switching
  reacts between requests in production, based on what the metric is doing right now.
- Adaptive switching is just an internal name for the same feature as a guarded rollout
  — they're interchangeable.
solution:
- 2
difficulty: basic
timelimit: 600
enhanced_loading: null
---
# Otto's evaluation arc

Otto came into Evaluate already alive and on-brand. From there:

- **Challenge 01** — graded offline. A labeled dataset of 30 customer questions told you exactly where Otto was solid, where he slipped, and where the prompt couldn't help him.
- **Challenge 02** — got built-in judges. Three signals (Accuracy, Relevance, Toxicity) attached in two clicks; scores started populating monitoring within a minute.
- **Challenge 03** — got a custom brand-voice judge whose grading criteria pulled in the same `brand-voice` snippet that already drove Otto's prompt. **One source of truth for "on-brand."**
- **Challenge 04** — got a second custom judge using the `product-catalog` snippet as ground truth. Same pattern; different concern (accuracy of claims).
- **Challenge 06** — ran a prompt experiment. The brand-voice judge picked the winner from two variations that were a single sentence apart.
- **Challenge 07** — set up a guarded rollout. The same brand-voice judge metric you wired in Challenge 03 caught a risky Nova Pro variation and auto-rolled-back.
- **Challenge 08** — added a request-time safety net, twice: an adaptive trigger in LaunchDarkly that switches Otto's Default rule when the brand-voice score drops, and a small loop in the app that does the same thing from inside your process. No rollout required either way.

# What you took with you

Two patterns worth carrying into your own work:

1. **A snippet can drive both prompt content and grading criteria.** It's a small move that keeps "what you do" and "what you measure" pinned together. Anywhere you're worried about an LLM going off-style, this scales.
2. **There are three places to put safety nets: release-time, request-time, and per-request.** Guarded rollouts cover the first. Adaptive loops like the one you wrote in Challenge 08 cover the second. Track 3 / Coordinate covers the third with the self-healing pattern.

# One last question

You wired two safety nets in different challenges. What's the actual functional difference between Challenge 07's guarded rollout and Challenge 08's adaptive switching loop?

# Where to go from here

- **Coordinate (Track 3)** — Otto stops being a solo assistant and joins a team. A triage agent named **Toggle** routes customers to specialist agents (Curator for products, Tailor for sizing, Tracker for orders), and Otto becomes the brand-voice rewriter that polishes every specialist's response. Mode-permanent agent-mode Configs, agent graphs, SDK traversal, per-agent guarded rollouts, and the self-healing pattern.
- **AgentControl documentation:** [launchdarkly.com/docs/home/agentcontrol](https://launchdarkly.com/docs/home/agentcontrol)
- **Your own use case.** Pick one signal you care about, write a judge for it, attach it to your production config. That's the minimum-viable version of what you just did here.

# Otto says

> Thanks for noticing when I sound right. Come back any time.
