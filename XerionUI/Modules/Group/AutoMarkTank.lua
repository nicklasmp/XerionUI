--------------------------------------------------------------------------------
-- Auto Mark Tank
-- Offers a raid marker (the square by default) for the group's tank. Placing a
-- marker is a protected action: an addon may only do it from a click, never on
-- its own. So when the group forms, the roles change or you zone in and a tank
-- is without the marker, a small button appears; one click marks the tank
-- (through the secure /tm command) and the button goes away.
--
-- The button is a secure button; its macro is only rewritten out of combat and
-- it only shows and hides out of combat, so nothing is ever blocked. A tank
-- that already carries a marker is left alone unless asked to replace it. The
-- small x on the button dismisses it until the situation changes. In a
-- raid it needs lead or assist; in a party anyone may mark. Only active inside
-- dungeons (5-player instances).
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local T = XUI.Templates
local Style = XUI.Style

local M = XUI:NewModule("AutoMarkTank", {
	name = "Auto Mark Tank",
	desc = "A one-click button that puts a raid marker (square by default) on the tank of your group.",
	category = "group",
	icon = [[Interface\TargetingFrame\UI-RaidTargetingIcon_6]],
	order = 65,
	defaults = {
		marker = 6,
		inParty = true,
		inRaid = false,
		replace = false,
		text = T.Font(13, { color = { 1, 1, 1, 1 } }),
		border = T.Border(),
		position = T.Position(0, 170),
	},
})

M.MARKERS = {
	{ value = 1, text = "Star" }, { value = 2, text = "Circle" }, { value = 3, text = "Diamond" },
	{ value = 4, text = "Triangle" }, { value = 5, text = "Moon" }, { value = 6, text = "Square" },
	{ value = 7, text = "Cross" }, { value = 8, text = "Skull" },
}

local function Units()
	local list = { "player" }
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do list[#list + 1] = "raid" .. i end
	else
		for i = 1, 4 do list[#list + 1] = "party" .. i end
	end
	return list
end

local function Allowed()
	if not IsInGroup() then return false end
	-- dungeons only (5-player instances)
	local _, kind = IsInInstance()
	if kind ~= "party" then return false end
	if IsInRaid() then
		if not M.db.inRaid then return false end
		return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
	end
	return M.db.inParty
end

-- one unit of the Wanted scan (a named function so pcall needs no closure per unit)
local function CollectIfWanted(unit, index, out)
	if not UnitExists(unit) then return end
	local role = UnitGroupRolesAssigned(unit)
	if XUI.IsSecret(role) or role ~= "TANK" then return end
	local current = GetRaidTargetIndex(unit)
	if XUI.IsSecret(current) or current == index then return end
	if current and not M.db.replace then return end
	out[#out + 1] = unit
end

-- The tanks that need the marker.
local function Wanted()
	local out = {}
	if not Allowed() then return out end
	local index = M.db.marker
	for _, unit in ipairs(Units()) do
		pcall(CollectIfWanted, unit, index, out)
	end
	return out
end

local function IsTank(unit)
	return UnitExists(unit) and UnitGroupRolesAssigned(unit) == "TANK"
end

local button, label, icon, close, title
local dismissed -- macro text the user closed; the button stays away until it changes
local shownUnits = {} -- tanks the button currently offers (names are read when drawing)

-- "Name" or "Name +1" for the tank(s) on offer, in the tank's class colour.
local function TankText()
	local unit = shownUnits[1]
	if not unit then
		-- preview or nothing on offer: show any tank in the group, else yourself
		unit = "player"
		for _, u in ipairs(Units()) do
			local ok, isTank = pcall(IsTank, u)
			if ok and isTank == true then
				unit = u
				break
			end
		end
	end
	local name, r, g, b = "Tank", 1, 1, 1
	pcall(function()
		-- a secret name still draws through SetText, it just cannot be concatenated
		local n = UnitName(unit)
		if n then name = n end
		local class = UnitClassBase(unit)
		local c = class and not XUI.IsSecret(class) and RAID_CLASS_COLORS[class]
		if c then r, g, b = c.r, c.g, c.b end
	end)
	if #shownUnits > 1 and not XUI.IsSecret(name) then name = ("%s +%d"):format(name, #shownUnits - 1) end
	return name, r, g, b
end

local function Button()
	if button then return button end
	button = CreateFrame("Button", "XUI_MarkTankButton", UIParent, "SecureActionButtonTemplate")
	button:SetSize(236, 78)
	button:SetFrameStrata("MEDIUM")
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetAttribute("type", "macro")
	button:Hide()
	Style:Background(button)
	-- header strip with the title and the close x
	local head = button:CreateTexture(nil, "BORDER")
	head:SetHeight(26)
	head:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	head:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
	head:SetColorTexture(1, 1, 1, 0.04)
	title = button:CreateFontString(nil, "OVERLAY")
	title:SetPoint("LEFT", head, "LEFT", 10, 0)
	-- inset action row: marker icon + hint, the part that reads as the button
	local row = button:CreateTexture(nil, "BORDER")
	row:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 10, 10)
	row:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -10, 10)
	row:SetHeight(40)
	row:SetColorTexture(0, 0, 0, 0.4)
	-- hover: a soft white wash over the action row, drawn by the client
	local hover = button:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints(row)
	hover:SetColorTexture(1, 1, 1, 0.08)
	icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(28, 28)
	icon:SetPoint("LEFT", row, "LEFT", 6, 0)
	icon:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcons]])
	label = button:CreateFontString(nil, "OVERLAY")
	label:SetPoint("LEFT", icon, "RIGHT", 12, 0)
	label:SetPoint("RIGHT", button, "RIGHT", -18, 0)
	label:SetJustifyH("LEFT")
	-- close: a square in the header corner
	close = CreateFrame("Button", nil, button)
	close:SetSize(26, 26)
	close:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
	close:SetFrameLevel(button:GetFrameLevel() + 5)
	local wash = close:CreateTexture(nil, "BACKGROUND")
	wash:SetAllPoints()
	wash:SetColorTexture(0.85, 0.22, 0.22, 0)
	local x = close:CreateFontString(nil, "OVERLAY")
	x:SetFont(STANDARD_TEXT_FONT, 18, "")
	x:SetPoint("CENTER", 0, 1)
	x:SetText("\195\151") -- multiplication sign
	x:SetTextColor(0.6, 0.6, 0.6)
	close:SetScript("OnEnter", function()
		x:SetTextColor(1, 1, 1)
		wash:SetColorTexture(0.85, 0.22, 0.22, 0.45)
	end)
	close:SetScript("OnLeave", function()
		x:SetTextColor(0.6, 0.6, 0.6)
		wash:SetColorTexture(0.85, 0.22, 0.22, 0)
	end)
	close:SetScript("OnClick", function()
		dismissed = button:GetAttribute("macrotext") or ""
		-- a secure frame cannot be hidden in combat; Check hides it afterwards
		if not InCombatLockdown() then button:Hide() end
	end)
	XUI.Movers:Register(button, M, "position")
	-- one click done: look again, so the button leaves once the tank is marked
	button:HookScript("PostClick", function() M:After(0.4, M.Check) end)
	return button
