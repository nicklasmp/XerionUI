--------------------------------------------------------------------------------
-- Auto NPC Dialog
-- Picks chosen gossip options for you inside instances (skip a dungeon's
-- talk-to-the-NPC step) and answers the "are you sure?" box for the ones you
-- list. Talk to the NPC, press "Print the open options" and add the IDs.
--
-- Rewritten from KiraUI-Plugin's Auto Gossip (personal use).
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local IsSecret = XUI.IsSecret
local SETHRALISS = 48126
local COOLDOWN = 5

local M = XUI:NewModule("AutoGossip", {
	name = "Auto NPC Dialog",
	desc = "Picks chosen gossip options for you inside dungeons.",
	category = "group",
	icon = [[Interface\Icons\INV_Misc_Note_01]],
	order = 62,
	defaults = {
		options = { 131567, 131502, SETHRALISS },
		confirm = { SETHRALISS },
		instanceOnly = true,
		announce = true,
	},
})

local lastPick = {}

local function IDSet(list)
	local set = {}
	if type(list) ~= "table" then return set end
	for _, id in ipairs(list) do
		local n = tonumber(id)
		if n then set[n] = true end
	end
	return set
end

local function Inside()
	if not M.db.instanceOnly then return true end
	local ok, inside = pcall(IsInInstance)
	if not ok or IsSecret(inside) then return true end
	return inside and true or false
end

local function Say(text)
	if M.db.announce then M:Print(text) end
end

local function Select(id, name, confirmed)
	local CG = C_GossipInfo
	if not (CG and CG.SelectOption) then return false end
	local ok
	if confirmed then ok = pcall(CG.SelectOption, id, "", true) else ok = pcall(CG.SelectOption, id) end
	if type(name) ~= "string" or IsSecret(name) then name = "option " .. id end
	Say((ok and "selected: " or "could not select: ") .. name .. (confirmed and ok and " (confirmed)" or ""))
	return ok
end

function M:TrySelect()
	if not Inside() then return end
	local wanted = IDSet(self.db.options)
	if not next(wanted) then return end
	local CG = C_GossipInfo
	if not (CG and CG.GetOptions and CG.SelectOption) then return end
	local ok, opts = pcall(CG.GetOptions)
	if not ok or type(opts) ~= "table" then return end
	local confirm = IDSet(self.db.confirm)
	local now = GetTime()
	for _, o in ipairs(opts) do
		local id = o.gossipOptionID
		if type(id) == "number" and not IsSecret(id) and wanted[id] then
			-- once per few seconds: a refreshed gossip window must not loop
			if lastPick[id] and (now - lastPick[id]) < COOLDOWN then return end
			lastPick[id] = now
			Select(id, o.name, confirm[id])
			return
		end
	end
end

-- The "are you sure?" box of an option you listed under confirm.
function M:OnConfirmShown(optionID)
	if not Inside() or IsSecret(optionID) then return end
	local id = tonumber(optionID)
	if not id or not IDSet(self.db.confirm)[id] then return end
	local CG = C_GossipInfo
	if not (CG and CG.SelectOption) then return end
	local ok = pcall(CG.SelectOption, id, "", true)
	if ok and StaticPopup_Hide then pcall(StaticPopup_Hide, "GOSSIP_CONFIRM") end
	Say((ok and "confirmed option " or "could not confirm option ") .. id)
end

function M:OnEnable()
	self:RegisterEvent("GOSSIP_SHOW", function(m) m:After(0, m.TrySelect) end)
	if type(GossipConfirmDialog_Show) == "function" then
		self:SecureHook("GossipConfirmDialog_Show", function(m, optionID) m:After(0, function() m:OnConfirmShown(optionID) end) end)
	else
		self:RegisterEvent("GOSSIP_CONFIRM", function(m, _, optionID) m:After(0, function() m:OnConfirmShown(optionID) end) end)
	end
end

-- Lists what the open gossip window offers, with the IDs to add.
function M:PrintOptions()
	local CG = C_GossipInfo
	local opts = CG and CG.GetOptions and select(2, pcall(CG.GetOptions))
	if type(opts) ~= "table" or #opts == 0 then
		self:Print("no gossip window is open - talk to the NPC first.")
		return
	end
	for _, o in ipairs(opts) do
		local name = (type(o.name) == "string" and not IsSecret(o.name)) and o.name or "?"
		local id = (type(o.gossipOptionID) == "number" and not IsSecret(o.gossipOptionID)) and o.gossipOptionID or "hidden"
		self:Print(("id %s  %s"):format(tostring(id), name))
	end
end

-- The two lists are edited as comma separated text.
function M.ListText(list)
	local out = {}
	for _, id in ipairs(list or {}) do out[#out + 1] = tostring(id) end
	return table.concat(out, ", ")
end

function M.ParseList(text)
	local out, seen = {}, {}
	for token in tostring(text or ""):gmatch("%d+") do
		local n = tonumber(token)
		if n and not seen[n] then
			seen[n] = true
			out[#out + 1] = n
		end
	end
	return out
end

function M:DebugInfo()
	return {
		("options: %s"):format(M.ListText(self.db.options)),
		("confirm: %s"):format(M.ListText(self.db.confirm)),
		("inside an instance: %s"):format(tostring(Inside())),
	}
end
