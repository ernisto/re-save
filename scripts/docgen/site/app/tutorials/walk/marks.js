// What points at the code while a phrase is lit: the text window scrolled to the phrase,
// a box over its statement, or a box over its columns with the value card above.
import { REDUCED_MOTION } from "../../data.js";
import { el } from "../../dom.js";
import { highlightInto } from "../../highlight.js";
import { statementLines } from "../text.js";

// the text window: each state's line sits on the window's 2nd row; scrolling between two
// states glides between their lines, and past the last one on to the end of the text
export function readTo(w, i, frac) {
	const { reading, stage, lineTops } = w;
	const max = reading.scrollHeight - reading.clientHeight;
	if (max <= 0) {
		reading.classList.remove("more");
		return;
	}
	const style = getComputedStyle(reading);
	const row = parseFloat(style.lineHeight) || 28;
	// the clear rows; under them only the faded peek of the next line
	const rows = reading.clientHeight - 0.7 * parseFloat(style.fontSize) + 1;
	const anchor = j => {
		if (j < 0) return 0;
		const { from, to } = stage.states[Math.min(j, stage.states.length - 1)];
		const bottom = lineTops[to] + row;
		let top = from > 0 ? lineTops[from - 1] : 0;
		if (bottom - top > rows) top = lineTops[from];
		return Math.max(0, Math.min(max, top));
	};
	const last = i >= stage.states.length - 1;
	const top = Math.round(i < 0 ? 0 : last ? anchor(i) : anchor(i) + frac * (anchor(i + 1) - anchor(i)));
	reading.classList.toggle("more", top < max - 2);
	if (top === w.readTop) return;
	w.readTop = top;
	reading.scrollTo({ top, behavior: REDUCED_MOTION ? "auto" : "smooth" });
}

// the DOM range of a mark: the phrase's columns, right after its context, on the first line holding both
function columnRange(group, beat) {
	for (const line of group.querySelectorAll(".ln:not(.del):not(.folded):not(.folding)")) {
		const at = line.textContent.indexOf(beat.context + beat.columns);
		if (at === -1) continue;
		const from = at + beat.context.length;
		const to = from + beat.columns.length;
		const range = document.createRange();
		const walker = document.createTreeWalker(line, NodeFilter.SHOW_TEXT);
		let seen = 0;
		for (let node = walker.nextNode(); node; node = walker.nextNode()) {
			const len = node.textContent.length;
			if (seen <= from && from <= seen + len) range.setStart(node, from - seen);
			if (seen <= to && to <= seen + len) { range.setEnd(node, to - seen); return range; }
			seen += len;
		}
	}
	console.warn(`tutorial mark: no code line holds "${beat.context + beat.columns}"`);
	return null;
}

// one indicator per code block slides (top + height) to cover the lit lines
function placeIndicators(group, lit) {
	const hot = new Set(lit);
	for (const pre of group.querySelectorAll("pre")) {
		let box = pre.querySelector(":scope > .hl-box");
		if (!box) {
			box = el("div", { class: "hl-box", "aria-hidden": "true" });
			pre.prepend(box);
		}
		const lines = [...pre.querySelectorAll(".ln")].filter(l => hot.has(l));
		box.classList.toggle("on", lines.length > 0);
		if (lines.length === 0) continue;
		const first = lines[0];
		const last = lines[lines.length - 1];
		box.style.top = `${first.offsetTop}px`;
		box.style.height = `${last.offsetTop + last.offsetHeight - first.offsetTop}px`;
	}
}

// boxes the columns and puts the value card over them (below when there's no room)
function markColumns(w, beat, range) {
	const { stage, group, markBox, cover } = w;
	const base = stage.getBoundingClientRect();
	const r = range.getBoundingClientRect();
	Object.assign(markBox.style, { left: `${r.left - base.left - 3}px`, top: `${r.top - base.top - 1}px`, width: `${r.width + 6}px`, height: `${r.height + 2}px` });
	if (beat.value === undefined) return;
	cover.replaceChildren(highlightInto(el("code"), beat.value));
	const above = r.top - base.top - cover.offsetHeight - 8;
	const top = above >= group.offsetTop ? above : r.bottom - base.top + 8;
	const left = Math.min(r.left - base.left, stage.clientWidth - cover.offsetWidth);
	Object.assign(cover.style, { left: `${Math.max(0, left)}px`, top: `${top}px` });
}

// "scroll down to advance" under the code of the upper resting title on screen (stage.hinted,
// see markHints), held above the bottom of the screen (and of the stage) when the code runs past it
export function placeHint(w) {
	const { stage, group, hint } = w;
	const on = stage.hinted === true && stage.resting();
	hint.classList.toggle("on", on);
	if (!on) return;
	const base = stage.getBoundingClientRect();
	const code = group.getBoundingClientRect();
	// never above the code's top: while the code is still below the screen, so is the hint
	const lowest = Math.min(window.innerHeight, base.bottom) - hint.offsetHeight - 8;
	hint.style.top = `${Math.max(code.top + 8, Math.min(code.bottom + 8, lowest)) - base.top}px`;
	hint.style.left = `${code.left - base.left + (code.width - hint.offsetWidth) / 2}px`; // centred under the code
}

// indicators, for a phrase that changes no code (one that does shows the change instead);
// scroll: also bring what is lit into the code panel's view
export function placeMarks(w, scroll = false) {
	const { group, stateCol, markBox, cover } = w;
	const ready = performance.now() >= w.revealAt && !w.changing;
	const beat = ready ? w.beats[w.shown - 1] : null;
	const lit = beat && beat.kind === "code" ? beat.needles.flatMap(n => statementLines(group, n)) : [];
	placeIndicators(group, lit);

	const range = beat && beat.kind === "mark" ? columnRange(group, beat) : null;
	markBox.classList.toggle("on", range !== null);
	cover.classList.toggle("on", range !== null && beat.value !== undefined);
	if (range && w.markFor !== w.shown) {
		// a new mark spawns in place (no sliding over from the last one)
		w.markFor = w.shown;
		for (const node of [markBox, cover]) {
			node.classList.remove("spawn");
			void node.offsetWidth;
			node.classList.add("spawn");
		}
	}
	if (!range) w.markFor = null;

	let target = lit[0] ?? group.querySelector(".ln.add");
	if (range) {
		markColumns(w, beat, range);
		target = range.startContainer.parentElement.closest(".ln");
	}
	placeHint(w);
	if (scroll && target && !stateCol.contains(target)) {
		const top = target.getBoundingClientRect().top - group.getBoundingClientRect().top + group.scrollTop - group.clientHeight / 4;
		group.scrollTo({ top: Math.max(0, top), behavior: REDUCED_MOTION ? "auto" : "smooth" });
	}
}
