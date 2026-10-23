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
				type = "description",
				text = function()
					if IS121() then return "On this client the sound is played by the game itself for the spells below; text to speech is not available here." end
					return "Plays when a new external lands on you."
				end,
			} },
			G.Alert("alert", { test = function() m:TestAlert() end })
		)),
		Card("Sound for these spells", {
			{ type = "spellList", path = "soundSpells" },
		}, { hidden = function() return not IS121() end }),
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
			{ type = "description", text = "Placed beside each member's EllesmereUI party frame; without EllesmereUI they stack at the position below." },
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
			{ type = "description",
				text = "Five-player groups only: in a raid the rows are hidden. Your own row follows your casts; the others follow their buffs, which the game still lets this read inside a key." },
		}),
		Card("Placement", {
			{ type = "toggle", label = "Beside EllesmereUI's party frames", path = "attach", disabled = noEui,
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
			{ type = "toggle", label = "Show the countdown", path = "showTimer" },
		}, G.Font("timerText", { color = true }))),
		Card("Name text", Join({
			{ type = "toggle", label = "Show names (block mode)", path = "showName" },
		}, G.Font("nameText"))),
		Card("Spells", {
			{ type = "description",
				text = "What each class and spec shows, in this order. Switch a spell off, change its cooldown length (seconds), or move it." },
			{ type = "dropdown", label = "Class", values = classValues,
				get = function() return state.class end,
				set = function(_, v)
					state.class = v
					state.spec = v == "RACE" and "race" or ClassEntry(v).specs[1]
				end },
			{ type = "tabs", values = specValues,
				get = function() return state.spec end,
				set = function(_, v) state.spec = v end },
			{ type = "custom", build = function(parent, c) return PartyCDRows(parent, c, m, state) end },
		}),
	}
end)

