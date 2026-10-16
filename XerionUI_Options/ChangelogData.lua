-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
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
	{ version = "2.19.2", date = "2026-10-16", notes = {
		"Remove the Stoneform Bleed Alert; Reminders moves under Combat and takes the Melee Indicator",
	} },
	{ version = "2.19.1", date = "2026-10-16", notes = {
		"Navigation: Dungeons category lists each dungeon with its own modules; Aggro Check moves to a new Reminders group with Bloodlust Ready and Meter Reset",
	} },
	{ version = "2.19.0", date = "2026-10-16", notes = {
		"Navigation: related modules share one sidebar entry (Cooldown Manager, Cast Bars, Tank, Party Tracking, Group Utility, Encounter Tools); each part keeps its own switch and settings",
	} },
	{ version = "2.18.3", date = "2026-10-16", notes = {
		"Remove the unused automatic profile switching",
	} },
	{ version = "2.18.2", date = "2026-10-16", notes = {
		"Cleanup and performance pass: fix a leaked options listener, stop redundant page and CDM bar refreshes, cache sidebar health dots, remove dead theme and layout code",
	} },
	{ version = "2.18.1", date = "2026-10-16", notes = {
		"Global Style: remove the Themes card",
		"Profiles: remove the Switch automatically card",
	} },
	{ version = "2.18.0", date = "2026-10-16", notes = {
		"New module Cooldown Manager Bar Glows: choose a glow type (Pixel, Pulse, Autocast shine, Action button, Proc) with its own color, speed and size per EllesmereUI Cooldown Manager bar",
	} },
	{ version = "2.17.0", date = "2026-10-16", notes = {
		"Options sidebar: text-only accordion with foldable groups, guide line, status dot that turns into a switch on hover",
	} },
	{ version = "2.16.1", date = "2026-10-16", notes = {
		"Auto Mark Tank: slimmer card with the close button integrated as an edge strip",
	} },
	{ version = "2.16.0", date = "2026-10-16", notes = {
		"Options: rounded cards, fields and buttons (9-slice), pink default accent, brighter labels",
	} },
}
