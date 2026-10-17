-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
	{ version = "2.34.1", date = "2026-10-17", notes = {
		"Sidebar: every module row shows a status dot (green on, grey off, amber/red problem)",
	} },
	{ version = "2.34.0", date = "2026-10-17", notes = {
		"Ungroup modules: every module is listed on its own in the sidebar again (Reminders, Party Tracking, Cooldown Manager, Cast Bars, Externals, Damage Meter)",
	} },
	{ version = "2.33.2", date = "2026-10-17", notes = {
		"Give XerionUI Options the addon list icon",
	} },
	{ version = "2.33.1", date = "2026-10-17", notes = {
		"Sidebar icons removed again (too busy); off modules keep the dimmed text and off tag",
	} },
	{ version = "2.33.0", date = "2026-10-17", notes = {
		"Sidebar rows have icons again; the on/off toggle in the sidebar is gone (use the switch in the page header)",
		"Modules that are off are dimmed with a grey icon and an off tag; amber or red dot marks a problem; hover tooltip explains the state",
	} },
	{ version = "2.32.1", date = "2026-10-17", notes = {
		"Fix typo: \"Damager Meter\" is now \"Damage Meter\"",
	} },
	{ version = "2.32.0", date = "2026-10-17", notes = {
		"Breadcrumb above the page title shows where a page sits and reveals it in the sidebar",
		"Sidebar search: Up/Down moves the Enter target, matching words are highlighted, empty results are explained, +N more on this page, Ctrl+F focuses the search",
		"All/Active/Inactive show counts; fold-all button; back/forward (header buttons, Alt+Left/Right)",
		"Page filter box looks different from the sidebar search; header text shows in full on hover when cut; Undo button keeps its place; untested modules marked with * and a tooltip",
	} },
	{ version = "2.31.4", date = "2026-10-17", notes = {
		"Opening a page from a link or search hit unfolds its group and scrolls it into view",
		"Sidebar keeps its order while you switch modules; it settles when the pointer leaves",
		"Tab chips that do not fit move into a ... menu; the open tab stays visible",
	} },
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
		"Meter Reset now lives in a Damage Meter group under Group",
	} },
	{ version = "2.30.7", date = "2026-10-17", notes = {
		"Auto NPC Dialog: dialogs without a known dungeon (built-ins, typed IDs) are listed under 'Other' so the module is always reachable",
	} },
	{ version = "2.30.6", date = "2026-10-17", notes = {
		"Auto Mark Tank and Co-Tank are separate entries under Group instead of one Tank group",
	} },
}
