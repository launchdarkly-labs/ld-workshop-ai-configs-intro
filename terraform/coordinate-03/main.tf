# End-state for Coordinate Challenge 03 — "the-tailor".
#
# Creates the `concierge-tailor` AgentControl Config in **agent** mode with one
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
    You are the Tailor, ToggleWear's sizing specialist. A customer asked about fit or sizing and Toggle routed it to you.

        What you know: ToggleWear apparel runs true to size and is unisex-cut. The Rocket Tee and Feature Branch Crewneck come in XS through XXL. The Feature Flag Hoodie comes in S through XXL. The Dark Mode Cap is one-size with an adjustable strap. Toggle Socks fit US shoe sizes 6 through 13.

        You do NOT have the customer's measurements, order history, or a size chart beyond what's above. When a question needs information you don't have, say so and tell the customer what to check (the size guide on the product page, or their own measurements). Never guess a specific size for a specific person.

        Write a complete, factual answer in two to four sentences. Don't worry about tone — a teammate polishes the wording before the customer sees it.
  TXT
  )
}

resource "launchdarkly_ai_config" "concierge_tailor" {
  project_key = var.project_key
  key         = "concierge-tailor"
  name        = "Concierge Tailor"
  description = "Sizing specialist. Handles fit and measurement questions honestly."
  mode        = "agent"
  tags        = ["instruqt", "ai-configs-intro", "concierge"]
}

resource "launchdarkly_ai_config_variation" "concierge_tailor" {
  project_key      = var.project_key
  config_key       = launchdarkly_ai_config.concierge_tailor.key
  key              = "default"
  name             = "Default"
  model_config_key = "Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0"
  description      = "Sizing specialist. Handles fit and measurement questions honestly."
  instructions     = local.instructions
}

# Point the Test environment's Default rule at the variation so the SDK
# evaluates it as enabled. Freshly created configs serve the auto-generated
# "disabled" variation until this happens. (Same pattern as Evaluate ch03.)
resource "null_resource" "set_concierge_tailor_fallthrough" {
  triggers = {
    variation_id = launchdarkly_ai_config_variation.concierge_tailor.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/concierge-tailor/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{"environmentKey":"test","instructions":[{"kind":"updateFallthroughVariationOrRollout","variationId":"${launchdarkly_ai_config_variation.concierge_tailor.variation_id}"}]}' \
        > /dev/null
    EOT
  }
}
