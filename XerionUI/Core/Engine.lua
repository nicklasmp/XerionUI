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
