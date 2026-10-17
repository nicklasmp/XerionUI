-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
	{ version = "2.34.6", date = "2026-10-17", notes = {
		"Nameplates: dispel border gets one more additive layer so the corners fill in",
	} },
	{ version = "2.34.5", date = "2026-10-17", notes = {
		"Nameplates: fix the secret-boolean error in the dispel border tint (the style is read from EllesmereUI's setting instead of the texture's shown state)",
	} },
	{ version = "2.34.4", date = "2026-10-17", notes = {
		"Nameplates: dispel border color works again with EllesmereUI 9.6 (the border texture moved to host._euiPanTex); it only applies while EllesmereUI's Dispel Glow style is Blizzard Pandemic Border",
	} },
	{ version = "2.34.3", date = "2026-10-17", notes = {
		"Fix ADDON_ACTION_BLOCKED from the options window's keyboard shortcuts in combat",
	} },
	{ version = "2.34.2", date = "2026-10-17", notes = {
		"Sidebar: remove the Active filter tab (it hid disabled modules); a saved Active filter resets to All",
	} },
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
}
