// One Luau highlighter for snippets, inline code and recorded values.
import { DATA, FUNCTIONS, TYPES } from "./data.js";
import { el } from "./dom.js";

const KEYWORDS = new Set("local function end if then else elseif return for in do while repeat until not and or nil true false break continue".split(" "));

// Luau and Roblox globals; a field or method of one (table.insert, game:GetService) is builtin too
const BUILTINS = new Set(("game workspace script plugin shared task table string math os coroutine utf8 bit32 buffer debug vector " +
	"print warn error assert pcall xpcall type typeof tostring tonumber pairs ipairs next select require unpack " +
	"setmetatable getmetatable rawget rawset rawequal rawlen newproxy gcinfo tick time wait spawn delay elapsedTime " +
	"Enum Instance Vector2 Vector3 CFrame Color3 UDim UDim2 Ray Region3 TweenInfo BrickColor NumberRange NumberSequence ColorSequence DateTime Random").split(" "));

function linkWord(word) {
	if (FUNCTIONS.has(word)) return { href: `#${word}`, cls: "t-fn" };
	if (TYPES.has(word)) return { href: `#type-${word}`, cls: "t-type" };
	if (DATA.links[word]) return { href: DATA.links[word], cls: "t-type" };
	return null;
}

// links: also link known function, type and builtin names (prose only)
// lookup(name): recorded value of a snippet variable at this line, or undefined
export function highlightInto(target, code, { links = false, lookup = null } = {}) {
	const re = /(--[^\n]*)|("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)|(\b\d+(?:\.\d+)?\b)|([A-Za-z_][A-Za-z0-9_]*)|([\s\S])/g;
	let m;
	let prev = "";
	let prevBuiltin = false; // the last word was builtin, so a field right after it is too
	while ((m = re.exec(code))) {
		if (m[1]) target.append(el("span", { class: "tok-com" }, m[1]));
		else if (m[2]) target.append(el("span", { class: "tok-str" }, m[2]));
		else if (m[3]) target.append(el("span", { class: "tok-num" }, m[3]));
		else if (m[4]) {
			const word = m[4];
			const link = links ? linkWord(word) : null;
			const before = code.slice(0, m.index);
			const insideBraces = (before.match(/\{/g) || []).length > (before.match(/\}/g) || []).length;
			const isTableKey = insideBraces && /[{,]\s*$/.test(prev) && /^\s*=(?!=)/.test(code.slice(re.lastIndex));
			const isField = /[.:]\s*$/.test(prev) || isTableKey;
			const value = lookup && !isField ? lookup(word) : undefined;
			const builtin = isField ? prevBuiltin && /[.:]\s*$/.test(prev) : BUILTINS.has(word) && !lookup?.(word);
			// f(...), f "...", f { ... }
			const call = /^[ \t]*[("'`{]/.test(code.slice(re.lastIndex));
			const tok = builtin ? "tok-builtin" : call ? "tok-call" : null;
			if (KEYWORDS.has(word)) target.append(el("span", { class: "tok-kw" }, word));
			else if (prev.endsWith("resave.") && FUNCTIONS.has(word)) target.append(el("a", { class: "tok-fn", href: `#${word}`, "data-fn": word }, word));
			else if (link) target.append(el("a", { class: link.cls, href: link.href, "data-fn": FUNCTIONS.has(word) ? word : null }, word));
			else if (value !== undefined) target.append(el("span", { class: tok ? `var ${tok}` : "var", tabindex: "0", "data-value": value }, word));
			else if (tok) target.append(el("span", { class: tok }, word));
			else target.append(word);
			prevBuiltin = builtin;
		} else {
			target.append(m[5]);
			if (!/[.:\s]/.test(m[5])) prevBuiltin = false;
		}
		prev = (prev + m[0]).slice(-7);
	}
	return target;
}

export const highlight = code => highlightInto(el("pre", { class: "code" }), code);

// a recorded Luau value (returns, DataStore rows, session data)
export const ValuePre = text => highlightInto(el("pre", { class: "val" }), text);

export const InlineCode = text => highlightInto(el("code"), text, { links: true });
