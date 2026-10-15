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
-- that already carries a marker is left alone unless asked to replace it. In a
-- raid it needs lead or assist; in a party anyone may mark.
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

local function MarkerName(index)
	for _, m in ipairs(M.MARKERS) do
		if m.value == index then return m.text end
	end
	return tostring(index)
end

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
	if IsInRaid() then
		if not M.db.inRaid then return false end
		return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
	end
	return M.db.inParty
end

-- The tanks that need the marker.
local function Wanted()
	local out = {}
	if not Allowed() then return out end
	local index = M.db.marker
	for _, unit in ipairs(Units()) do
		pcall(function()
			if not UnitExists(unit) then return end
			local role = UnitGroupRolesAssigned(unit)
			if XUI.IsSecret(role) or role ~= "TANK" then return end
			local current = GetRaidTargetIndex(unit)
			if XUI.IsSecret(current) or current == index then return end
			if current and not M.db.replace then return end
			out[#out + 1] = unit
		end)
	end
	return out
end

local button, label, icon
local function Button()
	if button then return button end
	button = CreateFrame("Button", "XUI_MarkTankButton", UIParent, "SecureActionButtonTemplate")
	button:SetSize(170, 28)
	button:SetFrameStrata("MEDIUM")
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetAttribute("type", "macro")
	button:Hide()
	Style:Background(button)
	-- hover: a soft white wash, drawn by the client while the cursor is over it
	local hover = button:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints(button)
	hover:SetColorTexture(1, 1, 1, 0.2)
	icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("LEFT", button, "LEFT", 6, 0)
	icon:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcons]])
	label = button:CreateFontString(nil, "OVERLAY")
	label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	label:SetPoint("RIGHT", button, "RIGHT", -6, 0)
	label:SetJustifyH("LEFT")
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
	Style:ApplyFont(label, db.text)
	label:SetText(("Mark tank: %s"):format(MarkerName(db.marker)))
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
	b:SetAttribute("macrotext", table.concat(lines, "\n"))
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
