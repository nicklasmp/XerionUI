--------------------------------------------------------------------------------
-- MDT Compact
-- A small button on Mythic Dungeon Tools' window folds it into a compact
-- strip: the map at a width you choose, a thin title bar with the close
-- button, and (optionally) the pull list beside it. Everything else MDT shows
-- (side bars, dungeon buttons, tools, progress bar) is hidden while it is
-- compact and put back when you leave it. MDT's own saved size, position and
-- maximised state are restored on the way out, even at logout.
--
-- It works by moving the parts of MDT's window around, so it stops by itself
-- when MDT's window does not look like the one it was written against, and
-- says why on its page.
--
-- Idea from KiraUI-Plugin's MDT Compact (personal use); this module is
-- written for XerionUI.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local MDT = XUI.MDT

local floor = math.floor
local format = string.format

local FALLBACK_MAP_W = 840
local MIN_W, MAX_W = 300, 800
local STRIP_H = 22

local M = XUI:NewModule("MDTCompact", {
	name = "MDT Compact",
	desc = "A button on Mythic Dungeon Tools' window that folds it into a small map with the pull list beside it.",
	category = "group",
	icon = [[Interface\Icons\INV_Misc_Map02]],
	order = 61,
	requires = "MythicDungeonTools",
	untested = true,
	noPreview = true,
	defaults = {
		width = 440,
		showPulls = true,
		pullScale = 0.75,
		alpha = 1,
		wanted = false,
		pos = {},
	},
})

local frame, plugin, button
local compact, busy = false, false
local park, lastError
local looker, sweeper, resizeTimer, sizeHooked, hookedShow
local hiddenNow = {}
local reHide = setmetatable({}, { __mode = "k" })
local chrome = {}

local function Clamp(v, lo, hi, fallback)
	v = tonumber(v) or fallback
	if v < lo then return lo elseif v > hi then return hi end
	return v
end

local function GetAnchor(db) return { db.anchorFrom, db.anchorTo, db.xoffset, db.yoffset } end
local function SetAnchor(db, a) db.anchorFrom, db.anchorTo, db.xoffset, db.yoffset = a[1], a[2], a[3], a[4] end

local function CompactScale() return Clamp(M.db.width, MIN_W, MAX_W, 440) / park.mapW end

-- MDT's window has the parts this needs.
local function Ready(f)
	local mb = f and f.maximizeButton
	return (mb and type(mb.Minimize) == "function" and type(mb.Maximize) == "function"
		and f.topPanel and f.closeButton and f.scrollFrame and f.sidePanel and f.toolbar) and true or false
end

-- MDT wraps some regions in AceGUI widgets; the frame is inside.
local function Region(r)
	if type(r) == "table" and type(r.frame) == "table" and r.frame ~= r and r.frame.Hide then return r.frame end
	return r
end

local function SaveGeo(r)
	local g = { n = r:GetNumPoints(), w = r:GetWidth(), h = r:GetHeight(), s = r:GetScale() }
	for i = 1, g.n do g[i] = { r:GetPoint(i) } end
	return g
end

local function LoadGeo(r, g)
	r:ClearAllPoints()
	for i = 1, g.n do
		local p = g[i]
		r:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
	if g.w and g.w > 0 then r:SetWidth(g.w) end
	if g.h and g.h > 0 then r:SetHeight(g.h) end
	if g.s and g.s > 0 then r:SetScale(g.s) end
end

local function ApplyAlpha()
	local f = frame
	if not f then return end
	local db = MDT.DB()
	if db and db.fadeOutDuringCombat and InCombatLockdown() then return end
	f:SetAlpha(compact and Clamp(M.db.alpha, 0.2, 1, 1) or 1)
end

local function PlaceButton()
	local b, f = button, frame
	if not (b and f) then return end
	b:ClearAllPoints()
	if compact then
		b:SetSize(STRIP_H - 4, STRIP_H - 4)
		b:SetPoint("RIGHT", f.closeButton, "LEFT", -2, 0)
	else
		b:SetSize(20, 20)
		if f.topPanelString then
			b:SetPoint("LEFT", f.topPanelString, "RIGHT", 8, 0)
		else
			b:SetPoint("LEFT", f.topPanel, "LEFT", 8, 0)
		end
	end
	b:SetShown(M.running and true or false)
end

local function HideAgain(self)
	if compact and hiddenNow[self] then self:Hide() end
end

