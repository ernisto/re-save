---
group: Reads and writes
---
Applies `update` to `s.data` now and appends it to the oplog; [nothing is written yet](case:). Saved later by [livesync](case:livesync), [free](case:then_free), [view](case:then_view) or [a save call](case:then_saveupdate). [Throws on any invalid `update`](case:raises).

## Parameters

| Name | Description |
|---|---|
| `s` | Tracked session. |
| `update` | Changes data in place. Must not yield, must be deterministic and JSON-safe. |

