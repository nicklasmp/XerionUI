--------------------------------------------------------------------------------
-- Focus Cast Bar background
-- Tints the empty background behind EllesmereUI Mythic+ Tools' standalone
-- focus cast bar - NOT the focus cast bar of the unit frames. The Mythic+ Tools
-- module keeps its bar object private, so the bar is found from its saved
-- settings (width, height and the screen position of its centre) and its
-- StatusBar child, wherever and however it is anchored.
--
-- The background is the large texture behind the fill. Rather than painting it
-- once and hoping, the texture's own color setters are hooked, so whenever
-- EllesmereUI recolors it (a rebuild, a new cast, a profile change) our color
-- goes straight back on. The hook is installed once per texture and does
-- nothing while the module is off.
--
-- The FocusKick sound (formerly its own module) lives in the second half of
-- this file: one spoken alert for EllesmereUI's FocusKick, see the notes there.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local M = XUI:NewModule("EUIFocusCastbar", {
	name = "Focus Cast Bar",
	desc = "A custom background for the Mythic+ Tools focus cast bar, and a spoken Kick alert when your FocusKick target casts something you can interrupt.",
	category = "tweaks",
	icon = [[Interface\Icons\Spell_Nature_Polymorph]],
	order = 30,
	requires = "EllesmereUIMythicTimer",
	defaults = {
		color = { 0.08, 0.08, 0.08, 0.75 },
		kick = {
			enabled = true,
			text = "Kick",
			voice = "",
			volume = 100,
			rate = 0,
		},
	},
})

local function FocusSettings()
	local db = _G._EMT_AceDB
	local prof = db and db.profile
	local tfb = prof and prof.tfb
	return tfb and tfb.focus
end

local why -- why the bar was not found, for /xui debug
local bar, bgTexture

-- the centre of a frame as an offset from the centre of the screen, in UIParent units
local function CenterOffset(frame)
	local cx, cy = frame:GetCenter()
	local ux, uy = UIParent:GetCenter()
	if not (cx and ux) then return nil end
	local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return cx * k - ux, cy * k - uy
end

local barKids = {}
local function HasStatusBar(frame)
	for _, child in ipairs(XUI.Children(frame, barKids)) do
		if child.GetObjectType and child:GetObjectType() == "StatusBar" then return true end
	end
	return false
end

local function Matches(frame, width, height, x, y)
	if not frame.GetWidth or (frame.IsForbidden and frame:IsForbidden()) then return false end
	if math.abs((frame:GetWidth() or 0) - width) > 1 or math.abs((frame:GetHeight() or 0) - height) > 1 then return false end
	local fx, fy = CenterOffset(frame)
	if not fx or math.abs(fx - x) > 3 or math.abs(fy - y) > 3 then return false end
	return HasStatusBar(frame)
end

local function FindBar()
	local focus = FocusSettings()
	if not focus then why = "EllesmereUI Mythic+ Tools has no focus cast bar settings" return nil end
	if focus.enabled == false then why = "the focus cast bar is switched off in EllesmereUI" return nil end
	local pos = focus.pos
	local x, y = pos and pos.centerX or 0, pos and pos.centerY or -310
	local width, height = focus.width or 260, focus.height or 22
	if bar and Matches(bar, width, height, x, y) then return bar end
	bar, bgTexture = nil, nil
	-- every frame, not only UIParent's children: the bar may hang off a holder
	local frame = EnumerateFrames()
	while frame do
		if Matches(frame, width, height, x, y) then
			bar = frame
			why = "found"
			return bar
		end
		frame = EnumerateFrames(frame)
	end
	why = ("no frame of %dx%d centred at %d,%d with a status bar"):format(width, height, x, y)
	return nil
end

