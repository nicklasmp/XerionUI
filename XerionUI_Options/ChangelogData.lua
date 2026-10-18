-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
	{ version = "2.38.0", date = "2026-10-18", notes = {
		"Preview and Test are accent-filled primary buttons with a label, in the page header and wherever a Test button sits in a page",
		"Options panel: the Filter this page box is removed",
		"Bloodlust Ready and Aggro Check moved to the Combat category",
	} },
	{ version = "2.37.2", date = "2026-10-18", notes = {
		"Who Has the Key moved to the Misc category",
	} },
	{ version = "2.37.1", date = "2026-10-18", notes = {
		"Sidebar: Misc (renamed from Misc.) sits above EllesmereUI Tweaks and Dungeons sits right before Classes",
		"Options panel: the Position card is removed from every module (move frames with the unlock icon in the header)",
	} },
	{ version = "2.37.0", date = "2026-10-18", notes = {
		"NPC blacklist is a page of its own under Dungeons > All dungeons, shared by every dungeon (the Blacklist tab inside the dialog lists is gone)",
		"NPC blacklist: NPCs seen in two or more dungeons are listed as candidates, with a button to blacklist them",
	} },
	{ version = "2.36.0", date = "2026-10-18", notes = {
		"Auto NPC Dialog: the Picked tab is replaced by a Blacklist tab; blacklisting an NPC hides it and stops recording it in every dungeon",
		"Auto NPC Dialog: the Other group is now called Uncategorized",
		"New Misc. category (below EllesmereUI Tweaks) with Meter Reset, Bonus Roll Confirm and World Markers",
		"Options panel: keyboard navigation (Tab, Space/Enter, arrows) through switches, dropdowns, sliders and boxes",
		"Options panel: Diagnostics is a single icon instead of a menu; the Running status text is gone; the per-setting reset arrow is removed",
		"Co-Tank: removed the Always show this player option",
	} },
	{ version = "2.35.2", date = "2026-10-18", notes = {
		"New addon icon: bold Inter X on black, replaces the X/Twitter-style mark",
	} },
	{ version = "2.35.1", date = "2026-10-18", notes = {
		"Fix the options panel showing no settings on module pages (the hidden problem banner had height 0, which the game treats as no height)",
		"Options panel: Enable switch moved next to the page title; pages with few settings no longer split into tabs",
	} },
	{ version = "2.35.0", date = "2026-10-17", notes = {
		"Options panel: per-setting reset-to-default arrow next to changed values",
		"Options panel: module problems shown in a banner under the tab bar; OFF badge next to the title of a disabled module",
		"Options panel: Preview, Test and More are icon buttons; separate undo icon and wider header gaps",
		"Options panel: sidebar status uses shapes (dot, ring, triangle, cross) as well as colour; empty Inactive tab dimmed",
		"Options panel: higher contrast for muted and faint text, larger section headings, softer corner glow",
		"Options panel: Tab / Shift+Tab move between number and text boxes; missing SharedMedia entries are marked in red",
	} },
	{ version = "2.34.7", date = "2026-10-17", notes = {
		"Options: pixel-exact toggle switch textures",
	} },
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
}
