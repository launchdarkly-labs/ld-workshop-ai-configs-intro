---
slug: toggle
id: xpzkq3w5ezzk
type: challenge
title: Toggle the Triage Agent
teaser: Build your first agent-mode Config — and feel the mode-permanence constraint
  that makes the rest of this track make sense.
notes:
- type: text
  contents: 'Build your first agent-mode Config. Toggle is the Concierge''s front
    desk: he reads each customer message and names the specialist who should handle
    it. Along the way you''ll see the mode selector that can''t be changed later,
    which is the reason Otto himself can''t simply be converted.'
tabs:
- id: jdt2qoxhqax0
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: xxmb3dk99a6n
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: 40hmsbcxexmo
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 900
enhanced_loading: null
---

# Where Otto is now

Otto has had quite a run. In Build he was born, got his voice from the `brand-voice` snippet, learned to tell Free from Premium customers, and started reporting on himself. In Evaluate he was graded offline, judged online, experimented on, guarded during a risky rollout, and taught to fall back to a safe variation when his scores slipped. Your project already contains all of it, and the [ToggleWear](#tab-1) app is answering as Otto right now.

He's good at his job. He's also alone. Every customer question, whatever it's about, lands on one prompt and one model.

Otto is a **completion-mode** Config, and a Config's mode is permanent. Agent mode, which gives a Config a single `instructions` string, tools, and a place in an **agent graph**, is a different kind of Config. You can't flip Otto over; you can only build around him. So in this track you'll build a team around him: the **Concierge**.

| Agent | Role | Mode |
|---|---|---|
| **Toggle** | Front desk. Reads the customer's message and names the specialist who should handle it. | agent |
| **Curator** | Product specialist. Answers from the catalog, and only from the catalog. | agent |
| **Tailor** | Sizing specialist. Honest about what it doesn't know. | agent |
| **Tracker** | Orders and shipping specialist. Never invents an order status. | agent |
| **Otto** | Brand-voice rewriter. Every specialist's draft passes through him before the customer sees it. | agent (a new Config; the original Otto stays as he is) |

Topology: `Toggle → (Curator | Tailor | Tracker) → Otto → customer`

# Why Toggle comes first

Toggle is the front desk. Every customer message starts with him, and his only job is to say which specialist should take it. That makes him the simplest agent in the Concierge, and the right place to meet **agent mode**.

An agent-mode Config has one **Instructions** string instead of a system/user/assistant message list. The SDK hands your code that string plus the model to run it on; your code decides what to do with it. In this track, that decision is made by the graph you build in Challenge 06.

One thing to notice as you create it: the **Create config** dialog asks for a mode up front, and once you pick it you can't change it. Otto is completion-mode for good. Toggle will be agent-mode for good.

# Create the Config

Open the [LaunchDarkly](#tab-0) tab.

1. From the left-hand navigation, click **Configs**, then click **Create config** at the top right.
2. In the **Create config** dialog, choose **Agent** from the mode selector.
3. For **Name**, enter exactly:
```text
Concierge Toggle
```
   LaunchDarkly derives the key `concierge-toggle` from the name. The server code in Challenge 07 looks the graph's nodes up by key, so the name has to be exact.
<!-- VERIFY: confirm the agent-mode Create dialog derives the key from the name and whether an "Edit key" control is shown; if the derived key differs, add a step here. -->
4. Click **Create**. You land on the new Config's **Variations** tab with an untitled variation open.

# Write Toggle's instructions

An agent variation has a **Description** (what this agent is for, shown to teammates) and **Instructions** (what the model is told). Toggle's instructions are deliberately strict: he classifies, he doesn't chat.

1. For the variation name, enter:
```text
Default
```
2. Click **Select model**, choose **Bedrock**, search for `claude-haiku-4-5-20251001`, and select **anthropic.claude-haiku-4-5-20251001-v1:0** (the first match).
3. For **Description**, enter:
```text
Triage. Reads the customer's message and names the specialist who should handle it.
```
4. For **Instructions**, paste:
```text
You are Toggle, the front desk of ToggleWear's Concierge team. ToggleWear is an online shop for LaunchDarkly-branded apparel.

Your only job is to read the customer's message and decide which specialist should handle it:
- product — questions about what we sell: items, prices, colors, materials, recommendations, gifts.
- sizing — questions about fit, measurements, which size to pick, how something runs.
- orders — questions about an order, shipping, delivery, returns, refunds, or payment.

Respond with exactly one lowercase word: product, sizing, or orders. No punctuation, no explanation, nothing else. If the message is off-topic or you can't tell, respond with product.
```
<!-- VERIFY: confirm the agent-mode variation editor shows "Description" and "Instructions" fields (no Add message / role selector) and that the model picker is the same dialog as completion mode. -->
5. Click **Review and save**, then **Save changes**.

# Turn Toggle on

A new Config serves a built-in **disabled** variation until you tell it otherwise.

1. Click the **Targeting** tab and confirm the environment pill reads **Test**.
2. Switch the Config **On**.
3. On the **Default rule**, click **Edit**, open **Serve**, and choose **Default**.
4. Click **Review and save**, then **Save changes**.

# Why this is overkill, on purpose

A one-word classifier doesn't need an agent-mode Config. A completion Config would do it. We're using agent mode anyway because Toggle has to be a **node in a graph**, and only agent-mode Configs can be graph nodes. Mode-permanence means that decision had to be made now, at creation, not later.

Click **Check** when Toggle exists in agent mode, has his instructions, and serves Default in Test.
