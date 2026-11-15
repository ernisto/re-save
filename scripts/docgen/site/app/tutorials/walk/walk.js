// A step becomes a walk once its chapter has code: the stage pins its title + text on top
// and every script below. States, one scroll each: -1 = the previous title's code as is;
// 0 = top-level statements no phrase touches fold away; k = phrase k lit (its script frames
// slide in; with no change, its statement or columns get the indicator).
import { el } from "../../dom.js";
import { parseBeat } from "../text.js";
import { makeBlocks } from "./blocks.js";
import { fit } from "./fit.js";
import { placeHint, placeMarks, readTo } from "./marks.js";
import { player } from "./play.js";

// the stage's panels, scripts (and their output) left, state right
function codeGroup(blocks) {
	const scripts = blocks.filter(b => b.kind !== "ds").sort((a, b) => (a.kind === "out") - (b.kind === "out"));
	const stateCol = el("div", { class: "codecol states" }, blocks.filter(b => b.kind === "ds").map(b => b.figure));
	const group = el("div", { class: "codegroup" }, el("div", { class: "codecol" }, scripts.map(b => b.figure)), stateCol);
	return { group, stateCol };
}

// step: the step's node (its h3 + text); scripts: [caption] = { code, kind } carried over
// from earlier titles, updated to this one's frames
export function buildWalk(step, scripts, fences) {
	const start = new Map([...scripts].map(([caption, s]) => [caption, s.code]));
	for (const f of fences) scripts.set(f.caption, { code: f.code, kind: f.kind });
	if (scripts.size === 0) return;

	const head = step.querySelector(":scope > h3");
	const reading = el("div", { class: "stage-lines" }, [...step.childNodes].filter(n => n !== head));
	const text = el("div", { class: "stage-text" }, head, reading);
	const refs = [...text.querySelectorAll(".beatref")];
	const beats = refs.map(ref => parseBeat(ref.dataset.beat));
	const blocks = makeBlocks(start, scripts, fences, beats.flatMap(b => b.needles));
	// a panel taken away, and any output, don't carry on to the next title
	for (const [caption, s] of scripts) if (s.code === "" || s.kind === "out") scripts.delete(caption);

	const { group, stateCol } = codeGroup(blocks);
	const markBox = el("div", { class: "mark-box" });
	const cover = el("div", { class: "cover" });
	const hint = el("div", { class: "walk-hint" }, el("span", { class: "arrow" }, "↓"), "Scroll down to advance");
	const stage = el("div", { class: "stage" }, text, group, el("div", { class: "stage-overlay", "aria-hidden": "true" }, markBox, cover, hint));
	const slots = el("div", { class: "slots", "aria-hidden": "true" }, el("div", { class: "slot" }));
	stage.states = [{ k: -1, from: 0, to: 0 }];
	stage.slots = [...slots.children];

	const w = {
		stage, group, stateCol, reading, text, slots, refs, beats, blocks, markBox, cover, hint,
		folds: beats.length > 0 && blocks.some(b => b.keys.size > 0),
		sync: () => blocks.forEach(b => { b.figure.hidden = b.shown === ""; }),
		lineTops: [0], // top of each visual line of the text
		shown: -1, // the state on screen
		revealAt: 0, // a phrase that changes code shows its indicator once the change settles
		changing: false,
		markFor: null,
		pending: null, // a diff waiting for its glide
		readTop: -1,
	};
	w.sync();

	const { show, jump, busy } = player(w);
	Object.assign(stage, {
		fit: () => fit(w),
		show,
		jump,
		busy,
		read: (i, frac) => readTo(w, i, frac),
		place: scroll => placeMarks(w, scroll),
		placeHint: () => placeHint(w),
		resting: () => w.shown === -1 && stage.states.some(st => st.k >= 0),
	});
	step.append(el("div", { class: "walk" }, stage, slots));

	group.addEventListener("scroll", () => stage.place(), { passive: true });
	group.addEventListener("animationend", e => {
		if (e.target.classList.contains("folding")) e.target.classList.replace("folding", "folded");
		if (/^line-(in|collapse|fold)$/.test(e.animationName)) stage.place();
	});
}
