// Code panels: lines with recorded values, and a change from one code to the next where
// added lines slide in and removed lines collapse out.
import { REDUCED_MOTION } from "./data.js";
import { el } from "./dom.js";
import { highlightInto } from "./highlight.js";
import { createSignal } from "./solid.js";

// line diff: longest common subsequence, then walk it into keep/add/del steps
export function diffLines(before, after) {
	const n = before.length;
	const m = after.length;
	const lcs = Array.from({ length: n + 1 }, () => new Uint16Array(m + 1));
	for (let i = n - 1; i >= 0; i--) {
		for (let j = m - 1; j >= 0; j--) {
			lcs[i][j] = before[i] === after[j] ? lcs[i + 1][j + 1] + 1 : Math.max(lcs[i + 1][j], lcs[i][j + 1]);
		}
	}

	const steps = [];
	let i = 0;
	let j = 0;
	while (i < n || j < m) {
		if (i < n && j < m && before[i] === after[j]) {
			steps.push({ op: "keep", text: after[j] });
			i++;
			j++;
		} else if (j < m && (i >= n || lcs[i][j + 1] >= lcs[i + 1][j])) {
			steps.push({ op: "add", text: after[j++] });
		} else {
			steps.push({ op: "del", text: before[i++] });
		}
	}
	return steps;
}

// an empty line holds a zero-width space, so it keeps its height
function CodeLine(text, state, lookup, plain = false) {
	const line = el("div", { class: state ? `ln ${state}` : "ln" });
	if (text === "") line.append("​");
	else if (plain) line.append(text);
	else highlightInto(line, text, { lookup });
	return line;
}

// vars recorded by the build: [{ name, from, to, declares, value }], one per change,
// taken after each top-level statement (lines from..to). On the line that declares
// a name, show the value it got; anywhere else, the value before that line ran.
function valueLookup(vars, line) {
	return name => {
		let found;
		for (const v of vars) {
			if (v.name !== name) continue;
			if (v.declares && v.from <= line && line <= v.to) return v.value;
			if (v.to < line) found = v.value;
		}
		return found;
	};
}

// renders `after` into host; when `before` is given, the change between them animates
export function renderCodeChange(host, before, after, vars = []) {
	const pre = el("pre", { class: "code lines" });
	const afterLines = after.split("\n");
	const plain = host.dataset.plain === "1"; // output panels: text, not Luau

	if (before === null || before === after || REDUCED_MOTION) {
		afterLines.forEach((text, i) => pre.append(CodeLine(text, null, valueLookup(vars, i + 1), plain)));
		host.replaceChildren(pre);
		return;
	}

	const steps = diffLines(before.split("\n"), afterLines);
	const removes = steps.some(step => step.op === "del");
	let lineNo = 0;

	for (const step of steps) {
		if (step.op === "keep") {
			pre.append(CodeLine(step.text, null, valueLookup(vars, ++lineNo), plain));
		} else if (step.op === "add") {
			pre.append(CodeLine(step.text, removes ? "add after-del" : "add", valueLookup(vars, ++lineNo), plain));
		} else {
			const gone = CodeLine(step.text, "del", null, plain);
			gone.setAttribute("aria-hidden", "true");
			gone.addEventListener("animationend", e => {
				if (e.animationName === "line-collapse") gone.remove();
			});
			pre.append(gone);
		}
	}
	host.replaceChildren(pre);
}

export function CopyButton(getText) {
	const [label, setLabel] = createSignal("Copy");
	const copy = async () => {
		try {
			await navigator.clipboard.writeText(getText());
			setLabel("Copied");
		} catch {
			setLabel("Copy blocked");
		}
		setTimeout(() => setLabel("Copy"), 1500);
	};
	return el("button", { class: "btn", type: "button", onclick: copy }, label);
}
