# Internal REST surface used by Evaluate

Datasets, playgrounds, evaluations, and evaluation runs are **not** on
`/api/v2` and are not in the public API docs. The LaunchDarkly web app calls
them under `https://app.launchdarkly.com/internal/...`. They accept a normal
API token in the `Authorization` header and the `LD-API-Version: beta` header,
exactly like `/api/v2`.

Everything below was captured from the web app's own network traffic on
2026-10-06 while performing the ch01 flow (`01-otto-on-the-bench`) in the
`kevinc-instruqt` sandbox project. Treat it as a snapshot: these shapes can
change without notice. Re-capture if a check or solve script starts failing.

## Object model

| Object | What it is in the UI |
|---|---|
| **dataset** | An uploaded JSONL/CSV file under Library → Datasets. Rows are `{input, expected_output, metadata}`. |
| **evaluation** | One playground **column** (A, B, …): model, messages, snippet texts, acceptance criteria. Named after the playground, suffixed ` (1)`, ` (2)` for extra columns. |
| **playground** | A named wrapper that lists its evaluations as `variants[]`. "New playground" creates two evaluations and then one playground. |
| **run** | One execution of one evaluation against a dataset sample. "Run all" posts one run per column. |

Base: `INT=https://app.launchdarkly.com/internal/projects/{projectKey}`

## Datasets

```
GET  $INT/datasets?page=1&page_size=50
GET  $INT/datasets?page=1&page_size=100&status=ready        # playground picker
GET  $INT/datasets/{datasetId}
GET  $INT/datasets/{datasetId}/preview?mode=random&value=15&unit=count&limit=25&offset=0
POST $INT/datasets
```

List response (note the top-level key is `datasets`, not `items`):

```json
{"datasets":[{"id":"6abf…","name":"Otto Born baseline","key":"otto-born-baseline",
  "filename":"customer-questions.jsonl","contentType":"jsonl","rowCount":30,
  "status":"ready","sizeBytes":7724,"createdAt":"…","updatedAt":"…"}],
 "totalCount":1,"page":1,"pageSize":50}
```

Create request / response:

```json
{"name":"Otto Born baseline","key":"otto-born-baseline",
 "filename":"customer-questions.jsonl","format":"jsonl","size_bytes":7724,"empty":false}
```
```json
{"datasetId":"6abf…","status":"pending",
 "upload":{"uploadUrl":"https://s3.amazonaws.com/…","uploadMethod":"PUT",
           "uploadHeaders":{"Content-Type":"application/x-ndjson"},"expiresAt":"…"}}
```

Then `PUT` the raw file bytes to `uploadUrl` with that Content-Type. Status
flips to `ready` a few seconds later.

## Evaluations (playground columns)

```
GET   $INT/evaluations?limit=1&offset=0          # {items:[], totalCount}
GET   $INT/evaluations/{evaluationId}
POST  $INT/evaluations
PATCH $INT/evaluations/{evaluationId}            # partial update, e.g. {"name": "…"}
```

Create body as sent by "New playground" (defaults, before Load config):

```json
{"name":"Untitled playground","generationModel":"Anthropic.claude-sonnet-4-5",
 "generationProvider":"Anthropic",
 "messages":[{"content":"You are a helpful assistant.","role":"system"},
             {"content":"{{input}}","role":"user"}],
 "variables":{"input":"What is the history of LaunchDarkly?"}}
```

Save body after Load config (Otto Born) + Answer Relevancy, as sent by
"Run all" (PATCH). This is the shape `terraform/evaluate-01` reproduces:

```json
{"evaluationModel":"Anthropic.claude-sonnet-4-5","evaluationProvider":"Anthropic",
 "generationModel":"Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0","generationProvider":"Bedrock",
 "variables":{"input":"What is the history of LaunchDarkly?"},
 "criteria":[{"criterionType":"answer_relevancy","kind":"deepeval",
              "options":{"threshold":0.5,"passRateThreshold":0.95}}],
 "messages":[{"role":"system","content":"{{snippet.brand-voice#1}}\n\nYou work at ToggleWear…\n\n{{snippet.safety-rules#1}}"},
             {"role":"user","content":"{{input}}"}],
 "parameters":{},
 "promptSnippets":{"brand-voice":"You are Otto. …","safety-rules":"Don't make up prices…"}}
```

Notes:

- `generationModel` is a **model config key** (`Bedrock.anthropic.claude-sonnet-4-6`,
  not the bare Bedrock model id). Both Otto models exist as global model configs.
- `promptSnippets` is a map of snippet key → the snippet's current text, for every
  `{{snippet.<key>#N}}` in `messages`. Load config fills it from the public
  prompt-snippets API.
