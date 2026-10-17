--------------------------------------------------------------------------------
-- XerionUI_Options - NavBar.lua
-- The strip between the page header and the cards: chips that jump between the
-- page's cards (they switch the card on a long page, scroll to it on a short
-- one) and a filter box that narrows the page to the settings matching what is
-- typed. The chips come from page.nav (Page.lua), the filter is page.filter.
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local S = O.S
local NAV_H = O.LAYOUT.NAV_H
local FILTER_W = 190
local CHIP_GAP = 4
local MORE_W = 34

function O.CreateNavBar(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(NAV_H)
	f.chips = {}

	f.line = O:Rect(f, "line", "ARTWORK")
	f.line:SetHeight(1)
	f.line:SetPoint("BOTTOMLEFT")
	f.line:SetPoint("BOTTOMRIGHT")

	local box = CreateFrame("EditBox", nil, f)
	box:SetSize(FILTER_W, 24)
	box:SetPoint("RIGHT", -16, 0)
	box:SetAutoFocus(false)
	box:SetFont(O:FontPath(), O.SIZE.small, "")
	box:SetTextColor(O:Color("text"))
	box:SetTextInsets(26, 8, 0, 0)
	O:Skin(box, "field", "fieldLine")
	local icon = O:Icon(box, "sliders", 12, "muted")
	icon:SetPoint("LEFT", 8, 0)
	local hint = O:Text(box, O.SIZE.small, "faint")
	hint:SetPoint("LEFT", 26, 0)
	hint:SetText("Filter this page")
	box:SetScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		hint:SetShown(text == "")
		if f.syncing then return end
		local page = S.pages[S.currentKey]
		if page and page.built then page:SetFilter(text) end
	end)
	box:SetScript("OnEscapePressed", function(self)
		if (self:GetText() or "") ~= "" then self:SetText("") else self:ClearFocus() end
	end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEditFocusGained", function(self) O:SetBorderColor(self, O:Accent()) end)
	box:SetScript("OnEditFocusLost", function(self) O:SetBorderColor(self, O:Color("fieldLine")) end)
	f.box, f.hint = box, hint
	return f
end

local function Chip(f, i)
	local c = f.chips[i]
	if c then return c end
	c = CreateFrame("Button", nil, f)
	c:SetHeight(NAV_H - 1)
	c.under = O:Rect(c, nil, "OVERLAY")
	c.under:SetHeight(2)
	c.under:SetPoint("BOTTOMLEFT", 4, 0)
	c.under:SetPoint("BOTTOMRIGHT", -4, 0)
	c.text = O:Text(c, O.SIZE.small, "muted")
	c.text:SetPoint("CENTER", 0, 1)
	c:SetScript("OnClick", function(self)
		local page = S.pages[S.currentKey]
		if not (page and page.nav) then return end
		page.nav.set(self.value)
		O:RefreshNavBar(page)
	end)
	c:SetScript("OnEnter", function(self) self.hot = true O:RefreshNavBar() end)
	c:SetScript("OnLeave", function(self) self.hot = false O:RefreshNavBar() end)
	f.chips[i] = c
	return c
end

function O:RefreshNavBar(page)
	local f = S.navbar
	if not f then return end
	page = page or S.pages[S.currentKey]
	local text = page and page.filter or ""
	if (f.box:GetText() or "") ~= text and not f.box:HasFocus() then
		f.syncing = true
		f.box:SetText(text)
		f.syncing = false
	end
	f.hint:SetShown(text == "" and (f.box:GetText() or "") == "")
	local nav = page and page.nav
	local values = nav and (nav.list and nav.list() or nav.values) or {}
	local current = nav and nav.get and nav.get()
	local room = (f:GetWidth() > 1 and f:GetWidth() or 700) - FILTER_W - 48
	local ar, ag, ab = O:Accent()

	-- measure every chip, then decide which fit; the rest go behind a "..." chip
	-- whose menu lists them. The open tab always stays visible.
	local widths, total, curIdx = {}, 12 - CHIP_GAP, nil
	for i, v in ipairs(values) do
		local c = Chip(f, i)
		c.text:SetText(v.text)
		widths[i] = (c.text:GetStringWidth() or 40) + 22
		total = total + widths[i] + CHIP_GAP
		if current ~= nil and v.value == current then curIdx = i end
	end
	local layout, hidden = {}, {}
	if total <= room then
		for i = 1, #values do layout[i] = i end
	else
		local function Prefix(budget)
			local x, n = 12, 0
			for i = 1, #values do
				if x + widths[i] > budget then break end
				x = x + widths[i] + CHIP_GAP
				n = n + 1
			end
			return n
		end
		local budget = room - MORE_W - CHIP_GAP
		local n = Prefix(budget)
		if curIdx and curIdx > n then n = Prefix(budget - widths[curIdx] - CHIP_GAP) end
		for i = 1, n do layout[i] = i end
		if curIdx and curIdx > n then layout[#layout + 1] = curIdx end
		local shownSet = {}
		for _, i in ipairs(layout) do shownSet[i] = true end
		for i = 1, #values do if not shownSet[i] then hidden[#hidden + 1] = values[i] end end
	end

	local x = 12
	local placed = {}
	for _, i in ipairs(layout) do
		local c, v = f.chips[i], values[i]
		placed[i] = true
		c.value = v.value
		c:SetWidth(widths[i])
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
		x = x + widths[i] + CHIP_GAP
		if current ~= nil and v.value == current then
			c.under:Show()
			c.under:SetVertexColor(ar, ag, ab)
			c.text:SetTextColor(O:Color("text"))
		else
			c.under:Hide()
			c.text:SetTextColor(O:Color(c.hot and "label" or "muted"))
		end
		c:Show()
	end
	for i, c in ipairs(f.chips) do if not placed[i] then c:Hide() end end

	local more = f.more
	if not more then
		more = Chip(f, "more")
		more.text:SetText("...")
		more:SetScript("OnClick", function(self)
			local pg = S.pages[S.currentKey]
			local items = {}
			for _, v in ipairs(self.rest or {}) do
				items[#items + 1] = { text = v.text, onClick = function()
					if pg and pg.nav then pg.nav.set(v.value) O:RefreshNavBar(pg) end
				end }
			end
			if #items > 0 then O:ShowMenu(self, items) end
		end)
		f.more = more
	end
	more.rest = hidden
	if #hidden > 0 then
		more:SetWidth(MORE_W)
		more:ClearAllPoints()
		more:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
		more.under:Hide()
		more.text:SetTextColor(O:Color(more.hot and "text" or "muted"))
		more:Show()
	else
		more:Hide()
	end
end
