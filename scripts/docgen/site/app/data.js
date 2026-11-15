// The page data the docs build writes (scripts/docgen/build.luau), and lookups over it.
export const DATA = JSON.parse(document.getElementById("data").textContent);

export const FUNCTIONS = new Map(DATA.functions.map(f => [f.name, f]));
export const TYPES = new Map(DATA.types.map(t => [t.name, t]));

export const REPO = "ernisto/re-save";
export const GENERIC_DOCS = "https://create.roblox.com/docs/luau/type-checking";
export const OUTCOMES = { ok: "Success", err: "Returns error", throws: "Throws", warn: "Warns" };

// badge for each kind of limitation case (kind is picked per case in tests/lute/limitations)
export const LIMIT_KINDS = {
	known: { label: "Known issue", cls: "issue" },
	misuse: { label: "Misuse", cls: "misuse" },
	limit: { label: "Limitation", cls: "limit" },
	fix: { label: "Suggested fix", cls: "fix" },
};

export const REDUCED_MOTION = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;

// the top bar stays on screen: the view is the window below it
export const topH = () => document.querySelector("header.top").offsetHeight;
export const viewH = () => window.innerHeight - topH();
