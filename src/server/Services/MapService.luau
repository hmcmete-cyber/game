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
--   HuntZone/WeatherSpawns/SpawnN (Part, attribute Biome = Plateau|Coast|Mountains|Mushroom|Marsh|Canyon|Volcanic)
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
local BiomeMap = require(ReplicatedStorage.Shared.BiomeMap)
local BaseBuilder = require(script.Parent:WaitForChild("BaseBuilder"))
local ContinentBuilder = require(script.Parent:WaitForChild("ContinentBuilder"))

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
		Transparency = 0.7, -- v1.8: soft shimmer, not a hard beam
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
	-- v2.5 shop dressing: eave trim, supply crates, barrels and a potted
	-- plant (all beside the stall, the walk-up area in front stays clear)
	newPart(stall, "EaveFront", Vector3.new(17, 0.5, 0.6), cf * CFrame.new(0, 8.6, -5.6), accent, {})
	newPart(stall, "EaveBack", Vector3.new(17, 0.5, 0.6), cf * CFrame.new(0, 10.1, 5.6), accent, {})
	for k, off in { Vector3.new(-9.6, 0.9, 2.5), Vector3.new(-9.6, 2.6, 2.5), Vector3.new(-9.4, 0.9, 0.6) } do
		newPart(stall, "Crate" .. k, Vector3.new(1.8, 1.8, 1.8), cf * CFrame.new(off) * CFrame.Angles(0, k * 0.3, 0), Color3.fromRGB(205, 150, 90), {})
	end
	for k, off in { Vector3.new(9.6, 1.2, 2.6), Vector3.new(9.4, 1.2, 0.4) } do
		newPart(stall, "Barrel" .. k, Vector3.new(2.4, 1.8, 1.8), cf * CFrame.new(off) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 100, 65), { Shape = Enum.PartType.Cylinder })
		newPart(stall, "BarrelBand" .. k, Vector3.new(0.3, 1.95, 1.95), cf * CFrame.new(off) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(90, 90, 100), { Shape = Enum.PartType.Cylinder })
	end
	newPart(stall, "Pot", Vector3.new(1.6, 1.4, 1.6), cf * CFrame.new(9.2, 0.7, -3.4), Color3.fromRGB(200, 110, 80), {})
	newPart(stall, "Plant", Vector3.one * 2.2, cf * CFrame.new(9.2, 2.3, -3.4), Color3.fromRGB(90, 175, 90), { Shape = Enum.PartType.Ball })

	local spot = newPart(stall, vendor .. "Spot", Vector3.one, cf * CFrame.new(0, 0.4, 0), Color3.new(1, 1, 1), MARKER)
	spot:SetAttribute("Npc", vendor)
	stall.Parent = parent
	return stall
end

-- Bump when the generated layout changes: older generated maps are rebuilt
-- automatically. A hand-made map keeps itself by setting attribute Custom = true.
local MAP_VERSION = "2.9"
local DEATH_Y = 10 -- top of the death cloud floor (v1.6: -20 -> 0, v2.0: -> 10)

-- v2.2 CLASSIC STUDDED STYLE PASS over the whole generated map: every solid
-- part becomes toy Plastic; flat, level tops at least 4 studs wide get
-- Studs (floors, decks, bridges, paths, steps, ledges). Left alone: clouds
-- (SpecialMesh ellipsoids), Neon/Glass/ForceField/Glacier, see-through or
-- invisible parts (markers, hazards).
local KEEP_MATERIAL = {
	[Enum.Material.Neon] = true, [Enum.Material.Glass] = true, [Enum.Material.ForceField] = true, [Enum.Material.Glacier] = true,
}
local function studPass(root: Instance): number
	local studded = 0
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and not KEEP_MATERIAL[p.Material] and p.Transparency < 0.5 and not p:FindFirstChildOfClass("SpecialMesh") then
			p.Material = Enum.Material.Plastic
			if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.CFrame.UpVector.Y > 0.99
				and math.min(p.Size.X, p.Size.Z) >= 4 and p.TopSurface ~= Enum.SurfaceType.Studs then
				p.TopSurface = Enum.SurfaceType.Studs
				p.BottomSurface = Enum.SurfaceType.Inlet
				studded += 1
			end
		end
	end
	-- v2.7 (director: "classic texture everywhere", incl. cliff and slope
	-- faces): continent blocks and wedges get studs on their side faces too
	local continent = root:FindFirstChild("Continent")
	if continent then
		for _, p in continent:GetDescendants() do
			if (p:IsA("WedgePart") or (p:IsA("Part") and p.Shape == Enum.PartType.Block))
				and p.Material == Enum.Material.Plastic and p.Transparency < 0.5 and math.min(p.Size.X, p.Size.Y, p.Size.Z) >= 2 then
				p.FrontSurface = Enum.SurfaceType.Studs
				p.BackSurface = Enum.SurfaceType.Studs
				p.LeftSurface = Enum.SurfaceType.Studs
				p.RightSurface = Enum.SurfaceType.Studs
				if p:IsA("WedgePart") then
					p.TopSurface = Enum.SurfaceType.Studs -- the slope
				end
			end
		end
	end
	return studded
