---
slug: otto-for-everyone
id: g30fyyv1yqbx
type: challenge
title: Otto for Everyone
teaser: Free shoppers and premium shoppers want different things. Give them different
  Ottos with variations and targeting.
notes:
- type: text
  contents: Premium ToggleWear members get the white-glove treatment everywhere else
    on the site — Otto should be no exception. In this challenge you'll add a second
    variation backed by a more capable model, then target it to premium shoppers.
tabs:
- id: xdd3ix1smwzk
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: mvtzoyp0p2v9
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: h9jtwghly3x1
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 900
enhanced_loading: null
---

# Two audiences, two Ottos

Free shoppers and premium ToggleWear members get different treatment everywhere else on the site. Otto should be no exception. Premium customers get more time, more detail, and a more capable model behind the answers.

We're going to:

1. Add a second variation backed by **Claude Sonnet 4.6** with a richer premium-tier prompt.
2. Add a **targeting rule** that routes premium customers to that variation. Free shoppers keep getting the Haiku-backed Otto from the earlier challenges.
3. Test by flipping the user-tier dropdown on ToggleWear.

# Add the premium variation

Open the [LaunchDarkly](#tab-0) tab. Go to **Configs** → **Otto Assistant**.

1. Click **Add variation**.
2. For **Name**, enter:
```text
Otto (Premium)
```
3. For **Key**, confirm or enter:
```text
otto-premium
```
4. Click **Select model**, **search** for and select
```
anthropic.claude-sonnet-4-6
```
5. In prompt text area, make sure **System** is selected and clear the prompt.
6. Click **Load snippet** and select **Brand voice**.
7. On the next line, enter the following text:

```text
You work at ToggleWear and you're talking to a premium customer. Take a little more time with them. Offer thoughtful recommendations, mention complementary items when relevant, and share interesting product details (materials, care, the story behind a design). You can be a bit warmer and more conversational.
```
7. Go to the next line, click **Load snippet** and select **Safety rules**.
8. Click **Review and save**, then **Save changes**.

Note what we just did: the premium prompt **reuses** the `brand-voice` and `safety-rules` snippets from Challenge 03. If marketing tweaks the brand voice tomorrow, both variations pick it up automatically.

# Route premium shoppers to the premium Otto

Click the **Targeting** tab. Make sure the environment selector reads **test**.

1. Above the **Default rule**, click **+** and select **Build a custom rule**.
2. Build the clause:
	1. Context kinds: **user**
	2. Attribute: **tier**
	3. Operator: **is one of**
	4. Values: **premium** _&lt;ENTER&gt;_
3. For the variation dropdown, select **Otto (Premium)**.
4. Leave the **Default rule** as **Otto (Born)** — free shoppers and anyone without a tier still get the Haiku Otto.
6. Click **Review and save**, then **Save changes**.

# See it work

Open the [ToggleWear](#tab-1) tab. The header has a **Logged in as** dropdown. It defaults to **Free user**.

1. With **Free user** selected, click **Chat with Otto** and ask a question:
```text
What's good for cold weather?
```
Otto should be brief and friendly — that's the Haiku-backed Born variation.

2. Close the chat. At the top right of the page, change the dropdown to **Premium user**.

3. Re-open and reset the chat and ask the same question. Otto should answer at more length, mention complementary items, and feel a bit warmer — that's the Sonnet-backed Premium variation, served because the LaunchDarkly context now has `tier: "premium"` and the rule you just added matches it.

The app's code didn't change. The variation you served changed because LaunchDarkly evaluated the targeting rule against the context.

Click **Check** when you're satisfied.
