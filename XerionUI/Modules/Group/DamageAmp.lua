--------------------------------------------------------------------------------
-- Boss Damage Amp
-- Murder Row, Kystia Manaheart: when one of the two bosses finishes its timed
-- cast, the OTHER one takes extra damage for 20 seconds. The bar counts the
-- window down (a white tick runs along it) and its fill is that boss's health,
-- so you see how much of it is left to burn in the window.
--
-- There is no event for the amp itself, so the cast is recognised by its
-- timing: a cast that finishes `cast` seconds (+/- slack) after it started on
-- boss1 or boss2. Cast events on boss units are readable, only the bar ID in
-- the payload can be secret and is then ignored. Health goes straight into the
-- status bar (secret-safe); the percentage is formatted by the client.
--
-- Ported from KiraUI-Plugin's Kira Reminders (personal-use licence).
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local T = XUI.Templates
local Style = XUI.Style

local M = XUI:NewModule("DamageAmp", {
	name = "Boss Damage Amp",
	desc = "Murder Row: a bar for the 20 second damage window on the boss that did not cast (Kystia Manaheart).",
	category = "dungeon",
	dungeon = "Murder Row",
	icon = [[Interface\Icons\Ability_Warrior_Rampage]],
	order = 80,
	defaults = {
		text = "Damage Amp",
		showPercent = true,
		color = { 0.85, 0.15, 0.15, 1 },
		bar = T.Bar(260, 22),
		border = T.Border(),
		label = T.Font(13, { color = { 1, 1, 1, 1 } }),
		timer = T.Font(13, { color = { 1, 1, 1, 1 } }),
		percent = T.Font(13, { color = { 1, 1, 1, 1 } }),
		alert = T.Alert("NONE", { text = "Damage" }),
		position = T.Position(0, 60, "HIGH"),
	},
})

-- instanceID -> rules; `cast` is how long the telling cast takes, `window` how
-- long the amp lasts
local RULES = {
	[2813] = {
		{ enc = 3101, boss = "Kystia Manaheart", units = { "boss1", "boss2" }, cast = 2, slack = 0.45, window = 20 },
	},
}
local OTHER = { boss1 = "boss2", boss2 = "boss1" }
local CAST_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
}
-- the payload slot the cast bar ID sits in
local BAR_ID_FIFTH = { UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_STOP = true }

local display, armed, live, ticker
local castStart, castBar = {}, {}

local function InstanceID()
	local inInstance = IsInInstance()
	if not inInstance then return 0 end
	return select(8, GetInstanceInfo()) or 0
end

local function Display()
	if display then return display end
	local d = XUI.Widgets:CreateBar("XUI_DamageAmp")
	d:Hide()
	d.percent = d.texts:CreateFontString(nil, "OVERLAY")
	d.tick = d.texts:CreateTexture(nil, "ARTWORK")
	d.tick:SetColorTexture(1, 1, 1, 1)
	d.tickEdge = d.texts:CreateTexture(nil, "BORDER")
	d.tickEdge:SetColorTexture(0, 0, 0, 1)
	d.tickEdge:SetPoint("CENTER", d.tick, "CENTER")
	d.icon:Hide()
	XUI.Movers:Register(d, M, "position")
	display = d
	return d
end

local function SetTick(frac)
	local d = display
	local w = d.bar:GetWidth() or 0
	d.tick:ClearAllPoints()
	d.tick:SetPoint("CENTER", d.bar, "LEFT", w * math.max(0, math.min(1, frac)), 0)
end

local function Curve()
	local cc = _G.CurveConstants
	return _G.UnitHealthPercent and cc and cc.ScaleTo100 or nil
end

-- the health of the amped boss into the bar and its percentage text
local function Feed()
	if not (live and live.unit) then return end
	local d = display
	local ok, hp = pcall(UnitHealth, live.unit)
	if ok then pcall(d.bar.SetValue, d.bar, hp) end
	local curve = Curve()
	local okP, pct
	if curve then okP, pct = pcall(UnitHealthPercent, live.unit, true, curve) end
	if not (okP and pcall(d.percent.SetFormattedText, d.percent, "%d%%", pct)) then
		d.percent:SetText("")
	end
end

local function Hide()
	if ticker then M:CancelTicker(ticker) ticker = nil end
	if display and not M:IsPreview() then display:Hide() end
end

local function Stop()
	if not live then return end
	live = nil
	M:UnregisterEvent("UNIT_HEALTH")
	Hide()
	M:Refresh()
end