-- The background: the biggest texture of the holder that is not the fill,
-- lowest layer first.
local LAYER_RANK = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
local function FindBackground(holder)
	local best, bestRank
	local w, h = holder:GetWidth(), holder:GetHeight()
	for _, region in ipairs({ holder:GetRegions() }) do
		if region.SetColorTexture and region.GetDrawLayer then
			local rw, rh = region:GetWidth(), region:GetHeight()
			if rw and rh and rw >= w * 0.9 and rh >= h * 0.9 then
				local rank = LAYER_RANK[region:GetDrawLayer()] or 9
				if not best or rank < bestRank then best, bestRank = region, rank end
			end
		end
	end
	if best then return best end
	-- the original assumption: the first region is the background
	local first = holder:GetRegions()
	if first and first.SetColorTexture then return first end
	return nil
end

local hooked = setmetatable({}, { __mode = "k" })
local guard = false

local function Apply(tex)
	guard = true
	tex:SetColorTexture(XUI.UnpackColor(M.db.color))
	guard = false
end

local function Hook(tex)
	if hooked[tex] then return end
	hooked[tex] = true
	local function reapply(t)
		if guard or not M.running then return end
		Apply(t)
	end
	hooksecurefunc(tex, "SetColorTexture", reapply)
	hooksecurefunc(tex, "SetVertexColor", reapply)
	hooksecurefunc(tex, "SetTexture", reapply)
end

local function Paint(on)
	local holder = FindBar()
	if not holder then return end
	if not (bgTexture and bgTexture:GetParent() == holder) then bgTexture = FindBackground(holder) end
	if not bgTexture then why = "found the bar but not its background texture" return end
	if on then
		Hook(bgTexture)
		Apply(bgTexture)
	else
		guard = true
		bgTexture:SetColorTexture(0, 0, 0, 0.45) -- EllesmereUI's own
		guard = false
	end
end

-- the bar may be built a moment after the focus changes or after login
local function PaintSoon(self)
	self:After(0, function() Paint(true) end)
	self:After(0.3, function() Paint(true) end)
	self:After(1, function() Paint(true) end)
end


--------------------------------------------------------------------------------
-- FocusKick sound
-- WHY SPEECH AND NEVER A SOUND FILE
-- "Can be interrupted" is a secret boolean for other units in keys. Lua
-- cannot branch on it and PlaySoundFile refuses secrets, but SpeakText takes
-- a secret text. The engine turns the flag into the words or nothing:
--   C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, 0, 1)  -> 0 / 1
--   C_StringUtil.TruncateWhenZero(n)                                   -> "" / "1"
--   C_StringUtil.WrapString(s, '<silence msec="', '"/>Kick')          -> "" / words
-- (a 1 ms silence tag on Windows, [[slnc 1]] on Mac), so a protected cast
-- says nothing and Lua never learns which it was.
--
-- The kick's own cooldown is readable; a Cooldown frame fed its duration
-- object calls OnCooldownDone the moment it ends (SPELL_UPDATE_COOLDOWN does
-- not reliably fire then).

--------------------------------------------------------------------------------
local IsSecret = XUI.IsSecret
local EvalBool = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
local TruncateWhenZero = C_StringUtil and C_StringUtil.TruncateWhenZero
local WrapString = C_StringUtil and C_StringUtil.WrapString
local CAN_GATE = (EvalBool and TruncateWhenZero and WrapString) and true or false
local IS_MAC = (IsMacClient and IsMacClient()) and true or false
local READY_GAP = 1
local SHIELD_AFTER_START = 0.3

local function CDM()
	return XUI.EUI and XUI.EUI.Module("EllesmereUICooldownManager")
end

local function FKBar()
	local m = CDM()
	local byKey = m and m.barDataByKey
	return byKey and byKey[m.FOCUSKICK_BAR_KEY or "focuskick"], m
end

-- EllesmereUI's GetFocusKickUnit: "target" with Show on Target, else "focus"
local function WatchUnit()
	local m = CDM()
	local f = m and m.GetFocusKickUnit
	if f then
		local ok, u = pcall(f)
		if ok and (u == "focus" or u == "target") then return u end
	end
	return "focus"
end

