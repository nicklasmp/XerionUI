# Changelog

Newest first. Add an entry with `node tools/bump.js` before every push.

## 2.39.0 - 2026-10-19
- Add Mail Contacts: a list of your other characters, online friends, guild members and favorites beside Send Mail

## 2.38.3 - 2026-10-19
- Remove the breadcrumb above the page icon

## 2.38.2 - 2026-10-19
- Fit the Stop preview button to its label
- Drop the Group breadcrumb above group module titles

## 2.38.1 - 2026-10-18
- Center the dark action row on the Auto Mark Tank button

## 2.38.0 - 2026-10-18
- Preview and Test are accent-filled primary buttons with a label, in the page header and wherever a Test button sits in a page
- Options panel: the Filter this page box is removed
- Bloodlust Ready and Aggro Check moved to the Combat category

## 2.37.2 - 2026-10-18
- Who Has the Key moved to the Misc category

## 2.37.1 - 2026-10-18
- Sidebar: Misc (renamed from Misc.) sits above EllesmereUI Tweaks and Dungeons sits right before Classes
- Options panel: the Position card is removed from every module (move frames with the unlock icon in the header)

## 2.37.0 - 2026-10-18
- NPC blacklist is a page of its own under Dungeons > All dungeons, shared by every dungeon (the Blacklist tab inside the dialog lists is gone)
- NPC blacklist: NPCs seen in two or more dungeons are listed as candidates, with a button to blacklist them

## 2.36.0 - 2026-10-18
- Auto NPC Dialog: the Picked tab is replaced by a Blacklist tab; blacklisting an NPC hides it and stops recording it in every dungeon
- Auto NPC Dialog: the Other group is now called Uncategorized
- New Misc. category (below EllesmereUI Tweaks) with Meter Reset, Bonus Roll Confirm and World Markers
- Options panel: keyboard navigation (Tab, Space/Enter, arrows) through switches, dropdowns, sliders and boxes
- Options panel: Diagnostics is a single icon instead of a menu; the Running status text is gone; the per-setting reset arrow is removed
- Co-Tank: removed the Always show this player option

## 2.35.2 - 2026-10-18
- New addon icon: bold Inter X on black, replaces the X/Twitter-style mark

## 2.35.1 - 2026-10-18
- Fix the options panel showing no settings on module pages (the hidden problem banner had height 0, which the game treats as no height)
- Options panel: Enable switch moved next to the page title; pages with few settings no longer split into tabs

## 2.35.0 - 2026-10-17
- Options panel: per-setting reset-to-default arrow next to changed values
- Options panel: module problems shown in a banner under the tab bar; OFF badge next to the title of a disabled module
- Options panel: Preview, Test and More are icon buttons; separate undo icon and wider header gaps
- Options panel: sidebar status uses shapes (dot, ring, triangle, cross) as well as colour; empty Inactive tab dimmed
- Options panel: higher contrast for muted and faint text, larger section headings, softer corner glow
- Options panel: Tab / Shift+Tab move between number and text boxes; missing SharedMedia entries are marked in red

## 2.34.7 - 2026-10-17
- Options: pixel-exact toggle switch textures

## 2.34.6 - 2026-10-17
- Nameplates: dispel border gets one more additive layer so the corners fill in

## 2.34.5 - 2026-10-17
- Nameplates: fix the secret-boolean error in the dispel border tint (the style is read from EllesmereUI's setting instead of the texture's shown state)

## 2.34.4 - 2026-10-17
- Nameplates: dispel border color works again with EllesmereUI 9.6 (the border texture moved to host._euiPanTex); it only applies while EllesmereUI's Dispel Glow style is Blizzard Pandemic Border

## 2.34.3 - 2026-10-17
- Fix ADDON_ACTION_BLOCKED from the options window's keyboard shortcuts in combat

## 2.34.2 - 2026-10-17
- Sidebar: remove the Active filter tab (it hid disabled modules); a saved Active filter resets to All

## 2.34.1 - 2026-10-17
- Sidebar: every module row shows a status dot (green on, grey off, amber/red problem)

## 2.34.0 - 2026-10-17
- Ungroup modules: every module is listed on its own in the sidebar again (Reminders, Party Tracking, Cooldown Manager, Cast Bars, Externals, Damage Meter)

