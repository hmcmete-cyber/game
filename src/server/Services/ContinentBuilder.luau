-- FLOATING CONTINENT v1.6 — a huge round island at Y = UP (radius 520).
-- Radii in the table below are authoring units (v1.4); R() stretches them:
--   heart 16-70 -> 16-90, biomes 70-262 -> 90-450, coast 262-314 -> 450-520.
-- Called by MapService.buildPlaceholder with its helpers (ctx).
--
--   (studs after R)  r 16-90 Sky Heart · r 90-450 biome sectors · r 450-520 Coast
--   r  16-70   Sky Heart (center plaza; the updraft comes up through r < 16)
--   r  70-262  six 60° biome sectors (angles: 0° = +X, 90° = +Z)
--                330-30   Plateau Meadows   rolling hills, trees
--                 30-90   Mountains & Snowpeaks   4-stud terraced peaks, ice up high, Altar1
--                 90-150  Mushroom Plateaus   spiral mushroom-cap staircases (acid shelter)
--                150-210  Storm Marshes   sunk 3 studs, electric pools, lightning fields
--                210-270  Crystal Canyons   12 studs deep, pits to the death clouds,
--                                           cave roofs, crystals, storm bridge
--                270-330  Volcanic Caldera   crater with a lava lake, lava pools, Altar3
--   r 262-314  Coast (sand + shallows), Altar2
--
-- Every floor part carries ZoneName / ZoneColor / Biome (the HUD and the
-- acid-rain event read them). Spawn markers carry Biome.

local BiomeMap = require(game:GetService("ReplicatedStorage").Shared.BiomeMap)

local ContinentBuilder = {}

local SEG = 120 -- slices per ring (3° each)

