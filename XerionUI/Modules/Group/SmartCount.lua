--------------------------------------------------------------------------------
-- Smart Count Tracker
-- An enemy forces bar that knows your Mythic Dungeon Tools route. It shows the
-- count you have against the count the route wants by the next pull or by the
-- next boss, and while you are in a fight it stacks what the enemies in it are
-- worth behind the fill, so the bar's end shows where the pull will leave you.
--
-- The route is read from MDT's own tables (see MDTLink.lua) and kept in this
-- module's settings, so it is there next session without opening MDT. Which
-- pull you are on is worked out from the count: the last pull whose running
-- total you have reached, never past a boss that is still alive. During a
-- fight the pull you walked into stays the target.
--
-- Inside a key the per-enemy values can be secret. The stacked bars draw them
-- anyway; the "+N" text next to them is only written when every value is
-- readable.
--
-- Idea from KiraUI-Plugin's Smart Count Tracker (personal use); this module is
-- written for XerionUI, with its own route logic.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local T = XUI.Templates
local Style = XUI.Style
local MDT = XUI.MDT

local IsSecret, Ask = XUI.IsSecret, XUI.Ask
local floor, mmax, mmin, mabs = math.floor, math.max, math.min, math.abs
local format, tsort = string.format, table.sort

local PLAN_VERSION = 5
local MAX_PLATES = 40
local PULL_TICK = 0.5
local KEY_DIFFICULTY = { [8] = true, [23] = true }

local M = XUI:NewModule("SmartCount", {
	name = "Smart Count Tracker",
	desc = "Enemy forces against your Mythic Dungeon Tools route: what you need by the next pull or boss.",
	category = "group",
	icon = [[Interface\Icons\INV_Misc_Map02]],
	order = 60,
	untested = true,
	defaults = {
		numbers = "BOTH",
		target = "PULL",
		showPull = true,
		autoLoad = true,
		bar = T.Bar(260, 22),
		border = T.Border(),
		nameText = T.Font(12, { enabled = true }),
		valueText = T.Font(12, { enabled = true }),
		color = { 0.26, 0.55, 1, 1 },
		reachedColor = { 0.2, 0.8, 0.3, 1 },
		shortColor = { 0.9, 0.2, 0.2, 1 },
		pullColor = { 1, 1, 1, 0.35 },
		alert = T.Alert("NONE"),
		plans = {},
		links = {},
		position = T.Position(0, 230),
	},
})

M.NUMBERS = {
	{ value = "BOTH", text = "Percent and count" },
	{ value = "PERCENT", text = "Percent" },
	{ value = "COUNT", text = "Count" },
}
M.TARGETS = {
	{ value = "PULL", text = "The next pull of the route" },
	{ value = "BOSS", text = "Just before the next boss" },
}

local SAMPLE = { total = 460, count = 176, target = 207, name = "Sample Boss", pullName = "Pull 7/14", pull = { 9, 6, 14, 5 } }

local frame, ui
local killed, below = {}, {}
local finished, inCombat = false, false
local lastInst, lockedP
local pullTicker
local pull = { shown = 0 }
local mdt = { computed = 0, journals = {} }

local PLATES = {}
for i = 1, MAX_PLATES do PLATES[i] = "nameplate" .. i end

local function Plain(v)
	if v == nil or IsSecret(v) then return nil end
	return v
end

local function PlainName(s) return (tostring(s):lower():gsub("[%s%p]", "")) end

local function Unpack(ok, ...)
	if ok then return ... end
end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	return Unpack(pcall(fn, ...))
end

--------------------------------------------------------------------------------
-- The route, from MDT
--------------------------------------------------------------------------------
local function InstanceOf(cmap)
	local CM = C_ChallengeMode
	local r = { pcall(CM and CM.GetMapUIInfo, cmap) }
	return r[1] and tonumber(Plain(r[7])) or nil
end

