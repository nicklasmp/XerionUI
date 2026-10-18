--------------------------------------------------------------------------------
-- XerionUI_Options - PageHead.lua
-- (split out of Panel.lua; the window state lives in O.S)
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local S = O.S
local PAGEHEAD_H = O.LAYOUT.PAGEHEAD_H

--------------------------------------------------------------------------------
-- Page header
--------------------------------------------------------------------------------
function O.CreatePageHead(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(PAGEHEAD_H)

	f.iconFrame = CreateFrame("Frame", nil, f)
	f.iconFrame:SetSize(44, 44)
	f.iconFrame:SetPoint("LEFT", 24, 2)
	f.icon = f.iconFrame:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("TOPLEFT", 1, -1)
	f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	f.iconBorder = XUI.Style:Border(f.iconFrame, 1)

	-- where the page sits in the sidebar; a click shows it there
	f.crumb = CreateFrame("Button", nil, f)
	f.crumb:SetHeight(14)
	f.crumb:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -4)
	f.crumb.text = O:Text(f.crumb, O.SIZE.small, "faint")
	f.crumb.text:SetPoint("LEFT", 4, 0)
	f.crumb:SetScript("OnEnter", function(self)
		self.text:SetTextColor(O:Color("label"))
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Show in sidebar")
		GameTooltip:Show()
	end)
	f.crumb:SetScript("OnLeave", function(self) self.text:SetTextColor(O:Color("faint")) GameTooltip:Hide() end)
	f.crumb:SetScript("OnClick", function()
		if not S.currentKey then return end
		O:Unfold(S.currentKey)
		O:RefreshSidebar()
		O:RevealSelected()
	end)
	f.crumb:Hide()

	f.title = O:Text(f, O.SIZE.title, "text")
	f.title:SetPoint("TOPLEFT", f.iconFrame, "TOPRIGHT", 14, 0)
	f.desc = O:Text(f, O.SIZE.text, "muted")
	f.desc:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
	f.status = O:Text(f, O.SIZE.small, "danger")
	f.status:SetPoint("TOPLEFT", f.desc, "BOTTOMLEFT", 0, -4)

	-- the on/off switch sits right after the title, so what a module is doing and its
	-- state read together; the page's actions stay on the right
	f.enable = CreateFrame("Button", nil, f)
	f.enable:SetSize(100, 28) -- wide enough for the switch plus "Disabled"
	f.enable.switch = O.Switch(f.enable, 34, 18)
	f.enable.switch:SetPoint("LEFT")
	f.enable.label = O:Text(f.enable, O.SIZE.small, "muted")
	f.enable.label:SetPoint("LEFT", f.enable.switch, "RIGHT", 8, 0)
	function f.PlaceEnable()
		local w = math.min(f.title:GetStringWidth() or 0, math.max(0, (f.title:GetWidth() or 0) - 110))
		f.enable:ClearAllPoints()
		f.enable:SetPoint("LEFT", f.title, "LEFT", w + 14, 0)
	end
	f.enable:SetScript("OnClick", function()
		local m = f.module
		if m then
			m:SetEnabled(not m.db.enabled)
			O:RefreshPageHead()
			O:RefreshSidebar()
			if S.pages[m.key] then S.pages[m.key]:Refresh() end
		end
	end)

	-- Preview and Test are icon-only: the row stays short and the title keeps its room
	f.preview = CreateFrame("Button", nil, f)
	f.preview:SetSize(28, 28)
	f.preview:SetPoint("RIGHT", -24, 0)
	O:Skin(f.preview, "control")
	f.preview.icon = O:Icon(f.preview, "eye", 16, "muted")
	f.preview.icon:SetPoint("CENTER")
	f.preview.text = O:Text(f.preview, O.SIZE.small, "label") -- recoloured with the icon; never filled
	f.preview:SetScript("OnClick", function()
		local m = f.module
		if m then
			m:SetPreview(not m.preview)
			O:RefreshPageHead()
		end
	end)
	f.preview:SetScript("OnEnter", function(self) O:SetSkinColor(self, "controlHover") end)
	f.preview:SetScript("OnLeave", function(self) O:SetSkinColor(self, "control") end)
	O:Tooltip(f.preview, "Preview", "Shows the module with sample content so you can see your changes. Ends when the window closes.")

	-- text == false makes an icon-only button; `title` then names it in the tooltip
	local function HeadButton(icon, text, width, tip, onClick, title)
		local b = CreateFrame("Button", nil, f)
		b:SetSize(width, 28)
		O:Skin(b, "control")
		b.icon = O:Icon(b, icon, 16, "muted")
		b.text = O:Text(b, O.SIZE.text, "label")
		if text == false then
			b.icon:SetPoint("CENTER")
		else
			b.icon:SetPoint("LEFT", 10, 0)
			b.text:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
			b.text:SetText(text)
		end
		b:SetScript("OnClick", onClick)
		b:SetScript("OnEnter", function(self) O:SetSkinColor(self, "controlHover") end)
		b:SetScript("OnLeave", function(self) O:SetSkinColor(self, "control") end)
		if tip then O:Tooltip(b, title or text, tip) end
		return b
	end

	-- plays a short sample through the module's real code
	f.test = HeadButton("play", false, 28, "Runs a short sample through the real code, as if it had been triggered in the game.", function()
		local m = f.module
		if m and m.Test then
			-- a test goes through the real code, not the sample
			if m.preview then S.autoStarted[m] = nil m:SetPreview(false) end
			XUI.SafeCallFor(m, m.Test, m)
			O:RefreshPageHead()
		end
	end, "Test")
	f.test:SetPoint("RIGHT", f.preview, "LEFT", -8, 0)

	-- cycles the looks the preview can take
	f.state = HeadButton("layers", "", 150, "Switch which look the preview shows.", function()
		local m = f.module
		local list = m and m.PREVIEW_STATES
		if not list then return end
		local index = 0
		for i, s in ipairs(list) do if s.value == m.previewState then index = i end end
		m:SetPreviewState(list[index % #list + 1].value)
		O:RefreshPageHead()
	end)
	f.state:SetPoint("RIGHT", f.test, "LEFT", -8, 0)

	-- the "more" menu: rarely used page tools stay out of the way of the main buttons
	f.diag = HeadButton("dots", false, 28, "Diagnostics and other page tools.", function(self)
		local m = f.module
		if not m then return end
		O:ShowMenu(self, {
			{
				text = "Diagnostics",
				tip = "A text with the game build, this module's status, its checks, recent errors and its own debug lines - copy it when something does not work.",
				onClick = function() O:ShowText(m.name .. " - diagnostics", XUI.Health.Report(m)) end,
			},
		})
	end, "More")

	-- the texts end left of the leftmost control so they never run under it
	function f.FitTexts()
		local textLeft = f.title:GetLeft()
		local edge = f.stop and f.stop:GetLeft() or f:GetRight()
		local w = (textLeft and edge) and (edge - textLeft - 16) or 400
		w = math.max(w, 120)
		for _, fs in ipairs({ f.title, f.desc, f.status }) do
			fs:SetWordWrap(false)
			fs:SetWidth(w)
		end
		f.PlaceEnable()
	end
	f:SetScript("OnSizeChanged", function() f.FitTexts() end)

	-- a text cut short by the controls shows in full on hover
	f.textHit = CreateFrame("Button", nil, f)
	f.textHit:SetPoint("TOPLEFT", f.title, "TOPLEFT")
	f.textHit:SetPoint("BOTTOMRIGHT", f.status, "BOTTOMRIGHT")
	f.textHit:SetScript("OnEnter", function(self)
		local cut = false
		for _, fs in ipairs({ f.title, f.desc, f.status }) do
			if fs.IsTruncated and fs:IsTruncated() then cut = true end
		end
		if not cut then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(f.title:GetText() or "", 1, 1, 1)
		if (f.desc:GetText() or "") ~= "" then GameTooltip:AddLine(f.desc:GetText(), 0.75, 0.75, 0.75, true) end
		if (f.status:GetText() or "") ~= "" then GameTooltip:AddLine(f.status:GetText(), 0.6, 0.6, 0.6, true) end
		GameTooltip:Show()
	end)
	f.textHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

	f.line = O:Rect(f, "line", "ARTWORK")
	f.line:SetHeight(1)
	f.line:SetPoint("BOTTOMLEFT")
	f.line:SetPoint("BOTTOMRIGHT")
	return f
end

--------------------------------------------------------------------------------
-- Banner: a strip under the nav bar for a module's problem (kind "bad" = it does
-- not run or throws errors, "warn" = it runs but a check failed). Height 0 when
-- there is nothing to say, so the cards sit right under the nav bar.
--------------------------------------------------------------------------------
local BANNER_H = 34

function O.CreateBanner(parent)
	local f = CreateFrame("Frame", nil, parent)
	-- never SetHeight(0): in the game that means "no fixed height", and anything
	-- anchored to the strip would lose its position. The strip keeps its height and
	-- is hidden; the page content is moved down by it instead (see f:Set).
	f:SetHeight(BANNER_H)
	f:Hide()
	f.bg = O:Rect(f, nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.bar = O:Rect(f, nil, "ARTWORK")
	f.bar:SetWidth(3)
	f.bar:SetPoint("TOPLEFT")
	f.bar:SetPoint("BOTTOMLEFT")
	f.icon = O:Icon(f, "warn", 14, nil, "OVERLAY")
	f.icon:SetPoint("LEFT", 16, 0)
	f.text = O:Text(f, O.SIZE.small, "label")
	f.text:SetPoint("LEFT", f.icon, "RIGHT", 10, 0)
	f.text:SetPoint("RIGHT", -16, 0)
	f.text:SetWordWrap(true)
	f.text:SetMaxLines(2)
	f.line = O:Rect(f, "line", "ARTWORK")
	f.line:SetHeight(1)
	f.line:SetPoint("BOTTOMLEFT")
	f.line:SetPoint("BOTTOMRIGHT")
	function f:Set(kind, text)
		local content = S.content
		if not kind then
			self:Hide()
			if content then
				content:SetPoint("TOPLEFT", S.navbar, "BOTTOMLEFT", 0, 0)
			end
			return
		end
		if content then content:SetPoint("TOPLEFT", S.navbar, "BOTTOMLEFT", 0, -BANNER_H) end
		local r, g, b = O:Color("danger")
		if kind == "warn" then r, g, b = 1, 0.8, 0.2 end
		self.bg:SetVertexColor(r, g, b, 0.10)
		self.bar:SetVertexColor(r, g, b, 1)
		self.icon:SetTexture(O.MEDIA .. (kind == "warn" and "warn" or "close"))
		self.icon:SetVertexColor(r, g, b, 1)
		self.text:SetText(text or "")
		self:Show()
	end
	return f
end

-- "Category / Dungeon" or "Classes / Warrior" for the open page; nil for the
-- general pages, which sit at the top of the sidebar on their own.
local function CrumbFor(key)
	local token = key:match("^class:(%u+)$") or key:match("^spec:(%u+):")
	if token then
		for _, ce in ipairs(O.classEntries) do
			if ce.class.token == token then
				return key:find("^spec:") and ("Classes / " .. ce.class.name) or "Classes"
			end
		end
		return "Classes"
	end
	local e = XUI:GetModule(key) or O.groupByKey[key]
	if not (e and e.category) then return nil end
	local name = e.category
	for _, c in ipairs(XUI.CATEGORIES) do if c.key == e.category then name = c.name end end
	if e.category == "dungeon" and e.dungeon then name = name .. " / " .. e.dungeon end
	return name
end

function O:RefreshPageHead()
	local f = S.pageHead
	if not f then return end
	local m = XUI:GetModule(S.currentKey or "")
	f.module = m
	local showModule = m ~= nil
	f.enable:SetShown(showModule)
	f.preview:SetShown(showModule and m:HasPreview())
	f.test:SetShown(showModule and m.Test ~= nil)
	local states = showModule and m.PREVIEW_STATES
	f.state:SetShown(states and true or false)
	if states then
		local label = states[1].text
		for _, st in ipairs(states) do if st.value == m.previewState then label = st.text end end
		f.state.text:SetText(label)
		f.state:ClearAllPoints()
		f.state:SetPoint("RIGHT", m.Test and f.test or f.preview, "LEFT", -8, 0)
	end
	local last = (states and f.state) or ((showModule and m.Test) and f.test) or f.preview
	f.diag:SetShown(showModule)
	f.diag:ClearAllPoints()
	f.diag:SetPoint("RIGHT", last, "LEFT", -8, 0)
	-- keep the texts clear of the controls: stop them left of the leftmost one
	f.stop = showModule and f.diag or nil
	f.FitTexts()
	C_Timer.After(0, f.FitTexts) -- anchors above resolve a frame later
	f.status:SetText("")
	if S.banner then S.banner:Set(nil) end
	local crumb = S.currentKey and CrumbFor(S.currentKey)
	f.crumb:SetShown(crumb ~= nil)
	if crumb then
		f.crumb.text:SetText(crumb)
		f.crumb:SetWidth(f.crumb.text:GetStringWidth() + 8)
	end
	if m then
		f.icon:SetTexture(XUI.ModuleIcon(m))
		f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		f.icon:SetVertexColor(1, 1, 1)
		f.iconBorder:Apply({ useGlobal = false, style = "SOLID", size = 1, color = { 0, 0, 0, 1 } })
		f.title:SetText(m.name)
		f.desc:SetText(m.desc or "")
		f.PlaceEnable()
		f.enable.switch:SetState(m.db.enabled)
		f.enable.label:SetText(m.db.enabled and "Enabled" or "Disabled")
		f.enable.label:SetTextColor(O:Color(m.db.enabled and "text" or "muted"))
		local ok, why = m:CanRun()
		local note = m.untested and "  |cff888888Untested in game.|r" or ""
		-- problems go to the banner under the nav bar; the header keeps the calm states
		local banner
		if (m.errorCount or 0) > 0 then
			banner = { "bad", ("%d Lua error(s), last: %s"):format(m.errorCount, (m.errors and m.errors[#m.errors] or ""):match("^[^\n]*"):sub(1, 200)) }
		elseif m.db.enabled and not ok then
			banner = { "bad", "Not running: " .. (why or "unknown reason") }
		elseif m.db.enabled and m.running and #XUI.Health.Issues(m) > 0 then
			banner = { "warn", "Running, but check this: " .. XUI.Health.Issues(m)[1] }
		end
		if S.banner then S.banner:Set(banner and banner[1], banner and banner[2]) end
		if banner then
			f.status:SetText("")
		elseif m.db.enabled and m.running then
			f.status:SetTextColor(O:Accent())
			f.status:SetText("Running." .. note)
		elseif m.db.enabled then
			f.status:SetTextColor(O:Color("muted"))
			f.status:SetText("Enabled, starting..." .. note)
		else
			f.status:SetTextColor(O:Color("muted"))
			f.status:SetText(m:HasPreview() and ("Off - switch it on, or use Preview to see it." .. note)
				or ("Off - switch it on to use it." .. note))
		end
		local ar, ag, ab = O:Accent()
		if m.preview then
			f.preview.icon:SetVertexColor(ar, ag, ab)
			f.preview.text:SetTextColor(ar, ag, ab)
		else
			f.preview.icon:SetVertexColor(O:Color("muted"))
			f.preview.text:SetTextColor(O:Color("label"))
		end
	elseif O.groupByKey[S.currentKey] then
		local g = O.groupByKey[S.currentKey]
		f.icon:SetTexture(O.GroupIcon(g))
		f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		f.icon:SetVertexColor(1, 1, 1)
		f.iconBorder:Apply({ useGlobal = false, style = "SOLID", size = 1, color = { 0, 0, 0, 1 } })
		f.title:SetText(g.name)
		f.desc:SetText(g.desc or "")
	else
		local s
		for _, sp in ipairs(O.systemPages) do if sp.key == S.currentKey then s = sp end end
		f.icon:SetTexture(O.MEDIA .. (s and s.icon or "sliders"))
		f.icon:SetTexCoord(0, 1, 0, 1)
		f.icon:SetVertexColor(O:Accent())
		f.iconBorder:Apply({ useGlobal = false, style = "NONE" })
		f.title:SetText(s and s.title or "")
		f.desc:SetText(s and s.desc or "")
	end
end

--------------------------------------------------------------------------------
-- A small menu under a button: items = { { text, tip, onClick } }. Closes on a
-- click anywhere, on Escape and when the window hides.
--------------------------------------------------------------------------------
local menu

function O:ShowMenu(anchor, items)
	if not menu then
		menu = CreateFrame("Frame", "XUI_OptionsMenu", UIParent)
		menu:SetFrameStrata("FULLSCREEN_DIALOG")
		menu:SetToplevel(true)
		menu:EnableMouse(true)
		O:Skin(menu, "card", "fieldLine")
		tinsert(UISpecialFrames, "XUI_OptionsMenu")
		menu.blocker = CreateFrame("Button", nil, UIParent)
		menu.blocker:SetAllPoints(UIParent)
		menu.blocker:SetFrameStrata("FULLSCREEN")
		menu.blocker:SetScript("OnClick", function() menu:Hide() end)
		menu.blocker:Hide()
		menu:SetScript("OnShow", function() menu.blocker:Show() end)
		menu:SetScript("OnHide", function() menu.blocker:Hide() end)
		menu.rows = {}
	end
	local y = 4
	for i, item in ipairs(items) do
		local r = menu.rows[i]
		if not r then
			r = CreateFrame("Button", nil, menu)
			r:SetHeight(26)
			r.hl = O:Rect(r, "controlHover", "BACKGROUND")
			r.hl:SetAllPoints()
			r.hl:Hide()
			r.text = O:Text(r, O.SIZE.text, "text")
			r.text:SetPoint("LEFT", 10, 0)
			r:SetScript("OnEnter", function(self)
				self.hl:Show()
				if self.tip then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					GameTooltip:SetText(self.text:GetText(), 1, 1, 1)
					GameTooltip:AddLine(self.tip, 0.75, 0.75, 0.75, true)
					GameTooltip:Show()
				end
			end)
			r:SetScript("OnLeave", function(self) self.hl:Hide() GameTooltip:Hide() end)
			r:SetScript("OnClick", function(self)
				menu:Hide()
				if self.onClick then self.onClick() end
			end)
			menu.rows[i] = r
		end
		r.text:SetText(item.text)
		r.tip, r.onClick = item.tip, item.onClick
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 4, -y)
		r:SetPoint("TOPRIGHT", -4, -y)
		r:Show()
		y = y + 26
	end
	for i = #items + 1, #menu.rows do menu.rows[i]:Hide() end
	menu:SetSize(190, y + 4)
	menu:ClearAllPoints()
	menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
	menu:Show()
end

--------------------------------------------------------------------------------
-- A window with a text to copy (Ctrl+A, Ctrl+C)
--------------------------------------------------------------------------------
local textPopup

function O:ShowText(title, text)
	if not textPopup then
		local p = CreateFrame("Frame", "XUI_TextPopup", UIParent)
		p:SetSize(640, 440)
		p:SetFrameStrata("FULLSCREEN_DIALOG")
		p:SetPoint("CENTER")
		p:SetToplevel(true)
		p:EnableMouse(true)
		O:Skin(p, "window", "line")
		tinsert(UISpecialFrames, "XUI_TextPopup")
		p.title = O:Text(p, O.SIZE.heading, "text")
		p.title:SetPoint("TOPLEFT", 16, -14)
		p.hint = O:Text(p, O.SIZE.small, "muted")
		p.hint:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -4)
		p.hint:SetText("Press Ctrl+C to copy, then paste it where it is needed.")
		local close = O:IconButton(p, "close", 26, nil, function() p:Hide() end)
		close:SetPoint("TOPRIGHT", -8, -8)
		local holder = CreateFrame("Frame", nil, p)
		holder:SetPoint("TOPLEFT", 16, -62)
		holder:SetPoint("BOTTOMRIGHT", -16, 16)
		O:Skin(holder, "field", "fieldLine")
		local sf = CreateFrame("ScrollFrame", nil, holder, "ScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", 6, -6)
		sf:SetPoint("BOTTOMRIGHT", -24, 6)
		local box = CreateFrame("EditBox", nil, sf)
		box:SetMultiLine(true)
		box:SetWidth(580)
		box:SetAutoFocus(false)
		box:SetFont(O:FontPath(), O.SIZE.small, "")
		box:SetTextColor(O:Color("text"))
		box:SetScript("OnEscapePressed", function() p:Hide() end)
		sf:SetScrollChild(box)
		sf:SetScript("OnSizeChanged", function(_, w) box:SetWidth(w) end)
		p.box = box
		textPopup = p
	end
	textPopup.title:SetText(title or "")
	textPopup.box:SetText(text or "")
	textPopup:Show()
	textPopup.box:SetFocus()
	textPopup.box:HighlightText()
end
