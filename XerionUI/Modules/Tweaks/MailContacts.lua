--------------------------------------------------------------------------------
-- Mail alts
-- A panel beside the Send Mail tab listing your other characters; one click
-- fills in the recipient.
--
-- Every character you log in on while the module is on is remembered in
-- XUI.DB.global.mailAlts, so the list is the same on every character of the
-- account. Written from scratch; the idea comes from WindTools' Contacts.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local T = XUI.Templates
local Style = XUI.Style

local M = XUI:NewModule("MailContacts", {
	name = "Mail Alts",
	desc = "A list of your other characters beside the Send Mail tab. Click a name to address the mail.",
	category = "misc",
	icon = [[Interface\Icons\INV_Letter_15]],
	order = 110,
	defaults = {
		showRealm = true,
		font = T.Font(12),
		border = T.Border(),
		background = T.Background(),
	},
})

local ROWS, ROW_H, WIDTH = 16, 20, 170

local panel, offset = nil, 0
local list = {}

local function MyRealm()
	return (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or ""):gsub("%s", "")
end

local function Alts()
	local g = XUI.DB.global
	g.mailAlts = type(g.mailAlts) == "table" and g.mailAlts or {}
	return g.mailAlts
end

--------------------------------------------------------------------------------
-- Remembering characters
--------------------------------------------------------------------------------
function M:RememberSelf()
	local name = UnitName("player")
	if not name or name == UNKNOWNOBJECT then return end
	local realm = MyRealm()
	local _, class = UnitClass("player")
	Alts()[name .. "-" .. realm] = { name = name, realm = realm, class = class, faction = UnitFactionGroup("player") }
end

function M:Rebuild()
	wipe(list)
	local me, realm = UnitName("player"), MyRealm()
	for key, c in pairs(Alts()) do
		if type(c) == "table" and c.name and not (c.name == me and c.realm == realm) then
			list[#list + 1] = { name = c.name, realm = c.realm or realm, class = c.class, key = key }
		end
	end
	table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
local function Pick(c)
	local box = _G.SendMailNameEditBox
	if not box then return end
	box:SetText(c.realm ~= MyRealm() and (c.name .. "-" .. c.realm) or c.name)
	box:SetCursorPosition(0)
	if _G.SendMailSubjectEditBox then _G.SendMailSubjectEditBox:SetFocus() end
end

local function ShowMenu(row)
	local c = row.contact
	if not (c and MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(c.name)
		root:CreateButton("Forget this character", function()
			Alts()[c.key] = nil
			M:Show()
		end)
	end)
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
function M:Draw()
	if not panel then return end
	local total = #list
	offset = math.min(math.max(offset, 0), math.max(0, total - ROWS))
	for i = 1, ROWS do
		local row, c = panel.rows[i], list[offset + i]
		row.contact = c
		if c then
			local color = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
			if color then row.text:SetTextColor(color.r, color.g, color.b) else row.text:SetTextColor(1, 1, 1) end
			local text = c.name
			if self.db.showRealm and c.realm ~= MyRealm() then text = text .. " |cff888888" .. c.realm .. "|r" end
			row.text:SetText(text)
			row:Show()
		else
			row.text:SetText("")
			row:Hide()
		end
	end
	panel.empty:SetShown(total == 0)
	panel.count:SetText(total > ROWS and ("%d-%d / %d"):format(offset + 1, math.min(offset + ROWS, total), total) or "")
end

function M:Style()
	if not panel then return end
	local db = self.db
	Style:Border(panel):Apply(db.border)
	Style:ApplyBackground(Style:Background(panel), db.background)
	for _, fs in ipairs(panel.fonts) do Style:ApplyFont(fs, db.font) end
	for _, row in ipairs(panel.rows) do Style:ApplyFont(row.text, db.font) end
end

function M:Show()
	if not panel then return end
	self:Rebuild()
	self:Draw()
	self:Style()
end

-- A string must have a font before it gets any text (else SetText errors).
local function Text(parent)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	Style:ApplyFont(fs, M.db and M.db.font, 12)
	return fs
end

local function Build()
	if panel or not _G.SendMailFrame or not _G.MailFrame then return end
	panel = CreateFrame("Frame", "XUI_MailContacts", SendMailFrame)
	panel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 3, -1)
	panel:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMRIGHT", 3, 1)
	panel:SetWidth(WIDTH)
	panel:EnableMouse(true)
	panel:EnableMouseWheel(true)
	panel.fonts, panel.rows = {}, {}

	for i = 1, ROWS do
		local row = CreateFrame("Button", nil, panel)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -8 - (i - 1) * ROW_H)
		row:SetPoint("RIGHT", panel, "RIGHT", -6, 0)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row.hl = row:CreateTexture(nil, "HIGHLIGHT")
		row.hl:SetAllPoints()
		row.hl:SetColorTexture(1, 1, 1, 0.12)
		row.text = Text(row)
		row.text:SetPoint("LEFT", 4, 0)
		row.text:SetPoint("RIGHT", -4, 0)
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(false)
		row:SetScript("OnClick", function(self, button)
			if not self.contact then return end
			if button == "RightButton" then ShowMenu(self) else Pick(self.contact) end
		end)
		row:SetScript("OnEnter", function(self)
			local c = self.contact
			if not c then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(c.name)
			GameTooltip:AddLine(c.realm or "", 0.7, 0.7, 0.7)
			GameTooltip:AddLine("Right-click to forget", 0.5, 0.5, 0.5)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		panel.rows[i] = row
	end

	panel.empty = Text(panel)
	panel.empty:SetPoint("TOPLEFT", 12, -12)
	panel.empty:SetPoint("RIGHT", -12, 0)
	panel.empty:SetJustifyH("LEFT")
	panel.empty:SetWordWrap(true)
	panel.empty:SetTextColor(0.6, 0.6, 0.6)
	panel.empty:SetText("Log in on your other characters to add them.")
	panel.fonts[#panel.fonts + 1] = panel.empty

	panel.count = Text(panel)
	panel.count:SetPoint("BOTTOM", 0, 8)
	panel.count:SetTextColor(0.6, 0.6, 0.6)
	panel.fonts[#panel.fonts + 1] = panel.count

	panel:SetScript("OnMouseWheel", function(_, delta)
		offset = offset - delta * 2
		M:Draw()
	end)
	panel:SetScript("OnShow", function() if M.running then M:Show() end end)
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
function M:OnEnable()
	self:RememberSelf()
	self:RegisterEvent("MAIL_SHOW", "Refresh")
end

function M:OnRefresh()
	if not self:IsRunning() then
		if panel then panel:Hide() end
		return
	end
	Build()
	if not panel then return end
	panel:Show()
	if panel:IsVisible() then self:Show() end
end

function M:Test()
	if not self:RequireRunning() then return end
	if _G.MailFrame and not MailFrame:IsShown() and _G.ShowUIPanel then pcall(ShowUIPanel, MailFrame) end
	if _G.MailFrameTab_OnClick and _G.MailFrameTab2 then pcall(MailFrameTab_OnClick, MailFrameTab2, 2) end
end

function M:DebugInfo()
	local n = 0
	for _ in pairs(Alts()) do n = n + 1 end
	return { ("panel: %s, listed: %d, remembered characters: %d"):format(panel and "built" or "not built", #list, n) }
end
