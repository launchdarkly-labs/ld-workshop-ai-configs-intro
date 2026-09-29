---
slug: otto-sounds-like-otto
id: cyaxabuoypah
type: challenge
title: Otto Sounds Like Otto
teaser: Write a custom brand-voice judge whose criteria are driven by the same brand-voice
  snippet Otto uses for his prompt.
notes:
- type: text
  contents: Built-in judges cover accuracy, relevance, and toxicity — useful, but
    not specific to your brand. Otto needs to sound like Otto. In this challenge you'll
    write a custom judge whose grading prompt pulls in the L1 brand-voice snippet,
    so the same definition of "on-brand" drives both Otto's behavior and his evaluation.
    Then you'll paste a small block into the server so each Otto response gets graded
    automatically.
tabs:
- id: gz0wpcbuxouf
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: 8xf7tqcnqglg
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: lcz6phlyqd5f
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 1200
enhanced_loading: null
---

# Why custom judges

The built-in judges from the previous challenge are generic. They don't know what "on-brand" means for ToggleWear; they just check accuracy, relevance, and safety. Otto's whole identity — warm, helpful, a little playful, concise — is in your `brand-voice` snippet, and you want a judge that grades against that.

Custom judges are AgentControl Configs in **judge mode**. They have a prompt that takes the response being evaluated as a template variable, score it, and emit a numeric metric. The trick we'll use here: pull the same `brand-voice` snippet into the judge's prompt. One source of truth for "on-brand" — for both what Otto does and how he's graded.

# Create the judge Config

Open the [LaunchDarkly](#tab-0) tab.

1. From the left-hand navigation, click **Configs**, then click **Create config**.
2. For **Mode**, select **Judge**.
3. For **What should this judge evaluate?**, enter:
```text
Detect response is warm and friendly and score it
```
4. For **Judge model**, select **Bedrock**
4. Click **Generate judge**.

# Add the judge variation

The judge needs a variation that defines the grading prompt.

1. On the new judge config's detail page, you'll be prompted to add the first variation.
2. For **Name**, enter:
```text
Default
```
4. Click on the **Model** dropdown, search for and select:
```
anthropic.claude-haiku-4-5-20251001-v1:0
```
5. Clear out the prompt text area, with **System** selected, click **Load snippet** and choose **brand-voice**.
6. Below the snippet markup that the editor inserted, paste:
```text
Score the response on a scale of 0.0 to 1.0:
- 1.0: Strongly on-brand. Warm, helpful, a little playful, honest, concise.
- 0.7: Mostly on-brand with minor issues.
- 0.4: Lacking warmth or has noticeable voice issues.
- 0.0: Off-brand. Robotic, off-topic, or contradicts the voice entirely.

Respond with ONLY a number between 0.0 and 1.0. No other text.

Response to evaluate:
{{response}}
```
7. Click **Review and save**, then **Save changes**.

# Turn the judge on

1. Click the **Targeting** tab.
2. Make sure the environment selector reads **Test**.
3. Make sure the Config is toggled **On**.
4. Under **Default rule**, make sure the varation is set to **Default**.
5. If any changes were made, click **Review and save**, then **Save changes**.

# Wire Otto's Config to watch the score

Otto's main Config doesn't know about this judge yet. Tell it which metric to consider its primary quality signal — the guarded rollout in ch07 will read this.

1. Navigate to **Configs** → **Otto Assistant**.
2. For both **Otto (Born)** and **Otto (Premium)** variations:
  a. Below the prompt text area, click **+Add judges**.
  b. Select **Otto Brand Voice Judge** and click **Add 1 judge**.
  c. Set the **Sampling percentage** to **25%**.
3. Click **Review and save**, then **Save changes**.

# Wire the app to invoke the judge

Open the [Code Editor](#tab-2) tab. Open `server.py`.

Find the marker comment near the bottom of the `/chat` function body:

```python
    # ─── Challenge 07 judge injects below this marker ──────────────────────
```

Paste the following block **immediately below** that marker line:

```python
    # ─── Evaluate 03: brand-voice judge ─────────────────────────────────────
    # Score Otto's response 0.0-1.0 with the otto-brand-voice-judge Config,
    # then emit the score as an otto-brand-voice-score metric event. Errors
    # are swallowed — a judge failure should not poison a user's chat.
    try:
        bv_ctx = Context.builder(req.session_id).set("tier", req.user_tier).build()
        bv_cfg = ai_client.judge_config(
            "otto-brand-voice-judge",
            bv_ctx,
            variables={"response": assistant_text},
        )
        if bv_cfg.enabled and bv_cfg.model is not None:
            bv_system: list[dict] = []
            bv_messages: list[dict] = []
            for m in (bv_cfg.messages or []):
                if m.role == "system":
                    bv_system.append({"text": m.content})
                else:
                    bv_messages.append(
                        {"role": m.role, "content": [{"text": m.content}]}
                    )
            bv_kwargs = {
                "modelId": resolve_bedrock_model(bv_cfg.model.name),
                "messages": bv_messages,
                "inferenceConfig": {"maxTokens": 8, "temperature": 0.0},
            }
            if bv_system:
                bv_kwargs["system"] = bv_system
            bv_resp = bedrock.converse(**bv_kwargs)
            bv_text = _extract_text(bv_resp).strip()
            try:
                score = float(bv_text.split()[0])
            except (ValueError, IndexError):
                score = None
            if score is not None and 0.0 <= score <= 1.0:
                ld_client.track("otto-brand-voice-score", bv_ctx, None, score)
                log.info(
                    "brand-voice-judge session=%s otto_model=%s score=%.2f",
                    req.session_id, model_id, score,
                )
    except Exception:  # noqa: BLE001
        log.exception("Brand-voice judge eval failed (non-fatal)")
```

Save the file. The ToggleWear service auto-reloads.

# Watch the scores

The realchat traffic generator is still running, so within ~1 minute the judge starts scoring real Otto responses.

1. Open the **Otto Assistant** config → **Monitoring** tab.
2. From the metric dropdown, select **otto-brand-voice-score**.
3. Watch the line populate.

The judge's score is now your custom signal for "is Otto sounding like Otto right now?" It drives the metric ch07 will use as the guarded-rollout watchdog.

Click **Check** when the judge config is live and `server.py` invokes it.
