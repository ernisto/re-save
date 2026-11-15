// A walk's panels: one block per script or state, the code it shows at each phrase, and
// the statements that fold away while no phrase needs them.
import { diffLines, renderCodeChange } from "../../codechange.js";
import { el } from "../../dom.js";
import { statementRanges, topStatements } from "../text.js";

// fold keys: first lines of multi-line top-level statements that no phrase names and no
// frame of this title changes
function foldKeys(kind, first, final, needles) {
	const keys = new Set();
	if (kind !== "script") return keys;

	const lines = first === "" ? [] : first.split("\n");
	const removed = []; // line indexes of `first` that go away
	const inserted = []; // a line comes in right before this index of `first`
	let i = 0;
	for (const st of diffLines(lines, final.split("\n"))) {
		if (st.op === "del") removed.push(i);
		if (st.op === "add") inserted.push(i);
		if (st.op !== "add") i++;
	}
	for (const [a, z] of statementRanges(lines)) {
		const body = lines.slice(a, z + 1);
		const named = needles.some(n => body.some(t => t.includes(n)));
		const touched = removed.some(j => a <= j && j <= z) || inserted.some(j => a < j && j <= z);
		if (z > a && !named && !touched) keys.add(lines[a].trim());
	}
	return keys;
}

// start: [caption] = code before this title; scripts: every panel as of this title.
// at(k): the code at state k. A title at rest (-1) already shows its opening frames (those
// before any phrase), so it starts with its own code, drawn as is
export function makeBlocks(start, scripts, fences, needles) {
	return [...scripts].map(([caption, { kind }]) => {
		const frames = fences.filter(f => f.caption === caption);
		const at = k => frames.reduce((code, f) => (f.tag <= Math.max(k, 0) ? f.code : code), start.get(caption) ?? "");
		const opening = at(-1);
		const final = at(Infinity);

		const host = el("div", { class: "codechange" });
		if (kind === "out") host.dataset.plain = "1";
		renderCodeChange(host, null, opening);
		const figure = el("figure", { class: kind === "script" ? "codeblock" : `codeblock ${kind}` }, caption ? el("figcaption", {}, caption) : null, host);
		return { caption, kind, host, figure, at, final, keys: foldKeys(kind, opening, final, needles), shown: opening };
	});
}

// folded: a statement's signature and closing line stay, its body becomes one ⋯ line
export function fold(b, on, animate) {
	const pre = b.host.querySelector("pre");
	pre.querySelectorAll(".fold-mark").forEach(m => m.remove());
	pre.querySelectorAll(".ln").forEach(l => l.classList.remove("folded", "folding"));
	if (!on) return;
	for (const st of topStatements([...pre.querySelectorAll(".ln:not(.del)")])) {
		if (st.length < 3 || !b.keys.has(st[0].textContent.trim())) continue;
		const body = st.slice(1, -1);
		const indent = body[0].textContent.match(/^\s*/)[0];
		st[st.length - 1].before(el("div", { class: "ln fold-mark" }, `${indent}⋯`));
		body.forEach(l => l.classList.add(animate ? "folding" : "folded"));
	}
}
