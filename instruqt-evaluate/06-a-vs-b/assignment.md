---
slug: a-vs-b
id: 5qur6sxcwjlz
type: challenge
title: A vs. B
teaser: Run a prompt experiment comparing two Otto variations on live traffic, read
  the results panel, and promote the winner.
notes:
- type: text
  contents: You've measured Otto in production (built-in + custom judges) and you've
    measured him offline (the dataset eval). What you haven't done yet is compare
    two versions of Otto head-to-head on real traffic. That's what experiments are
    for — split traffic, watch a metric, promote the winner.
tabs:
- id: ichjegaatnae
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: p3mma8zpqvrg
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: loi0ct9gsvcw
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 900
enhanced_loading: null
---

# The experimental question

Otto's current prompt is concise — the brand-voice snippet says "keep answers short by default." But maybe being short trades off against being **helpful**. What if Otto proactively suggested one complementary item when someone asks about a product? Does that read as more helpful (good), or as more pushy and less concise (bad)?

You can argue either side from the prompts alone. That's the whole point. Run an experiment, let the brand-voice judge decide.

# Add the contender variation

Open the [LaunchDarkly](#tab-0) tab. Go to **Configs** → **Otto Assistant**.

1. At the bottom of the variations list, click **Add variation**. A new **Untitled variation** card opens in **Draft** state.
2. For the variation name, enter:
```text
Otto (Recommender)
```
   There is no key field; LaunchDarkly derives the key `otto-recommender` from this name.
3. Click **Select model**, type `haiku-4-5-20251001` in the search box, and select:
```
anthropic.claude-haiku-4-5-20251001-v1:0
```
4. In the prompt area, make sure **System** is selected, then select all of the placeholder text and delete it.
5. Click **Load snippet** and select **Brand voice**.
6. On the next line, enter the following text:
```text
You work at ToggleWear, an online shop for LaunchDarkly-branded apparel. Help customers find products, answer questions about sizing and care, and guide them when they're not sure what they want. When recommending a product, briefly mention one complementary item from the catalog that pairs well with it — keep it natural, not pushy.
```
7. Go to the next line, click **Load snippet** and select **Safety rules**.
8. Click **Review and save**, then **Save changes**.

Compare this prompt to **Otto (Born)**'s in the same UI. The only delta is one sentence about complementary items. Everything else — brand voice, safety, model — is identical.

# Create the experiment

1. From the left-hand navigation, under **Experimentation**, click **Experiments**.
2. In the upper right-hand corner, click **Create experiment**.
3. **Experiment name**:
```text
Otto Prompt Experiment
```
4. **Hypothesis**:
```text
Adding a one-sentence prompt to suggest a complementary item improves brand-voice score without going off-brand.
```
5. Click **Create experiment**. The experiment key `otto-prompt-experiment` is derived from the name. You land on the **Design** tab with a banner reading **Experiment design is not complete**.
6. Under **Name and hypothesis**, check the **Hypothesis** box. If it came through empty, paste the hypothesis again; the design can't be saved without it.
7. Under **Variations and audience targeting**:
  * **Assignment method**: leave **LaunchDarkly flag or config**.
  * **Flag or config**: click **Find a flag or config by name or key** and select **otto-assistant** (listed under Configs).
  * **Targeting rule**: leave **Default Rule**. The caption reads *All user contexts will be targeted*.
  * **Randomize by**: leave **user**.
8. Under **Audience allocation**:
  * **Variation served to user contexts outside this experiment**: leave **Otto (Born)**.
  * **Percent of user contexts in this experiment**: click **100%**.
9. Under **Variations split**, all three variations start at roughly 33% each. Click **Edit**, and in the **Variation Split** dialog:
  * Untick **Otto (Premium)**.
  * Click **Split equally** so **Otto (Born)** and **Otto (Recommender)** read 50% each.
  * Click **Save audience split changes**.
  * Back on the page, make sure **Control** shows **Otto (Born)**.
10. Under **Metrics**:
  * **Metric source**: leave **LaunchDarkly hosted**.
  * Click **Select metrics or metric groups**, tick **Otto Brand Voice Score**, and click **Done**. It becomes the primary metric.
11. Under **Statistical approach and success criteria**, open **Statistical approach** and choose **Bayesian**. Leave everything else at the default value.
12. At the top of the page, click **Save**. The banner changes to **Experiment design is complete**.

# Start the iteration

The experiment is created in a draft state. To begin collecting data, start the first iteration.

* In the banner at the top of the **Design** tab, click **Start**, then confirm with **Start experiment**. The page switches to the **Results** tab and the banner shows the experiment running.

> A background traffic generator is already firing — about two simulated users per second, each scored by the brand-voice judge. Once the iteration starts, traffic splits ~50/50 between the two variations. After a minute or two, the results panel will have enough data to call a winner.

# Read the results

1. Stay on the **Results** tab (the **Design**, **Exposures**, and **Iterations** tabs sit alongside it).
2. Watch the per-treatment scores accumulate. The contender's confidence interval will start wide and tighten as samples accumulate.
3. Once the panel shows a clear winner (one treatment outside the other's confidence interval), you're done.

What you should see, given how the brand-voice judge weights "warm + helpful + concise":

- If the recommender's extra-helpful pitch outweighs the conciseness penalty, **Recommender wins**.
- If the brand voice's "keep answers short by default" dominates, **Born wins**.
- The metric tells you which is true. Reading the prompts alone wouldn't have.

# Promote the winner

1. At the top of the experiment, open the **Stop** menu. It lists each variation in the experiment (**Otto (Born)** marked *Control*, and **Otto (Recommender)**) plus **Request approval to stop**. Choose the variation that won.
2. In the **Stop experiment** dialog, confirm the **Variation to ship**, write a short **Reason for stopping**, type `test` in the **Environment** box, and click **Stop experiment**.
3. The Otto Assistant **Targeting** tab's Default rule now serves the shipped variation to everyone, and the experiment's status changes to stopped.

Click **Check** when the experiment exists with at least one iteration started.