-- Boss names and creatures of an instance, by journal entry.
local function Journal(inst)
	local CEJ = C_EncounterJournal
	local jInst = inst and tonumber(Plain(Call(CEJ and CEJ.GetInstanceForGameMap, inst)))
	if not jInst then return nil end
	local j = { byName = {}, byDisplay = {}, count = 0 }
	for i = 1, 30 do
		local name, _, jEnc, _, _, _, dEnc = Call(EJ_GetEncounterInfoByIndex, i, jInst)
		name, jEnc = Plain(name), tonumber(Plain(jEnc))
		if type(name) ~= "string" or not jEnc then break end
		local e = { name = name, key = "e" .. jEnc, enc = tonumber(Plain(dEnc)) }
		j.count = j.count + 1
		for c = 1, 12 do
			local _, cname, _, display = Call(EJ_GetCreatureInfo, c, jEnc)
			cname, display = Plain(cname), tonumber(Plain(display))
			if type(cname) ~= "string" then break end
			local k = PlainName(cname)
			if not j.byName[k] then j.byName[k] = e end
			if display and not j.byDisplay[display] then j.byDisplay[display] = e end
		end
		local k = PlainName(name)
		if not j.byName[k] then j.byName[k] = e end
	end
	if j.count == 0 then return nil end
	return j
end

local function BossOf(journal, enemy, clone, p)
	if not enemy.isBoss then return nil end
	if journal then
		return journal.byDisplay[tonumber(enemy.displayId) or -1]
			or (type(enemy.name) == "string" and journal.byName[PlainName(enemy.name)])
			or nil
	end
	-- no journal entry: a boss that counts for nothing is the boss itself
	if (tonumber(clone.count) or tonumber(enemy.count) or 0) > 0 then return nil end
	local named = type(enemy.name) == "string"
	return { name = named and enemy.name or "?", key = "p" .. p, mob = named and PlainName(enemy.name) or nil }
end

