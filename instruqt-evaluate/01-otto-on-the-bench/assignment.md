---
slug: otto-on-the-bench
id: hvxtrzt1nel4
type: challenge
title: Otto on the Bench
teaser: Run an offline evaluation against a golden dataset of customer questions to
  see how Otto performs before any production traffic.
notes:
- type: text
  contents: Otto is built and on-brand, but how do we know he's good? In this challenge
    you'll run him through 30 labeled customer questions, grade his answers with an
    LLM-as-a-judge, and read the results to spot where he's weak. Knowing where Otto
    slips is what makes everything that follows — built-in judges, custom judges,
    experiments, guarded rollouts — useful.
tabs:
- id: qhyrqbdxzwcm
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: l7zeajhisjha
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: x4by7yxkmroz
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 900
enhanced_loading: null
---

# Otto on the bench

Otto is in his post-Build form — born, given personality, refactored on-brand, premium variation in place, monitoring data flowing. The natural next question is whether he's actually any good.

Before we look at production behavior (next challenge, with built-in judges), we'll grade Otto **offline**. Offline evaluation runs a curated dataset of customer questions through Otto and tells you how often he answers well, where he's weak, and where he drifts off-brand — without sending real traffic.

A 30-question dataset is already in your project. Your job is to point an evaluation at it, set the grading rubric, and read what comes back. The dataset deliberately mixes easy product questions ("Got any t-shirts?") with hard ones — off-topic queries, ambiguous requests, even a prompt-injection attempt — so the results tell a story rather than a flat all-pass. Datasets can be found in **Library** --> **Datasets**. You'll be able to explore the data in the playground, which we'll create next.

# Create the evaluation

1. From the left-hand navigation, where you see the **Code | Agents** selector, click **Agents**
1. Click **Playgrounds** in the left navigation.
2. Click **New playground**.
3. Click **Untitled playground** at the top, select the existing text, and replace it with:
```text
Otto Born baseline
```

# Side **A**

1. Click the ![Load Config](../assets/otto-load-config.png) icon to load from a config.
2. Click **Otto Assistant** on the left, then open **Select a variation** on the right and choose **Otto (Born)**.
3. Click **Load config**.
4. Loading the config copies the variation's Bedrock model (**anthropic.claude-haiku-4-5-20251001-v1:0**) into side A. Playground runs in this workshop account go through LaunchDarkly's Anthropic connection rather than Bedrock, so swap it for the same model on the Anthropic provider: click the model selector at the top of side A, click **Anthropic** at the top of the **Select model** dialog, type the text below into **Search models...**, and click the single match.
```text
claude-haiku-4-5-20251001
```
   This only changes which API key the playground uses to call Haiku 4.5. Otto's variation in production still runs on Bedrock.
5. Loading the config replaced the column's messages with the variation's system prompt, so add the customer turn back: below the prompt, click **Add message**. The new message defaults to the **User** role with placeholder text.
6. Select all of the placeholder text in the new message and replace it with:
```text
{{input}}
```

# Side **B**

1. Click the ![Load Config](../assets/otto-load-config.png) icon to load from a config.
2. Click **Otto Assistant** on the left, then open **Select a variation** on the right and choose **Otto (Premium)**.
3. Click **Load config**.
4. Side B now shows the variation's Bedrock model (**anthropic.claude-sonnet-4-6**). Swap it the same way: click the model selector, click **Anthropic**, search for the text below, and click the match.
```text
claude-sonnet-4-6
```
5. Loading the config replaced the column's messages with the variation's system prompt, so add the customer turn back: below the prompt, click **Add message**. The new message defaults to the **User** role with placeholder text.
6. Select all of the placeholder text in the new message and replace it with:
```text
{{input}}
```

# Select Dataset

1. At the bottom of the screen, grab and drag the dark gray bar up so you can see the controls.
2. Click **Select a dataset (optional)**, and select **Otto Born baseline**.
3. To the right of the selector, click **Random**. In the **Rows** field next to it (it defaults to 5), enter **15**.

# Configure acceptance criteria

The evaluation needs to know how to grade Otto's responses against each row's `expected_output`. You'll set up one criteria: a grader that checks for relevancy.

**Note**: If the right-hand pane is still collapsed, press `]` to open it.

1. In the **Acceptance criteria** panel on the right, click **Add criteria** and select **Answer Relevancy**.
2. Leave the defaults as-is (pass when score ≥ 0.5, minimum pass rate 95%).

# Run the evaluation

1. At the top right, click **Run all**. This saves both sides and starts one run per side.
2. The run takes roughly a minute — both versions of Otto answer each of the 15 sampled questions and the judge grades each answer.

# Read the results

Once the run completes, the results panel shows the overall score plus per-row results. Scan the failures. Some patterns you should see:

- **Off-topic and tricky rows** are where Otto is most likely to slip — he may engage with the weather question or apologize too much on the broken-mug row.
- **Sizing and policy rows** pass if Otto honestly says he doesn't know; they fail when he invents stock or refund terms.
- **Product info** rows mostly pass — these are squarely in Otto's wheelhouse.

Find at least one row Otto answered well and one where he didn't. Knowing exactly where Otto is weak is what makes the next four challenges land — built-in judges, custom judges, experiments, and guarded rollouts all depend on you having an opinion about what "good" looks like.

Click **Check** when you've run the evaluation and reviewed the results.
