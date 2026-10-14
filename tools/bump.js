// Usage: node tools/bump.js <patch|minor|major> "Change one" "Change two" ...
// Bumps ## Version in both TOC files and prepends a CHANGELOG.md entry.
// Run it once per push; then commit, push and push the tag (see CLAUDE.md).
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..");
const tocs = ["XerionUI/XerionUI.toc", "XerionUI_Options/XerionUI_Options.toc"].map((p) => path.join(root, p));
const [kind, ...notes] = process.argv.slice(2);
if (!["patch", "minor", "major"].includes(kind) || !notes.length) {
	console.error('usage: node tools/bump.js <patch|minor|major> "change" ["change" ...]');
	process.exit(1);
}
const main = fs.readFileSync(tocs[0], "utf8");
const m = main.match(/^## Version:\s*(\d+)\.(\d+)\.(\d+)/m);
if (!m) throw new Error("no ## Version in " + tocs[0]);
let [maj, min, pat] = m.slice(1).map(Number);
if (kind === "major") { maj++; min = 0; pat = 0; } else if (kind === "minor") { min++; pat = 0; } else pat++;
const next = `${maj}.${min}.${pat}`;
for (const f of tocs) {
	if (!fs.existsSync(f)) continue;
	const t = fs.readFileSync(f, "utf8");
	if (/^## Version:/m.test(t)) fs.writeFileSync(f, t.replace(/^## Version:.*$/m, "## Version: " + next));
}
const cl = path.join(root, "CHANGELOG.md");
const head = "# Changelog\n\nNewest first. Add an entry with `node tools/bump.js` before every push.\n";
const old = fs.existsSync(cl) ? fs.readFileSync(cl, "utf8").replace(/^# Changelog\n+Newest first.*\n/, "") : "";
const date = new Date().toISOString().slice(0, 10);
const entry = `\n## ${next} - ${date}\n${notes.map((n) => "- " + n).join("\n")}\n`;
fs.writeFileSync(cl, head + entry + old.replace(/^\n+/, "\n"));
console.log(`${m[1]}.${m[2]}.${m[3]} -> ${next}`);