local function Add(r)
	r = Region(r)
	if type(r) == "table" and r.Hide and r.IsShown then chrome[#chrome + 1] = r end
end

local function WantPulls(f)
	local sp = f.sidePanel
	local group = sp and sp.PullButtonScrollGroup
	return (M.db.showPulls and group and group.frame) and true or false
end

local function CollectChrome(f, pulls)
	wipe(chrome)
	local sp = f.sidePanel
	Add(f.navigationSidebar)
	Add(f.bottomPanel)
	Add(f.bottomLeftPanelString and f.bottomLeftPanelString.clickArea or _G.MDTBottomLeftPanelClickArea)
	Add(f.SendingStatusBar)
	Add(f.maximizeButton)
	Add(f.liveReturnButton)
	Add(f.setLivePresetButton)
	Add(f.toolbar)
	Add(f.toolbar and f.toolbar.toggleButton)
	Add(f.seasonSelectionGroup)
	Add(f.sublevelSelectionGroup)
	Add(f.topPanelString)
	Add(f.topPanelLogo)
	Add(f.resizer)
	if sp then
		Add(sp.WidgetGroup)
		Add(sp.ProgressBar)
		if not pulls then Add(sp) end
	end
	local i = 1
	while true do
		local b = _G["MDTDungeonButton" .. i]
		if not b then break end
		Add(b)
		i = i + 1
	end
	return chrome
end

local function HideChrome()
	local f = frame
	if not (compact and park and f) then return end
	local list = CollectChrome(f, WantPulls(f))
	wipe(hiddenNow)
	for i = 1, #list do
		local r = list[i]
		if park.shown[r] == nil then park.shown[r] = r:IsShown() and true or false end
		hiddenNow[r] = true
		if r.HookScript and not reHide[r] then
			reHide[r] = true
			r:HookScript("OnShow", HideAgain)
		end
		if r:IsShown() then r:Hide() end
	end
end

-- MDT shows things again when it redraws; hide them for a few seconds.
local function SweepSoon()
	if sweeper then M:CancelTicker(sweeper) end
	sweeper = M:NewTicker(0.25, HideChrome, 8)
end

-- Runs MDT's own Minimize/Maximize without our hooks reacting to it.
local function SizeButton(method)
	local mb = frame and frame.maximizeButton
	local fn = mb and mb[method]
	if type(fn) ~= "function" then return false end
	busy = true
	local ok, err = pcall(fn, mb)
	busy = false
	if not ok then
		lastError = tostring(err)
		M:Print("MDT could not change its window size: " .. lastError)
	end
	return ok
end

local function Resize(entering)
	local f, db = frame, MDT.DB()
	if not (f and db and park) then return false end
	park.small = CompactScale()
	db.nonFullscreenScale = park.small
	local pos = entering and M.db.pos
	if type(pos) == "table" and type(pos[1]) == "string" and type(pos[2]) == "string" and tonumber(pos[3]) and tonumber(pos[4]) then
		SetAnchor(db, { pos[1], pos[2], tonumber(pos[3]), tonumber(pos[4]) })
	end
	return SizeButton("Minimize")
end

local function Layout()
	local f = frame
	if not (compact and park and Ready(f)) then return end
	local db = M.db
	local sp = f.sidePanel
	local pulls = WantPulls(f)
	local colW = 0
	if pulls then
		local group = sp.PullButtonScrollGroup.frame
		local ps = Clamp(db.pullScale, 0.5, 1, 0.75)
		local g = park.geo[group]
		local gw = (g and g.w and g.w > 0) and g.w or group:GetWidth()
		colW = floor(gw * ps + 0.5)
		sp:ClearAllPoints()
		sp:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, 0)
		sp:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 0, 0)
		sp:SetWidth(colW)
		hiddenNow[sp] = nil
		if not sp:IsShown() then sp:Show() end
		group:SetScale(ps)
		group:ClearAllPoints()
		group:SetPoint("TOPLEFT", sp, "TOPLEFT", 0, 0)
		group:SetPoint("BOTTOMLEFT", sp, "BOTTOMLEFT", 0, 0)
		group:SetWidth(gw)
	end

	local top = f.topPanel
	top:ClearAllPoints()
	top:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 0)
	top:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", colW, 0)
	top:SetHeight(STRIP_H)

	local close = f.closeButton
	close:ClearAllPoints()
	close:SetPoint("RIGHT", top, "RIGHT", -2, 0)
	close:SetSize(STRIP_H - 2, STRIP_H - 2)

	HideChrome()
	PlaceButton()
	ApplyAlpha()
end

local function MapWidth(f, db)
	local s = tonumber(db.scale)
	local w = f:GetWidth()
	if s and s > 0 and w and w > 0 then
		w = w / s
		if w > 400 and w < 2000 then return w end
	end
	return FALLBACK_MAP_W
