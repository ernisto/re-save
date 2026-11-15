// A function's Try it: pick a case (tick conditions or step with Next), see its code,
// the DataStore before and after, and what it returned.
import { CopyButton, renderCodeChange } from "../codechange.js";
import { LIMIT_KINDS, OUTCOMES } from "../data.js";
import { el } from "../dom.js";
import { inline } from "../markdown.js";
import { Result, StorePanel } from "../result.js";
import { createMemo, createRenderEffect, createSignal, flush } from "../solid.js";
import { caseOrder, idsOf, indexTree, isClose, keyOf } from "./order.js";
import { Tree } from "./tree.js";

// [function name] = { show(ids) }, for [text](case:ids) links in descriptions
export const CASE_VIEWS = new Map();

// hand-written description from tests/lute/{intro,limitations}/<function>.luau; a more case where a
// condition makes no difference borrows the description of the case it equals
const describe = (run, part) => (run && run.description ? el("p", {}, inline(run.description[part])) : null);

// why a case is where it is: its limitation note, or what makes it a more case
function EdgeNote(run, index, showCase) {
	if (!run) return null;
	if (run.limit) {
		// hand-written per case in tests/lute/limitations: kind, why it happens, what to do about it
		const kind = LIMIT_KINDS[run.limit.kind];
		// a misuse links to its suggested fix, which is also the next case in the queue
		const fix = run.limit.fix === undefined ? null
			: [" ", el("button", { class: "linkish", type: "button", onclick: () => showCase(run.limit.fix) }, "See the suggested fix ›")];
		return [
			el("span", { class: `edge-chip ${kind.cls}` }, kind.label),
			el("p", { class: "limit-note" }, inline(run.limit.todo ? `${run.limit.why} ${run.limit.todo}` : run.limit.why), fix),
		];
	}
	const labels = ids => ids.map(id => `"${index.get(id).node.label}"`).join(", ");
	const reasons = [];
	if (run.bugvariant) reasons.push(`A variant of the known issue under ${labels(run.bugvariant)}, which has its own case.`);
	if (run.irrelevant) reasons.push(`Makes no difference here: ${labels(run.irrelevant)}. The result matches the case without it.`);
	return reasons.length > 0 ? reasons.join(" ") : null;
}

export function TryIt(fn) {
	const index = indexTree(fn.tree);
	const { order, counterText } = caseOrder(fn, index);
	const [key, setKey] = createSignal("");
	const run = createMemo(() => fn.runs[key()]);
	const [treeOpen, setTreeOpen] = createSignal(false);

	let left, resultCard;
	let animate = true; // the next code change slides; a jump to a far case just appears

	// a new case starts at the top of the left column (ticking a box doesn't, so the tree
	// being clicked stays put)
	const showCase = (next, { animate: slide = true } = {}) => {
		animate = slide;
		setKey(keyOf(idsOf(next)));
		flush();
		left.scrollTop = 0;
	};
	const step = by => showCase(order[(order.indexOf(key()) + by + order.length) % order.length]);
	CASE_VIEWS.set(fn.name, {
		show(ids) {
			const next = keyOf(idsOf(ids));
			if (!(next in fn.runs)) return false;
			showCase(next, { animate: isClose(key(), next) });
			return true;
		},
	});

	// the code panel keeps what it shows, so the next case can animate from it
	const codeHost = el("div");
	let shownCode = null;
	createRenderEffect(run, r => {
		if (!r) {
			codeHost.replaceChildren(el("div", { class: "empty" }, "No recorded snippet for this combination."));
			return;
		}
		renderCodeChange(codeHost, animate ? shownCode : null, r.code, r.vars);
		shownCode = r.code;
		animate = true;
	});

	const single = order.length < 2;
	const outcome = () => (run() ? OUTCOMES[run().outcome] || run().outcome : "not recorded");
	const treeId = `tree-${fn.name}`;

	const lab = el("div", { class: "lab" },
		el("div", { class: "lab-left", ref: n => (left = n) },
			el("div", { class: "card lab-cases" },
				el("header", { class: "cases-head" },
					el("span", {}, "Cases"),
					el("span", { class: "combo" }, () => (run() ? counterText(key()) : `${order.length} cases`)),
					el("span", { class: "spacer" }),
					el("button", {
						class: "btn tree-toggle", type: "button", "aria-controls": treeId,
						"aria-expanded": () => String(treeOpen()), disabled: fn.tree.length === 0,
						onclick: () => setTreeOpen(!treeOpen()),
					}, () => (treeOpen() ? "Hide cases" : "Show cases")),
					el("button", { class: "btn", type: "button", onclick: () => showCase("") }, "Reset"),
					el("button", { class: "btn", type: "button", disabled: single, onclick: () => step(-1), "aria-label": "Previous case" }, "‹ Prev"),
					el("button", { class: "btn", type: "button", disabled: single, onclick: () => step(1), "aria-label": "Next case" }, "Next ›"),
					el("div", { class: "edge-note" }, () => EdgeNote(run(), index, showCase)),
					el("div", { class: "case-text", "aria-live": "polite" }, () => describe(run(), "case"))),
				el("div", { class: "body store-host" }, () => run() && StorePanel("DataStore before", run().input.cloud, run().input.tx)),
				el("div", { class: "body", id: treeId, hidden: () => !treeOpen() }, Tree(fn, index, key, setKey))),
			el("div", { class: "card lab-code" },
				el("header", {}, "Code sample", el("span", { class: "spacer" }), CopyButton(() => shownCode ?? "")),
				el("div", { class: "body" }, codeHost))),
		el("div", { class: "card lab-result", ref: n => (resultCard = n) },
			el("header", { class: "cases-head" },
				el("span", {}, "Result"),
				el("span", { class: () => (run() ? `outcome k-${run().outcome}` : "outcome") }, outcome),
				el("div", { class: "case-text", "aria-live": "polite" }, () => describe(run(), "result"))),
			el("div", { class: "body store-host" }, () => {
				const end = run()?.checkpoints.at(-1);
				return end && StorePanel("DataStore after", end.cloud, end.tx);
			}),
			el("div", {}, () => run() && Result(run()))));

	// each case's result starts at its top
	createRenderEffect(run, () => { resultCard.scrollTop = 0; });
	return lab;
}
