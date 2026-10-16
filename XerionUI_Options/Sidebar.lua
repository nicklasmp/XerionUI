--------------------------------------------------------------------------------
-- XerionUI_Options - Sidebar.lua
-- (split out of Panel.lua; the window state lives in O.S)
-- A text-only accordion: pages on top, then one foldable group per category
-- (a chevron and a count), its modules below on a thin guide line. The open
-- page gets an accent bar on that line; a module's status dot turns into its
-- on/off switch while the row is hovered or open.
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local S = O.S
local ITEM_H = O.LAYOUT.ITEM_H
local HEAD_H = ITEM_H + 4
local GUIDE_X = 22   -- x of the guide line under a group heading
local STEP = 14      -- extra indent per nesting level

local itemPool, headPool = {}, {}

local function IsHot(b)
	return ((b.IsMouseOver and b:IsMouseOver()) or (b.sw and b.sw.IsMouseOver and b.sw:IsMouseOver())) and true or false
end

-- Fold chevron: points down when open, right when folded.
local function Chevron(parent)
	local c = O:Icon(parent, "chevron", 12, "faint", "OVERLAY")
	function c:SetFolded(folded, lit)
		self:SetRotation(folded and math.rad(90) or 0)
		if lit then self:SetVertexColor(O:Accent()) else self:SetVertexColor(O:Color("faint")) end
	end
	return c
end

local function SidebarItem(i)
	local b = itemPool[i]
	if b then return b end
	b = CreateFrame("Button", nil, S.sidebar.child)
	b:SetHeight(ITEM_H)
	b.hl = O:Rect(b, "card", "BACKGROUND")
	b.hl:Hide()
	b.sel = O:Rect(b, "selected", "BACKGROUND", 1)
	b.sel:Hide()
	b.guide = O:Rect(b, "line", "BORDER")
	b.guide:SetWidth(1)
	b.bar = O:Rect(b, nil, "ARTWORK")
	b.bar:SetWidth(2)
	b.chev = Chevron(b)
	b.text = O:Text(b, O.SIZE.text, "label")
	b.count = O:Text(b, O.SIZE.small, "faint")
	b.count:SetPoint("RIGHT", -16, 0)

	-- status dot (solid = on, ring = off; amber/red = a problem) that becomes a
	-- real switch while the row is hot. A click here never opens the page.
	b.sw = CreateFrame("Button", nil, b)
	b.sw:SetSize(36, ITEM_H)
	b.sw:SetPoint("RIGHT", -6, 0)
	b.sw.ring = O:Icon(b.sw, "circle", 8, nil, "ARTWORK")
	b.sw.ring:SetPoint("CENTER")
	b.sw.hole = O:Icon(b.sw, "circle", 4, nil, "OVERLAY")
	b.sw.hole:SetPoint("CENTER")
	b.sw.switch = O.Switch(b.sw, 26, 14)
	b.sw.switch:SetPoint("CENTER")
	b.sw:SetScript("OnClick", function()
		local m = b.module
		if not m then return end
		m:SetEnabled(not m.db.enabled)
		O:RefreshSidebar()
		O:RefreshPageHead()
		if S.pages[m.key] then S.pages[m.key]:Refresh() end
	end)
	b.sw:SetScript("OnEnter", function()
		O:PaintItem(b)
		if b.module then
			GameTooltip:SetOwner(b.sw, "ANCHOR_RIGHT")
			GameTooltip:SetText(b.module.db.enabled and "Switch off" or "Switch on")
			GameTooltip:Show()
		end
	end)
	b.sw:SetScript("OnLeave", function() O:PaintItem(b) GameTooltip:Hide() end)

	b:SetScript("OnEnter", function(self) O:PaintItem(self) end)
	b:SetScript("OnLeave", function(self) O:PaintItem(self) end)
	b:SetScript("OnClick", function(self)
		if self.classToken then
			-- a second click on the open class folds it
			if self.key == S.currentKey then S.expandedClass[self.classToken] = not S.expandedClass[self.classToken]
			else S.expandedClass[self.classToken] = true end
		end
		O:Open(self.key)
	end)
	itemPool[i] = b
	return b
end

