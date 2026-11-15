---
group: Sessions
yields: true
---
[Saves the oplog if any](case:pending), then untracks and freezes the session. [On error the session stays tracked.](case:pending,update_fails)

## Parameters

| Name | Description |
|---|---|
| `s` | Session to release. |

## Returns

| Description |
|---|
| [Error message; the session stays tracked when the save failed.](case:pending,write_fails) [When saved without updates that failed on newer cloud data, the session is freed and the error lists them.](case:pending,rewritten) [Keeps failing while a newer release owns the save.](case:bumped,pending) |
