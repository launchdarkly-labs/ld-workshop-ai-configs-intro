# End-state for Coordinate Challenge 02 — "the-curator".
#
# Creates the `concierge-curator` AgentControl Config in **agent** mode with one
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
    {{snippet.product-catalog#1}}

        You are the Curator, ToggleWear's product specialist. A customer asked a product question and Toggle routed it to you.

        Answer from the catalog above and only from the catalog. Name the exact product and price when you can. If the customer asks about something we don't carry, say so plainly and suggest the closest item we do carry. Never invent stock levels, colors, materials, or policies that aren't in the catalog.

        Write a complete, factual answer in two to four sentences. Don't worry about tone — a teammate polishes the wording before the customer sees it.
  TXT
  )
}

resource "launchdarkly_ai_config" "concierge_curator" {
  project_key = var.project_key
  key         = "concierge-curator"
  name        = "Concierge Curator"
  description = "Product specialist. Answers product questions from the ToggleWear catalog and nothing else."
  mode        = "agent"
  tags        = ["instruqt", "ai-configs-intro", "concierge"]
}

resource "launchdarkly_ai_config_variation" "concierge_curator" {
  project_key      = var.project_key
  config_key       = launchdarkly_ai_config.concierge_curator.key
  key              = "default"
  name             = "Default"
  model_config_key = "Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0"
  description      = "Product specialist. Answers product questions from the ToggleWear catalog and nothing else."
  instructions     = local.instructions
}

# Point the Test environment's Default rule at the variation so the SDK
# evaluates it as enabled. Freshly created configs serve the auto-generated
# "disabled" variation until this happens. (Same pattern as Evaluate ch03.)
resource "null_resource" "set_concierge_curator_fallthrough" {
  triggers = {
    variation_id = launchdarkly_ai_config_variation.concierge_curator.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/concierge-curator/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{"environmentKey":"test","instructions":[{"kind":"updateFallthroughVariationOrRollout","variationId":"${launchdarkly_ai_config_variation.concierge_curator.variation_id}"}]}' \
        > /dev/null
    EOT
  }
}
