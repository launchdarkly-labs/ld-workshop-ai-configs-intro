---
slug: otto-checks-his-facts
id: 2k3vwzvjpmae
type: challenge
title: Otto Checks His Facts
teaser: Add a second custom judge that grades Otto against the product catalog, catching
  invented prices, materials, or policies.
notes:
- type: text
  contents: The brand-voice judge measures HOW Otto sounds. This challenge adds a
    judge that measures WHAT he says — specifically, whether his product claims match
    the catalog. Same pattern as ch03 (Config in judge mode, snippet drives the criteria,
    paste a small block into the server), but the snippet here is the catalog itself.
tabs:
- id: xyyygmxtrmcm
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: pzddc7r4pgib
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: 9yhphh5dhicg
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 1200
enhanced_loading: null
---

# Two kinds of "good"

The brand-voice judge from ch03 grades the *style* of Otto's answers. But style isn't enough — Otto can sound exactly right while still making things up. Invented prices, fabricated return policies, sizes that don't exist. Style judge says "sounds great"; the customer ends up with a wrong expectation.

This challenge adds a second judge that scores **accuracy against the product catalog**. Same overall pattern as the brand-voice judge — Config in judge mode, snippet-driven criteria, paste into the server. The new twist: the snippet contains the catalog itself, so adding or changing a product means editing one snippet.

# Create the product-catalog snippet

