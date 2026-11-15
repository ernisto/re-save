---
group: Reads and writes
yields: true
---
Runs `update` inside one `UpdateAsync`. [Uses the tracked session if any, so its oplog is saved in the same write.](case:pending,tracked)

## Parameters

| Name | Description |
|---|---|
| `st` | Store the key lives in. |
| `key` | DataStore key. |
| `update` | Changes data in place. Checked like queueupdate, on the data and on a pending tx's copy. |

## Returns

| Description |
|---|
| [Error message.](case:update_fails) |
