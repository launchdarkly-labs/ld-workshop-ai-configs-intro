# Coordinate Challenge 10 — "self-healing".
#
# One LaunchDarkly resource: a count metric, `concierge-self-heal`, that the
# server emits every time the synchronous brand-voice check rejects Otto's
# rewrite and regenerates it on the pinned fallback model. setup-workstation
# applies this module so the metric exists for the Monitoring view before the
# learner pastes the self-healing block; the paste itself lives in
# selfheal-server-paste.py and is installed by patch-server.py.

resource "launchdarkly_metric" "self_heal" {
  project_key           = var.project_key
  key                   = "concierge-self-heal"
  name                  = "Concierge self-heal"
  description           = "Count of rewrites that failed the synchronous brand-voice check and were regenerated on the fallback model. Lower is better."
  kind                  = "custom"
  event_key             = "concierge-self-heal"
  is_numeric            = false
  unit_aggregation_type = "sum"
  success_criteria      = "LowerThanBaseline"
  analysis_type         = "mean"
  randomization_units   = ["user"]
  tags                  = ["instruqt", "ai-configs-intro", "concierge"]
}
