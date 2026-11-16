-- Dynamic background music.
--   On the hub / at your base  → calm "Hub" track
--   Up in the cloud zones      → upbeat "Sky" track
--   At night                   → the *Night versions, if you set them
-- Tracks crossfade smoothly. All IDs and volumes live in Shared/Audio.luau.
-- Volumes go through SoundGroups in SoundService ("Music", "SFX"), so one
-- number changes the whole category. Press M to mute / unmute music.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Audio = require(ReplicatedStorage.Shared.Audio)

local SoundManager = {}

local player = Players.LocalPlayer
local groups = {} -- [name] = SoundGroup
local tracks = {} -- [key] = Sound
local current: string? = nil
local muted = false

local function group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	g.Volume = Audio.Groups[name] or 1
	groups[name] = g
	return g
end

-- Use this for any sound effect so it follows the SFX volume
function SoundManager.Group(name: string): SoundGroup
	return groups[name] or group(name)
end

local function track(key: string): Sound?
	local info = Audio.Music[key]
	if not info or info.SoundId == "" then
		return nil
	end
	if not tracks[key] then
		local s = Instance.new("Sound")
		s.Name = "Music_" .. key
		s.SoundId = info.SoundId
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = groups.Music
		s.Parent = SoundService
		tracks[key] = s
	end
	return tracks[key]
end

local function fadeTo(s: Sound, volume: number, stopAfter: boolean)
	local t = TweenService:Create(s, TweenInfo.new(Audio.FadeTime, Enum.EasingStyle.Sine), { Volume = volume })
	if stopAfter then
		t.Completed:Connect(function()
			if s.Volume <= 0.001 then
				s:Pause()
			end
		end)
	end
	t:Play()
end

-- Which track should play right now?
local function wantedKey(): string
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local inSky = root ~= nil and root.Position.Y > Audio.SkyHeight
	local base = inSky and "Sky" or "Hub"
	if workspace:GetAttribute("IsNight") and track(base .. "Night") then
		return base .. "Night"
	end
	return base
end

local function switchTo(key: string)
	if key == current then
		return
	end
	local old = current and tracks[current]
	current = key
	if old then
		fadeTo(old, 0, true)
	end
	local new = track(key)
	if new then
		if not new.IsPlaying then
			new:Resume()
			if not new.IsPlaying then
				new:Play()
			end
		end
		fadeTo(new, Audio.Music[key].Volume, false)
	end
end

function SoundManager.Start()
	group("Music")
	group("SFX")

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			muted = not muted
			groups.Music.Volume = muted and 0 or Audio.Groups.Music
		end
	end)

	task.spawn(function()
		while true do
			switchTo(wantedKey())
			task.wait(0.5)
		end
	end)
end

return SoundManager
