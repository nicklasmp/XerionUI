--------------------------------------------------------------------------------
-- XerionUI_Options - Sidebar.lua
-- (split out of Panel.lua; the window state lives in O.S)
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local S = O.S
local ITEM_H = O.LAYOUT.ITEM_H

--------------------------------------------------------------------------------
-- Sidebar
--------------------------------------------------------------------------------
local itemPool, headPool = {}, {}

-- Fold toggle: a 14px chevron in a 26px rounded-feel hit area that lights up on
-- hover, so it is easy to aim at. Forwards rotation/colour to its icon.
local function FoldButton(parent, onClick)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(26, 26)
	f.bg = O:Rect(f, "control", "BACKGROUND")
	f.bg:SetAllPoints()
	f.bg:Hide()
	f.glyph = O:Icon(f, "chevron", 14, "muted", "OVERLAY")
	f.glyph:SetPoint("CENTER")
	function f:SetRotation(r) self.glyph:SetRotation(r) end
	function f:SetVertexColor(...) self.glyph:SetVertexColor(...) end
	f:SetScript("OnEnter", function(self)
		self.bg:Show()
		self.glyph:SetVertexColor(O:Color("text"))
	end)
	f:SetScript("OnLeave", function(self)
		self.bg:Hide()
		self.glyph:SetVertexColor(O:Color("muted"))
	end)
	f:SetScript("OnClick", onClick)
	return f
end

local function SidebarItem(i)
	local b = itemPool[i]
	if b then return b end
	b = CreateFrame("Button", nil, S.sidebar.child)
	b:SetHeight(ITEM_H)
	b.sel = O:Rect(b, "selected", "BACKGROUND")
	b.sel:SetAllPoints()
	b.bar = O:Rect(b, nil, "ARTWORK")
	b.bar:SetWidth(2)
	b.bar:SetPoint("TOPLEFT")
	b.bar:SetPoint("BOTTOMLEFT")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(16, 16)
	b.icon:SetPoint("LEFT", 16, 0)
	b.arrow = FoldButton(b, function()
		if not b.classToken then return end
		S.expandedClass[b.classToken] = not S.expandedClass[b.classToken]
		O:RefreshSidebar()
	end)
	b.arrow:SetPoint("RIGHT", -8, 0)
	b.text = O:Text(b, O.SIZE.text, "label")
	b.text:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
	b.text:SetPoint("RIGHT", -26, 0)
	-- health badge on the icon's corner: only lit when the module has a problem
	b.dot = O:Icon(b, "circle", 7, nil, "OVERLAY")
	b.dot:SetPoint("CENTER", b.icon, "BOTTOMRIGHT", -1, 1)
	-- on/off status dot (solid = on, ring = off); a hit area lights up on
	-- hover. A click here never opens the page.
	b.sw = CreateFrame("Button", nil, b)
	b.sw:SetSize(26, 26)
	b.sw:SetPoint("RIGHT", -8, 0)
	b.sw.bg = O:Rect(b.sw, "control", "BACKGROUND")
	b.sw.bg:SetAllPoints()
	b.sw.bg:Hide()
	b.sw.ring = O:Icon(b.sw, "circle", 8, nil, "ARTWORK")
	b.sw.ring:SetPoint("CENTER")
	b.sw.hole = O:Icon(b.sw, "circle", 4, nil, "OVERLAY")
	b.sw.hole:SetPoint("CENTER")
	b.sw.switch = {
		SetState = function(_, on)
			if on then
				b.sw.ring:SetVertexColor(O:Accent())
				b.sw.hole:Hide()
			else
				b.sw.ring:SetVertexColor(O:Color("muted"))
				b.sw.hole:SetVertexColor(O:Color(b.sw.hover and "control" or "sidebar"))
				b.sw.hole:Show()
			end
		end,
	}
	b.sw:SetScript("OnClick", function()
		local m = b.module
		if not m then return end
		m:SetEnabled(not m.db.enabled)
		O:RefreshSidebar()
		O:RefreshPageHead()
		if S.pages[m.key] then S.pages[m.key]:Refresh() end
	end)
	b.sw:SetScript("OnEnter", function(self)
		self.hover = true
		self.bg:Show()
		if b.module then
			self.switch:SetState(b.module.db.enabled)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(b.module.db.enabled and "Switch off" or "Switch on")
			GameTooltip:Show()
		end
	end)
	b.sw:SetScript("OnLeave", function(self)
		self.hover = false
		self.bg:Hide()
		if b.module then self.switch:SetState(b.module.db.enabled) end
		GameTooltip:Hide()
	end)
	b:SetScript("OnEnter", function(self)
		if self.key ~= S.currentKey then self.text:SetTextColor(O:Color("text")) end
	end)
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
	h:SetHeight(30)
	h.text = O:Text(h, O.SIZE.small, "faint")
	h.text:SetPoint("BOTTOMLEFT", 16, 6)
	h.arrow = FoldButton(h, function() if h.onClick then h.onClick() end end)
	h.arrow:SetPoint("BOTTOMRIGHT", -8, 2)
	-- "3/8": how many of the modules below are switched on
	h.count = O:Text(h, O.SIZE.small, "faint")
	h:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
	h:SetScript("OnEnter", function(self) if self.onClick then self.text:SetTextColor(O:Color("text")) end end)
	h:SetScript("OnLeave", function(self) self.text:SetTextColor(O:Color("faint")) end)
	headPool[i] = h
	return h
