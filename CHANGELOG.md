# Changelog

Newest first. Add an entry with `node tools/bump.js` before every push.

## 2.18.3 - 2026-10-16
- Remove the unused automatic profile switching

## 2.18.2 - 2026-10-16
- Cleanup and performance pass: fix a leaked options listener, stop redundant page and CDM bar refreshes, cache sidebar health dots, remove dead theme and layout code

## 2.18.1 - 2026-10-16
- Global Style: remove the Themes card
- Profiles: remove the Switch automatically card

## 2.18.0 - 2026-10-16
- New module Cooldown Manager Bar Glows: choose a glow type (Pixel, Pulse, Autocast shine, Action button, Proc) with its own color, speed and size per EllesmereUI Cooldown Manager bar

## 2.17.0 - 2026-10-16
- Options sidebar: text-only accordion with foldable groups, guide line, status dot that turns into a switch on hover

## 2.16.1 - 2026-10-16
- Auto Mark Tank: slimmer card with the close button integrated as an edge strip

## 2.16.0 - 2026-10-16
- Options: rounded cards, fields and buttons (9-slice), pink default accent, brighter labels

## 2.15.1 - 2026-10-16
- Options: flatter window and page headers, larger module icon and enable switch

## 2.15.0 - 2026-10-16
- Options redesign: flat row-based pages (label left, control right) with titled cards, underline filter tabs, bigger type
- Options font defaults to GothamNarrowBlack (SharedMedia_MyMedia), falling back to Arial Narrow

## 2.14.2 - 2026-10-16
- Auto Mark Tank: new card design showing who gets marked (class-coloured name), larger marker icon and a round close badge on the corner; dismissing now sticks until the situation changes

## 2.14.1 - 2026-10-16
- Options sidebar: replace the on/off pill with a crisp status dot (ring = off), health badge moved to the icon

## 2.14.0 - 2026-10-16
- Options: remove the Modules overview page (the sidebar switches replace it); add an Inactive filter chip; sidebar lists switched-on modules first, then switched-off, each alphabetical; crisper sidebar switch

## 2.13.1 - 2026-10-16
- Options sidebar: larger fold chevrons with hover hit area

## 2.13.0 - 2026-10-16
- Auto NPC Dialog: records every dialog opened in a dungeon (dungeon, NPC, option text) and lists them by dungeon in the options with a switch each for auto-pick and confirm; built-ins can be switched off one by one

## 2.12.0 - 2026-10-16
- Options sidebar: on/off switch per module and an All/Active filter

## 2.11.5 - 2026-10-16
- Options sidebar: disabled modules dimmed, enabled ones lit, on/total count per section

## 2.11.4 - 2026-10-16
- Auto Mark Tank: only offer the marker inside dungeons

## 2.11.3 - 2026-10-16
- Add 512px addon icon

## 2.11.2 - 2026-10-16
- Auto Mark Tank: add a close (x) button to dismiss the popup without marking

## 2.11.1 - 2026-10-15
- Cooldown Manager Bar Fonts: a bar with the toggle on but no font picked now uses the default font, hooked Blizzard icons are placed on their bar, the bar font wins over the Stack Font module, and Diagnostics shows how many texts were placed

## 2.11.0 - 2026-10-15
- Auto Mark Tank: hover effect on the button; remove the Hide Challenger's Might option from Nameplates (it could not work on enemy buffs)

## 2.10.2 - 2026-10-15
- Auto Mark Tank: placing a marker is protected, so it is now a one-click button that appears when the tank has no marker (fixes the SetRaidTarget forbidden error)

## 2.10.1 - 2026-10-15
- Nameplates diagnostics: report how many buff rows the Challenger's Might filter reached

## 2.10.0 - 2026-10-15
- New module Auto Mark Tank: puts a raid marker (square by default) on the group's tank when the group forms, roles change or you zone in

## 2.9.0 - 2026-10-15
- New module Cooldown Manager Bar Fonts: choose a font per EllesmereUI Cooldown Manager bar (cooldown numbers, keybinds, counts)

## 2.8.2 - 2026-10-15
- Nameplates: dispel border is stronger (three extra additive layers)

## 2.8.1 - 2026-10-15
- Nameplates: the tinted dispel border keeps EllesmereUI's weight (extra additive layer)

## 2.8.0 - 2026-10-15
- Nameplates: the dispel border is EllesmereUI's own border again, now with a color you choose; Hide Challenger's Might option for the Mythic+ buff

## 2.7.3 - 2026-10-15
- Nameplates: the dispel glow is drawn through EllesmereUI's own glow engine (the one built for aura buttons), so it renders; EllesmereUI's red border is kept hidden. Pixel, Action Button and Modern looks; autocast, shine and pulse map to the nearest

## 2.7.2 - 2026-10-15
- Nameplates diagnostics: report the glow overlays that are on screen (size, level, alpha)

## 2.7.1 - 2026-10-15
- Fix a duplicated header in CHANGELOG.md (it leaked into the 2.6.1 release notes); add a test for the nameplate dispel glow wrap

## 2.7.0 - 2026-10-15
- Chat Tweaks: option to put the input box above the tab row (like ElvUI), with a fine-tune offset

## 2.6.1 - 2026-10-15
- GitHub releases (and so WowUp's changelog) now show the matching CHANGELOG.md entry instead of an empty auto-generated note
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
