--[[
	Pocket Storm — EDIT-MODE map blockout builder (Studio Command Bar)

	How to use (Astra / director):
	  1. Studio in EDIT mode (not Play).
	  2. View the Command Bar (search "Command Bar" in Studio, or Ctrl+P → "Command Bar").
	  3. Paste this whole file, press Enter.
	  4. Output prints what was created / kept.
	  5. File → Save to File (place.rbxl).

	Safety:
	  - Idempotent: only creates objects that are MISSING (matched by name).
	    Running it twice changes nothing. Existing objects are never moved,
	    resized or deleted.
	  - Inserts NO scripts.
	  - Touches only workspace.Map (+ disables other SpawnLocations ONLY when
	    it creates Map.SpawnLocation for the first time).
	  - Never touches ServerScriptService / ReplicatedStorage / StarterPlayer.

	Layout (Y = 40, everything floats above the Baseplate):
	  StartPad (60x60) at origin, SpawnLocation at (0, 41.5, 22)
	  HuntZone/WeatherSpawns: 6 markers; Spawn1 = tutorial Rain Cloud spot
	  Shortcut (towards -Z): Bridge1 → WaterGap1 (Snow freezes) → Bridge2
	                         → LiftPlatform1 (rests 12 studs LOW; Tornado lifts it)
	  Detour (always walkable): DetourA (+X) → DetourB (down -Z) → DetourC
	  RooftopPad (100x50) centered (0, 40, -141), 6 rooftops along X
	  Each RooftopN: Floor, Nest, Display/Slot1..6
	  Abyss/AbyssFloor: invisible kill layer at Y = 15

	Expected counts after a fresh run:
	  Rooftops: 6 models, each 1 Nest + 6 Slots
	  WeatherSpawns: 6, LiftPlatforms: 1, WaterGaps: 1, CrateSpawns: 0
]]

local CollectionService = game:GetService("CollectionService")
local Y = 40
local created, kept = 0, 0

local function ensure(parent, name, className, setup)
	local existing = parent:FindFirstChild(name)
	if existing then
		kept += 1
		return existing
	end
	local obj = Instance.new(className)
	obj.Name = name
	if setup then
		setup(obj)
	end
	obj.Parent = parent
	created += 1
	return obj
end

local function folder(parent, name)
	return ensure(parent, name, "Folder")
end

local function part(parent, name, size, cf, color, props)
	return ensure(parent, name, "Part", function(p)
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in props or {} do
			p[k] = v
		end
	end)
end

local MARKER = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }
local grass = Color3.fromRGB(120, 195, 125)
local stone = Color3.fromRGB(205, 195, 175)

local map = folder(workspace, "Map")

-- Start + spawn
part(map, "StartPad", Vector3.new(60, 2, 60), CFrame.new(0, Y, 0), grass)
if not map:FindFirstChild("SpawnLocation") then
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d.Enabled = false
		end
	end
	ensure(map, "SpawnLocation", "SpawnLocation", function(s)
		s.Size = Vector3.new(6, 1, 6)
		s.CFrame = CFrame.new(0, Y + 1.5, 22)
		s.Anchored = true
		s.Neutral = true
		s.Duration = 0
	end)
end

-- Hunt zone
local spawns = folder(folder(map, "HuntZone"), "WeatherSpawns")
local spots = {
	Vector3.new(0, Y + 4, 10), -- Spawn1: tutorial
	Vector3.new(-20, Y + 4, -15),
	Vector3.new(20, Y + 4, -15),
	Vector3.new(-20, Y + 4, 10),
	Vector3.new(20, Y + 4, 10),
	Vector3.new(0, Y + 4, -20),
}
for i, pos in spots do
	part(spawns, "Spawn" .. i, Vector3.new(2, 2, 2), CFrame.new(pos), Color3.new(1, 1, 1), MARKER)
end

-- Route
local route = folder(map, "Route")
local lifts = folder(route, "LiftPlatforms")
local gaps = folder(route, "WaterGaps")
part(route, "Bridge1", Vector3.new(12, 2, 30), CFrame.new(0, Y, -45), stone)
part(gaps, "WaterGap1", Vector3.new(12, 1, 16), CFrame.new(0, Y, -68), Color3.fromRGB(60, 140, 230), {
	CanCollide = false,
	Transparency = 0.35,
})
part(route, "Bridge2", Vector3.new(12, 2, 24), CFrame.new(0, Y, -88), stone)
part(lifts, "LiftPlatform1", Vector3.new(12, 2, 16), CFrame.new(0, Y - 12, -108), Color3.fromRGB(240, 170, 80))
part(route, "DetourA", Vector3.new(50, 2, 12), CFrame.new(55, Y, 0), stone)
part(route, "DetourB", Vector3.new(12, 2, 152), CFrame.new(80, Y, -70), stone)
part(route, "DetourC", Vector3.new(36, 2, 12), CFrame.new(68, Y, -141), stone)

-- Rooftops
part(map, "RooftopPad", Vector3.new(100, 2, 50), CFrame.new(0, Y, -141), grass)
local roofs = folder(map, "Rooftops")
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
	local roof = ensure(roofs, "Rooftop" .. i, "Model")
	local floor = part(roof, "Floor", Vector3.new(14, 1, 20), CFrame.new(x, Y + 1.5, -145), colors[i])
	part(roof, "Nest", Vector3.new(6, 0.6, 6), CFrame.new(x, Y + 2.3, -139), Color3.fromRGB(255, 225, 90), {
		Material = Enum.Material.Neon,
	})
	local display = folder(roof, "Display")
	for row = 0, 1 do
		for col = 0, 2 do
			local n = row * 3 + col + 1
			part(display, "Slot" .. n, Vector3.new(2.5, 0.6, 2.5),
				CFrame.new(x - 4 + col * 4, Y + 2.3, -149 - row * 4), Color3.fromRGB(90, 90, 110))
		end
	end
	if not roof.PrimaryPart then
		roof.PrimaryPart = floor
	end
end

-- Decorative floating islands (client makes them drift; see FloatingIslands.luau)
local decor = folder(map, "Decor")
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
	local island = ensure(decor, "Island" .. i, "Model")
	local top = part(island, "Grass", Vector3.new(3, size, size), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), grass, {
	Shape = Enum.PartType.Cylinder,
	Material = Enum.Material.Grass,
	})
	part(island, "Rock", Vector3.new(size * 0.85, size * 0.6, size * 0.85), CFrame.new(pos - Vector3.new(0, size * 0.3, 0)), Color3.fromRGB(150, 120, 95), {
	Shape = Enum.PartType.Ball,
	Material = Enum.Material.Slate,
	})
	for j = 1, 3 do
	local a = j * 2.1
	part(island, "Cloud" .. j, Vector3.one * (size * 0.35), CFrame.new(pos + Vector3.new(math.cos(a) * size * 0.45, -size * 0.35, math.sin(a) * size * 0.45)), Color3.fromRGB(245, 248, 255), {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
	})
	end
	island.PrimaryPart = top
	island:SetAttribute("FloatAmplitude", 1 + (i % 3) * 0.5)
	CollectionService:AddTag(island, "FloatingIsland")
end

-- Later + safety
folder(folder(map, "CrateArena"), "CrateSpawns")
part(folder(map, "Abyss"), "AbyssFloor", Vector3.new(800, 10, 800), CFrame.new(0, Y - 25, 0), Color3.new(0, 0, 0), {
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
})

print(("[MapBuilder] done — created %d, kept %d existing"):format(created, kept))
