// The condition tree: one checkbox per condition. Children only unlock once their parent
// is ticked, round siblings (same `group`) exclude each other, `conflicts` can't combine.
import { el } from "../dom.js";
import { flush } from "../solid.js";
import { idsOf, keyOf } from "./order.js";

// key(): the shown case; setKey(key) shows another
export function Tree(fn, index, key, setKey) {
	const descendants = id => {
		const out = [];
		const walk = nodes => nodes.forEach(n => { out.push(n.id); walk(n.children); });
		walk(index.get(id).node.children);
		return out;
	};

	const blockedBy = (checked, id) => {
		for (const other of index.get(id).node.conflicts || []) if (checked.has(other)) return other;
		for (const [otherId, entry] of index) {
			if (checked.has(otherId) && (entry.node.conflicts || []).includes(id)) return otherId;
		}
		return null;
	};

	const toggle = (id, on) => {
		const checked = new Set(idsOf(key()));
		const uncheck = gone => [gone, ...descendants(gone)].forEach(d => checked.delete(d));
		if (!on) uncheck(id);
		else {
			const { node, siblings } = index.get(id);
			if (node.group) siblings.filter(sib => sib.id !== id && sib.group === node.group).forEach(sib => uncheck(sib.id));
			checked.add(id);
		}
		setKey(keyOf(checked));
		flush();
		document.getElementById(`c-${fn.name}-${id}`)?.focus();
	};

	const TreeNode = (checked, node, enabled) => {
		const blocker = blockedBy(checked, node.id);
		const usable = enabled && !blocker;
		const inputId = `c-${fn.name}-${node.id}`;
		const input = el("input", {
			type: "checkbox", id: inputId,
			class: node.group ? "one" : null,
			title: node.group ? "Pick at most one of the round options" : null,
			checked: checked.has(node.id), disabled: !usable,
			onchange: e => toggle(node.id, e.target.checked),
		});
		const why = enabled && blocker ? el("span", { class: "why" }, `can't combine with "${index.get(blocker).node.label}"`) : null;
		return el("li", { class: usable ? "" : "off" },
			el("label", { for: inputId }, input, el("span", {}, node.label, why)),
			node.children.length > 0 ? Nodes(checked, node.children, usable && checked.has(node.id)) : null);
	};

	// round siblings sit together in one group box, where the first of them stands
	const Nodes = (checked, nodes, enabled) => {
		const list = el("ul", { class: "tree" });
		const groups = new Map();
		for (const node of nodes) {
			const item = TreeNode(checked, node, enabled);
			if (!node.group) { list.append(item); continue; }
			if (!groups.has(node.group)) {
				const inner = el("ul", { class: "tree" });
				groups.set(node.group, inner);
				list.append(el("li", {}, el("div", { class: "group" }, inner)));
			}
			groups.get(node.group).append(item);
		}
		return list;
	};

	return el("div", {}, () => fn.tree.length === 0
		? el("div", { class: "tree-empty" }, "This function has one case.")
		: Nodes(new Set(idsOf(key())), fn.tree, true));
}
