---
group: Reads and writes
yields: true
---
Saves updates to many keys atomically: test every update on the current data (the session cache for tracked keys), create a tx, lock every record, [commit](case:) or [abort](case:lock_fails), then adopt the result into each record.

## Parameters

| Name | Description |
|---|---|
| `builder` | Receives `update`; call `update(store, key, fn)` once per key. |

## Returns

| Description |
|---|
| First error from a failed update check (nothing is written), [lock](case:locked), [commit](case:commit_fails), [abort](case:poor) or adopt. |