## 2.33.2 - 2026-10-17
- Give XerionUI Options the addon list icon

## 2.33.1 - 2026-10-17
- Sidebar icons removed again (too busy); off modules keep the dimmed text and off tag

## 2.33.0 - 2026-10-17
- Sidebar rows have icons again; the on/off toggle in the sidebar is gone (use the switch in the page header)
- Modules that are off are dimmed with a grey icon and an off tag; amber or red dot marks a problem; hover tooltip explains the state

## 2.32.1 - 2026-10-17
- Fix typo: "Damager Meter" is now "Damage Meter"

## 2.32.0 - 2026-10-17
- Breadcrumb above the page title shows where a page sits and reveals it in the sidebar
- Sidebar search: Up/Down moves the Enter target, matching words are highlighted, empty results are explained, +N more on this page, Ctrl+F focuses the search
- All/Active/Inactive show counts; fold-all button; back/forward (header buttons, Alt+Left/Right)
- Page filter box looks different from the sidebar search; header text shows in full on hover when cut; Undo button keeps its place; untested modules marked with * and a tooltip

## 2.31.4 - 2026-10-17
- Opening a page from a link or search hit unfolds its group and scrolls it into view
- Sidebar keeps its order while you switch modules; it settles when the pointer leaves
- Tab chips that do not fit move into a ... menu; the open tab stays visible

## 2.31.3 - 2026-10-17
- Options panel corner glows now use the accent color only
- Nav chips hide with their empty cards

## 2.31.2 - 2026-10-17
- A page tab disappears when its card is hidden by a setting (e.g. Party Frames Text), so no tab is ever empty

## 2.31.1 - 2026-10-17
- Preview now only appears on modules that draw a sample; the rest have Test only
- Preview and Test live only in the page header, no duplicate buttons inside the pages
- Removed Preview from the Skyriding Bar
- Pages with fewer than four cards no longer get tab chips, and Needs attention is never a tab

## 2.31.0 - 2026-10-17
- Sidebar width can be dragged (right edge, double-click resets) and is 15% wider by default

## 2.30.8 - 2026-10-17
- Meter Reset now lives in a Damage Meter group under Group

## 2.30.7 - 2026-10-17
- Auto NPC Dialog: dialogs without a known dungeon (built-ins, typed IDs) are listed under 'Other' so the module is always reachable

## 2.30.6 - 2026-10-17
- Auto Mark Tank and Co-Tank are separate entries under Group instead of one Tank group

## 2.30.5 - 2026-10-17
- Move Meter Reset into a new Damage Meter group under Group

## 2.30.4 - 2026-10-17
- Split Group Utility: Shroud, Who Has the Key, Bonus Roll Confirm and World Markers are now separate entries under Group

## 2.30.3 - 2026-10-17
- World Markers options: removed the meaningless Preview button

## 2.30.2 - 2026-10-17
- World markers are now placed at the mouse cursor immediately (/wm [@cursor]), no confirming click needed

## 2.30.1 - 2026-10-17
- Global glow now defaults to EllesmereUI's Auto-Cast Shine: four layers of sparks (sizes 7/6/5/4), layer k laps k times slower; saved profiles move onto it once (colour kept)

## 2.30.0 - 2026-10-17
- Options window: resizable (corner grip, Reset window size in General)
- Options: filter box and card chips above every page; the sidebar search lists matching settings and jumps to them
- Options: Undo button in the header, a more menu for Diagnostics
- Options: clearer value fields (dropdowns, number and text boxes) and tooltips on the shared style rows

## 2.29.1 - 2026-10-17
- Performance: shared inspect queue for Interrupts and Party CDs, fewer allocations in scans and polls, bounded Cooldown Manager catch-up tickers, Boiling Point drains only while shown

## 2.29.0 - 2026-10-17
- World Markers: set the place/clear keys directly in the options with a new key bind control

## 2.28.2 - 2026-10-17
- World Markers: Open key bindings button now opens the Key Bindings page

## 2.28.1 - 2026-10-17
- Stronger corner glow in the options panel backdrop

## 2.28.0 - 2026-10-17
- New World Markers module: bindable keys that place world markers one after another and clear them all (Key Bindings -> AddOns -> XerionUI)

