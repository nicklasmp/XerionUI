# Changelog

Newest first. Add an entry with `node tools/bump.js` before every push.

## 2.6.0 - 2026-10-15
- Chat Tweaks: input box height option, faster tab fade-out; Nameplates: dispel glow no longer needs EllesmereUI's Dispel Glow setting when 'without purge or soothe' is on, plus debug info

## 2.5.0 - 2026-10-15
- Nameplates: dispel glow on EllesmereUI buffs now uses our own glow styles (type, color, lines...), replacing EllesmereUI's static border; the 'without purge or soothe' option is kept

## 2.4.0 - 2026-10-15
- Add Chat Tweaks module: EllesmereUI chat tabs on mouseover and an optional background behind the input box

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