function ContinentBuilder.Build(ctx)
	local newPart, MARKER, polar = ctx.newPart, ctx.MARKER, ctx.polar
	local UP, rng = ctx.UP, ctx.rng
	local continent, decor, hazards, altars, route, signs =
		ctx.continent, ctx.decor, ctx.hazards, ctx.altars, ctx.route, ctx.signs
	local spawnPoint, hazardFlag = ctx.spawnPoint, ctx.hazardFlag

	local function zone(name, color, biome, warning)
		return { ZoneName = name, ZoneColor = color, Biome = biome, Warning = warning }
	end
	local Z = {
		Heart = zone("Sky Heart", Color3.fromRGB(190, 235, 255), "Plateau"),
		Plateau = zone("Plateau Meadows", Color3.fromRGB(150, 230, 150), "Plateau"),
		Mountains = zone("Mountains", Color3.fromRGB(210, 220, 235), "Mountains", "Slippery ice!"),
		Snow = zone("Snowpeaks", Color3.fromRGB(235, 245, 255), "Mountains", "Slippery ice!"),
		Mushroom = zone("Mushroom Plateaus", Color3.fromRGB(230, 150, 220), "Mushroom", "Climb the mushrooms!"),
		Marsh = zone("Storm Marshes", Color3.fromRGB(140, 190, 170), "Marsh", "Zappy water!"),
		Canyon = zone("Crystal Canyons", Color3.fromRGB(190, 140, 255), "Canyon", "Watch the holes!"),
		Volcanic = zone("Volcanic Caldera", Color3.fromRGB(255, 140, 90), "Volcanic", "Hot lava!"),
		Coast = zone("Coast", Color3.fromRGB(255, 225, 160), "Coast"),
	}

	local function tag(p: Instance, z)
		for k, v in z do
			p:SetAttribute(k, v)
		end
		return p
	end

	-- v1.7: the layout is authored in v1.4 units (heart 16-70, biomes 70-262,
	-- coast 262-314). R() stretches it to studs (heart 16-110, biomes 110-590,
	-- coast 590-680) and Wr() bends the outline by angle so the island has an
	-- irregular, map-like coastline (about 555-805 studs from the center).
	local R, Wr = BiomeMap.R, BiomeMap.Wr -- shared with the client (Shared/BiomeMap)
	local function A(r: number, deg: number, y: number): Vector3
		return polar(Wr(R(r), deg), deg, y)
	end

	-- Footprint registry so random props never intersect landmarks or each other
	local used: { { Vector2 | number } } = {}
	local function reserve(pos: Vector3, radius: number)
		table.insert(used, { Vector2.new(pos.X, pos.Z), radius })
	end
	local function isFree(pos: Vector3, radius: number): boolean
		local p2 = Vector2.new(pos.X, pos.Z)
		for _, u in used do
			if (p2 - (u[1] :: Vector2)).Magnitude < radius + (u[2] :: number) then
				return false
			end
		end
		return true
	end
	-- try up to 14 random positions from gen() (nil = rejected roll); returns a free one (reserved) or nil
	local function place(gen: () -> Vector3?, radius: number): Vector3?
		for _ = 1, 14 do
			local pos = gen()
			if pos and isFree(pos, radius) then
				reserve(pos, radius)
				return pos
			end
		end
		return nil
	end

	------------------------------------------------------------------
	-- v2.5 DRESSING KIT (purposeful detail; every prop is a small Model in
	-- Map/Decor/Dressing/<Habitat>, anchored, no scripts)
	------------------------------------------------------------------
	local dressRoot = Instance.new("Folder")
	dressRoot.Name = "Dressing"
	dressRoot.Parent = decor
	local function dressFolder(habitat: string): Folder
		local f = dressRoot:FindFirstChild(habitat)
		if not f then
			f = Instance.new("Folder")
			f.Name = habitat
			f.Parent = dressRoot
		end
		return f :: Folder
	end
	local dressTree: (string, Vector3) -> ()
	local function piece(model: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, shape: string?, collide: boolean?)
		local p = newPart(model, name, size, cf, color, {
			Material = Enum.Material.Plastic, CastShadow = false, CanCollide = collide == true,
			Shape = shape and Enum.PartType[shape] or nil,
		})
		return p
	end
	local function upright(c: Vector3, h: number): CFrame
		return CFrame.new(c + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	end
	-- leafy tree: root flare, trunk, two branches, four-ball canopy
	dressTree = function(name: string, c: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		local h = rng:NextNumber(9, 13)
		local bark, leaf = Color3.fromRGB(125, 88, 60), Color3.fromRGB(85, 170, 85)
		piece(m, "Flare", Vector3.new(1.2, 3.4, 3.4), upright(c, 1.2), bark:Lerp(Color3.new(0, 0, 0), 0.15), "Cylinder", true)
		piece(m, "Trunk", Vector3.new(h, 2, 2), upright(c, h), bark, "Cylinder", true)
		for k = -1, 1, 2 do
			piece(m, "Branch" .. k, Vector3.new(0.8, 4, 0.8), CFrame.new(c + Vector3.new(k * 1.4, h * 0.65, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), math.rad(-k * 45)), bark)
		end
		local top = c + Vector3.new(0, h + 1.5, 0)
		local main = piece(m, "Canopy", Vector3.one * 9, CFrame.new(top), leaf, "Ball")
		main:SetAttribute("Shelter", true)
		for k = 1, 3 do
			local a = k * 2.1 + rng:NextNumber(0, 1)
			piece(m, "Leaves" .. k, Vector3.one * rng:NextNumber(5, 6.5), CFrame.new(top + Vector3.new(math.cos(a) * 3.4, rng:NextNumber(-1.5, 0.5), math.sin(a) * 3.4)),
				leaf:Lerp(Color3.fromRGB(140, 210, 100), k / 4), "Ball")
		end
		m.Parent = dressFolder("Plateau")
	end
	-- snowy pine: trunk + three stacked shrinking tiers with snow caps
	local function dressPine(name: string, c: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		piece(m, "Trunk", Vector3.new(4, 1.4, 1.4), upright(c, 4), Color3.fromRGB(110, 80, 55), "Cylinder", true)
		for t = 0, 2 do
			local rT = 4.5 - t * 1.3
			local y = 3 + t * 2.6
			piece(m, "Tier" .. t, Vector3.new(2.6, rT * 2, rT * 2), CFrame.new(c + Vector3.new(0, y + 1.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(45, 120, 70), "Cylinder")
			piece(m, "Snow" .. t, Vector3.new(0.5, rT * 1.4, rT * 1.4), CFrame.new(c + Vector3.new(0, y + 2.85, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(245, 250, 255), "Cylinder")
		end
		m.Parent = dressFolder("Mountains")
	end
	-- rock cluster: one big tilted block, two medium balls, two pebbles
	local function dressRocks(name: string, c: Vector3, base: Color3, habitat: string)
		local m = Instance.new("Model")
		m.Name = name
		local s = rng:NextNumber(0.8, 1.4)
		piece(m, "Big", Vector3.new(5, 3.4, 4) * s, CFrame.new(c + Vector3.new(0, 1.3 * s, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), base, nil, true)
		piece(m, "MidA", Vector3.one * 3 * s, CFrame.new(c + Vector3.new(2.8, 0.9, 1.2) * s), base:Lerp(Color3.new(1, 1, 1), 0.08), "Ball", true)
		piece(m, "MidB", Vector3.one * 2.4 * s, CFrame.new(c + Vector3.new(-2.6, 0.7, -1) * s), base:Lerp(Color3.new(0, 0, 0), 0.1), "Ball", true)
		piece(m, "PebbleA", Vector3.one * 1.1 * s, CFrame.new(c + Vector3.new(1.2, 0.4, -2.4) * s), base, "Ball")
		piece(m, "PebbleB", Vector3.one * 0.9 * s, CFrame.new(c + Vector3.new(-1.5, 0.35, 2.3) * s), base, "Ball")
		m.Parent = dressFolder(habitat)
	end
	-- flower patch: five stems with coloured heads + two leaves
	local function dressFlowers(name: string, c: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		local colors = { Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 220, 80), Color3.fromRGB(150, 130, 255), Color3.fromRGB(255, 255, 255) }
		for k = 1, 5 do
			local off = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
			piece(m, "Stem" .. k, Vector3.new(0.25, 1.4, 0.25), CFrame.new(c + off + Vector3.new(0, 0.7, 0)), Color3.fromRGB(70, 150, 70))
			piece(m, "Bloom" .. k, Vector3.one * 0.8, CFrame.new(c + off + Vector3.new(0, 1.5, 0)), colors[k % #colors + 1], "Ball")
		end
		m.Parent = dressFolder("Plateau")
	end
	-- small cheap mushroom for groves: stem, gills, cap, dome, two spots
	local function miniShroom(m: Instance, name: string, c: Vector3, h: number, r: number, color: Color3)
		piece(m, name .. "Stem", Vector3.new(h, r * 0.5, r * 0.5), upright(c, h), Color3.fromRGB(240, 230, 210), "Cylinder")
		piece(m, name .. "Gills", Vector3.new(0.3, r * 1.7, r * 1.7), CFrame.new(c + Vector3.new(0, h - 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(225, 200, 180), "Cylinder")
		piece(m, name .. "Cap", Vector3.new(0.6, r * 2, r * 2), CFrame.new(c + Vector3.new(0, h + 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, "Cylinder")
		piece(m, name .. "Dome", Vector3.new(0.5, r * 1.3, r * 1.3), CFrame.new(c + Vector3.new(0, h + 0.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), color:Lerp(Color3.new(1, 1, 1), 0.1), "Cylinder")
		for k = 1, 2 do
			local a = k * 2.6
			piece(m, name .. "Spot" .. k, Vector3.new(0.15, r * 0.4, r * 0.4), CFrame.new(c + Vector3.new(math.cos(a) * r * 0.75, h + 0.72, math.sin(a) * r * 0.75)) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(255, 252, 245), "Cylinder")
		end
	end
	local function dressGrove(name: string, c: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		local palette = { Color3.fromRGB(230, 80, 90), Color3.fromRGB(170, 110, 230), Color3.fromRGB(250, 170, 80), Color3.fromRGB(90, 170, 240) }
		local n = rng:NextInteger(3, 5)
		for k = 1, n do
			local a = k / n * math.pi * 2 + rng:NextNumber(0, 0.6)
			local d = k == 1 and 0 or rng:NextNumber(2, 4)
			miniShroom(m, "Shroom" .. k, c + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), k == 1 and rng:NextNumber(3, 4.5) or rng:NextNumber(1.2, 2.6),
				k == 1 and rng:NextNumber(1.8, 2.4) or rng:NextNumber(0.8, 1.4), palette[(k + n) % #palette + 1])
		end
		for k = 1, 2 do
			local a = k * 3
			piece(m, "Root" .. k, Vector3.new(0.6, 0.5, 4), CFrame.new(c + Vector3.new(math.cos(a) * 1.5, 0.2, math.sin(a) * 1.5)) * CFrame.Angles(0, a, math.rad(8)), Color3.fromRGB(150, 120, 100))
		end
		m.Parent = dressFolder("Mushroom")
	end
	-- reed bed: six thin stalks with brown cattail tips + a lily leaf
	local function dressReeds(name: string, c: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		for k = 1, 6 do
			local off = Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))
			local h = rng:NextNumber(3, 5.5)
			piece(m, "Reed" .. k, Vector3.new(0.25, h, 0.25), CFrame.new(c + off + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), Color3.fromRGB(110, 150, 90))
			if k % 2 == 0 then
				piece(m, "Cattail" .. k, Vector3.new(0.5, 1.1, 0.5), CFrame.new(c + off + Vector3.new(0, h + 0.3, 0)), Color3.fromRGB(120, 80, 50))
			end
		end
		m.Parent = dressFolder("Marsh")
	end
	-- fallen log with a bark ring and a tiny mushroom
	local function dressLog(name: string, c: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		local yaw = rng:NextNumber(0, 3)
		piece(m, "Log", Vector3.new(9, 2, 2), CFrame.new(c + Vector3.new(0, 1, 0)) * CFrame.Angles(0, yaw, 0), Color3.fromRGB(95, 75, 60), "Cylinder", true)
		piece(m, "EndRing", Vector3.new(0.2, 1.6, 1.6), CFrame.new(c + Vector3.new(0, 1, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(4.55, 0, 0), Color3.fromRGB(190, 160, 120), "Cylinder")
		miniShroom(m, "Shroom", c + Vector3.new(0, 2, 0), 0.8, 0.6, Color3.fromRGB(230, 80, 90))
		m.Parent = dressFolder("Marsh")
	end
	-- v2.6 crystal (director's blue crystal reference): a faceted prism shaft
	-- (turned 45°) with a pointed two-wedge tip, glassy and blue
	local function crystalPrism(parent: Instance, name: string, base: Vector3, h: number, w: number, tilt: CFrame, color: Color3): BasePart
		local root = CFrame.new(base) * tilt
		local shaftH = h * 0.75
		local shaft = newPart(parent, name, Vector3.new(w, shaftH, w), root * CFrame.new(0, shaftH / 2, 0) * CFrame.Angles(0, math.rad(45), 0), color,
			{ Material = Enum.Material.Glass, Transparency = 0.12, CastShadow = false, CanCollide = false })
		local tipH = h * 0.25
		for k = 0, 1 do
			local wedge = Instance.new("WedgePart")
			wedge.Name = name .. "Tip" .. k
			wedge.Anchored = true
			wedge.CanCollide = false
			wedge.CastShadow = false
			wedge.Material = Enum.Material.Glass
			wedge.Transparency = 0.08
			wedge.Color = color:Lerp(Color3.new(1, 1, 1), 0.25)
			wedge.Size = Vector3.new(w, tipH, w / 2)
			wedge.CFrame = root * CFrame.new(0, shaftH + tipH / 2, 0) * CFrame.Angles(0, math.rad(45 + k * 180), 0) * CFrame.new(0, 0, -w / 4)
			wedge.Parent = parent
		end
		return shaft
	end
	local CRYSTAL_BLUES = { Color3.fromRGB(80, 160, 255), Color3.fromRGB(120, 200, 255), Color3.fromRGB(60, 110, 230), Color3.fromRGB(150, 130, 255) }
	-- crystal group: four tilted crystals of different heights on a rock base
	local function dressCrystals(name: string, c: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		-- frosty base (pale blue-white lumps) like the reference
		for k = 1, 3 do
			piece(m, "Frost" .. k, Vector3.one * rng:NextNumber(2, 3.2), CFrame.new(c + Vector3.new(rng:NextNumber(-1.2, 1.2), 0.3, rng:NextNumber(-1, 1))), Color3.fromRGB(200, 225, 245), "Ball", true)
		end
		-- one tall main prism + three smaller ones leaning outward
		crystalPrism(m, "Main", c + Vector3.new(0, 0.4, 0), rng:NextNumber(6, 8), 1.6, CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, math.rad(rng:NextNumber(-6, 6))), CRYSTAL_BLUES[1])
		for k = 1, 3 do
			local a = k * 2.1 + rng:NextNumber(0, 0.5)
			local off = Vector3.new(math.cos(a) * 1.3, 0.3, math.sin(a) * 1.3)
			crystalPrism(m, "Small" .. k, c + off, rng:NextNumber(2.2, 4), 0.9, CFrame.Angles(0, -a, math.rad(25)), CRYSTAL_BLUES[k % #CRYSTAL_BLUES + 1])
		end
		m.Parent = dressFolder("Canyon")
	end
	-- basalt columns: five hexagon-ish columns of mixed height, one glowing vent
	local function dressBasalt(name: string, c: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2
			local h = rng:NextNumber(2, 7)
			local pos = c + Vector3.new(math.cos(a) * 1.8, 0, math.sin(a) * 1.8)
			piece(m, "Column" .. k, Vector3.new(h, 2, 2), upright(pos, h), Color3.fromRGB(55, 48, 50):Lerp(Color3.fromRGB(85, 75, 75), k / 5), "Cylinder", true)
		end
		newPart(m, "Vent", Vector3.new(0.3, 1.6, 1.6), CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 120, 40),
			{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
		m.Parent = dressFolder("Volcanic")
	end
	-- beach bits: a starfish (five arms) and a piece of driftwood
	local function dressBeach(name: string, c: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		local star = Color3.fromRGB(255, 140, 90)
		piece(m, "StarCore", Vector3.new(0.3, 1, 1), CFrame.new(c + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), star, "Cylinder")
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2
			piece(m, "Arm" .. k, Vector3.new(0.5, 0.25, 1.3), CFrame.new(c + Vector3.new(math.cos(a) * 0.8, 0.15, math.sin(a) * 0.8)) * CFrame.Angles(0, -a + math.pi / 2, 0), star)
		end
		piece(m, "Driftwood", Vector3.new(5, 0.7, 0.7), CFrame.new(c + Vector3.new(3, 0.35, 1)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(190, 170, 140), "Cylinder")
		m.Parent = dressFolder("Coast")
	end

	-- one slice of a ring (radii in authoring units, see R)
	local function ring(name: string, deg: number, r0: number, r1: number, top: number, thick: number, color: Color3, material: Enum.Material, z)
		r0, r1 = Wr(R(r0), deg), Wr(R(r1), deg)
		local theta = math.rad(deg)
		local dir = Vector3.new(math.cos(theta), 0, math.sin(theta))
		local mid = dir * ((r0 + r1) / 2) + Vector3.new(0, top - thick / 2, 0)
		local width = 2 * r1 * math.sin(math.pi / SEG) * 1.08
		local p = newPart(continent, name, Vector3.new(width, thick, r1 - r0), CFrame.lookAt(mid, mid + dir), color, {
			Material = material,
			CastShadow = false, -- never darken the hub below
		})
		if z then
			tag(p, z)
		end
		return p
	end

	-- a round terrace / cap / hill: upright cylinder with its TOP at topY
	local function disc(parent, name, center: Vector3, radius: number, height: number, topY: number, color, material, z, props)
		-- v2.2: round again (classic Roblox builds use cylinders for round
		-- terraces, caps and hills); toy plastic, glacier ice stays glacier
		local p = newPart(parent, name, Vector3.new(height, radius * 2, radius * 2),
			CFrame.new(center.X, topY - height / 2, center.Z) * CFrame.Angles(0, 0, math.pi / 2), color, {
				Shape = Enum.PartType.Cylinder,
				Material = material == Enum.Material.Glacier and material or Enum.Material.Plastic,
				CastShadow = false,
			})
		if props then
			for k, v in props do
				(p :: any)[k] = v
			end
		end
		if z then
			tag(p, z)
		end
		return p
	end

	-- habitat rules live in Shared/BiomeMap (one answer for builder, HUD, events)
	local sector, wobble = BiomeMap.Sector, BiomeMap.Wobble
	-- degrees from the wobbled angle to the nearest habitat border (30, 90, ...)
	local function borderDist(d2: number): number
		local m = (d2 - 30) % 60
		return math.min(m, 60 - m)
	end

	local grass = Color3.fromRGB(125, 195, 120)
	local rock = Color3.fromRGB(150, 145, 140)
	local moss = Color3.fromRGB(110, 170, 150)
	local mud = Color3.fromRGB(85, 95, 80)
	local canyonC = Color3.fromRGB(150, 110, 140)
	local basalt = Color3.fromRGB(60, 50, 50)
	local sand = Color3.fromRGB(240, 220, 170)

	-- Canyon pits (angle range, radius range) — straight down to the death clouds
	local PITS = { { 225, 235, 140, 172 }, { 245, 255, 186, 210 } }
	local function inPit(deg: number, r0: number, r1: number): boolean
		for _, pit in PITS do
			if deg >= pit[1] and deg < pit[2] and r0 < pit[4] and r1 > pit[3] then
				return true
			end
		end
		return false
	end

	------------------------------------------------------------------
	-- GROUND (v1.8): Roblox TERRAIN instead of overlapping parts. Every
	-- slice band asks BiomeMap which habitat owns it (one answer, no
	-- overlaps); terrain voxels merge neighbouring blocks into one smooth
	-- surface and blend materials at the borders by themselves.
	------------------------------------------------------------------
	local terrain = workspace.Terrain
	-- clear only the continent's slab of terrain (rebuilds start clean)
	for gx = -850, 850, 340 do
		for gz = -850, 850, 340 do
			terrain:FillBlock(CFrame.new(gx, UP - 30, gz), Vector3.new(340, 80, 340), Enum.Material.Air)
		end
	end
	------------------------------------------------------------------
	-- v2.2 STUDDED ROUND GROUND (classic Roblox build style). The island is
	-- cut into GSEG pie slices; each slice is cut into radial bands, and
	-- every band is built EXACTLY to its wedge shape: one studded plastic
	-- block (inner chord width) + two flat triangle WedgeParts filling out to
	-- the outer chord. Neighbouring slices share their radial edges, so
	-- nothing overlaps and nothing gaps; the coastline is a smooth organic
	-- curve (Wr) instead of steps. Each band belongs to exactly ONE habitat
	-- (BiomeMap at the band centre); equal neighbours merge. All bands share
	-- one bottom (UP-24) so height steps never open slits. Near a habitat
	-- border the colour blends 35 % toward the neighbour (visual only).
	------------------------------------------------------------------
	local GSEG = 90 -- 4° slices
	local BOTTOM = UP - 24
	local LOOK = { Plateau = 0, Mountains = 0, Mushroom = 0, Marsh = -3, Volcanic = 0, Canyon = 0 }
	local HCOLOR = {
		Plateau = Color3.fromRGB(110, 195, 90), Mountains = Color3.fromRGB(165, 160, 158), Mushroom = Color3.fromRGB(120, 180, 165),
		Marsh = Color3.fromRGB(95, 120, 100), Volcanic = Color3.fromRGB(75, 62, 62), Canyon = Color3.fromRGB(185, 130, 170),
		Heart = Color3.fromRGB(240, 242, 250), Coast = Color3.fromRGB(245, 225, 165), Shallows = Color3.fromRGB(110, 195, 235),
	}
	local function canyonTop(r0: number): number
		if r0 < 90 or r0 >= 238 then
			return UP - 4
		elseif r0 < 110 or r0 >= 222 then
			return UP - 8
		end
		return UP - 12
	end
	local transitions = {}
	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "Ground"
	groundFolder.Parent = continent
	local pieces = 0
	local function studs(p: BasePart, face: string)
		p.Material = Enum.Material.Plastic
		;(p :: any)[face .. "Surface"] = Enum.SurfaceType.Studs
	end
	-- one exact wedge-shaped band (radii in warped studs)
	local function band(name: string, deg: number, r0: number, r1: number, top: number, color: Color3, zone, opts)
		local half = math.rad(180 / GSEG)
		local th = math.rad(deg)
		local d = Vector3.new(math.cos(th), 0, math.sin(th)) -- radial (slice +z)
		local t = Vector3.new(math.sin(th), 0, -math.cos(th)) -- tangent (slice +x)
		local up = Vector3.yAxis
		local wi, wo = 2 * r0 * math.sin(half), 2 * r1 * math.sin(half)
		-- chords sit at r*cos(half) along the radial line
		local z0, z1 = r0 * math.cos(half), r1 * math.cos(half)
		local thick = top - (opts and opts.Bottom or BOTTOM)
		local yMid = top - thick / 2
		local glass = opts and opts.Glass
		local function finish(p: BasePart)
			p.CastShadow = false
			if glass then
				p.Material = Enum.Material.Glass
				p.Transparency = 0.15
			end
			tag(p, zone)
			pieces += 1
		end
		local mid = d * ((z0 + z1) / 2) + Vector3.new(0, yMid, 0)
		local block = newPart(groundFolder, name, Vector3.new(wi, thick, z1 - z0), CFrame.fromMatrix(mid, t, up, d), color, {})
		if not glass then
			studs(block, "Top")
		end
		finish(block)
		if wo - wi > 0.05 then
			for side = -1, 1, 2 do
				-- right triangle: legs along the tangent ((wo-wi)/2) and radial (z1-z0),
				-- right angle at the outer chord next to the block
				local legT, legR = (wo - wi) / 2, z1 - z0
				local centre = d * ((z0 + z1) / 2) + t * side * (wi / 2 + legT / 2) + Vector3.new(0, yMid, 0)
				local localY = t * side -- wedge height axis -> outward along the tangent
				local localZ = d -- wedge depth axis -> outward radially (vertical face at the outer chord)
				local localX = localY:Cross(localZ)
				local w = Instance.new("WedgePart")
				w.Name = name .. (side < 0 and "_L" or "_R")
				w.Anchored = true
				w.Size = Vector3.new(thick, legT, legR)
				w.CFrame = CFrame.fromMatrix(centre, localX, localY, localZ)
				w.Color = color
				w.Material = Enum.Material.Plastic
				if not glass then
					-- the world-up face of this wedge is local -X (Left) or +X (Right)
					local upFace = localX.Y < 0 and "Left" or "Right"
					studs(w, upFace)
				end
				w.Parent = groundFolder
				finish(w)
			end
		end
	end

	local EDGES = { 70, 90, 110, 138, 166, 194, 222, 238, 262 }
	for k = 0, GSEG - 1 do
		local deg = (k + 0.5) * 360 / GSEG
		band("Heart" .. k, deg, R(16), R(70), UP, HCOLOR.Heart, Z.Heart)
		local run = nil
		local function flush()
			if run then
				band(run.Name .. k, deg, Wr(R(run.R0), deg), Wr(R(run.R1), deg), run.Top, run.Color, run.Zone)
				if run.Roof then
					local roofTop = UP
					-- a 4-stud slab (not a full column): you can walk under it
					band("CaveRoof" .. k .. "_" .. run.R0, deg, Wr(R(run.R0), deg), Wr(R(run.R1), deg), roofTop, Color3.fromRGB(125, 100, 125), Z.Canyon, { Bottom = UP - 4 })
				end
				run = nil
			end
		end
		for b = 1, #EDGES - 1 do
			local r0, r1 = EDGES[b], EDGES[b + 1]
			local d2 = wobble(deg, (r0 + r1) / 2)
			local h = sector(d2)
			local top = h == "Canyon" and canyonTop(r0) or UP + LOOK[h]
			local color = HCOLOR[h]
			local bd = borderDist(d2)
			local key = h .. top
			if bd < 4 then
				local other = sector(d2 + 6) ~= h and sector(d2 + 6) or sector(d2 - 6)
				color = color:Lerp(HCOLOR[other], 0.35)
				key ..= "~" .. other
				table.insert(transitions, { r = (r0 + r1) / 2, deg = deg, top = top, a = h, b = other })
			end
			local roof = false -- cave roofs only over the canyon floor near its east wall
			if h == "Canyon" and d2 >= 258 and d2 < 270 and r0 >= 110 and r1 <= 222 then
				roof = true
				key ..= "+roof"
			end
			if h == "Canyon" and inPit(deg, r0, r1) then
				flush()
			elseif run and run.Key == key then
				run.R1 = r1
			else
				flush()
				run = { Key = key, Name = h, R0 = r0, R1 = r1, Top = top, Color = color, Zone = Z[h], Roof = roof }
			end
		end
		flush()
		band("Coast" .. k, deg, Wr(R(262), deg), Wr(R(300), deg), UP - 0.5, HCOLOR.Coast, Z.Coast)
		band("Shallows" .. k, deg, Wr(R(300), deg), Wr(R(314), deg), UP - 1.5, HCOLOR.Shallows, Z.Coast, { Glass = true })
	end
	print(string.format("[MapCheck] studded ground: %d pieces", pieces))

	------------------------------------------------------------------
	-- Reserve every landmark footprint first (random props avoid them)
	------------------------------------------------------------------
	local function habitatAt(deg: number, rOld: number): string
		return sector(wobble(deg % 360, rOld))
	end
	-- random point in a habitat: returns nil when the roll landed elsewhere
	local function habGen(rMin: number, rMax: number, dMin: number, dMax: number, hab: string, y: number): () -> Vector3?
		return function()
			local deg, r = rng:NextNumber(dMin, dMax) % 360, rng:NextNumber(rMin, rMax)
			if habitatAt(deg, r) ~= hab then
				return nil
			end
			return A(r, deg, y)
		end
	end
	for _, c in {
		{ 175, 60, 82 }, { 115, 42, 44 }, { 225, 78, 52 }, { 130, 84, 35 }, { 235, 38, 38 }, { 160, 35, 30 }, -- peaks
		{ 130, 105, 36 }, { 205, 128, 36 }, { 150, 142, 36 }, { 100, 140, 36 }, { 240, 100, 36 }, { 185, 95, 36 }, -- shroom stairs
		{ 205, 110, 42 }, { 200, 12, 52 }, { 258, 66, 26 }, { 225, 192, 14 }, -- elder, mesa, lake, tower
		{ 180, 300, 74 }, { 115, 285, 40 }, { 130, 220, 9 }, { 150, 238, 22 }, { 200, 222, 22 }, { 120, 255, 22 }, -- volcanoes, canyon
		{ 292, 90, 9 }, { 282, 180, 10 }, { 240, 326, 10 }, -- lighthouse, altars
	} do
		reserve(A(c[1], c[2], UP), c[3])
	end
	-- roads, boardwalk and lava river: { angle, from studs, to studs }
	local ROADS_FOR_DRESSING = {} -- filled below: { angle, from, to }
	local ROAD_END = {
		[0] = Wr(R(230), 0),
		[120] = Wr(R(230), 120),
		[300] = Wr(R(180), 300) - 76,
		[60] = Wr(R(175), 60) - 86,
	}
	-- winding lava river (director's lava-river reference): S-curve along 315°,
	-- swinging ±18 studs sideways, back on the axis at the middle (bridge)
	local function lavaRiverAt(f: number): Vector3
		local r0, r1 = Wr(R(150), 315), Wr(R(250), 315)
		local side = polar(1, 45, 0)
		return polar(r0 + f * (r1 - r0), 315, UP) + side * (18 * math.sin(f * math.pi * 2))
	end
	for _, deg in { 0, 120, 300, 60 } do
		table.insert(ROADS_FOR_DRESSING, { deg, R(70), ROAD_END[deg] })
	end
	for _, line in {
		{ 0, R(70), ROAD_END[0] }, { 120, R(70), ROAD_END[120] }, { 300, R(70), ROAD_END[300] }, { 60, R(70), ROAD_END[60] },
		{ 180, R(70), Wr(R(250), 180) },
	} do
		for r = line[2], line[3], 18 do
			reserve(polar(r, line[1], UP), 9)
		end
	end
	-- v2.6 winding lava river: reserve along its curve (see lavaRiverAt below)
	for f = 0, 1, 0.05 do
		reserve(lavaRiverAt(f), 14)
	end

	-- Sky Heart: glowing ring around the updraft hole + beacon
	for i = 0, 11 do
		local a = i * 30
		local pos = polar(19, a, UP + 0.3)
		newPart(decor, "HeartGlow" .. i, Vector3.new(4, 0.4, 1), CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)), Color3.fromRGB(255, 200, 120), {
			Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false,
		})
	end
	for i = 1, 8 do
		spawnPoint(A(rng:NextNumber(26, 64), rng:NextNumber(0, 360), UP + 3), "Plateau")
	end

	------------------------------------------------------------------
	-- PLATEAU MEADOWS (330-30): rolling hills + trees
	------------------------------------------------------------------
	for i = 1, 14 do
		local rad = rng:NextNumber(20, 40)
		local c = place(habGen(100, 240, 330, 390, "Plateau", UP), rad)
		if c then
			disc(continent, "Hill" .. i, c, rad, 3.5, UP + 3.5, grass, Enum.Material.Grass, Z.Plateau)
		end
	end
	for i = 1, 30 do
		local c = place(habGen(85, 250, 330, 390, "Plateau", UP), 7)
		if not c then
			continue
		end
		dressTree("Tree" .. i, c)
	end
	for _ = 1, 16 do
		local deg = (330 + rng:NextNumber(2, 58)) % 360
		spawnPoint(A(rng:NextNumber(80, 250), deg, UP + 3), "Plateau")
	end

	------------------------------------------------------------------
	-- MOUNTAINS & SNOWPEAKS (30-90): 4-stud terraces (jumpable while carrying)
	------------------------------------------------------------------
	local function peak(name: string, center: Vector3, radius: number, tiers: number, snowFrom: number, iceFrom: number)
		-- v2.6 (snowy-peak reference): a sharper pyramid profile — wide dark
		-- rock base narrowing faster toward a pointed summit, snow on the upper half
		for t = 1, tiers do
			local frac = (t - 1) / tiers
			local r = 6 + (radius - 6) * (1 - frac) ^ 1.35
			local top = UP + t * 4
			local snowy = t >= snowFrom
			local rockShade = Color3.fromRGB(85, 82, 90):Lerp(rock, frac * 0.7)
			disc(continent, name .. "Tier" .. t, center, r, 4, top, snowy and Color3.fromRGB(240, 246, 255) or rockShade,
				snowy and Enum.Material.Snow or Enum.Material.Rock, snowy and Z.Snow or Z.Mountains)
			if t >= iceFrom then
				local ice = newPart(continent, name .. "Ice" .. t, Vector3.new(0.2, r * 2, r * 2), CFrame.new(center.X, top + 0.1, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
					Color3.fromRGB(215, 240, 255), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glacier, Transparency = 0.25 })
				hazardFlag(ice, "Ice")
			end
		end
		return Vector3.new(center.X, UP + tiers * 4, center.Z)
	end
	local function ledge(center: Vector3, radius: number, tiers: number, t: number, around: number): Vector3
		local rT = radius - (t - 1) * (radius - 6) / tiers
		local rN = radius - t * (radius - 6) / tiers
		local p = polar((rT + rN) / 2, around, 0)
		return Vector3.new(center.X + p.X, UP + 4 * t + 3, center.Z + p.Z)
	end
	local mainC = A(175, 60, UP)
	local summit = peak("Snowpeak", mainC, 80, 20, 10, 14)
	-- four rock ridges running down the main peak, snow-covered on the upper half
	for k, ang in { 30, 120, 210, 300 } do
		local dir = Vector3.new(math.cos(math.rad(ang)), 0, math.sin(math.rad(ang)))
		for t = 1, 20, 2 do
			local frac = (t - 1) / 20
			local r = 6 + (80 - 6) * (1 - frac) ^ 1.35
			local pos = mainC + dir * (r - 1.2) + Vector3.new(0, t * 4 + 1, 0)
			newPart(decor, "Ridge" .. k .. "_" .. t, Vector3.new(3, 6, 4), CFrame.lookAt(pos, pos + dir) * CFrame.Angles(math.rad(-25), 0, 0),
				t >= 10 and Color3.fromRGB(245, 248, 255) or Color3.fromRGB(70, 68, 76), { Material = Enum.Material.Plastic, CanCollide = false, CastShadow = false })
		end
	end
	local peaks = {
		{ A(115, 42, UP), 42, 10 },
		{ A(225, 78, UP), 50, 12 },
		{ A(130, 84, UP), 33, 8 },
		{ A(235, 38, UP), 36, 9 },
		{ A(160, 35, UP), 28, 7 },
	}
	for i, p in peaks do
		peak("Peak" .. i, p[1], p[2], p[3], 5, 7)
	end
	ctx.altar(decor, altars, "Altar1", summit)
	altars:FindFirstChild("Altar1"):SetAttribute("Biome", "Mountains")
	for _, pos in {
		summit + Vector3.new(0, 3, 0),
		ledge(mainC, 80, 20, 3, 200), ledge(mainC, 80, 20, 6, 20), ledge(mainC, 80, 20, 9, 120), ledge(mainC, 80, 20, 12, 300),
		ledge(mainC, 80, 20, 16, 60), ledge(mainC, 80, 20, 18, 240),
		ledge(peaks[1][1], 42, 10, 4, 250), ledge(peaks[2][1], 50, 12, 5, 150), ledge(peaks[4][1], 36, 9, 3, 330),
		ledge(peaks[5][1], 28, 7, 3, 90), A(180, 50, UP + 3), A(140, 70, UP + 3),
		A(95, 60, UP + 3), A(250, 55, UP + 3),
	} do
		spawnPoint(pos, "Mountains")
	end

	------------------------------------------------------------------
	-- MUSHROOM PLATEAUS (90-150): spiral cap staircases + giant shelters
	------------------------------------------------------------------
	local capColors = { Color3.fromRGB(230, 80, 90), Color3.fromRGB(170, 110, 230), Color3.fromRGB(90, 170, 240), Color3.fromRGB(250, 170, 80) }
	local stemC = Color3.fromRGB(240, 230, 210)
	-- v2.4 READABLE MUSHROOM (director: must read as a mushroom from the
	-- gameplay camera): round stem with a white ring, darker gills under the
	-- cap, a cap WIDER than the stem built as a stepped dome (brim + 2 dome
	-- layers), and white spots stuck onto the cap. The brim top stays at the
	-- old cap height, so mushroom staircases and spawns still work.
	local gillC = Color3.fromRGB(225, 200, 180)
	local spotC = Color3.fromRGB(255, 252, 245)
	local function mushroomCap(name: string, base: Vector3, brimTop: number, capR: number, color: Color3)
		disc(continent, name .. "Gills", base, capR * 0.86, 0.6, brimTop - 1.2, gillC, Enum.Material.Plastic, Z.Mushroom)
		local brim = disc(continent, name .. "Cap", base, capR, 1.2, brimTop, color, Enum.Material.Plastic, Z.Mushroom)
		brim:SetAttribute("Shelter", true)
		local lighter = color:Lerp(Color3.new(1, 1, 1), 0.08)
		disc(continent, name .. "Dome", base, capR * 0.72, 1.1, brimTop + 1.1, lighter, Enum.Material.Plastic, Z.Mushroom)
		disc(continent, name .. "DomeTop", base, capR * 0.44, 0.9, brimTop + 2, lighter:Lerp(Color3.new(1, 1, 1), 0.06), Enum.Material.Plastic, Z.Mushroom)
		local spots = math.clamp(math.floor(capR / 2.2), 3, 8)
		for k = 1, spots do
			local ang = k / spots * math.pi * 2 + capR
			local pos = base + Vector3.new(math.cos(ang) * capR * 0.86, 0, math.sin(ang) * capR * 0.86)
			disc(decor, name .. "Spot" .. k, pos, math.max(0.5, capR * 0.11), 0.25, brimTop + 0.2, spotC, Enum.Material.Plastic, nil, { CanCollide = false })
		end
		for k = 1, 3 do
			local ang = k * 2.1 + capR
			local pos = base + Vector3.new(math.cos(ang) * capR * 0.55, 0, math.sin(ang) * capR * 0.55)
			disc(decor, name .. "TopSpot" .. k, pos, math.max(0.4, capR * 0.08), 0.25, brimTop + 1.3, spotC, Enum.Material.Plastic, nil, { CanCollide = false })
		end
		return brim
	end
	local function mushroom(name: string, base: Vector3, height: number, capR: number, color: Color3)
		local stemR = math.max(1.6, capR * 0.22)
		local brimTop = UP + height + 2
		disc(continent, name .. "Stem", base, stemR, brimTop - 1.8 - UP, brimTop - 1.8, stemC, Enum.Material.Plastic, Z.Mushroom)
		if height > 6 then
			disc(continent, name .. "Ring", base, stemR * 1.5, 0.5, UP + height * 0.62, spotC, Enum.Material.Plastic, Z.Mushroom)
		end
		return mushroomCap(name, base, brimTop, capR, color)
	end
	local clusters = { A(130, 105, UP), A(205, 128, UP), A(150, 142, UP), A(100, 140, UP), A(240, 100, UP), A(185, 95, UP) }
	for c, center in clusters do
		local steps = 9
		for i = 1, steps do
			local a = i * 55 + c * 40
			local pos = center + polar(9 + i * 1.6, a, 0)
			local last = i == steps
			mushroom(`Shroom{c}_{i}`, pos, 4 * i - 2, last and 13 or 7, capColors[(i + c) % #capColors + 1])
			if last then
				spawnPoint(Vector3.new(pos.X, UP + 4 * i + 3, pos.Z), "Mushroom")
				local glow = newPart(decor, `SporeGlow{c}`, Vector3.one * 2, CFrame.new(pos + Vector3.new(0, 4 * i + 5, 0)), Color3.fromRGB(180, 255, 200), {
					Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false,
				})
				local light = Instance.new("PointLight")
				light.Range = 24
				light.Color = glow.Color
				light.Parent = glow
			elseif i % 3 == 0 then
				spawnPoint(Vector3.new(pos.X, UP + 4 * i + 3, pos.Z), "Mushroom")
			end
		end
	end
	for i = 1, 18 do
		local capR = rng:NextNumber(10, 16)
		local pos = place(habGen(90, 250, 93, 147, "Mushroom", UP), capR + 2)
		if pos then
			mushroom("GiantShroom" .. i, pos, rng:NextNumber(14, 22), capR, capColors[i % #capColors + 1])
		end
	end
	for _ = 1, 10 do
		spawnPoint(A(rng:NextNumber(85, 255), rng:NextNumber(92, 148), UP + 3), "Mushroom")
	end

	------------------------------------------------------------------
	-- STORM MARSHES (150-210): sunk 3 studs, electric pools, lightning fields
	------------------------------------------------------------------
	for k = 0, SEG - 1 do
		local deg = (k + 0.5) * 360 / SEG
		if deg > 152 and deg < 208 and k % 2 == 0 then
			local r0 = 110 + (k % 4) * 30
			local pool = ring("MarshPool" .. k, deg, r0, r0 + 18, UP - 2.6, 0.8, Color3.fromRGB(60, 140, 160), Enum.Material.Glass)
			pool.Transparency = 0.3
			hazardFlag(pool, "River")
		end
	end
	for i, deg in { 160, 175, 190, 202 } do
		local c = A(200, deg, UP - 3)
		local field = newPart(hazards, "LightningField" .. i, Vector3.new(30, 0.2, 30), CFrame.new(c + Vector3.new(0, 0.2, 0)), Color3.new(0, 0, 0), { Transparency = 1 })
		hazardFlag(field, "Storm")
	end
	for i = 1, 32 do
		local c = place(habGen(80, 255, 153, 207, "Marsh", UP - 3), 3)
		if not c then
			continue
		end
		local h = rng:NextNumber(6, 12)
		newPart(decor, "DeadTree" .. i, Vector3.new(1.4, h, 1.4), CFrame.new(c + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-12, 12))),
			Color3.fromRGB(70, 60, 55), { Material = Enum.Material.Wood, CanCollide = false, CastShadow = false })
	end
	local marshFog = newPart(decor, "MarshFog", Vector3.new(320, 1, 320), CFrame.new(A(170, 180, UP)), Color3.new(1, 1, 1), MARKER)
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(170, 200, 190))
	mist.Size = NumberSequence.new(14, 26)
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.75), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime = NumberRange.new(8, 12)
	mist.Rate = 14
	mist.Speed = NumberRange.new(0.5, 1.5)
	mist.Parent = marshFog
	for _ = 1, 16 do
		spawnPoint(A(rng:NextNumber(80, 255), rng:NextNumber(153, 207), UP), "Marsh")
	end

	------------------------------------------------------------------
	-- CRYSTAL CANYONS (210-270): crystals, electric river, storm bridge
	------------------------------------------------------------------
	local crystalC = { Color3.fromRGB(255, 140, 230), Color3.fromRGB(130, 230, 255), Color3.fromRGB(190, 150, 255) }
	for i = 1, 48 do
		local base = place(function()
			local deg, r = rng:NextNumber(213, 267), rng:NextNumber(112, 220)
			if inPit(deg, r - 6, r + 6) or habitatAt(deg, r) ~= "Canyon" then
				return nil
			end
			return A(r, deg, UP - 12)
		end, 3)
		if not base then
			continue
		end
		local h = rng:NextNumber(4, 11)
		local crystal = crystalPrism(decor, "Crystal" .. i, base, h, h * 0.3,
			CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), rng:NextNumber(0, 6), math.rad(rng:NextNumber(-20, 20))), CRYSTAL_BLUES[i % #CRYSTAL_BLUES + 1])
		if i % 4 == 0 then
			local light = Instance.new("PointLight")
			light.Range = 18
			light.Brightness = 1.5
			light.Color = crystal.Color
			light.Parent = crystal
		end
	end
	for k = 0, SEG - 1 do
		local deg = (k + 0.5) * 360 / SEG
		if deg > 211 and deg < 269 and not inPit(deg, 196, 206) and k % 3 ~= 0 then
			local river = ring("CanyonRiver" .. k, deg, 196, 206, UP - 11.6, 0.8, Color3.fromRGB(80, 120, 240), Enum.Material.Glass)
			river.Transparency = 0.3
			hazardFlag(river, "River")
		end
	end
	local bridgeMid = A(166, 230, UP - 12.5)
	local bridge = newPart(route, "StormBridge", Vector3.new(6, 1, 80), CFrame.lookAt(bridgeMid, bridgeMid + polar(1, 230, 0)), Color3.fromRGB(80, 75, 95), {
		Material = Enum.Material.DiamondPlate,
	})
	tag(bridge, Z.Canyon)
	local storm = newPart(hazards, "StormBridge1", Vector3.new(6, 0.2, 80), bridge.CFrame * CFrame.new(0, 0.6, 0), Color3.new(0, 0, 0), { Transparency = 1 })
	hazardFlag(storm, "Storm")
	for _, pos in {
		A(125, 220, UP - 9), A(125, 260, UP - 9), A(180, 215, UP - 9), A(160, 262, UP - 9),
		A(215, 240, UP - 9), A(230, 262, UP - 5), A(100, 240, UP - 5), A(190, 265, UP - 9),
		A(185, 263, UP + 3), A(140, 266, UP + 3), -- on the cave roofs
	} do
		spawnPoint(pos, "Canyon")
	end

	------------------------------------------------------------------
	-- VOLCANIC CALDERA (270-330): crater with lava lake, lava pools, spires
	------------------------------------------------------------------
	local calderaC = A(180, 300, UP)
	-- v2.6 (erupting volcano reference): a tall cone of 8 tiers narrowing to a
	-- glowing crater, lava streaks pouring down the sides, eruption sparks + smoke
	local tiers, calR = 8, 70
	for t = 1, tiers do
		local r = calR - (t - 1) * 6.5
		disc(continent, "Caldera" .. t, calderaC, r, 4, UP + t * 4, t == tiers and Color3.fromRGB(45, 35, 35) or basalt, Enum.Material.Basalt, Z.Volcanic)
	end
	local lakeTop = UP + tiers * 4
	local function lava(name: string, pos: Vector3, size: Vector3)
		local p = newPart(decor, name, size, CFrame.new(pos), Color3.fromRGB(255, 110, 30), {
			Material = Enum.Material.Neon, CanCollide = false, CanQuery = true, CastShadow = false,
		})
		local glow = Instance.new("PointLight")
		glow.Range = 22
		glow.Brightness = 2
		glow.Color = Color3.fromRGB(255, 130, 50)
		glow.Parent = p
		local embers = Instance.new("ParticleEmitter")
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 180, 80))
		embers.LightEmission = 1
		embers.Size = NumberSequence.new(0.4, 0)
		embers.Lifetime = NumberRange.new(1.5, 3)
		embers.Rate = 8
		embers.Speed = NumberRange.new(4, 9)
		embers.EmissionDirection = Enum.NormalId.Top
		embers.SpreadAngle = Vector2.new(25, 25)
		embers.Parent = p
		-- invisible flat hazard box (unrotated, so the damage check is exact)
		local h = newPart(hazards, name .. "Hazard", Vector3.new(size.X, 0.2, size.Z), CFrame.new(pos.X, pos.Y + size.Y / 2, pos.Z), Color3.new(0, 0, 0), { Transparency = 1 })
		hazardFlag(h, "Lava")
		return p
	end
	local lake = lava("LavaLake", Vector3.new(calderaC.X, lakeTop + 0.1, calderaC.Z), Vector3.new(18, 0.4, 18))
	local erupt = Instance.new("ParticleEmitter")
	erupt.Name = "Eruption"
	erupt.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 70, 20))
	erupt.LightEmission = 1
	erupt.Size = NumberSequence.new(1.2, 0)
	erupt.Lifetime = NumberRange.new(1.5, 2.5)
	erupt.Rate = 35
	erupt.Speed = NumberRange.new(45, 75)
	erupt.SpreadAngle = Vector2.new(22, 22)
	erupt.Acceleration = Vector3.new(0, -60, 0)
	erupt.EmissionDirection = Enum.NormalId.Top
	erupt.Parent = lake
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 60, 60))
	smoke.Size = NumberSequence.new(10, 30)
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Lifetime = NumberRange.new(5, 8)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(10, 18)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = lake
	local fire = Instance.new("Fire")
	fire.Size = 25
	fire.Heat = 20
	fire.Parent = lake
	-- lava streaks: glowing pieces down the outer edge of each tier
	for k, ang in { 15, 75, 140, 200, 260, 320 } do
		local dir = Vector3.new(math.cos(math.rad(ang)), 0, math.sin(math.rad(ang)))
		local reach = (k % 2 == 0) and 1 or 3 -- some streaks stop higher up
		for t = tiers, reach, -1 do
			local r = calR - (t - 1) * 6.5
			local pos = calderaC + dir * (r - 0.4) + Vector3.new(0, UP - calderaC.Y + t * 4 - 2, 0)
			newPart(decor, "LavaStreak" .. k .. "_" .. t, Vector3.new(1.8, 4.2, 1.2), CFrame.lookAt(pos, pos + dir) * CFrame.Angles(math.rad(-12), 0, 0),
				t > tiers - 2 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(255, 100, 30), { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
		end
	end
	for i = 1, 12 do
		local pos = place(habGen(90, 250, 275, 325, "Volcanic", UP + 0.1), 9)
		if pos then
			lava("LavaPool" .. i, pos, Vector3.new(rng:NextNumber(8, 14), 0.4, rng:NextNumber(8, 14)))
		end
	end
	for i = 1, 22 do
		local pos = place(habGen(85, 255, 273, 327, "Volcanic", UP), 4)
		if pos then
			local h = rng:NextNumber(10, 24)
			newPart(continent, "Spire" .. i, Vector3.new(4, h, 4), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(rng:NextNumber(-8, 8))),
				Color3.fromRGB(30, 25, 35), { Material = Enum.Material.Glass, Reflectance = 0.1, CastShadow = false })
		end
	end
	local altar3 = ctx.altar(decor, altars, "Altar3", A(240, 326, UP))
	altar3:SetAttribute("Biome", "Volcanic")
	for _, pos in {
		calderaC + polar(55, 0, 15), calderaC + polar(45, 120, 19), calderaC + polar(30, 240, 31),
		A(100, 285, UP + 3), A(150, 325, UP + 3), A(230, 280, UP + 3), A(240, 300, UP + 3), A(120, 310, UP + 3),
	} do
		spawnPoint(pos, "Volcanic")
	end

	------------------------------------------------------------------
	-- COAST: sand ring + shallows, Altar2
	------------------------------------------------------------------
	local altar2 = ctx.altar(decor, altars, "Altar2", A(282, 180, UP - 0.5))
	altar2:SetAttribute("Biome", "Coast")
	for _ = 1, 26 do
		spawnPoint(A(rng:NextNumber(268, 296), rng:NextNumber(0, 360), UP + 2.5), "Coast")
	end


	------------------------------------------------------------------
	-- v1.6 LANDMARKS + ROUTES (one big readable landmark per biome)
	------------------------------------------------------------------
	local function block(parent, name, size: Vector3, cf: CFrame, color: Color3, material, z, extra)
		local p = newPart(parent, name, size, cf, color, { Material = material, CastShadow = false })
		for k, v in extra or {} do
			(p :: any)[k] = v
		end
		if z then
			tag(p, z)
		end
		return p
	end
	local function lamp(pos: Vector3, color: Color3)
		block(decor, "LampPost", Vector3.new(0.6, 8, 0.6), CFrame.new(pos + Vector3.new(0, 4, 0)), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
		local bulb = block(decor, "LampBulb", Vector3.new(1.4, 1.4, 1.4), CFrame.new(pos + Vector3.new(0, 8.6, 0)), color, Enum.Material.Neon, nil, { CanCollide = false })
		local light = Instance.new("PointLight")
		light.Range = 20
		light.Brightness = 1.2
		light.Color = color
		light.Parent = bulb
	end

	-- Sky Heart crystal: floats high above the plaza, seen from everywhere
	local crystalModel = Instance.new("Model")
	crystalModel.Name = "HeartCrystal"
	crystalModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local core = block(crystalModel, "Crystal", Vector3.new(14, 34, 14), CFrame.new(0, UP + 70, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color3.fromRGB(150, 230, 255), Enum.Material.Neon, nil, { CanCollide = false, Transparency = 0.15 })
	local glow = Instance.new("PointLight")
	glow.Range = 60
	glow.Brightness = 2
	glow.Color = core.Color
	glow.Parent = core
	crystalModel.PrimaryPart = core
	crystalModel:SetAttribute("FloatAmplitude", 3)
	crystalModel:SetAttribute("FloatSpin", 0.25)
	crystalModel.Parent = decor
	game:GetService("CollectionService"):AddTag(crystalModel, "FloatingIsland")

	-- Roads from the Sky Heart into the flat biomes (+ lamps); a boardwalk into the marsh
	local ROADS = {
		-- { angle, zone, colour, top, end radius in studs (stops at landmarks) }
		{ 0, Z.Plateau, Color3.fromRGB(205, 200, 185), UP, ROAD_END[0] },
		{ 120, Z.Mushroom, Color3.fromRGB(190, 170, 200), UP, ROAD_END[120] },
		{ 300, Z.Volcanic, Color3.fromRGB(90, 80, 80), UP, ROAD_END[300] },
		{ 60, Z.Mountains, Color3.fromRGB(190, 190, 195), UP, ROAD_END[60] },
	}
	for i, road in ROADS do
		local deg, z, color, top = road[1], road[2], road[3], road[4]
		local r0, r1 = R(70), road[5]
		local mid = polar((r0 + r1) / 2, deg, top + 0.05)
		block(continent, "Road" .. i, Vector3.new(10, 0.3, r1 - r0), CFrame.lookAt(mid, mid + polar(1, deg, 0)), color, Enum.Material.Cobblestone, z)
		for r = r0 + 20, r1, 60 do
			lamp(polar(r, deg + 2.2, top), Color3.fromRGB(255, 215, 160))
		end
	end
	do
		local r0, r1 = R(70), Wr(R(250), 180)
		local mid = polar((r0 + r1) / 2, 180, UP - 2.3)
		block(continent, "Boardwalk", Vector3.new(8, 0.6, r1 - r0), CFrame.lookAt(mid, mid + polar(1, 180, 0)), Color3.fromRGB(130, 95, 65), Enum.Material.WoodPlanks, Z.Marsh)
		for r = r0 + 30, r1, 70 do
			lamp(polar(r, 181.5, UP - 2), Color3.fromRGB(170, 255, 200))
		end
	end

	-- PLATEAU: Grand Mesa with ancient ruins on top
	local mesaC = A(200, 12, UP)
	for t = 1, 4 do
		disc(continent, "Mesa" .. t, mesaC, 58 - t * 9, 4, UP + t * 4, Color3.fromRGB(190, 170, 140), Enum.Material.Sandstone, Z.Plateau)
	end
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local base = mesaC + Vector3.new(math.cos(a) * 16, 16, math.sin(a) * 16)
		local h = (i % 3 == 0) and 6 or 14
		block(decor, "RuinPillar" .. i, Vector3.new(3, h, 3), CFrame.new(base + Vector3.new(0, h / 2, 0)), Color3.fromRGB(235, 230, 215), Enum.Material.Marble)
	end
	block(decor, "RuinLintel", Vector3.new(3, 2, 22), CFrame.new(mesaC + Vector3.new(16, 31, 0)), Color3.fromRGB(235, 230, 215), Enum.Material.Marble)
	spawnPoint(mesaC + Vector3.new(0, 19, 0), "Plateau")
	spawnPoint(mesaC + Vector3.new(8, 19, 8), "Plateau")

	-- MOUNTAINS: frozen lake below the peaks
	local lakeC = A(258, 66, UP)
	disc(continent, "FrozenLake", lakeC, 24, 0.4, UP + 0.4, Color3.fromRGB(200, 235, 255), Enum.Material.Glacier, Z.Snow, { Transparency = 0.1 })
	local lakeHazard = newPart(hazards, "FrozenLakeIce", Vector3.new(40, 0.2, 40), CFrame.new(lakeC + Vector3.new(0, 0.5, 0)), Color3.new(0, 0, 0), { Transparency = 1 })
	hazardFlag(lakeHazard, "Ice")
	spawnPoint(lakeC + Vector3.new(0, 3.5, 0), "Mountains")

	-- MUSHROOM: the Elder Shroom — climb the shelf caps spiralling up its stem
	local elderC = A(205, 110, UP)
	disc(continent, "ElderStem", elderC, 8, 63.2, UP + 63.2, Color3.fromRGB(235, 225, 205), Enum.Material.SmoothPlastic, Z.Mushroom)
	local elderCap = mushroomCap("Elder", elderC, UP + 65, 40, Color3.fromRGB(150, 90, 220))
	disc(continent, "ElderRing", elderC, 12, 1, UP + 40, spotC, Enum.Material.Plastic, Z.Mushroom)
	elderCap:SetAttribute("Shelter", true)
	for i = 1, 15 do
		local a = math.rad(i * 48)
		local pos = elderC + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12)
		disc(continent, "ElderShelf" .. i, pos, 6, 1.5, UP + i * 4, Color3.fromRGB(240, 180, 90), Enum.Material.SmoothPlastic, Z.Mushroom)
	end
	spawnPoint(elderC + Vector3.new(14, 68, 0), "Mushroom")
	spawnPoint(elderC + Vector3.new(-14, 68, 6), "Mushroom")
	local elderGlow = block(decor, "ElderGlow", Vector3.one * 4, CFrame.new(elderC + Vector3.new(0, 72, 0)), Color3.fromRGB(200, 150, 255), Enum.Material.Neon, nil,
		{ Shape = Enum.PartType.Ball, CanCollide = false })
	local eg = Instance.new("PointLight")
	eg.Range = 50
	eg.Color = elderGlow.Color
	eg.Parent = elderGlow

	-- MARSH: ruined watchtower with a truss ladder
	local towerC = A(225, 192, UP - 3)
	for i, off in { Vector3.new(6, 0, 0), Vector3.new(-6, 0, 0), Vector3.new(0, 0, 6), Vector3.new(0, 0, -6) } do
		local size = off.X ~= 0 and Vector3.new(1.5, 30, 13.5) or Vector3.new(13.5, 30, 1.5)
		block(continent, "TowerWall" .. i, size, CFrame.new(towerC + off + Vector3.new(0, 15, 0)), Color3.fromRGB(110, 115, 105), Enum.Material.Cobblestone, Z.Marsh)
	end
	block(continent, "TowerTop", Vector3.new(16, 1, 16), CFrame.new(towerC + Vector3.new(0, 30.5, 0)), Color3.fromRGB(95, 85, 70), Enum.Material.WoodPlanks, Z.Marsh)
	local truss = Instance.new("TrussPart")
	truss.Name = "TowerLadder"
	truss.Anchored = true
	truss.Size = Vector3.new(2, 30, 2)
	truss.CFrame = CFrame.new(towerC + Vector3.new(7.8, 15, 0))
	truss.Color = Color3.fromRGB(90, 80, 70)
	truss.Parent = continent
	spawnPoint(towerC + Vector3.new(0, 34, 0), "Marsh")
	for i = 1, 10 do
		local pad = place(habGen(120, 240, 158, 202, "Marsh", UP - 2.2), 5)
		if not pad then
			continue
		end
		disc(continent, "LilyPad" .. i, pad, rng:NextNumber(3, 5), 0.4, UP - 2.6, Color3.fromRGB(80, 160, 90), Enum.Material.Grass, Z.Marsh)
	end

	-- CANYON: stone arches over the floor + a giant crystal spire
	for i, spot in { { 150, 238 }, { 200, 222 }, { 120, 255 } } do
		local c = A(spot[1], spot[2], UP - 12)
		local axis = polar(1, spot[2] + 90, 0)
		for k = 0, 8 do
			local t = k / 8 * math.pi
			local pos = c + axis * math.cos(t) * 18 + Vector3.new(0, math.sin(t) * 16 + 2, 0)
			block(continent, `Arch{i}_{k}`, Vector3.new(6, 4, 7), CFrame.lookAt(pos, pos + axis), Color3.fromRGB(165, 120, 140), Enum.Material.Sandstone, Z.Canyon)
		end
	end
	local spireC = A(130, 220, UP - 12)
	local spire = crystalPrism(decor, "CrystalSpire", spireC, 70, 12, CFrame.Angles(math.rad(8), math.rad(30), 0), CRYSTAL_BLUES[2])
	for k = 1, 4 do
		local a = k * 1.57 + 0.4
		crystalPrism(decor, "SpireShard" .. k, spireC + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7), rng:NextNumber(14, 26), 4.5,
			CFrame.Angles(0, -a, math.rad(22)), CRYSTAL_BLUES[k % #CRYSTAL_BLUES + 1])
	end
	local sl = Instance.new("PointLight")
	sl.Range = 60
	sl.Brightness = 2
	sl.Color = spire.Color
	sl.Parent = spire
	for _ = 1, 6 do
		local deg, r
		repeat
			deg, r = rng:NextNumber(214, 266), rng:NextNumber(115, 218)
		until not inPit(deg, r - 6, r + 6)
		spawnPoint(A(r, deg, UP - 9), "Canyon")
	end

	-- VOLCANIC: Ash Cone (second volcano) + lava river with an obsidian bridge
	local ashC = A(115, 285, UP)
	for t = 1, 6 do
		disc(continent, "AshCone" .. t, ashC, 42 - t * 5, 4, UP + t * 4, Color3.fromRGB(70, 60, 60), Enum.Material.Basalt, Z.Volcanic)
	end
	lava("AshLava", Vector3.new(ashC.X, UP + 24.1, ashC.Z), Vector3.new(10, 0.4, 10))
	spawnPoint(ashC + Vector3.new(9, 23, 0), "Volcanic")
	-- winding river: bright yellow-orange core over a wider red glow edge,
	-- dark crust lumps on both banks
	local SEGS = 24
	for k = 0, SEGS - 1 do
		local a, b = lavaRiverAt(k / SEGS), lavaRiverAt((k + 1) / SEGS)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 2
		local cf = CFrame.lookAt(mid, mid + (b - a).Unit)
		newPart(decor, "LavaEdge" .. k, Vector3.new(14, 0.3, len), cf + Vector3.new(0, 0.05, 0), Color3.fromRGB(200, 50, 20), {
			Material = Enum.Material.Neon, CanCollide = false, CastShadow = false,
		})
		newPart(decor, "LavaRiver" .. k, Vector3.new(7, 0.3, len), cf + Vector3.new(0, 0.15, 0), Color3.fromRGB(255, 170, 50), {
			Material = Enum.Material.Neon, CanCollide = false, CastShadow = false,
		})
		if k % 2 == 0 then
			for _, sgn in { -1, 1 } do
				local bank = mid + cf.RightVector * sgn * rng:NextNumber(8, 10)
				newPart(decor, "Crust" .. k .. "_" .. sgn, Vector3.one * rng:NextNumber(2.5, 4.5), CFrame.new(bank), Color3.fromRGB(40, 32, 34), {
					Shape = Enum.PartType.Ball, Material = Enum.Material.Basalt, CanCollide = false, CastShadow = false,
				})
			end
		end
		-- hazard boxes stay axis-aligned (the damage check is a flat box)
		local h = newPart(hazards, "LavaHazard" .. k, Vector3.new(12, 0.2, 12), CFrame.new(mid + Vector3.new(0, 0.3, 0)), Color3.new(0, 0, 0), { Transparency = 1 })
		hazardFlag(h, "Lava")
	end
	local bridgeC = A(200, 315, UP + 1)
	block(route, "ObsidianBridge", Vector3.new(26, 1, 6), CFrame.lookAt(bridgeC, bridgeC + polar(1, 315, 0)), Color3.fromRGB(30, 25, 40), Enum.Material.Glass, Z.Volcanic)

	-- COAST: lighthouse, wooden piers, palm trees
	local lightC = A(292, 90, UP - 0.5)
	for t = 0, 4 do
		disc(continent, "Lighthouse" .. t, lightC, 6 - t * 0.4, 10, UP - 0.5 + (t + 1) * 10,
			t % 2 == 0 and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(220, 60, 60), Enum.Material.SmoothPlastic, Z.Coast)
	end
	local beacon = block(decor, "LighthouseLamp", Vector3.new(5, 4, 5), CFrame.new(lightC + Vector3.new(0, 52.5, 0)), Color3.fromRGB(255, 240, 180), Enum.Material.Neon, nil, { CanCollide = false })
	local spot = Instance.new("SpotLight")
	spot.Range = 60
	spot.Angle = 40
	spot.Brightness = 4
	spot.Face = Enum.NormalId.Front
	spot.Parent = beacon
	local bl = Instance.new("PointLight")
	bl.Range = 40
	bl.Color = beacon.Color
	bl.Parent = beacon
	for i, deg in { 20, 75, 140, 200, 250, 330 } do
		local r0, r1 = Wr(R(300), deg), Wr(R(314), deg) + 40
		local mid = polar((r0 + r1) / 2, deg, UP - 0.2)
		block(route, "Pier" .. i, Vector3.new(7, 0.6, r1 - r0), CFrame.lookAt(mid, mid + polar(1, deg, 0)), Color3.fromRGB(150, 110, 75), Enum.Material.WoodPlanks, Z.Coast)
		lamp(polar(r1 - 3, deg + 0.6, UP - 0.5), Color3.fromRGB(255, 220, 170))
		spawnPoint(polar(r1 - 6, deg, UP + 2.5), "Coast")
	end
	for i = 1, 22 do
		local base = place(function()
			return A(rng:NextNumber(266, 298), rng:NextNumber(0, 360), UP - 0.5)
		end, 5)
		if not base then
			continue
		end
		local lean = CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-12, 12)))
		local trunkCF = CFrame.new(base) * lean * CFrame.new(0, 7, 0)
		block(decor, "PalmTrunk" .. i, Vector3.new(1.4, 14, 1.4), trunkCF, Color3.fromRGB(150, 115, 80), Enum.Material.Wood, nil, { CanCollide = false })
		local top = (trunkCF * CFrame.new(0, 7, 0)).Position
		for k = 0, 4 do
			local leaf = block(decor, `PalmLeaf{i}_{k}`, Vector3.new(1.6, 0.3, 8), CFrame.new(top) * CFrame.Angles(0, math.rad(k * 72), 0) * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, 0, -3.5),
				Color3.fromRGB(70, 160, 80), Enum.Material.Grass, nil, { CanCollide = false })
			leaf:SetAttribute("Shelter", true)
		end
	end

	------------------------------------------------------------------
	-- HABITAT TRANSITIONS: a few mossy boulders / shrubs along borders
	-- (decoration only — terrain already blends the ground itself)
	------------------------------------------------------------------
	local transitionCount = 0
	for _, t in transitions do
		if rng:NextNumber() < 0.15 then
			local pos = A(t.r + rng:NextNumber(-8, 8), t.deg + rng:NextNumber(-1, 1), t.top)
			if isFree(pos, 5) then
				reserve(pos, 5)
				transitionCount += 1
				local mix = HCOLOR[t.a]:Lerp(HCOLOR[t.b], 0.5)
				local size = rng:NextNumber(3, 7)
				-- round plastic rock + bush (balls), half sunk into the ground
				newPart(continent, "Transition" .. transitionCount, Vector3.one * size,
					CFrame.new(pos + Vector3.new(0, size * 0.2, 0)), mix:Lerp(rock, 0.4), {
						Shape = Enum.PartType.Ball, Material = Enum.Material.Plastic, CastShadow = false,
					})
				newPart(decor, "TransitionShrub" .. transitionCount, Vector3.one * size * 0.8,
					CFrame.new(pos + Vector3.new(size * 0.7, size * 0.2, 0)), HCOLOR[t.b]:Lerp(grass, 0.5), {
						Shape = Enum.PartType.Ball, Material = Enum.Material.Plastic, CanCollide = false, CastShadow = false,
					})
			end
		end
	end

	------------------------------------------------------------------
	-- BENEATH THE CONTINENT (v1.8, director: clouds + mist, not rock).
	-- Seen from the bases below:
	--   Map/Continent/UnderClouds  soft cloud masses (5-8 overlapping rounded
	--                              lobes, bright tops, cooler bellies) in two
	--                              rings just under the terrain (Y ~110-174)
	--   Map/Continent/UnderHaze    a separate, much fainter drifting mist
	--                              layer lower down (Y ~90-110)
	-- Nothing here collides or can be touched; all of it stays > 30 studs
	-- above the hub/bases (tops ~Y 56) and > 40 studs from the updraft.
	------------------------------------------------------------------
	local underClouds = Instance.new("Folder")
	underClouds.Name = "UnderClouds"
	underClouds.Parent = continent
	local underHaze = Instance.new("Folder")
	underHaze.Name = "UnderHaze"
	underHaze.Parent = continent
	local function edgeAt(deg: number): number
		return Wr(R(314), deg)
	end
	local SOFT = { Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
	local function lobe(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, transparency: number)
		local p = newPart(parent, name, size, cf, color, SOFT)
		p.Transparency = transparency
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	-- one cloud mass: a wide soft base, a row of round body lobes, small crown lobes
	local function cloudMass(name: string, center: Vector3, w: number)
		local model = Instance.new("Model")
		model.Name = name
		local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local top = Color3.fromRGB(250, 251, 255)
		local belly = Color3.fromRGB(205, 214, 232)
		lobe(model, "Base", Vector3.new(w, w * 0.32, w * 0.62), CFrame.new(center) * yaw, belly, 0.12)
		local n = rng:NextInteger(3, 5)
		for i = 1, n do
			local t = (i - (n + 1) / 2) / n
			local size = w * rng:NextNumber(0.34, 0.48)
			local off = Vector3.new(t * w * 0.7, w * rng:NextNumber(0.06, 0.11), rng:NextNumber(-0.12, 0.12) * w)
			lobe(model, "Body" .. i, Vector3.new(size, size * 0.85, size * 0.9), CFrame.new(center) * yaw * CFrame.new(off), belly:Lerp(top, 0.6), 0.08)
		end
		for i = 1, 2 do
			local size = w * rng:NextNumber(0.22, 0.3)
			local off = Vector3.new(rng:NextNumber(-0.2, 0.2) * w, w * 0.2, rng:NextNumber(-0.08, 0.08) * w)
			lobe(model, "Crown" .. i, Vector3.new(size, size * 0.85, size), CFrame.new(center) * yaw * CFrame.new(off), top, 0.06)
		end
		model.Parent = underClouds
	end
	-- two rings; footprints never overlap (own registry)
	local massSpots = {}
	local function massFree(p: Vector3, r: number): boolean
		for _, m in massSpots do
			if (Vector2.new(p.X, p.Z) - m[1]).Magnitude < r + m[2] then
				return false
			end
		end
		return true
	end
	-- v2.3 CLOUD CANOPY: the director's camera from the bases still saw the
	-- plate between the rings. Now a CONTINUOUS canopy covers the whole
	-- underside: hanging cloud masses (flat bright top tucked against the
	-- plate, round lobes bulging DOWN toward the viewer) on a 92-stud grid,
	-- each 108-138 wide so neighbours overlap into one soft ceiling. It runs
	-- 4 % past the coastline to soften the edge and leaves only the updraft
	-- hole (r < 34) open. Centres at UP-44 (Y ~156): > 95 studs above the bases.
	local function hangingMass(name: string, center: Vector3, w: number)
		local model = Instance.new("Model")
		model.Name = name
		local yaw = CFrame.new(center) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local top, belly = Color3.fromRGB(248, 250, 255), Color3.fromRGB(214, 222, 240)
		lobe(model, "Top", Vector3.new(w, w * 0.3, w * 0.8), yaw, top, 0.04)
		local n = rng:NextInteger(3, 4)
		for i = 1, n do
			local t = (i - (n + 1) / 2) / n
			local size = w * rng:NextNumber(0.4, 0.52)
			local off = Vector3.new(t * w * 0.62, -w * rng:NextNumber(0.1, 0.16), rng:NextNumber(-0.18, 0.18) * w)
			lobe(model, "Bulge" .. i, Vector3.new(size, size * 0.8, size * 0.9), yaw * CFrame.new(off), belly:Lerp(top, 0.45), 0.05)
		end
		model.Parent = underClouds
	end
	local masses = 0
	for gx = -800, 800, 92 do
		for gz = -800, 800, 92 do
			local c = Vector3.new(gx + rng:NextNumber(-14, 14), UP - 44 + rng:NextNumber(-5, 3), gz + rng:NextNumber(-14, 14))
			local r = Vector2.new(c.X, c.Z).Magnitude
			local deg = math.deg(math.atan2(c.Z, c.X)) % 360
			if r > 34 + 50 and r < edgeAt(deg) * 1.04 then
				masses += 1
				hangingMass("CloudMass" .. masses, c, rng:NextNumber(108, 138))
			end
		end
	end
	-- small masses ringing the updraft hole (kept 34 studs clear of its axis)
	for i = 0, 7 do
		local a2 = i * 45 + 22.5
		masses += 1
		hangingMass("CloudMass" .. masses, polar(62, a2, UP - 46), 56)
	end

	-- haze: big, very faint, flat-ish veils + slow drifting fog particles
	for i = 0, 23 do
		local deg = i * 15 + rng:NextNumber(-4, 4)
		local r = edgeAt(deg) * rng:NextNumber(0.35, 0.95)
		local w = rng:NextNumber(180, 260)
		lobe(underHaze, "Veil" .. i, Vector3.new(w, 18, w * 0.7), CFrame.new(polar(r, deg, UP - 100 + rng:NextNumber(-4, 4))) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color3.fromRGB(228, 234, 246), 0.62)
	end
	for i = 0, 11 do
		local deg = i * 30 + 15
		local emitterPart = newPart(underHaze, "Drift" .. i, Vector3.new(120, 1, 120), CFrame.new(polar(edgeAt(deg) * 0.6, deg, UP - 96)), Color3.new(1, 1, 1), MARKER)
		local fog = Instance.new("ParticleEmitter")
		fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
		fog.Color = ColorSequence.new(Color3.fromRGB(232, 238, 250))
		fog.Size = NumberSequence.new(40, 80)
		fog.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.8), NumberSequenceKeypoint.new(1, 1) })
		fog.Lifetime = NumberRange.new(14, 20)
		fog.Rate = 1.2
		fog.Speed = NumberRange.new(1, 2.5)
		fog.SpreadAngle = Vector2.new(180, 20)
		fog.LightInfluence = 1
		fog.Parent = emitterPart
	end

	-- QA marker: centre of the canyon pit used by the QA "Death test"
	local pitMarker = newPart(decor, "PitMarker", Vector3.one, CFrame.new(A(198, 250, UP + 5)), Color3.new(1, 0, 0), MARKER)
	pitMarker:SetAttribute("QaPit", true)

	------------------------------------------------------------------
	-- v2.5 HABITAT DRESSING (placed through the footprint registry, so it
	-- never lands on landmarks, roads or other props)
	------------------------------------------------------------------
	local dressCount = 0
	local function scatter(n: number, radius: number, gen, fn)
		for i = 1, n do
			local pos = place(gen, radius)
			if pos then
				dressCount += 1
				fn(i, pos)
			end
		end
	end
	scatter(12, 4, habGen(90, 250, 333, 387, "Plateau", UP), function(i, p) dressFlowers("Flowers" .. i, p) end)
	scatter(6, 6, habGen(90, 250, 333, 387, "Plateau", UP), function(i, p) dressRocks("MeadowRocks" .. i, p, Color3.fromRGB(165, 160, 150), "Plateau") end)
	scatter(18, 6, habGen(80, 255, 33, 87, "Mountains", UP), function(i, p) dressPine("Pine" .. i, p) end)
	scatter(10, 7, habGen(80, 255, 33, 87, "Mountains", UP), function(i, p) dressRocks("MountainRocks" .. i, p, Color3.fromRGB(150, 148, 150), "Mountains") end)
	scatter(14, 6, habGen(85, 250, 93, 147, "Mushroom", UP), function(i, p) dressGrove("Grove" .. i, p) end)
	scatter(16, 4, habGen(80, 255, 153, 207, "Marsh", UP - 3), function(i, p) dressReeds("Reeds" .. i, p) end)
	scatter(6, 6, habGen(80, 255, 153, 207, "Marsh", UP - 3), function(i, p) dressLog("Log" .. i, p) end)
	scatter(14, 4, function()
		local deg, r = rng:NextNumber(214, 266), rng:NextNumber(112, 218)
		if inPit(deg, r - 6, r + 6) or habitatAt(deg, r) ~= "Canyon" then
			return nil
		end
		return A(r, deg, UP - 12)
	end, function(i, p) dressCrystals("CrystalGroup" .. i, p) end)
	scatter(10, 5, habGen(85, 255, 273, 327, "Volcanic", UP), function(i, p) dressBasalt("Basalt" .. i, p) end)
	scatter(6, 6, habGen(85, 255, 273, 327, "Volcanic", UP), function(i, p) dressRocks("AshRocks" .. i, p, Color3.fromRGB(70, 60, 60), "Volcanic") end)
	scatter(12, 4, function()
		return A(rng:NextNumber(266, 296), rng:NextNumber(0, 360), UP - 0.5)
	end, function(i, p) dressBeach("Beach" .. i, p) end)
	scatter(10, 6, function()
		return A(rng:NextNumber(268, 298), rng:NextNumber(0, 360), UP - 0.5)
	end, function(i, p) dressRocks("ShoreRocks" .. i, p, Color3.fromRGB(175, 165, 150), "Coast") end)
	-- foothills: boulder clusters around the base of every peak
	for i, spec in { { 175, 60, 82 }, { 115, 42, 44 }, { 225, 78, 52 }, { 130, 84, 35 }, { 235, 38, 38 }, { 160, 35, 30 } } do
		local c = A(spec[1], spec[2], UP)
		for k = 1, 3 do
			local a = k * 2.1 + i
			local pos = c + Vector3.new(math.cos(a) * (spec[3] + 6), 0, math.sin(a) * (spec[3] + 6))
			if isFree(pos, 5) then
				reserve(pos, 5)
				dressCount += 1
				dressRocks("Foothill" .. i .. "_" .. k, pos, Color3.fromRGB(150, 145, 140), "Mountains")
			end
		end
	end
	-- road edge stones along the four roads
	for ri, road in ROADS_FOR_DRESSING do
		for r = road[2] + 10, road[3] - 6, 14 do
			for side = -1, 1, 2 do
				local pos = polar(r, road[1], UP) + polar(6.5 * side, road[1] + 90, 0)
				newPart(dressFolder("Roads"), "EdgeStone" .. ri .. "_" .. r .. "_" .. side, Vector3.new(1.4, 0.8, 1.4), CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, math.rad(road[1]), 0),
					Color3.fromRGB(215, 210, 200), { Material = Enum.Material.Plastic, CastShadow = false })
			end
		end
	end
	print(string.format("[MapCheck] dressing: %d prop groups", dressCount))

	-- Biome signs
	for key, deg in { Plateau = 0, Mountains = 60, Mushroom = 120, Marsh = 180, Canyon = 240, Volcanic = 300 } do
		local z = Z[key]
		ctx.zoneSign(signs, key .. "Sign", A(76, deg, UP + 14), string.upper(z.ZoneName), z.ZoneColor)
	end
end

-- After the map is in workspace: drop every continent spawn onto the real
-- ground below it (habitat borders wander, so authored heights can be off),
-- take the Biome from that ground, and remove spawns over holes or closer
-- than MIN_GAP to another spawn (no overlapping clouds). Prints a summary.
function ContinentBuilder.FixSpawns(map: Instance, upY: number)
	local MIN_GAP = 9
	local folder = map:FindFirstChild("HuntZone") and map.HuntZone:FindFirstChild("WeatherSpawns")
	if not folder then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map:FindFirstChild("Continent"), map:FindFirstChild("Route"), workspace.Terrain }
	local kept, moved, noGround, tooClose = {}, 0, 0, 0
	for _, sp in folder:GetChildren() do
		if not sp:IsA("BasePart") or sp.Position.Y < upY - 60 then
			continue -- not a continent spawn
		end
		local hit = workspace:Raycast(sp.Position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
		if not hit then
			noGround += 1
			sp:Destroy()
			continue
		end
		local pos = hit.Position + Vector3.new(0, 3, 0)
		local close = false
		for _, other in kept do
			if (other - pos).Magnitude < MIN_GAP then
				close = true
				break
			end
		end
		if close then
			tooClose += 1
			sp:Destroy()
			continue
		end
		if (pos - sp.Position).Magnitude > 0.5 then
			moved += 1
		end
		sp.CFrame = CFrame.new(pos)
		local info = BiomeMap.ZoneOfHit(hit)
		if info and info.Biome then
			sp:SetAttribute("Biome", info.Biome)
		end
		table.insert(kept, pos)
	end
	print(string.format("[MapCheck] continent spawns kept=%d moved=%d removed(no ground)=%d removed(<%d studs apart)=%d",
		#kept, moved, noGround, MIN_GAP, tooClose))
end

return ContinentBuilder