--------------------------------------------------------------------------------
-- Party Stops: one list of spells per bar
--------------------------------------------------------------------------------
local function StopRows(parent, ctx, m, g)
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
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(18, 18)
		r.icon:SetPoint("LEFT", 8, 0)
		r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.name = O:Text(r, O.SIZE.text, "text")
		r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
		r.remove = O:IconButton(r, "close", 22, "Remove from this bar", function()
			m:RemoveSpell(g, r.spell)
			ctx:Changed()
		end)
		r.remove:SetPoint("RIGHT", -2, 0)
		r.down = O:IconButton(r, "chevron", 22, "Move down", function()
			if m:MoveSpell(g, r.spell, 1) then ctx:Changed() end
		end)
		r.down:SetPoint("RIGHT", r.remove, "LEFT", -2, 0)
		r.up = O:IconButton(r, "chevron", 22, "Move up", function()
			if m:MoveSpell(g, r.spell, -1) then ctx:Changed() end
		end)
		r.up.icon:SetTexCoord(0, 1, 1, 0)
		r.up:SetPoint("RIGHT", r.down, "LEFT", -2, 0)
		r.name:SetPoint("RIGHT", r.up, "LEFT", -8, 0)
		f.rows[i] = r
		return r
	end

	function f:Measure()
		local n = #m:BarSpells(g)
		self.height = math.max(1, n) * PCD_ROW_H
		self:SetHeight(self.height)
		return self.height
	end

	function f:Refresh()
		local list = m:BarSpells(g)
		for i, e in ipairs(list) do
			local r = Row(i)
			r.spell = e.id
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", 0, -(i - 1) * PCD_ROW_H)
			r:SetPoint("TOPRIGHT", 0, -(i - 1) * PCD_ROW_H)
			r.icon:SetTexture(XUI.GetSpellIcon(e.id))
			local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
			local label = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[e.class]) or e.class
			r.name:SetText(XUI.GetSpellName(e.id) .. "  |c" .. (c and c.colorStr or "ffffffff") .. label .. "|r")
			r.up:SetEnabled(i > 1)
			r.down:SetEnabled(i < #list)
			r:Show()
		end
		for i = #list + 1, #self.rows do self.rows[i]:Hide() end
		self:Measure()
	end
	return f
end

local function StopBarCards(m, G, g)
	local k = "bar"
	local function P(field) return k .. "." .. field end
	local function namesOff() return not m.db[k].showNames end
	return {
		Card("Layout", Join({
			{ type = "dropdown", label = "Direction", path = P("orientation"), values = m.ORIENTATION },
			{ type = "slider", label = "Lines", path = P("lines"), min = 1, max = 8, step = 1,
				tip = "Rows when horizontal, columns when vertical. The icons are spread evenly over them." },
			{ type = "toggle", label = "Fill from the other end", path = P("reverse"),
				tip = "Horizontal: icons run to the left instead of the right. Vertical: upwards instead of downwards." },
			{ type = "toggle", label = "Stack the lines the other way", path = P("stackReverse"),
				tip = "Horizontal: new rows go up instead of down. Vertical: new columns go left instead of right." },
			{ type = "toggle", label = "Center each line", path = P("center") },
			{ type = "slider", label = "Space between icons", path = P("spacing"), min = -1, max = 30, step = 1 },
		}, G.Icon(P("icon"), { square = true }))),
		Card("Border", G.Border(P("border"))),
		Card("Timer text", G.Font(P("timerText"), { color = true })),
		Card("Names", Join({
			{ type = "toggle", label = "Member name in class color", path = P("showNames") },
			{ type = "dropdown", label = "Name place", path = P("namePos"), values = m.NAMEPOS, disabled = namesOff },
			{ type = "slider", label = "Name letters (0 = whole name)", path = P("nameLen"), min = 0, max = 12, step = 1, disabled = namesOff },
		}, G.Font(P("nameText")))),
		Card("Position", G.Position(P("position"))),
		Card("Spells", {
			{ type = "custom", build = function(parent, c) return StopRows(parent, c, m, g) end },
			{ type = "dropdown", label = "Add a spell",
				values = function()
					local out, have = { { value = 0, text = "Choose a spell" } }, {}
					for _, e in ipairs(m:BarSpells(g)) do have[e.id] = true end
					for _, e in ipairs(m:Catalogue()) do
						if not have[e.id] then
							local cls = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[e.class]) or e.class
							out[#out + 1] = { value = e.id, text = XUI.GetSpellName(e.id) .. " (" .. cls .. ")" }
						end
					end
					return out
				end,
				get = function() return 0 end,
				set = function(c, v)
					if type(v) == "number" and v ~= 0 then
						m:AddSpell(g, v)
						c:Changed()
					end
				end },
		}),
	}
end

O:RegisterModuleOptions("PartyStops", function(ctx, m, G)
	local cards = {
		Card("Who", {
			{ type = "toggle", label = "Include your own stops", path = "showSelf" },
			{ type = "toggle", label = "Only while in a group", path = "groupOnly" },
			{ type = "toggle", label = "Only in dungeons", path = "dungeonOnly" },
			{ type = "toggle", label = "Read party talents for cooldown lengths", path = "talents",
				tip = "Inspects party members in a dungeon so a talent that shortens a stop is counted, and a stop they did not take is left out." },
			{ type = "slider", label = "Enemies watched", path = "maxUnits", min = 4, max = 20, step = 1,
				tip = "How many enemy nameplates in combat are watched for a stop landing. Fewer is lighter." },
			{ type = "description",
				text = "Five-player groups only. Your own stops follow your casts; the others are noticed by the debuff a stop leaves on an enemy, which the game still lets this read inside a key. All stops share one block; set its layout below." },
		}),
	}
	for _, c in ipairs(StopBarCards(m, G, 1)) do cards[#cards + 1] = c end
	return cards
end)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
O:RegisterModuleOptions("CoTank", function(ctx, m, G)
	local function noDebuffs() return not m.db.debuffs.enabled end
	return {
		Card("Who", {
			{ type = "toggle", label = "Only while you are tank-specced", path = "tankOnly" },
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
			{ type = "toggle", label = "Your own Shroud when you are the rogue", path = "selfBar" },
		}),
		Card("Bar", Join(G.Bar("bar"), {
			{ type = "toggle", label = "Show icon", path = "showIcon" },
			{ type = "slider", label = "Gap between icon and bar", path = "iconGap", min = 0, max = 10, step = 1 },
			{ type = "slider", label = "Gap between bars", path = "gap", min = 0, max = 20, step = 1 },
		})),
		Card("Border", G.Border("border")),
		Card("Name text", G.Font("nameText", { toggle = "Show name" })),
		Card("Timer text", G.Font("timerText", { toggle = "Show timer" })),
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
	}
end)

--------------------------------------------------------------------------------
-- Auto NPC Dialog: the dialogs seen in a dungeon, with a
-- switch to pick it and one to answer its "are you sure?" box.
local GOSSIP_HEAD_H, GOSSIP_ROW_H = 30, 44

StaticPopupDialogs.XERIONUI_BLACKLIST_NPC = {
	text = "Blacklist %s?\n\nThe NPC and all its dialogs are hidden in every dungeon and no longer recorded. You can undo it under Dungeons > All dungeons.",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, fn) fn() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function ConfirmBlacklist(name, fn)
	StaticPopup_Show("XERIONUI_BLACKLIST_NPC", name or "this NPC", nil, fn)
end

-- mode: nil = the dialogs (of one dungeon with zoneOnly, else all), "blacklist" = the
-- blacklisted NPCs, "several" = NPCs seen in more than one dungeon (candidates)
local function GossipList(parent, ctx, m, zoneOnly, mode)
	local f = CreateFrame("Frame", nil, parent)
	f.height = 40
	f.heads, f.rows = {}, {}
	f.empty = O:Text(f, O.SIZE.text, "muted")
	f.empty:SetPoint("TOPLEFT", 0, -4)
	f.empty:SetPoint("TOPRIGHT", 0, -4)
	f.empty:SetJustifyH("LEFT")
	f.empty:SetWordWrap(true)

	local function Changed() ctx:Changed("options") end

	local function Head(i)
		local h = f.heads[i]
		if h then return h end
		h = CreateFrame("Frame", nil, f)
		h:SetHeight(GOSSIP_HEAD_H)
		h.name = O:Text(h, O.SIZE.text, "text")
		h.name:SetPoint("BOTTOMLEFT", 0, 6)
		h.info = O:Text(h, O.SIZE.small, "muted")
		h.info:SetPoint("BOTTOMRIGHT", 0, 7)
		h.line = O:Rect(h, "line", "ARTWORK")
		h.line:SetHeight(1)
		h.line:SetPoint("BOTTOMLEFT")
		h.line:SetPoint("BOTTOMRIGHT")
		f.heads[i] = h
		return h
	end

	local function Row(i)
		local r = f.rows[i]
		if r then return r end
		r = CreateFrame("Frame", nil, f)
		r:SetHeight(GOSSIP_ROW_H - 2)
		r.bg = O:Rect(r, "control", "BACKGROUND")
		r.bg:SetAllPoints()
		r.bg:SetAlpha(0.45)

		r.pick = CreateFrame("Button", nil, r)
		r.pick:SetPoint("TOPLEFT")
		r.pick:SetPoint("BOTTOMLEFT")
		r.pick:SetWidth(44)
		r.pick.switch = O.Switch(r.pick)
		r.pick.switch:SetPoint("LEFT", 8, 0)
		r.pick:SetScript("OnClick", function()
			m:SetPicked(r.entry.id, not r.entry.picked)
			Changed()
		end)
		O:Tooltip(r.pick, "Pick automatically")

		r.forget = O:IconButton(r, "close", 22, "Forget this dialog", function()
			m:Forget(r.entry.id)
			Changed()
		end)
		r.forget:SetPoint("RIGHT", -6, 0)

		-- hides the NPC in every dungeon (Blacklist tab)
		r.ban = O:Button(r, "Blacklist", 70, function()
			local e = r.entry
			ConfirmBlacklist(e.npc or ("NPC " .. tostring(e.npcID)), function()
				m:Blacklist(e.npcID, e.npc)
				Changed()
			end)
		end)
		O:Tooltip(r.ban, "Blacklist this NPC", "Hides the NPC and all its dialogs in every dungeon. Undo it under Dungeons > All dungeons.")

		r.confirm = CreateFrame("Button", nil, r)
		r.confirm:SetSize(86, GOSSIP_ROW_H - 2)
		r.confirm.switch = O.Switch(r.confirm)
		r.confirm.switch:SetPoint("LEFT", 0, 0)
		r.confirm.label = O:Text(r.confirm, O.SIZE.small, "label")
		r.confirm.label:SetPoint("LEFT", r.confirm.switch, "RIGHT", 6, 0)
		r.confirm.label:SetText("Confirm")
		r.confirm:SetScript("OnClick", function()
			m:SetConfirm(r.entry.id, not r.entry.confirm)
			Changed()
		end)
		r.confirm:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
			GameTooltip:SetText("Answer \"are you sure?\"")
			GameTooltip:AddLine("Also accepts the confirmation box this option opens. Only used when the option is picked automatically.", 1, 1, 1, true)
			local t = r.entry and r.entry.confirmText
			if t then GameTooltip:AddLine("\"" .. t .. "\"", 0.7, 0.7, 0.7, true) end
			GameTooltip:Show()
		end)
		r.confirm:SetScript("OnLeave", function() GameTooltip:Hide() end)

		r.text = O:Text(r, O.SIZE.text, "text")
		r.text:SetPoint("TOPLEFT", 52, -7)
		r.text:SetJustifyH("LEFT")
		r.text:SetWordWrap(false)
		r.sub = O:Text(r, O.SIZE.small, "muted")
		r.sub:SetPoint("TOPLEFT", 52, -25)
		r.sub:SetJustifyH("LEFT")
		r.sub:SetWordWrap(false)
		f.rows[i] = r
		return r
	end

	-- one row of the blacklist tab: an NPC and a button that takes it off again
	f.brows = {}
	local function BlackRow(i)
		local r = f.brows[i]
		if r then return r end
		r = CreateFrame("Frame", nil, f)
		r:SetHeight(GOSSIP_ROW_H - 2)
		r.bg = O:Rect(r, "control", "BACKGROUND")
		r.bg:SetAllPoints()
		r.bg:SetAlpha(0.45)
		r.remove = O:IconButton(r, "close", 22, "Remove from the blacklist", function()
			m:Unblacklist(r.index)
			Changed()
		end)
		r.remove:SetPoint("RIGHT", -6, 0)
		r.name = O:Text(r, O.SIZE.text, "text")
		r.name:SetPoint("LEFT", 12, 5)
		r.name:SetPoint("RIGHT", r.remove, "LEFT", -8, 0)
		r.sub = O:Text(r, O.SIZE.small, "muted")
		r.sub:SetPoint("LEFT", 12, -9)
		r.sub:SetPoint("RIGHT", r.remove, "LEFT", -8, 0)
		f.brows[i] = r
		return r
	end

	local function Fill(r, e)
		r.entry = e
		r.pick.switch:SetState(e.picked, false)
		if e.text then
			r.text:SetText("\"" .. e.text .. "\"")
			r.text:SetTextColor(O:Color(e.picked and "text" or "label"))
		else
			r.text:SetText("Text not seen yet - talk to the NPC once")
			r.text:SetTextColor(O:Color("faint"))
		end
		local sub = { e.npc or "NPC name saved on first visit", "ID " .. e.id }
		if e.builtin then sub[#sub + 1] = "built-in" end
		r.sub:SetText(table.concat(sub, "  -  "))
		r.confirm.switch:SetState(e.confirm, false)
		r.confirm:SetAlpha(e.picked and 1 or 0.4) -- only matters once the option is picked
		r.forget:SetShown(not e.builtin)
		local canBan = e.npc ~= nil or e.npcID ~= nil
		r.ban:SetShown(canBan)
		r.ban:ClearAllPoints()
		if e.builtin then r.ban:SetPoint("RIGHT", -6, 0) else r.ban:SetPoint("RIGHT", r.forget, "LEFT", -4, 0) end
		r.confirm:ClearAllPoints()
		if canBan then
			r.confirm:SetPoint("RIGHT", r.ban, "LEFT", -8, 0)
		elseif e.builtin then
			r.confirm:SetPoint("RIGHT", -6, 0)
		else
			r.confirm:SetPoint("RIGHT", r.forget, "LEFT", -8, 0)
		end
		r.text:SetPoint("RIGHT", r.confirm, "LEFT", -8, 0)
		r.sub:SetPoint("RIGHT", r.confirm, "LEFT", -8, 0)
	end

	-- NPCs seen in several dungeons, each with a button that blacklists it
	f.srows = {}
	local function SeveralRow(i)
		local r = f.srows[i]
		if r then return r end
		r = CreateFrame("Frame", nil, f)
		r:SetHeight(GOSSIP_ROW_H - 2)
		r.bg = O:Rect(r, "control", "BACKGROUND")
		r.bg:SetAllPoints()
		r.bg:SetAlpha(0.45)
		r.ban = O:Button(r, "Blacklist", 70, function()
			local n = r.npc
			ConfirmBlacklist(n.name or ("NPC " .. tostring(n.id)), function()
				m:Blacklist(n.id, n.name)
				Changed()
			end)
		end)
		r.ban:SetPoint("RIGHT", -6, 0)
		r.name = O:Text(r, O.SIZE.text, "text")
		r.name:SetPoint("LEFT", 12, 5)
		r.name:SetPoint("RIGHT", r.ban, "LEFT", -8, 0)
		r.sub = O:Text(r, O.SIZE.small, "muted")
		r.sub:SetPoint("LEFT", 12, -9)
		r.sub:SetPoint("RIGHT", r.ban, "LEFT", -8, 0)
		f.srows[i] = r
		return r
	end

	local function RefreshSeveral(self)
		for k = 1, #self.heads do self.heads[k]:Hide() end
		for k = 1, #self.rows do self.rows[k]:Hide() end
		for k = 1, #self.brows do self.brows[k]:Hide() end
		local list = m:CrossDungeonNPCs()
		for i, npc in ipairs(list) do
			local r = SeveralRow(i)
			r.npc = npc
			r.name:SetText(npc.name or ("NPC " .. npc.id))
			r.sub:SetText(("Seen in %d dungeons: %s"):format(#npc.zones, table.concat(npc.zones, ", ")))
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", 0, -(i - 1) * GOSSIP_ROW_H)
			r:SetPoint("TOPRIGHT", 0, -(i - 1) * GOSSIP_ROW_H)
			r:Show()
		end
		for k = #list + 1, #self.srows do self.srows[k]:Hide() end
		if #list == 0 then
			self.empty:SetText("No NPC has shown up in more than one dungeon yet. When one does, it is listed here so you can hide it.")
			self.empty:Show()
			self.height = 40
		else
			self.empty:Hide()
			self.height = #list * GOSSIP_ROW_H
		end
	end

	-- the blacklist: the NPCs hidden in every dungeon
	local function RefreshBlacklist(self)
		for k = 1, #self.srows do self.srows[k]:Hide() end
		for k = 1, #self.heads do self.heads[k]:Hide() end
		for k = 1, #self.rows do self.rows[k]:Hide() end
		local list = m.db.blacklist or {}
		for i, entry in ipairs(list) do
			local r = BlackRow(i)
			r.index = i
			r.name:SetText(entry.name or ("NPC " .. entry.id))
			r.sub:SetText(entry.id and ("NPC ID " .. entry.id) or "matched by name")
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", 0, -(i - 1) * GOSSIP_ROW_H)
			r:SetPoint("TOPRIGHT", 0, -(i - 1) * GOSSIP_ROW_H)
			r:Show()
		end
		for k = #list + 1, #self.brows do self.brows[k]:Hide() end
		if #list == 0 then
			self.empty:SetText("No NPC is blacklisted. Use the Blacklist button on an NPC's dialog under its dungeon.")
			self.empty:Show()
			self.height = 40
		else
			self.empty:Hide()
			self.height = #list * GOSSIP_ROW_H
		end
	end

	function f:Refresh()
		if mode == "blacklist" then return RefreshBlacklist(self) end
		if mode == "several" then return RefreshSeveral(self) end
		for k = 1, #self.brows do self.brows[k]:Hide() end
		for k = 1, #self.srows do self.srows[k]:Hide() end
		local list = {}
		for _, e in ipairs(m:Catalogue()) do
			if (not zoneOnly or (e.zone or O.DIALOG_NO_ZONE) == zoneOnly) then list[#list + 1] = e end
		end
		local y, nh, nr, i = 0, 0, 0, 1
		while i <= #list do
			-- one dungeon: a header, then its dialogs
			local zone, first = list[i].zone, list[i]
			local j, on = i, 0
			while j <= #list and list[j].zone == zone do
				if list[j].picked then on = on + 1 end
				j = j + 1
			end
			nh = nh + 1
			local h = Head(nh)
			h.name:SetText(zone or "Not seen in a dungeon yet")
			h.name:SetTextColor(O:Color(zone and "text" or "muted"))
			local info = {}
			if first.kind then info[#info + 1] = first.kind end
			info[#info + 1] = ("%d of %d picked"):format(on, j - i)
			h.info:SetText(table.concat(info, "  -  "))
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", 0, -y)
			h:SetPoint("TOPRIGHT", 0, -y)
			h:Show()
			y = y + GOSSIP_HEAD_H + 4
			for k = i, j - 1 do
				nr = nr + 1
				local r = Row(nr)
				Fill(r, list[k])
				r:ClearAllPoints()
				r:SetPoint("TOPLEFT", 0, -y)
				r:SetPoint("TOPRIGHT", 0, -y)
				r:Show()
				y = y + GOSSIP_ROW_H
			end
			y = y + 6
			i = j
		end
		for k = nh + 1, #self.heads do self.heads[k]:Hide() end
		for k = nr + 1, #self.rows do self.rows[k]:Hide() end
		if #list == 0 then
			self.empty:SetText("No dialogs seen yet. Talk to an NPC inside a dungeon and its options show up under that dungeon.")
			self.empty:Show()
			y = 40
		else
			self.empty:Hide()
		end
		self.height = y
	end

	function f:Measure()
		self:SetHeight(self.height)
		return self.height
	end

	-- a dialog seen while the window is open shows up straight away
	-- keyed by ctx, so a rebuilt page replaces its listener instead of piling up
	XUI:On("GossipSeen", ctx, function() if ctx.page then ctx.page:RefreshSoon() end end)
	return f
end

-- The items of the Dialogs card, shared by the module's page and a dungeon's page.
-- zone = one dungeon, nil = all. NPCs that show up everywhere are hidden on the
-- blacklist page (Dungeons > All dungeons), not here.
local function DialogItems(m, zone)
	return {
		{ type = "description",
			text = "Every NPC dialog you open inside a dungeon or delve is listed here under its dungeon (Dungeons) or delve (Delves) and NPC. The quoted line is the option clicked for you - the step you skip. Switch it on to have it picked automatically. The Blacklist button hides the NPC in every dungeon (see Dungeons > All dungeons > NPC blacklist)." },
		{ type = "custom", build = function(parent, c) return GossipList(parent, c, m, zone) end },
		{ type = "button", text = "Forget unpicked",
			tip = zone and "Removes every dialog of this dungeon that is not switched on." or "Removes every listed dialog that is not switched on.",
			onClick = function(c) m:ForgetUnpicked(zone) c:Changed("options") end },
	}
end

O:RegisterModuleOptions("AutoGossip", function(ctx, m, G)
	return {
		Card("Dialogs", DialogItems(m)),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("BonusRollConfirm", function(ctx, m, G)
	return {
		Card("Confirm", {
			{ type = "toggle", label = "Ask before using a bonus roll", path = "confirmRoll" },
			{ type = "toggle", label = "Ask before passing", path = "confirmPass" },
			{ type = "toggle", label = "Show the loot specialization", path = "showSpec",
				tip = "Names the spec the roll will award for, so a wrong loot spec is noticed before the roll is gone." },
			{ type = "toggle", label = "Say what happened", path = "announce" },
		}),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("MeterReset", function(ctx, m, G)
	return {
		Card("Ask when leaving", {
			{ type = "toggle", label = "Dungeons", path = "dungeons" },
			{ type = "toggle", label = "Raids", path = "raids" },
			{ type = "toggle", label = "Scenarios", path = "scenarios" },
			{ type = "slider", label = "Delay after loading (s)", path = "delay", min = 0, max = 10, step = 1,
				tip = "Waits a moment after the loading screen so the question does not appear on top of it." },
			{ type = "toggle", label = "Say what happened", path = "announce" },
		}),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("SkipCinematics", function(ctx, m, G)
	return {
		Card("Skip", {
			{ type = "toggle", label = "Say what happened", path = "announce" },
		}),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("WorldMarkers", function(ctx, m, G)
	local markers = {}
	for id = 1, 8 do
		markers[#markers + 1] = { type = "toggle", label = m.NAMES[id], path = "use." .. id }
	end
	return {
		Card("Keys", {
			{ type = "description",
				text = "Click a key box and press the key you want. Each press of the first key places the next marker below; the second key clears every marker." },
			{ type = "keybind", label = "Place next marker", binding = m.NEXT_BINDING },
			{ type = "keybind", label = "Clear all markers", binding = m.CLEAR_BINDING },
		}),
		Card("Markers in the cycle", Join(markers, {
			{ type = "toggle", label = "Start over after clearing", path = "resetOnClear",
				tip = "Square is placed first again after you clear the markers." },
		})),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("DamageAmp", function(ctx, m, G)
	return {
		Card("Bar", {
			{ type = "description",
				text = "Murder Row, Kystia Manaheart: when one boss finishes its timed cast the other takes extra damage for 20 seconds. The bar counts the window down and shows that boss's health. Use the Test button to play it." },
			{ type = "input", label = "Label", path = "text" },
			{ type = "toggle", label = "Show health percent", path = "showPercent" },
			{ type = "color", label = "Bar color", path = "color" },
		}),
		Card("Bar size", G.Bar("bar")),
		Card("Border", G.Border("border")),
		Card("Label", G.Font("label", { color = true })),
		Card("Timer", G.Font("timer", { color = true })),
		Card("Percent", G.Font("percent", { color = true })),
		Card("Alert", G.Alert("alert")),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("ChaosBarrage", function(ctx, m, G)
	return {
		Card("Counter", {
			{ type = "description",
				text = "Murder Row, Kystia Manaheart: boxes count the bolts left in a group and a bar times the current bolt. Use the Test button to play it." },
			{ type = "toggle", label = "Show for tanks", path = "roles.TANK" },
			{ type = "toggle", label = "Show for healers", path = "roles.HEALER" },
			{ type = "toggle", label = "Show for damage dealers", path = "roles.DAMAGER" },
			{ type = "color", label = "Bolt color", path = "color", hasAlpha = true },
			{ type = "color", label = "Empty color", path = "emptyColor", hasAlpha = true },
			{ type = "slider", label = "Width", path = "width", min = 40, max = 400, step = 1 },
			{ type = "slider", label = "Box height", path = "height", min = 4, max = 40, step = 1 },
			{ type = "slider", label = "Gap", path = "gap", min = 0, max = 10, step = 1 },
		}),
		Card("Cast bar", {
			{ type = "toggle", label = "Show the bolt cast bar", path = "showCast" },
			{ type = "slider", label = "Height", path = "cast.height", min = 4, max = 40, step = 1 },
			{ type = "color", label = "Bar color", path = "cast.color" },
		}),
		Card("Border", G.Border("border")),
		Card("Timer", G.Font("castTimer", { color = true })),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("InstanceKeys", function(ctx, m, G)
	return {
		Card("Show", {
			{ type = "description",
				text = "Shown when you enter a Mythic dungeon: the group members whose keystone is for it. It goes away when you leave, when a boss fight or the key starts. Members are only listed if they run an addon that shares keystones (BigWigs, EllesmereUI or XerionUI)." },
			{ type = "toggle", label = "Title", path = "showTitle" },
			{ type = "toggle", label = "Hide in combat", path = "hideInCombat",
				tip = "Hidden while you fight, back ten seconds after (three fights at most)." },
			{ type = "toggle", label = "Show every player's key", path = "showAll",
				tip = "Also lists keys that belong to other dungeons, dimmed and with the dungeon's name." },
			{ type = "dropdown", label = "Align", path = "align", values = XUI.Style.JUSTIFY },
			{ type = "color", label = "Other dungeon color", path = "otherColor", hasAlpha = false,
				disabled = function() return not m.db.showAll end },
		}),
		Card("Text", G.Font("text", { color = true })),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("Bloodlust", function(ctx, m, G)
	return {
		Card("Alert when lust is ready again", G.Alert("alert", { test = function() m:TestAlert() end })),
	}
end)

--------------------------------------------------------------------------------
O:RegisterModuleOptions("AutoMarkTank", function(ctx, m, G)
	return {
		Card("Marker", {
			{ type = "description",
				text = "The game only lets a click place a marker, so a small button appears when your tank has none. Click it once to mark the tank. Drag it in unlock mode." },
			{ type = "dropdown", label = "Marker", path = "marker", values = m.MARKERS },
			{ type = "toggle", label = "Replace a marker the tank already has", path = "replace",
				tip = "Off: a tank that already carries a marker is left alone." },
		}),
		Card("Where", {
			{ type = "toggle", label = "In parties", path = "inParty" },
			{ type = "toggle", label = "In raids (needs lead or assist)", path = "inRaid" },
		}),
		Card("Text", G.Font("text", { color = true })),
		Card("Border", G.Border("border")),
	}
end)

--------------------------------------------------------------------------------
-- The blacklist page (Dungeons > All dungeons): the NPCs hidden in every dungeon,
-- a box to add one, and the NPCs already seen in more than one dungeon.
function O.BlacklistPage(g)
	local m = XUI:GetModule("AutoGossip")
	local mctx = O.ModuleContext(m)
	return {
		ctx = O:NewContext(function() return {} end, nil, { group = g }),
		build = function()
			return {
				O.Card("Blacklisted NPCs", {
					{ type = "description",
						text = "NPCs that turn up in many dungeons and never matter - a vendor, a bank, a quartermaster. A blacklisted NPC is hidden in every dungeon and its dialogs are no longer recorded. A dialog you have switched on keeps working and stays listed." },
					{ type = "custom", build = function(parent, c) return GossipList(parent, c, m, nil, "blacklist") end },
				}, { ctx = mctx }),
				O.Card("Seen in several dungeons", {
					{ type = "description",
						text = "NPCs whose dialogs were recorded in two or more dungeons. Blacklist the ones that do not matter." },
					{ type = "custom", build = function(parent, c) return GossipList(parent, c, m, nil, "several") end },
				}, { ctx = mctx }),
			}
		end,
	}
end

-- The "NPC dialogs" page under a dungeon: that dungeon's dialogs.
function O.DialogPage(g)
	local m = XUI:GetModule("AutoGossip")
	local zone = g.zone
	local state = {}
	local mctx = O.ModuleContext(m)
	return {
		ctx = O:NewContext(function() return state end, nil, { group = g }),
		build = function()
			local dialogs = O.Card(zone, DialogItems(m, zone))
			dialogs.ctx = mctx
			return {
				O.Card("Auto NPC Dialog", {
					{ type = "description", text = m.desc or "" },
					{ type = "toggle", label = "Enabled",
						get = function() return m.db.enabled end,
						set = function(_, on)
							m:SetEnabled(on)
							O:RefreshSidebar()
							O:RefreshPageHead()
						end },
				}, { ctx = mctx }),
				dialogs,
			}
		end,
	}
end
