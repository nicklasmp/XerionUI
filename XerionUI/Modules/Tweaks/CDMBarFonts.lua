--------------------------------------------------------------------------------
-- Cooldown Manager bar fonts
-- A font per EllesmereUI Cooldown Manager bar (Cooldowns, Utility, Buffs and
-- any custom bar), for everything EllesmereUI writes on that bar's icons:
-- cooldown numbers, keybinds, stack and charge counts. A bar without a choice
-- keeps EllesmereUI's font. Size, outline and color stay EllesmereUI's.
--
-- EllesmereUI styles every one of those texts with the shared "cdm" font key
-- through EllesmereUI.ApplyIconTextFont / ApplyModuleFont, which look the
-- function up at call time; both are wrapped. A text is placed on its bar by
-- walking up its parents to an icon frame (ns.cdmBarIcons) or a bar frame
-- (ns.cdmBarFrames). The wrappers pass everything through while idle. The
-- bars are restyled when a choice changes or the module is switched off.
-- The Cooldown Manager Stack Font module, when on, still decides stack texts.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local M = XUI:NewModule("EUICDMBarFonts", {
	name = "Cooldown Manager Bar Fonts",
	desc = "A separate font for each EllesmereUI Cooldown Manager bar.",
	category = "tweaks",
	icon = [[Interface\Icons\INV_Misc_Note_02]],
	order = 91,
	requires = "EllesmereUICooldownManager",
	defaults = {
		bars = {},
	},
})

local KEY = "cdm"
local active = false
local wrapped = false
local owner = setmetatable({}, { __mode = "k" }) -- frame -> bar key
local builtAt = -1

local function CDM()
	return XUI.EUI and XUI.EUI.Module("EllesmereUICooldownManager")
end

-- icon frames and bar frames onto their bar key; rebuilt at most once a frame
local function Rebuild(ns)
	local now = GetTime()
	if now == builtAt then return end
	builtAt = now
	wipe(owner)
	for key, frame in pairs(ns.cdmBarFrames or {}) do owner[frame] = key end
	for key, icons in pairs(ns.cdmBarIcons or {}) do
		for _, icon in ipairs(icons) do owner[icon] = key end
	end
end

local function BarOf(fs)
	local ns = CDM()
	if not ns then return nil end
	local p = fs:GetParent()
	for _ = 1, 5 do
		if not p then return nil end
		local key = owner[p]
		if key then return key end
		p = p:GetParent()
	end
	return nil
end

local function FaceFor(fs)
	local bars = M.db.bars
	if not (active and bars and next(bars)) then return nil end
	local ok, key = pcall(function()
		local k = BarOf(fs)
		if not k then
			local ns = CDM()
			if ns then Rebuild(ns) end
			k = BarOf(fs)
		end
		return k
	end)
	local choice = ok and key and bars[key]
	if type(choice) == "table" and choice.on and choice.face then
		return XUI.Media:Fetch("font", choice.face)
	end
	return nil
end

local function Wrap()
	if wrapped then return end
	local E = _G.EllesmereUI
	if type(E) ~= "table" or type(E.ApplyIconTextFont) ~= "function" then return end
	wrapped = true
	local icon, module = E.ApplyIconTextFont, E.ApplyModuleFont
	E.ApplyIconTextFont = function(fs, path, size, key, ...)
		if active and key == KEY and fs then path = FaceFor(fs) or path end
		return icon(fs, path, size, key, ...)
	end
	if type(module) == "function" then
		E.ApplyModuleFont = function(fs, path, size, key, ...)
			if active and key == KEY and fs then path = FaceFor(fs) or path end
			return module(fs, path, size, key, ...)
		end
	end
end

local function Restyle()
	local ns = CDM()
	if not ns then return end
	if type(ns.RefreshCDMIconAppearance) == "function" and type(ns.barDataByKey) == "table" then
		for barKey in pairs(ns.barDataByKey) do
			pcall(ns.RefreshCDMIconAppearance, barKey)
		end
	end
	if type(ns.BuildTrackedBuffBars) == "function" then
		pcall(ns.BuildTrackedBuffBars)
	end
end

function M:OnEnable()
	active = true
	Wrap()
	Restyle()
	-- the bars are built a moment after login
	self:After(2, Restyle)
end

function M:OnDisable()
	active = false
	Restyle()
end

function M:OnRefresh()
	if active then Restyle() end
end

-- the bars as the options list them: { key, name }, in EllesmereUI's order
function M.BarList()
	local ns = CDM()
	local list = {}
	if ns and type(ns.barDataByKey) == "table" then
		for key, bd in pairs(ns.barDataByKey) do
			list[#list + 1] = { key = key, name = type(bd) == "table" and bd.name or key }
		end
		table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
	end
	return list
end

function M:DebugInfo()
	local lines = { "wrappers installed: " .. tostring(wrapped) }
	for _, bar in ipairs(M.BarList()) do
		local c = self.db.bars[bar.key]
		lines[#lines + 1] = ("%s (%s): %s"):format(tostring(bar.name), bar.key,
			type(c) == "table" and c.on and tostring(c.face) or "EllesmereUI font")
	end
	return lines
end
