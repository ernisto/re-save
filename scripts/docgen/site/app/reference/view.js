// The API reference: overview cards, every function and type, and the rail that marks
// the section being read.
import { DATA } from "../data.js";
import { el, Icon } from "../dom.js";
import { Part, revealAnchor } from "../nav.js";
import { createSignal } from "../solid.js";
import { CASE_VIEWS } from "../tryit/lab.js";
import { FunctionMember, TypeMember } from "./members.js";

const HELPERS = [
	["cloud(store)", "the raw mock DataStore table, to seed or read stored records"],
	["txcloud", "the raw tx store table"],
	["fail(store, \"get\" | \"update\" | \"remove\")", ["that DataStore call fails before doing anything; pass ", el("code", {}, "\"tx\""), " for the tx store"]],
	["failwrite(store, n?)", ["the nth ", el("code", {}, "UpdateAsync"), " from now runs the callback, then fails to write"]],
	["settle()", "waits so background work (tx resolution, the save loop) can finish"],
	["checkpoint(label)", "records the state at that point as an extra result tab"],
];

// functions grouped by their docs/api front matter `group`, in first-seen order, then the types
function sectionsOf() {
	const groups = new Map();
	for (const fn of DATA.functions) {
		if (!groups.has(fn.group)) groups.set(fn.group, []);
		groups.get(fn.group).push({ kind: "fn", id: fn.name, name: fn.name, rail: `${fn.name}()`, fn });
	}
	groups.set("Types", DATA.types.map(t => ({ kind: "ty", id: `type-${t.name}`, name: t.name, rail: t.name })));
	return groups;
}

// scroll-spy: the section being read is the last one whose top passed 30% of the window
function spy(setActive, rail) {
	const mark = () => {
		const line = window.innerHeight * 0.3;
		let current = null;
		for (const section of document.querySelectorAll("#reference section.member")) {
			if (section.getBoundingClientRect().top > line) break;
			current = section;
		}
		setActive(current?.id ?? null);

		// keep its entry visible inside the rail
		const entry = current && rail.querySelector(`a[data-target="${CSS.escape(current.id)}"]`);
		if (!entry) return;
		const railBox = rail.getBoundingClientRect();
		const box = entry.getBoundingClientRect();
		if (box.top < railBox.top) rail.scrollTop -= railBox.top - box.top + 8;
		else if (box.bottom > railBox.bottom) rail.scrollTop += box.bottom - railBox.bottom + 8;
	};
	let queued = false;
	window.addEventListener("scroll", () => {
		if (queued) return;
		queued = true;
		requestAnimationFrame(() => { queued = false; mark(); });
	}, { passive: true });
	window.addEventListener("resize", mark);
	requestAnimationFrame(mark);
}

// [text](case:ids) in a description: show that case in the same function's Try it
function followCaseLinks() {
	document.addEventListener("click", e => {
		const link = e.target.closest("a.caselink");
		if (!link) return;
		e.preventDefault();

		const member = link.closest("section.member");
		const caseView = member && CASE_VIEWS.get(member.id);
		if (!caseView || !caseView.show(link.dataset.case)) return;

		const lab = member.querySelector(".lab");
		lab.closest("details").open = true;
		revealAnchor(lab);
		lab.classList.remove("flash");
		void lab.offsetWidth;
		lab.classList.add("flash");
	});
}

export function Reference() {
	const groups = sectionsOf();
	const [active, setActive] = createSignal(null);
	const Entry = (entry, label) => el("a", {
		href: `#${entry.id}`, "data-target": entry.id,
		class: () => (active() === entry.id ? "active" : null),
	}, Icon(entry.kind), label);

	const rail = el("aside", { class: "rail", id: "rail", "aria-label": "On this page" },
		[...groups].map(([group, entries]) => [el("div", { class: "heading" }, group), entries.map(e => Entry(e, e.rail))]));
	spy(setActive, rail);
	followCaseLinks();

	return el("div", { class: "shell", id: "reference", "data-view": "" },
		el("main", { id: "main" },
			el("h1", { class: "page-title" }, "re-save"),
			el("p", { class: "lede" }, "Session-based DataStore saving with an oplog, schema migrations and multi-key transactions. New here? ", el("a", { href: "#tutorials" }, "Start with the tutorials.")),
			el("p", { class: "lede" }, "Each function ends in its cases: tick what applies, or step through them with Next: intro cases first, then limitations (failures and known issues), then more cases. The code for that exact case shows up, with its result."),
			Part("Overview"),
			el("div", { class: "cards", id: "cards" }, [...groups].map(([group, entries]) =>
				el("div", { class: "card" }, el("div", { class: "heading" }, group), entries.map(e => Entry(e, e.name))))),
			Part("Functions"),
			el("div", { id: "functions" }, [...groups.values()].flat().filter(e => e.fn).map(e => FunctionMember(e.fn))),
			Part("Types"),
			el("div", { id: "types" }, DATA.types.map(TypeMember)),
			Part("Snippet helpers"),
			el("p", { class: "lede" }, "Test-only helpers the snippets use on top of the real API."),
			el("div", { class: "helpers" }, HELPERS.map(([code, text]) => [el("code", {}, code), el("span", {}, text)]))),
		rail);
}
