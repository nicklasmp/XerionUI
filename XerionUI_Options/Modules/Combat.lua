--------------------------------------------------------------------------------
-- XerionUI_Options - Modules/Combat.lua
-- Options for the Combat category.
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local Card = O.Card

O:RegisterModuleOptions("MeleeIndicator", function(ctx, m, G)
	return {
		Card("Marker", {
			{ type = "input", label = "Text", path = "text" },
			{ type = "color", label = "Color", path = "color" },
			{ type = "slider", label = "Check every (seconds)", path = "interval", min = 0.1, max = 1, step = 0.05 },
			{ type = "toggle", label = "Pulse", path = "pulse", tip = "Fades the marker in and out while you are out of range, so it is harder to miss." },
			{ type = "slider", label = "Pulse speed (seconds per fade)", path = "pulseSpeed", min = 0.15, max = 1.5, step = 0.05,
				disabled = function() return not m.db.pulse end },
		}),
		Card("Text", G.Font("font")),
		Card("Position", G.Position("position")),
	}
end)
