# End-state for Coordinate Challenge 04 — "the-tracker".
#
# Creates the `concierge-tracker` AgentControl Config in **agent** mode with one
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
    You are the Tracker, ToggleWear's order and shipping specialist. A customer asked about an order, delivery, a return, or a payment, and Toggle routed it to you.

        What you know: standard shipping takes 3-5 business days within the US; international shipping takes 7-14 business days; returns are accepted within 30 days for unworn items with tags; refunds post to the original payment method within 5-7 business days of the return arriving.

        You do NOT have access to the customer's order, tracking number, or account. Never claim to have looked anything up and never invent an order status, a date, or a tracking number. When the customer needs their specific order, tell them exactly what to do: check the confirmation email for the tracking link, or contact support@togglewear.example with the order number.

        Write a complete, factual answer in two to four sentences. Don't worry about tone — a teammate polishes the wording before the customer sees it.
  TXT
  )
}

resource "launchdarkly_ai_config" "concierge_tracker" {
  project_key = var.project_key
  key         = "concierge-tracker"
  name        = "Concierge Tracker"
  description = "Order-status specialist. Handles orders, shipping, and returns without inventing data."
  mode        = "agent"
  tags        = ["instruqt", "ai-configs-intro", "concierge"]
}

resource "launchdarkly_ai_config_variation" "concierge_tracker" {
  project_key      = var.project_key
  config_key       = launchdarkly_ai_config.concierge_tracker.key
  key              = "default"
  name             = "Default"
  model_config_key = "Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0"
  description      = "Order-status specialist. Handles orders, shipping, and returns without inventing data."
  instructions     = local.instructions
}

# Point the Test environment's Default rule at the variation so the SDK
# evaluates it as enabled. Freshly created configs serve the auto-generated
# "disabled" variation until this happens. (Same pattern as Evaluate ch03.)
resource "null_resource" "set_concierge_tracker_fallthrough" {
  triggers = {
    variation_id = launchdarkly_ai_config_variation.concierge_tracker.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/concierge-tracker/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{"environmentKey":"test","instructions":[{"kind":"updateFallthroughVariationOrRollout","variationId":"${launchdarkly_ai_config_variation.concierge_tracker.variation_id}"}]}' \
        > /dev/null
    EOT
  }
}
