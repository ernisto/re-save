// Sizing a walk once per title: the zoom at which every state fits, how much text shows,
// and one scroll slot per state.
import { renderCodeChange } from "../../codechange.js";
import { viewH } from "../../data.js";
import { el } from "../../dom.js";
import { textLines } from "../text.js";
import { fold } from "./blocks.js";
import { fitCode, measureCode } from "./zoom.js";

// what the panels show at state k, drawn at once
function drawState(w, k) {
	for (const b of w.blocks) {
		const code = b.at(k);
		renderCodeChange(b.host, null, code);
		fold(b, w.folds && k >= 0, false);
		b.figure.hidden = code === "";
	}
}

// every state the walk can show; with folds, -1 is only the hand-over from the last title
const fitStates = w => [...(w.folds ? [] : [-1]), ...Array.from({ length: w.beats.length + 1 }, (_, k) => k)];

// states ({ k, from, to }) are one scroll each: the pin, the fold, then one per phrase (lines
// from..to of the text), and one per line no phrase covers. The stage unpins after the last
function layout(w) {
	const { reading, refs, folds, stage, slots } = w;
	w.lineTops = textLines(reading);
	const base = reading.getBoundingClientRect().top - reading.scrollTop;
	const lineAt = rect => {
		let at = 0;
		w.lineTops.forEach((t, i) => { if (t <= rect.top - base + 6) at = i; });
		return at;
	};
	const spans = refs.map(ref => {
		const rects = [...ref.getClientRects()].filter(r => r.height > 0);
		return rects.length === 0 ? [0, 0] : [lineAt(rects[0]), lineAt(rects[rects.length - 1])];
	});
	const states = folds ? [{ k: -1, from: 0, to: 0 }, { k: 0, from: 0, to: 0 }] : [];
	let k = 0;
	w.lineTops.forEach((_, line) => {
		const here = spans.flatMap(([a], i) => (a === line ? [i + 1] : []));
		if (here.length === 0) {
			const covered = spans.some(([a, z]) => a < line && line <= z);
			if (!covered && !(folds && line === 0)) states.push({ k, from: line, to: line });
			return;
		}
		for (const p of here) {
			k = p;
			states.push({ k, from: spans[p - 1][0], to: spans[p - 1][1] });
		}
	});
	stage.states = states.length > 0 ? states : [{ k: 0, from: 0, to: 0 }];
	slots.replaceChildren(...stage.states.map(() => el("div", { class: "slot" })));
	stage.slots = [...slots.children];
}

// the text shows as much as fits next to the code at its natural size: all of it, or as
// many lines as fit (never under 3), the rest scrolling by as phrases light
function fitText(w, pad, gap) {
	const { reading, text, group } = w;
	const style = getComputedStyle(reading);
	const row = parseFloat(style.lineHeight) || 28;
	const peek = 0.7 * parseFloat(style.fontSize);
	const head = text.offsetHeight - reading.offsetHeight;
	const budget = viewH() - pad - gap - measureCode(group, fitStates(w), k => drawState(w, k), 1).height;
	if (head + reading.scrollHeight <= budget) reading.style.maxHeight = "none";
	else reading.style.maxHeight = `${Math.max(3, Math.floor((budget - head - peek) / row)) * row + peek}px`;
}

// checked on the real layout (columns share the width there), with the stage unclamped:
// when a state still overflows, the zoom shrinks to fit it, down to the readable floor
function tallestState(w, room) {
	const { stage, group } = w;
	stage.style.maxHeight = "none";
	let height = 0;
	for (let tries = 0; tries < 3; tries++) {
		height = 0;
		let code = 0;
		for (const k of fitStates(w)) {
			drawState(w, k);
			if (stage.offsetHeight > height) {
				height = stage.offsetHeight;
				code = group.offsetHeight;
			}
		}
		const zoom = parseFloat(group.style.getPropertyValue("--zoom")) || 1;
		if (height <= room || zoom <= 0.8 || code === 0) break;
		group.style.setProperty("--zoom", Math.max(0.8, zoom * (code - (height - room)) / code).toFixed(3));
	}
	stage.style.maxHeight = "";
	return Math.min(height, viewH());
}

// zoom is settled once per title, so every state of the walk fits; the stage is as tall as
// its tallest state needs (up to the window), so short code leaves no empty screen
export function fit(w) {
	const { stage, group, reading, text, slots } = w;
	if (stage.fitted || group.clientWidth === 0) return;
	stage.fitted = true;

	stage.style.height = "";
	reading.style.maxHeight = "";
	const stageStyle = getComputedStyle(stage);
	const pad = parseFloat(stageStyle.paddingTop) + parseFloat(stageStyle.paddingBottom);
	const gap = parseFloat(stageStyle.rowGap) || 0;
	fitText(w, pad, gap);

	// a little short of the window: a stage whose content fits stays free, not window-tall
	const room = viewH() - 4;
	fitCode(group, room - pad - gap - text.offsetHeight, fitStates(w), k => drawState(w, k));
	layout(w);
	const height = tallestState(w, room);
	stage.style.height = `${height}px`;

	// free when all of it fits the window: it never pins, so its walk is the stage itself.
	// Its states skip the hand-over from the last title (that one is on screen too)
	stage.free = height < viewH() - 1;
	stage.first = Math.max(0, stage.states.findIndex(st => st.k >= 0));
	stage.cursor = null;
	slots.hidden = stage.free;
	slots.style.marginTop = `${-height}px`;
	// pinned: the walk starts once its top reaches the window's; one slot per state, and it
	// leaves right after the last one
	const n = stage.slots.length;
	stage.slots.forEach((slot, i) => { slot.style.height = `${i < n - 1 ? 100 : height}px`; });

	w.blocks.forEach(b => { renderCodeChange(b.host, null, b.shown); fold(b, w.folds && w.shown >= 0, false); });
	w.sync();
	stage.place();
}
