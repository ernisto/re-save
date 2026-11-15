// Moving a walk from state to state: diffs glide in, folds animate, and going forward
// several states at once plays them in order.
import { diffLines, renderCodeChange } from "../../codechange.js";
import { REDUCED_MOTION } from "../../data.js";
import { fold } from "./blocks.js";

const GLIDE = 350;

// a diff still waiting for its glide plays now, without animating
function settlePending(w) {
	if (!w.pending) return;
	clearTimeout(w.pending.timer);
	w.pending.run(false);
	w.pending = null;
}

// scroll the code panel (smoothly) so the first changed line of a redraw sits in view;
// false when it already is
function glideTo(w, { b, old, next }) {
	const oldLines = old === "" ? [] : old.split("\n");
	let at = 0;
	for (const st of diffLines(oldLines, next.split("\n"))) {
		if (st.op !== "keep") break;
		at++;
	}
	const lines = [...b.host.querySelectorAll(".ln:not(.del)")];
	const line = lines[Math.min(at, lines.length - 1)];
	if (!line) return false;
	const box = w.group.getBoundingClientRect();
	const r = line.getBoundingClientRect();
	if (r.top >= box.top + 8 && r.bottom <= box.bottom - box.height / 3) return false;
	const top = r.top - box.top + w.group.scrollTop - w.group.clientHeight / 4;
	w.group.scrollTo({ top: Math.max(0, top), behavior: "smooth" });
	return true;
}

// show state k; returns how long its animation runs. A diff first glides the code to where
// it lands, then plays; a frame with a diff shows no other indicator
function apply(w, k) {
	const { stage, group, blocks, refs } = w;
	settlePending(w);
	group.querySelectorAll(".ln.add").forEach(l => l.classList.remove("add", "after-del"));
	const before = w.shown;
	w.shown = k;
	let folding = false;
	const on = w.folds && k >= 0;
	const redraws = [];
	for (const b of blocks) {
		const next = b.at(k);
		if (next !== b.shown) redraws.push({ b, old: b.shown, next });
		else if (on !== before >= 0) {
			// folding animates the first time it turns on
			fold(b, on, on && before < 0);
			folding ||= on && before < 0;
		}
		b.shown = next;
	}
	// a script that changes shows its diff alone; state changing beside it still lets the
	// phrase point at its code
	w.changing = k >= 1 && redraws.some(r => r.b.kind === "script");
	w.sync();
	refs.forEach((ref, j) => ref.classList.toggle("active", j === k - 1));

	const draw = animate => {
		for (const { b, old, next } of redraws) {
			renderCodeChange(b.host, animate ? old : null, next);
			fold(b, on, false);
		}
		stage.place();
	};
	if (redraws.length === 0 || REDUCED_MOTION || k < 1) {
		draw(!REDUCED_MOTION && k >= 1);
		const settle = REDUCED_MOTION ? 0 : folding ? 400 : 0;
		w.revealAt = performance.now() + settle;
		stage.place(true);
		setTimeout(() => stage.place(), settle + 20);
		return settle;
	}

	// glide to the first line that changes, then play the diff
	w.revealAt = Infinity;
	stage.place();
	const moved = redraws.find(r => r.b.kind !== "ds"); // state panels stay put beside the scripts
	const glide = moved && glideTo(w, moved) ? GLIDE : 0;
	w.pending = { run: draw };
	w.pending.timer = setTimeout(() => {
		w.pending = null;
		draw(true);
		w.revealAt = performance.now() + 750;
	}, glide);
	return glide + 750;
}

// stage.show(k, index) / stage.jump(k, index) / stage.busy(): going forward plays each state
// after the last one's animation, so a fold and a diff never share a frame; going back, and
// any change out of sight, jumps straight there
export function player(w) {
	const { stage, group } = w;
	const order = () => [-1, ...new Set(stage.states.map(st => st.k).filter(k => k !== -1))];
	let target = -1;
	let timer = null;
	let lastIndex = -1;

	const advance = () => {
		timer = null;
		if (w.shown === target) return;
		const ks = order();
		if (ks.indexOf(target) < ks.indexOf(w.shown)) {
			apply(w, target);
			return;
		}
		const wait = apply(w, ks[ks.indexOf(w.shown) + 1]);
		if (w.shown !== target) timer = setTimeout(advance, wait);
	};

	const show = (k, index = -1) => {
		// a scroll that only moves to the next line still ends the last diff's green
		if (index !== lastIndex && k === w.shown && timer === null) group.querySelectorAll(".ln.add").forEach(l => l.classList.remove("add", "after-del"));
		lastIndex = index;
		target = k;
		if (timer === null) advance();
	};

	// out of sight: straight to state k, nothing played on the way
	const jump = (k, index = -1) => {
		clearTimeout(timer);
		timer = null;
		settlePending(w);
		lastIndex = index;
		target = k;
		if (w.shown === k) return;
		w.shown = k;
		for (const b of w.blocks) {
			b.shown = b.at(k);
			renderCodeChange(b.host, null, b.shown);
			fold(b, w.folds && k >= 0, false);
		}
		w.sync();
		w.refs.forEach((ref, j) => ref.classList.toggle("active", j === k - 1));
		stage.place();
	};
	return { show, jump, busy: () => timer !== null };
}
