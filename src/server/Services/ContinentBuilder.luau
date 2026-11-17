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

local ContinentBuilder = {}

local SEG = 96 -- slices per ring (3.75° each)

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
		Mountains = zone("Mountains", Color3.fromRGB(210, 220, 235), "Mountains", "Icy ledges up high - Frost perks help"),
		Snow = zone("Snowpeaks", Color3.fromRGB(235, 245, 255), "Mountains", "Ice! You will slip without grip"),
		Mushroom = zone("Mushroom Plateaus", Color3.fromRGB(230, 150, 220), "Mushroom", "Climb the caps - they shelter you from acid rain"),
		Marsh = zone("Storm Marshes", Color3.fromRGB(140, 190, 170), "Marsh", "Electric pools and lightning fields!"),
		Canyon = zone("Crystal Canyons", Color3.fromRGB(190, 140, 255), "Canyon", "Pits drop to the death clouds - watch your step!"),
		Volcanic = zone("Volcanic Caldera", Color3.fromRGB(255, 140, 90), "Volcanic", "Lava burns! Fire perks make you immune"),
		Coast = zone("Coast", Color3.fromRGB(255, 225, 160), "Coast"),
	}

	local function tag(p: Instance, z)
		for k, v in z do
			p:SetAttribute(k, v)
		end
		return p
	end

	-- v1.6: the layout below is authored in the v1.4 radii (heart 16-70,
	-- biomes 70-262, coast 262-314) and stretched to the big continent
	-- (heart 16-90, biomes 90-450, coast 450-520) by R().
	local function R(r: number): number
		if r <= 70 then
			return 16 + (r - 16) * (74 / 54)
		elseif r <= 262 then
			return 90 + (r - 70) * (360 / 192)
		end
		return 450 + (r - 262) * (70 / 52)
	end
	local function A(r: number, deg: number, y: number): Vector3
		return polar(R(r), deg, y)
	end

	-- one slice of a ring (radii in authoring units, see R)
	local function ring(name: string, deg: number, r0: number, r1: number, top: number, thick: number, color: Color3, material: Enum.Material, z)
		r0, r1 = R(r0), R(r1)
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

	-- vertical cylinder (stands on its X axis) with its TOP at topY
	local function disc(parent, name, center: Vector3, radius: number, height: number, topY: number, color, material, z, props)
		local p = newPart(parent, name, Vector3.new(height, radius * 2, radius * 2),
			CFrame.new(center.X, topY - height / 2, center.Z) * CFrame.Angles(0, 0, math.pi / 2), color, {
				Shape = Enum.PartType.Cylinder,
				Material = material,
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

	local function sector(deg: number): string
		if deg >= 330 or deg < 30 then
			return "Plateau"
		elseif deg < 90 then
			return "Mountains"
		elseif deg < 150 then
			return "Mushroom"
		elseif deg < 210 then
			return "Marsh"
		elseif deg < 270 then
			return "Canyon"
		end
		return "Volcanic"
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
	-- GROUND RINGS
	------------------------------------------------------------------
	for k = 0, SEG - 1 do
		local deg = (k + 0.5) * 360 / SEG
		ring("Heart" .. k, deg, 16, 70, UP, 4, Color3.fromRGB(235, 238, 248), Enum.Material.Marble, Z.Heart)

		local s = sector(deg)
		if s == "Plateau" then
			ring("Meadow" .. k, deg, 70, 262, UP, 4, grass, Enum.Material.Grass, Z.Plateau)
		elseif s == "Mountains" then
			ring("MountainBase" .. k, deg, 70, 262, UP, 4, rock, Enum.Material.Rock, Z.Mountains)
		elseif s == "Mushroom" then
			ring("MushroomFloor" .. k, deg, 70, 262, UP, 4, moss, Enum.Material.Grass, Z.Mushroom)
		elseif s == "Marsh" then
			ring("Marsh" .. k, deg, 70, 262, UP - 3, 4, mud, Enum.Material.Mud, Z.Marsh)
		elseif s == "Canyon" then
			ring("CanyonA" .. k, deg, 70, 90, UP - 4, 4, canyonC, Enum.Material.Sandstone, Z.Canyon)
			ring("CanyonB" .. k, deg, 90, 110, UP - 8, 4, canyonC, Enum.Material.Sandstone, Z.Canyon)
			-- floor r 110-222 in 4 bands so pits can cut holes
			for b = 0, 3 do
				local r0, r1 = 110 + b * 28, 138 + b * 28
				if not inPit(deg, r0, r1) then
					ring("CanyonFloor" .. k .. "_" .. b, deg, r0, r1, UP - 12, 4, canyonC:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Sandstone, Z.Canyon)
				end
			end
			ring("CanyonC" .. k, deg, 222, 238, UP - 8, 4, canyonC, Enum.Material.Sandstone, Z.Canyon)
			ring("CanyonD" .. k, deg, 238, 262, UP - 4, 4, canyonC, Enum.Material.Sandstone, Z.Canyon)
			-- cave roofs near the 270° wall: walk under for shelter, or on top
			if deg >= 258 then
				ring("CaveRoof" .. k, deg, 120, 205, UP, 4, Color3.fromRGB(120, 95, 120), Enum.Material.Slate, Z.Canyon)
			end
		else -- Volcanic
			ring("Basalt" .. k, deg, 70, 262, UP, 4, basalt, Enum.Material.Basalt, Z.Volcanic)
		end

		ring("Coast" .. k, deg, 262, 300, UP - 0.5, 4, sand, Enum.Material.Sand, Z.Coast)
		ring("Shallows" .. k, deg, 300, 314, UP - 1.5, 4, Color3.fromRGB(120, 200, 230), Enum.Material.Glass, Z.Coast)
	end

	-- Rocky underside (boulders, center left free for the updraft)
	for i = 1, 60 do
		local deg = i * 6 + rng:NextNumber(-3, 3)
		local r = rng:NextNumber(70, 270)
		local size = rng:NextNumber(70, 130)
		local p = newPart(continent, "Underside" .. i, Vector3.new(size, size * 0.6, size), CFrame.new(A(r, deg, UP - 14 - size * 0.3)),
			Color3.fromRGB(120, 100, 90), { Material = Enum.Material.Slate, CastShadow = false })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end

	-- Sky Heart: glowing ring around the updraft hole + beacon
	for i = 0, 11 do
		local a = i * 30
		local pos = polar(19, a, UP + 0.3)
		newPart(decor, "HeartGlow" .. i, Vector3.new(4, 0.4, 1), CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)), Color3.fromRGB(150, 230, 255), {
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
		local deg = (330 + rng:NextNumber(5, 55)) % 360
		local c = A(rng:NextNumber(100, 240), deg, UP)
		disc(continent, "Hill" .. i, c, rng:NextNumber(20, 40), 3.5, UP + 3.5, grass, Enum.Material.Grass, Z.Plateau)
	end
	for i = 1, 30 do
		local deg = (330 + rng:NextNumber(2, 58)) % 360
		local c = A(rng:NextNumber(85, 250), deg, UP)
		local h = rng:NextNumber(10, 16)
		newPart(decor, "TreeTrunk" .. i, Vector3.new(2, h, 2), CFrame.new(c + Vector3.new(0, h / 2, 0)), Color3.fromRGB(120, 85, 60), {
			Material = Enum.Material.Wood, CastShadow = false,
		})
		local leaves = newPart(decor, "TreeLeaves" .. i, Vector3.one * rng:NextNumber(10, 14), CFrame.new(c + Vector3.new(0, h + 2, 0)),
			Color3.fromRGB(90, 170, 90), { Shape = Enum.PartType.Ball, Material = Enum.Material.Grass, CanCollide = false })
		leaves:SetAttribute("Shelter", true)
	end
	for _ = 1, 16 do
		local deg = (330 + rng:NextNumber(2, 58)) % 360
		spawnPoint(A(rng:NextNumber(80, 250), deg, UP + 3), "Plateau")
	end

	------------------------------------------------------------------
	-- MOUNTAINS & SNOWPEAKS (30-90): 4-stud terraces (jumpable while carrying)
	------------------------------------------------------------------
	local function peak(name: string, center: Vector3, radius: number, tiers: number, snowFrom: number, iceFrom: number)
		for t = 1, tiers do
			local r = radius - (t - 1) * (radius - 6) / tiers
			local top = UP + t * 4
			local snowy = t >= snowFrom
			disc(continent, name .. "Tier" .. t, center, r, 4, top, snowy and Color3.fromRGB(235, 245, 255) or rock,
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
	local function mushroom(name: string, base: Vector3, height: number, capR: number, color: Color3)
		disc(continent, name .. "Stem", base, math.max(2, capR * 0.22), height, UP + height, stemC, Enum.Material.SmoothPlastic, Z.Mushroom)
		local cap = disc(continent, name .. "Cap", base, capR, 2, UP + height + 2, color, Enum.Material.SmoothPlastic, Z.Mushroom)
		cap:SetAttribute("Shelter", true)
		return cap
	end
	local clusters = { A(130, 105, UP), A(205, 128, UP), A(150, 142, UP), A(95, 125, UP), A(240, 100, UP), A(185, 95, UP) }
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
		local pos = A(rng:NextNumber(90, 250), rng:NextNumber(93, 147), UP)
		mushroom("GiantShroom" .. i, pos, rng:NextNumber(14, 22), rng:NextNumber(10, 16), capColors[i % #capColors + 1])
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
		local c = A(rng:NextNumber(80, 255), rng:NextNumber(153, 207), UP - 3)
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
		local deg, r
		repeat
			deg, r = rng:NextNumber(213, 267), rng:NextNumber(112, 220)
		until not inPit(deg, r - 6, r + 6)
		local base = A(r, deg, UP - 12)
		local h = rng:NextNumber(4, 11)
		local crystal = newPart(decor, "Crystal" .. i, Vector3.new(h * 0.35, h, h * 0.35),
			CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), rng:NextNumber(0, 6), math.rad(rng:NextNumber(-20, 20))),
			crystalC[i % #crystalC + 1], { Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false })
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
	local tiers, calR = 4, 70
	for t = 1, tiers do
		local r = calR - (t - 1) * 10
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
	lava("LavaLake", Vector3.new(calderaC.X, lakeTop + 0.1, calderaC.Z), Vector3.new(26, 0.4, 26))
	for i = 1, 12 do
		local pos = A(rng:NextNumber(90, 250), rng:NextNumber(275, 325), UP + 0.1)
		if (pos - calderaC).Magnitude > calR + 8 then
			lava("LavaPool" .. i, pos, Vector3.new(rng:NextNumber(8, 14), 0.4, rng:NextNumber(8, 14)))
		end
	end
	for i = 1, 22 do
		local pos = A(rng:NextNumber(85, 255), rng:NextNumber(273, 327), UP)
		if (pos - calderaC).Magnitude > calR + 4 then
			local h = rng:NextNumber(10, 24)
			newPart(continent, "Spire" .. i, Vector3.new(4, h, 4), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(rng:NextNumber(-8, 8))),
				Color3.fromRGB(30, 25, 35), { Material = Enum.Material.Glass, Reflectance = 0.1, CastShadow = false })
		end
	end
	local altar3 = ctx.altar(decor, altars, "Altar3", A(240, 326, UP))
	altar3:SetAttribute("Biome", "Volcanic")
	for _, pos in {
		calderaC + polar(55, 0, 11), calderaC + polar(45, 120, 15), calderaC + polar(30, 240, 19),
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
		{ 0, Z.Plateau, Color3.fromRGB(205, 200, 185), UP, 390 },
		{ 120, Z.Mushroom, Color3.fromRGB(190, 170, 200), UP, 390 },
		{ 300, Z.Volcanic, Color3.fromRGB(90, 80, 80), UP, 215 },
		{ 60, Z.Mountains, Color3.fromRGB(190, 190, 195), UP, 195 },
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
		local r0, r1 = R(70), R(250)
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
	disc(continent, "ElderStem", elderC, 8, 62, UP + 62, Color3.fromRGB(235, 225, 205), Enum.Material.SmoothPlastic, Z.Mushroom)
	local elderCap = disc(continent, "ElderCap", elderC, 40, 3, UP + 65, Color3.fromRGB(150, 90, 220), Enum.Material.SmoothPlastic, Z.Mushroom)
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
		local pad = A(rng:NextNumber(120, 240), rng:NextNumber(158, 202), UP - 2.2)
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
	local spire = block(decor, "CrystalSpire", Vector3.new(12, 70, 12), CFrame.new(spireC + Vector3.new(0, 33, 0)) * CFrame.Angles(math.rad(8), math.rad(30), 0),
		Color3.fromRGB(255, 140, 230), Enum.Material.Neon, nil, { Transparency = 0.2, CanCollide = false })
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
	local riverMid = A(200, 315, UP + 0.1)
	local rr0, rr1 = R(150), R(250)
	newPart(decor, "LavaRiver", Vector3.new(10, 0.4, rr1 - rr0), CFrame.lookAt(riverMid, riverMid + polar(1, 315, 0)), Color3.fromRGB(255, 100, 30), {
		Material = Enum.Material.Neon, CanCollide = false, CastShadow = false,
	})
	-- hazard pieces stay axis-aligned (the damage check is a flat box)
	for k = 0, 9 do
		local pos = polar(rr0 + (k + 0.5) * (rr1 - rr0) / 10, 315, UP + 0.3)
		local h = newPart(hazards, "LavaRiver" .. k, Vector3.new(14, 0.2, 14), CFrame.new(pos), Color3.new(0, 0, 0), { Transparency = 1 })
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
		local r0, r1 = R(300), R(314) + 40
		local mid = polar((r0 + r1) / 2, deg, UP - 0.2)
		block(route, "Pier" .. i, Vector3.new(7, 0.6, r1 - r0), CFrame.lookAt(mid, mid + polar(1, deg, 0)), Color3.fromRGB(150, 110, 75), Enum.Material.WoodPlanks, Z.Coast)
		lamp(polar(r1 - 3, deg + 0.6, UP - 0.5), Color3.fromRGB(255, 220, 170))
		spawnPoint(polar(r1 - 6, deg, UP + 2.5), "Coast")
	end
	for i = 1, 22 do
		local base = A(rng:NextNumber(266, 298), rng:NextNumber(0, 360), UP - 0.5)
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

	-- Biome signs
	for key, deg in { Plateau = 0, Mountains = 60, Mushroom = 120, Marsh = 180, Canyon = 240, Volcanic = 300 } do
		local z = Z[key]
		ctx.zoneSign(signs, key .. "Sign", A(76, deg, UP + 14), string.upper(z.ZoneName), z.ZoneColor)
	end
end

return ContinentBuilder