## 2.27.0 - 2026-10-17
- Options panel gets a soft corner-glow backdrop tinted from the accent color

## 2.26.3 - 2026-10-16
- Auto Mark Tank popup no longer falls back to the word Tank when previewing or when the name is secret

## 2.26.2 - 2026-10-16
- Auto Mark Tank popup shows the tank name in the action row

## 2.26.1 - 2026-10-16
- Auto Mark Tank popup restyled as a card with header, centred tank name and an inset action row

## 2.26.0 - 2026-10-16
- Style cards (Font, Border, Glow, Icon, Bar, Background) get a Reset to default button that puts that card back to the module's or the Global Style default

## 2.25.1 - 2026-10-16
- Autocast shine: default particles 16 (EllesmereUI's default of four layers of four sparks); speed and scale already match

## 2.25.0 - 2026-10-16
- Auto NPC Dialog moves under each dungeon: every dungeon with a seen dialog gets an NPC dialogs entry with its own dialogs (and a Settings tab)
- Externals gets its own group under Group instead of sitting in Party Tracking

## 2.24.1 - 2026-10-16
- Patch notes: remove the header button again; the version number opens the notes and carries the unread dot

## 2.24.0 - 2026-10-16
- Options: tabs are now rounded pills with an accent fill for the active one, and a group's tabs show a dot for which modules are switched on

## 2.23.2 - 2026-10-16
- Patch notes: back to the list view (no tabs)

## 2.23.1 - 2026-10-16
- Removed the Cooldown Manager Glow Probe diagnostics module

## 2.23.0 - 2026-10-16
- Options: groups show one member at a time with tabs, and long pages split into tabs by card title instead of one long list
- New module Cooldown Manager Glow Probe: diagnostics for why custom spell IDs get no active glow in EllesmereUI

## 2.22.3 - 2026-10-16
- Removed the Cooldown Manager Bar Glows module: glow types per bar are set in EllesmereUI itself

## 2.22.2 - 2026-10-16
- Cooldown Manager Bar Glows: glows on custom bars' icons are now recognised; debug shows ignored glows

## 2.22.1 - 2026-10-16
- Cooldown Manager Bar Glows now hooks the glow engine itself, so cooldown-ready and proc glows are replaced too; tab rows wrap instead of running past the card

## 2.22.0 - 2026-10-16
- Patch notes: own button in the window header with a dot while there are notes you have not opened; unread versions are marked new

## 2.21.3 - 2026-10-16
- Patch notes: open them by clicking the version number in the window header instead of a sidebar entry

## 2.21.2 - 2026-10-16
- Cooldown Manager page: a switched-off Font or Glow part now says so, with an Enable button

## 2.21.1 - 2026-10-16
- Autocast shine: draw the sparks from our own spark texture (the game's artifact sheet cut-out showed nothing), always use the script-free shine, retry when the icon has no size yet; Cooldown Manager Bar Glows debug shows what EllesmereUI asked for

## 2.21.0 - 2026-10-16
- New Patch notes page in the options sidebar: shows the latest 5 versions from the changelog with a button for older ones (up to 15)

## 2.20.3 - 2026-10-16
- Cooldown Manager page: pick a bar and Font or Glow with tabs so one card shows at a time instead of one per bar and module

## 2.20.2 - 2026-10-16
- Melee Indicator: remove the alert sound

## 2.20.1 - 2026-10-16
- Classes: Well-Honed Instincts moves under Guardian; Reaper's Mark, Control Undead and Runeforge Alert removed

## 2.20.0 - 2026-10-16
- Classes: sidebar is now Classes > class > specialization with a page per level; only Blood Death Knight and Guardian Druid kept for now (Blightfall and Forbidden Sacrifice removed)

## 2.19.2 - 2026-10-16
- Remove the Stoneform Bleed Alert; Reminders moves under Combat and takes the Melee Indicator

## 2.19.1 - 2026-10-16
- Navigation: Dungeons category lists each dungeon with its own modules; Aggro Check moves to a new Reminders group with Bloodlust Ready and Meter Reset

## 2.19.0 - 2026-10-16
- Navigation: related modules share one sidebar entry (Cooldown Manager, Cast Bars, Tank, Party Tracking, Group Utility, Encounter Tools); each part keeps its own switch and settings

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
