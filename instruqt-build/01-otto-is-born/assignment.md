---
slug: otto-is-born
id: 6pn3ey5dbzmb
type: challenge
title: Otto is Born
teaser: Create Otto's first AgentControl Config and wire him into the ToggleWear app.
notes:
- type: text
  contents: Today is Otto's first day. You'll create his first Config in AgentControl,
    give him a starting prompt and a starting model, and add the few lines of server
    code that bring him to life. By the end of this challenge, Otto will say his first
    words from the ToggleWear storefront.
tabs:
- id: ftikmtel9qfo
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: yapitnqzvza4
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: wiby4zdkume6
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: ""
timelimit: 1200
enhanced_loading: null
---

# Meet Otto

ToggleWear wants an AI shopping assistant on the storefront, and we're going to build it. We've named him Otto. Right now he's a placeholder — the chat widget on the [ToggleWear](#tab-1) tab returns a canned "not wired up yet" line. We're going to fix that.

By the end of this challenge:

- Otto exists as a **Config** in AgentControl.
- He has a starting prompt and a starting model (Claude Haiku 4.5 on Bedrock).
- The ToggleWear app evaluates the Config on each `/chat` call.
- Otto says his first real words.

# Create Otto's Config

Open the [LaunchDarkly](#tab-0) tab.

1. From the left-hand navigation, where you see the **Code | Agents** selector, click Agents
2. Under Agents, click **Configs**.
3. Click **Create config** in the upper right.
4. For **Name**, enter:
```text
Otto Assistant
```
5. For **Key**, the UI should pre-fill `otto-assistant`. Confirm or set it to:
```text
otto-assistant
```
6. For **Mode**, select **Completion**.
7. Click **Create**.

![Create Config](../assets/ch01-create-config.png)

# Add Otto's first variation

The Config exists but has no variations yet — nothing to serve. Add the "born" variation.

1. You are now on the Config detail page, adding the first variation.
2. For **Name**, enter:
```text
Otto (Born)
```
3. For **Key**, confirm or enter:
```text
otto-born
```
4. Under **Select model**, In the search box, enter and select:
```text
anthropic.claude-haiku-4-5-20251001-v1:0
```
5. In the prompt text area, select **System**, and add this content in the prompt:
```text
You are a customer service assistant for ToggleWear, an online retailer. Answer questions from customers about products and store policies. Be accurate and concise.
```
6. Click **Review and save**, then **Save changes**.

# Turn Otto on in `Test`

By default Otto's `Test` environment is serving the placeholder "disabled" variation. Switch it to the Born variation we just created.

1. Click the **Targeting** tab.
2. Make sure the environment selector reads **Test**.
3. Under **Default rule**, click **Edit** and select **Otto (Born)**.
4. Click **Review and save**, then **Save changes**.

# Wire Otto into the app

Open the [Code Editor](#tab-2) tab. Open `server.py`.

Find the block marked:

```python
# ─────────────────────────────────────────────────────────────────────
# Challenge 01 paste block — replace this stub with real Otto code.
```

Replace **everything between the opening marker and the** `# ─── End Challenge 01 paste block ────` **line** with:

```python
    # ─── Challenge 01: wire Otto to /chat ─────────────────────────────────
    # Build context, evaluate the otto-assistant Config.
    context = Context.builder(req.session_id).set("tier", req.user_tier).build()
    cfg = ai_client.completion_config(OTTO_CONFIG_KEY, context, FALLBACK_CONFIG)

    if not cfg.enabled or cfg.model is None:
        return JSONResponse(status_code=503, content={
            "response": "Otto isn't enabled. Check the Config targeting.",
            "turn": turn, "turn_limit": TURN_LIMIT,
        })

    # Translate the Config's messages into Bedrock Converse format.
    system_blocks = []
    seed_messages = []
    for m in cfg.messages or []:
        if m.role == "system":
            system_blocks.append({"text": m.content})
        else:
            seed_messages.append({"role": m.role, "content": [{"text": m.content}]})

    # Merge in this session's prior turns + the new user message.
    with _state_lock:
        prior = list(_history[req.session_id])
    history_blocks = [{"role": m.role, "content": [{"text": m.content}]} for m in prior]
    bedrock_messages = seed_messages + history_blocks + [
        {"role": "user", "content": [{"text": req.message}]}
    ]

    model_id = resolve_bedrock_model(cfg.model.name)
    tracker = cfg.create_tracker()

    try:
        response = tracker.track_bedrock_converse_metrics(
            bedrock.converse(modelId=model_id, messages=bedrock_messages, system=system_blocks)
        )
    except ClientError as e:
        err = e.response.get("Error", {})
        log.error("Bedrock ClientError code=%s model=%s message=%s",
                  err.get("Code"), model_id, err.get("Message"))
        return JSONResponse(status_code=502, content={
            "response": _bedrock_user_message(err.get("Code")),
            "turn": turn, "turn_limit": TURN_LIMIT,
        })

    assistant_text = _extract_text(response)
    with _state_lock:
        _history[req.session_id].append(LDMessage(role="user", content=req.message))
        _history[req.session_id].append(LDMessage(role="assistant", content=assistant_text))

    usage = response.get("usage") or {}
    metrics = response.get("metrics") or {}
    log.info(
        "chat session=%s tier=%s turn=%d model=%s tokens_in=%s tokens_out=%s latency_ms=%s",
        req.session_id, req.user_tier, turn, model_id,
        usage.get("inputTokens"), usage.get("outputTokens"), metrics.get("latencyMs"),
    )

    # ─── Challenge 07 judge injects below this marker ──────────────────────
```

Save the file (⌘ + S/Ctrl + S). The ToggleWear service auto-reloads.

Read through the block of code to note how the LaunchDarkly AI SDK gets the model
configuration, then passes that on to the Bedrock SDK.

Earlier in the code, at line 41, you'll see the AgentControl client SDK instantiation:
```python
ai_client = LDAIClient(ld_client)
```

In the code you just pasted, look at line ~147, and you'll see where we get the config from AgentControl.
```python
cfg = ai_client.completion_config(OTTO_CONFIG_KEY, context, FALLBACK_CONFIG)
```

The next lines that follow validate the config, then continue on to setup the message structure. And around line 177, the AgentControl config attributes are used in the `bedrock.converse` method call.

# Say hi to Otto

Open the [ToggleWear](#tab-1) tab. Click **Chat with Otto** in the bottom-right. Ask him something — try:

```text
Got any t-shirts?
```

Otto should answer for real this time. He'll be brief and a little robotic — that's by design. We'll give him a personality in the next challenge.

When you're satisfied, click **Check** below.
