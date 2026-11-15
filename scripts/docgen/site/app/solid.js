// Solid's reactive core, pinned. Writes are batched: a signal read right after its
// setter still gives the old value until flush() (or the next microtask).
import * as solid from "https://esm.sh/@solidjs/signals@2.0.0-rc.20";

export const { createRoot, createSignal, createMemo, createRenderEffect, flush, untrack } = solid;
