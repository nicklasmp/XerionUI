--------------------------------------------------------------------------------
-- Bonus Roll Confirm
-- Asks "are you sure?" before a bonus roll is spent (and optionally before it is
-- passed), and names the loot specialization the roll will award for, so a roll
-- is never burned by accident or on the wrong spec.
--
-- Ported from the BonusRollConfirm addon. The buttons of Blizzard's
-- BonusRollFrame are wrapped once; the wrapper calls the original handler only
-- after the popup is accepted, and goes straight through while the module is
-- off, so nothing has to be undone on disable.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local M = XUI:NewModule("BonusRollConfirm", {
	name = "Bonus Roll Confirm",
	desc = "Asks for confirmation before a bonus roll is used, and shows your loot spec.",
	category = "misc",
	icon = [[Interface\Icons\inv_misc_curiouscoin]],
	order = 64,
	defaults = {
		confirmRoll = true,
		confirmPass = true,
		showSpec = true,
		announce = true,
	},
})

local DIALOG_ROLL = "XUI_BONUS_ROLL_CONFIRM"
local DIALOG_PASS = "XUI_BONUS_PASS_CONFIRM"

local function Accepted(_, data)
	if type(data) == "table" and data.run then data.run() end
end

local function Cancelled(_, data)
	if type(data) == "table" and data.cancel then data.cancel() end
end

local function Define(key, text)
	StaticPopupDialogs[key] = {
		text = text,
		button1 = CONFIRM or ACCEPT or "Confirm",
		button2 = CANCEL or "Cancel",
		OnAccept = Accepted,
		OnCancel = Cancelled,
		timeout = 0,
		whileDead = false,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end

Define(DIALOG_ROLL, "Are you sure you want to use a bonus roll?%s")
Define(DIALOG_PASS, "Are you sure you want to pass on this bonus roll?")

-- Name of the spec loot will be awarded for.
function M.LootSpecText()
	local specID = GetLootSpecialization and GetLootSpecialization()
	if type(specID) == "number" and specID > 0 then
		local name = select(2, GetSpecializationInfoByID(specID))
		if name then return name end
	elseif GetSpecialization then
		local index = GetSpecialization()
		local name = index and select(2, GetSpecializationInfo(index))
		if name then return name .. " (current spec)" end
	end
	return "unknown"
end

local function Say(text)
	if M.db.announce then M:Print(text) end
end

-- Wraps one button's OnClick. isRoll picks which question is asked.
local function HookButton(btn, isRoll)
	if not btn or btn._xuiBonusHooked then return end
	local original = btn:GetScript("OnClick")
	if not original then return end
	btn._xuiBonusHooked = true

	btn:SetScript("OnClick", function(self, button, down)
		local wanted = M.running and (isRoll and M.db.confirmRoll or (not isRoll and M.db.confirmPass))
		local done = isRoll and "bonus roll used." or "bonus roll passed."
		if not wanted then
			original(self, button, down)
			if M.running then Say(done) end
			return
		end
		local data = {
			run = function()
				original(self, button, down)
				Say(done)
			end,
			cancel = function() Say(isRoll and "bonus roll cancelled." or "pass cancelled.") end,
		}
		if isRoll then
			local spec = M.db.showSpec and ("\n\nLoot spec: |cffffd100" .. M.LootSpecText() .. "|r") or ""
			StaticPopup_Show(DIALOG_ROLL, spec, nil, data)
		else
			StaticPopup_Show(DIALOG_PASS, nil, nil, data)
		end
	end)
end

local function HookFrame()
	local frame = _G.BonusRollFrame
	if not frame or frame._xuiBonusScanned then return end

	local rollBtn = (frame.PromptFrame and frame.PromptFrame.RollButton) or frame.RollButton
	local function Scan(parent)
		for i = 1, parent:GetNumChildren() do
			local child = select(i, parent:GetChildren())
			if child then
				if child.IsObjectType and child:IsObjectType("Button") then
					HookButton(child, child == rollBtn)
				end
				Scan(child)
			end
		end
	end
	Scan(frame)
	frame._xuiBonusScanned = true
end

function M:OnEnable()
	self:RegisterEvent("BONUS_ROLL_STARTED", HookFrame)
	if type(_G.BonusRollFrame_StartBonusRoll) == "function" then
		self:SecureHook("BonusRollFrame_StartBonusRoll", HookFrame)
	end
	HookFrame()
end

-- Shows the roll question without needing a real bonus roll.
function M:Test()
	if not self:RequireRunning() then return end
	local spec = self.db.showSpec and ("\n\nLoot spec: |cffffd100" .. M.LootSpecText() .. "|r") or ""
	StaticPopup_Show(DIALOG_ROLL, spec, nil, {
		run = function() Say("test: bonus roll would be used.") end,
		cancel = function() Say("test: bonus roll cancelled.") end,
	})
end

function M:DebugInfo()
	return {
		("BonusRollFrame: %s, hooked: %s"):format(_G.BonusRollFrame and "found" or "missing",
			tostring(_G.BonusRollFrame and _G.BonusRollFrame._xuiBonusScanned or false)),
		("loot spec: %s"):format(M.LootSpecText()),
	}
end
