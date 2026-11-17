-- WORLD EVENTS: every EventMinGap-EventMaxGap seconds one random event runs
-- for EventDuration seconds. State for clients lives in workspace attributes:
--   Event        "" | "MeteorShower" | "AcidRain" | "Fog"
--   EventBiome   biome the event targets ("" = everywhere)
--   EventEnds    server time it ends
--
--   Meteor Shower  meteors crash into one biome and leave Epic+ clouds
--   Acid Rain      one biome: outside shelter you take AcidDamage/s
--                  (shelter = anything solid above you: caps, caves, trees;
--                   PoisonImmune perks and the Shield Generator protect you)
--   Fog            thick fog everywhere, steal hold is faster — heist time!
-- For testing in Studio: EventService.Run("Fog") from the server Command Bar:
--   require(game.ServerScriptService.Server.Services.EventService).Run("AcidRain")

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local BiomeMap = require(ReplicatedStorage.Shared.BiomeMap)

local EventService = {}

local MapService, WeatherService, Remotes
local running = false

local BIOME_NAMES = {
	Plateau = "Plateau Meadows", Mountains = "Mountains", Mushroom = "Mushroom Plateaus", Marsh = "Storm Marshes",
	Canyon = "Crystal Canyons", Volcanic = "Volcanic Caldera", Coast = "Coast",
}

local function announce(text: string, seconds: number?)
	Remotes.Hint:FireAllClients(text, seconds or 6)
end

local function spawnsIn(biome: string): { BasePart }
	local list = {}
	for _, s in MapService.GetSpawns() do
		if s:GetAttribute("Biome") == biome then
			table.insert(list, s)
		end
	end
	return list
end

local function randomBiome(exclude: string?): string
	local options = {}
	for b in BIOME_NAMES do
		if b ~= exclude and #spawnsIn(b) > 0 then
			table.insert(options, b)
		end
	end
	table.sort(options)
	return options[math.random(1, #options)] or "Plateau"
end

------------------------------------------------------------------------
-- Meteor Shower
------------------------------------------------------------------------
local function meteor(target: BasePart)
	local impact = target.Position
	local start = impact + Vector3.new(math.random(-80, 80), 260, math.random(-80, 80))
	local rock = Instance.new("Part")
	rock.Name = "Meteor"
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.one * 5
	rock.Material = Enum.Material.Basalt
	rock.Color = Color3.fromRGB(70, 50, 45)
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CFrame = CFrame.new(start)
	local fire = Instance.new("Fire")
	fire.Size = 12
	fire.Heat = 20
	fire.Parent = rock
	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 80, 40))
	trail.LightEmission = 1
	trail.Size = NumberSequence.new(3, 0)
	trail.Lifetime = NumberRange.new(0.6, 1)
	trail.Rate = 60
	trail.Speed = NumberRange.new(2, 5)
	trail.Parent = rock
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Parent = rock
	rock.Parent = workspace
	local tween = TweenService:Create(rock, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(impact) })
	tween:Play()
	tween.Completed:Wait()
	local boom = Instance.new("Explosion")
	boom.Position = impact
	boom.BlastPressure = 0 -- visual only
	boom.BlastRadius = 8
	boom.DestroyJointRadiusPercent = 0
	boom.Parent = workspace
	rock.Transparency = 1
	trail.Enabled = false
	fire.Enabled = false
	Debris:AddItem(rock, 2)
	WeatherService.SpawnEventCloud(target, Config.MeteorTiers, impact + Vector3.new(0, 6, 0))
end

