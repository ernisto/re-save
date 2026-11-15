// The page: every view built once from the data, then routed by the address bar's #id.
import { applyTheme, Header } from "./header.js";
import { followLinks, fromHash, view } from "./nav.js";
import { Examples, Footer, Home } from "./pages.js";
import { Reference } from "./reference/view.js";
import { createRenderEffect, createRoot, flush } from "./solid.js";
import { Tooltip } from "./tooltip.js";
import { Tutorials } from "./tutorials/view.js";

createRoot(() => {
	applyTheme();
	const views = [Home(), Examples(), Tutorials(), Reference()];
	// only the routed view shows
	createRenderEffect(view, id => views.forEach(node => { node.hidden = node.id !== id; }));
	document.body.append(Header(), ...views, Footer(), Tooltip());
});
flush();

followLinks();
fromHash();
// the browser scrolls to the fragment itself after this runs; route once more after it
window.addEventListener("load", () => setTimeout(fromHash), { once: true });
