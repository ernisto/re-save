// Wheel, keys and swipes on a tutorial page. One wheel gesture moves exactly one state: the
// rest of the gesture (momentum, extra notches) is swallowed, and a scroll that would reach
// (or carry past) a walk with states left glides to land it. Nothing ever jumps the page or
// pulls it back: the page's own glides replace the browser's, they don't fight them.
import { REDUCED_MOTION, topH } from "../data.js";
import { freeHasStep, hasStep, reach, shownStages, stateOf, stepFree } from "./stages.js";

const KEYS = { ArrowDown: 1, PageDown: 1, " ": 1, ArrowUp: -1, PageUp: -1 };
const SWIPE = 48; // a swipe of SWIPE px steps a free stage once

const glide = top => window.scrollTo({ top, behavior: REDUCED_MOTION ? "auto" : "smooth" });

// how far the page must move that way to land a walk it would otherwise scroll into or past
// (px: how far this scroll goes): a free stage fully on screen, a pinned one on its first
// slot (last, going up). null: none in reach. A finished walk doesn't stop the page again
function landingBy(host, dir, px) {
	for (const st of dir > 0 ? shownStages(host) : shownStages(host).reverse()) {
		if (!st.fitted || (st.free && !hasStep(st, dir))) continue;
		let by;
		if (st.free) {
			const r = st.getBoundingClientRect();
			by = dir > 0 ? Math.min(r.bottom - window.innerHeight, r.top - topH()) : r.top - topH();
		} else by = st.slots[dir > 0 ? 0 : st.slots.length - 1].getBoundingClientRect().top - reach(st);
		if (Math.abs(by) > 1 && Math.abs(by) <= px && Math.sign(by) === dir) return by;
	}
	return null;
}

// the pinned stage whose walk is under way: its first state reached, its last one not yet
const walkingStage = host => shownStages(host).find(st => {
	if (st.free) return false;
	const line = reach(st) + 1;
	return st.slots[0].getBoundingClientRect().top < line && st.slots[st.slots.length - 1].getBoundingClientRect().top >= line;
});

export function steer(host) {
	let gestureEnd = 0;
	let handled = false; // this gesture stepped or landed a walk: the rest of it does nothing
	// where the browser's own smooth scroll is still heading: notches it hasn't played yet count
	let nativeTo = null;
	let nativeAt = 0;

	window.addEventListener("wheel", e => {
		const now = performance.now();
		const inGesture = now < gestureEnd;
		gestureEnd = now + 180;
		if (e.ctrlKey || e.deltaY === 0 || host.offsetParent === null) return;
		if (!inGesture) handled = false;
		else if (handled) { e.preventDefault(); return; }

		// over a code panel that can still scroll that way, the wheel scrolls the code
		const code = e.target.closest?.(".codegroup");
		if (code) {
			const room = e.deltaY > 0 ? code.scrollHeight - code.clientHeight - code.scrollTop : code.scrollTop;
			if (room > 1) { gestureEnd = 0; return; }
		}

		const dir = Math.sign(e.deltaY);
		if (freeHasStep(host, dir)) {
			e.preventDefault();
			stepFree(host, dir);
			handled = true;
			return;
		}

		const delta = Math.abs(e.deltaY) * (e.deltaMode === 1 ? 16 : e.deltaMode === 2 ? window.innerHeight : 1);
		const queued = nativeTo !== null && now - nativeAt < 400 ? Math.max(0, (nativeTo - window.scrollY) * dir) : 0;
		const by = landingBy(host, dir, delta + queued + 1);
		if (by !== null) {
			e.preventDefault();
			nativeTo = null;
			glide(window.scrollY + by);
			handled = true;
			return;
		}

		// a pinned walk under way: one gesture glides to its next slot; past either end the page scrolls on
		const stage = walkingStage(host);
		const next = stage ? stateOf(stage) + dir : -1;
		if (next < 0 || next >= stage.slots.length) {
			nativeTo = window.scrollY + dir * (queued + delta);
			nativeAt = now;
			return;
		}
		e.preventDefault();
		nativeTo = null;
		glide(stage.slots[next].getBoundingClientRect().top + window.scrollY - reach(stage));
		handled = true;
	}, { passive: false });

	window.addEventListener("keydown", e => {
		const dir = KEYS[e.key];
		if (!dir || e.altKey || e.ctrlKey || e.metaKey || host.offsetParent === null) return;
		if (e.target.closest?.("input, textarea, select, [contenteditable]")) return;
		if (stepFree(host, e.shiftKey && e.key === " " ? -dir : dir)) e.preventDefault();
	});

	let touchY = null;
	window.addEventListener("touchstart", e => { touchY = e.touches[0].clientY; }, { passive: true });
	window.addEventListener("touchmove", e => {
		if (touchY === null || host.offsetParent === null) return;
		const dy = touchY - e.touches[0].clientY;
		const dir = Math.sign(dy);
		if (!freeHasStep(host, dir)) return;
		if (e.cancelable) e.preventDefault();
		if (Math.abs(dy) < SWIPE) return;
		stepFree(host, dir);
		touchY = e.touches[0].clientY;
	}, { passive: false });
	window.addEventListener("touchend", () => { touchY = null; }, { passive: true });
}