-- One dungeon's selected route: running total after every pull, and where the
-- bosses stand in it.
local function BuildPlan(Tab, db, idx, journal)
	local enemies = Tab.dungeonEnemies[idx]
	local presets = type(db.presets) == "table" and db.presets[idx]
	local sel = type(db.currentPreset) == "table" and db.currentPreset[idx]
	local preset = type(presets) == "table" and sel and presets[sel]
	if type(enemies) ~= "table" or type(preset) ~= "table" then return nil end
	local counts = type(Tab.dungeonTotalCount) == "table" and Tab.dungeonTotalCount[idx]
	local plan = {
		route = type(preset.text) == "string" and preset.text or "?",
		total = type(counts) == "table" and tonumber(counts.normal) or 0,
		bosses = {},
		v = PLAN_VERSION,
	}
	if not journal then
		plan.names = {}
		for _, enemy in pairs(enemies) do
			if type(enemy) == "table" and enemy.isBoss and type(enemy.name) == "string" then plan.names[PlainName(enemy.name)] = true end
		end
	end
	local value = preset.value
	local pulls = type(value) == "table" and value.pulls
	if type(pulls) ~= "table" then return plan end
	local order = {}
	for k in pairs(pulls) do
		if type(k) == "number" then order[#order + 1] = k end
	end
	tsort(order)
	local seen, cum, after = {}, 0, {}
	for i, p in ipairs(order) do
		local group, add = pulls[p], 0
		if type(group) == "table" then
			for e, clones in pairs(group) do
				local enemy = type(e) == "number" and enemies[e]
				if type(enemy) == "table" and type(clones) == "table" and type(enemy.clones) == "table" then
					for _, ci in pairs(clones) do
						local clone = enemy.clones[ci]
						if type(clone) == "table" then
							add = add + (tonumber(clone.count) or tonumber(enemy.count) or 0)
							local boss = BossOf(journal, enemy, clone, p)
							if boss then
								local t = seen[boss.key]
								if not t then
									t = { name = boss.name, ej = boss.key, enc = boss.enc, before = cum, pull = i }
									seen[boss.key] = t
									plan.bosses[#plan.bosses + 1] = t
								end
								if boss.mob then
									t.mobs = t.mobs or {}
									local have = false
									for _, m in ipairs(t.mobs) do
										if m == boss.mob then have = true end
									end
									if not have then t.mobs[#t.mobs + 1] = boss.mob end
								end
							end
						end
					end
				end
			end
		end
		cum = cum + add
		after[i] = cum
	end
	plan.after = after
	return plan
end

-- Reads every dungeon of the current season from MDT into the saved plans.
function M:ComputePlans()
	local Tab = MDT.Table()
	if not Tab then return false end
	local db = MDT.DB()
	if not db then return false end
	local enemies, info, names = rawget(Tab, "dungeonEnemies"), rawget(Tab, "mapInfo"), rawget(Tab, "dungeonList")
	if type(enemies) ~= "table" or type(info) ~= "table" then
		mdt.err = "its dungeon tables were not found"
		return false
	end
	local seasons = rawget(Tab, "dungeonSelectionToIndex")
	local season = type(seasons) == "table" and type(seasons[1]) == "table" and seasons[1] or nil
	local list = {}
	if season then
		for _, idx in ipairs(season) do list[#list + 1] = idx end
	else
		for idx in pairs(enemies) do list[#list + 1] = idx end
	end
	local fresh, n = {}, 0
	for _, idx in ipairs(list) do
		local m = info[idx]
		local cmap = type(m) == "table" and tonumber(m.mapID)
		if cmap and type(enemies[idx]) == "table" then
			local inst = InstanceOf(cmap)
			local journal = inst and mdt.journals[inst] or Journal(inst)
			if journal then mdt.journals[inst] = journal end
			local ok, plan = pcall(BuildPlan, Tab, db, idx, journal)
			if not ok then
				mdt.err = tostring(plan)
			elseif plan then
				plan.cmap, plan.inst = cmap, inst
				plan.journal = journal and true or false
				plan.dungeon = type(names) == "table" and type(names[idx]) == "string" and names[idx] or nil
				fresh[cmap] = plan
				n = n + 1
			end
		end
	end
	if n > 0 then self.db.plans = fresh end
	mdt.computed = n
	return n > 0
end

local function LinkBosses(plan)
	-- bosses without a journal entry get their encounter ID from a fight (see Link)
	local links = M.db.links and M.db.links[plan.cmap]
	if type(links) ~= "table" then return end
	for _, b in ipairs(plan.bosses) do
		if not b.enc and type(b.mobs) == "table" then
			for _, mob in ipairs(b.mobs) do
				local l = links[mob]
				if type(l) == "table" and l.enc then
					b.enc, b.name, b.linked = l.enc, l.name or b.name, true
					break
				end
			end
		end
	end
end

local function CurrentPlan()
	local plans = M.db.plans
	if type(plans) ~= "table" then return nil end
	local CM = C_ChallengeMode
	local cmap = Call(CM and CM.GetActiveChallengeMapID)
	local p = cmap and not IsSecret(cmap) and plans[cmap]
	if type(p) == "table" and p.v == PLAN_VERSION then
		LinkBosses(p)
		return p
	end
	local inst = select(8, Call(GetInstanceInfo))
	if not inst or IsSecret(inst) then return nil end
	for _, q in pairs(plans) do
		if type(q) == "table" and q.inst == inst and q.v == PLAN_VERSION then
			LinkBosses(q)
			return q
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- The count
--------------------------------------------------------------------------------
-- count, total and the completed criteria (dead bosses) from the scenario.
local function ReadForces()
	local SI = C_ScenarioInfo
	if not SI then return nil end
	local step = Call(SI.GetScenarioStepInfo)
	local n = type(step) == "table" and tonumber(step.numCriteria) or 0
	local count, total
	local done = {}
	for i = 1, n do
		local c = Call(SI.GetCriteriaInfo, i)
		if type(c) == "table" then
			if c.isWeightedProgress == true then
				local t = tonumber(c.totalQuantity)
				if t and t > 0 then
					total = t
					local s, v = c.quantityString, nil
					if type(s) == "string" and not IsSecret(s) then
						s = s:gsub("%%", "")
						if s:find(",") and not s:find("%.") then s = s:gsub(",", ".") end
						v = tonumber(s)
					end
					if not v then
						local q = tonumber(c.quantity)
						v = q and q * t / 100
					end
					count = v
				end
			elseif c.completed == true then
				done[#done + 1] = c
			end
		end
	end
	return count, total, done
end

local function Killed(plan, enc, name)
	if not plan then return end
	local want = type(name) == "string" and name ~= "" and PlainName(name) or nil
	for _, b in ipairs(plan.bosses) do
		if not killed[b.ej] and ((enc and b.enc == enc) or (want and PlainName(b.name) == want)) then
			killed[b.ej] = true
			-- a boss that died means every boss before it in the route did
			for _, x in ipairs(plan.bosses) do
				if not killed[x.ej] and (x.pull or 0) < (b.pull or 0) then killed[x.ej] = true end
			end
		end
	end
end

local function MarkDone(plan, done)
	if not (plan and done) then return end
	for _, c in ipairs(done) do
		local id, desc = c.assetID, c.description
		if IsSecret(id) then id = nil end
		if IsSecret(desc) then desc = nil end
		Killed(plan, tonumber(id), desc)
	end
end

-- A boss fight at a mob the journal could not name: its first fight links it.
local function Link(plan, enc, name)
	if not (plan and plan.journal == false and enc and type(name) == "string" and name ~= "") then return end
	local want = PlainName(name)
	if type(plan.names) == "table" and plan.names[want] then return end
	local free
	for _, b in ipairs(plan.bosses) do
		if b.enc == enc or PlainName(b.name) == want then return end
		if not free and not b.enc and not killed[b.ej] then free = b end
	end
	if not free then return end
	if type(free.mobs) == "table" then
		M.db.links = M.db.links or {}
		local links = M.db.links[plan.cmap]
		if not links then
			links = {}
			M.db.links[plan.cmap] = links
		end
		for _, mob in ipairs(free.mobs) do links[mob] = { enc = enc, name = name } end
	end
	free.enc, free.name, free.linked = enc, name, true
end

local function HasPulls(plan)
	return plan and type(plan.after) == "table" and #plan.after > 0
end

local function At(after, i) return i > 0 and after[i] or 0 end

-- The last pull the count has completed, never past a boss still alive.
local function PullsDone(plan, count)
	local after = plan.after
	local stop = #after
	for _, b in ipairs(plan.bosses) do
		local i = b.pull or 0
		if i > 0 and not killed[b.ej] and i - 1 < stop then stop = i - 1 end
	end
	local p = 0
	for i = 1, stop do
		if after[i] <= count + 0.01 then p = i else break end
	end
	return p
end

-- Label and target for the next pull of the route.
local function PullView(plan, count, total)
	if not HasPulls(plan) then return nil end
	local after, n = plan.after, #plan.after
	local p = inCombat and lockedP or PullsDone(plan, count)
	if inCombat and not lockedP then
		lockedP = p
	end
	local fighting = inCombat
	if p >= n then return "Finish", total > 0 and total or after[n] end
	local boss
	for _, x in ipairs(plan.bosses) do
		if x.pull == p + 1 and not killed[x.ej] then
			boss = x
			break
		end
	end
	local label, target
	if fighting then
		label, target = boss and boss.name or format("Pull %d/%d", p + 1, n), after[p + 1]
	elseif boss then
		label, target = "Before " .. boss.name, At(after, p)
	else
		label, target = format("Pull %d/%d", p + 1, n), after[p + 1]
	end
	if total > 0 then target = mmin(target, total) end
	return label, target
end

local function NextBoss(plan, total)
	for _, b in ipairs(plan.bosses) do
		if not killed[b.ej] then return b end
	end
	return { final = true, before = total, name = "Finish" }
end

local function Showing(self)
	if self:IsPreview() then return true end
	if not self.running or finished then return false end
	return XUI.KeyActive()
end

local function KeyDungeon()
	if XUI.KeyActive() then return true end
	local ok, inside, kind = pcall(IsInInstance)
	if not ok or IsSecret(inside) or not inside or kind ~= "party" then return false end
	local diff = Plain(select(3, Call(GetInstanceInfo)))
	return KEY_DIFFICULTY[diff] == true
end

local function NoPlanText()
	if not MDT.IsLoaded() then return "MDT is not loaded" end
	if MDT.Table() then return "No MDT route for this dungeon" end
	if not XUI.IsAddOnLoaded(MDT.UI) then return "Open MDT once to read your route" end
	return "Your MDT route could not be read"
end

local function Numbers(db, count, target, total)
	local pc = total > 0 and count / total * 100 or 0
	local pt = total > 0 and target / total * 100 or 0
	local need = target - count
	local main, delta
	if db.numbers == "COUNT" then
		main = format("%d / %d", floor(count + 0.5), floor(target + 0.5))
	else
		main = format("%.1f%% / %.1f%%", pc, pt)
	end
	if db.numbers == "PERCENT" then
		delta = format("%.1f%%", mabs(pt - pc))
	else
		delta = tostring(floor(mabs(need) + 0.5))
	end
	delta = need > 0 and ("|cffff6060-" .. delta .. "|r") or ("|cff60ff60+" .. delta .. "|r")
	return main .. "  " .. delta
end

--------------------------------------------------------------------------------
-- The bar
--------------------------------------------------------------------------------
local function EnsureFrame()
	if frame then return end
	frame = XUI.Widgets:CreateBar("XUI_SmartCount")
	frame:Hide()
	ui = { segs = {} }
	ui.clip = CreateFrame("Frame", nil, frame)
	ui.clip:SetClipsChildren(true)
	ui.clip:SetAllPoints(frame.bar)
	ui.clip:SetFrameLevel(frame.bar:GetFrameLevel() + 1)
	ui.mark = frame.texts:CreateTexture(nil, "OVERLAY")
	ui.mark:SetColorTexture(1, 1, 1, 1)
	ui.mark:Hide()
	ui.plus = frame.texts:CreateFontString(nil, "OVERLAY")
	ui.plus:Hide()
	XUI.Movers:Register(frame, M, "position")
end

local function ApplyVisual()
	local db = M.db
	frame:ApplyLayout(db.bar, db.border, "NONE")
	frame:ApplyNameText(db.nameText)
	frame:ApplyTimeText(db.valueText)
	local b = Style:Resolve("bar", db.bar)
	local inset = frame.border:GetInset()
	ui.w, ui.h = (b.width or 260) - 2 * inset, (b.height or 22) - 2 * inset
	ui.mark:SetSize(2, ui.h + 4)
	ui.ver = (ui.ver or 0) + 1
	Style:ApplyFont(ui.plus, db.valueText)
	ui.plus:ClearAllPoints()
	ui.plus:SetPoint("RIGHT", frame.time, "LEFT", -6, 0)
	frame.name:ClearAllPoints()
	frame.name:SetPoint("LEFT", frame.bar, "LEFT", 4, 0)
	frame.name:SetPoint("RIGHT", ui.plus, "LEFT", -4, 0)
end

-- One stacked piece of the pull, behind the previous one.
local function Place(n, anchor, v, total)
	local s = ui.segs[n]
	if not s then
		s = CreateFrame("StatusBar", nil, ui.clip)
		s:SetFrameLevel(ui.clip:GetFrameLevel() + 1)
		s:EnableMouse(false)
		ui.segs[n] = s
	end
	if s.ver ~= ui.ver then
		s.ver, s.at, s.total = ui.ver, nil, nil
		local c = M.db.pullColor
		s:SetStatusBarTexture(frame.bar:GetStatusBarTexture():GetTexture())
		s:SetStatusBarColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 0.35)
		s:SetSize(ui.w, ui.h)
		s.tex = s:GetStatusBarTexture()
	end
	if s.total ~= total then
		s.total = total
		s:SetMinMaxValues(0, total)
	end
	if s.at ~= anchor then
		s.at = anchor
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0)
	end
	s:SetValue(v)
	s:Show()
	return s.tex
end

-- Draws what the fight is worth; returns the sum when every value was readable.
local function DrawPull(total)
	if not ui then return nil end
	local n, sum, plain = 0, 0, true
	local anchor = frame.bar:GetStatusBarTexture()
	if total and total > 0 and M.db.showPull and (M:IsPreview() or inCombat) then
		if M:IsPreview() then
			for _, v in ipairs(SAMPLE.pull) do
				n = n + 1
				anchor = Place(n, anchor, v, total)
				sum = sum + v
			end
		else
			local get = C_ScenarioInfo and C_ScenarioInfo.GetUnitCriteriaProgressValues
			if get then
				for i = 1, MAX_PLATES do
					local unit = PLATES[i]
					if Ask(UnitExists, unit) and Ask(UnitCanAttack, "player", unit) and not Ask(UnitIsDead, unit) then
						local ok, fights = pcall(UnitAffectingCombat, unit)
						if ok and (IsSecret(fights) or fights == true) then
							local okV, v = pcall(get, unit)
							if okV and v ~= nil then
								n = n + 1
								anchor = Place(n, anchor, v, total)
								if IsSecret(v) then plain = false else sum = sum + v end
							end
						end
					end
				end
			end
		end
	end
	for i = n + 1, pull.shown do ui.segs[i]:Hide() end
	pull.shown = n
	if n == 0 then return nil end
	return plain and sum or nil, n
end

local function Paint(db, label, right, count, target, total, reached, fighting, sum)
	frame.bar:SetMinMaxValues(0, mmax(1, total))
	frame.bar:SetValue(total > 0 and mmin(count, total) or 0)
	local c = db.color
	if reached then c = db.reachedColor end
	-- a pull that is readable ends short of or past the target
	if sum and target and fighting then c = (count + sum >= target) and db.reachedColor or db.shortColor end
	frame:SetColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
	if target and total > 0 then
		ui.mark:ClearAllPoints()
		ui.mark:SetPoint("CENTER", frame.bar, "LEFT", mmin(1, target / total) * ui.w, 0)
		ui.mark:Show()
	else
		ui.mark:Hide()
	end
	frame.name:SetText(label)
	frame.time:SetText(right or "")
	if sum and sum > 0 then
		ui.plus:SetText("|cff9fd0ff+" .. floor(sum + 0.5) .. "|r")
		ui.plus:Show()
	else
		ui.plus:Hide()
	end
end

local function Reached(self, key)
	if not below[key] then return end
	below[key] = nil
	XUI.Audio:Play(self.db.alert, "Count reached")
end

function M:Update()
	if not frame then return end
	local db = self.db
	if not Showing(self) then
		frame:Hide()
		DrawPull(nil)
		return
	end
	frame:Show()
	if self:IsPreview() then
		local label = db.target == "PULL" and SAMPLE.pullName or "Before " .. SAMPLE.name
		local sum = DrawPull(SAMPLE.total)
		Paint(db, label, Numbers(db, SAMPLE.count, SAMPLE.target, SAMPLE.total), SAMPLE.count, SAMPLE.target, SAMPLE.total, nil, true, sum)
		return
	end
	local plan = CurrentPlan()
	local okF, count, total, done = pcall(ReadForces)
	if not okF then count, total, done = nil, nil, nil end
	MarkDone(plan, done)
	total = total or (plan and plan.total) or 0
	count = count or 0
	local key = XUI.KeyActive()
	local sum = DrawPull(key and total > 0 and total or nil)
	if not plan then
		Paint(db, NoPlanText(), "", 0, nil, 0)
		return
	end
	if #plan.bosses == 0 then
		Paint(db, format('MDT route "%s" has no bosses', plan.route), "", count, nil, total)
		return
	end
	local b = NextBoss(plan, total)
	local label, target = b.final and "Finish" or "Before " .. b.name, mmin(b.before or 0, total > 0 and total or math.huge)
	if db.target == "PULL" then
		local l, t = PullView(plan, count, total)
		if l then label, target = l, t end
	end
	local id = b.final and "end" or b.ej
	local reached = count >= target
	if reached then
		if key then Reached(self, id) end
	else
		below[id] = true
	end
	Paint(db, label, Numbers(db, count, target, total), count, target, total, reached, inCombat, sum)
end

--------------------------------------------------------------------------------
-- Run state
--------------------------------------------------------------------------------
local function NewRun()
	wipe(killed)
	wipe(below)
	finished, lockedP = false, nil
end

-- Editing a route in MDT's window changes the count the bar wants.
local function HookWindow()
	local Tab = MDT.T
	local f = Tab and rawget(Tab, "main_frame")
	if mdt.hooked or type(f) ~= "table" or not f.HookScript then return end
	mdt.hooked = true
	f:HookScript("OnHide", function()
		if M.running then C_Timer.After(0, function() M:Changed() end) end
	end)
end

function M:Changed()
	HookWindow()
	if self.running then self:ComputePlans() end
	self:RefreshSoon()
end

function M:AfterZone()
	local inst = select(8, Call(GetInstanceInfo))
	if IsSecret(inst) then inst = nil end
	if inst ~= lastInst then
		lastInst = inst
		NewRun()
	end
	finished = false
	if MDT.Table() then self:ComputePlans() end
	if self.db.autoLoad and KeyDungeon() and not CurrentPlan() then MDT.LoadWindow() end
	self:RefreshSoon()
end

local function SyncPullTicker(self)
	local want = self.running and inCombat and self.db.showPull and XUI.KeyActive()
	if want and not pullTicker then
		pullTicker = self:NewTicker(PULL_TICK, function(m) m:Update() end)
	elseif not want and pullTicker then
		self:CancelTicker(pullTicker)
		pullTicker = nil
	end
end

function M:OnEnable()
	pullTicker = nil
	inCombat = Ask(InCombatLockdown) == true
	MDT.Hook(self, function() self:After(0, function(m) m:Changed() end) end)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function(m)
		inCombat = Ask(InCombatLockdown) == true
		m:After(0.5, m.AfterZone)
	end)
	self:RegisterEvent("CHALLENGE_MODE_START", function(m)
		NewRun()
		if MDT.Table() then m:ComputePlans() end
		m:RefreshSoon()
	end)
	self:RegisterEvent("CHALLENGE_MODE_RESET", function(m)
		NewRun()
		m:RefreshSoon()
	end)
	self:RegisterEvent("CHALLENGE_MODE_COMPLETED", function(m)
		finished = true
		m:RefreshSoon()
	end)
	self:RegisterEvent("SCENARIO_CRITERIA_UPDATE", "RefreshSoon")
	self:RegisterEvent("SCENARIO_UPDATE", "RefreshSoon")
	self:RegisterEvent("ENCOUNTER_START", function(m, _, id, name)
		if XUI.KeyActive() then Link(CurrentPlan(), tonumber(Plain(id)), Plain(name)) end
		m:RefreshSoon()
	end)
	self:RegisterEvent("ENCOUNTER_END", function(m, _, id, name, _, _, success)
		if not IsSecret(success) and success == 1 then
			local n = Plain(name)
			Killed(CurrentPlan(), tonumber(Plain(id)), type(n) == "string" and n or nil)
		end
		m:RefreshSoon()
	end)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", function(m)
		inCombat = true
		lockedP = nil
		SyncPullTicker(m)
		m:RefreshSoon()
	end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function(m)
		inCombat, lockedP = false, nil
		SyncPullTicker(m)
		m:RefreshSoon()
	end)
	HookWindow()
	if MDT.Table() then self:ComputePlans() end
	self:After(0.5, self.AfterZone)
end

function M:OnDisable()
	pullTicker = nil
end

function M:OnSettingChanged()
	self:RefreshSoon()
end

function M:OnRefresh()
	if not (self.running or self:IsPreview() or frame) then return end
	EnsureFrame()
	XUI.Movers:Apply(frame)
	ApplyVisual()
	SyncPullTicker(self)
	self:Update()
end

--------------------------------------------------------------------------------
-- For the options and /xui debug
--------------------------------------------------------------------------------
-- Reads the routes again; with `load` the MDT window is loaded first.
function M:ReadRoutes(load)
	if load then
		MDT.tried = false
		MDT.LoadWindow()
	end
	local ok = self:ComputePlans()
	self:RefreshSoon()
	return ok
end

function M:Status()
	local lines = {}
	if not MDT.IsLoaded() then
		lines[1] = "MDT is not loaded."
		return lines
	end
	if MDT.Table() then
		lines[#lines + 1] = format("MDT routes read: %d dungeons.", mdt.computed or 0)
	elseif not MDT.door then
		lines[#lines + 1] = "MDT has changed: its routes cannot be read."
	else
		lines[#lines + 1] = "MDT routes not read in this session yet (open MDT once)."
	end
	if mdt.err or MDT.err then lines[#lines + 1] = "Last problem: " .. tostring(mdt.err or MDT.err) end
	local list = {}
	for _, p in pairs(self.db.plans or {}) do
		if type(p) == "table" and p.v == PLAN_VERSION and #p.bosses > 0 then list[#list + 1] = p end
	end
	tsort(list, function(x, y) return tostring(x.dungeon or x.cmap) < tostring(y.dungeon or y.cmap) end)
	for _, p in ipairs(list) do
		local parts = {}
		for _, b in ipairs(p.bosses) do
			parts[#parts + 1] = format("%s %.1f%%", b.name, p.total > 0 and b.before / p.total * 100 or 0)
		end
		lines[#lines + 1] = format("%s - %s: %s, %d pulls%s", p.dungeon or tostring(p.cmap), p.route, table.concat(parts, ", "),
			HasPulls(p) and #p.after or 0, p.journal == false and " (bosses guessed, no journal entry)" or "")
	end
	return lines
end

function M:DebugInfo()
	local out = {}
	out[#out + 1] = format("MDT loaded: %s | window part loaded: %s | route data reachable: %s | hook: %s",
		tostring(MDT.IsLoaded()), tostring(XUI.IsAddOnLoaded(MDT.UI)), tostring(MDT.Table() ~= nil), tostring(MDT.door == true))
	local plan = CurrentPlan()
	local count, total = ReadForces()
	out[#out + 1] = format("forces now: %s of %s | in key: %s | finished: %s", tostring(count), tostring(total),
		tostring(XUI.KeyActive()), tostring(finished))
	if plan then
		out[#out + 1] = format("route here: %s, %d pulls, %d bosses", plan.route, HasPulls(plan) and #plan.after or 0, #plan.bosses)
		for _, b in ipairs(plan.bosses) do
			out[#out + 1] = format("   %s: before %d, pull %s%s%s", b.name, b.before, tostring(b.pull),
				b.enc and "" or " (no encounter id)", killed[b.ej] and " - killed" or "")
		end
	else
		out[#out + 1] = "route here: none (" .. NoPlanText() .. ")"
	end
	for _, line in ipairs(self:Status()) do out[#out + 1] = line end
	return out
end
