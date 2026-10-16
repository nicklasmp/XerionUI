--------------------------------------------------------------------------------
-- XerionUI_Options - Classes.lua
-- The Class section of the sidebar: every class is always listed, whatever you
-- play, with its modules below it. A class has a page of its own with one tab
-- per specialization (plus "All") that lists the modules of that spec; a
-- module without a spec shows under every tab. Modules that belong to no class
-- in particular sit under "All classes".
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local ICON = [[Interface\Icons\ClassIcon_]]

-- token, name, icon file, { specID, name }...
O.CLASSES = {
	{ token = "DEATHKNIGHT", name = "Death Knight", icon = ICON .. "DeathKnight", specs = { { 250, "Blood" }, { 251, "Frost" }, { 252, "Unholy" } } },
	{ token = "DRUID", name = "Druid", icon = ICON .. "Druid", specs = { { 102, "Balance" }, { 103, "Feral" }, { 104, "Guardian" }, { 105, "Restoration" } } },
	{ token = "EVOKER", name = "Evoker", icon = ICON .. "Evoker", specs = { { 1467, "Devastation" }, { 1468, "Preservation" }, { 1473, "Augmentation" } } },
	{ token = "HUNTER", name = "Hunter", icon = ICON .. "Hunter", specs = { { 253, "Beast Mastery" }, { 254, "Marksmanship" }, { 255, "Survival" } } },
	{ token = "PRIEST", name = "Priest", icon = ICON .. "Priest", specs = { { 256, "Discipline" }, { 257, "Holy" }, { 258, "Shadow" } } },
	{ token = "ROGUE", name = "Rogue", icon = ICON .. "Rogue", specs = { { 259, "Assassination" }, { 260, "Outlaw" }, { 261, "Subtlety" } } },
	{ token = "WARLOCK", name = "Warlock", icon = ICON .. "Warlock", specs = { { 265, "Affliction" }, { 266, "Demonology" }, { 267, "Destruction" } } },
}
O.ANY_CLASS = { token = "ANY", name = "All classes", icon = [[Interface\Icons\INV_Misc_Book_09]], specs = {} }

O.classByToken = { ANY = O.ANY_CLASS }
for _, c in ipairs(O.CLASSES) do O.classByToken[c.token] = c end

local function Contains(list, v)
	for _, x in ipairs(list) do if x == v then return true end end
	return false
end

-- The "class" modules of a class (or, for ANY, those tied to no class).
function O:ClassModules(token)
	local out = {}
	for _, m in ipairs(XUI:SortedModules("class")) do
		if token == "ANY" then
			if not m.classes then out[#out + 1] = m end
		elseif m.classes and Contains(m.classes, token) then
			out[#out + 1] = m
		end
	end
	return out
end

local function ShownUnder(m, tab)
	if tab == "ALL" or not m.specs then return true end
	return Contains(m.specs, tab)
end

-- The page of one class: tabs, then a card per module of the chosen spec.
function O:ClassPageSpec(token)
	local class = O.classByToken[token]
	if not class then return nil end
	local state = { tab = "ALL" }
	local mods = O:ClassModules(token)

	local tabs = { { value = "ALL", text = "All" } }
	for _, s in ipairs(class.specs) do tabs[#tabs + 1] = { value = s[1], text = s[2] } end

	local function Count()
		local n = 0
		for _, m in ipairs(mods) do if ShownUnder(m, state.tab) then n = n + 1 end end
		return n
	end

	return {
		ctx = O:NewContext(function() return state end, nil, { classPage = token }),
		build = function(ctx)
			local cards = {}
			if #class.specs > 0 then
				cards[#cards + 1] = O.Card(nil, {
					{ type = "tabs", values = tabs,
						get = function() return state.tab end, set = function(_, v) state.tab = v end },
				})
			end
			cards[#cards + 1] = O.Card(nil, {
				{ type = "description", text = "Nothing for this specialization yet." },
			}, { hidden = function() return Count() > 0 end })
			for _, m in ipairs(mods) do
				local items = {
					{ type = "description", text = function()
						local text = m.desc or ""
						if m.classes and not m:IsAvailable() then
							text = text .. "\n|cff888888Runs on " .. class.name .. " only. You can set it up from here.|r"
						end
						return text
					end },
					{ type = "toggle", label = "Enabled",
						get = function() return m.db.enabled end,
						set = function(_, on) m:SetEnabled(on) O:RefreshSidebar() O:RefreshPageHead() end },
					{ type = "button", text = "Open settings", onClick = function() O:Open(m.key) end },
				}
				cards[#cards + 1] = O.Card(m.name, items, { hidden = function() return not ShownUnder(m, state.tab) end })
			end
			return cards
		end,
	}
end
