--------------------------------------------------------------------------------
-- Timer kit
-- The secret-safe cooldown icon the group modules share (Party Stops uses it;
-- Party Cooldowns still carries its own copy of the same machinery).
--
-- Why it looks the way it does: in a key the moment something happens is a
-- secret boolean. A boolean that may be secret can be turned into one of two
-- numbers with C_CurveUtil.EvaluateColorValueFromBoolean, a StatusBar draws a
-- secret value, and a frame anchored to the bar's fill moves with it. So when
-- the boolean flips, the current "time code" is written into a StatusBar. The
-- bar's min/max is slid once a second, which scrolls a strip of numbers
-- (cd ... 1) under a one-line window: the countdown text. A second bar moves a
-- grey veil off the icon when the countdown reaches zero. Two slots take turns
-- so a cooldown can restart before the old one has ended.
--
--   local kit = XUI.TimerKit.New(module)
--   kit.Now()                       whole seconds since this kit's epoch
--   kit.NewCell(parent) / kit.Scrap(cell)
--   kit.Dress(cell, def, look)      def = { id, show, cd }, look = { size, icon, border, timerText }
--   kit.Tracker(owner, key, cd)     a timer for one spell of one owner
--   kit.Feed(t, lit, n)             the boolean flipped (maybe secret) at second n
--   kit.StartPlain(t, n)            a known start (your own cast)
--   kit.Bind(t, cell) / kit.TickOne(t, cell, n) / kit.Push(t)
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI
local Style = XUI.Style
local Media = XUI.Media

local IsSecret = XUI.IsSecret
local EvalBool = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
local floor, ceil, abs = math.floor, math.ceil, math.abs
local mmax, mmin = math.max, math.min
local tconcat = table.concat
local format = string.format

local Kit = {}
XUI.TimerKit = Kit

local CODES, LINGER = 254, 4
local GREY = 0.5
local WHITE = [[Interface\Buttons\WHITE8X8]]
local DOOR_SLACK, DOOR_PASSES = 1e-6, 16
local DOOR_BYTES = { 0, 1, 48, 85, 127, 200, 254, 255 }

Kit.CODES, Kit.LINGER = CODES, LINGER

-- Everything stands on EvaluateColorValueFromBoolean handing back the numbers
-- it was given; a client that rounds them makes every timer wrong.
function Kit.TestDoor()
	local d = { state = "error" }
	if not EvalBool then
		d.detail = "the client has no EvaluateColorValueFromBoolean"
		return d
	end
	local off = 0
	for _, k in ipairs(DOOR_BYTES) do
		local want = k / 255
		local v = want
		for pass = 1, DOOR_PASSES do
			local ok, w
			if pass % 2 == 1 then ok, w = pcall(EvalBool, true, v, 0) else ok, w = pcall(EvalBool, false, 0, v) end
			if not ok then
				d.detail = tostring(w)
				return d
			end
			if IsSecret(w) then
				d.state = "hidden"
				return d
			end
			if type(w) ~= "number" then
				d.detail = "the answer was a " .. type(w) .. ", not a number"
				return d
			end
			v = w
			local gap = abs(v - want)
			if gap >= off then off, d.sent, d.got = gap, want, v end
		end
	end
	d.off = off
	d.state = off == 0 and "exact" or (off <= DOOR_SLACK and "close" or "coarse")
	return d
end

function Kit.DoorOpen(d) return d.state == "exact" or d.state == "close" or d.state == "hidden" end

