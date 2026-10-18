--------------------------------------------------------------------------------
-- XerionUI_Options - Page.lua
-- A page is a scrolling column of cards; a card is a list of rows under a small
-- title, one control per row: label on the left, the control on the right.
-- Descriptions, tabs, text areas and custom controls stack across the row.
-- Pages are described with plain tables and built the first time they are
-- shown:
--     { O.Card("Text", { control, control, ... }), ... }
-- hidden(ctx) / disabled(ctx) are re-evaluated after every change, so
-- dependent options appear and grey out as you click.
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local max = math.max

local PAGE_PAD = 20
local CARD_PAD = 16
local CARD_GAP = 12
local ROW_H = 38     -- a control row
local STACK_PAD = 10 -- above and below a stacked control
local HEAD_H = 28    -- a sub-heading band inside a card
local MAX_CARD_W = 900

-- How tightly the pages are packed: compact, normal or roomy.
local DENSITY = {
	compact = { page = 14, card = 12, cardGap = 8, row = 30, stack = 8 },
	normal = { page = 20, card = 16, cardGap = 12, row = 38, stack = 10 },
	roomy = { page = 24, card = 20, cardGap = 18, row = 46, stack = 14 },
}
function O:SetDensity(name)
	local d = DENSITY[name] or DENSITY.normal
	PAGE_PAD, CARD_PAD, CARD_GAP, ROW_H, STACK_PAD = d.page, d.card, d.cardGap, d.row, d.stack
	O.CARD_PAD = CARD_PAD
end
O.DENSITIES = { { value = "compact", text = "Compact" }, { value = "normal", text = "Normal" }, { value = "roomy", text = "Roomy" } }
O:SetDensity(XUI.DB.global.panel.density)
local TITLE_H = 24

-- controls that sit in a one-line row; the rest stack across it
local ROW_TYPES = { toggle = true, slider = true, dropdown = true, color = true, button = true, input = true }

--------------------------------------------------------------------------------
-- Context: where a page's controls read and write.
--   root()                      the table paths are relative to
--   onChange(path, value, desc) after a write
--------------------------------------------------------------------------------
local Ctx = {}
Ctx.__index = Ctx

function O:NewContext(root, onChange, extra)
	local ctx = setmetatable(extra or {}, Ctx)
	ctx.root, ctx.onChange = root, onChange
	return ctx
end

function Ctx:Root()
	return self.root()
end

function Ctx:Changed(path, value, desc)
	if self.onChange then XUI.SafeCall(self.onChange, path, value, desc) end
	if self.page then self.page:RefreshSoon() end
end

--------------------------------------------------------------------------------
-- Descriptor helpers
--------------------------------------------------------------------------------
function O.Card(title, items, opts)
	local card = opts or {}
	card.title, card.items = title, items
	return card
end

