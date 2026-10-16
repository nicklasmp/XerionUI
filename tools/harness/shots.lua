-- Renders each options page (and the module previews) to tools/harness/out.
MOCK.LoadTOC("XerionUI")
MOCK.Fire("PLAYER_LOGIN")
MOCK.Advance(0.5)
local XUI = _G.XerionUI
for _, m in ipairs(XUI.modules) do m:SetEnabled(true) end
-- three Cooldown Manager bars, so the Cooldown Manager page has something to show
if XUI.EUI then
	local realModule = XUI.EUI.Module
	XUI.EUI.Module = function(name)
		if name == "EllesmereUICooldownManager" then
			return { barDataByKey = { cd = { name = "Cooldowns" }, ut = { name = "Utility" }, bf = { name = "Buffs" } } }
		end
		return realModule(name)
	end
end
-- a few dialogs for the Auto NPC Dialog page
XUI.DB.global.gossipSeen = {
	[555001] = { text = "We're ready. Open the gate.", npc = "Kaelen Dawnward", zone = "Ara-Kara", kind = "Dungeon" },
	[555002] = { text = "Tell me what happened here.", npc = "Kaelen Dawnward", zone = "Ara-Kara", kind = "Dungeon" },
	[131567] = { text = "Take us to the boss.", npc = "Scout Velra", zone = "Murder Row", kind = "Dungeon" },
}
XUI:GetModule("AutoGossip"):SetPicked(555001, true)
SlashCmdList.XERIONUI("")
MOCK.Advance(0.5)
MOCK.crop = "XUI_OptionsFrame"
local keys = { "style", "general", "profiles" }
for _, m in ipairs(XUI.modules) do keys[#keys + 1] = m.key end
for key in pairs(XUI.Options.groupByKey) do keys[#keys + 1] = key end
for _, key in ipairs(keys) do
	XUI.Options:Open(key)
	MOCK.Advance(0.2)
	MOCK.Shot("page-" .. key:gsub(":", "_"))
end
XUI.Options:Open("MeleeIndicator")
for _, m in ipairs(XUI.modules) do m:SetPreview(true) end
MOCK.Advance(0.2)
XUI.Options:Close()
MOCK.crop = nil
for _, m in ipairs(XUI.modules) do m:SetPreview(true) end
MOCK.Advance(0.2)
MOCK.Shot("previews")
XUI:SetUnlocked(true)
MOCK.Advance(0.2)
MOCK.Shot("unlock")
for i, e in ipairs(MOCK.errors) do print("ERROR " .. i .. ": " .. e) end
