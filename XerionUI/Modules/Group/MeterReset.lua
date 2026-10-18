--------------------------------------------------------------------------------
-- Meter Reset
-- Asks whether to reset the damage meter when you leave a dungeon (optionally
-- raids and scenarios too), so the next run starts from a clean meter.
--
-- Leaving is detected by comparing the instance type before and after each
-- loading screen. The reset itself is Blizzard's own C_DamageMeter call.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local M = XUI:NewModule("MeterReset", {
	name = "Meter Reset",
	desc = "Asks if you want to reset the damage meter when you leave a dungeon.",
	category = "misc",
	icon = [[Interface\Icons\inv_misc_book_09]],
	order = 65,
	defaults = {
		dungeons = true,
		raids = false,
		scenarios = false,
		delay = 2,
		announce = true,
	},
})

local DIALOG = "XUI_METER_RESET_CONFIRM"

local function Say(text)
	if M.db.announce then M:Print(text) end
end

-- Resets every damage meter session. Returns false when the API is missing.
function M.ResetMeter()
	local DM = _G.C_DamageMeter
	if not (DM and DM.ResetAllCombatSessions) then return false end
	return (pcall(DM.ResetAllCombatSessions))
end

StaticPopupDialogs[DIALOG] = {
	text = "You left %s.\n\nReset the damage meter?",
	button1 = YES or "Yes",
	button2 = NO or "No",
	OnAccept = function()
		if M.ResetMeter() then
			Say("damage meter reset.")
		else
			Say("the damage meter API is not available.")
		end
	end,
	timeout = 0,
	whileDead = false,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- The instance type we are in right now, or nil outside instances.
local function CurrentType()
	local inInstance, kind = IsInInstance()
	if inInstance then return kind end
	return nil
end

local function Watched(kind)
	local db = M.db
	return (kind == "party" and db.dungeons)
		or (kind == "raid" and db.raids)
		or (kind == "scenario" and db.scenarios)
end

local LABELS = { party = "the dungeon", raid = "the raid", scenario = "the scenario" }

local previous, previousName

function M:OnEnable()
	previous = CurrentType()
	previousName = previous and (GetInstanceInfo()) or nil

	self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		local now = CurrentType()
		local left, name = previous, previousName
		previous = now
		previousName = now and (GetInstanceInfo()) or nil
		-- A /reload or a teleport between two instances is not "leaving".
		if now or not left or not Watched(left) then return end
		self:After(self.db.delay, function()
			if CurrentType() then return end
			StaticPopup_Show(DIALOG, name or LABELS[left] or "the instance")
		end)
	end)
end

-- Shows the question without needing to leave an instance.
function M:Test()
	if not self:RequireRunning() then return end
	StaticPopup_Show(DIALOG, "the dungeon")
end

function M:DebugInfo()
	local DM = _G.C_DamageMeter
	return {
		("instance type: %s"):format(tostring(CurrentType())),
		("ResetAllCombatSessions: %s"):format(DM and DM.ResetAllCombatSessions and "available" or "missing"),
	}
end
