# End-state for Evaluate Challenge 08 — "Otto Knows When to Fold".
#
# Sets the otto-assistant fallthrough to otto-formal so real /chat traffic
# routes to the deliberately off-brand variation, the brand-voice judge
# scores low, and the in-app adaptive loop has something to detect.
#
# No new LD resources are created — the variation and the metric all exist
# from prior challenges. Variation ids are looked up via value._ldMeta.variationKey
# (the targeting payload has no top-level `key` on variations; verified 2026-10-06). This module just kicks the fallthrough into the
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
        | jq -r '.variations[]? | select(.value._ldMeta.variationKey=="otto-formal") | ._id')

      if [ -z "$FORMAL_ID" ] || [ "$FORMAL_ID" = "null" ]; then
        echo "Could not locate otto-formal variation. Has Challenge 07 been completed?"
        exit 1
      fi

      # Right after a guarded rollout ends (auto-revert or Stop release) the
      # targeting PATCH can briefly return HTTP 500 while LD finalizes the
      # release (seen live 2026-10-06; the same call succeeded ~30s later).
      # Retry a few times before giving up.
      ATTEMPT=1
      until curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw "$(jq -n --arg v "$FORMAL_ID" \
          '{environmentKey:"test", instructions:[{kind:"updateFallthroughVariationOrRollout", variationId:$v}]}')" \
        > /dev/null; do
        if [ "$ATTEMPT" -ge 8 ]; then
          echo "Giving up setting the fallthrough to otto-formal after $ATTEMPT attempts."
          exit 1
        fi
        echo "Fallthrough PATCH failed (attempt $ATTEMPT); retrying in 10s..."
        ATTEMPT=$((ATTEMPT + 1))
        sleep 10
      done
      echo "Fallthrough now serves otto-formal."
    EOT
  }
}
