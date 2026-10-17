--------------------------------------------------------------------------------
-- XerionUI_Options - ModuleGroups.lua
-- Modules that belong together share one sidebar entry and one page. Every
-- member keeps its own module, switch and saved settings; the group only
-- decides how they are listed. The page shows one section per member: its
-- switch first, then its own cards. Classes and specializations work the same
-- way: "class:TOKEN" and "spec:TOKEN:ID" are entries with their modules as
-- members.
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

-- members: { module key, section label }
-- A group page shows one member at a time, picked with tabs, instead of every
-- member's cards in one long list (tabs = false keeps the list).
O.MODULE_GROUPS = {
	{
		key = "grp:cdm", name = "Cooldown Manager", category = "tweaks",
		desc = "Fonts and stack counts for the EllesmereUI Cooldown Manager bars.",
		members = { { "EUICDMBarFonts", "Bar fonts" }, { "EUICDMStackFont", "Stack font" } },
	},
	{
		key = "grp:cast", name = "Cast Bars", category = "tweaks",
		desc = "The focus cast bar and the bars that show who is being targeted by a cast.",
		members = { { "EUIFocusCastbar", "Focus cast bar" }, { "EUITargetedSpellBars", "Targeted spell bars" } },
	},
	{
		key = "grp:party", name = "Party Tracking", category = "group",
		desc = "Interrupts and cooldowns of your party members.",
		members = { { "Interrupts", "Interrupts" }, { "PartyCDs", "Party cooldowns" } },
	},
	{
		key = "grp:externals", name = "Externals", category = "group",
		desc = "Externals your party members use on each other.",
		members = { { "Externals", "Externals" } },
	},
	{
		key = "grp:reminders", name = "Reminders", category = "combat",
		desc = "Warnings and prompts that tell you when something needs your attention.",
		members = {
			{ "MeleeIndicator", "Melee indicator" }, { "AggroCheck", "Aggro check" },
			{ "Bloodlust", "Bloodlust ready" },
		},
	},
	{
		key = "grp:meter", name = "Damager Meter", category = "group",
		desc = "Prompts and helpers for your damage meter.",
		members = { { "MeterReset", "Meter reset" } },
	},
}

O.groupByKey = {}   -- [group key] = entry
O.groupPages = {}   -- [group key] = function(entry) -> page spec, for a page of its own design
O.groupOf = {}      -- [member module key] = entry

