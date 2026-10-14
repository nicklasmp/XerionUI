--------------------------------------------------------------------------------
-- Chaos Barrage counter
-- Murder Row, Kystia Manaheart: Nibbles' bolts come in groups. A row of boxes
-- counts the bolts left in the group and a small bar counts down the bolt being
-- cast, so the tank knows when the group ends and a different cast follows.
--
-- Nothing tells us which boss casts the bolts, so every cast on boss1 / boss2
-- is timed: a bolt is a cast of `cast` seconds, the other cast takes `other`
-- seconds. The unit with the most recognised bolts is the one followed. When the
-- boss stops casting for `quiet` seconds, or starts a channel, the counter hides
-- itself and comes back (full) on the next cast or `hold` seconds after the
-- channel ends. Only the cast timing is used, so secret payloads do not matter;
-- an unreadable cast bar ID is ignored.
--
-- Dropped from the Kira original: sitting on an EllesmereUI nameplate (use the
-- position's attach option for that) and the chat debug report.
-- Ported from KiraUI-Plugin's Kira Reminders (personal-use licence).
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local T = XUI.Templates
local Style = XUI.Style

local M = XUI:NewModule("ChaosBarrage", {
	name = "Chaos Barrage Counter",
	desc = "Murder Row: counts the bolts left in a group and times the current bolt (Kystia Manaheart).",
	category = "dungeon",
	dungeon = "Murder Row",
	icon = [[Interface\Icons\Spell_Shadow_ShadowBolt]],
	order = 81,
	defaults = {
		roles = { TANK = true, HEALER = false, DAMAGER = false },
		color = { 0.1, 0.85, 0.85, 1 },
		emptyColor = { 0.08, 0.08, 0.08, 0.75 },
		width = 150,
		height = 14,
		gap = 2,
		showCast = true,
		cast = T.Bar(150, 12, { color = { 0.85, 0.15, 0.15, 1 } }),
		castTimer = T.Font(11, { color = { 1, 1, 1, 1 } }),
		border = T.Border(),
		alert = T.Alert("NONE", { text = "Bolts" }),
		position = T.Position(0, 30, "HIGH"),
	},
})

local RULES = {
	[2813] = {
		{ enc = 3101, boss = "Kystia Manaheart", units = { "boss1", "boss2" }, cast = 3, other = 3.5,
		  slack = 0.25, lean = 0.15, first = 4, loop = 3, quiet = 2.5, late = 1.1, hold = 10 },
	},
}
local CAST_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
}
local DEMO = { pace = 0.8, steps = {
	{ 4, 4, true }, { 4, 3, true }, { 4, 2, true }, { 4, 1, true }, { 3, 3 },
	{ 3, 3, true }, { 3, 2, true }, { 3, 1, true }, { 3, 3 },
} }
local MAX_BOXES = 6

local display
local ticker
local rule                      -- the rule counting right now
local unit                      -- the boss unit that casts the bolts
local total, left = 0, 0
local busy, heard = false, 0
local away, wait
local sim, simStep
local castT0, castLen
local state = {}                -- unit -> { start, expect, votes }

local function InstanceID()
	local inInstance = IsInInstance()
	if not inInstance then return 0 end
	return select(8, GetInstanceInfo()) or 0
end

-- the spec's role; shown when the client will not say
local function RoleShown(db)
	local CSI = C_SpecializationInfo
	local getIndex = (CSI and CSI.GetSpecialization) or _G.GetSpecialization
	local getRole = (CSI and CSI.GetSpecializationRole) or _G.GetSpecializationRole
	local index = getIndex and XUI.Probe(getIndex)
	local role = index and getRole and XUI.Probe(getRole, index)
	if not role then return true end
	return db.roles[role] ~= false
end

local function Display()
	if display then return display end
	local d = CreateFrame("Frame", "XUI_ChaosBarrage", UIParent)
	d:SetSize(150, 14)
	d:Hide()
	d.boxes = {}
	d.castBar = XUI.Widgets:CreateBar("XUI_ChaosBarrageCast", d)
	d.castBar.icon:Hide()
	d.castBar.name:Hide()
	d.castBar:Hide()
	XUI.Movers:Register(d, M, "position")
	display = d
	return d
end

local function Box(i)
	local d = display
	local b = d.boxes[i]
	if b then return b end
	b = CreateFrame("Frame", nil, d)
	b.border = Style:Border(b)
	b.fill = b:CreateTexture(nil, "ARTWORK")
	d.boxes[i] = b
	return b
