--------------------------------------------------------------------------------
-- Auto NPC Dialog
-- Picks chosen gossip options for you inside instances (skip a dungeon's
-- talk-to-the-NPC step) and answers the "are you sure?" box for the ones you
-- list.
--
-- Every gossip option seen inside an instance is remembered account-wide
-- (XUI.DB.global.gossipSeen) with its dungeon, NPC and text, so the options
-- page can list them by dungeon with a switch each.
--
-- Rewritten from KiraUI-Plugin's Auto Gossip (personal use).
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local IsSecret = XUI.IsSecret
local COOLDOWN = 5

-- Dialogs shipped with the addon: dungeon steps worth skipping every time.
-- Used while "Use the built-in dungeon list" is on (the default); each can be
-- switched off on its own. confirm = also answer "are you sure?".
-- Dungeon, NPC and text come from what the game shows once you talk to them.
local BUILTIN = {
	{ id = 131567 },
	{ id = 131502 },
	{ id = 48126, confirm = true }, -- Sethraliss
}
local BUILTIN_BY_ID = {}
for _, d in ipairs(BUILTIN) do BUILTIN_BY_ID[d.id] = d end

local KINDS = { party = "Dungeon", raid = "Raid", scenario = "Scenario", pvp = "Battleground", arena = "Arena" }

local M = XUI:NewModule("AutoGossip", {
	name = "Auto NPC Dialog",
	desc = "Picks chosen gossip options for you inside dungeons.",
	category = "group",
	icon = [[Interface\Icons\INV_Misc_Note_01]],
	order = 62,
	defaults = {
		useBuiltin = true,
		options = {},
		confirm = {},
		builtinOff = {},       -- [id] = true: a built-in dialog switched off
		builtinNoConfirm = {}, -- [id] = true: a built-in's "are you sure?" left alone
		instanceOnly = true,
		announce = true,
	},
})

local lastPick = {}

-- strips colour codes and textures from a game string
local function Clean(s)
	if type(s) ~= "string" or IsSecret(s) then return nil end
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	return s ~= "" and s or nil
end

