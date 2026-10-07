---
slug: quick-takes
id: xk4ekaxytv61
type: challenge
title: Quick Takes from a Built-in Judge
teaser: Attach AgentControl's built-in judges to Otto and watch scores populate the
  monitoring view in near real time.
notes:
- type: text
  contents: Offline evaluation graded Otto against a curated dataset. That's useful
    before shipping, but you also want continuous quality signal in production. Built-in
    judges fill that role — they're pre-configured LLM judges you can attach to any
    completion-mode variation in 30 seconds, no code changes required.
tabs:
- id: 9br0bxlsohok
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: yolvoiahzvcy
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: e2waiwhemjlb
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 600
enhanced_loading: null
---

# What built-in judges are

AgentControl ships three pre-configured LLM-as-a-judge evaluators that you can attach to a completion-mode variation in a couple of clicks:

| Judge | What it scores |
|---|---|
| **Accuracy** | Whether the response is correct and grounded |
| **Relevance** | Whether the response addresses the user's request |
| **Toxicity** | Whether the response contains harmful or unsafe phrasing (lower = safer) |

When a judge is attached, the SDK fires it automatically against a configurable percentage of Otto's responses. The scores show up as metrics in the monitoring view, ready to drive dashboards, alerts, or — in a couple of challenges — guarded rollouts.

A low-rate stream of chat traffic is already flowing in the background, so by the time you finish attaching the judges, scores will be visible.

# Attach the judges

Open the [LaunchDarkly](#tab-0) tab.

1. Go to **Configs** → **Otto Assistant**. The **Otto (Born)** variation is expanded at the top of the **Variations** tab.
2. Below the prompt, next to **Add message** and **Add tools**, click **+ Add judges**.
3. Check **All judges** (or check **Accuracy**, **Relevance**, and **Toxicity** individually), then click **Add 3 judges**.
4. A **Judges** table appears under the prompt with one row per judge, showing its **Event key** (`$ld:ai:judge:accuracy` and so on), a **Provider** dropdown, and a **Sampling percentage** that defaults to 10%. Set each sampling percentage to **25**.
5. At the top right, click **Review and save**, then **Save changes**.

Adding the judges also created three judge-mode configs in your project — **Accuracy**, **Relevance**, and **Toxicity** — which you'll see in the Configs list. Those are the judges themselves; what you attached to Otto (Born) is a reference to each one plus a sampling rate.

# Watch the scores

The background traffic generator is sending Otto ~20 questions per minute. At 25% sampling, each judge fires roughly 5 times a minute — fast enough that within a couple of minutes the monitoring view has visible data.

1. Click the **Monitoring** tab and confirm the environment pill reads **Test**.
2. Three new chart cards sit below the cost and request cards: **$ld:ai:judge:accuracy**, **$ld:ai:judge:relevance**, and **$ld:ai:judge:toxicity**. They appear automatically once judges are attached. If you don't see them, open the **Charts** selector and check **Accuracy**, **Relevance**, and **Toxicity**.
3. Within a couple of minutes each card starts plotting scores, and the per-variation table at the bottom gains **Accuracy**, **Relevance**, and **Toxicity** columns.

Give it a minute or two if scores haven't appeared yet. The first scores typically land within 60-90 seconds of attaching the judges.

# Read what you see

A few questions to sit with:

- Which judge has the **highest** score on average? Which the lowest? Why might that be — what does Otto's current prompt do well, and where might it be slipping?
- Toxicity is a **safety** signal, not a quality one. A toxicity score of ~1.0 (with `isInverted` accounting) means Otto is clean. Is he?
- Accuracy and Relevance are correlated but not identical. Where might they diverge — what would a response that's relevant but inaccurate look like?

You won't fix anything in this challenge — observation is the point. The next two challenges write **custom** judges for the brand-voice and product-claim signals that the built-ins don't cover.

Click **Check** when at least one built-in is attached to Otto (Born).
