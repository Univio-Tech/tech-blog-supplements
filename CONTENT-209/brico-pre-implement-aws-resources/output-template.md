# Output Template

No literal service names here — every resource's fields come from `resources.yaml`. For each
resource entry, look up its service in `resources.yaml` and render only the fields listed there
(always in order: Settings, IAM, Env), skipping any field not in that service's list — e.g. a
service without `env` never gets an Env bullet.

```markdown
# AWS Resource Readiness

**Review range:** `<base>...<head>` plus `<working-tree status>`, or `specs: <spec file names>` when reviewing named specifications
**Terraform evidence:** `<repository revision/module paths>` or `UNVERIFIED: <reason>`
**AWS CLI cross-check:** `<account id/ARN from sts get-caller-identity>` or `not requested`
**Environment scope:**  {YOUR_CLOUD_ENV_NAME} (or whatever the user chose in step 0c) — omit this line entirely when the AWS CLI cross-check was declined

## Add

### `<service>`: `<resource-name>`
- Settings: `<...>` `<aws-verified|aws-mismatch: ...|aws-unverified: ...>`
- IAM: `<actions + scoped resource ARNs>` `<aws-verified|aws-mismatch: ...|aws-unverified: ...>`
- Env: `<KEY=value, one per line, only the vars this change needs>` `<aws-verified|aws-mismatch: ...|aws-unverified: ...>`

## Diff

### `<service>`: `<resource-name>`
- Settings: `<field: old -> new, one per line, only what changes>` `<aws-verified|aws-mismatch: ...|aws-unverified: ...>`
- IAM: `<+ added action/ARN>` / `<- removed action/ARN>` `<aws-verified|aws-mismatch: ...|aws-unverified: ...>`
- Env: `<+ KEY=value added>` / `<~ KEY changed old -> new>` / `<- KEY removed>` `<aws-verified|aws-mismatch: ...|aws-unverified: ...>`

## Unknown Service

`<only when the diff/spec implies a service not listed in resources.yaml>`
### `<detected-service-name>`
- Evidence: `<what in the diff/spec/code implies this service>`
- Note: not in `resources.yaml` — add an entry there before this service can be scored normally.

## No Infrastructure Change Detected

`<only when Add and Diff are both empty; state examined evidence and Terraform verification status>`
```

Omit the `<aws-verified|...>` suffix entirely on every line when the user declined the AWS CLI
cross-check in step 0 — do not print `not requested` on every bullet, only once in the header.
