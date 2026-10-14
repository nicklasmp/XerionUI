--------------------------------------------------------------------------------
-- Party Cooldowns
-- A row of cooldown icons for every party member: defensives, offensives and
-- externals of their specialization, greyed out with a countdown while they
-- are on cooldown. Beside EllesmereUI's party frames, or as a block you place.
--
-- HOW A COOLDOWN IS READ WHEN THE GAME HIDES EVERYTHING
-- In a key a party member's casts, auras and cooldowns are secret: they can be
-- handed back to the API but not compared or counted. What is left:
--   * "is this aura on the unit?" can still be asked through a one-slot
--     AuraContainer (Engine.NewSensor); the answer is a secret boolean;
--   * C_CurveUtil.EvaluateColorValueFromBoolean turns a secret boolean into
--     one of two numbers without anyone learning which;
--   * a StatusBar draws whatever value it is given, secret or not, and a
--     frame anchored to the bar's fill moves with it.
-- So the moment a buff appears, the time is stamped into a StatusBar value
-- (code = seconds since an epoch, in steps of u seconds). The bar's min/max is
-- slid every second, which scrolls a strip of numbers (cd ... 1) under a small
-- window: the timer text. A second bar moves a grey veil off the icon when the
-- timer reaches zero. Two slots take turns so a cooldown can restart.
-- Your own row is read from your own casts, which are readable.
--
-- Spells whose buff lands on somebody else (externals) are read on the other
-- members ("zone"), and a talent that swaps the spell (Avenging Wrath ->
-- Avenging Crusader) is read from the inspect data.
--
-- Spell data and approach from KiraUI-Plugin (personal use); this module is a
-- rewrite on XerionUI's own blocks.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local T = XUI.Templates
local Style = XUI.Style
local Engine = XUI.Engine
local Media = XUI.Media
local Data = XUI.PartyCDData

local M = XUI:NewModule("PartyCDs", {
	name = "Party Cooldowns",
	desc = "Defensive and offensive cooldowns of your party, even inside keys.",
	category = "group",
	icon = XUI.MEDIA_PATH .. "partycds",
	order = 31,
	defaults = {
		showSelf = false,
		groupOnly = true,
		attach = true,
		side = "RIGHT",
		offX = 4,
		offY = 0,
		growth = "DOWN",
		spacing = 2,
		rowSpacing = 6,
		showName = true,
		showTimer = true,
		icon = T.Icon(28),
		border = T.Border(),
		glow = T.Glow(true),
		timerText = T.Font(12, { color = { 1, 1, 1, 1 } }),
		nameText = T.Font(12),
		cds = {},
		off = {},
		order = {},
		position = T.Position(-320, 0),
	},
})

M.SIDES = {
	{ value = "RIGHT", text = "Right of the frame" },
	{ value = "LEFT", text = "Left of the frame" },
	{ value = "BELOW", text = "Below the frame" },
	{ value = "BELOW_CENTER", text = "Below, centered" },
	{ value = "BELOW_RIGHT", text = "Below, from the left" },
	{ value = "BELOW_LEFT", text = "Below, from the right" },
	{ value = "ABOVE", text = "Above the frame" },
	{ value = "ABOVE_CENTER", text = "Above, centered" },
	{ value = "ABOVE_RIGHT", text = "Above, from the left" },
	{ value = "ABOVE_LEFT", text = "Above, from the right" },
}
M.GROWTH = { { value = "DOWN", text = "Down" }, { value = "UP", text = "Up" } }
M.CLASSES = Data.CLASSES

local SPELLS, SPECS, CLASSES, ROLE_SPEC = Data.SPELLS, Data.SPECS, Data.CLASSES, Data.ROLE_SPEC
local IsSecret, Ask = XUI.IsSecret, XUI.Ask
local EvalBool = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
local floor, ceil, abs = math.floor, math.ceil, math.abs
local mmax, mmin = math.max, math.min
local tconcat, tsort, tremove = table.concat, table.sort, table.remove
local format = string.format

local TOKENS = { "player", "party1", "party2", "party3", "party4" }
local MAX = 5
local READ_EVERY, READS_AFTER, HOLD, KEY_HOLD = 0.2, 2, 0.5, 2
local TICK = 0.25
local CD_MIN, CD_MAX = 5, 900
local CODES, LINGER = 254, 4
local GREY = 0.5
local WHITE = [[Interface\Buttons\WHITE8X8]]

local PREVIEW = {
	{ name = "Guardian", class = "DRUID", spec = 104 },
	{ name = "Paladin", class = "PALADIN", spec = 65, race = "Dwarf" },
	{ name = "Warrior", class = "WARRIOR", spec = 71 },
	{ name = "Rogue", class = "ROGUE", spec = 261 },
	{ name = "Shaman", class = "SHAMAN", spec = 262 },
}
local PREVIEW_AT = { 0.15, 1, 0.6 }

--------------------------------------------------------------------------------
-- The value check. Everything above stands on EvaluateColorValueFromBoolean
-- handing back the numbers it was given; a client that rounds them makes every
-- timer wrong, so the module refuses to run on one.
--------------------------------------------------------------------------------
local DOOR_SLACK, DOOR_PASSES = 1e-6, 16
local DOOR_BYTES = { 0, 1, 48, 85, 127, 200, 254, 255 }

local function TestDoor()
	local d = { state = "error" }
	if not EvalBool then
		d.detail = "the client has no EvaluateColorValueFromBoolean"
		return d
	end
	local off = 0
	for _, k in ipairs(DOOR_BYTES) do
		local want = k / 255
		local v = want
		for pass = 1, DOOR_PASSES do
			local ok, w
			if pass % 2 == 1 then ok, w = pcall(EvalBool, true, v, 0) else ok, w = pcall(EvalBool, false, 0, v) end
			if not ok then
				d.detail = tostring(w)
				return d
			end
			if IsSecret(w) then
				d.state = "hidden"
				return d
			end
			if type(w) ~= "number" then
				d.detail = "the answer was a " .. type(w) .. ", not a number"
				return d
			end
			v = w
			local gap = abs(v - want)
			if gap >= off then off, d.sent, d.got = gap, want, v end
		end
	end
	d.off = off
	d.state = off == 0 and "exact" or (off <= DOOR_SLACK and "close" or "coarse")
	return d
end

local door = TestDoor()
local HAS_WIDGETS = XUI.HasAuraContainers() and true or false

local function DoorOpen() return door.state == "exact" or door.state == "close" or door.state == "hidden" end

function M:CanLoad()
	if not HAS_WIDGETS then return false, "The game's aura container widgets are not available on this client." end
	if not DoorOpen() then door = TestDoor() end
	if door.state == "coarse" then
		return false, format("This client rounds the numbers the timers are kept in (off by %.1e).", door.off or 0)
	end
	if door.state == "error" then
		return false, "The client refused the value check: " .. tostring(door.detail) .. "."
	end
	return true
end

--------------------------------------------------------------------------------
-- Spell lists
--------------------------------------------------------------------------------
local function CdKey(spec, id) return spec .. ":" .. id end

