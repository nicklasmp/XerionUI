// Usage: node tools/genchangelog.js
// Regenerates XerionUI_Options/ChangelogData.lua from CHANGELOG.md (newest 15 versions).
// Called by tools/bump.js; run it by hand after editing CHANGELOG.md.
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..");
const KEEP = 15;
const md = fs.readFileSync(path.join(root, "CHANGELOG.md"), "utf8");
const entries = [];
for (const block of md.split(/^## /m).slice(1)) {
	const [head, ...lines] = block.split("\n");
	const m = head.match(/^(\d+\.\d+\.\d+)\s*-\s*(\S+)/);
	if (!m) continue;
	const notes = lines.filter((l) => l.startsWith("- ")).map((l) => l.slice(2).trim());
	if (notes.length) entries.push({ version: m[1], date: m[2], notes });
}
const q = (s) => JSON.stringify(s); // JSON strings are valid Lua 5.1 strings for our ASCII text
let out = "-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.\n";
out += "local XUI = _G.XerionUI\nlocal O = XUI and XUI.Options\nif not O then return end\n\nO.CHANGELOG = {\n";
for (const e of entries.slice(0, KEEP)) {
	out += `\t{ version = ${q(e.version)}, date = ${q(e.date)}, notes = {\n`;
	for (const n of e.notes) out += `\t\t${q(n)},\n`;
	out += "\t} },\n";
}
out += "}\n";
fs.writeFileSync(path.join(root, "XerionUI_Options", "ChangelogData.lua"), out);
console.log(`ChangelogData.lua: ${Math.min(KEEP, entries.length)} versions`);