Open the [LaunchDarkly](#tab-0) tab.

1. Navigate to **Library → Snippets** and click **Create snippet**.
2. For **Name**, enter:
```text
Product catalog
```
   LaunchDarkly derives the key from the name, so this name yields `product-catalog`, which is the key the judge prompt and the server code reference. (The dialog has an **Edit key** button; you only need it if the derived key reads differently.)
3. Leave **Description** empty.
4. For **Body**, paste:
```text
ToggleWear product catalog. These are the only products we sell. Anything not in this list is not a ToggleWear product.

- Rocket Tee - $28. Heather grey, classic crew-neck t-shirt with the LaunchDarkly rocket.
- Feature Flag Hoodie - $58. Midnight navy, pullover with embroidered flag logo.
- Dark Mode Cap - $24. Six-panel dad cap with tone-on-tone black logo.
- Ship It Mug - $16. 12oz ceramic, "Ship it" in the LaunchDarkly font.
- Toggle Socks - $14. Crew socks with a tiny rocket on the ankle.
- Release Notes Notebook - $18. A5 hardcover with dot grid.
- Rollout Tote - $22. 12oz canvas with reinforced handles.
- Feature Branch Crewneck - $52. Heavyweight sage green sweatshirt.

Otto should not invent stock, sizes, materials beyond what's listed, colors not listed, return policies, shipping details, or any other facts not stated above. He may suggest customers check the product page or contact support for specifics he doesn't have.
```
5. Click **Save**. The snippet appears in the list; use its **Copy key** button to confirm the key reads `product-catalog`.

# Create the judge Config

1. From the left-hand navigation, click **Configs**, then click **Create config**.
2. In the **Create config** dialog, choose **Judge**.
3. For **What should this judge evaluate?**, enter:
```text
Check whether product claims in the response match the ToggleWear catalog
```
4. For **Judge model**, open the provider dropdown and select **Bedrock**.
5. Click **Edit config key** and enter exactly:
```text
otto-claim-accuracy-judge
```
6. Click **Generate judge**.

As in Challenge 03, LaunchDarkly drafts a name, a rubric, and a **Default** variation. You'll replace the rubric with one grounded in the catalog snippet.

# Rewrite the Default variation

1. In the **Default** variation, click the model selector, choose **Bedrock**, and search for and select:
```text
anthropic.claude-haiku-4-5-20251001-v1:0
```
2. Click into the **System** message, select all of its text, and delete it.
3. With the empty System message focused, click **Load snippet** and choose **Product catalog**.
4. On a new line below the snippet chip, paste:
```text
You are evaluating whether Otto's response to a customer makes any factual product claims that contradict the ToggleWear catalog above.

Customer's question:
{{input}}

Otto's response:
{{response}}

Score 0.0 to 1.0:
- 1.0: Response makes no claims that contradict the catalog, OR makes no factual product claims at all (e.g. asks a clarifying question, gracefully declines).
- 0.5: Borderline — mentions a product detail not in the catalog but doesn't clearly contradict it.
- 0.0: Response asserts a price, material, size, color, policy, or other fact that contradicts or is unsupported by the catalog.

Respond with ONLY a number between 0.0 and 1.0. No other text.
```
5. Delete the generated **MESSAGE HISTORY** and **RESPONSE TO EVALUATE** helper messages (hover each and click its trash icon). Only the System message should remain.
6. Click **Review and save**, then **Save changes**.
7. In the right-hand panel, click the pencil next to **Name** and rename the config to `Otto Claim Accuracy Judge`. Then click the pencil next to **Desired direction**, choose **Higher is better**, and save.

# Confirm the judge is on

1. Click the **Targeting** tab.
2. Make sure the environment pill reads **Test**, the **Config is On** switch is on, and the **Default rule** reads **Serve Default**. Generated judges start this way; fix and **Review and save** only if something differs.

> **Note:** The brand-voice judge from Challenge 03 stays Otto's primary quality signal (it is what the experiment and guarded rollout read). This judge's score is an auxiliary signal you'll compare alongside it.

# Attach the judge to Otto

1. Navigate to **Configs** → **Otto Assistant**.
2. For both **Otto (Born)** and **Otto (Premium)**:
  * Below the prompt, click **+ Add judges**.
  * Tick **Otto Claim Accuracy Judge** and click **Add 1 judge**.
  * In the **Judges** table, set its **Sampling percentage** to **25**.
3. Click **Review and save**, then **Save changes**.

# Wire the app to invoke the second judge

Open the [Code Editor](#tab-2) tab. Open `app/server.py` again.

Find the same marker comment you used in ch03:

```python
    # ─── Challenge 07 judge injects below this marker ──────────────────────
```

Paste the following block **immediately below** the marker. (It'll end up above the brand-voice block you pasted in ch03 — both run on each chat call, independently.)

```python
    # ─── Evaluate 04: product-claim accuracy judge ──────────────────────────
    # Score Otto's response 0.0-1.0 against the product-catalog snippet via
    # the otto-claim-accuracy-judge Config. Emits otto-claim-accuracy-score.
    # Pass both {{input}} (the customer's question) and {{response}} as
    # template variables so the judge can ground its grading in context.
    try:
        from ldai.providers.types import JudgeResult

        cl_ctx = Context.builder(req.session_id).set("tier", req.user_tier).build()
        cl_cfg = ai_client.judge_config(
            "otto-claim-accuracy-judge",
            cl_ctx,
            variables={
                "input": req.message,
                "response": assistant_text,
            },
        )
        if cl_cfg.enabled and cl_cfg.model is not None:
            cl_system: list[dict] = []
            cl_messages: list[dict] = []
            for m in (cl_cfg.messages or []):
                if m.role == "system":
                    cl_system.append({"text": m.content})
                else:
                    cl_messages.append(
                        {"role": m.role, "content": [{"text": m.content}]}
                    )
            if not cl_messages:
                # Bedrock Converse requires at least one user turn. The judge's
                # rubric (with the response already interpolated) is the system
                # prompt, so a short user nudge is all that's needed.
                cl_messages.append(
                    {"role": "user", "content": [{"text": "Score the response now."}]}
                )
            cl_kwargs = {
                "modelId": resolve_bedrock_model(cl_cfg.model.name),
                "messages": cl_messages,
                "inferenceConfig": {"maxTokens": 8, "temperature": 0.0},
            }
            if cl_system:
                cl_kwargs["system"] = cl_system
            cl_resp = bedrock.converse(**cl_kwargs)
            cl_text = _extract_text(cl_resp).strip()
            try:
                score = float(cl_text.split()[0])
            except (ValueError, IndexError):
                score = None

            # Route the score through the LD AI tracker too. That records it
            # against the judge's own event key ($ld:ai:judge:otto-claim-accuracy-judge),
            # which is what the judge card on the Monitoring tab reads. The
            # ld_client.track call below feeds the otto-claim-accuracy-score custom
            # metric used by the experiment and the guarded rollout.
            cl_result = JudgeResult(judge_config_key="otto-claim-accuracy-judge")
            cl_result.sampled = True
            cl_result.metric_key = (
                getattr(cl_cfg, "evaluation_metric_key", None)
                or "$ld:ai:judge:otto-claim-accuracy-judge"
            )
            if score is not None and 0.0 <= score <= 1.0:
                cl_result.score = score
                cl_result.success = True
                ld_client.track("otto-claim-accuracy-score", cl_ctx, None, score)
                log.info(
                    "claim-accuracy-judge session=%s otto_model=%s score=%.2f",
                    req.session_id, model_id, score,
                )
            else:
                cl_result.error_message = f"unparseable score: {cl_text!r}"
            tracker.track_judge_result(cl_result)
    except Exception:  # noqa: BLE001
        log.exception("Claim-accuracy judge eval failed (non-fatal)")
```

Save. Service auto-reloads.

# Compare the two judges

In the **Otto Assistant** → **Monitoring** view, compare the **$ld:ai:judge:otto-brand-voice-judge** and **$ld:ai:judge:otto-claim-accuracy-judge** chart cards. You should see two different signals — Otto might be sounding right (high brand-voice) while still inventing facts (lower claim-accuracy), or vice versa.

That decoupling is the whole point. One signal isn't enough; one workshop's worth of catalog isn't going to invent itself.

Click **Check** when the second judge is live, attached to Otto, and `server.py` invokes both.