local function SidebarHead(i)
	local h = headPool[i]
	if h then return h end
	h = CreateFrame("Button", nil, S.sidebar.child)
	h:SetHeight(HEAD_H)
	h.hl = O:Rect(h, "card", "BACKGROUND")
	h.hl:SetAllPoints()
	h.hl:Hide()
	h.chev = Chevron(h)
	h.text = O:Text(h, O.SIZE.text, "text")
	h.count = O:Text(h, O.SIZE.small, "faint")
	h.count:SetPoint("RIGHT", -16, 0)
	h:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
	h:SetScript("OnEnter", function(self) self.hl:Show() end)
	h:SetScript("OnLeave", function(self) self.hl:Hide() end)
	headPool[i] = h
	return h
end

-- The dot's state is only read when the list is rebuilt (full); hovering just
-- repaints from the cached state, so it does no health checks.
local function DotState(m)
	if not m.db.enabled then return "off" end
	if not m:CanRun() or (m.errorCount or 0) > 0 then return "bad" end
	if #XUI.Health.Issues(m) > 0 then return "warn" end
	return "on"
end

-- Paints one row from its state: open page, hover, on/off, health.
function O:PaintItem(b, full)
	local selected = b.key == S.currentKey
	local hot = IsHot(b)
	local m = b.module
	local ar, ag, ab = O:Accent()
	b.sel:SetShown(selected)
	b.hl:SetShown(hot and not selected)
	b.bar:SetShown(selected)
	b.bar:SetVertexColor(ar, ag, ab)
	local color = (selected or hot) and "text" or "label"
	if m then
		if not m.db.enabled and not selected then color = hot and "label" or "faint" end
		b.text:SetTextColor(O:Color(color))
		-- dot colour: accent = running, amber/red = problem, ring = off
		b.sw.hole:Hide()
		local showSwitch = hot or selected
		if full or not b.dot then b.dot = DotState(m) end
		b.sw.switch:SetShown(showSwitch)
		b.sw.ring:SetShown(not showSwitch)
		if b.dot ~= "off" then
			b.sw.switch:SetState(true)
			if b.dot == "bad" then b.sw.ring:SetVertexColor(O:Color("danger"))
			elseif b.dot == "warn" then b.sw.ring:SetVertexColor(1, 0.8, 0.2)
			else b.sw.ring:SetVertexColor(ar, ag, ab) end
		else
			b.sw.switch:SetState(false)
			b.sw.ring:SetVertexColor(O:Color("faint"))
			if not showSwitch then
				b.sw.hole:SetVertexColor(O:Color("sidebar"))
				b.sw.hole:Show()
			end
		end
	else
		b.text:SetTextColor(O:Color(color))
		if b.classToken then b.chev:SetFolded(not S.expandedClass[b.classToken], S.expandedClass[b.classToken]) end
	end
end

