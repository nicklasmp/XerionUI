--------------------------------------------------------------------------------
-- XerionUI - Core/Inspect.lua
-- The inspect queue the group modules share: NotifyInspect is throttled by the
-- client, so wanted units wait in a queue that a slow ticker drains one at a
-- time, never while the inspect window is open.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local STEP = 1 -- seconds between queue passes
local GAP = 2  -- minimum seconds between two NotifyInspect calls

-- XUI.NewInspectQueue(module, try) -> queue
--   try(item, queue) runs when an item reaches the front; it returns true to
--   put the item back (still waiting for an answer) and false to drop it.
--   queue:Add(item)   waits once per item, starts the ticker
--   queue:Notify(unit) asks the client to inspect (stamps the gap)
--   queue:Stop()      forgets everything (call on enable and disable)
function XUI.NewInspectQueue(M, try)
	local q, items, ticker, lastAt = {}, {}, nil, 0

	function q:Stop()
		wipe(items)
		if ticker then M:CancelTicker(ticker) ticker = nil end
	end

	local function Step()
		if #items == 0 or not M.running then return q:Stop() end
		if InspectFrame and InspectFrame:IsShown() then return end
		if GetTime() - lastAt < GAP then return end
		local item = table.remove(items, 1)
		if try(item, q) then items[#items + 1] = item end
	end

	function q:Add(item)
		for i = 1, #items do
			if items[i] == item then return end
		end
		items[#items + 1] = item
		if not ticker then ticker = M:NewTicker(STEP, Step) end
	end

	function q:Notify(unit)
		lastAt = GetTime()
		if NotifyInspect then pcall(NotifyInspect, unit) end
	end

	return q
end