-- The shipped IDs sat in the saved lists before the built-in list existed;
-- take them out once so the toggle really switches them off.
local function MigrateBuiltin(db)
	if db.builtinMigrated then return end
	db.builtinMigrated = true
	local builtinConfirm = {}
	for _, d in ipairs(BUILTIN) do
		if d.confirm then builtinConfirm[d.id] = true end
	end
	local function strip(list, drop)
		local out = {}
		for _, id in ipairs(list or {}) do
			if not drop[tonumber(id)] then out[#out + 1] = id end
		end
		return out
	end
	db.options = strip(db.options, BUILTIN_BY_ID)
	db.confirm = strip(db.confirm, builtinConfirm)
end

--------------------------------------------------------------------------------
-- What is picked
--------------------------------------------------------------------------------
local function Has(list, id)
	for _, v in ipairs(list or {}) do
		if tonumber(v) == id then return true end
	end
	return false
end

local function Put(list, id, on)
	for i = #list, 1, -1 do
		if tonumber(list[i]) == id then table.remove(list, i) end
	end
	if on then list[#list + 1] = id end
end

local function BuiltinOn(db, id)
	return BUILTIN_BY_ID[id] and db.useBuiltin and not (db.builtinOff and db.builtinOff[id])
end

function M:IsBuiltin(id) return BUILTIN_BY_ID[id] ~= nil end

function M:IsPicked(id)
	return (BuiltinOn(self.db, id) or Has(self.db.options, id)) and true or false
end

function M:IsConfirm(id)
	local db = self.db
	if Has(db.confirm, id) then return true end
	local b = BUILTIN_BY_ID[id]
	return (b and b.confirm and not (db.builtinNoConfirm and db.builtinNoConfirm[id])) and true or false
end

function M:SetPicked(id, on)
	local db = self.db
	db.options = db.options or {}
	db.builtinOff = db.builtinOff or {}
	if BUILTIN_BY_ID[id] then
		db.builtinOff[id] = (not on) or nil
		-- with the built-in list off, a built-in switched on rides the own list
		Put(db.options, id, on and not db.useBuiltin)
	else
		Put(db.options, id, on)
	end
end

function M:SetConfirm(id, on)
	local db = self.db
	db.confirm = db.confirm or {}
	db.builtinNoConfirm = db.builtinNoConfirm or {}
	local b = BUILTIN_BY_ID[id]
	if b and b.confirm then
		db.builtinNoConfirm[id] = (not on) or nil
		Put(db.confirm, id, false)
	else
		Put(db.confirm, id, on)
	end
end

-- built-in and typed IDs together, as the lists the rest of the module reads
function M:Wanted()
	local options, confirm = {}, {}
	for _, id in ipairs(self.db.options or {}) do options[#options + 1] = id end
	for _, id in ipairs(self.db.confirm or {}) do confirm[#confirm + 1] = id end
	for _, d in ipairs(BUILTIN) do
		if BuiltinOn(self.db, d.id) then options[#options + 1] = d.id end
		if self:IsConfirm(d.id) and not Has(confirm, d.id) then confirm[#confirm + 1] = d.id end
	end
	return options, confirm
end

--------------------------------------------------------------------------------
-- What has been seen
--------------------------------------------------------------------------------
local function Seen()
	local g = XUI.DB.global
	g.gossipSeen = type(g.gossipSeen) == "table" and g.gossipSeen or {}
	return g.gossipSeen
end

-- nil outside instances; else the instance's name, kind and ID
local function InstanceInfo()
	local ok, name, kind, _, difficulty, _, _, _, instanceID = pcall(GetInstanceInfo)
	if not ok or IsSecret(kind) or not kind or kind == "none" then return end
	return {
		zone = Clean(name),
		kind = KINDS[kind] or "Instance",
		difficulty = Clean(difficulty),
		zoneID = (type(instanceID) == "number" and not IsSecret(instanceID)) and instanceID or nil,
	}
end

local function NPCInfo()
	local name, npcID
	pcall(function()
		name = Clean(UnitName("npc"))
		local guid = UnitGUID("npc")
		if type(guid) == "string" and not IsSecret(guid) then
			npcID = tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
		end
	end)
	return name, npcID
end

-- Stores every option of the open gossip window, when inside an instance.
function M:Record(opts)
	local where = InstanceInfo()
	if not where or type(opts) ~= "table" then return end
	local npc, npcID = NPCInfo()
	local seen, now, changed = Seen(), time(), false
	pcall(function()
		for _, o in ipairs(opts) do
			local id, text = o.gossipOptionID, Clean(o.name)
			if type(id) == "number" and not IsSecret(id) and text then
				local e = seen[id] or {}
				e.text, e.npc, e.npcID = text, npc or e.npc, npcID or e.npcID
				e.zone, e.zoneID, e.kind = where.zone or e.zone, where.zoneID or e.zoneID, where.kind
				e.difficulty, e.time = where.difficulty, now
				if not seen[id] then changed = true end
				seen[id] = e
			end
		end
	end)
	XUI:Fire("GossipSeen", changed)
end

-- The "are you sure?" text says what the option costs or starts.
function M:RecordConfirm(id, text)
	local e = Seen()[id]
	text = Clean(text)
	if e and text then
		e.confirmText = text
		XUI:Fire("GossipSeen", false)
	end
end

function M:Forget(id)
	Seen()[id] = nil
	XUI:Fire("GossipSeen", true)
end

-- Removes every seen dialog that is not picked.
function M:ForgetUnpicked()
	local seen = Seen()
	for id in pairs(seen) do
		if not self:IsPicked(id) then seen[id] = nil end
	end
	XUI:Fire("GossipSeen", true)
end

-- Every dialog the options page lists: seen ones, built-ins and typed IDs,
-- sorted by dungeon, then NPC, then text.
--   { id, text, npc, npcID, zone, zoneID, kind, difficulty, confirmText,
--     builtin, picked, confirm }
function M:Catalogue()
	local seen, out, have = Seen(), {}, {}
	local legacyNames = self.db.names or {}
	local function add(id)
		id = tonumber(id)
		if not id or have[id] then return end
		have[id] = true
		local e, b = seen[id] or {}, BUILTIN_BY_ID[id]
		out[#out + 1] = {
			id = id,
			text = e.text or (b and b.text) or legacyNames[id],
			npc = e.npc or (b and b.npc),
			npcID = e.npcID,
			zone = e.zone or (b and b.zone),
			zoneID = e.zoneID,
			kind = e.kind,
			difficulty = e.difficulty,
			confirmText = e.confirmText,
			builtin = b ~= nil,
			picked = self:IsPicked(id),
			confirm = self:IsConfirm(id),
		}
	end
	for id in pairs(seen) do add(id) end
	for _, d in ipairs(BUILTIN) do add(d.id) end
	for _, id in ipairs(self.db.options or {}) do add(id) end
	for _, id in ipairs(self.db.confirm or {}) do add(id) end
	table.sort(out, function(a, b)
		local za, zb = a.zone or "\255", b.zone or "\255"
		if za ~= zb then return za < zb end
		local na, nb = a.npc or "\255", b.npc or "\255"
		if na ~= nb then return na < nb end
		return a.id < b.id
	end)
	return out
end

--------------------------------------------------------------------------------
-- Picking
--------------------------------------------------------------------------------
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
	name = Clean(name) or ("option " .. id)
	local npc = NPCInfo()
	if npc then name = npc .. ": " .. name end
	Say((ok and "selected " or "could not select ") .. name .. (confirmed and ok and " (confirmed)" or ""))
	return ok
end

function M:OnGossipShow()
	local CG = C_GossipInfo
	if not (CG and CG.GetOptions) then return end
	local ok, opts = pcall(CG.GetOptions)
	if not ok or type(opts) ~= "table" then return end
	self:Record(opts)
	self:TrySelect(opts)
end

function M:TrySelect(opts)
	if not Inside() then return end
	local options, confirmList = self:Wanted()
	local wanted = IDSet(options)
	if not next(wanted) then return end
	local CG = C_GossipInfo
	if not (CG and CG.SelectOption) then return end
	if not opts then
		local ok, o = pcall(CG.GetOptions)
		if not ok or type(o) ~= "table" then return end
		opts = o
	end
	local confirm = IDSet(confirmList)
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
function M:OnConfirmShown(optionID, text)
	if IsSecret(optionID) then return end
	local id = tonumber(optionID)
	if not id then return end
	self:RecordConfirm(id, text)
	if not Inside() or not IDSet(select(2, self:Wanted()))[id] then return end
	local CG = C_GossipInfo
	if not (CG and CG.SelectOption) then return end
	local ok = pcall(CG.SelectOption, id, "", true)
	if ok and StaticPopup_Hide then pcall(StaticPopup_Hide, "GOSSIP_CONFIRM") end
	Say((ok and "confirmed option " or "could not confirm option ") .. id)
end

function M:OnEnable()
	MigrateBuiltin(self.db)
	self:RegisterEvent("GOSSIP_SHOW", function(m) m:After(0, m.OnGossipShow) end)
	if type(GossipConfirmDialog_Show) == "function" then
		self:SecureHook("GossipConfirmDialog_Show", function(m, optionID, text)
			m:After(0, function() m:OnConfirmShown(optionID, text) end)
		end)
	else
		self:RegisterEvent("GOSSIP_CONFIRM", function(m, _, optionID, text)
			m:After(0, function() m:OnConfirmShown(optionID, text) end)
		end)
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
	self:Record(opts)
	for _, o in ipairs(opts) do
		local name = Clean(o.name) or "?"
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
	local n = 0
	for _ in pairs(Seen()) do n = n + 1 end
	return {
		("options: %s"):format(M.ListText(self.db.options)),
		("confirm: %s"):format(M.ListText(self.db.confirm)),
		("dialogs seen: %d"):format(n),
		("inside an instance: %s"):format(tostring(Inside())),
	}
end