-- The entry the sidebar lists for a group. It looks like a module to the
-- sidebar: it is "on" when any member is.
local function MakeEntry(def)
	local members, labels = {}, {}
	for _, pair in ipairs(def.members) do
		local m = XUI:GetModule(pair[1])
		if m then
			members[#members + 1] = m
			labels[m.key] = pair[2]
		end
	end
	if #members == 0 and not def.allowEmpty then return nil end
	local entry = {
		isGroup = true, key = def.key, name = def.name, desc = def.desc,
		category = def.category, dungeon = def.dungeon, untested = false, tabs = def.tabs ~= false,
		members = members, labels = labels, texture = def.texture, empty = def.empty,
	}
	entry.db = setmetatable({}, { __index = function(_, k)
		if k == "enabled" then
			for _, m in ipairs(members) do if m.db.enabled then return true end end
			return false
		end
	end })
	function entry:IsAvailable()
		for _, m in ipairs(members) do if m:IsAvailable() then return true end end
		return false
	end
	return entry
end

local function Register(def, ownsMembers)
	local entry = MakeEntry(def)
	if entry then
		O.groupByKey[entry.key] = entry
		if ownsMembers then
			for _, m in ipairs(entry.members) do
				-- a module made for several specializations opens the first one
				if not O.groupOf[m.key] then O.groupOf[m.key] = entry end
			end
		end
	end
	return entry
end

for _, def in ipairs(O.MODULE_GROUPS) do Register(def, true) end

local function Members(modules)
	local out = {}
	for _, m in ipairs(modules) do out[#out + 1] = { m.key, m.name } end
	return out
end

-- Classes and their specializations. O.classEntries lists, per class, the class
-- entry and the entries of the specializations that have modules.
O.classEntries = {} -- { { class, entry, specs = { { id, name, entry }... } }... }
for _, c in ipairs(O.CLASSES) do
	local specs = {}
	for _, s in ipairs(c.specs) do
		local entry = Register({
			key = ("spec:%s:%d"):format(c.token, s[1]), name = s[2], category = "class", texture = c.icon,
			desc = ("%s modules for %s."):format(s[2], c.name), members = Members(O:SpecModules(c.token, s[1])),
		}, true)
		if entry then specs[#specs + 1] = { id = s[1], name = s[2], entry = entry } end
	end
	local classWide = Register({
		key = "class:" .. c.token, name = c.name, category = "class", texture = c.icon, allowEmpty = true,
		desc = "Modules that work for every " .. c.name .. " specialization.",
		empty = "Nothing here works for every specialization yet. Pick a specialization in the sidebar.",
		members = Members(O:ClassWideModules(c.token)),
	}, true)
	if classWide and (#classWide.members > 0 or #specs > 0) then
		O.classEntries[#O.classEntries + 1] = { class = c, entry = classWide, specs = specs }
	end
end

-- What a category lists in the sidebar: its modules, with the members of a
-- group replaced by the group itself.
function O.CategoryEntries(category)
	local out = {}
	for _, m in ipairs(XUI:SortedModules(category)) do
		-- Auto NPC Dialog is listed under each dungeon (see O:DialogEntry)
		if not O.groupOf[m.key] and m.key ~= "AutoGossip" then out[#out + 1] = m end
	end
	-- a group sits in its own category, whatever the categories of its members
	for _, def in ipairs(O.MODULE_GROUPS) do
		local g = O.groupByKey[def.key]
		if g and g.category == category then out[#out + 1] = g end
	end
	return out
end

-- Auto NPC Dialog is split per dungeon: every dungeon that has a seen dialog
-- gets an "NPC dialogs" entry under it in the sidebar. The entry is a group of
-- the one module; its page (O.DialogPage, Modules/Group.lua) shows that
-- dungeon's dialogs.
O.DIALOG_NO_ZONE = "Other"

function O.DialogZones()
	local m = XUI:GetModule("AutoGossip")
	local out, have = {}, {}
	if not m then return out end
	for _, e in ipairs(m:Catalogue()) do
		-- dialogs not seen in game yet (built-ins, typed IDs) have no dungeon: "Other"
		local zone = e.zone or O.DIALOG_NO_ZONE
		if not have[zone] then
			have[zone] = true
			out[#out + 1] = zone
		end
	end
	return out
end

function O:DialogEntry(zone)
	local key = "dlg:" .. zone
	local entry = O.groupByKey[key]
	if entry then return entry end
	entry = Register({
		key = key, name = "NPC dialogs", category = "dungeon", dungeon = zone,
		desc = "Dialogs to skip in " .. zone .. ".", members = { { "AutoGossip", "Auto NPC dialog" } },
	}, false)
	if entry then
		entry.zone = zone
		O.groupPages[key] = function(g) return O.DialogPage(g) end
	end
	return entry
end

-- The texture shown for a group: its first member's.
function O.GroupIcon(g)
	return g.texture or XUI.ModuleIcon(g.members[1])
end

--------------------------------------------------------------------------------
-- The page of a group
--------------------------------------------------------------------------------
local function HasIssues(m) return #XUI.Health.Issues(m) > 0 end

function O:GroupPageSpec(key)
	local g = O.groupByKey[key]
	if not g then return nil end
	if O.groupPages[key] then
		local spec = O.groupPages[key](g)
		spec.tabbed = true
		return spec
	end
	local state = { member = g.members[1] and g.members[1].key }
	return {
		tabbed = g.tabs and #g.members > 1,
		ctx = O:NewContext(function() return state end, nil, { group = g }),
		build = function()
			local cards = {}
			if g.tabs and #g.members > 1 then
				local tabs = {}
				for _, m in ipairs(g.members) do tabs[#tabs + 1] = { value = m.key, text = g.labels[m.key] } end
				cards[#cards + 1] = O.Card(nil, {
					{ type = "tabs", values = tabs,
						status = function(key)
							local m = XUI:GetModule(key)
							return m and m.db.enabled and true or false
						end,
						get = function() return state.member end, set = function(_, v) state.member = v end },
				})
			end
			if #g.members == 0 then
				cards[#cards + 1] = O.Card(nil, { { type = "description", text = g.empty or "Nothing here yet." } })
			end
			for _, m in ipairs(g.members) do
				local mctx = O.ModuleContext(m)
				local items = {
					{ type = "description", text = m.desc or "" },
					{ type = "toggle", label = "Enabled",
						get = function() return m.db.enabled end,
						set = function(_, on)
							m:SetEnabled(on)
							O:RefreshSidebar()
							O:RefreshPageHead()
						end },
					{ type = "description", color = "danger", hidden = function() return not HasIssues(m) end,
						text = function()
							local lines = {}
							for _, issue in ipairs(XUI.Health.Issues(m)) do lines[#lines + 1] = "- " .. issue end
							return table.concat(lines, "\n")
						end },
				}
					if not m.noPreview then
						items[#items + 1] = { type = "button", text = "Preview",
							onClick = function() m:SetPreview(not m.preview) end }
					end
				if m.Test then
					items[#items + 1] = { type = "button", text = "Test",
						onClick = function() XUI.SafeCallFor(m, m.Test, m) end }
				end
				local function Tabbed(card)
					if g.tabs and #g.members > 1 then
						local own = card.hidden
						card.hidden = function(ctx)
							if state.member ~= m.key then return true end
							if type(own) == "function" then return own(ctx) and true or false end
							return own and true or false
						end
					end
					return card
				end
				cards[#cards + 1] = Tabbed(O.Card(g.labels[m.key], items, { ctx = mctx }))
				local build = O.moduleBuilders[m.key]
				for _, card in ipairs(build and build(mctx, m, O.Groups) or {}) do
					card.ctx = mctx
					cards[#cards + 1] = Tabbed(card)
				end
			end
			return cards
		end,
	}
end
