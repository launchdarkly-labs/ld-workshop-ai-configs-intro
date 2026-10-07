---
slug: otto-returns
id: wmpejyfizund
type: challenge
title: Otto Returns
teaser: Otto joins the Concierge as the brand-voice rewriter — the final node every
  response passes through before reaching the customer.
notes:
- type: text
  contents: >-
    Otto joins the Concierge as the brand-voice rewriter, the final node every response passes through. It's a new agent-mode Config, and its instructions load the very same brand-voice snippet that has driven Otto's prompt since Build and his judge since Evaluate.
tabs:
- id: wjlxv03pk38s
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: cjfpi8y0wvy6
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: mfhffx8uepe3
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 900
enhanced_loading: null
---

# Otto's new job

Three specialists now produce correct, plainly worded drafts. Something has to make them sound like ToggleWear. That something is Otto.

Not the Otto you built in Build. That Config is completion-mode, and it can't join a graph. This is a **new agent-mode Config** that carries Otto's voice into the team: it takes a specialist's draft and the customer's question, and rewrites the draft in Otto's voice without changing a single fact.

The voice comes from where it has always come from. Build put it in the `brand-voice` snippet. Evaluate's brand-voice judge grades against that same snippet. Now the rewriter's instructions load it too. One snippet, three tracks, one definition of "on-brand".

# Create the Config

Open the [LaunchDarkly](#tab-0) tab.

1. **Configs** → **Create config**. Choose **Agent**.
2. For **Name**, enter exactly:
```text
Concierge Otto Rewriter
```
3. Click **Create**.

# Write the rewriter's instructions

The instructions use two placeholders, `{{question}}` and `{{draft}}`. The server fills them in per request in Challenge 07. Keep them exactly as written.

1. Name the variation `Default`.
2. **Select model** → **Bedrock** → search `claude-haiku-4-5-20251001` → select **anthropic.claude-haiku-4-5-20251001-v1:0**.
3. For **Description**, enter:
```text
Brand-voice rewriter. Otto rewrites every specialist draft in his own voice before it reaches the customer.
```
4. Click into the empty **Instructions** box, click **Load snippet**, and choose **Brand voice**. A `{{snippet.brand-voice#1}}` chip appears.
5. On a new line below it, paste:
```text
You are Otto in your new role on ToggleWear's Concierge team: the last stop before a response reaches the customer. A specialist has drafted a factually correct but plainly worded answer. Rewrite it in your own voice.

Rules:
- Keep every fact, number, product name, and caveat from the draft. Don't add facts the draft doesn't contain.
- Keep it short. Two or three sentences is usually right.
- Reply with only the rewritten response — no preamble, no quotation marks, no notes.

Customer's question:
{{question}}

Specialist's draft:
{{draft}}
```
6. Click **Review and save**, then **Save changes**.

# Turn the rewriter on

1. **Targeting** tab, environment **Test**. Switch the Config **On**.
2. On the **Default rule**, click **Edit**, open **Serve**, choose **Default**.
3. **Review and save**, then **Save changes**.

# Two Ottos

Open **Configs** and look at **Otto Assistant** next to **Concierge Otto Rewriter**. Same voice, same snippet, different modes. Otto Assistant keeps serving the ToggleWear app exactly as before until Challenge 07 switches the app over to the graph. Nothing about him changes; the team is built around him.

Click **Check** when the rewriter exists in agent mode, loads the brand-voice snippet, keeps both placeholders, and serves Default in Test.
