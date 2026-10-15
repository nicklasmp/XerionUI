--------------------------------------------------------------------------------
-- Auto Mark Tank
-- Puts a raid marker (the square by default) on the group's tank when the group
-- forms, the roles change or you zone in, so everyone can see who tanks and
-- the tank is easy to target.
--
-- It acts on those moments only, never on a timer, and leaves a tank that
-- already carries a marker alone unless asked to replace it. In a raid it needs
-- lead or assist; in a party anyone may mark.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local M = XUI:NewModule("AutoMarkTank", {
	name = "Auto Mark Tank",
	desc = "Puts a raid marker (square by default) on the tank of your group.",
	category = "group",
	icon = [[Interface\TargetingFrame\UI-RaidTargetingIcon_6]],
	order = 65,
	defaults = {
		marker = 6,
		inParty = true,
		inRaid = false,
		replace = false,
		outOfCombat = true,
		announce = true,
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
	if IsInRaid() then
		if not M.db.inRaid then return false end
		return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
	end
	return M.db.inParty and IsInGroup()
end

-- Marks every tank that needs it; returns how many were marked.
function M:Mark(force)
	if not (self.running and IsInGroup()) then return 0 end
	if not force then
		if not Allowed() then return 0 end
		if self.db.outOfCombat and InCombatLockdown() then return 0 end
	end
	local index = self.db.marker
	local marked = 0
	for _, unit in ipairs(Units()) do
		local ok = pcall(function()
			if not UnitExists(unit) then return end
			if XUI.IsSecret(UnitGroupRolesAssigned(unit)) then return end
			if UnitGroupRolesAssigned(unit) ~= "TANK" then return end
			local current = GetRaidTargetIndex(unit)
			if XUI.IsSecret(current) then return end
			if current == index then return end
			if current and not (self.db.replace or force) then return end
			SetRaidTarget(unit, index)
			marked = marked + 1
			if self.db.announce then
				self:Print(("%s marked with %s."):format(UnitName(unit) or unit, MarkerName(index)))
			end
		end)
		if not ok then self:Trace("could not mark %s", unit) end
	end
	return marked
end

local pending = false
function M:Soon()
	if pending then return end
	pending = true
	-- roles and unit tokens settle a moment after the event
	self:After(1.5, function()
		pending = false
		self:Mark()
	end)
end

function M:OnEnable()
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "Soon")
	self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "Soon")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "Soon")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "Soon")
	self:Soon()
end

function M:Test()
	if not self:RequireRunning() then return end
	if not IsInGroup() then
		self:Print("join a group with a tank to test this.")
		return
	end
	local n = self:Mark(true)
	if n == 0 then self:Print("no tank to mark (or already marked).") end
end

function M:DebugInfo()
	local lines = { ("in group: %s, raid: %s, allowed: %s"):format(tostring(IsInGroup()), tostring(IsInRaid()), tostring(Allowed())) }
	for _, unit in ipairs(Units()) do
		if UnitExists(unit) then
			lines[#lines + 1] = ("%s: role %s, marker %s"):format(unit, tostring(UnitGroupRolesAssigned(unit)), tostring(GetRaidTargetIndex(unit)))
		end
	end
	return lines
end
