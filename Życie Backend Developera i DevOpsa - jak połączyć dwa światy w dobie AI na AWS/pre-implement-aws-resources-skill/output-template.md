# Output Template

For each resource, render only the `fields` its service lists in `resources.yaml`, in order
Settings, IAM, Env (`none` for an empty field). One subsection per resource, no prose, empty
sections omitted.

```markdown
# AWS Resource Readiness

**Review range:** `<base>...<head>` plus `<working-tree status>`, or `specs: <file names>`
**Terraform evidence:** `<revision/module paths>` or `UNVERIFIED: <reason>`
**AWS CLI cross-check:** `<account id/ARN>` or `not requested`
**Environment scope:** `<env>`

## Add

### `<service>`: `<resource-name>`
- Settings: `<...>` <tags>
- IAM: `<actions + scoped resource ARNs>` <tags>
- Env: `<KEY=value, one per line>` <tags>

## Diff

### `<service>`: `<resource-name>`
- Settings: `<field: old -> new>` <tags>
- IAM: `<+ added>` / `<- removed>` <tags>
- Env: `<+ KEY=value>` / `<~ KEY old -> new>` / `<- KEY>` <tags>

## Unknown Service

### `<detected-service-name>`
- Evidence: `<what implies this service>`
- Note: not in `resources.yaml`; add an entry before it can be reported normally.

## No Infrastructure Change Detected

`<only when Add and Diff are empty: evidence examined and Terraform status>`
```

## Tags

A line carries the tags that apply, in this order:

1. `(unverified)`: Terraform status `UNVERIFIED`.
2. `(suggested — not created yet)`: the concrete value a not-yet-created resource will have,
   derived from the evidenced naming convention (e.g.
   `https://sqs.<region>.amazonaws.com/<account-id>/<queue-name>`, `<table-arn>/index/<name>`).
   Use `(aws-unverified: …)` instead only when no value can be derived, and name the missing
   input.
3. `(aws-verified)` / `(aws-mismatch: <diff>)` / `(aws-unverified: <specific reason>)`: live AWS
   result. Omit when the cross-check was declined; the header says `not requested` once.
