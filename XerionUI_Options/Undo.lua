--------------------------------------------------------------------------------
-- XerionUI_Options - Undo.lua
-- Remembers the last changes made with the controls so a slip of a slider or a
-- colour can be taken back from the Undo button in the window header. Every
-- control writes through O:SetValue, which calls Capture before and Push after.
-- A drag of one control (many writes in a row) counts as one step.
--------------------------------------------------------------------------------
local XUI = _G.XerionUI
local O = XUI and XUI.Options
if not O then return end

local U = { stack = {}, LIMIT = 50, MERGE = 1.2, listeners = {} }
O.Undo = U

local function Copy(v)
	if type(v) == "table" then return XUI.CopyTable(v) end
	return v
end

-- The value before a write; wrapped so a nil value is still "something".
function U.Capture(desc, ctx)
	local ok, v = pcall(O.GetValue, O, desc, ctx)
	if not ok then return nil end
	return { value = Copy(v) }
end

local function Notify()
	for _, fn in ipairs(U.listeners) do fn() end
end

function U.OnChange(fn) U.listeners[#U.listeners + 1] = fn end

function U.Push(desc, ctx, before, after)
	if not before then return end
	if type(after) ~= "table" and before.value == after then return end
	local now = GetTime()
	local top = U.stack[#U.stack]
	if top and top.desc == desc and top.ctx == ctx and now - top.time < U.MERGE then
		top.time = now -- the same control, still being dragged: keep the first "before"
		Notify()
		return
	end
	U.stack[#U.stack + 1] = { desc = desc, ctx = ctx, before = before, time = now }
	if #U.stack > U.LIMIT then table.remove(U.stack, 1) end
	Notify()
end

function U.Count() return #U.stack end

-- Text for the button's tooltip: what the next step would take back.
function U.Describe()
	local top = U.stack[#U.stack]
	if not top then return nil end
	local label = O.ResolveValue(top.desc.label or top.desc.text, top.ctx)
	return type(label) == "string" and label or "last change"
end

function U.Undo()
	local top = table.remove(U.stack)
	if not top then return end
	O:SetValue(top.desc, top.ctx, Copy(top.before.value), true)
	Notify()
	O:RefreshPageHead()
end

function U.Clear()
	wipe(U.stack)
	Notify()
end
