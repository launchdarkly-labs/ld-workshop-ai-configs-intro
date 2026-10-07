# End-state for Evaluate Challenge 01 — "Otto on the Bench".
#
# Datasets, playgrounds, evaluations, and evaluation runs are not exposed by
# the Terraform provider, and they live under the *internal* REST surface
# (`https://app.launchdarkly.com/internal/...`), not `/api/v2`. The internal
# endpoints are publicly reachable with a normal API token but undocumented.
# Every request/response shape below was captured from the LaunchDarkly web
# app's own network traffic on 2026-10-06 while clicking through the exact
# flow the learner performs in assignment.md. See
# `instruqt-evaluate/INTERNAL-API.md` for the captured shapes.
#
# Object model (matches the UI):
#
#   dataset      — uploaded JSONL; `{input, expected_output, metadata}` rows
#   evaluation   — ONE playground column: model + messages + snippets +
#                  acceptance criteria. "New playground" creates two of these.
#   playground   — a named wrapper over N evaluations (`variants[]`)
#   run          — one execution of one evaluation against a dataset sample
#
# Three chained REST steps via null_resource + curl:
#
#   1. create_dataset      POST /datasets  + PUT uploadUrl with the JSONL bytes
#   2. create_playground   POST /evaluations x2 (A = Otto Born, B = Otto Premium)
#                          POST /playgrounds wrapping both
#   3. run_playground      POST /evaluations/{id}/runs for each column
#
# setup-workstation applies only step 1 (`-target=null_resource.create_dataset`)
# so the learner arrives with the dataset pre-seeded; they build and run the
# playground themselves in the LD UI. solve-workstation applies all three so
# Skip lands in the same end state.
#
# Runs call Bedrock through LaunchDarkly's playground BYOK integration
# (`aiconfig-test-run`), which is ACCOUNT-level, not project-level. If the
# account has no working Bedrock role configured, runs land in state
# PERMANENT_ERROR with "Bedrock request failed: AccessDenied (HTTP 403)".
# That is an operator-side AWS IAM task — see OPERATOR-CHECKLIST-evaluate.md.

locals {
  dataset_path     = "${path.module}/datasets/customer-questions.jsonl"
  dataset_filename = "customer-questions.jsonl"
  dataset_format   = "jsonl"
  dataset_key      = "otto-born-baseline"
  dataset_name     = "Otto Born baseline"

  playground_name = "Otto Born baseline"
  config_key      = "otto-assistant"

  # Column A / column B. Load config copies each variation's Bedrock model,
  # but the workshop account's Bedrock connection for playground runs is
  # broken on LaunchDarkly's side (2026-10-07), so the assignment has the
  # learner switch each column to the same model on the Anthropic provider.
  # Mirror that here. Keys are the GLOBAL Anthropic model configs.
  # When Bedrock is fixed, switch these (and the assignment) back to
  # "Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0" / "Bedrock.anthropic.claude-sonnet-4-6".
  column_a_variation  = "otto-born"
  column_a_model      = "Anthropic.claude-haiku-4-5-20251001"
  column_b_variation  = "otto-premium"
  column_b_model      = "Anthropic.claude-sonnet-4-6"
  generation_provider = "Anthropic"

  # Playground defaults the learner does not change in ch01.
  evaluation_provider = "Anthropic"
  evaluation_model    = "Anthropic.claude-sonnet-4-5"
  criteria_json = jsonencode([{
    criterionType = "answer_relevancy"
    kind          = "deepeval"
    options       = { threshold = 0.5, passRateThreshold = 0.95 }
  }])

  # Dataset sampling the assignment asks for: Random, 15 rows.
  row_selection_mode  = "random"
  row_selection_unit  = "count"
  row_selection_value = 15

  dataset_bytes  = file(local.dataset_path)
  dataset_size   = length(local.dataset_bytes)
  dataset_sha256 = sha256(local.dataset_bytes)

  api_base = "https://app.launchdarkly.com/api/v2"
  int_base = "https://app.launchdarkly.com/internal"
}

