# End-state for Coordinate Challenge 06 — "build-the-graph".
#
# Creates the `concierge` agent graph: root concierge-toggle, three routing
# edges to the specialists (handoff {"route": ...}), three edges from the
# specialists to concierge-otto-rewriter (handoff {"step": "rewrite"}).
#
# The Terraform provider (~> 2.29) has no agent-graph resource, so this uses
# the public REST endpoint (verified live 2026-10-07):
#   POST /api/v2/projects/{proj}/agent-graphs   body: graph.json
#   GET  /api/v2/projects/{proj}/agent-graphs/{key}
# Idempotent: if the graph already exists (the learner built it in the UI)
# nothing is changed — the check script validates topology either way.

locals {
  graph = jsondecode(file("${path.module}/graph.json"))
}

resource "null_resource" "create_concierge_graph" {
  triggers = {
    graph_sha = sha256(file("${path.module}/graph.json"))
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      CODE=$(curl -sS -o /dev/null -w '%%{http_code}' \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/agent-graphs/${local.graph.key}' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" -H 'LD-API-Version: beta')
      if [ "$CODE" = "200" ]; then
        echo "Agent graph '${local.graph.key}' already exists — leaving it as the learner built it."
        exit 0
      fi
      curl -fsS -X POST \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/agent-graphs' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        -H 'Content-Type: application/json' \
        --data-binary @'${path.module}/graph.json' > /dev/null
      echo "Created agent graph '${local.graph.key}' (root ${local.graph.rootConfigKey}, ${length(local.graph.edges)} edges)."
    EOT
  }
}
