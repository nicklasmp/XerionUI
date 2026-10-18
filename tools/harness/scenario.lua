-- The scenario: log in, open the options, visit every page, touch every
-- control, run each module through combat, previews, profiles and unlock
-- mode, then log out. Any Lua error fails the run.

local function Step(name, fn)
	local before = #MOCK.errors
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then MOCK.errors[#MOCK.errors + 1] = name .. ": " .. tostring(err) end
	MOCK.Advance(0.5)
	local n = #MOCK.errors - before
	print(("%-44s %s"):format(name, n == 0 and "ok" or ("FAILED (" .. n .. ")")))
end

local XUI

Step("load XerionUI", function()
	MOCK.LoadTOC("XerionUI")
	XUI = _G.XerionUI
	assert(XUI and XUI.DB.profile, "database not initialised")
end)

Step("login", function()
	MOCK.Fire("PLAYER_LOGIN")
	MOCK.Fire("PLAYER_ENTERING_WORLD", true, false)
	assert(XUI.loggedIn)
end)

Step("open options (/xui)", function()
	SlashCmdList.XERIONUI("")
	MOCK.Advance(0.1)
	assert(XUI.Options and XUI.Options:IsShown(), "options did not open")
end)

local function Controls()
	local out = {}
	for _, f in ipairs(MOCK.frames) do
		if type(rawget(f, "desc")) == "table" and rawget(f, "ctx") and rawget(f, "Refresh") then out[#out + 1] = f end
	end
	return out
end

local exercised = {}
local function Exercise(control)
	local O, desc, ctx = XUI.Options, control.desc, control.ctx
	if exercised[control] then return end
	exercised[control] = true
	local t = desc.type
	if t == "toggle" then
		local v = O:GetValue(desc, ctx)
		O:SetValue(desc, ctx, not v)
		MOCK.Advance(0.05)
		O:SetValue(desc, ctx, v and true or false)
	elseif t == "slider" then
		local step = desc.step or 1
		local mid = desc.min + math.floor((desc.max - desc.min) / 2 / step) * step
		O:SetValue(desc, ctx, mid)
		MOCK.Advance(0.05)
		O:SetValue(desc, ctx, desc.min)
	elseif t == "dropdown" then
		local values = O:DropdownValues(desc, ctx)
		O:OpenDropdown(control.field, desc, ctx, O:GetValue(desc, ctx), function() end)
		MOCK.Advance(0.05)
		O.CloseDropdown()
		local pick = values[2] or values[1]
		if pick then O:SetValue(desc, ctx, pick.value) end
	elseif t == "color" then
		O:SetValue(desc, ctx, { 0.2, 0.4, 0.6, 1 })
	elseif t == "input" and not desc.readOnly then
		O:SetValue(desc, ctx, "test")
	elseif t == "button" and desc.onClick then
		desc.onClick(ctx, control)
	end
	MOCK.Advance(0.05)
	control:Refresh()
end

local pageKeys = { "style", "general", "profiles", "changelog" }
for _, m in ipairs(XUI.modules) do pageKeys[#pageKeys + 1] = m.key end
for _, c in ipairs(XUI.Options.CLASSES) do pageKeys[#pageKeys + 1] = "class:" .. c.token end
pageKeys[#pageKeys + 1] = "class:ANY"

for _, key in ipairs(pageKeys) do
	Step("page " .. key, function()
		XUI.Options:Open(key)
		MOCK.Advance(0.1)
	end)
end

MOCK.autoAccept = true
Step("touch every control", function()
	for _, key in ipairs(pageKeys) do
		XUI.Options:Open(key)
		MOCK.Advance(0.05)
		for _, c in ipairs(Controls()) do
			local ok, err = xpcall(Exercise, debug.traceback, c)
			if not ok then
				MOCK.errors[#MOCK.errors + 1] = ("control '%s' (%s) on %s: %s"):format(
					tostring(c.desc.label or c.desc.text or c.desc.path), c.desc.type, key, err)
			end
		end
	end
	MOCK.autoAccept = false
end)

Step("style cards: Reset to default restores the block", function()
	local G = XUI.Options.Groups
	-- global style page
	local ctx = XUI.Options:NewContext(function() return XUI.DB.style end, function() XUI.Style:Invalidate() end)
	local items = G.Glow("glow", { global = true })
	local reset = items[#items]
	assert(reset.type == "button" and reset.text == "Reset to default", "a glow group should end with the reset button")
	XUI.DB.style.glow.particles, XUI.DB.style.glow.type = 9, "PULSE"
	reset.onClick(ctx)
	assert(XUI.DB.style.glow.particles == 16 and XUI.DB.style.glow.type == XUI.DB.STYLE_DEFAULTS.glow.type, "global glow should be back to its defaults")
	-- a module's own block
	local m = XUI:GetModule("MeleeIndicator")
	local mctx = XUI.Options.ModuleContext(m)
	local font = G.Font("font", { color = true })
	local mreset = font[#font]
	assert(not mreset.hidden(mctx), "a module font with a shipped default should offer the reset")
	m.db.font.size = 77
	mreset.onClick(mctx)
	assert(m.db.font.size == XUI.DB.moduleDefaults[m.key].font.size, "the module font should be back to its default size")
end)

Step("modules: enable all", function()
	XUI.Options:Open("style")
	for _, m in ipairs(XUI.modules) do m:SetEnabled(true) end
end)

Step("combat start / end", function()
	MOCK.inCombat = true
	MOCK.Fire("PLAYER_REGEN_DISABLED")
	MOCK.Advance(3)
	MOCK.inCombat = false
	MOCK.Fire("PLAYER_REGEN_ENABLED")
	MOCK.Advance(5)
end)

Step("party cooldowns: group, buffs and casts", function()
	MOCK.inGroup, MOCK.role = true, "TANK"
	MOCK.Fire("GROUP_ROSTER_UPDATE")
	MOCK.Advance(1)
	for _, unit in ipairs({ "party1", "party2", "party3", "party4" }) do MOCK.Fire("UNIT_AURA", unit) end
	MOCK.Advance(2)
	MOCK.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 31884)
	MOCK.Advance(3)
	MOCK.Fire("CHALLENGE_MODE_START")
	MOCK.Advance(3)
	MOCK.inGroup, MOCK.role = false, nil
	MOCK.Fire("GROUP_ROSTER_UPDATE")
	MOCK.Advance(1)
end)

Step("previews on / off", function()
	for _, m in ipairs(XUI.modules) do m:SetPreview(true) end
	MOCK.Advance(0.1)
	for _, m in ipairs(XUI.modules) do m:SetPreview(false) end
end)

Step("module reset", function()
	for _, m in ipairs(XUI.modules) do m:Reset() end
end)

-- LibDeflate's inflate does not survive fengari's Lua 5.3 number semantics
-- (it is fine in the 5.1 client); compression is stubbed so the profile
-- logic around it can still be tested.
do
	local LD = LibStub("LibDeflate")
	local probe = LD:CompressDeflate("probe probe probe")
	if LD:DecompressDeflate(probe) ~= "probe probe probe" then
		LD.CompressDeflate = function(_, s) return s end
		LD.DecompressDeflate = function(_, s) return s end
		print("(LibDeflate stubbed for the 5.3 VM)")
	end
end

Step("profiles: new / switch / copy / export / import", function()
	local DB = XUI.DB
	assert(DB:NewProfile("Second", true))
	assert(DB:GetProfileName() == "Second")
	DB:SetProfile("Default")
	DB:CopyProfile("Second")
	local s = DB:ExportProfile()
	assert(type(s) == "string" and s:find("^!XUI1!"), "export failed")
	local ok, name = DB:ImportProfile(s, "Imported")
	assert(ok, name)
	assert(DB:GetProfileName() == name)
	DB:SetProfile("Default")
	assert(DB:DeleteProfile("Imported"))
	local bad = DB:ImportProfile("garbage")
	assert(bad == false)
end)

Step("unlock mode", function()
	XUI:SetUnlocked(true)
	MOCK.Advance(0.1)
	assert(XUI.unlockActive, "unlock did not activate")
	XUI:SetUnlocked(false)
	assert(not XUI.unlockActive)
end)

Step("global style change reaches modules", function()
	XUI.DB.style.font.outline = "THICKOUTLINE"
	XUI:Fire("StyleChanged")
	MOCK.Advance(0.1)
end)

Step("sidebar: search, class folding, dock", function()
	local O = XUI.Options
	O:Open("general")
	for _, text in ipairs({ "tank", "interrupt", "druid", "zzzz", "" }) do
		O.S.searchText = text
		O:RefreshSidebar()
	end
	XUI.DB.global.panel.classFolded = true
	O:RefreshSidebar()
	XUI.DB.global.panel.classFolded = false
	O:RefreshSidebar()
	O:Open("class:DRUID")
	O:UpdateDock()
	O:RebuildAll()
end)

Step("options: filter, jump to a setting, undo, menu, resize", function()
	local O = XUI.Options
	local S = O.S
	local key, page
	for _, m in ipairs(XUI.modules) do
		O:Open(m.key)
		MOCK.Advance(0.1)
		local p = S.pages[m.key]
		if p and p.nav then key, page = m.key, p break end
	end
	assert(page, "no module page has card navigation")

	-- filter: nothing matches, then one word, then cleared
	page:SetFilter("zzzzqqq")
	assert(page.empty and page.empty:IsShown(), "no-match note is missing")
	page:SetFilter("color")
	page:SetFilter("")
	assert(not page.empty:IsShown(), "no-match note stays after clearing")

	-- chips switch or scroll to a card
	for _, v in ipairs(page.nav.values) do
		page.nav.set(v.value)
		O:RefreshNavBar(page)
	end

	-- a toggle, undone
	local toggle, slider
	for _, card in ipairs(page.cards) do
		for _, c in ipairs(card.items) do
			if c.desc.type == "toggle" and c.desc.path and not toggle then toggle = c end
			if c.desc.type == "slider" and c.desc.path and type(c.desc.label) == "string" and not slider then
				slider = { control = c, card = card.spec.title }
			end
		end
	end
	assert(toggle, "no toggle on the page")
	local d, ctx = toggle.desc, toggle.ctx
	local before = O:GetValue(d, ctx) and true or false
	O.Undo.Clear()
	O:SetValue(d, ctx, not before)
	assert(O.Undo.Count() == 1, "a change is not remembered")
	O.Undo.Undo()
	assert((O:GetValue(d, ctx) and true or false) == before, "undo did not restore the value")
	assert(O.Undo.Count() == 0, "undo left a step behind")

	-- a hit from the sidebar search lands on the setting
	if slider then
		local label = slider.control.desc.label
		S.searchText = label:lower()
		O:RefreshSidebar()
		S.searchText = ""
		O:RefreshSidebar()
		O:Open(key, { card = slider.card, label = label })
		MOCK.Advance(0.3)
		assert(page:Focus({ card = slider.card, label = label }), "could not focus a setting")
	end

	-- the more menu, resize and reset
	O:ShowMenu(S.pageHead.diag, { { text = "Test", onClick = function() end } })
	_G.XUI_OptionsMenu:Hide()
	S.frame:SetSize(1100, 760)
	MOCK.Advance(0.1)
	O:ResetWindowSize()
	O:Open("general")
end)

Step("options: reset arrow on module and group pages", function()
	local O = XUI.Options
	local checked = 0
	local keys = {}
	for key in pairs(O.groupByKey) do keys[#keys + 1] = key end
	table.sort(keys)
	table.insert(keys, 1, "general")
	for _, m in ipairs(XUI.modules) do keys[#keys + 1] = m.key end
	for _, key in ipairs(keys) do
		if checked >= 3 then break end
		O:Open(key)
		MOCK.Advance(0.1)
		local page = O.S.pages[key]
		local target
		if page then
			for _, card in ipairs(page.cards) do
				for _, c in ipairs(card.items) do
					if not target and c.resetButton and c.desc.type == "toggle" then target = c end
				end
			end
		end
		if target then
			local d, ctx = target.desc, target.ctx
			local default = XUI.GetPath(ctx.defaults(), d.path)
			assert(type(default) == "boolean", "toggle default is not a boolean: " .. key)
			assert(not target.resetButton:IsShown(), "reset arrow shown on a default value: " .. key)
			O.Undo.Clear()
			O:SetValue(d, ctx, not default)
			page:Refresh()
			assert(target.resetButton:IsShown(), "no reset arrow on a changed value: " .. key)
			target.resetButton:GetScript("OnClick")(target.resetButton)
			page:Refresh()
			assert((O:GetValue(d, ctx) and true or false) == default, "reset did not restore the default: " .. key)
			assert(not target.resetButton:IsShown(), "reset arrow stays after reset: " .. key)
			checked = checked + 1
		end
	end
	assert(checked > 0, "no page with a resettable toggle")
	O:Open("general")
end)

Step("diagnostics, self-check and perf", function()
	XUI.perfOn = true
	local text = XUI.Health.Report()
	assert(#text > 100, "report is empty")
	for _, m in ipairs(XUI.modules) do
		XUI.Health.Report(m)
		XUI.Health.Issues(m, true)
	end
	XUI.Options:ShowText("test", text)
	SlashCmdList.XERIONUI("perf")
	SlashCmdList.XERIONUI("perf reset")
	XUI.perfOn = false
end)

Step("close options + slash commands", function()
	XUI.Options:Close()
	SlashCmdList.XERIONUI("help")
	SlashCmdList.XERIONUI("profile")
	SlashCmdList.XERIONUI("version")
end)

Step("message bus survives listeners that add listeners", function()
	local owner, late, hits = {}, {}, 0
	XUI:On("XUITestMessage", owner, function()
		hits = hits + 1
		XUI:On("XUITestMessage", late, function() hits = hits + 100 end)
	end)
	XUI:Fire("XUITestMessage")
	assert(hits == 1, "a listener added during Fire must wait for the next one, got " .. hits)
	XUI:Fire("XUITestMessage")
	assert(hits == 102, "the added listener runs on the next Fire, got " .. hits)
	XUI:Off("XUITestMessage", owner)
	XUI:Off("XUITestMessage", late)
end)

Step("media lists are sorted once and shared", function()
	local a = XUI.Media:List("font")
	assert(XUI.Media:List("font") == a, "the font list should be cached")
	for i = 2, #a do
		assert(a[i - 1]:lower() <= a[i]:lower(), "font list not sorted at " .. i)
	end
	local v = XUI.Media.version
	XUI.Media.LSM:Register("font", "ZZ Test Font", [[Fonts\ARIALN.TTF]])
	assert(XUI.Media.version == v + 1, "registering media should bump the list version")
	local b = XUI.Media:List("font")
	assert(b ~= a and b[#b] == "ZZ Test Font", "the new font should be listed last")
end)

Step("profile command ignores capitalisation", function()
	XUI.DB:NewProfile("CaseTest", false)
	XUI.DB:SetProfile("Default")
	SlashCmdList.XERIONUI("profile casetest")
	assert(XUI.DB:GetProfileName() == "CaseTest", "got " .. tostring(XUI.DB:GetProfileName()))
	XUI.DB:SetProfile("Default")
	XUI.DB:DeleteProfile("CaseTest")
end)

Step("who has the key: lists this dungeon's keys", function()
	local m = XUI:GetModule("InstanceKeys")
	assert(m and m.running, "the module should be running")
	local saved = {
		UnitFullName = _G.UnitFullName, Ambiguate = _G.Ambiguate, GetNormalizedRealmName = _G.GetNormalizedRealmName,
		GetInstanceInfo = _G.GetInstanceInfo, C_MythicPlus = _G.C_MythicPlus, C_ChallengeMode = _G.C_ChallengeMode,
		send = C_ChatInfo.SendAddonMessage,
	}
	local sent = {}
	MOCK.inGroup = true
	local names = { player = "Xerion", party1 = "Brew", party2 = "Cleric" }
	_G.UnitFullName = function(u) return names[u], nil end
	_G.Ambiguate = function(s) return s end
	_G.GetNormalizedRealmName = function() return "Realm" end
	_G.GetInstanceInfo = function() return "Ara-Kara", "party", 23, "", 5, 0, false, 2660 end
	_G.C_MythicPlus = {
		GetOwnedKeystoneLevel = function() return 10 end,
		GetOwnedKeystoneChallengeMapID = function() return 503 end,
		RequestMapInfo = function() end,
	}
	_G.C_ChallengeMode = {
		GetMapUIInfo = function(id) return id == 503 and "Ara-Kara" or "Dawnbreaker", id, 0, 0, 0, id == 503 and 2660 or 9999 end,
		IsChallengeModeActive = function() return false end,
	}
	C_ChatInfo.SendAddonMessage = function(prefix, text, channel) sent[#sent + 1] = prefix .. "|" .. text .. "|" .. channel end
	local function text()
		local d = _G.XUI_InstanceKeys
		return d and d:IsShown() and d.text:GetText() or nil
	end

	MOCK.Advance(4)
	MOCK.Fire("PLAYER_ENTERING_WORLD")
	MOCK.Advance(0.5)
	assert(sent[1] == "LibKS|R|PARTY", "entering a Mythic dungeon should ask the group, sent " .. tostring(sent[1]))
	assert(text() and text():find("Xerion", 1, true) and text():find("+10", 1, true), "your own key should be listed: " .. tostring(text()))

	MOCK.Fire("CHAT_MSG_ADDON", "LibKS", "12,503,2500", "PARTY", "Brew")
	MOCK.Fire("CHAT_MSG_ADDON", "LibKS", "11,504,1000", "PARTY", "Cleric")
	MOCK.Fire("CHAT_MSG_ADDON", "LibKS", "garbage", "PARTY", "Brew")
	MOCK.Fire("CHAT_MSG_ADDON", "Other", "5,503,1", "PARTY", "Brew")
	MOCK.Advance(0.5)
	local shown = text()
	assert(shown:find("Brew", 1, true) and shown:find("+12", 1, true), "a member with this dungeon's key should be listed: " .. shown)
	assert(not shown:find("Cleric", 1, true), "a key for another dungeon must not be listed: " .. shown)
	assert(shown:find("Xerion", 1, true) < shown:find("Brew", 1, true), "lowest key first: " .. shown)
	assert(shown:find("Who has a key?", 1, true), "the title should show")

	m.db.showAll = true
	m:Refresh()
	shown = text()
	assert(shown:find("Cleric", 1, true) and shown:find("(Dawnbreaker)", 1, true), "showAll lists other dungeons' keys, named: " .. shown)
	m.db.showAll = false

	MOCK.Advance(4)
	MOCK.Fire("CHAT_MSG_ADDON", "LibKS", "R", "PARTY", "Brew")
	assert(sent[#sent] == "LibKS|10,503,0|PARTY", "a request should be answered with our key, sent " .. tostring(sent[#sent]))

	MOCK.Fire("PLAYER_REGEN_DISABLED")
	assert(text() == nil, "combat should hide it")
	MOCK.Fire("PLAYER_REGEN_ENABLED")
	MOCK.Advance(10.5)
	assert(text() ~= nil, "it should return ten seconds after the fight")
	MOCK.Fire("ENCOUNTER_START")
	assert(text() == nil, "a boss fight should dismiss it")

	-- not a Mythic dungeon: nothing is asked, nothing shown
	_G.GetInstanceInfo = function() return "World", "none", 0, "", 0, 0, false, 1 end
	local before = #sent
	MOCK.Fire("PLAYER_ENTERING_WORLD")
	MOCK.Advance(0.5)
	assert(text() == nil and #sent == before, "outside a Mythic dungeon nothing should happen")

	MOCK.inGroup = false
	_G.UnitFullName, _G.Ambiguate, _G.GetNormalizedRealmName = saved.UnitFullName, saved.Ambiguate, saved.GetNormalizedRealmName
	_G.GetInstanceInfo, _G.C_MythicPlus, _G.C_ChallengeMode = saved.GetInstanceInfo, saved.C_MythicPlus, saved.C_ChallengeMode
	C_ChatInfo.SendAddonMessage = saved.send
	m:Refresh()
end)

Step("auto NPC dialog: records dungeon dialogs and picks switched-on ones", function()
	local m = XUI:GetModule("AutoGossip")
	assert(m and m.running, "the module should be running")
	local saved = {
		GetInstanceInfo = _G.GetInstanceInfo, IsInInstance = _G.IsInInstance, UnitName = _G.UnitName,
		UnitGUID = _G.UnitGUID, C_GossipInfo = _G.C_GossipInfo,
	}
	local selected = {}
	local inside = true
	_G.GetInstanceInfo = function()
		if inside then return "Ara-Kara", "party", 23, "Mythic", 5, 0, false, 2660 end
		return "Dornogal", "none", 0, "", 0, 0, false, 1
	end
	_G.IsInInstance = function() return inside, inside and "party" or "none" end
	_G.UnitName = function(u) return u == "npc" and "|cffffd200Kaelen|r" or "Xerion" end
	_G.UnitGUID = function(u) return u == "npc" and "Creature-0-1-2-3-219123-000ABC" or "Player-1-" .. tostring(u) end
	_G.C_GossipInfo = {
		GetOptions = function()
			return { { gossipOptionID = 555001, name = "Let's go!" }, { gossipOptionID = 555002, name = "Tell me more." } }
		end,
		SelectOption = function(id) selected[#selected + 1] = id end,
	}
	local seen = XUI.DB.global.gossipSeen
	seen[555001], seen[555002] = nil, nil

	MOCK.Fire("GOSSIP_SHOW")
	MOCK.Advance(0.1)
	local e = seen[555001]
	assert(e and e.text == "Let's go!" and e.npc == "Kaelen" and e.npcID == 219123, "the dialog should be recorded with its NPC")
	assert(e.zone == "Ara-Kara" and e.kind == "Dungeon", "the dialog should be recorded with its dungeon")
	assert(#selected == 0, "nothing is picked before it is switched on")

	local found
	for _, c in ipairs(m:Catalogue()) do if c.id == 555001 then found = c end end
	assert(found and not found.picked and found.zone == "Ara-Kara", "the catalogue should list the seen dialog")

	m:SetPicked(555001, true)
	assert(m:IsPicked(555001) and m:IsPicked(555002) == false, "switching on picks only that dialog")
	MOCK.Fire("GOSSIP_SHOW")
	MOCK.Advance(0.1)
	assert(selected[1] == 555001, "a switched-on dialog should be selected, got " .. tostring(selected[1]))

	-- the dungeon gets its own sidebar entry and page with its dialogs
	local zones = XUI.Options.DialogZones()
	local hasZone
	for _, z in ipairs(zones) do if z == "Ara-Kara" then hasZone = true end end
	assert(hasZone, "the seen dungeon should be listed for the sidebar")
	local entry = XUI.Options:DialogEntry("Ara-Kara")
	assert(entry and entry.dungeon == "Ara-Kara", "a dungeon entry should exist")
	XUI.Options:Open(entry.key)
	MOCK.Advance(0.1)
	XUI.Options:RefreshSidebar()
	for _, c in ipairs(Controls()) do
		local ok, err = xpcall(Exercise, debug.traceback, c)
		assert(ok, "dungeon dialog page control: " .. tostring(err))
	end
	XUI.Options:Open("style")

	-- built-ins can be switched off one by one
	assert(m:IsPicked(131567), "a built-in is picked by default")
	m:SetPicked(131567, false)
	assert(not m:IsPicked(131567), "a built-in can be switched off")
	m:SetPicked(131567, true)
	assert(m:IsPicked(131567), "and on again")
	assert(m:IsConfirm(48126), "a built-in confirm is on by default")
	m:SetConfirm(48126, false)
	assert(not m:IsConfirm(48126), "a built-in confirm can be switched off")
	m:SetConfirm(48126, true)

	-- outside instances nothing is recorded
	inside = false
	MOCK.Advance(6)
	seen[555002] = nil
	MOCK.Fire("GOSSIP_SHOW")
	MOCK.Advance(0.1)
	assert(seen[555002] == nil, "dialogs outside instances are not recorded")

	m:SetPicked(555001, false)
	m:Forget(555001)
	assert(seen[555001] == nil, "forget removes a dialog")
	for k, v in pairs(saved) do _G[k] = v end
end)

Step("nameplate dispel glow wraps EllesmereUI's buff style", function()
	local applied = 0
	local ns = { plates = {}, GetOffensiveDispelTypes = function() return false, false end, GetDispelGlowStyle = function() return 98 end }
	_G.EllesmereNameplates_NS = ns
	local AK = { styles = {}, RestyleSoon = function() end }
	local started = 0
	_G.EllesmereUI = { AuraKit = AK, _ModuleNS = {},
		Glows = { PANDEMIC_BORDER = 98, StartSpecGlow = function() started = started + 1 end, StopGlow = function() end } }
	AK.styles["np:buffs"] = {
		purgeGlow = true,
		applyExtra = function() applied = applied + 1 end,
	}
	MOCK.loaded.EllesmereUINameplates = true
	local m = XUI.modules and XUI.modules.EUINameplates or XUI:GetModule("EUINameplates")
	XUI.DB.profile.modules.EUINameplates.enabled = true
	XUI:UpdateModuleState(m)
	assert(m.running, "module not running")
	MOCK.Advance(5)
	local style = AK.styles["np:buffs"]
	assert(style.__xuiGlowWrap, "style was not wrapped")
	local button = CreateFrame("Button")
	local host = CreateFrame("Frame", nil, button)
	local tex = host:CreateTexture()
	-- EllesmereUI 9.6 keeps the border on host._euiPanTex; the host's first region can be anything
	host:CreateTexture()
	host._euiPanTex = tex
	tex:Show()
	style.applyExtra(button, { npGlowHost = host }, style)
	assert(applied == 1, "original applyExtra not called")
	local dbg = table.concat(m:DebugInfo(), "; ")
	assert(dbg:find("borders tinted: 1", 1, true), "no glow shown: " .. dbg)
end)

Step("logout strips defaults", function()
	MOCK.Fire("PLAYER_LOGOUT")
	local sv = _G.XerionUIDB
	assert(sv and sv.profiles and sv.profiles.Default)
end)

print("")
print(("build %d: aura containers made %d, engine sound registrations %d"):format(XUI.BUILD, MOCK.containers or 0, MOCK.auraSounds or 0))
local running = {}
for _, m in ipairs(XUI.modules) do if m.running then running[#running + 1] = m.key end end
print("running at the end: " .. table.concat(running, ", "))
local unknown = {}
for k in pairs(MOCK.unknown) do unknown[#unknown + 1] = k end
table.sort(unknown)
print("mocked no-op methods used: " .. table.concat(unknown, ", "))
print("")
if #MOCK.errors > 0 then
	for i, e in ipairs(MOCK.errors) do print(("ERROR %d: %s"):format(i, e)) end
	error(#MOCK.errors .. " error(s)")
else
	print("ALL OK")
end
