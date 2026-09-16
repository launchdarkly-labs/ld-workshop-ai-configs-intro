# End-state for Evaluate Challenge 08 — "Otto Knows When to Fold".
#
# Sets the otto-assistant fallthrough to otto-formal so real /chat traffic
# routes to the deliberately off-brand variation, the brand-voice judge
# scores low, and the in-app adaptive loop has something to detect.
#
# No new LD resources are created — the variation and the metric all exist
# from prior challenges. This module just kicks the fallthrough into the
# "bad" state the learner will then watch their adaptive code recover from.

resource "null_resource" "set_fallthrough_to_formal" {
  triggers = {
    # Re-run if the project changes (idempotent per-project).
    project = var.project_key
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      FORMAL_ID=$(curl -fsS -X GET \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        | jq -r '.variations[]? | select(.key=="otto-formal") | ._id')

      if [ -z "$FORMAL_ID" ] || [ "$FORMAL_ID" = "null" ]; then
        echo "Could not locate otto-formal variation. Has Challenge 07 been completed?"
        exit 1
      fi

      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw "$(jq -n --arg v "$FORMAL_ID" \
          '{environmentKey:"test", instructions:[{kind:"updateFallthroughVariationOrRollout", variationId:$v}]}')" \
        > /dev/null
    EOT
  }
}
