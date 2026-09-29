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
2. For **Name**:
```text
Product catalog
```
3. For **Key**, make sure it is:
```text
product-catalog
```
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
5. Click **Save**.

# Create the judge Config

1. From the left-hand navigation, click **Configs**, then click **Create config**.
2. For **Mode**, select **Judge**.
3. For **What should this judge evaluate?**, enter:
```text
Otto Claim Accuracy Judge
```
4. For **Judge model**, select **Bedrock**
5. Click **Generate judge**.

# Add the judge variation

1. On the new judge config's detail page, you'll be prompted to add the first variation.
2. For **Name**, enter:
```text
Default
```
3. Click on the **Model** dropdown, search for and select:
```
anthropic.claude-haiku-4-5-20251001-v1:0
```
4. Clear out the prompt text area, with **System** selected, click **Load snippet** and choose **product-catalog**.
5. Below the snippet markup that the editor inserted, paste:
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
5. Click **Review and save**, then **Save changes**.

# Turn the judge on

1. Click the **Targeting** tab.
2. Make sure the environment selector reads **Test**.
3. Make sure the Config is toggled **On**.
4. Under **Default rule**, make sure the varation is set to **Default**.
5. If any changes were made, click **Review and save**, then **Save changes**.

> **Note:** Don't change the **Evaluation metric** on Otto Assistant. The brand-voice judge from ch03 is still Otto's primary quality signal; this judge's metric is an auxiliary signal you'll be able to compare alongside.

# Add the judge to the Catalog Config

1. Navigate to **Configs** → **Otto Assistant**.
2. For both **Otto (Born)** and **Otto (Premium)** variations:
  a. Below the prompt text area, click **+Add judges**.
  b. Select **Otto Claim Accuracy Judge** and click **Add 1 judge**.
  c. Set the **Sampling percentage** to **25%**.
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
            if score is not None and 0.0 <= score <= 1.0:
                ld_client.track("otto-claim-accuracy-score", cl_ctx, None, score)
                log.info(
                    "claim-accuracy-judge session=%s otto_model=%s score=%.2f",
                    req.session_id, model_id, score,
                )
    except Exception:  # noqa: BLE001
        log.exception("Claim-accuracy judge eval failed (non-fatal)")
```

Save. Service auto-reloads.

# Compare the two judges

In the **Otto Assistant** → **Monitoring** view, switch between **otto-brand-voice-score** and **otto-claim-accuracy-score**. You should see two different signals — Otto might be sounding right (high brand-voice) while still inventing facts (lower claim-accuracy), or vice versa.

That decoupling is the whole point. One signal isn't enough; one workshop's worth of catalog isn't going to invent itself.

Click **Check** when the second judge is live and `server.py` invokes both.
