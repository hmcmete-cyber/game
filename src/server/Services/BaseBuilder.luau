-- Builds one high-tech floating base: a hexagon island with a shiny metal +
-- glass top, rocky underside, glowing rim, spinning energy rings, a central
-- Nest and Containment Spheres (vaults).
--
-- Resulting model (names matter for the game code):
-- RooftopN (Model, PrimaryPart = Top1)
-- ├── Top1..3, Glass1..3, Rim1..6, Rock*, Core   (the island)
-- ├── Nest (Part)                                 deposit pad in the middle
-- ├── LockPad (Part)                              owner steps on it -> shield
-- ├── Vaults/Vault1..N (Part, Ball, glass)        tagged VaultSphere + FloatingIsland
-- ├── Pedestals/*                                 under each sphere
-- └── Rings/RingA, RingB (Model)                  tagged SpinRing (client spins them)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BaseBuilder = {}

BaseBuilder.Radius = 16 -- hexagon circumradius (studs); v2.13: was 12

local METAL = Color3.fromRGB(205, 212, 225)
local ROCK = Color3.fromRGB(120, 98, 82)
local DARK_ROCK = Color3.fromRGB(85, 72, 66)
local SPHERE = Color3.fromRGB(200, 230, 255)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?)
	local p = Instance.new(props and props.Class or "Part") :: Part
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			if k ~= "Class" then
				(p :: any)[k] = v
			end
		end
	end
	p.Parent = parent
	return p
end

local function folder(parent: Instance, name: string)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

-- A regular hexagon = 3 rectangles (R x 2·apothem) rotated 0°, 60°, 120°
local function hexagon(parent: Instance, name: string, center: CFrame, radius: number, thickness: number, color: Color3, props: { [string]: any }?)
	local apothem = radius * math.sqrt(3) / 2
	local first
	for k = 0, 2 do
		local p = part(parent, name .. (k + 1), Vector3.new(radius, thickness, apothem * 2),
			center * CFrame.Angles(0, k * math.pi / 3, 0), color, props)
		first = first or p
	end
	return first
end

local NO_COLLIDE = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

local function ring(parent: Instance, name: string, center: CFrame, radius: number, segments: number, color: Color3, speed: number)
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- spins as one piece
	local pivot = part(model, "Center", Vector3.one, center, color, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local arc = 2 * math.pi * radius / segments
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		part(model, "Seg" .. i, Vector3.new(0.35, 0.35, arc * 0.7),
			center * CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius) * CFrame.Angles(0, -a, 0),
			color, {
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			})
	end
	model.PrimaryPart = pivot
	model:SetAttribute("SpinSpeed", speed)
	model.Parent = parent
	CollectionService:AddTag(model, "SpinRing")
	return model
end

-- Glass containment sphere on a glowing pedestal
function BaseBuilder.Vault(vaults: Instance, pedestals: Instance?, name: string, position: Vector3, size: number?)
	local s = size or 4.4
	local v = part(vaults, name, Vector3.one * s, CFrame.new(position), SPHERE, {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Glass,
		Transparency = 0.6,
		Reflectance = 0.1,
		CanCollide = false,
		CastShadow = false,
	})
	CollectionService:AddTag(v, "VaultSphere")
	v:SetAttribute("FloatAmplitude", 0.35)
	v:SetAttribute("FloatSpeed", 1.2)
	CollectionService:AddTag(v, "FloatingIsland")

	if pedestals then
		local floorY = position.Y - s / 2 - 1.1
		part(pedestals, name .. "Base", Vector3.new(0.6, s * 0.75, s * 0.75),
			CFrame.new(position.X, floorY + 0.3, position.Z) * CFrame.Angles(0, 0, math.pi / 2), METAL, {
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Metal,
				Reflectance = 0.2,
			})
		part(pedestals, name .. "Glow", Vector3.new(0.15, s * 0.85, s * 0.85),
			CFrame.new(position.X, floorY + 0.65, position.Z) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(120, 210, 255), {
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Neon,
				Transparency = 0.2,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			})
	end
	return v
end

-- top: position of the walkable top surface center
-- facing (optional): point the base's front (local -Z: lock pad, entrance)
-- toward this position.
function BaseBuilder.Build(parent: Instance, name: string, top: Vector3, accent: Color3, facing: Vector3?): Model
	local R = BaseBuilder.Radius
	local base = Instance.new("Model")
	base.Name = name
	base.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- your base is always loaded

	local topCF = facing and CFrame.lookAt(top, Vector3.new(facing.X, top.Y, facing.Z)) or CFrame.new(top)

	-- Shiny metal deck + glass inlay
	local deck = hexagon(base, "Top", topCF * CFrame.new(0, -0.5, 0), R, 1, METAL, {
		Material = Enum.Material.Metal,
		Reflectance = 0.15,
	})
	hexagon(base, "Glass", topCF * CFrame.new(0, 0.06, 0), R * 0.72, 0.12, accent, {
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})

	-- Glowing rim along the 6 edges
	local apothem = R * math.sqrt(3) / 2
	for i = 0, 5 do
		local theta = math.rad(30 + 60 * i)
		part(base, "Rim" .. (i + 1), Vector3.new(0.35, 0.35, R),
			topCF * CFrame.new(math.cos(theta) * apothem, 0.15, math.sin(theta) * apothem) * CFrame.Angles(0, -theta, 0),
			accent, {
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			})
	end

	-- Rocky underside, tapering down
	hexagon(base, "Rock", topCF * CFrame.new(0, -3, 0), R * 0.9, 4, ROCK, { Material = Enum.Material.Ground })
	hexagon(base, "RockLow", topCF * CFrame.new(0, -6.5, 0), R * 0.6, 4, DARK_ROCK, { Material = Enum.Material.Slate })
	part(base, "Core", Vector3.one * R * 0.75, topCF * CFrame.new(0, -9.5, 0), DARK_ROCK, {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Slate,
	})

	-- Central deposit pad
	part(base, "Nest", Vector3.new(0.4, 7, 7), topCF * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(255, 225, 90), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
		})

	-- Lock pad (see BaseLockService.luau)
	part(base, "LockPad", Vector3.new(0.5, 3.5, 3.5), topCF * CFrame.new(0, 0.25, -8.5) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(90, 255, 140), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
		})

	-- Containment spheres around the middle
	local vaults = folder(base, "Vaults")
	local pedestals = folder(base, "Pedestals")
	for n = 1, Config.VaultCount do
		local a = math.rad(45) + (n - 1) * (math.pi * 2 / Config.VaultCount)
		BaseBuilder.Vault(vaults, pedestals, "Vault" .. n, topCF:PointToWorldSpace(Vector3.new(math.cos(a) * 6.8, 3.3, math.sin(a) * 6.8)))
	end

	-- Energy rings
	local rings = folder(base, "Rings")
	ring(rings, "RingA", topCF * CFrame.new(0, 1.2, 0), R + 2.5, 28, Color3.fromRGB(120, 220, 255), 0.35)
	ring(rings, "RingB", topCF * CFrame.new(0, 4.5, 0) * CFrame.Angles(math.rad(10), 0, math.rad(6)), R + 1, 24, accent, -0.55)

	-- v1.6 DECOR (gameplay paths above are unchanged). Local frame: -Z faces
	-- the hub/bridge (front edge 270 deg), the expansion link sits at the -X
	-- corner (180 deg). Railings only on the back/right edges so both
	-- entrances stay open.
	local decor = folder(base, "Decor")
	-- v2.15: no railing on the back edge (90): open path to the Egg Nursery
	for _, edgeDeg in { 30, 330 } do
		local theta = math.rad(edgeDeg)
		local cf = topCF * CFrame.new(math.cos(theta) * (apothem - 0.4), 1.6, math.sin(theta) * (apothem - 0.4)) * CFrame.Angles(0, -theta, 0)
		part(decor, "RailGlass" .. edgeDeg, Vector3.new(0.2, 3, R - 1), cf, Color3.fromRGB(190, 225, 255), {
			Material = Enum.Material.Glass, Transparency = 0.55, CastShadow = false,
		})
		part(decor, "RailTop" .. edgeDeg, Vector3.new(0.35, 0.3, R - 1), cf * CFrame.new(0, 1.6, 0), accent, {
			Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false,
		})
	end
	-- corner lamps (skip the two entrance corners)
	for _, cornerDeg in { 60, 120, 240, 300 } do
		local a = math.rad(cornerDeg)
		local pos = topCF * CFrame.new(math.cos(a) * (R - 1.2), 0, math.sin(a) * (R - 1.2))
		part(decor, "LampPost" .. cornerDeg, Vector3.new(0.5, 6, 0.5), pos * CFrame.new(0, 3, 0), Color3.fromRGB(70, 75, 90), {
			Material = Enum.Material.Metal, CastShadow = false,
		})
		local bulb = part(decor, "LampBulb" .. cornerDeg, Vector3.new(1.2, 1.2, 1.2), pos * CFrame.new(0, 6.4, 0), accent, {
			Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false,
		})
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Brightness = 1
		light.Color = accent
		light.Parent = bulb
	end
	-- entrance arch over the bridge side
	local front = topCF * CFrame.new(0, 0, -(apothem - 0.6))
	for _, x in { -4.2, 4.2 } do
		part(decor, "ArchPillar", Vector3.new(0.9, 8, 0.9), front * CFrame.new(x, 4, 0), Color3.fromRGB(235, 238, 248), {
			Material = Enum.Material.Marble, CastShadow = false,
		})
	end
	part(decor, "ArchBeam", Vector3.new(9.6, 0.8, 1), front * CFrame.new(0, 8.3, 0), Color3.fromRGB(235, 238, 248), {
		Material = Enum.Material.Marble, CastShadow = false,
	})
	part(decor, "ArchGlow", Vector3.new(8.4, 0.25, 1.1), front * CFrame.new(0, 7.75, 0), accent, {
		Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false,
	})
	-- flag in the base colour on the back edge (spot your base from far away)
	local back = topCF * CFrame.new(-6.5, 0, apothem - 1.2) -- v2.15: off-centre, the middle is the nursery path
	part(decor, "FlagPole", Vector3.new(0.35, 16, 0.35), back * CFrame.new(0, 8, 0), Color3.fromRGB(220, 225, 235), {
		Material = Enum.Material.Metal, CanCollide = false, CastShadow = false,
	})
	part(decor, "Flag", Vector3.new(0.12, 3, 5), back * CFrame.new(0, 14, 2.6), accent, {
		Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false, CastShadow = false,
	})
	-- two planters with bushes beside the flag
	for _, x in { -4.2, 6.2 } do
		local cf = topCF * CFrame.new(x, 0.5, apothem - 1.6)
		part(decor, "Planter", Vector3.new(2.4, 1, 1.4), cf, Color3.fromRGB(120, 90, 70), { Material = Enum.Material.WoodPlanks, CastShadow = false })
		part(decor, "Bush", Vector3.new(2.2, 1.6, 1.4), cf * CFrame.new(0, 1.1, 0), Color3.fromRGB(110, 185, 110), {
			Shape = Enum.PartType.Ball, Material = Enum.Material.Grass, CanCollide = false, CanQuery = false, CastShadow = false,
		})
	end
	-- glowing ring around the vaults marks the "vault zone"
	part(decor, "VaultRing", Vector3.new(0.1, 17, 17), topCF * CFrame.new(0, 0.13, 0) * CFrame.Angles(0, 0, math.pi / 2), accent, {
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Transparency = 0.75, CanCollide = false, CanQuery = false, CastShadow = false,
	})

	-- v2.5 STRUCTURE: plinth trim under the deck edge, round support pillars
	-- down into the rock, a little storage shed on the back-left with a
	-- sloped roof, door and window, and a stack of supply crates by it
	local wood, roofC, trim = Color3.fromRGB(170, 120, 80), accent:Lerp(Color3.fromRGB(60, 60, 70), 0.35), Color3.fromRGB(235, 238, 248)
	for i = 0, 5 do
		local theta = math.rad(30 + 60 * i)
		part(decor, "Plinth" .. i, Vector3.new(0.8, 1, R), topCF * CFrame.new(math.cos(theta) * (apothem + 0.2), -1.4, math.sin(theta) * (apothem + 0.2)) * CFrame.Angles(0, -theta, 0),
			trim, { Material = Enum.Material.Plastic, CastShadow = false })
		local corner = math.rad(60 * i)
		part(decor, "Pillar" .. i, Vector3.new(6, 1.4, 1.4), topCF * CFrame.new(math.cos(corner) * (R - 2.5), -4.5, math.sin(corner) * (R - 2.5)) * CFrame.Angles(0, 0, math.pi / 2),
			trim, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Plastic, CastShadow = false })
	end
	-- at the +X corner (free of vaults, lamps, rails and both entrances), door facing the nest
	local shedCF = topCF * CFrame.new(8.4, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	part(decor, "ShedFloor", Vector3.new(4.2, 0.4, 3.6), shedCF * CFrame.new(0, 0.2, 0), wood, { Material = Enum.Material.Plastic })
	part(decor, "ShedBack", Vector3.new(4.2, 3.4, 0.4), shedCF * CFrame.new(0, 2.1, 1.6), wood, { Material = Enum.Material.Plastic })
	part(decor, "ShedLeft", Vector3.new(0.4, 3.4, 3.6), shedCF * CFrame.new(-1.9, 2.1, 0), wood, { Material = Enum.Material.Plastic })
	part(decor, "ShedRight", Vector3.new(0.4, 3.4, 3.6), shedCF * CFrame.new(1.9, 2.1, 0), wood, { Material = Enum.Material.Plastic })
	part(decor, "ShedFrontL", Vector3.new(1.3, 3.4, 0.4), shedCF * CFrame.new(-1.45, 2.1, -1.6), wood, { Material = Enum.Material.Plastic })
	part(decor, "ShedFrontR", Vector3.new(1.3, 3.4, 0.4), shedCF * CFrame.new(1.45, 2.1, -1.6), wood, { Material = Enum.Material.Plastic })
	part(decor, "ShedLintel", Vector3.new(1.6, 0.8, 0.4), shedCF * CFrame.new(0, 3.4, -1.6), wood, { Material = Enum.Material.Plastic })
	part(decor, "ShedDoor", Vector3.new(1.5, 2.6, 0.2), shedCF * CFrame.new(0, 1.7, -1.75), Color3.fromRGB(110, 75, 50), { Material = Enum.Material.Plastic, CanCollide = false })
	part(decor, "ShedWindow", Vector3.new(0.2, 1, 1.2), shedCF * CFrame.new(1.95, 2.4, 0), Color3.fromRGB(150, 210, 255), { Material = Enum.Material.Glass, Transparency = 0.3 })
	part(decor, "RoofL", Vector3.new(2.4, 1.2, 4.4), shedCF * CFrame.new(-1.1, 4.4, 0) * CFrame.Angles(0, math.rad(-90), 0), roofC, { Class = "WedgePart", Material = Enum.Material.Plastic })
	part(decor, "RoofR", Vector3.new(2.4, 1.2, 4.4), shedCF * CFrame.new(1.1, 4.4, 0) * CFrame.Angles(0, math.rad(90), 0), roofC, { Class = "WedgePart", Material = Enum.Material.Plastic })
	for k, off in { Vector3.new(-3.4, 0.7, -0.4), Vector3.new(-3.4, 2.1, -0.4), Vector3.new(-4.6, 0.7, 0.8) } do
		part(decor, "Crate" .. k, Vector3.new(1.4, 1.4, 1.4), shedCF * CFrame.new(off) * CFrame.Angles(0, k * 0.4, 0), Color3.fromRGB(200, 150, 90), { Material = Enum.Material.Plastic })
	end

	base.PrimaryPart = deck
	base.Parent = parent
	return base
end

return BaseBuilder
