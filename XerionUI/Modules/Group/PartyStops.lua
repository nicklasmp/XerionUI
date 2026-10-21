--------------------------------------------------------------------------------
-- Party Stops
-- When the group's crowd control is ready again: stuns, knocks, fears and AoE
-- disorients (Leg Sweep, Chaos Nova, Shadowfury, Capacitor Totem, Shockwave,
-- Hammer of Justice, ...), one icon per member and spell with a countdown.
-- Two bars, so the big AoE stops and the rest can sit in different places.
--
-- HOW ANOTHER MEMBER'S CAST IS NOTICED
-- Their casts are secret in a key, but the debuff a stop leaves on an enemy is
-- not: a chain of hidden sensors (Engine.NewChain), one per enemy nameplate in
-- combat, answers "is this debuff on any of them?". The moment the answer
-- flips, the timer starts (see Modules/Group/TimerKit.lua for how a secret
-- boolean becomes a countdown). Debuffs from you are left out of the question
-- ("not mine"): your own row follows your own casts, which are readable.
--
-- Cooldown lengths follow each member's talents, read from the inspect data
-- (or your own loadout). A spell a member did not take is not shown for them.
--
-- Spell list and approach from KiraUI-Plugin (personal use); this module is a
-- rewrite on XerionUI's own blocks.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local T = XUI.Templates
local Style = XUI.Style
local Engine = XUI.Engine
local Data = XUI.PartyStopsData
local Kit = XUI.TimerKit

local SPELLS, ORDER = Data.SPELLS, Data.ORDER
local IsSecret, Ask = XUI.IsSecret, XUI.Ask
local floor, mmax, mmin = math.floor, math.max, math.min
local tremove, wipe = table.remove, wipe
local format = string.format

local GROUPS = 2
local TOKENS = { "player", "party1", "party2", "party3", "party4" }
local MAX_PLATES = 40
local READ_EVERY, TICK, LINGER_PLATE, SETTLE = 0.2, 0.25, 1, 0.4
local NOT_MINE = "HARMFUL|!PLAYER"
local PREVIEW_AT = { 0.35, 1, 0.7 }
local EDIT_ICONS = 7
local EMPTY = {}

