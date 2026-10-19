--------------------------------------------------------------------------------
-- Mail contacts
-- A panel beside the Send Mail tab listing your other characters (and online
-- friends, guild members and favorites); one click fills in the recipient.
--
-- Every character you log in on while the module is on is remembered in
-- XUI.DB.global.mailAlts, so the list is the same on every character of the
-- account. Written from scratch; the idea comes from WindTools' Contacts.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local T = XUI.Templates
local Style = XUI.Style

local M = XUI:NewModule("MailContacts", {
	name = "Mail Contacts",
	desc = "A list of your other characters, online friends, guild members and favorites beside the Send Mail tab. Click a name to address the mail.",
	category = "misc",
	icon = [[Interface\Icons\INV_Letter_15]],
	order = 110,
	defaults = {
		defaultTab = "ALTS",
		showRealm = true,
		font = T.Font(12),
		border = T.Border(),
		background = T.Background(),
	},
})

local ROWS, ROW_H, WIDTH = 16, 20, 170
local TABS = {
	{ key = "ALTS", label = "Alts" },
	{ key = "FRIENDS", label = "Friends" },
	{ key = "GUILD", label = "Guild" },
	{ key = "FAVS", label = "Favs" },
}
M.TABS = { ALTS = "Alts", FRIENDS = "Friends", GUILD = "Guild", FAVS = "Favorites" }

local panel, tab, offset = nil, nil, 0
local list = {}

local function MyRealm()
	return (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or ""):gsub("%s", "")
end

local function Store(key)
	local g = XUI.DB.global
	g[key] = type(g[key]) == "table" and g[key] or {}
	return g[key]
end

local function ClassFileFromName(localized)
	if not localized or localized == "" then return end
	for file, name in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
		if name == localized then return file end
	end
	for file, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do
		if name == localized then return file end
	end
end

-- "Name-Realm" -> name, realm (realm falls back to the current one)
local function Split(full)
	local name, realm = tostring(full):match("^([^-]+)-(.+)$")
	return name or full, realm or MyRealm()
end

--------------------------------------------------------------------------------
-- Remembering characters
--------------------------------------------------------------------------------
function M:RememberSelf()
	local name = UnitName("player")
	if not name or name == UNKNOWNOBJECT then return end
	local realm = MyRealm()
	local _, class = UnitClass("player")
	local alts = Store("mailAlts")
	alts[name .. "-" .. realm] = { name = name, realm = realm, class = class, faction = UnitFactionGroup("player") }
end

--------------------------------------------------------------------------------
-- Building the lists
--------------------------------------------------------------------------------
local function ByName(a, b) return a.name:lower() < b.name:lower() end

