---
group: Sessions
yields: true
---
Loads a key into a live session and writes the migrated record back. [Missing keys get the default written.](case:) [A key already tracked returns the same session without a cloud call.](case:tracked)

## Parameters

| Name | Description |
|---|---|
| `st` | Store the key lives in. |
| `key` | DataStore key. |

## Returns

| Description |
|---|
| [Error message; the key is not tracked when set.](case:update_fails) |
| [Live session; data is frozen and migrated.](case:record) |
