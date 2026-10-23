-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
	{ version = "2.46.3", date = "2026-10-23", notes = {
		"Dim the Confirm switch in Auto NPC Dialog until the option is picked",
		"Add more built-in dungeon dialogs and drop the When card in Auto NPC Dialog",
	} },
	{ version = "2.46.2", date = "2026-10-23", notes = {
		"Auto NPC Dialog: remove manual ID and NPC entry; add a Blacklist button per NPC with an are-you-sure dialog",
	} },
	{ version = "2.46.1", date = "2026-10-23", notes = {
		"Save Auto NPC Dialog NPC name from the gossip window title when the unit name is missing",
		"Explain unseen built-in NPC names instead of showing Unknown NPC",
	} },
	{ version = "2.46.0", date = "2026-10-23", notes = {
		"Add Skip Cinematics: skips the cinematic that plays in Kings' Rest (per-dungeon list, more can be added)",
	} },
	{ version = "2.45.2", date = "2026-10-23", notes = {
		"Auto NPC Dialog: built-in list, instance-only and chat announcements are now always on (options removed)",
	} },
	{ version = "2.45.1", date = "2026-10-23", notes = {
		"Auto NPC Dialog: ship the Den of Nalorakk and Altar of Fangs dialogs in the built-in list",
	} },
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
}