local function meteorShower()
	local biome = randomBiome()
	workspace:SetAttribute("EventBiome", biome)
	announce(`METEOR SHOWER over the {BIOME_NAMES[biome]}! Epic+ clouds are falling - go!`, 7)
	local spots = spawnsIn(biome)
	for i = 1, Config.MeteorClouds do
		if #spots == 0 then
			break
		end
		local target = table.remove(spots, math.random(1, #spots))
		task.spawn(meteor, target)
		task.wait(math.random(3, 7))
		if i == 1 then
			announce("Meteors are hitting - rare clouds are landing!", 3)
		end
	end
end

------------------------------------------------------------------------
-- Acid Rain
------------------------------------------------------------------------
local function biomeUnder(root: BasePart, params: RaycastParams): string?
	local info = BiomeMap.ZoneOfHit(workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params))
	return info and info.Biome or nil
end

local function sheltered(root: BasePart, params: RaycastParams): boolean
	local hit = workspace:Raycast(root.Position + Vector3.new(0, 3, 0), Vector3.new(0, 120, 0), params)
	return hit ~= nil
end

local function acidRain()
	local biome = randomBiome("Coast")
	workspace:SetAttribute("EventBiome", biome)
	announce(`ACID RAIN in the {BIOME_NAMES[biome]}! Find shelter - caps, caves, trees - or take damage!`, 7)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = false
	local warned = {}
	local ends = workspace:GetAttribute("EventEnds") or 0
	while workspace:GetServerTimeNow() < ends do
		task.wait(1)
		local map = workspace:FindFirstChild("Map")
		local ignore = {}
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(ignore, p.Character)
			end
		end
		for _, name in { "Hazards", "Zones", "AirColumns" } do
			local f = map and map:FindFirstChild(name)
			if f then
				table.insert(ignore, f)
			end
		end
		local weather = workspace:FindFirstChild("Weather")
		if weather then
			table.insert(ignore, weather)
		end
		params.FilterDescendantsInstances = ignore

		local now = workspace:GetServerTimeNow()
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and biomeUnder(root, params) == biome
				and not player:GetAttribute("PoisonImmune") and (player:GetAttribute("ShieldUntil") or 0) < now
				and not sheltered(root, params) then
				hum:TakeDamage(Config.AcidDamage * (1 - (player:GetAttribute("DamageResist") or 0)))
				if not warned[player] then
					warned[player] = true
					Remotes.Hint:FireClient(player, "The acid rain burns! Get under something!", 3)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- Fog
------------------------------------------------------------------------
local function setStealHold(seconds: number)
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "StealPrompt" then
			d.HoldDuration = seconds
		end
	end
end

local function fog()
	workspace:SetAttribute("EventBiome", "")
	announce("FOG BANK rolling in! You can barely see - stealing is FASTER. Guard your vaults!", 7)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local before = atmosphere and { Density = atmosphere.Density, Haze = atmosphere.Haze, Offset = atmosphere.Offset }
	if atmosphere then
		TweenService:Create(atmosphere, TweenInfo.new(6), { Density = 0.72, Haze = 3, Offset = 0.1 }):Play()
	end
	setStealHold(Config.FogStealHold)
	local ends = workspace:GetAttribute("EventEnds") or 0
	while workspace:GetServerTimeNow() < ends do
		task.wait(1)
	end
	setStealHold(Config.StealHold)
	if atmosphere and before then
		TweenService:Create(atmosphere, TweenInfo.new(8), before):Play()
	end
end

------------------------------------------------------------------------

local EVENTS = {
	MeteorShower = meteorShower,
	AcidRain = acidRain,
	Fog = fog,
}

-- Runs one event now (also usable from the Command Bar for testing)
function EventService.Run(name: string)
	if running or not EVENTS[name] then
		return false
	end
	running = true
	workspace:SetAttribute("Event", name)
	workspace:SetAttribute("EventEnds", workspace:GetServerTimeNow() + Config.EventDuration)
	task.spawn(function()
		local ok, err = pcall(EVENTS[name])
		if not ok then
			warn("[Events] " .. name .. " failed: " .. tostring(err))
		end
		local left = (workspace:GetAttribute("EventEnds") or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			task.wait(left)
		end
		workspace:SetAttribute("Event", "")
		workspace:SetAttribute("EventBiome", "")
		announce("The skies calm down... for now.", 3)
		running = false
	end)
	return true
end

-- Current steal hold time (WeatherService uses it for new prompts)
function EventService.StealHold(): number
	return workspace:GetAttribute("Event") == "Fog" and Config.FogStealHold or Config.StealHold
end

function EventService.Start(mapService, weatherService, remotes)
	MapService, WeatherService, Remotes = mapService, weatherService, remotes
	workspace:SetAttribute("Event", "")
	workspace:SetAttribute("EventBiome", "")
	task.spawn(function()
		local names = { "MeteorShower", "AcidRain", "Fog" }
		while true do
			task.wait(math.random(Config.EventMinGap, Config.EventMaxGap))
			if #Players:GetPlayers() > 0 then
				EventService.Run(names[math.random(1, #names)])
			end
		end
	end)
end

return EventService
