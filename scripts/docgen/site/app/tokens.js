// Type tokens (from @std/syntax, built by scripts/docgen/reflect) and signatures.
import { GENERIC_DOCS } from "./data.js";
import { el } from "./dom.js";

export function Tokens(tokens) {
	const frag = document.createDocumentFragment();
	for (const tok of tokens) {
		if (tok.k === "space") { frag.append(tok.t); continue; }
		const cls = `t-${tok.k}`;
		frag.append(tok.href ? el("a", { class: cls, href: tok.href }, tok.t) : el("span", { class: cls }, tok.t));
	}
	return frag;
}

export const punct = text => el("span", { class: "t-punct" }, text);

// items joined by ", ", between `open` and `close`
const listed = (open, items, close) => [punct(open), items.map((item, i) => [i > 0 ? punct(", ") : null, item]), punct(close)];

// `<T, U>`, each generic linking to the type-checking docs
export const Generics = names => names.length === 0 ? null
	: listed("<", names.map(g => el("a", { class: "t-generic", href: GENERIC_DOCS }, g)), ">");

function returnsOf(fn) {
	if (fn.returns.length === 0) return punct(" : ( )");
	if (fn.returns.length === 1) return [punct(" : "), Tokens(fn.returns[0].type)];
	return listed(" : ( ", fn.returns.map(r => Tokens(r.type)), " )");
}

export function Signature(fn) {
	return el("span", { class: "sig-line" },
		el("span", { class: "t-prefix" }, "resave."),
		el("span", { class: "t-fn" }, fn.name),
		Generics(fn.generics),
		listed(" ( ", fn.params.map(p => [el("span", { class: "t-param" }, p.name), punct(" : "), Tokens(p.type)]), " )"),
		returnsOf(fn));
}
