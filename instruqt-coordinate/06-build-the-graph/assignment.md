---
slug: build-the-graph
id: gsx8xc38ahsf
type: challenge
title: Build the Graph
teaser: Wire the five agent Configs into an agent graph with handoff data on every
  edge.
notes:
- type: text
  contents: 'Wire the five agent Configs into an agent graph: Toggle as the root,
    an edge to each specialist carrying a routing hint, and an edge from each specialist
    to Otto. The graph is topology plus handoff data; your code does the traversing
    in the next challenge.'
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
3. For **Name**, enter:
```text
Concierge
```
   The key `concierge` appears under the name (there's an **Edit key** link if it differs).
4. For **Description**, enter:
```text
Toggle triages, a specialist answers, Otto rewrites.
```
5. Click **Create**. The graph builder opens on the **Graph** tab with an empty canvas.

# Add the root and the specialists

Every node is an agent Config. The first node you add is the root, where the workflow starts. Nodes are added from their parent: each node has an arrow handle at its bottom edge, and clicking it adds a connected child.

1. Click **Add your first agent**. A node appears with a **Select an agent...** picker; choose **Concierge Toggle**. Toggle is now the root.
2. Click the **↓** handle at the bottom of the Toggle node. A new connected node appears; in its picker choose **Concierge Curator**.
3. Click Toggle's **↓** handle again and choose **Concierge Tailor**.
4. Click Toggle's **↓** handle once more and choose **Concierge Tracker**.

Use **Fit View** (the frame icon in the canvas controls, bottom left) whenever the nodes run off screen.

# Add Otto and the handoff data

Six edges: three out of Toggle, three into Otto. Each Toggle edge carries a `route` so the server can match Toggle's one-word answer to a specialist. Each specialist edge carries a `step` that labels what happens next. Every edge has an **Edit** button on it; that's where the handoff JSON goes.

1. Click the **↓** handle on **Concierge Curator** and choose **Concierge Otto Rewriter**.
2. Click the **↓** handle on **Concierge Tailor** and choose **Concierge Otto Rewriter** again. Then do the same from **Concierge Tracker**. The builder shows a card per edge while you work; when you save, the three cards collapse into one Otto node with three incoming edges, because a graph has one node per Config.
3. Now the handoffs. Click **Edit** on the Toggle → Curator edge. In the **Handoff data** dialog, enter the JSON below and click **Save**:
```json
{"route": "product"}
```
4. Toggle → **Concierge Tailor**:
```json
{"route": "sizing"}
```
5. Toggle → **Concierge Tracker**:
```json
{"route": "orders"}
```
6. Each of the three edges into **Concierge Otto Rewriter**:
```json
{"step": "rewrite"}
```
7. Click **Save** at the top right of the graph. A toast reads **Agent graph updated**.

# What the SDK will see

When your code asks for this graph, it gets back the root node, every node's resolved agent Config (model, instructions, with snippets already expanded), and the edges with their handoff data as plain dictionaries. The handoff is yours to interpret. In Challenge 07 the server reads `route` to pick a specialist and follows the specialist's only edge to Otto.

Click **Check** when the `concierge` graph exists with Toggle as the root, six edges, and `route` handoff data on each of Toggle's edges.
