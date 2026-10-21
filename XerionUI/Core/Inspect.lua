--------------------------------------------------------------------------------
-- XerionUI - Core/Inspect.lua
-- The inspect queue the group modules share: NotifyInspect is throttled by the
-- client, so wanted units wait in a queue that a slow ticker drains one at a
-- time, never while the inspect window is open.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local STEP = 1 -- seconds between queue passes
local GAP = 2  -- minimum seconds between two NotifyInspect calls

-- XUI.NewInspectQueue(module, try) -> queue
--   try(item, queue) runs when an item reaches the front; it returns true to
--   put the item back (still waiting for an answer) and false to drop it.
--   queue:Add(item)   waits once per item, starts the ticker
--   queue:Notify(unit) asks the client to inspect (stamps the gap)
--   queue:Stop()      forgets everything (call on enable and disable)
function XUI.NewInspectQueue(M, try)
	local q, items, ticker, lastAt = {}, {}, nil, 0

	function q:Stop()
		wipe(items)
		if ticker then M:CancelTicker(ticker) ticker = nil end
	end

	local function Step()
		if #items == 0 or not M.running then return q:Stop() end
		if InspectFrame and InspectFrame:IsShown() then return end
		if GetTime() - lastAt < GAP then return end
		local item = table.remove(items, 1)
		if try(item, q) then items[#items + 1] = item end
	end

	function q:Add(item)
		for i = 1, #items do
			if items[i] == item then return end
		end
		items[#items + 1] = item
		if not ticker then ticker = M:NewTicker(STEP, Step) end
	end

	function q:Notify(unit)
		lastAt = GetTime()
		if NotifyInspect then pcall(NotifyInspect, unit) end
	end

	return q
end

--------------------------------------------------------------------------------
-- Talents. Which talents of a class a module cares about, read from the
-- inspect data of a party member (or from your own active loadout), and the
-- cooldown length those talents give.
--
--   local talents = XUI.Talents.New()
--   talents:Want("MAGE", 382424)             remember that this talent matters
--   talents:Ranks("MAGE")                     { [talentSpellID] = rank } of the inspected unit, or nil
--   talents:Ranks("MAGE", XUI.Talents.Config())  the same for your own loadout
--   XUI.Talents.Length(base, mods, ranks, spec, guess)
--       mods = { { talentID, add = -30, pct = -10, spec = 70, likely = true }, ... }
--       guess: a talent that could not be read counts as 0 (1 when `likely`)
--       instead of making the answer nil
--------------------------------------------------------------------------------
local Talents = {}
XUI.Talents = Talents

local INSPECT_CONFIG = (Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID) or -1

function Talents.Config()
	local CT = C_ClassTalents
	if not (CT and CT.GetActiveConfigID) then return nil end
	local ok, id = pcall(CT.GetActiveConfigID)
	if ok and type(id) == "number" and not XUI.IsSecret(id) then return id end
	return nil
end

local State = {}
State.__index = State

function Talents.New()
	return setmetatable({ ids = {}, all = {}, wanted = {}, misses = {}, index = {} }, State)
end

function State:Want(class, id)
	local list = self.ids[class]
	if not list then
		list = {}
		self.ids[class] = list
	end
	if self.all[id] ~= class then
		self.all[id] = class
		list[#list + 1] = id
	end
	self.wanted[id] = true
end

-- talent spell ID -> every { node, entry } that grants it in one tree
local function IndexTree(self, Tr, tree, config)
	local nodes = Tr.GetTreeNodes(tree)
	if type(nodes) ~= "table" then return nil, 0 end
	local idx, found = {}, 0
	for _, nodeID in ipairs(nodes) do
		local node = Tr.GetNodeInfo(config, nodeID)
		local entries = type(node) == "table" and node.entryIDs
		if type(entries) == "table" then
			for _, entryID in ipairs(entries) do
				local e = Tr.GetEntryInfo(config, entryID)
				local d = type(e) == "table" and e.definitionID and Tr.GetDefinitionInfo(e.definitionID)
				local spell = type(d) == "table" and d.spellID
				if spell and self.wanted[spell] then
					local spots = idx[spell]
					if not spots then
						spots = {}
						idx[spell] = spots
						found = found + 1
					end
					spots[#spots + 1] = { node = nodeID, entry = entryID }
				end
			end
		end
	end
	return idx, found
end

function State:Ranks(class, config)
	config = config or INSPECT_CONFIG
	local Tr = C_Traits
	local want = self.ids[class]
	if not (want and Tr and Tr.GetConfigInfo and Tr.GetTreeNodes and Tr.GetNodeInfo and Tr.GetEntryInfo and Tr.GetDefinitionInfo) then return nil end
	if config == INSPECT_CONFIG and Tr.HasValidInspectData and Tr.HasValidInspectData() == false then return nil end
	local info = Tr.GetConfigInfo(config)
	local trees = type(info) == "table" and info.treeIDs
	if type(trees) ~= "table" then return nil end
	local out
	for _, tree in ipairs(trees) do
		local idx = self.index[tree]
		if not idx and (self.misses[tree] or 0) < 3 then
			local found
			idx, found = IndexTree(self, Tr, tree, config)
			if idx and found > 0 then
				self.index[tree] = idx
			else
				idx = nil
				self.misses[tree] = (self.misses[tree] or 0) + 1
			end
		end
		if idx then
			for _, id in ipairs(want) do
				local spots = idx[id]
				if spots then
					local got = 0
					for _, spot in ipairs(spots) do
						local node = Tr.GetNodeInfo(config, spot.node)
						if type(node) == "table" and node.subTreeActive ~= false then
							local act, rank = node.activeEntry, node.activeRank
							if type(act) == "table" and act.entryID == spot.entry and type(rank) == "number" and rank > got then got = rank end
						end
					end
					out = out or {}
					out[id] = got
				end
			end
		end
	end
	return out
end

function Talents.Length(base, mods, ranks, spec, guess)
	local cd, mul = base, 1
	for _, mod in ipairs(mods) do
		local rank = 1
		if mod[1] then
			rank = ranks and ranks[mod[1]]
			if type(rank) ~= "number" then
				if not guess then return nil end
				rank = mod.likely and 1 or 0
			end
		end
		if mod.spec and mod.spec ~= spec then rank = 0 end
		if rank > 0 then cd, mul = cd + (mod.add or 0) * rank, mul * (1 + (mod.pct or 0) * rank / 100) end
	end
	return math.floor(math.max(5, math.min(900, cd * mul)) + 0.5)
end
