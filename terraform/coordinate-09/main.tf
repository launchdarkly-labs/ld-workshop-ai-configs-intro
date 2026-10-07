# Coordinate Challenge 09 — "per-agent-rollout".
#
# Adds a second variation to concierge-otto-rewriter backed by Amazon Nova
# Lite (cheaper, noticeably worse at Otto's voice). setup-workstation applies
# this module so the variation exists before the learner opens the Targeting
# tab; the learner (or solve-workstation) then starts a guarded rollout from
# Default to this variation, watching otto-brand-voice-score.
#
# The point of the challenge: the rollout touches ONE node of the graph.
# Toggle, Curator, Tailor and Tracker keep serving their Default variations
# throughout; only Otto's rewrite step is at risk — and it's guarded.
#
# Model config key is the account-global Bedrock Nova Lite entry (same way
# Evaluate ch03 uses the global Haiku entry). The app maps the served model
# name "amazon.nova-lite-v1:0" to the us. inference profile.

# The lite variation reuses Otto's rewriter instructions verbatim — only the
# model changes. Keep this text in sync with coordinate-05/main.tf.
resource "launchdarkly_ai_config_variation" "otto_rewriter_lite" {
  project_key      = var.project_key
  config_key       = "concierge-otto-rewriter"
  key              = "otto-rewriter-lite"
  name             = "Otto Rewriter (Lite)"
  model_config_key = "Bedrock.amazon.nova-lite-v1:0"
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