function Kit.New(M, fault)
	local K = {}
	local layer, meter
	local metrics, strips = {}, {}
	local T0 = GetTime() - 1024

	local function Fault(err)
		if fault then fault(err) end
	end

	function K.Now() return floor(GetTime() - T0 + 0.5) end
	local Now = K.Now

	local function Unit(cd) return mmax(1, ceil(cd / CODES)) end
	K.Unit = Unit

	local function Ensure()
		if layer then return end
		layer = CreateFrame("Frame", nil, UIParent)
		layer:SetFrameStrata("MEDIUM")
		layer:SetSize(1, 1)
		layer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		meter = layer:CreateFontString(nil, "OVERLAY")
		meter:SetPoint("CENTER", layer, "CENTER", 0, 0)
		meter:SetAlpha(0)
	end
	K.Ensure = Ensure

	----------------------------------------------------------------------------
	-- Timer text metrics: the numbers are one FontString of "cd\n...\n1" scrolled
	-- under a window one line high, so the line height must be exact.
	----------------------------------------------------------------------------
	local function Height(text)
		meter:SetText(text)
		local h = meter:GetStringHeight()
		if type(h) ~= "number" or IsSecret(h) or h <= 0 then return nil end
		return h
	end

	local function LineMetrics(font, size, flags)
		local key = tostring(font) .. "|" .. size .. "|" .. flags
		local m = metrics[key]
		if m then return m[1], m[2] end
		meter:SetFont(font, size, flags)
		local one, nine = Height("0"), Height("0\n0\n0\n0\n0\n0\n0\n0\n0")
		if not (one and nine and nine > one) then return size, size end
		local step = (nine - one) / 8
		metrics[key] = { step, one }
		return step, one
	end

	local function StripText(cd)
		local s = strips[cd]
		if s then return s end
		local out = {}
		for r = cd, 1, -1 do
			out[#out + 1] = r >= 60 and format("%d:%02d", floor(r / 60), r % 60) or tostring(r)
		end
		s = tconcat(out, "\n")
		strips[cd] = s
		return s
	end

	----------------------------------------------------------------------------
	-- Cells
	----------------------------------------------------------------------------
	function K.NewCell(parent)
		Ensure()
		local c = CreateFrame("Frame", nil, parent)
		c:Hide()
		c.iconTex = c:CreateTexture(nil, "ARTWORK")
		c.border = Style:Border(c)
		c.clip = CreateFrame("Frame", nil, layer)
		c.clip:SetClipsChildren(true)
		c.clip:Hide()
		c.win = CreateFrame("Frame", nil, layer)
		c.win:SetClipsChildren(true)
		c.win:Hide()
		c.pos, c.fill, c.text, c.strip, c.veil, c.grey, c.gate = {}, {}, {}, {}, {}, {}, {}
		for k = 1, 2 do
			local pos = CreateFrame("StatusBar", nil, layer)
			pos:SetStatusBarTexture(WHITE)
			pos:SetStatusBarColor(0, 0, 0, 0)
			pos:SetOrientation("VERTICAL")
			pos:SetMinMaxValues(0, 1)
			pos:SetValue(1)
			local fill = pos:GetStatusBarTexture()
			local gate = CreateFrame("StatusBar", nil, layer)
			gate:SetStatusBarTexture(WHITE)
			gate:SetStatusBarColor(0, 0, 0, 0)
			gate:SetOrientation("VERTICAL")
			gate:SetMinMaxValues(0, 1)
			gate:SetValue(1)
			local text = CreateFrame("Frame", nil, c.win)
			text:SetAllPoints(c.win)
			text:SetAlpha(0)
			local strip = text:CreateFontString(nil, "OVERLAY")
			strip:SetJustifyH("CENTER")
			strip:SetPoint("BOTTOM", fill, "TOP", 0, 0)
			local veil = CreateFrame("Frame", nil, c.clip)
			veil:SetClipsChildren(true)
			veil:SetAlpha(0)
			local grey = veil:CreateTexture(nil, "ARTWORK")
			grey:SetAllPoints(c.clip)
			grey:SetDesaturated(true)
			grey:SetVertexColor(GREY, GREY, GREY)
			c.pos[k], c.fill[k], c.text[k], c.strip[k], c.gate[k], c.veil[k], c.grey[k] = pos, fill, text, strip, gate, veil, grey
		end
		return c
	end

	function K.Scrap(c)
		c:Hide()
		c.clip:Hide()
		c.win:Hide()
		for k = 1, 2 do
			c.pos[k]:Hide()
			c.gate[k]:Hide()
		end
	end

	-- Sizes and fonts of one cell. Everything depends on `sig`, so a refresh that
	-- changes nothing costs next to nothing.
	function K.Dress(c, def, look)
		local size = look.size or 36
		c:SetSize(size, size)
		c.border:Apply(look.border)
		local inset = c.border:GetInset()
		local level = c:GetFrameLevel()
		local tex = XUI.GetSpellIcon(def.show or def.id)
		local zoom = Style:Resolve("icon", look.icon).zoom
		c.iconTex:ClearAllPoints()
		c.iconTex:SetPoint("TOPLEFT", c, "TOPLEFT", inset, -inset)
		c.iconTex:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -inset, inset)
		c.iconTex:SetTexture(tex)
		Style:IconTexCoord(c.iconTex, size - 2 * inset, size - 2 * inset, zoom)
		c.clip:SetFrameLevel(level + 1)
		c.win:SetFrameLevel(level + 4)
		local f = Style:Resolve("font", look.timerText)
		local font, ts, flags = Media:Fetch("font", f.face), look.timerText.size or f.size or 12, Style:FontFlags(f)
		for k = 1, 2 do
			c.veil[k]:SetFrameLevel(level + 2)
			c.text[k]:SetFrameLevel(level + 5)
			c.grey[k]:SetTexture(tex)
			Style:IconTexCoord(c.grey[k], size - 2 * inset, size - 2 * inset, zoom)
			Style:ApplyFont(c.strip[k], look.timerText, ts)
			c.strip[k]:SetJustifyH("CENTER")
		end
		local step, one = LineMetrics(font, ts, flags)
		local sig = tconcat({ tostring(font), ts, flags, def.cd, size, inset, format("%.3f", step), format("%.3f", one) }, "|")
		if c.sig == sig then return end
		local cd, u = def.cd, Unit(def.cd)
		local line = mmin(one, step)
		local jump = size + 2
		c.clip:ClearAllPoints()
		c.clip:SetPoint("TOPLEFT", c, "TOPLEFT", inset, -inset)
		c.clip:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -inset, inset)
		c.win:ClearAllPoints()
		c.win:SetPoint("CENTER", c, "CENTER", 0, 0)
		c.win:SetSize(size + 6, line)
		c.line, c.seat = line, nil
		for k = 1, 2 do
			local pos, strip, veil, gate = c.pos[k], c.strip[k], c.veil[k], c.gate[k]
			local edge = gate:GetStatusBarTexture()
			pos:SetMinMaxValues(0, 1)
			pos:SetValue(1)
			pos:ClearAllPoints()
			pos:SetPoint("BOTTOM", c.win, "BOTTOM", 0, -(cd - 1 + u) * step)
			pos:SetSize(1, 255 * u * step)
			strip:SetText(StripText(cd))
			gate:SetMinMaxValues(0, 1)
			gate:SetValue(1)
			gate:ClearAllPoints()
			gate:SetPoint("BOTTOM", c.clip, "BOTTOM", 0, -(cd - 1 + u) * jump)
			gate:SetSize(1, 255 * u * jump)
			veil:ClearAllPoints()
			veil:SetPoint("BOTTOM", edge, "TOP", 0, -1)
			veil:SetPoint("TOP", edge, "TOP", 0, (cd - 1) * jump + size + 1)
			veil:SetWidth(size)
		end
		c.sig = sig
	end

	-- The text window sits on a pixel boundary so the numbers stay sharp.
	local function PerUnit(region)
		local es = region:GetEffectiveScale()
		local _, ph = (GetPhysicalScreenSize or function() end)()
		if type(es) ~= "number" or IsSecret(es) or es <= 0 or type(ph) ~= "number" or ph <= 0 then return nil end
		return es * ph / 768
	end

	local function SeatNow(c)
		local line, ppu = c.line, PerUnit(c)
		if not (line and ppu) then return end
		local _, y = c:GetCenter()
		local seat = 0.25 / ppu
		if type(y) == "number" and not IsSecret(y) then
			local base = (y - line / 2) * ppu
			if c.seat then
				local at = base + c.seat * ppu
				if abs(at - floor(at) - 0.25) < 0.1 then return end
			end
			local f = base - floor(base)
			seat = ((f < 0.75 and 0.25 or 1.25) - f) / ppu
		elseif c.seat then
			return
		end
		c.win:SetPoint("CENTER", c, "CENTER", 0, seat)
		c.seat = seat
	end

	function K.Seat(c)
		local ok, err = pcall(SeatNow, c)
		if not ok then Fault(err) end
	end

	----------------------------------------------------------------------------
	-- The timer. Per spell: a double-buffered pair of slots { c = code value,
	-- v = visible }, one epoch each, all values possibly secret.
	----------------------------------------------------------------------------
	local function Clear(t, n)
		local a, b = t.slot[1], t.slot[2]
		a.c, a.v, a.epoch = 1, 0, n
		b.c, b.v, b.epoch = 1, 0, n
		t.cur = 1
	end
	K.Clear = Clear

	-- A slot's epoch is renewed before its codes run out.
	local function Roll(t, n)
		local k = t.cur
		if n - t.slot[k].epoch < t.P then return false end
		k = 3 - k
		local sl = t.slot[k]
		sl.c, sl.v, sl.epoch = 1, 0, n
		t.cur = k
		return true
	end

	local function Stamp(t, n)
		local code = floor((n - t.slot[t.cur].epoch) / t.u)
		if code < 0 then code = 0 elseif code > CODES then code = CODES end
		return (255 - code) / 255
	end

	local function Left(t, sl, n)
		local code = 255 - floor(sl.c * 255 + 0.5)
		return t.cd - ((n - sl.epoch) - t.u * code)
	end
	K.Left = Left

	local function Range(c, k, sl, u, n)
		local m = (254 - (n - sl.epoch) / u) / 255
		c.pos[k]:SetMinMaxValues(m, m + 1)
		c.gate[k]:SetMinMaxValues(m, m + 1)
	end

	local function WriteSlot(c, k, sl, u, n)
		c.pos[k]:SetMinMaxValues(0, 1)
		c.pos[k]:SetValue(sl.c)
		c.gate[k]:SetMinMaxValues(0, 1)
		c.gate[k]:SetValue(sl.c)
		c.text[k]:SetAlpha(sl.v)
		c.veil[k]:SetAlpha(sl.v)
		Range(c, k, sl, u, n)
	end

	local function Push(t)
		local c = t.cell
		if not c then return end
		local n = Now()
		for k = 1, 2 do
			local ok, err = pcall(WriteSlot, c, k, t.slot[k], t.u, n)
			if not ok then Fault(err) end
		end
	end
	K.Push = Push

	local function StartPlain(t, n)
		Roll(t, n)
		local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
		sl.c, sl.v, other.v = Stamp(t, n), 1, 0
	end
	K.StartPlain = StartPlain

	-- A timer for one spell of one owner; rebuilt when the length changes.
	function K.Tracker(owner, key, cd)
		local t = owner.tr[key]
		if not t then
			t = { slot = { {}, {} }, primed = false }
			owner.tr[key] = t
		end
		if t.cd ~= cd then
			t.cd, t.u, t.loop = cd, Unit(cd), nil
			t.P = CODES * t.u
			t.def = { id = key, show = key, cd = cd }
			Clear(t, Now())
			t.primed, t.fresh = false, true
		end
		return t
	end

	-- A preview timer: part-way through its cooldown, restarting when it ends.
	function K.Seed(t, frac, n)
		if frac >= 1 then return end
		local began = n - floor(t.cd * frac)
		Clear(t, began - 1)
		StartPlain(t, began)
		t.loop = true
	end

	-- A cell takes over a timer.
	function K.Bind(t, c)
		local old = c.t
		if old and old ~= t and old.cell == c then old.cell = nil end
		c.t, t.cell = t, c
		Push(t)
	end

	function K.Loose(c)
		local old = c.t
		if old and old.cell == c then old.cell = nil end
		c.t, c.m = nil, nil
	end

	-- A choice between two numbers by a boolean that may be secret is
	-- EvalBool; this says whether the boolean is readable and what it is.
	local function State(v)
		if IsSecret(v) then return false, false end
		return true, v and true or false
	end

	-- The boolean `lit` (is the effect up?) was read at second n.
	function K.Feed(t, lit, n)
		if t.primed then
			if Roll(t, n) then Push(t) end
			local prev = t.prev
			local curKnown, up = State(lit)
			local prevKnown, was = State(prev)
			local idle = (curKnown and not up) or (prevKnown and was)
			if not idle then
				if curKnown and prevKnown then
					StartPlain(t, n)
				else
					local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
					-- a start is "lit now, not lit before"
					local function Edge(a, b) return EvalBool(lit, EvalBool(prev, a, b), a) end
					sl.c = Edge(sl.c, Stamp(t, n))
					sl.v = Edge(sl.v, 1)
					other.v = Edge(other.v, 0)
				end
				Push(t)
			end
		end
		t.prev, t.primed = lit, true
	end

	-- One second of housekeeping for a bound timer: renew the epoch, slide the
	-- ranges, end a timer that has run out. Returns whether anything runs.
	function K.TickOne(t, c, n)
		if Roll(t, n) then Push(t) end
		local running = false
		for k = 1, 2 do
			local sl = t.slot[k]
			if IsSecret(sl.v) or sl.v ~= 0 then
				if not IsSecret(sl.v) and not IsSecret(sl.c) and Left(t, sl, n) <= -LINGER then
					sl.v = 0
					if t.loop then StartPlain(t, n) end
					Push(t)
				else
					local ok, err = pcall(Range, c, k, sl, t.u, n)
					if not ok then Fault(err) end
					running = true
				end
			end
		end
		if running then K.Seat(c) end
		return running
	end

	-- Text of a timer for the debug report.
	function K.State(t, n)
		local state = "ready"
		for k = 1, 2 do
			local sl = t.slot[k]
			if IsSecret(sl.v) or IsSecret(sl.c) then
				state = "timer hidden"
			elseif sl.v ~= 0 and Left(t, sl, n) > 0 and state == "ready" then
				state = format("%d s left", Left(t, sl, n))
			end
		end
		return state
	end

	return K
end
