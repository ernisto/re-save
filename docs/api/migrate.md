---
group: Setup
---
Returns a new frozen schema with `migrate` appended. Every migration is test-run against the default first; [any failure throws](case:raises).

## Parameters

| Name | Description |
|---|---|
| `base` | Schema to extend. Not changed. |
| `migrate` | Turns version N data into version N+1 data. |

## Returns

| Description |
|---|
| Frozen schema, one version newer. |