-- Lower-case words the search matches a module against: its name, category,
-- description and the labels of its options.
local searchIndex = {}
local function ModuleWords(m)
	if searchIndex[m.key] then return searchIndex[m.key] end
	local words = { m.name:lower(), (m.desc or ""):lower() }
	local build = O.moduleBuilders[m.key]
	if build then
		local ok, cards = pcall(build, O.ModuleContext(m), m, O.Groups)
		if ok and type(cards) == "table" then
			for _, card in ipairs(cards) do
				if card.title then words[#words + 1] = card.title:lower() end
				for _, d in ipairs(card.items or {}) do
					local label = d.label or d.text
					if type(label) == "string" then words[#words + 1] = label:lower() end
				end
			end
		end
	end
	local joined = table.concat(words, " ")
	searchIndex[m.key] = joined
	return joined
end

local function Matches(hay)
	if S.searchText == "" then return true end
	for word in S.searchText:gmatch("%S+") do
		if not hay:find(word, 1, true) then return false end
	end
	return true
end

-- The index runs every module's options builder, so it is only built once
-- somebody searches, not when the window opens.
local function ModuleMatches(m, extra)
	if S.searchText == "" then return true end
	return Matches(ModuleWords(m) .. " " .. extra)
end

-- The filter chips: "on" keeps modules that are switched on, "off" the rest.
local function Keep(m)
	local filter = XUI.DB.global.panel.filter
	if filter == "on" then return m.db.enabled end
	if filter == "off" then return not m.db.enabled end
	return true
end

-- Sidebar order: modules that are switched on first, then the ones off, each
-- part alphabetical.
local function ByStateThenName(a, b)
	if a.db.enabled ~= b.db.enabled then return a.db.enabled end
	return a.name:lower() < b.name:lower()
end

function O:RefreshSidebar()
	if not S.sidebar then return end
	local child = S.sidebar.child
	local y, ni, nh = 4, 0, 0
	wipe(S.entries)
	-- a new search starts from a fresh index, so option labels that changed show up
	if S.searchText == "" then wipe(searchIndex) end

	-- mode: "page" (top-level text), "module" (on a guide line) or "group" (a class)
	local function AddItem(key, title, m, mode, indent, classToken)
		ni = ni + 1
		indent = indent or 0
		local b = SidebarItem(ni)
		b.key, b.module, b.classToken, b.mode = key, m, classToken, mode
		b.dot = nil
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
		b:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
		b:SetHeight(mode == "group" and HEAD_H or ITEM_H)
		b.text:ClearAllPoints()
		b.hl:ClearAllPoints()
		b.sel:ClearAllPoints()
		b.bar:ClearAllPoints()
		b.chev:ClearAllPoints()
		b.guide:ClearAllPoints()
		b.guide:Hide()
		b.chev:Hide()
		b.sw:SetShown(m ~= nil)
		b.count:SetText("")
		if mode == "module" then
			local gx = GUIDE_X + indent
			b.guide:SetPoint("TOPLEFT", gx, 0)
			b.guide:SetPoint("BOTTOMLEFT", gx, 0)
			b.guide:Show()
			b.hl:SetPoint("TOPLEFT", gx, 0)
			b.hl:SetPoint("BOTTOMRIGHT")
			b.sel:SetPoint("TOPLEFT", gx, 0)
			b.sel:SetPoint("BOTTOMRIGHT")
			b.bar:SetPoint("TOPLEFT", gx - 1, 0)
			b.bar:SetPoint("BOTTOMLEFT", gx - 1, 0)
			b.text:SetPoint("LEFT", gx + 18, 0)
			b.text:SetPoint("RIGHT", -42, 0)
		else
			b.hl:SetAllPoints()
			b.sel:SetAllPoints()
			b.bar:SetPoint("TOPLEFT")
			b.bar:SetPoint("BOTTOMLEFT")
			if mode == "group" then
				b.chev:SetPoint("LEFT", 16 + indent, 0)
				b.chev:Show()
				b.text:SetPoint("LEFT", 36 + indent, 0)
				b.chev:SetFolded(not S.expandedClass[classToken], S.expandedClass[classToken])
			else
				b.text:SetPoint("LEFT", 18, 0)
			end
			b.text:SetPoint("RIGHT", -16, 0)
		end
		b.text:SetText(m and m.untested and (title .. "  |cff777777untested|r") or title)
		b:Show()
		O:PaintItem(b, true)
		S.entries[#S.entries + 1] = key
		y = y + (mode == "group" and HEAD_H or ITEM_H)
	end

	-- a foldable group heading: chevron, name, "3/8" modules switched on.
	-- fold = { folded = bool, toggle = function }
	local function AddHead(text, fold, mods, indent)
		nh = nh + 1
		indent = indent or 0
		local h = SidebarHead(nh)
		h.text:ClearAllPoints()
		h.text:SetPoint("LEFT", 36 + indent, 0)
		h.text:SetPoint("RIGHT", -52, 0)
		h.text:SetText(text)
		h.chev:ClearAllPoints()
		h.chev:SetPoint("LEFT", 16 + indent, 0)
		h.chev:SetFolded(fold.folded, not fold.folded)
		if mods and #mods > 0 then
			local on = 0
			for _, m in ipairs(mods) do if m.db.enabled then on = on + 1 end end
			h.count:SetText(on .. "/" .. #mods)
			if on > 0 then h.count:SetTextColor(O:Accent()) else h.count:SetTextColor(O:Color("faint")) end
		else
			h.count:SetText("")
		end
		h.onClick = fold.toggle
		h.hl:Hide()
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
		h:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
		h:Show()
		y = y + HEAD_H
	end

	local shownPages = 0
	for _, s in ipairs(O.systemPages) do
		if Matches((s.title .. " " .. (s.desc or "")):lower()) then
			AddItem(s.key, s.title, nil, "page")
			shownPages = shownPages + 1
		end
	end
	if shownPages > 0 then y = y + 6 end
	local panel = XUI.DB.global.panel
	for _, cat in ipairs(XUI.CATEGORIES) do
		local list, all = {}, {}
		local flag = cat.key .. "Folded"
		local folded = panel[flag] and S.searchText == ""
		if cat.key == "class" then
			-- every class, whatever you play, each with its modules below it; the
			-- whole group folds from its heading (a search unfolds it)
			local classMods = {}
			for _, c in ipairs(O.CLASSES) do
				for _, m in ipairs(O:ClassModules(c.token)) do classMods[#classMods + 1] = m end
			end
			for _, m in ipairs(O:ClassModules(O.ANY_CLASS.token)) do classMods[#classMods + 1] = m end
			AddHead(cat.name, { folded = folded, toggle = function()
				panel[flag] = not panel[flag]
				O:RefreshSidebar()
			end }, classMods)
			local order = {}
			if not folded then
				for _, c in ipairs(O.CLASSES) do order[#order + 1] = c end
				order[#order + 1] = O.ANY_CLASS
			end
			for _, c in ipairs(order) do
				local mods, matching = {}, {}
				for _, m in ipairs(O:ClassModules(c.token)) do
					if Keep(m) then mods[#mods + 1] = m end
				end
				table.sort(mods, ByStateThenName)
				for _, m in ipairs(mods) do
					if ModuleMatches(m, c.name:lower()) then matching[#matching + 1] = m end
				end
				local classMatches = Matches(c.name:lower())
				-- a class nothing has been made for yet stays out of the list
				if #mods > 0 and (S.searchText == "" or classMatches or #matching > 0) then
					-- the class you play starts unfolded
					if S.expandedClass[c.token] == nil then S.expandedClass[c.token] = (c.token == XUI.playerClass) end
					AddItem("class:" .. c.token, c.name, nil, "group", STEP, c.token)
					if S.searchText ~= "" or S.expandedClass[c.token] then
						for _, m in ipairs(S.searchText ~= "" and not classMatches and matching or mods) do
							AddItem(m.key, m.name, m, "module", STEP)
						end
					end
				end
			end
		else
			for _, m in ipairs(XUI:SortedModules(cat.key)) do
				if m:IsAvailable() and ModuleMatches(m, cat.name:lower() .. " " .. (m.dungeon or ""):lower()) then
					all[#all + 1] = m
					if Keep(m) then list[#list + 1] = m end
				end
			end
			table.sort(list, ByStateThenName)
			if #list > 0 then
				AddHead(cat.name, { folded = folded, toggle = function()
					panel[flag] = not panel[flag]
					O:RefreshSidebar()
				end }, all)
				if not folded then
					if cat.key == "dungeon" then
						-- one sub-heading per dungeon (alphabetical), its modules below it
						local byDungeon, names = {}, {}
						for _, m in ipairs(list) do
							local d = m.dungeon or "Other"
							if not byDungeon[d] then byDungeon[d] = {} names[#names + 1] = d end
							byDungeon[d][#byDungeon[d] + 1] = m
						end
						table.sort(names)
						for _, d in ipairs(names) do
							-- each dungeon folds on its own (a search unfolds them)
							panel.dungeonsFolded = panel.dungeonsFolded or {}
							local dFolded = panel.dungeonsFolded[d] and S.searchText == ""
							AddHead(d, { folded = dFolded, toggle = function()
								panel.dungeonsFolded[d] = not panel.dungeonsFolded[d] or nil
								O:RefreshSidebar()
							end }, nil, STEP)
							if not dFolded then
								for _, m in ipairs(byDungeon[d]) do AddItem(m.key, m.name, m, "module", STEP) end
							end
						end
					else
						for _, m in ipairs(list) do AddItem(m.key, m.name, m, "module") end
					end
				end
			end
		end
	end
	for i = ni + 1, #itemPool do itemPool[i]:Hide() end
	for i = nh + 1, #headPool do headPool[i]:Hide() end
	child:SetHeight(y + 8)
	S.sidebar:UpdateBar()
end
