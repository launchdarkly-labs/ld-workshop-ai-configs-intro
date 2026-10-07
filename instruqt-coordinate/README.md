# Track 3 — Coordinate (L3)

Authored 2026-10-07 (Phases 2–10 of `../PHASES-coordinate.md`); awaiting its first live Instruqt run. See `../OPERATOR-CHECKLIST-coordinate.md` for what still needs clicking through.

Otto's character survives: he becomes the brand-voice rewriter inside a team called the **Concierge**.

**Cast (see `../DECISIONS.md` and `../NARRATIVE.md`):** Toggle (triage, root), Curator (products), Tailor (sizing), Tracker (orders), Otto (rewriter). Topology `Toggle → (Curator | Tailor | Tracker) → Otto → customer`; graph key `concierge`.

| # | Challenge | Terraform / code |
|---|---|---|
| 01 | toggle — first agent-mode Config | `terraform/coordinate-01` |
| 02 | the-curator | `terraform/coordinate-02` (loads `product-catalog` snippet) |
| 03 | the-tailor | `terraform/coordinate-03` |
| 04 | the-tracker | `terraform/coordinate-04` |
| 05 | otto-returns — rewriter, loads `brand-voice` | `terraform/coordinate-05` |
| 06 | build-the-graph — UI graph, REST solve | `terraform/coordinate-06` (`graph.json`) |
| 07 | wire-the-sdk — graph dispatch in `server.py` | `terraform/coordinate-07` (`concierge-server-paste.py`, `patch-server.py`) |
| 08 | quiz | — |
| 09 | per-agent-rollout — Nova Lite on the rewriter only | `terraform/coordinate-09`, `traffic-generator/concierge_traffic.py` |
| 10 | self-healing — synchronous judge + Haiku fallback | `terraform/coordinate-10` (`selfheal-server-paste.py`, `patch-server.py`) |
| 11 | wrap-up (quiz) | — |

Track-level `setup-workstation` syncs the VM clone, bootstraps the project, and materializes the post-Build + post-Evaluate state (Build 01/02/03/05/06, Evaluate 01/02/03/04/07, plus the four server patches).
