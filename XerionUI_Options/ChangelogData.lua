-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
	{ version = "2.31.3", date = "2026-10-17", notes = {
		"Options panel corner glows now use the accent color only",
		"Nav chips hide with their empty cards",
	} },
	{ version = "2.31.2", date = "2026-10-17", notes = {
		"A page tab disappears when its card is hidden by a setting (e.g. Party Frames Text), so no tab is ever empty",
	} },
	{ version = "2.31.1", date = "2026-10-17", notes = {
		"Preview now only appears on modules that draw a sample; the rest have Test only",
		"Preview and Test live only in the page header, no duplicate buttons inside the pages",
		"Removed Preview from the Skyriding Bar",
		"Pages with fewer than four cards no longer get tab chips, and Needs attention is never a tab",
	} },
	{ version = "2.31.0", date = "2026-10-17", notes = {
		"Sidebar width can be dragged (right edge, double-click resets) and is 15% wider by default",
	} },
	{ version = "2.30.8", date = "2026-10-17", notes = {
		"Meter Reset now lives in a Damager Meter group under Group",
	} },
	{ version = "2.30.7", date = "2026-10-17", notes = {
		"Auto NPC Dialog: dialogs without a known dungeon (built-ins, typed IDs) are listed under 'Other' so the module is always reachable",
	} },
	{ version = "2.30.6", date = "2026-10-17", notes = {
		"Auto Mark Tank and Co-Tank are separate entries under Group instead of one Tank group",
	} },
	{ version = "2.30.5", date = "2026-10-17", notes = {
		"Move Meter Reset into a new Damager Meter group under Group",
	} },
	{ version = "2.30.4", date = "2026-10-17", notes = {
		"Split Group Utility: Shroud, Who Has the Key, Bonus Roll Confirm and World Markers are now separate entries under Group",
	} },
	{ version = "2.30.3", date = "2026-10-17", notes = {
		"World Markers options: removed the meaningless Preview button",
	} },
	{ version = "2.30.2", date = "2026-10-17", notes = {
		"World markers are now placed at the mouse cursor immediately (/wm [@cursor]), no confirming click needed",
	} },
	{ version = "2.30.1", date = "2026-10-17", notes = {
		"Global glow now defaults to EllesmereUI's Auto-Cast Shine: four layers of sparks (sizes 7/6/5/4), layer k laps k times slower; saved profiles move onto it once (colour kept)",
	} },
	{ version = "2.30.0", date = "2026-10-17", notes = {
		"Options window: resizable (corner grip, Reset window size in General)",
		"Options: filter box and card chips above every page; the sidebar search lists matching settings and jumps to them",
		"Options: Undo button in the header, a more menu for Diagnostics",
		"Options: clearer value fields (dropdowns, number and text boxes) and tooltips on the shared style rows",
	} },
	{ version = "2.29.1", date = "2026-10-17", notes = {
		"Performance: shared inspect queue for Interrupts and Party CDs, fewer allocations in scans and polls, bounded Cooldown Manager catch-up tickers, Boiling Point drains only while shown",
	} },
	{ version = "2.29.0", date = "2026-10-17", notes = {
		"World Markers: set the place/clear keys directly in the options with a new key bind control",
	} },
}
