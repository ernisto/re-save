// A case's recorded result: what it returned or threw, then the state at each checkpoint.
import { el } from "./dom.js";
import { highlightInto, ValuePre } from "./highlight.js";
import { createSignal } from "./solid.js";

const Subhead = text => el("div", { class: "subhead" }, text);

// oplog entry "line 4: d.coins += 5" -> muted line ref + highlighted body
function OplogItem(text) {
	const m = text.match(/^(line \d+: )([\s\S]*)$/);
	if (!m) return el("li", {}, text);
	return highlightInto(el("li", {}, el("span", { class: "tok-com" }, m[1])), m[2]);
}

const KvTable = (rows, keyOf) => el("table", { class: "kv" }, el("tbody", {}, rows.map(row =>
	el("tr", {}, el("td", {}, keyOf(row)), el("td", {}, ValuePre(row.value))))));

// DataStore rows (and tx store rows when there are any)
function Stores(cloud, tx) {
	return el("div", { class: "stores" },
		cloud.length === 0 ? el("div", { class: "empty" }, "empty") : KvTable(cloud, row => `${row.store}/${row.key}`),
		tx.length > 0 ? [Subhead("Tx store"), KvTable(tx, row => row.key)] : null);
}

// the "DataStore before" / "DataStore after" panels under the card headers
export const StorePanel = (title, cloud, tx) => el("div", { class: "store-panel" }, Subhead(title), Stores(cloud, tx));

function Session(s) {
	const flags = [s.tracked ? "tracked" : "untracked", s.loaded ? null : "not loaded", s.frozen ? "frozen" : null]
		.filter(Boolean)
		.map(name => el("span", { class: "flag" + (name === "tracked" ? " on" : "") }, name));

	return el("div", { class: "sess" },
		el("div", { class: "head" }, `${s.store}/${s.key}`, flags),
		s.oplog.length > 0 ? [el("span", { class: "lbl" }, "oplog"), el("ol", { class: "oplog" }, s.oplog.map(OplogItem))] : null,
		s.base !== s.data ? [el("span", { class: "lbl" }, "base"), ValuePre(s.base)] : null,
		el("span", { class: "lbl" }, "data"), ValuePre(s.data));
}

// withStores: false for the last tab, whose DataStore is the "DataStore after" panel
function State(cp, withStores) {
	return el("div", { class: "state" },
		withStores ? [Subhead("DataStore"), Stores(cp.cloud, cp.tx)] : null,
		cp.sessions.length > 0 ? Subhead("Sessions") : null,
		cp.sessions.map(Session),
		cp.warnings.length > 0 ? [Subhead("Warnings"), el("div", { class: "warns" }, cp.warnings.map(w => el("pre", {}, w)))] : null);
}

function Returned(run) {
	if (run.thrown) return [Subhead("Throws"), el("div", { class: "thrown" }, el("pre", {}, run.thrown))];
	return [
		Subhead("Returns"),
		run.returned.length === 0 ? el("div", { class: "empty" }, "nothing") : null,
		run.returned.map((r, i) => el("div", { class: "ret" },
			el("span", { class: "idx" }, `#${i + 1}`),
			r.isstring ? el("pre", { class: "errtext" }, r.text) : ValuePre(r.text))),
	];
}

// drop checkpoints whose state equals the one after, so tabs only mark real changes
function changedCheckpoints(run) {
	const sameState = (a, b) => JSON.stringify([a.cloud, a.tx, a.sessions]) === JSON.stringify([b.cloud, b.tx, b.sessions]);
	return run.checkpoints.filter((cp, i, all) => {
		const next = all[i + 1];
		return !next || cp.warnings.length > 0 || !sameState(cp, next);
	});
}

// one tab per checkpoint, the last one open
function Checkpoints(cps) {
	if (cps.length === 1) return State(cps[0], false);

	const last = cps.length - 1;
	const [tab, setTab] = createSignal(last);
	return [
		el("div", { class: "tabs", role: "tablist" }, cps.map((cp, i) => el("button", {
			class: "tab", type: "button", role: "tab",
			"aria-selected": () => String(tab() === i),
			onclick: () => setTab(i),
		}, cp.label))),
		el("div", {}, () => State(cps[tab()], tab() !== last)),
	];
}

export function Result(run) {
	return el("div", { class: "body" },
		run.bugs.map(b => el("div", { class: "bugnote" }, el("strong", {}, "Known issue: "), b)),
		Returned(run),
		Checkpoints(changedCheckpoints(run)));
}