end

local function Paint()
	if not display then return end
	local db = M.db
	local w, h, gap = db.width, db.height, db.gap
	local each = total > 0 and (w - gap * (total - 1)) / total or 0
	local r, g, b, a = XUI.UnpackColor(db.color)
	local er, eg, eb, ea = XUI.UnpackColor(db.emptyColor)
	for i = 1, math.max(total, #display.boxes) do
		local box = display.boxes[i]
		if i <= total and i <= MAX_BOXES then
			box = box or Box(i)
			local x = (i - 1) * (each + gap)
			box:ClearAllPoints()
			box:SetPoint("TOPLEFT", display, "TOPLEFT", x, 0)
			box:SetSize(each, h)
			local inset = box.border:Apply(db.border)
			box.fill:ClearAllPoints()
			box.fill:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
			box.fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
			if i <= left then box.fill:SetColorTexture(r, g, b, a) else box.fill:SetColorTexture(er, eg, eb, ea) end
			box:Show()
		elseif box then
			box:Hide()
		end
	end
end

local function CastTick()
	local bar = display and display.castBar
	if not (bar and castT0) then return end
	local t = GetTime() - castT0
	if t > castLen + 0.4 then
		castT0 = nil
		bar:Hide()
		return
	end
	local rest = math.max(0, castLen - t)
	bar.bar:SetValue(rest)
	bar.time:SetFormattedText("%.1f", rest)
end

local function CastBar(len, t0)
	local bar = display and display.castBar
	if not bar then return end
	if not len then
		castT0 = nil
		bar:Hide()
		return
	end
	castT0, castLen = t0, len
	bar.bar:SetMinMaxValues(0, len)
	bar:Show()
	CastTick()
end

local function Set(t, l)
	if total == t and left == l then return end
	total, left = t, l
	Paint()
end

local function Idle()
	-- the box is shown while counting (or simulating); the ticker lives with it
	local now = GetTime()
	CastTick()
	if sim then
		local i = math.max(1, math.ceil((now - sim) / DEMO.pace))
		local step = DEMO.steps[i]
		if step then
			Set(step[1], step[2])
			if simStep ~= i then
				simStep = i
				if step[3] then CastBar(DEMO.pace, sim + (i - 1) * DEMO.pace) else CastBar() end
			end
		else
			sim, simStep = nil, nil
			M:Refresh()
		end
		return
	end
	if not rule or away or wait then return end
	if busy then
		if now - heard > rule.other + 1.5 then busy, heard = false, now end
	elseif now - heard > rule.quiet then
		M:Away(now)
	end
end

local function Show()
	display:Show()
	if not ticker then ticker = M:NewTicker(0.05, Idle) end
end

local function HideAll()
	if ticker then M:CancelTicker(ticker) ticker = nil end
	CastBar()
	if display and not M:IsPreview() then display:Hide() end
end

function M:Away(now)
	if away then return end
	away, wait, busy = now, nil, false
	local s = unit and state[unit]
	if s then s.start, s.expect = nil, nil end
	CastBar()
	if ticker then M:CancelTicker(ticker) ticker = nil end
	display:Hide()
end

function M:Back()
	if not away then return end
	away, wait = nil, true
	busy, heard = false, GetTime()
	total, left = rule.first, rule.first
	Paint()
	Show()
end

local function Spend()
	if left > 0 then Set(total, left - 1) else Set(rule.loop, rule.loop - 1) end
end

local function Kind(gap, lean)
	local slack = rule.slack
	if gap < rule.cast - slack or gap > rule.other + 2 * slack then return nil end
	if gap < (rule.cast + rule.other) / 2 + lean then return "bolt" end
	return "other"
end

-- the unit with the most recognised bolts is the one followed
local function Vote(s, u)
	s.votes = (s.votes or 0) + 1
	local own = unit and state[unit]
	if not own or s.votes > (own.votes or 0) then unit = u end
end

local function Close(s, u, kind, now)
	if kind == "bolt" then Vote(s, u) end
	if u ~= unit then return end
	wait = nil
	busy, heard = false, now
	CastBar()
	if kind == "bolt" then
		Spend()
	elseif kind == "other" then
		Set(rule.loop, rule.loop)
	end
end

local function Begin(s, u, now, prev)
	local gap = prev and (now - prev)
	if gap and gap >= rule.cast - rule.slack and gap <= rule.other + rule.late and (not unit or u == unit) then
		Close(s, u, s.expect or "bolt", now)
	end
	s.expect = nil
	if unit and u ~= unit then return end
	if away then M:Back() end
	wait = nil
	busy, heard = true, now
	if left > 0 then
		s.expect = "bolt"
		CastBar(rule.cast, now)
	else
		s.expect = "other"
		Set(rule.loop, rule.loop)
		CastBar()
	end
end

function M:OnCast(event, u)
	if XUI.IsSecret(u) or type(u) ~= "string" or not rule then return end
	local s = state[u]
	if not s then s = {} state[u] = s end
	local now = GetTime()
	if event == "UNIT_SPELLCAST_CHANNEL_START" then
		s.start = nil
		if u == unit and not wait then self:Away(now) end
		return
	end
	if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if u == unit and away and now - away >= rule.hold then self:Back() end
		return
	end
	if event == "UNIT_SPELLCAST_START" then
		local prev = s.start
		s.start = now
		Begin(s, u, now, prev)
		return
	end
	local gap = s.start and (now - s.start)
	if not gap then return end
	local lean = 0
	if u == unit or not unit then
		local other = s.expect == "other" or (not s.expect and left <= 0)
		lean = other and -rule.lean or rule.lean
	end
	local kind = Kind(gap, lean)
	if event == "UNIT_SPELLCAST_SUCCEEDED" and not kind then return end
	s.start = nil
	if event == "UNIT_SPELLCAST_INTERRUPTED" then kind = nil end
	Close(s, u, kind, now)
end

local function Stop()
	if not rule then return end
	rule, unit, away, wait = nil, nil, nil, nil
	HideAll()
	M:Refresh()
end

local function Start(self, r)
	if not RoleShown(self.db) then return end
	sim, simStep = nil, nil
	rule, unit = r, nil
	wipe(state)
	busy, heard = false, GetTime()
	away, wait = nil, true
	total, left = r.first, r.first
	self:Refresh()
	CastBar()
	Show()
end

local function Zone(self)
	for _, event in ipairs(CAST_EVENTS) do self:UnregisterEvent(event) end
	local list = RULES[InstanceID()]
	if not list then return end
	for _, r in ipairs(list) do
		for _, event in ipairs(CAST_EVENTS) do
			self:RegisterUnitEvent(event, r.units, "OnCast")
		end
	end
end

function M:OnEnable()
	Display()
	Zone(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function(self) Stop() Zone(self) end)
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", Zone)
	self:RegisterEvent("ENCOUNTER_START", function(self, _, id)
		Zone(self)
		id = tonumber(id)
		for _, r in ipairs(RULES[InstanceID()] or {}) do
			if r.enc == id then Start(self, r) end
		end
	end)
	self:RegisterEvent("ENCOUNTER_END", Stop)
end

-- plays the boxes: four bolts, then three, twice
function M:Test()
	if not self:RequireRunning() then return end
	if rule then return end
	sim, simStep = GetTime(), nil
	Display()
	self:Refresh()
	Show()
	Idle()
end

function M:OnRefresh()
	if not (display or self:IsPreview()) then return end
	local d, db = Display(), self.db
	XUI.Movers:Apply(d)
	d:SetSize(db.width, db.height)
	local cb = d.castBar
	cb:ClearAllPoints()
	cb:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -2)
	cb:SetPoint("TOPRIGHT", d, "BOTTOMRIGHT", 0, -2)
	cb:ApplyLayout(db.cast, db.border, "NONE")
	cb:SetColor(XUI.UnpackColor(db.cast.color or { 0.85, 0.15, 0.15, 1 }))
	cb:ApplyTimeText(db.castTimer)
	cb:SetWidth(db.width)
	cb.time:SetShown(db.castTimer.enabled ~= false)
	if rule or sim then
		Paint()
		return
	end
	if self:IsPreview() then
		total, left = 4, 3
		Paint()
		if db.showCast then
			castT0 = nil
			cb.bar:SetMinMaxValues(0, 3)
			cb.bar:SetValue(1.4)
			cb.time:SetText("1.4")
			cb:Show()
		else
			cb:Hide()
		end
		d:Show()
	else
		total, left = 0, 0
		cb:Hide()
		d:Hide()
	end
end