-- Concatenates item lists: O.Join(G.Font("text"), { more }, ...)
function O.Join(...)
	local out = {}
	for i = 1, select("#", ...) do
		local list = select(i, ...)
		if list then
			for _, item in ipairs(list) do out[#out + 1] = item end
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- Scroll area with a thin scrollbar
--------------------------------------------------------------------------------
function O:CreateScroll(parent)
	local sf = CreateFrame("ScrollFrame", nil, parent)
	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(1, 1)
	sf:SetScrollChild(child)
	sf:EnableMouseWheel(true)

	local bar = CreateFrame("Frame", nil, sf)
	bar:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -3, -4)
	bar:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", -3, 4)
	bar:SetWidth(4)
	local thumb = CreateFrame("Frame", nil, bar)
	thumb:SetWidth(4)
	thumb.tex = O:Rect(thumb, "controlLine", "OVERLAY")
	thumb.tex:SetAllPoints()
	thumb:EnableMouse(true)
	sf.bar, sf.thumb, sf.child = bar, thumb, child

	function sf:UpdateBar()
		local range = self:GetVerticalScrollRange()
		if range <= 0 then
			bar:Hide()
			return
		end
		bar:Show()
		local h = bar:GetHeight()
		local view = self:GetHeight()
		local th = max(24, h * view / (view + range))
		thumb:SetHeight(th)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOP", bar, "TOP", 0, -(h - th) * self:GetVerticalScroll() / range)
	end

	sf:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		local v = math.max(0, math.min(range, self:GetVerticalScroll() - delta * 48))
		self:SetVerticalScroll(v)
		self:UpdateBar()
	end)
	sf:SetScript("OnScrollRangeChanged", function(self) self:UpdateBar() end)
	sf:SetScript("OnSizeChanged", function(self, w) child:SetWidth(w) self:UpdateBar() end)

	thumb:SetScript("OnMouseDown", function(self)
		local _, cy = GetCursorPosition()
		self.startY, self.startScroll = cy / self:GetEffectiveScale(), sf:GetVerticalScroll()
		self:SetScript("OnUpdate", function()
			local _, y = GetCursorPosition()
			y = y / self:GetEffectiveScale()
			local range = sf:GetVerticalScrollRange()
			local free = bar:GetHeight() - self:GetHeight()
			if free <= 0 then return end
			local v = self.startScroll + (self.startY - y) * range / free
			sf:SetVerticalScroll(math.max(0, math.min(range, v)))
			sf:UpdateBar()
		end)
	end)
	thumb:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
	return sf, child
end

--------------------------------------------------------------------------------
-- Page
--------------------------------------------------------------------------------
local Page = {}
Page.__index = Page

-- spec: { build = function(ctx) return cards end, ctx = context }
function O:CreatePage(parent, spec)
	local page = setmetatable({ spec = spec, ctx = spec.ctx, cards = {}, filter = "" }, Page)
	page.ctx.page = page
	page.scroll, page.child = self:CreateScroll(parent)
	page.scroll:SetAllPoints(parent)
	page.scroll:Hide()
	page.RefreshSoon = XUI.Coalesce(function() page:Refresh() end)
	return page
end

