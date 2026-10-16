--------------------------------------------------------------------------------
-- XerionUI_Options - Modules/Class.lua
-- Options for the Class category.
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local Card, Join = O.Card, O.Join

O:RegisterModuleOptions("BoneShield", function(ctx, m, G)
	return {
		Card("When", {
			{ type = "slider", label = "Glow with seconds left", path = "glowThreshold", min = 1, max = 20, step = 1 },
			{ type = "toggle", label = "Warn under 5 stacks", path = "stackWarn",
				tip = "In keys the stack count is hidden: put Ossuary on a Cooldown Manager buff bar for this to work there." },
			{ type = "slider", label = "Sound with seconds left", path = "soundThreshold", min = 1, max = 20, step = 1 },
			{ type = "toggle", label = "Sound only in combat", path = "soundInCombatOnly" },
			{ type = "slider", label = "Bone Shield duration (fallback)", path = "duration", min = 10, max = 60, step = 1 },
			{ type = "toggle", label = "Custom Bone Shield icon art", path = "customArt" },
		}),
		Card("Glow", G.Glow("glow")),
		Card("Alert", G.Alert("alert")),
		Card("Diagnostics", {
			{ type = "button", text = "Print status", onClick = function() m:PrintStatus() end },
			{ type = "button", text = "Forget learned spells", onClick = function() m:ForgetLearned() end },
		}),
	}
end)

O:RegisterModuleOptions("DRWSound", function(ctx, m, G)
	return {
		Card("When", {
			{ type = "toggle", label = "When it is extended", path = "onRefresh" },
			{ type = "toggle", label = "When it starts", path = "onGain" },
			{ type = "description", text = "Dancing Rune Weapon must be on a Cooldown Manager bar." },
		}),
		Card("Alert", G.Alert("alert", { test = function() m:TestAlert() end })),
	}
end)

O:RegisterModuleOptions("BoilingPoint", function(ctx, m, G)
	return {
		Card("Bar", Join(G.Bar("bar", { color = true }), {
			{ type = "toggle", label = "Also a bar while the proc is up", path = "procBar" },
			{ type = "color", label = "Proc bar color", path = "procColor" },
		})),
		Card("Border", G.Border("border")),
		Card("Timer text", G.Font("timerText", { toggle = "Show timer" })),
		Card("Glow while Blood Boil is lit", G.Glow("procGlow")),
		Card("Position", G.Position("position")),
	}
end)

