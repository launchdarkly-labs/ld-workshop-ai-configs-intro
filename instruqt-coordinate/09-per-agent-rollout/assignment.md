---
slug: per-agent-rollout
id: dm177zs89d6m
type: challenge
title: Per-Agent Rollout
teaser: Roll out a cheaper model to just one node — Otto-the-rewriter — without touching
  the other agents. Bounded blast radius.
notes:
- type: text
  contents: >-
    Roll a cheaper model out to one node only. Otto-the-rewriter gets a Nova Lite variation behind a guarded rollout watching the brand-voice score; Toggle and the three specialists are never touched. The guard fires, the rewriter rolls back, and the rest of the team never noticed.
tabs:
- id: iiicuu1vg3co
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: qw1psptnuxh4
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: mrzjftnv6o22
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 1200
enhanced_loading: null
---

# The blast radius of a rollout

In Evaluate you guarded a model change to Otto Assistant. That rollout touched every customer response, because Otto was the whole system.

The Concierge is five nodes. A rollout on one of them changes only that node's contribution. In this challenge you put a cheaper model, **Amazon Nova Lite**, on trial for the rewriter alone, behind a guarded rollout watching the same **Otto Brand Voice Score** metric from Evaluate. Toggle, the Curator, the Tailor and the Tracker keep serving their Default variations the entire time.

# What's already in place

- **Concierge Otto Rewriter** has a second variation, **Otto Rewriter (Lite)**, backed by Nova Lite with the same instructions. Setup created it.
- Background traffic is evaluating the rewriter about once every two seconds and emitting an `otto-brand-voice-score` per session, biased by which model served it. Nova Lite's mean is well below Haiku's.

Open the [LaunchDarkly](#tab-0) tab, go to **Configs → Concierge Otto Rewriter**, and look at the two variations. Then open **Configs → Concierge Toggle → Targeting** for comparison: a plain Default rule, nothing on trial.

# Start the guarded rollout

1. Back on **Concierge Otto Rewriter**, click the **Targeting** tab. Confirm the environment pill reads **Test**.
2. On the **Default rule** card, click **Edit**.
3. Open **Serve** and choose **Guarded rollout** (under **Rollout**).
4. Fill in the form:
   - **Original variation**: leave **Default**.
   - **Target variation**: choose **Otto Rewriter (Lite)**.
   - **Metrics to monitor**: click **Select metrics or metric groups** and click **Otto Brand Voice Score** in the search results. The row is added behind the picker; close the picker by clicking anywhere outside it. In the metric row, tick **Automatic rollback**.
   - **Target by**: leave **user**.
   - **Rollout duration**: open the dropdown and choose **Custom**. Set each of the four stages to **1** **minutes**.
5. Click **Review and save**. The dialog reads **Start release on default rule** with Otto Rewriter (Lite) as the rollout and Default as the original variation. Click **Save**.

# Watch one node fail safely

The Default rule card shows the release **In progress** with the current split and a **Stop release** button. As the stages advance and Nova Lite serves more of the rewriter traffic, its brand-voice scores drag the metric down. Within two to three minutes the guard fires:

- The card reads **Default rule rolled back automatically after detecting a regression for Otto Brand Voice Score**.
- The rewriter snaps back to **Default** on Haiku.

While that's happening, open **Configs → Concierge Curator → Targeting** in another look. Nothing changed. The Curator never knew there was a rollout. That is the point of per-agent rollouts: the risk is scoped to the node you're changing.

Click **Check** when the guarded rollout on Concierge Otto Rewriter is running or has already rolled back, and the other four agents are untouched.
