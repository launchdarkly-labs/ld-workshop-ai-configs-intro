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

1. From the left-hand navigation, click **Configs**, then click **Create config** at the top right.
2. In the **Create config** dialog, choose **Judge** from the mode selector.
3. For **What should this judge evaluate?**, enter:
```text
Score how warm, helpful, playful, honest and concise the response is
```
4. For **Judge model**, open the provider dropdown (it defaults to **Anthropic**) and select **Bedrock**.
5. Click **Edit config key** and enter exactly:
```text
otto-brand-voice-judge
```
   The key matters: the code you paste into `server.py` later looks the judge up by this key.
6. Click **Generate judge**.

LaunchDarkly drafts the judge for you: it picks a name, writes a rubric, and lands you on the new config's **Variations** tab with a **Default** variation already in place. Over the next two sections you'll replace that draft with the brand-voice rubric.

# Rewrite the Default variation

The generated **Default** variation runs on Sonnet 4.5 and carries a three-message rubric (a system prompt plus **MESSAGE HISTORY** and **RESPONSE TO EVALUATE** helper messages). Replace it with a single system prompt built on the brand-voice snippet.

1. In the **Default** variation, click the model selector (it shows `anthropic.claude-sonnet-4-5-...`), choose **Bedrock**, and search for and select:
```text
anthropic.claude-haiku-4-5-20251001-v1:0
```
2. Click into the **System** message, select all of its text, and delete it.
3. With the empty System message focused, click **Load snippet** and choose **Brand voice**.
4. On a new line below the snippet chip, paste:
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
5. Delete the two helper messages below it. Hover over the **MESSAGE HISTORY** message and click its trash icon (**Delete message**); do the same for **RESPONSE TO EVALUATE**. Only the System message should remain.
6. Click **Review and save**, then **Save changes**.

# Fix the name and the direction

The generator named the config from your description and may have guessed that a lower score is better. Both live in the right-hand panel.

1. Next to **Name**, click the pencil icon, enter `Otto Brand Voice Judge`, and save.
2. Next to **Desired direction**, click the pencil icon, choose **Higher is better**, and click the check mark to save. A 1.0 from this judge means Otto is fully on-brand.
3. Leave **Event key** as `$ld:ai:judge:otto-brand-voice-judge`. That is the metric key LaunchDarkly records judge scores under.

# Confirm the judge is on

Generated judges come up enabled in every environment, but it's worth confirming.

1. Click the **Targeting** tab.
2. Make sure the environment pill reads **Test**.
3. The **Config is On** switch should be on, and the **Default rule** should read **Serve Default**.
4. If you had to change anything, click **Review and save**, then **Save changes**.

# Attach the judge to Otto

Otto's main Config doesn't know about this judge yet. Attach it to both variations so LaunchDarkly samples Otto's responses through it.

1. Navigate to **Configs** → **Otto Assistant**.
2. For both **Otto (Born)** and **Otto (Premium)** (expand the variation if it's collapsed):
  a. Below the prompt, click **+ Add judges**.
  b. Tick **Otto Brand Voice Judge** and click **Add 1 judge**.
  c. In the **Judges** table, set its **Sampling percentage** to **25**.
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
    # then emit the score both as an otto-brand-voice-score metric event and
    # through the AI tracker as a judge result (Monitoring judge card). Errors
    # are swallowed — a judge failure should not poison a user's chat.
    try:
        from ldai.providers.types import JudgeResult

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

            # Route the score through the LD AI tracker too. That records it
            # against the judge's own event key ($ld:ai:judge:otto-brand-voice-judge),
            # which is what the judge card on the Monitoring tab reads. The
            # ld_client.track call below feeds the otto-brand-voice-score custom
            # metric used by the experiment and the guarded rollout.
            bv_result = JudgeResult(judge_config_key="otto-brand-voice-judge")
            bv_result.sampled = True
            bv_result.metric_key = (
                getattr(bv_cfg, "evaluation_metric_key", None)
                or "$ld:ai:judge:otto-brand-voice-judge"
            )
            if score is not None and 0.0 <= score <= 1.0:
                bv_result.score = score
                bv_result.success = True
                ld_client.track("otto-brand-voice-score", bv_ctx, None, score)
                log.info(
                    "brand-voice-judge session=%s otto_model=%s score=%.2f",
                    req.session_id, model_id, score,
                )
            else:
                bv_result.error_message = f"unparseable score: {bv_text!r}"
            tracker.track_judge_result(bv_result)
    except Exception:  # noqa: BLE001
        log.exception("Brand-voice judge eval failed (non-fatal)")
```

Save the file. The ToggleWear service auto-reloads.

# Watch the scores

The realchat traffic generator is still running, so within ~1 minute the judge starts scoring real Otto responses. The pasted code emits each score as an `otto-brand-voice-score` metric event; that numeric metric already exists in your project (the challenge setup created it) and is what the experiment in Challenge 06 and the guarded rollout in Challenge 07 will read.

1. Open the **Otto Assistant** config → **Monitoring** tab.
2. A chart card for **$ld:ai:judge:otto-brand-voice-judge** appears alongside the built-in judge cards from Challenge 02 and starts filling in as the pasted code reports each score through the tracker.

The judge's score is now your custom signal for "is Otto sounding like Otto right now?" It drives the metric ch07 will use as the guarded-rollout watchdog.

Click **Check** when the judge config is live, attached to Otto, and `server.py` invokes it.