# ---------------------------------------------------------------------------
# 1. Dataset
#
# POST /internal/projects/{key}/datasets
#   -> { datasetId, upload: { uploadUrl, uploadMethod: "PUT",
#        uploadHeaders: { "Content-Type": "application/x-ndjson" } } }
# then PUT the raw JSONL to uploadUrl. Status flips pending -> ready once
# LD has parsed the rows (a couple of seconds for 30 rows).
# ---------------------------------------------------------------------------
resource "null_resource" "create_dataset" {
  triggers = {
    sha256 = local.dataset_sha256
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      # Idempotent: skip if a ready dataset with this key already exists.
      EXISTING=$(curl -fsS -X GET \
        '${local.int_base}/projects/${var.project_key}/datasets?page=1&page_size=50' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        | jq -r '.datasets[]? | select(.key == "${local.dataset_key}") | .id' \
        | head -n 1)

      if [ -n "$EXISTING" ]; then
        echo "Dataset '${local.dataset_key}' already exists (id=$EXISTING)."
        exit 0
      fi

      CREATE_RESPONSE=$(curl -fsS -X POST \
        '${local.int_base}/projects/${var.project_key}/datasets' \
        -H 'Content-Type: application/json' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        --data-raw '{
          "name": "${local.dataset_name}",
          "key": "${local.dataset_key}",
          "filename": "${local.dataset_filename}",
          "format": "${local.dataset_format}",
          "size_bytes": ${local.dataset_size},
          "empty": false
        }')

      UPLOAD_URL=$(printf '%s' "$CREATE_RESPONSE" | jq -r '.upload.uploadUrl')

      curl -fsS -X PUT "$UPLOAD_URL" \
        -H 'Content-Type: application/x-ndjson' \
        --data-binary @${local.dataset_path}
    EOT
  }
}

# ---------------------------------------------------------------------------
# 2. Playground = two evaluations (columns) + one playground wrapper
#
# The UI builds each column's body from the loaded variation: messages come
# from the variation, `promptSnippets` is a map of snippet key -> current text
# for every `{{snippet.<key>#N}}` reference, and a `{{input}}` user message is
# appended by the learner. We read the live variation + snippet text from the
# public API so the solve state mirrors whatever Build left in the project.
# ---------------------------------------------------------------------------
resource "null_resource" "create_playground" {
  depends_on = [null_resource.create_dataset]

  triggers = {
    playground_name = local.playground_name
    column_a        = "${local.column_a_variation}@${local.column_a_model}"
    column_b        = "${local.column_b_variation}@${local.column_b_model}"
    criteria        = sha256(local.criteria_json)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      AUTH="Authorization: $LAUNCHDARKLY_ACCESS_TOKEN"
      PUB='${local.api_base}/projects/${var.project_key}'
      INT='${local.int_base}/projects/${var.project_key}'

      # If a playground with this name already exists, skip (idempotent).
      EXISTING=$(curl -fsS -X GET "$INT/playgrounds?sortBy=createdAt" \
        -H "$AUTH" -H 'LD-API-Version: beta' \
        | jq -r '.items[]? | select(.name == "${local.playground_name}") | .id' \
        | head -n 1)

      if [ -n "$EXISTING" ]; then
        echo "Playground '${local.playground_name}' already exists (id=$EXISTING)."
        exit 0
      fi

      # Snippet texts referenced by both Otto variations.
      BRAND_VOICE=$(curl -fsS "$PUB/ai-configs/prompt-snippets/brand-voice" \
        -H "$AUTH" -H 'LD-API-Version: beta' | jq -r '.text')
      SAFETY_RULES=$(curl -fsS "$PUB/ai-configs/prompt-snippets/safety-rules" \
        -H "$AUTH" -H 'LD-API-Version: beta' | jq -r '.text')

      # System prompt of each variation (first message).
      PROMPT_A=$(curl -fsS "$PUB/ai-configs/${local.config_key}/variations/${local.column_a_variation}" \
        -H "$AUTH" -H 'LD-API-Version: beta' | jq -r '.messages[0].content')
      PROMPT_B=$(curl -fsS "$PUB/ai-configs/${local.config_key}/variations/${local.column_b_variation}" \
        -H "$AUTH" -H 'LD-API-Version: beta' | jq -r '.messages[0].content')

      build_column() {
        # $1 name, $2 model config key, $3 system prompt
        jq -n \
          --arg name "$1" \
          --arg model "$2" \
          --arg prompt "$3" \
          --arg bv "$BRAND_VOICE" \
          --arg sr "$SAFETY_RULES" \
          --argjson criteria '${local.criteria_json}' \
          '{
            name: $name,
            generationProvider: "${local.generation_provider}",
            generationModel: $model,
            evaluationProvider: "${local.evaluation_provider}",
            evaluationModel: "${local.evaluation_model}",
            messages: [
              { role: "system", content: $prompt },
              { role: "user",   content: "{{input}}" }
            ],
            variables: { input: "What is the history of LaunchDarkly?" },
            promptSnippets: { "brand-voice": $bv, "safety-rules": $sr },
            parameters: {},
            criteria: $criteria
          }'
      }

      EVAL_A=$(curl -fsS -X POST "$INT/evaluations" \
        -H "$AUTH" -H 'LD-API-Version: beta' -H 'Content-Type: application/json' \
        --data-raw "$(build_column '${local.playground_name}' '${local.column_a_model}' "$PROMPT_A")" \
        | jq -r '.id')

      EVAL_B=$(curl -fsS -X POST "$INT/evaluations" \
        -H "$AUTH" -H 'LD-API-Version: beta' -H 'Content-Type: application/json' \
        --data-raw "$(build_column '${local.playground_name} (1)' '${local.column_b_model}' "$PROMPT_B")" \
        | jq -r '.id')

      curl -fsS -X POST "$INT/playgrounds" \
        -H "$AUTH" -H 'LD-API-Version: beta' -H 'Content-Type: application/json' \
        --data-raw "$(jq -n --arg a "$EVAL_A" --arg b "$EVAL_B" \
          '{ name: "${local.playground_name}",
             variants: [ { evaluationId: $a, position: 0 },
                         { evaluationId: $b, position: 1 } ] }')" \
        > /dev/null

      echo "Created playground '${local.playground_name}' (A=$EVAL_A, B=$EVAL_B)."
    EOT
  }
}

