// One section per function (signature, parameters, returns, prose, Try it) and per type.
import { el, Icon } from "../dom.js";
import { inline, Markdown, splitSummary } from "../markdown.js";
import { Anchored } from "../nav.js";
import { Generics, punct, Signature, Tokens } from "../tokens.js";
import { TryIt } from "../tryit/lab.js";

const Box = (items, none) => el("div", { class: "box" }, items.length === 0 ? el("div", { class: "none" }, none) : items);

const Item = (decl, desc) => el("div", { class: "item" }, el("div", { class: "decl" }, decl), el("p", { class: "desc" }, inline(desc)));

// the try-it columns pin just below the pinned signature, whose height varies with wrapping
const pinWatch = new ResizeObserver(entries => entries.forEach(e => {
	e.target.parentElement.style.setProperty("--pin", `${e.target.offsetHeight}px`);
}));

export function FunctionMember(fn) {
	const [summary, rest] = splitSummary(fn.md);
	const title = el("div", { class: "member-title pinned" }, Icon("fn"), Anchored(el("h3", { class: "sig-title" }, Signature(fn)), fn.name));
	pinWatch.observe(title);

	return el("section", { class: "member", id: fn.name },
		title,
		el("div", { class: "chips" },
			fn.yields ? el("span", { class: "chip", title: "Pauses the calling thread until it finishes" }, "Yields") : null,
			el("span", { class: "chip src" }, fn.source)),
		el("p", { class: "summary" }, inline(summary)),
		el("h4", { class: "label" }, "Parameters"),
		Box(fn.params.map(p => Item([el("span", { class: "t-param" }, p.name), punct(" : "), Tokens(p.type)], p.desc)), "None"),
		el("h4", { class: "label" }, "Returns"),
		Box(fn.returns.map(r => Item(Tokens(r.type), r.desc)), "Nothing"),
		rest.trim() ? Markdown(rest) : null,
		el("details", { class: "tryit" }, el("summary", {}, el("h4", { class: "label" }, "Try it")), TryIt(fn)));
}

export function TypeMember(t) {
	const id = `type-${t.name}`;
	return el("section", { class: "member", id },
		el("div", { class: "member-title" }, Icon("ty"), Anchored(el("h3", {}, t.name), id)),
		el("div", { class: "chips" }, el("span", { class: "chip src" }, t.source)),
		el("div", { class: "sig" },
			el("span", { class: "t-generic" }, "type "),
			el("span", { class: "t-type" }, t.name),
			Generics(t.generics),
			punct(" = "),
			Tokens(t.body)));
}