-- the FocusKick pick, then its bar, then our own interrupt list
local function ResolveKick()
	local bd, m = FKBar()
	local resolve = m and m.ResolveCastableInterrupt
	if bd and resolve then
		local pick = bd.focusKickInterruptSpellID
		if type(pick) == "number" and pick > 0 then
			local ok, id = pcall(resolve, pick)
			if ok and id then return id end
		end
		local ok, sd = pcall(m.GetBarSpellData, m.FOCUSKICK_BAR_KEY or "focuskick")
		local spells = ok and type(sd) == "table" and sd.assignedSpells
		if type(spells) == "table" then
			for _, sid in ipairs(spells) do
				if type(sid) == "number" and sid > 0 then
					local ok2, id = pcall(resolve, sid)
					if ok2 and id then return id end
				end
			end
		end
	end
	local id, poll = XUI.Data.PlayerKick()
	return poll or id or false
end

--------------------------------------------------------------------------------
-- Speaking
--------------------------------------------------------------------------------
local function Words()
	local w = M.db.kick.text
	if type(w) ~= "string" or not w:find("%S") then return "Kick" end
	return w
end

local function Say(text)
	local db = M.db.kick
	XUI.Audio:Speak(text, db.voice, db.volume, db.rate)
end

local function XmlEscape(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function GatedWords(words, notInt)
	local digit = TruncateWhenZero(EvalBool(notInt, 0, 1))
	if IS_MAC then return WrapString(digit, "[[slnc ", "]]" .. words) end
	return WrapString(digit, '<silence msec="', '"/>' .. XmlEscape(words))
end

local function Hostile(unit)
	return XUI.Ask(UnitCanAttack, "player", unit) ~= false
end

local function CastState(unit, channel)
	if channel then
		local name, _, _, _, _, _, notInt = UnitChannelInfo(unit)
		return name, notInt
	end
	local name, _, _, _, _, _, _, notInt = UnitCastingInfo(unit)
	return name, notInt
end

-- Speaks for the unit's current cast when it can be interrupted (or lets the
-- engine decide when that is secret). channel nil looks at both.
local function RingForCast(unit, channel)
	local ok, name, notInt
	if channel == nil then
		ok, name, notInt = pcall(CastState, unit, false)
		if not ok or type(name) == "nil" then ok, name, notInt = pcall(CastState, unit, true) end
	else
		ok, name, notInt = pcall(CastState, unit, channel)
	end
	if not ok or type(name) == "nil" then return false end
	if not IsSecret(notInt) then
		if notInt then return true end
		Say(Words())
		return true
	end
	if not CAN_GATE then return true end
	local okText, text = pcall(GatedWords, Words(), notInt)
	if okText then Say(text) end
	return true
end

--------------------------------------------------------------------------------
-- The kick's cooldown
--------------------------------------------------------------------------------
local kickID, tracker, armed, lastReadyAt = nil, nil, false, -READY_GAP

local function Kick()
	if kickID == nil then kickID = ResolveKick() end
	return kickID or nil
end

-- running, duration object (nil when the duration API does not know the spell)
local function KickState(id)
	local info = C_Spell.GetSpellCooldown(id)
	local active, onGCD = XUI.Readable(info and info.isActive), XUI.Readable(info and info.isOnGCD)
	local running = (active and not onGCD) and true or false
	local dur
	if running and C_Spell.GetSpellCooldownDuration then
		local ok, d = pcall(C_Spell.GetSpellCooldownDuration, id)
		if ok then dur = d end
	end
	return running, dur
end

-- true = on cooldown, false = ready, nil = no interrupt
local function KickBusy()
	local id = Kick()
	if not id then return nil end
	local ok, running = pcall(KickState, id)
	if not ok then return nil end
	return running
end

local function KickBack()
	local now = GetTime()
	if now - lastReadyAt < READY_GAP then return end
	lastReadyAt = now
	if not M.running or not M.db.kick.enabled then return end
	local unit = WatchUnit()
	if UnitExists(unit) and Hostile(unit) then RingForCast(unit, nil) end
end

