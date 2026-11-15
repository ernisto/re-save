// The tutorials: one page per chapter = chapter nav | article | on-this-page.
import { DATA } from "../data.js";
import { el } from "../dom.js";
import { inline, Markdown } from "../markdown.js";
import { Anchored, chapter, setChapter } from "../nav.js";
import { createSignal } from "../solid.js";
import { steer } from "./input.js";
import { follower } from "./stages.js";
import { splitFences, splitSteps } from "./text.js";
import { buildWalk } from "./walk/walk.js";

const chapterId = tut => `tutorial-${tut.slug}`;

// a step: its title and text; on a page where phrases light code, its fences become a walk
function Step(tut, step, i, scripts, lit) {
	const id = `${tut.slug}-${i}`;
	const { text, fences } = lit ? splitFences(step.lines.join("\n")) : { text: step.lines.join("\n"), fences: [] };
	const node = el("div", { class: "step", id, "data-title": step.title ?? null },
		step.title ? Anchored(el("h3", {}, inline(step.title)), id) : null,
		Markdown(text));
	if (lit) buildWalk(node, scripts, fences);
	return node;
}

const PagerLink = (cls, href, label, title) => el("a", { class: cls, href }, el("small", {}, label), el("span", {}, title));

function Chapter(tut, n) {
	const id = chapterId(tut);
	const scripts = new Map();
	// no phrase lights code: a plain page, its fences shown as is
	const lit = /\]\((code|mark):/.test(tut.md);
	const prev = DATA.tutorials[n - 1];
	const next = DATA.tutorials[n + 1];

	return el("section", { class: "chapter", id, hidden: () => chapter() !== id },
		Anchored(el("h2", {}, tut.title), id),
		splitSteps(tut.md).map((step, i) => Step(tut, step, i, scripts, lit)),
		el("nav", { class: "pager", "aria-label": "Chapters" },
			prev ? PagerLink("prev", `#${chapterId(prev)}`, "Previous", prev.title) : null,
			next ? PagerLink("next", `#${chapterId(next)}`, "Next", next.title) : PagerLink("next", "#reference", "Next", "API Reference")));
}

// on-this-page: the titled steps of the shown chapter, the last one whose top passed 30%
// of the window marked
function Toc(host) {
	const [active, setActive] = createSignal(null);
	const titled = () => [...(host.querySelector(`[id="${chapter()}"]`)?.querySelectorAll(".step[data-title]") ?? [])];
	const spy = () => {
		if (host.offsetParent === null) return;
		const line = window.innerHeight * 0.3;
		let current = null;
		for (const step of titled()) {
			if (step.getBoundingClientRect().top > line) break;
			current = step.id;
		}
		setActive(current);
	};

	const toc = el("aside", { class: "toc", id: "toc", "aria-label": "On this page" }, () => [
		el("div", { class: "heading" }, "On this page"),
		titled().map(step => el("a", {
			href: `#${step.id}`, "data-target": step.id,
			class: () => (active() === step.id ? "active" : null),
		}, step.dataset.title)),
	]);
	return { toc, spy };
}

export function Tutorials() {
	if (DATA.tutorials.length > 0) setChapter(chapterId(DATA.tutorials[0]));
	const host = el("article", { class: "steps", id: "steps" }, DATA.tutorials.map(Chapter));
	const { toc, spy } = Toc(host);

	const follow = follower(host);
	let queued = false;
	window.addEventListener("scroll", () => {
		if (queued) return;
		queued = true;
		requestAnimationFrame(() => { queued = false; spy(); follow(); });
	}, { passive: true });
	window.addEventListener("resize", () => {
		host.querySelectorAll(".stage").forEach(st => { st.fitted = false; });
		follow();
	});
	steer(host);

	return el("div", { class: "tut", id: "tutorials", "data-view": "" },
		el("nav", { class: "chapters", id: "chapters", "aria-label": "Chapters" },
			el("div", { class: "heading" }, "Tutorials"),
			DATA.tutorials.map(tut => el("a", {
				href: `#${chapterId(tut)}`, "data-target": chapterId(tut),
				class: () => (chapter() === chapterId(tut) ? "active" : null),
			}, tut.title))),
		host,
		toc);
}
