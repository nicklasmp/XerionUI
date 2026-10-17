--------------------------------------------------------------------------------
-- XerionUI_Options - Modules/Tweaks.lua
-- Options for the EllesmereUI Tweaks category.
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local Card, Join = O.Card, O.Join

O:RegisterModuleOptions("EUINameplates", function(ctx, m, G)
	local function off() return not m.db.shield.enabled end
	return {
		Card("Dispel glow", {
			{ type = "toggle", label = "Show the glow without purge or soothe", path = "dispelAlways",
				tip = "EllesmereUI's own Dispel Glow setting still switches the glow on and off." },
		}),
		Card("Dispel border", {
			{ type = "toggle", label = "Use our border color", path = "customBorder",
				tip = "Tints EllesmereUI's border around a dispellable buff. Off, it keeps EllesmereUI's own red." },
			{ type = "color", label = "Color", path = "borderColor", hasAlpha = true,
				disabled = function() return not m.db.customBorder end },
		}),
		Card("Shield amount", Join({
			{ type = "toggle", label = "Show the shield amount", path = "shield.enabled", tip = "Show how much absorb shield the unit has." },
			{ type = "toggle", label = "Enemies only", path = "shield.enemyOnly", disabled = off, tip = "Skip the shield amount on friendly units." },
			{ type = "spacer" },
			{ type = "slider", label = "Offset X", path = "shield.offX", min = -40, max = 40, step = 1, disabled = off, tip = "Moves it sideways; negative is left." },
			{ type = "slider", label = "Offset Y", path = "shield.offY", min = -40, max = 40, step = 1, disabled = off, tip = "Moves it up or down; negative is down." },
		}, G.Font("shieldText", { color = true }))),
	}
end)

O:RegisterModuleOptions("EUIFlyingBar", function(ctx, m, G)
	return {
		Card("Whirling Surge icon", {
			{ type = "toggle", label = "Hide the icon", path = "hideIcon",
				tip = "Removes the Whirling Surge icon beside the bars; the bars close up. Switching this module off puts EllesmereUI's own icon setting back." },
		}),
	}
end)

O:RegisterModuleOptions("EUIActionBarFont", function(ctx, m, G)
	return {
		Card("Font", G.Font("font", { noSize = true })),
	}
end)

O:RegisterModuleOptions("EUICDMStackFont", function(ctx, m, G)
	return {
		Card("Font", {
			{ type = "dropdown", label = "Stack font", path = "face", media = "font",
				tip = "Used for stack and charge counts only. Size, outline and color stay as set in EllesmereUI." },
		}),
	}
end)

O:RegisterModuleOptions("ZoneText", function(ctx, m, G)
	return {
		Card("Font", Join({
			{ type = "slider", label = "Size", path = "scale", min = 50, max = 200, step = 5,
				tip = "Percent of Blizzard's own size. The color of the text stays as the game sets it for the zone." },
		}, G.Font("font", { noSize = true }))),
	}
end)

O:RegisterModuleOptions("EUIFocusCastbar", function(ctx, m, G)
	local function off() return not m.db.kick.enabled end
	return {
		Card("Background", {
			{ type = "color", label = "Background color", path = "color",
				tip = "Tints the empty background behind the cast fill. The cast color itself is unchanged." },
		}),
		Card("FocusKick sound", {
			{ type = "toggle", label = "Speak when you can interrupt", path = "kick.enabled",
				tip = "Speaks when your FocusKick target casts something you can interrupt and your kick is ready." },
			{ type = "description", text = "Speech only: whether a cast can be interrupted is hidden in keys, and only speech can follow it without Lua knowing. A sound file would play on every cast." },
			{ type = "input", label = "Words", path = "kick.text", disabled = off, tip = "What is spoken." },
			{ type = "dropdown", label = "Voice", path = "kick.voice", values = function() return XUI.Audio:Voices() end, disabled = off, tip = "The text to speech voice installed on this computer." },
			{ type = "slider", label = "Volume", path = "kick.volume", min = 0, max = 100, step = 5, disabled = off, tip = "How loud the spoken text is." },
			{ type = "slider", label = "Speed", path = "kick.rate", min = -10, max = 10, step = 1, disabled = off, tip = "How fast the voice speaks; negative is slower." },
		}),
	}
end)

O:RegisterModuleOptions("EUITargetedSpellBars", function(ctx, m, G)
	local function off() return not m.db.spark end
	return {
		Card("Boss casts", {
			{ type = "toggle", label = "Hide boss casts", path = "hideBossCasts",
				tip = "Takes effect at once for plates already on screen." },
			{ type = "button", text = "Re-detect", onClick = function() m:Redetect() end },
		}),
		Card("Cast spark", {
			{ type = "toggle", label = "Show a spark on the cast progress", path = "spark", tip = "A bright mark at the end of the filled part of the cast bar." },
			{ type = "slider", label = "Width", path = "sparkWidth", min = 1, max = 10, step = 1, disabled = off },
			{ type = "color", label = "Color", path = "sparkColor", disabled = off },
			{ type = "button", text = "EllesmereUI preview", onClick = function() m:TogglePreview() end },
		}),
	}
end)

