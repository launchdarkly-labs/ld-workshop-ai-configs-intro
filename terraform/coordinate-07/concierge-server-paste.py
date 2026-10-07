    # ─── Coordinate 07: Concierge dispatch ──────────────────────────────────
    # Otto no longer answers alone. Evaluate the `concierge` agent graph for
    # this customer, let Toggle (the root node) name a specialist, follow the
    # edge whose handoff matches, get the specialist's draft, then follow the
    # specialist's edge to Otto-the-rewriter for the final wording.
    #
    # LaunchDarkly hands us the topology, the per-node Configs (already
    # resolved for this context, snippets expanded) and the handoff data on
    # every edge. The application decides what to do with them — LaunchDarkly
    # never calls the models for us.
    context = Context.builder(req.session_id).set("tier", req.user_tier).build()
    graph = ai_client.agent_graph("concierge", context)
    if not graph.is_enabled() or graph.root() is None:
        return JSONResponse(status_code=503, content={
            "response": "The Concierge graph isn't enabled. Check that every agent Config is on and the graph has a root.",
            "turn": turn, "turn_limit": TURN_LIMIT,
        })
    graph_tracker = graph.create_tracker()

    def call_node(node, user_text: str) -> dict:
        """Run one graph node: evaluate its agent Config, call its model on Bedrock.

        Agent-mode Configs give us `instructions` (one string) instead of a
        messages array. Snippets like {{snippet.brand-voice#1}} are already
        expanded by LaunchDarkly, and so is every other {{mustache}} tag: the
        SDK renders the agent task with no variables, so per-request data
        travels in the user turn, never in the agent task. The node's tracker
        is tagged with the graph key, so every metric rolls up to the
        Concierge graph in Monitoring.
        """
        agent = node.get_config()
        if not agent.enabled or agent.model is None:
            raise RuntimeError(f"agent {node.get_key()} is disabled")
        instructions = agent.instructions or ""
        node_model_id = resolve_bedrock_model(agent.model.name)
        node_tracker = agent.create_tracker()
        node_resp = node_tracker.track_bedrock_converse_metrics(
            bedrock.converse(
                modelId=node_model_id,
                system=[{"text": instructions}],
                messages=[{"role": "user", "content": [{"text": user_text}]}],
                inferenceConfig={"maxTokens": 400, "temperature": 0.4},
            )
        )
        return {
            "text": _extract_text(node_resp).strip(),
            "agent": agent,
            "tracker": node_tracker,
            "instructions": instructions,
            "model_id": node_model_id,
            "usage": node_resp.get("usage") or {},
        }

    try:
        # 1. Toggle triages. Its instructions force a one-word answer.
        toggle = graph.root()
        triage = call_node(toggle, req.message)
        route = triage["text"].strip().lower().split()[0].strip(".,!") if triage["text"].strip() else "product"

        # 2. Follow the edge whose handoff names that route. Unknown route ->
        #    first edge (Curator), so a confused triage still gets an answer.
        edges = toggle.get_edges()
        edge = next((e for e in edges if (e.handoff or {}).get("route") == route), None)
        if edge is None and edges:
            edge, route = edges[0], (edges[0].handoff or {}).get("route", route)
        specialist = graph.get_node(edge.target_config) if edge else None
        if specialist is None:
            raise RuntimeError("Toggle has no outgoing edges")
        draft = call_node(specialist, req.message)

        # 3. Follow the specialist's edge to Otto-the-rewriter.
        out_edges = specialist.get_edges()
        rewriter = graph.get_node(out_edges[0].target_config) if out_edges else None
        if rewriter is None:
            raise RuntimeError(f"{specialist.get_key()} has no outgoing edge to a rewriter")
        rewrite_user_text = (
            f"Customer's question:\n{req.message}\n\nSpecialist's draft:\n{draft['text']}"
        )
        rewrite = call_node(rewriter, rewrite_user_text)
        assistant_text = rewrite["text"]
        model_id = rewrite["model_id"]
        tracker = rewrite["tracker"]  # the Evaluate-era judge blocks below record against this
        graph_tracker.track_invocation_success()
    except ClientError as e:
        graph_tracker.track_invocation_failure()
        err = e.response.get("Error", {})
        log.error("Bedrock ClientError in Concierge dispatch code=%s message=%s",
                  err.get("Code"), err.get("Message"))
        return JSONResponse(status_code=502, content={
            "response": _bedrock_user_message(err.get("Code")),
            "turn": turn, "turn_limit": TURN_LIMIT,
        })
    except RuntimeError as e:
        graph_tracker.track_invocation_failure()
        log.error("Concierge dispatch failed: %s", e)
        return JSONResponse(status_code=503, content={
            "response": "The Concierge team isn't fully wired up yet. Check the agent Configs and the graph edges.",
            "turn": turn, "turn_limit": TURN_LIMIT,
        })

    # ─── Coordinate 10: self-healing hook ───────────────────────────────────
    # (Challenge 10 pastes its synchronous brand-voice check directly below
    #  this comment. It may replace `assistant_text` and `model_id`.)

    with _state_lock:
        _history[req.session_id].append(LDMessage(role="user", content=req.message))
        _history[req.session_id].append(LDMessage(role="assistant", content=assistant_text))

    log.info(
        "concierge session=%s tier=%s turn=%d route=%s specialist=%s rewriter_model=%s tokens_out=%s",
        req.session_id, req.user_tier, turn, route, specialist.get_key(), model_id,
        rewrite["usage"].get("outputTokens"),
    )

