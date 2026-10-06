# End-state for Evaluate Challenge 03 — "Otto Sounds Like Otto".
#
# Creates the custom brand-voice judge — a Config in judge mode whose prompt
# pulls in the L1 `brand-voice` snippet. The same snippet now drives both
# Otto's prompt (in otto-assistant) AND the criteria he's graded against.
#
# Resources:
#   * launchdarkly_ai_config       - otto-brand-voice-judge (mode = judge)
#   * launchdarkly_ai_config_variation - default variation, Haiku-backed,
#                                       prompt references {{snippet.brand-voice#1}}
#                                       and {{response}}
#   * null_resource set_judge_fallthrough - turn the judge on by pointing
#                                          test env fallthrough at default
#   * launchdarkly_metric          - otto-brand-voice-score (numeric, mean)
#   * null_resource attach_judge_to_otto - add otto-brand-voice-judge to the
#                                          judgeConfiguration of otto-born and
#                                          otto-premium (merging with ch02's
#                                          built-ins), 25% sampling.
#
# Verified against the live UI 2026-10-06: the Create config dialog lets the
# learner set the key explicitly (Edit config key), judge configs carry
# evaluationMetricKey "$ld:ai:judge:<key>" and isInverted, and judges are
# attached to a variation via PATCH .../variations/{key} with
# {"judgeConfiguration":{"judges":[{"judgeConfigKey":"<key>","samplingRate":0.25}]}}.
#
# setup-workstation applies `-target=launchdarkly_metric.brand_voice_score`
# so the metric exists in the learner path too (the UI flow never creates
# it, but ch06's experiment and ch07's guarded rollout need it).

locals {
  brand_voice_judge_prompt = <<-PROMPT
    You are evaluating whether a response from Otto, ToggleWear's shopping assistant, adheres to the brand voice we want him to use.

    The brand voice is:

    {{snippet.brand-voice#1}}

    Score the response on a scale of 0.0 to 1.0:
    - 1.0: Strongly on-brand. Warm, helpful, a little playful, honest, concise.
    - 0.7: Mostly on-brand with minor issues.
    - 0.4: Lacking warmth or has noticeable voice issues.
    - 0.0: Off-brand. Robotic, off-topic, or contradicts the voice entirely.

    Respond with ONLY a number between 0.0 and 1.0. No other text.

    Response to evaluate:
    {{response}}
  PROMPT
}

# ─── Brand-voice judge Config ──────────────────────────────────────────────

resource "launchdarkly_ai_config" "brand_voice_judge" {
  project_key           = var.project_key
  key                   = "otto-brand-voice-judge"
  name                  = "Otto Brand Voice Judge"
  evaluation_metric_key = "$ld:ai:judge:otto-brand-voice-judge"
  description           = "Scores Otto's responses 0.0-1.0 for adherence to the brand-voice snippet. Drives otto-brand-voice-score; Evaluate ch07's guarded rollout watches this."
  mode                  = "judge"
  tags                  = ["instruqt", "ai-configs-intro"]
}

resource "launchdarkly_ai_config_variation" "brand_voice_judge_default" {
  project_key      = var.project_key
  config_key       = launchdarkly_ai_config.brand_voice_judge.key
  key              = "default"
  name             = "Default"
  model_config_key = "Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0"

  messages {
    role    = "system"
    content = trimspace(local.brand_voice_judge_prompt)
  }
}

resource "null_resource" "set_brand_voice_judge_fallthrough" {
  triggers = {
    variation_id = launchdarkly_ai_config_variation.brand_voice_judge_default.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/${launchdarkly_ai_config.brand_voice_judge.key}/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{"environmentKey":"test","instructions":[{"kind":"updateFallthroughVariationOrRollout","variationId":"${launchdarkly_ai_config_variation.brand_voice_judge_default.variation_id}"}]}'
    EOT
  }
}

# ─── Brand-voice score metric ──────────────────────────────────────────────

resource "launchdarkly_metric" "brand_voice_score" {
  project_key           = var.project_key
  key                   = "otto-brand-voice-score"
  name                  = "Otto Brand Voice Score"
  description           = "Mean brand-voice judge score (0.0-1.0) for Otto's responses. Higher is better."
  kind                  = "custom"
  event_key             = "otto-brand-voice-score"
  is_numeric            = true
  unit                  = "score"
  unit_aggregation_type = "average"
  success_criteria      = "HigherThanBaseline"
  analysis_type         = "mean"
  randomization_units   = ["user"]
  tags                  = ["instruqt"]
}

# ─── Attach the judge to Otto's variations ────────────────────────────────
#
# PATCHing judgeConfiguration replaces the whole list, so merge with whatever
# is already attached (ch02's built-ins) and only add ours if missing.

resource "null_resource" "attach_judge_to_otto" {
  depends_on = [launchdarkly_ai_config_variation.brand_voice_judge_default]

  triggers = {
    judge = launchdarkly_ai_config.brand_voice_judge.key
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
        if printf '%s' "$CURRENT" | jq -e 'map(.judgeConfigKey) | index("${launchdarkly_ai_config.brand_voice_judge.key}")' > /dev/null; then
          echo "$V already has ${launchdarkly_ai_config.brand_voice_judge.key} attached."
          continue
        fi
        curl -fsS -X PATCH \
          'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/variations/'$V \
          -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" -H 'LD-API-Version: beta' \
          -H 'Content-Type: application/json' \
          --data-raw "$(printf '%s' "$CURRENT" | jq -c '{judgeConfiguration: {judges: (. + [{judgeConfigKey: "${launchdarkly_ai_config.brand_voice_judge.key}", samplingRate: 0.25}])}}')" \
          > /dev/null
        echo "Attached ${launchdarkly_ai_config.brand_voice_judge.key} to $V."
      done
    EOT
  }
}
