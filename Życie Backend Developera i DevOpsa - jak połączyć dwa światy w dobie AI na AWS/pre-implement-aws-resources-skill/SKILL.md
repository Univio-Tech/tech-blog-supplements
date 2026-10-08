---
name: pre-implement-aws-resources
description: Use this skill to review application diffs or {YOUR_SPECS_LOCATION} for required AWS infrastructure before a merge request. Identifies required AWS related resources; compares against Terraform when available; optionally performs read-only live AWS verification after explicit user approval.
---

# Pre-Implement AWS Resources

Identifies infrastructure that must exist before a change can be deployed. Run this skill before
every merge request. It reports results only in the output window; it does not edit application,
specification, or Terraform files.

## Inputs

- A target branch, commit, or merge-request base. Default: `origin/master`.
- The current worktree diff, including uncommitted changes.
- Or, when no branch/diff evidence exists: one or more named specifications in {YOUR_SPECS_LOCATION}
  (asked in step 0 below; never assumed).
- Optional Terraform repository: {YOUR_REPOSITORY_REF}.
- Whether to cross-check against the real AWS account currently logged in locally (asked in step 1
  below; never assumed).
- Which AWS region to use when cross-checking AWS (asked in step 2 below; defaults to
  {YOUR_DEFAULT_REGION}).
- Which environment(s) to scope the report to when cross-checking AWS (asked in step 3 below;
  defaults to  {YOUR_CLOUD_ENV_NAME} only).

## Interaction mode

Before the final report, the assistant may ask only the required gating questions, in this order:
1. Review source (branch diff vs. named specifications).
2. AWS live cross-check approval.
3. If approved: AWS profile, if ambiguous.
4. If approved: AWS account confirmation after `sts get-caller-identity`.
5. If approved: AWS region, if ambiguous.
6. If approved: environment scope.

The "Output" section's "return only this report" rule applies only to the final report, not to
these gating questions.

## Workflow

0. Ask the user which source to review:
   - **Branch diff** (default) — the usual pre-merge-request case: compare the current branch
     against `origin/master` as in step 4.
   - **Named specifications** — use this when no branch has pending changes yet and the change
     was never run through this skill before implementation. The user names one or more spec
     files in {YOUR_SPECS_LOCATION}. Skip step 4 entirely; go straight to step 5 and treat every named
     spec as the full review scope (not just specs touched by a diff). Steps 6–10 proceed
     unchanged, except step 6 has no diff to inspect — corroborate against the current state of
     the code the spec describes instead.

1. Before touching AWS: ask the user whether to cross-check this report against the real AWS
   account they are currently logged into locally. Do not run any `aws` command before this
   answer, including `sts get-caller-identity`. If they decline, skip AWS CLI verification
   entirely for the rest of this run and rely on Terraform/diff evidence only. If they accept:
   - Run `scripts/resolve_aws_profile.sh` to resolve the AWS profile. Only treat AWS CLI as
     unconfigured when it returns `status: none`. If it returns `status: ambiguous`, ask the user
     which of the listed `profiles` to use. Otherwise use its `profile_arg`/`profile_name` as-is —
     do not re-derive this logic inline.
   - Run `aws sts get-caller-identity` once (with the resolved `profile_arg` when non-empty), state
     the resulting account id/ARN and the profile name used in the output header, and confirm with
     the user that this is the intended account before using it — this account may be a real, live
     environment, not a sandbox.

2. Resolve the AWS region (only when the AWS CLI cross-check in step 1 was accepted). See Region
   scoping below.

3. Ask the user which environment(s) to scope this report to (only when the AWS CLI cross-check
   in step 1 was accepted — this question has no purpose otherwise). Default to {YOUR_ENV_NAME}.
   See Environment scoping below for what this constrains for the rest of the run.

4. Establish the review range without guessing (branch-diff source only; skip if the user chose
   named specifications in step 0):

   ```bash
   git fetch origin master
   BASE="$(git merge-base HEAD origin/master)"
   git diff --name-status "$BASE"...HEAD
   git diff --name-status
   ```

   Include committed branch changes and uncommitted staged/unstaged changes. If the user provides
   a base, use it instead of `origin/master` and state it in the output.

5. Inspect the relevant {YOUR_SPECS_LOCATION} files first: changed/added files in the diff (branch-diff
   source), or the exact files the user named (named-specifications source). Read each complete
   specification and extract explicit provisioning, deployment, security, trigger, networking,
   observability, and rollback requirements. Treat a specification as a requirement even when
   application code is not yet present.