O:RegisterModuleOptions("EUIPartyFrames", function(ctx, m, G)
	local function off() return not m.db.health.enabled end
	local function byValue() return not m.db.health.byValue end
	local function single() return m.db.health.byValue end
	return {
		Card("Health + shield %", {
			{ type = "toggle", label = "Show health + shield %", path = "health.enabled" },
			{ type = "dropdown", label = "Position", path = "health.anchor", values = m.ANCHORS, disabled = off },
			{ type = "toggle", label = "Use EllesmereUI's name font", path = "health.matchName", disabled = off },
			{ type = "slider", label = "Offset X", path = "health.x", min = -60, max = 60, step = 1, disabled = off, tip = "Moves it sideways; negative is left." },
			{ type = "slider", label = "Offset Y", path = "health.y", min = -30, max = 30, step = 1, disabled = off, tip = "Moves it up or down; negative is down." },
		}),
		Card("Text", G.Font("healthText"), { hidden = function() return off() or m.db.health.matchName end }),
		Card("Color", {
			{ type = "toggle", label = "Color by value", path = "health.byValue", disabled = off },
			{ type = "color", label = "Text color", path = "health.color", hidden = single, disabled = off },
			{ type = "color", label = "Below step 1", path = "health.c1", hidden = byValue, disabled = off },
			{ type = "slider", label = "Step 1", path = "health.t1", min = 1, max = 200, step = 1, hidden = byValue, disabled = off },
			{ type = "color", label = "Step 1 to 2", path = "health.c2", hidden = byValue, disabled = off },
			{ type = "slider", label = "Step 2", path = "health.t2", min = 1, max = 200, step = 1, hidden = byValue, disabled = off },
			{ type = "color", label = "Step 2 to 3", path = "health.c3", hidden = byValue, disabled = off },
			{ type = "slider", label = "Step 3", path = "health.t3", min = 1, max = 200, step = 1, hidden = byValue, disabled = off },
			{ type = "color", label = "Step 3 and above", path = "health.c4", hidden = byValue, disabled = off },
		}),
		Card("Debuff stack count", {
			{ type = "dropdown", label = "Position on each debuff icon", path = "stack.placement", values = m.STACK_PLACES },
			{ type = "spacer" },
			{ type = "slider", label = "Offset X", path = "stack.x", min = -40, max = 40, step = 1, tip = "Moves it sideways; negative is left." },
			{ type = "slider", label = "Offset Y", path = "stack.y", min = -40, max = 40, step = 1, tip = "Moves it up or down; negative is down." },
			{ type = "description", text = "Preview shows a sample debuff on your first party frame." },
		}),
	}
end)

O:RegisterModuleOptions("EUIChat", function(ctx, m, G)
	return {
		Card("Tabs", {
			{ type = "toggle", label = "Tabs on mouseover", path = "tabsMouseover",
				tip = "Hides EllesmereUI's chat tabs until the cursor is over the chat or the tabs, or while the input box is open. The tabs can still be clicked while hidden." },
		}),
		Card("Input box", {
			{ type = "slider", label = "Height", path = "inputHeight", min = 20, max = 60, step = 1,
				tip = "Sets EllesmereUI's Edit Box Height while this module runs (EllesmereUI's own default is 23)." },
			{ type = "toggle", label = "Input box above the tabs", path = "inputAboveTabs",
				tip = "Puts the input box above the tab row instead of below the chat (turns on EllesmereUI's Input on Top while this module runs)." },
			{ type = "slider", label = "Offset Y", path = "inputOffsetY", min = -20, max = 40, step = 1,
				disabled = function() return not m.db.inputAboveTabs end,
				tip = "Fine-tunes the gap between the tabs and the input box." },
		}),
		Card("Input background", G.Background("inputBg", { toggle = "Background behind the input box" })),
	}
end)

O:RegisterModuleOptions("EUICDMBarFonts", function(ctx, m, G)
	local cards = {}
	for _, bar in ipairs(m.BarList()) do
		local on = "bars." .. bar.key .. ".on"
		local face = "bars." .. bar.key .. ".face"
		cards[#cards + 1] = Card(tostring(bar.name), {
			{ type = "toggle", label = "Own font for this bar", path = on,
				get = function() return XUI.GetPath(m.db, on) == true end },
			{ type = "dropdown", label = "Font", path = face, media = "font",
				get = function() return XUI.GetPath(m.db, face) or "GothamNarrowBlack" end,
				disabled = function() return XUI.GetPath(m.db, on) ~= true end,
				tip = "Cooldown numbers, keybinds and counts on this bar. Size, outline and color stay as set in EllesmereUI." },
		}, { bar = bar.key })
	end
	if #cards == 0 then
		cards[1] = Card("Bars", {
			{ type = "description", text = "No Cooldown Manager bars found yet. Open this page again once EllesmereUI's Cooldown Manager has loaded." },
		})
	end
	return cards
end)