end

function O:PaintItem(b)
	local selected = b.key == S.currentKey
	b.sel:SetShown(selected)
	b.bar:SetShown(selected)
	local ar, ag, ab = O:Accent()
	b.bar:SetVertexColor(ar, ag, ab)
	b.text:SetTextColor(O:Color(selected and "text" or "label"))
	local m = b.module
	if m then
		b.icon:SetDesaturated(not m.db.enabled)
		b.icon:SetAlpha(m.db.enabled and 1 or 0.3)
		-- off modules read as dimmed, on modules stay bright with a bigger lit dot
		if not selected and not m.db.enabled then b.text:SetTextColor(O:Color("faint")) end
		b.sw:Show()
		b.sw.switch:SetState(m.db.enabled)
		b.dot:Hide()
		if m.db.enabled then
			local ok = m:CanRun()
			if not ok or (m.errorCount or 0) > 0 then
				b.dot:SetVertexColor(O:Color("danger"))
				b.dot:Show()
			elseif #XUI.Health.Issues(m) > 0 then
				b.dot:SetVertexColor(1, 0.8, 0.2)
				b.dot:Show()
			end
		end
	else
		b.dot:Hide()
		b.sw:Hide()
		b.icon:SetDesaturated(false)
		b.icon:SetAlpha(1)
		if b.classToken then
			b.icon:SetVertexColor(1, 1, 1)
			b.arrow:SetVertexColor(O:Color(selected and "text" or "muted"))
		elseif selected then b.icon:SetVertexColor(ar, ag, ab) else b.icon:SetVertexColor(O:Color("muted")) end
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
	local y, ni, nh = 6, 0, 0
	wipe(S.entries)

	local function AddItem(key, title, icon, m, isMedia, indent, classToken)
		ni = ni + 1
		local b = SidebarItem(ni)
		b.key, b.module, b.classToken = key, m, classToken
		b.icon:ClearAllPoints()
		b.icon:SetPoint("LEFT", 16 + (indent or 0), 0)
		b.arrow:SetShown(classToken ~= nil)
		b.text:ClearAllPoints()
		b.text:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
		b.text:SetPoint("RIGHT", m and -38 or (classToken and -38 or -26), 0)
		if classToken then
			b.arrow:SetRotation(S.expandedClass[classToken] and 0 or math.rad(90))
		end
		b.text:SetText(m and m.untested and (title .. "  |cff777777untested|r") or title)
		if isMedia then
			b.icon:SetTexture(O.MEDIA .. icon)
			b.icon:SetTexCoord(0, 1, 0, 1)
		else
			b.icon:SetTexture(icon or 134400)
			b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			b.icon:SetVertexColor(1, 1, 1)
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
		b:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
		b:Show()
		O:PaintItem(b)
		S.entries[#S.entries + 1] = key
		y = y + ITEM_H
	end
	-- fold: nil for a plain heading, else { folded = bool, toggle = function }
	local function AddHead(text, fold, mods)
		nh = nh + 1
		local h = SidebarHead(nh)
		h.text:SetText(text:upper())
		if mods and #mods > 0 then
			local on = 0
			for _, m in ipairs(mods) do if m.db.enabled then on = on + 1 end end
			h.count:ClearAllPoints()
			h.count:SetPoint("BOTTOMRIGHT", fold and -38 or -14, 6)
			h.count:SetText(on .. "/" .. #mods)
			if on > 0 then h.count:SetTextColor(O:Accent()) else h.count:SetTextColor(O:Color("faint")) end
			h.count:Show()
		else
			h.count:Hide()
		end
		h.onClick = fold and fold.toggle or nil
		h.arrow:SetShown(fold ~= nil)
		if fold then h.arrow:SetRotation(fold.folded and math.rad(90) or 0) end
		h:EnableMouse(fold ~= nil)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
		h:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
		h:Show()
		y = y + 30
	end

	for _, s in ipairs(O.systemPages) do
		if Matches((s.title .. " " .. (s.desc or "")):lower()) then
			AddItem(s.key, s.title, s.icon, nil, true)
		end
	end
	for _, cat in ipairs(XUI.CATEGORIES) do
		local list, all = {}, {}
		if cat.key == "class" then
			-- every class, whatever you play, each with its modules below it; the
			-- whole group folds from its heading (a search unfolds it)
			local folded = XUI.DB.global.panel.classFolded and S.searchText == ""
			local classMods = {}
			for _, c in ipairs(O.CLASSES) do
				for _, m in ipairs(O:ClassModules(c.token)) do classMods[#classMods + 1] = m end
			end
			for _, m in ipairs(O:ClassModules(O.ANY_CLASS.token)) do classMods[#classMods + 1] = m end
			AddHead(cat.name, { folded = folded, toggle = function()
				XUI.DB.global.panel.classFolded = not XUI.DB.global.panel.classFolded
				O:RefreshSidebar()
			end }, classMods)
			local order = {}
			for _, c in ipairs(O.CLASSES) do order[#order + 1] = c end
			order[#order + 1] = O.ANY_CLASS
			for _, c in ipairs(folded and {} or order) do
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
					AddItem("class:" .. c.token, c.name, c.icon, nil, false, 0, c.token)
					if S.searchText ~= "" or S.expandedClass[c.token] then
						for _, m in ipairs(S.searchText ~= "" and not classMatches and matching or mods) do
							AddItem(m.key, m.name, XUI.ModuleIcon(m), m, false, 14)
						end
					end
				end
			end
			list = {}
		else
		for _, m in ipairs(XUI:SortedModules(cat.key)) do
			if m:IsAvailable() and ModuleMatches(m, cat.name:lower() .. " " .. (m.dungeon or ""):lower()) then
				all[#all + 1] = m
				if Keep(m) then list[#list + 1] = m end
			end
		end
		table.sort(list, ByStateThenName)
		end
		if #list > 0 then
			if cat.key == "group" or cat.key == "dungeon" or cat.key == "tweaks" then
				-- these fold from their heading too (a search unfolds them)
				local flag = cat.key .. "Folded"
				local folded = XUI.DB.global.panel[flag] and S.searchText == ""
				AddHead(cat.name, { folded = folded, toggle = function()
					XUI.DB.global.panel[flag] = not XUI.DB.global.panel[flag]
					O:RefreshSidebar()
				end }, all)
				if not folded then
					if cat.key == "dungeon" then
						-- one sub-heading per dungeon (alphabetical), its modules indented below
						local byDungeon, names = {}, {}
						for _, m in ipairs(list) do
							local d = m.dungeon or "Other"
							if not byDungeon[d] then byDungeon[d] = {} names[#names + 1] = d end
							byDungeon[d][#byDungeon[d] + 1] = m
						end
						table.sort(names)
						for _, d in ipairs(names) do
							-- each dungeon folds on its own (a search unfolds them)
							local panel = XUI.DB.global.panel
							panel.dungeonsFolded = panel.dungeonsFolded or {}
							local dFolded = panel.dungeonsFolded[d] and S.searchText == ""
							AddHead(d, { folded = dFolded, toggle = function()
								panel.dungeonsFolded[d] = not panel.dungeonsFolded[d] or nil
								O:RefreshSidebar()
							end })
							if not dFolded then
								for _, m in ipairs(byDungeon[d]) do AddItem(m.key, m.name, XUI.ModuleIcon(m), m, false, 14) end
							end
						end
					else
						for _, m in ipairs(list) do AddItem(m.key, m.name, XUI.ModuleIcon(m), m) end
					end
				end
			else
				AddHead(cat.name, nil, all)
				for _, m in ipairs(list) do AddItem(m.key, m.name, XUI.ModuleIcon(m), m) end
			end
		end
	end
	for i = ni + 1, #itemPool do itemPool[i]:Hide() end
	for i = nh + 1, #headPool do headPool[i]:Hide() end
	child:SetHeight(y + 8)
	S.sidebar:UpdateBar()
end
