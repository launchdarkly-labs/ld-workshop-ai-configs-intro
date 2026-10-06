# End-state for Evaluate Challenge 02 — "Quick Takes".
#
# Attaches the three built-in judges (Accuracy, Relevance, Toxicity) to the
# otto-born variation at a 25% sampling rate each.
#
# How built-in judges actually work (verified 2026-10-06 by capturing the
# web app's traffic while clicking "+ Add judges"):
#
#   * Built-ins are NOT pre-provisioned in a project. The picker lists them
#     from an account-level template; the moment you click "Add N judges"
#     the UI POSTs each one to /api/v2/projects/{key}/ai-configs as a normal
#     judge-mode config (keys `accuracy`, `relevance`, `toxicity`, each with
#     a `default` variation on Bedrock Sonnet 4.5 and
#     evaluationMetricKey `$ld:ai:judge:<key>`). The captured bodies live in
#     ./builtin-judges/*.json and are replayed verbatim here.
#   * The auto-created judge configs come up enabled in every environment
#     with fallthrough -> Default, so nothing else is needed to "turn them on".
#   * Attaching = PATCH the variation with
#       {"judgeConfiguration":{"judges":[{"judgeConfigKey":"accuracy","samplingRate":0.25},...]}}
#     using the SHORT key, not the $ld:ai:judge:* event key.
#   * GET .../variations/{key} returns a versions list ({items:[...]}), so
#     anything reading judgeConfiguration back must take the max version.

locals {
  api_base      = "https://app.launchdarkly.com/api/v2"
  sampling_rate = 0.25
  judge_keys    = ["accuracy", "relevance", "toxicity"]
}

# Materialize the built-in judge configs in the project (idempotent: a 409
# from an existing key is swallowed).
resource "null_resource" "create_built_in_judges" {
  triggers = {
    templates = sha256(join("", [for k in local.judge_keys : file("${path.module}/builtin-judges/${k}.json")]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      for k in ${join(" ", local.judge_keys)}; do
        # A duplicate POST returns 400 (not 409), so probe first.
        EXISTS=$(curl -sS -o /dev/null -w '%%{http_code}' \
          '${local.api_base}/projects/${var.project_key}/ai-configs/'$k \
          -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
          -H 'LD-API-Version: beta')
        if [ "$EXISTS" = "200" ]; then
          echo "Built-in judge '$k' already exists."
          continue
        fi
        curl -fsS -X POST \
          '${local.api_base}/projects/${var.project_key}/ai-configs' \
          -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
          -H 'Content-Type: application/json' \
          -H 'LD-API-Version: beta' \
          --data-binary @'${path.module}/builtin-judges/'$k'.json' \
          > /dev/null
        echo "Created built-in judge '$k'."
      done
    EOT
  }
}

resource "null_resource" "attach_built_in_judges" {
  depends_on = [null_resource.create_built_in_judges]

  triggers = {
    config    = "otto-assistant"
    variation = "otto-born"
    rate      = local.sampling_rate
    judges    = join(",", local.judge_keys)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      curl -fsS -X PATCH \
        '${local.api_base}/projects/${var.project_key}/ai-configs/otto-assistant/variations/otto-born' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json' \
        -H 'LD-API-Version: beta' \
        --data-raw "$(jq -n --argjson rate ${local.sampling_rate} \
          '{judgeConfiguration: {judges: [
            {judgeConfigKey: "accuracy",  samplingRate: $rate},
            {judgeConfigKey: "relevance", samplingRate: $rate},
            {judgeConfigKey: "toxicity",  samplingRate: $rate}
          ]}}')" \
        > /dev/null
      echo "Attached accuracy/relevance/toxicity to otto-born at ${local.sampling_rate}."
    EOT
  }
}
