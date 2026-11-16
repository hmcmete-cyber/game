-- Builds one high-tech floating base: a hexagon island with a shiny metal +
-- glass top, rocky underside, glowing rim, spinning energy rings, a central
-- Nest and Containment Spheres (vaults).
--
-- Resulting model (names matter for the game code):
-- RooftopN (Model, PrimaryPart = Top1)
-- ├── Top1..3, Glass1..3, Rim1..6, Rock*, Core   (the island)
-- ├── Nest (Part)                                 deposit pad in the middle
-- ├── Vaults/Vault1..N (Part, Ball, glass)        tagged VaultSphere + FloatingIsland
-- ├── Pedestals/*                                 under each sphere
-- └── Rings/RingA, RingB (Model)                  tagged SpinRing (client spins them)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BaseBuilder = {}

BaseBuilder.Radius = 12 -- hexagon circumradius (studs)

local METAL = Color3.fromRGB(205, 212, 225)
local ROCK = Color3.fromRGB(120, 98, 82)
local DARK_ROCK = Color3.fromRGB(85, 72, 66)
local SPHERE = Color3.fromRGB(200, 230, 255)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?)
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
function BaseBuilder.Build(parent: Instance, name: string, top: Vector3, accent: Color3): Model
	local R = BaseBuilder.Radius
	local base = Instance.new("Model")
	base.Name = name

	local topCF = CFrame.new(top)

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

	-- Containment spheres around the middle
	local vaults = folder(base, "Vaults")
	local pedestals = folder(base, "Pedestals")
	for n = 1, Config.VaultCount do
		local a = math.rad(45) + (n - 1) * (math.pi * 2 / Config.VaultCount)
		BaseBuilder.Vault(vaults, pedestals, "Vault" .. n, top + Vector3.new(math.cos(a) * 6.8, 3.3, math.sin(a) * 6.8))
	end

	-- Energy rings
	local rings = folder(base, "Rings")
	ring(rings, "RingA", topCF * CFrame.new(0, 1.2, 0), R + 2.5, 28, Color3.fromRGB(120, 220, 255), 0.35)
	ring(rings, "RingB", topCF * CFrame.new(0, 4.5, 0) * CFrame.Angles(math.rad(10), 0, math.rad(6)), R + 1, 24, accent, -0.55)

	base.PrimaryPart = deck
	base.Parent = parent
	return base
end

return BaseBuilder
