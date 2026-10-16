-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
	{ version = "2.26.0", date = "2026-10-16", notes = {
		"Style cards (Font, Border, Glow, Icon, Bar, Background) get a Reset to default button that puts that card back to the module's or the Global Style default",
	} },
	{ version = "2.25.1", date = "2026-10-16", notes = {
		"Autocast shine: default particles 16 (EllesmereUI's default of four layers of four sparks); speed and scale already match",
	} },
	{ version = "2.25.0", date = "2026-10-16", notes = {
		"Auto NPC Dialog moves under each dungeon: every dungeon with a seen dialog gets an NPC dialogs entry with its own dialogs (and a Settings tab)",
		"Externals gets its own group under Group instead of sitting in Party Tracking",
	} },
	{ version = "2.24.1", date = "2026-10-16", notes = {
		"Patch notes: remove the header button again; the version number opens the notes and carries the unread dot",
	} },
	{ version = "2.24.0", date = "2026-10-16", notes = {
		"Options: tabs are now rounded pills with an accent fill for the active one, and a group's tabs show a dot for which modules are switched on",
	} },
	{ version = "2.23.2", date = "2026-10-16", notes = {
		"Patch notes: back to the list view (no tabs)",
	} },
	{ version = "2.23.1", date = "2026-10-16", notes = {
		"Removed the Cooldown Manager Glow Probe diagnostics module",
	} },
	{ version = "2.23.0", date = "2026-10-16", notes = {
		"Options: groups show one member at a time with tabs, and long pages split into tabs by card title instead of one long list",
		"New module Cooldown Manager Glow Probe: diagnostics for why custom spell IDs get no active glow in EllesmereUI",
	} },
	{ version = "2.22.3", date = "2026-10-16", notes = {
		"Removed the Cooldown Manager Bar Glows module: glow types per bar are set in EllesmereUI itself",
	} },
	{ version = "2.22.2", date = "2026-10-16", notes = {
		"Cooldown Manager Bar Glows: glows on custom bars' icons are now recognised; debug shows ignored glows",
	} },
	{ version = "2.22.1", date = "2026-10-16", notes = {
		"Cooldown Manager Bar Glows now hooks the glow engine itself, so cooldown-ready and proc glows are replaced too; tab rows wrap instead of running past the card",
	} },
	{ version = "2.22.0", date = "2026-10-16", notes = {
		"Patch notes: own button in the window header with a dot while there are notes you have not opened; unread versions are marked new",
	} },
	{ version = "2.21.3", date = "2026-10-16", notes = {
		"Patch notes: open them by clicking the version number in the window header instead of a sidebar entry",
	} },
	{ version = "2.21.2", date = "2026-10-16", notes = {
		"Cooldown Manager page: a switched-off Font or Glow part now says so, with an Enable button",
	} },
	{ version = "2.21.1", date = "2026-10-16", notes = {
		"Autocast shine: draw the sparks from our own spark texture (the game's artifact sheet cut-out showed nothing), always use the script-free shine, retry when the icon has no size yet; Cooldown Manager Bar Glows debug shows what EllesmereUI asked for",
	} },
}
