# End-state for Coordinate Challenge 01 — "toggle".
#
# Creates the `concierge-toggle` AgentControl Config in **agent** mode with one
# Default variation (Bedrock Haiku 4.5) and points the Test environment's
# Default rule at it.
#
# Agent-mode variations carry `description` + `instructions` (a single
# string) instead of a `messages` array. Snippet references such as
# {{snippet.brand-voice#1}} and {{variable}} placeholders are expanded by
# LaunchDarkly / the SDK exactly as they are for completion messages
# (verified live 2026-10-07 against the Python AI SDK 0.20.1).

locals {
  instructions = trimspace(<<-TXT
    You are Toggle, the front desk of ToggleWear's Concierge team. ToggleWear is an online shop for LaunchDarkly-branded apparel.

        Your only job is to read the customer's message and decide which specialist should handle it:
        - product — questions about what we sell: items, prices, colors, materials, recommendations, gifts.
        - sizing — questions about fit, measurements, which size to pick, how something runs.
        - orders — questions about an order, shipping, delivery, returns, refunds, or payment.

        Respond with exactly one lowercase word: product, sizing, or orders. No punctuation, no explanation, nothing else. If the message is off-topic or you can't tell, respond with product.
  TXT
  )
}

resource "launchdarkly_ai_config" "concierge_toggle" {
  project_key = var.project_key
  key         = "concierge-toggle"
  name        = "Concierge Toggle"
  description = "Triage. Reads the customer's message and names the specialist who should handle it."
  mode        = "agent"
  tags        = ["instruqt", "ai-configs-intro", "concierge"]
}

resource "launchdarkly_ai_config_variation" "concierge_toggle" {
  project_key      = var.project_key
  config_key       = launchdarkly_ai_config.concierge_toggle.key
  key              = "default"
  name             = "Default"
  model_config_key = "Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0"
  instructions     = local.instructions
}

# Point the Test environment's Default rule at the variation so the SDK
# evaluates it as enabled. Freshly created configs serve the auto-generated
# "disabled" variation until this happens. (Same pattern as Evaluate ch03.)
resource "null_resource" "set_concierge_toggle_fallthrough" {
  triggers = {
    variation_id = launchdarkly_ai_config_variation.concierge_toggle.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/concierge-toggle/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{"environmentKey":"test","instructions":[{"kind":"updateFallthroughVariationOrRollout","variationId":"${launchdarkly_ai_config_variation.concierge_toggle.variation_id}"}]}' \
        > /dev/null
    EOT
  }
}
