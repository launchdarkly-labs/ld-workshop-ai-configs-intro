# End-state for Evaluate Challenge 04 — "Otto Checks His Facts".
#
# Creates the product-claim judge — a Config in judge mode that grades
# whether Otto's responses contain claims contradicting the ToggleWear
# catalog. The catalog itself lives in a snippet (`product-catalog`), so
# the same snippet-as-data pattern that drives the brand-voice judge
# drives this one too. Adding a new product means editing one snippet.
#
# Resources:
#   * null_resource create_product_catalog_snippet - REST POST (snippets
#     aren't exposed by the Terraform provider)
#   * launchdarkly_ai_config           - otto-claim-accuracy-judge
#   * launchdarkly_ai_config_variation - default, Haiku-backed
#   * null_resource set_judge_fallthrough
#   * launchdarkly_metric              - otto-claim-accuracy-score
#
#   * null_resource attach_judge_to_otto - add the judge to otto-born and
#     otto-premium's judgeConfiguration (merging with existing judges)
#
# Model key is the GLOBAL Bedrock Haiku entry so the solve state matches
# what the learner picks in the UI. The judge's evaluationMetricKey defaults
# to "$ld:ai:judge:otto-claim-accuracy-judge" (that's what the UI generates).
#
# setup-workstation applies `-target=launchdarkly_metric.claim_accuracy_score`
# so the metric exists in the learner path too (the UI flow never creates it).

locals {
  product_catalog_text = trimspace(<<-CATALOG
    ToggleWear product catalog. These are the only products we sell. Anything not in this list is not a ToggleWear product.

    - Rocket Tee - $28. Heather grey, classic crew-neck t-shirt with the LaunchDarkly rocket.
    - Feature Flag Hoodie - $58. Midnight navy, pullover with embroidered flag logo.
    - Dark Mode Cap - $24. Six-panel dad cap with tone-on-tone black logo.
    - Ship It Mug - $16. 12oz ceramic, "Ship it" in the LaunchDarkly font.
    - Toggle Socks - $14. Crew socks with a tiny rocket on the ankle.
    - Release Notes Notebook - $18. A5 hardcover with dot grid.
    - Rollout Tote - $22. 12oz canvas with reinforced handles.
    - Feature Branch Crewneck - $52. Heavyweight sage green sweatshirt.

    Otto should not invent stock, sizes, materials beyond what's listed, colors not listed, return policies, shipping details, or any other facts not stated above. He may suggest customers check the product page or contact support for specifics he doesn't have.
  CATALOG
  )

  claim_judge_prompt = <<-PROMPT
    You are evaluating whether Otto's response to a customer makes any factual product claims that contradict the ToggleWear catalog.

    The catalog is the only source of truth:

    {{snippet.product-catalog#1}}

    Customer's question:
    {{input}}

    Otto's response:
    {{response}}

    Score 0.0 to 1.0:
    - 1.0: Response makes no claims that contradict the catalog, OR makes no factual product claims at all (e.g. asks a clarifying question, gracefully declines).
    - 0.5: Borderline — mentions a product detail not in the catalog but doesn't clearly contradict it.
    - 0.0: Response asserts a price, material, size, color, policy, or other fact that contradicts or is unsupported by the catalog.

    Respond with ONLY a number between 0.0 and 1.0. No other text.
  PROMPT
}

# ─── Product-catalog snippet ───────────────────────────────────────────────

resource "null_resource" "create_product_catalog_snippet" {
  triggers = {
    text_hash = sha256(local.product_catalog_text)
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X POST \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/prompt-snippets' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json' \
        --data-raw "$(jq -n --arg t "${local.product_catalog_text}" \
          '{key:"product-catalog", name:"Product catalog", text:$t, tags:["instruqt"]}')" \
        || echo "(snippet may already exist — continuing)"
    EOT
  }
}

# ─── Product-claim judge Config ────────────────────────────────────────────

resource "launchdarkly_ai_config" "claim_judge" {
  project_key = var.project_key
  key         = "otto-claim-accuracy-judge"
  name        = "Otto Claim Accuracy Judge"
  description = "Scores Otto's responses 0.0-1.0 for accuracy against the product-catalog snippet. Drives otto-claim-accuracy-score."
  mode        = "judge"
  tags        = ["instruqt", "ai-configs-intro"]
}

resource "launchdarkly_ai_config_variation" "claim_judge_default" {
  project_key      = var.project_key
  config_key       = launchdarkly_ai_config.claim_judge.key
  key              = "default"
  name             = "Default"
  model_config_key = "Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0"

  depends_on = [null_resource.create_product_catalog_snippet]

  messages {
    role    = "system"
    content = trimspace(local.claim_judge_prompt)
  }
}

resource "null_resource" "set_claim_judge_fallthrough" {
  triggers = {
    variation_id = launchdarkly_ai_config_variation.claim_judge_default.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/${launchdarkly_ai_config.claim_judge.key}/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{"environmentKey":"test","instructions":[{"kind":"updateFallthroughVariationOrRollout","variationId":"${launchdarkly_ai_config_variation.claim_judge_default.variation_id}"}]}'
    EOT
  }
}

# ─── Claim-accuracy score metric ───────────────────────────────────────────

resource "launchdarkly_metric" "claim_accuracy_score" {
  project_key           = var.project_key
  key                   = "otto-claim-accuracy-score"
  name                  = "Otto Claim Accuracy Score"
  description           = "Mean claim-accuracy judge score (0.0-1.0) for Otto's responses. Higher is better."
  kind                  = "custom"
  event_key             = "otto-claim-accuracy-score"
  is_numeric            = true
  unit                  = "score"
  unit_aggregation_type = "average"
  success_criteria      = "HigherThanBaseline"
  analysis_type         = "mean"
  randomization_units   = ["user"]
  tags                  = ["instruqt"]
}

# ─── Attach the judge to Otto's variations ────────────────────────────────

resource "null_resource" "attach_judge_to_otto" {
  depends_on = [launchdarkly_ai_config_variation.claim_judge_default]

  triggers = {
    judge = launchdarkly_ai_config.claim_judge.key
    rate  = "0.25"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      for V in otto-born otto-premium; do
        CURRENT=$(curl -fsS -X GET \
          'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/variations/'$V \
          -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" -H 'LD-API-Version: beta' \
          | jq -c '(.items // []) | max_by(.version) | .judgeConfiguration.judges // []')
        if printf '%s' "$CURRENT" | jq -e 'map(.judgeConfigKey) | index("${launchdarkly_ai_config.claim_judge.key}")' > /dev/null; then
          echo "$V already has ${launchdarkly_ai_config.claim_judge.key} attached."
          continue
        fi
        curl -fsS -X PATCH \
          'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/variations/'$V \
          -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" -H 'LD-API-Version: beta' \
          -H 'Content-Type: application/json' \
          --data-raw "$(printf '%s' "$CURRENT" | jq -c '{judgeConfiguration: {judges: (. + [{judgeConfigKey: "${launchdarkly_ai_config.claim_judge.key}", samplingRate: 0.25}])}}')" \
          > /dev/null
        echo "Attached ${launchdarkly_ai_config.claim_judge.key} to $V."
      done
    EOT
  }
}
