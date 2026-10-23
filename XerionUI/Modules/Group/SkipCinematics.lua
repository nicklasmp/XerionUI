--------------------------------------------------------------------------------
-- Skip Cinematics
-- Skips the in-game cinematics and movies that play inside chosen dungeons
-- (Kings' Rest has one), so the run is not held up by a cutscene.
--
-- Only dungeons in the built-in list are touched, and each can be switched off.
-- Both kinds of scene are handled: in-engine cinematics (CINEMATIC_START) and
-- pre-rendered movies (PLAY_MOVIE). Everything else, in or out of instances,
-- plays as normal.
--------------------------------------------------------------------------------
local XUI = select(2, ...).XUI

local IsSecret = XUI.IsSecret

-- instanceID = dungeon. Add a line to skip a cinematic in another dungeon.
local DUNGEONS = {
	{ id = 1762, name = "Kings' Rest" },
}
local BY_ID = {}
for _, d in ipairs(DUNGEONS) do BY_ID[d.id] = d end

local M = XUI:NewModule("SkipCinematics", {
	name = "Skip Cinematics",
	desc = "Skips the cinematic that plays inside chosen dungeons, such as Kings' Rest.",
	category = "misc",
	icon = [[Interface\Icons\inv_misc_book_09]],
	order = 66,
	defaults = {
		off = {}, -- [instanceID] = true: a dungeon switched off
		announce = true,
	},
})

M.DUNGEONS = DUNGEONS

local function Say(text)
	if M.db.announce then M:Print(text) end
end

function M:IsOn(id)
	return BY_ID[id] ~= nil and not (self.db.off and self.db.off[id])
end

function M:SetOn(id, on)
	self.db.off = self.db.off or {}
	self.db.off[id] = (not on) or nil
end

-- The dungeon we are in if it is listed and switched on, else nil.
local function Current()
	local ok, _, kind, _, _, _, _, _, instanceID = pcall(GetInstanceInfo)
	if not ok or IsSecret(kind) or IsSecret(instanceID) then return end
	if kind == "none" or type(instanceID) ~= "number" then return end
	if M:IsOn(instanceID) then return BY_ID[instanceID] end
end

local function SkipCinematic()
	local dungeon = Current()
	if not dungeon then return end
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
	Say(done and ("skipped the cinematic in " .. dungeon.name .. ".")
		or ("could not skip the cinematic in " .. dungeon.name .. "."))
end

local function SkipMovie()
	local dungeon = Current()
	if not dungeon then return end
	local frame = _G.MovieFrame
	local done = false
	if frame and frame.StopMovie then
		done = pcall(frame.StopMovie, frame)
	end
	if not done and _G.GameMovieFinished then
		done = pcall(_G.GameMovieFinished)
		if frame and frame.Hide then pcall(frame.Hide, frame) end
	end
	Say(done and ("skipped the movie in " .. dungeon.name .. ".")
		or ("could not skip the movie in " .. dungeon.name .. "."))
end

function M:OnEnable()
	-- one frame later: the cinematic frame is not set up yet when the event fires
	self:RegisterEvent("CINEMATIC_START", function(m) m:After(0, SkipCinematic) end)
	self:RegisterEvent("PLAY_MOVIE", function(m) m:After(0, SkipMovie) end)
end

function M:DebugInfo()
	local lines = {}
	for _, d in ipairs(DUNGEONS) do
		lines[#lines + 1] = ("%s (%d): %s"):format(d.name, d.id, self:IsOn(d.id) and "on" or "off")
	end
	local dungeon = Current()
	lines[#lines + 1] = ("in a skipped dungeon: %s"):format(dungeon and dungeon.name or "no")
	return lines
end