--------------------------------------------------------------------------------
-- Shared card sets
--------------------------------------------------------------------------------
-- The cards of a Kit.TimedIcon module; `extra` cards are put first.
local function TimedIconCards(G, extra, glow)
	local cards = {}
	for _, c in ipairs(extra or {}) do cards[#cards + 1] = c end
	cards[#cards + 1] = Card("Icon", Join(G.Icon("icon", { square = true }), {
		{ type = "toggle", label = "Cooldown swipe", path = "showSwipe" },
	}))
	cards[#cards + 1] = Card("Border", G.Border("border"))
	if glow then cards[#cards + 1] = Card("Glow", G.Glow("glow")) end
	cards[#cards + 1] = Card("Timer text", G.Font("timerText", { toggle = "Show timer", color = true }))
	cards[#cards + 1] = Card("Position", G.Position("position"))
	return cards
end

O:RegisterModuleOptions("BloodIsLife", function(ctx, m, G)
	return TimedIconCards(G, nil, true)
end)

O:RegisterModuleOptions("BloodBeast", function(ctx, m, G)
	return {
		Card("Text", Join(G.Font("font"), {
			{ type = "color", label = "Label color", path = "labelColor" },
			{ type = "color", label = "Value color", path = "valueColor" },
		})),
		Card("Position", G.Position("position")),
	}
end)

O:RegisterModuleOptions("ControlUndead", function(ctx, m, G)
	return TimedIconCards(G, {
		Card("When", {
			{ type = "toggle", label = "Hide when the minion is gone", path = "hideOnPetLost" },
			{ type = "slider", label = "Warn color with seconds left", path = "warnAt", min = 0, max = 120, step = 5 },
			{ type = "color", label = "Warn color", path = "warnColor" },
		}),
	})
end)

O:RegisterModuleOptions("WellHoned", function(ctx, m, G)
	return {
		Card("Sounds", {
			{ type = "dropdown", label = "When the lockout lands", path = "sound", media = "sound", filesOnly = true },
			{ type = "button", text = "Test", onClick = function() m:Test("sound") end },
			{ type = "dropdown", label = "When it ends", path = "endSound", media = "sound", filesOnly = true },
			{ type = "button", text = "Test", onClick = function() m:Test("endSound") end },
			{ type = "dropdown", label = "Channel", path = "channel", values = XUI.Audio.CHANNELS },
			{ type = "description", text = "Played by the game itself, so it works in keys and raid encounters. A new sound is registered when the fight or the encounter ends." },
		}),
	}
end)

O:RegisterModuleOptions("BearForm", function(ctx, m, G)
	return {
		Card("Text", Join({
			{ type = "input", label = "Text", path = "text" },
			{ type = "color", label = "Color", path = "color" },
			{ type = "toggle", label = "Pulse", path = "pulse", tip = "Fades the text in and out while you are not in Bear Form, so it is harder to miss." },
			{ type = "slider", label = "Pulse speed (seconds per fade)", path = "pulseSpeed", min = 0.15, max = 1.5, step = 0.05,
				disabled = function() return not m.db.pulse end },
		}, G.Font("font"))),
		Card("Position", G.Position("position")),
		Card("Alert", G.Alert("alert", { fallbackText = "Bear form" })),
	}
end)

O:RegisterModuleOptions("ReapersMark", function(ctx, m, G)
	return {
		Card("Icon", Join(G.Icon("icon", { square = true }), {
			{ type = "toggle", label = "Cooldown swipe", path = "showSwipe" },
		})),
		Card("Border", G.Border("border")),
		Card("Timer text", G.Font("timerText", { toggle = "Show timer", anchor = true })),
		Card("Stacks", G.Font("stackText", { toggle = "Show stacks", anchor = true, color = true })),
		Card("Position", G.Position("position")),
	}
end)

O:RegisterModuleOptions("RuneforgeAlert", function(ctx, m, G)
	local cards = {
		Card("Text", Join({
			{ type = "input", label = "Text", path = "text" },
			{ type = "color", label = "Color", path = "color" },
		}, G.Font("font"))),
	}
	-- one card per build of the current specialization: which runes are fine on each weapon
	for _, setup in ipairs(m.SETUPS) do
		local items = {}
		for _, slot in ipairs(setup.slots) do
			items[#items + 1] = { type = "description", text = slot.label .. ": accepted runes" }
			for _, rune in ipairs(m.RUNES) do
				items[#items + 1] = {
					type = "toggle", label = rune.name,
					get = function()
						local runes = m:Accepted(setup.key, slot.key)
						return runes and runes[rune.enchantId] == true or false
					end,
					set = function(_, on) m:SetAccepted(setup.key, slot.key, rune.enchantId, on) end,
				}
			end
		end
		cards[#cards + 1] = Card(setup.label, items, { hidden = function() return setup.spec ~= XUI.GetSpecID() end })
	end
	cards[#cards + 1] = Card("Position", G.Position("position"))
	return cards
end)


O:RegisterModuleOptions("Ironfur", function(ctx, m, G)
	return {
		Card("When", {
			{ type = "slider", label = "Glow with seconds left (last stack)", path = "glowThreshold", min = 1, max = 7, step = 1 },
			{ type = "slider", label = "Voice with seconds left (last stack)", path = "soundThreshold", min = 1, max = 7, step = 1 },
			{ type = "toggle", label = "Only in combat", path = "soundInCombatOnly" },
			{ type = "slider", label = "Seconds one Ironfur lasts (fallback)", path = "duration", min = 4, max = 15, step = 1,
				tip = "Used where the game hides the aura (in keys); the real time takes over when it is readable." },
			{ type = "description", text = "Put Ironfur on a Cooldown Manager buff bar to get the glow there; or switch on the icon below." },
		}, { previewState = true }),
		Card("Glow", G.Glow("glow")),
		Card("Alert", G.Alert("alert", { fallbackText = "Ironfur" })),
		Card("Icon of its own", Join({
			{ type = "toggle", label = "Show an icon with the seconds left", path = "showIcon" },
		}, G.Icon("icon", { square = true }))),
		Card("Border", G.Border("border")),
		Card("Timer text", G.Font("timerText", { toggle = "Show timer" })),
		Card("Position", G.Position("position")),
	}
end)
