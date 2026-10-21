--------------------------------------------------------------------------------
-- Cooldown Manager combat res
-- Lets the group's battle resurrection pool be tracked on an EllesmereUI
-- Cooldown Manager bar by any class.
--
-- Add it the usual way: a bar's "+" > Custom Spell ID > 20484 (Rebirth), with
-- "Show Charges" ticked for the count. EllesmereUI only draws a custom spell
-- that is in the player's spellbook (ns.IsSpellInPlayerBook, looked up at call
-- time), which a Rebirth of someone else's class never is, so the entry was
-- kept but never shown. That check is wrapped to say yes for the combat res
-- spell. The pool is the spell's charges for every class, so the charge count
-- works unchanged; the swipe of a non-druid's frame has no cooldown behind it,
-- so the recharge of the pool is pushed onto it from here while the frame is
-- shown.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local M = XUI:NewModule("EUICombatRes", {
	name = "Cooldown Manager Combat Res",
	desc = "Track the group's battle resurrections on an EllesmereUI Cooldown Manager bar, whatever your class.",
	category = "tweaks",
	icon = [[Interface\Icons\Spell_Nature_Reincarnation]],
	order = 92,
	requires = "EllesmereUICooldownManager",
	defaults = {},
})

local SPELL = 20484 -- Rebirth: its charges are the shared pool for everyone
local SUFFIX = ":custom:" .. SPELL
local active = false
local wrapped = false
local original
local pushed = 0

local function CDM()
	return XUI.EUI and XUI.EUI.Module("EllesmereUICooldownManager")
end

local function Wrap(ns)
	if wrapped or type(ns.IsSpellInPlayerBook) ~= "function" then return end
	wrapped = true
	original = ns.IsSpellInPlayerBook
	ns.IsSpellInPlayerBook = function(id, ...)
		if active and id == SPELL then return true end
		return original(id, ...)
	end
end

-- the shown frames for the combat res spell, one per bar that lists it
local function Frames(ns)
	local list
	for key, f in pairs(ns._presetFrames or {}) do
		if type(key) == "string" and key:sub(-#SUFFIX) == SUFFIX and f:IsShown() then
			list = list or {}
			list[#list + 1] = f
		end
	end
	return list
end

local function Push()
	local ns = CDM()
	if not (active and ns) then return end
	local frames = Frames(ns)
	if not frames then return end
	-- a druid's own Rebirth cooldown is EllesmereUI's to draw
	if IsPlayerSpell and IsPlayerSpell(SPELL) then return end
	local ok, obj = pcall(C_Spell.GetSpellChargeDuration, SPELL)
	for _, f in ipairs(frames) do
		local cd = f._cooldown
		if cd then
			if ok and obj and cd.SetCooldownFromDurationObject then
				pcall(cd.SetCooldownFromDurationObject, cd, obj, true)
				pushed = pushed + 1
			else
				cd:Clear()
			end
		end
	end
end

local function Rebuild()
	local ns = CDM()
	if ns and type(ns.QueueReanchor) == "function" then pcall(ns.QueueReanchor) end
end

function M:OnEnable()
	active = true
	local ns = CDM()
	if ns then Wrap(ns) end
	self:RegisterEvent("SPELL_UPDATE_CHARGES", Push)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", Push)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", Push)
	self:RegisterEvent("ENCOUNTER_START", Push)
	self:RegisterEvent("ENCOUNTER_END", Push)
	-- the bars are built a moment after login
	self:After(2, function() Rebuild(); Push() end)
	Rebuild()
end

function M:OnDisable()
	active = false
	Rebuild()
end

function M:OnRefresh()
	if active then Rebuild(); Push() end
end

function M:DebugInfo()
	local ns = CDM()
	local frames = ns and Frames(ns)
	local info = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(SPELL)
	return {
		"book check wrapped: " .. tostring(wrapped),
		"combat res spell known to the player: " .. tostring(IsPlayerSpell and IsPlayerSpell(SPELL) or false),
		"shown frames for spell " .. SPELL .. ": " .. (frames and #frames or 0),
		"swipe pushes: " .. pushed,
		"charge info present: " .. tostring(info ~= nil),
	}
end
