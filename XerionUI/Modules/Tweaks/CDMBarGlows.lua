--------------------------------------------------------------------------------
-- Cooldown Manager bar glows
-- A glow type per EllesmereUI Cooldown Manager bar: Pixel, Pulse, Autocast
-- shine, Action button or Proc, with its own color, speed and size, drawn by
-- the shared style engine. A bar without a choice keeps EllesmereUI's glow.
--
-- EllesmereUI lights every icon glow (active buff, cooldown ready, procs,
-- pandemic) through ns.StartNativeGlow(overlay, style, r, g, b, opts) and ends
-- it with ns.StopNativeGlow(overlay); most callers look the function up on the
-- namespace at call time, so both are wrapped. The overlay's parent is the icon.
-- On a bar with a choice, EllesmereUI's glow is ended and ours is drawn on the
-- icon instead; the overlay is still marked lit so EllesmereUI's own integrity
-- passes leave it alone. Everything else passes straight through.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local M = XUI:NewModule("EUICDMBarGlows", {
	name = "Cooldown Manager Bar Glows",
	desc = "A separate glow type for each EllesmereUI Cooldown Manager bar.",
	category = "tweaks",
	icon = [[Interface\Icons\Spell_Holy_HolyBolt]],
	order = 92,
	requires = "EllesmereUICooldownManager",
	defaults = {
		bars = {},
	},
})

local active = false
local wrapped = false
local lit = setmetatable({}, { __mode = "k" }) -- overlay -> icon our glow sits on
local origStart, origStop, ourStart, ourStop
local barOn = {} -- bar key -> whether it had its own glow when last refreshed

local function CDM()
	return XUI.EUI and XUI.EUI.Module("EllesmereUICooldownManager")
end

-- the bar's glow block when it has its own glow, else nil
local function ChoiceFor(frame)
	local bars = M.db.bars
	if not (active and XUI.CDMBarKey and next(bars)) then return nil end
	local key = XUI.CDMBarKey(frame)
	local choice = key and bars[key]
	if type(choice) == "table" and choice.on and type(choice.glow) == "table" then return choice.glow end
	return nil
end

local function Release(overlay)
	local icon = lit[overlay]
	if icon then
		XUI.Style:HideGlow(icon)
		lit[overlay] = nil
	end
end

local function Wrap()
	if wrapped then return end
	local ns = CDM()
	if not (ns and type(ns.StartNativeGlow) == "function" and type(ns.StopNativeGlow) == "function") then return end
	wrapped = true
	origStart, origStop = ns.StartNativeGlow, ns.StopNativeGlow

	ourStart = function(overlay, style, cr, cg, cb, opts)
		if active and overlay then
			local icon = (opts and opts.owner) or overlay:GetParent()
			-- "show glows only in combat" keeps its say: let EllesmereUI suppress it
			local gated = ns._cdmGlowOOCGate and not InCombatLockdown()
			local block = icon and not gated and ChoiceFor(overlay)
			if block then
				origStop(overlay)
				overlay._glowActive = true
				overlay:SetAlpha(1)
				lit[overlay] = icon
				XUI.Style:ShowGlow(icon, block, true)
				return
			end
			Release(overlay)
		end
		return origStart(overlay, style, cr, cg, cb, opts)
	end

	ourStop = function(overlay)
		if overlay and lit[overlay] then Release(overlay) end
		return origStop(overlay)
	end
	ns.StartNativeGlow, ns.StopNativeGlow = ourStart, ourStop
end

local function Unwrap()
	local ns = CDM()
	if wrapped and ns then
		-- leave a wrapper somebody else put on top of ours; ours passes straight
		-- through while the module is off (and stays installed for a re-enable)
		local startBack, stopBack = ns.StartNativeGlow == ourStart, ns.StopNativeGlow == ourStop
		if startBack then ns.StartNativeGlow = origStart end
		if stopBack then ns.StopNativeGlow = origStop end
		if not (startBack and stopBack) then return end
	end
	wrapped = false
end

-- Redraw after a change: our glows are redrawn with the current block, the ones
-- that no longer apply are dropped and EllesmereUI's own light again on its next
-- pass. A bar is only refreshed when it gains or loses its own glow, not on every
-- slider step.
local function Redraw()
	for overlay, icon in pairs(lit) do
		local block = ChoiceFor(overlay)
		if block then
			XUI.Style:ShowGlow(icon, block, true)
		else
			XUI.Style:HideGlow(icon)
			lit[overlay] = nil
			overlay._glowActive = false
		end
	end
	local ns = CDM()
	if ns and type(ns.RefreshCDMIconAppearance) == "function" and type(ns.barDataByKey) == "table" then
		for barKey in pairs(ns.barDataByKey) do
			local c = M.db.bars[barKey]
			local on = active and type(c) == "table" and c.on == true and type(c.glow) == "table"
			if (barOn[barKey] or false) ~= on then
				barOn[barKey] = on
				pcall(ns.RefreshCDMIconAppearance, barKey)
			end
		end
	end
end

function M:OnEnable()
	active = true
	Wrap()
	-- the Cooldown Manager is built a moment after login
	self:After(2, function()
		Wrap()
		Redraw()
	end)
end

function M:OnDisable()
	active = false
	for overlay in pairs(lit) do
		Release(overlay)
		overlay._glowActive = false
	end
	Unwrap()
	Redraw()
end

local RedrawSoon = XUI.Coalesce(function() if active then Redraw() end end)

function M:OnRefresh()
	RedrawSoon()
end

-- Makes sure a bar has a glow block to edit (own style, Autocast shine to start with).
function M.SeedBar(key)
	local bars = M.db.bars
	local choice = bars[key]
	if type(choice) ~= "table" then
		choice = {}
		bars[key] = choice
	end
	if type(choice.glow) ~= "table" then
		choice.glow = { enabled = true, useGlobal = false }
		for k, v in pairs(XUI.DB.style.glow) do
			choice.glow[k] = type(v) == "table" and { unpack(v) } or v
		end
		choice.glow.type = "AUTOCAST"
	end
	return choice
end

function M:DebugInfo()
	local lines = { "wrappers installed: " .. tostring(wrapped) }
	local n = 0
	for _ in pairs(lit) do n = n + 1 end
	lines[#lines + 1] = "icons lit by us right now: " .. n
	local ns = CDM()
	if ns and type(ns.barDataByKey) == "table" then
		for key, bd in pairs(ns.barDataByKey) do
			local c = self.db.bars[key]
			local on = type(c) == "table" and c.on and type(c.glow) == "table"
			lines[#lines + 1] = ("%s (%s): %s"):format(type(bd) == "table" and tostring(bd.name) or key, key,
				on and tostring(c.glow.type) or "EllesmereUI glow")
		end
	end
	return lines
end
