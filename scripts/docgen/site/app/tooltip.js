// Hovering or focusing a snippet variable shows its recorded value; a function, its signature.
import { FUNCTIONS } from "./data.js";
import { el } from "./dom.js";
import { highlightInto } from "./highlight.js";
import { inline, splitSummary } from "./markdown.js";
import { createRenderEffect, createSignal } from "./solid.js";
import { Signature } from "./tokens.js";

const TIPPED = ".var, [data-fn]";
const MARGIN = 8;

function TipContent(target) {
	const fn = target.dataset.fn && FUNCTIONS.get(target.dataset.fn);
	if (fn) return [
		el("div", { class: "vartip-sig" }, Signature(fn)),
		el("p", { class: "vartip-sum" }, inline(splitSummary(fn.md)[0])),
	];
	return [el("div", { class: "vartip-name" }, target.textContent), highlightInto(el("pre"), target.dataset.value)];
}

// fixed to the window: below the target when it fits, else above; clamped to the edges
function placeTip(tip, target) {
	const box = target.getBoundingClientRect();
	const viewWidth = document.documentElement.clientWidth;
	const viewHeight = window.innerHeight;
	const clamp = (value, low, high) => Math.max(low, Math.min(value, high));

	const below = box.bottom + 6;
	const above = box.top - 6 - tip.offsetHeight;
	const top = below + tip.offsetHeight <= viewHeight - MARGIN || above < MARGIN ? below : above;
	tip.style.left = `${clamp(box.left, MARGIN, viewWidth - tip.offsetWidth - MARGIN)}px`;
	tip.style.top = `${clamp(top, MARGIN, viewHeight - tip.offsetHeight - MARGIN)}px`;
}

export function Tooltip() {
	const [target, setTarget] = createSignal(null);
	const tip = el("div", { class: "vartip", role: "tooltip", id: "vartip", hidden: () => target() === null },
		() => target() && TipContent(target()));

	createRenderEffect(target, (now, before) => {
		before?.removeAttribute("aria-describedby");
		if (!now) return;
		now.setAttribute("aria-describedby", "vartip");
		placeTip(tip, now);
	});

	document.addEventListener("mouseover", e => {
		const v = e.target.closest?.(TIPPED);
		if (v) setTarget(v);
	});
	document.addEventListener("mouseout", e => {
		const v = e.target.closest?.(TIPPED);
		if (v && !v.contains(e.relatedTarget)) setTarget(null);
	});
	document.addEventListener("focusin", e => { if (e.target.matches?.(TIPPED)) setTarget(e.target); });
	document.addEventListener("focusout", e => { if (e.target.matches?.(TIPPED)) setTarget(null); });
	document.addEventListener("keydown", e => { if (e.key === "Escape") setTarget(null); });
	// a fixed tooltip would drift away from its target while the page scrolls
	window.addEventListener("scroll", () => setTarget(null), { passive: true, capture: true });
	return tip;
}
