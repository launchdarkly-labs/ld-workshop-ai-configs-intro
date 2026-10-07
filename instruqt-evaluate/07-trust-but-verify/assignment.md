---
slug: trust-but-verify
id: ghx4xfduw9h3
type: challenge
title: Trust But Verify
teaser: Roll out a risky new model behind a guarded rollout backed by the brand-voice
  judge — watch it auto-revert when quality drops.
notes:
- type: text
  contents: A new model came in from the vendor — Amazon Nova Pro. Marketing wants
    to try it. You want to try it too, but only if it doesn't make Otto sound off-brand.
    This is exactly what guarded rollouts are for — ship the change behind a metric,
    let it watch for regression, and automatically roll back if quality drops. The
    brand-voice judge you built in Challenge 03 is the metric.
tabs:
- id: dkhfq60shwai
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: 9cdmd2dpvhfc
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: w9h19hyf1itj
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 1200
enhanced_loading: null
---

# What's already in place

Most of this challenge is already wired:

- A new variation, **Otto (Formal)**, has been added to Otto Assistant. It's backed by Amazon Nova Pro and has a deliberately corporate-sounding prompt — formal greetings, formal sign-offs, the works.
- Background traffic is flowing at ~1 session every 2 seconds. Each session emits an `otto-brand-voice-score` event biased by which model served it. Formal's mean is well below the others.
- The brand-voice judge from Challenge 03 is already invoking on every real `/chat` call and contributing real scores too.

Your job is to **configure a guarded rollout** that splits traffic between Otto (Born) and Otto (Formal), watches the `otto-brand-voice-score` metric, and rolls back automatically if Formal's score regresses.

# Inspect what changed

1. Open the [LaunchDarkly](#tab-0) tab.
2. Go to **Configs → Otto Assistant**.
3. Notice the new variation **Otto (Formal)** in the list. Click it to see the prompt — explicitly formal, the opposite of the brand voice.
4. Click the **Monitoring** tab and select **otto-brand-voice-score**. You should see scores accumulating — most of them in the high range (since most traffic still goes to Born), with no contribution from Formal yet because Formal isn't being served to anyone.

# Start the guarded rollout

1. Click the **Targeting** tab. Confirm the environment pill reads **Test**.
2. On the **Default rule** card, click the pencil (**Edit**) icon.
3. Open the **Serve** dropdown. It groups **Variation** (each Otto variation), **Rollout** (**Manual percentage**, **Progressive rollout**, **Guarded rollout**), and **Optimize** (**Experiment**). Choose **Guarded rollout**.
4. A guarded rollout form appears under the rule. Fill it in:
   - **Original variation**: leave it as the variation the Default rule currently serves. If you shipped the experiment winner in Challenge 06, that is **Otto (Recommender)**; otherwise it is **Otto (Born)**.
   - **Target variation**: choose **Otto (Formal)**.
   - **Metrics to monitor**: click **Select metrics or metric groups** and click **Otto Brand Voice Score** in the search results. The row is added to the form behind the picker as soon as you click it; close the picker by clicking anywhere outside it (pressing Escape can undo the selection). In the metric row that appears, tick **Automatic rollback**. (Rollback direction comes from the metric itself: its success criterion is *higher is better*, so a drop counts as a regression.)
   - **Target by**: leave **user**.
   - **Rollout duration**: open the dropdown (it defaults to **24 hours**) and choose **Custom**. Four stages appear (5%, 10%, 25%, 50%). Set each stage's interval to **1** and its unit to **minutes** so the whole rollout fits inside the lab.
5. Click **Review and save**. The **Save changes** dialog summarizes it as **Start release on default rule** with the rollout, original variation, duration, and metric. A **Health check warnings** notice about thin data is expected here. Click **Save**.

# Watch what happens

The Default rule card now shows the release **In progress**: the current split (5% **Otto (Formal)**, 95% the original variation), the stage timeline with time remaining, a **Stop release** button, and **Not enough data, analysis pending until minimum sample size is reached** under the metric. Background traffic flows through, and the brand-voice score for the Formal variation lands much lower than for Born. Regression detection needs a minimum sample on the Formal side, so it typically fires two to three minutes in, once the rollout reaches the 25-50% stages.

When it does:

- The Default rule card reads **Default rule rolled back automatically after detecting a regression for Otto Brand Voice Score**, with a **Review regression** link and the metric chart showing Formal's score well below the original variation.
- Traffic snaps back to 100% of the original variation. The Formal variation gets dropped.
- The monitoring view's brand-voice-score graph shows the dip during the rollout phase, then recovery after rollback.

If you'd rather not wait, **Stop release** opens a dialog with two choices: **Roll forward** (serve Otto (Formal)) or **Roll back** (serve the original variation). That's the manual version of what the guard does for you.

# If you want to force it

Background traffic is intentionally low-rate so the lab fits in the time budget but doesn't burn through tokens. If the rollback doesn't fire fast enough for demo pacing, run the sabotage script from a terminal:

```bash
/opt/ld/ai-configs-intro/app/.venv/bin/python3 /opt/ld/ai-configs-intro/traffic-generator/sabotage.py
```

It emits 60 low-score events directly. The rollback usually fires within a minute of the sabotage finishing.

# What you just saw

A risky model entered production behind a metric guard. The judge you wrote in Challenge 03 — the one whose criteria came from a snippet you wrote in Build — caught the regression and rolled it back without you watching. That's the whole point: when the safety net runs itself, you can ship more aggressively.

Click **Check** when the guarded rollout is configured and running.
