# Coordinate Challenge 07 — "wire-the-sdk".
#
# Nothing to create in LaunchDarkly: the five configs (ch01-05) and the graph
# (ch06) already exist. The change is in app/server.py — see
# concierge-server-paste.py (what the learner pastes) and patch-server.py
# (what solve-workstation runs). This module exists only so the challenge
# scripts follow the same shape as every other challenge.

resource "null_resource" "noop" {
  triggers = { note = "server.py is patched by patch-server.py; no LD resources here" }
}
