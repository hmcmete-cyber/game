-- Finds the map (built by Astra in Studio) and hands out rooftops.
-- If workspace.Map doesn't exist yet, builds a simple placeholder map so the
-- game is playable right away. Once Astra's Map is saved in the place, the
-- placeholder is never built.
--
-- Expected structure (see COMMS.md):
-- workspace.Map
--   SpawnLocation
--   Rooftops/RooftopN (Model) -> Nest (Part), Vaults/VaultN (Part, glass sphere) — see BaseBuilder.luau
--     (if Vaults is missing, spheres are created above Display/SlotN or around the Nest)
--   HuntZone/WeatherSpawns/SpawnN (Part, attribute Zone = 1|2|3) -- Spawn1 = tutorial spot, always a Cumulus
--   HuntZone/Altars/AltarN (Part)         -- Cloud Altars: rare clouds + 0.01% Mythic
--   Hazards/* (Part, attribute HazardType = "Ice" | "River" | "Storm" | "Electric", CanCollide off, CanQuery on)
--   Zones/* (Part volumes, attributes ZoneName, ZoneColor, Warning?) — for the HUD
--   AirColumns/* (cylinder Part, attributes Lift, PushX/PushZ/PushAbove) — updraft & descent
--   RooftopN/Market/*Spot (Part, attribute Npc = "Tayron" | "Aurelius") — vendor NPCs
--   Route/LiftPlatforms/* (Part, placed in LOWERED position)
--   Route/WaterGaps/* (Part, CanCollide off; Snow freezes them solid)
--   CrateArena/CrateSpawns/CrateN (Part)
--   Abyss/* (optional Parts: touching them kills, for falling off the map)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseBuilder = require(script.Parent:WaitForChild("BaseBuilder"))

local MapService = {}

local map: Instance = nil
local owners = {} -- [Player] = rooftop Model

local function getFolder(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

-- Sort children by the number at the end of their name (Slot1, Slot2, ... Slot10)
local function sortedParts(parent: Instance?): { BasePart }
	local list = {}
	if not parent then
		return list
	end
	for _, child in parent:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	table.sort(list, function(a, b)
		local na = tonumber(a.Name:match("%d+$")) or 0
		local nb = tonumber(b.Name:match("%d+$")) or 0
		if na == nb then
			return a.Name < b.Name
		end
		return na < nb
	end)
	return list
end

local function newPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

local MARKER = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }

local function zoneSign(parent: Instance, name: string, pos: Vector3, text: string, color: Color3)
	local anchor = newPart(parent, name, Vector3.one, CFrame.new(pos), color, MARKER)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(420, 70)
	gui.MaxDistance = 140
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = anchor
end

-- Neon strips along both edges of a path segment
local function edgeLights(parent: Instance, center: Vector3, width: number, length: number, color: Color3)
	for _, side in { -1, 1 } do
		newPart(parent, "Edge", Vector3.new(0.4, 0.4, length), CFrame.new(center + Vector3.new(side * width / 2, 1.1, 0)), color, {
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
	end
end

-- Altar: glowing disc + 4 neon pillars; the marker is where clouds rise
local function altar(parent: Instance, markers: Instance, name: string, top: Vector3)
	local deco = Instance.new("Model")
	deco.Name = name .. "Decor"
	newPart(deco, "Disc", Vector3.new(0.6, 12, 12), CFrame.new(top + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(200, 150, 255), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Transparency = 0.2 })
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2 + math.pi / 4
		newPart(deco, "Pillar" .. i, Vector3.new(1.2, 9, 1.2), CFrame.new(top + Vector3.new(math.cos(a) * 9, 4.5, math.sin(a) * 9)),
			Color3.fromRGB(230, 200, 255), { Material = Enum.Material.Marble })
		newPart(deco, "PillarTip" .. i, Vector3.one * 1.6, CFrame.new(top + Vector3.new(math.cos(a) * 9, 9.6, math.sin(a) * 9)),
			Color3.fromRGB(190, 120, 255), { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, CanCollide = false })
	end
	deco.Parent = parent
	local marker = newPart(markers, name, Vector3.new(2, 2, 2), CFrame.new(top + Vector3.new(0, 4, 0)), Color3.new(1, 1, 1), MARKER)
	return marker
end

-- Regular hexagon from 3 rotated rectangles (R x 2·apothem)
local function hexagon(parent: Instance, name: string, cf: CFrame, radius: number, thickness: number, color: Color3, props)
	local apothem = radius * math.sqrt(3) / 2
	for k = 0, 2 do
		newPart(parent, name .. (k + 1), Vector3.new(radius, thickness, apothem * 2), cf * CFrame.Angles(0, k * math.pi / 3, 0), color, props)
	end
end

-- Vertical air column (client Movement.luau applies it):
--   Lift  = vertical speed inside (positive up, small negative = gentle glide down)
--   PushX / PushZ / PushAbove = sideways push once you're above that height
local function airColumn(parent: Instance, name: string, size: Vector3, pos: Vector3, lift: number, color: Color3, push: Vector3?, pushAbove: number?)
	local col = newPart(parent, name, size, CFrame.new(pos), color, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CanCollide = false,
		CanQuery = true,
		CanTouch = false,
		CastShadow = false,
	})
	-- cylinders lie along X: stand it up
	col.Size = Vector3.new(size.Y, size.X, size.Z)
	col.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	col:SetAttribute("Lift", lift)
	if push then
		col:SetAttribute("PushX", push.X)
		col:SetAttribute("PushZ", push.Z)
		col:SetAttribute("PushAbove", pushAbove or 0)
	end
	local streaks = Instance.new("ParticleEmitter")
	streaks.Texture = "rbxasset://textures/particles/smoke_main.dds"
	streaks.Color = ColorSequence.new(color)
	streaks.Transparency = NumberSequence.new(0.5, 1)
	streaks.Size = NumberSequence.new(2, 4)
	streaks.Lifetime = NumberRange.new(2, 3)
	streaks.Rate = 25
	streaks.Speed = NumberRange.new(math.abs(lift) * 0.8, math.abs(lift))
	streaks.EmissionDirection = lift >= 0 and Enum.NormalId.Right or Enum.NormalId.Left -- along the standing axis
	streaks.SpreadAngle = Vector2.new(8, 8)
	streaks.LightEmission = 0.4
	streaks.Parent = col
	return col
end

local function buildPlaceholder(): Instance
	local m = Instance.new("Folder")
	m.Name = "Map"

	local Y = 40 -- hub level
	local UP = 130 -- sky level (cloud zones)
	local hubR = 60
	local hubColor = Color3.fromRGB(235, 238, 248)

	local hunt = getFolder(m, "HuntZone")
	local spawns = getFolder(hunt, "WeatherSpawns")
	local altars = getFolder(hunt, "Altars")
	local route = getFolder(m, "Route")
	getFolder(route, "LiftPlatforms")
	getFolder(route, "WaterGaps")
	local decor = getFolder(m, "Decor")
	local signs = getFolder(decor, "Signs")
	local hazards = getFolder(m, "Hazards")
	local zones = getFolder(m, "Zones")
	local air = getFolder(m, "AirColumns")

	local spawnCount = 0
	local function spawnPoint(pos: Vector3, zone: number)
		spawnCount += 1
		local p = newPart(spawns, "Spawn" .. spawnCount, Vector3.new(2, 2, 2), CFrame.new(pos), Color3.new(1, 1, 1), MARKER)
		p:SetAttribute("Zone", zone)
	end
	local function zoneVolume(name: string, center: Vector3, size: Vector3, label: string, color: Color3, warning: string?)
		local v = newPart(zones, name, size, CFrame.new(center), color, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = true,
			CanTouch = false,
			CastShadow = false,
		})
		v:SetAttribute("ZoneName", label)
		v:SetAttribute("ZoneColor", color)
		if warning then
			v:SetAttribute("Warning", warning)
		end
	end
	local function hazard(name: string, size: Vector3, cf: CFrame, kind: string, color: Color3, props)
		local h = newPart(hazards, name, size, cf, color, props)
		h.CanCollide = false
		h.CanQuery = true
		h.CanTouch = false
		h.CastShadow = false
		h:SetAttribute("HazardType", kind)
		return h
	end

	------------------------------------------------------------------
	-- HEXAGON HUB (Y = 40, radius 60): marble deck, glass inlay, neon rim,
	-- pillars at the 6 corners, spawn ring, updraft in the middle
	------------------------------------------------------------------
	local hubCF = CFrame.new(0, Y, 0)
	hexagon(route, "HubDeck", hubCF * CFrame.new(0, -1, 0), hubR, 2, hubColor, { Material = Enum.Material.Marble })
	hexagon(decor, "HubGlass", hubCF * CFrame.new(0, 0.06, 0), hubR * 0.55, 0.12, Color3.fromRGB(170, 210, 255), {
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
		CanQuery = false,
	})
	hexagon(decor, "HubRock", hubCF * CFrame.new(0, -6, 0), hubR * 0.85, 8, Color3.fromRGB(125, 105, 90), { Material = Enum.Material.Ground })
	hexagon(decor, "HubRockLow", hubCF * CFrame.new(0, -13, 0), hubR * 0.5, 8, Color3.fromRGB(95, 80, 72), { Material = Enum.Material.Slate })
	local hubApothem = hubR * math.sqrt(3) / 2
	for i = 0, 5 do
		local theta = math.rad(30 + 60 * i)
		newPart(decor, "HubRim" .. i, Vector3.new(0.5, 0.5, hubR), hubCF * CFrame.new(math.cos(theta) * hubApothem, 0.2, math.sin(theta) * hubApothem) * CFrame.Angles(0, -theta, 0),
			Color3.fromRGB(150, 220, 255), { Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false })
		local corner = math.rad(60 * i)
		local cpos = Vector3.new(math.cos(corner) * (hubR - 4), Y, math.sin(corner) * (hubR - 4))
		newPart(decor, "Pillar" .. i, Vector3.new(2.5, 16, 2.5), CFrame.new(cpos + Vector3.new(0, 8, 0)), Color3.fromRGB(245, 240, 230), { Material = Enum.Material.Marble })
		local orb = newPart(decor, "PillarOrb" .. i, Vector3.one * 3, CFrame.new(cpos + Vector3.new(0, 17.5, 0)), Color3.fromRGB(170, 220, 255), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 1.5
		light.Color = orb.Color
		light.Parent = orb
	end

	-- Spawn ring around the updraft
	for i = 1, 6 do
		local a = math.rad(i * 60 + 30)
		local sp = Instance.new("SpawnLocation")
		sp.Name = "SpawnLocation" .. i
		sp.Size = Vector3.new(6, 1, 6)
		sp.CFrame = CFrame.lookAt(Vector3.new(math.cos(a) * 26, Y + 0.5, math.sin(a) * 26), Vector3.new(0, Y + 0.5, 0))
		sp.Anchored = true
		sp.Neutral = true
		sp.Duration = 0
		sp.Material = Enum.Material.Neon
		sp.Color = Color3.fromRGB(190, 230, 255)
		sp.Transparency = 0.3
		sp.Parent = m
	end
	zoneVolume("Hub", Vector3.new(0, Y + 10, 0), Vector3.new(130, 40, 130), "Hexagon Hub", Color3.fromRGB(200, 230, 255))
	zoneSign(signs, "HubSign", Vector3.new(0, Y + 30, 0), "STEAL A CLOUD", Color3.fromRGB(255, 255, 255))

	-- Tutorial cloud right on the hub
	spawnPoint(Vector3.new(0, Y + 4, 18), 1)

	------------------------------------------------------------------
	-- 12 BASES around the hub (radius 95), each facing the center,
	-- joined to the hub by a bridge
	------------------------------------------------------------------
	local roofs = getFolder(m, "Rooftops")
	for i = 1, 12 do
		local a = math.rad((i - 1) * 30 + 15)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local hue = (i - 1) / 12
		BaseBuilder.Build(roofs, "Rooftop" .. i, dir * 95 + Vector3.new(0, Y, 0), Color3.fromHSV(hue, 0.45, 1), Vector3.new(0, Y, 0))
		local mid = dir * 67 + Vector3.new(0, Y - 0.5, 0)
		newPart(route, "BaseBridge" .. i, Vector3.new(6, 1, 36), CFrame.lookAt(mid, mid + dir), hubColor, { Material = Enum.Material.Marble })
	end

	------------------------------------------------------------------
	-- UPDRAFT in the hub center -> sky landing (pushes you toward -Z at the top)
	-- DESCENT chute from the landing edge back down to the hub
	------------------------------------------------------------------
	airColumn(air, "Updraft", Vector3.new(14, UP + 22 - Y, 14), Vector3.new(0, (Y + UP + 22) / 2, 0), 70,
		Color3.fromRGB(190, 235, 255), Vector3.new(0, 0, -45), UP - 2)
	newPart(decor, "UpdraftPad", Vector3.new(0.6, 16, 16), CFrame.new(0, Y + 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 220, 255), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	zoneSign(signs, "UpdraftSign", Vector3.new(0, Y + 12, 0), "UPDRAFT - to the clouds", Color3.fromRGB(190, 235, 255))

	-- Sky landing (UP level), right next to the top of the updraft
	-- (z -20 … -100: the updraft throws you ~30-40 studs toward -Z)
	newPart(route, "SkyLanding", Vector3.new(40, 2, 80), CFrame.new(0, UP - 1, -60), Color3.fromRGB(245, 248, 255), { Material = Enum.Material.Marble })
	zoneVolume("Landing", Vector3.new(0, UP + 10, -60), Vector3.new(50, 40, 80), "Sky Landing", Color3.fromRGB(220, 240, 255))
	-- Descent chute: step off the front edge (z -20) and glide down to the hub.
	-- (Missing the chute is fine too: you just land on the hub.)
	airColumn(air, "Descent", Vector3.new(12, UP - Y - 6, 12), Vector3.new(0, (Y + UP - 6) / 2, -16), -14, Color3.fromRGB(255, 220, 240))
	zoneSign(signs, "DescentSign", Vector3.new(0, UP + 6, -22), "v  GLIDE DOWN TO THE HUB  v", Color3.fromRGB(255, 220, 240))

	------------------------------------------------------------------
	-- SKY PATH (one way, no shortcuts):
	-- Landing -> Gate 1 Ice -> Zone 1 Breeze -> Gate 2 River ->
	-- Zone 2 Canyon (+Altar1) -> Gate 3 Storm Bridge -> Zone 3 Cosmic -> Altar2
	------------------------------------------------------------------
	local cloudWhite = Color3.fromRGB(240, 246, 255)

	-- GATE 1: Ice Path (z -100 … -130)
	local iceColor = Color3.fromRGB(200, 235, 255)
	newPart(route, "IceBridge", Vector3.new(10, 2, 30), CFrame.new(0, UP - 1, -115), Color3.fromRGB(190, 225, 255), { Material = Enum.Material.Ice })
	hazard("IcePath1", Vector3.new(10, 0.2, 30), CFrame.new(0, UP + 0.1, -115), "Ice", Color3.fromRGB(215, 240, 255), {
		Material = Enum.Material.Glacier,
		Transparency = 0.2,
	})
	zoneVolume("Gate1", Vector3.new(0, UP + 10, -115), Vector3.new(40, 40, 30), "Gate 1 - Ice Path", iceColor,
		"Slippery! You lose control - Frost Cloud perk helps")
	zoneSign(signs, "Gate1Sign", Vector3.new(0, UP + 10, -102), "GATE 1 - ICE PATH", iceColor)

	-- ZONE 1: Breeze (z -130 … -210)
	local breeze = Color3.fromRGB(190, 230, 255)
	newPart(route, "BreezeField", Vector3.new(60, 2, 80), CFrame.new(0, UP - 1, -170), cloudWhite)
	edgeLights(decor, Vector3.new(0, UP - 1, -170), 60, 80, breeze)
	zoneVolume("Zone1", Vector3.new(0, UP + 10, -170), Vector3.new(70, 40, 80), "Breeze Zone", breeze)
	for _, pos in {
		Vector3.new(-20, UP + 3, -145), Vector3.new(20, UP + 3, -150), Vector3.new(-15, UP + 3, -172),
		Vector3.new(15, UP + 3, -177), Vector3.new(-22, UP + 3, -197), Vector3.new(22, UP + 3, -200),
	} do
		spawnPoint(pos, 1)
	end

	-- GATE 2: Electric River (z -210 … -250)
	local riverColor = Color3.fromRGB(170, 120, 255)
	newPart(route, "RiverBankA", Vector3.new(16, 2, 8), CFrame.new(0, UP - 1, -214), Color3.fromRGB(120, 110, 100), { Material = Enum.Material.Ground })
	newPart(route, "RiverBed", Vector3.new(16, 2, 24), CFrame.new(0, UP - 1.6, -230), Color3.fromRGB(70, 80, 90), { Material = Enum.Material.Pebble })
	newPart(route, "RiverBankB", Vector3.new(16, 2, 8), CFrame.new(0, UP - 1, -246), Color3.fromRGB(120, 110, 100), { Material = Enum.Material.Ground })
	hazard("ElectricRiver1", Vector3.new(16, 0.8, 24), CFrame.new(0, UP - 0.4, -230), "River", Color3.fromRGB(60, 140, 230), {
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	})
	zoneVolume("Gate2", Vector3.new(0, UP + 10, -230), Vector3.new(40, 40, 40), "Gate 2 - Electric River", riverColor,
		"Cross while the water is BLUE - yellow = shock incoming!")
	zoneSign(signs, "Gate2Sign", Vector3.new(0, UP + 10, -212), "GATE 2 - ELECTRIC RIVER", riverColor)

	-- ZONE 2: Thunder Canyon (z -250 … -310) + Altar1
	local canyon = Color3.fromRGB(95, 90, 115)
	local thunder = Color3.fromRGB(255, 230, 90)
	newPart(route, "CanyonField", Vector3.new(60, 2, 60), CFrame.new(0, UP - 1, -280), canyon, { Material = Enum.Material.Slate })
	edgeLights(decor, Vector3.new(0, UP - 1, -280), 60, 60, thunder)
	altar(decor, altars, "Altar1", Vector3.new(0, UP, -280))
	zoneVolume("Zone2", Vector3.new(0, UP + 10, -280), Vector3.new(70, 40, 60), "Thunder Canyon", thunder)
	for _, pos in {
		Vector3.new(-22, UP + 3, -260), Vector3.new(22, UP + 3, -262), Vector3.new(-22, UP + 3, -298),
		Vector3.new(22, UP + 3, -300), Vector3.new(-12, UP + 3, -305),
	} do
		spawnPoint(pos, 2)
	end

	-- GATE 3: Storm Bridge (z -310 … -370), 6 wide
	local stormColor = Color3.fromRGB(255, 90, 90)
	newPart(route, "StormBridge", Vector3.new(6, 2, 60), CFrame.new(0, UP - 1, -340), Color3.fromRGB(80, 75, 95), { Material = Enum.Material.DiamondPlate })
	hazard("StormBridge1", Vector3.new(6, 0.2, 60), CFrame.new(0, UP + 0.05, -340), "Storm", Color3.fromRGB(80, 75, 95), { Transparency = 1 })
	zoneVolume("Gate3", Vector3.new(0, UP + 10, -340), Vector3.new(40, 40, 60), "Gate 3 - Storm Bridge", stormColor,
		"Lightning hits the RED circles - and the wind pushes you sideways!")
	zoneSign(signs, "Gate3Sign", Vector3.new(0, UP + 10, -312), "GATE 3 - STORM BRIDGE", stormColor)

	-- ZONE 3: Cosmic Stratosphere (z -370 … -430) + Altar2 (z -430 … -454)
	local cosmic = Color3.fromRGB(35, 28, 70)
	local neon = Color3.fromRGB(255, 90, 230)
	newPart(route, "CosmicField", Vector3.new(60, 2, 60), CFrame.new(0, UP - 1, -400), cosmic, { Material = Enum.Material.Glass, Reflectance = 0.2 })
	edgeLights(decor, Vector3.new(0, UP - 1, -400), 60, 60, neon)
	zoneVolume("Zone3", Vector3.new(0, UP + 10, -412), Vector3.new(70, 40, 84), "Cosmic Stratosphere", neon)
	for _, pos in {
		Vector3.new(-20, UP + 3, -385), Vector3.new(20, UP + 3, -390),
		Vector3.new(-18, UP + 3, -415), Vector3.new(18, UP + 3, -418),
	} do
		spawnPoint(pos, 3)
	end
	newPart(route, "AltarPad2", Vector3.new(24, 2, 24), CFrame.new(0, UP - 1, -442), Color3.fromRGB(70, 55, 110), { Material = Enum.Material.Marble })
	altar(decor, altars, "Altar2", Vector3.new(0, UP, -442))

	------------------------------------------------------------------
	-- Decorative floating islands
	------------------------------------------------------------------
	local grass = Color3.fromRGB(120, 195, 125)
	local islandSpots = {
		{ Vector3.new(-160, Y + 20, 60), 26 }, { Vector3.new(170, Y + 40, -40), 30 },
		{ Vector3.new(-140, UP - 10, -200), 24 }, { Vector3.new(120, UP + 15, -300), 26 },
		{ Vector3.new(-110, UP + 30, -420), 22 }, { Vector3.new(150, Y - 10, 150), 28 },
	}
	for i, spot in islandSpots do
		local pos, size = spot[1], spot[2]
		local island = Instance.new("Model")
		island.Name = "Island" .. i
		local top = newPart(island, "Grass", Vector3.new(3, size, size), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), grass, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Grass,
		})
		newPart(island, "Rock", Vector3.one * size * 0.7, CFrame.new(pos - Vector3.new(0, size * 0.3, 0)), Color3.fromRGB(150, 120, 95), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Slate,
		})
		island.PrimaryPart = top
		island:SetAttribute("FloatAmplitude", 1 + (i % 3) * 0.5)
		island.Parent = decor
		CollectionService:AddTag(island, "FloatingIsland")
	end

	getFolder(getFolder(m, "CrateArena"), "CrateSpawns")

	-- Falling off = respawn (below the hub)
	local abyss = getFolder(m, "Abyss")
	newPart(abyss, "AbyssFloor", Vector3.new(1200, 10, 1200), CFrame.new(0, Y - 30, -150), Color3.new(0, 0, 0), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	m.Parent = workspace
	return m
end

-- Also used from the Studio Command Bar (docs/MapBuilder.luau) to save the
-- placeholder into the place. Does nothing if workspace.Map already exists.
function MapService.BuildPlaceholder(): Instance
	local existing = workspace:FindFirstChild("Map")
	if existing then
		return existing
	end
	return buildPlaceholder()
end

function MapService.Start()
	map = workspace:FindFirstChild("Map")
	if not map then
		map = buildPlaceholder()
		print("[Map] workspace.Map not found — built placeholder map")
	end

	-- Make sure all expected folders exist so other code never errors
	getFolder(map, "Rooftops")
	getFolder(getFolder(map, "HuntZone"), "WeatherSpawns")
	getFolder(map.HuntZone, "Altars")
	getFolder(map, "Hazards")
	getFolder(map, "Zones")
	getFolder(map, "AirColumns")
	local route = getFolder(map, "Route")
	getFolder(route, "LiftPlatforms")
	getFolder(route, "WaterGaps")
	getFolder(getFolder(map, "CrateArena"), "CrateSpawns")

	-- Abyss: touching kills (for falling off rooftops)
	local abyss = map:FindFirstChild("Abyss")
	if abyss then
		for _, part in abyss:GetDescendants() do
			if part:IsA("BasePart") then
				part.Touched:Connect(function(hit)
					local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						hum.Health = 0
					end
				end)
			end
		end
	end
end

function MapService.GetSpawns(): { BasePart }
	return sortedParts(map.HuntZone.WeatherSpawns)
end

function MapService.GetAltars(): { BasePart }
	return sortedParts(map.HuntZone.Altars)
end

-- Hazard parts (attribute HazardType = "Ice" | "Electric")
function MapService.GetHazards(): { BasePart }
	local list = {}
	for _, d in map.Hazards:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("HazardType") then
			table.insert(list, d)
		end
	end
	return list
end

function MapService.GetLiftPlatforms(): { BasePart }
	return sortedParts(map.Route.LiftPlatforms)
end

function MapService.GetWaterGaps(): { BasePart }
	return sortedParts(map.Route.WaterGaps)
end

-- Vault spheres of a rooftop. Creates them if the map doesn't have any.
function MapService.GetVaults(rooftop: Instance): { BasePart }
	local folder = rooftop:FindFirstChild("Vaults")
	if not folder then
		folder = getFolder(rooftop, "Vaults")
		local slots = sortedParts(rooftop:FindFirstChild("Display"))
		local nest = rooftop:FindFirstChild("Nest") :: BasePart
		for n = 1, Config.VaultCount do
			local pos
			if slots[n] then
				pos = slots[n].Position + Vector3.new(0, slots[n].Size.Y / 2 + 1.5, 0)
			else
				local a = (n / Config.VaultCount) * math.pi * 2
				pos = nest.Position + Vector3.new(math.cos(a) * 6, 1.6, math.sin(a) * 6)
			end
			BaseBuilder.Vault(folder, nil, "Vault" .. n, pos, 3)
		end
	end
	local list = sortedParts(folder)
	for _, v in list do
		if not CollectionService:HasTag(v, "VaultSphere") then
			CollectionService:AddTag(v, "VaultSphere")
		end
	end
	while #list > Config.VaultCount do
		table.remove(list)
	end
	return list
end

function MapService.GetRooftop(player: Player)
	return owners[player]
end

function MapService.AssignRooftop(player: Player)
	local taken = {}
	for _, roof in owners do
		taken[roof] = true
	end
	local roofs = {}
	for _, roof in map.Rooftops:GetChildren() do
		if roof:FindFirstChild("Nest") then
			table.insert(roofs, roof)
		end
	end
	table.sort(roofs, function(a, b)
		return (tonumber(a.Name:match("%d+$")) or 0) < (tonumber(b.Name:match("%d+$")) or 0)
	end)
	for _, roof in roofs do
		if not taken[roof] then
			owners[player] = roof
			roof:SetAttribute("OwnerUserId", player.UserId)

			-- Name sign above the nest
			local sign = Instance.new("BillboardGui")
			sign.Name = "OwnerSign"
			sign.Size = UDim2.fromOffset(220, 50)
			sign.StudsOffset = Vector3.new(0, 6, 0)
			sign.AlwaysOnTop = false
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextScaled = true
			label.Font = Enum.Font.GothamBold
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.3
			label.Text = `{player.DisplayName}'s Roof`
			label.Parent = sign
			sign.Parent = roof.Nest
			return roof
		end
	end
	return nil
end

function MapService.ReleaseRooftop(player: Player)
	local roof = owners[player]
	if not roof then
		return
	end
	owners[player] = nil
	roof:SetAttribute("OwnerUserId", nil)
	local sign = roof.Nest:FindFirstChild("OwnerSign")
	if sign then
		sign:Destroy()
	end
end

Players.PlayerRemoving:Connect(function(player)
	-- safety net; normally released from main
	if owners[player] then
		MapService.ReleaseRooftop(player)
	end
end)

return MapService
