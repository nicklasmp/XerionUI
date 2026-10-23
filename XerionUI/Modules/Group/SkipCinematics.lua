--------------------------------------------------------------------------------
-- Skip Cinematic (Kings' Rest)
-- Skips the cinematic that plays inside Kings' Rest, so the run is not held up
-- by a cutscene. Listed under that dungeon in the sidebar; the module's own
-- switch turns it on and off.
--
-- Both kinds of scene are handled: in-engine cinematics (CINEMATIC_START) and
-- pre-rendered movies (PLAY_MOVIE). Everything else, in or out of Kings' Rest,
-- plays as normal.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local IsSecret = XUI.IsSecret

local DUNGEON = { id = 1762, name = "Kings' Rest" } -- instance ID

local M = XUI:NewModule("SkipCinematics", {
	name = "Skip Cinematic",
	desc = "Skips the cinematic that plays inside Kings' Rest.",
	category = "dungeon",
	dungeon = DUNGEON.name,
	icon = [[Interface\Icons\inv_misc_book_09]],
	order = 66,
	defaults = {
		announce = true,
	},
})

local function Say(text)
	if M.db.announce then M:Print(text) end
end

-- true while inside Kings' Rest
local function Inside()
	local ok, _, kind, _, _, _, _, _, instanceID = pcall(GetInstanceInfo)
	if not ok or IsSecret(kind) or IsSecret(instanceID) then return false end
	return kind ~= "none" and instanceID == DUNGEON.id
end

local function SkipCinematic()
	if not Inside() then return end
	local done = false
	if type(_G.CinematicFrame_CancelCinematic) == "function" then
		done = pcall(_G.CinematicFrame_CancelCinematic)
	end
	if not done and _G.CanCancelScene and _G.CanCancelScene() then
		done = pcall(_G.CancelScene)
	end
	if not done and _G.StopCinematic then
		done = pcall(_G.StopCinematic)
	end
	Say(done and ("skipped the cinematic in " .. DUNGEON.name .. ".")
		or ("could not skip the cinematic in " .. DUNGEON.name .. "."))
end

local function SkipMovie()
	if not Inside() then return end
	local frame = _G.MovieFrame
	local done = false
	if frame and frame.StopMovie then
		done = pcall(frame.StopMovie, frame)
	end
	if not done and _G.GameMovieFinished then
		done = pcall(_G.GameMovieFinished)
		if frame and frame.Hide then pcall(frame.Hide, frame) end
	end
	Say(done and ("skipped the movie in " .. DUNGEON.name .. ".")
		or ("could not skip the movie in " .. DUNGEON.name .. "."))
end

function M:OnEnable()
	-- one frame later: the cinematic frame is not set up yet when the event fires
	self:RegisterEvent("CINEMATIC_START", function(m) m:After(0, SkipCinematic) end)
	self:RegisterEvent("PLAY_MOVIE", function(m) m:After(0, SkipMovie) end)
end

function M:DebugInfo()
	return { ("inside %s: %s"):format(DUNGEON.name, tostring(Inside())) }
end
