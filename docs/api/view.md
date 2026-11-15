---
group: Reads and writes
yields: true
---
Reads a key. [Untracked keys are read without writing.](case:record) [Tracked keys are synced, which saves their oplog.](case:pending,tracked)

## Parameters

| Name | Description |
|---|---|
| `st` | Store the key lives in. |
| `key` | DataStore key. |

## Returns

| Description |
|---|
| [Error message.](case:get_fails) |
| Migrated data; [nil for a missing untracked key](case:). |
