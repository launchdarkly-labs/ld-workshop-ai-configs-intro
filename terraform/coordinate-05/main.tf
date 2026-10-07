# End-state for Coordinate Challenge 05 — "otto-returns".
#
# Creates the `concierge-otto-rewriter` AgentControl Config in **agent** mode with one
# Default variation (Bedrock Haiku 4.5) and points the Test environment's
# Default rule at it.
#
# Agent-mode variations carry `description` + `instructions` (a single
# string) instead of a `messages` array. Snippet references such as
# {{snippet.brand-voice#1}} and {{variable}} placeholders are expanded by
# LaunchDarkly / the SDK exactly as they are for completion messages
# (verified live 2026-10-07 against the Python AI SDK 0.20.1).
#
# This is Otto's payoff across three tracks: the SAME `brand-voice` snippet
# drives his original prompt (Build ch03), the brand-voice judge (Evaluate
# ch03), and now his rewriter instructions. One source of truth for "on-brand".
# No request-time placeholders here: the SDK renders the agent task as a
# Mustache template with no variables, so {{anything}} of ours would come
# back empty. The server sends the question + draft in the user turn (ch07).
locals {
  instructions = trimspace(<<-TXT
    {{snippet.brand-voice#1}}

    You are Otto in your new role on ToggleWear's Concierge team: the last stop before a response reaches the customer. A specialist has drafted a factually correct but plainly worded answer. Rewrite it in your own voice.

    Rules:
    - Keep every fact, number, product name, and caveat from the draft. Don't add facts the draft doesn't contain.
    - Keep it short. Two or three sentences is usually right.
    - Reply with only the rewritten response — no preamble, no quotation marks, no notes.

    The message you receive contains the customer's question followed by the specialist's draft. Rewrite the draft; don't answer the question from scratch.
  TXT
  )
}

resource "launchdarkly_ai_config" "concierge_otto_rewriter" {
  project_key = var.project_key
  key         = "concierge-otto-rewriter"
  name        = "Concierge Otto Rewriter"
  description = "Brand-voice rewriter. Otto rewrites every specialist draft in his own voice before it reaches the customer."
  mode        = "agent"
  tags        = ["instruqt", "ai-configs-intro", "concierge"]
}

resource "launchdarkly_ai_config_variation" "concierge_otto_rewriter" {
  project_key      = var.project_key
  config_key       = launchdarkly_ai_config.concierge_otto_rewriter.key
  key              = "default"
  name             = "Default"
  model_config_key = "Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0"
  description      = "Brand-voice rewriter. Otto rewrites every specialist draft in his own voice before it reaches the customer."
  instructions     = local.instructions
}

# Point the Test environment's Default rule at the variation so the SDK
# evaluates it as enabled. Freshly created configs serve the auto-generated
# "disabled" variation until this happens. (Same pattern as Evaluate ch03.)
resource "null_resource" "set_concierge_otto_rewriter_fallthrough" {
  triggers = {
    variation_id = launchdarkly_ai_config_variation.concierge_otto_rewriter.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/concierge-otto-rewriter/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{"environmentKey":"test","instructions":[{"kind":"updateFallthroughVariationOrRollout","variationId":"${launchdarkly_ai_config_variation.concierge_otto_rewriter.variation_id}"}]}' \
        > /dev/null
    EOT
  }
}
