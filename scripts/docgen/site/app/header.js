// The top bar: brand, version, view tabs, member search, theme toggle, GitHub link.
import { DATA, REPO } from "./data.js";
import { el, svg } from "./dom.js";
import { go, view } from "./nav.js";
import { createRenderEffect, createSignal } from "./solid.js";

const TABS = [["home", "Home"], ["tutorials", "Tutorials"], ["examples", "Examples"], ["reference", "API Reference"]];
const GITHUB_PATH = "M8 0c4.42 0 8 3.58 8 8a8.013 8.013 0 0 1-5.45 7.59c-.4.08-.55-.17-.55-.38 0-.27.01-1.13.01-2.2 0-.75-.25-1.23-.54-1.48 1.78-.2 3.65-.88 3.65-3.95 0-.88-.31-1.59-.82-2.15.08-.2.36-1.02-.08-2.12 0 0-.67-.22-2.2.82-.64-.18-1.32-.27-2-.27-.68 0-1.36.09-2 .27-1.53-1.03-2.2-.82-2.2-.82-.44 1.1-.16 1.92-.08 2.12-.51.56-.82 1.28-.82 2.15 0 3.06 1.86 3.75 3.64 3.95-.23.2-.44.55-.51 1.07-.46.21-1.61.55-2.33-.66-.15-.24-.6-.83-1.23-.82-.67.01-.27.38.01.53.34.19.73.9.82 1.13.16.45.68 1.31 2.69.94 0 .67.01 1.3.01 1.49 0 .21-.15.45-.55.38A7.995 7.995 0 0 1 0 8c0-4.42 3.58-8 8-8Z";

// a commit graph: a session's oplog (right) replayed onto the saved record (left)
const Brand = () => el("a", { class: "brand", href: "#home" },
	svg("svg", { viewBox: "0 0 24 24", "aria-hidden": "true" },
		svg("circle", { cx: "6", cy: "5", r: "2.5" }),
		svg("path", { d: "M6 7.5v9" }),
		svg("circle", { class: "solid", cx: "6", cy: "19", r: "2.5" }),
		svg("circle", { cx: "18", cy: "5", r: "2.5" }),
		svg("path", { d: "M18 7.5V11a8 8 0 0 1-8 8H8.5" })),
	"re-save");

// the saved choice, else the system's
const [theme, setTheme] = createSignal(localStorage.getItem("theme"));
export function applyTheme() {
	createRenderEffect(theme, t => { if (t) document.documentElement.dataset.theme = t; });
}
function toggleTheme() {
	const dark = getComputedStyle(document.documentElement).colorScheme === "dark";
	const next = dark ? "light" : "dark";
	localStorage.setItem("theme", next);
	setTheme(next);
}

function Repo() {
	const [stars, setStars] = createSignal("");
	fetch(`https://api.github.com/repos/${REPO}`)
		.then(r => (r.ok ? r.json() : null))
		.then(repo => { if (repo) setStars(`★ ${repo.stargazers_count}`); })
		.catch(() => {});

	return el("a", { class: "repo", href: `https://github.com/${REPO}`, "aria-label": `GitHub repository ${REPO}` },
		svg("svg", { viewBox: "0 0 16 16", "aria-hidden": "true" }, svg("path", { fill: "currentColor", d: GITHUB_PATH })),
		el("span", { class: "repo-text" },
			el("span", { class: "repo-name" }, REPO),
			el("span", { class: "stars", id: "stars", title: "GitHub stars" }, stars)));
}

// pick a member from the list (or type its exact name + Enter) to jump to it; "/" focuses
function Search() {
	const jump = e => {
		const input = e.target;
		const name = input.value.trim().replace(/\(\)$/, "");
		const target = document.getElementById(name) ?? document.getElementById(`type-${name}`);
		if (!target) return;
		history.replaceState(null, "", `#${target.id}`);
		go(target);
		input.value = "";
		input.blur();
	};
	const input = el("input", {
		type: "search", id: "search", list: "members", placeholder: "Search ( / )", "aria-label": "Jump to a function or type",
		onchange: jump, onkeydown: e => { if (e.key === "Enter") jump(e); },
	});
	document.addEventListener("keydown", e => {
		if (e.key !== "/" || e.target.matches("input, textarea")) return;
		e.preventDefault();
		input.focus();
	});
	const names = [...DATA.functions, ...DATA.types].map(m => m.name);
	return [input, el("datalist", { id: "members" }, names.map(value => el("option", { value })))];
}

export function Header() {
	const bar = el("header", { class: "top" },
		Brand(),
		el("span", { class: "version", id: "version" }, DATA.version ? `v${DATA.version}` : ""),
		el("nav", { class: "tabs-top", "aria-label": "Sections" }, TABS.map(([id, label]) =>
			el("a", { href: `#${id}`, "data-tab": id, "aria-current": () => (view() === id ? "page" : null) }, label))),
		el("span", { class: "spacer" }),
		Search(),
		el("button", { type: "button", id: "theme", "aria-label": "Toggle dark mode", onclick: toggleTheme }, "◐"),
		Repo());

	// --hdr = the bar's height, for everything that sits below it
	new ResizeObserver(() => document.documentElement.style.setProperty("--hdr", `${bar.offsetHeight}px`)).observe(bar);
	return bar;
}
