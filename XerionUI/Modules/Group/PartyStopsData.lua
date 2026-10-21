--------------------------------------------------------------------------------
-- Party Stops data: the group's crowd control cooldowns (stuns, knocks,
-- fears, AoE disorients), one entry per spell.
--
--   class      who casts it
--   cd         base cooldown in seconds
--   debuff     the aura it leaves on an enemy; seeing it start is how another
--              member's cast is noticed (their casts are secret in a key)
--   cast       other spell IDs of the same cast, for your own casts
--   lag        seconds the aura shows up after the cast (the cooldown began earlier)
--   hold       the aura is gone before the next look (Sap-like): keep reading a while
--   need       talents that must be taken for the spell to exist; any of them being
--              untaken hides the spell for that member
--   mods       talents that change the cooldown ({ talentID, add = s, pct = % })
--   spec/role  only that specialization (role is the fallback when the spec is unknown)
--   bar        which of the two bars it starts on
-- Facts only (spell IDs and numbers); the module is written for XerionUI.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local D = {}
XUI.PartyStopsData = D

D.SPELLS = {
	[119381] = { class = "MONK", cd = 60, debuff = { 119381 }, bar = 1, mods = { { 344359, add = -10 } } },
	[179057] = { class = "DEMONHUNTER", cd = 45, debuff = { 179057 }, bar = 1, need = { 179057 } },
	[30283] = { class = "WARLOCK", cd = 60, debuff = { 30283 }, bar = 1, need = { 30283 }, mods = { { 1270255, add = -15 } } },
	[192058] = { class = "SHAMAN", cd = 60, debuff = { 118905 }, lag = 2, bar = 1, need = { 192058 },
		mods = { { 381867, add = -5 }, { 265046, add = -15 }, { 445027, add = -5 } } },
	[46968] = { class = "WARRIOR", cd = 40, debuff = { 132168 }, bar = 1, need = { 46968 },
		mods = { { 275339, add = -15, likely = true }, { 440992, add = -5 } } },
	[109248] = { class = "HUNTER", cd = 45, debuff = { 117405, 117526 }, bar = 1, need = { 109248 } },
	[853] = { class = "PALADIN", cd = 45, debuff = { 853 }, bar = 1, mods = { { 234299, add = -15 } } },
	[19577] = { class = "HUNTER", cd = 60, debuff = { 24394, 474421 }, cast = { 474421 }, bar = 1, need = { 19577, 474421 },
		mods = { { 459507, add = -20 } } },
	[207167] = { class = "DEATHKNIGHT", cd = 60, debuff = { 207167 }, bar = 2, need = { 207167 } },
	[115750] = { class = "PALADIN", cd = 90, debuff = { 105421 }, bar = 2, need = { 115750 }, mods = { { 469325, add = -15 } } },
	[8122] = { class = "PRIEST", cd = 40, debuff = { 8122 }, bar = 2, need = { 8122 }, mods = { { 196704, add = -10 } } },
	[99] = { class = "DRUID", cd = 30, debuff = { 99 }, bar = 2, need = { 99 } },
	[5246] = { class = "WARRIOR", cd = 90, debuff = { 5246 }, bar = 2, need = { 5246 }, mods = { { 424742, add = -15 } } },
	[207684] = { class = "DEMONHUNTER", cd = 120, debuff = { 207685 }, lag = 2, cast = { 389813 }, bar = 2, need = { 207684 },
		mods = { { 320418, add = -30 }, { 389718, pct = -15 } } },
	[202138] = { class = "DEMONHUNTER", cd = 60, debuff = { 204843 }, lag = 2, cast = { 389807 }, spec = 581, role = "TANK", bar = 2,
		need = { 202138 }, mods = { { 389718, pct = -15 } } },
	[108199] = { class = "DEATHKNIGHT", cd = 90, debuff = { 374776 }, spec = 250, role = "TANK", bar = 2, need = { 108199 } },
	[102793] = { class = "DRUID", cd = 60, debuff = { 127797 }, bar = 2, need = { 102793 } },
	[132469] = { class = "DRUID", cd = 30, debuff = { 61391 }, bar = 2, need = { 132469 }, mods = { { 400140, add = -5 } } },
	[2094] = { class = "ROGUE", cd = 120, debuff = { 2094 }, hold = true, bar = 2, need = { 2094 },
		mods = { { 200733, pct = -50 }, { 256165, pct = -25 }, { 441415, pct = -10 } } },
}

-- Listed in this order in the options and when a new spell is added to a bar.
D.ORDER = {
	119381, 179057, 30283, 192058, 46968, 109248, 853, 19577,
	207167, 115750, 8122, 99, 5246, 207684, 202138, 108199, 102793, 132469, 2094,
}

for id, sp in pairs(D.SPELLS) do
	sp.id = id
	sp.casts = { [id] = true }
	for _, c in ipairs(sp.cast or {}) do sp.casts[c] = true end
	sp.include = {}
	for _, d in ipairs(sp.debuff) do sp.include[d] = true end
end
