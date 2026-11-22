-- Balanced, cinematic sky lighting + a smooth day/night cycle.
--
-- v1.1: the old preset was far too bright (exposure +0.25, strong bloom,
-- saturated grading). Now exposure is slightly negative, bloom only catches
-- truly bright things (neon, sun), grading is gentle.
--
-- The cycle runs on the server (ClockTime replicates to everyone). Every
-- update blends between keyframes below, so sky haze, ambient light, tint and
-- the sky clouds change colour through dawn → day → dusk → night.
-- workspace attribute "IsNight" (true/false) tells other systems the time of day.
--
-- To tune by hand: set the attribute ManualLighting = true on Lighting
-- (the cycle then stops touching it).
-- Manual Studio step: Lighting → Technology = Future.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local LightingService = {}

local function getOrCreate(parent: Instance, className: string, name: string)
	local obj = parent:FindFirstChild(name) or parent:FindFirstChildOfClass(className)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

local rgb = Color3.fromRGB

-- Keyframes by ClockTime (0-24). Blended linearly, wrapping at midnight.
local KEYS = {
	{ T = 0, Bright = 0.53, Exposure = -0.45, Ambient = rgb(40, 45, 75), Outdoor = rgb(60, 65, 105),
		Haze = rgb(60, 70, 120), Decay = rgb(30, 30, 70), Tint = rgb(205, 215, 255), Clouds = rgb(90, 95, 140) },
	{ T = 5.5, Bright = 0.79, Exposure = -0.4, Ambient = rgb(70, 60, 90), Outdoor = rgb(110, 90, 130),
		Haze = rgb(160, 120, 170), Decay = rgb(90, 70, 130), Tint = rgb(240, 220, 245), Clouds = rgb(200, 160, 200) },
	{ T = 7, Bright = 1.58, Exposure = -0.3, Ambient = rgb(120, 105, 115), Outdoor = rgb(170, 145, 150),
		Haze = rgb(255, 200, 180), Decay = rgb(170, 130, 170), Tint = rgb(255, 238, 225), Clouds = rgb(255, 220, 215) },
	{ T = 12, Bright = 1.85, Exposure = -0.3, Ambient = rgb(120, 125, 140), Outdoor = rgb(150, 160, 180),
		Haze = rgb(200, 220, 245), Decay = rgb(130, 160, 210), Tint = rgb(250, 250, 255), Clouds = rgb(250, 252, 255) },
	{ T = 17, Bright = 1.67, Exposure = -0.3, Ambient = rgb(125, 115, 125), Outdoor = rgb(165, 145, 155),
		Haze = rgb(255, 210, 200), Decay = rgb(170, 140, 200), Tint = rgb(255, 242, 235), Clouds = rgb(255, 230, 230) },
	{ T = 19, Bright = 0.97, Exposure = -0.35, Ambient = rgb(95, 75, 105), Outdoor = rgb(140, 100, 135),
		Haze = rgb(240, 140, 150), Decay = rgb(110, 80, 150), Tint = rgb(255, 225, 225), Clouds = rgb(240, 160, 170) },
	{ T = 20.5, Bright = 0.62, Exposure = -0.45, Ambient = rgb(50, 50, 85), Outdoor = rgb(70, 70, 115),
		Haze = rgb(80, 80, 140), Decay = rgb(40, 40, 90), Tint = rgb(210, 215, 255), Clouds = rgb(100, 100, 150) },
}

local function lerpColor(a: Color3, b: Color3, t: number)
	return a:Lerp(b, t)
end

local function sample(clock: number)
	local prev, nextKey = KEYS[#KEYS], KEYS[1]
	for i, k in KEYS do
		if k.T <= clock then
			prev = k
			nextKey = KEYS[i + 1] or KEYS[1]
		end
	end
	local span = (nextKey.T - prev.T) % 24
	local t = span > 0 and ((clock - prev.T) % 24) / span or 0
	local out = {}
	for key, v in prev do
		if key ~= "T" then
			out[key] = typeof(v) == "Color3" and lerpColor(v, nextKey[key], t) or v + (nextKey[key] - v) * t
		end
	end
	return out
end

local atmosphere, cc, clouds

function LightingService.Apply()
	if Lighting:GetAttribute("ManualLighting") then
		return
	end
	Lighting.GeographicLatitude = 25
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4

	atmosphere = getOrCreate(Lighting, "Atmosphere", "PS_Atmosphere")
	atmosphere.Density = 0.26
	atmosphere.Offset = 0.15
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.1

	clouds = getOrCreate(workspace.Terrain, "Clouds", "PS_SkyClouds")
	clouds.Cover = 0.55
	clouds.Density = 0.45

	-- Bloom only on really bright pixels (neon, sun) — no more washed-out screen
	local bloom = getOrCreate(Lighting, "BloomEffect", "PS_Bloom")
	-- v2.22: stronger glow on HDR VFX (FxKit particles use Brightness 2.5-4)
	bloom.Intensity = 0.55 -- v2.32 director: a bit less bright overall
	bloom.Size = 28
	bloom.Threshold = 1.8

	local sunRays = getOrCreate(Lighting, "SunRaysEffect", "PS_SunRays")
	sunRays.Intensity = 0.05
	sunRays.Spread = 0.7

	cc = getOrCreate(Lighting, "ColorCorrectionEffect", "PS_ColorCorrection")
	cc.Brightness = 0
	cc.Contrast = 0.06
	cc.Saturation = 0.08

	local dof = getOrCreate(Lighting, "DepthOfFieldEffect", "PS_DepthOfField")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 80
	dof.InFocusRadius = 120
	dof.NearIntensity = 0

	local sky = getOrCreate(Lighting, "Sky", "PS_Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 10
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true

	Lighting.ClockTime = 9 -- start in the morning
	LightingService.Update(Lighting.ClockTime)
	workspace:SetAttribute("IsNight", false)
end

-- Blend every colour for the given time of day
function LightingService.Update(clock: number)
	if Lighting:GetAttribute("ManualLighting") or not atmosphere then
		return
	end
	local s = sample(clock)
	Lighting.Brightness = s.Bright
	Lighting.ExposureCompensation = s.Exposure
	Lighting.Ambient = s.Ambient
	Lighting.OutdoorAmbient = s.Outdoor
	atmosphere.Color = s.Haze
	atmosphere.Decay = s.Decay
	cc.TintColor = s.Tint
	clouds.Color = s.Clouds
end

function LightingService.IsNight(clock: number): boolean
	return clock >= Config.NightStart or clock < Config.NightEnd
end

-- Day/night cycle: advance the clock smoothly; colours refresh 4×/s
function LightingService.StartCycle()
	local minutesPerSecond = 24 * 60 / Config.DayLength
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local dt = now - last
			last = now
			local clock = (Lighting.ClockTime + dt * minutesPerSecond / 60) % 24
			Lighting.ClockTime = clock
			LightingService.Update(clock)
			local night = LightingService.IsNight(clock)
			if workspace:GetAttribute("IsNight") ~= night then
				workspace:SetAttribute("IsNight", night)
			end
		end
	end)
end

return LightingService
