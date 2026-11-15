// The code panels' zoom (--zoom on the group): measured over every state a walk can show.

// the largest size the panels take over every state, at a zoom (draw(k) puts state k in them)
export function measureCode(group, states, draw, zoom) {
	group.classList.add("measuring"); // content-sized
	group.style.setProperty("--zoom", zoom);
	let width = 0;
	let height = 0;
	for (const k of states) {
		draw(k);
		width = Math.max(width, group.offsetWidth);
		height = Math.max(height, group.offsetHeight);
	}
	group.classList.remove("measuring");
	return { width, height };
}

// the zoom at which every state fits the space
export function fitCode(group, availHeight, states, draw) {
	const availWidth = group.clientWidth;
	if (availWidth === 0) return; // hidden page: measured when shown

	let zoom = 1;
	for (let pass = 0; pass < 2; pass++) {
		const { width, height } = measureCode(group, states, draw, zoom);
		// never below readable: past that the panel scrolls to the lit lines instead; and only a
		// little above natural size, so short code leaves room instead of filling the window
		zoom = Math.min(1.2, Math.max(0.8, zoom * Math.min(availHeight / height, availWidth / Math.max(1, width))));
	}
	group.style.setProperty("--zoom", zoom.toFixed(3));
}