local function BarDefaults(group, x, y)
	local spells = {}
	for _, id in ipairs(ORDER) do
		if SPELLS[id].bar == group then spells[#spells + 1] = id end
	end
	return {
		show = true,
		grow = "RIGHT",
		spacing = 2,
		showNames = true,
		namePos = "IN",
		nameLen = 4,
		spells = spells,
		icon = T.Icon(36),
		border = T.Border(),
		timerText = T.Font(16, { color = { 1, 1, 1, 1 } }),
		nameText = T.Font(10),
		position = T.Position(x, y),
	}
end

local M = XUI:NewModule("PartyStops", {
	name = "Party Stops",
	desc = "When your group's stuns and AoE crowd control are ready again, even inside keys.",
	category = "group",
	icon = XUI.MEDIA_PATH .. "partycds",
	iconSpell = 119381,
	order = 32,
	untested = true,
	defaults = {
		showSelf = true,
		groupOnly = true,
		dungeonOnly = false,
		talents = true,
		maxUnits = 10,
		seen = {},
		bar1 = BarDefaults(1, -160, -150),
		bar2 = BarDefaults(2, -160, -200),
	},
})

M.GROW = {
	{ value = "RIGHT", text = "Right" },
	{ value = "LEFT", text = "Left" },
	{ value = "UP", text = "Up" },
	{ value = "DOWN", text = "Down" },
	{ value = "CENTER", text = "Centered" },
}
M.NAMEPOS = {
	{ value = "IN", text = "On the icon" },
	{ value = "BELOW", text = "Under the icon" },
}

--------------------------------------------------------------------------------
-- Availability
--------------------------------------------------------------------------------
local door = Kit.TestDoor()
local HAS_WIDGETS = XUI.HasAuraContainers() and true or false

function M:CanLoad()
	if not HAS_WIDGETS then return false, "The game's aura container widgets are not available on this client." end
	if not Kit.DoorOpen(door) then door = Kit.TestDoor() end
	if door.state == "coarse" then
		return false, format("This client rounds the numbers the timers are kept in (off by %.1e).", door.off or 0)
	end
	if door.state == "error" then
		return false, "The client refused the value check: " .. tostring(door.detail) .. "."
	end
	return true
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local bars, feeds, members, byCast = {}, {}, {}, {}
local sensHost
local built, waitBuild, preview = false, false, false
local ticker, readTicker, scanTicker, lastN, growing
local tracking, taken, lingerUntil, rulesHold = false, 0, 0, true
local unitOf, slotOf, alive = {}, {}, {}
local ownOn = false
local stats = { reads = 0, hidden = 0, errors = 0, own = 0, ownHidden = 0, scans = 0 }
local specByGUID = {}
local inspectQ, ownRanks
local QueueRefresh

local function Fault(err)
	stats.errors = stats.errors + 1
	stats.lastErr = tostring(err)
	M:Trace("error: %s", stats.lastErr)
end

local kit = Kit.New(M, Fault)

QueueRefresh = function() M:RefreshSoon() end

local PLATES, IS_PLATE = {}, {}
for i = 1, MAX_PLATES do
	PLATES[i] = "nameplate" .. i
	IS_PLATE[PLATES[i]] = true
end

local function InDungeon()
	local ok, inside, kind = pcall(IsInInstance)
	if not ok or IsSecret(inside) or IsSecret(kind) then return true end
	return (inside and kind == "party") and true or false
end

local function Cap() return mmax(1, mmin(MAX_PLATES, floor(tonumber(M.db.maxUnits) or 10))) end

--------------------------------------------------------------------------------
-- Spell lists (what the options edit)
--------------------------------------------------------------------------------
local function BarDb(g) return M.db["bar" .. g] end

-- Spells that were added to the addon after the lists were first saved join
-- the bar they belong to, once; a spell the user removed stays removed.
local function Migrate()
	local db = M.db
	if type(db.seen) ~= "table" then db.seen = {} end
	for g = 1, GROUPS do
		if type(BarDb(g).spells) ~= "table" then BarDb(g).spells = {} end
	end
	for _, id in ipairs(ORDER) do
		if not db.seen[id] then
			db.seen[id] = true
			local there = false
			for g = 1, GROUPS do
				for _, v in ipairs(BarDb(g).spells) do
					if v == id then there = true end
				end
			end
			if not there then
				local list = BarDb(SPELLS[id].bar or 1).spells
				list[#list + 1] = id
			end
		end
	end
end

function M:BarSpells(g)
	local out = {}
	for _, id in ipairs(BarDb(g).spells) do
		local sp = SPELLS[id]
		if sp then out[#out + 1] = { id = id, class = sp.class } end
	end
	return out
end

function M:Catalogue()
	local out = {}
	for _, id in ipairs(ORDER) do out[#out + 1] = { id = id, class = SPELLS[id].class } end
	return out
end

function M:AddSpell(g, id)
	if not SPELLS[id] then return end
	for k = 1, GROUPS do
		local list = BarDb(k).spells
		for i = #list, 1, -1 do
			if list[i] == id then tremove(list, i) end
		end
	end
	local list = BarDb(g).spells
	list[#list + 1] = id
	self:RefreshSoon()
end

function M:RemoveSpell(g, id)
	local list = BarDb(g).spells
	for i = #list, 1, -1 do
		if list[i] == id then tremove(list, i) end
	end
	self:RefreshSoon()
end

function M:MoveSpell(g, id, dir)
	local list = BarDb(g).spells
	for i, v in ipairs(list) do
		if v == id and list[i + dir] then
			list[i], list[i + dir] = list[i + dir], list[i]
			self:RefreshSoon()
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Talents
--------------------------------------------------------------------------------
local talents = XUI.Talents.New()
local talentsByGUID, talentsStale = {}, {}

for _, id in ipairs(ORDER) do
	local sp = SPELLS[id]
	for _, need in ipairs(sp.need or EMPTY) do talents:Want(sp.class, need) end
	for _, mod in ipairs(sp.mods or EMPTY) do
		if mod[1] then talents:Want(sp.class, mod[1]) end
	end
end

local function Known(id)
	local SB = C_SpellBook
	return Ask((SB and SB.IsSpellKnown) or IsPlayerSpell, id)
end

-- Your own talents: the active loadout, then what the spell book says.
local function OwnTalents(class)
	if ownRanks and ownRanks.class == class then return ownRanks.ranks end
	local config = XUI.Talents.Config()
	local ok, read = false, nil
	if config then ok, read = pcall(talents.Ranks, talents, class, config) end
	local own = (ok and read) or {}
	for _, id in ipairs(talents.ids[class] or EMPTY) do
		if own[id] == nil then
			local known = Known(id)
			if known ~= nil then own[id] = known and 1 or 0 end
		end
	end
	-- knowing the spell proves its talent
	for id, sp in pairs(SPELLS) do
		if sp.class == class and sp.need then
			local base = Known(id)
			for _, alt in ipairs(sp.cast or EMPTY) do
				if Known(alt) == true then base = true end
			end
			if base == true then
				for _, need in ipairs(sp.need) do
					if (own[need] or 0) < 1 then own[need] = 1 end
				end
			end
		end
	end
	ownRanks = { class = class, ranks = own }
	return own
end

local function TalentsOf(m)
	if m.fake or M.db.talents == false then return nil end
	if m.me then return OwnTalents(m.class) end
	return m.guid and talentsByGUID[m.guid] or nil
end

local function WantsInspect(m)
	if m.me or m.fake or not m.guid or not talents.ids[m.class or ""] or not InDungeon() then return false end
	return talentsByGUID[m.guid] == nil or talentsStale[m.guid] == true
end

local function InspectSpec(unit)
	local get = (C_SpecializationInfo and C_SpecializationInfo.GetInspectSpecialization) or GetInspectSpecialization
	if not get then return nil end
	local ok, id = pcall(get, unit)
	if ok and type(id) == "number" and not IsSecret(id) and id > 0 then return id end
	return nil
end

-- true keeps the member waiting for the inspect answer
local function TryInspect(m, q)
	if members[m.guid or ""] ~= m or not WantsInspect(m) or (m.asks or 0) >= 6 then return false end
	if Ask(CanInspect, m.unit) == true and Ask(UnitIsVisible, m.unit) ~= false then
		q:Notify(m.unit)
		m.asks = (m.asks or 0) + 1
	end
	return true
end

local function QueueInspect(m)
	inspectQ = inspectQ or XUI.NewInspectQueue(M, TryInspect)
	inspectQ:Add(m)
end

-- The inspect answer for one member; true when something they have changed.
local function ReadInspect(m)
	local changed = false
	local spec = InspectSpec(m.unit)
	if spec and specByGUID[m.guid] ~= spec then
		specByGUID[m.guid] = spec
		m.spec = spec
		changed = true
	end
	if not talents.ids[m.class or ""] then return changed end
	local ok, got = pcall(talents.Ranks, talents, m.class)
	if not ok then
		Fault(got)
		got = nil
	end
	local old = talentsByGUID[m.guid]
	if not got then
		m.talentMiss = (m.talentMiss or 0) + 1
		if m.talentMiss < 3 then return changed end
		got = old or {}
	end
	talentsByGUID[m.guid], talentsStale[m.guid], m.talentMiss = got, nil, nil
	for _, id in ipairs(talents.ids[m.class]) do
		if (old and old[id]) ~= got[id] then changed = true end
	end
	return changed
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

local function KeyOf(unit)
	local ok, guid = pcall(UnitGUID, unit)
	if ok and not IsSecret(guid) and guid then return guid end
	return unit
end

local function RoleOf(unit)
	local ok, role = pcall(UnitGroupRolesAssigned, unit)
	if ok and not IsSecret(role) and (role == "TANK" or role == "HEALER" or role == "DAMAGER") then return role end
	return nil
end

-- First letters of a name, counting UTF-8 characters.
local function Short(name, letters)
	if IsSecret(name) or type(name) ~= "string" or letters <= 0 then return name end
	local i, count, len = 1, 0, #name
	while i <= len and count < letters do
		local b = name:byte(i)
		i = i + ((b >= 240 and 4) or (b >= 224 and 3) or (b >= 192 and 2) or 1)
		count = count + 1
	end
	return name:sub(1, i - 1)
end

--------------------------------------------------------------------------------
-- Members
--------------------------------------------------------------------------------
local function Fits(sp, m, known)
	if m.class ~= sp.class then return false end
	if known and sp.need then
		local no = false
		for _, id in ipairs(sp.need) do
			no = known[id] == 0
			if not no then break end
		end
		if no then return false end
	end
	if not sp.spec then return true end
	if m.spec then return m.spec == sp.spec end
	if m.role then return m.role == sp.role end
	return true
end

local function Roster()
	local db = M.db
	local out = {}
	for i, unit in ipairs(TOKENS) do
		local me = i == 1
		if (me and db.showSelf ~= false) or (not me and Ask(UnitExists, unit) == true) then
			local key = KeyOf(unit)
			local m = members[key]
			if not m then
				m = { tr = {} }
				members[key] = m
			end
			m.unit, m.me = unit, me
			m.guid = key ~= unit and key or nil
			m.class = ClassOf(unit) or m.class
			m.name = NameOf(unit)
			if me then
				local own = XUI.GetSpecID()
				m.spec = (type(own) == "number" and own > 0) and own or nil
			else
				m.spec = (m.guid and specByGUID[m.guid]) or InspectSpec(unit)
				if m.spec and m.guid then specByGUID[m.guid] = m.spec end
			end
			m.role = RoleOf(unit)
			if db.talents ~= false and WantsInspect(m) then QueueInspect(m) end
			out[#out + 1] = m
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- Frames and layout
--------------------------------------------------------------------------------
local function NewCell(bar)
	local c = kit.NewCell(bar.frame)
	c.tag = CreateFrame("Frame", nil, c)
	c.tag:SetAllPoints(c)
	c.who = c.tag:CreateFontString(nil, "OVERLAY")
	c.who:SetJustifyH("CENTER")
	c.who:SetWordWrap(false)
	c.who:Hide()
	return c
end

local function Bind(g, list)
	local bar, bdb = bars[g], BarDb(g)
	local look = { size = bdb.icon.width or 36, icon = bdb.icon, border = bdb.border, timerText = bdb.timerText }
	for i, e in ipairs(list) do
		local t = e.t
		local c = bar.cells[i]
		if not c or not pcall(kit.Dress, c, t.def, look) then
			if c then
				kit.Loose(c)
				kit.Scrap(c)
			end
			c = NewCell(bar)
			bar.cells[i] = c
			kit.Dress(c, t.def, look)
		end
		c.tag:SetFrameLevel(c:GetFrameLevel() + 7)
		c.m = e.m
		kit.Bind(t, c)
	end
	for i = #list + 1, #bar.cells do kit.Loose(bar.cells[i]) end
	bar.n = #list
end

local function Layout(g)
	local bar, bdb = bars[g], BarDb(g)
	local size, gap = bdb.icon.width or 36, bdb.spacing or 2
	local grow = bdb.grow
	local names = bdb.showNames ~= false
	local below = names and bdb.namePos == "BELOW"
	local nameSize = bdb.nameText.size or 10
	local letters = floor(tonumber(bdb.nameLen) or 0)
	local step = size + gap
	local tall = step + (below and nameSize + 2 or 0)
	local n = bar.n or 0
	bar.frame:SetSize(size, size)
	for i, c in ipairs(bar.cells) do
		local on = i <= n
		if on then
			local k, x, y = i - 1, 0, 0
			if grow == "LEFT" then
				x = -k * step
			elseif grow == "UP" then
				y = k * tall
			elseif grow == "DOWN" then
				y = -k * tall
			elseif grow == "CENTER" then
				x = floor((k - (n - 1) / 2) * step + 0.5)
			else
				x = k * step
			end
			c:ClearAllPoints()
			c:SetPoint("CENTER", bar.frame, "CENTER", x, y)
			kit.Seat(c)
			local who, m = c.who, c.m
			if names and m and m.name ~= nil then
				Style:ApplyFont(who, bdb.nameText, nameSize)
				who:SetTextColor(XUI.ClassColor(m.class))
				who:ClearAllPoints()
				if below then
					who:SetPoint("TOP", c, "BOTTOM", 0, -1)
				else
					who:SetPoint("BOTTOM", c, "BOTTOM", 0, 2)
				end
				who:SetWidth(step)
				if not pcall(who.SetText, who, Short(m.name, letters)) then who:SetText("") end
				who:Show()
			else
				who:Hide()
			end
		end
		c:SetShown(on)
		c.clip:SetShown(on)
		c.win:SetShown(on)
	end
	bar.frame:SetShown(n > 0)
end

local function EnsureFrames()
	if sensHost then return end
	sensHost = CreateFrame("Frame", nil, UIParent)
	sensHost:SetSize(1, 1)
	sensHost:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	kit.Ensure()
	for g = 1, GROUPS do
		local f = CreateFrame("Frame", "XUI_PartyStops" .. g, UIParent)
		f:SetFrameStrata("MEDIUM")
		f:SetSize(36, 36)
		f:Hide()
		XUI.Movers:Register(f, M, "bar" .. g .. ".position", { key = tostring(g), label = "Party Stops - bar " .. g })
		bars[g] = { frame = f, cells = {}, n = 0 }
	end
end

--------------------------------------------------------------------------------
-- Timers
--------------------------------------------------------------------------------
local function Tick()
	local n = kit.Now()
	local second = n ~= lastN
	lastN = n
	local any = false
	for g = 1, GROUPS do
		local bar = bars[g]
		for i = 1, bar.n or 0 do
			local c = bar.cells[i]
			local t = c and c.t
			if t then
				any = true
				if second then kit.TickOne(t, c, n) end
			end
		end
	end
	if not any and ticker then
		M:CancelTicker(ticker)
		ticker = nil
	end
end

local function EnsureTicker()
	lastN = nil
	if not ticker then ticker = M:NewTicker(TICK, Tick) end
end

--------------------------------------------------------------------------------
-- Enemy nameplates and the sensor chains
--------------------------------------------------------------------------------
local function FeedOf(id)
	local f = feeds[id]
	if f then return f end
	local sp = SPELLS[id]
	f = { chain = Engine.NewChain(sensHost, "stop", NOT_MINE, sp.include), trackers = EMPTY, n = 0, on = false, hold = sp.hold, settle = 0 }
	f.chain.unit = {}
	for slot, unit in pairs(unitOf) do f.chain:Aim(slot, unit) end
	feeds[id] = f
	return f
end

-- Why a nameplate is not worth watching, or nil.
local function Verdict(unit, strict)
	if Ask(UnitExists, unit) ~= true then return "no such unit" end
	if Ask(UnitCanAttack, "player", unit) == false then return "not attackable" end
	if Ask(UnitCanAssist, "player", unit) ~= false then return "friendly, or the client would not say" end
	if Ask(UnitIsDeadOrGhost, unit) == true then return "dead" end
	if Ask(UnitIsBossMob, unit) == true then return "boss" end
	if strict and Ask(UnitAffectingCombat, unit) == false then return "not in combat" end
	return nil
end

local function Grow()
	if growing then return end
	growing = true
	local function Step()
		if InCombatLockdown() then
			waitBuild, growing = true, false
			return
		end
		local cap = Cap()
		for _, f in pairs(feeds) do
			if f.on and not f.chain.failed and f.chain.n < cap then
				f.chain:Grow()
				M:After(0, Step)
				return
			end
		end
		growing = false
	end
	M:After(0, Step)
end

local function TopUp()
	if InCombatLockdown() then
		waitBuild = true
		return
	end
	waitBuild = false
	Grow()
end

local function Release(slot)
	local unit = unitOf[slot]
	if not unit then return end
	unitOf[slot] = nil
	slotOf[unit] = nil
	taken = taken - 1
	lingerUntil = GetTime() + LINGER_PLATE
	for _, f in pairs(feeds) do f.chain:Park(slot) end
end

local function Take(slot, unit)
	unitOf[slot] = unit
	slotOf[unit] = slot
	taken = taken + 1
	local settle = GetTime() + SETTLE
	for _, f in pairs(feeds) do
		f.chain:Aim(slot, unit)
		if f.on then f.settle = settle end
	end
end

local function Rescan()
	if not tracking then return end
	stats.scans = stats.scans + 1
	local cap = Cap()
	local hold = true
	if InCombatLockdown() then
		hold = false
		for unit in pairs(alive) do
			if Verdict(unit, true) == nil then
				hold = true
				break
			end
		end
	end
	rulesHold = hold
	for slot = 1, MAX_PLATES do
		local unit = unitOf[slot]
		if unit and (slot > cap or Verdict(unit, hold) ~= nil) then Release(slot) end
	end
	local free = 1
	for unit in pairs(alive) do
		if not slotOf[unit] and Verdict(unit, hold) == nil then
			while free <= cap and unitOf[free] do free = free + 1 end
			if free > cap then break end
			Take(free, unit)
		end
	end
	if taken > 0 and not readTicker then
		readTicker = M:NewTicker(READ_EVERY, function() M:ReadAll() end)
	end
end

local QueueScan = XUI.Coalesce(Rescan)

local function PlateEvent(_, event, unit)
	if type(unit) ~= "string" or IsSecret(unit) or not IS_PLATE[unit] then return end
	if event == "NAME_PLATE_UNIT_REMOVED" then
		alive[unit] = nil
		local slot = slotOf[unit]
		if slot then Release(slot) end
	else
		alive[unit] = true
	end
	QueueScan()
end

local function StartTracking()
	if tracking then return end
	tracking = true
	wipe(alive)
	for _, unit in ipairs(PLATES) do
		if Ask(UnitExists, unit) == true then alive[unit] = true end
	end
	M:RegisterEvent("NAME_PLATE_UNIT_ADDED", PlateEvent)
	M:RegisterEvent("NAME_PLATE_UNIT_REMOVED", PlateEvent)
	scanTicker = M:NewTicker(2, QueueScan)
	QueueScan()
end

local function StopTracking()
	if not tracking then return end
	tracking = false
	M:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
	M:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
	if scanTicker then
		M:CancelTicker(scanTicker)
		scanTicker = nil
	end
	for slot = 1, MAX_PLATES do Release(slot) end
	wipe(alive)
	if readTicker then
		M:CancelTicker(readTicker)
		readTicker = nil
	end
end

function M:ReadAll()
	if not tracking or (taken <= 0 and GetTime() > lingerUntil) then
		if readTicker then
			self:CancelTicker(readTicker)
			readTicker = nil
		end
		return
	end
	local n, now = kit.Now(), GetTime()
	for id, f in pairs(feeds) do
		if f.on and f.chain.sensors[1] and f.hold and now < f.settle then
			for i = 1, f.n do f.trackers[i].primed = false end
		elseif f.on and f.chain.sensors[1] then
			local ok, lit = pcall(Engine.SensorLit, f.chain.span)
			if ok then
				stats.reads = stats.reads + 1
				if IsSecret(lit) then stats.hidden = stats.hidden + 1 end
				local at = n - (SPELLS[id].lag or 0)
				for i = 1, f.n do
					local okF, err = pcall(kit.Feed, f.trackers[i], lit, at)
					if not okF then Fault(err) end
				end
			else
				Fault(lit)
			end
		end
	end
end

-- Which spells are watched, and by which timers.
local function SetFeeds(want)
	local any = false
	for id, list in pairs(want) do
		local f = FeedOf(id)
		f.trackers, f.n = list, #list
		if not f.on then
			f.on, f.settle = true, GetTime() + SETTLE
			for i = 1, f.n do list[i].primed = false end
			f.chain:SetEnabled(true)
		end
		any = true
	end
	for id, f in pairs(feeds) do
		if f.on and not want[id] then
			f.on, f.n, f.trackers = false, 0, EMPTY
			f.chain:SetEnabled(false)
		end
	end
	if any then
		StartTracking()
		TopUp()
	else
		StopTracking()
	end
end

--------------------------------------------------------------------------------
-- Your own casts
--------------------------------------------------------------------------------
local function OwnCast(_, _, _, _, spellID)
	if IsSecret(spellID) then
		stats.ownHidden = stats.ownHidden + 1
		return
	end
	local t = spellID and byCast[spellID]
	if not t then return end
	stats.own = stats.own + 1
	local n = kit.Now()
	kit.StartPlain(t, n)
	if t.cell then kit.Push(t) end
	EnsureTicker()
end

--------------------------------------------------------------------------------
-- Building and refreshing
--------------------------------------------------------------------------------
local function Live()
	local db = M.db
	if not M.running then return false end
	if IsInRaid() then return false end
	if db.groupOnly ~= false and not IsInGroup() then return false end
	if db.dungeonOnly and not InDungeon() then return false end
	return true
end

-- How many preview icons each bar may show while the layout is being edited.
local function Share()
	local have, take, used = {}, {}, {}
	for g = 1, GROUPS do
		local count = 0
		if BarDb(g).show ~= false then
			for _, id in ipairs(BarDb(g).spells) do
				if SPELLS[id] and not used[id] then
					used[id] = true
					count = count + 1
				end
			end
		end
		have[g] = count
	end
	local left = EDIT_ICONS
	for g = 1, GROUPS do
		local slots = GROUPS - g + 1
		take[g] = mmin(have[g], floor((left + slots - 1) / slots))
		left = left - take[g]
	end
	for g = 1, GROUPS do
		local more = mmin(have[g] - take[g], left)
		take[g] = take[g] + more
		left = left - more
	end
	return take
end

local function Rebuild()
	local db = M.db
	local on = Live()
	local n = kit.Now()
	local seen, want, used = {}, {}, {}
	local roster = (on and not preview) and Roster() or EMPTY
	local fakes, cells = 0, false
	local room = (preview and XUI.unlockActive) and Share() or nil
	wipe(byCast)
	for _, m in ipairs(roster) do seen[m] = true end
	if preview then
		for _, m in pairs(members) do
			if not m.fake then seen[m] = true end
		end
	end
	for g = 1, GROUPS do
		local list = {}
		local bdb = BarDb(g)
		if (preview or on) and bdb.show ~= false then
			for _, id in ipairs(bdb.spells) do
				local sp = SPELLS[id]
				if sp and not used[id] then
					used[id] = true
					if preview then
						if not room or #list < room[g] then
							local cd = XUI.Talents.Length(sp.cd, sp.mods or EMPTY, nil, nil, true)
							fakes = fakes + 1
							local key = "preview" .. id
							local m = members[key]
							if not m then
								m = { tr = {}, fake = true }
								members[key] = m
							end
							m.class, m.name = sp.class, "Preview"
							seen[m] = true
							local t = kit.Tracker(m, id, cd)
							if t.fresh then kit.Seed(t, PREVIEW_AT[(fakes - 1) % #PREVIEW_AT + 1], n) end
							t.fresh = nil
							list[#list + 1] = { t = t, m = m }
						end
					else
						for _, m in ipairs(roster) do
							local known = m.class == sp.class and TalentsOf(m) or nil
							if Fits(sp, m, known) then
								local t = kit.Tracker(m, id, XUI.Talents.Length(sp.cd, sp.mods or EMPTY, known, nil, true))
								t.fresh = nil
								list[#list + 1] = { t = t, m = m }
								if m.me then
									byCast[id] = t
									for alt in pairs(sp.casts) do byCast[alt] = t end
								else
									local w = want[id]
									if not w then
										w = {}
										want[id] = w
									end
									w[#w + 1] = t
								end
							end
						end
					end
				end
			end
		end
		local ok, err = pcall(Bind, g, list)
		if not ok then Fault(err) end
		ok, err = pcall(Layout, g)
		if not ok then Fault(err) end
		if #list > 0 then cells = true end
	end
	for key, m in pairs(members) do
		if not seen[m] then
			for _, t in pairs(m.tr) do t.cell = nil end
			members[key] = nil
		end
	end
	local ok, err = pcall(SetFeeds, want)
	if not ok then Fault(err) end
	local wantOwn = next(byCast) ~= nil
	if wantOwn ~= ownOn then
		ownOn = wantOwn
		if wantOwn then
			M:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", OwnCast)
		else
			M:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		end
	end
	if cells then EnsureTicker() end
end

--------------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------------
function M:OnEnable()
	ticker, readTicker, scanTicker, lastN, growing = nil, nil, nil, nil, false
	tracking, taken, ownOn = false, 0, false
	wipe(unitOf)
	wipe(slotOf)
	for _, f in pairs(feeds) do f.on, f.n, f.trackers = false, 0, EMPTY end
	Migrate()
	if inspectQ then inspectQ:Stop() end
	EnsureFrames()
	built = true
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function(m) m:After(0.5, QueueRefresh) end)
	self:RegisterEvent("CHALLENGE_MODE_START", function()
		local n = kit.Now()
		for _, m in pairs(members) do
			for _, t in pairs(m.tr) do
				if not t.loop then
					kit.Clear(t, n)
					kit.Push(t)
				end
			end
		end
		QueueRefresh()
	end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function(m)
		if waitBuild then m:Refresh() end
		QueueScan()
	end)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", function() QueueScan() end)
	self:RegisterEvent("GROUP_ROSTER_UPDATE", function(m)
		QueueRefresh()
		m:After(0.5, QueueRefresh)
	end)
	self:RegisterEvent("INSPECT_READY", function(_, _, guid)
		if IsSecret(guid) or not guid then return end
		local m = members[guid]
		if m and not m.me and ReadInspect(m) then QueueRefresh() end
	end)
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, _, unit)
		if type(unit) == "string" and not IsSecret(unit) and unit ~= "player" then
			for guid, m in pairs(members) do
				if m.unit == unit then
					specByGUID[guid], m.spec, m.asks = nil, nil, nil
					talentsStale[guid] = true
				end
			end
		end
		ownRanks = nil
		QueueRefresh()
	end)
	self:RegisterEvent("TRAIT_CONFIG_UPDATED", function()
		ownRanks = nil
		QueueRefresh()
	end)
	self:RegisterEvent("PLAYER_ROLES_ASSIGNED", QueueRefresh)
end

function M:OnDisable()
	ticker, readTicker, scanTicker, lastN, growing = nil, nil, nil, nil, false
	tracking, taken, ownOn = false, 0, false
	if inspectQ then inspectQ:Stop() end
	for slot = 1, MAX_PLATES do
		if unitOf[slot] then Release(slot) end
	end
	for _, f in pairs(feeds) do
		f.on, f.n, f.trackers = false, 0, EMPTY
		f.chain:SetEnabled(false)
	end
end

function M:OnSettingChanged()
	self:RefreshSoon()
end

function M:OnRefresh()
	preview = self:IsPreview() and true or false
	if not (self.running or preview or built) then return end
	Migrate()
	EnsureFrames()
	for g = 1, GROUPS do XUI.Movers:Apply(bars[g].frame) end
	Rebuild()
end

function M:DebugInfo()
	local out = {}
	out[#out + 1] = format("value check: %s%s", door.state, door.off and format(" (off by %.1e)", door.off) or "")
	out[#out + 1] = format("aura containers: %s | watching: %s | enemies watched: %d | rules hold: %s", HAS_WIDGETS and "yes" or "NO",
		tracking and "yes" or "no", taken, tostring(rulesHold))
	out[#out + 1] = format("reads %d (hidden %d), own casts %d (hidden %d), scans %d, errors %d",
		stats.reads, stats.hidden, stats.own, stats.ownHidden, stats.scans, stats.errors)
	if stats.lastErr then out[#out + 1] = "last error: " .. stats.lastErr end
	if waitBuild then out[#out + 1] = "sensors are built when combat ends" end
	local n = kit.Now()
	for id, f in pairs(feeds) do
		if f.on then
			out[#out + 1] = format("%s (%d): %d sensors, filter %s%s%s", XUI.GetSpellName(id), id, f.chain.n, f.chain.filter,
				f.chain.note and (" (fell back: " .. f.chain.note .. ")") or "", f.chain.failed and (" | FAILED: " .. f.chain.failed) or "")
		end
	end
	for _, m in pairs(members) do
		if not m.fake then
			out[#out + 1] = format("%s: %s, spec %s, role %s, talents %s", tostring(m.unit), tostring(m.class), tostring(m.spec),
				tostring(m.role), (m.me or (m.guid and talentsByGUID[m.guid])) and "read" or "not read")
			for id, t in pairs(m.tr) do
				out[#out + 1] = format("   %s (%d), %d s: %s", XUI.GetSpellName(id), id, t.cd, kit.State(t, n))
			end
		end
	end
	return out
end