end

local function Draw()
	local b = Button()
	local db = M.db
	XUI.Movers:Apply(b)
	Style:Border(b):Apply(db.border)
	Style:ApplyBackground(Style:Background(b), nil)
	local size = db.text.size or 13
	Style:ApplyFont(title, db.text, math.max(size - 1, 8))
	title:SetTextColor(0.85, 0.85, 0.85)
	title:SetText("Auto Mark Tank")
	Style:ApplyFont(label, db.text, size + 1)
	local name, r, g, bl = TankText()
	label:SetText(name)
	label:SetTextColor(r, g, bl)
	local col, row = (db.marker - 1) % 4, math.floor((db.marker - 1) / 4)
	icon:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
end

-- Sets the macro and shows or hides the button; out of combat only.
function M:Check()
	if not self.running or InCombatLockdown() then return end
	local b = Button()
	local units = Wanted()
	if #units == 0 and not self:IsPreview() then
		b:Hide()
		return
	end
	local lines = {}
	for _, unit in ipairs(units) do
		lines[#lines + 1] = ("/tm [@%s] %d"):format(unit, self.db.marker)
	end
	local macro = table.concat(lines, "\n")
	if macro == dismissed and not self:IsPreview() then
		b:Hide()
		return
	end
	b:SetAttribute("macrotext", macro)
	shownUnits = units
	Draw()
	b:Show()
end

local pending = false
function M:Soon()
	if pending then return end
	pending = true
	-- roles and unit tokens settle a moment after the event
	self:After(1.5, function()
		pending = false
		self:Check()
	end)
end

function M:OnEnable()
	Button()
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "Soon")
	self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "Soon")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "Soon")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "Soon")
	self:RegisterEvent("RAID_TARGET_UPDATE", "Soon")
	self:Soon()
end

function M:OnDisable()
	if button and not InCombatLockdown() then button:Hide() end
end

function M:OnRefresh()
	if not button then return end
	if self.running then self:Check() end
	if self:IsPreview() and not InCombatLockdown() then
		Draw()
		button:Show()
	end
end

function M:Test()
	if not self:RequireRunning() then return end
	if not IsInGroup() then
		self:Print("join a group with a tank to test this.")
		return
	end
	self:Check()
end

function M:DebugInfo()
	local lines = { ("in group: %s, raid: %s, allowed: %s"):format(tostring(IsInGroup()), tostring(IsInRaid()), tostring(Allowed())) }
	for _, unit in ipairs(Units()) do
		if UnitExists(unit) then
			lines[#lines + 1] = ("%s: role %s, marker %s"):format(unit, tostring(UnitGroupRolesAssigned(unit)), tostring(GetRaidTargetIndex(unit)))
		end
	end
	lines[#lines + 1] = "button shown: " .. tostring(button and button:IsShown())
	return lines
end
