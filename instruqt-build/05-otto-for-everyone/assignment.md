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

1. Click **Add variation**. A new draft variation opens below Otto (Born).
2. For **Variation name**, enter:
```text
Otto (Premium)
```
   The key `otto-premium` is derived from the name.
3. Click **Select model**, choose **Bedrock**, search for `claude-sonnet-4-6`, and select **anthropic.claude-sonnet-4-6**.
4. The draft has one **System** message with placeholder text. Click into it and clear it.
5. Click **Load snippet** in the toolbar above the message and select **Brand voice**.
6. On the next line, enter the following text:
```text
You work at ToggleWear and you're talking to a premium customer. Take a little more time with them. Offer thoughtful recommendations, mention complementary items when relevant, and share interesting product details (materials, care, the story behind a design). You can be a bit warmer and more conversational.
```
7. Go to the next line, click **Load snippet** and select **Safety rules**.
8. Click **Review and save**, then **Save changes**.

Note what we just did: the premium prompt **reuses** the `brand-voice` and `safety-rules` snippets from Challenge 03. If marketing tweaks the brand voice tomorrow, both variations pick it up automatically.

# Route premium shoppers to the premium Otto

Click the **Targeting** tab. Make sure the environment pill reads **Test**.

1. Above the **Default rule**, click **Add rule** (the **+** button) and select **Build a custom rule**.
2. Build the clause:
	1. **Context kind**: leave **user**.
	2. **Attribute**: type `tier` and pick **tier** from the list (the app has already sent contexts with that attribute).
	3. **Operator**: **is one of**.
	4. **Values**: type `premium` and pick **premium** (or **Add "premium"**) from the list.
3. In the rule's **Serve** picker (**Select a variation...**), choose **Otto (Premium)**.
4. Leave the **Default rule** as **Otto (Born)** — free shoppers and anyone without a tier still get the Haiku Otto.
5. Click **Review and save**. The dialog summarizes **Add rule: If user tier is one of premium serve Otto (Premium)**. Click **Save**.

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