end

-- Back to MDT's own window. `external` = MDT changed its size itself, so its
-- saved values are left alone.
local function Leave(external)
	local f = frame
	if not (compact and park and f) then
		compact = false
		return
	end
	local db = MDT.DB()
	if db and not external then M.db.pos = GetAnchor(db) end

	compact = false
	wipe(hiddenNow)
	if sweeper then M:CancelTicker(sweeper) sweeper = nil end
	if resizeTimer then resizeTimer:Cancel() resizeTimer = nil end

	for r, g in pairs(park.geo) do LoadGeo(r, g) end
	for r, was in pairs(park.shown) do
		if was and not r:IsShown() then r:Show() end
	end
	local b = park.bounds
	if b[1] then f:SetResizeBounds(b[1], b[2], b[3], b[4]) end

	if db and not external then
		db.nonFullscreenScale = park.savedNormal
		SetAnchor(db, park.anchor)
		SizeButton(park.savedMax and "Maximize" or "Minimize")
	end
	if plugin then
		local ok, section = pcall(plugin.GetCurrentSection, plugin)
		pcall(plugin.SetCurrentSection, plugin, (ok and section) or "maps")
	end

	park = nil
	ApplyAlpha()
	PlaceButton()
end

local function Enter()
	local f = frame
	if compact or not Ready(f) then return end
	local db = MDT.DB()
	if not db or db.devMode then return end
	if plugin then
		pcall(plugin.HideAllDialogs, plugin)
		pcall(plugin.SetCurrentSection, plugin, "maps")
	end

	local sp = f.sidePanel
	local group = sp.PullButtonScrollGroup and sp.PullButtonScrollGroup.frame
	park = {
		savedScale = db.scale,
		savedNormal = db.nonFullscreenScale,
		savedMax = db.maximized and true or false,
		anchor = GetAnchor(db),
		mapW = MapWidth(f, db),
		bounds = { f:GetResizeBounds() },
		geo = {},
		shown = {},
	}
	park.geo[f.topPanel] = SaveGeo(f.topPanel)
	park.geo[f.closeButton] = SaveGeo(f.closeButton)
	park.geo[sp] = SaveGeo(sp)
	if group then park.geo[group] = SaveGeo(group) end

	compact = true
	HideChrome()
	local b = park.bounds
	f:SetResizeBounds(1, 1, b[3] or 10000, b[4] or 10000)

	if not Resize(true) then
		Leave(false)
		M.db.wanted = false
		return
	end
	Layout()
	SweepSoon()
end

-- At logout MDT's saved values go back to what they were.
local function WriteBack()
	if not (compact and park) then return end
	local db = MDT.DB()
	if not db then return end
	M.db.pos = GetAnchor(db)
	db.scale = park.savedScale
	db.nonFullscreenScale = park.savedNormal
	db.maximized = park.savedMax
	SetAnchor(db, park.anchor)
end

local function Toggle()
	if not M.running then
		M:Print("switch the module on first (Group, MDT Compact).")
		return
	end
	M.db.wanted = not compact
	if M.db.wanted then
		if frame and frame:IsShown() and Ready(frame) then Enter() else MDT.Open() end
	else
		Leave(false)
	end
end

