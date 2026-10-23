-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
	{ version = "2.46.7", date = "2026-10-23", notes = {
		"Party Interrupts: ignore cast stops with no interrupter (stuns, deaths), pair cast stop and meter hit within 0.3 s",
		"Party Interrupts: read party cooldown talents (Quick Witted, Honed Reflexes, Coldthirst, Light of the Sun) and update kick base cooldowns",
	} },
	{ version = "2.46.6", date = "2026-10-23", notes = {
		"Auto NPC Dialog: Blacklist button always shown on a dialog row (dimmed until the NPC is known)",
	} },
	{ version = "2.46.5", date = "2026-10-23", notes = {
		"Remove the Forget unpicked button from Auto NPC Dialog",
	} },
	{ version = "2.46.4", date = "2026-10-23", notes = {
		"Skip Cinematic: moved under Kings' Rest in the Dungeons tab (was Misc), one switch for the module",
	} },
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
}