local function BuildCard(page, spec)
	-- a card may bring its own context (a group page mixes several modules)
	local ctx = spec.ctx or page.ctx
	ctx.page = page
	local card = { spec = spec, items = {}, ctx = ctx }
	local f = CreateFrame("Frame", nil, page.child)
	O:Skin(f, "card", "cardBorder")
	card.frame = f
	card.lines = {}
	-- the title sits above the card, not in it
	if spec.title then
		card.head = CreateFrame("Frame", nil, page.child)
		card.head:SetHeight(TITLE_H)
		card.head.text = O:Text(card.head, O.SIZE.heading, "muted")
		card.head.text:SetPoint("BOTTOMLEFT", 2, 5)
		card.head.text:SetText(spec.title:upper())
	end
	-- an eye on the card's corner puts the preview in the look this card edits
	if spec.previewState and ctx.module then
		local m = ctx.module
		local b = O:IconButton(f, "eye", 22, "Show this in the preview", function()
			if spec.previewState == true then m:SetPreview(true) else m:SetPreviewState(spec.previewState) end
		end)
		b:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 1)
		card.previewButton = b
	end
	for _, desc in ipairs(spec.items or {}) do
		local make = O.Controls[desc.type]
		assert(make, "XerionUI options: unknown control type " .. tostring(desc.type))
		local control = make(f, desc, ctx)
		control.page = page
		card.items[#card.items + 1] = control
	end
	return card
end

-- A page with many titled cards gets a row of chips in the bar above it (see
-- NavBar.lua): from AUTO_TABS_FROM cards on, the chips switch which card is
-- shown, so a long page never reads as one endless list; a shorter page just
-- scrolls and gets no chips. A card with nonav (a notice such as "Needs
-- attention") is never a chip and stays on every tab. Pages that bring their own tabs set spec.tabbed; cards
-- without a title (notices, switches) stay on every tab. While a filter is typed,
-- every card is searched, whatever tab is open.
local AUTO_TABS_FROM = 4
local SHORT_PAGE_ROWS = 12 -- at or below this many settings a page is never split into tabs

local function BuildNav(page, specs)
	local order, seen = {}, {}
	for _, s in ipairs(specs) do
		if s.title and not s.nonav and not seen[s.title] then
			seen[s.title] = true
			order[#order + 1] = { value = s.title, text = s.title }
		end
	end
	if #order < AUTO_TABS_FROM then return end
	-- many titled cards that hold only a few settings in all fit one screen: tabs
	-- would just hide them, so such a page has no tabs and simply scrolls
	local rows = 0
	for _, s in ipairs(specs) do
		for _, d in ipairs(s.items or {}) do
			if ROW_TYPES[d.type] or d.type == "keybind" then rows = rows + 1 end
		end
	end
	if rows <= SHORT_PAGE_ROWS then return end
	local state = { tab = order[1].value }
	-- a card that hides itself (its own condition) takes its chip with it, so a
	-- tab is never empty; the open tab falls back to the first one left
	local own = {}
	for _, s in ipairs(specs) do
		if s.title and not s.nonav and own[s.title] == nil then own[s.title] = s.hidden or false end
	end
	local function IsHidden(s)
		local h = own[s.title]
		if type(h) == "function" then return h(s.ctx or page.ctx) and true or false end
		return h and true or false
	end
	local function Visible()
		local list = {}
		for _, v in ipairs(order) do
			local gone = true
			for _, s in ipairs(specs) do
				if s.title == v.value and not IsHidden(s) then gone = false break end
			end
			if not gone then list[#list + 1] = v end
		end
		return list
	end
	local function Current()
		local list = Visible()
		for _, v in ipairs(list) do if v.value == state.tab then return state.tab end end
		return list[1] and list[1].value or state.tab
	end
	for _, s in ipairs(specs) do
		local title, hidden = s.title, s.hidden
		if title and not s.nonav then
			s.hidden = function(ctx)
				if Current() ~= title and not (ctx.page and ctx.page.filter ~= "") then return true end
				if type(hidden) == "function" then return hidden(ctx) and true or false end
				return hidden and true or false
			end
		end
	end
	page.nav = {
		mode = "tab", values = order, list = Visible,
		get = Current,
		set = function(v) state.tab = v page:Refresh() end,
	}
end

function Page:Build()
	if self.built then return end
	self.built = true
	local specs = self.spec.build(self.ctx) or {}
	if not self.spec.tabbed then BuildNav(self, specs) end
	for _, spec in ipairs(specs) do
		self.cards[#self.cards + 1] = BuildCard(self, spec)
	end
end

local function Hidden(desc, ctx)
	local h = desc.hidden
	if type(h) == "function" then return h(ctx) and true or false end
	return h and true or false
end

-- The lower-case text a filter is matched against for one control.
local function ControlText(control)
	local d = control.desc
	if d.type == "description" or d.type == "spacer" or d.type == "tabs" then return "" end
	local parts = {}
	for _, v in ipairs({ d.label, d.type == "button" and d.text or nil, d.tip }) do
		v = O.ResolveValue(v, control.ctx)
		if type(v) == "string" then parts[#parts + 1] = v:lower() end
	end
	return table.concat(parts, " ")
end

local function HasAllWords(text, words)
	for _, w in ipairs(words) do
		if not text:find(w, 1, true) then return false end
	end
	return true
end

-- Sets what the page is filtered by ("" shows everything again).
function Page:SetFilter(text)
	text = (text or ""):lower():match("^%s*(.-)%s*$")
	if text == self.filter then return end
	self.filter = text
	self.words = {}
	for w in text:gmatch("%S+") do self.words[#self.words + 1] = w end
	self.scroll:SetVerticalScroll(0)
	self:Layout()
end

function Page:Layout()
	local width = self.scroll:GetWidth()
	if not width or width <= 1 then return end
	local cardW = math.min(width - PAGE_PAD * 2 - 8, MAX_CARD_W)
	local x0 = math.floor((width - 8 - cardW) / 2)
	local inner = cardW - CARD_PAD * 2
	local y = PAGE_PAD
	local filtering, matches = self.filter ~= "", 0
	for _, card in ipairs(self.cards) do
		local spec, f = card.spec, card.frame
		-- while filtering: which controls of the card match, and does the card show
		local pass, show = nil, not Hidden(spec, card.ctx)
		if show and filtering then
			pass = {}
			local titleHit = spec.title and HasAllWords(spec.title:lower(), self.words)
			local any, keep = false, false
			for _, control in ipairs(card.items) do
				local d = control.desc
				if not Hidden(d, card.ctx) then
					if d.type == "tabs" and not spec.title then
						pass[control] = true keep = true -- the selector of a page with sub-pages stays
					elseif titleHit or HasAllWords(ControlText(control), self.words) then
						pass[control] = true any = true
					end
				end
			end
			show = any or keep
			if any then matches = matches + 1 end
		end
		if not show then
			f:Hide()
			if card.head then card.head:Hide() end
		else
			if card.head then
				card.head:ClearAllPoints()
				card.head:SetPoint("TOPLEFT", self.child, "TOPLEFT", x0, -y)
				card.head:SetWidth(cardW)
				card.head:Show()
				y = y + TITLE_H
			end
			local rowY, lines, prevBand = 0, 0, true
			for _, control in ipairs(card.items) do
				local desc = control.desc
				local kind = desc.type
				if Hidden(desc, card.ctx) or kind == "spacer" or (pass and not pass[control]) then
					control:Hide()
				else
					control:SetWidth(inner)
					if control.Measure then control:Measure() end
					local band = kind == "heading"
					local rowH, at
					if band then
						rowH, at = HEAD_H, rowY
						control:SetHeight(HEAD_H)
					elseif ROW_TYPES[kind] and not (kind == "input" and desc.multiline) then
						rowH, at = ROW_H, rowY
						control:SetHeight(ROW_H - 4)
						at = rowY + 2
					else
						local h = control.height or control:GetHeight()
						rowH, at = h + STACK_PAD * 2, rowY + STACK_PAD
					end
					-- a hairline between rows, but not against a band
					if not prevBand and not band then
						lines = lines + 1
						local line = card.lines[lines]
						if not line then
							line = O:Rect(f, "line", "ARTWORK")
							line:SetHeight(1)
							card.lines[lines] = line
						end
						line:ClearAllPoints()
						line:SetPoint("TOPLEFT", f, "TOPLEFT", CARD_PAD, -rowY)
						line:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -rowY)
						line:Show()
					end
					prevBand = band
					control:ClearAllPoints()
					control:SetPoint("TOPLEFT", f, "TOPLEFT", CARD_PAD, -at)
					control:Show()
					rowY = rowY + rowH
				end
			end
			for i = lines + 1, #card.lines do card.lines[i]:Hide() end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", self.child, "TOPLEFT", x0, -y)
			f:SetSize(cardW, max(rowY, 8))
			f:Show()
			y = y + f:GetHeight() + CARD_GAP
		end
	end
	if filtering and matches == 0 then
		if not self.empty then
			self.empty = O:Text(self.child, O.SIZE.text, "muted")
			self.empty:SetPoint("TOPLEFT", self.child, "TOPLEFT", PAGE_PAD + 4, -PAGE_PAD - 4)
		end
		self.empty:SetText(("No settings on this page match \"%s\"."):format(self.filter))
		self.empty:Show()
		y = y + 40
	elseif self.empty then
		self.empty:Hide()
	end
	self.child:SetHeight(y + PAGE_PAD)
	self.scroll:UpdateBar()
	if self.keyRing then O:KeyRefresh(self) end
end

-- Tab / Shift+Tab inside a number or text box: on to the next (or back to the
-- previous) box on the page, wrapping around. Only boxes that are on screen count.
function O.TabFrom(control, dir)
	local page = control.page
	if not page then return end
	local boxes, at = {}, nil
	for _, card in ipairs(page.cards) do
		for _, c in ipairs(card.items) do
			if c.box and c:IsShown() and not c.disabled and not c.desc.readOnly then
				boxes[#boxes + 1] = c
				if c == control then at = #boxes end
			end
		end
	end
	if not at or #boxes < 2 then return end
	local nextControl = boxes[(at - 1 + dir) % #boxes + 1]
	O.ScrollIntoView(page, nextControl)
	nextControl.box:SetFocus()
end

-- Scrolls the page just far enough to bring a control into view.
function O.ScrollIntoView(page, control)
	local top, childTop = control:GetTop(), page.child:GetTop()
	if not (top and childTop) then return end
	local view = page.scroll:GetHeight()
	local scroll = page.scroll:GetVerticalScroll()
	local y = childTop - top
	if y < scroll or y > scroll + view - 40 then
		page.scroll:SetVerticalScroll(math.max(0, math.min(page.scroll:GetVerticalScrollRange(), y - 60)))
		page.scroll:UpdateBar()
	end
end

--------------------------------------------------------------------------------
-- Keyboard cursor: Tab / Shift+Tab (or Up / Down once it is on) walk through the
-- settings of the open page with an accent frame around the current one; Space or
-- Enter uses it (flip, open the list, type a number, press), Left / Right step a
-- slider. Panel.lua routes the keys. Tab inside a number or text box goes to the
-- next box instead (O.TabFrom).
--------------------------------------------------------------------------------
local KEY_TYPES = { toggle = true, slider = true, dropdown = true, color = true, button = true, input = true, keybind = true }

local function KeyList(page)
	local list = {}
	for _, card in ipairs(page.cards) do
		for _, c in ipairs(card.items) do
			if KEY_TYPES[c.desc.type] and c.activate and c:IsShown() and not c.disabled then list[#list + 1] = c end
		end
	end
	return list
end

local function KeyRing(page)
	if page.keyRing then return page.keyRing end
	local ring = CreateFrame("Frame", nil, page.child)
	ring:SetFrameLevel(page.child:GetFrameLevel() + 30)
	ring.edges = {}
	for i, def in ipairs({
		{ "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
	}) do
		local t = O:Rect(ring, nil, "OVERLAY")
		t:SetPoint(def[1])
		t:SetPoint(def[2])
		if def[3] then t:SetHeight(2) else t:SetWidth(2) end
		ring.edges[i] = t
	end
	ring:Hide()
	page.keyRing = ring
	return ring
end

function O:KeyClear()
	local S = O.S
	S.keyFocus = nil
	for _, page in pairs(S.pages) do
		if page.keyRing then page.keyRing:Hide() end
	end
end

-- Puts the ring on the focused control, or hides it when that is gone.
function O:KeyRefresh(page)
	local ring = page.keyRing
	local c = O.S.keyFocus
	if not ring then return end
	if not (c and c.page == page and c:IsShown()) then
		ring:Hide()
		return
	end
	local r, g, b = O:Accent()
	for _, t in ipairs(ring.edges) do t:SetVertexColor(r, g, b, 1) end
	ring:ClearAllPoints()
	ring:SetPoint("TOPLEFT", c, "TOPLEFT", -6, 3)
	ring:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 6, -3)
	ring:Show()
end

-- Moves the cursor one setting on (step 1) or back (step -1).
function O:KeyMove(step)
	local S = O.S
	local page = S.pages[S.currentKey]
	if not (page and page.built) then return end
	local list = KeyList(page)
	if #list == 0 then return end
	local at
	for i, c in ipairs(list) do if c == S.keyFocus then at = i end end
	local target
	if at then target = list[(at - 1 + step) % #list + 1] else target = step > 0 and list[1] or list[#list] end
	S.keyFocus = target
	O.ScrollIntoView(page, target)
	KeyRing(page)
	O:KeyRefresh(page)
end

-- Space / Enter on the cursor; Left / Right (dir -1 / 1) on a slider.
function O:KeyUse(dir)
	local c = O.S.keyFocus
	if not (c and c:IsShown()) then return false end
	if dir then
		if not c.nudge then return false end
		c.nudge(dir)
	else
		c.activate()
	end
	return true
end

-- Scrolls so the card titled `title` is at the top of the page.
function Page:ScrollToCard(title)
	for _, card in ipairs(self.cards) do
		if card.spec.title == title and card.frame:IsShown() then
			local anchor = card.head or card.frame
			local top, childTop = anchor:GetTop(), self.child:GetTop()
			if top and childTop then
				local range = self.scroll:GetVerticalScrollRange()
				self.scroll:SetVerticalScroll(math.max(0, math.min(range, childTop - top - 8)))
				self.scroll:UpdateBar()
			end
			return true
		end
	end
	return false
end

-- A short accent glow on a control, so a jump from the search shows where it landed.
local function Flash(control)
	if not control.flash then
		local t = O:Rect(control, nil, "BACKGROUND", 3)
		t:SetPoint("TOPLEFT", -8, 4)
		t:SetPoint("BOTTOMRIGHT", 8, -4)
		local ag = t:CreateAnimationGroup()
		local fade = ag:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(0)
		fade:SetDuration(1.6)
		ag:SetScript("OnFinished", function() t:Hide() end)
		control.flash, control.flashAnim = t, ag
	end
	local r, g, b = O:Accent()
	control.flash:SetVertexColor(r, g, b, 0.28)
	control.flash:Show()
	control.flashAnim:Stop()
	control.flashAnim:Play()
end

-- Opens the card and scrolls to the setting with this label (from a search hit):
-- focus = { card = "Border", label = "Thickness (pixels)" }. False if not found.
function Page:Focus(focus)
	if not (self.built and focus and focus.label) then return false end
	self:SetFilter("")
	if self.nav and self.nav.mode == "tab" and focus.card then self.nav.set(focus.card) end
	self:Refresh()
	local want = focus.label:lower()
	for _, card in ipairs(self.cards) do
		if card.frame:IsShown() and (focus.card == nil or card.spec.title == focus.card) then
			for _, control in ipairs(card.items) do
				local label = O.ResolveValue(control.desc.label, control.ctx)
				if control:IsShown() and type(label) == "string" and label:lower() == want then
					local top, childTop = control:GetTop(), self.child:GetTop()
					if top and childTop then
						local range = self.scroll:GetVerticalScrollRange()
						self.scroll:SetVerticalScroll(math.max(0, math.min(range, childTop - top - 90)))
						self.scroll:UpdateBar()
					end
					Flash(control)
					return true
				end
			end
		end
	end
	return false
end

function Page:Refresh()
	if not self.built then return end
	for _, card in ipairs(self.cards) do
		for _, control in ipairs(card.items) do
			XUI.SafeCall(control.Refresh, control)
		end
	end
	self:Layout()
end

function Page:Show()
	self:Build()
	self.scroll:Show()
	self:Refresh()
	if O.RefreshNavBar then O:RefreshNavBar(self) end
	-- the scroll frame may only have its size on the next frame
	C_Timer.After(0, function() if self.scroll:IsShown() then self:Layout() end end)
end

function Page:Hide()
	self.scroll:Hide()
	if self.keyRing then self.keyRing:Hide() end
end

-- Rebuilds the page from its spec (after a profile switch, say).
function Page:Rebuild()
	for _, card in ipairs(self.cards) do
		card.frame:Hide()
		card.frame:SetParent(nil)
		if card.head then card.head:Hide() card.head:SetParent(nil) end
	end
	wipe(self.cards)
	if O.S.keyFocus and O.S.keyFocus.page == self then O.S.keyFocus = nil end
	if self.keyRing then self.keyRing:Hide() end
	self.nav = nil
	self.built = false
	if self.scroll:IsShown() then self:Show() end
end
