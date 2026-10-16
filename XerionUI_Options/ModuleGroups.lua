--------------------------------------------------------------------------------
-- XerionUI_Options - ModuleGroups.lua
-- Modules that belong together share one sidebar entry and one page. Every
-- member keeps its own module, switch and saved settings; the group only
-- decides how they are listed. The page shows one section per member: its
-- switch first, then its own cards.
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

-- members: { module key, section label }
O.MODULE_GROUPS = {
	{
		key = "grp:cdm", name = "Cooldown Manager", category = "tweaks",
		desc = "Fonts, stack counts and glows for the EllesmereUI Cooldown Manager bars.",
		members = { { "EUICDMBarFonts", "Bar fonts" }, { "EUICDMStackFont", "Stack font" }, { "EUICDMBarGlows", "Bar glows" } },
	},
	{
		key = "grp:cast", name = "Cast Bars", category = "tweaks",
		desc = "The focus cast bar and the bars that show who is being targeted by a cast.",
		members = { { "EUIFocusCastbar", "Focus cast bar" }, { "EUITargetedSpellBars", "Targeted spell bars" } },
	},
	{
		key = "grp:tank", name = "Tank", category = "group",
		desc = "Co-tank tracking and marking the tank of your group.",
		members = { { "CoTank", "Co-Tank" }, { "AutoMarkTank", "Auto mark tank" } },
	},
	{
		key = "grp:party", name = "Party Tracking", category = "group",
		desc = "Interrupts, cooldowns and externals of your party members.",
		members = { { "Interrupts", "Interrupts" }, { "PartyCDs", "Party cooldowns" }, { "Externals", "Externals" } },
	},
	{
		key = "grp:utility", name = "Group Utility", category = "group",
		desc = "Small helpers for dungeons and groups.",
		members = {
			{ "Shroud", "Shroud / Mass Invis" }, { "InstanceKeys", "Who has the key" },
			{ "BonusRollConfirm", "Bonus roll confirm" }, { "AutoGossip", "Auto NPC dialog" },
		},
	},
	{
		key = "grp:reminders", name = "Reminders", category = "group",
		desc = "Warnings and prompts that tell you when something needs your attention.",
		members = { { "AggroCheck", "Aggro check" }, { "Bloodlust", "Bloodlust ready" }, { "MeterReset", "Meter reset" } },
	},
}

O.groupByKey = {}   -- [group key] = entry
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
	if #members == 0 then return nil end
	local entry = {
		isGroup = true, key = def.key, name = def.name, desc = def.desc,
		category = def.category, dungeon = def.dungeon, untested = false,
		members = members, labels = labels,
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

for _, def in ipairs(O.MODULE_GROUPS) do
	local entry = MakeEntry(def)
	if entry then
		O.groupByKey[entry.key] = entry
		for _, m in ipairs(entry.members) do O.groupOf[m.key] = entry end
	end
end

-- What a category lists in the sidebar: its modules, with the members of a
-- group replaced by the group itself.
function O.CategoryEntries(category)
	local out, added = {}, {}
	for _, m in ipairs(XUI:SortedModules(category)) do
		local g = O.groupOf[m.key]
		if not g then
			out[#out + 1] = m
		elseif not added[g] and g.category == category then
			added[g] = true
			out[#out + 1] = g
		end
	end
	return out
end

-- The texture shown for a group: its first member's.
function O.GroupIcon(g)
	return XUI.ModuleIcon(g.members[1])
end

--------------------------------------------------------------------------------
-- The page of a group
--------------------------------------------------------------------------------
local function HasIssues(m) return #XUI.Health.Issues(m) > 0 end

function O:GroupPageSpec(key)
	local g = O.groupByKey[key]
	if not g then return nil end
	return {
		ctx = O:NewContext(function() return {} end, nil, { group = g }),
		build = function()
			local cards = {}
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
					{ type = "button", text = "Preview",
						onClick = function() m:SetPreview(not m.preview) end },
				}
				if m.Test then
					items[#items + 1] = { type = "button", text = "Test",
						onClick = function() XUI.SafeCallFor(m, m.Test, m) end }
				end
				cards[#cards + 1] = O.Card(g.labels[m.key], items, { ctx = mctx })
				local build = O.moduleBuilders[m.key]
				for _, card in ipairs(build and build(mctx, m, O.Groups) or {}) do
					card.ctx = mctx
					cards[#cards + 1] = card
				end
			end
			return cards
		end,
	}
end
