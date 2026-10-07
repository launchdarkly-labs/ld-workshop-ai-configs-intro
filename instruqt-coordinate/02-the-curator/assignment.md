---
slug: the-curator
id: uxaadwkk86gk
type: challenge
title: The Curator
teaser: Build the product-knowledge specialist that Toggle hands off to.
notes:
- type: text
  contents: >-
    Build the Curator: the product-knowledge specialist Toggle hands product questions to. Its instructions start by loading the same product-catalog snippet the claim-accuracy judge uses, so the catalog has one source of truth across agents and judges.
tabs:
- id: 6bukvxckj9hc
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: oiqcrrawqycm
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: dw1grikroewg
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 900
enhanced_loading: null
---

# The first specialist

Toggle routes product questions somewhere. That somewhere is the **Curator**: the Concierge's product specialist. The Curator answers from the catalog and nothing else, and doesn't worry about sounding like Otto. Otto handles that later.

The catalog is already in your project. In Evaluate you created the `product-catalog` snippet and the claim-accuracy judge that grades against it. The Curator's instructions start by loading that same snippet, so the specialist, the judge, and tomorrow's price change all read from one place.

# Create the Config

Open the [LaunchDarkly](#tab-0) tab.

1. **Configs** → **Create config**. Choose **Agent**.
2. For **Name**, enter exactly:
```text
Concierge Curator
```
3. Click **Create**.

# Write the Curator's instructions

1. Name the variation `Default`.
2. **Select model** → **Bedrock** → search `claude-haiku-4-5-20251001` → select **anthropic.claude-haiku-4-5-20251001-v1:0**.
3. For **Description**, enter:
```text
Product specialist. Answers product questions from the ToggleWear catalog and nothing else.
```
4. Click into the empty **Instructions** box, click **Load snippet**, and choose **Product catalog**. A `{{snippet.product-catalog#1}}` chip appears.
<!-- VERIFY: confirm Load snippet is available in the agent-mode Instructions editor and inserts the snippet reference. -->
5. On a new line below it, paste:
```text
You are the Curator, ToggleWear's product specialist. A customer asked a product question and Toggle routed it to you.

Answer from the catalog above and only from the catalog. Name the exact product and price when you can. If the customer asks about something we don't carry, say so plainly and suggest the closest item we do carry. Never invent stock levels, colors, materials, or policies that aren't in the catalog.

Write a complete, factual answer in two to four sentences. Don't worry about tone — a teammate polishes the wording before the customer sees it.
```
6. Click **Review and save**, then **Save changes**.

# Turn the Curator on

1. **Targeting** tab, environment **Test**. Switch the Config **On**.
2. On the **Default rule**, click **Edit**, open **Serve**, choose **Default**.
3. **Review and save**, then **Save changes**.

# Notice the handoff

Read the last paragraph of the instructions again. The Curator is told a teammate will polish the wording. That's the Concierge's division of labor: specialists get the facts right, Otto makes it sound like ToggleWear. You'll see the same sentence on the Tailor and the Tracker.

Click **Check** when the Curator exists in agent mode, loads the product-catalog snippet, and serves Default in Test.
