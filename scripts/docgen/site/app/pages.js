// The plain pages: home, examples, and the footer under every view.
import { DATA, REPO } from "./data.js";
import { el } from "./dom.js";
import { highlightInto } from "./highlight.js";
import { Markdown } from "./markdown.js";
import { Anchored, Part } from "./nav.js";

const code = text => el("code", {}, text);

const FEATURES = [
	["No session locks", ["A key can be open on more than one server. Each session keeps its changes in an oplog and replays them on the newest saved data, so no change is lost."]],
	["Change now, save later", [code("queueupdate"), " changes ", code("session.data"), " at once. The oplog is saved in the background, on ", code("free"), " and on shutdown."]],
	["Versioned schemas", ["Migrations upgrade old saves when they load, and are test-run on the default when the schema is built, so a broken one fails at startup."]],
	["Transactions", [code("savebatch"), " changes several keys at once, or none of them: made for trades and gifts."]],
];

export function Home() {
	const install = `[server-dependencies]\nresave = "${REPO}@${DATA.version}"`;
	return el("div", { class: "home", id: "home", "data-view": "" },
		el("h1", { class: "page-title" }, "re-save"),
		el("p", { class: "lede" }, "Session-based DataStore saving for Roblox, with an oplog, schema migrations and multi-key transactions."),
		el("div", { class: "cta" },
			el("a", { class: "primary", href: "#tutorials" }, "Start the tutorial"),
			el("a", { href: "#examples" }, "Examples"),
			el("a", { href: "#reference" }, "API Reference")),
		el("div", { class: "features" }, FEATURES.map(([title, text]) => el("div", {}, el("h3", {}, title), el("p", {}, text)))),
		Part("Install"),
		el("p", { class: "lede" }, "Add it to ", code("wally.toml"), ", then run ", code("wally install"), ". ", el("a", { href: "#tutorial-installing" }, "More ways to install.")),
		highlightInto(el("pre", { class: "code", id: "install" }), install));
}

// one page, one section per docs/examples file
export function Examples() {
	const idOf = ex => `example-${ex.slug}`;
	return el("div", { class: "shell", id: "examples", "data-view": "" },
		el("main", { id: "examples-main" },
			el("h1", { class: "page-title" }, "Examples"),
			el("p", { class: "lede" }, "Complete scripts for common jobs. The tutorials explain why each part is there."),
			DATA.examples.map(ex => el("section", { class: "example", id: idOf(ex) },
				Anchored(el("h2", { class: "part" }, ex.title), idOf(ex)),
				Markdown(ex.md)))),
		el("aside", { class: "rail", id: "examples-rail", "aria-label": "Examples" },
			el("div", { class: "heading" }, "Examples"),
			DATA.examples.map(ex => el("a", { href: `#${idOf(ex)}` }, ex.title))));
}

export function Footer() {
	const link = (href, text) => el("a", { href }, text);
	return el("footer", { class: "foot" },
		el("span", {}, "re-save © 2026 ernisto, released under the ", link(`https://github.com/${REPO}/blob/main/LICENSE`, "MIT License"), "."),
		el("span", {}, "Rewritten from ", link("https://github.com/jackhexed/drop", "drop"), " by ", link("https://github.com/jackhexed", "jackhexed"), ", also MIT."),
		el("span", { class: "foot-links" },
			link(`https://github.com/${REPO}`, "GitHub"), " · ",
			link(`https://github.com/${REPO}/issues`, "Issues"), " · ",
			link(`https://github.com/${REPO}/releases/latest`, "Releases")));
}
