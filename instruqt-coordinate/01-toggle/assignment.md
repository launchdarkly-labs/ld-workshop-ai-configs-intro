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

An agent-mode Config has one **Agent task** string (the API calls it `instructions`) instead of a system/user/assistant message list. The SDK hands your code that string plus the model to run it on; your code decides what to do with it. In this track, that decision is made by the graph you build in Challenge 06.

One thing to notice as you create it: the **Create config** dialog asks for a mode up front, and once you pick it you can't change it. Otto is completion-mode for good. Toggle will be agent-mode for good.

# Create the Config

Open the [LaunchDarkly](#tab-0) tab.

1. From the left-hand navigation, click **Configs**, then click **Create config** at the top right.
2. In the **Create config** dialog, choose **Agent** from the mode selector.
3. For **Name**, enter exactly:
```text
Concierge Toggle
```
   The key `concierge-toggle` appears under the name as you type (there's an **Edit key** link if it ever differs). The server code in Challenge 07 looks the graph's nodes up by key, so the key has to be exact.
4. Click **Create**. You land on the new Config's **Variations** tab with an untitled variation open.

# Write Toggle's instructions

An agent variation has one text box, **Agent task**: the instructions the model is given. That's the whole difference from a completion variation's message list. Toggle's instructions are deliberately strict: he classifies, he doesn't chat.

1. For the variation name, enter:
```text
Default
```
2. Click **Select model**, choose **Bedrock**, search for `haiku-4-5-20251001`, and select **us.anthropic.claude-haiku-4-5-20251001-v1:0** (the only `us.` entry). A **Region** pill reading `global` appears next to the model; leave it.
3. Click into the **Agent task** box and paste:
```text
You are Toggle, the front desk of ToggleWear's Concierge team. ToggleWear is an online shop for LaunchDarkly-branded apparel.

Your only job is to read the customer's message and decide which specialist should handle it:
- product — questions about what we sell: items, prices, colors, materials, recommendations, gifts.
- sizing — questions about fit, measurements, which size to pick, how something runs.
- orders — questions about an order, shipping, delivery, returns, refunds, or payment.

Respond with exactly one lowercase word: product, sizing, or orders. No punctuation, no explanation, nothing else. If the message is off-topic or you can't tell, respond with product.
```
5. Click **Review and save**, then **Save changes**.

# Confirm Toggle is on

A config's first saved variation is served automatically: the config is switched **On** in **Test** and the **Default rule** serves **Default**. Confirm it rather than assume it.

1. Click the **Targeting** tab and make sure the environment pill reads **Test**.
2. Check that the config is **On** and the **Default rule** reads **Serve Default**. If either is off, fix it (switch **On**; **Default rule → Edit → Serve → Default**), then **Review and save** and **Save changes**.

# Why this is overkill, on purpose

A one-word classifier doesn't need an agent-mode Config. A completion Config would do it. We're using agent mode anyway because Toggle has to be a **node in a graph**, and only agent-mode Configs can be graph nodes. Mode-permanence means that decision had to be made now, at creation, not later.

Click **Check** when Toggle exists in agent mode, has his agent task, and serves Default in Test.
