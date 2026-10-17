--------------------------------------------------------------------------------
-- XerionUI_Options - Panel.lua
-- The window: header, sidebar (search, pages, modules by category) and the
-- page area with its header (icon, title, description, and for modules the
-- enable switch and preview).
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local W, H = 980, 680
local SIDEBAR_W = 262
local SIDE_MIN, SIDE_MAX = 200, 460
local HEADER_H = 46
local PAGEHEAD_H = 88
local NAV_H = 36
local MIN_W, MIN_H, MAX_W, MAX_H = 780, 520, 1600, 1200
local ITEM_H = 30
O.LAYOUT = { SIDEBAR_W = SIDEBAR_W, HEADER_H = HEADER_H, PAGEHEAD_H = PAGEHEAD_H, NAV_H = NAV_H, ITEM_H = ITEM_H }

O.systemPages = {}      -- ordered list of { key, title, desc, icon, build }
O.moduleBuilders = {}   -- [module key] = function(ctx, module, G) -> cards

-- Registers the options of a module. build(ctx, module, G) returns cards.
function O:RegisterModuleOptions(key, build)
	self.moduleBuilders[key] = build
end

-- Registers a page shown at the top of the sidebar.
-- spec: { key, title, desc, icon, build = function(ctx, G) -> cards, root, onChange }
function O:RegisterSystemPage(spec)
	self.systemPages[#self.systemPages + 1] = spec
end

-- State the window, the sidebar, the page head and the preview helpers share.
local S = {
	entries = {},        -- sidebar entries in display order
	pages = {},          -- [key] = Page
	autoStarted = {},    -- modules whose preview the open page started
	expandedClass = {},  -- [class token] = unfolded in the sidebar
	docked = false,
	searchText = "",
}
O.S = S

--------------------------------------------------------------------------------
-- Pages
--------------------------------------------------------------------------------
function O.ModuleContext(m)
	return O:NewContext(function() return m.db end, function(path)
		XUI:NotifySettingChanged(m, path)
	end, { module = m })
end

function O:GetPageIfBuilt(key) return S.pages[key] end

local function GetPage(key)
	if S.pages[key] then return S.pages[key] end
	local m = XUI:GetModule(key)
	local spec
	if O.groupByKey[key] then
		spec = O:GroupPageSpec(key)
	elseif m then
		local build = O.moduleBuilders[key]
		spec = {
			ctx = O.ModuleContext(m),
			build = function(ctx)
				local cards = {
					-- a module that is off says so, and can be switched on right here
					O.Card(nil, {
						{ type = "description", color = "label",
							text = "This module is switched off. The preview shows it, but it does nothing in the game until you enable it." },
						{ type = "button", text = "Enable", primary = true,
							onClick = function() m:SetEnabled(true) O:RefreshPageHead() O:RefreshSidebar() if ctx.page then ctx.page:Refresh() end end },
					}, { hidden = function() return m.db.enabled end }),
					-- what the self-check found outside this addon
					O.Card("Needs attention", {
						{ type = "description", color = "danger", text = function()
							local lines = {}
							for _, issue in ipairs(XUI.Health.Issues(m)) do lines[#lines + 1] = "- " .. issue end
							return table.concat(lines, "\n")
						end },
					}, { hidden = function() return #XUI.Health.Issues(m) == 0 end }),
				}
				local own
				if build then
					own = build(ctx, m, O.Groups)
				else
					own = { O.Card(nil, { { type = "description", text = "This module has no settings yet." } }) }
				end
				for _, c in ipairs(own) do cards[#cards + 1] = c end
				return cards
			end,
		}
	else
		for _, s in ipairs(O.systemPages) do
			if s.key == key then
				spec = {
					tabbed = s.list, -- a page that is meant to be a list is not split into tabs
					ctx = O:NewContext(s.root, s.onChange, { system = s }),
					build = function(ctx) return s.build(ctx, O.Groups) end,
				}
				break
			end
		end
	end
	if not spec then return nil end
	S.pages[key] = O:CreatePage(S.content, spec)
	return S.pages[key]
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local function SavePosition()
	local point, _, relPoint, x, y = S.frame:GetPoint(1)
	if not x then return end
	XUI.DB.global.panel.point = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
end

-- Soft colored glows in the window corners, tinted from the accent by turning its
-- hue, so the panel has a look of its own and still follows the accent color.
local GLOWS = {
	{ point = "TOPLEFT",     x = 0.0,  y = 0.0, size = 620, hue = -0.33, a = 0.28 },
	{ point = "TOPRIGHT",    x = 0.0,  y = 0.0, size = 700, hue =  0.00, a = 0.34 },
	{ point = "BOTTOMLEFT",  x = 0.0,  y = 0.0, size = 660, hue =  0.33, a = 0.26 },
	{ point = "BOTTOMRIGHT", x = 0.0,  y = 0.0, size = 620, hue =  0.62, a = 0.30 },
}

local function ShiftHue(r, g, b, shift)
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local d, h = max - min, 0
	if d > 0 then
		if max == r then h = ((g - b) / d) % 6
		elseif max == g then h = (b - r) / d + 2
		else h = (r - g) / d + 4 end
		h = h / 6
	end
	local s, v = (max == 0) and 0 or d / max, max
	h = (h + shift) % 1
	-- keep the glow vivid even when the accent is pale
	s = math.max(s, 0.55) v = math.max(v, 0.8)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return v, t, p elseif i == 1 then return q, v, p
	elseif i == 2 then return p, v, t elseif i == 3 then return p, q, v
	elseif i == 4 then return t, p, v else return v, p, q end
end

function O:RefreshBackdrop()
	local bd = S.backdrop
	if not bd then return end
	local r, g, b = O:Accent()
	for _, glow in ipairs(bd.glows) do
		local cr, cg, cb = ShiftHue(r, g, b, glow.def.hue)
		glow:SetVertexColor(cr, cg, cb, glow.def.a)
	end
end

local function CreateBackdrop()
	local bd = CreateFrame("Frame", nil, S.frame)
	bd:SetAllPoints()
	bd:SetClipsChildren(true)
	bd.glows = {}
	for i, def in ipairs(GLOWS) do
		local t = bd:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(O.MEDIA .. "glow")
		t:SetBlendMode("ADD")
		t:SetSize(def.size, def.size)
		t:SetPoint("CENTER", bd, def.point, def.x, def.y)
		t.def = def
		bd.glows[i] = t
	end
	S.backdrop = bd
	O:RefreshBackdrop()
end

local function CreateWindow()
	S.frame = CreateFrame("Frame", "XUI_OptionsFrame", UIParent)
	local panel = XUI.DB.global.panel
	S.frame:SetSize(math.max(MIN_W, math.min(MAX_W, panel.w or W)), math.max(MIN_H, math.min(MAX_H, panel.h or H)))
	S.frame:SetResizable(true)
	if S.frame.SetResizeBounds then S.frame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H) end
	S.frame:SetFrameStrata("HIGH")
	S.frame:SetToplevel(true)
	S.frame:SetClampedToScreen(true)
	S.frame:SetMovable(true)
	S.frame:EnableMouse(true)
	-- scale first: borders are sized in physical pixels of the final scale
	S.frame:SetScale(XUI.DB.global.panel.scale or 1)
	O:Skin(S.frame, "window", "line")
	tinsert(UISpecialFrames, "XUI_OptionsFrame")

	local p = XUI.DB.global.panel.point
	if type(p) == "table" and p[1] then
		S.frame:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
	else
		S.frame:SetPoint("CENTER")
	end

	CreateBackdrop()

	-- header
	local header = CreateFrame("Frame", nil, S.frame)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_H)
	header.bg = O:Rect(header, "sidebar", "BACKGROUND")
	header.bg:SetAllPoints()
	header.bg:SetAlpha(0.86) -- lets the backdrop glow show through
	header.line = O:Rect(header, "line", "ARTWORK")
	header.line:SetHeight(1)
	header.line:SetPoint("BOTTOMLEFT")
	header.line:SetPoint("BOTTOMRIGHT")
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() S.frame:StartMoving() end)
	header:SetScript("OnDragStop", function()
		S.frame:StopMovingOrSizing()
		SavePosition()
	end)

	local logo = header:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(O.MEDIA .. "addon-icon")
	logo:SetSize(24, 24)
	logo:SetPoint("LEFT", 14, 0)
	local title = O:Text(header, 18, "text")
	title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
	title:SetText("XerionUI")
	local version = O:Text(header, O.SIZE.small, "faint")
	version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
	version:SetText(XUI.version)
	-- the version opens the patch notes
	local versionBtn = CreateFrame("Button", nil, header)
	versionBtn:SetPoint("TOPLEFT", version, "TOPLEFT", -4, 4)
	versionBtn:SetPoint("BOTTOMRIGHT", version, "BOTTOMRIGHT", 4, -4)
	versionBtn:SetScript("OnEnter", function()
		version:SetTextColor(O:Color("text"))
		GameTooltip:SetOwner(versionBtn, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Patch notes")
		GameTooltip:Show()
	end)
	versionBtn:SetScript("OnLeave", function()
		version:SetTextColor(O:Color("faint"))
		GameTooltip:Hide()
	end)
	versionBtn:SetScript("OnClick", function() O:Open("changelog") end)

	local close = O:IconButton(header, "close", 30, nil, function() S.frame:Hide() end)
	close:SetPoint("RIGHT", -10, 0)
	local unlock = O:IconButton(header, "move", 30, "Unlock frames", function()
		S.frame:Hide()
		XUI:SetUnlocked(true)
	end)
	unlock:SetPoint("RIGHT", close, "LEFT", -4, 0)
	-- takes back the last change made with a control (Undo.lua)
	local undo = O:IconButton(header, "reset", 30, nil, function() O.Undo.Undo() end)
	undo:SetPoint("RIGHT", unlock, "LEFT", -4, 0)
	undo:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		local what = O.Undo.Describe()
		GameTooltip:SetText(what and ("Undo: " .. what) or "Nothing to undo")
		if what then GameTooltip:AddLine(O.Undo.Count() .. " step(s) remembered", 0.6, 0.6, 0.6) end
		GameTooltip:Show()
	end)
	undo:HookScript("OnLeave", function() GameTooltip:Hide() end)
	S.undoButton = undo
	O.Undo.OnChange(function() O:RefreshUndo() end)
	O:RefreshUndo()
	-- accent dot by the version number while there are patch notes you have not opened
	versionBtn.dot = O:Icon(versionBtn, "circle", 7, nil, "OVERLAY")
	versionBtn.dot:SetPoint("LEFT", versionBtn, "RIGHT", 1, 3)
	S.notesButton = versionBtn
	O:RefreshNotesButton()

	-- sidebar
	local side = CreateFrame("Frame", nil, S.frame)
	side:SetPoint("TOPLEFT", 0, -HEADER_H)
	side:SetPoint("BOTTOMLEFT")
	local function SideWidth()
		return math.max(SIDE_MIN, math.min(SIDE_MAX, XUI.DB.global.panel.sideW or SIDEBAR_W))
	end
	side:SetWidth(SideWidth())
	side.bg = O:Rect(side, "sidebar", "BACKGROUND")
	side.bg:SetAllPoints()
	side.bg:SetAlpha(0.86)
	side.line = O:Rect(side, "line", "ARTWORK")
	side.line:SetWidth(1)
	side.line:SetPoint("TOPRIGHT")
	side.line:SetPoint("BOTTOMRIGHT")

	local search = CreateFrame("EditBox", nil, side)
	search:SetHeight(28)
	search:SetPoint("TOPLEFT", 12, -12)
	search:SetPoint("TOPRIGHT", -12, -12)
	search:SetAutoFocus(false)
	search:SetFont(O:FontPath(), O.SIZE.text, "")
	search:SetTextColor(O:Color("text"))
	search:SetTextInsets(28, 8, 0, 0)
	O:Skin(search, "field", "fieldLine")
	local sIcon = O:Icon(search, "search", 13, "muted")
	sIcon:SetPoint("LEFT", 9, 0)
	local hint = O:Text(search, O.SIZE.text, "faint")
	hint:SetPoint("LEFT", 28, 0)
	hint:SetText("Search")
	search:SetScript("OnTextChanged", function(self)
		S.searchText = (self:GetText() or ""):lower()
		hint:SetShown(S.searchText == "")
		O:RefreshSidebar()
	end)
	search:SetScript("OnEscapePressed", function(self)
		if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
	end)
	search:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		if S.entries[1] then O:Open(S.entries[1]) end
	end)

	-- filter chips: all modules, only the ones switched on, or only the ones off
	local chips = {}
	-- underlined tabs: the open one gets the accent line
	local tabsLine = O:Rect(side, "line", "ARTWORK")
	tabsLine:SetHeight(1)
	tabsLine:SetPoint("TOPLEFT", 12, -66)
	tabsLine:SetPoint("TOPRIGHT", -12, -66)
	local function PaintChips()
		for _, c in ipairs(chips) do
			if c.filter == XUI.DB.global.panel.filter then
				c.under:Show()
				c.under:SetVertexColor(O:Accent())
				c.text:SetTextColor(O:Color("text"))
			else
				c.under:Hide()
				c.text:SetTextColor(O:Color("muted"))
			end
		end
	end
	for i, def in ipairs({ { "All", nil }, { "Active", "on" }, { "Inactive", "off" } }) do
		local c = CreateFrame("Button", nil, side)
		c:SetHeight(24)
		c.under = O:Rect(c, nil, "OVERLAY")
		c.under:SetHeight(2)
		c.under:SetPoint("BOTTOMLEFT")
		c.under:SetPoint("BOTTOMRIGHT")
		c.text = O:Text(c, O.SIZE.small, "muted")
		c.text:SetPoint("CENTER", 0, 1)
		c.text:SetText(def[1])
		c.filter = def[2]
		c:SetScript("OnClick", function(self)
			XUI.DB.global.panel.filter = self.filter
			PaintChips()
			O:RefreshSidebar()
		end)
		chips[i] = c
	end
	-- the three tabs share the sidebar width
	local function LayoutChips()
		local tabW = (side:GetWidth() - 24) / 3
		for i, c in ipairs(chips) do
			c:SetWidth(tabW)
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", 12 + (i - 1) * tabW, -43)
		end
	end
	LayoutChips()
	PaintChips()

	local list = CreateFrame("Frame", nil, side)
	list:SetPoint("TOPLEFT", 0, -72)
	list:SetPoint("BOTTOMRIGHT", -1, 8)
	S.sidebar = O:CreateScroll(list)
	S.sidebar:SetAllPoints(list)

	-- content
	S.content = CreateFrame("Frame", nil, S.frame)
	S.content:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, -(PAGEHEAD_H + NAV_H))
	S.content:SetPoint("BOTTOMRIGHT", 0, 1)
	S.pageHead = O.CreatePageHead(S.frame)
	S.pageHead:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
	S.pageHead:SetPoint("TOPRIGHT", 0, -HEADER_H)
	S.navbar = O.CreateNavBar(S.frame)
	S.navbar:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, -PAGEHEAD_H)
	S.navbar:SetPoint("TOPRIGHT", 0, -(HEADER_H + PAGEHEAD_H))

	-- corner grip: drag to resize; the open page lays itself out again
	local relayout = XUI.Coalesce(function()
		local page = S.pages[S.currentKey]
		if page and page.built then page:Layout() end
		O:RefreshNavBar()
	end)
	S.frame:SetScript("OnSizeChanged", relayout)

	-- drag the sidebar's right edge to change its width (saved)
	local split = CreateFrame("Button", nil, S.frame)
	split:SetWidth(6)
	split:SetPoint("TOPLEFT", side, "TOPRIGHT", -3, 0)
	split:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT", -3, 0)
	split:SetFrameLevel(S.frame:GetFrameLevel() + 20)
	split.line = O:Rect(split, nil, "OVERLAY")
	split.line:SetWidth(2)
	split.line:SetPoint("TOP")
	split.line:SetPoint("BOTTOM")
	split.line:Hide()
	local function Dragging(self)
		local x = GetCursorPosition() / S.frame:GetEffectiveScale()
		local w = math.max(SIDE_MIN, math.min(SIDE_MAX, math.floor(x - S.frame:GetLeft() + 0.5)))
		if w ~= math.floor(side:GetWidth() + 0.5) then
			side:SetWidth(w)
			XUI.DB.global.panel.sideW = w
			LayoutChips()
			relayout()
		end
	end
	split:SetScript("OnEnter", function(self)
		self.line:SetVertexColor(O:Accent())
		self.line:Show()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Drag to resize the sidebar")
		GameTooltip:AddLine("Double-click to reset", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	split:SetScript("OnLeave", function(self)
		if not self.dragging then self.line:Hide() end
		GameTooltip:Hide()
	end)
	split:SetScript("OnMouseDown", function(self)
		self.dragging = true
		self:SetScript("OnUpdate", Dragging) -- only while the mouse is held
	end)
	split:SetScript("OnMouseUp", function(self)
		self.dragging = nil
		self:SetScript("OnUpdate", nil)
		if not self:IsMouseOver() then self.line:Hide() end
	end)
	split:SetScript("OnDoubleClick", function()
		side:SetWidth(SIDEBAR_W)
		XUI.DB.global.panel.sideW = SIDEBAR_W
		LayoutChips()
		relayout()
	end)
	local grip = CreateFrame("Button", nil, S.frame)
	grip:SetSize(18, 18)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(S.frame:GetFrameLevel() + 20)
	grip.tex = grip:CreateTexture(nil, "OVERLAY")
	grip.tex:SetAllPoints()
	grip.tex:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
	grip.tex:SetVertexColor(O:Color("muted"))
	grip:SetScript("OnEnter", function(self)
		self.tex:SetVertexColor(O:Accent())
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:SetText("Drag to resize")
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", function(self) self.tex:SetVertexColor(O:Color("muted")) GameTooltip:Hide() end)
	grip:SetScript("OnMouseDown", function() S.frame:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function()
		S.frame:StopMovingOrSizing()
		local p = XUI.DB.global.panel
		p.w, p.h = math.floor(S.frame:GetWidth() + 0.5), math.floor(S.frame:GetHeight() + 0.5)
		SavePosition()
	end)

	S.frame:SetScript("OnHide", function()
		O.CloseDropdown()
		for _, m in ipairs(XUI.modules) do m:SetPreview(false) end
		wipe(S.autoStarted)
		if S.docked then S.docked = false end
	end)

	local owner = {}
	XUI:On("ProfileChanged", owner, function()
		if not S.frame:IsShown() then return end
		O.Undo.Clear()
		for _, page in pairs(S.pages) do page:Refresh() end
		O:RefreshSidebar()
		O:RefreshPageHead()
	end)
	XUI:On("ModuleStateChanged", owner, function()
		if S.frame:IsShown() then O:RefreshSidebar() O:RefreshPageHead() end
	end)
	XUI:On("PreviewChanged", owner, function()
		if S.frame:IsShown() then O:RefreshPageHead() S.UpdateDockSoon() end
	end)
	XUI:On("ModuleError", owner, function()
		if S.frame:IsShown() then O:RefreshPageHead() O:RefreshSidebar() end
	end)
end

-- Unread dot by the version number; call after the notes were read.
function O:RefreshNotesButton()
	local b = S.notesButton
	if not b then return end
	b.dot:SetShown(O.ChangelogUnread() > 0)
	b.dot:SetVertexColor(O:Accent())
end

-- The Undo button in the header is only there while there is something to undo.
function O:RefreshUndo()
	if S.undoButton then S.undoButton:SetShown(O.Undo.Count() > 0) end
end

-- Puts the window back at the default size (General > Window).
function O:ResetWindowSize()
	local panel = XUI.DB.global.panel
	panel.w, panel.h = W, H
	if S.frame then
		S.frame:SetSize(W, H)
		SavePosition()
	end
end

function O:Open(key, focus)
	if not S.frame then CreateWindow() end
	key = key or S.currentKey or (O.systemPages[1] and O.systemPages[1].key)
	-- a module that sits in a group opens the group's page
	if O.groupOf[key] then key = O.groupOf[key].key end
	if XUI:GetModule(key) == nil and not O.groupByKey[key] then
		local found = false
		for _, s in ipairs(O.systemPages) do if s.key == key then found = true end end
		if not found then key = O.systemPages[1].key end
	end
	local changed = S.currentKey ~= key
	if S.currentKey and S.pages[S.currentKey] and S.currentKey ~= key then S.pages[S.currentKey]:Hide() end
	S.currentKey = key
	if key == "changelog" then
		O.ChangelogOpened()
		if S.pages[key] then S.pages[key]:Rebuild() end
	end
	O:RefreshNotesButton()
	S.frame:Show()
	O:RefreshBackdrop()
	O.SyncAutoPreview(key)
	S.UpdateDockSoon()
	O:RefreshSidebar()
	O:RefreshPageHead()
	local page = GetPage(key)
	if page then
		-- a page you come back to starts unfiltered
		if page.built and changed then page:SetFilter("") end
		page:Show()
		-- a hit from the sidebar search: land on the setting itself
		if focus then
			C_Timer.After(0.1, function()
				if S.currentKey == key and page:Focus(focus) then O:RefreshNavBar(page) end
			end)
		end
	end
end

function O:Close()
	if S.frame then S.frame:Hide() end
end

function O:IsShown()
	return S.frame and S.frame:IsShown() or false
end

-- Rebuilds every page (after the panel font or accent changed).
function O:RebuildAll()
	for _, page in pairs(S.pages) do page:Rebuild() end
	O:RefreshSidebar()
	O:RefreshPageHead()
end