local function EnsureTracker()
	if tracker then return tracker end
	local bucket = CreateFrame("Frame", nil, UIParent)
	bucket:SetSize(1, 1)
	bucket:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -10000, -10000)
	tracker = CreateFrame("Cooldown", nil, bucket, "CooldownFrameTemplate")
	tracker:SetAllPoints(bucket)
	tracker:SetDrawSwipe(false)
	tracker:SetDrawEdge(false)
	tracker:SetDrawBling(false)
	tracker:SetHideCountdownNumbers(true)
	tracker.noCooldownCount = true
	tracker:SetScript("OnCooldownDone", function()
		if not armed then return end
		armed = false
		KickBack()
	end)
	return tracker
end

local ReadKick
local QueueReread = XUI.Coalesce(function() M:After(0.25, function() ReadKick() end) end)

ReadKick = function()
	local id = Kick()
	if not id then armed = false return end
	local ok, running, dur = pcall(KickState, id)
	if not ok then return end
	if running then
		-- right after it came back a read can still say "running"
		local since = GetTime() - lastReadyAt
		if since < READY_GAP then
			M:After(READY_GAP - since + 0.05, ReadKick)
			return
		end
		armed = true
		if dur then
			local t = EnsureTracker()
			pcall(t.SetCooldownFromDurationObject, t, dur)
		else
			QueueReread()
		end
	elseif armed then
		-- ended early: a reset or a refund
		armed = false
		if tracker then tracker:Clear() end
		KickBack()
	end
end

local function RefreshKick()
	local old = kickID
	kickID = nil
	if Kick() ~= old then
		armed = false
		if tracker then tracker:Clear() end
	end
end

--------------------------------------------------------------------------------
-- Casts
--------------------------------------------------------------------------------
local lastStartAt = 0

local function OnCast(event, unit)
	if not M.db.kick.enabled then return end
	if unit ~= WatchUnit() then return end
	local shield = event == "UNIT_SPELLCAST_INTERRUPTIBLE"
	local now = GetTime()
	if shield then
		if now - lastStartAt < SHIELD_AFTER_START then return end
	else
		lastStartAt = now
	end
	if not Hostile(unit) then return end
	-- on cooldown: the kick half speaks if the cast is still going later
	if KickBusy() ~= false then return end
	if shield then
		local ok, name = pcall(CastState, unit, false)
		if not ok or type(name) == "nil" then ok, name = pcall(CastState, unit, true) end
		if ok and type(name) ~= "nil" then Say(Words()) end
		return
	end
	RingForCast(unit, event == "UNIT_SPELLCAST_CHANNEL_START")
end

local function EnableKick(self)
	RefreshKick()
	local QueueRead = XUI.Coalesce(function() if M.running and M.db.kick.enabled then ReadKick() end end)
	local function changed()
		RefreshKick()
		QueueRead()
	end
	self:RegisterEvent("SPELLS_CHANGED", changed)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", changed)
	self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", changed)
	self:RegisterUnitEvent("UNIT_PET", "player", changed)
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN", function(_, _, id, base)
		-- a readable spell that is not the interrupt cannot move it
		if id ~= nil and not IsSecret(id) and kickID and id ~= kickID
			and not (base ~= nil and not IsSecret(base) and base == kickID) then
			return
		end
		QueueRead()
	end)
	self:RegisterEvent("SPELL_UPDATE_CHARGES", QueueRead)
	self:RegisterEvent("PET_BAR_UPDATE_COOLDOWN", QueueRead)
	-- both tokens: Show on Target can switch at any time
	local function cast(_, event, unit) OnCast(event, unit) end
	self:RegisterUnitEvent("UNIT_SPELLCAST_START", { "focus", "target" }, cast)
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", { "focus", "target" }, cast)
	self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", { "focus", "target" }, cast)
	ReadKick()
end

local function DisableKick()
	armed = false
	if tracker then tracker:Clear() end
end

