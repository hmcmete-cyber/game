-- Hazard gates (Map/Hazards/*, attribute HazardType):
--   "Ice"      Gate 1 · slippery, you lose control (client Movement.luau)
--   "River"    Gate 2 · electric river that pulses Calm → Warn → Shock.
--              Calm = a bit slow. Shock = very slow + damage. Time your crossing!
--              (attribute State is set here; Storm Charm = immune)
--   "Storm"    Gate 3 · narrow bridge: lightning strikes random spots
--              (red warning circle first) + side wind (client)
--   "Electric" always-on electric ground (slow + damage)
-- Carrying a cloud makes every hazard worse.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local HazardService = {}

local MapService, Remotes

-- Is a position standing on/inside a hazard part?
function HazardService.Inside(hazard: BasePart, pos: Vector3): boolean
	local rel = hazard.CFrame:PointToObjectSpace(pos)
	local half = hazard.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and rel.Y > -2 and rel.Y < 6
end

local function players()
	local list = {}
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			table.insert(list, { Player = player, Root = root, Hum = hum })
		end
	end
	return list
end

------------------------------------------------------------------------
-- River look per state (server-side so everyone sees the same thing)
------------------------------------------------------------------------

local RIVER_LOOK = {
	Calm = { Color = Color3.fromRGB(60, 140, 230), Material = Enum.Material.Glass, Light = 0, Sparks = false },
	Warn = { Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.Glass, Light = 2, Sparks = false },
	Shock = { Color = Color3.fromRGB(170, 120, 255), Material = Enum.Material.Neon, Light = 6, Sparks = true },
}

local function setRiverState(river: BasePart, state: string)
	if river:GetAttribute("State") == state then
		return
	end
	river:SetAttribute("State", state)
	local look = RIVER_LOOK[state]
	river.Color = look.Color
	river.Material = look.Material
	local light = river:FindFirstChild("RiverLight")
	if not light then
		light = Instance.new("PointLight")
		light.Name = "RiverLight"
		light.Range = 24
		light.Color = Color3.fromRGB(170, 140, 255)
		light.Parent = river
	end
	light.Brightness = look.Light
	local sparks = river:FindFirstChild("RiverSparks")
	if not sparks then
		sparks = Instance.new("ParticleEmitter")
		sparks.Name = "RiverSparks"
		sparks.Color = ColorSequence.new(Color3.fromRGB(200, 160, 255), Color3.fromRGB(120, 230, 255))
		sparks.LightEmission = 1
		sparks.Lifetime = NumberRange.new(0.1, 0.25)
		sparks.Rate = 80
		sparks.Speed = NumberRange.new(5, 10)
		sparks.SpreadAngle = Vector2.new(40, 40)
		sparks.EmissionDirection = Enum.NormalId.Top
		sparks.Size = NumberSequence.new(0.35, 0)
		sparks.Parent = river
	end
	sparks.Enabled = look.Sparks
end

local function riverState(now: number): string
	local period = Config.RiverCalm + Config.RiverWarn + Config.RiverShock
	local t = now % period
	if t < Config.RiverCalm then
		return "Calm"
	elseif t < Config.RiverCalm + Config.RiverWarn then
		return "Warn"
	end
	return "Shock"
end

------------------------------------------------------------------------
-- Lightning on Storm bridges
------------------------------------------------------------------------

local function flashPart(size: Vector3, cf: CFrame, color: Color3, transparency: number, life: number, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Transparency = transparency
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace:FindFirstChild("Weather") or workspace
	Debris:AddItem(p, life)
	return p
end

local function strike(bridge: BasePart)
	-- random spot on the bridge
	local half = bridge.Size / 2
	local localPos = Vector3.new((math.random() * 2 - 1) * half.X, half.Y, (math.random() * 2 - 1) * half.Z)
	local ground = bridge.CFrame:PointToWorldSpace(localPos)
	local r = Config.LightningRadius

	-- warning circle
	local warn = flashPart(Vector3.new(0.2, r * 2, r * 2), CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(255, 60, 60), 0.5, Config.LightningWarn, Enum.PartType.Cylinder)
	TweenService:Create(warn, TweenInfo.new(Config.LightningWarn), { Transparency = 0.1 }):Play()

	task.delay(Config.LightningWarn, function()
		-- bolt: a few jagged neon segments from the sky
		local top = ground + Vector3.new(0, 60, 0)
		local prev = top
		for i = 1, 6 do
			local nextPos = (i == 6) and ground or top:Lerp(ground, i / 6) + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
			local mid = (prev + nextPos) / 2
			flashPart(Vector3.new(0.6, 0.6, (nextPos - prev).Magnitude), CFrame.lookAt(mid, nextPos),
				Color3.fromRGB(220, 235, 255), 0, 0.15)
			prev = nextPos
		end
		local flash = flashPart(Vector3.one * r * 2, CFrame.new(ground), Color3.fromRGB(200, 220, 255), 0.3, 0.3, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Brightness = 10
		light.Range = 40
		light.Color = Color3.fromRGB(200, 220, 255)
		light.Parent = flash

		for _, p in players() do
			local flat = Vector3.new(p.Root.Position.X - ground.X, 0, p.Root.Position.Z - ground.Z)
			if flat.Magnitude <= r and math.abs(p.Root.Position.Y - ground.Y) < 8 then
				local carrying = p.Player:GetAttribute("Carrying") ~= nil
				p.Hum:TakeDamage(carrying and Config.LightningDamage * 1.3 or Config.LightningDamage)
				local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.xAxis
				Remotes.Knock:FireClient(p.Player, dir * Config.LightningKnock + Vector3.new(0, 30, 0))
			end
		end
	end)
end

------------------------------------------------------------------------

local function damageLoop()
	while true do
		task.wait(Config.ElectricInterval)
		local now = workspace:GetServerTimeNow()
		local state = riverState(now)
		local hazards = MapService.GetHazards()

		for _, h in hazards do
			if h:GetAttribute("HazardType") == "River" then
				setRiverState(h, state)
			end
		end

		for _, p in players() do
			if p.Player:GetAttribute("ElectricImmune") then
				continue
			end
			for _, h in hazards do
				local kind = h:GetAttribute("HazardType")
				local shocking = kind == "Electric" or (kind == "River" and state == "Shock")
				if shocking and HazardService.Inside(h, p.Root.Position) then
					local carrying = p.Player:GetAttribute("Carrying") ~= nil
					local dmg = kind == "River" and Config.RiverDamage or Config.ElectricDamage
					p.Hum:TakeDamage(carrying and dmg * 1.6 or dmg)
					break
				end
			end
		end
	end
end

local function lightningLoop()
	while true do
		task.wait(Config.LightningInterval)
		for _, h in MapService.GetHazards() do
			if h:GetAttribute("HazardType") == "Storm" then
				strike(h)
			end
		end
	end
end

function HazardService.Start(mapService, remotes)
	MapService = mapService
	Remotes = remotes
	task.spawn(damageLoop)
	task.spawn(lightningLoop)
end

return HazardService
