---
slug: the-tracker
id: 4zgkkggyhaj6
type: challenge
title: The Tracker
teaser: Add the order-status specialist — the third back-of-house agent completes
  the Concierge's middle tier.
notes:
- type: text
  contents: 'Add the Tracker, the order-status specialist, and the Concierge has all
    three back-of-house agents. The Tracker''s instructions are the strictest of the
    three: it has no access to orders and must never pretend it does.'
tabs:
- id: aegyhvbamcet
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: edoxed08d4l1
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: 4novgbryc7xw
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 600
enhanced_loading: null
---

# The third specialist

The **Tracker** handles orders, shipping, returns, and payments. It's the specialist with the strongest temptation to make things up, because customers ask it for things it can't see: *where's my order?* The Tracker has no access to orders, and its instructions say so in capitals. It knows the policies and it knows exactly what to tell a customer to do next.

With the Tracker in place, Toggle's three routes each have somewhere to go.

# Create the Config

Open the [LaunchDarkly](#tab-0) tab.

1. **Configs** → **Create config**. Choose **Agent**.
2. For **Name**, enter exactly:
```text
Concierge Tracker
```
3. Click **Create**.

# Write the Tracker's instructions

1. Name the variation `Default`.
2. **Select model** → **Bedrock** → search `claude-haiku-4-5-20251001` → select **anthropic.claude-haiku-4-5-20251001-v1:0**.
3. For **Description**, enter:
```text
Order-status specialist. Handles orders, shipping, and returns without inventing data.
```
4. For **Instructions**, paste:
```text
You are the Tracker, ToggleWear's order and shipping specialist. A customer asked about an order, delivery, a return, or a payment, and Toggle routed it to you.

What you know: standard shipping takes 3-5 business days within the US; international shipping takes 7-14 business days; returns are accepted within 30 days for unworn items with tags; refunds post to the original payment method within 5-7 business days of the return arriving.

You do NOT have access to the customer's order, tracking number, or account. Never claim to have looked anything up and never invent an order status, a date, or a tracking number. When the customer needs their specific order, tell them exactly what to do: check the confirmation email for the tracking link, or contact support@togglewear.example with the order number.

Write a complete, factual answer in two to four sentences. Don't worry about tone — a teammate polishes the wording before the customer sees it.
```
5. Click **Review and save**, then **Save changes**.

# Turn the Tracker on

1. **Targeting** tab, environment **Test**. Switch the Config **On**.
2. On the **Default rule**, click **Edit**, open **Serve**, choose **Default**.
3. **Review and save**, then **Save changes**.

# Three specialists, three Configs

Look at the **Configs** list. Four Concierge Configs, all agent mode, all on Haiku, each with a single tightly scoped job. In the next challenge the fifth one arrives, and it's someone you know.

Click **Check** when the Tracker exists in agent mode with its instructions and serves Default in Test.