-- The gated path with a plain "interruptible", as a key would run it.
function M:Test()
	if CAN_GATE then
		local ok, text = pcall(GatedWords, Words(), false)
		if ok then Say(text) return end
	end
	Say(Words())
end

local function MigrateKick()
	local db = M.db
	if db.kickMigrated then return end
	db.kickMigrated = true
	local profile = XUI.DB and XUI.DB.profile
	local old = profile and profile.modules and profile.modules.EUIFocusKick
	if type(old) ~= "table" then return end
	for _, k in ipairs({ "text", "voice", "volume", "rate" }) do
		if old[k] ~= nil then db.kick[k] = old[k] end
	end
	if old.enabled ~= nil then db.kick.enabled = old.enabled and true or false end
end

function M:OnEnable()
	local mod = XUI.EUI and XUI.EUI.Module("EllesmereUIMythicTimer")
	if mod and type(mod.TFB_Refresh) == "function" then
		self:SecureHook(mod, "TFB_Refresh", PaintSoon)
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function(self) self:After(1, function() Paint(true) end) end)
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", PaintSoon)
	self:RegisterUnitEvent("UNIT_SPELLCAST_START", "focus", PaintSoon)
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "focus", PaintSoon)
	Paint(true)
	PaintSoon(self)
	MigrateKick()
	EnableKick(self)
end

function M:OnDisable()
	Paint(false)
	DisableKick()
end

-- The sample: a bar of our own in the middle of the screen with the chosen
-- background, because EllesmereUI's real bar only exists with a focus.
local sample
local function Sample()
	if sample then return sample end
	sample = CreateFrame("Frame", "XUI_FocusCastbarSample", UIParent)
	sample:SetFrameStrata("HIGH")
	sample.bg = sample:CreateTexture(nil, "BACKGROUND")
	sample.bg:SetAllPoints()
	sample.bar = CreateFrame("StatusBar", nil, sample)
	sample.bar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
	sample.bar:SetStatusBarColor(0.85, 0.85, 0.2, 1)
	sample.bar:SetMinMaxValues(0, 1)
	sample.bar:SetValue(0.6)
	sample.bar:SetAllPoints()
	sample.border = XUI.Style:Border(sample.bar)
	sample.text = sample.bar:CreateFontString(nil, "OVERLAY")
	XUI.Style:ApplyFont(sample.text, nil, 12)
	sample.text:SetPoint("LEFT", 6, 0)
	sample.text:SetText("Polymorph")
	sample:Hide()
	return sample
end

function M:OnRefresh()
	if self.running then Paint(true) end
	if not (sample or self:IsPreview()) then return end
	local s = Sample()
	local focus = FocusSettings()
	s:SetSize(focus and focus.width or 260, focus and focus.height or 22)
	s:ClearAllPoints()
	s:SetPoint("CENTER", UIParent, "CENTER", 0, -250)
	s.bg:SetColorTexture(XUI.UnpackColor(self.db.color))
	s.border:Apply({ useGlobal = false, style = "SOLID", size = 1, color = { 0, 0, 0, 1 } })
	s:SetShown(self:IsPreview())
end

function M:DebugInfo()
	local mod = XUI.EUI and XUI.EUI.Module("EllesmereUIMythicTimer")
	local holder = FindBar()
	local focus = FocusSettings()
	local out = {
		("Mythic+ Tools namespace: %s, TFB_Refresh: %s"):format(tostring(mod ~= nil), tostring(mod and type(mod.TFB_Refresh))),
		("settings: enabled %s, size %sx%s, centre %s,%s"):format(
			tostring(focus and focus.enabled), tostring(focus and focus.width), tostring(focus and focus.height),
			tostring(focus and focus.pos and focus.pos.centerX), tostring(focus and focus.pos and focus.pos.centerY)),
		("bar: %s"):format(tostring(why)),
	}
	if holder then
		local bg = bgTexture or FindBackground(holder)
		out[#out + 1] = ("background texture: %s, hooked: %s"):format(tostring(bg ~= nil), tostring(bg and hooked[bg] or false))
	end
	return out
end
