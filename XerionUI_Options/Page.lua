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
local MAX_CARD_W = 720

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
	local page = setmetatable({ spec = spec, ctx = spec.ctx, cards = {} }, Page)
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

-- A long page is split with tabs, one per card title, so the level under a
-- component never reads as one endless list. Pages that bring their own tabs
-- set spec.tabbed; cards without a title (notices, switches) stay on every tab.
local AUTO_TABS_FROM = 4

local function AutoTabs(specs)
	local order, seen = {}, {}
	for _, s in ipairs(specs) do
		if s.title and not seen[s.title] then
			seen[s.title] = true
			order[#order + 1] = { value = s.title, text = s.title }
		end
	end
	if #order < AUTO_TABS_FROM then return specs end
	local state = { tab = order[1].value }
	for _, s in ipairs(specs) do
		local title, own = s.title, s.hidden
		if title then
			s.hidden = function(ctx)
				if state.tab ~= title then return true end
				if type(own) == "function" then return own(ctx) and true or false end
				return own and true or false
			end
		end
	end
	-- the tab bar goes below the cards that lead the page without a title
	local at = 1
	while specs[at] and not specs[at].title do at = at + 1 end
	table.insert(specs, at, O.Card(nil, {
		{ type = "tabs", values = order,
			get = function() return state.tab end, set = function(_, v) state.tab = v end },
	}))
	return specs
end

function Page:Build()
	if self.built then return end
	self.built = true
	local specs = self.spec.build(self.ctx) or {}
	if not self.spec.tabbed then specs = AutoTabs(specs) end
	for _, spec in ipairs(specs) do
		self.cards[#self.cards + 1] = BuildCard(self, spec)
	end
end

local function Hidden(desc, ctx)
	local h = desc.hidden
	if type(h) == "function" then return h(ctx) and true or false end
	return h and true or false
end

function Page:Layout()
	local width = self.scroll:GetWidth()
	if not width or width <= 1 then return end
	local cardW = math.min(width - PAGE_PAD * 2 - 8, MAX_CARD_W)
	local x0 = math.floor((width - 8 - cardW) / 2)
	local inner = cardW - CARD_PAD * 2
	local y = PAGE_PAD
	for _, card in ipairs(self.cards) do
		local spec, f = card.spec, card.frame
		if Hidden(spec, card.ctx) then
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
				if Hidden(desc, card.ctx) or kind == "spacer" then
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
	self.child:SetHeight(y + PAGE_PAD)
	self.scroll:UpdateBar()
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
	-- the scroll frame may only have its size on the next frame
	C_Timer.After(0, function() if self.scroll:IsShown() then self:Layout() end end)
end

function Page:Hide()
	self.scroll:Hide()
end

-- Rebuilds the page from its spec (after a profile switch, say).
function Page:Rebuild()
	for _, card in ipairs(self.cards) do
		card.frame:Hide()
		card.frame:SetParent(nil)
		if card.head then card.head:Hide() card.head:SetParent(nil) end
	end
	wipe(self.cards)
	self.built = false
	if self.scroll:IsShown() then self:Show() end
end
