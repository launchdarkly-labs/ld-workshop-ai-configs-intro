---
slug: build-the-graph
id: gsx8xc38ahsf
type: challenge
title: Build the Graph
teaser: Wire the five agent Configs into an agent graph with handoff data on every
  edge.
notes:
- type: text
  contents: >-
    Wire the five agent Configs into an agent graph: Toggle as the root, an edge to each specialist carrying a routing hint, and an edge from each specialist to Otto. The graph is topology plus handoff data; your code does the traversing in the next challenge.
tabs:
- id: yegs3yooq5z9
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: ni6jzpzgxs7k
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: yofz6v1iyshc
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 900
enhanced_loading: null
---

# Five agents, no connections

You have five agent-mode Configs that know nothing about each other. An **agent graph** is how LaunchDarkly records the topology: which Config is the root, which Configs hand off to which, and what data travels along each handoff.

The graph is data, not code. LaunchDarkly doesn't run it or call any model. Your application reads the graph through the SDK and decides what to do at each node. That's Challenge 07. Here you build the map.

# Create the graph

Open the [LaunchDarkly](#tab-0) tab.

1. In the left-hand navigation, make sure the **Code | Agents** selector reads **Agents**, then click **Graphs**.
2. Click **Create new graph**.
3. For the name, enter:
```text
Concierge
```
   The key becomes `concierge`. If the dialog shows a different key, click **Edit key** and set it to `concierge`.
4. For the description, enter:
```text
Toggle triages, a specialist answers, Otto rewrites.
```
5. Click **Create**. The graph builder opens.
<!-- VERIFY: capture the exact Create new graph dialog fields (name, Edit key, description) and whether the builder opens automatically. -->

# Add the nodes

Add the five Concierge Configs to the canvas and mark Toggle as the root.

1. Click **Add agent** (or the **+** on the canvas) and pick **Concierge Toggle**. Mark it as the **root** node.
2. Add **Concierge Curator**, **Concierge Tailor**, **Concierge Tracker**, and **Concierge Otto Rewriter** the same way.
<!-- VERIFY: capture the builder's exact controls for adding a node and designating the root (button labels, context menu). -->

# Draw the edges and add handoff data

Six edges: three out of Toggle, three into Otto. Each Toggle edge carries a `route` so the server can match Toggle's one-word answer to a specialist. Each specialist edge carries a `step` that labels what happens next.

1. Drag from **Concierge Toggle** to **Concierge Curator** to create an edge. Click the **+** on the edge, enter the JSON below, and click outside the box to save it:
```json
{"route": "product"}
```
2. Toggle → **Concierge Tailor**:
```json
{"route": "sizing"}
```
3. Toggle → **Concierge Tracker**:
```json
{"route": "orders"}
```
4. **Concierge Curator** → **Concierge Otto Rewriter**:
```json
{"step": "rewrite"}
```
5. **Concierge Tailor** → **Concierge Otto Rewriter**:
```json
{"step": "rewrite"}
```
6. **Concierge Tracker** → **Concierge Otto Rewriter**:
```json
{"step": "rewrite"}
```
7. Save the graph.
<!-- VERIFY: confirm how an edge is created in the builder (drag between nodes vs. an Add edge control), the exact handoff editor behaviour (the docs say: click + on the edge, enter JSON, click outside to save), and whether there is an explicit Save button. -->

# What the SDK will see

When your code asks for this graph, it gets back the root node, every node's resolved agent Config (model, instructions, with snippets already expanded), and the edges with their handoff data as plain dictionaries. The handoff is yours to interpret. In Challenge 07 the server reads `route` to pick a specialist and follows the specialist's only edge to Otto.

Click **Check** when the `concierge` graph exists with Toggle as the root, six edges, and `route` handoff data on each of Toggle's edges.
