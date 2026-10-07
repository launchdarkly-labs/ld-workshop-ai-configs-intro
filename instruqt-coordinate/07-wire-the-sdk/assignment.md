---
slug: wire-the-sdk
id: zpbosvxzm1pb
type: challenge
title: Wire the SDK
teaser: Traverse the graph from Python — server.py becomes a multi-agent dispatcher.
notes:
- type: text
  contents: Replace Otto's single Bedrock call in server.py with graph-driven dispatch.
    The Python SDK hands your code the graph, each node's resolved agent Config, and
    the handoff data on every edge; your code calls Toggle, follows the matching edge
    to a specialist, then hands the draft to Otto.
tabs:
- id: dokcdq2kd5yy
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: oulmnzo4kbvp
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: stizveg10dgv
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 1200
enhanced_loading: null
---

# From one call to a dispatch

Right now `/chat` evaluates **Otto Assistant** and makes one Bedrock call. In this challenge you replace that whole section with graph-driven dispatch:

1. Ask the SDK for the `concierge` graph for this customer's context.
2. Call the root node, Toggle. He answers with one word.
3. Find the edge out of Toggle whose handoff `route` matches that word, and call the specialist at the other end.
4. Follow the specialist's edge to Otto-the-rewriter and call him with the question and the draft.
5. Return Otto's rewrite.

The Evaluate-era judge blocks stay exactly where they are. They used to grade Otto Assistant's answer; now they grade the rewriter's output, and the brand-voice judge's results are recorded against the rewriter's Config.

# What the SDK gives you

```python
graph = ai_client.agent_graph("concierge", context)   # AgentGraphDefinition
root = graph.root()                                   # AgentGraphNode
agent = root.get_config()                             # AIAgentConfig: .model, .instructions, .enabled, .create_tracker()
edges = root.get_edges()                              # list of Edge: .source_config, .target_config, .handoff (dict)
node = graph.get_node("concierge-curator")
```

Three things worth knowing before you paste:

- **Snippets are already expanded.** `agent.instructions` for the Curator starts with the full catalog text, not `{{snippet.product-catalog#1}}`.
- **So is everything else in double braces.** The SDK renders an agent task as a Mustache template with no variables, so a `{{placeholder}}` of your own comes back as an empty string. Per-request data (the customer's question, the specialist's draft) goes in the user turn; that's what the paste does for the rewriter.
- **Every node's tracker is tagged with the graph key.** `agent.create_tracker()` records tokens, latency and success for that node, and the events carry `graphKey: concierge`, so Monitoring can roll the whole team up as one system. `graph.create_tracker()` records one success or failure per request for the graph itself.

# Replace the Otto block

Open the [Code Editor](#tab-2) tab and open `app/server.py`.

1. Find this comment inside the `chat` handler:
```python
    # ─── Challenge 01: wire Otto to /chat ─────────────────────────────────
```
2. Select from that line down to the line **just before** this comment (leave this one in place; the judge blocks below it stay):
```python
    # ─── Challenge 07 judge injects below this marker ──────────────────────
```
   That selection covers the Otto Config evaluation, the Bedrock call, the history update, and the `log.info(...)` call.
3. Delete the selection and paste the block below in its place. Every line starts with four spaces; if your editor re-indents on paste, fix it so the block sits inside the `chat` function.

```python
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
```

4. Save. The service reloads on its own.

# Try it

Open the [ToggleWear](#tab-1) tab and ask three questions, one per specialist:

- `Do you have anything in green?`
- `Does the hoodie run large?`
- `How long does shipping take?`

Each answer should still sound like Otto. Now open the [Code Editor](#tab-2) terminal (**Terminal → New Terminal**) and watch the routing:

```bash
journalctl -u togglewear -f | grep concierge
```

Every request logs the route Toggle chose, the specialist that drafted, and the model that rewrote.

# In LaunchDarkly

Open the [LaunchDarkly](#tab-0) tab and go to **Agents → Graphs → Concierge**. The **Graph** tab now carries numbers: **Global values** at the top shows the graph's invocations, and every node card shows its own **Invocations** (with the share of traffic that reached it), **Avg. duration**, **Error rate** and token counts. Toggle and the rewriter sit at 100% because every request passes through them; the three specialists split the rest according to what customers asked. The **Monitoring** tab charts the same metrics over time, all tagged with the one graph key.

Click **Check** when `server.py` evaluates the `concierge` graph, the old Otto block is gone, and the app answers a question through the team.