local function Tick()
	if not live then return end
	local left = live.dur - (GetTime() - live.t0)
	if left <= 0 then return Stop() end
	SetTick(left / live.dur)
	display.time:SetFormattedText("%.1f", left / live.dur * live.shown)
	if live.sim then live.sim((GetTime() - live.t0) / live.dur) end
end

local function Begin(text, unit, window, sim, dur)
	local d = Display()
	local now = GetTime()
	live = { unit = unit, t0 = now, dur = dur or window, shown = window, sim = sim }
	d.name:SetText(text or "")
	M:Refresh()
	if sim then
		d.bar:SetMinMaxValues(0, 1)
	else
		local okH, hp = pcall(UnitHealth, unit)
		local okM = okH and pcall(d.bar.SetMinMaxValues, d.bar, 0, hp)
		if not okM then
			local okX, max = pcall(UnitHealthMax, unit)
			if okX then pcall(d.bar.SetMinMaxValues, d.bar, 0, max) end
		end
		M:RegisterUnitEvent("UNIT_HEALTH", unit, Feed)
	end
	d:Show()
	SetTick(1)
	Tick()
	Feed()
	if ticker then M:CancelTicker(ticker) end
	ticker = M:NewTicker(0.05, Tick)
end

local function Start(rule, unit)
	if live and not live.sim and GetTime() - live.t0 < 5 then return end
	Begin(M.db.text, unit, rule.window)
	XUI.Audio:Play(M.db.alert, M.db.text)
end

local function Safe(v)
	if XUI.IsSecret(v) or type(v) ~= "number" then return nil end
	return v
end

function M:OnCast(event, unit, _, _, a4, a5)
	if XUI.IsSecret(unit) or type(unit) ~= "string" or not armed then return end
	local now = GetTime()
	local barID = Safe(BAR_ID_FIFTH[event] and a5 or a4)
	local start = castStart[unit]
	local gap = start and (now - start)
	if event == "UNIT_SPELLCAST_START" then
		castStart[unit], castBar[unit] = now, barID
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		castStart[unit], castBar[unit] = nil, nil
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if gap and not (barID and castBar[unit] and barID ~= castBar[unit])
			and gap >= armed.cast - armed.slack and gap <= armed.cast + armed.slack then
			castStart[unit], castBar[unit] = nil, nil
			Start(armed, OTHER[unit])
		end
	end
end

local function Arm(self, encounter)
	local list = RULES[InstanceID()]
	armed = nil
	for _, rule in ipairs(list or {}) do
		if rule.enc == encounter then armed = rule end
	end
	wipe(castStart)
	wipe(castBar)
	if not armed then return end
	for _, event in ipairs(CAST_EVENTS) do
		self:RegisterUnitEvent(event, armed.units, "OnCast")
	end
end

local function Disarm(self)
	armed = nil
	for _, event in ipairs(CAST_EVENTS) do self:UnregisterEvent(event) end
	Stop()
end

function M:OnEnable()
	Display()
	self:RegisterEvent("ENCOUNTER_START", function(self, _, id) Arm(self, tonumber(id)) end)
	self:RegisterEvent("ENCOUNTER_END", Disarm)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", Disarm)
end

-- plays the bar with a made-up health curve for eight seconds
function M:Test()
	if not self:RequireRunning() then return end
	if live and not live.sim then return end
	local d = Display()
	Begin(self.db.text, nil, 20, function(f)
		local hp = math.max(0, 1 - 1.08 * f ^ 1.7)
		d.bar:SetValue(hp)
		d.percent:SetFormattedText("%d%%", hp * 97)
	end, 8)
end

function M:OnRefresh()
	if not (display or self:IsPreview()) then return end
	local d, db = Display(), self.db
	XUI.Movers:Apply(d)
	d:ApplyLayout(db.bar, db.border, "NONE")
	d:SetColor(XUI.UnpackColor(db.color))
	d:ApplyNameText(db.label)
	d:ApplyTimeText(db.timer)
	Style:ApplyFont(d.percent, db.percent)
	d.percent:ClearAllPoints()
	d.percent:SetPoint("CENTER", d.bar, "CENTER")
	d.percent:SetShown(db.showPercent)
	local h = d.bar:GetHeight() or 22
	d.tick:SetSize(2, h + 6)
	d.tickEdge:SetSize(4, h + 8)
	if live then return end
	if self:IsPreview() then
		d.bar:SetMinMaxValues(0, 100)
		d.bar:SetValue(46)
		d.name:SetText(db.text)
		d.percent:SetText("44%")
		d.time:SetText("11.0")
		SetTick(0.55)
		d:Show()
	else
		d:Hide()
	end
end
