---
slug: how-is-otto-doing
id: quemgqcw6u62
type: challenge
title: How is Otto Doing?
teaser: Otto is live. Time to look at the data. Tokens, latency, and learner feedback,
  all in one view.
notes:
- type: text
  contents: A few days of pretend-traffic have rolled through, and ToggleWear shoppers
    have been chatting with Otto and rating his answers. In this challenge you'll
    explore the AgentControl monitoring view and see how Otto's variations stack up.
tabs:
- id: nz8guwejvqib
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: gsnr8qvrfphq
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: aekuh5pojiiu
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 900
enhanced_loading: null
---

# Otto is in production

Otto has been live for a couple of pretend-days. ToggleWear shoppers have been chatting with him and giving him thumbs-up and thumbs-down ratings. (Behind the scenes, setup ran a traffic generator that fed Otto ~120 fake sessions while you were starting this lab.)

The point of this challenge is to *look*. You're not going to change anything. You're going to use the AgentControl monitoring view the same way you'd use it the morning after a real launch — to answer the question, "Is Otto working?"

# Open the monitoring view

Open the [LaunchDarkly](#tab-0) tab.

1. Go to **Configs** → **Otto Assistant**.
2. Click the **Monitoring** tab.
3. Make sure the environment pill reads **Test**. The time range defaults to **Last 7 days**.

You should see a populated dashboard: four summary charts across the top and a per-variation table underneath. Take a minute to look at it before reading further.

# Things to look for

The dashboard breaks Otto's performance down by variation. Compare **Otto (Born)** to **Otto (Premium)**:

- **Requests**: how many times each variation was served. Born is busier because most simulated shoppers were free-tier (roughly 80/20).
- **Satisfaction rating**: the share of thumbs-up ratings. Both variations score well, but Premium scores noticeably better. That's not magic — it's the model. The traffic generator weighted positive feedback higher for Sonnet.
- **Cost**: the **Total input cost** and **Total output cost** charts read **$0.00** here because the workshop's Bedrock model configs carry no price. In your own project you'd set per-token pricing on the model config (**Library → Models**) and this is where it shows up.
- **More charts**: click the **3 selected** menu next to the time range to add **Tokens**, **Time to first token**, **Error rate** and **Request duration**, then **Apply**. Premium (Sonnet) writes longer answers, so its output tokens and request duration run higher than Born (Haiku).

Below the charts, **Group by context** switches the table from per-variation to per-context-kind, and **Export data as CSV** gives you the raw numbers. The **LLM traces** panel at the bottom stays empty in this workshop; it fills in when the observability plugin is installed alongside the AI SDK.

# Questions to ask yourself

- If you had to pick **one** variation based on this data, which would you pick?
- The Premium variation costs more per call (bigger model, more output tokens). Is the positive-feedback delta worth the cost difference? Where would you look to find the cost data?
- What would you change about the data collection? (Are thumbs-up / thumbs-down enough? Would you also want a numeric quality score? Latency thresholds?)

# What happens next

Otto is healthy in `Test`, and that is where Build ends: you created him, gave him a voice, factored that voice into reusable snippets, split him into Free and Premium variations, and read his first production dashboard. The next track, **Evaluate**, starts from exactly this state and asks the harder question: how do you *prove* Otto is good, and what should happen automatically when he isn't?

Click **Check** when you've had a good look around the monitoring view.
