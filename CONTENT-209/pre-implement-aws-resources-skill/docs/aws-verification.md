# AWS live verification mechanics

Detail supporting the "Environment scoping" rule in `SKILL.md`. Read this only when live AWS
verification (step 1) was accepted.

## Why this matters

A report scoped to  {YOUR_CLOUD_ENV_NAME} that also lists ` {YOUR_SIBLINGS_CLOUD_ENV_NAME}-*` entries the user did not ask for is a defect, not
extra diligence — it's easy to mix environments by accident when they share one AWS account.

## Naming convention

If the AWS account is shared across environments (e.g. one account hosting both `{YOUR_CLOUD_ENV_NAME}-*` and
`{YOUR_SIBLINGS_CLOUD_ENV_NAME}-*` resources, as in this repository), every `list-*`/`describe-*`/`get-*` call and every
resource name built from a naming convention must use the selected environment's prefix (`{YOUR_CLOUD_ENV_NAME}-` by
default) — never the bare/unprefixed name and never a sibling environment's prefix.

Examples:
- `aws dynamodb list-tables` → filter results to names starting with `{YOUR_CLOUD_ENV_NAME}-`, not all tables in the
  account.
- `aws sqs list-queues --queue-name-prefix {YOUR_CLOUD_ENV_NAME}-` rather than listing every queue and filtering
  client-side.
- A suggested-but-not-yet-created resource name is still built with the selected environment's
  prefix, e.g. `{YOUR_CLOUD_ENV_NAME}-order-sync-dlq`, not `order-sync-dlq`.

## Multiple environments

If the user explicitly asks for more than one environment in a single run, repeat every discovery
call and every derived name once per requested environment, and label each resource entry with its
environment explicitly (e.g. `### SQS:  {YOUR_CLOUD_ENV_NAME}-order-sync` and `### SQS: {YOUR_SIBLINGS_CLOUD_ENV_NAME}-order-sync` as separate
entries) — never merge two environments' values into one entry.
