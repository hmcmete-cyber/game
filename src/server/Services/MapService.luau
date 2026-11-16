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
--   Shops/CloudShop (Model, see ShopBuilder.luau) with a TayronSpot part for the NPC
--   Route/LiftPlatforms/* (Part, placed in LOWERED position)
--   Route/WaterGaps/* (Part, CanCollide off; Snow freezes them solid)
--   CrateArena/CrateSpawns/CrateN (Part)
--   Abyss/* (optional Parts: touching them kills, for falling off the map)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseBuilder = require(script.Parent:WaitForChild("BaseBuilder"))
local ShopBuilder = require(script.Parent:WaitForChild("ShopBuilder"))

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

local function buildPlaceholder(): Instance
	local m = Instance.new("Folder")
	m.Name = "Map"

	local Y = 40
	local cloudWhite = Color3.fromRGB(240, 246, 255)
	local plazaColor = Color3.fromRGB(215, 225, 240)

	local hunt = getFolder(m, "HuntZone")
	local spawns = getFolder(hunt, "WeatherSpawns")
	local altars = getFolder(hunt, "Altars")
	local route = getFolder(m, "Route")
	local lifts = getFolder(route, "LiftPlatforms")
	local gaps = getFolder(route, "WaterGaps")
	local decor = getFolder(m, "Decor")
	local signs = getFolder(decor, "Signs")

	local spawnCount = 0
	local function spawnPoint(pos: Vector3, zone: number)
		spawnCount += 1
		local p = newPart(spawns, "Spawn" .. spawnCount, Vector3.new(2, 2, 2), CFrame.new(pos), Color3.new(1, 1, 1), MARKER)
		p:SetAttribute("Zone", zone)
	end

	------------------------------------------------------------------
	-- SPAWN AREA: plaza with the 6 bases lined up on both sides
	------------------------------------------------------------------
	newPart(route, "Plaza", Vector3.new(20, 2, 100), CFrame.new(0, Y, 0), plazaColor, { Material = Enum.Material.Marble })
	edgeLights(decor, Vector3.new(0, Y, 0), 20, 100, Color3.fromRGB(150, 220, 255))
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "SpawnLocation"
	spawnLoc.Size = Vector3.new(6, 1, 6)
	spawnLoc.CFrame = CFrame.new(0, Y + 1.5, 35)
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Duration = 0
	spawnLoc.Parent = m
	zoneSign(signs, "SpawnSign", Vector3.new(0, Y + 14, 45), "☁️ STEAL A CLOUD ☁️", Color3.fromRGB(255, 255, 255))

	spawnPoint(Vector3.new(0, Y + 4, 15), 1) -- Spawn1: tutorial Cumulus right in front of you

	local roofs = getFolder(m, "Rooftops")
	local accents = {
		Color3.fromRGB(255, 120, 150),
		Color3.fromRGB(255, 180, 90),
		Color3.fromRGB(255, 235, 110),
		Color3.fromRGB(120, 235, 150),
		Color3.fromRGB(110, 190, 255),
		Color3.fromRGB(190, 140, 255),
	}
	local zs = { 30, 0, -30 }
	for i = 1, 6 do
		local side = i <= 3 and -1 or 1
		local z = zs[(i - 1) % 3 + 1]
		BaseBuilder.Build(roofs, "Rooftop" .. i, Vector3.new(side * 26, Y + 1, z), accents[i])
		newPart(route, "BaseBridge" .. i, Vector3.new(9, 1, 6), CFrame.new(side * 13, Y + 0.5, z), plazaColor, { Material = Enum.Material.Marble })
	end

	------------------------------------------------------------------
	-- ONE path, no shortcuts. Every zone starts with a mandatory gate:
	--   Gate 1 Ice Path → Zone 1 Breeze → Gate 2 Electric River →
	--   Zone 2 Thunder Canyon (+ Altar1) → Gate 3 Storm Bridge →
	--   Zone 3 Cosmic Stratosphere → Altar2
	------------------------------------------------------------------
	local hazards = getFolder(m, "Hazards")
	local zones = getFolder(m, "Zones")

	-- Zone volumes: the client shows where you are (top-center panel)
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

	zoneVolume("SpawnArea", Vector3.new(0, Y + 10, 0), Vector3.new(90, 40, 110), "🏠 Spawn Area", Color3.fromRGB(200, 230, 255))

	-- CLOUD SHOP right behind the spawn (+Z), Tayron inside (NpcService)
	newPart(route, "ShopDeckLink", Vector3.new(20, 2, 10), CFrame.new(0, Y, 54.5), plazaColor, { Material = Enum.Material.Marble })
	ShopBuilder.Build(getFolder(m, "Shops"), Vector3.new(0, Y + 1, 72))
	zoneVolume("ShopArea", Vector3.new(0, Y + 10, 72), Vector3.new(40, 40, 30), "🛍️ Cloud Shop", Color3.fromRGB(255, 190, 220))

	-- GATE 1: Ice Path (z -50 … -80), narrow, no rails
	local iceColor = Color3.fromRGB(200, 235, 255)
	newPart(route, "IceBridge", Vector3.new(10, 2, 30), CFrame.new(0, Y, -65), Color3.fromRGB(190, 225, 255), { Material = Enum.Material.Ice })
	hazard("IcePath1", Vector3.new(10, 0.2, 30), CFrame.new(0, Y + 1.1, -65), "Ice", Color3.fromRGB(215, 240, 255), {
		Material = Enum.Material.Glacier,
		Transparency = 0.2,
	})
	zoneVolume("Gate1", Vector3.new(0, Y + 10, -65), Vector3.new(40, 40, 30), "❄️ Gate 1 · Ice Path", iceColor,
		"Slippery! You lose control — the Snow Cloud perk (Frost Grip) helps")
	zoneSign(signs, "Gate1Sign", Vector3.new(0, Y + 10, -52), "❄️ GATE 1 · ICE PATH", iceColor)

	-- ZONE 1: Breeze (z -80 … -160)
	local breeze = Color3.fromRGB(190, 230, 255)
	newPart(route, "BreezeField", Vector3.new(60, 2, 80), CFrame.new(0, Y, -120), cloudWhite)
	edgeLights(decor, Vector3.new(0, Y, -120), 60, 80, breeze)
	zoneVolume("Zone1", Vector3.new(0, Y + 10, -120), Vector3.new(70, 40, 80), "🌤️ Breeze Zone", breeze)
	for _, pos in {
		Vector3.new(-20, Y + 4, -95), Vector3.new(20, Y + 4, -100), Vector3.new(-15, Y + 4, -122),
		Vector3.new(15, Y + 4, -127), Vector3.new(-22, Y + 4, -147), Vector3.new(22, Y + 4, -150),
	} do
		spawnPoint(pos, 1)
	end

	-- GATE 2: Electric River (z -160 … -200): banks + 24-stud river that pulses
	local riverColor = Color3.fromRGB(170, 120, 255)
	newPart(route, "RiverBankA", Vector3.new(16, 2, 8), CFrame.new(0, Y, -164), Color3.fromRGB(120, 110, 100), { Material = Enum.Material.Ground })
	newPart(route, "RiverBed", Vector3.new(16, 2, 24), CFrame.new(0, Y - 0.6, -180), Color3.fromRGB(70, 80, 90), { Material = Enum.Material.Pebble })
	newPart(route, "RiverBankB", Vector3.new(16, 2, 8), CFrame.new(0, Y, -196), Color3.fromRGB(120, 110, 100), { Material = Enum.Material.Ground })
	hazard("ElectricRiver1", Vector3.new(16, 0.8, 24), CFrame.new(0, Y + 0.6, -180), "River", Color3.fromRGB(60, 140, 230), {
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	})
	zoneVolume("Gate2", Vector3.new(0, Y + 10, -180), Vector3.new(40, 40, 40), "⚡ Gate 2 · Electric River", riverColor,
		"Cross while the water is BLUE — yellow = shock incoming!")
	zoneSign(signs, "Gate2Sign", Vector3.new(0, Y + 10, -162), "⚡ GATE 2 · ELECTRIC RIVER", riverColor)

	-- ZONE 2: Thunder Canyon (z -200 … -260) + Altar1 in the middle
	local canyon = Color3.fromRGB(95, 90, 115)
	local thunder = Color3.fromRGB(255, 230, 90)
	newPart(route, "CanyonField", Vector3.new(60, 2, 60), CFrame.new(0, Y, -230), canyon, { Material = Enum.Material.Slate })
	edgeLights(decor, Vector3.new(0, Y, -230), 60, 60, thunder)
	altar(decor, altars, "Altar1", Vector3.new(0, Y + 1, -230))
	zoneVolume("Zone2", Vector3.new(0, Y + 10, -230), Vector3.new(70, 40, 60), "⛈️ Thunder Canyon", thunder)
	for _, pos in {
		Vector3.new(-22, Y + 4, -210), Vector3.new(22, Y + 4, -212), Vector3.new(-22, Y + 4, -248),
		Vector3.new(22, Y + 4, -250), Vector3.new(-12, Y + 4, -255),
	} do
		spawnPoint(pos, 2)
	end

	-- GATE 3: Storm Bridge (z -260 … -320): 6 wide, 60 long, lightning + wind
	local stormColor = Color3.fromRGB(255, 90, 90)
	newPart(route, "StormBridge", Vector3.new(6, 2, 60), CFrame.new(0, Y, -290), Color3.fromRGB(80, 75, 95), { Material = Enum.Material.DiamondPlate })
	hazard("StormBridge1", Vector3.new(6, 0.2, 60), CFrame.new(0, Y + 1.05, -290), "Storm", Color3.fromRGB(80, 75, 95), {
		Transparency = 1,
	})
	zoneVolume("Gate3", Vector3.new(0, Y + 10, -290), Vector3.new(40, 40, 60), "🌩️ Gate 3 · Storm Bridge", stormColor,
		"Lightning hits the RED circles — and the wind pushes you sideways!")
	zoneSign(signs, "Gate3Sign", Vector3.new(0, Y + 10, -262), "🌩️ GATE 3 · STORM BRIDGE", stormColor)

	-- ZONE 3: Cosmic Stratosphere (z -320 … -380) + Altar2 (z -380 … -404)
	local cosmic = Color3.fromRGB(35, 28, 70)
	local neon = Color3.fromRGB(255, 90, 230)
	newPart(route, "CosmicField", Vector3.new(60, 2, 60), CFrame.new(0, Y, -350), cosmic, { Material = Enum.Material.Glass, Reflectance = 0.2 })
	edgeLights(decor, Vector3.new(0, Y, -350), 60, 60, neon)
	zoneVolume("Zone3", Vector3.new(0, Y + 10, -362), Vector3.new(70, 40, 84), "🌌 Cosmic Stratosphere", neon)
	for _, pos in {
		Vector3.new(-20, Y + 4, -335), Vector3.new(20, Y + 4, -340),
		Vector3.new(-18, Y + 4, -365), Vector3.new(18, Y + 4, -368),
	} do
		spawnPoint(pos, 3)
	end
	newPart(route, "AltarPad2", Vector3.new(24, 2, 24), CFrame.new(0, Y, -392), Color3.fromRGB(70, 55, 110), { Material = Enum.Material.Marble })
	altar(decor, altars, "Altar2", Vector3.new(0, Y + 1, -392))

	------------------------------------------------------------------
	-- Decorative floating islands along the path
	------------------------------------------------------------------
	local grass = Color3.fromRGB(120, 195, 125)
	local islandSpots = {
		{ Vector3.new(-80, Y + 10, 20), 22 },
		{ Vector3.new(85, Y + 20, -40), 26 },
		{ Vector3.new(-75, Y - 6, -140), 20 },
		{ Vector3.new(90, Y + 18, -200), 24 },
		{ Vector3.new(-85, Y + 24, -300), 28 },
		{ Vector3.new(80, Y - 8, -400), 22 },
		{ Vector3.new(-70, Y + 15, -470), 18 },
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
		for j = 1, 3 do
			local a = j * 2.1
			newPart(island, "Cloud" .. j, Vector3.one * (size * 0.35),
				CFrame.new(pos + Vector3.new(math.cos(a) * size * 0.45, -size * 0.35, math.sin(a) * size * 0.45)),
				Color3.fromRGB(245, 248, 255), { Shape = Enum.PartType.Ball, CanCollide = false })
		end
		island.PrimaryPart = top
		island:SetAttribute("FloatAmplitude", 1 + (i % 3) * 0.5)
		island.Parent = decor
		CollectionService:AddTag(island, "FloatingIsland")
	end

	-- Placeholders for later
	getFolder(getFolder(m, "CrateArena"), "CrateSpawns")

	-- Falling off = respawn
	local abyss = getFolder(m, "Abyss")
	newPart(abyss, "AbyssFloor", Vector3.new(800, 10, 1000), CFrame.new(0, Y - 25, -180), Color3.new(0, 0, 0), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	-- Use our spawn, not the Baseplate one
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d.Enabled = false
		end
	end

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