6. Inspect the remaining diff and its immediate context (branch-diff source), or the current code
   the named specs describe (named-specifications source). Look for runtime configuration, AWS SDK
   clients, Lambda handlers, event contracts, LocalStack topology, Docker/deployment files, and
   README requirements. Every resource must satisfy the Evidence rules below before it enters the
   inventory.

7. Build a resource inventory. Use `resources.yaml` as the supported service catalog and field
   schema (Settings/IAM/Env), not as a checklist to walk in full — evaluate only the services for
   which step 5/6 turned up evidence in specs, diff, local topology, Terraform, or code context. If
   that evidence points to a service not listed in `resources.yaml`, report it as `Unknown Service`
   (see Rules) instead of skipping it or forcing it into an existing entry. Required analysis for
   the most common services:

   | Area | Required analysis |
   | --- | --- |
   | Lambda | Function, runtime/image, timeout, memory, reserved concurrency, environment, VPC, Function URL, aliases/permissions |
   | IAM | Execution role, least-privilege actions, resource ARNs, trust policy, KMS, Secrets Manager/SSM, logs, X-Ray, DLQ permissions |
   | SQS | Main queue, FIFO mode, DLQ, redrive policy, visibility timeout, retention, encryption, queue policy, Lambda event-source mapping, partial batch failure |
   | DynamoDB | Table, PK/SK, GSIs, TTL, PITR, encryption, capacity mode, stream, table and index IAM permissions |
   | EventBridge | Bus, rule or schedule, event pattern, target, retry/DLQ, target invocation permission, scheduler role when applicable |
   | Other AWS | Any other service in `resources.yaml` (Step Functions, S3, ECR, API Gateway/Function URL, CloudWatch alarms/dashboards/log retention, KMS, VPC endpoints, Route 53) as indicated by the diff |

   For every new environment variable a Lambda's code reads, check its own env-parsing schema
   (e.g. the Zod/config schema, not just where the value is consumed) for a default. If the code
   already defaults to the exact value you were about to list, that variable is not a requirement —
   do not add it to **Add**/**Diff**. Only list an env var when it has no default, or when the
   desired value differs from the code's default.

8. When access is available, compare the inventory with the Terraform repository. Clone it outside
   this repository if it is not already available, never into the application worktree:

   ```bash
   glab repo clone {REPOSITORY_NAME} {YOUR_TEMP_LOCATION}
   ```

   Search Terraform modules, environment variables, IAM policies, resource names, tags, and
   outputs. Identify the owning module and environment. Do not modify or apply Terraform. If
   GIT provider access, the repository, or a target environment is unavailable, mark each matching
   status as `UNVERIFIED`; do not claim the resource is absent.

9. When the user accepted the AWS CLI cross-check in step 1, resolve every resource reference to
   its real identifier before writing the report. Use a
   discovery call to find the actual name/ARN/URL, matching by the naming convention, tag, or
   pattern the code/spec/Terraform already implies. Only once the real identifier is found, verify its live configuration
   with the call matching that resource type, e.g. `aws lambda get-function-configuration`, `aws
   sqs get-queue-attributes`, `aws dynamodb describe-table`, `aws iam get-role` /
   `list-attached-role-policies` / `get-role-policy`, `aws events describe-rule`, `aws scheduler
   get-schedule`. Every call is read-only — never create, update, or delete a resource.

   Mark each entry `(aws-verified)` when live state matches the claim, `(aws-mismatch: <what
   differs>)` when it does not, or `(aws-unverified: <reason>)` only when the resource genuinely
   cannot be resolved or checked this way — state the real reason. `(aws-unverified:
   credentials unavailable)` is only valid when `aws sts get-caller-identity` in step 1 itself
   failed; once credentials work, every subsequent placeholder must be resolved or given its own
   specific reason, never that generic one. Do this in addition to, not instead of, the Terraform
   comparison in step 8.

   A resource that does not exist yet is never left as a bare `<placeholder>` or a "does not exist"
   note with nothing else — always compute and print the concrete value it will have once created,
   derived from the naming convention already evidenced by the code, Terraform, or a deployed
   sibling resource (e.g. an ARN built from the confirmed account id + region + the exact resource
   name the code/{YOUR_LOCALSTACK_PATH}/a sibling's live config already uses; a deterministic SQS
   URL of the form `https://sqs.<region>.amazonaws.com/<account-id>/<queue-name>`; an index ARN of
   the form `<table-arn>/index/<index-name>`). Tag that value `(suggested — not created yet)`, not
   `(aws-unverified)`; `aws-unverified` is reserved for a value that could not even be derived, not
   for one that was derived but not yet confirmed live. When a value cannot be derived at all
   (e.g. a secret with no equivalent on any deployed sibling), say so by name and state exactly
   what input is missing rather than leaving the field blank.

10. Sort every requirement into exactly one bucket: **Add** (the resource does not exist yet —
   Terraform status `CREATE REQUIRED`) or **Diff** (the resource exists and needs a change —
   `CHANGE REQUIRED` or `REMOVE REQUIRED`). A resource that already matches (`EXISTS`) is omitted
   from the report entirely. If Terraform access was unavailable, keep the requirement in whichever
   bucket the diff implies and mark it `(unverified)` inline instead of adding a status column.
   Flag conflicts such as Lambda code with no event-source mapping, a schedule with no invoke
   permission, a queue without appropriate redrive, or IAM permissions broader than the used AWS
   calls inline under the affected resource's own entry, never as a separate section.

## Evidence rules

A resource requirement requires at least one of:
- explicit {YOUR_SPECS_LOCATION} requirement,
- AWS SDK/client usage plus operation semantics,
- Lambda handler trigger contract,
- LocalStack/deployment topology declaration,
- Terraform reference,
- README/deployment instruction.

A variable name alone is insufficient evidence.
When evidence conflicts, prefer {YOUR_SPECS_LOCATION}, then code, then Terraform, then README.

## Region scoping

When live AWS verification is enabled, resolve the AWS region before resource discovery. Use
`$AWS_REGION`/`$AWS_DEFAULT_REGION`, then the selected profile's configured region. Default:
 {YOUR_DEFAULT_REGION}. If no region can be resolved or multiple regions are plausible, ask the user. Do
not mix regions in one report unless explicitly requested.

## Environment scoping

When live AWS verification is enabled, all resource names, ARNs, URLs, env values, and discovery
filters must be scoped to exactly the selected environment. Default:  {YOUR_CLOUD_ENV_NAME}. Never include sibling
environments unless the user explicitly selected them for this run. See
`docs/aws-verification.md` for the naming-convention mechanics (prefixes, shared-account
discovery filtering).

## Output

Return only this report in the output window. Keep it short: one subsection per resource, no
prose paragraphs, no restating the workflow. Omit a resource-type heading entirely when nothing in
that category changed. Do not save a report file.

Use the skeleton in `output-template.md`, which selects each resource's fields (Settings/IAM/Env)
from `resources.yaml` rather than hardcoding them per service.

## Rules

- The supported service catalog and per-service field schema (Settings/IAM/Env) live in
  `resources.yaml`. Add a new service there, not as a hardcoded name in this file or in
  `output-template.md`. Only render a field for a service when `resources.yaml` lists it — e.g.
  never add an Env bullet under a service that doesn't have `env` in its field list.
- If the diff/spec implies an AWS service that is not listed in `resources.yaml`, do not silently
  guess its fields or skip it. Report it under its own `## Unknown Service` section (name, why it
  was detected, and the evidence), and note that `resources.yaml` needs a new entry for it.
- Specs in {YOUR_SPECS_LOCATION} always take precedence in review order, then the rest of the diff (when a
  diff exists).
- Every resource lives under exactly one of **Add** or **Diff**, grouped by resource type (Lambda,
  SQS, DynamoDB, other). Never mix resource types under one heading and never re-list a resource in
  both sections.
- Lambda entries always order as: function name, then Settings, then IAM, then Env — in that order,
  even when one of them is empty (write `none`).
- List only fields that need to exist or change. Do not restate unrelated existing configuration.
- IAM recommendations must use least privilege and scoped resource ARNs. Never emit credentials,
  secret values, or private endpoints. The one exception is the account id/ARN in the **AWS CLI
  cross-check** header line when the user explicitly opted into step 1 — that is the point of
  stating which account was checked; still never print it anywhere else in the report.
- Never run a mutating `aws` command (anything other than `get-*`/`describe-*`/`list-*`) during
  this skill, even when the user opted into the AWS CLI cross-check. This skill only reads.
- Include dependent operational resources such as DLQs, retry policies, and invoke permissions as
  their own resource entry when the evidence requires them; do not fold them into prose.
- This is an analysis skill. Never create AWS resources, run `terraform apply`, or change the
  Terraform repository unless explicitly requested in a separate task.
- See Environment scoping above; it applies to every line of the report, not just the ones marked
  `(aws-verified)`.
- Never report a not-yet-created resource as an unresolved placeholder. Always give its concrete
  suggested value, derived from the established naming convention, tagged `(suggested — not
  created yet)`. Reserve `(aws-unverified: ...)` for a value that genuinely cannot be derived from
  any evidence, and name the specific missing input when that happens.
