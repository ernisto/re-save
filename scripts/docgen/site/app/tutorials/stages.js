// Which state each walk of the shown chapter is in, as the page scrolls. Two kinds (see fit):
// - free: the whole stage fits the window. It stays where it is: while all of it is on
//   screen, the wheel, arrow keys and swipes step its states in place, the topmost stage
//   with a state left first
// - pinned: taller stages pin to the top; the last slot that reached the top is the state
import { topH, viewH } from "../data.js";

export const shownStages = host => [...(host.querySelector(".chapter:not([hidden])")?.querySelectorAll(".stage") ?? [])];

export function onScreen(stage) {
	const r = stage.getBoundingClientRect();
	return r.top >= topH() - 1 && r.bottom <= window.innerHeight + 1;
}

const freeStages = host => shownStages(host).filter(st => st.free);

// the state a free stage steps to that way, from the one it shows (an idle stage shows -1
// below the one walking, its last state above it); null: none
function nextOf(st, dir) {
	const at = st.cursor ?? st.idle;
	const next = at === -1 ? (dir > 0 ? st.first : -1) : at + dir;
	return next >= st.first && next < st.states.length ? next : null;
}

// "scroll down to advance" shows on one stage at most: the upper one on screen that scrolling
// would move next, while it rests (one mid-walk shows its phrases instead)
export function markHints(host) {
	let decided = false;
	for (const stage of shownStages(host)) {
		const r = stage.getBoundingClientRect();
		const seen = r.bottom > topH() && r.top < window.innerHeight;
		const resting = stage.resting?.() === true;
		const pending = resting || (stage.free && stage.cursor != null && nextOf(stage, 1) !== null);
		stage.hinted = !decided && seen && resting;
		decided ||= seen && pending;
		stage.placeHint?.();
	}
}

// one state of the first free stage on screen that has one that way; false: scroll on
export function stepFree(host, dir) {
	const stages = freeStages(host).filter(st => onScreen(st) && st.cursor !== undefined);
	for (const st of dir > 0 ? stages : stages.reverse()) {
		const next = nextOf(st, dir);
		if (next === null) continue;
		st.cursor = next;
		st.show(st.states[next].k, next);
		st.read(next, 0);
		markHints(host);
		return true;
	}
	return false;
}

// a free stage that still has a state that way (one not reached yet counts from its rest)
export const hasStep = (st, dir) => nextOf(st, dir) !== null;

export const freeHasStep = (host, dir) => freeStages(host).some(st => onScreen(st) && st.cursor !== undefined && nextOf(st, dir) !== null);

// how far down the window a pinned stage's top sits
export const reach = stage => topH() + Math.max(0, viewH() - stage.offsetHeight);

export function stateOf(stage) {
	const line = reach(stage) + 1;
	let current = -1;
	stage.slots.forEach((slot, i) => { if (slot.getBoundingClientRect().top < line) current = i; });
	return current;
}

// A free stage walks only when stepped (wheel, keys, swipes: see stepFree); until then it
// rests on its opening code. Only a stage fully out of the window resets: above it, its walk
// is over (idle = last); below it, it hasn't begun (idle = -1). One only partly cut off (a
// nudge, a smooth-scroll tail) keeps its state
function followFree(stage, move) {
	const r = stage.getBoundingClientRect();
	if (r.bottom <= topH()) {
		stage.cursor = null;
		stage.idle = stage.states.length - 1;
	} else if (r.top >= window.innerHeight) {
		stage.cursor = null;
		stage.idle = -1;
	} else stage.idle ??= -1;

	const current = stage.cursor ?? stage.idle;
	stage[move](current === -1 ? -1 : stage.states[current].k, current);
	stage.read(current, 0);
}

function followPinned(stage, move) {
	const current = stateOf(stage);
	stage[move](current === -1 ? -1 : stage.states[current].k, current);
	if (current < 0) return stage.read(-1, 0);
	// how far through this state the page is
	const slot = stage.slots[current];
	const last = current === stage.slots.length - 1;
	const into = reach(stage) - slot.getBoundingClientRect().top;
	stage.read(current, last ? 0 : Math.max(0, Math.min(1, into / slot.offsetHeight)));
}

// follow(): every walk of the shown chapter to the state the scroll puts it in, fitting the
// ones that come near the window first
export function follower(host) {
	return () => {
		if (host.offsetParent === null) return;
		for (const stage of shownStages(host)) {
			const box = stage.parentNode.getBoundingClientRect();
			const near = box.bottom > topH() && box.top < window.innerHeight;
			if (near) stage.fit();
			// one out of sight just takes its state: nobody would see it play
			const move = near ? "show" : "jump";
			if (stage.free) followFree(stage, move);
			else followPinned(stage, move);
		}
		markHints(host);
	};
}
