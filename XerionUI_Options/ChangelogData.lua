-- Generated from CHANGELOG.md by tools/genchangelog.js - do not edit by hand.
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

O.CHANGELOG = {
	{ version = "2.30.1", date = "2026-10-17", notes = {
		"Global glow now defaults to EllesmereUI's Auto-Cast Shine: four layers of sparks (sizes 7/6/5/4), layer k laps k times slower; saved profiles move onto it once (colour kept)",
	} },
	{ version = "2.30.0", date = "2026-10-17", notes = {
		"Options window: resizable (corner grip, Reset window size in General)",
		"Options: filter box and card chips above every page; the sidebar search lists matching settings and jumps to them",
		"Options: Undo button in the header, a more menu for Diagnostics",
		"Options: clearer value fields (dropdowns, number and text boxes) and tooltips on the shared style rows",
	} },
	{ version = "2.29.1", date = "2026-10-17", notes = {
		"Performance: shared inspect queue for Interrupts and Party CDs, fewer allocations in scans and polls, bounded Cooldown Manager catch-up tickers, Boiling Point drains only while shown",
	} },
	{ version = "2.29.0", date = "2026-10-17", notes = {
		"World Markers: set the place/clear keys directly in the options with a new key bind control",
	} },
	{ version = "2.28.2", date = "2026-10-17", notes = {
		"World Markers: Open key bindings button now opens the Key Bindings page",
	} },
	{ version = "2.28.1", date = "2026-10-17", notes = {
		"Stronger corner glow in the options panel backdrop",
	} },
	{ version = "2.28.0", date = "2026-10-17", notes = {
		"New World Markers module: bindable keys that place world markers one after another and clear them all (Key Bindings -> AddOns -> XerionUI)",
	} },
	{ version = "2.27.0", date = "2026-10-17", notes = {
		"Options panel gets a soft corner-glow backdrop tinted from the accent color",
	} },
	{ version = "2.26.3", date = "2026-10-16", notes = {
		"Auto Mark Tank popup no longer falls back to the word Tank when previewing or when the name is secret",
	} },
	{ version = "2.26.2", date = "2026-10-16", notes = {
		"Auto Mark Tank popup shows the tank name in the action row",
	} },
	{ version = "2.26.1", date = "2026-10-16", notes = {
		"Auto Mark Tank popup restyled as a card with header, centred tank name and an inset action row",
	} },
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
}
