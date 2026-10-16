--------------------------------------------------------------------------------
-- XerionUI_Options - Classes.lua
-- The Classes section of the sidebar: Classes > class > specialization. A
-- class page lists the modules that work for every specialization of that
-- class, a specialization page the modules made for it (ModuleGroups.lua builds
-- both from the modules' `classes` and `specs`). Only the specializations
-- XerionUI has modules for are listed here.
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local ICON = [[Interface\Icons\ClassIcon_]]

-- token, name, icon file, { specID, name }...
O.CLASSES = {
	{ token = "DEATHKNIGHT", name = "Death Knight", icon = ICON .. "DeathKnight", specs = { { 250, "Blood" } } },
	{ token = "DRUID", name = "Druid", icon = ICON .. "Druid", specs = { { 104, "Guardian" } } },
}

local function Contains(list, v)
	for _, x in ipairs(list) do if x == v then return true end end
	return false
end

-- The "class" modules of a class.
function O:ClassModules(token)
	local out = {}
	for _, m in ipairs(XUI:SortedModules("class")) do
		if m.classes and Contains(m.classes, token) then out[#out + 1] = m end
	end
	return out
end

-- The modules of a class that are made for one specialization.
function O:SpecModules(token, specID)
	local out = {}
	for _, m in ipairs(O:ClassModules(token)) do
		if m.specs and Contains(m.specs, specID) then out[#out + 1] = m end
	end
	return out
end

-- The modules of a class that work for every specialization.
function O:ClassWideModules(token)
	local out = {}
	for _, m in ipairs(O:ClassModules(token)) do
		if not m.specs then out[#out + 1] = m end
	end
	return out
end