end

local function buildPlaceholder(): Instance
	local m = Instance.new("Folder")
	m.Name = "Map"

	local Y = 40 -- hub level
	local UP = BiomeMap.UP -- top of the floating continent (v2.4: 320, was 200)
	local DEATH = DEATH_Y -- death cloud floor (Y 0; hub/base undersides end around Y 23)
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
	-- v2.5 hub dressing: benches + planters between the spawn ring and the rim
	for i = 0, 5 do
		local a = math.rad(i * 60)
		if i ~= 0 and i ~= 3 then -- keep the two shop corners clear
			local pos = Vector3.new(math.cos(a) * 40, Y, math.sin(a) * 40)
			local face = CFrame.lookAt(pos, Vector3.new(0, Y, 0))
			newPart(decor, "BenchSeat" .. i, Vector3.new(5, 0.5, 1.6), face * CFrame.new(0, 1.3, 0), Color3.fromRGB(170, 120, 80), {})
			newPart(decor, "BenchBack" .. i, Vector3.new(5, 1.4, 0.4), face * CFrame.new(0, 2.2, 0.7), Color3.fromRGB(170, 120, 80), {})
			for k = -1, 1, 2 do
				newPart(decor, "BenchLeg" .. i .. k, Vector3.new(0.4, 1.1, 1.4), face * CFrame.new(k * 2.1, 0.55, 0), Color3.fromRGB(90, 90, 100), {})
			end
			local pp = Vector3.new(math.cos(a + 0.22) * 44, Y, math.sin(a + 0.22) * 44)
			newPart(decor, "Planter" .. i, Vector3.new(3, 1.6, 3), CFrame.new(pp + Vector3.new(0, 0.8, 0)), Color3.fromRGB(225, 225, 235), {})
			newPart(decor, "PlanterBush" .. i, Vector3.one * 3, CFrame.new(pp + Vector3.new(0, 2.4, 0)), Color3.fromRGB(100, 185, 95), { Shape = Enum.PartType.Ball })
		end
	end

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
		local bridge = newPart(route, "BaseBridge" .. i, Vector3.new(6, 1, 78), CFrame.lookAt(mid, mid + dir), hubColor, { Material = Enum.Material.Marble })
		-- v2.5: posts + handrails on both sides (path stays 6 wide)
		for side = -1, 1, 2 do
			for k = -3, 3 do
				newPart(decor, "BridgePost" .. i .. "_" .. side .. "_" .. k, Vector3.new(0.6, 2.4, 0.6), bridge.CFrame * CFrame.new(side * 3.2, 1.6, k * 12.5), Color3.fromRGB(235, 238, 248), {})
			end
			newPart(decor, "BridgeRail" .. i .. "_" .. side, Vector3.new(0.4, 0.4, 76), bridge.CFrame * CFrame.new(side * 3.2, 2.7, 0), Color3.fromHSV((i - 1) / 12, 0.45, 1), {})
		end
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
	-- in a Persistent model so StreamingEnabled never unloads it
	local updraftModel = Instance.new("Model")
	updraftModel.Name = "UpdraftModel"
	updraftModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	updraftModel.Parent = air
	local updraft = airColumn(updraftModel, "Updraft", Vector3.new(14, UP + 18 - Y, 14), Vector3.new(0, (Y + UP + 18) / 2, 0), 140,
		Color3.fromRGB(190, 235, 255))
	updraft:SetAttribute("ExitHeight", UP + 6)
	-- one smooth arc into the Sky Heart plaza at the continent's center
	updraft:SetAttribute("LaunchTarget", Vector3.new(46, UP + 4, 0))
	updraft:SetAttribute("LaunchTime", 0.95) -- v2.0: higher, longer arc (sideways speed held by LaunchCarry)
	-- v1.8 two-way: drop into the Sky Heart hole to ride DOWN to the hub
	updraft:SetAttribute("BottomY", Y)
	updraft:SetAttribute("DownSpeed", 70)
	zoneSign(signs, "UpdraftDownSign", Vector3.new(0, UP + 14, 0), "DOWN", Color3.fromRGB(255, 200, 120))
	newPart(decor, "UpdraftPad", Vector3.new(0.6, 16, 16), CFrame.new(0, Y + 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 220, 255), {
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, CanCollide = false,
	})
	zoneSign(signs, "UpdraftSign", Vector3.new(0, Y + 12, 0), "UP!", Color3.fromRGB(190, 235, 255))

	------------------------------------------------------------------
	-- FLOATING CONTINENT (Y 200, radius ~314, 7 biomes) — see ContinentBuilder
	------------------------------------------------------------------
	ContinentBuilder.Build({
		newPart = newPart, MARKER = MARKER, polar = polar, UP = UP, rng = rng,
		continent = continent, decor = decor, hazards = hazards, altars = altars, route = route, signs = signs,
		spawnPoint = spawnPoint, hazardFlag = hazardFlag, altar = altar, zoneSign = zoneSign,
	})

	------------------------------------------------------------------
	-- DEATH CLOUD FLOOR: no void — a thick cloud sea below everything.
	-- Touching it kills you; you respawn at your base.
	------------------------------------------------------------------
	local abyss = getFolder(m, "Abyss")
	-- the kill slab itself is invisible now (it looked like a flat plate);
	-- what you SEE is the puffy cloud bank + low fog drifting on top of it
	local slab = newPart(abyss, "DeathClouds", Vector3.new(2048, 6, 2048), CFrame.new(0, DEATH - 3, 0), Color3.fromRGB(235, 238, 245), {
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local fog = Instance.new("ParticleEmitter")
	fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fog.Color = ColorSequence.new(Color3.fromRGB(240, 242, 250))
	fog.Size = NumberSequence.new(60, 120)
	fog.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(1, 1),
	})
	fog.Lifetime = NumberRange.new(10, 16)
	fog.Rate = 50
	fog.Speed = NumberRange.new(1, 3)
	fog.EmissionDirection = Enum.NormalId.Top
	fog.SpreadAngle = Vector2.new(30, 30)
	fog.LightInfluence = 1
	fog.Parent = slab
	-- v2.0 CLOUD BANK (decor only, never lethal by itself): puffy masses of
	-- 5 overlapping rounded lobes, on a jittered 160-stud grid from r 230
	-- outward (inside r 230 the hub and the 12 bases float above open fog).
	-- Centres Y 14-20 (just above the kill height); masses never touch.
	local sea = getFolder(decor, "CloudSea")
	local function lobe(parent: Instance, size: Vector3, cf: CFrame, color: Color3)
		local p = newPart(parent, "Lobe", size, cf, color, {
			Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		})
		p.Transparency = 0.06
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	local i = 0
	for gx = -1040, 1040, 160 do
		for gz = -1040, 1040, 160 do
			local c = Vector3.new(gx + rng:NextNumber(-25, 25), DEATH + rng:NextNumber(4, 10), gz + rng:NextNumber(-25, 25))
			local rr = Vector2.new(c.X, c.Z).Magnitude
			local clear = true
			if rr <= 230 then
				-- v2.3 inner fill under the hub + bases (the gray Baseplate used to
				-- show here): sunk lower (tops stay < Y ~31) and kept away from the
				-- hub rock and every base's rock underside
				c = Vector3.new(c.X, DEATH - 9, c.Z)
				if rr < 85 then
					clear = false
				end
				for b = 1, 12 do
					local a = math.rad((b - 1) * 30 + 15)
					if (Vector2.new(c.X, c.Z) - Vector2.new(math.cos(a) * 140, math.sin(a) * 140)).Magnitude < 45 then
						clear = false
					end
				end
			end
			for _, isl in { Vector2.new(-260, 120), Vector2.new(270, -80), Vector2.new(-120, 260) } do -- hub-level decor islands
				if (Vector2.new(c.X, c.Z) - isl).Magnitude < 90 then
					clear = false
				end
			end
			if clear then
				i += 1
				local w = rr <= 230 and rng:NextNumber(55, 70) or rng:NextNumber(70, 105) -- <= 105 wide on a 160 grid with 25 jitter: masses never touch
				local mass = Instance.new("Model")
				mass.Name = "Bank" .. i
				local yaw = CFrame.new(c) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
				local top, belly = Color3.fromRGB(250, 251, 255), Color3.fromRGB(212, 220, 236)
				lobe(mass, Vector3.new(w, w * 0.34, w * 0.66), yaw, belly)
				lobe(mass, Vector3.new(w * 0.46, w * 0.38, w * 0.42), yaw * CFrame.new(-w * 0.22, w * 0.12, 0), belly:Lerp(top, 0.6))
				lobe(mass, Vector3.new(w * 0.5, w * 0.42, w * 0.46), yaw * CFrame.new(w * 0.14, w * 0.15, w * 0.04), belly:Lerp(top, 0.75))
				lobe(mass, Vector3.new(w * 0.32, w * 0.3, w * 0.3), yaw * CFrame.new(w * 0.36, w * 0.08, -w * 0.06), belly:Lerp(top, 0.6))
				lobe(mass, Vector3.new(w * 0.3, w * 0.28, w * 0.3), yaw * CFrame.new(-w * 0.02, w * 0.28, 0), top)
				-- v2.7 detail: small curls along the top and the rim break up the outline
				for k = 1, 5 do
					local cs = w * rng:NextNumber(0.13, 0.22)
					lobe(mass, Vector3.new(cs, cs * 0.85, cs), yaw * CFrame.new(rng:NextNumber(-0.42, 0.42) * w, w * rng:NextNumber(0.14, 0.3), rng:NextNumber(-0.2, 0.2) * w),
						belly:Lerp(top, rng:NextNumber(0.6, 1)))
				end
				mass.Parent = sea
			end
		end
	end

	------------------------------------------------------------------
	-- Decorative floating islands (outside everything)
	------------------------------------------------------------------
	local islandSpots = {
		-- hub-level islands stay below the continent's keel (Y ~96); sky islands sit beyond its coast (r > 820)
		{ Vector3.new(-260, Y + 22, 120), 28 }, { Vector3.new(270, Y + 25, -80), 32 },
		{ Vector3.new(-760, UP - 20, -480), 26 }, { Vector3.new(700, UP + 30, 640), 30 },
		{ Vector3.new(120, UP + 70, -900), 24 }, { Vector3.new(-120, Y - 5, 260), 26 },
	}
	for i, spot in islandSpots do
		local pos, size = spot[1], spot[2]
		local island = Instance.new("Model")
		island.Name = "Island" .. i
		island.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local top = newPart(island, "Grass", Vector3.new(3, size, size), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(125, 195, 120), {
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

	print(`[MapCheck] studded {studPass(m)} extra surfaces`)
	m.Parent = workspace
	m:SetAttribute("MapVersion", MAP_VERSION)
	ContinentBuilder.FixSpawns(m, UP)
	local count = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	print(`[MapCheck] Map v{MAP_VERSION}: {count} parts`)
	return m
end

-- The Roblox template's gray checkerboard "Baseplate" sits under the hub and
-- ruins the lower view (director). The generated world never stands on it
-- (the death floor is above it), so it is removed whenever the generated map
-- is used. A hand-made map (attribute Custom) keeps whatever it has.
local function removeTemplateBaseplate(map: Instance?)
	if map and map:GetAttribute("Custom") then
		return
	end
	local bp = workspace:FindFirstChild("Baseplate")
	if bp and bp:IsA("BasePart") then
		print("[Map] removed the template workspace.Baseplate (gray checkerboard)")
		bp:Destroy()
	end
end

-- Also used from the Studio Command Bar (docs/MapBuilder.luau) to save the
-- placeholder into the place. Does nothing if workspace.Map already exists.
function MapService.BuildPlaceholder(): Instance
	local existing = workspace:FindFirstChild("Map")
	if existing and (existing:GetAttribute("Custom") or existing:GetAttribute("MapVersion") == MAP_VERSION) then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local m = buildPlaceholder()
	m.Parent = workspace
	removeTemplateBaseplate(m)
	return m
end

function MapService.Start()
	map = workspace:FindFirstChild("Map")
	if map and not map:GetAttribute("Custom") and map:GetAttribute("MapVersion") ~= MAP_VERSION then
		warn("[Map] old generated map (version " .. tostring(map:GetAttribute("MapVersion")) .. ") — rebuilding v" .. MAP_VERSION)
		map:Destroy()
		map = nil
	end
	if not map then
		map = buildPlaceholder()
		print("[Map] workspace.Map not found — built placeholder map")
	end

	removeTemplateBaseplate(map)

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

	-- Safety net: very fast falls can skip a Touched event, so also kill by height
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, plr in Players:GetPlayers() do
				local char = plr.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 and root.Position.Y < DEATH_Y + 2 then
					hum.Health = 0
				end
			end
		end
	end)
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
