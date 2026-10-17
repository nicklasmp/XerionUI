--------------------------------------------------------------------------------
-- XerionUI_Options - Sidebar.lua
-- (split out of Panel.lua; the window state lives in O.S)
-- A text-only accordion: pages on top, then one foldable group per category (a
-- chevron and a count), its modules below on a thin guide line. The open page
-- gets an accent bar on that line. A module that is switched off is dimmed and
-- carries an "off" tag; a problem shows as an amber
-- or red dot. Switching a module on or off is done in the page header.
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
	return (b.IsMouseOver and b:IsMouseOver()) and true or false
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

	-- right edge: "off" for a module that is switched off, a dot for a problem
	b.state = O:Text(b, O.SIZE.small, "faint")
	b.state:SetPoint("RIGHT", -14, 0)
	b.state:SetText("off")
	b.flag = O:Icon(b, "circle", 8, nil, "OVERLAY")
	b.flag:SetPoint("RIGHT", -14, 0)

	b:SetScript("OnEnter", function(self)
		O:PaintItem(self)
		local m = self.module
		if not m then return end
		local lines = {}
		if not m.db.enabled then lines[#lines + 1] = "Switched off. Open it to switch it on." end
		if m.db.enabled and not m.isGroup then
			if (m.errorCount or 0) > 0 then lines[#lines + 1] = m.errorCount .. " Lua error(s)"
			else
				local ok, why = m:CanRun()
				if not ok then lines[#lines + 1] = "Not running: " .. (why or "unknown reason")
				else
					local issues = XUI.Health.Issues(m)
					if #issues > 0 then lines[#lines + 1] = issues[1] end
				end
			end
		end
		if m.untested then lines[#lines + 1] = "Untested in game" end
		if #lines > 0 then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(m.name, 1, 1, 1)
			for _, l in ipairs(lines) do GameTooltip:AddLine(l, 0.75, 0.75, 0.75, true) end
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self) O:PaintItem(self) GameTooltip:Hide() O:SettleSidebar() end)
	b:SetScript("OnClick", function(self)
		if self.classToken then
			-- a second click on the open class folds it
			if self.key == S.currentKey then S.expandedClass[self.classToken] = not S.expandedClass[self.classToken]
			else S.expandedClass[self.classToken] = true end
		end
		O:Open(self.key, self.focus)
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
local function ModuleDot(m)
	if not m:CanRun() or (m.errorCount or 0) > 0 then return "bad" end
	if #XUI.Health.Issues(m) > 0 then return "warn" end
	return "on"
end

-- a group shows its worst member
local RANK = { off = 0, on = 1, warn = 2, bad = 3 }
local function DotState(m)
	if not m.isGroup then
		return m.db.enabled and ModuleDot(m) or "off"
	end
	local worst = "off"
	for _, member in ipairs(m.members) do
		if member.db.enabled then
			local s = ModuleDot(member)
			if RANK[s] > RANK[worst] then worst = s end
		end
	end
	return worst
end

-- Paints one row from its state: open page, hover, on/off, health.
function O:PaintItem(b, full)
	local selected = b.key == S.currentKey and not b.focus
	local hot = IsHot(b)
	-- while searching, the row Enter would open is lit like a hovered one
	local cursor = S.searchText ~= "" and not b.focus and b.key == S.entries[S.cursor or 1]
	local m = b.module
	local ar, ag, ab = O:Accent()
	b.sel:SetShown(selected)
	b.hl:SetShown((hot or cursor) and not selected)
	b.bar:SetShown(selected)
	b.bar:SetVertexColor(ar, ag, ab)
	local color = (selected or hot or cursor) and "text" or "label"
	if m then
		local on = m.db.enabled
		if not on and not selected then color = (hot or cursor) and "label" or "faint" end
		b.text:SetTextColor(O:Color(color))
		if full or not b.dot then b.dot = DotState(m) end
		-- every row has a status dot: green = on, grey = off, amber / red = a problem
		b.state:Hide()
		b.flag:Show()
		if b.dot == "bad" then b.flag:SetVertexColor(O:Color("danger"))
		elseif b.dot == "warn" then b.flag:SetVertexColor(1, 0.8, 0.2)
		elseif b.dot == "on" then b.flag:SetVertexColor(0.35, 0.8, 0.45)
		else b.flag:SetVertexColor(0.4, 0.4, 0.4, 0.6) end
	else
		b.text:SetTextColor(O:Color(color))
		b.state:Hide()
		b.flag:Hide()
		if b.classToken then b.chev:SetFolded(not S.expandedClass[b.classToken], S.expandedClass[b.classToken]) end
	end
end

-- Lower-case words the search matches a module against: its name, category,
-- description and the labels of its options. settingsIndex keeps the options
-- themselves ({ card, label } per setting) so a hit can open the setting.
local searchIndex, settingsIndex = {}, {}
local SETTING_TYPES = { toggle = true, slider = true, dropdown = true, color = true, input = true, keybind = true }
local ModuleWords
function ModuleWords(m)
	if searchIndex[m.key] then return searchIndex[m.key] end
	local words = { m.name:lower(), (m.desc or ""):lower() }
	local settings = {}
	settingsIndex[m.key] = settings
	if m.isGroup then
		for _, member in ipairs(m.members) do words[#words + 1] = ModuleWords(member) end
	end
	local build = O.moduleBuilders[m.key]
	if build then
		local ok, cards = pcall(build, O.ModuleContext(m), m, O.Groups)
		if ok and type(cards) == "table" then
			for _, card in ipairs(cards) do
				if card.title then words[#words + 1] = card.title:lower() end
				for _, d in ipairs(card.items or {}) do
					local label = d.label or d.text
					if type(label) == "string" then words[#words + 1] = label:lower() end
					if SETTING_TYPES[d.type] and type(d.label) == "string" then
						settings[#settings + 1] = { card = card.title, label = d.label }
					end
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

-- Sorting and the on/off filter read a snapshot of each module's state, taken
-- when the mouse is not over the list. Switching a module while the pointer is in
-- the list therefore never moves or removes the row under it; the list settles
-- (O:SettleSidebar) when the pointer leaves.
local sortOn = {}
local function SortOn(m)
	local v = sortOn[m.key]
	if v == nil then
		v = m.db.enabled and true or false
		sortOn[m.key] = v
	end
	return v
end

function O:SettleSidebar()
	if S.sidebarDirty and S.sidebar and not S.sidebar:IsMouseOver() then
		S.sidebarDirty = nil
		O:RefreshSidebar()
	end
end

-- The filter chips: "on" keeps modules that are switched on, "off" the rest.
local function Keep(m)
	local filter = XUI.DB.global.panel.filter
	if filter == "on" then return SortOn(m) end
	if filter == "off" then return not SortOn(m) end
	return true
end

-- Sidebar order: modules that are switched on first, then the ones off, each
-- part alphabetical.
local function ByStateThenName(a, b)
	local sa, sb = SortOn(a), SortOn(b)
	if sa ~= sb then return sa end
	return a.name:lower() < b.name:lower()
end

-- Colours the words of the search inside a row's title.
local function Highlight(text)
	if S.searchText == "" or text:find("|c", 1, true) then return text end
	local lower, marks = text:lower(), {}
	for word in S.searchText:gmatch("%S+") do
		local i, j = lower:find(word, 1, true)
		if i then marks[#marks + 1] = { i, j } end
	end
	if #marks == 0 then return text end
	table.sort(marks, function(a, b) return a[1] < b[1] end)
	local merged = { marks[1] }
	for k = 2, #marks do
		local last = merged[#merged]
		if marks[k][1] <= last[2] + 1 then last[2] = math.max(last[2], marks[k][2])
		else merged[#merged + 1] = marks[k] end
	end
	local r, g, b = O:Accent()
	local open = ("|cff%02x%02x%02x"):format(r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5)
	local out, pos = {}, 1
	for _, m in ipairs(merged) do
		out[#out + 1] = text:sub(pos, m[1] - 1) .. open .. text:sub(m[1], m[2]) .. "|r"
		pos = m[2] + 1
	end
	out[#out + 1] = text:sub(pos)
	return table.concat(out)
end

-- Repaints every visible row (the search cursor moved).
function O:PaintAllItems()
	for _, b in ipairs(itemPool) do if b:IsShown() then O:PaintItem(b) end end
end

-- Moves the search cursor (the row Enter opens) up or down the hits.
function O:MoveSearchCursor(delta)
	if S.searchText == "" or #S.entries == 0 then return end
	S.cursor = math.max(1, math.min(#S.entries, (S.cursor or 1) + delta))
	O:PaintAllItems()
	O:RevealSelected(S.entries[S.cursor])
end

-- Counts behind the All / Active / Inactive tabs.
function O:RefreshFilterCounts()
	local chips = S.filterChips
	if not chips then return end
	local on, off = 0, 0
	for _, m in ipairs(XUI.modules) do
		if m:IsAvailable() then
			if m.db.enabled then on = on + 1 else off = off + 1 end
		end
	end
	local counts = { on + off, on, off }
	local wide = (chips[1]:GetWidth() or 0) >= 70
	for i, c in ipairs(chips) do
		c.text:SetText(wide and ("%s |cff777777%d|r"):format(c.label, counts[i]) or c.label)
	end
end

-- Folds every group, or unfolds them all when everything is already folded.
function O:ToggleFoldAll()
	local panel = XUI.DB.global.panel
	local anyOpen = false
	for _, cat in ipairs(XUI.CATEGORIES) do
		if not panel[cat.key .. "Folded"] then anyOpen = true end
	end
	for _, cat in ipairs(XUI.CATEGORIES) do panel[cat.key .. "Folded"] = anyOpen or nil end
	if anyOpen then
		for token in pairs(S.expandedClass) do S.expandedClass[token] = false end
	end
	panel.dungeonsFolded = nil
	O:RefreshSidebar()
end

function O:RefreshSidebar()
	if not S.sidebar then return end
	local child = S.sidebar.child
	local y, ni, nh, nm = 4, 0, 0, 0
	if S.resortSidebar or not S.sidebar:IsMouseOver() then
		wipe(sortOn)
		S.resortSidebar = nil
	end
	wipe(S.entries)
	-- a new search starts from a fresh index, so option labels that changed show up
	if S.searchText == "" then wipe(searchIndex) wipe(settingsIndex) end

	-- mode: "page" (top-level text), "module" (on a guide line) or "group" (a class)
	local function AddItem(key, title, m, mode, indent, classToken, focus)
		ni = ni + 1
		indent = indent or 0
		local b = SidebarItem(ni)
		b.key, b.module, b.classToken, b.mode = key, m, classToken, mode
		b.focus = focus
		b.dot = nil
		b.top = y
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
		b.count:SetText("")
		if mode == "module" or mode == "setting" then
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
			b.text:SetPoint("LEFT", gx + (mode == "setting" and 30 or 18), 0)
			b.text:SetPoint("RIGHT", mode == "setting" and -10 or -42, 0)
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
			b.text:SetPoint("RIGHT", m and -32 or -16, 0)
		end
		b.text:SetText(Highlight(title) .. (m and m.untested and " |cff777777*|r" or ""))
		b:Show()
		O:PaintItem(b, true)
		if mode ~= "setting" then S.entries[#S.entries + 1] = key end
		if mode == "module" then nm = nm + 1 end
		y = y + (mode == "group" and HEAD_H or ITEM_H)
	end

	-- while searching: the settings of a module that match, under its row. A click
	-- opens the page, the card that holds the setting, and flashes it.
	local function AddHits(m)
		if S.searchText == "" or m.isGroup then return end
		ModuleWords(m)
		local n = 0
		for _, s in ipairs(settingsIndex[m.key] or {}) do
			if Matches(((s.card or "") .. " " .. s.label):lower()) then
				n = n + 1
				if n <= 4 then
					AddItem(m.key, (s.card and (s.card .. " / ") or "") .. s.label, nil, "setting", STEP, nil, s)
				end
			end
		end
		if n > 4 then
			AddItem(m.key, ("+%d more on this page"):format(n - 4), nil, "setting", STEP, nil, { more = true })
		end
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
		if not s.hidden and Matches((s.title .. " " .. (s.desc or "")):lower()) then
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
			-- Classes > class > specialization; a search unfolds everything
			local classMods = {}
			for _, ce in ipairs(O.classEntries) do
				for _, m in ipairs(O:ClassModules(ce.class.token)) do classMods[#classMods + 1] = m end
			end
			AddHead(cat.name, { folded = folded, toggle = function()
				panel[flag] = not panel[flag]
				O:RefreshSidebar()
			end }, classMods)
			for _, ce in ipairs(folded and {} or O.classEntries) do
				local c = ce.class
				local cname = c.name:lower()
				local classMatches = Matches(cname)
				local rows = {}
				for _, s in ipairs(ce.specs) do
					if Keep(s.entry) and (S.searchText == "" or classMatches or ModuleMatches(s.entry, cname .. " " .. s.name:lower())) then
						rows[#rows + 1] = s
					end
				end
				local wide = #ce.entry.members > 0 and Keep(ce.entry)
				if (#rows > 0 or wide) and (S.searchText == "" or classMatches or #rows > 0 or ModuleMatches(ce.entry, cname)) then
					-- the class you play starts unfolded
					if S.expandedClass[c.token] == nil then S.expandedClass[c.token] = (c.token == XUI.playerClass) end
					AddItem(ce.entry.key, c.name, nil, "group", STEP, c.token)
					if S.searchText ~= "" or S.expandedClass[c.token] then
						for _, s in ipairs(rows) do
								AddItem(s.entry.key, s.name, s.entry, "module", STEP)
								AddHits(s.entry)
							end
					end
				end
			end
		else
			for _, m in ipairs(O.CategoryEntries(cat.key)) do
				if m:IsAvailable() and ModuleMatches(m, cat.name:lower() .. " " .. (m.dungeon or ""):lower()) then
					if m.isGroup then
						for _, member in ipairs(m.members) do all[#all + 1] = member end
					else
						all[#all + 1] = m
					end
					if Keep(m) then list[#list + 1] = m end
				end
			end
			if cat.key == "dungeon" then
				-- Auto NPC Dialog: one entry under every dungeon with a seen dialog
				local gm = XUI:GetModule("AutoGossip")
				if gm and gm:IsAvailable() then
					for _, zone in ipairs(O.DialogZones()) do
						local e = O:DialogEntry(zone)
						if e and ModuleMatches(e, cat.name:lower() .. " " .. zone:lower() .. " dialog gossip") then
							all[#all + 1] = gm
							if Keep(e) then list[#list + 1] = e end
						end
					end
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
								for _, m in ipairs(byDungeon[d]) do
										AddItem(m.key, m.name, m, "module", STEP)
										AddHits(m)
									end
							end
						end
					else
						for _, m in ipairs(list) do
								AddItem(m.key, m.name, m, "module")
								AddHits(m)
							end
					end
				end
			end
		end
	end
	-- nothing left to list: say why instead of showing a bare column
	local empty = S.sidebar.empty
	if not empty then
		empty = O:Text(child, O.SIZE.small, "muted")
		empty:SetJustifyH("LEFT")
		empty:SetWordWrap(true)
		S.sidebar.empty = empty
	end
	local message
	if nm == 0 then
		local filter = panel.filter
		if S.searchText ~= "" then message = ('No modules match "%s".'):format(S.searchText)
		elseif filter == "on" then message = "No modules are switched on."
		elseif filter == "off" then message = "Every module is switched on." end
	end
	if message then
		empty:ClearAllPoints()
		empty:SetPoint("TOPLEFT", child, "TOPLEFT", 16, -(y + 8))
		empty:SetWidth(math.max(60, (child:GetWidth() or 200) - 32))
		empty:SetText(message)
		empty:Show()
		y = y + 48
	else
		empty:Hide()
	end
	if (S.cursor or 1) > #S.entries then S.cursor = math.max(1, #S.entries) end
	O:RefreshFilterCounts()
	for i = ni + 1, #itemPool do itemPool[i]:Hide() end
	for i = nh + 1, #headPool do headPool[i]:Hide() end
	child:SetHeight(y + 8)
	S.sidebar:UpdateBar()
end

-- Scrolls the list so the open page's row is in view (after the next layout, so
-- the scroll range already includes a group that was just unfolded).
function O:RevealSelected(key)
	key = key or S.currentKey
	C_Timer.After(0, function()
		local sf = S.sidebar
		if not sf then return end
		for _, b in ipairs(itemPool) do
			if b:IsShown() and b.key == key and not b.focus and b.top then
				local view, cur = sf:GetHeight(), sf:GetVerticalScroll()
				local bottom = b.top + b:GetHeight()
				local want = cur
				if b.top < cur + 24 then want = b.top - 40
				elseif bottom > cur + view - 24 then want = bottom - view + 40 end
				sf:SetVerticalScroll(math.max(0, math.min(sf:GetVerticalScrollRange(), want)))
				sf:UpdateBar()
				return
			end
		end
	end)
end
