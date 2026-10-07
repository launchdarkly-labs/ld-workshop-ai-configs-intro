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

