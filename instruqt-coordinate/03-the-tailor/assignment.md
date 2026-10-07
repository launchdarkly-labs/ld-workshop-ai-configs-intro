---
slug: the-tailor
id: 24ksygvy8zbc
type: challenge
title: The Tailor
teaser: Add the sizing specialist — the second of three back-of-house agents.
notes:
- type: text
  contents: Add the Tailor, the sizing specialist. Same build as the Curator; the
    difference is entirely in the instructions, which tell the Tailor exactly what
    it knows and, more importantly, what it doesn't.
tabs:
- id: eots4ssderf5
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: dahe4nco9way
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: wgqrzqjupart
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 600
enhanced_loading: null
---

# Same pattern, second specialist

The **Tailor** handles sizing. The build is identical to the Curator's: agent mode, Haiku, one Default variation, turn it on. The only thing that changes is the instructions, and the instructions are where this agent's judgment lives.

Sizing questions are where an assistant is most tempted to guess. The Tailor knows the size ranges we sell, and is told plainly that it does **not** know the customer's measurements. When a question needs that, it says so and points the customer to the size guide. That's Otto's honesty from Build, written into a specialist.

# Create the Config

Open the [LaunchDarkly](#tab-0) tab.

1. **Configs** → **Create config**. Choose **Agent**.
2. For **Name**, enter exactly:
```text
Concierge Tailor
```
3. Click **Create**.

# Write the Tailor's instructions

1. Name the variation `Default`.
2. **Select model** → **Bedrock** → search `claude-haiku-4-5-20251001` → select **anthropic.claude-haiku-4-5-20251001-v1:0**.
3. For **Description**, enter:
```text
Sizing specialist. Handles fit and measurement questions honestly.
```
4. For **Instructions**, paste:
```text
You are the Tailor, ToggleWear's sizing specialist. A customer asked about fit or sizing and Toggle routed it to you.

What you know: ToggleWear apparel runs true to size and is unisex-cut. The Rocket Tee and Feature Branch Crewneck come in XS through XXL. The Feature Flag Hoodie comes in S through XXL. The Dark Mode Cap is one-size with an adjustable strap. Toggle Socks fit US shoe sizes 6 through 13.

You do NOT have the customer's measurements, order history, or a size chart beyond what's above. When a question needs information you don't have, say so and tell the customer what to check (the size guide on the product page, or their own measurements). Never guess a specific size for a specific person.

Write a complete, factual answer in two to four sentences. Don't worry about tone — a teammate polishes the wording before the customer sees it.
```
5. Click **Review and save**, then **Save changes**.

# Turn the Tailor on

1. **Targeting** tab, environment **Test**. Switch the Config **On**.
2. On the **Default rule**, click **Edit**, open **Serve**, choose **Default**.
3. **Review and save**, then **Save changes**.

Click **Check** when the Tailor exists in agent mode with its instructions and serves Default in Test.
