-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
	{ version = "2.40.3", date = "2026-10-20", notes = {
		"Rename Mail Contacts to Mail Alts",
	} },
	{ version = "2.40.2", date = "2026-10-19", notes = {
		"Mail Contacts: show only your own characters (Friends, Guild and Favorites lists removed)",
	} },
	{ version = "2.40.1", date = "2026-10-19", notes = {
		"Fix Mail Contacts font error when the panel is built",
	} },
	{ version = "2.40.0", date = "2026-10-19", notes = {
		"New modules added by an update are now enabled automatically (once per profile; turn them off in the options)",
	} },
	{ version = "2.39.1", date = "2026-10-19", notes = {
		"Mail Contacts moved to the Misc category",
	} },
	{ version = "2.39.0", date = "2026-10-19", notes = {
		"Add Mail Contacts: a list of your other characters, online friends, guild members and favorites beside Send Mail",
	} },
	{ version = "2.38.3", date = "2026-10-19", notes = {
		"Remove the breadcrumb above the page icon",
	} },
	{ version = "2.38.2", date = "2026-10-19", notes = {
		"Fit the Stop preview button to its label",
		"Drop the Group breadcrumb above group module titles",
	} },
	{ version = "2.38.1", date = "2026-10-18", notes = {
		"Center the dark action row on the Auto Mark Tank button",
	} },
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
}
