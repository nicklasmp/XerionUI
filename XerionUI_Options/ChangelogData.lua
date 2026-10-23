-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
	{ version = "2.45.0", date = "2026-10-23", notes = {
		"Auto NPC Dialog: delves now have their own Delves category in the sidebar, separate from Dungeons",
	} },
	{ version = "2.44.5", date = "2026-10-23", notes = {
		"Chat Tweaks: show tabs on unread whisper again (read alert state via ChatFrameUtil.IsTabAlerting)",
	} },
	{ version = "2.44.4", date = "2026-10-23", notes = {
		"New modules are no longer enabled automatically after an update",
	} },
	{ version = "2.44.3", date = "2026-10-23", notes = {
		"Remove MDT Font again",
	} },
	{ version = "2.44.2", date = "2026-10-22", notes = {
		"Remove Cooldown Manager Combat Res tweak",
	} },
	{ version = "2.44.1", date = "2026-10-21", notes = {
		"Lower idle polling in EUIChat tabs and Chaos Barrage (fast ticks only while animating)",
	} },
	{ version = "2.44.0", date = "2026-10-21", notes = {
		"Add Cooldown Manager Combat Res: track the group's battle resurrections on an EllesmereUI Cooldown Manager bar with any class",
	} },
	{ version = "2.43.0", date = "2026-10-21", notes = {
		"Add MDT Font: use another font for the text in Mythic Dungeon Tools' window",
	} },
	{ version = "2.42.3", date = "2026-10-21", notes = {
		"Remove Smart Count Tracker and MDT Compact again",
	} },
	{ version = "2.42.2", date = "2026-10-21", notes = {
		"Fix the page header on/off switch being covered by the title hover area",
	} },
	{ version = "2.42.1", date = "2026-10-21", notes = {
		"Fix Chaos Barrage and Damage Amp staying on screen or not restarting when switched off and on",
	} },
	{ version = "2.42.0", date = "2026-10-21", notes = {
		"Party Stops is now one block: choose horizontal or vertical, how many rows or columns, fill order and centering (the two old bars are merged on update)",
	} },
	{ version = "2.41.1", date = "2026-10-21", notes = {
		"Chat Tweaks: show the chat tabs while a whisper is unread",
	} },
	{ version = "2.41.0", date = "2026-10-21", notes = {
		"Add Party Stops: cooldowns of the group's stuns and AoE crowd control, read from enemy debuffs, with talent-adjusted lengths",
		"Add Smart Count Tracker: enemy forces bar against your MDT route with the pull stacked behind the fill",
		"Add MDT Compact: fold Mythic Dungeon Tools' window into a small map with the pull list",
		"Add shared Timer kit, enemy sensor chains and talent reader for the group modules",
	} },
	{ version = "2.40.3", date = "2026-10-20", notes = {
		"Rename Mail Contacts to Mail Alts",
	} },
}
