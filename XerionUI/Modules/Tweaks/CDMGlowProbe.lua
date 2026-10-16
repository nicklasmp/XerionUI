--------------------------------------------------------------------------------
-- Cooldown Manager glow probe (diagnostics only)
-- Records what EllesmereUI's Cooldown Manager does when an icon turns active:
-- which spell, whether the per-spell settings it reads carry an active glow, and
-- whether a glow ended up lit. Read it with /xui debug EUICDMGlowProbe after an
-- icon has been active. It changes nothing.
--
-- EllesmereUI turns the active glow on in ns.ApplyActiveOverlays(frame, fd, ss,
-- isActive, bd), looked up on the namespace at call time by every caller, so a
-- wrapper sees them all; a custom spell ID comes in through its Fake-Active
-- overlay (fd._rule) and a normal buff through the hooked Blizzard frame.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local M = XUI:NewModule("EUICDMGlowProbe", {
	name = "Cooldown Manager Glow Probe",
	desc = "Diagnostics: records how EllesmereUI lights the active glow on Cooldown Manager icons.",
	category = "tweaks",
	icon = [[Interface\Icons\INV_Misc_Note_02]],
	order = 99,
	requires = "EllesmereUICooldownManager",
	defaults = {},
})

local MAX = 16
local active = false
local wrapped, orig, ours
local seen, order = {}, {}
local calls = 0

local function CDM()
	return XUI.EUI and XUI.EUI.Module("EllesmereUICooldownManager")
end

local function Glow(ss)
	if type(ss) ~= "table" then return "no settings" end
	local g = ss.activeGlow
	if g == nil then return "unset" end
	return tostring(g)
end

local function Record(ns, frame, fd, ss, isActive, lit)
	local rule = type(fd) == "table" and fd._rule or nil
	local fc = ns._ecmeFC and ns._ecmeFC[frame]
	local sid = (rule and rule.spellID) or (fc and fc.spellID) or "?"
	local source = rule and (rule.cas and "custom (Fake-Active, own entry)" or "Fake-Active (bar settings)") or "hooked frame"
	-- what the bar's per-spell settings would say for the same spell
	local resolved = "n/a"
	if type(sid) == "number" and type(ns.ResolveSpellSettings) == "function" then
		local barKey = fc and fc.barKey
		local ok, rs = pcall(function()
			local sd = barKey and ns.GetBarSpellData and ns.GetBarSpellData(barKey)
			return ns.ResolveSpellSettings(nil, sid, sd, barKey)
		end)
		resolved = ok and Glow(rs) or "error"
	end
	local key = ("%s|%s|%s"):format(tostring(sid), source, tostring(isActive))
	if not seen[key] then
		if #order >= MAX then seen[table.remove(order, 1)] = nil end
		order[#order + 1] = key
	end
	seen[key] = ("spell %s, %s, active=%s: glow in the settings used = %s, in the bar's settings = %s, glow lit afterwards = %s"):format(
		tostring(sid), source, tostring(isActive), Glow(ss), resolved, tostring(lit))
end

local function Wrap()
	if wrapped then return end
	local ns = CDM()
	if not (ns and type(ns.ApplyActiveOverlays) == "function") then return end
	wrapped = true
	orig = ns.ApplyActiveOverlays
	ours = function(frame, fd, ss, isActive, ...)
		local r = orig(frame, fd, ss, isActive, ...)
		if active then
			calls = calls + 1
			pcall(Record, ns, frame, fd, ss, isActive, type(fd) == "table" and fd._activeGlowOn == true)
		end
		return r
	end
	ns.ApplyActiveOverlays = ours
end

function M:OnEnable()
	active = true
	Wrap()
	self:After(2, Wrap)
end

function M:OnDisable()
	active = false
	local ns = CDM()
	if wrapped and ns and ns.ApplyActiveOverlays == ours then
		ns.ApplyActiveOverlays = orig
		wrapped = false
	end
end

function M:DebugInfo()
	local lines = {
		"wrapper installed: " .. tostring(wrapped),
		("ApplyActiveOverlays calls seen: %d"):format(calls),
	}
	if #order == 0 then
		lines[#lines + 1] = "nothing recorded yet: let a Cooldown Manager icon turn active, then run this again"
	end
	for _, key in ipairs(order) do lines[#lines + 1] = seen[key] end
	return lines
end
