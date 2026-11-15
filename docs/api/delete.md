---
group: Reads and writes
yields: true
---
Removes the key from the DataStore. [A tracked session for the key is not touched.](case:tracked,then_free)

## Parameters

| Name | Description |
|---|---|
| `store` | Store the key lives in. |
| `key` | DataStore key. |

## Returns

| Description |
|---|
| [Error message.](case:remove_fails) |