local function EnsureButton()
	if button or not Ready(frame) or not M.running then return end
	local f = frame
	local b = CreateFrame("Button", nil, f)
	b:SetFrameLevel(f.topPanel:GetFrameLevel() + 10)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local logo = XUI.MEDIA_PATH .. "logo"
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(logo)
	local glow = b:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetTexture(logo)
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.6)
	b:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			if XUI.Options and XUI.Options.Open then XUI.Options:Open("MDTCompact") end
		else
			Toggle()
		end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(compact and "XerionUI: full MDT window" or "XerionUI: compact MDT window", 1, 1, 1)
		GameTooltip:AddLine("Right-click: settings", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button = b
end

-- MDT's own maximise/minimise button was used while compact: step aside.
local function OnSizeModeChanged()
	if busy or not compact or not park then return end
	local db = MDT.DB()
	local stillOurs = db and park.small and db.nonFullscreenScale == park.small
	Leave(not stillOurs)
	M.db.wanted = false
end

local function EnsureHooks()
	if sizeHooked or not Ready(frame) then return end
	sizeHooked = true
	M:SecureHook(frame.maximizeButton, "Minimize", OnSizeModeChanged)
	M:SecureHook(frame.maximizeButton, "Maximize", OnSizeModeChanged)
end

local function OnFrameShown()
	if not M.running or not Ready(frame) then return end
	EnsureHooks()
	EnsureButton()
	PlaceButton()
	if compact then
		Layout()
		C_Timer.After(0, Layout)
		SweepSoon()
	elseif M.db.wanted then
		Enter()
		C_Timer.After(0, Layout)
	end
end

local function Found()
	local f = _G.MDTFrame
	if type(f) ~= "table" or type(f.HookScript) ~= "function" then return false end
	frame = f
	if not hookedShow then
		hookedShow = true
		f:HookScript("OnShow", OnFrameShown)
	end
	if f:IsShown() then C_Timer.After(0, OnFrameShown) end
	return true
end

local function StopLooking()
	if looker then
		M:CancelTicker(looker)
		looker = nil
	end
end

local function StartLooking()
	if looker then return end
	if Found() then return end
	looker = M:NewTicker(0.1, function()
		if Found() then StopLooking() end
	end)
end

-- Waits for MDT to build its window.
local function Watch()
	local api = MDT.API()
	if api and type(api.RegisterUIInitializer) == "function" then
		local ok = pcall(api.RegisterUIInitializer, api, function(p)
			plugin = p
			if M.running then StartLooking() end
		end)
		if ok then
			-- the initializer calls back when the window is built; it may already be
			Found()
			return
		end
	end
	StartLooking()
end

local function ResizeSoon()
	if resizeTimer then resizeTimer:Cancel() end
	resizeTimer = C_Timer.NewTimer(0.2, function()
		resizeTimer = nil
		if compact and M.running then
			Resize(false)
			Layout()
		end
	end)
end

--------------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------------
function M:CanLoad()
	local db = MDT.DB()
	if db and db.devMode then return false, "MDT is in developer mode, so the compact window stays off." end
	return true
end

function M:OnEnable()
	looker, sweeper = nil, nil
	Watch()
	self:RegisterEvent("PLAYER_LOGOUT", WriteBack)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		if compact then C_Timer.After(0, ApplyAlpha) end
	end)
end

function M:OnDisable()
	looker, sweeper = nil, nil
	if compact then Leave(false) end
	if button then button:Hide() end
end

function M:OnSettingChanged()
	if not self.running or not Ready(frame) then return end
	if compact then
		if CompactScale() ~= park.small then ResizeSoon() end
		Layout()
	end
end

function M:OnRefresh()
	if not self.running then return end
	EnsureHooks()
	EnsureButton()
	PlaceButton()
end

-- For the options.
function M:Toggle() Toggle() end
function M:IsCompact() return compact end

function M:ResetPosition()
	self.db.pos = {}
	if compact and park then
		local db = MDT.DB()
		if db then SetAnchor(db, park.anchor) end
		Resize(false)
		Layout()
	end
end

function M:Why()
	if not MDT.IsLoaded() then return "Mythic Dungeon Tools is not loaded." end
	local okE, exists = pcall(C_AddOns.DoesAddOnExist, MDT.UI)
	if okE and exists then
		local okS, state = pcall(C_AddOns.GetAddOnEnableState, MDT.UI, UnitName("player"))
		if okS and state == 0 then
			return '"Mythic Dungeon Tools - UI" is disabled in the AddOns list, so MDT has no window to fold.'
		end
	end
	if frame and not Ready(frame) then return "MDT's window has changed: the parts this folds were not found." end
	return nil
end

function M:DebugInfo()
	local out = {}
	local db = MDT.DB()
	out[#out + 1] = format("compact now: %s | wanted: %s | window found: %s | ready: %s | plugin table: %s | looking: %s",
		tostring(compact), tostring(self.db.wanted), tostring(frame ~= nil), tostring(Ready(frame)), tostring(plugin ~= nil),
		looker and "ticking" or "no")
	if db then
		out[#out + 1] = format("MDT saved: scale %s, normal %s, maximised %s, anchor %s/%s %s,%s, dev mode %s", tostring(db.scale),
			tostring(db.nonFullscreenScale), tostring(db.maximized), tostring(db.anchorFrom), tostring(db.anchorTo),
			tostring(db.xoffset), tostring(db.yoffset), tostring(db.devMode))
	else
		out[#out + 1] = "MDT saved settings: not reachable"
	end
	if park then
		out[#out + 1] = format("parked: scale %s, normal %s | map %s at scale 1, compact %s", tostring(park.savedScale),
			tostring(park.savedNormal), tostring(park.mapW), tostring(park.small))
	end
	local why = self:Why()
	if why then out[#out + 1] = why end
	if lastError then out[#out + 1] = "last MDT error: " .. lastError end
	return out
end
