# End-state for Evaluate Challenge 06 — "A vs. B".
#
# Adds the otto-recommender contender variation, then sets up + starts an
# experiment comparing it head-to-head with otto-born on the
# otto-brand-voice-score metric. The contender's prompt differs from
# otto-born by exactly one sentence — proactive recommendation of a
# complementary item. Whether that helps or hurts the brand-voice score is
# the experimental question.
#
# Experiment creation isn't exposed by the Terraform provider; setup-
# experiment.py drives the REST calls via null_resource. The script
# fetches the variationIds and the Config version from the live LD API,
# then POSTs to /experiments and starts the first iteration.
#
# VERIFY (per Phase 0 of PHASES-evaluate.md): the exact ruleId value for
# the fallthrough in an experiment's `flags` map is not documented; the
# helper script tries the literal string "fallthrough" first and falls
# back to enumerating the targeting response.

locals {
  recommender_prompt = <<-PROMPT
    {{snippet.brand-voice#1}}

    You work at ToggleWear, an online shop for LaunchDarkly-branded apparel. Help customers find products, answer questions about sizing and care, and guide them when they're not sure what they want. When recommending a product, briefly mention one complementary item from the catalog that pairs well with it — keep it natural, not pushy.

    {{snippet.safety-rules#1}}
  PROMPT
}

# ─── Contender variation ───────────────────────────────────────────────────

resource "launchdarkly_ai_config_variation" "otto_recommender" {
  project_key      = var.project_key
  config_key       = "otto-assistant"
  key              = "otto-recommender"
  name             = "Otto (Recommender)"
  model_config_key = "Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0"

  messages {
    role    = "system"
    content = trimspace(local.recommender_prompt)
  }
}

# ─── Experiment setup ──────────────────────────────────────────────────────
#
# Calls the helper to create + start the experiment. Idempotent: the helper
# is a no-op if an experiment with the same key already exists.

resource "null_resource" "setup_experiment" {
  depends_on = [launchdarkly_ai_config_variation.otto_recommender]

  triggers = {
    contender_id = launchdarkly_ai_config_variation.otto_recommender.variation_id
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/setup-experiment.py --project ${var.project_key}"
  }
}
