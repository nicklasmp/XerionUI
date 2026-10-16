--------------------------------------------------------------------------------
-- Cooldown Manager bar glows
-- A glow type per EllesmereUI Cooldown Manager bar: Pixel, Pulse, Autocast
-- shine, Action button or Proc, with its own color, speed and size, drawn by
-- the shared style engine. A bar without a choice keeps EllesmereUI's glow.
--
-- EllesmereUI lights every icon glow (active buff, cooldown ready, procs,
-- pandemic, bar glows) by calling one of the engine's Start functions on an
-- overlay that sits on the icon (EllesmereUI.Glows.StartAutoCastShine and so on)
-- and ends it with Glows.StopAllGlows. Those are wrapped: on a bar with a choice,
-- the engine draw is skipped and ours is drawn on the icon instead, and
-- everything else passes straight through.
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
local stats = { asked = 0, ours = 0 } -- glow requests EllesmereUI made, for /xui debug
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

-- The glow engine functions EllesmereUI draws every glow through. All of its
-- glow paths end in one of them (active buff, cooldown ready, procs, pandemic,
-- bar glows): ns.StartNativeGlow is used by some, but the cooldown-ready and proc
-- glows call a private copy of it, so only the engine itself sees every glow.
local ENGINE_STARTS = {
	"StartProceduralAnts", "StartButtonGlow", "StartAutoCastShine", "StartShapeGlow",
	"StartSolidFill", "StartFlipBookGlow", "StartAnimatedAnts",
}
local origs, ours = {}, {}
local origStopAll, ourStopAll

-- the Cooldown Manager icon a glow overlay sits on, or nil for any other glow
local function IconOf(overlay)
	local ns = CDM()
	local fc = ns and ns._ecmeFC
	if not (fc and overlay and overlay.GetParent) then return nil end
	local ok, parent = pcall(overlay.GetParent, overlay)
	if ok and parent and fc[parent] then return parent end
	return nil
end

local function Wrap()
	if wrapped then return end
	local G = _G.EllesmereUI and _G.EllesmereUI.Glows
	if not (type(G) == "table" and type(G.StopAllGlows) == "function") then return end
	wrapped = true

	for _, name in ipairs(ENGINE_STARTS) do
		local orig = G[name]
		if type(orig) == "function" then
			origs[name] = orig
			ours[name] = function(overlay, ...)
				if active and overlay then
					local icon = IconOf(overlay)
					if icon then
						stats.asked = stats.asked + 1
						local block = ChoiceFor(overlay)
						if block then
							lit[overlay] = icon
							stats.ours = stats.ours + 1
							XUI.Style:ShowGlow(icon, block, true)
							return
						end
						Release(overlay)
					end
				end
				return orig(overlay, ...)
			end
			G[name] = ours[name]
		end
	end

	origStopAll = G.StopAllGlows
	ourStopAll = function(overlay, ...)
		if overlay and lit[overlay] then Release(overlay) end
		return origStopAll(overlay, ...)
	end
	G.StopAllGlows = ourStopAll
end

local function Unwrap()
	local G = _G.EllesmereUI and _G.EllesmereUI.Glows
	if wrapped and G then
		-- leave a wrapper somebody else put on top of ours; ours passes straight
		-- through while the module is off (and stays installed for a re-enable)
		local allBack = true
		for name, our in pairs(ours) do
			if G[name] == our then G[name] = origs[name] else allBack = false end
		end
		if G.StopAllGlows == ourStopAll then G.StopAllGlows = origStopAll else allBack = false end
		if not allBack then return end
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
	lines[#lines + 1] = ("EllesmereUI started %d Cooldown Manager glows, %d drawn by us"):format(stats.asked, stats.ours)
	if XUI.glowError then lines[#lines + 1] = "last glow error: " .. tostring(XUI.glowError) end
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
