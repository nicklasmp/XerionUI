--------------------------------------------------------------------------------
-- Chat tweaks
-- Two small additions to EllesmereUI's chat (EllesmereUIChat):
--   * Tabs on mouseover: the tab strip is hidden until the cursor is over the
--     chat or the tabs, or while the input box is open or a tab menu is up.
--   * Input background: a solid fill behind the input box while typing (like
--     ElvUI), with its own color and texture.
--
-- The tab strip is EllesmereUI's own frame (ns._chatTabStrip, published through
-- its module namespace) and EllesmereUI writes its alpha for the chat fade. Its
-- SetAlpha is wrapped once so our mouseover factor multiplies whatever the
-- chat fade asks for; the wrapper is a plain pass-through while this module is
-- off. The fill is a texture of our own on each input box (the box itself is
-- never written to), so nothing of Blizzard's frames is tainted.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local T = XUI.Templates
local Style = XUI.Style

local M = XUI:NewModule("EUIChat", {
	name = "Chat Tweaks",
	desc = "Tabs on mouseover, a taller input box and a background behind it in EllesmereUI's chat.",
	category = "tweaks",
	icon = [[Interface\Icons\INV_Misc_Note_05]],
	order = 100,
	requires = "EllesmereUIChat",
	defaults = {
		tabsMouseover = true,
		inputHeight = 30,
		inputBg = T.Background({
			enabled = true,
			useGlobal = false,
			color = { 0.05, 0.065, 0.08, 0.9 },
		}),
	},
})

local STEP = 0.05
local factor = 1          -- mouseover factor applied on top of EllesmereUI's alpha
local target = 1
local baseAlpha           -- the alpha EllesmereUI last asked for
local wrappedStrip
local fills = setmetatable({}, { __mode = "k" })

local function Chat()
	return XUI.EUI and XUI.EUI.Module("EllesmereUIChat")
end

local function WrapStrip()
	local ns = Chat()
	local strip = ns and ns._chatTabStrip
	if not strip or wrappedStrip == strip then return strip end
	wrappedStrip = strip
	baseAlpha = strip:GetAlpha()
	local orig = strip.SetAlpha
	strip.SetAlpha = function(self, a)
		baseAlpha = a
		orig(self, a * factor)
	end
	return strip
end

local function PushAlpha()
	local strip = wrappedStrip
	if strip and baseAlpha then strip:SetAlpha(baseAlpha) end
end

local function WantTabs()
	local ns = Chat()
	local strip = wrappedStrip
	if strip and strip:IsShown() and strip:IsMouseOver() then return true end
	local ext = ns and ns._chatBgExt
	if ext and ext:IsShown() and ext:IsMouseOver() then return true end
	for i = 1, 20 do
		local cf = _G["ChatFrame" .. i]
		if cf and cf:IsShown() and cf:IsMouseOver() then return true end
		local eb = _G["ChatFrame" .. i .. "EditBox"]
		if eb and eb:IsShown() then return true end
	end
	local menus = _G.Menu and Menu.GetManager and Menu.GetManager()
	return menus and menus:IsAnyMenuOpen() and true or false
end

function M:Poll()
	if not wrappedStrip then WrapStrip() end
	target = WantTabs() and 1 or 0
	if factor == target then return end
	if target > factor then
		factor = math.min(1, factor + STEP * 5)
	else
		factor = math.max(0, factor - STEP * 7)
	end
	PushAlpha()
end

function M:StartTabs()
	if self._tabTicker then return end
	WrapStrip()
	self._tabTicker = self:NewTicker(STEP, self.Poll)
end

function M:StopTabs()
	if self._tabTicker then
		self._tabTicker:Cancel()
		self._tabTicker = nil
	end
	factor, target = 1, 1
	PushAlpha()
end

local function EachInput(fn)
	for i = 1, 20 do
		local eb = _G["ChatFrame" .. i .. "EditBox"]
		if eb then fn(eb) end
	end
end

local function Fill(eb)
	local tex = fills[eb]
	if not tex then
		tex = eb:CreateTexture(nil, "BACKGROUND", nil, -8)
		tex:SetAllPoints(eb)
		fills[eb] = tex
	end
	return tex
end

-- EllesmereUI's own Edit Box Height setting (default 23) is set while this
-- module runs and put back when it stops.
local savedHeight
function M:ApplyHeight()
	local ns = Chat()
	local E = ns and ns.ECHAT
	local cfg = E and E.DB and E.DB()
	if not cfg then return end
	if self.running then
		if savedHeight == nil then savedHeight = cfg.editBoxHeight or false end
		cfg.editBoxHeight = self.db.inputHeight
	elseif savedHeight ~= nil then
		cfg.editBoxHeight = savedHeight or nil
		savedHeight = nil
	else
		return
	end
	if E.ApplyInputPosition then E.ApplyInputPosition() end
end

function M:ApplyInput()
	local on = self.running and self.db.inputBg
	EachInput(function(eb)
		if on then
			Style:ApplyBackground(Fill(eb), self.db.inputBg)
		elseif fills[eb] then
			fills[eb]:Hide()
		end
	end)
end

function M:OnEnable()
	-- EllesmereUI builds its chat a moment after login, and whisper windows
	-- (and their input boxes) appear later: apply again when they do
	self._tabTicker = nil  -- the framework cancelled it when the module last stopped
	self:After(2, self.Refresh)
	self:RegisterEvent("UPDATE_CHAT_WINDOWS", function(m) m:RefreshSoon() end)
end

function M:OnRefresh()
	if not self.running then
		self:ApplyInput()
		return
	end
	if self.db.tabsMouseover then self:StartTabs() else self:StopTabs() end
	self:ApplyInput()
	self:ApplyHeight()
end

function M:OnDisable()
	self:StopTabs()
	self:ApplyInput()
	self:ApplyHeight()
end

function M:DebugInfo()
	local ns = Chat()
	return {
		"EllesmereUIChat namespace: " .. tostring(ns ~= nil),
		"tab strip wrapped: " .. tostring(wrappedStrip ~= nil),
		"tab factor: " .. string.format("%.2f", factor),
	}
end