local function SpecList(spec, db, all)
	local src = SPECS[spec]
	if not src then return nil end
	local order, rank = db.order and db.order[spec], nil
	if type(order) == "table" then
		rank = {}
		for i, id in ipairs(order) do
			if not rank[id] then rank[id] = i end
		end
	end
	local out = {}
	for i, e in ipairs(src) do
		local id, base = e, nil
		if type(e) == "table" then id, base = e[1], e[2] end
		local sp = SPELLS[id]
		local off = (db.off and db.off[CdKey(spec, id)]) and true or false
		if sp and (all or not off) then
			base = base or sp.cd
			local user = db.cds and tonumber(db.cds[CdKey(spec, id)])
			local cd = floor(mmax(CD_MIN, mmin(CD_MAX, user or base)))
			local sw = sp.swap
			if sw and sw.specs and not sw.specs[spec] then sw = nil end
			local show = (sw and sw.likely) and sw.id or id
			out[#out + 1] = { id = id, show = show, cd = cd, base = base, spell = sp, off = off, swap = sw,
				at = rank and (rank[id] or #order + i) or i }
		end
	end
	if rank then tsort(out, function(a, b) return a.at < b.at end) end
	return out
end

local racial = { byRace = {} }
for _, id in ipairs(Data.RACIALS) do racial.byRace[SPELLS[id].race] = id end

racial.Def = function(id, db, all)
	local sp = SPELLS[id]
	local off = (db.off and db.off[CdKey("race", id)]) and true or false
	if not sp or (off and not all) then return nil end
	local user = db.cds and tonumber(db.cds[CdKey("race", id)])
	local cd = floor(mmax(CD_MIN, mmin(CD_MAX, user or sp.cd)))
	return { id = id, show = id, cd = cd, base = sp.cd, spell = sp, off = off }
end

racial.List = function(db)
	local out = {}
	for _, id in ipairs(Data.RACIALS) do out[#out + 1] = racial.Def(id, db, true) end
	return out
end

racial.Add = function(list, race, db)
	local id = race and racial.byRace[race]
	local def = id and racial.Def(id, db)
	if not def then return list end
	list = list or {}
	list[#list + 1] = def
	return list
end

racial.Of = function(unit, guid)
	local ok, _, token = pcall(UnitRace, unit)
	if ok and not IsSecret(token) and type(token) == "string" then return token end
	if guid and GetPlayerInfoByGUID then
		ok, _, _, _, token = pcall(GetPlayerInfoByGUID, guid)
		if ok and not IsSecret(token) and type(token) == "string" then return token end
	end
	return nil
end

-- For the options: every spell of a spec (hidden ones too), or the racials.
function M:SpecSpells(spec)
	if spec == "race" then return racial.List(self.db) end
	return SpecList(spec, self.db, true) or {}
end

function M:SetCd(spec, id, seconds)
	local sp = SPELLS[id]
	if not sp or type(seconds) ~= "number" then return end
	local base = sp.cd
	for _, e in ipairs(SPECS[spec] or {}) do
		if type(e) == "table" and e[1] == id then base = e[2] end
	end
	seconds = floor(mmax(CD_MIN, mmin(CD_MAX, seconds)))
	self.db.cds[CdKey(spec, id)] = seconds ~= base and seconds or nil
	self:RefreshSoon()
end

function M:SetSpellShown(spec, id, on)
	if not SPELLS[id] then return end
	self.db.off[CdKey(spec, id)] = (not on) and true or nil
	self:RefreshSoon()
end

function M:MoveSpell(spec, id, dir)
	local list = SpecList(spec, self.db, true)
	if not list or (dir ~= 1 and dir ~= -1) then return false end
	local at
	for i, def in ipairs(list) do
		if def.id == id then at = i end
	end
	local to = at and at + dir
	if not to or not list[to] then return false end
	list[at], list[to] = list[to], list[at]
	local ids, moved = {}, false
	for i, def in ipairs(list) do
		local e = SPECS[spec][i]
		ids[i] = def.id
		if (type(e) == "table" and e[1] or e) ~= def.id then moved = true end
	end
	self.db.order[spec] = moved and ids or nil
	self:RefreshSoon()
	return true
end

--------------------------------------------------------------------------------
-- Small readers
--------------------------------------------------------------------------------
local function ClassOf(unit)
	local ok, _, token = pcall(UnitClass, unit)
	if ok and not IsSecret(token) and type(token) == "string" then return token end
	return nil
end

local function NameOf(unit)
	local ok, name = pcall(UnitName, unit)
	if not ok then return nil end
	return name
end

local function Key(unit)
	local ok, guid = pcall(UnitGUID, unit)
	if ok and not IsSecret(guid) and guid then return guid end
	return unit
end

local function RoleOf(unit)
	local ok, role = pcall(UnitGroupRolesAssigned, unit)
	if ok and not IsSecret(role) and type(role) == "string" then return role end
	return nil
end

local T0 = GetTime() - 1024
local function Now() return floor(GetTime() - T0 + 0.5) end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local holder, layer, meter
local slots, members = {}, {}
local built, failed, waitBuild, pending, fought = false, nil, false, false, false
local ticker, readTicker, inspectTicker, lastN
local stats = { reads = 0, secret = 0, errors = 0, edges = 0, own = 0, ownHidden = 0 }
local specByGUID = {}
local sensHost
local RF, mapSig, mapTimer

local function Fault(err)
	stats.errors = stats.errors + 1
	stats.lastErr = tostring(err)
	M:Trace("error: %s", stats.lastErr)
end

local function QueueRefresh() M:RefreshSoon() end

--------------------------------------------------------------------------------
-- Talent swaps (a talent replaces the spell by another one)
--------------------------------------------------------------------------------
local swaps = { byGUID = {}, byClass = {}, stale = {} }
local zone = { want = {} }

do
	local consts = Constants and Constants.TraitConsts
	local CFG = (consts and consts.INSPECT_TRAIT_CONFIG_ID) or -1

	for _, c in ipairs(CLASSES) do
		for _, spec in ipairs(c.specs) do
			for _, e in ipairs(SPECS[spec] or {}) do
				local id = type(e) == "table" and e[1] or e
				local sw = SPELLS[id] and SPELLS[id].swap
				if sw then
					swaps.byClass[c.token] = swaps.byClass[c.token] or {}
					swaps.byClass[c.token][id] = sw
				end
			end
		end
	end

	local function Locate(Tr, trees, sw)
		for _, tree in ipairs(trees) do
			local nodes = Tr.GetTreeNodes(tree)
			if type(nodes) == "table" then
				for _, nodeID in ipairs(nodes) do
					local node = Tr.GetNodeInfo(CFG, nodeID)
					local entries = type(node) == "table" and node.entryIDs
					if type(entries) == "table" then
						for _, entryID in ipairs(entries) do
							local e = Tr.GetEntryInfo(CFG, entryID)
							local d = type(e) == "table" and e.definitionID and Tr.GetDefinitionInfo(e.definitionID)
							if type(d) == "table" and d.spellID and sw.talents[d.spellID] then
								sw.tree, sw.node, sw.entry = tree, nodeID, entryID
								return
							end
						end
					end
				end
			end
		end
		sw.misses = (sw.misses or 0) + 1
	end

	local function Fits(sw, spec) return not sw.specs or sw.specs[spec] == true end

	local function AnyFits(want, spec)
		for _, sw in pairs(want) do
			if Fits(sw, spec) then return true end
		end
		return false
	end

	local function Read(want, spec)
		local Tr = C_Traits
		if not (Tr and Tr.GetConfigInfo and Tr.GetTreeNodes and Tr.GetNodeInfo and Tr.GetEntryInfo and Tr.GetDefinitionInfo) then return nil end
		if Tr.HasValidInspectData and Tr.HasValidInspectData() == false then return nil end
		local info = Tr.GetConfigInfo(CFG)
		local trees = type(info) == "table" and info.treeIDs
		if type(trees) ~= "table" then return nil end
		local out
		for id, sw in pairs(want) do
			if Fits(sw, spec) then
				if not sw.node and (sw.misses or 0) < 3 then Locate(Tr, trees, sw) end
				local mine = false
				for _, tree in ipairs(trees) do
					if tree == sw.tree then mine = true end
				end
				local node = mine and Tr.GetNodeInfo(CFG, sw.node)
				if type(node) == "table" and type(node.ID) == "number" and node.ID > 0 then
					local act = node.activeEntry
					local rank = type(node.activeRank) == "number" and node.activeRank or 0
					out = out or {}
					out[id] = (type(act) == "table" and act.entryID == sw.entry and rank > 0) and true or false
				end
			end
		end
		return out
	end

	-- your own talents: the spell's override, then whether a talent is known
	local function Mine(sw, id)
		local on
		local get = C_Spell and C_Spell.GetOverrideSpell
		if get and sw.id ~= id then
			local ok, ov = pcall(get, id)
			if ok and type(ov) == "number" and not IsSecret(ov) then on = (ov == sw.id) end
		end
		if on then return true end
		for talent in pairs(sw.talents) do
			local known = Ask(IsPlayerSpell, talent)
			if known then return true end
			if known == false then on = false end
		end
		return on
	end

	swaps.Wanted = function(m)
		local guid = m.guid
		local want = swaps.byClass[m.class or ""]
		if m.fake or not guid or not want or not AnyFits(want, m.spec) then return false end
		local Tr = C_Traits
		if not (Tr and Tr.GetConfigInfo and Tr.GetNodeInfo) then return false end
		return swaps.byGUID[guid] == nil or swaps.stale[guid] == true
	end

	swaps.Stale = function(m)
		if m.guid and swaps.byGUID[m.guid] then swaps.stale[m.guid] = true end
		m.swapMiss = nil
	end

	swaps.Read = function(m, spec)
		local guid = m.guid
		local want = guid and swaps.byClass[m.class or ""]
		spec = spec or m.spec
		if not want or not AnyFits(want, spec) then return false end
		local ok, got = pcall(Read, want, spec)
		if not ok then
			Fault(got)
			got = nil
		end
		local old = swaps.byGUID[guid]
		if not got then
			m.swapMiss = (m.swapMiss or 0) + 1
			if m.swapMiss < 3 then return false end
			got = old or {}
		end
		swaps.byGUID[guid], swaps.stale[guid], m.swapMiss = got, nil, nil
		for id in pairs(want) do
			if (old and old[id]) ~= got[id] then return true end
		end
		return false
	end

	-- Settles which spell a swapped entry draws, or drops a gated one.
	swaps.Mark = function(list, s, m)
		local known = m.guid and swaps.byGUID[m.guid]
		m.gated = nil
		for i = #list, 1, -1 do
			local def = list[i]
			local sw = def.swap
			if sw then
				local on, how
				if s.index == 1 then
					on, how = Mine(sw, def.id), "your talents"
				elseif known then
					on, how = known[def.id], "their talents"
				end
				if on == nil then on, how = sw.likely and true or false, "assumed, talents not read" end
				if not sw.gate then
					def.show, def.how = on and sw.id or def.id, how
				elseif on then
					def.how = how
				else
					tremove(list, i)
					m.gated = format("%s (%s)%s", XUI.GetSpellName(def.id), how, m.gated and (", " .. m.gated) or "")
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Timer text metrics. The numbers are one FontString of "cd\n...\n1" scrolled
-- under a window one line high, so the line height must be exact.
--------------------------------------------------------------------------------
local metrics, strips = {}, {}

local function Height(text)
	meter:SetText(text)
	local h = meter:GetStringHeight()
	if type(h) ~= "number" or IsSecret(h) or h <= 0 then return nil end
	return h
end

local function LineMetrics(font, size, flags)
	local key = tostring(font) .. "|" .. size .. "|" .. flags
	local m = metrics[key]
	if m then return m[1], m[2] end
	meter:SetFont(font, size, flags)
	local one, nine = Height("0"), Height("0\n0\n0\n0\n0\n0\n0\n0\n0")
	if not (one and nine and nine > one) then return size, size end
	local step = (nine - one) / 8
	metrics[key] = { step, one }
	return step, one
end

local function StripText(cd)
	local s = strips[cd]
	if s then return s end
	local out = {}
	for r = cd, 1, -1 do
		out[#out + 1] = r >= 60 and format("%d:%02d", floor(r / 60), r % 60) or tostring(r)
	end
	s = tconcat(out, "\n")
	strips[cd] = s
	return s
end

--------------------------------------------------------------------------------
-- Cells
--------------------------------------------------------------------------------
local function NewCell(row)
	local c = CreateFrame("Frame", nil, row)
	c:Hide()
	c.iconTex = c:CreateTexture(nil, "ARTWORK")
	c.border = Style:Border(c)

	-- the highlight glow while the effect is up; its alpha is the (secret) lit value
	c.glow = CreateFrame("Frame", nil, c)
	c.glow:SetAllPoints(c)
	c.glow:SetAlpha(0)

	c.clip = CreateFrame("Frame", nil, layer)
	c.clip:SetClipsChildren(true)
	c.clip:Hide()
	c.win = CreateFrame("Frame", nil, layer)
	c.win:SetClipsChildren(true)
	c.win:Hide()
	c.pos, c.fill, c.text, c.strip, c.veil, c.grey, c.gate = {}, {}, {}, {}, {}, {}, {}
	for k = 1, 2 do
		local pos = CreateFrame("StatusBar", nil, layer)
		pos:SetStatusBarTexture(WHITE)
		pos:SetStatusBarColor(0, 0, 0, 0)
		pos:SetOrientation("VERTICAL")
		pos:SetMinMaxValues(0, 1)
		pos:SetValue(1)
		local fill = pos:GetStatusBarTexture()
		local gate = CreateFrame("StatusBar", nil, layer)
		gate:SetStatusBarTexture(WHITE)
		gate:SetStatusBarColor(0, 0, 0, 0)
		gate:SetOrientation("VERTICAL")
		gate:SetMinMaxValues(0, 1)
		gate:SetValue(1)
		local text = CreateFrame("Frame", nil, c.win)
		text:SetAllPoints(c.win)
		text:SetAlpha(0)
		local strip = text:CreateFontString(nil, "OVERLAY")
		strip:SetJustifyH("CENTER")
		strip:SetPoint("BOTTOM", fill, "TOP", 0, 0)
		local veil = CreateFrame("Frame", nil, c.clip)
		veil:SetClipsChildren(true)
		veil:SetAlpha(0)
		local grey = veil:CreateTexture(nil, "ARTWORK")
		grey:SetAllPoints(c.clip)
		grey:SetDesaturated(true)
		grey:SetVertexColor(GREY, GREY, GREY)
		c.pos[k], c.fill[k], c.text[k], c.strip[k], c.gate[k], c.veil[k], c.grey[k] = pos, fill, text, strip, gate, veil, grey
	end
	return c
end

local function Scrap(c)
	c:Hide()
	c.clip:Hide()
	c.win:Hide()
	for k = 1, 2 do
		c.pos[k]:Hide()
		c.gate[k]:Hide()
	end
end

local function Unit(cd) return mmax(1, ceil(cd / CODES)) end

-- Sizes and fonts of one cell. Everything depends on `sig`, so a refresh that
-- changes nothing costs next to nothing.
local function Dress(c, def)
	local db = M.db
	local size = db.icon.width or 28
	c:SetSize(size, size)
	c.border:Apply(db.border)
	local inset = c.border:GetInset()
	local level = c:GetFrameLevel()
	local tex = XUI.GetSpellIcon(def.show or def.id)
	local zoom = Style:Resolve("icon", db.icon).zoom
	c.iconTex:ClearAllPoints()
	c.iconTex:SetPoint("TOPLEFT", c, "TOPLEFT", inset, -inset)
	c.iconTex:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -inset, inset)
	c.iconTex:SetTexture(tex)
	Style:IconTexCoord(c.iconTex, size - 2 * inset, size - 2 * inset, zoom)
	c.clip:SetFrameLevel(level + 1)
	c.win:SetFrameLevel(level + 4)
	c.glow:SetFrameLevel(level + 6)
	if db.glow.enabled == false then Style:HideGlow(c.glow) else Style:ShowGlow(c.glow, db.glow) end
	local f = Style:Resolve("font", db.timerText)
	local font, ts, flags = Media:Fetch("font", f.face), f.size or 12, Style:FontFlags(f)
	for k = 1, 2 do
		c.veil[k]:SetFrameLevel(level + 2)
		c.text[k]:SetFrameLevel(level + 5)
		c.grey[k]:SetTexture(tex)
		Style:IconTexCoord(c.grey[k], size - 2 * inset, size - 2 * inset, zoom)
		Style:ApplyFont(c.strip[k], db.timerText, ts)
		c.strip[k]:SetJustifyH("CENTER")
	end
	local step, one = LineMetrics(font, ts, flags)
	local sig = tconcat({ tostring(font), ts, flags, def.cd, size, inset, format("%.3f", step), format("%.3f", one) }, "|")
	if c.sig == sig then return end
	local cd, u = def.cd, Unit(def.cd)
	local line = mmin(one, step)
	local jump = size + 2
	c.clip:ClearAllPoints()
	c.clip:SetPoint("TOPLEFT", c, "TOPLEFT", inset, -inset)
	c.clip:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -inset, inset)
	c.win:ClearAllPoints()
	c.win:SetPoint("CENTER", c, "CENTER", 0, 0)
	c.win:SetSize(size + 6, line)
	c.line, c.seat = line, nil
	for k = 1, 2 do
		local pos, strip, veil, gate = c.pos[k], c.strip[k], c.veil[k], c.gate[k]
		local edge = gate:GetStatusBarTexture()
		pos:SetMinMaxValues(0, 1)
		pos:SetValue(1)
		pos:ClearAllPoints()
		pos:SetPoint("BOTTOM", c.win, "BOTTOM", 0, -(cd - 1 + u) * step)
		pos:SetSize(1, 255 * u * step)
		strip:SetText(StripText(cd))
		gate:SetMinMaxValues(0, 1)
		gate:SetValue(1)
		gate:ClearAllPoints()
		gate:SetPoint("BOTTOM", c.clip, "BOTTOM", 0, -(cd - 1 + u) * jump)
		gate:SetSize(1, 255 * u * jump)
		veil:ClearAllPoints()
		veil:SetPoint("BOTTOM", edge, "TOP", 0, -1)
		veil:SetPoint("TOP", edge, "TOP", 0, (cd - 1) * jump + size + 1)
		veil:SetWidth(size)
	end
	c.sig = sig
end

-- The text window sits on a pixel boundary so the numbers stay sharp.
local function PerUnit(region)
	local es = region:GetEffectiveScale()
	local _, ph = (GetPhysicalScreenSize or function() end)()
	if type(es) ~= "number" or IsSecret(es) or es <= 0 or type(ph) ~= "number" or ph <= 0 then return nil end
	return es * ph / 768
end

local function SeatNow(c)
	local line, ppu = c.line, PerUnit(c)
	if not (line and ppu) then return end
	local _, y = c:GetCenter()
	local seat = 0.25 / ppu
	if type(y) == "number" and not IsSecret(y) then
		local base = (y - line / 2) * ppu
		if c.seat then
			local at = base + c.seat * ppu
			if abs(at - floor(at) - 0.25) < 0.1 then return end
		end
		local f = base - floor(base)
		seat = ((f < 0.75 and 0.25 or 1.25) - f) / ppu
	elseif c.seat then
		return
	end
	c.win:SetPoint("CENTER", c, "CENTER", 0, seat)
	c.seat = seat
end

local function Seat(c)
	local ok, err = pcall(SeatNow, c)
	if not ok then Fault(err) end
end

--------------------------------------------------------------------------------
-- The timer. Per spell: a double-buffered pair of slots { c = code value,
-- v = visible }, one epoch each, all values possibly secret.
--------------------------------------------------------------------------------
local function Clear(t, n)
	local a, b = t.slot[1], t.slot[2]
	a.c, a.v, a.epoch = 1, 0, n
	b.c, b.v, b.epoch = 1, 0, n
	t.cur = 1
end

-- A slot's epoch is renewed before its codes run out.
local function Roll(t, n)
	local k = t.cur
	if n - t.slot[k].epoch < t.P then return false end
	k = 3 - k
	local sl = t.slot[k]
	sl.c, sl.v, sl.epoch = 1, 0, n
	t.cur = k
	return true
end

local function Stamp(t, n)
	local code = floor((n - t.slot[t.cur].epoch) / t.u)
	if code < 0 then code = 0 elseif code > CODES then code = CODES end
	return (255 - code) / 255
end

local function Left(t, sl, n)
	local code = 255 - floor(sl.c * 255 + 0.5)
	return t.cd - ((n - sl.epoch) - t.u * code)
end

local function Range(c, k, sl, u, n)
	local m = (254 - (n - sl.epoch) / u) / 255
	c.pos[k]:SetMinMaxValues(m, m + 1)
	c.gate[k]:SetMinMaxValues(m, m + 1)
end

local function WriteSlot(c, k, sl, u, n)
	c.pos[k]:SetMinMaxValues(0, 1)
	c.pos[k]:SetValue(sl.c)
	c.gate[k]:SetMinMaxValues(0, 1)
	c.gate[k]:SetValue(sl.c)
	c.text[k]:SetAlpha(sl.v)
	c.veil[k]:SetAlpha(sl.v)
	Range(c, k, sl, u, n)
end

local function Push(t)
	local c = t.cell
	if not c then return end
	local n = Now()
	for k = 1, 2 do
		local ok, err = pcall(WriteSlot, c, k, t.slot[k], t.u, n)
		if not ok then Fault(err) end
	end
end

local function StartPlain(t, n)
	Roll(t, n)
	local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
	sl.c, sl.v, other.v = Stamp(t, n), 1, 0
end

local function EnsureTicker() end -- replaced below, needs Tick

-- One second of housekeeping: renew epochs, slide the ranges, end timers that
-- have run out, and notice members who left.
local function Tick()
	local n = Now()
	if n == lastN then return end
	lastN = n
	local any = false
	for i = 1, #slots do
		local s = slots[i]
		for j = 1, MAX do
			local t = s.tr[j]
			local c = t and t.cell
			if c then
				any = true
				if Roll(t, n) then Push(t) end
				local running = false
				for k = 1, 2 do
					local sl = t.slot[k]
					if IsSecret(sl.v) or sl.v ~= 0 then
						if not IsSecret(sl.v) and not IsSecret(sl.c) and Left(t, sl, n) <= -LINGER then
							sl.v = 0
							if t.loop then StartPlain(t, n) end
							Push(t)
						else
							local ok, err = pcall(Range, c, k, sl, t.u, n)
							if not ok then Fault(err) end
							running = true
						end
					end
				end
				if running then Seat(c) end
			end
		end
		local m = s.member
		if i > 1 and m and not m.fake then
			if Ask(UnitIsVisible, s.unit) == false or Ask(UnitIsConnected, s.unit) == false then
				s.away = true
			elseif s.away then
				s.away = nil
				zone.Stale(s)
				QueueRefresh()
			end
		end
	end
	if not any and ticker then
		M:CancelTicker(ticker)
		ticker = nil
	end
end

EnsureTicker = function()
	lastN = nil
	if not ticker then ticker = M:NewTicker(TICK, Tick) end
end

--------------------------------------------------------------------------------
-- Reading the buffs (other members)
--------------------------------------------------------------------------------
-- A choice between two numbers by a boolean that may be secret.
local function Pick(cur, dual, short, a, b)
	if not dual then return EvalBool(cur, a, b) end
	if dual == "any" then
		local r = EvalBool(cur, a, b)
		for i = 1, short.n do r = EvalBool(short[i], a, r) end
		return r
	end
	return EvalBool(cur, EvalBool(short, b, a), b)
end

-- Whether the buff state is known, and whether it is up.
local function State(cur, dual, short)
	if IsSecret(cur) then return false, false end
	if dual == "any" then
		local up = cur and true or false
		for i = 1, short.n do
			local v = short[i]
			if IsSecret(v) then return false, false end
			if v then up = true end
		end
		return true, up
	end
	if IsSecret(short) then return false, false end
	return true, (cur and not (dual and short)) and true or false
end

local function Feed(t, cur, dual, short, n)
	if t.primed then
		if Roll(t, n) then Push(t) end
		local prev, prevShort = t.prev, t.prevShort
		local curKnown, up = State(cur, dual, short)
		local prevKnown, was = State(prev, dual, prevShort)
		local idle = (curKnown and not up) or (prevKnown and was)
		if not idle then
			if curKnown and prevKnown then
				StartPlain(t, n)
				stats.edges = stats.edges + 1
			else
				local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
				sl.c = Pick(cur, dual, short, Pick(prev, dual, prevShort, sl.c, Stamp(t, n)), sl.c)
				sl.v = Pick(cur, dual, short, Pick(prev, dual, prevShort, sl.v, 1), sl.v)
				other.v = Pick(cur, dual, short, Pick(prev, dual, prevShort, other.v, 0), other.v)
			end
			Push(t)
		end
	end
	t.prev, t.prevShort, t.primed = cur, short, true
end

local function ReadOne(s, j, t, n, glowOn)
	local cur = not t.def.spell.others and Engine.SensorLit(s.sens[j])
	local dual, short = s.dual[j], false
	if dual then short = Engine.SensorLit(s.short[j]) end
	local sig = s.any[j]
	if sig then dual, short = "any", zone.Read(s, t, sig) end
	stats.reads = stats.reads + 1
	if IsSecret(cur) then stats.secret = stats.secret + 1 end
	Feed(t, cur, dual, short, n)
	t.last = cur
	local c = t.cell
	if not c then return end
	local lit = 0
	if glowOn then lit = Pick(cur, dual, short, 1, 0) end
	c.glow:SetAlpha(lit)
end

local function ReadSlot(s, n)
	local glow = M.db.glow
	local glowOn = not glow or glow.enabled ~= false
	for j = 1, MAX do
		local t = s.tr[j]
		if t and s.live[j] then
			local ok, err = pcall(ReadOne, s, j, t, n, glowOn)
			if not ok then Fault(err) end
		end
	end
end

-- The reader runs a few passes after every aura change and then stops.
local function ReadPass()
	if not M.running then
		M:CancelTicker(readTicker)
		readTicker = nil
		return
	end
	local now, n, busy = GetTime(), Now(), false
	for i = 1, #slots do
		local s = slots[i]
		if s.reads > 0 then
			if not s.member then
				s.reads = 0
			elseif now >= s.hold then
				s.reads = s.reads - 1
				ReadSlot(s, n)
			end
			if s.reads > 0 then busy = true end
		end
	end
	if not busy and readTicker then
		M:CancelTicker(readTicker)
		readTicker = nil
	end
end

local function Wake()
	if not readTicker then readTicker = M:NewTicker(READ_EVERY, ReadPass) end
end

-- Your own row: a cast starts its timer.
local function OwnCast(s, spellID)
	if IsSecret(spellID) then
		stats.ownHidden = stats.ownHidden + 1
		return
	end
	local t = spellID and s.byCast[spellID]
	if not t then return end
	stats.own, stats.ownLast = stats.own + 1, spellID
	StartPlain(t, Now())
	Push(t)
	EnsureTicker()
end

--------------------------------------------------------------------------------
-- Sensors
--------------------------------------------------------------------------------
local function NewSensor(unit)
	local c, why = Engine.NewSensor(sensHost, unit, "cd", {})
	if not c then failed = why end
	return c
end

-- Points a sensor at a spell list; true when it is watching.
local function Aim(c, sig, filters, who)
	local hot = InCombatLockdown() and true or nil
	local fresh = false
	if c.aim ~= sig then
		if not pcall(c.SetAuraGroupCandidateFilters, c, "cd", filters) then
			pending = true
			return false
		end
		c.aim, fresh = sig, true
	end
	if not c.on then
		c.on, fresh = true, true
		pcall(c.SetEnabled, c, true)
	end
	if fresh or not who or c.who ~= who or (c.hot and not hot) then
		stats.aims = (stats.aims or 0) + 1
		if pcall(c.UpdateAllAuras, c) then
			c.who, c.hot = who, hot
		else
			c.who = nil
		end
	end
	return true
end

local function Park(c)
	if c and c.on then
		c.on = false
		pcall(c.SetEnabled, c, false)
	end
end

zone.Stale = function(s)
	for j = 1, MAX do
		local c = s.sens[j]
		if c then c.who = nil end
		c = s.short[j]
		if c then c.who = nil end
	end
	for _, h in pairs(s.zone) do h.who = nil end
end

-- The other members' answers for an external spell.
zone.Read = function(s, t, sig)
	local lists = t.zl
	if not lists then
		lists = { { n = 0 }, { n = 0 } }
		t.zl = lists
	end
	local list = lists[1] == t.prevShort and lists[2] or lists[1]
	local k = 0
	for i = 1, #slots do
		local o = slots[i]
		local h = o.zone[sig]
		if h and h.on and o ~= s then
			k = k + 1
			list[k] = Engine.SensorLit(h)
		end
	end
	for i = k + 1, list.n do list[i] = nil end
	list.n = k
	return list
end

zone.Churn = function(info)
	local churn
	for i = 1, #slots do
		local o = slots[i]
		if o.zowner and o.member and o.reads < READS_AFTER then
			if churn == nil then churn = XUI.AuraPayloadChurns(info) end
			if not churn then return end
			o.reads = READS_AFTER
		end
	end
	if churn then Wake() end
end

local function SyncEvents(s)
	if not s.evt then return end
	local wantAura = (s.event == "UNIT_AURA") or s.zon
	local wantCast = s.event == "UNIT_SPELLCAST_SUCCEEDED"
	if wantAura ~= (s.hasAura or false) then
		s.hasAura = wantAura
		if wantAura then s.evt:RegisterUnitEvent("UNIT_AURA", s.unit) else s.evt:UnregisterEvent("UNIT_AURA") end
	end
	if wantCast ~= (s.hasCast or false) then
		s.hasCast = wantCast
		if wantCast then s.evt:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", s.unit) else s.evt:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED") end
	end
end

-- Externals land on somebody else, so each slot also watches the others' buffs
-- for the spells another member might have cast.
zone.Aim = function()
	local want = zone.want
	for i = 1, #slots do
		local s = slots[i]
		local exists
		local lit = false
		for sig, sp in pairs(want) do
			local need = false
			for k = 1, #slots do
				if k ~= i then
					local o = slots[k]
					for j = 1, MAX do
						if o.any[j] == sig then need = true end
					end
				end
			end
			if need then
				if exists == nil then exists = Ask(UnitExists, s.unit) == true end
				need = exists
			end
			local h = s.zone[sig]
			if need and not h then
				if InCombatLockdown() or failed then
					pending = true
				else
					h = NewSensor(s.unit)
					s.zone[sig] = h
				end
			end
			if h then
				if need and Aim(h, sig, sp.filters, s.who) then lit = true else Park(h) end
			end
		end
		for sig, h in pairs(s.zone) do
			if not want[sig] then Park(h) end
		end
		if lit ~= (s.zon or false) then s.zon = lit end
		SyncEvents(s)
	end
	for i = 1, #slots do
		local s = slots[i]
		local owner = false
		for j = 1, MAX do
			local sig, t = s.any[j], s.tr[j]
			if sig and t then
				owner = true
				local set = ""
				for k = 1, #slots do
					local h = slots[k].zone[sig]
					if k ~= i and h and h.on then set = set .. k end
				end
				if t.zset ~= set then t.zset, t.primed = set, false end
			end
		end
		s.zowner = owner
	end
end

-- Aims a slot's sensors for one spell; returns live, dual.
local function AimPair(s, j, def)
	local sp = def.spell
	local main = s.sens[j]
	if sp.others then
		Park(main)
		Park(s.short[j])
		return main ~= nil, false
	end
	if not main or not Aim(main, sp.sig, sp.filters, s.who) then
		Park(s.short[j])
		return false, false
	end
	if not sp.short then
		Park(s.short[j])
		return true, false
	end
	local sh = s.short[j]
	if not sh then
		if InCombatLockdown() or failed then
			pending = true
			return true, false
		end
		sh = NewSensor(s.unit)
		s.short[j] = sh
		if not sh then return true, false end
	end
	if not Aim(sh, sp.shortSig, sp.shortFilters, s.who) then
		return true, false
	end
	return true, true
end

-- A preview timer: part-way through its cooldown, restarting when it ends.
local function Seed(t, def, i, j)
	local frac = PREVIEW_AT[(i + j) % #PREVIEW_AT + 1]
	if frac < 1 then
		local began = Now() - floor(def.cd * frac)
		Clear(t, began - 1)
		StartPlain(t, began)
		t.loop = true
	end
	t.lit = (i == 2 and j == 1)
end

local function Unbind(s, j)
	local t = s.tr[j]
	if t then
		if t.cell == s.cells[j] then t.cell = nil end
		s.tr[j] = nil
	end
	Park(s.sens[j])
	Park(s.short[j])
	s.live[j], s.dual[j], s.any[j] = false, false, nil
end

-- Hands one member's spell list to a slot: cells, timers, sensors, events.
local function AssignSlot(s, m, list, now)
	local db = M.db
	local n = list and mmin(#list, MAX) or 0
	local fake = m and m.fake or false
	local sensored = s.sensored and not fake
	local watch = false
	local vis = 0
	s.who = (m and m.guid) or (s.index == 1 and "player") or nil
	wipe(s.byCast)
	for j = 1, MAX do
		local def = j <= n and list[j] or nil
		if def then
			local t = m.tr[def.id]
			if not t then
				t = { slot = { {}, {} }, primed = false }
				m.tr[def.id] = t
			end
			if t.cd ~= def.cd then
				t.cd, t.u, t.loop = def.cd, Unit(def.cd), nil
				t.P = CODES * t.u
				Clear(t, Now())
				if fake then Seed(t, def, s.index, j) end
			end
			t.def = def
			local c = s.cells[j]
			if not c or not pcall(Dress, c, def) then
				if c then Scrap(c) end
				c = NewCell(s.row)
				s.cells[j] = c
				Dress(c, def)
			end
			local glowOn = db.glow.enabled ~= false
			local old = s.tr[j]
			if old ~= t then
				if old and old.cell == c then old.cell = nil end
				s.tr[j] = t
				t.primed, t.last = false, nil
				c.glow:SetAlpha(0)
			end
			t.cell = c
			local live, dual, any = false, false, nil
			if sensored then
				live, dual = AimPair(s, j, def)
				if live and def.spell.zone then
					any = def.spell.sig
					zone.want[any] = def.spell
				end
				if dual ~= s.dual[j] or any ~= s.any[j] then t.primed = false end
				if live then watch = true end
				if not glowOn then c.glow:SetAlpha(0) end
			else
				Park(s.sens[j])
				Park(s.short[j])
				c.glow:SetAlpha((t.lit and glowOn) and 1 or 0)
				if not fake then
					for id in pairs(def.spell.casts) do s.byCast[id] = t end
				end
			end
			s.live[j], s.dual[j], s.any[j] = live, dual, any
			vis = vis + 1
			Push(t)
		else
			Unbind(s, j)
		end
	end
	local want = nil
	if m and not fake and n > 0 then want = sensored and "UNIT_AURA" or "UNIT_SPELLCAST_SUCCEEDED" end
	s.event = want
	SyncEvents(s)
	s.member, s.n, s.vis = m, n, vis
	if watch then
		s.hold, s.reads = now + HOLD, READS_AFTER
	else
		s.reads = 0
	end
end

--------------------------------------------------------------------------------
-- Frames and layout
--------------------------------------------------------------------------------
local SIDES = {
	RIGHT        = { at = "LEFT",        to = "RIGHT",       x = 1,  y = 0,  from = "LEFT",   dx = 1,  dy = 0 },
	LEFT         = { at = "RIGHT",       to = "LEFT",        x = -1, y = 0,  from = "RIGHT",  dx = -1, dy = 0 },
	BELOW        = { at = "TOP",         to = "BOTTOM",      x = 0,  y = -1, from = "TOP",    dx = 0,  dy = -1 },
	BELOW_CENTER = { at = "TOP",         to = "BOTTOM",      x = 0,  y = -1, from = "LEFT",   dx = 1,  dy = 0 },
	BELOW_RIGHT  = { at = "TOPLEFT",     to = "BOTTOMLEFT",  x = 0,  y = -1, from = "LEFT",   dx = 1,  dy = 0 },
	BELOW_LEFT   = { at = "TOPRIGHT",    to = "BOTTOMRIGHT", x = 0,  y = -1, from = "RIGHT",  dx = -1, dy = 0 },
	ABOVE        = { at = "BOTTOM",      to = "TOP",         x = 0,  y = 1,  from = "BOTTOM", dx = 0,  dy = 1 },
	ABOVE_CENTER = { at = "BOTTOM",      to = "TOP",         x = 0,  y = 1,  from = "LEFT",   dx = 1,  dy = 0 },
	ABOVE_RIGHT  = { at = "BOTTOMLEFT",  to = "TOPLEFT",     x = 0,  y = 1,  from = "LEFT",   dx = 1,  dy = 0 },
	ABOVE_LEFT   = { at = "BOTTOMRIGHT", to = "TOPRIGHT",    x = 0,  y = 1,  from = "RIGHT",  dx = -1, dy = 0 },
}

local function EuiFrames()
	local rf = XUI.EUI and XUI.EUI.Module("EllesmereUIRaidFrames")
	if type(rf) ~= "table" or type(rf._partyUnitToButton) ~= "table" then return nil end
	return rf
end

local function Seen(btn)
	return (btn and Ask(btn.IsVisible, btn) == true) or false
end

local function MapSig(map)
	local out = {}
	if type(map) ~= "table" then return "" end
	for i, s in ipairs(slots) do
		local btn = map[s.unit]
		out[i] = tostring(btn) .. (Seen(btn) and "+" or "-")
	end
	return tconcat(out, " ")
end

-- EllesmereUI rebuilds its party map on roster changes; the rows follow.
local function MapLater()
	if mapTimer then return end
	mapTimer = true
	M:After(0.5, function()
		mapTimer = nil
		if RF and MapSig(RF._partyUnitToButton) ~= mapSig then QueueRefresh() end
	end)
end

local function HookEui()
	local rf = EuiFrames()
	if not rf then return end
	RF = rf
	if type(rf._RebuildPartyUnitMap) == "function" then
		M:SecureHook(rf, "_RebuildPartyUnitMap", function()
			if MapSig(rf._partyUnitToButton) ~= mapSig then QueueRefresh() else MapLater() end
		end)
	end
end

local function PlaceRow(row, anchor, stack, db, prev, hang)
	row:ClearAllPoints()
	if not stack then
		local away, along = db.offX or 4, db.offY or 0
		row:SetPoint(hang.at, anchor, hang.to, hang.x ~= 0 and hang.x * away or along, hang.y ~= 0 and hang.y * away or along)
		return
	end
	local up, gap = db.growth == "UP", db.rowSpacing or 6
	if not prev then
		row:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT", holder, up and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
	elseif up then
		row:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, gap)
	else
		row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
	end
end

local function Layout(preview)
	local db = M.db
	local size, gap = db.icon.width or 28, db.spacing or 2
	local rf = db.attach ~= false and EuiFrames() or nil
	local map = rf and rf._partyUnitToButton or nil
	RF, mapSig = rf, rf and MapSig(map) or nil
	local stack = true
	if map and (IsInGroup() or not preview) then
		for _, s in ipairs(slots) do
			if (s.vis or 0) > 0 and Seen(map[s.unit]) then
				stack = false
				break
			end
		end
	end
	if stack then map = nil end
	local hang = not stack and SIDES[db.side] or SIDES.RIGHT
	local column = hang.dy ~= 0
	local timers = db.showTimer ~= false
	local prev, rows = nil, 0
	for _, s in ipairs(slots) do
		local row, n, m = s.row, s.n, s.member
		local vis, at = s.vis or 0, 0
		local btn = map and map[s.unit] or nil
		local show = vis > 0
		if show and not stack then show = Seen(btn) end
		if show then
			local long = vis * size + (vis - 1) * gap
			if column then row:SetSize(size, long) else row:SetSize(long, size) end
			if pcall(PlaceRow, row, btn, stack, db, prev, hang) then
				if stack then prev = row end
				rows = rows + 1
			else
				show = false
			end
		end
		row:SetShown(show)
		for j = 1, MAX do
			local c = s.cells[j]
			if c then
				local t = s.tr[j]
				local on = (show and j <= n and t ~= nil) and true or false
				if on then
					local step = at * (size + gap)
					c:ClearAllPoints()
					c:SetPoint(hang.from, row, hang.from, hang.dx * step, hang.dy * step)
					at = at + 1
					Seat(c)
				end
				c:SetShown(on)
				c.clip:SetShown(on)
				c.win:SetShown(on and timers)
			end
		end
		local label = row.name
		if show and stack and db.showName ~= false and m and m.name ~= nil then
			Style:ApplyFont(label, db.nameText)
			label:SetTextColor(XUI.ClassColor(m.class))
			if not pcall(label.SetText, label, m.name) then label:SetText("") end
			label:Show()
		else
			label:Hide()
		end
	end
	holder:SetSize(4 * size + 3 * gap, size)
	holder:SetShown(rows > 0)
	holder:EnableMouse(false)
end

local function EnsureFrames()
	if holder then return end
	holder = CreateFrame("Frame", "XUI_PartyCDs", UIParent)
	holder:SetFrameStrata("MEDIUM")
	holder:SetSize(88, 28)
	holder:Hide()
	XUI.Movers:Register(holder, M, "position")
	layer = CreateFrame("Frame", nil, UIParent)
	layer:SetFrameStrata("MEDIUM")
	layer:SetSize(1, 1)
	layer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	meter = layer:CreateFontString(nil, "OVERLAY")
	meter:SetPoint("CENTER", layer, "CENTER", 0, 0)
	meter:SetAlpha(0)
	for _, s in ipairs(slots) do
		local row = CreateFrame("Frame", nil, holder)
		row:Hide()
		row.name = row:CreateFontString(nil, "OVERLAY")
		row.name:SetPoint("RIGHT", row, "LEFT", -4, 0)
		row.name:SetJustifyH("RIGHT")
		row.name:SetWordWrap(false)
		row.name:Hide()
		s.row = row
	end
end

--------------------------------------------------------------------------------
-- Specialization of a member
--------------------------------------------------------------------------------
local function InspectSpec(unit)
	local get = (C_SpecializationInfo and C_SpecializationInfo.GetInspectSpecialization) or GetInspectSpecialization
	if not get then return nil end
	local ok, id = pcall(get, unit)
	if ok and type(id) == "number" and not IsSecret(id) and id > 0 then return id end
	return nil
end

local queue, lastInspect = {}, 0

local function StopInspects()
	wipe(queue)
	if inspectTicker then
		M:CancelTicker(inspectTicker)
		inspectTicker = nil
	end
end

local function InspectStep()
	if #queue == 0 or not M.running then
		StopInspects()
		return
	end
	local sheet = InspectFrame
	if sheet and sheet:IsShown() then return end
	local now = GetTime()
	if now - lastInspect < 2 then return end
	local s = tremove(queue, 1)
	local m, unit = s.member, s.unit
	if not m or m.fake or (m.spec and not swaps.Wanted(m)) then return end
	if (m.tries or 0) >= 12 then
		if now - (m.triedAt or 0) < 30 then
			M:After(30, QueueRefresh)
			return
		end
		m.tries = 0
	end
	m.tries, m.triedAt = (m.tries or 0) + 1, now
	if Ask(CanInspect, unit) == true and NotifyInspect then
		lastInspect = now
		pcall(NotifyInspect, unit)
	end
	queue[#queue + 1] = s
end

local function QueueInspect(s)
	for _, q in ipairs(queue) do
		if q == s then return end
	end
	queue[#queue + 1] = s
	if not inspectTicker then inspectTicker = M:NewTicker(1, InspectStep) end
end

local function SpecFor(s, m)
	if s.index == 1 then
		m.how = "yours"
		return XUI.GetSpecID() or m.spec
	end
	local guid = m.guid
	local spec = guid and specByGUID[guid]
	if spec then
		m.how = "inspected"
		return spec
	end
	spec = InspectSpec(s.unit)
	if spec then
		if guid then specByGUID[guid] = spec end
		m.how = "inspected"
		return spec
	end
	local byRole = ROLE_SPEC[m.class or ""]
	spec = byRole and byRole[RoleOf(s.unit) or ""] or nil
	if spec then
		m.how = "from the role"
		return spec
	end
	QueueInspect(s)
	return nil
end

--------------------------------------------------------------------------------
-- Building and refreshing
--------------------------------------------------------------------------------
local function EnsureEngine()
	if failed or not M.running then return end
	if InCombatLockdown() then
		waitBuild = true
		return
	end
	waitBuild = false
	if not sensHost then
		sensHost = CreateFrame("Frame", nil, UIParent)
		sensHost:SetSize(1, 1)
		sensHost:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	end
	for i, s in ipairs(slots) do
		s.sensored = i > 1
		if s.sensored then
			for j = 1, MAX do
				if not s.sens[j] then
					s.sens[j] = NewSensor(s.unit)
					if not s.sens[j] then return end
				end
			end
		end
	end
	built = true
end

local function Live()
	if not M.running or failed or not built then return false end
	if IsInRaid() then return false end
	if M.db.groupOnly ~= false and not IsInGroup() then return false end
	return true
end

local function Rebuild(preview)
	local db = M.db
	local now = GetTime()
	local on = Live()
	local seen, cells, reads = {}, false, false
	pending = false
	fought = InCombatLockdown() and true or false
	wipe(zone.want)
	for i, s in ipairs(slots) do
		local m, list
		local rows = (on and (i > 1 or db.showSelf)) and true or false
		if preview then
			local p = PREVIEW[i]
			local key = "preview" .. i
			m = members[key]
			if not m then
				m = { tr = {}, fake = true, class = p.class, name = p.name, spec = p.spec, race = p.race }
				members[key] = m
			end
			list = racial.Add(SpecList(p.spec, db), p.race, db)
		elseif rows and Ask(UnitExists, s.unit) == true then
			local key = Key(s.unit)
			m = members[key]
			if not m then
				m = { tr = {} }
				members[key] = m
			end
			m.guid = key ~= s.unit and key or nil
			m.class = ClassOf(s.unit) or m.class
			m.race = racial.Of(s.unit, m.guid) or m.race
			m.name = NameOf(s.unit)
			m.spec = SpecFor(s, m)
			list = m.spec and SpecList(m.spec, db) or nil
			list = racial.Add(list, m.race, db)
			if list then
				swaps.Mark(list, s, m)
				if i > 1 and swaps.Wanted(m) then QueueInspect(s) end
			end
		end
		if m then seen[m] = true end
		local ok, err = pcall(AssignSlot, s, m, list, now)
		if not ok then Fault(err) end
		if s.n > 0 then cells = true end
		if s.reads > 0 then reads = true end
	end
	for key, m in pairs(members) do
		if not seen[m] then
			for _, t in pairs(m.tr) do t.cell = nil end
			members[key] = nil
		end
	end
	local ok, err = pcall(zone.Aim)
	if not ok then Fault(err) end
	ok, err = pcall(Layout, preview)
	if not ok then Fault(err) end
	if cells then EnsureTicker() end
	if reads then Wake() end
end

-- A key start clears every timer (a new run, everything is ready).
local function ResetAll(hold)
	local now = GetTime()
	local n = Now()
	for _, m in pairs(members) do
		for _, t in pairs(m.tr) do
			if not t.loop then
				Clear(t, n)
				Push(t)
			end
		end
	end
	for _, s in ipairs(slots) do
		if s.member and s.event == "UNIT_AURA" then s.hold, s.reads = now + hold, READS_AFTER end
	end
	lastN = nil
	Wake()
end

for i, unit in ipairs(TOKENS) do
	slots[i] = {
		index = i, unit = unit, reads = 0, hold = 0, n = 0, sensored = i > 1,
		cells = {}, tr = {}, sens = {}, short = {}, live = {}, dual = {}, byCast = {}, any = {}, zone = {},
	}
end

local function OnSlotEvent(s, event, _, a, b)
	if event == "UNIT_AURA" then
		if s.zon then zone.Churn(a) end
		if s.member and s.event == "UNIT_AURA" and (s.reads >= READS_AFTER or XUI.AuraPayloadChurns(a)) then
			s.reads = READS_AFTER
			Wake()
		end
	else
		OwnCast(s, b)
	end
end

--------------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------------
function M:OnEnable()
	ticker, readTicker, inspectTicker, lastN = nil, nil, nil, nil
	EnsureFrames()
	for _, s in ipairs(slots) do
		if not s.evt then
			s.evt = CreateFrame("Frame")
			s.evt:SetScript("OnEvent", function(_, event, ...)
				XUI.SafeCallFor(M, OnSlotEvent, s, event, ...)
			end)
		end
	end
	EnsureEngine()
	HookEui()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function(m)
		for i = 1, #slots do zone.Stale(slots[i]) end
		m:After(0.5, QueueRefresh)
	end)
	self:RegisterEvent("CHALLENGE_MODE_START", function() ResetAll(KEY_HOLD) end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function(m)
		if waitBuild or pending then
			m:Refresh()
		elseif fought then
			QueueRefresh()
		end
	end)
	self:RegisterEvent("GROUP_ROSTER_UPDATE", function(m)
		QueueRefresh()
		m:After(0.5, QueueRefresh)
	end)
	self:RegisterEvent("INSPECT_READY", function(_, _, guid)
		if IsSecret(guid) or not guid then return end
		for _, s in ipairs(slots) do
			local m = s.member
			if m and m.guid == guid then
				local spec = InspectSpec(s.unit)
				local changed = swaps.Read(m, spec)
				if spec and specByGUID[guid] ~= spec then
					specByGUID[guid] = spec
					changed = true
				end
				if changed then QueueRefresh() end
			end
		end
	end)
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, _, unit)
		if type(unit) == "string" and not IsSecret(unit) and unit ~= "player" then
			for _, s in ipairs(slots) do
				local m = s.member
				if s.unit == unit and m and m.guid then
					specByGUID[m.guid] = nil
					m.spec, m.tries = nil, nil
					swaps.Stale(m)
				end
			end
		end
		QueueRefresh()
	end)
	self:RegisterEvent("PLAYER_ROLES_ASSIGNED", QueueRefresh)
	self:RegisterEvent("TRAIT_CONFIG_UPDATED", QueueRefresh)
end

function M:OnDisable()
	ticker, readTicker, inspectTicker, lastN = nil, nil, nil, nil
	StopInspects()
	for _, s in ipairs(slots) do
		if s.evt then s.evt:UnregisterAllEvents() end
		s.hasAura, s.hasCast, s.zon, s.event, s.reads = false, false, false, nil, 0
	end
end

function M:OnSettingChanged(path)
	self:RefreshSoon()
end

function M:OnRefresh()
	local preview = self:IsPreview()
	if not (self.running or preview or holder) then return end
	EnsureFrames()
	XUI.Movers:Apply(holder)
	if self.running then EnsureEngine() end
	Rebuild(preview)
end

function M:DebugInfo()
	local out = {}
	out[#out + 1] = format("value check: %s%s", door.state, door.off and format(" (off by %.1e)", door.off) or "")
	out[#out + 1] = format("aura containers: %s | sensors built: %s | watching: %s",
		HAS_WIDGETS and "yes" or "NO", built and "yes" or "no", Live() and "yes" or "no")
	out[#out + 1] = format("reads %d, hidden %d, starts seen in the open %d, own casts %d, errors %d",
		stats.reads, stats.secret, stats.edges, stats.own, stats.errors)
	if stats.lastErr then out[#out + 1] = "last error: " .. stats.lastErr end
	if failed then out[#out + 1] = "stopped: " .. tostring(failed) end
	if waitBuild then out[#out + 1] = "sensors are built when combat ends" end
	local n = Now()
	for _, s in ipairs(slots) do
		local m = s.member
		if m then
			out[#out + 1] = format("%s: spec %s (%s), race %s, read from %s", s.unit, tostring(m.spec), tostring(m.how),
				tostring(m.race), s.event == "UNIT_AURA" and "buffs" or (s.event and "your casts" or "nothing"))
			for j = 1, MAX do
				local t = s.tr[j]
				if t then
					local state = "ready"
					for k = 1, 2 do
						local sl = t.slot[k]
						if IsSecret(sl.v) or IsSecret(sl.c) then
							state = "timer hidden"
						elseif sl.v ~= 0 and Left(t, sl, n) > 0 and state == "ready" then
							state = format("%d s left", Left(t, sl, n))
						end
					end
					out[#out + 1] = format("   %s (%d), %d s: %s | buff ids %s", XUI.GetSpellName(t.def.id), t.def.id, t.cd, state, t.def.spell.sig)
				end
			end
			if m.gated then out[#out + 1] = "   not shown, talent not taken: " .. m.gated end
		end
	end
	return out
end
