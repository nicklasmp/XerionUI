--------------------------------------------------------------------------------
-- XerionUI_Options - Pages/Changelog.lua
-- Patch notes: the latest versions, newest first (data from ChangelogData.lua).
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local PAGE_SIZE = 5
local scratch = { shown = PAGE_SIZE }

O:RegisterSystemPage({
	key = "changelog",
	title = "Patch notes",
	hidden = true, -- no sidebar entry: opened from the version number in the window header
	icon = "layers",
	desc = "What changed in the latest versions.",
	root = function() return scratch end,
	build = function()
		local log = O.CHANGELOG or {}
		local cards = {}
		for i = 1, math.min(scratch.shown, #log) do
			local e = log[i]
			local title = e.version .. "   |cff808080" .. e.date .. "|r"
			if e.version == XUI.version then title = title .. "   |cff66cc66current|r" end
			local lines = {}
			for _, n in ipairs(e.notes) do lines[#lines + 1] = "- " .. n end
			cards[#cards + 1] = O.Card(title, {
				{ type = "description", size = O.SIZE.text, color = "label", text = table.concat(lines, "\n") },
			})
		end
		if #log == 0 then
			cards[1] = O.Card("Patch notes", { { type = "description", text = "No patch notes are bundled with this build." } })
		elseif scratch.shown < #log then
			cards[#cards + 1] = O.Card("Older versions", {
				{
					type = "button", text = "Show " .. math.min(PAGE_SIZE, #log - scratch.shown) .. " older versions",
					onClick = function()
						scratch.shown = scratch.shown + PAGE_SIZE
						O:RebuildAll()
					end,
				},
			})
		end
		return cards
	end,
})
