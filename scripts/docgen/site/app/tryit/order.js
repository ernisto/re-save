// The order Next / Prev walk a function's cases in, and what the counter says.

export const idsOf = key => (key === "" ? [] : key.split(","));
export const keyOf = ids => [...ids].sort().join(",");

// [id] = { node, parent, siblings }
export function indexTree(nodes, parent = null, out = new Map()) {
	for (const node of nodes) {
		out.set(node.id, { node, parent, siblings: nodes });
		indexTree(node.children, node.id, out);
	}
	return out;
}

// cases at most two boxes apart are "close": switching between them animates the code diff
export function isClose(a, b) {
	const x = new Set(idsOf(a));
	const y = new Set(idsOf(b));
	let differ = 0;
	for (const id of x) if (!y.has(id)) differ++;
	for (const id of y) if (!x.has(id)) differ++;
	return differ <= 2;
}

// queue groups, decided by the build (markgroups):
//   intro       must-know: succeeds, at most one top-level condition (children only refine it)
//   limitation  known issues (their smallest case), and at most one top-level condition
//               that throws, returns an error or warns
//   more        everything else: conditions together, or ones that make no difference
const GROUPS = { intro: { at: 0, name: "Intro" }, limitation: { at: 1, name: "Limitation" }, more: { at: 2, name: "More" } };

// walk order follows the tree shape: each case = its checked boxes' positions in the tree
// (top to bottom), compared like words, so a case is followed by the cases that only add
// boxes below its last one (depth first); a misuse's suggested fix comes right after it
export function caseOrder(fn, index) {
	const position = new Map([...index.keys()].map((id, i) => [id, i]));
	const shapeOf = key => idsOf(key).map(id => position.get(id)).sort((a, b) => a - b);
	const groupOf = key => GROUPS[fn.runs[key].group];

	const sorted = Object.keys(fn.runs).sort((a, b) => {
		if (groupOf(a) !== groupOf(b)) return groupOf(a).at - groupOf(b).at;
		const sa = shapeOf(a);
		const sb = shapeOf(b);
		for (let i = 0; i < Math.min(sa.length, sb.length); i++) if (sa[i] !== sb[i]) return sa[i] - sb[i];
		return sa.length - sb.length;
	});

	const fixOf = key => fn.runs[key].limit && fn.runs[key].limit.fix;
	const isFix = new Set(sorted.map(fixOf).filter(k => k !== undefined));
	const order = [];
	for (const key of sorted) {
		if (isFix.has(key)) continue;
		order.push(key);
		const fix = fixOf(key);
		if (fix !== undefined) order.push(fix);
	}

	const counterText = key => {
		const group = groupOf(key);
		const members = order.filter(k => groupOf(k) === group);
		return `${group.name} ${members.indexOf(key) + 1} of ${members.length}`;
	};
	return { order, counterText };
}
