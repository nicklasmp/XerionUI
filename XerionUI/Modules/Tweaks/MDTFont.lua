--------------------------------------------------------------------------------
-- MDT font
-- Replaces the interface font of Mythic Dungeon Tools (Archivo Narrow Bold) with
-- one from SharedMedia.
--
-- MDT's window gets every piece of text from named font objects, one per role
-- and variant: MDTFont_body, MDTFont_small, MDTFont_title, MDTFont_heading,
-- MDTFont_number, MDTFont_display, MDTFont_bodyCompact, MDTFont_smallCompact and
-- MDTFont_titleCompact, each with an "_outline" twin. They are created when
-- MDT's window part ("MythicDungeonTools_UI", load on demand) loads, so they
-- are changed in place then: only the file is swapped, MDT keeps the size and
-- outline of every role. The fonts MDT keeps for Cyrillic, Korean and Chinese
-- text are left alone. The enemy names drawn on the map are not font objects,
-- so they keep MDT's font.
--
-- Switching the module off puts each object back to the file it had.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local M = XUI:NewModule("MDTFont", {
	name = "MDT Font",
	desc = "Use another font for the text in Mythic Dungeon Tools' window.",
	category = "tweaks",
	icon = [[Interface\Icons\INV_Misc_Map02]],
	order = 100,
	requires = "MythicDungeonTools",
	defaults = {
		face = "GothamNarrowBlack",
	},
})

local UI_ADDON = "MythicDungeonTools_UI"
local ROLES = { "body", "small", "title", "heading", "number", "display", "bodyCompact", "smallCompact", "titleCompact" }
local ARCHIVO = "archivonarrow"

local active = false
local originals = {}   -- name -> { path, height, flags } as MDT made it
local changed = 0

local function Each(fn)
	for i = 1, #ROLES do
		local name = "MDTFont_" .. ROLES[i]
		fn(name, _G[name])
		fn(name .. "_outline", _G[name .. "_outline"])
	end
end

local function Swap(name, font, path)
	if type(font) ~= "table" or type(font.GetFont) ~= "function" then return end
	local orig = originals[name]
	if not orig then
		local ok, p, h, f = pcall(font.GetFont, font)
		if not (ok and type(p) == "string") then return end
		-- only MDT's own roman face is ours to change; a client alphabet stays
		if not p:lower():find(ARCHIVO, 1, true) then return end
		orig = { p, h, f }
		originals[name] = orig
	end
	local ok = pcall(font.SetFont, font, path or orig[1], orig[2], orig[3])
	if ok and path then changed = changed + 1 end
end

local function Apply()
	changed = 0
	local path = active and XUI.Media:Fetch("font", M.db.face) or nil
	Each(function(name, font) Swap(name, font, path) end)
end

function M:OnEnable()
	active = true
	Apply()
	-- the window part loads the first time MDT is opened
	XUI.OnAddOnLoaded(UI_ADDON, function() if active then Apply() end end)
end

function M:OnDisable()
	active = false
	Apply()
end

function M:OnRefresh()
	if active then Apply() end
end

function M:DebugInfo()
	local n = 0
	for _ in pairs(originals) do n = n + 1 end
	return {
		"MDT window part loaded: " .. tostring(XUI.IsAddOnLoaded(UI_ADDON)),
		"MDT font objects found: " .. n,
		"font objects changed: " .. changed,
		"font: " .. tostring(XUI.Media:Fetch("font", self.db.face)),
	}
end