# ---------------------------------------------------------------------------
# 3. Run both columns against the dataset ("Run all" in the UI)
#
# POST /internal/projects/{key}/evaluations/{evalId}/runs
#   { datasetId, playgroundId, rowSelectionMode, rowSelectionUnit,
#     rowSelectionValue, rowSelectionSeed }
#   -> { id, state: "PENDING", ... }   state later becomes a terminal value
#      (observed: PERMANENT_ERROR; completed-state name not yet observed —
#       check scripts use the /summary endpoint's statusCounts instead).
# ---------------------------------------------------------------------------
resource "null_resource" "run_playground" {
  depends_on = [null_resource.create_playground]

  triggers = {
    playground_name = local.playground_name
    sampling        = "${local.row_selection_mode}/${local.row_selection_value}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      AUTH="Authorization: $LAUNCHDARKLY_ACCESS_TOKEN"
      INT='${local.int_base}/projects/${var.project_key}'

      DATASET_ID=$(curl -fsS -X GET "$INT/datasets?page=1&page_size=50" \
        -H "$AUTH" -H 'LD-API-Version: beta' \
        | jq -r '.datasets[]? | select(.key == "${local.dataset_key}") | .id' \
        | head -n 1)

      if [ -z "$DATASET_ID" ]; then
        echo "Could not locate the '${local.dataset_key}' dataset."
        exit 1
      fi

      PLAYGROUND=$(curl -fsS -X GET "$INT/playgrounds?sortBy=createdAt" \
        -H "$AUTH" -H 'LD-API-Version: beta' \
        | jq -c '[.items[]? | select(.name == "${local.playground_name}")][0]')

      PLAYGROUND_ID=$(printf '%s' "$PLAYGROUND" | jq -r '.id // empty')
      if [ -z "$PLAYGROUND_ID" ]; then
        echo "Could not locate the '${local.playground_name}' playground."
        exit 1
      fi

      SEED=$(( $(date +%s) % 1000 ))

      for EVAL_ID in $(printf '%s' "$PLAYGROUND" | jq -r '.variants[].evaluationId'); do
        curl -fsS -X POST "$INT/evaluations/$EVAL_ID/runs" \
          -H "$AUTH" -H 'LD-API-Version: beta' -H 'Content-Type: application/json' \
          --data-raw "$(jq -n \
            --arg d "$DATASET_ID" --arg p "$PLAYGROUND_ID" --argjson seed "$SEED" \
            '{ datasetId: $d, playgroundId: $p,
               rowSelectionMode: "${local.row_selection_mode}",
               rowSelectionUnit: "${local.row_selection_unit}",
               rowSelectionValue: ${local.row_selection_value},
               rowSelectionSeed: $seed }')" \
          | jq -r '"Started run \(.id) for evaluation \(.evaluationId) (state=\(.state))"'
      done
    EOT
  }
}
