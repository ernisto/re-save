// A chapter's markdown into steps, a step's panel fences, phrases, and statement ranges.

// text before the first `## ` is the chapter's intro, each `## ` is a step
export function splitSteps(md) {
	const steps = [];
	let current = { title: null, lines: [] };
	for (const line of md.replace(/\r\n/g, "\n").split("\n")) {
		const h = line.match(/^##\s+(.*)$/);
		if (h) {
			steps.push(current);
			current = { title: h[1], lines: [] };
		} else current.lines.push(line);
	}
	steps.push(current);
	return steps.filter(s => s.title !== null || s.lines.join("").trim() !== "");
}

const DATASTORE = "DataStore";

// a step's panel fences come out of its text; each is one frame of the panel its caption
// names, shown once the phrase before it lights (before any phrase: as the title pins;
// @k: at phrase k). An empty frame takes the panel away. Kinds:
//   ```luau <caption>    a script; code on another server is its own script
//   ```output <caption>  what a script printed or threw: plain text under the scripts,
//                        gone at the next title
//   ```state <caption>   state beside the scripts (a server's memory, a session, the tx
//                        store); ```cloud is the "DataStore" state
// every panel is diffed and lit the same way
const FENCE_KINDS = { luau: "script", output: "out", state: "ds", cloud: "ds" };
export function splitFences(text) {
	const fences = [];
	const rest = text.replace(/^```(luau|output|state|cloud)[ \t]*(.*)\n([\s\S]*?)\n?```$/gm, (_, lang, info, code, at) => {
		const [, caption, tag] = info.match(/^(.*?)\s*(?:@(\d+))?$/);
		const before = text.slice(0, at).match(/\]\((?:code|mark):/g) ?? [];
		fences.push({ caption: caption || (lang === "cloud" ? DATASTORE : ""), kind: FENCE_KINDS[lang], tag: tag ? Number(tag) : before.length, code });
		return "";
	});
	return { text: rest, fences };
}

// [phrase](code:a|b) lights statements; [phrase](mark:context»columns -> value) boxes the
// columns right after `context` and shows `value` over them
export function parseBeat(target) {
	const kind = target.slice(0, 4);
	const rest = target.slice(5);
	if (kind === "code") return { kind, needles: rest.split("|") };
	const [spec, value] = rest.split(" -> ");
	const [context, columns] = spec.includes("»") ? spec.split("»") : ["", spec];
	return { kind, context, columns, value, needles: [context + columns] };
}

// empty code lines hold a zero-width space (see CodeLine)
const isBlank = text => /^[\s​]*$/.test(text);

// last line of the statement starting at `start`: deeper-indented lines after it (blank
// lines inside are fine), then a closing `end` / `}` / `)` at its own indent
function statementEnd(texts, start) {
	const indent = t => t.match(/^\s*/)[0].length;
	const base = indent(texts[start]);
	let end = start;
	for (let j = start + 1; j < texts.length; j++) {
		if (isBlank(texts[j])) continue;
		if (indent(texts[j]) > base) { end = j; continue; }
		if (end > start && /^\s*(end|\}|\))/.test(texts[j])) end = j;
		break;
	}
	return end;
}

// [first, last] line of the statement holding `needle`, or null
function textStatement(texts, needle) {
	const start = texts.findIndex(t => t.includes(needle));
	return start === -1 ? null : [start, statementEnd(texts, start)];
}

// [first, last] of each top-level statement: a line at indent 0 plus the deeper lines and
// the closing `end` / `})` after it; blank lines separate them
export function statementRanges(texts) {
	const out = [];
	let i = 0;
	while (i < texts.length) {
		if (isBlank(texts[i])) { i++; continue; }
		const end = statementEnd(texts, i);
		out.push([i, end]);
		i = end + 1;
	}
	return out;
}

export const topStatements = lines => statementRanges(lines.map(l => l.textContent)).map(([a, z]) => lines.slice(a, z + 1));

// the code lines of the statement holding `needle`, in the first panel that has one
export function statementLines(group, needle) {
	for (const pre of group.querySelectorAll("pre")) {
		const lines = [...pre.querySelectorAll(".ln:not(.del):not(.fold-mark)")];
		const range = textStatement(lines.map(l => l.textContent), needle);
		if (range) return lines.slice(range[0], range[1] + 1);
	}
	console.warn(`tutorial beat: no code line holds "${needle}"`);
	return [];
}

// top of every visual line in `root`'s text (relative to its scrolled content), merged
// when they're within half a line (inline code on the same line, table cells in a row)
export function textLines(root) {
	const base = root.getBoundingClientRect().top - root.scrollTop;
	const tops = [];
	const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
	for (let node = walker.nextNode(); node; node = walker.nextNode()) {
		if (!node.textContent.trim()) continue;
		const range = document.createRange();
		range.selectNodeContents(node);
		for (const rect of range.getClientRects()) if (rect.height > 0) tops.push(rect.top - base);
	}
	tops.sort((a, b) => a - b);
	const lines = [];
	for (const top of tops) if (lines.length === 0 || top - lines[lines.length - 1] > 12) lines.push(top);
	return lines.length > 0 ? lines : [0];
}
