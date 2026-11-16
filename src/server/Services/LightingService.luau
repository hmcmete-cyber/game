-- "High-graphics" sky look: warm late-afternoon sun above the clouds.
-- Runs once at server start. To tune lighting by hand in Studio instead,
-- set the attribute ManualLighting = true on the Lighting service.
--
-- Note: Lighting.Technology can't be set from scripts. In Studio select
-- Lighting → Properties → Technology = Future (best shadows / lights).

local Lighting = game:GetService("Lighting")

local LightingService = {}

local function getOrCreate(className: string, name: string)
	local obj = Lighting:FindFirstChild(name)
	if not obj then
		-- reuse an existing effect of the same class if Studio already has one
		obj = Lighting:FindFirstChildOfClass(className)
	end
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = Lighting
	end
	return obj
end

function LightingService.Apply()
	if Lighting:GetAttribute("ManualLighting") then
		return
	end

	-- Soft golden sun
	Lighting.ClockTime = 16.6
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = 0.15
	Lighting.Ambient = Color3.fromRGB(105, 110, 135)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 155, 180)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35

	-- Dreamy sky haze
	local atmosphere = getOrCreate("Atmosphere", "PS_Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(205, 222, 255)
	atmosphere.Decay = Color3.fromRGB(120, 150, 205)
	atmosphere.Glare = 0.45
	atmosphere.Haze = 1.4

	-- Glow on neon / bright things (crystals, shiny clouds)
	local bloom = getOrCreate("BloomEffect", "PS_Bloom")
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.4

	local sunRays = getOrCreate("SunRaysEffect", "PS_SunRays")
	sunRays.Intensity = 0.07
	sunRays.Spread = 0.75

	-- Slightly warmer, punchier colours
	local cc = getOrCreate("ColorCorrectionEffect", "PS_ColorCorrection")
	cc.Brightness = 0.03
	cc.Contrast = 0.1
	cc.Saturation = 0.18
	cc.TintColor = Color3.fromRGB(255, 247, 238)

	-- Gentle far blur: distant islands look dreamy, gameplay stays sharp
	local dof = getOrCreate("DepthOfFieldEffect", "PS_DepthOfField")
	dof.FarIntensity = 0.18
	dof.FocusDistance = 60
	dof.InFocusRadius = 90
	dof.NearIntensity = 0

	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.Name = "PS_Sky"
		sky.SunAngularSize = 14
		sky.Parent = Lighting
	end
end

return LightingService
