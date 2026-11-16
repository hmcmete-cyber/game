-- Pastel dream sky: soft golden-hour sun, lilac/peach haze, real volumetric
-- sky clouds (Terrain Clouds) with sun rays slipping between them.
-- Runs once at server start. To tune by hand instead, set the attribute
-- ManualLighting = true on the Lighting service.
--
-- Manual Studio steps (can't be done from scripts):
--   Lighting → Technology = Future
--   Optional custom skybox: Lighting → Sky → set SkyboxBk/Dn/Ft/Lf/Rt/Up to a
--   pastel skybox from the Creator Store (any 6-image skybox works).

local Lighting = game:GetService("Lighting")

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

function LightingService.Apply()
	if Lighting:GetAttribute("ManualLighting") then
		return
	end

	-- Golden hour, warm and soft
	Lighting.ClockTime = 17.3
	Lighting.GeographicLatitude = 20
	Lighting.Brightness = 2.6
	Lighting.ExposureCompensation = 0.25
	Lighting.Ambient = Color3.fromRGB(150, 135, 175)
	Lighting.OutdoorAmbient = Color3.fromRGB(190, 170, 210)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.5

	-- Pastel haze: peach near the horizon, lilac in the distance
	local atmosphere = getOrCreate(Lighting, "Atmosphere", "PS_Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(255, 214, 226)
	atmosphere.Decay = Color3.fromRGB(176, 150, 230)
	atmosphere.Glare = 0.6
	atmosphere.Haze = 1.8

	-- Real 3D sky clouds — sun rays shine through the gaps
	local clouds = getOrCreate(workspace.Terrain, "Clouds", "PS_SkyClouds")
	clouds.Cover = 0.62
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 236, 245)

	local bloom = getOrCreate(Lighting, "BloomEffect", "PS_Bloom")
	bloom.Intensity = 0.8
	bloom.Size = 32
	bloom.Threshold = 1.3

	local sunRays = getOrCreate(Lighting, "SunRaysEffect", "PS_SunRays")
	sunRays.Intensity = 0.12
	sunRays.Spread = 0.85

	-- Candy-pastel grade: a touch brighter, softer contrast, pink-gold tint
	local cc = getOrCreate(Lighting, "ColorCorrectionEffect", "PS_ColorCorrection")
	cc.Brightness = 0.04
	cc.Contrast = 0.06
	cc.Saturation = 0.22
	cc.TintColor = Color3.fromRGB(255, 240, 245)

	local dof = getOrCreate(Lighting, "DepthOfFieldEffect", "PS_DepthOfField")
	dof.FarIntensity = 0.16
	dof.FocusDistance = 70
	dof.InFocusRadius = 100
	dof.NearIntensity = 0

	local sky = getOrCreate(Lighting, "Sky", "PS_Sky")
	sky.SunAngularSize = 16
	sky.MoonAngularSize = 9
	sky.StarCount = 1500
	sky.CelestialBodiesShown = true
end

return LightingService
