---
slug: self-healing
id: aqy5kku5gu2s
type: challenge
title: Self-Healing
teaser: Add a synchronous judge inside the rewriter — if Otto's response fails the
  brand-voice check, regenerate before the user sees it.
notes:
- type: text
  contents: 'Add the per-request safety net: a synchronous brand-voice judge inside
    the rewriter that regenerates an off-brand response on a pinned fallback model
    before the customer ever sees it, and counts every heal in a metric.'
tabs:
- id: fdt26j0xiwel
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: 2bz1lvgpwmqa
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: eh4nvea58dnj
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 1200
enhanced_loading: null
---

# The third safety net

You've now seen two timescales of protection:

| Timescale | Mechanism | Where |
|---|---|---|
| Release time | Guarded rollout watches a metric while traffic ramps and rolls back on regression. | Evaluate 07, Coordinate 09 |
| Between requests | An in-app loop watches the rolling score and flips targeting to a safe variation. | Evaluate 08 |
| **Per request** | **Judge the response before the customer sees it; regenerate if it fails.** | **This challenge** |

The first two protect the *next* customers. Self-healing protects *this* customer. It costs latency: one extra model call to grade, and occasionally a second to regenerate. The Concierge makes that trade deliberately, at the one node where it matters most: Otto's final wording.

# What's already in place

- A `concierge-self-heal` count metric exists in your project (setup created it). Every regeneration emits one event, so you can see how often the net catches something.
- Real chat traffic is flowing through the graph again.

# Paste the self-healing block

Open the [Code Editor](#tab-2) tab and open `app/server.py`.

1. Find this comment inside the Concierge dispatch you pasted in Challenge 07:
```python
    # ─── Coordinate 10: self-healing hook ───────────────────────────────────
```
2. Two comment lines follow it. Place your cursor on the empty line after them and paste:

```python
    # ─── Coordinate 10: self-healing ────────────────────────────────────────
    # Per-request safety net. Before the customer sees Otto's rewrite, grade it
    # synchronously with the brand-voice judge (the same Config Evaluate built).
    # If it scores below SELF_HEAL_THRESHOLD, regenerate ONCE on the pinned
    # fallback model (Haiku 4.5), emit a concierge-self-heal event, and serve
    # the healed text instead. The async judge blocks further down still grade
    # whatever we end up serving.
    SELF_HEAL_THRESHOLD = 0.5
    SELF_HEAL_FALLBACK_MODEL = resolve_bedrock_model("anthropic.claude-haiku-4-5-20251001-v1:0")
    try:
        sh_cfg = ai_client.judge_config(
            "otto-brand-voice-judge", context, variables={"response": assistant_text}
        )
        sh_score = None
        if sh_cfg.enabled and sh_cfg.model is not None:
            sh_system = [{"text": m.content} for m in (sh_cfg.messages or []) if m.role == "system"]
            sh_messages = [
                {"role": m.role, "content": [{"text": m.content}]}
                for m in (sh_cfg.messages or []) if m.role != "system"
            ] or [{"role": "user", "content": [{"text": "Score the response now."}]}]
            sh_resp = bedrock.converse(
                modelId=resolve_bedrock_model(sh_cfg.model.name),
                system=sh_system,
                messages=sh_messages,
                inferenceConfig={"maxTokens": 8, "temperature": 0.0},
            )
            try:
                sh_score = float(_extract_text(sh_resp).strip().split()[0])
            except (ValueError, IndexError):
                sh_score = None
        if sh_score is not None and sh_score < SELF_HEAL_THRESHOLD:
            healed = bedrock.converse(
                modelId=SELF_HEAL_FALLBACK_MODEL,
                system=[{"text": rewrite["instructions"]}],
                messages=[{"role": "user", "content": [{"text": rewrite_user_text}]}],
                inferenceConfig={"maxTokens": 400, "temperature": 0.4},
            )
            healed_text = _extract_text(healed).strip()
            if healed_text:
                log.info(
                    "self-heal session=%s score=%.2f below %.2f: regenerated on %s (was %s)",
                    req.session_id, sh_score, SELF_HEAL_THRESHOLD, SELF_HEAL_FALLBACK_MODEL, model_id,
                )
                ld_client.track(
                    "concierge-self-heal", context,
                    {"score": sh_score, "rewriter_model": model_id, "fallback_model": SELF_HEAL_FALLBACK_MODEL},
                )
                assistant_text = healed_text
                model_id = SELF_HEAL_FALLBACK_MODEL + " (self-healed)"
        elif sh_score is not None:
            log.info("self-heal session=%s score=%.2f passed", req.session_id, sh_score)
    except Exception:  # noqa: BLE001
        log.exception("Self-healing check failed (non-fatal); serving the original rewrite")
```

3. Save. The service reloads.

The block grades `assistant_text` with the same **Otto Brand Voice Judge** you built in Evaluate, synchronously. Below 0.5 it regenerates once on Haiku 4.5 using the rewriter's own instructions, records a `concierge-self-heal` event with the score and both model names, and replaces the response before it's returned. The asynchronous judge blocks further down still run on whatever is finally served.

# See it work

Most rewrites pass. To watch a heal, make one fail:

1. Open the [LaunchDarkly](#tab-0) tab, go to **Configs → Concierge Otto Rewriter → Targeting**, click **Edit** on the Default rule, open **Serve**, and choose **Otto Rewriter (Lite)**. **Review and save**, then **Save changes**. Nova Lite is now rewriting every response.
2. Open the [ToggleWear](#tab-1) tab and ask a few questions.
3. In the [Code Editor](#tab-2) terminal, follow the log:
```bash
journalctl -u togglewear -f | grep self-heal
```
   Passing rewrites log `score=0.8x passed`. When Nova Lite drifts off-brand you'll see `below 0.50: regenerated on us.anthropic.claude-haiku-4-5-20251001-v1:0`, and the answer in ToggleWear is the healed one.
4. Put the rewriter back: **Targeting → Edit → Serve → Default**, **Review and save**, **Save changes**.

Under **Metrics**, open **Concierge self-heal** to see the count of heals so far.

# What you built

A graph of five agents, each with its own Config, its own model, and its own metrics, that reads like an org chart. A rollout that risks one node at a time. And a judge standing between Otto and the customer, so a bad sentence never ships. Otto didn't get replaced. He got a team.

Click **Check** when the self-healing block is in `server.py`, the metric exists, and the app still answers.
