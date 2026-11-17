-- Client side of world events + a light level-of-detail manager.
--
-- Events (state from workspace attributes set by the server EventService):
--   * an event pill under the zone pill with the time left
--   * Acid Rain: green rain around you + green tint while you stand in the
--     targeted biome; a "SHELTERED" tag when something is above you
--   * Meteor Shower / Fog: visuals come from the server (meteors, atmosphere)
--
-- LOD: decorative particle emitters and lights (inside workspace.Map) switch
-- off when they are far from the camera; StreamingEnabled handles parts.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BiomeMap = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BiomeMap"))

local WorldFx = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local EVENT_TEXT = {
	MeteorShower = { "METEOR SHOWER", Color3.fromRGB(255, 160, 80) },
	AcidRain = { "ACID RAIN", Color3.fromRGB(170, 255, 90) },
	Fog = { "FOG BANK", Color3.fromRGB(200, 210, 230) },
}
local BIOME_TEXT = {
	Plateau = "Meadows", Mountains = "Mountains", Mushroom = "Mushrooms", Marsh = "Marshes",
	Canyon = "Canyons", Volcanic = "Caldera", Coast = "Coast",
}

local LOD_PARTICLES = 380 -- studs
local LOD_LIGHTS = 260

------------------------------------------------------------------------

local function groundBiome(root: BasePart): string?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local info = BiomeMap.ZoneOfHit(workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params))
	return info and info.Biome or nil
end

local function sheltered(root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = false
	local ignore = { player.Character }
	local map = workspace:FindFirstChild("Map")
	for _, n in { "Hazards", "Zones", "AirColumns" } do
		local f = map and map:FindFirstChild(n)
		if f then
			table.insert(ignore, f)
		end
	end
	local weather = workspace:FindFirstChild("Weather")
	if weather then
		table.insert(ignore, weather)
	end
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(root.Position + Vector3.new(0, 3, 0), Vector3.new(0, 120, 0), params) ~= nil
end

local function makeUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WorldEvent"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	local pill = Instance.new("TextLabel")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 92)
	pill.Size = UDim2.fromOffset(300, 30)
	pill.BackgroundColor3 = Color3.fromRGB(16, 27, 48)
	pill.BackgroundTransparency = 0.12
	pill.Font = Enum.Font.GothamBold
	pill.TextSize = 15
	pill.TextColor3 = Color3.new(1, 1, 1)
	pill.Visible = false
	pill.Parent = gui
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Parent = pill
	gui.Parent = player:WaitForChild("PlayerGui")
	return pill, stroke
end

local function makeRain(): (BasePart, ParticleEmitter)
	local p = Instance.new("Part")
	p.Name = "AcidRainFx"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(90, 1, 90)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(170, 255, 90))
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(0.25)
	e.Lifetime = NumberRange.new(1, 1.4)
	e.Rate = 0
	e.Speed = NumberRange.new(60, 70)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(3, 3)
	e.Parent = p
	p.Parent = workspace.CurrentCamera
	return p, e
end

------------------------------------------------------------------------
-- LOD: track decorative emitters/lights under workspace.Map
------------------------------------------------------------------------
local lodItems: { [Instance]: { Base: boolean, Kind: string } } = {}

local function lodTrack(inst: Instance)
	if inst:IsA("ParticleEmitter") then
		lodItems[inst] = { Base = inst.Enabled, Kind = "P" }
	elseif inst:IsA("PointLight") or inst:IsA("SpotLight") then
		lodItems[inst] = { Base = inst.Enabled, Kind = "L" }
	end
end

local function lodStep()
	local camPos = camera.CFrame.Position
	for inst, info in lodItems do
		if not inst.Parent then
			lodItems[inst] = nil
			continue
		end
		local parent = inst.Parent
		local pos = parent:IsA("BasePart") and parent.Position or (parent:IsA("Attachment") and parent.WorldPosition)
		if pos then
			local limit = info.Kind == "P" and LOD_PARTICLES or LOD_LIGHTS
			local want = info.Base and (pos - camPos).Magnitude < limit;
			(inst :: any).Enabled = want
		end
	end
end

------------------------------------------------------------------------

function WorldFx.Start()
	local pill, stroke = makeUi()
	local rainPart, rain = makeRain()
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "AcidTint"
	tint.Enabled = false
	tint.TintColor = Color3.fromRGB(215, 255, 200)
	tint.Parent = Lighting

	-- LOD tracking
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local function scope(inst: Instance)
			local decor = map:FindFirstChild("Decor")
			local continent = map:FindFirstChild("Continent")
			local abyss = map:FindFirstChild("Abyss")
			return (decor and inst:IsDescendantOf(decor)) or (continent and inst:IsDescendantOf(continent))
				or (abyss and inst:IsDescendantOf(abyss))
		end
		for _, d in map:GetDescendants() do
			if scope(d) then
				lodTrack(d)
			end
		end
		map.DescendantAdded:Connect(function(d)
			if scope(d) then
				lodTrack(d)
			end
		end)
		while true do
			task.wait(0.5)
			lodStep()
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			rainPart.CFrame = CFrame.new(root.Position + Vector3.new(0, 40, 0))
		end
		if acc < 0.25 then
			return
		end
		acc = 0

		local event = workspace:GetAttribute("Event") or ""
		local info = EVENT_TEXT[event]
		if info then
			local left = math.floor(math.max(0, (workspace:GetAttribute("EventEnds") or 0) - workspace:GetServerTimeNow()))
			local biome = workspace:GetAttribute("EventBiome") or ""
			local where = BIOME_TEXT[biome] and (" - " .. BIOME_TEXT[biome]) or ""
			pill.Text = string.format("%s%s  %d:%02d", info[1], where, left // 60, left % 60)
			pill.TextColor3 = info[2]
			stroke.Color = info[2]
			pill.Visible = true
		else
			pill.Visible = false
		end

		local inAcid = event == "AcidRain" and root ~= nil and groundBiome(root) == workspace:GetAttribute("EventBiome")
		rain.Rate = inAcid and 500 or 0
		tint.Enabled = inAcid
		if inAcid and root then
			local safe = player:GetAttribute("PoisonImmune") or sheltered(root)
			pill.Text ..= safe and "  [SHELTERED]" or "  [EXPOSED]"
		end
	end)
end

return WorldFx
