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
		return { ZoneName = name, ZoneColor = color, Biome = biome } -- director: no slogans (warning unused)
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
	-- classic studs on every face (v2.7 rugged props)
	local function studAll(p: BasePart): BasePart
		p.TopSurface = Enum.SurfaceType.Studs
		p.FrontSurface = Enum.SurfaceType.Studs
		p.BackSurface = Enum.SurfaceType.Studs
		p.LeftSurface = Enum.SurfaceType.Studs
		p.RightSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Inlet
		return p
	end
	-- a block chunk with random yaw and a small tilt (rugged, broken look)
	local function chunk(model: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, tilt: number?, collide: boolean?): BasePart
		local t = math.rad(tilt or 6)
		return studAll(piece(model, name, size, CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-t, t), rng:NextNumber(0, math.pi), rng:NextNumber(-t, t)), color, nil, collide))
	end
	local function upright(c: Vector3, h: number): CFrame
		return CFrame.new(c + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	end
	-- v2.7 rugged leafy tree: splayed roots, a trunk of offset twisted
	-- segments with knots, three jointed branches, and a canopy of many
	-- studded leaf chunks in three greens (no smooth balls)
	dressTree = function(name: string, c: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		local h = rng:NextNumber(9, 13)
		local bark, leaf = Color3.fromRGB(125, 88, 60), Color3.fromRGB(85, 170, 85)
		local dark = bark:Lerp(Color3.new(0, 0, 0), 0.2)
		for k = 1, 4 do
			local a = k * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			studAll(piece(m, "Root" .. k, Vector3.new(1, 1.2, 3), CFrame.lookAt(c + dir * 1.6 + Vector3.new(0, 0.4, 0), c + dir * 3) * CFrame.Angles(math.rad(-15), 0, 0), dark))
		end
		local segs, lean = 4, Vector3.new(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25))
		local segH = h / segs
		local p = c
		for k = 1, segs do
			local w = 2.2 - k * 0.15
			studAll(piece(m, "Trunk" .. k, Vector3.new(w, segH + 0.5, w), CFrame.new(p + Vector3.new(0, segH / 2, 0)) * CFrame.Angles(0, k * 0.5 + rng:NextNumber(0, 0.4), 0), k % 2 == 0 and bark or bark:Lerp(dark, 0.4), nil, true))
			p += Vector3.new(0, segH, 0) + lean
		end
		for k = 1, 2 do
			local a = rng:NextNumber(0, math.pi * 2)
			piece(m, "Knot" .. k, Vector3.new(0.9, 0.9, 0.9), CFrame.new(c + Vector3.new(math.cos(a), h * (0.25 + k * 0.2), math.sin(a)) + lean * k) * CFrame.Angles(0, a, 0.5), dark)
		end
		local top = p + Vector3.new(0, 1.5, 0)
		local canopy = studAll(piece(m, "Canopy", Vector3.new(7, 5, 7), CFrame.new(top) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), leaf))
		canopy:SetAttribute("Shelter", true)
		local greens = { leaf, leaf:Lerp(Color3.fromRGB(140, 210, 100), 0.5), leaf:Lerp(Color3.fromRGB(40, 110, 60), 0.4) }
		for k = 1, 9 do
			local a = k * 2.4 + rng:NextNumber(0, 0.6)
			local off = Vector3.new(math.cos(a) * rng:NextNumber(2.5, 4), rng:NextNumber(-1.5, 2.8), math.sin(a) * rng:NextNumber(2.5, 4))
			local sz = rng:NextNumber(2.6, 4.4)
			chunk(m, "Leaf" .. k, Vector3.new(sz, sz * 0.8, sz), top + off, greens[k % 3 + 1], 14)
		end
		for k = 1, 3 do
			local a = k * 2.1 + rng:NextNumber(0, 0.8)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local base = c + lean * 2 + Vector3.new(0, h * (0.5 + k * 0.1), 0)
			local tip = base + dir * 3.2 + Vector3.new(0, 2, 0)
			studAll(piece(m, "Branch" .. k, Vector3.new(0.7, 0.7, (tip - base).Magnitude), CFrame.lookAt((base + tip) / 2, tip), bark))
			local twig = tip + dir * 1.2 + Vector3.new(0, 0.9, 0)
			piece(m, "Twig" .. k, Vector3.new(0.45, 0.45, 1.6), CFrame.lookAt((tip + twig) / 2, twig), bark)
			chunk(m, "BranchLeaf" .. k, Vector3.new(2.6, 2, 2.6), twig + Vector3.new(0, 0.6, 0), greens[(k + 1) % 3 + 1], 12)
		end
		m.Parent = dressFolder("Plateau")
	end
	-- v2.7 rugged snowy pine: segmented trunk, four tiers of crossed square
	-- blocks (an eight-point star from above), snow slabs on top and snow
	-- clumps drooping from the branch tips
	local function dressPine(name: string, c: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		local trunkC, needle, snow = Color3.fromRGB(110, 80, 55), Color3.fromRGB(45, 120, 70), Color3.fromRGB(245, 250, 255)
		for k = 0, 2 do
			studAll(piece(m, "Trunk" .. k, Vector3.new(1.4 - k * 0.15, 1.6, 1.4 - k * 0.15), CFrame.new(c + Vector3.new(0, 0.8 + k * 1.4, 0)) * CFrame.Angles(0, k * 0.6, 0), trunkC, nil, true))
		end
		local spin = rng:NextNumber(0, math.pi)
		for t = 0, 3 do
			local w = 7 - t * 1.6
			local y = 3 + t * 2.2
			local col = needle:Lerp(Color3.fromRGB(30, 90, 55), t / 4)
			for x = 0, 1 do
				studAll(piece(m, "Tier" .. t .. "_" .. x, Vector3.new(w, 2, w), CFrame.new(c + Vector3.new(0, y + 1, 0)) * CFrame.Angles(0, spin + t * 0.35 + x * math.pi / 4, 0), col))
			end
			studAll(piece(m, "Snow" .. t, Vector3.new(w * 0.62, 0.6, w * 0.62), CFrame.new(c + Vector3.new(0, y + 2.3, 0)) * CFrame.Angles(0, spin + t * 0.35 + math.pi / 8, 0), snow))
			for k = 0, 1 do
				local a = spin + t * 0.35 + k * math.pi + rng:NextNumber(-0.2, 0.2)
				piece(m, "Clump" .. t .. "_" .. k, Vector3.new(1.1, 0.7, 1.1), CFrame.new(c + Vector3.new(math.cos(a) * w * 0.6, y + 1.9, math.sin(a) * w * 0.6)) * CFrame.Angles(0, a, 0.2), snow)
			end
		end
		studAll(piece(m, "Tip", Vector3.new(1, 1.6, 1), CFrame.new(c + Vector3.new(0, 12.6, 0)) * CFrame.Angles(0, math.pi / 4, 0), snow))
		m.Parent = dressFolder("Mountains")
	end
	-- v2.7 rugged rock cluster: broken studded blocks of different sizes and
	-- tilts with small chips and pebbles around them
	local function dressRocks(name: string, c: Vector3, base: Color3, habitat: string)
		local m = Instance.new("Model")
		m.Name = name
		local s = rng:NextNumber(0.8, 1.4)
		chunk(m, "Big", Vector3.new(5, 3.4, 4) * s, c + Vector3.new(0, 1.3 * s, 0), base, 12, true)
		chunk(m, "Cap", Vector3.new(3, 1.4, 2.6) * s, c + Vector3.new(0.4, 3.1 * s, -0.2), base:Lerp(Color3.new(1, 1, 1), 0.1), 14)
		chunk(m, "MidA", Vector3.new(3, 2.6, 2.6) * s, c + Vector3.new(2.8, 1, 1.2) * s, base:Lerp(Color3.new(1, 1, 1), 0.08), 18, true)
		chunk(m, "MidB", Vector3.new(2.4, 2, 2.2) * s, c + Vector3.new(-2.6, 0.8, -1) * s, base:Lerp(Color3.new(0, 0, 0), 0.1), 18, true)
		for k = 1, 4 do
			local a = k * 1.6 + rng:NextNumber(0, 0.5)
			chunk(m, "Chip" .. k, Vector3.one * rng:NextNumber(0.7, 1.3) * s, c + Vector3.new(math.cos(a) * 3.4, 0.35, math.sin(a) * 3.4) * s, base:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.15)), 25)
		end
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
		-- v2.7: octagonal basalt columns (two crossed blocks) with broken,
		-- tilted caps, glowing cracks at the foot and a vent with embers
		local m = Instance.new("Model")
		m.Name = name
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2
			local h = rng:NextNumber(2, 7)
			local pos = c + Vector3.new(math.cos(a) * 1.8, 0, math.sin(a) * 1.8)
			local col = Color3.fromRGB(55, 48, 50):Lerp(Color3.fromRGB(85, 75, 75), k / 5)
			for x = 0, 1 do
				studAll(piece(m, "Column" .. k .. "_" .. x, Vector3.new(1.8, h, 1.8), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, a + x * math.pi / 4, 0), col, nil, x == 0))
			end
			chunk(m, "Cap" .. k, Vector3.new(1.6, 0.6, 1.6), pos + Vector3.new(0, h + 0.2, 0), col:Lerp(Color3.new(1, 1, 1), 0.08), 20)
		end
		for k = 1, 3 do
			local a = k * 2.1
			newPart(m, "Crack" .. k, Vector3.new(0.3, 0.15, 2.4), CFrame.new(c + Vector3.new(math.cos(a) * 3, 0.08, math.sin(a) * 3)) * CFrame.Angles(0, -a, 0), Color3.fromRGB(255, 110, 40),
				{ Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
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
	-- v2.10: ONE intentional chasm on the west ravine, crossed by the Storm Bridge
	-- v2.16: no holes in the canyon (the coarse ground bands turned the chasm into a
	-- ~220-stud void and crystals floated over it)
	local PITS = {}
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
	for gx = -1360, 1360, 340 do
		for gz = -1360, 1360, 340 do
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
			if false and h == "Canyon" and d2 >= 258 and d2 < 270 and r0 >= 110 and r1 <= 222 then -- v2.16: cave roofs removed (they floated)
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
		{ 175, 60, 92 }, { 115, 42, 50 }, { 225, 78, 58 }, { 130, 84, 40 }, { 235, 38, 42 }, { 160, 35, 34 }, -- peaks (v2.7 crags)
		{ 130, 105, 36 }, { 205, 128, 36 }, { 150, 142, 36 }, { 100, 140, 36 }, { 240, 100, 36 }, { 185, 95, 36 }, -- shroom stairs
		{ 205, 110, 42 }, { 200, 12, 52 }, { 258, 66, 26 }, { 225, 192, 14 }, -- elder, mesa, lake, tower
		{ 180, 300, 82 }, { 115, 285, 46 }, { 130, 220, 9 }, { 150, 238, 22 }, { 200, 222, 22 }, { 120, 255, 22 }, -- volcanoes, canyon
		{ 292, 90, 9 }, { 282, 180, 10 }, { 240, 326, 10 }, -- lighthouse, altars
		{ 248, 0, 50 }, { 250, 62, 50 }, { 248, 120, 50 }, { 252, 180, 50 }, { 252, 240, 50 }, { 252, 300, 50 }, { 281, 210, 44 }, -- v2.10 temples
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
	-- (v2.10: the round hills are gone; tablelands are built after the crag kit)
	for i = 1, 48 do
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
	------------------------------------------------------------------
	-- v2.7 CRAG: blocky, asymmetric mountain (director: no stacked cylinders).
	-- Every 4-stud tier is a rotated core block stretched along a ridge axis
	-- plus offset satellite blocks (spurs, shoulders, outcrops), all
	-- full-height columns from the ground (no overhangs, solid collision),
	-- studs on every visible face, and wedge ramps for angled rock faces.
	-- The tier centres drift sideways so the summit sits off-centre.
	------------------------------------------------------------------
	local cragFolder = Instance.new("Folder")
	cragFolder.Name = "Crags"
	cragFolder.Parent = continent
	local function allStuds(p: BasePart)
		p.Material = Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
		p.FrontSurface = Enum.SurfaceType.Studs
		p.BackSurface = Enum.SurfaceType.Studs
		p.LeftSurface = Enum.SurfaceType.Studs
		p.RightSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Inlet
		p.CastShadow = false
	end
	-- crag record: { model, blocks = { { cf, half, top } }, centers, tops, summit, radius }
	local BASE_Y = UP - 2
	local function cragBlock(c: any, name: string, pos: Vector2, yaw: number, sx: number, sz: number, top: number, color: Color3, z)
		local h = top - BASE_Y
		local cf = CFrame.new(pos.X, BASE_Y + h / 2, pos.Y) * CFrame.Angles(0, yaw, 0)
		local p = newPart(c.model, name, Vector3.new(sx, h, sz), cf, color, {})
		allStuds(p)
		if z then
			tag(p, z)
		end
		table.insert(c.blocks, { cf = cf, half = Vector3.new(sx / 2, h / 2, sz / 2), top = top })
		return p, cf
	end
	-- ramp leaning against the face of a block that points most along `out`
	local function cragRamp(c: any, name: string, cf: CFrame, sx: number, sz: number, top: number, out: Vector3, color: Color3, z)
		local axes = { { cf.RightVector, sx / 2, sz }, { -cf.RightVector, sx / 2, sz }, { cf.LookVector, sz / 2, sx }, { -cf.LookVector, sz / 2, sx } }
		local best = axes[1]
		for _, a in axes do
			if a[1]:Dot(out) > best[1]:Dot(out) then
				best = a
			end
		end
		local dir, halfD, width = best[1], best[2], best[3]
		local height = math.min(4, top - UP)
		if height < 1 then
			return
		end
		local depth = height * 1.4
		local centre = Vector3.new(cf.Position.X, top - height / 2, cf.Position.Z) + dir * (halfD + depth / 2)
		local zAxis = -dir -- tall face against the block, slope runs down and outward
		local xAxis = Vector3.yAxis:Cross(zAxis)
		local w = Instance.new("WedgePart")
		w.Name = name
		w.Anchored = true
		w.Size = Vector3.new(width, height, depth)
		w.CFrame = CFrame.fromMatrix(centre, xAxis, Vector3.yAxis, zAxis)
		w.Color = color
		allStuds(w)
		if z then
			tag(w, z)
		end
		w.Parent = c.model
	end
	-- height of the crag's top surface at (x, z) (nil = not on the crag)
	local function cragTopAt(c: any, x: number, zz: number): number?
		local best
		for _, b in c.blocks do
			local l = b.cf:PointToObjectSpace(Vector3.new(x, b.cf.Position.Y, zz))
			if math.abs(l.X) <= b.half.X - 0.5 and math.abs(l.Z) <= b.half.Z - 0.5 and (best == nil or b.top > best) then
				best = b.top
			end
		end
		return best
	end
	-- a point standing on tier t, searched around the angle `around` (spawns)
	local function cragLedge(c: any, t: number, around: number): Vector3?
		local want = c.tops[t]
		for k = 0, 11 do
			local deg = around + (k % 2 == 0 and 1 or -1) * math.floor((k + 1) / 2) * 30
			local dir = polar(1, deg, 0)
			local hits = {}
			for d = 2, c.radius * 1.2, 1.5 do
				local q = c.centers[t] + dir * d
				local top = cragTopAt(c, q.X, q.Z)
				if top and math.abs(top - want) < 0.1 then
					table.insert(hits, q)
				end
			end
			if #hits > 0 then
				local q = hits[math.ceil(#hits / 2)]
				return Vector3.new(q.X, want + 3, q.Z)
			end
		end
		return nil
	end
	--[[ opts:
		Radius, Tiers, MinR (top tier radius), Power (profile curve),
		Ridge (deg of the ridge axis), Stretch (ridge elongation),
		Drift (summit offset in studs), DriftDeg, Seed,
		Color(t, frac, isSatellite) -> Color3, Zone(t, frac) -> zone table
	]]
	local function crag(name: string, center: Vector3, o): any
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = cragFolder
		local c = { model = model, blocks = {}, centers = {}, tops = {}, summit = center, radius = o.Radius }
		local cr = Random.new(o.Seed or 7)
		local ridgeYaw = math.rad(o.Ridge or 0)
		local driftDir = polar(1, o.DriftDeg or 0, 0)
		local ridgeDir = polar(1, o.Ridge or 0, 0)
		for t = 1, o.Tiers do
			local frac = (t - 1) / o.Tiers
			local r = o.MinR + (o.Radius - o.MinR) * (1 - frac) ^ (o.Power or 1)
			local top = UP + t * 4
			local ct = center + driftDir * ((o.Drift or 0) * frac ^ 1.3)
			c.centers[t] = Vector3.new(ct.X, top, ct.Z)
			c.tops[t] = top
			local z = o.Zone(t, frac)
			local col = o.Color(t, frac, false)
			local stretch = 1 + ((o.Stretch or 1.3) - 1) * (1 - frac * 0.6)
			local yaw = ridgeYaw + math.rad(cr:NextNumber(-10, 10))
			cragBlock(c, name .. "T" .. t, Vector2.new(ct.X, ct.Z), -yaw, r * 1.35 * stretch, r * 1.35, top, col, z)
			-- spurs: continue the ridgeline beyond both ends of the core
			for _, sgn in { 1, -1 } do
				if cr:NextNumber() < 0.75 then
					local off = ridgeDir * sgn * r * cr:NextNumber(0.65, 0.8) + polar(1, (o.Ridge or 0) + 90, 0) * r * cr:NextNumber(-0.15, 0.15)
					local w = r * cr:NextNumber(0.35, 0.5)
					local sTop = top - (cr:NextNumber() < 0.5 and 2 or 0)
					local sp = ct + off
					local _, scf = cragBlock(c, name .. "T" .. t .. "Spur" .. sgn, Vector2.new(sp.X, sp.Z), -yaw + math.rad(cr:NextNumber(-20, 20)), w * 1.4, w, sTop, o.Color(t, frac, true), z)
					if cr:NextNumber() < 0.6 then
						cragRamp(c, name .. "T" .. t .. "SpurRamp" .. sgn, scf, w * 1.4, w, sTop, ridgeDir * sgn, o.Color(t, frac, true), z)
					end
				end
			end
			-- shoulders/outcrops on the flanks, at uneven angles and heights
			local n = cr:NextInteger(2, 3)
			local a0 = cr:NextNumber(0, 360)
			for k = 1, n do
				local deg = a0 + k * 360 / n + cr:NextNumber(-35, 35)
				local out = polar(1, deg, 0)
				local w = r * cr:NextNumber(0.4, 0.6)
				local sp = ct + out * r * cr:NextNumber(0.4, 0.55)
				local sTop = top - (cr:NextNumber() < 0.4 and 2 or 0)
				local sx, sz = w * cr:NextNumber(0.9, 1.3), w
				local _, scf = cragBlock(c, name .. "T" .. t .. "Rock" .. k, Vector2.new(sp.X, sp.Z), math.rad(cr:NextNumber(0, 90)), sx, sz, sTop, o.Color(t, frac, true), z)
				if cr:NextNumber() < 0.55 then
					cragRamp(c, name .. "T" .. t .. "Ramp" .. k, scf, sx, sz, sTop, out, o.Color(t, frac, true), z)
				end
			end
		end
		c.summit = c.centers[o.Tiers]
		return c
	end

	------------------------------------------------------------------
	-- MOUNTAINS & SNOWPEAKS (30-90): 4-stud terraces (jumpable while carrying)
	------------------------------------------------------------------
	local SNOW = Color3.fromRGB(240, 246, 255)
	local function peak(name: string, center: Vector3, radius: number, tiers: number, snowFrom: number, iceFrom: number, o): any
		-- sharp snowy peak reference: dark rock base, lighter rock higher up,
		-- snow on the upper tiers, ice sheets near the top
		local c = crag(name, center, {
			Radius = radius, Tiers = tiers, MinR = o.MinR or 7, Power = o.Power or 1.25,
			Ridge = o.Ridge, Stretch = o.Stretch or 1.35, Drift = o.Drift or radius * 0.35, DriftDeg = o.DriftDeg, Seed = o.Seed,
			Color = function(t, frac, sat)
				if t >= snowFrom then
					return sat and SNOW:Lerp(Color3.fromRGB(205, 215, 230), 0.4) or SNOW
				end
				local shade = Color3.fromRGB(78, 74, 84):Lerp(rock, frac * 0.8)
				return sat and shade:Lerp(Color3.new(0, 0, 0), 0.12) or shade
			end,
			Zone = function(t)
				return t >= snowFrom and Z.Snow or Z.Mountains
			end,
		})
		for t = iceFrom, tiers do
			local b = c.blocks[1]
			for _, blk in c.blocks do
				if blk.top == c.tops[t] then
					b = blk
					break
				end
			end
			local ice = newPart(c.model, name .. "Ice" .. t, Vector3.new(b.half.X * 1.2, 0.2, b.half.Z * 1.2), b.cf.Rotation + Vector3.new(b.cf.X, c.tops[t] + 0.1, b.cf.Z),
				Color3.fromRGB(215, 240, 255), { Material = Enum.Material.Glacier, Transparency = 0.25, CastShadow = false })
			hazardFlag(ice, "Ice")
		end
		return c
	end
	local mainC = A(175, 60, UP)
	local function toward(from: Vector3, to: Vector3): number
		return math.deg(math.atan2(to.Z - from.Z, to.X - from.X))
	end
	local peaks = {
		{ A(115, 42, UP), 42, 10 },
		{ A(225, 78, UP), 50, 12 },
		{ A(130, 84, UP), 33, 8 },
		{ A(235, 38, UP), 36, 9 },
		{ A(160, 35, UP), 28, 7 },
	}
	-- the main peak's ridge runs between its two biggest neighbours (one range)
	local mainCrag = peak("Snowpeak", mainC, 80, 20, 10, 14, {
		Ridge = toward(peaks[1][1], peaks[2][1]), DriftDeg = toward(mainC, peaks[2][1]) + 40, Drift = 18, Seed = 11, MinR = 12,
	})
	local summit = mainCrag.summit
	local peakCrags = {}
	for i, p in peaks do
		-- each ridge points at the main peak so the ranges read as connected
		peakCrags[i] = peak("Peak" .. i, p[1], p[2], p[3], 5, 7, {
			Ridge = toward(p[1], mainC) + (i % 2 == 0 and 12 or -12), DriftDeg = toward(p[1], mainC) + 180 + i * 25,
			Drift = p[2] * 0.3, Seed = 20 + i, Stretch = 1.25 + (i % 3) * 0.12, Power = 1.1 + (i % 2) * 0.3,
		})
	end
	ctx.altar(decor, altars, "Altar1", summit)
	altars:FindFirstChild("Altar1"):SetAttribute("Biome", "Mountains")
	for _, pos in {
		summit + Vector3.new(0, 3, 0),
		cragLedge(mainCrag, 3, 200), cragLedge(mainCrag, 6, 20), cragLedge(mainCrag, 9, 120), cragLedge(mainCrag, 12, 300),
		cragLedge(mainCrag, 16, 60), cragLedge(mainCrag, 18, 240),
		cragLedge(peakCrags[1], 4, 250), cragLedge(peakCrags[2], 5, 150), cragLedge(peakCrags[4], 3, 330),
		cragLedge(peakCrags[5], 3, 90), A(180, 50, UP + 3), A(140, 70, UP + 3),
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
		-- v2.7 detail: radial gill ribs under the cap and a broken, drooping
		-- rim lip of studded blocks (all under the brim top: walking unchanged)
		local detail = Instance.new("Model")
		detail.Name = name .. "Detail"
		local ribs = math.clamp(math.floor(capR * 0.9), 8, 14)
		local spin = capR * 1.7
		for k = 1, ribs do
			local ang = k / ribs * math.pi * 2 + spin
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local mid = base + dir * capR * 0.5
			newPart(detail, "Gill" .. k, Vector3.new(0.35, 0.7, capR * 0.75), CFrame.lookAt(Vector3.new(mid.X, brimTop - 1.55, mid.Z), Vector3.new(mid.X, brimTop - 1.55, mid.Z) + dir),
				gillC:Lerp(Color3.new(0, 0, 0), 0.12), { CanCollide = false, CanQuery = false, CastShadow = false })
		end
		local lips = math.clamp(math.floor(capR * 0.9), 6, 14)
		local darker = color:Lerp(Color3.new(0, 0, 0), 0.18)
		for k = 1, lips do
			local ang = (k + 0.5) / lips * math.pi * 2 + spin
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local at = base + dir * (capR - 0.4)
			local len = 2 * math.pi * capR / lips * rng:NextNumber(0.7, 0.95)
			local lip = newPart(detail, "Lip" .. k, Vector3.new(len, rng:NextNumber(0.8, 1.3), 1.1), CFrame.lookAt(Vector3.new(at.X, brimTop - 1.2, at.Z), Vector3.new(at.X, brimTop - 1.2, at.Z) + dir) * CFrame.Angles(math.rad(rng:NextNumber(-18, -6)), 0, 0),
				k % 2 == 0 and color or darker, { CanCollide = false, CanQuery = false, CastShadow = false })
			studAll(lip)
		end
		detail.Parent = decor
		return brim
	end
	-- v2.35 director: "we can't get up the big mushroom" -> a climbable vine
	-- ladder (TrussPart) just OUTSIDE the cap rim, from the ground to the cap top
	local function vineLadder(name: string, base: Vector3, capR: number, brimTop: number, away: Vector3?)
		local dir = away and Vector3.new(away.X, 0, away.Z) or Vector3.new(math.cos(capR * 3.1), 0, math.sin(capR * 3.1))
		dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.xAxis
		local at = base + dir * (capR + 1.15)
		local h = brimTop + 1 - (UP - 0.5)
		local t = Instance.new("TrussPart")
		t.Name = name .. "Vine"
		t.Size = Vector3.new(2, h, 2)
		t.CFrame = CFrame.lookAt(Vector3.new(at.X, UP - 0.5 + h / 2, at.Z), Vector3.new(base.X, UP - 0.5 + h / 2, base.Z))
		t.Anchored = true
		t.Color = Color3.fromRGB(90, 170, 80)
		t.Material = Enum.Material.Grass
		t.Parent = continent
		for k = 1, math.floor(h / 4) do -- leaves along the vine
			newPart(decor, name .. "VineLeaf" .. k, Vector3.new(1.4, 0.2, 0.9), t.CFrame * CFrame.new(((k % 2) * 2 - 1) * 1.2, -h / 2 + k * 4, 0) * CFrame.Angles(0, 0, ((k % 2) * 2 - 1) * 0.4),
				Color3.fromRGB(110, 200, 90), { CanCollide = false, CanQuery = false, CastShadow = false })
		end
		return t
	end
	local function mushroom(name: string, base: Vector3, height: number, capR: number, color: Color3)
		local stemR = math.max(1.6, capR * 0.22)
		local brimTop = UP + height + 2
		disc(continent, name .. "Stem", base, stemR, brimTop - 1.8 - UP, brimTop - 1.8, stemC, Enum.Material.Plastic, Z.Mushroom)
		if height > 6 then
			disc(continent, name .. "Ring", base, stemR * 1.5, 0.5, UP + height * 0.62, spotC, Enum.Material.Plastic, Z.Mushroom)
		end
		-- v2.7 detail: root flares and bumps on the stem
		local roots = Instance.new("Model")
		roots.Name = name .. "Roots"
		for k = 1, 4 do
			local ang = k * math.pi / 2 + stemR
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local at = base + dir * (stemR + 0.6)
			studAll(newPart(roots, "Root" .. k, Vector3.new(1.2, 1.4, 2.4), CFrame.lookAt(Vector3.new(at.X, UP + 0.5, at.Z), Vector3.new(at.X, UP + 0.5, at.Z) + dir) * CFrame.Angles(math.rad(-20), 0, 0),
				stemC:Lerp(Color3.fromRGB(150, 120, 100), 0.4), { CanCollide = false, CanQuery = false, CastShadow = false }))
		end
		for k = 1, height > 6 and 3 or 1 do
			local ang = k * 2.3 + stemR
			local at = base + Vector3.new(math.cos(ang), 0, math.sin(ang)) * stemR * 0.92
			newPart(roots, "Bump" .. k, Vector3.new(0.9, 1.2, 0.9), CFrame.new(at.X, UP + height * (0.2 + k * 0.2), at.Z) * CFrame.Angles(0, ang, 0),
				stemC:Lerp(Color3.new(1, 1, 1), 0.1), { CanCollide = false, CanQuery = false, CastShadow = false })
		end
		roots.Parent = decor
		if height >= 8 and capR >= 7 then
			vineLadder(name, base, capR, brimTop, nil) -- giants: climb up the vine
		end
		return mushroomCap(name, base, brimTop, capR, color)
	end
	local clusters = { A(130, 105, UP), A(205, 128, UP), A(150, 142, UP), A(100, 140, UP), A(240, 100, UP), A(185, 95, UP) }
	for c, center in clusters do
		local steps = 9
		for i = 1, steps do
			local a = i * 55 + c * 40 + rng:NextNumber(-5, 5)
			local pos = center + polar(9 + i * 1.6 + rng:NextNumber(-1.2, 1.2), a, 0)
			local last = i == steps
			mushroom(`Shroom{c}_{i}`, pos, 4 * i - 2, last and 13 or rng:NextNumber(6.8, 8.5), capColors[rng:NextInteger(1, #capColors)])
			if last then -- the top of each staircase also gets a vine from the ground, on the far side
				vineLadder(`Shroom{c}_{i}Top`, pos, 13, UP + 4 * i, pos - center)
			end
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
	-- lean a whole built mushroom around its foot (every piece named <prefix>...)
	local function leanMushroom(prefix: string, base: Vector3, ax: number, az: number)
		local pivot = CFrame.new(base.X, UP, base.Z)
		local turn = pivot * CFrame.Angles(math.rad(ax), 0, math.rad(az)) * pivot:Inverse()
		for _, folder in { continent, decor } do
			for _, ch in folder:GetChildren() do
				local rest = string.sub(ch.Name, #prefix + 1, #prefix + 1)
				if string.sub(ch.Name, 1, #prefix) == prefix and rest ~= "" and not string.match(rest, "%d") then
					if ch:IsA("BasePart") then
						ch.CFrame = turn * ch.CFrame
					elseif ch:IsA("Model") then
						ch:PivotTo(turn * ch:GetPivot())
					end
				end
			end
		end
	end
	-- v2.10 (director: break up the rows): giants vary a lot in height and cap
	-- size, about half of them lean or bend, some grow in tight pairs with a
	-- small one half-hidden under the big cap
	for i = 1, 22 do
		local capR = rng:NextNumber(7, 17)
		local pos = place(habGen(90, 250, 93, 147, "Mushroom", UP), capR + 1)
		if pos then
			local name = "GiantShroom" .. i
			local height = rng:NextNumber(8, 26)
			mushroom(name, pos, height, capR, capColors[rng:NextInteger(1, #capColors)])
			if rng:NextNumber() < 0.55 then
				leanMushroom(name, pos, rng:NextNumber(-13, 13), rng:NextNumber(-13, 13))
			end
			if rng:NextNumber() < 0.4 then
				local a = rng:NextNumber(0, math.pi * 2)
				local small = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * capR * 0.6
				local sName = name .. "Kid"
				mushroom(sName, small, rng:NextNumber(3, 6), rng:NextNumber(3, 5), capColors[rng:NextInteger(1, #capColors)])
				leanMushroom(sName, small, rng:NextNumber(-20, 20), rng:NextNumber(-20, 20))
			end
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
	-- v2.10 CRYSTAL CANYON TERRAIN (director: no flat purple plate with
	-- random holes). Warm layered sandstone mesas fill the canyon floor and
	-- leave DEEP WINDING RAVINES between them: a main ravine from the heart
	-- to the coast, two branches (west one crosses the chasm on the Storm
	-- Bridge, east one runs into the caves) and the crystal river crossing.
	-- Every mesa is a stack of 4-stud strata layers that step inward (ledges
	-- you can climb), with broken chips on the rims. Big blue crystal
	-- clusters glow at the ravine bends as landmarks.
	------------------------------------------------------------------
	-- v2.11: back to the blue-purple crystal palette (director liked it)
	local STRATA = { Color3.fromRGB(120, 92, 165), Color3.fromRGB(150, 112, 195), Color3.fromRGB(96, 78, 145), Color3.fromRGB(178, 140, 212), Color3.fromRGB(110, 120, 190) }
	local function mainDeg(r: number): number
		local f = (r - 74) / 182
		return 240 + 11 * math.sin(f * math.pi * 2 * 1.15 + 0.4)
	end
	local function pathPoints(ctrl: { { number } }, step: number): { Vector3 }
		local pts = {}
		for k = 1, #ctrl - 1 do
			local a, b = ctrl[k], ctrl[k + 1]
			local n = math.max(1, math.floor((b[1] - a[1]) / step))
			for j = 0, n - 1 do
				local t = j / n
				table.insert(pts, A(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, UP))
			end
		end
		local last = ctrl[#ctrl]
		table.insert(pts, A(last[1], last[2], UP))
		return pts
	end
	local mainCtrl = {}
	for r = 74, 256, 6 do
		table.insert(mainCtrl, { r, mainDeg(r) })
	end
	local ravines = {
		pathPoints(mainCtrl, 2),
		pathPoints({ { 122, mainDeg(122) }, { 166, 230 }, { 205, 224 }, { 250, 219 } }, 2),
		pathPoints({ { 140, mainDeg(140) }, { 175, 252 }, { 215, 259 }, { 250, 262 } }, 2),
	}
	local RAVINE_HALF = 28
	local function ravineDist(p: Vector3): number
		local best = math.huge
		for _, path in ravines do
			for _, q in path do
				local d = (Vector2.new(p.X, p.Z) - Vector2.new(q.X, q.Z)).Magnitude
				if d < best then
					best = d
				end
			end
		end
		return best
	end
	-- v2.11 (director didn't like the box mesas): the ravines are lined by
	-- CONTINUOUS CLIFF WALLS that follow every bend: overlapping tall slabs
	-- of blue-purple crystal rock, leaning out, heights rolling like a real
	-- skyline, glowing crystal veins on the faces and crystals growing out of
	-- the walls into the ravine. Above the walls the canyon rim is open
	-- ground with hoodoo rock spires capped by crystals.
	local mesaFolder = Instance.new("Folder")
	mesaFolder.Name = "CanyonWalls"
	mesaFolder.Parent = continent
	local mesaCount = 0
	local VEIN = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(200, 140, 255), Color3.fromRGB(150, 230, 255) }
	for pi, path in ravines do
		local wall = Instance.new("Model")
		wall.Name = "Ravine" .. pi
		for k = 2, #path - 1, 2 do
			local q, prev, nxt = path[k], path[k - 1], path[k + 1]
			local tan = Vector3.new(nxt.X - prev.X, 0, nxt.Z - prev.Z)
			if tan.Magnitude < 0.01 then
				continue
			end
			tan = tan.Unit
			local side = tan:Cross(Vector3.yAxis)
			for _, sgn in { -1, 1 } do
				local thick = rng:NextNumber(10, 16)
				local at = q + side * sgn * (RAVINE_HALF + thick / 2 - 2)
				local _, ar = BiomeMap.Polar(at)
				local ad = math.deg(math.atan2(at.Z, at.X)) % 360
				local w2 = wobble(ad, ar)
				local roofZone = false -- v2.16: no cave roofs any more
				local nearRiver = ar >= 189 and ar <= 213
				if habitatAt(ad, ar) == "Canyon" and not roofZone and not nearRiver and not inPit(ad, ar - 4, ar + 4)
					and ravineDist(at) > RAVINE_HALF - 1 and isFree(at, 6) then
					mesaCount += 1
					local floorY = canyonTop(ar)
					-- rolling skyline: two sine waves along the path + jitter
					local h = 12 + 7 * math.sin(k * 0.21 + pi * 1.7) + 4 * math.sin(k * 0.57 + sgn) + rng:NextNumber(-2, 3)
					h = math.clamp(math.floor(h / 2) * 2, 8, 26)
					local lean = CFrame.Angles(0, 0, math.rad(sgn * rng:NextNumber(3, 9)))
					local cf = CFrame.lookAt(Vector3.new(at.X, floorY + h / 2, at.Z), Vector3.new(at.X, floorY + h / 2, at.Z) + tan) * lean
					local col = STRATA[(k + pi) % #STRATA + 1]
					local slab = newPart(wall, "Slab" .. k .. "_" .. sgn, Vector3.new(thick, h, rng:NextNumber(14, 19)), cf, col, {})
					studAll(slab)
					tag(slab, Z.Canyon)
					-- darker band near the foot and a lighter broken cap on top
					local band = newPart(wall, "Band" .. k .. "_" .. sgn, Vector3.new(thick + 0.4, math.min(4, h * 0.3), slab.Size.Z + 0.4), cf * CFrame.new(0, -h / 2 + 2, 0), col:Lerp(Color3.new(0, 0, 0), 0.25), {})
					studAll(band)
					tag(band, Z.Canyon)
					if rng:NextNumber() < 0.6 then
						local cap = chunk(wall, "Cap" .. k .. "_" .. sgn, Vector3.new(thick * 0.8, rng:NextNumber(1.5, 3.5), slab.Size.Z * 0.7), (cf * CFrame.new(rng:NextNumber(-1, 1), h / 2 + 1, 0)).Position, col:Lerp(Color3.new(1, 1, 1), 0.12), 12, true)
						tag(cap, Z.Canyon)
					end
					-- glowing crystal vein running down the ravine-facing side
					if rng:NextNumber() < 0.35 then
						newPart(wall, "Vein" .. k .. "_" .. sgn, Vector3.new(0.4, h * rng:NextNumber(0.5, 0.85), 0.8), cf * CFrame.new(-sgn * (thick / 2 + 0.1), rng:NextNumber(-1, 2), rng:NextNumber(-4, 4)) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), 0, 0),
							VEIN[rng:NextInteger(1, #VEIN)], { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
					end
					-- crystals growing out of the wall into the ravine
					if rng:NextNumber() < 0.22 then
						local root = at - side * sgn * (thick / 2 - 1) + Vector3.new(0, rng:NextNumber(2, h * 0.6), 0) - Vector3.new(0, 0, 0)
						crystalPrism(wall, "WallCrystal" .. k .. "_" .. sgn, Vector3.new(root.X, floorY + (root.Y - at.Y), root.Z), rng:NextNumber(5, 10), rng:NextNumber(1.4, 2.4),
							CFrame.fromAxisAngle(tan, math.rad(-sgn * rng:NextNumber(35, 60))), CRYSTAL_BLUES[rng:NextInteger(1, #CRYSTAL_BLUES)])
					end
					reserve(at, 8)
				end
			end
		end
		wall.Parent = mesaFolder
	end
	-- hoodoos: tall stacked rock spires with crystal caps on the open rim
	local hoodoos = 0
	for i = 1, 40 do
		local pos = place(function()
			local deg, r = rng:NextNumber(213, 267), rng:NextNumber(80, 252)
			if habitatAt(deg, r) ~= "Canyon" or inPit(deg, r - 5, r + 5) then
				return nil
			end
			local p = A(r, deg, canyonTop(r))
			if ravineDist(p) < RAVINE_HALF + 12 then
				return nil
			end
			return p
		end, 7)
		if pos then
			hoodoos += 1
			local m = Instance.new("Model")
			m.Name = "Hoodoo" .. i
			local y = pos.Y
			local n = rng:NextInteger(3, 5)
			for k = 1, n do
				local w = 7 - k * 0.9 + rng:NextNumber(-0.6, 0.6)
				local h = rng:NextNumber(3, 5)
				local seg = chunk(m, "Seg" .. k, Vector3.new(w, h, w * rng:NextNumber(0.8, 1.1)), Vector3.new(pos.X + rng:NextNumber(-0.6, 0.6), y + h / 2, pos.Z + rng:NextNumber(-0.6, 0.6)), STRATA[(k + i) % #STRATA + 1], 5, true)
				tag(seg, Z.Canyon)
				y += h
			end
			crystalPrism(m, "Top", Vector3.new(pos.X, y, pos.Z), rng:NextNumber(4, 8), rng:NextNumber(1.4, 2.2), CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-12, 12))), CRYSTAL_BLUES[i % #CRYSTAL_BLUES + 1])
			m.Parent = mesaFolder
		end
	end
	-- crystal landmarks at the ravine bends (big glowing blue clusters)
	local clusterAt = { { 1, 0.18 }, { 1, 0.45 }, { 1, 0.78 }, { 2, 0.55 }, { 2, 0.95 }, { 3, 0.5 }, { 3, 0.9 } }
	for i, spec in clusterAt do
		local path = ravines[spec[1]]
		local q = path[math.clamp(math.floor(#path * spec[2]), 1, #path)]
		local side = polar(1, rng:NextNumber(0, 360), 0)
		local _, qr = BiomeMap.Polar(q)
		local base = Vector3.new(q.X, canyonTop(qr), q.Z) + side * (RAVINE_HALF - 9)
		local m = Instance.new("Model")
		m.Name = "CrystalLandmark" .. i
		for k = 1, 3 do
			chunk(m, "Frost" .. k, Vector3.new(rng:NextNumber(5, 8), rng:NextNumber(1.5, 2.5), rng:NextNumber(5, 8)), base + Vector3.new(rng:NextNumber(-3, 3), 0.6, rng:NextNumber(-3, 3)), Color3.fromRGB(205, 228, 248), 8)
		end
		local main = crystalPrism(m, "Main", base + Vector3.new(0, 1, 0), rng:NextNumber(18, 28), 4, CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8))), CRYSTAL_BLUES[1])
		for k = 1, 5 do
			local a = k * 1.25 + rng:NextNumber(0, 0.4)
			crystalPrism(m, "Shard" .. k, base + Vector3.new(math.cos(a) * 4, 0.6, math.sin(a) * 4), rng:NextNumber(6, 13), rng:NextNumber(1.6, 2.6),
				CFrame.Angles(0, -a, math.rad(rng:NextNumber(18, 32))), CRYSTAL_BLUES[k % #CRYSTAL_BLUES + 1])
		end
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 2.2
		light.Color = Color3.fromRGB(120, 190, 255)
		light.Parent = main
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.5, 0)
		sparkle.Lifetime = NumberRange.new(1, 2)
		sparkle.Rate = 6
		sparkle.Speed = NumberRange.new(1, 3)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = main
		m.Parent = decor
		reserve(base, 10)
	end
	print(string.format("[MapCheck] canyon: %d wall slabs along 3 ravines, %d hoodoos, %d crystal landmarks", mesaCount, hoodoos, #clusterAt))

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
	-- v2.12 (director: the straight striped river looked artificial): a
	-- continuous MEANDERING crystal river in a natural channel. Its width
	-- breathes, it bends in and out, crystal-rock banks of broken ledges
	-- line both sides, and glowing shards sit in the shallows.
	local riverFolder = Instance.new("Folder")
	riverFolder.Name = "CanyonRiver"
	riverFolder.Parent = continent
	local function riverAt(deg: number): Vector3
		local r = 201.5 + 3.6 * math.sin(deg * 0.23) + 2.2 * math.sin(deg * 0.61 + 1.3)
		return A(r, deg, UP - 11.6)
	end
	local bankC = { Color3.fromRGB(120, 92, 165), Color3.fromRGB(96, 78, 145), Color3.fromRGB(150, 112, 195) }
	local seg = 0
	for deg = 211, 268.5, 1.5 do
		local a1, b1 = riverAt(deg), riverAt(deg + 1.5)
		local mid = (a1 + b1) / 2
		local _, mr = BiomeMap.Polar(mid)
		local md = math.deg(math.atan2(mid.Z, mid.X)) % 360
		if habitatAt(md, mr) == "Canyon" and not inPit(md, mr - 4, mr + 4) then
			seg += 1
			local dir = (b1 - a1).Unit
			local w = 20 + 7 * math.sin(deg * 0.4) + 3 * math.sin(deg * 1.1)
			local cf = CFrame.lookAt(mid, mid + dir)
			local water = newPart(riverFolder, "Water" .. seg, Vector3.new(w, 0.8, (b1 - a1).Magnitude + 1.5), cf, Color3.fromRGB(80, 130, 240),
				{ Material = Enum.Material.Glass, Transparency = 0.3, CastShadow = false })
			tag(water, Z.Canyon)
			hazardFlag(water, "River")
			for _, sgn in { -1, 1 } do
				if rng:NextNumber() < 0.85 then
					local h = rng:NextNumber(1.5, 4)
					local bank = chunk(riverFolder, "Bank" .. seg .. "_" .. sgn, Vector3.new(rng:NextNumber(4, 7), h, rng:NextNumber(6, 10)),
						(cf * CFrame.new(sgn * (w / 2 + rng:NextNumber(1, 2.5)), h / 2 - 0.4, 0)).Position, bankC[rng:NextInteger(1, #bankC)], 10, true)
					tag(bank, Z.Canyon)
				end
			end
			if seg % 4 == 0 then
				crystalPrism(riverFolder, "Shard" .. seg, (cf * CFrame.new(rng:NextNumber(-w / 3, w / 3), -0.3, 0)).Position, rng:NextNumber(3, 6), 1.2,
					CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), 0, math.rad(rng:NextNumber(-25, 25))), CRYSTAL_BLUES[seg % #CRYSTAL_BLUES + 1])
			end
		end
	end
	-- v2.16: the Storm Bridge spanned the removed chasm; gone with it
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
	-- v2.7: broken, rugged crag (shoulders, spurs, ramps) instead of a disc stack;
	-- the summit sits off-centre, the crater rim is uneven
	local tiers = 8
	local volcano = crag("Caldera", calderaC, {
		Radius = 70, Tiers = tiers, MinR = 17, Power = 0.9, Ridge = 340, Stretch = 1.3, Drift = 10, DriftDeg = 250, Seed = 31,
		Color = function(t, frac, sat)
			local c = Color3.fromRGB(58, 48, 50):Lerp(Color3.fromRGB(40, 32, 34), frac)
			return sat and c:Lerp(Color3.fromRGB(95, 60, 45), 0.25) or c
		end,
		Zone = function()
			return Z.Volcanic
		end,
	})
	local craterC = volcano.summit
	local lakeTop = UP + tiers * 4
	-- uneven crater rim: broken blocks of different heights with gaps
	for k = 1, 9 do
		if k ~= 4 then -- one gap where the lava spills out
			local a = k * 40 + rng:NextNumber(-8, 8)
			local pos = craterC + polar(rng:NextNumber(11.5, 13.5), a, 0)
			local h = rng:NextNumber(2, 7)
			local p = newPart(volcano.model, "Rim" .. k, Vector3.new(rng:NextNumber(4, 7), h + 2, rng:NextNumber(3, 5)),
				CFrame.new(pos.X, lakeTop + h / 2 - 1, pos.Z) * CFrame.Angles(0, -math.rad(a) + math.rad(rng:NextNumber(-15, 15)), math.rad(rng:NextNumber(-8, 8))),
				Color3.fromRGB(35, 28, 30), {})
			allStuds(p)
			tag(p, Z.Volcanic)
		end
	end
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
	local lake = lava("LavaLake", Vector3.new(craterC.X, lakeTop + 0.1, craterC.Z), Vector3.new(18, 0.4, 18))
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
	-- lava streaks follow the real contours: they run over each step's top and
	-- drip down every drop, starting at the crater and cooling as they go
	local streaks = Instance.new("Folder")
	streaks.Name = "LavaStreaks"
	streaks.Parent = decor
	for k, ang in { 160, 15, 75, 215, 275, 330 } do
		local dir = polar(1, ang, 0)
		local reach = (k % 2 == 0) and 0.55 or 1 -- some streaks stop higher up
		local prevTop, prevQ = nil, nil
		for d = 9, volcano.radius * 1.15 * reach, 3 do
			local q = craterC + dir * d
			local top = cragTopAt(volcano, q.X, q.Z)
			if not top then
				break
			end
			local heat = math.clamp((top - UP) / (tiers * 4), 0, 1)
			local col = Color3.fromRGB(230, 60, 20):Lerp(Color3.fromRGB(255, 210, 90), heat)
			newPart(streaks, "Flow" .. k .. "_" .. d, Vector3.new(2.4, 0.3, 3.2), CFrame.lookAt(Vector3.new(q.X, top + 0.15, q.Z), Vector3.new(q.X, top + 0.15, q.Z) + dir),
				col, { Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false })
			if prevTop and prevTop - top > 0.5 then
				local drop = prevTop - top
				local e = (prevQ + q) / 2
				newPart(streaks, "Drip" .. k .. "_" .. d, Vector3.new(2.2, drop + 0.3, 0.6), CFrame.lookAt(Vector3.new(e.X, top + drop / 2, e.Z), Vector3.new(e.X, top + drop / 2, e.Z) + dir),
					col, { Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false })
			end
			prevTop, prevQ = top, q
		end
	end
	for i = 1, 12 do
		local pos = place(habGen(90, 250, 275, 325, "Volcanic", UP + 0.1), 9)
		if pos then
			lava("LavaPool" .. i, pos, Vector3.new(rng:NextNumber(8, 14), 0.4, rng:NextNumber(8, 14)))
		end
	end
	-- v2.7 rugged obsidian spires: stacked twisted segments narrowing upward,
	-- shards breaking off the sides, glowing lava cracks, a broken tip
	local spireFolder = Instance.new("Folder")
	spireFolder.Name = "Spires"
	spireFolder.Parent = continent
	for i = 1, 22 do
		local pos = place(habGen(85, 255, 273, 327, "Volcanic", UP), 5)
		if pos then
			local m = Instance.new("Model")
			m.Name = "Spire" .. i
			local h = rng:NextNumber(10, 24)
			local segs = math.clamp(math.floor(h / 5), 2, 5)
			local segH = h / segs
			local lean = Vector3.new(rng:NextNumber(-0.35, 0.35), 0, rng:NextNumber(-0.35, 0.35))
			local p = pos
			local obsidian = Color3.fromRGB(30, 25, 35)
			for k = 1, segs do
				local w = 4.4 - (k - 1) * (3 / segs)
				local seg = newPart(m, "Seg" .. k, Vector3.new(w, segH + 0.4, w), CFrame.new(p + Vector3.new(0, segH / 2, 0)) * CFrame.Angles(0, k * 0.45 + rng:NextNumber(0, 0.3), math.rad(rng:NextNumber(-4, 4))),
					k % 2 == 0 and obsidian or obsidian:Lerp(Color3.fromRGB(60, 45, 60), 0.4), { CastShadow = false })
				studAll(seg)
				if rng:NextNumber() < 0.7 then
					local a = rng:NextNumber(0, math.pi * 2)
					local sh = newPart(m, "Shard" .. k, Vector3.new(0.9, segH * 0.9, 1.4), CFrame.new(p + Vector3.new(math.cos(a) * w * 0.55, segH * 0.55, math.sin(a) * w * 0.55)) * CFrame.Angles(0, -a, math.rad(rng:NextNumber(18, 30))),
						obsidian, { CanCollide = false, CastShadow = false })
					studAll(sh)
				end
				if k <= 2 then
					local a = rng:NextNumber(0, math.pi * 2)
					newPart(m, "Crack" .. k, Vector3.new(0.25, segH * 0.8, 0.5), CFrame.new(p + Vector3.new(math.cos(a) * w * 0.5, segH * 0.5, math.sin(a) * w * 0.5)) * CFrame.Angles(0, -a, 0),
						Color3.fromRGB(255, 110, 40), { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
				end
				p += Vector3.new(0, segH, 0) + lean
			end
			studAll(newPart(m, "Tip", Vector3.new(1.2, 2.4, 1.2), CFrame.new(p + Vector3.new(0, 1, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), rng:NextNumber(0, 3), math.rad(rng:NextNumber(-20, 20))),
				obsidian, { CanCollide = false, CastShadow = false }))
			for k = 1, 3 do
				local a = k * 2.1 + rng:NextNumber(0, 0.5)
				studAll(newPart(m, "Rubble" .. k, Vector3.one * rng:NextNumber(0.8, 1.6), CFrame.new(pos + Vector3.new(math.cos(a) * 3.2, 0.4, math.sin(a) * 3.2)) * CFrame.Angles(0, a, 0.3),
					obsidian, { CastShadow = false }))
			end
			m.Parent = spireFolder
		end
	end
	local altar3 = ctx.altar(decor, altars, "Altar3", A(240, 326, UP))
	altar3:SetAttribute("Biome", "Volcanic")
	for _, pos in {
		cragLedge(volcano, 3, 0), cragLedge(volcano, 4, 120), cragLedge(volcano, 7, 240),
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
	-- v2.10 TABLELANDS (director: real flat-topped plateaus, not circles):
	-- crag kit with a steep escarpment profile, a long stretched outline,
	-- spurs as branching ridges, rock outcrops + ramps as eroded steps, a
	-- broad flat grassy top, layered sandstone sides and debris at the foot
	local SANDS = { Color3.fromRGB(176, 128, 92), Color3.fromRGB(198, 156, 112), Color3.fromRGB(214, 178, 132), Color3.fromRGB(160, 112, 82) }
	local function tableland(name: string, center: Vector3, radius: number, tiers: number, seed: number, drift: number?)
		local c = crag(name, center, {
			Radius = radius, Tiers = tiers, MinR = radius * 0.72, Power = 2.6, Ridge = rng:NextNumber(0, 180), Stretch = rng:NextNumber(1.45, 1.85),
			Drift = drift or radius * 0.08, DriftDeg = rng:NextNumber(0, 360), Seed = seed,
			Color = function(t, frac, sat)
				if t == tiers then
					return sat and grass:Lerp(Color3.fromRGB(70, 140, 60), 0.3) or grass
				end
				return SANDS[(t + (sat and 1 or 0)) % #SANDS + 1]
			end,
			Zone = function()
				return Z.Plateau
			end,
		})
		for k = 1, 4 do
			local a = k * 1.6 + rng:NextNumber(0, 0.6)
			local pos = center + polar(radius * rng:NextNumber(1.05, 1.25), math.deg(a), 0)
			if isFree(pos, 5) then
				dressRocks(name .. "Debris" .. k, pos, SANDS[k % #SANDS + 1], "Plateau")
			end
		end
		return c
	end
	tableland("GrandMesa", mesaC, 58, 4, 51, 0)
	local tableN = 0
	for i = 1, 14 do
		local rad = rng:NextNumber(30, 58)
		local c = place(habGen(105, 250, 334, 386, "Plateau", UP), rad + 8)
		if c then
			tableN += 1
			tableland("Tableland" .. tableN, c, rad, rng:NextInteger(2, 5), 60 + i)
		end
		if tableN >= 8 then
			break
		end
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
	local ash = crag("AshCone", ashC, {
		Radius = 40, Tiers = 6, MinR = 10, Power = 0.85, Ridge = 30, Stretch = 1.4, Drift = 6, DriftDeg = 120, Seed = 41,
		Color = function(t, frac, sat)
			local c = Color3.fromRGB(78, 68, 68):Lerp(Color3.fromRGB(55, 46, 48), frac)
			return sat and c:Lerp(Color3.new(0, 0, 0), 0.15) or c
		end,
		Zone = function()
			return Z.Volcanic
		end,
	})
	lava("AshLava", Vector3.new(ash.summit.X, UP + 24.1, ash.summit.Z), Vector3.new(10, 0.4, 10))
	local ashSpawn = cragLedge(ash, 4, 0)
	if ashSpawn then
		spawnPoint(ashSpawn, "Volcanic")
	end
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
	-- v2.10 OUTER LANDS (the continent grew ~1.45x wider): new mountain
	-- ranges, volcanic ridges and craters fill the added outer ring.
	------------------------------------------------------------------
	local outerSpawns = {}
	-- two more mountain ranges: chains of 3 peaks whose ridges follow the chain
	for chain, spec in { { 205, 40, 248, 52 }, { 200, 70, 250, 84 } } do
		local a, b = A(spec[1], spec[2], UP), A(spec[3], spec[4], UP)
		for k = 0, 2 do
			local c = a:Lerp(b, k / 2) + polar(rng:NextNumber(-12, 12), rng:NextNumber(0, 360), 0)
			local rad = ({ 38, 52, 34 })[k + 1] + rng:NextNumber(-4, 4)
			if isFree(c, rad) then
				reserve(c, rad + 6)
				local tiers = math.floor(rad / 4)
				local pk = peak(`Range{chain}_{k}`, c, rad, tiers, math.floor(tiers * 0.55), tiers - 1, {
					Ridge = math.deg(math.atan2(b.Z - a.Z, b.X - a.X)) + rng:NextNumber(-15, 15), DriftDeg = rng:NextNumber(0, 360),
					Drift = rad * 0.3, Seed = 70 + chain * 5 + k, Stretch = 1.5,
				})
				table.insert(outerSpawns, { cragLedge(pk, 3, rng:NextNumber(0, 360)), "Mountains" })
			end
		end
	end
	-- volcanic ridges: long low broken crags of dark basalt
	local function ashColor(t, frac, sat)
		local c = Color3.fromRGB(70, 58, 58):Lerp(Color3.fromRGB(45, 36, 38), frac)
		return sat and c:Lerp(Color3.fromRGB(110, 60, 40), 0.2) or c
	end
	local function volcZone()
		return Z.Volcanic
	end
	for i, spec in { { 215, 280, 300 }, { 232, 322, 30 }, { 160, 276, 60 } } do
		local c = A(spec[1], spec[2], UP)
		if isFree(c, 40) then
			reserve(c, 46)
			local cr = crag("VolcRidge" .. i, c, { Radius = 40, Tiers = 4, MinR = 10, Power = 1.2, Ridge = spec[3], Stretch = 2.2, Drift = 8, DriftDeg = spec[3] + 90, Seed = 90 + i, Color = ashColor, Zone = volcZone })
			table.insert(outerSpawns, { cragLedge(cr, 2, spec[3]), "Volcanic" })
		end
	end
	-- two small craters with lava pools and broken rims
	for i, spec in { { 238, 288 }, { 205, 322 } } do
		local c = A(spec[1], spec[2], UP)
		if isFree(c, 34) then
			reserve(c, 40)
			local cr = crag("Crater" .. i, c, { Radius = 32, Tiers = 3, MinR = 16, Power = 0.8, Ridge = rng:NextNumber(0, 180), Stretch = 1.25, Drift = 4, DriftDeg = 0, Seed = 95 + i, Color = ashColor, Zone = volcZone })
			local top = cr.summit
			lava("CraterLava" .. i, Vector3.new(top.X, UP + 12.1, top.Z), Vector3.new(14, 0.4, 14))
			for k = 1, 7 do
				local a = k * 51 + rng:NextNumber(-10, 10)
				local pos = top + polar(rng:NextNumber(9, 11), a, 0)
				local h = rng:NextNumber(1.5, 4.5)
				local rim = newPart(cr.model, "Rim" .. k, Vector3.new(rng:NextNumber(3.5, 5.5), h + 1, 3), CFrame.new(pos.X, UP + 12 + h / 2 - 0.5, pos.Z) * CFrame.Angles(0, -math.rad(a), math.rad(rng:NextNumber(-8, 8))), Color3.fromRGB(38, 30, 32), {})
				studAll(rim)
				tag(rim, Z.Volcanic)
			end
			table.insert(outerSpawns, { cragLedge(cr, 2, 90), "Volcanic" })
		end
	end
	for _, sp in outerSpawns do
		if sp[1] then
			spawnPoint(sp[1], sp[2])
		end
	end
	-- the outer ring needs as much life as the inner one: extra spawns
	for _, h in { { "Plateau", 333, 387 }, { "Mountains", 33, 87 }, { "Mushroom", 93, 147 }, { "Marsh", 153, 207 }, { "Canyon", 213, 267 }, { "Volcanic", 273, 327 } } do
		for _ = 1, 8 do
			local deg, r = rng:NextNumber(h[2], h[3]) % 360, rng:NextNumber(190, 255)
			if habitatAt(deg, r) == h[1] then
				spawnPoint(A(r, deg, UP + 3), h[1])
			end
		end
	end

	------------------------------------------------------------------
	-- v2.10 BIOME TEMPLES (director: a detailed themed temple/arena at the
	-- far end of every biome, future boss location). Each one:
	--   stepped octagonal arena floor, a ring of 12 columns (base, octagon
	--   shaft segments, capital; some broken with rubble), a gate facing the
	--   continent centre (pylons, lintel, pediment, stairs, fire braziers),
	--   ruined back walls with crenellations, a raised shrine with a themed
	--   emblem, banners and themed particles. Map/Temples/<Biome>, with a
	--   BossSpawn marker (used by the boss) at the arena centre.
	------------------------------------------------------------------
	local templesFolder = Instance.new("Folder")
	templesFolder.Name = "Temples"
	templesFolder.Parent = ctx.continent.Parent
	local function tpart(m: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): BasePart
		local p = newPart(m, name, size, cf, color, props or {})
		if p.Material ~= Enum.Material.Neon then
			studAll(p)
		end
		p.CastShadow = false
		return p
	end
	local function particles(parent: Instance, color: Color3, rate: number, speed: number, accel: Vector3, size: number, glow: number)
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(color)
		e.LightEmission = glow
		e.Size = NumberSequence.new(size, 0)
		e.Lifetime = NumberRange.new(2, 4)
		e.Rate = rate
		e.Speed = NumberRange.new(speed * 0.5, speed)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = accel
		e.Parent = parent
		return e
	end
	local THEMES = {
		Plateau = { Stone = Color3.fromRGB(218, 206, 178), Trim = Color3.fromRGB(150, 128, 96), Accent = Color3.fromRGB(95, 175, 80), Glow = Color3.fromRGB(255, 220, 120), Fx = Color3.fromRGB(150, 220, 110), Accel = Vector3.new(0, -1, 0) },
		Mountains = { Stone = Color3.fromRGB(205, 214, 228), Trim = Color3.fromRGB(120, 128, 145), Accent = Color3.fromRGB(110, 175, 255), Glow = Color3.fromRGB(190, 230, 255), Fx = Color3.fromRGB(250, 252, 255), Accel = Vector3.new(0, -3, 0) },
		Mushroom = { Stone = Color3.fromRGB(178, 156, 196), Trim = Color3.fromRGB(110, 90, 130), Accent = Color3.fromRGB(235, 85, 150), Glow = Color3.fromRGB(190, 255, 210), Fx = Color3.fromRGB(200, 255, 220), Accel = Vector3.new(0, 1, 0) },
		Marsh = { Stone = Color3.fromRGB(98, 124, 108), Trim = Color3.fromRGB(60, 80, 70), Accent = Color3.fromRGB(80, 200, 220), Glow = Color3.fromRGB(150, 240, 255), Fx = Color3.fromRGB(170, 240, 255), Accel = Vector3.new(0, 2, 0) },
		Canyon = { Stone = Color3.fromRGB(176, 160, 236), Trim = Color3.fromRGB(104, 92, 186), Accent = Color3.fromRGB(80, 170, 255), Glow = Color3.fromRGB(170, 230, 255), Fx = Color3.fromRGB(200, 235, 255), Accel = Vector3.new(0, 1, 0), Crystal = true },
		Volcanic = { Stone = Color3.fromRGB(62, 50, 52), Trim = Color3.fromRGB(35, 28, 30), Accent = Color3.fromRGB(255, 110, 40), Glow = Color3.fromRGB(255, 150, 60), Fx = Color3.fromRGB(255, 170, 70), Accel = Vector3.new(0, 4, 0) },
		Coast = { Stone = Color3.fromRGB(238, 228, 205), Trim = Color3.fromRGB(150, 175, 185), Accent = Color3.fromRGB(70, 175, 230), Glow = Color3.fromRGB(160, 230, 255), Fx = Color3.fromRGB(220, 245, 255), Accel = Vector3.new(0, 2, 0) },
	}
	-- themed emblem above the shrine
	local function emblem(m: Instance, biome: string, at: CFrame, th)
		local glow = { Material = Enum.Material.Neon, CanCollide = false }
		if biome == "Plateau" then -- sun disc with rays
			tpart(m, "SunDisc", Vector3.new(1, 7, 7), at * CFrame.Angles(0, math.rad(90), 0), th.Glow, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, CanCollide = false })
			for k = 0, 7 do
				tpart(m, "Ray" .. k, Vector3.new(0.8, 3, 0.6), at * CFrame.Angles(0, 0, k * math.pi / 4) * CFrame.new(0, 5.4, 0), th.Glow, glow)
			end
		elseif biome == "Mountains" then -- snowflake
			for k = 0, 2 do
				tpart(m, "Arm" .. k, Vector3.new(0.8, 10, 0.6), at * CFrame.Angles(0, 0, k * math.pi / 3), th.Glow, glow)
				for sgn = -1, 1, 2 do
					tpart(m, "Twig" .. k .. sgn, Vector3.new(0.5, 2.4, 0.5), at * CFrame.Angles(0, 0, k * math.pi / 3) * CFrame.new(0, sgn * 3.2, 0) * CFrame.Angles(0, 0, math.rad(40)), th.Glow, glow)
					tpart(m, "Twag" .. k .. sgn, Vector3.new(0.5, 2.4, 0.5), at * CFrame.Angles(0, 0, k * math.pi / 3) * CFrame.new(0, sgn * 3.2, 0) * CFrame.Angles(0, 0, math.rad(-40)), th.Glow, glow)
				end
			end
		elseif biome == "Mushroom" then -- glowing mushroom
			tpart(m, "Stem", Vector3.new(1.6, 5, 1.6), at * CFrame.new(0, -1.5, 0), Color3.fromRGB(245, 235, 215), { CanCollide = false })
			tpart(m, "Cap", Vector3.new(1.6, 8, 8), at * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2), th.Accent, { Shape = Enum.PartType.Cylinder, CanCollide = false })
			tpart(m, "CapTop", Vector3.new(1.2, 5, 5), at * CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.pi / 2), th.Accent:Lerp(Color3.new(1, 1, 1), 0.15), { Shape = Enum.PartType.Cylinder, CanCollide = false })
			for k = 1, 5 do
				local a = k * 1.25
				tpart(m, "Spot" .. k, Vector3.new(0.4, 1, 1), at * CFrame.new(math.cos(a) * 2.6, 3.2, math.sin(a) * 2.6), th.Glow, glow)
			end
		elseif biome == "Marsh" then -- lightning bolt
			local pts = { Vector3.new(-1, 5, 0), Vector3.new(1.5, 1.5, 0), Vector3.new(-1.2, 0.5, 0), Vector3.new(1.2, -4.5, 0) }
			for k = 1, #pts - 1 do
				local a, b = at * pts[k], at * pts[k + 1]
				tpart(m, "Bolt" .. k, Vector3.new(1.1, 1.1, (b - a).Magnitude + 0.8), CFrame.lookAt((a + b) / 2, b), th.Glow, glow)
			end
		elseif biome == "Canyon" then -- crystal cluster
			local base = (at * CFrame.new(0, -4, 0)).Position
			crystalPrism(m, "EmblemMain", base, 12, 2.6, CFrame.new(), CRYSTAL_BLUES[1])
			for k = 1, 4 do
				crystalPrism(m, "EmblemShard" .. k, base + Vector3.new(math.cos(k * 1.57) * 2, 0, math.sin(k * 1.57) * 2), 6, 1.4, CFrame.Angles(0, -k * 1.57, math.rad(25)), CRYSTAL_BLUES[k % #CRYSTAL_BLUES + 1])
			end
		elseif biome == "Volcanic" then -- flame
			for k = 0, 3 do
				tpart(m, "Flame" .. k, Vector3.new(4 - k * 0.8, 3, 4 - k * 0.8), at * CFrame.new(0, -3 + k * 2.4, 0) * CFrame.Angles(0, k * 0.6, 0), th.Glow:Lerp(Color3.fromRGB(255, 240, 160), k / 4), glow)
			end
			local f = Instance.new("Fire")
			f.Size = 10
			f.Parent = m:FindFirstChild("Flame0")
		else -- Coast: wave / shell arc
			for k = 0, 8 do
				local t = k / 8 * math.pi
				tpart(m, "Wave" .. k, Vector3.new(1.2, 1.2, 2.4), at * CFrame.new(math.cos(t) * 4.5, math.sin(t) * 4.5 - 1.5, 0) * CFrame.Angles(0, 0, t), k % 2 == 0 and th.Glow or th.Accent, glow)
			end
		end
	end
	local function temple(biome: string, rAuth: number, deg: number, groundY: number)
		local th = THEMES[biome]
		local m = Instance.new("Model")
		m.Name = biome
		local c = A(rAuth, deg, groundY)
		local inward = Vector3.new(-c.X, 0, -c.Z).Unit
		local base = CFrame.lookAt(Vector3.new(c.X, groundY, c.Z), Vector3.new(c.X, groundY, c.Z) + inward) -- -Z (look) faces the continent centre
		local floorY = 3
		-- stepped base: three octagonal steps (two crossed squares each)
		for step = 1, 3 do
			local w = 84 - step * 8
			for x = 0, 1 do
				tpart(m, "Step" .. step .. "_" .. x, Vector3.new(w, step == 3 and floorY or 1, w), base * CFrame.new(0, (step - 1) + (step == 3 and floorY / 2 - 1 or 0.5), 0) * CFrame.Angles(0, x * math.pi / 4, 0),
					step == 3 and th.Stone or th.Trim:Lerp(th.Stone, step / 3))
			end
		end
		-- inlaid floor ring and centre seal
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			tpart(m, "Inlay" .. k, Vector3.new(6, 0.2, 2), base * CFrame.new(math.cos(a) * 22, floorY + 1.1, math.sin(a) * 22) * CFrame.Angles(0, -a + math.pi / 2, 0), k % 2 == 0 and th.Accent or th.Trim)
		end
		tpart(m, "Seal", Vector3.new(0.3, 14, 14), base * CFrame.new(0, floorY + 1.1, 0) * CFrame.Angles(0, 0, math.pi / 2), th.Accent, { Shape = Enum.PartType.Cylinder, CanCollide = false })
		-- column ring (gap at the gate side)
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2 + math.pi / 12
			local local2 = Vector3.new(math.sin(a) * 27, 0, -math.cos(a) * 27)
			if math.abs(math.deg(a) % 360 - 0) > 20 and math.abs(math.deg(a) % 360 - 360) > 20 then
				local broken = rng:NextNumber() < 0.25
				local h = broken and rng:NextNumber(5, 10) or 18
				local cf = base * CFrame.new(local2 + Vector3.new(0, floorY + 1, 0))
				tpart(m, "ColBase" .. k, Vector3.new(4.4, 1.6, 4.4), cf * CFrame.new(0, 0.8, 0), th.Trim)
				for seg = 0, math.floor(h / 4.5) - 1 do
					for x = 0, 1 do
						tpart(m, "Col" .. k .. "_" .. seg .. "_" .. x, Vector3.new(3, 4.5, 3), cf * CFrame.new(0, 1.6 + seg * 4.5 + 2.25, 0) * CFrame.Angles(0, x * math.pi / 4 + seg * 0.08, 0), th.Stone)
					end
				end
				if broken then
					for r2 = 1, 3 do
						chunk(m, "Rubble" .. k .. "_" .. r2, Vector3.new(2.4, 1.6, 2.4), (cf * CFrame.new(rng:NextNumber(-4, 4), 0.8, rng:NextNumber(-4, 4))).Position, th.Stone, 25)
					end
				else
					tpart(m, "Capital" .. k, Vector3.new(5, 1.4, 5), cf * CFrame.new(0, 1.6 + h + 0.7, 0), th.Trim)
					tpart(m, "CapTop" .. k, Vector3.new(4, 0.8, 4), cf * CFrame.new(0, 1.6 + h + 1.8, 0) * CFrame.Angles(0, math.pi / 4, 0), th.Accent)
					if th.Crystal then
						-- prismatic temple: crystal clusters crown every column
						local cbase = (cf * CFrame.new(0, 1.6 + h + 2.2, 0)).Position
						crystalPrism(m, "ColCrystal" .. k, cbase, 6, 1.6, CFrame.new(), CRYSTAL_BLUES[k % #CRYSTAL_BLUES + 1])
						crystalPrism(m, "ColShard" .. k, cbase + Vector3.new(0.8, 0, 0.4), 3.5, 0.9, CFrame.Angles(0, 0, math.rad(-25)), CRYSTAL_BLUES[(k + 1) % #CRYSTAL_BLUES + 1])
					end
				end
			end
		end
		-- ruined back walls with crenellations between the rear columns
		for k = -2, 2 do
			local a = math.pi + k * math.pi / 6
			local pos = Vector3.new(math.sin(a) * 30.5, 0, -math.cos(a) * 30.5)
			local h = rng:NextNumber(6, 12)
			local wcf = base * CFrame.new(pos + Vector3.new(0, floorY + 1 + h / 2, 0)) * CFrame.Angles(0, -a, 0)
			tpart(m, "Wall" .. k, Vector3.new(14, h, 2.4), wcf, th.Stone:Lerp(th.Trim, 0.25))
			for q = -1, 1 do
				if rng:NextNumber() < 0.75 then
					tpart(m, "Merlon" .. k .. "_" .. q, Vector3.new(2.6, 2, 2.6), wcf * CFrame.new(q * 4.6, h / 2 + 1, 0), th.Stone)
				end
			end
			tpart(m, "Banner" .. k, Vector3.new(4, h * 0.7, 0.3), wcf * CFrame.new(0, -h * 0.05, -1.4), th.Accent, { CanCollide = false })
		end
		-- shrine dais at the back with the emblem
		local shrine = base * CFrame.new(0, floorY + 1, 20)
		tpart(m, "Dais1", Vector3.new(16, 2, 10), shrine * CFrame.new(0, 1, 0), th.Trim)
		tpart(m, "Dais2", Vector3.new(11, 2, 7), shrine * CFrame.new(0, 3, 0.5), th.Stone)
		tpart(m, "Altar", Vector3.new(6, 3, 3.4), shrine * CFrame.new(0, 5.5, 1), th.Stone:Lerp(th.Accent, 0.2))
		emblem(m, biome, shrine * CFrame.new(0, 14, 1) * CFrame.Angles(0, math.pi, 0), th)
		local fxPart = tpart(m, "Aura", Vector3.new(30, 1, 30), base * CFrame.new(0, floorY + 3, 0), th.Glow, MARKER)
		particles(fxPart, th.Fx, 14, 3, th.Accel, 0.5, 0.6)
		local aura = Instance.new("PointLight")
		aura.Range = 50
		aura.Brightness = 1.6
		aura.Color = th.Glow
		aura.Parent = m:FindFirstChild("Altar")
		-- gate: pylons, lintel, pediment, stairs, braziers
		local gate = base * CFrame.new(0, 0, -38)
		-- v2.13 (director: the gate blocked the facade): two lower obelisks set
		-- wide apart, no lintel/pediment across the view
		for sgn = -1, 1, 2 do
			local py = gate * CFrame.new(sgn * 14, 0, 0)
			tpart(m, "Pylon" .. sgn, Vector3.new(4, 11, 4), py * CFrame.new(0, 6.5, 0), th.Stone)
			tpart(m, "PylonBand" .. sgn, Vector3.new(4.6, 1, 4.6), py * CFrame.new(0, 5, 0), th.Accent)
			tpart(m, "PylonTop" .. sgn, Vector3.new(3, 2.4, 3), py * CFrame.new(0, 13, 0) * CFrame.Angles(0, math.pi / 4, 0), th.Trim)
			-- brazier with fire / glow
			local br = gate * CFrame.new(sgn * 20, 0, -4)
			tpart(m, "BrazierLeg" .. sgn, Vector3.new(1.4, 5, 1.4), br * CFrame.new(0, 2.5, 0), th.Trim)
			local bowl = tpart(m, "Brazier" .. sgn, Vector3.new(4, 1.6, 4), br * CFrame.new(0, 5.6, 0), th.Trim)
			local flame = tpart(m, "BrazierGlow" .. sgn, Vector3.new(2.6, 1, 2.6), br * CFrame.new(0, 6.6, 0), th.Glow, { Material = Enum.Material.Neon, CanCollide = false })
			local fire = Instance.new("Fire")
			fire.Size = 6
			fire.Color = th.Glow
			fire.SecondaryColor = th.Accent
			fire.Parent = flame
			local l = Instance.new("PointLight")
			l.Range = 22
			l.Color = th.Glow
			l.Parent = bowl
		end
		-- accent path tiles leading through the gate to the seal
		for k = 0, 5 do
			tpart(m, "Path" .. k, Vector3.new(6, 0.2, 3), base * CFrame.new(0, (k < 1 and 1 or 4) + 0.1, -36 + k * 5), k % 2 == 0 and th.Accent or th.Trim, { CanCollide = false })
		end
		local spawn = newPart(m, "BossSpawn", Vector3.new(2, 1, 2), base * CFrame.new(0, floorY + 4, 4), Color3.new(1, 0, 0), MARKER)
		spawn:SetAttribute("Biome", biome)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				tag(d, Z[biome] or Z.Coast)
			end
		end
		m:SetAttribute("Biome", biome)
		m.Parent = templesFolder
		return m
	end
	temple("Plateau", 248, 0, UP)
	temple("Mountains", 250, 62, UP)
	temple("Mushroom", 248, 120, UP)
	temple("Marsh", 252, 180, UP - 3)
	temple("Canyon", 252, 240, canyonTop(252))
	temple("Volcanic", 252, 300, UP)
	temple("Coast", 281, 210, UP - 0.5)
	print("[MapCheck] temples: " .. #templesFolder:GetChildren())

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
		for k = 1, 4 do
			local cs = w * rng:NextNumber(0.12, 0.2)
			lobe(model, "Curl" .. k, Vector3.new(cs, cs * 0.85, cs), CFrame.new(center) * yaw * CFrame.new(rng:NextNumber(-0.4, 0.4) * w, w * rng:NextNumber(0.1, 0.24), rng:NextNumber(-0.2, 0.2) * w),
				belly:Lerp(top, rng:NextNumber(0.6, 1)), 0.06)
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
		-- v2.7 detail: smaller curls hanging off the bulges
		for k = 1, 4 do
			local cs = w * rng:NextNumber(0.14, 0.22)
			lobe(model, "Curl" .. k, Vector3.new(cs, cs * 0.8, cs), yaw * CFrame.new(rng:NextNumber(-0.4, 0.4) * w, -w * rng:NextNumber(0.2, 0.3), rng:NextNumber(-0.25, 0.25) * w),
				belly:Lerp(top, rng:NextNumber(0.3, 0.6)), 0.05)
		end
		model.Parent = underClouds
	end
	local masses = 0
	-- v2.10 (bigger continent): grid covers the whole new footprint
	for gx = -1300, 1300, 100 do
		for gz = -1300, 1300, 100 do
			local c = Vector3.new(gx + rng:NextNumber(-14, 14), UP - 44 + rng:NextNumber(-5, 3), gz + rng:NextNumber(-14, 14))
			local r = Vector2.new(c.X, c.Z).Magnitude
			local deg = math.deg(math.atan2(c.Z, c.X)) % 360
			if r > 34 + 50 and r < edgeAt(deg) * 1.04 then
				masses += 1
				hangingMass("CloudMass" .. masses, c, rng:NextNumber(120, 150))
			end
		end
	end
	-- v2.10 director: the plate must never show from below. Second, lower
	-- CLOUD DECK of wide flattened lobes (overlapping on a 130 grid, offset
	-- from the canopy grid) closes every gap between the hanging masses, and
	-- a SKIRT of masses around the shoreline hides the plate's side faces
	-- from low, far camera angles. Together they read as one thick layer.
	local deck = Instance.new("Folder")
	deck.Name = "CloudDeck"
	deck.Parent = underClouds
	local deckN = 0
	for gx = -1300 + 65, 1300, 130 do
		for gz = -1300 + 65, 1300, 130 do
			local c = Vector3.new(gx + rng:NextNumber(-12, 12), UP - 78 + rng:NextNumber(-4, 4), gz + rng:NextNumber(-12, 12))
			local r = Vector2.new(c.X, c.Z).Magnitude
			local deg = math.deg(math.atan2(c.Z, c.X)) % 360
			if r > 34 + 60 and r < edgeAt(deg) * 1.02 then
				deckN += 1
				local w = rng:NextNumber(190, 230)
				local yaw = CFrame.new(c) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				lobe(deck, "Deck" .. deckN, Vector3.new(w, w * 0.2, w * 0.85), yaw, Color3.fromRGB(222, 228, 242), 0.08)
				lobe(deck, "DeckBulge" .. deckN, Vector3.new(w * 0.45, w * 0.16, w * 0.4), yaw * CFrame.new(rng:NextNumber(-0.2, 0.2) * w, -w * 0.07, rng:NextNumber(-0.2, 0.2) * w),
					Color3.fromRGB(210, 218, 236), 0.08)
			end
		end
	end
	for i = 0, 89 do
		local deg = i * 4 + rng:NextNumber(-1, 1)
		local w = rng:NextNumber(95, 120)
		local c = polar(edgeAt(deg) * 1.02, deg, UP - 32)
		lobe(deck, "Skirt" .. i, Vector3.new(w, w * 0.42, w * 0.6), CFrame.lookAt(c, c + polar(1, deg + 90, 0)), Color3.fromRGB(236, 240, 250), 0.06)
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
	local pitMarker = newPart(decor, "PitMarker", Vector3.one, CFrame.new(A(330, 240, UP + 5)), Color3.new(1, 0, 0), MARKER)
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
	scatter(20, 4, habGen(90, 250, 333, 387, "Plateau", UP), function(i, p) dressFlowers("Flowers" .. i, p) end)
	scatter(10, 6, habGen(90, 250, 333, 387, "Plateau", UP), function(i, p) dressRocks("MeadowRocks" .. i, p, Color3.fromRGB(165, 160, 150), "Plateau") end)
	scatter(30, 6, habGen(80, 255, 33, 87, "Mountains", UP), function(i, p) dressPine("Pine" .. i, p) end)
	scatter(16, 7, habGen(80, 255, 33, 87, "Mountains", UP), function(i, p) dressRocks("MountainRocks" .. i, p, Color3.fromRGB(150, 148, 150), "Mountains") end)
	scatter(22, 6, habGen(85, 250, 93, 147, "Mushroom", UP), function(i, p) dressGrove("Grove" .. i, p) end)
	scatter(26, 4, habGen(80, 255, 153, 207, "Marsh", UP - 3), function(i, p) dressReeds("Reeds" .. i, p) end)
	scatter(10, 6, habGen(80, 255, 153, 207, "Marsh", UP - 3), function(i, p) dressLog("Log" .. i, p) end)
	scatter(14, 4, function()
		local deg, r = rng:NextNumber(214, 266), rng:NextNumber(112, 218)
		if inPit(deg, r - 6, r + 6) or habitatAt(deg, r) ~= "Canyon" then
			return nil
		end
		return A(r, deg, UP - 12)
	end, function(i, p) dressCrystals("CrystalGroup" .. i, p) end)
	scatter(16, 5, habGen(85, 255, 273, 327, "Volcanic", UP), function(i, p) dressBasalt("Basalt" .. i, p) end)
	scatter(10, 6, habGen(85, 255, 273, 327, "Volcanic", UP), function(i, p) dressRocks("AshRocks" .. i, p, Color3.fromRGB(70, 60, 60), "Volcanic") end)
	scatter(20, 4, function()
		return A(rng:NextNumber(266, 296), rng:NextNumber(0, 360), UP - 0.5)
	end, function(i, p) dressBeach("Beach" .. i, p) end)
	scatter(16, 6, function()
		return A(rng:NextNumber(268, 298), rng:NextNumber(0, 360), UP - 0.5)
	end, function(i, p) dressRocks("ShoreRocks" .. i, p, Color3.fromRGB(175, 165, 150), "Coast") end)
	-- foothills: boulder clusters around the base of every peak
	for i, spec in { { 175, 60, 92 }, { 115, 42, 50 }, { 225, 78, 58 }, { 130, 84, 40 }, { 235, 38, 42 }, { 160, 35, 34 } } do
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
-- v2.16: after the map is in workspace, sit every canyon prop on the real
-- ground under it (habitat borders wander, so a prop's planned floor height
-- can be off): nothing floats, nothing is buried. Props with no ground at
-- all under them are removed.
function ContinentBuilder.GroundProps(map: Instance)
	local continent = map:FindFirstChild("Continent")
	local decor = map:FindFirstChild("Decor")
	if not continent then
		return
	end
	local list = {}
	local walls = continent:FindFirstChild("CanyonWalls")
	for _, m in walls and walls:GetChildren() or {} do
		if m:IsA("Model") and string.sub(m.Name, 1, 6) == "Hoodoo" then
			table.insert(list, m)
		end
	end
	for _, m in decor and decor:GetChildren() or {} do
		if m:IsA("Model") and string.sub(m.Name, 1, 15) == "CrystalLandmark" then
			table.insert(list, m)
		end
	end
	local dressing = decor and decor:FindFirstChild("Dressing")
	local canyonDress = dressing and dressing:FindFirstChild("Canyon")
	for _, m in canyonDress and canyonDress:GetChildren() or {} do
		if m:IsA("Model") then
			table.insert(list, m)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { continent:FindFirstChild("Ground") or continent }
	local moved, removed = 0, 0
	for _, m in list do
		local cf, size = m:GetBoundingBox()
		local bottom = cf.Position.Y - size.Y / 2
		local hit = workspace:Raycast(Vector3.new(cf.Position.X, bottom + 30, cf.Position.Z), Vector3.new(0, -70, 0), params)
		if not hit then
			m:Destroy()
			removed += 1
		elseif math.abs(hit.Position.Y - bottom) > 0.3 then
			m:PivotTo(m:GetPivot() + Vector3.new(0, hit.Position.Y - bottom, 0))
			moved += 1
		end
	end
	print(string.format("[MapCheck] canyon props grounded: %d moved, %d removed", moved, removed))
end

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
