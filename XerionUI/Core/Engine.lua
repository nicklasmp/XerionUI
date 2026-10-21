--------------------------------------------------------------------------------
-- XerionUI - Core/Engine.lua
-- The small, repeated parts of drawing through the game's aura engine
-- (AuraContainer), shared by every module that does it.
--
--   Engine.NewContainer(parent, name)   a container ready for AddAuraSlot/Group
--   Engine.Silence(button)              no clicks or tooltips on an engine button
--   Engine.WhenFree(module, pending, fn)  run a refused restyle when the fight
--                                        or restriction that refused it ends
--   Engine.NewSensor(host, unit, key, include)  a hidden container that answers
--                                        "is one of these auras on `unit`?"
--   Engine.SensorLit(sensor)             that answer (a secret boolean in keys)
--
-- Why the last one: once an engine button's initializer returns, the client
-- locks it against addon code for as long as auras are secret (combat, keys,
-- boss fights). A restyle made then is refused; the module notes that, and it
-- is repeated when the restriction lifts.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local Engine = {}
XUI.Engine = Engine

-- A container frame, or nil and the reason. Anchoring and the slot/group are
-- the caller's: they differ.
function Engine.NewContainer(parent, name)
	if C_AddOns and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
		pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
	end
	local ok, c = pcall(CreateFrame, "AuraContainer", name, parent, "CustomAuraContainerTemplate")
	if not ok or not c then return nil, "the client refused the AuraContainer frame" end
	c:SetSize(1, 1)
	c:SetScale(1)
	return c
end

-- Neither clicks nor tooltips: these are readouts, and an engine button comes
-- with both alive. Only legal inside the initializer.
function Engine.Silence(button)
	pcall(button.SetMouseClickEnabled, button, false)
	pcall(button.SetMouseMotionEnabled, button, false)
end

-- Registers, on `module`, the two events that end a restriction. `pending()`
-- says whether a restyle is waiting; `fn` is the restyle.
function Engine.WhenFree(module, pending, fn)
	module:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		if pending() then fn() end
	end)
	module:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", function(self)
		-- the restriction still reads its old answer while its own event is handed out
		if pending() then self:After(0, fn) end
	end)
end

--------------------------------------------------------------------------------
-- Sensors. A one-slot container filtered to some spell IDs, parked far off
-- screen. The aura button it holds sits 50000 px to the right, so the
-- container only stretches that far while a matching aura exists, and
-- IsMouseOver on it answers "is the aura there?" even when the aura list
-- itself is secret (the answer is a secret boolean, good for
-- C_CurveUtil.EvaluateColorValueFromBoolean).
--------------------------------------------------------------------------------
local function InitSensorButton(b)
	pcall(b.SetSize, b, 1, 1)
	Engine.Silence(b)
end

function Engine.NewSensor(host, unit, key, include)
	local c, why = Engine.NewContainer(host)
	if not c then return nil, why end
	c:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -11, 0)
	pcall(c.EnableMouse, c, false)
	local ok, err = pcall(c.AddAuraGroup, c, key, "HELPFUL", {
		maxFrameCount = 1,
		candidateFilters = { includeSpellIDs = include },
		initializeFrame = InitSensorButton,
		layout = { elementWidth = 50000, elementHeight = 1, elementSpacing = 0, lineSpacing = 0 },
	})
	if not ok then return nil, tostring(err) end
	pcall(c.SetUnit, c, unit)
	pcall(c.SetEnabled, c, false)
	return c
end

function Engine.SensorLit(c) return c:IsMouseOver(1e5, -1e5, 0, 0) end

--------------------------------------------------------------------------------
-- Enemy sensor chains. Engine.NewSensor watches one unit for one spell list;
-- a chain watches many units (the enemy nameplates) at once and answers one
-- question for all of them: "is any of these auras on any of them?"
--
-- Each sensor is parked 1 px wide at the far left of the screen and anchored
-- to the right edge of the one before. A matching aura makes its sensor's
-- button 16384 px wide, which pushes every later sensor and the tail marker
-- to the right. A frame stretched from the head to the tail therefore covers
-- the cursor only while some aura is up, and IsMouseOver on it is the answer
-- (a secret boolean in keys). Sensors are never removed: they are aimed at a
-- unit with SetUnit/SetEnabled and parked again with SetEnabled(false).
--
--   local chain = Engine.NewChain(host, key, "HARMFUL|!PLAYER", include)
--   chain:Grow() / chain.n          add a sensor (not in combat)
--   chain:Aim(slot, unit) / chain:Park(slot)
--   chain:SetEnabled(on)            the whole chain on or off
--   Engine.SensorLit(chain.span)    the answer
--------------------------------------------------------------------------------
local TAIL = "DisableUntrustedLayoutScriptsTemplate"
local CHAIN_STRIDE = 16384
local CHAIN_REACH = 52