local function BuildAlts()
	local me, realm = UnitName("player"), MyRealm()
	for key, c in pairs(Store("mailAlts")) do
		if type(c) == "table" and c.name and not (c.name == me and c.realm == realm) then
			list[#list + 1] = { name = c.name, realm = c.realm or realm, class = c.class, key = key, alt = true }
		end
	end
end

local function BuildFriends()
	local seen = {}
	local realm = MyRealm()
	for i = 1, C_FriendList.GetNumFriends() do
		local info = C_FriendList.GetFriendInfoByIndex(i)
		if info and info.connected and info.name then
			local name, r = Split(info.name)
			seen[name .. "-" .. r] = true
			list[#list + 1] = { name = name, realm = r, class = ClassFileFromName(info.className) }
		end
	end
	local faction = UnitFactionGroup("player")
	local _, online = BNGetNumFriends()
	for i = 1, online or 0 do
		local acc = C_BattleNet.GetFriendAccountInfo(i)
		local n = C_BattleNet.GetFriendNumGameAccounts(i) or 0
		for j = 1, n do
			local g = C_BattleNet.GetFriendGameAccountInfo(i, j)
			if g and g.clientProgram == "WoW" and g.wowProjectID == WOW_PROJECT_ID and g.characterName
				and g.characterName ~= "" and (not g.factionName or g.factionName == faction) then
				local r = (g.realmName and g.realmName ~= "") and g.realmName:gsub("%s", "") or realm
				local key = g.characterName .. "-" .. r
				if not seen[key] then
					seen[key] = true
					local class = g.classID and select(2, GetClassInfo(g.classID)) or ClassFileFromName(g.className)
					list[#list + 1] = { name = g.characterName, realm = r, class = class, note = acc and acc.accountName }
				end
			end
		end
	end
end

local function BuildGuild()
	if not IsInGuild() then return end
	local realm = MyRealm()
	for i = 1, GetNumGuildMembers() do
		local full, _, _, _, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
		if full and online then
			local name, r = Split(full)
			list[#list + 1] = { name = name, realm = r, class = class }
		end
	end
end

local function BuildFavs()
	for key, class in pairs(Store("mailFavs")) do
		local name, realm = Split(key)
		list[#list + 1] = { name = name, realm = realm, class = type(class) == "string" and class or nil, key = key, fav = true }
	end
end

function M:Rebuild()
	wipe(list)
	local ok = pcall(function()
		if tab == "ALTS" then BuildAlts()
		elseif tab == "FRIENDS" then BuildFriends()
		elseif tab == "GUILD" then BuildGuild()
		else BuildFavs() end
	end)
	if ok then table.sort(list, ByName) end
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
local function Recipient(c)
	if c.realm and c.realm ~= MyRealm() then return c.name .. "-" .. c.realm end
	return c.name
end

local function Pick(c)
	local box = _G.SendMailNameEditBox
	if not box then return end
	box:SetText(Recipient(c))
	box:SetCursorPosition(0)
	if _G.SendMailSubjectEditBox then _G.SendMailSubjectEditBox:SetFocus() end
end

local function ToggleFav(c)
	local favs = Store("mailFavs")
	local key = c.name .. "-" .. c.realm
	if favs[key] then favs[key] = nil else favs[key] = c.class or true end
	if tab == "FAVS" then M:Show() end
end

local function ShowMenu(row)
	local c = row.contact
	if not c or not MenuUtil or not MenuUtil.CreateContextMenu then return end
	MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(c.name)
		local isFav = Store("mailFavs")[c.name .. "-" .. c.realm]
		root:CreateButton(isFav and "Remove from favorites" or "Add to favorites", function() ToggleFav(c) end)
		if c.alt and c.key then
			root:CreateButton("Forget this character", function()
				Store("mailAlts")[c.key] = nil
				M:Show()
			end)
		end
	end)
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
function M:Draw()
	if not panel then return end
	local db = self.db
	local total = #list
	local maxOffset = math.max(0, total - ROWS)
	offset = math.min(math.max(offset, 0), maxOffset)
	for i = 1, ROWS do
		local row, c = panel.rows[i], list[offset + i]
		row.contact = c
		if c then
			local color = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
			local r, g, b = 1, 1, 1
			if color then r, g, b = color.r, color.g, color.b end
			row.text:SetTextColor(r, g, b)
			local text = c.name
			if db.showRealm and c.realm ~= MyRealm() then text = text .. " |cff888888" .. c.realm .. "|r" end
			row.text:SetText(text)
			row:Show()
		else
			row.text:SetText("")
			row:Hide()
		end
	end
	if total == 0 then
		panel.empty:SetText(tab == "ALTS" and "Log in on your other characters to add them." or "Nobody here.")
		panel.empty:Show()
	else
		panel.empty:Hide()
	end
	panel.count:SetText(total > ROWS and ("%d-%d / %d"):format(offset + 1, math.min(offset + ROWS, total), total) or "")
end

function M:Style()
	if not panel then return end
	local db = self.db
	Style:Border(panel):Apply(db.border)
	Style:ApplyBackground(Style:Background(panel), db.background)
	for _, fs in ipairs(panel.fonts) do Style:ApplyFont(fs, db.font) end
	for _, row in ipairs(panel.rows) do Style:ApplyFont(row.text, db.font) end
	for _, b in ipairs(panel.tabs) do
		local on = b.key == tab
		b.text:SetTextColor(on and 1 or 0.6, on and 1 or 0.6, on and 1 or 0.6)
		b.line:SetShown(on)
	end
end

function M:Show()
	if not panel then return end
	if _G.C_GuildInfo and tab == "GUILD" and IsInGuild() then pcall(C_GuildInfo.GuildRoster) end
	self:Rebuild()
	self:Draw()
	self:Style()
end

function M:SetTab(key)
	tab, offset = key, 0
	self:Show()
end

local function Build()
	if panel or not _G.SendMailFrame or not _G.MailFrame then return end
	panel = CreateFrame("Frame", "XUI_MailContacts", SendMailFrame)
	panel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 3, -1)
	panel:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMRIGHT", 3, 1)
	panel:SetWidth(WIDTH)
	panel:EnableMouse(true)
	panel:EnableMouseWheel(true)
	panel.fonts, panel.rows, panel.tabs = {}, {}, {}

	local step = (WIDTH - 12) / #TABS
	for i, t in ipairs(TABS) do
		local b = CreateFrame("Button", nil, panel)
		b:SetSize(step, 22)
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", 6 + (i - 1) * step, -6)
		b.key = t.key
		b.text = b:CreateFontString(nil, "OVERLAY")
		b.text:SetPoint("CENTER")
		b.text:SetText(t.label)
		b.line = b:CreateTexture(nil, "ARTWORK")
		b.line:SetColorTexture(XUI.UnpackColor(XUI.DB.global.accent))
		b.line:SetHeight(2)
		b.line:SetPoint("BOTTOMLEFT", 4, 0)
		b.line:SetPoint("BOTTOMRIGHT", -4, 0)
		b:SetScript("OnClick", function() M:SetTab(t.key) end)
		panel.fonts[#panel.fonts + 1] = b.text
		panel.tabs[i] = b
	end

	for i = 1, ROWS do
		local row = CreateFrame("Button", nil, panel)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -34 - (i - 1) * ROW_H)
		row:SetPoint("RIGHT", panel, "RIGHT", -6, 0)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row.hl = row:CreateTexture(nil, "HIGHLIGHT")
		row.hl:SetAllPoints()
		row.hl:SetColorTexture(1, 1, 1, 0.12)
		row.text = row:CreateFontString(nil, "OVERLAY")
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
			if c.note then GameTooltip:AddLine(c.note, 0.35, 0.67, 0.87) end
			GameTooltip:AddLine("Right-click for options", 0.5, 0.5, 0.5)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		panel.rows[i] = row
	end

	panel.empty = panel:CreateFontString(nil, "OVERLAY")
	panel.empty:SetPoint("TOPLEFT", 12, -44)
	panel.empty:SetPoint("RIGHT", -12, 0)
	panel.empty:SetJustifyH("LEFT")
	panel.empty:SetWordWrap(true)
	panel.empty:SetTextColor(0.6, 0.6, 0.6)
	panel.fonts[#panel.fonts + 1] = panel.empty

	panel.count = panel:CreateFontString(nil, "OVERLAY")
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
	self:RegisterEvent("GUILD_ROSTER_UPDATE", function()
		if panel and panel:IsVisible() and tab == "GUILD" then M:Rebuild() M:Draw() end
	end)
	self:RegisterEvent("FRIENDLIST_UPDATE", function()
		if panel and panel:IsVisible() and tab == "FRIENDS" then M:Rebuild() M:Draw() end
	end)
	self:RegisterEvent("BN_FRIEND_INFO_CHANGED", function()
		if panel and panel:IsVisible() and tab == "FRIENDS" then M:Rebuild() M:Draw() end
	end)
end

function M:OnRefresh()
	if not self:IsRunning() then
		if panel then panel:Hide() end
		return
	end
	Build()
	if not panel then return end
	panel:Show()
	if not tab then tab = self.db.defaultTab or "ALTS" end
	if panel:IsVisible() then self:Show() end
end

function M:Test()
	if not self:RequireRunning() then return end
	if _G.MailFrame and not MailFrame:IsShown() and _G.ShowUIPanel then pcall(ShowUIPanel, MailFrame) end
	if _G.MailFrameTab_OnClick and _G.MailFrameTab2 then pcall(MailFrameTab_OnClick, MailFrameTab2, 2) end
end

function M:DebugInfo()
	local alts = 0
	for _ in pairs(Store("mailAlts")) do alts = alts + 1 end
	return { ("panel: %s, tab: %s, rows: %d, remembered characters: %d"):format(panel and "built" or "not built", tostring(tab), #list, alts) }
end
