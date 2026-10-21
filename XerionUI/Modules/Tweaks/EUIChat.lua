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
	desc = "Tabs on mouseover, a taller input box above the tabs and a background behind it in EllesmereUI's chat.",
	category = "tweaks",
	icon = [[Interface\Icons\INV_Misc_Note_05]],
	order = 100,
	requires = "EllesmereUIChat",
	defaults = {
		tabsMouseover = true,
		inputHeight = 30,
		inputAboveTabs = true,
		inputOffsetY = 0,
		inputBg = T.Background({
			enabled = true,
			useGlobal = false,
			color = { 0.05, 0.065, 0.08, 0.9 },
		}),
	},
})

local STEP = 0.05
-- global names built once: the tab poll runs every STEP and used to concatenate 40 strings per tick
local FRAME_NAMES, EDIT_NAMES = {}, {}
for i = 1, 20 do
	FRAME_NAMES[i] = "ChatFrame" .. i
	EDIT_NAMES[i] = "ChatFrame" .. i .. "EditBox"
end
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

-- Blizzard raises tab.alerting on a window that got a message while another tab
-- is selected and clears it once the tab is opened, so it doubles as "unread"
local function UnreadWhisper()
	for i = 1, 20 do
		local cf = _G[FRAME_NAMES[i]]
		local ct = cf and cf.chatType
		if ct == "WHISPER" or ct == "BN_WHISPER" then
			local tab = _G[FRAME_NAMES[i] .. "Tab"]
			if tab and tab.alerting then return true end
		end
	end
	return false
end

local function WantTabs()
	if UnreadWhisper() then return true end
	local ns = Chat()
	local strip = wrappedStrip
	if strip and strip:IsShown() and strip:IsMouseOver() then return true end
	local ext = ns and ns._chatBgExt
	if ext and ext:IsShown() and ext:IsMouseOver() then return true end
	for i = 1, 20 do
		local cf = _G[FRAME_NAMES[i]]
		if cf and cf:IsShown() and cf:IsMouseOver() then return true end
		local eb = _G[EDIT_NAMES[i]]
		if eb and eb:IsShown() then return true end
	end
	local menus = _G.Menu and Menu.GetManager and Menu.GetManager()
	return menus and menus:IsAnyMenuOpen() and true or false
end

-- fast while the tabs fade, slow while they rest: the resting poll only has to notice the mouse
local IDLE_STEP = 0.15
local tabRate

local function SetTabRate(self, rate)
	if tabRate == rate and self._tabTicker then return end
	tabRate = rate
	if self._tabTicker then self:CancelTicker(self._tabTicker) end
	self._tabTicker = self:NewTicker(rate, self.Poll)
end

function M:Poll()
	if not wrappedStrip then WrapStrip() end
	target = WantTabs() and 1 or 0
	if factor == target then return SetTabRate(self, IDLE_STEP) end
	SetTabRate(self, STEP)
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
	SetTabRate(self, IDLE_STEP)
end

function M:StopTabs()
	if self._tabTicker then
		self:CancelTicker(self._tabTicker)
		self._tabTicker = nil
	end
	tabRate = nil
	factor, target = 1, 1
	PushAlpha()
end

local function EachInput(fn)
	for i = 1, 20 do
		local eb = _G[EDIT_NAMES[i]]
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
--
-- Input above the tabs: EllesmereUI's "Input on Top" puts the box over the
-- top of the text, under the tabs. It is switched on so the panel reserves
-- nothing below the chat, its text strip reservation is turned off (the
-- box no longer covers the text), and the box is then anchored above the tab
-- band instead. EllesmereUI anchors the box again in every ApplyInputPosition
-- pass, so that pass is hooked and the anchor repeated.
local saved = {}
local origStrip
local hooked = false

local function Placing(m)
	local ns = Chat()
	return m.running and m.db.inputAboveTabs and ns and not (ns.ChatStock and ns.ChatStock())
end

local function PlaceAbove(m)
	local ns = Chat()
	local E = ns and ns.ECHAT
	local cfg = E and E.DB and E.DB()
	if not (cfg and Placing(m)) then return end
	local tabs = (cfg.tabHeight or 24)
		+ ((E.ExtendBgBehindTabs and E.ExtendBgBehindTabs(cfg)) and 0 or (cfg.tabPadding or 0))
	local y = tabs + 4 + (m.db.inputOffsetY or 0)
	for i = 1, 20 do
		local cf = _G[FRAME_NAMES[i]]
		local eb = _G[EDIT_NAMES[i]]
		if cf and eb then
			eb:ClearAllPoints()
			eb:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", -10, y)
			eb:SetPoint("BOTTOMRIGHT", cf, "TOPRIGHT", 5, y)
		end
	end
end

local lastLayout
function M:ApplyHeight()
	local ns = Chat()
	local E = ns and ns.ECHAT
	local cfg = E and E.DB and E.DB()
	if not cfg then return end
	-- a full input layout pass only when something it depends on changed
	local sig = table.concat({ tostring(self.running), tostring(self.db.inputHeight),
		tostring(self.db.inputAboveTabs), tostring(self.db.inputOffsetY),
		tostring(cfg.tabHeight), tostring(cfg.tabPadding) }, "|")
	if sig == lastLayout then
		PlaceAbove(self)
		return
	end
	lastLayout = sig
	local above = Placing(self)
	if self.running then
		if saved.height == nil then saved.height = cfg.editBoxHeight or false end
		cfg.editBoxHeight = self.db.inputHeight
		if above then
			if saved.onTop == nil then saved.onTop = cfg.inputOnTop or false end
			cfg.inputOnTop = true
			if not origStrip then
				origStrip = E.InputTopStripActive
				E.InputTopStripActive = function(cf)
					if Placing(M) then return false end
					return origStrip(cf)
				end
			end
		end
	end
	if not above and saved.onTop ~= nil then
		cfg.inputOnTop = saved.onTop or nil
		saved.onTop = nil
	end
	if not self.running and saved.height ~= nil then
		cfg.editBoxHeight = saved.height or nil
		saved.height = nil
	end
	if not hooked and E.ApplyInputPosition then
		hooked = true
		hooksecurefunc(E, "ApplyInputPosition", function() PlaceAbove(M) end)
	end
	if E.ApplyInputPosition then E.ApplyInputPosition() end
	if E.RefreshInputTopStrips then E.RefreshInputTopStrips() end
	PlaceAbove(self)
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