local Chain = {}
Chain.__index = Chain

local function InitChainButton(b)
	pcall(b.SetSize, b, 1, 1)
	Engine.Silence(b)
end

local function AddChainGroup(c, key, filter, include)
	return pcall(c.AddAuraGroup, c, key, filter, {
		maxFrameCount = 1,
		candidateFilters = { includeSpellIDs = include },
		initializeFrame = InitChainButton,
		layout = { elementWidth = CHAIN_STRIDE, elementHeight = 1, elementSpacing = 0, lineSpacing = 0 },
	})
end

function Engine.NewChain(host, key, filter, include)
	local self = setmetatable({ host = host, key = key, filter = filter, include = include, sensors = {}, n = 0 }, Chain)
	local head = CreateFrame("Frame", nil, host)
	head:SetSize(1, 1)
	head:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -CHAIN_REACH, 0)
	local okT, tail = pcall(CreateFrame, "Frame", nil, host, TAIL)
	local okS, span = pcall(CreateFrame, "Frame", nil, host, TAIL)
	if not (okT and tail and okS and span) then
		tail = (okT and tail) or CreateFrame("Frame", nil, host)
		span = (okS and span) or CreateFrame("Frame", nil, host)
		self.failed = "the client has no " .. TAIL
	end
	tail:SetSize(1, 1)
	tail:SetPoint("TOPLEFT", head, "TOPLEFT", 0, 0)
	span:SetPoint("TOPLEFT", head, "TOPLEFT", 0, 0)
	span:SetPoint("BOTTOMRIGHT", tail, "BOTTOMRIGHT", 0, 0)
	self.head, self.tail, self.span = head, tail, span
	return self
end

local function NewChainSensor(self)
	local ok, s = pcall(CreateFrame, "AuraContainer", nil, self.host, "CustomAuraContainerTemplate," .. TAIL)
	if not ok or not s then
		ok, s = pcall(CreateFrame, "AuraContainer", nil, self.host, "CustomAuraContainerTemplate")
	end
	if not ok or not s then return nil, "the client refused the AuraContainer frame" end
	s:SetSize(1, 1)
	pcall(s.EnableMouse, s, false)
	local added, err = AddChainGroup(s, self.key, self.filter, self.include)
	if not added then
		s:Hide()
		return nil, tostring(err), true
	end
	pcall(s.SetEnabled, s, false)
	return s
end

-- Adds one sensor to the end of the chain; true when it worked. A filter the
-- client refuses ("!PLAYER") falls back to plain HARMFUL, noted in self.note.
function Chain:Grow()
	if self.failed then return false end
	local s, why, refused = NewChainSensor(self)
	if not s and refused and self.filter ~= "HARMFUL" then
		self.filter, self.note = "HARMFUL", why
		s, why = NewChainSensor(self)
	end
	if not s then
		self.failed = why
		return false
	end
	local last = self.sensors[self.n]
	local ok, err = pcall(function()
		s:SetPoint("TOPLEFT", last or self.head, last and "TOPRIGHT" or "TOPLEFT", 0, 0)
		self.tail:ClearAllPoints()
		self.tail:SetPoint("TOPLEFT", s, "TOPRIGHT", 0, 0)
	end)
	if not ok then
		self.failed = tostring(err)
		s:Hide()
		return false
	end
	self.n = self.n + 1
	self.sensors[self.n] = s
	if self.unit and self.unit[self.n] and self.on then self:Aim(self.n, self.unit[self.n]) end
	return true
end

function Chain:Aim(slot, unit)
	self.unit = self.unit or {}
	self.unit[slot] = unit
	local s = self.sensors[slot]
	if s and self.on then
		pcall(s.SetUnit, s, unit)
		pcall(s.SetEnabled, s, true)
	end
end

function Chain:Park(slot)
	if self.unit then self.unit[slot] = nil end
	local s = self.sensors[slot]
	if s then pcall(s.SetEnabled, s, false) end
end

-- The whole chain on or off; turning it on aims every sensor that has a unit.
function Chain:SetEnabled(on)
	on = on and true or false
	if on == self.on then return end
	self.on = on
	for slot, s in ipairs(self.sensors) do
		local unit = self.unit and self.unit[slot]
		if on and unit then
			pcall(s.SetUnit, s, unit)
			pcall(s.SetEnabled, s, true)
		else
			pcall(s.SetEnabled, s, false)
		end
	end
end
