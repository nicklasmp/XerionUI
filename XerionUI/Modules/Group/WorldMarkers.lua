--------------------------------------------------------------------------------
-- World Markers
-- Two bindable buttons: one places the next world marker in a chosen order on
-- every press, the other clears them all.
--
-- Placing a world marker is a protected action, so the buttons are secure
-- macro buttons running /wm and /cwm. The cycling is done by a restricted
-- snippet wrapped around the button's click, which is why it also works in
-- combat. Bind the keys in Key Bindings -> AddOns -> XerionUI.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local M = XUI:NewModule("WorldMarkers", {
	name = "World Markers",
	desc = "Bind a key that places world markers one after another, and one that clears them.",
	category = "group",
	icon = [[Interface\Icons\inv_misc_map_01]],
	order = 66,
	defaults = {
		-- Which markers the cycle uses; the order is the list below.
		use = { true, true, true, true, true, true, true, true },
		order = { 1, 2, 3, 4, 5, 6, 7, 8 },
		resetOnClear = true,
	},
})

M.NEXT_BUTTON = "XUI_WorldMarkerNext"
M.CLEAR_BUTTON = "XUI_WorldMarkerClear"
M.NEXT_BINDING = "CLICK XUI_WorldMarkerNext:LeftButton"
M.CLEAR_BINDING = "CLICK XUI_WorldMarkerClear:LeftButton"

-- World marker index (what /wm takes) -> name.
M.NAMES = {
	[1] = "Square", [2] = "Triangle", [3] = "Diamond", [4] = "Cross",
	[5] = "Star", [6] = "Circle", [7] = "Moon", [8] = "Skull",
}

-- Labels in Key Bindings.
_G.BINDING_HEADER_XERIONUI = "XerionUI"
_G["BINDING_NAME_" .. M.NEXT_BINDING] = "Place next world marker"
_G["BINDING_NAME_" .. M.CLEAR_BINDING] = "Clear all world markers"

local nextBtn, clearBtn, header
local pending = false

-- The markers the cycle uses, in order.
function M:Sequence()
	local seq, seen = {}, {}
	for _, id in ipairs(self.db.order) do
		if self.NAMES[id] and not seen[id] and self.db.use[id] then
			seen[id] = true
			seq[#seq + 1] = id
		end
	end
	return seq
end

local function Build()
	if nextBtn then return end
	header = CreateFrame("Frame", "XUI_WorldMarkerHeader", UIParent, "SecureHandlerBaseTemplate")
	nextBtn = CreateFrame("Button", M.NEXT_BUTTON, UIParent, "SecureActionButtonTemplate")
	clearBtn = CreateFrame("Button", M.CLEAR_BUTTON, UIParent, "SecureActionButtonTemplate")
	for _, b in ipairs({ nextBtn, clearBtn }) do
		b:RegisterForClicks("AnyDown", "AnyUp")
		b:SetAttribute("type", "macro")
	end
	clearBtn:SetAttribute("macrotext", "/cwm all")

	if header.WrapScript and header.SetFrameRef then
		header:SetFrameRef("nxt", nextBtn)
		-- Before each click: step to the next marker and point the macro at it.
		header:WrapScript(nextBtn, "OnClick", [[
			local n = self:GetAttribute("count") or 0
			if n == 0 then return end
			local i = ((self:GetAttribute("idx") or 0) % n) + 1
			self:SetAttribute("idx", i)
			self:SetAttribute("macrotext", "/wm " .. self:GetAttribute("m" .. i))
		]])
		-- Clearing starts the cycle over (when enabled).
		header:WrapScript(clearBtn, "OnClick", [[
			if not owner:GetAttribute("reset") then return end
			local nxt = owner:GetFrameRef("nxt")
			if nxt then nxt:SetAttribute("idx", 0) end
		]])
	end
end

-- Pushes the settings to the secure buttons. Attributes cannot change in
-- combat, so a change made then waits for combat to end.
function M:Apply()
	if not nextBtn then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	local seq = self:Sequence()
	for i = 1, 8 do nextBtn:SetAttribute("m" .. i, seq[i]) end
	nextBtn:SetAttribute("count", #seq)
	nextBtn:SetAttribute("idx", 0)
	-- With no marker chosen the button does nothing instead of repeating.
	nextBtn:SetAttribute("macrotext", seq[1] and ("/wm " .. seq[1]) or "")
	header:SetAttribute("reset", self.db.resetOnClear and true or nil)
end

function M:OnEnable()
	Build()
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		if pending then self:Apply() end
	end)
	self:Apply()
end

function M:OnRefresh()
	if self:IsRunning() then self:Apply() end
end

function M:OnDisable()
	-- The buttons stay (secure frames cannot be destroyed) but do nothing.
	if nextBtn and not InCombatLockdown() then
		nextBtn:SetAttribute("count", 0)
		nextBtn:SetAttribute("macrotext", "")
	end
end

-- The key(s) bound to a button, as text, or nil.
function M.BoundKeys(binding)
	if not GetBindingKey then return nil end
	local k1, k2 = GetBindingKey(binding)
	if not k1 then return nil end
	local t = GetBindingText and GetBindingText(k1, "KEY_") or k1
	if k2 then t = t .. ", " .. (GetBindingText and GetBindingText(k2, "KEY_") or k2) end
	return t
end

function M:OpenBindings()
	if InCombatLockdown() then return end
	if _G.Settings and Settings.OpenToCategory and _G.SETTINGS_KEYBINDINGS_CATEGORY_ID then
		Settings.OpenToCategory(SETTINGS_KEYBINDINGS_CATEGORY_ID)
	elseif _G.Settings and Settings.OpenToCategory then
		pcall(Settings.OpenToCategory, "Key Bindings")
	end
end

-- Test: place the first marker through the same macro the button uses.
function M:DebugInfo()
	local seq = self:Sequence()
	local names = {}
	for i, id in ipairs(seq) do names[i] = self.NAMES[id] end
	return {
		("cycle: %s"):format(#names > 0 and table.concat(names, " > ") or "(none)"),
		("next key: %s"):format(self.BoundKeys(self.NEXT_BINDING) or "unbound"),
		("clear key: %s"):format(self.BoundKeys(self.CLEAR_BINDING) or "unbound"),
	}
end
