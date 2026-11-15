// Views (home | tutorials | examples | reference), the shown tutorial chapter, and the
// scrolling every in-page link does. A target inside a hidden view shows that view first.
import { REDUCED_MOTION, topH } from "./data.js";
import { el } from "./dom.js";
import { createSignal, flush } from "./solid.js";

export const [view, setView] = createSignal("reference");
export const [chapter, setChapter] = createSignal(null); // id of the shown tutorial chapter

export function showView(id) {
	setView(id);
	flush();
	window.dispatchEvent(new Event("resize"));
}

export function showChapter(id) {
	setChapter(id);
	flush();
	window.dispatchEvent(new Event("scroll"));
}

// Scroll just enough to show `target`, smoothly unless reduced motion is asked for:
// below the window -> the target's bottom meets the window bottom (a function's pinned
// signature stays visible at the top); above -> its top meets the window top (below a
// pinned signature when inside a function); already in view -> stay.
export function revealAnchor(target) {
	const box = target.getBoundingClientRect();
	const section = target.matches("section.member") ? null : target.closest("section.member");
	const pin = section ? parseFloat(getComputedStyle(section).getPropertyValue("--pin")) || 0 : 0;
	const viewTop = topH() + pin + 8;
	const viewBottom = window.innerHeight - 8;

	let delta = 0;
	if (box.top < viewTop) delta = box.top - viewTop;
	else if (box.bottom > viewBottom) delta = box.bottom - viewBottom;
	if (Math.abs(delta) < 1) return;
	window.scrollBy({ top: delta, behavior: REDUCED_MOTION ? "auto" : "smooth" });
}

export function go(target, instant = false) {
	const shell = target.closest("[data-view]");
	const switched = shell !== null && shell.hidden;
	if (switched) showView(shell.id);

	// tutorials: one chapter page at a time; the tab itself opens the shown (or first) one
	let pageSwitched = false;
	if (shell?.id === "tutorials") {
		const page = target.closest(".chapter") ?? shell.querySelector(".chapter:not([hidden])") ?? shell.querySelector(".chapter");
		if (page?.hidden) {
			showChapter(page.id);
			pageSwitched = true;
		}
	}

	if (target === shell || target.matches(".chapter")) window.scrollTo({ top: 0 });
	else if (switched || pageSwitched || instant) target.scrollIntoView();
	else revealAnchor(target);
}

// route the address bar's #id; no target: home
export function fromHash() {
	const target = location.hash.length > 1 && document.getElementById(decodeURIComponent(location.hash.slice(1)));
	if (target) go(target, true);
	else showView("home");
}

// in-page links: smooth, minimal scroll (see revealAnchor); the hash updates without a jump
export function followLinks() {
	document.addEventListener("click", e => {
		const link = e.target.closest?.("a[href^='#']");
		if (!link || link.classList.contains("caselink")) return;
		const id = decodeURIComponent(link.getAttribute("href").slice(1));
		const target = id && document.getElementById(id);
		if (!target) return;

		e.preventDefault();
		history.replaceState(null, "", `#${id}`);
		go(target);
	});
	window.addEventListener("hashchange", fromHash);
}

function scrollToSection(target) {
	window.scrollTo({ top: target.getBoundingClientRect().top + window.scrollY - topH(), behavior: REDUCED_MOTION ? "auto" : "smooth" });
}

// a heading that titles section `id`: a click scrolls to the top of it, # copies its link
export function Anchored(heading, id) {
	const [mark, setMark] = createSignal("#");
	const copy = e => {
		e.stopPropagation();
		navigator.clipboard?.writeText(`${location.href.split("#")[0]}#${id}`).then(() => {
			setMark("✓");
			setTimeout(() => setMark("#"), 1200);
		}, () => {});
		history.replaceState(null, "", `#${id}`);
	};

	heading.append(el("button", { class: "hash", type: "button", title: "Copy link", "aria-label": "Copy link to this section", onclick: copy }, mark));
	heading.classList.add("anchored");
	heading.addEventListener("click", e => {
		// links inside the heading (a signature's types) still go where they point
		if (e.target.closest("a, button")) return;
		history.replaceState(null, "", `#${id}`);
		scrollToSection(document.getElementById(id));
	});
	return heading;
}

const slug = text => text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

// a section heading (h2.part) that titles what follows it, up to the next one
export const Part = title => Anchored(el("h2", { class: "part", id: `section-${slug(title)}` }, title), `section-${slug(title)}`);
