--------------------------------------------------------------------------------
-- XerionUI_Options - Modules/Group.lua
-- Options for the Group category.
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local Card, Join = O.Card, O.Join

local function IS121() return XUI.IS_121 end

--------------------------------------------------------------------------------
O:RegisterModuleOptions("Externals", function(ctx, m, G)
	return {
		Card("Layout", {
			{ type = "dropdown", label = "Grow", path = "grow", values = m.GROW },
			{ type = "slider", label = "Spacing", path = "spacing", min = 0, max = 20, step = 1 },
		}),
		Card("Icon", G.Icon("icon", { square = true })),
		Card("Border", G.Border("border")),
		Card("Glow", G.Glow("glow")),
		Card("Timer text", G.Font("timerText", { toggle = "Show timer", anchor = true })),
		Card("Alert", Join(
			{ {
				type = "description", width = "full",
				text = function()
					if IS121() then return "On this client the sound is played by the game itself for the spells below; text to speech is not available here." end
					return "Plays when a new external lands on you."
				end,
			} },
			G.Alert("alert", { test = function() m:TestAlert() end })
		)),
		Card("Sound for these spells", {
			{ type = "spellList", path = "soundSpells", width = "full" },
		}, { hidden = function() return not IS121() end }),
		Card("Position", G.Position("position")),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("Interrupts", function(ctx, m, G)
	local function barMode() return m.db.displayMode == "icon" end
	local function iconMode() return m.db.displayMode ~= "icon" end
	return {
		Card("Show", {
			{ type = "dropdown", label = "Display", path = "displayMode", values = m.MODES },
			{ type = "dropdown", label = "Icon shows", path = "iconSource", values = m.ICON_SOURCES,
				tip = "The interrupted spell is shown for as long as the bar runs, so you can see which cast was handled." },
			{ type = "toggle", label = "Your own interrupt", path = "showSelf" },
			{ type = "toggle", label = "Ready interrupts too", path = "showReady" },
			{ type = "toggle", label = "Only in a group", path = "groupOnly" },
			{ type = "toggle", label = "Hide in raids", path = "hideInRaid" },
			{ type = "toggle", label = "Raid marker of the kicked mob", path = "showMark", hidden = barMode },
			{ type = "toggle", label = "Show icon", path = "showIcon", hidden = barMode },
			{ type = "toggle", label = "Show timer", path = "showTimer" },
		}),
		Card("Bars", Join(G.Bar("bar"), {
			{ type = "dropdown", label = "Grow", path = "growth", values = m.GROWTH },
			{ type = "slider", label = "Spacing", path = "spacing", min = 0, max = 20, step = 1 },
			{ type = "slider", label = "Gap between icon and bar", path = "iconGap", min = 0, max = 10, step = 1 },
		}), { hidden = barMode }),
		Card("Icons on party frames", Join(G.Icon("icon", { square = true }), {
			{ type = "dropdown", label = "Side", path = "partySide", values = m.SIDES },
			{ type = "slider", label = "Gap", path = "partyGap", min = 0, max = 20, step = 1 },
			{ type = "description", width = "full", text = "Placed beside each member's EllesmereUI party frame; without EllesmereUI they stack at the position below." },
		}), { hidden = iconMode }),
		Card("Border", G.Border("border")),
		Card("Cooldown flash", Join(G.Glow("flash", { toggle = "Flash when a member's interrupt goes on cooldown" }), {
			{ type = "toggle", label = "Blinking fill over the row", path = "flashFill" },
			{ type = "color", label = "Fill color", path = "flashFillColor", hasAlpha = true },
			{ type = "slider", label = "Flash for (seconds)", path = "flashSecs", min = 0.5, max = 6, step = 0.5 },
			{ type = "toggle", label = "Also for your own interrupt", path = "flashSelf" },
		})),
		Card("Name text", G.Font("nameText"), { hidden = barMode }),
		Card("Timer text", G.Font("timerText")),
		Card("Detection", {
			{ type = "toggle", label = "Watch interrupted casts", path = "observe",
				tip = "Starts a member's bar when an enemy's cast is interrupted, even when the client hides who did it." },
			{ type = "toggle", label = "Confirm with the damage meter", path = "meterConfirm",
				tip = "Pairs each interrupted cast with the damage meter's interrupt list to tell who kicked." },
			{ type = "slider", label = "Unknown interrupt cooldown", path = "partyCd", min = 5, max = 60, step = 1 },
			{ type = "button", text = "Print status", onClick = function() m:PrintStatus() end },
		}),
		Card("Position", G.Position("position")),
	}
end)

--------------------------------------------------------------------------------
-- Party Cooldowns: the spell list is one row per spell of the chosen spec
--------------------------------------------------------------------------------
local PCD_ROW_H = 28

local function PartyCDRows(parent, ctx, m, state)
	local f = CreateFrame("Frame", nil, parent)
	f.rows = {}
	f.height = PCD_ROW_H
	f:SetHeight(PCD_ROW_H)

	local function Row(i)
		local r = f.rows[i]
		if r then return r end
		r = CreateFrame("Frame", nil, f)
		r:SetHeight(PCD_ROW_H - 2)
		r.bg = O:Rect(r, "control", "BACKGROUND")
		r.bg:SetAllPoints()
		r.bg:SetAlpha(i % 2 == 0 and 0.35 or 0.6)
		r.toggle = CreateFrame("Button", nil, r)
		r.toggle:SetSize(30, 16)
		r.toggle:SetPoint("LEFT", 6, 0)
		r.switch = O.Switch(r.toggle)
		r.switch:SetAllPoints()
		r.toggle:SetScript("OnClick", function()
			m:SetSpellShown(state.spec, r.spell, r.def.off)
			ctx:Changed()
		end)
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(18, 18)
		r.icon:SetPoint("LEFT", r.toggle, "RIGHT", 8, 0)
		r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.name = O:Text(r, O.SIZE.text, "text")
		r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
		r.down = O:IconButton(r, "chevron", 22, "Move down", function()
			if m:MoveSpell(state.spec, r.spell, 1) then ctx:Changed() end
		end)
		r.down:SetPoint("RIGHT", -2, 0)
		r.up = O:IconButton(r, "chevron", 22, "Move up", function()
			if m:MoveSpell(state.spec, r.spell, -1) then ctx:Changed() end
		end)
		r.up.icon:SetTexCoord(0, 1, 1, 0)
		r.up:SetPoint("RIGHT", r.down, "LEFT", -2, 0)
		r.secs = O:Text(r, O.SIZE.small, "muted")
		r.secs:SetText("s")
		r.secs:SetPoint("RIGHT", r.up, "LEFT", -8, 0)
		r.cd = CreateFrame("EditBox", nil, r)
		r.cd:SetSize(50, 20)
		r.cd:SetPoint("RIGHT", r.secs, "LEFT", -4, 0)
		r.cd:SetAutoFocus(false)
		r.cd:SetNumeric(true)
		r.cd:SetFont(O:FontPath(), O.SIZE.small, "")
		r.cd:SetTextColor(O:Color("text"))
		r.cd:SetJustifyH("CENTER")
		O:Skin(r.cd, "control", "controlLine")
		local function commit()
			local n = tonumber(r.cd:GetText() or "")
			r.cd:ClearFocus()
			if n and n > 0 then m:SetCd(state.spec, r.spell, n) end
			ctx:Changed()
		end
		r.cd:SetScript("OnEnterPressed", commit)
		r.cd:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		r.name:SetPoint("RIGHT", r.cd, "LEFT", -8, 0)
		f.rows[i] = r
		return r
	end

	function f:Measure()
		local n = #m:SpecSpells(state.spec)
		self.height = math.max(1, n) * PCD_ROW_H
		self:SetHeight(self.height)
		return self.height
	end

	function f:Refresh()
		local list = m:SpecSpells(state.spec)
		for i, def in ipairs(list) do
			local r = Row(i)
			r.def, r.spell = def, def.id
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", 0, -(i - 1) * PCD_ROW_H)
			r:SetPoint("TOPRIGHT", 0, -(i - 1) * PCD_ROW_H)
			r.icon:SetTexture(XUI.GetSpellIcon(def.show or def.id))
			r.name:SetText(XUI.GetSpellName(def.id))
			r.switch:SetState(not def.off, false)
			r.icon:SetDesaturated(def.off)
			if not r.cd:HasFocus() then r.cd:SetText(tostring(def.cd)) end
			r.up:SetEnabled(i > 1)
			r.down:SetEnabled(i < #list)
			r:Show()
		end
		for i = #list + 1, #self.rows do self.rows[i]:Hide() end
		self:Measure()
	end
	return f
end

O:RegisterModuleOptions("PartyCDs", function(ctx, m, G)
	local state = { class = XUI.playerClass, spec = nil }
	local function ClassEntry(token)
		for _, c in ipairs(m.CLASSES) do
			if c.token == token then return c end
		end
	end
	if not ClassEntry(state.class) then state.class = m.CLASSES[1].token end
	state.spec = ClassEntry(state.class).specs[1]

	local function classValues()
		local out = {}
		for _, c in ipairs(m.CLASSES) do
			out[#out + 1] = { value = c.token, text = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.token]) or c.token }
		end
		out[#out + 1] = { value = "RACE", text = "Racials (every class)" }
		return out
	end
	local function specValues()
		local out = {}
		if state.class == "RACE" then return { { value = "race", text = "Racials" } } end
		for _, id in ipairs(ClassEntry(state.class).specs) do
			local ok, _, name = pcall(GetSpecializationInfoByID, id)
			out[#out + 1] = { value = id, text = ok and name or ("Spec " .. id) }
		end
		return out
	end
	local function noEui() return not (XUI.EUI and XUI.EUI.Module("EllesmereUIRaidFrames")) end
	local function loose() return noEui() or not m.db.attach end

	return {
		Card("Who", {
			{ type = "toggle", label = "Show your own row", path = "showSelf" },
			{ type = "toggle", label = "Only while in a group", path = "groupOnly" },
			{ type = "description", width = "full",
				text = "Five-player groups only: in a raid the rows are hidden. Your own row follows your casts; the others follow their buffs, which the game still lets this read inside a key." },
		}),
		Card("Placement", {
			{ type = "toggle", label = "Beside EllesmereUI's party frames", path = "attach", disabled = noEui, width = "full",
				tip = "Off, or without EllesmereUI's party frames, the rows form one block you place yourself." },
			{ type = "dropdown", label = "Side", path = "side", values = m.SIDES, disabled = loose },
			{ type = "slider", label = "Distance", path = "offX", min = -40, max = 40, step = 1, disabled = loose },
			{ type = "slider", label = "Shift along", path = "offY", min = -40, max = 40, step = 1, disabled = loose },
			{ type = "dropdown", label = "Block grows", path = "growth", values = m.GROWTH },
			{ type = "slider", label = "Space between rows", path = "rowSpacing", min = 0, max = 30, step = 1 },
		}),
		Card("Icons", Join({
			{ type = "slider", label = "Space between icons", path = "spacing", min = 0, max = 20, step = 1 },
		}, G.Icon("icon", { square = true }))),
		Card("Border", G.Border("border")),
		Card("Glow while the effect is up", G.Glow("glow", { toggle = "Glow while the buff is up" })),
		Card("Timer text", Join({
			{ type = "toggle", label = "Show the countdown", path = "showTimer", width = "full" },
		}, G.Font("timerText", { color = true }))),
		Card("Name text", Join({
			{ type = "toggle", label = "Show names (block mode)", path = "showName", width = "full" },
		}, G.Font("nameText"))),
		Card("Spells", {
			{ type = "description", width = "full",
				text = "What each class and spec shows, in this order. Switch a spell off, change its cooldown length (seconds), or move it." },
			{ type = "dropdown", label = "Class", values = classValues,
				get = function() return state.class end,
				set = function(_, v)
					state.class = v
					state.spec = v == "RACE" and "race" or ClassEntry(v).specs[1]
				end },
			{ type = "tabs", width = "full", values = specValues,
				get = function() return state.spec end,
				set = function(_, v) state.spec = v end },
			{ type = "custom", width = "full", build = function(parent, c) return PartyCDRows(parent, c, m, state) end },
		}),
		Card("Position", G.Position("position")),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("CoTank", function(ctx, m, G)
	local function noDebuffs() return not m.db.debuffs.enabled end
	return {
		Card("Who", {
			{ type = "toggle", label = "Only while you are tank-specced", path = "tankOnly", width = "full" },
			{ type = "input", label = "Always show this player", path = "pinName",
				tip = "Leave empty to find the other tank automatically." },
			{
				type = "button", text = function() return m.testMode and "Stop test" or "Test on your target" end,
				tip = "Puts the live bar and the real debuff row on your target (or you), no raid needed.",
				onClick = function() m:SetTest(not m.testMode) end,
				disabled = function() return not m.running end,
			},
		}),
		Card("Bar", G.Bar("bar")),
		Card("Border", G.Border("border")),
		Card("Name text", G.Font("nameText", { toggle = "Show name", anchor = true })),
		Card("Health text", G.Font("healthText", { toggle = "Show health %", anchor = true })),
		Card("Debuffs", {
			{ type = "toggle", label = "Show debuffs", path = "debuffs.enabled" },
			{ type = "toggle", label = "Boss and role debuffs only", path = "debuffs.bossOnly", disabled = noDebuffs },
			{ type = "slider", label = "How many", path = "debuffs.max", min = 1, max = 10, step = 1, disabled = noDebuffs },
			{ type = "slider", label = "Spacing", path = "debuffs.spacing", min = 0, max = 20, step = 1, disabled = noDebuffs },
			{ type = "dropdown", label = "Grow", path = "debuffs.grow", values = m.GROW, disabled = noDebuffs },
			{ type = "dropdown", label = "Place at the bar's", path = "debuffs.attach", values = XUI.Style.ANCHORS, disabled = noDebuffs,
				tip = "Where on the bar the row sits, outside it: Left or Right beside the bar, Top or Bottom above or below it, a corner above or below it. Pair Left with Grow: Left, Right with Grow: Right." },
			{ type = "slider", label = "Offset X", path = "debuffs.x", min = -100, max = 100, step = 1, disabled = noDebuffs },
			{ type = "slider", label = "Offset Y", path = "debuffs.y", min = -100, max = 100, step = 1, disabled = noDebuffs },
			{ type = "toggle", label = "Dispel-color border", path = "debuffs.dispelBorder", disabled = noDebuffs },
			{ type = "slider", label = "Border thickness (pixels)", path = "debuffs.borderSize", min = 1, max = 6, step = 1, disabled = noDebuffs },
			{ type = "toggle", label = "Tooltip on hover", path = "debuffs.tooltip", disabled = noDebuffs },
		}),
		Card("Debuff icons", G.Icon("debuffIcon", { square = true }), { hidden = noDebuffs }),
		Card("Debuff timer", G.Font("durText", { toggle = "Show timer", anchor = true }), { hidden = noDebuffs }),
		Card("Debuff stacks", G.Font("stackText", { toggle = "Show stacks", anchor = true }), { hidden = noDebuffs }),
		Card("Position", G.Position("position")),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("Shroud", function(ctx, m, G)
	return {
		Card("Bars", {
			{ type = "toggle", label = "Mass Invisibility", path = "showMassInvis" },
			{ type = "color", label = "Color", path = "miColor" },
			{ type = "toggle", label = "Shroud of Concealment", path = "showShroud" },
			{ type = "color", label = "Color", path = "color" },
			{ type = "toggle", label = "Your own Shroud when you are the rogue", path = "selfBar", width = "full" },
		}),
		Card("Bar", Join(G.Bar("bar"), {
			{ type = "toggle", label = "Show icon", path = "showIcon" },
			{ type = "slider", label = "Gap between icon and bar", path = "iconGap", min = 0, max = 10, step = 1 },
			{ type = "slider", label = "Gap between bars", path = "gap", min = 0, max = 20, step = 1 },
		})),
		Card("Border", G.Border("border")),
		Card("Name text", G.Font("nameText", { toggle = "Show name" })),
		Card("Timer text", G.Font("timerText", { toggle = "Show timer" })),
		Card("Position", G.Position("position")),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("CCTracker", function(ctx, m, G)
	return {
		Card("Bars", {
			{ type = "dropdown", label = "Stacking", path = "mode", values = m.MODES },
			{ type = "toggle", label = "Only spells your group can cast", path = "classRows",
				hidden = function() return m.db.mode == "each" end },
			{ type = "dropdown", label = "Grow", path = "grow", values = m.GROW },
			{ type = "slider", label = "Spacing", path = "spacing", min = 0, max = 20, step = 1 },
			{ type = "dropdown", label = "Icon", path = "iconSide", values = m.ICON_SIDES },
			{ type = "slider", label = "Gap between icon and bar", path = "iconGap", min = 0, max = 10, step = 1 },
			{ type = "slider", label = "Enemies tracked at most", path = "maxUnits", min = 1, max = 40, step = 1 },
		}),
		Card("Bar", G.Bar("bar")),
		Card("Border", G.Border("border")),
		Card("Name text", Join(G.Font("nameText", { toggle = "Show name" }), {
			{ type = "dropdown", label = "Align", path = "nameAlign", values = m.NAME_ALIGNS },
		})),
		Card("Timer text", Join(G.Font("timerText", { toggle = "Show timer" }), {
			{ type = "dropdown", label = "Timer side", path = "timerSide", values = m.TIMER_SIDES },
			{ type = "toggle", label = "Tenths of a second", path = "tenths" },
		})),
		Card("Sound", {
			{ type = "description", width = "full", text = "Played by the game when a listed debuff lands - once per enemy, so the Effects channel is the default." },
			{ type = "dropdown", label = "Sound", path = "sound", media = "sound", filesOnly = true },
			{ type = "dropdown", label = "Channel", path = "soundChannel", values = XUI.Audio.CHANNELS },
			{ type = "dropdown", label = "For", path = "soundFrom", values = m.SOUND_FROM },
			{ type = "button", text = "Test", onClick = function() m:PlayTest() end },
		}),
		Card("Spells", {
			{ type = "description", width = "full", text = "The DEBUFF's spell ID, which is not always the cast's (Binding Shot's stun is 117526). Order is the bars' order." },
			{
				type = "spellList", path = "spells", colors = "colors", labels = "labels", reorder = true, width = "full",
				defaultColor = function(id) return m:SpellColor(id) end,
				defaultLabel = function(id) local b = m.BUILTIN[id] return b and b[1] or nil end,
			},
		}),
		Card("Position", G.Position("position")),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("AggroCheck", function(ctx, m, G)
	return {
		Card("Warning", {
			{ type = "input", label = "Text", path = "text" },
			{ type = "color", label = "Color", path = "color" },
			{ type = "toggle", label = "Pulse", path = "pulse" },
			{ type = "toggle", label = "Only in Mythic+ keys", path = "keyOnly" },
		}),
		Card("Text", G.Font("font")),
		Card("Alert", G.Alert("alert")),
		Card("Position", G.Position("position")),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("InstanceKeys", function(ctx, m, G)
	return {
		Card("Show", {
			{ type = "description", width = "full",
				text = "Shown when you enter a Mythic dungeon: the group members whose keystone is for it. It goes away when you leave, when a boss fight or the key starts. Members are only listed if they run an addon that shares keystones (BigWigs, EllesmereUI or XerionUI)." },
			{ type = "toggle", label = "Title", path = "showTitle" },
			{ type = "toggle", label = "Hide in combat", path = "hideInCombat",
				tip = "Hidden while you fight, back ten seconds after (three fights at most)." },
			{ type = "toggle", label = "Show every player's key", path = "showAll", width = "full",
				tip = "Also lists keys that belong to other dungeons, dimmed and with the dungeon's name." },
			{ type = "dropdown", label = "Align", path = "align", values = XUI.Style.JUSTIFY },
			{ type = "color", label = "Other dungeon color", path = "otherColor", hasAlpha = false,
				disabled = function() return not m.db.showAll end },
		}),
		Card("Text", G.Font("text", { color = true })),
		Card("Position", G.Position("position")),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("Bloodlust", function(ctx, m, G)
	return {
		Card("Alert when lust is ready again", G.Alert("alert", { test = function() m:TestAlert() end })),
	}
end)
