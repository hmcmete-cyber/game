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
--   HuntZone/WeatherSpawns/SpawnN (Part, attribute Biome = Plateau|Coast|Mountains|Valley)
--   HuntZone/Altars/AltarN (Part)         -- Cloud Altars: rare clouds + 0.01% Mythic
--   Hazards/* (Part, attribute HazardType = "Ice" | "River" | "Storm" | "Electric", CanCollide off, CanQuery on)
--   Zones/* (Part volumes, attributes ZoneName, ZoneColor, Warning?) — for the HUD
--   AirColumns/* (cylinder Part, attributes Lift, PushX/PushZ/PushAbove) — updraft & descent
--   Decor/ItemShop + Decor/UpgradeShop: the only 2 shops (hub, opposite corners);
--     *Spot parts with attribute Npc = "Tayron" | "Aurelius" mark where vendors stand
--   Route/LiftPlatforms/* (Part, placed in LOWERED position)
--   Route/WaterGaps/* (Part, CanCollide off; Snow freezes them solid)
--   CrateArena/CrateSpawns/CrateN (Part)
--   Abyss/* (Parts: touching them kills — the Death Cloud floor)
--   Continent/* floor parts carry ZoneName/ZoneColor/Biome/Warning attributes (HUD)
--   Expansion/ExpansionPadN — empty pads next to each base for future buildings

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

-- A vendor stall: wooden counter + striped canopy + glowing sign + lamps.
-- floor: floor-level center, facing: point the counter toward this.
-- The NPC stands at "<Name>Spot" (attribute Npc = vendor) behind the counter.
local function shopStall(parent: Instance, name: string, floor: Vector3, facing: Vector3, vendor: string, title: string, accent: Color3)
	local stall = Instance.new("Model")
	stall.Name = name
	local cf = CFrame.lookAt(floor, Vector3.new(facing.X, floor.Y, facing.Z))
	local wood = Color3.fromRGB(160, 110, 72)
	local dark = Color3.fromRGB(105, 70, 45)

	newPart(stall, "Floor", Vector3.new(16, 0.4, 10), cf * CFrame.new(0, 0.2, 0), wood, { Material = Enum.Material.WoodPlanks })
	newPart(stall, "Counter", Vector3.new(12, 3, 1.6), cf * CFrame.new(0, 1.9, -2.5), dark, { Material = Enum.Material.Wood })
	newPart(stall, "CounterTop", Vector3.new(12.6, 0.3, 2.2), cf * CFrame.new(0, 3.55, -2.5), accent, { Material = Enum.Material.Neon })
	newPart(stall, "ShelfBack", Vector3.new(12, 6, 0.5), cf * CFrame.new(0, 3.4, 4.5), dark, { Material = Enum.Material.Wood })
	for row = 0, 1 do
		newPart(stall, "Shelf" .. row, Vector3.new(11, 0.3, 1.4), cf * CFrame.new(0, 2.4 + row * 2, 3.8), wood, { Material = Enum.Material.Wood })
		for i = 0, 5 do
			newPart(stall, "Jar" .. row .. i, Vector3.new(1.1, 0.7, 0.7), cf * CFrame.new(-4.5 + i * 1.8, 3 + row * 2, 3.8) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromHSV((i * 0.15 + row * 0.4) % 1, 0.5, 1), {
					Shape = Enum.PartType.Cylinder,
					Material = Enum.Material.Neon,
					Transparency = 0.2,
					CanCollide = false,
				})
		end
	end
	for _, x in { -7.5, 7.5 } do
		for _, z in { -4.5, 4.5 } do
			newPart(stall, "Post", Vector3.new(0.6, 9, 0.6), cf * CFrame.new(x, 4.7, z), dark, { Material = Enum.Material.Wood })
		end
	end
	for i = 0, 7 do
		newPart(stall, "Canopy" .. i, Vector3.new(2.1, 0.25, 11), cf * CFrame.new(-7.35 + i * 2.1, 9.4, 0) * CFrame.Angles(math.rad(-8), 0, 0),
			i % 2 == 0 and accent or Color3.fromRGB(255, 250, 245), { Material = Enum.Material.Fabric })
	end
	local sign = newPart(stall, "Sign", Vector3.new(10, 2.2, 0.3), cf * CFrame.new(0, 7.6, -4.7), Color3.fromRGB(255, 250, 240), {
		Material = Enum.Material.Wood,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = title
	label.TextColor3 = accent:Lerp(Color3.new(0, 0, 0), 0.35)
	label.Parent = surface
	for _, x in { -5, 5 } do
		local lamp = newPart(stall, "Lamp", Vector3.new(0.8, 1, 0.8), cf * CFrame.new(x, 8.4, -4.2), Color3.fromRGB(255, 225, 170), {
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Range = 16
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 215, 165)
		light.Parent = lamp
	end
	local spot = newPart(stall, vendor .. "Spot", Vector3.one, cf * CFrame.new(0, 0.4, 0), Color3.new(1, 1, 1), MARKER)
	spot:SetAttribute("Npc", vendor)
	stall.Parent = parent
	return stall
end

-- One wedge-like slice of a ring (used to build the round floating continent)
local SEGMENTS = 48
local function ringSegment(parent: Instance, name: string, thetaDeg: number, r0: number, r1: number, top: number, thick: number,
	color: Color3, material: Enum.Material, zone: { [string]: any }?)
	local theta = math.rad(thetaDeg)
	local dir = Vector3.new(math.cos(theta), 0, math.sin(theta))
	local mid = dir * ((r0 + r1) / 2) + Vector3.new(0, top - thick / 2, 0)
	local width = 2 * r1 * math.sin(math.pi / SEGMENTS) * 1.08
	local p = newPart(parent, name, Vector3.new(width, thick, r1 - r0), CFrame.lookAt(mid, mid + dir), color, {
		Material = material,
		CastShadow = false, -- the continent must not darken the hub below
	})
	if zone then
		for k, v in zone do
			p:SetAttribute(k, v)
		end
	end
	return p
end

local function buildPlaceholder(): Instance
	local m = Instance.new("Folder")
	m.Name = "Map"

	local Y = 40 -- hub level
	local UP = 200 -- top of the floating continent
	local DEATH = -20 -- death cloud floor
	local hubR = 60
	local hubColor = Color3.fromRGB(235, 238, 248)
	local rng = Random.new(2026)

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
	local continent = getFolder(m, "Continent")

	local spawnCount = 0
	local function spawnPoint(pos: Vector3, biome: string)
		spawnCount += 1
		local p = newPart(spawns, "Spawn" .. spawnCount, Vector3.new(2, 2, 2), CFrame.new(pos), Color3.new(1, 1, 1), MARKER)
		p:SetAttribute("Biome", biome)
	end
	local function polar(r: number, deg: number, y: number): Vector3
		local t = math.rad(deg)
		return Vector3.new(math.cos(t) * r, y, math.sin(t) * r)
	end
	local function hazardFlag(part: BasePart, kind: string)
		part.CanCollide = false
		part.CanQuery = true
		part.CanTouch = false
		part.CastShadow = false
		part:SetAttribute("HazardType", kind)
		part.Parent = hazards
	end

	------------------------------------------------------------------
	-- HEXAGON HUB (Y 40, R 60) + 2 shops + spawn ring
	------------------------------------------------------------------
	local hubCF = CFrame.new(0, Y, 0)
	hexagon(route, "HubDeck", hubCF * CFrame.new(0, -1, 0), hubR, 2, hubColor, { Material = Enum.Material.Marble })
	hexagon(decor, "HubGlass", hubCF * CFrame.new(0, 0.06, 0), hubR * 0.55, 0.12, Color3.fromRGB(170, 210, 255), {
		Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, CanQuery = false,
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
		if i ~= 0 and i ~= 3 then -- corners 0 and 3 hold the shops
			newPart(decor, "Pillar" .. i, Vector3.new(2.5, 16, 2.5), CFrame.new(cpos + Vector3.new(0, 8, 0)), Color3.fromRGB(245, 240, 230), { Material = Enum.Material.Marble })
			local orb = newPart(decor, "PillarOrb" .. i, Vector3.one * 3, CFrame.new(cpos + Vector3.new(0, 17.5, 0)), Color3.fromRGB(170, 220, 255), {
				Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, CanCollide = false,
			})
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 1.2
			light.Color = orb.Color
			light.Parent = orb
		end
	end
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
	local hubZone = newPart(zones, "Hub", Vector3.new(130, 40, 130), CFrame.new(0, Y + 10, 0), hubColor, {
		Transparency = 1, CanCollide = false, CanQuery = true, CanTouch = false,
	})
	hubZone:SetAttribute("ZoneName", "Hexagon Hub")
	hubZone:SetAttribute("ZoneColor", Color3.fromRGB(200, 230, 255))
	zoneSign(signs, "HubSign", Vector3.new(0, Y + 30, 0), "STEAL A CLOUD", Color3.fromRGB(255, 255, 255))

	shopStall(decor, "ItemShop", Vector3.new(-44, Y, 0), Vector3.new(0, Y, 0), "Tayron", "ITEM SHOP", Color3.fromRGB(120, 200, 255))
	shopStall(decor, "UpgradeShop", Vector3.new(44, Y, 0), Vector3.new(0, Y, 0), "Aurelius", "UPGRADES", Color3.fromRGB(255, 205, 90))

	------------------------------------------------------------------
	-- 12 BASES, farther out (radius 140), each with an empty Expansion pad
	-- beside it for future buildings
	------------------------------------------------------------------
	local roofs = getFolder(m, "Rooftops")
	local expansion = getFolder(m, "Expansion")
	for i = 1, 12 do
		local a = math.rad((i - 1) * 30 + 15)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local center = dir * 140 + Vector3.new(0, Y, 0)
		BaseBuilder.Build(roofs, "Rooftop" .. i, center, Color3.fromHSV((i - 1) / 12, 0.45, 1), Vector3.new(0, Y, 0))
		local mid = dir * 92 + Vector3.new(0, Y - 0.5, 0)
		newPart(route, "BaseBridge" .. i, Vector3.new(6, 1, 78), CFrame.lookAt(mid, mid + dir), hubColor, { Material = Enum.Material.Marble })
		-- expansion pad (empty) + short connector
		local padPos = center + side * 30 + Vector3.new(0, -0.5, 0)
		local pad = newPart(expansion, "ExpansionPad" .. i, Vector3.new(20, 1, 20), CFrame.lookAt(padPos, padPos + dir), Color3.fromRGB(220, 225, 235), {
			Material = Enum.Material.Concrete,
		})
		pad:SetAttribute("ExpansionSlot", i)
		local linkPos = center + side * 16 + Vector3.new(0, -0.5, 0)
		newPart(expansion, "ExpansionLink" .. i, Vector3.new(8, 1, 6), CFrame.lookAt(linkPos, linkPos + dir), hubColor, { Material = Enum.Material.Marble })
	end

	------------------------------------------------------------------
	-- UPDRAFT through the hole in the continent's center
	------------------------------------------------------------------
	local updraft = airColumn(air, "Updraft", Vector3.new(14, UP + 18 - Y, 14), Vector3.new(0, (Y + UP + 18) / 2, 0), 110,
		Color3.fromRGB(190, 235, 255))
	updraft:SetAttribute("ExitHeight", UP + 6)
	updraft:SetAttribute("LaunchTarget", Vector3.new(0, UP + 3, -28))
	updraft:SetAttribute("LaunchTime", 0.8)
	newPart(decor, "UpdraftPad", Vector3.new(0.6, 16, 16), CFrame.new(0, Y + 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 220, 255), {
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, CanCollide = false,
	})
	zoneSign(signs, "UpdraftSign", Vector3.new(0, Y + 12, 0), "UPDRAFT - to the Floating Continent", Color3.fromRGB(190, 235, 255))

	------------------------------------------------------------------
	-- FLOATING CONTINENT (Y 200, radius ~182), built from 48 slices.
	--   r 14-80   Plateau (center, flat)
	--   r 80-140  north: Mountains · south: Valley (stepped down, pits) · east/west: Plateau
	--   r 140-182 Coast (sand + shallows)
	------------------------------------------------------------------
	local Z_PLATEAU = { ZoneName = "Plateau", ZoneColor = Color3.fromRGB(150, 230, 150), Biome = "Plateau" }
	local Z_COAST = { ZoneName = "Coast", ZoneColor = Color3.fromRGB(255, 225, 160), Biome = "Coast" }
	local Z_MOUNT = { ZoneName = "Mountains", ZoneColor = Color3.fromRGB(210, 220, 235), Biome = "Mountains",
		Warning = "Icy ledges up high - Frost Cloud perk helps" }
	local Z_VALLEY = { ZoneName = "Valley", ZoneColor = Color3.fromRGB(190, 140, 255), Biome = "Valley",
		Warning = "Pits, an electric river and a storm bridge - watch your step!" }

	local grass = Color3.fromRGB(125, 195, 120)
	local rock = Color3.fromRGB(150, 145, 140)
	local valleyGround = Color3.fromRGB(105, 90, 110)
	local sand = Color3.fromRGB(240, 220, 170)

	local function inRange(deg: number, a: number, b: number)
		return deg >= a and deg < b
	end

	for k = 0, SEGMENTS - 1 do
		local deg = (k + 0.5) * 360 / SEGMENTS
		ringSegment(continent, "Plateau" .. k, deg, 14, 80, UP, 4, grass, Enum.Material.Grass, Z_PLATEAU)

		if inRange(deg, 45, 135) then
			ringSegment(continent, "MountainBase" .. k, deg, 80, 140, UP, 4, rock, Enum.Material.Rock, Z_MOUNT)
		elseif inRange(deg, 225, 315) then
			-- stepped valley: 4-stud steps you can jump even while carrying
			local pit = inRange(deg, 255, 285)
			ringSegment(continent, "ValleyStepA" .. k, deg, 80, 88, UP - 4, 4, valleyGround, Enum.Material.Ground, Z_VALLEY)
			ringSegment(continent, "ValleyStepB" .. k, deg, 88, 96, UP - 8, 4, valleyGround, Enum.Material.Ground, Z_VALLEY)
			if pit then
				-- a gap from r 100 to 124 = a pit straight down to the death clouds
				ringSegment(continent, "ValleyFloorIn" .. k, deg, 96, 100, UP - 12, 4, valleyGround, Enum.Material.Ground, Z_VALLEY)
				ringSegment(continent, "ValleyFloorOut" .. k, deg, 124, 128, UP - 12, 4, valleyGround, Enum.Material.Ground, Z_VALLEY)
			else
				ringSegment(continent, "ValleyFloor" .. k, deg, 96, 128, UP - 12, 4, valleyGround, Enum.Material.Ground, Z_VALLEY)
			end
			ringSegment(continent, "ValleyStepC" .. k, deg, 128, 134, UP - 8, 4, valleyGround, Enum.Material.Ground, Z_VALLEY)
			ringSegment(continent, "ValleyStepD" .. k, deg, 134, 140, UP - 4, 4, valleyGround, Enum.Material.Ground, Z_VALLEY)
		else
			ringSegment(continent, "PlateauOuter" .. k, deg, 80, 140, UP, 4, grass, Enum.Material.Grass, Z_PLATEAU)
		end

		ringSegment(continent, "Coast" .. k, deg, 140, 172, UP - 0.5, 4, sand, Enum.Material.Sand, Z_COAST)
		ringSegment(continent, "Shallows" .. k, deg, 172, 182, UP - 1.5, 4, Color3.fromRGB(120, 200, 230), Enum.Material.Glass, Z_COAST)
	end

	-- Rocky underside (a ring of boulders, leaving the center free for the updraft)
	for i = 1, 24 do
		local deg = i * 15 + rng:NextNumber(-5, 5)
		local r = rng:NextNumber(60, 150)
		local size = rng:NextNumber(40, 70)
		local p = newPart(continent, "Underside" .. i, Vector3.new(size, size * 0.6, size), CFrame.new(polar(r, deg, UP - 10 - size * 0.3)),
			Color3.fromRGB(120, 100, 90), { Material = Enum.Material.Slate, CastShadow = false })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end

	-- MOUNTAINS: terraced peaks (5-stud steps), icy upper ledges, Altar1 on top
	local function peak(name: string, center: Vector3, radius: number, tiers: number, icyFrom: number)
		for t = 1, tiers do
			local r = radius - (t - 1) * (radius - 5) / tiers
			local top = center.Y + t * 5
			local tier = newPart(continent, name .. "Tier" .. t, Vector3.new(5, r * 2, r * 2), CFrame.new(center.X, top - 2.5, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
				t >= icyFrom and Color3.fromRGB(235, 245, 255) or rock, {
					Shape = Enum.PartType.Cylinder,
					Material = t >= icyFrom and Enum.Material.Snow or Enum.Material.Rock,
					CastShadow = false,
				})
			for key, v in Z_MOUNT do
				tier:SetAttribute(key, v)
			end
			if t >= icyFrom then
				local ice = newPart(continent, name .. "Ice" .. t, Vector3.new(0.2, r * 2, r * 2), CFrame.new(center.X, top + 0.1, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
					Color3.fromRGB(215, 240, 255), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glacier, Transparency = 0.25 })
				hazardFlag(ice, "Ice")
			end
		end
		return center + Vector3.new(0, tiers * 5, 0)
	end
	local summit = peak("PeakMain", polar(110, 90, UP), 28, 8, 4)
	peak("PeakWest", polar(105, 60, UP), 18, 5, 4)
	peak("PeakEast", polar(112, 122, UP), 20, 5, 4)
	altar(decor, altars, "Altar1", summit)
	altars:FindFirstChild("Altar1"):SetAttribute("Biome", "Mountains")

	-- VALLEY: electric river arcs + storm bridge over the pit, Altar2 beyond
	for k = 0, SEGMENTS - 1 do
		local deg = (k + 0.5) * 360 / SEGMENTS
		if inRange(deg, 228, 252) or inRange(deg, 288, 312) then
			local river = ringSegment(continent, "River" .. k, deg, 106, 116, UP - 11.6, 0.8, Color3.fromRGB(60, 140, 230), Enum.Material.Glass)
			river.Transparency = 0.3
			hazardFlag(river, "River")
		end
	end
	local bridgeMid = polar(112, 270, UP - 12.5)
	local bridge = newPart(route, "StormBridge", Vector3.new(6, 1, 34), CFrame.lookAt(bridgeMid, bridgeMid + polar(1, 270, 0)), Color3.fromRGB(80, 75, 95), {
		Material = Enum.Material.DiamondPlate,
	})
	for key, v in Z_VALLEY do
		bridge:SetAttribute(key, v)
	end
	local storm = newPart(hazards, "StormBridge1", Vector3.new(6, 0.2, 34), bridge.CFrame * CFrame.new(0, 0.6, 0), Color3.new(0, 0, 0), { Transparency = 1 })
	hazardFlag(storm, "Storm")
	local altar2 = altar(decor, altars, "Altar2", polar(160, 270, UP))
	altar2:SetAttribute("Biome", "Coast")

	-- Biome spawn points
	for _ = 1, 12 do
		spawnPoint(polar(rng:NextNumber(24, 74), rng:NextNumber(0, 360), UP + 3), "Plateau")
	end
	for _ = 1, 6 do
		local deg = rng:NextNumber(0, 1) < 0.5 and rng:NextNumber(140, 220) or rng:NextNumber(320, 400) % 360
		spawnPoint(polar(rng:NextNumber(88, 134), deg, UP + 3), "Plateau")
	end
	for _ = 1, 14 do
		spawnPoint(polar(rng:NextNumber(146, 168), rng:NextNumber(0, 360), UP + 2.5), "Coast")
	end
	-- on the ledges of the terraced peaks (between one tier's edge and the next)
	local function ledge(center: Vector3, radius: number, tiers: number, t: number, aroundDeg: number): Vector3
		local rT = radius - (t - 1) * (radius - 5) / tiers
		local rN = radius - t * (radius - 5) / tiers
		return center + polar((rT + rN) / 2, aroundDeg, 5 * t + 3)
	end
	local mainC, westC, eastC = polar(110, 90, UP), polar(105, 60, UP), polar(112, 122, UP)
	for _, pos in {
		summit + Vector3.new(0, 3, 0),
		ledge(mainC, 28, 8, 3, 200), ledge(mainC, 28, 8, 6, 20),
		ledge(westC, 18, 5, 3, 250), ledge(eastC, 20, 5, 3, 300),
		polar(88, 75, UP + 3), polar(136, 100, UP + 3), polar(132, 55, UP + 3),
	} do
		spawnPoint(pos, "Mountains")
	end
	for _, deg in { 232, 240, 248, 292, 300, 308, 262, 278 } do
		local r = (deg > 255 and deg < 285) and 98 or 120
		spawnPoint(polar(r, deg, UP - 9), "Valley")
	end

	------------------------------------------------------------------
	-- DEATH CLOUD FLOOR: no void — a thick cloud sea below everything.
	-- Touching it kills you; you respawn at your base.
	------------------------------------------------------------------
	local abyss = getFolder(m, "Abyss")
	local slab = newPart(abyss, "DeathClouds", Vector3.new(2048, 6, 2048), CFrame.new(0, DEATH - 3, 0), Color3.fromRGB(235, 238, 245), {
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local fog = Instance.new("ParticleEmitter")
	fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fog.Color = ColorSequence.new(Color3.fromRGB(240, 242, 250))
	fog.Size = NumberSequence.new(60, 120)
	fog.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1),
	})
	fog.Lifetime = NumberRange.new(10, 16)
	fog.Rate = 40
	fog.Speed = NumberRange.new(1, 3)
	fog.EmissionDirection = Enum.NormalId.Top
	fog.SpreadAngle = Vector2.new(30, 30)
	fog.LightInfluence = 1
	fog.Parent = slab
	-- big puffy cloud lumps on top of the sea (decor only)
	local sea = getFolder(decor, "CloudSea")
	for i = 1, 140 do
		local pos = Vector3.new(rng:NextNumber(-700, 700), DEATH + rng:NextNumber(-2, 10), rng:NextNumber(-700, 700))
		local w = rng:NextNumber(30, 90)
		local puff = newPart(sea, "Puff" .. i, Vector3.new(w, w * rng:NextNumber(0.3, 0.5), w * rng:NextNumber(0.7, 1.1)), CFrame.new(pos),
			Color3.fromRGB(245, 247, 252):Lerp(Color3.fromRGB(200, 205, 225), rng:NextNumber()), {
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = puff
	end

	------------------------------------------------------------------
	-- Decorative floating islands (outside everything)
	------------------------------------------------------------------
	local islandSpots = {
		{ Vector3.new(-260, Y + 30, 120), 28 }, { Vector3.new(270, Y + 60, -80), 32 },
		{ Vector3.new(-240, UP - 20, -200), 26 }, { Vector3.new(230, UP + 20, 210), 30 },
		{ Vector3.new(60, UP + 50, -280), 24 }, { Vector3.new(-120, Y - 5, 260), 26 },
	}
	for i, spot in islandSpots do
		local pos, size = spot[1], spot[2]
		local island = Instance.new("Model")
		island.Name = "Island" .. i
		local top = newPart(island, "Grass", Vector3.new(3, size, size), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), grass, {
			Shape = Enum.PartType.Cylinder, Material = Enum.Material.Grass,
		})
		newPart(island, "Rock", Vector3.one * size * 0.7, CFrame.new(pos - Vector3.new(0, size * 0.3, 0)), Color3.fromRGB(150, 120, 95), {
			Shape = Enum.PartType.Ball, Material = Enum.Material.Slate,
		})
		island.PrimaryPart = top
		island:SetAttribute("FloatAmplitude", 1 + (i % 3) * 0.5)
		island.Parent = decor
		CollectionService:AddTag(island, "FloatingIsland")
	end

	getFolder(getFolder(m, "CrateArena"), "CrateSpawns")

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