- Criteria menu → `criterionType`: Likeness, Accuracy, Answer Relevancy
  (`answer_relevancy`), Toxicity, Bias, Misinformation. All `kind: "deepeval"`.
  Response echoes each criterion with `judgeKey: null, successDirection: null`
  (custom-judge criteria presumably fill those).
- Response adds `id`, `version` (increments per PATCH), `createdAt`, `updatedAt`,
  `archivedAt`, `generationContext`, `tools`.

## Playgrounds

```
GET   $INT/playgrounds?sortBy=createdAt           # {items:[…], totalCount}
GET   $INT/playgrounds?limit=1&status=archived
GET   $INT/playgrounds/{playgroundId}
POST  $INT/playgrounds
PATCH $INT/playgrounds/{playgroundId}             # e.g. {"name": "…"}
```

```json
{"name":"Otto Born baseline",
 "variants":[{"evaluationId":"ce09…","position":0},{"evaluationId":"6c63…","position":1}]}
```

Response adds `id`, `createdBy`, `createdAt`, `updatedAt`, `archivedAt`.
Renaming the playground in the UI also PATCHes each evaluation's `name`.

## Runs

```
POST $INT/evaluations/{evaluationId}/runs
GET  $INT/evaluations/{evaluationId}/runs?limit=1
GET  $INT/evaluations/{evaluationId}/runs/{runId}
GET  $INT/evaluations/{evaluationId}/runs/{runId}/summary
GET  $INT/evaluations/{evaluationId}/runs/{runId}/rows?limit=25&offset=0
GET  $INT/evaluations/runs?expand=playground&source=playground%2Capi&limit=10   # project-wide, Evaluations page
GET  $INT/evaluations/runs?datasetId={datasetId}&source=playground%2Capi&limit=1
```

Create body ("Run all", Random / 15 rows):

```json
{"datasetId":"6abf…","playgroundId":"bfd6…",
 "rowSelectionMode":"random","rowSelectionUnit":"count","rowSelectionValue":15,"rowSelectionSeed":347}
```

`rowSelectionMode` ∈ `top | random | all` (UI radio); `rowSelectionUnit` ∈ `count | percent`.

Run object:

```json
{"id":"7f21…","datasetId":"…","playgroundId":"…","evaluationId":"…","evaluationVersion":4,
 "state":"PENDING","rowCount":30,"selectedRowCount":15,
 "rowSelectionMode":"random","rowSelectionValue":15,"rowSelectionUnit":"count","rowSelectionSeed":347,
 "source":"playground","createdBy":"…","createdAt":1791313703450}
```

`state` values observed: `PENDING`, `PERMANENT_ERROR` (with `statusReason`,
e.g. `Bedrock request failed: AccessDenied (HTTP 403)…`). The completed-state
name has **not** been observed yet (runs could not complete in the sandbox,
see below). Check scripts therefore test for graded rows via `/summary`:

```json
{"statusCounts":{"total":15,"passed":0,"failed":0,"error":0,"pending":15},
 "generationLatencyMs":{…},"generationTokens":{…},"criterionSummaries":[],…}
```

## Provider credentials (BYOK)

Playground runs use the account-level **Manage API keys** integration
(`integrationKey: aiconfig-test-run`), exposed on the *public* API:

```
GET  /api/v2/integration-manifests/aiconfig-test-run
GET  /api/v2/integration-configurations/keys/aiconfig-test-run
```

Each configuration has `configValues: {provider, apiKey, region, roleArn, externalId}`.
Bedrock uses role assumption, not static keys: LD assumes `roleArn` using
`externalId`, in `region`. A misconfigured trust policy yields the
`PERMANENT_ERROR` above on every run. This is per **account**, so the
operator must set it up once for the account the Instruqt IdP simulator
logs learners into — it is not something a per-project solve script can fix.

`GET /internal/ai/evaluations/providers` → `{"experience":"byok","providers":["anthropic","bedrock","openai"]}`.

## Public endpoints the playground also uses

```
GET /api/v2/projects/{key}/ai-configs?sort=-lastModified&limit=20          # Load config picker
GET /api/v2/projects/{key}/ai-configs/{configKey}/variations/{variationKey}
GET /api/v2/projects/{key}/ai-configs/model-configs?restricted=false        # Select model
GET /api/v2/projects/{key}/ai-configs/prompt-snippets?limit=100&offset=0
GET /api/v2/projects/{key}/ai-configs/prompt-snippets/{key}/versions?limit=100&offset=0
```

---

# Public-API shapes verified for Evaluate ch02–ch08 (2026-10-06)

Everything in this section is on `/api/v2` and documented, but several
response shapes differ from what the scripts originally assumed. Verified by
capturing the web app's traffic and replaying with an API token.

