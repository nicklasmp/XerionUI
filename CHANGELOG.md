# Changelog

Newest first. Add an entry with `node tools/bump.js` before every push.

## 2.7.0 - 2026-10-15
- Chat Tweaks: option to put the input box above the tab row (like ElvUI), with a fine-tune offset

## 2.6.1 - 2026-10-15
- GitHub releases (and so WowUp's changelog) now show the matching CHANGELOG.md entry instead of an empty auto-generated note
# Changelog

Newest first. Add an entry with `node tools/bump.js` before every push.

## 2.6.0 - 2026-10-15
- Chat Tweaks: new input box height option (sets EllesmereUI's Edit Box Height while the module runs)
- Chat Tweaks: tabs now fade out faster on mouseover
- Nameplates: the dispel glow no longer depends on EllesmereUI's own Dispel Glow setting when "Show the glow without purge or soothe" is on
- Nameplates: glow errors are reported in the module status, and Diagnostics lists the glow wiring

## 2.5.0 - 2026-10-15
- Nameplates: the dispel glow on EllesmereUI buffs uses XerionUI's own glow styles (type, color, lines, thickness...) instead of EllesmereUI's static border
- Nameplates: "Show the glow without purge or soothe" is kept

## 2.4.0 - 2026-10-15
- New module Chat Tweaks for EllesmereUI's chat: tabs on mouseover (hidden until the cursor is over the chat, or while typing)
- Chat Tweaks: optional background behind the input box while typing, with its own color and texture

## 2.3.0 - 2026-10-14
- Auto NPC Dialog: built-in dungeon list, on by default, with a toggle

## 2.2.3 - 2026-10-14
- Merge FocusKick Sound into Focus Cast Bar (own section; old settings carried over)

## 2.2.2 - 2026-10-14
- Fix a syntax error in Auto NPC Dialog from 2.2.1

## 2.2.1 - 2026-10-14
- Auto NPC Dialog lists the name next to each option ID (learned when the NPC is talked to)

## 2.2.0 - 2026-10-14
- Add Meter Reset module: asks whether to reset the damage meter when you leave a dungeon (optionally raids and scenarios)

## 2.1.2 - 2026-10-14
- Make the interrupt flash blink fewer times (1.5 s, about two pulses)

## 2.1.1 - 2026-10-14
- Fix the module header texts running under the buttons
- Add folding for each dungeon in the sidebar

## 2.1.0 - 2026-10-14
- Add Bonus Roll Confirm module (ported from the BonusRollConfirm addon): confirmation before using or passing a bonus roll, with loot spec shown

## 2.0.2 - 2026-10-14
- Rename Auto Gossip module to Auto NPC Dialog
- Remove the CC Tracker module (not the wanted feature)

## 2.0.1 - 2026-10-14
- Add addon icon and custom Party Cooldowns icon
- Add version history (CHANGELOG.md) and tools/bump.js

## 2.0.0 - 2026-10-03
- Rebuilt core replacing legacy v1.20; all class modules ported
- Dungeon category, Party Cooldowns, Auto Gossip, Damage Amp and Chaos Barrage modules
- GitHub release workflow so WowUp can install and update the addon
