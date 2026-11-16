-- Finds the map (built by Astra in Studio) and hands out rooftops.
-- If workspace.Map doesn't exist yet, builds a simple placeholder map so the
-- game is playable right away. Once Astra's Map is saved in the place, the
-- placeholder is never built.
--
-- Expected structure (see COMMS.md):
-- workspace.Map
--   SpawnLocation
--   Rooftops/RooftopN (Model) -> Nest (Part), Vaults/VaultN (Part, glass sphere)
--     (if Vaults is missing, spheres are created above Display/SlotN or around the Nest)
--   HuntZone/WeatherSpawns/SpawnN (Part)   -- Spawn1 = tutorial spot, always a Rain Cloud
--   Route/LiftPlatforms/* (Part, placed in LOWERED position)
--   Route/WaterGaps/* (Part, CanCollide off; Snow freezes them solid)
--   CrateArena/CrateSpawns/CrateN (Part)
--   Abyss/* (optional Parts: touching them kills, for falling off the map)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

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

-- Transparent glass storage sphere
local function makeVault(parent: Instance, name: string, position: Vector3)
	local v = newPart(parent, name, Vector3.one * 2.6, CFrame.new(position), Color3.fromRGB(200, 230, 255), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		CanCollide = false,
		CastShadow = false,
	})
	return v
end

local MARKER = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }

local function buildPlaceholder(): Instance
	local m = Instance.new("Folder")
	m.Name = "Map"

	local Y = 40
	local grass = Color3.fromRGB(120, 195, 125)
	local stone = Color3.fromRGB(205, 195, 175)

	-- Start + hunt zone
	newPart(m, "StartPad", Vector3.new(60, 2, 60), CFrame.new(0, Y, 0), grass)
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "SpawnLocation"
	spawnLoc.Size = Vector3.new(6, 1, 6)
	spawnLoc.CFrame = CFrame.new(0, Y + 1.5, 22)
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Duration = 0
	spawnLoc.Parent = m

	local hunt = getFolder(m, "HuntZone")
	local spawns = getFolder(hunt, "WeatherSpawns")
	local spots = {
		Vector3.new(0, Y + 4, 10), -- Spawn1: tutorial, right in front of the spawn
		Vector3.new(-20, Y + 4, -15),
		Vector3.new(20, Y + 4, -15),
		Vector3.new(-20, Y + 4, 10),
		Vector3.new(20, Y + 4, 10),
		Vector3.new(0, Y + 4, -20),
	}
	for i, pos in spots do
		newPart(spawns, "Spawn" .. i, Vector3.new(2, 2, 2), CFrame.new(pos), Color3.new(1, 1, 1), MARKER)
	end

	-- Shortcut route: needs Snow (water gap) and Tornado (lift platform)
	local route = getFolder(m, "Route")
	local lifts = getFolder(route, "LiftPlatforms")
	local gaps = getFolder(route, "WaterGaps")
	newPart(route, "Bridge1", Vector3.new(12, 2, 30), CFrame.new(0, Y, -45), stone)
	newPart(gaps, "WaterGap1", Vector3.new(12, 1, 16), CFrame.new(0, Y, -68), Color3.fromRGB(60, 140, 230), {
		CanCollide = false,
		Transparency = 0.35,
	})
	newPart(route, "Bridge2", Vector3.new(12, 2, 24), CFrame.new(0, Y, -88), stone)
	newPart(lifts, "LiftPlatform1", Vector3.new(12, 2, 16), CFrame.new(0, Y - 12, -108), Color3.fromRGB(240, 170, 80))

	-- Long detour: always walkable
	newPart(route, "DetourA", Vector3.new(50, 2, 12), CFrame.new(55, Y, 0), stone)
	newPart(route, "DetourB", Vector3.new(12, 2, 152), CFrame.new(80, Y, -70), stone)
	newPart(route, "DetourC", Vector3.new(36, 2, 12), CFrame.new(68, Y, -141), stone)

	-- Rooftops
	newPart(m, "RooftopPad", Vector3.new(100, 2, 50), CFrame.new(0, Y, -141), grass)
	local roofs = getFolder(m, "Rooftops")
	local colors = {
		Color3.fromRGB(255, 170, 170),
		Color3.fromRGB(255, 210, 150),
		Color3.fromRGB(255, 245, 160),
		Color3.fromRGB(170, 235, 170),
		Color3.fromRGB(165, 205, 255),
		Color3.fromRGB(215, 175, 255),
	}
	for i = 1, 6 do
		local x = -40 + (i - 1) * 16
		local roof = Instance.new("Model")
		roof.Name = "Rooftop" .. i
		local floor = newPart(roof, "Floor", Vector3.new(14, 1, 20), CFrame.new(x, Y + 1.5, -145), colors[i])
		newPart(roof, "Nest", Vector3.new(6, 0.6, 6), CFrame.new(x, Y + 2.3, -139), Color3.fromRGB(255, 225, 90), {
			Material = Enum.Material.Neon,
		})
		local vaults = getFolder(roof, "Vaults")
		for n = 1, Config.VaultCount do
			local offset = (n - (Config.VaultCount + 1) / 2) * 2.8
			makeVault(vaults, "Vault" .. n, Vector3.new(x + offset, Y + 3.5, -149 + math.abs(offset) * 0.35))
		end
		roof.PrimaryPart = floor
		roof.Parent = roofs
	end

	-- Decorative floating islands (client makes them drift; see FloatingIslands.luau)
	local decor = getFolder(m, "Decor")
	local islandSpots = {
		{ Vector3.new(-95, Y + 10, -40), 22 },
		{ Vector3.new(120, Y + 22, -60), 28 },
		{ Vector3.new(-75, Y - 6, -190), 20 },
		{ Vector3.new(60, Y + 26, 55), 18 },
		{ Vector3.new(-60, Y + 18, 70), 24 },
		{ Vector3.new(135, Y - 10, -175), 26 },
	}
	for i, spot in islandSpots do
		local pos, size = spot[1], spot[2]
		local island = Instance.new("Model")
		island.Name = "Island" .. i
		local top = newPart(island, "Grass", Vector3.new(3, size, size), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), grass, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Grass,
		})
		newPart(island, "Rock", Vector3.new(size * 0.85, size * 0.6, size * 0.85), CFrame.new(pos - Vector3.new(0, size * 0.3, 0)), Color3.fromRGB(150, 120, 95), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Slate,
		})
		for j = 1, 3 do
			local a = j * 2.1
			newPart(island, "Cloud" .. j, Vector3.one * (size * 0.35), CFrame.new(pos + Vector3.new(math.cos(a) * size * 0.45, -size * 0.35, math.sin(a) * size * 0.45)), Color3.fromRGB(245, 248, 255), {
				Shape = Enum.PartType.Ball,
				CanCollide = false,
			})
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
	newPart(abyss, "AbyssFloor", Vector3.new(800, 10, 800), CFrame.new(0, Y - 25, 0), Color3.new(0, 0, 0), {
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

function MapService.Start()
	map = workspace:FindFirstChild("Map")
	if not map then
		map = buildPlaceholder()
		print("[Map] workspace.Map not found — built placeholder map")
	end

	-- Make sure all expected folders exist so other code never errors
	getFolder(map, "Rooftops")
	getFolder(getFolder(map, "HuntZone"), "WeatherSpawns")
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
			makeVault(folder, "Vault" .. n, pos)
		end
	end
	local list = sortedParts(folder)
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