## Variations and judges (ch02, ch03, ch04)

```
GET   /api/v2/projects/{key}/ai-configs/{configKey}/variations/{variationKey}
      -> {"items":[<version 1>, <version 2>, ...], "totalCount": N}   # NOT a single object
PATCH /api/v2/projects/{key}/ai-configs/{configKey}/variations/{variationKey}
      {"judgeConfiguration":{"judges":[{"judgeConfigKey":"accuracy","samplingRate":0.25}, ...]}}
      # replaces the whole list — merge with the existing judges first
```

- Attached judges use the judge config's **short key** (`accuracy`,
  `otto-brand-voice-judge`). The `$ld:ai:judge:<key>` string the UI shows is
  the judge's `evaluationMetricKey` (its event key).
- Built-in judges are **not** pre-provisioned. "+ Add judges → Add N judges"
  POSTs each one to `/api/v2/projects/{key}/ai-configs` as a judge-mode
  config with a `defaultVariation` (captured bodies:
  `terraform/evaluate-02/builtin-judges/*.json`). They come up enabled in all
  environments. A duplicate POST returns **400** `invalid variation "default"`,
  not 409 — probe with GET first.
- "Create config → Judge → Generate judge" calls
  `POST /internal/ai-configs/judge-copilot-generate/completion` and then the
  public POST above. The dialog has **Edit config key**, so the key is
  deterministic if the learner sets it. The generated config carries
  `isInverted` (UI: *Desired direction*, "Lower is better" = `true`) and a
  Default variation with three messages using `{{message_history}}` and
  `{{response_to_evaluate}}`.
- `GET .../ai-configs?filter=mode+anyOf+["judge"]&limit=100` lists judge configs.
- Snippet keys are derived from the name (`Product catalog` → `product-catalog`);
  the Create snippet dialog has no key field.

## Targeting (ch06, ch07, ch08)

```
GET /api/v2/projects/{key}/ai-configs/{configKey}/targeting
```

```json
{"variations":[{"_id":"…","name":"Otto (Born)","description":"",
                "value":{"_ldMeta":{"variationKey":"otto-born","enabled":true,"modelKey":"…"},"messages":[…]}}],
 "environments":{"test":{"_version":4,"enabled":true,"offVariation":0,
                         "fallthrough":{"variation":1},"rules":[]}}}
```

- Variations have **no top-level `key`**; use `.value._ldMeta.variationKey` or `.name`.
- `fallthrough.variation` is an **index** into `variations`, not an id.
- `environments.<env>._version` is the version experiments want as
  `flagConfigVersion` (not the config's own `version`).
- Rollout kinds are distinguishable on `fallthrough.rollout.experimentAllocation.type`:
  `"experiment"` (running experiment), `"measuredRollout"` (guarded rollout),
  absent (manual percentage rollout).

### Start a guarded rollout (what the UI sends)

```
PATCH /api/v2/projects/{key}/ai-configs/{configKey}/targeting
{"environmentKey":"test","comment":"","instructions":[{
  "kind":"startAutomatedRelease","releaseKind":"guarded",
  "originalVariationId":"<born _id>","targetVariationId":"<formal _id>",
  "randomizationUnit":"user",
  "stages":[{"allocation":5000,"durationMillis":60000}, …],        # allocation per 100000
  "metrics":[{"key":"otto-brand-voice-score","isGroup":false}],
  "metricMonitoringPreferences":{"otto-brand-voice-score":{"autoRollback":true}}}]}
```

Release history (status values observed: `manually_reverted`):
`GET /internal/projects/{key}/flags/{configKey}/automated-releases?filter=kind:guarded,environmentKey:test`
→ `{"items":[{"id","kind":"guarded","status","stages":[…]}]}`. Stopping a
release is UI-only so far (**Stop release** → Roll forward / Roll back).

## Experiments (ch06)

```
POST  /api/v2/projects/{key}/environments/test/experiments
PATCH /api/v2/projects/{key}/environments/test/experiments/{expKey}
      {"instructions":[{"kind":"startIteration","changeJustification":"…"}]}
GET   /api/v2/projects/{key}/environments/test/experiments/{expKey}?expand=metrics,treatments
```

- Create body requires `maintainerId` (a real member id; the operator token is
  a service token so `/members/me` 404s — look up the bootstrap member or
  fall back to an owner/admin).
- `iteration.flags.<configKey>.ruleId` for the default rule is the literal
  `"fallthrough"`; GET echoes it as `targetingRule`.
- `currentIteration.status` ∈ `not_started | running | stopped`. The
  experiment key is derived from the name (`Otto Prompt Experiment` →
  `otto-prompt-experiment`). Starting fails with `optimistic_locking_error`
  if the config's fallthrough is already in another running experiment.
- Stopping = **Stop** menu → pick the variation to ship → *Stop experiment*
  dialog (reason + type the environment key). `DELETE` on an experiment is
  405; archive with `{"instructions":[{"kind":"archiveExperiment"}]}`.

## Shell gotcha that bit every check script

`echo "$JSON" | jq` corrupts any payload containing `\n` escapes (prompt text
does) under **dash** (`/bin/sh` on Ubuntu) and zsh, because their `echo`
expands backslash escapes. Use `printf '%s' "$JSON" | jq`. All Evaluate
check/solve scripts and `terraform/evaluate-*/main.tf` were converted on
2026-10-06; the Build track still uses `echo` in three check scripts.


## Verified live on 2026-10-06 (Instruqt lab, Hands-on Workshops account)

### Stop an experiment iteration and ship a treatment (`/api/v2`)

```
PATCH /api/v2/projects/{proj}/environments/test/experiments/otto-prompt-experiment
{"comment": "...", "instructions": [{"kind": "stopIteration",
  "winningTreatmentId": "<currentIteration.treatments[].\_id>",   # GET ...?expand=treatments
  "winningReason": "Recommender wins on brand-voice score"}]}
```
→ 200, `currentIteration.status == "stopped"`, and the config's `fallthrough.variation` is set to the
winning treatment's variation (same as the UI's Stop → ship flow). Used by `terraform/evaluate-06/setup-experiment.py --stop-if-running`.

