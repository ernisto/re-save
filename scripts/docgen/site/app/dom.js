// el(tag, attrs, ...children): a DOM node. An attribute or child given as a function is
// live: it is redrawn whenever a signal it reads changes. `on*` attributes are listeners,
// `ref` gets the node once it is made.
import { createRenderEffect } from "./solid.js";

const SVG_NS = "http://www.w3.org/2000/svg";
// set as properties: the attribute only holds the starting value
const PROPS = new Set(["checked", "disabled", "hidden", "value"]);

function setAttr(node, key, value) {
	if (PROPS.has(key)) node[key] = value ?? false;
	else if (value === undefined || value === null || value === false) node.removeAttribute(key);
	else node.setAttribute(key, value === true ? "" : value);
}

function bind(node, attrs) {
	for (const [key, value] of Object.entries(attrs || {})) {
		if (key === "ref") value(node);
		else if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
		else if (typeof value === "function") createRenderEffect(value, v => setAttr(node, key, v));
		else setAttr(node, key, value);
	}
}

function append(parent, child) {
	if (child === null || child === undefined || child === false) return;
	if (Array.isArray(child)) child.forEach(c => append(parent, c));
	else if (typeof child === "function") parent.append(region(child));
	else parent.append(child instanceof Node ? child : document.createTextNode(String(child)));
}

// a live part of the DOM: what `fn` returns, swapped whenever a signal it reads changes.
// Everything made while `fn` runs is disposed when it runs again
export function region(fn) {
	const start = document.createComment("");
	const holder = document.createDocumentFragment();
	holder.append(start);
	let shown = [];

	createRenderEffect(() => {
		const box = document.createDocumentFragment();
		append(box, fn());
		return [...box.childNodes];
	}, nodes => {
		shown.forEach(n => n.remove());
		start.after(...nodes);
		shown = nodes;
	});
	return holder;
}

export function el(tag, attrs, ...children) {
	const node = document.createElement(tag);
	bind(node, attrs);
	append(node, children);
	return node;
}

export function svg(tag, attrs, ...children) {
	const node = document.createElementNS(SVG_NS, tag);
	bind(node, attrs);
	append(node, children);
	return node;
}

// own glyphs: function = braces around a dot, type = stacked bars
const ICON_PATHS = {
	fn: ["M7 3.5C4.8 3.5 4.5 5 4.5 7v1.2c0 1-.6 1.8-1.5 1.8.9 0 1.5.8 1.5 1.8V13c0 2 .3 3.5 2.5 3.5", "M13 3.5c2.2 0 2.5 1.5 2.5 3.5v1.2c0 1 .6 1.8 1.5 1.8-.9 0-1.5.8-1.5 1.8V13c0 2-.3 3.5-2.5 3.5"],
	ty: ["M4 5h12", "M4 10h8", "M4 15h12"],
};

export function Icon(kind) {
	const stroke = { fill: "none", stroke: "currentColor", "stroke-width": "2", "stroke-linecap": "round" };
	return svg("svg", { viewBox: "0 0 20 20", class: `icon ${kind}`, "aria-hidden": "true" },
		ICON_PATHS[kind].map(d => svg("path", { d, ...stroke })),
		kind === "fn" ? svg("circle", { cx: "10", cy: "10", r: "2", fill: "currentColor" }) : null);
}
