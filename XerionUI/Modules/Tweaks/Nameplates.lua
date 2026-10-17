--------------------------------------------------------------------------------
-- EllesmereUI Nameplates tweaks
--
-- Dispel glow without purge or soothe: EllesmereUI only glows Magic/Enrage
-- auras when your character can purge or soothe. This reports both as
-- supported, so its engine-filtered groups still mark them (in keys too).
-- EllesmereUI's own Dispel Glow setting still switches the glow on and off.
--
-- Dispel border color: EllesmereUI marks a dispellable buff with a static
-- border (Blizzard's red pandemic art) on a host frame of the aura button.
-- The buff row's two styles (AuraKit "np:buffs" / "np:buffs2") call an
-- applyExtra for every button; that is wrapped so the border texture is
-- desaturated and tinted with our color. A style table is replaced whenever
-- EllesmereUI rebuilds its styles, so the wrap is repeated after each
-- NPC_ReloadAll / RefreshAllSettings and the buttons are restyled. Off, the
-- border goes back to EllesmereUI's own look.
--
-- Shield amount: the mob's absorb as a number right after EllesmereUI's
-- health text. The amount is secret in keys; it never touches Lua arithmetic
-- - it goes straight into AbbreviateNumbers, SetText and StatusBar:SetValue.
-- "No shield" cannot be tested either, so an invisible 0..1 status bar is fed
-- the raw amount and a clipping frame pinned to its fill owns the text: no
-- shield, no fill, nothing to draw in.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local T = XUI.Templates
local Style = XUI.Style

local M = XUI:NewModule("EUINameplates", {
	name = "Nameplates",
	desc = "Dispel border color (also without purge or soothe) and shield amounts on EllesmereUI nameplates.",
	category = "tweaks",
	icon = [[Interface\Icons\Spell_Holy_PowerWordShield]],
	order = 10,
	requires = "EllesmereUINameplates",
	defaults = {
		dispelAlways = true,
		customBorder = true,
		borderColor = { 1, 0.82, 0.25, 1 },
		shield = { enabled = false, enemyOnly = true, offX = 0, offY = 0 },
		shieldText = T.Font(11, { color = { 1, 0.82, 0.25, 1 } }),
	},
})

local IsSecret = XUI.IsSecret
local SHIELD_GAP = 3
local IsPlateToken = setmetatable({}, { __index = function(t, unit)
	local is = type(unit) == "string" and unit:sub(1, 9) == "nameplate"
	t[unit] = is
	return is
end })
local PREVIEW_AMOUNT = 5500000

local function NP()
	local np = _G.EllesmereNameplates_NS
	return type(np) == "table" and np or nil
end

--------------------------------------------------------------------------------
-- Dispel glow
--------------------------------------------------------------------------------
local function HookDispel()
	local np = NP()
	if not np or np.__xuiDispelHook or type(np.GetOffensiveDispelTypes) ~= "function" then return end
	local original = np.GetOffensiveDispelTypes
	np.GetOffensiveDispelTypes = function(...)
		if M.running and M.db.dispelAlways then return true, true end
		return original(...)
	end
	np.__xuiDispelHook = true
end

local GLOW_KEYS = { "np:buffs", "np:buffs2" }
local stats = { wraps = 0, buttons = 0, tinted = 0 }
local boost = setmetatable({}, { __mode = "k" })
local BORDER_ATLAS = "UI-CooldownManager-PandemicBorder"
local BOOST_LAYERS = 4

-- EllesmereUI's border is Blizzard's red pandemic art: a texture it keeps on
-- the glow host as host._euiPanTex (EllesmereUI 9.6 and later; the host also
-- holds the regions of whatever glow style is picked, so it is not the host's
-- first region). It is only shown while the Dispel Glow style is Blizzard
-- Pandemic Border; any other style is left to EllesmereUI. Desaturated and tinted it takes any color but turns
-- thin, because the red art is dark once it is grey: a second copy of the art
-- is laid over it with additive blending, which brings back the weight.
-- The texture's own shown state is secret on engine buttons, so the style that
-- shows it is read from EllesmereUI's setting instead.
local function PandemicStyle()
	local np, G = NP(), _G.EllesmereUI and _G.EllesmereUI.Glows
	return np and G and type(np.GetDispelGlowStyle) == "function" and np.GetDispelGlowStyle() == G.PANDEMIC_BORDER
end

local function Tint(host, on)
	local tex = host._euiPanTex
	if not (tex and tex.SetVertexColor) then return false end
	local layers = boost[host]
	if on and PandemicStyle() then
		local c = M.db.borderColor
		local r, g, b, a = c[1] or 1, c[2] or 0.82, c[3] or 0.25, c[4] or 1
		tex:SetDesaturated(true)
		tex:SetVertexColor(r, g, b, a)
		if not layers then
			layers = {}
			boost[host] = layers
		end
		for i = 1, BOOST_LAYERS do
			local t = layers[i]
			if not t then
				local ok, made = pcall(host.CreateTexture, host, nil, "ARTWORK", nil, i)
				if ok and made then
					made:SetAllPoints(tex)
					made:SetAtlas(BORDER_ATLAS)
					made:SetBlendMode("ADD")
					t = made
					layers[i] = t
				end
			end
			if t then
				t:SetDesaturated(true)
				t:SetVertexColor(r, g, b, a)
				t:Show()
			end
		end
	else
		tex:SetDesaturated(false)
		tex:SetVertexColor(1, 1, 1, 1)
		if layers then for i = 1, #layers do layers[i]:Hide() end end
	end
	return true
end

local function OnButton(button, d, style)
	stats.buttons = stats.buttons + 1
	local host = d and d.npGlowHost
	if host then
		if Tint(host, M.running and M.db.customBorder) then stats.tinted = stats.tinted + 1 end
	elseif M.running and M.db.dispelAlways and style.purgeGlow ~= true then
		-- a group EllesmereUI does not mark: nothing to tint
		return
	end
end

-- EllesmereUI builds fresh style tables when its settings change: wrap the
-- ones that are not wrapped yet. Returns true when anything was wrapped.
local function WrapStyles()
	local AK = _G.EllesmereUI and _G.EllesmereUI.AuraKit
	local styles = AK and AK.styles
	if type(styles) ~= "table" then return false end
	local wrapped = false
	for _, key in ipairs(GLOW_KEYS) do
		local style = styles[key]
		if style and not style.__xuiGlowWrap and type(style.applyExtra) == "function" then
			local original = style.applyExtra
			style.applyExtra = function(button, d, st)
				original(button, d, st)
				XUI.SafeCallFor(M, OnButton, button, d, st)
			end
			style.__xuiGlowWrap = true
			stats.wraps = stats.wraps + 1
			wrapped = true
		end
	end
	return wrapped
end

local function RestyleGlow()
	local AK = _G.EllesmereUI and _G.EllesmereUI.AuraKit
	if not (AK and type(AK.RestyleSoon) == "function") then return end
	for _, key in ipairs(GLOW_KEYS) do
		if AK.styles and AK.styles[key] then AK.RestyleSoon(key) end
	end
end

local glowSig
local function GlowSignature()
	local c = M.db.borderColor or {}
	return table.concat({ tostring(M.running), tostring(M.db.customBorder),
		tostring(c[1]), tostring(c[2]), tostring(c[3]), tostring(c[4]) }, "|")
end

local function ReloadPlates()
	local np = NP()
	if not np then return end
	if type(np.NPC_ReloadAll) == "function" then
		pcall(np.NPC_ReloadAll)
	elseif type(np.RefreshAllSettings) == "function" then
		pcall(np.RefreshAllSettings)
	end
end

--------------------------------------------------------------------------------
-- Shield text
--------------------------------------------------------------------------------
local preview = false
local gen = 0

local function Showing(r)
	if not r then return false end
	local shown = r:IsShown()
	return not IsSecret(shown) and shown and true or false
end

-- right after EllesmereUI's health text, whichever slot it lives in
local function Anchor(plate)
	if Showing(plate.hpText) then return plate.hpText end
	if Showing(plate.hpNumber) then return plate.hpNumber end
	return plate.health
end

local function Host(plate, anchor)
	local host = anchor ~= plate.health and anchor:GetParent()
	return host or plate.healthTextFrame or plate
end

local function Build(plate)
	local w = plate.__xuiShield
	if w then return w end
	local host = plate.healthTextFrame or plate
	w = {}
	w.gate = CreateFrame("StatusBar", nil, host)
	w.gate:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
	w.gate:SetStatusBarColor(1, 1, 1, 0)
	w.gate:SetMinMaxValues(0, 1)
	w.gate:SetValue(0)
	w.clip = CreateFrame("Frame", nil, host)
	w.clip:SetClipsChildren(true)
	w.clip:SetPoint("TOPLEFT", w.gate, "TOPLEFT", 0, 0)
	w.clip:SetPoint("BOTTOMRIGHT", w.gate:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
	w.fs = w.clip:CreateFontString(nil, "OVERLAY")
	plate.__xuiShield = w
	return w
end

local function LayoutShield(w, anchor, host)
	local db = M.db
	local f = Style:ApplyFont(w.fs, db.shieldText)
	local size = f.size or 11
	if w.gate:GetParent() ~= host then
		w.gate:SetParent(host)
		w.clip:SetParent(host)
	end
	-- a fixed box: the text is secret in a key, and the gate is all or nothing
	w.gate:ClearAllPoints()
	w.gate:SetSize(size * 6, size + 6)
	w.gate:SetPoint("LEFT", anchor, "RIGHT", SHIELD_GAP + db.shield.offX, db.shield.offY)
	w.fs:ClearAllPoints()
	w.fs:SetPoint("LEFT", w.gate, "LEFT", 0, 0)
	w.fs:SetJustifyH("LEFT")
end

local function Wanted(unit)
	if not M.db.shield.enemyOnly then return true end
	return XUI.Ask(UnitCanAttack, "player", unit) ~= false
end

local function Push(w, amount)
	w.gate:SetValue(amount)
	w.fs:SetText(AbbreviateNumbers(amount))
end

local function Paint(plate)
	local w = plate.__xuiShield
	if not w then return end
	local amount = 0
	if preview then
		amount = PREVIEW_AMOUNT
	elseif plate.unit and Wanted(plate.unit) then
		local ok, v = pcall(UnitGetTotalAbsorbs, plate.unit)
		if ok and (IsSecret(v) or type(v) == "number") then amount = v end
	end
	if not pcall(Push, w, amount) then pcall(Push, w, 0) end
end

-- from: "added" (plate came up), "unit" (SetUnit hook), nil (settings pass).
-- A plate is stamped twice when it comes up; the second paint is skipped.
local function ApplyToPlate(plate, from)
	if not (plate and plate.health) then return end
	local on = (M.running or preview) and M.db.shield.enabled
	if not on then
		local w = plate.__xuiShield
		if w then w.gate:Hide() w.clip:Hide() end
		return
	end
	local w = Build(plate)
	local anchor = Anchor(plate)
	local host = Host(plate, anchor)
	if w.gen ~= gen or w.anchor ~= anchor or w.host ~= host then
		w.gen, w.anchor, w.host = gen, anchor, host
		LayoutShield(w, anchor, host)
	end
	w.gate:Show()
	w.clip:Show()
	if from == "added" then
		local fresh = plate.unit and w.hookUnit == plate.unit and w.hookAt == GetTime()
		w.hookUnit = nil
		if fresh then return end
	elseif from == "unit" then
		w.hookUnit, w.hookAt = plate.unit, GetTime()
	end
	Paint(plate)
end

local function Stamp(plate, from)
	if not plate then return end
	ApplyToPlate(plate, from)
	if not plate.__xuiUnitHook and type(plate.SetUnit) == "function" then
		plate.__xuiUnitHook = true
		hooksecurefunc(plate, "SetUnit", function(self) ApplyToPlate(self, "unit") end)
	end
end

-- A stand-in nameplate for the preview when none is on screen: a health bar
-- with a percentage and the shield amount placed exactly as on a real plate.
local standIn
local function StandIn()
	if standIn then return standIn end
	standIn = CreateFrame("Frame", "XUI_ShieldSample", UIParent)
	standIn:SetSize(140, 14)
	standIn:SetFrameStrata("HIGH")
	standIn.bg = standIn:CreateTexture(nil, "BACKGROUND")
	standIn.bg:SetAllPoints()
	standIn.bg:SetColorTexture(0, 0, 0, 0.7)
	standIn.bar = CreateFrame("StatusBar", nil, standIn)
	standIn.bar:SetAllPoints()
	standIn.bar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
	standIn.bar:SetStatusBarColor(0.8, 0.2, 0.2, 1)
	standIn.bar:SetMinMaxValues(0, 1)
	standIn.bar:SetValue(0.72)
	standIn.hp = standIn.bar:CreateFontString(nil, "OVERLAY")
	Style:ApplyFont(standIn.hp, nil, 11)
	standIn.hp:SetPoint("RIGHT", standIn, "RIGHT", -3, 0)
	standIn.hp:SetText("72%")
	standIn.shield = standIn:CreateFontString(nil, "OVERLAY")
	standIn:Hide()
	return standIn
end

local function PaintStandIn(show)
	if not (show or standIn) then return end
	local f = StandIn()
	f:ClearAllPoints()
	f:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
	Style:ApplyFont(f.shield, M.db.shieldText)
	f.shield:ClearAllPoints()
	f.shield:SetPoint("LEFT", f, "RIGHT", SHIELD_GAP + M.db.shield.offX, M.db.shield.offY)
	f.shield:SetText(AbbreviateNumbers(PREVIEW_AMOUNT))
	f:SetShown(show)
end

local function StampAll()
	local np = NP()
	local n = 0
	if np and np.plates then
		for _, plate in pairs(np.plates) do
			Stamp(plate)
			if plate.health and plate.IsVisible and plate:IsVisible() and M.db.shield.enabled and (M.running or preview) then n = n + 1 end
		end
	end
	PaintStandIn(preview and n == 0)
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
function M:OnEnable()
	HookDispel()
	ReloadPlates()
	WrapStyles()
	RestyleGlow()
	local np = NP()
	-- a rebuilt style is a new table, without our wrap
	local function Rewrap(self)
		if WrapStyles() then RestyleGlow() end
		self:After(0, function() if WrapStyles() then RestyleGlow() end end)
	end
	if np and type(np.RefreshAllSettings) == "function" then
		self:SecureHook(np, "RefreshAllSettings", function(self)
			StampAll()
			self:After(0, StampAll)
			Rewrap(self)
		end)
	end
	if np and type(np.NPC_ReloadAll) == "function" then self:SecureHook(np, "NPC_ReloadAll", Rewrap) end
	-- EllesmereUI builds its styles at login, possibly after this module started
	self:After(1, Rewrap)
	self:After(4, Rewrap)
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(self, _, unit)
		local plates = NP() and NP().plates
		local plate = plates and plates[unit]
		if plate then Stamp(plate, "added") else self:After(0, function() local p = NP().plates[unit] if p then Stamp(p, "added") end end) end
	end)
	-- fires for every unit in the group too: a memoised token test, no string made per event
	self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", function(_, _, unit)
		if not (M.db.shield.enabled and unit) or not IsPlateToken[unit] then return end
		local plates = NP() and NP().plates
		if not plates then return end
		local plate = plates[unit]
		if plate and plate.unit == unit then Paint(plate) return end
		-- EllesmereUI re-points plates without an add/remove cycle
		for _, p in pairs(plates) do
			if p.unit == unit then Paint(p) return end
		end
	end)
end

function M:OnDisable()
	preview = false
	ReloadPlates()
	RestyleGlow()
end

function M:OnRefresh()
	gen = gen + 1
	preview = self:IsPreview() and self.db.shield.enabled
	StampAll()
	local sig = GlowSignature()
	if sig ~= glowSig then
		glowSig = sig
		if self.running then WrapStyles() end
		RestyleGlow()
	end
end

function M:OnSettingChanged(path)
	if path == "dispelAlways" then ReloadPlates() end
	self:RefreshSoon()
end

function M:DebugInfo()
	local AK = _G.EllesmereUI and _G.EllesmereUI.AuraKit
	local lines = {
		"EllesmereUI AuraKit: " .. tostring(AK ~= nil),
		"style wraps installed: " .. stats.wraps,
		"buttons styled: " .. stats.buttons .. ", borders tinted: " .. stats.tinted,
	}
	for _, key in ipairs(GLOW_KEYS) do
		local st = AK and AK.styles and AK.styles[key]
		lines[#lines + 1] = key .. ": " .. (st and ("wrapped=" .. tostring(st.__xuiGlowWrap == true)
			.. ", purgeGlow=" .. tostring(st.purgeGlow)) or "missing")
	end
	return lines
end