### Stop an in-progress guarded rollout (what the UI's **Stop release → Roll back** sends)

```
PATCH /api/v2/projects/{proj}/ai-configs/otto-assistant/targeting
{"comment": "", "environmentKey": "test", "instructions": [{"kind": "stopAutomatedRelease",
  "releaseId": "<automated-releases items[].id>",
  "finalizationBehavior": "rollBackCurrentPhase",      # the Roll forward radio presumably sends a different value (not captured)
  "fallthrough": true}]}
```
→ 200 with the full targeting document; `fallthrough` becomes the original variation. The release
list is `GET /internal/projects/{proj}/flags/otto-assistant/automated-releases?filter=kind:guarded,environmentKey:test`;
an in-progress release has `endedAtMillis == null`, finished ones carry `status` `reverted` / `completed`.
Release items also expose `events[]` (`stage_started`, `monitoring_window_expired`, `completed`,
`safe_roll_forward`, `regression_detected`, `reverted`) and `metricConfigurations[]`
(`minSampleSize`, `regressionThreshold`, `statisticalConfidenceThreshold`, `statsModel`, `status`).

### 409s to expect
- `startAutomatedRelease` and `updateFallthroughVariationOrRollout` return **409** while an experiment
  iteration is running on the fallthrough, and (for the latter) while a guarded rollout is in progress.

### Token caveats (2026-10-06)
- The per-lab scoped `LD_API_TOKEN` (project-scoped inline role) can read/patch `/api/v2/.../ai-configs/.../targeting`,
  create AI configs, snippets and metrics, and run the ch04/ch07 solves end to end. But
  `GET /internal/.../automated-releases` returns 200 with no `items` for it — only the operator token sees releases.
  Anything that needs the release list (ch07 check, ch08 setup guard) must run with `LAUNCHDARKLY_ACCESS_TOKEN`.
- Guarded rollouts in the lab auto-revert fast once Formal gets traffic (observed +106s, +167s, +171s), so an
  in-progress release is a narrow window to test against.

### Completed playground runs (verified live 2026-10-07, Anthropic provider)
`GET /internal/projects/{proj}/evaluations/runs?source=playground,api&limit=50` → `items[]`:
```
{"id": "<uuid>", "evaluation": {"id": "<uuid>", "version": 3, "name": "Otto Born baseline", "messages": [...],
  "generationProvider": "Anthropic", "generationModel": "Anthropic.claude-sonnet-4-6", ...},
 "dataset": {...}, "createdAt": ..., "completedAt": ..., "state": "COMPLETE",
 "rowCount": 30, "selectedRowCount": 15, "completedCount": 15, "failedCount": 1, "createdBy": {...}}
```
`state` is `PENDING` → `COMPLETE` (or `PERMANENT_ERROR` with `statusReason`). There is **no** top-level `evaluationId`;
use `.evaluation.id`. Summary: `GET .../evaluations/{evaluation.id}/runs/{id}/summary` →
`statusCounts: {total, passed, failed, error, pending}`, `generationLatencyMs`, `generationTokens`, `criterionSummaries[]`.
The UI shows "Failed" on a column when the pass rate is under the 95% threshold (14/15 = 93%); that is a grading
verdict, not an execution error.
