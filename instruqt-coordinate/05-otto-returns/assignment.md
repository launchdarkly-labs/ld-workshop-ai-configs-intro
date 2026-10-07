---
slug: otto-returns
id: wmpejyfizund
type: challenge
title: Otto Returns
teaser: Otto joins the Concierge as the brand-voice rewriter — the final node every
  response passes through before reaching the customer.
notes:
- type: text
  contents: Otto joins the Concierge as the brand-voice rewriter, the final node every
    response passes through. It's a new agent-mode Config, and its instructions load
    the very same brand-voice snippet that has driven Otto's prompt since Build and
    his judge since Evaluate.
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

The rewriter gets the customer's question and the specialist's draft in the message it receives, not in its agent task. Anything in double braces in an agent task is a Mustache tag that LaunchDarkly renders before the SDK hands the text over, so an agent task is no place for per-request data.

1. Name the variation `Default`.
2. **Select model** → **Bedrock** → search `haiku-4-5-20251001` → select **us.anthropic.claude-haiku-4-5-20251001-v1:0**.
3. Click into the empty **Agent task** box, click **Load snippet** in the toolbar above it, and choose **Brand voice**. A `{{snippet.brand-voice#1}}` chip appears.
4. On a new line below it, paste:
```text
You are Otto in your new role on ToggleWear's Concierge team: the last stop before a response reaches the customer. A specialist has drafted a factually correct but plainly worded answer. Rewrite it in your own voice.

Rules:
- Keep every fact, number, product name, and caveat from the draft. Don't add facts the draft doesn't contain.
- Keep it short. Two or three sentences is usually right.
- Reply with only the rewritten response — no preamble, no quotation marks, no notes.

The message you receive contains the customer's question followed by the specialist's draft. Rewrite the draft; don't answer the question from scratch.
```
5. Click **Review and save**, then **Save changes**.

# Confirm the rewriter is on

A config's first saved variation is served automatically: the config is switched **On** in **Test** and the **Default rule** serves **Default**. Confirm it rather than assume it.

1. Click the **Targeting** tab and make sure the environment pill reads **Test**.
2. Check that the config is **On** and the **Default rule** reads **Serve Default**. If either is off, fix it (switch **On**; **Default rule → Edit → Serve → Default**), then **Review and save** and **Save changes**.

# Two Ottos

Open **Configs** and look at **Otto Assistant** next to **Concierge Otto Rewriter**. Same voice, same snippet, different modes. Otto Assistant keeps serving the ToggleWear app exactly as before until Challenge 07 switches the app over to the graph. Nothing about him changes; the team is built around him.

Click **Check** when the rewriter exists in agent mode, loads the brand-voice snippet, tells Otto to rewrite the draft, and serves Default in Test.
