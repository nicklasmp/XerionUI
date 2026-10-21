--------------------------------------------------------------------------------
-- MDT link
-- What the modules that talk to Mythic Dungeon Tools share: finding its
-- saved settings, its main table (routes live there, in the part of MDT that
-- loads with its window), and loading that part when a module needs it.
--
--   XUI.MDT.IsLoaded()      Mythic Dungeon Tools is loaded
--   XUI.MDT.DB()            MDT's saved settings (its "global" table), or nil
--   XUI.MDT.Table()         MDT's main table once something has handed it over, or nil
--   XUI.MDT.Hook(module, fn)  have `fn(mdtTable)` called the first time MDT's table is seen
--   XUI.MDT.LoadWindow()    load "Mythic Dungeon Tools - UI" now (not in combat); true when loaded
-- MDT is a separate addon that changes between its releases, so every read
-- here is defensive and the modules say so on their pages when it fails.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local MDT = {}
XUI.MDT = MDT

MDT.CORE, MDT.UI = "MythicDungeonTools", "MythicDungeonTools_UI"

function MDT.IsLoaded() return XUI.IsAddOnLoaded(MDT.CORE) end

function MDT.API()
	local api = _G.MythicDungeonToolsAPI
	return type(api) == "table" and api or nil
end

function MDT.DB()
	local api = MDT.API()
	if api and type(api.GetDB) == "function" then
		local ok, db = pcall(api.GetDB, api)
		if ok and type(db) == "table" then return db end
	end
	local sv = _G.MythicDungeonToolsDB
	if type(sv) == "table" and type(sv.global) == "table" then return sv.global end
	return nil
end

local function IsMain(t)
	return type(t) == "table" and type(rawget(t, "dungeonEnemies")) == "table"
end

function MDT.Table()
	if MDT.T then return MDT.T end
	local g = rawget(_G, "MDT")
	if IsMain(g) then MDT.T = g end
	return MDT.T
end

-- MDT calls its own API with its main table as `self`; a hook on one of those
-- calls is the way to be handed the table.
function MDT.Hook(module, fn)
	MDT.onTable = fn
	local api = MDT.API()
	if api and type(api.IsRetail) == "function" then
		MDT.door = true
		module:SecureHook(api, "IsRetail", function(_, self)
			if MDT.T or not IsMain(self) then return end
			MDT.T = self
			if MDT.onTable then MDT.onTable(self) end
		end)
	end
	if MDT.Table() and fn then fn(MDT.T) end
end

function MDT.LoadWindow()
	if not MDT.IsLoaded() or InCombatLockdown() then return false end
	if XUI.IsAddOnLoaded(MDT.UI) then return true end
	if MDT.tried then return false end
	MDT.tried = true
	local CA = C_AddOns
	if not (CA and CA.LoadAddOn) then return false end
	local ok, loaded, reason = pcall(CA.LoadAddOn, MDT.UI)
	if not ok then
		MDT.err = "loading it failed: " .. tostring(loaded)
	elseif not loaded then
		MDT.err = "it did not load: " .. tostring(reason)
	end
	return ok and loaded and true or false
end

-- Opens MDT's window.
function MDT.Open()
	local api = MDT.API()
	if api and type(api.ShowInterface) == "function" then
		pcall(api.ShowInterface, api, true)
		return true
	end
	local slash = SlashCmdList and SlashCmdList.MYTHICDUNGEONTOOLS
	if type(slash) == "function" then
		pcall(slash, "")
		return true
	end
	return false
end
