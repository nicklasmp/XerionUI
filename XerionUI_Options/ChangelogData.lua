-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
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
	{ version = "2.21.0", date = "2026-10-16", notes = {
		"New Patch notes page in the options sidebar: shows the latest 5 versions from the changelog with a button for older ones (up to 15)",
	} },
	{ version = "2.20.3", date = "2026-10-16", notes = {
		"Cooldown Manager page: pick a bar and Font or Glow with tabs so one card shows at a time instead of one per bar and module",
	} },
	{ version = "2.20.2", date = "2026-10-16", notes = {
		"Melee Indicator: remove the alert sound",
	} },
	{ version = "2.20.1", date = "2026-10-16", notes = {
		"Classes: Well-Honed Instincts moves under Guardian; Reaper's Mark, Control Undead and Runeforge Alert removed",
	} },
	{ version = "2.20.0", date = "2026-10-16", notes = {
		"Classes: sidebar is now Classes > class > specialization with a page per level; only Blood Death Knight and Guardian Druid kept for now (Blightfall and Forbidden Sacrifice removed)",
	} },
}
