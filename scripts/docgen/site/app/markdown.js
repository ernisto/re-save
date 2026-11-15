// Markdown: headings, paragraphs, lists, tables, fences; inline code, bold, em, links.
import { el } from "./dom.js";
import { highlight, InlineCode } from "./highlight.js";

export function inline(text) {
	const frag = document.createDocumentFragment();
	const re = /`([^`]+)`|\*\*([^*]+)\*\*|\*([^*]+)\*|\[((?:`[^`]*`|[^\]])+)\]\(((?:code|mark):(?:[^()]|\([^()]*\))+|[^)\s]+)\)/g;
	let last = 0;
	let m;
	while ((m = re.exec(text))) {
		if (m.index > last) frag.append(text.slice(last, m.index));
		if (m[1] !== undefined) frag.append(InlineCode(m[1]));
		else if (m[2] !== undefined) frag.append(el("strong", {}, inline(m[2])));
		else if (m[3] !== undefined) frag.append(el("em", {}, inline(m[3])));
		else if (/^(code|mark):/.test(m[5])) frag.append(el("span", { class: "beatref", "data-beat": m[5] }, inline(m[4])));
		else if (m[5].startsWith("case:")) frag.append(el("a", { class: "caselink", href: "#", "data-case": m[5].slice(5), title: "Show this case" }, inline(m[4])));
		else frag.append(el("a", { href: m[5] }, inline(m[4])));
		last = re.lastIndex;
	}
	if (last < text.length) frag.append(text.slice(last));
	return frag;
}

function splitRow(line) {
	return line.replace(/^\s*\|/, "").replace(/\|\s*$/, "").split(/(?<!\\)\|/).map(c => c.trim().replace(/\\\|/g, "|"));
}

const BULLET = /^\s*(?:[-*]|\d+\.)\s+/;

// one block starting at lines[i]: [node, next i]
function block(lines, i) {
	const line = lines[i];

	const heading = line.match(/^(#{1,3})\s+(.*)$/);
	if (heading) return [el(heading[1].length <= 2 ? "h2" : "h3", {}, inline(heading[2])), i + 1];

	if (line.startsWith("```")) {
		const lang = line.slice(3).trim();
		const body = [];
		i++;
		while (i < lines.length && !lines[i].startsWith("```")) body.push(lines[i++]);
		const code = body.join("\n");
		return [lang === "text" ? el("pre", { class: "output" }, code) : highlight(code), i + 1];
	}

	if (line.trim().startsWith("|") && lines[i + 1] && /^\s*\|[\s:|-]+\|\s*$/.test(lines[i + 1])) {
		const head = splitRow(line);
		const rows = [];
		i += 2;
		while (i < lines.length && lines[i].trim().startsWith("|")) rows.push(splitRow(lines[i++]));
		return [el("table", {},
			el("thead", {}, el("tr", {}, head.map(h => el("th", {}, inline(h))))),
			el("tbody", {}, rows.map(r => el("tr", {}, r.map(c => el("td", {}, inline(c))))))), i];
	}

	if (BULLET.test(line)) {
		const ordered = /^\s*\d+\./.test(line);
		const items = [];
		while (i < lines.length && BULLET.test(lines[i])) {
			let item = lines[i++].replace(BULLET, "");
			while (i < lines.length && /^\s{2,}\S/.test(lines[i]) && !BULLET.test(lines[i])) item += " " + lines[i++].trim();
			items.push(el("li", {}, inline(item)));
		}
		return [el(ordered ? "ol" : "ul", ordered ? { start: line.match(/\d+/)[0] } : {}, items), i];
	}

	const para = [];
	while (i < lines.length && lines[i].trim() !== "" && !/^(#{1,3}\s|```|\s*[-*]\s|\s*\d+\.\s|\s*\|)/.test(lines[i])) para.push(lines[i++].trim());
	return [el("p", {}, inline(para.join(" "))), i];
}

export function Markdown(source) {
	const out = el("div", { class: "prose" });
	const lines = source.replace(/\r\n/g, "\n").split("\n");
	let i = 0;
	while (i < lines.length) {
		if (lines[i].trim() === "") { i++; continue; }
		const [node, next] = block(lines, i);
		out.append(node);
		i = next;
	}
	return out;
}

// first paragraph = summary, the rest = body
export function splitSummary(md) {
	const trimmed = md.trim();
	const cut = trimmed.search(/\n\s*\n/);
	return cut === -1 ? [trimmed, ""] : [trimmed.slice(0, cut), trimmed.slice(cut)];
}
