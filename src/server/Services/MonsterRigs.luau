-- Blocky, chunky monster rigs (original designs, part-built, no assets).
-- Every body piece is joined to its parent with a Motor6D whose C0 is the
-- joint point on the parent and C1 the joint point on the piece itself, so
-- KeyframeSequence poses rotate limbs around shoulders / hips / necks.
-- Each part carries attribute Role (body, head, jawTop, jawBot, legA, legB,
-- armL, armR, wing, tail, spin, orbit, deco) — MonsterAnims animates by role.
--
-- MonsterRigs.Build(typeName, scale) -> Model (HumanoidRootPart + Humanoid)

local MonsterRigs = {}

local V = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material

local function rig(name: string, scale: number, hip: number)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = V(2, 2, 1) * scale
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(0, hip * scale + root.Size.Y / 2, 0)
	root.Parent = model
	model.PrimaryPart = root
	local parts = { HumanoidRootPart = root }
	return { Model = model, Parts = parts, Scale = scale, Hip = hip }
end

-- add(r, name, parent, size, joint (on parent), pivot (on this part), color, opts)
-- opts: Material, Shape ("Ball"/"Cylinder"), Class ("WedgePart"/"CornerWedgePart"),
--       Role, Rot (CFrame applied at the joint), Transparency, Glow (PointLight colour)
local function add(r, name: string, parent: string, size: Vector3, joint: Vector3, pivot: Vector3, color: Color3, opts)
	opts = opts or {}
	local s = r.Scale
	local p = Instance.new(opts.Class or "Part") :: BasePart
	p.Name = name
	p.Size = size * s
	p.Color = color
	p.Material = opts.Material or M.SmoothPlastic
	if opts.Shape then
		(p :: Part).Shape = Enum.PartType[opts.Shape]
	end
	p.Transparency = opts.Transparency or 0
	-- v2.2: every monster is built in the classic studded plastic style;
	-- glowing (Neon), crystal (Glass), and see-through parts keep their material
	local special = p.Material == M.Neon or p.Material == M.Glass or (opts.Transparency or 0) > 0
	if opts.Studs ~= false and not special then
		opts.Studs = true
	end
	if opts.Studs then
		-- classic Roblox studded plastic (v2.1 style): studs on top, inlets below
		p.Material = M.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Inlet
	end
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true -- lasers / punches can hit it
	p.Massless = true
	p.CastShadow = false
	p:SetAttribute("Role", opts.Role or "deco")
	local parentPart = r.Parts[parent]
	local c0 = CFrame.new(joint * s) * (opts.Rot or CFrame.new())
	local c1 = CFrame.new(pivot * s)
	p.CFrame = parentPart.CFrame * c0 * c1:Inverse()
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = parentPart
	m.Part1 = p
	m.C0 = c0
	m.C1 = c1
	m.Parent = parentPart
	if opts.Glow then
		local l = Instance.new("PointLight")
		l.Color = opts.Glow
		l.Range = 10 * s
		l.Brightness = 1.5
		l.Parent = p
	end
	p.Parent = r.Model
	r.Parts[name] = p
	return p
end

local function legs4(r, body: string, w: number, l: number, h: number, size: Vector3, color: Color3, material)
	-- four legs at the body's corners; diagonal pairs share a swing group
	add(r, "LegFL", body, size, V(-w, -h, -l), V(0, size.Y / 2, 0), color, { Role = "legA", Material = material })
	add(r, "LegBR", body, size, V(w, -h, l), V(0, size.Y / 2, 0), color, { Role = "legA", Material = material })
	add(r, "LegFR", body, size, V(w, -h, -l), V(0, size.Y / 2, 0), color, { Role = "legB", Material = material })
	add(r, "LegBL", body, size, V(-w, -h, l), V(0, size.Y / 2, 0), color, { Role = "legB", Material = material })
end

local function biped(r, body: string, hipY: number, hipX: number, legSize: Vector3, shoulderY: number, shoulderX: number, armSize: Vector3, legColor: Color3, armColor: Color3, material)
	add(r, "LegL", body, legSize, V(-hipX, hipY, 0), V(0, legSize.Y / 2, 0), legColor, { Role = "legA", Material = material })
	add(r, "LegR", body, legSize, V(hipX, hipY, 0), V(0, legSize.Y / 2, 0), legColor, { Role = "legB", Material = material })
	add(r, "ArmL", body, armSize, V(-shoulderX, shoulderY, 0), V(0, armSize.Y / 2, 0), armColor, { Role = "armL", Material = material })
	add(r, "ArmR", body, armSize, V(shoulderX, shoulderY, 0), V(0, armSize.Y / 2, 0), armColor, { Role = "armR", Material = material })
end

local function crystal(r, name: string, parent: string, size: Vector3, at: Vector3, rot: CFrame, color: Color3, role: string?)
	return add(r, name, parent, size, at, V(0, -size.Y / 2, 0), color, {
		Class = "WedgePart", Material = M.Glass, Rot = rot, Role = role or "deco", Transparency = 0.05,
	})
end

local A = CFrame.Angles
local rad = math.rad

-- v2.5 DETAIL KIT (director: no more "two shapes" monsters). Three levels:
-- silhouette (body/head/limbs), secondary anatomy (chest/belly blocks,
-- joints, plates), tertiary accents (brows, claws, spots, teeth).
--
-- articulated limb: Upper (animated by role) -> Lower -> Tip (foot/hand/claw)
local function limb(r, name: string, parent: string, joint: Vector3, upper: Vector3, lower: Vector3, tip: Vector3?, color: Color3, tipColor: Color3?, role: string, opts)
	opts = opts or {}
	add(r, name, parent, upper, joint, V(0, upper.Y / 2, 0), color, { Role = role, Shape = opts.Shape })
	add(r, name .. "Lower", name, lower, V(0, -upper.Y / 2 + 0.1, opts.Bend or 0), V(0, lower.Y / 2, 0), color:Lerp(RGB(0, 0, 0), 0.1), { Shape = opts.LowerShape })
	if tip then
		add(r, name .. "Tip", name .. "Lower", tip, V(0, -lower.Y / 2, -(tip.Z - lower.Z) / 2), V(0, tip.Y / 2, 0), tipColor or color, {})
	end
end

-- eyes (MonsterRigs.cartoonEyes turns EyeL/EyeR into big eyes with pupils) + brows
local function face(r, parent: string, at: Vector3, spacing: number, eye: Vector3, browColor: Color3, browTilt: number)
	add(r, "EyeL", parent, eye, at + V(-spacing, 0, 0), V(0, 0, 0), RGB(30, 30, 30), {})
	add(r, "EyeR", parent, eye, at + V(spacing, 0, 0), V(0, 0, 0), RGB(30, 30, 30), {})
	add(r, "BrowL", parent, V(eye.X * 1.7, eye.Y * 0.32, 0.3), at + V(-spacing, eye.Y * 0.95, -0.08), V(0, 0, 0), browColor, { Rot = A(0, 0, rad(browTilt)) })
	add(r, "BrowR", parent, V(eye.X * 1.7, eye.Y * 0.32, 0.3), at + V(spacing, eye.Y * 0.95, -0.08), V(0, 0, 0), browColor, { Rot = A(0, 0, rad(-browTilt)) })
end

-- a row of small teeth/claws (wedges) along X
local function teeth(r, prefix: string, parent: string, at: Vector3, count: number, width: number, size: Vector3, down: boolean, color: Color3?)
	for i = 1, count do
		local x = -width / 2 + (i - 0.5) * width / count
		add(r, prefix .. i, parent, size, at + V(x, 0, 0), V(0, 0, 0), color or RGB(255, 255, 250), {
			Class = "WedgePart", Rot = down and A(rad(180), 0, 0) or nil,
		})
	end
end

-- a crystal cluster: 3 crystals of different size/tilt around a point
local function crystalCluster(r, prefix: string, parent: string, at: Vector3, scale: number, colors: { Color3 })
	local spec = {
		{ V(0, 0, 0), V(0.9, 2.4, 1.4), A(rad(-8), 0, 0) },
		{ V(-0.7, -0.2, 0.3), V(0.7, 1.6, 1.1), A(rad(10), rad(70), rad(25)) },
		{ V(0.6, -0.25, -0.2), V(0.6, 1.3, 1), A(rad(-12), rad(-60), rad(-22)) },
	}
	for i, c in spec do
		crystal(r, prefix .. i, parent, c[2] * scale, at + c[1] * scale, c[3], colors[(i - 1) % #colors + 1])
	end
end

local BUILD = {}

-- (a) Prismaw: crystal stalker — a lean purple quadruped with a lavender
-- chest, faceted snouted head, crystal ears, three crystal clusters along
-- its back, shoulder shards, jointed legs with paws and a crystal tail
BUILD.Prismaw = function(s)
	local r = rig("Prismaw", s, 3)
	local purple, dark, lav = RGB(115, 55, 175), RGB(70, 35, 110), RGB(190, 160, 235)
	local cyan, magenta = RGB(60, 230, 240), RGB(240, 70, 200)
	add(r, "Body", "HumanoidRootPart", V(5, 3.2, 7.4), V(0, 0.7, 0), V(0, 0, 0), purple, { Role = "body" })
	add(r, "Chest", "Body", V(4.2, 2.2, 3), V(0, -0.8, -2.2), V(0, 0, 0), lav, {})
	add(r, "Hips", "Body", V(4.4, 2.6, 2.4), V(0, 0.2, 2.8), V(0, 0, 0), dark, {})
	add(r, "Neck", "Body", V(2.6, 2.2, 2), V(0, 1, -3.8), V(0, 0, 0.6), purple, { Rot = A(rad(-20), 0, 0) })
	add(r, "Head", "Neck", V(3.2, 2.6, 2.8), V(0, 0.5, -1.1), V(0, -0.2, 1.2), purple, { Role = "head" })
	add(r, "Snout", "Head", V(2.4, 1.4, 1.8), V(0, -0.4, -1.4), V(0, 0, 0.8), purple, { Class = "WedgePart", Rot = A(0, math.pi, 0) })
	add(r, "Jaw", "Head", V(2.4, 0.7, 2.4), V(0, -1.3, -0.6), V(0, 0.3, 1.1), dark, { Role = "jawBot" })
	teeth(r, "Fang", "Jaw", V(0, 0.55, -1), 4, 1.8, V(0.3, 0.5, 0.3), false, RGB(200, 250, 255))
	face(r, "Head", V(0, 0.55, -1.42), 0.8, V(0.55, 0.6, 0.25), dark, 14)
	crystal(r, "EarL", "Head", V(0.5, 1.6, 1), V(-1.1, 1.2, 0.3), A(rad(-15), 0, rad(25)), cyan)
	crystal(r, "EarR", "Head", V(0.5, 1.6, 1), V(1.1, 1.2, 0.3), A(rad(-15), 0, rad(-25)), magenta)
	crystalCluster(r, "BackA", "Body", V(0, 1.6, -1.6), 1.1, { cyan, magenta })
	crystalCluster(r, "BackB", "Body", V(-0.6, 1.6, 0.8), 0.9, { magenta, cyan })
	crystalCluster(r, "BackC", "Hips", V(0.4, 1.3, 0.2), 0.75, { cyan })
	crystal(r, "ShoulderL", "Body", V(0.6, 1.4, 1), V(-2.5, 0.8, -2.2), A(0, 0, rad(50)), cyan)
	crystal(r, "ShoulderR", "Body", V(0.6, 1.4, 1), V(2.5, 0.8, -2.2), A(0, 0, rad(-50)), magenta)
	for _, spec in { { "LegFL", -1.9, -2.6, "legA" }, { "LegFR", 1.9, -2.6, "legB" }, { "LegBL", -1.9, 2.8, "legB" }, { "LegBR", 1.9, 2.8, "legA" } } do
		limb(r, spec[1], "Body", V(spec[2], -1.3, spec[3]), V(1.3, 1.8, 1.4), V(1, 1.6, 1.1), V(1.3, 0.5, 1.6), dark, lav, spec[4])
	end
	add(r, "Tail", "Hips", V(1.2, 1.2, 2.2), V(0, 0.4, 1.6), V(0, 0, -1), dark, { Role = "tail", Rot = A(rad(20), 0, 0) })
	crystal(r, "TailShard", "Tail", V(0.9, 1.8, 1.4), V(0, 0.2, 1.2), A(rad(-70), math.pi, 0), cyan)
	return r
end

-- (b) Frostback: glacier tortoise — dark plastron belly, a layered domed
-- shell (rim + dome + top plates) carrying ice crystal clusters, a beaked
-- head on a thick neck, elephant legs with toe nails, a stubby tail
BUILD.Frostback = function(s)
	local r = rig("Frostback", s, 2.2)
	local skin, shell, rim, belly, ice = RGB(70, 85, 75), RGB(85, 76, 72), RGB(60, 52, 50), RGB(200, 190, 150), RGB(175, 235, 205)
	add(r, "Body", "HumanoidRootPart", V(6.4, 2.2, 7.4), V(0, 0.3, 0), V(0, 0, 0), belly, { Role = "body" })
	add(r, "ShellRim", "Body", V(7.4, 0.8, 8.4), V(0, 1.4, 0), V(0, 0, 0), rim, {})
	add(r, "Shell", "Body", V(6.4, 1.8, 7.2), V(0, 2.6, 0), V(0, 0, 0), shell, {})
	add(r, "ShellTop", "Shell", V(4.6, 1.2, 5.2), V(0, 1.4, 0), V(0, 0, 0), shell:Lerp(RGB(255, 255, 255), 0.06), {})
	for i, p in { V(-2.2, 0.95, -2.4), V(2.2, 0.95, -2.4), V(-2.2, 0.95, 2.4), V(2.2, 0.95, 2.4), V(0, 0.95, -3.1), V(0, 0.95, 3.1) } do
		add(r, "Plate" .. i, "Shell", V(1.6, 0.3, 1.6), p, V(0, 0, 0), rim, {})
	end
	crystalCluster(r, "IceA", "ShellTop", V(0, 0.6, -0.6), 1.2, { ice })
	crystalCluster(r, "IceB", "Shell", V(-2, 1, 1.6), 0.8, { ice })
	crystalCluster(r, "IceC", "Shell", V(2.1, 1, 1.2), 0.7, { ice })
	add(r, "Neck", "Body", V(1.8, 1.6, 2.2), V(0, 0.5, -4), V(0, 0, 0.8), skin, {})
	add(r, "Head", "Neck", V(2.6, 2.1, 2.6), V(0, 0.4, -1.3), V(0, 0, 1.1), skin, { Role = "head" })
	add(r, "Beak", "Head", V(2, 1, 1.2), V(0, -0.3, -1.6), V(0, 0, 0), RGB(200, 180, 120), { Class = "WedgePart", Rot = A(0, math.pi, 0) })
	add(r, "Jaw", "Head", V(2.2, 0.6, 2.2), V(0, -1.2, -0.3), V(0, 0.3, 1), RGB(55, 70, 60), { Role = "jawBot" })
	face(r, "Head", V(0, 0.5, -1.32), 0.75, V(0.45, 0.5, 0.2), RGB(40, 50, 45), 10)
	for _, spec in { { "LegFL", -2.7, -2.6, "legA" }, { "LegFR", 2.7, -2.6, "legB" }, { "LegBL", -2.7, 2.7, "legB" }, { "LegBR", 2.7, 2.7, "legA" } } do
		limb(r, spec[1], "Body", V(spec[2], -0.6, spec[3]), V(2, 1.4, 2), V(1.8, 1.3, 1.8), V(2.2, 0.4, 2.4), skin, RGB(225, 220, 200), spec[4])
	end
	crystal(r, "LegIceL", "LegFL", V(0.8, 1.4, 1.2), V(-0.7, 0.2, -0.4), A(0, rad(45), rad(25)), ice)
	crystal(r, "LegIceR", "LegFR", V(0.8, 1.4, 1.2), V(0.7, 0.2, -0.4), A(0, rad(-45), rad(-25)), ice)
	add(r, "Tail", "Body", V(0.9, 0.8, 1.6), V(0, 0, 4), V(0, 0, -0.6), skin, { Role = "tail", Class = "WedgePart" })
	return r
end

-- (c) Voltwraith: storm wraith — a body made of dark cloud lobes around a
-- glowing storm heart, a hooded cloud head with a brow ridge, long jointed
-- arms ending in lightning claws, a tapering cloud tail with a bolt
BUILD.Voltwraith = function(s)
	local r = rig("Voltwraith", s, 5)
	local cloud, deep, bolt = RGB(70, 76, 98), RGB(45, 50, 70), RGB(110, 240, 255)
	add(r, "Body", "HumanoidRootPart", V(3.4, 3.6, 2.4), V(0, 1, 0), V(0, 0, 0), cloud, { Role = "body", Shape = "Ball" })
	add(r, "ChestLobeL", "Body", V(2.2, 2.2, 2.2), V(-1.1, 0.8, -0.2), V(0, 0, 0), cloud:Lerp(RGB(255, 255, 255), 0.05), { Shape = "Ball" })
	add(r, "ChestLobeR", "Body", V(2.2, 2.2, 2.2), V(1.1, 0.8, -0.2), V(0, 0, 0), cloud:Lerp(RGB(255, 255, 255), 0.05), { Shape = "Ball" })
	add(r, "StormHeart", "Body", V(1.2, 1.2, 0.4), V(0, 0.3, -1.25), V(0, 0, 0), bolt, { Material = M.Neon, Glow = bolt })
	add(r, "ShoulderL", "Body", V(1.8, 1.8, 1.8), V(-1.9, 1.6, 0), V(0, 0, 0), deep, { Shape = "Ball" })
	add(r, "ShoulderR", "Body", V(1.8, 1.8, 1.8), V(1.9, 1.6, 0), V(0, 0, 0), deep, { Shape = "Ball" })
	add(r, "Head", "Body", V(2.4, 2.4, 2.4), V(0, 2.2, 0), V(0, -1.2, 0), cloud, { Role = "head", Shape = "Ball" })
	add(r, "Hood", "Head", V(2.8, 1.2, 2.6), V(0, 0.8, 0.2), V(0, 0, 0), deep, { Shape = "Ball" })
	add(r, "BrowRidge", "Head", V(2.2, 0.35, 0.6), V(0, 0.45, -1), V(0, 0, 0), deep, {})
	add(r, "EyeL", "Head", V(0.5, 0.3, 0.2), V(-0.5, 0.15, -1.15), V(0, 0, 0), bolt, { Material = M.Neon })
	add(r, "EyeR", "Head", V(0.5, 0.3, 0.2), V(0.5, 0.15, -1.15), V(0, 0, 0), bolt, { Material = M.Neon })
	add(r, "Mouth", "Head", V(1, 0.15, 0.15), V(0, -0.5, -1.15), V(0, 0, 0), bolt, { Material = M.Neon })
	for _, side in { -1, 1 } do
		local n = side < 0 and "ArmL" or "ArmR"
		limb(r, n, "Body", V(side * 2.2, 1.5, 0), V(1, 2.4, 1), V(0.8, 2.4, 0.8), nil, cloud, nil, side < 0 and "armL" or "armR")
		for k = -1, 1 do
			add(r, n .. "Claw" .. (k + 2), n .. "Lower", V(0.25, 1, 0.25), V(k * 0.28, -1.5, -0.1), V(0, 0.5, 0), bolt, {
				Class = "WedgePart", Material = M.Neon, Rot = A(rad(180), 0, rad(k * 15)),
			})
		end
	end
	add(r, "Tail1", "Body", V(2.6, 2, 2), V(0, -1.9, 0.2), V(0, 1, 0), cloud, { Role = "tail", Shape = "Ball" })
	add(r, "Tail2", "Tail1", V(1.8, 1.8, 1.6), V(0, -1, 0.3), V(0, 0.9, 0), deep, { Role = "tail", Shape = "Ball" })
	add(r, "Tail3", "Tail2", V(1.1, 1.4, 1), V(0, -0.9, 0.3), V(0, 0.7, 0), deep, { Role = "tail", Shape = "Ball" })
	add(r, "TailBolt", "Tail3", V(0.25, 1.6, 0.25), V(0.2, -0.6, 0), V(0, 0, 0), bolt, { Material = M.Neon, Rot = A(0, 0, rad(25)) })
	return r
end

-- (d) Cyclonox: living twister — a cloud-crowned storm head with brows and a
-- howling mouth, a six-ring spinning funnel, cloud arms with fists, and
-- debris + tiny bolts orbiting it
BUILD.Cyclonox = function(s)
	local r = rig("Cyclonox", s, 5)
	local storm, dark, eye = RGB(110, 116, 132), RGB(66, 70, 84), RGB(140, 230, 255)
	add(r, "Body", "HumanoidRootPart", V(4, 3, 4), V(0, 2, 0), V(0, 0, 0), dark, { Role = "body", Shape = "Ball" })
	add(r, "Head", "Body", V(5.4, 2.6, 5.4), V(0, 2.4, 0), V(0, 0, 0), storm, { Role = "head", Shape = "Ball" })
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		add(r, "Crown" .. i, "Head", V(2, 1.6, 2), V(math.cos(a) * 1.8, 1, math.sin(a) * 1.8), V(0, 0, 0), storm:Lerp(RGB(255, 255, 255), 0.1), { Shape = "Ball" })
	end
	face(r, "Head", V(0, 0.4, -2.55), 1, V(0.7, 0.45, 0.25), dark, 18)
	add(r, "Mouth", "Head", V(1.4, 0.6, 0.3), V(0, -0.5, -2.55), V(0, 0, 0), RGB(30, 32, 45), {})
	local last = "Body"
	for i, w in { 3.8, 3.2, 2.6, 2.0, 1.5, 1.0 } do
		add(r, "Funnel" .. i, last, V(w, 1.3, w), V(0.12 * i, -1.15, 0), V(0, 0, 0), storm:Lerp(dark, i / 7), { Role = "spin", Shape = "Ball" })
		last = "Funnel" .. i
	end
	for _, side in { -1, 1 } do
		local n = side < 0 and "ArmL" or "ArmR"
		limb(r, n, "Head", V(side * 2.9, -0.4, 0), V(1.6, 2.2, 1.6), V(1.3, 2, 1.3), nil, storm, nil, side < 0 and "armL" or "armR")
		add(r, n .. "Fist", n .. "Lower", V(2.2, 2.2, 2.2), V(0, -1.3, 0), V(0, 0, 0), dark, { Shape = "Ball" })
	end
	for i = 1, 4 do
		local a = i * 1.6
		add(r, "Debris" .. i, "Body", V(0.9, 0.7, 0.8), V(math.cos(a) * 3.6, 0.5 * i - 1.5, math.sin(a) * 3.6), V(0, 0, 0), RGB(130, 105, 80), { Role = "orbit" })
	end
	for i = 1, 2 do
		local a = i * 3.1 + 0.8
		add(r, "Spark" .. i, "Body", V(0.2, 1.2, 0.2), V(math.cos(a) * 3, -0.5, math.sin(a) * 3), V(0, 0, 0), eye, { Role = "orbit", Material = M.Neon, Rot = A(0, 0, rad(30)) })
	end
	return r
end

-- (e) Cindermaw: magma tyrant — stacked basalt torso plates over a glowing
-- core, huge shoulder plates swept up like wings, a horned head with brow,
-- fanged jaw and magma mouth, jointed arms with magma fists, digitigrade
-- legs with claws, a segmented rock tail
BUILD.Cindermaw = function(s)
	local r = rig("Cindermaw", s, 4)
	local rock, dark, magma = RGB(52, 40, 40), RGB(32, 26, 28), RGB(255, 115, 35)
	add(r, "Body", "HumanoidRootPart", V(4.6, 3, 3), V(0, 1.6, 0), V(0, 0, 0), rock, { Role = "body" })
	add(r, "Chest", "Body", V(5.4, 2.4, 3.4), V(0, 2.4, -0.1), V(0, 0, 0), rock, {})
	add(r, "Core", "Chest", V(1.8, 1.8, 0.4), V(0, -0.1, -1.72), V(0, 0, 0), magma, { Material = M.Neon, Glow = magma })
	for i, x in { -1.6, 1.6 } do
		add(r, "Seam" .. i, "Body", V(0.25, 2.6, 0.2), V(x, 0, -1.52), V(0, 0, 0), magma, { Material = M.Neon, Rot = A(0, 0, rad(x * 8)) })
	end
	add(r, "Belt", "Body", V(4.8, 0.6, 3.2), V(0, -1.2, 0), V(0, 0, 0), dark, {})
	add(r, "Head", "Chest", V(2.6, 2.2, 2.4), V(0, 1.5, -0.4), V(0, -1.1, 0), rock, { Role = "head" })
	add(r, "Jaw", "Head", V(2.3, 0.7, 2), V(0, -1.2, -0.3), V(0, 0.3, 0.9), dark, { Role = "jawBot" })
	teeth(r, "Fang", "Jaw", V(0, 0.55, -0.8), 4, 1.8, V(0.3, 0.6, 0.3), false)
	add(r, "Mouth", "Head", V(1.6, 0.3, 0.2), V(0, -0.55, -1.22), V(0, 0, 0), magma, { Material = M.Neon })
	face(r, "Head", V(0, 0.35, -1.22), 0.65, V(0.45, 0.4, 0.2), dark, 22)
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "HornBase" .. n, "Head", V(0.7, 1.2, 0.7), V(side * 1.1, 1, 0.2), V(0, -0.6, 0), dark, { Rot = A(0, 0, rad(-side * 30)) })
		add(r, "HornTip" .. n, "HornBase" .. n, V(0.5, 1.2, 0.8), V(0, 0.6, 0), V(0, -0.6, 0), RGB(230, 220, 200), { Class = "WedgePart", Rot = A(0, 0, rad(-side * 25)) })
		add(r, "Wing" .. n, "Chest", V(0.6, 5, 4), V(side * 2.4, 1.4, 1.4), V(0, -2.2, 1.4), rock, { Class = "WedgePart", Role = "wing", Rot = A(rad(-20), rad(side * 90), rad(-side * 35)) })
		add(r, "WingSeam" .. n, "Wing" .. n, V(0.65, 3.6, 0.25), V(0, 0, 0.6), V(0, 0, 0), magma, { Material = M.Neon })
		add(r, "Pauldron" .. n, "Chest", V(2.2, 1.4, 2.6), V(side * 3, 0.9, 0), V(0, 0, 0), dark, {})
		limb(r, "Arm" .. n, "Chest", V(side * 3.3, 0.2, 0), V(1.8, 2.6, 1.8), V(1.6, 2.4, 1.6), nil, rock, nil, side < 0 and "armL" or "armR")
		add(r, "MagmaFist" .. n, "Arm" .. n .. "Lower", V(2.2, 1.6, 2.2), V(0, -1.6, 0), V(0, 0, 0), magma, { Material = M.Neon, Glow = side > 0 and magma or nil })
		limb(r, "Leg" .. n, "Body", V(side * 1.5, -1.4, 0), V(2, 2.2, 2), V(1.6, 2, 1.6), V(2, 0.6, 2.6), rock, dark, side < 0 and "legA" or "legB", { Bend = 0.3 })
		teeth(r, "Claw" .. n, "Leg" .. n .. "Tip", V(0, 0, -1.4), 3, 1.6, V(0.35, 0.5, 0.5), false, RGB(230, 220, 200))
	end
	add(r, "Tail1", "Body", V(1.6, 1.4, 2), V(0, -0.6, 1.8), V(0, 0, -0.9), rock, { Role = "tail" })
	add(r, "Tail2", "Tail1", V(1.2, 1.1, 1.8), V(0, -0.2, 0.9), V(0, 0, -0.8), dark, { Role = "tail" })
	add(r, "TailTip", "Tail2", V(0.9, 0.9, 1.4), V(0, -0.1, 0.8), V(0, 0, -0.6), magma, { Material = M.Neon })
	return r
end

-- (f) Smoldlet: ember blob — a round coal body with a lighter ember belly,
-- glowing cracks, a cheeky face (brows + grin), stubby arms and toed feet,
-- and a three-tongue flame tuft on its head
BUILD.Smoldlet = function(s)
	local r = rig("Smoldlet", s, 1.2)
	local coal, ember, belly = RGB(38, 32, 32), RGB(255, 140, 40), RGB(110, 60, 40)
	add(r, "Body", "HumanoidRootPart", V(4.2, 3.6, 4), V(0, 0.9, 0), V(0, 0, 0), coal, { Role = "body", Shape = "Ball" })
	add(r, "Belly", "Body", V(2.6, 2.4, 1), V(0, -0.5, -1.55), V(0, 0, 0), belly, { Shape = "Ball" })
	for i, spec in { { V(-1.3, 0.5, -1.4), 25 }, { V(1.4, 0.2, -1.3), -30 }, { V(0.3, 1.4, -1), 70 }, { V(-1.6, -0.6, 1), -15 } } do
		add(r, "Crack" .. i, "Body", V(0.2, 1.4, 0.2), spec[1], V(0, 0, 0), ember, { Material = M.Neon, Rot = A(0, 0, rad(spec[2])) })
	end
	add(r, "Head", "Body", V(1.2, 0.35, 0.2), V(0, -0.25, -1.95), V(0, 0, 0), ember, { Role = "head", Material = M.Neon, Glow = ember })
	face(r, "Body", V(0, 0.6, -1.9), 0.75, V(0.6, 0.7, 0.3), RGB(20, 18, 18), 20)
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "Arm" .. n, "Body", V(0.9, 1.4, 0.9), V(side * 2, 0, -0.3), V(0, 0.6, 0), coal, { Role = side < 0 and "armL" or "armR", Shape = "Ball" })
		add(r, "Foot" .. n, "Body", V(1.3, 0.9, 1.6), V(side * 1.1, -1.6, -0.1), V(0, 0.45, 0), coal, { Role = side < 0 and "legA" or "legB" })
		for k = -1, 1 do
			add(r, "Toe" .. n .. (k + 2), "Foot" .. n, V(0.35, 0.35, 0.35), V(k * 0.4, -0.25, -0.8), V(0, 0, 0), ember, { Shape = "Ball", Material = M.Neon })
		end
	end
	local flame = add(r, "Flame", "Body", V(1.2, 1.6, 1.2), V(0, 1.9, 0), V(0, -0.6, 0), ember, { Material = M.Neon, Role = "tail", Class = "WedgePart" })
	add(r, "FlameL", "Body", V(0.8, 1.1, 0.8), V(-0.6, 1.8, 0.2), V(0, -0.4, 0), RGB(255, 200, 70), { Material = M.Neon, Class = "WedgePart", Rot = A(0, 0, rad(20)) })
	add(r, "FlameR", "Body", V(0.8, 1.2, 0.8), V(0.6, 1.8, -0.2), V(0, -0.4, 0), RGB(255, 90, 30), { Material = M.Neon, Class = "WedgePart", Rot = A(0, math.pi, rad(-20)) })
	local fire = Instance.new("Fire")
	fire.Size = 3 * s
	fire.Heat = 5
	fire.Parent = flame
	return r
end

-- v2.4 MUSHROOM KIT (director: mushrooms must read as mushrooms): a cap is
-- an upright-cylinder brim + two smaller dome layers, darker gills under the
-- brim, white spots stuck ON the cap. In a turned cylinder's own space X
-- points up, so children of the brim use (up, y, z) offsets.
local UPRIGHT = A(0, 0, rad(90))
local GILL, SPOT = RGB(225, 200, 180), RGB(255, 252, 245)
local function capKit(r, name: string, parent: string, at: Vector3, radius: number, thick: number, color: Color3, role: string?)
	add(r, name, parent, V(thick, radius * 2, radius * 2), at, V(-thick / 2, 0, 0), color, { Shape = "Cylinder", Rot = UPRIGHT, Role = role or "deco" })
	local light = color:Lerp(RGB(255, 255, 255), 0.08)
	add(r, name .. "Dome", name, V(thick * 0.85, radius * 1.44, radius * 1.44), V(thick / 2, 0, 0), V(-thick * 0.42, 0, 0), light, { Shape = "Cylinder" })
	add(r, name .. "DomeTop", name .. "Dome", V(thick * 0.7, radius * 0.86, radius * 0.86), V(thick * 0.42, 0, 0), V(-thick * 0.35, 0, 0), light, { Shape = "Cylinder" })
	add(r, name .. "Gills", name, V(thick * 0.45, radius * 1.7, radius * 1.7), V(-thick / 2, 0, 0), V(thick * 0.22, 0, 0), GILL, { Shape = "Cylinder" })
	for k = 1, 5 do
		local ang = k / 5 * math.pi * 2
		add(r, name .. "Spot" .. k, name, V(0.2, radius * 0.26, radius * 0.26), V(thick / 2 + 0.05, math.cos(ang) * radius * 0.82, math.sin(ang) * radius * 0.82), V(0, 0, 0), SPOT, { Shape = "Cylinder" })
	end
	add(r, name .. "SpotTop", name .. "Dome", V(0.2, radius * 0.3, radius * 0.3), V(thick * 0.43, radius * 0.25, radius * 0.25), V(0, 0, 0), SPOT, { Shape = "Cylinder" })
end
-- a small whole mushroom (stem + cap) sprouting from a part
local function sprout(r, name: string, parent: string, at: Vector3, stemH: number, capR: number, color: Color3)
	add(r, name .. "Stem", parent, V(stemH, capR * 0.6, capR * 0.6), at, V(-stemH / 2, 0, 0), RGB(240, 230, 210), { Shape = "Cylinder", Rot = UPRIGHT })
	add(r, name .. "Cap", name .. "Stem", V(0.6, capR * 2, capR * 2), V(stemH / 2, 0, 0), V(-0.3, 0, 0), color, { Shape = "Cylinder" })
	add(r, name .. "CapDome", name .. "Cap", V(0.5, capR * 1.3, capR * 1.3), V(0.3, 0, 0), V(-0.25, 0, 0), color:Lerp(RGB(255, 255, 255), 0.08), { Shape = "Cylinder" })
	add(r, name .. "Dot", name .. "CapDome", V(0.12, capR * 0.4, capR * 0.4), V(0.26, capR * 0.2, 0), V(0, 0, 0), SPOT, { Shape = "Cylinder" })
end

-- (g) Capstride: toadstool strider — a round cream stalk body with a white
-- ring, its face (brows, eyes, smile) under a wide red domed cap with gills
-- and spots, jointed arms with mitten hands, legs with feet and little root
-- toes, a small mushroom sprouting from each shoulder
BUILD.Capstride = function(s)
	local r = rig("Capstride", s, 2.4)
	local stem, cap, shade = RGB(240, 228, 205), RGB(215, 50, 50), RGB(215, 200, 175)
	add(r, "Body", "HumanoidRootPart", V(2.4, 5, 2.4), V(0, 2.4, 0), V(0, 0, 0), stem, { Role = "body", Transparency = 1 })
	add(r, "Stalk", "Body", V(5.2, 3, 3), V(0, 0, 0), V(0, 0, 0), stem, { Shape = "Cylinder", Rot = UPRIGHT })
	add(r, "StalkBase", "Body", V(1.2, 3.6, 3.6), V(0, -2.2, 0), V(0, 0, 0), shade, { Shape = "Cylinder", Rot = UPRIGHT })
	add(r, "StalkRing", "Body", V(0.5, 3.8, 3.8), V(0, 0.4, 0), V(0, 0, 0), SPOT, { Shape = "Cylinder", Rot = UPRIGHT })
	capKit(r, "Head", "Body", V(0, 2.6, 0), 3.8, 1.5, cap, "head")
	face(r, "Body", V(0, 1.45, -1.5), 0.6, V(0.55, 0.65, 0.2), RGB(120, 70, 50), 12)
	add(r, "Mouth", "Body", V(0.9, 0.2, 0.15), V(0, 0.65, -1.52), V(0, 0, 0), RGB(120, 60, 50), {})
	add(r, "Blush", "Body", V(2.6, 0.25, 0.1), V(0, 0.95, -1.5), V(0, 0, 0), RGB(255, 170, 160), {})
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		limb(r, "Arm" .. n, "Body", V(side * 1.6, 0.9, 0), V(0.8, 1.4, 0.8), V(0.7, 1.2, 0.7), V(1, 0.9, 1), stem, shade, side < 0 and "armL" or "armR")
		limb(r, "Leg" .. n, "Body", V(side * 0.8, -2.5, 0), V(1, 1.1, 1.1), V(0.9, 0.9, 1), V(1.2, 0.5, 1.6), stem, shade, side < 0 and "legA" or "legB")
		for k = -1, 1, 2 do
			add(r, "Root" .. n .. k, "Leg" .. n .. "Tip", V(0.3, 0.3, 0.9), V(k * 0.4, -0.1, -0.9), V(0, 0, 0), RGB(170, 140, 110), { Rot = A(0, rad(k * 20), 0) })
		end
	end
	sprout(r, "ShoulderShroomL", "Body", V(-1.1, 1.9, 0.6), 1.2, 0.9, RGB(240, 140, 60))
	sprout(r, "ShoulderShroomR", "Body", V(1.1, 1.6, 0.5), 1, 0.75, RGB(240, 140, 60))
	return r
end

-- (h) Sporeback: fungal brute — hunched purple-grey body with a paler chest,
-- a big pink domed cap on a stalk, a grove of three small mushrooms on its
-- back, a low head with brows and a jaw of stubby teeth, jointed legs with
-- claws and a root-like tail
BUILD.Sporeback = function(s)
	local r = rig("Sporeback", s, 2.6)
	local hide, chest, cap = RGB(115, 95, 125), RGB(170, 150, 175), RGB(240, 130, 190)
	add(r, "Body", "HumanoidRootPart", V(5, 3.6, 6.4), V(0, 0.8, 0), V(0, 0, 0), hide, { Role = "body" })
	add(r, "Chest", "Body", V(4.2, 2.4, 2.4), V(0, -0.7, -2.4), V(0, 0, 0), chest, {})
	add(r, "Hump", "Body", V(4.4, 1.4, 3.6), V(0, 2, -0.6), V(0, 0, 0), hide:Lerp(RGB(0, 0, 0), 0.1), {})
	add(r, "CapStem", "Body", V(1.6, 2.2, 2.2), V(0, 1.8, 0.6), V(-0.8, 0, 0), RGB(235, 220, 230), { Shape = "Cylinder", Rot = UPRIGHT })
	capKit(r, "Cap", "Body", V(0, 3.4, 0.6), 3.3, 1.2, cap)
	add(r, "Head", "Body", V(2.6, 2.2, 2.6), V(0, -0.4, -3.6), V(0, 0, 1.1), hide, { Role = "head" })
	add(r, "Jaw", "Head", V(2.2, 0.7, 2), V(0, -1.1, -0.2), V(0, 0, 0.9), RGB(70, 55, 80), { Role = "jawBot" })
	teeth(r, "Tooth", "Jaw", V(0, 0.5, -0.8), 4, 1.7, V(0.3, 0.45, 0.3), false)
	face(r, "Head", V(0, 0.45, -1.32), 0.7, V(0.5, 0.5, 0.2), RGB(80, 60, 90), 16)
	add(r, "CheekSpores", "Head", V(2.7, 0.4, 0.4), V(0, -0.2, -1.1), V(0, 0, 0), RGB(255, 190, 230), {})
	for _, spec in { { "LegFL", -2, -2.4, "legA" }, { "LegFR", 2, -2.4, "legB" }, { "LegBL", -2, 2.4, "legB" }, { "LegBR", 2, 2.4, "legA" } } do
		limb(r, spec[1], "Body", V(spec[2], -1.2, spec[3]), V(1.5, 1.6, 1.5), V(1.2, 1.4, 1.2), V(1.4, 0.4, 1.8), hide, RGB(220, 210, 225), spec[4])
	end
	sprout(r, "BackShroomA", "Body", V(-1.5, 1.8, -1.9), 1.4, 1, RGB(250, 160, 205))
	sprout(r, "BackShroomB", "Body", V(1.6, 1.8, 2.4), 1.1, 0.8, RGB(250, 160, 205))
	sprout(r, "BackShroomC", "Body", V(-1.3, 1.8, 2.7), 0.9, 0.65, RGB(200, 150, 230))
	add(r, "Tail", "Body", V(0.8, 0.8, 2.4), V(0, 0, 3.2), V(0, 0, -1), RGB(150, 120, 100), { Role = "tail" })
	add(r, "TailRoot", "Tail", V(0.5, 0.5, 1.4), V(0.3, -0.3, 1.2), V(0, 0, -0.5), RGB(150, 120, 100), { Rot = A(rad(25), rad(20), 0) })
	return r
end

-- (i) Rubbleye: watching rubble — a cracked boulder core wrapped in layered
-- rock plates, one huge eye (white, purple iris, pupil) under heavy brow
-- rocks with lid plates, glowing purple veins, six orbiting boulders of
-- different sizes and a few pebbles
BUILD.Rubbleye = function(s)
	local r = rig("Rubbleye", s, 6)
	local rock, dark, eye = RGB(92, 86, 98), RGB(62, 58, 68), RGB(190, 80, 255)
	add(r, "Body", "HumanoidRootPart", V(4.2, 4.2, 4.2), V(0, 1.5, 0), V(0, 0, 0), rock, { Role = "body", Shape = "Ball" })
	for i, spec in { { V(0, 1.7, 0.4), V(3, 1, 3) }, { V(-1.7, 0.2, 0.6), V(1, 2.6, 2.6) }, { V(1.7, -0.2, 0.5), V(1, 2.4, 2.4) }, { V(0, -1.8, 0.3), V(2.8, 1, 2.6) } } do
		add(r, "Plate" .. i, "Body", spec[2], spec[1], V(0, 0, 0), dark, {})
	end
	add(r, "Head", "Body", V(2.4, 2.4, 0.8), V(0, 0.2, -1.95), V(0, 0, 0), RGB(250, 250, 255), { Role = "head", Shape = "Ball" })
	add(r, "Iris", "Head", V(1.3, 1.3, 0.3), V(0, 0, -0.3), V(0, 0, 0), eye, { Shape = "Ball", Material = M.Neon, Glow = eye })
	add(r, "Pupil", "Iris", V(0.6, 0.6, 0.2), V(0, 0, -0.12), V(0, 0, 0), RGB(20, 0, 30), { Shape = "Ball" })
	add(r, "BrowRock", "Body", V(3, 0.9, 1.2), V(0, 1.6, -1.8), V(0, 0, 0), dark, { Rot = A(rad(-10), 0, 0) })
	add(r, "LidLow", "Body", V(2.6, 0.6, 1), V(0, -1.1, -1.9), V(0, 0, 0), dark, {})
	for i, spec in { { V(-1.2, 0.8, -1.7), 30 }, { V(1.3, -0.5, -1.6), -40 }, { V(0.4, -1.4, 1.8), 70 } } do
		add(r, "Vein" .. i, "Body", V(0.2, 1.3, 0.2), spec[1], V(0, 0, 0), eye, { Material = M.Neon, Rot = A(0, 0, rad(spec[2])) })
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local size = 1.3 + (i % 3) * 0.55
		add(r, "Boulder" .. i, "Body", V(size, size * 0.85, size), V(math.cos(a) * 4, (i % 2) * 1.2 - 0.6, math.sin(a) * 4), V(0, 0, 0), rock:Lerp(dark, (i % 3) / 3), {
			Role = "orbit", Shape = (i % 2 == 0) and "Ball" or nil,
		})
	end
	for i = 1, 3 do
		local a = i * 2.2 + 0.5
		add(r, "Pebble" .. i, "Body", V(0.6, 0.6, 0.6), V(math.cos(a) * 5.4, -1.4, math.sin(a) * 5.4), V(0, 0, 0), dark, { Role = "orbit", Shape = "Ball" })
	end
	return r
end

-- (j) Bristlehulk: bramble brute — a gorilla-shaped leafy body with a pale
-- moss chest, heavy shoulders, a small head under a brow ridge with tusks
-- and a layered leaf crown, long knuckle-walking arms with big fists, short
-- legs with feet, and rows of bristle leaves down its back
BUILD.Bristlehulk = function(s)
	local r = rig("Bristlehulk", s, 2.6)
	local leaf, dark, moss = RGB(80, 150, 70), RGB(50, 100, 45), RGB(170, 205, 120)
	add(r, "Body", "HumanoidRootPart", V(5, 4.2, 3.4), V(0, 2, 0), V(0, 0, 0), leaf, { Role = "body" })
	add(r, "Chest", "Body", V(3.6, 2.6, 0.8), V(0, 0.3, -1.85), V(0, 0, 0), moss, {})
	add(r, "Shoulders", "Body", V(6.2, 1.6, 3.6), V(0, 2, 0), V(0, 0, 0), dark, {})
	add(r, "Head", "Shoulders", V(2.4, 2, 2.2), V(0, 0.6, -0.9), V(0, -1, 0), dark, { Role = "head" })
	add(r, "Brow", "Head", V(2.6, 0.5, 0.8), V(0, 0.55, -1), V(0, 0, 0), RGB(40, 80, 35), {})
	add(r, "Muzzle", "Head", V(1.6, 0.9, 0.6), V(0, -0.5, -1.2), V(0, 0, 0), moss, {})
	face(r, "Head", V(0, 0.15, -1.12), 0.55, V(0.4, 0.45, 0.2), RGB(40, 80, 35), 18)
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "Tusk" .. n, "Muzzle", V(0.3, 0.7, 0.3), V(side * 0.6, 0.4, -0.2), V(0, 0, 0), RGB(250, 245, 225), { Class = "WedgePart", Rot = A(0, math.pi, 0) })
		limb(r, "Arm" .. n, "Shoulders", V(side * 3.4, 0, 0), V(1.7, 2.8, 1.7), V(1.5, 2.6, 1.5), V(2.2, 1.6, 2.2), leaf, dark, side < 0 and "armL" or "armR")
		limb(r, "Leg" .. n, "Body", V(side * 1.3, -2.1, 0), V(1.6, 1.5, 1.6), V(1.4, 1.2, 1.4), V(1.7, 0.5, 2.2), dark, dark, side < 0 and "legA" or "legB")
	end
	for i = 1, 4 do
		add(r, "Crown" .. i, "Head", V(0.5, 1.4, 1.2), V(-0.9 + (i - 1) * 0.6, 1.2, 0.2), V(0, -0.7, 0), RGB(130, 210, 100), { Class = "WedgePart", Rot = A(rad(-15), 0, rad((i - 2.5) * 12)) })
	end
	for row = 0, 2 do
		for k = -1, 1 do
			add(r, "Bristle" .. row .. "_" .. (k + 2), "Body", V(0.5, 1.8, 1.1), V(k * 1.3, 1.6 - row * 1.1, 1.75 + row * 0.05), V(0, -0.9, 0),
				RGB(110, 190, 90):Lerp(dark, row / 4), { Class = "WedgePart", Rot = A(rad(-35), 0, rad(k * 12)) })
		end
	end
	return r
end

-- (k) Gulpvine: storm snapper — roots spread into the ground, a bulb base,
-- a two-segment stalk, a snapping maw with lips, lightning teeth, glowing
-- veins and small eyes, six layered leaves (some sparking) and tendrils
BUILD.Gulpvine = function(s)
	local r = rig("Gulpvine", s, 0.6)
	local stalk, maw, jaw = RGB(40, 50, 75), RGB(55, 70, 105), RGB(35, 42, 65)
	local volt, tooth, lip = RGB(110, 240, 255), RGB(220, 245, 255), RGB(90, 110, 150)
	add(r, "Body", "HumanoidRootPart", V(3.2, 1.4, 3.2), V(0, -0.1, 0), V(0, 0, 0), RGB(45, 60, 70), { Role = "body", Shape = "Ball" })
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		add(r, "Root" .. i, "Body", V(0.5, 0.5, 2.4), V(math.cos(a) * 1.6, -0.4, math.sin(a) * 1.6), V(0, 0, -1.1), RGB(70, 60, 55), { Rot = A(rad(15), -a + math.pi / 2, 0) })
	end
	add(r, "Stem", "Body", V(1.2, 2, 1.2), V(0, 0.6, 0), V(0, -1, 0), stalk, { Role = "tail" })
	add(r, "StemTop", "Stem", V(1, 1.4, 1), V(0, 1, 0), V(0, -0.7, 0), stalk, {})
	add(r, "StemVein", "Stem", V(0.2, 1.9, 0.2), V(0, 0, -0.62), V(0, 0, 0), volt, { Material = M.Neon })
	add(r, "Head", "StemTop", V(3.4, 1.2, 3.4), V(0, 0.8, 0), V(0, -0.6, 1.2), maw, { Role = "jawTop" })
	add(r, "Jaw", "StemTop", V(3.2, 1, 3.2), V(0, 0.6, 0), V(0, 0.5, 1.1), jaw, { Role = "jawBot" })
	add(r, "LipT", "Head", V(3.5, 0.3, 0.4), V(0, -0.5, -1.6), V(0, 0, 0), lip, {})
	add(r, "LipB", "Jaw", V(3.3, 0.3, 0.4), V(0, 0.45, -1.5), V(0, 0, 0), lip, {})
	add(r, "EyeL", "Head", V(0.5, 0.5, 0.3), V(-0.8, 0.75, -1.2), V(0, 0, 0), volt, {})
	add(r, "EyeR", "Head", V(0.5, 0.5, 0.3), V(0.8, 0.75, -1.2), V(0, 0, 0), volt, {})
	add(r, "MawVeinT", "Head", V(3, 0.15, 0.2), V(0, 0.62, -0.6), V(0, 0, 0), volt, { Material = M.Neon })
	add(r, "MawVeinB", "Jaw", V(2.8, 0.15, 0.2), V(0, -0.52, -0.6), V(0, 0, 0), volt, { Material = M.Neon, Glow = volt })
	teeth(r, "ToothT", "Head", V(0, -0.8, -1.4), 5, 2.8, V(0.35, 0.65, 0.35), true, tooth)
	teeth(r, "ToothB", "Jaw", V(0, 0.7, -1.3), 5, 2.6, V(0.35, 0.65, 0.35), false, tooth)
	for i = 1, 6 do
		local a = i * 1.05 + 0.3
		local big = i % 2 == 0
		local leaf = add(r, "Leaf" .. i, "Body", V(big and 1.6 or 1.1, 0.25, big and 3.4 or 2.4), V(math.cos(a) * 1.4, 0.4 + (big and 0 or 0.3), math.sin(a) * 1.4),
			V(0, 0, big and -1.5 or -1.1), stalk:Lerp(RGB(70, 110, 130), big and 0 or 0.3), { Rot = A(rad(big and -12 or -30), -a + math.pi / 2, 0), Role = "wing" })
		add(r, "LeafVein" .. i, "Leaf" .. i, V(0.12, 0.27, big and 2.8 or 1.9), V(0, 0, 0), V(0, 0, 0), volt, { Material = M.Neon })
		if i % 3 == 0 then
			local sparks = Instance.new("ParticleEmitter")
			sparks.Color = ColorSequence.new(volt)
			sparks.LightEmission = 1
			sparks.Size = NumberSequence.new(0.25, 0)
			sparks.Lifetime = NumberRange.new(0.15, 0.3)
			sparks.Rate = 5
			sparks.Speed = NumberRange.new(4, 8)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks.Parent = leaf
		end
	end
	for i = 1, 2 do
		add(r, "Tendril" .. i, "StemTop", V(0.25, 1.8, 0.25), V(i == 1 and -0.7 or 0.7, 0.2, 0.3), V(0, -0.9, 0), stalk, { Rot = A(rad(20), 0, rad(i == 1 and 40 or -40)) })
	end
	return r
end

-- (l) Mossgrave: mossy golem — stacked rock torso (waist, chest, shoulder
-- boulders), a blocky head under a brow slab with glowing eyes, heavy
-- jointed arms with boulder fists, thick legs with slab feet, moss caps,
-- hanging vines and a few small flowers
BUILD.Mossgrave = function(s)
	local r = rig("Mossgrave", s, 3)
	local stone, dark, moss, vine = RGB(140, 140, 136), RGB(105, 105, 102), RGB(95, 150, 75), RGB(60, 115, 50)
	add(r, "Body", "HumanoidRootPart", V(4.2, 2.6, 3), V(0, 1.2, 0), V(0, 0, 0), dark, { Role = "body" })
	add(r, "Chest", "Body", V(5.4, 3, 3.6), V(0, 2.7, -0.1), V(0, 0, 0), stone, {})
	add(r, "ChestMoss", "Chest", V(4.6, 0.6, 3.2), V(0, 1.6, 0.1), V(0, 0, 0), moss, {})
	add(r, "Head", "Chest", V(2.6, 2.2, 2.4), V(0, 1.6, -0.5), V(0, -1.1, 0), stone, { Role = "head" })
	add(r, "BrowSlab", "Head", V(3, 0.7, 1), V(0, 0.6, -0.9), V(0, 0, 0), dark, {})
	add(r, "EyeL", "Head", V(0.5, 0.35, 0.2), V(-0.6, 0.15, -1.22), V(0, 0, 0), RGB(150, 255, 150), { Material = M.Neon })
	add(r, "EyeR", "Head", V(0.5, 0.35, 0.2), V(0.6, 0.15, -1.22), V(0, 0, 0), RGB(150, 255, 150), { Material = M.Neon })
	add(r, "JawRock", "Head", V(2.2, 0.8, 2), V(0, -1.1, -0.1), V(0, 0, 0), dark, {})
	add(r, "MossTop", "Head", V(2.8, 0.6, 2.6), V(0, 1.2, 0), V(0, 0, 0), moss, {})
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "ShoulderRock" .. n, "Chest", V(2.4, 2, 2.6), V(side * 3.2, 0.9, 0), V(0, 0, 0), stone, { Shape = "Ball" })
		limb(r, "Arm" .. n, "Chest", V(side * 3.5, 0, 0), V(2, 2.6, 2), V(1.9, 2.4, 1.9), V(2.6, 2, 2.6), stone, dark, side < 0 and "armL" or "armR")
		limb(r, "Leg" .. n, "Body", V(side * 1.3, -1.3, 0), V(2.1, 2, 2.1), V(1.9, 1.8, 1.9), V(2.4, 0.7, 3), stone, dark, side < 0 and "legA" or "legB")
		add(r, "Vine" .. n, "Chest", V(0.3, 3.6, 0.3), V(side * 1.4, -0.4, -1.82), V(0, 0, 0), vine, { Rot = A(0, 0, rad(side * 12)) })
		add(r, "Flower" .. n, "ShoulderRock" .. n, V(0.6, 0.6, 0.6), V(0, 1, 0), V(0, 0, 0), side < 0 and RGB(255, 230, 90) or RGB(255, 150, 200), { Shape = "Ball" })
	end
	add(r, "MossShoulder", "ShoulderRockL", V(2.4, 0.5, 2.6), V(0, 0.8, 0), V(0, 0, 0), moss, {})
	add(r, "VineArm", "ArmRLower", V(0.3, 3, 0.3), V(0.8, 0, -0.8), V(0, 0, 0), vine, {})
	return r
end

-- (m) Gnashgut: fanged glutton — a round green body with a pale belly, a
-- huge mouth (upper lip, lower jaw, tongue, big + small fangs), eyes under
-- bushy brows, warty back bumps, short clawed arms and stubby toed feet
BUILD.Gnashgut = function(s)
	local r = rig("Gnashgut", s, 1.6)
	local skin, belly, mouth, fang = RGB(95, 170, 80), RGB(200, 225, 150), RGB(70, 25, 35), RGB(250, 245, 225)
	add(r, "Body", "HumanoidRootPart", V(6, 5, 5), V(0, 1.6, 0), V(0, 0, 0), skin, { Role = "body", Shape = "Ball" })
	add(r, "Belly", "Body", V(4.2, 3.4, 1.6), V(0, -0.8, -1.9), V(0, 0, 0), belly, { Shape = "Ball" })
	add(r, "Head", "Body", V(4.6, 1.2, 1.4), V(0, 0.7, -2.2), V(0, 0, 0), skin:Lerp(RGB(0, 0, 0), 0.1), { Role = "jawTop" })
	add(r, "MouthInside", "Body", V(3.8, 1.2, 0.6), V(0, 0, -2.25), V(0, 0, 0), mouth, {})
	add(r, "Tongue", "MouthInside", V(1.6, 0.3, 1), V(0, -0.4, -0.3), V(0, 0, 0), RGB(230, 90, 110), {})
	add(r, "Jaw", "Body", V(4.2, 1.1, 1.4), V(0, -0.6, -2.1), V(0, 0, 0), skin, { Role = "jawBot" })
	add(r, "FangL", "Head", V(0.6, 1.4, 0.6), V(-1.3, -1, -0.2), V(0, 0, 0), fang, { Class = "WedgePart", Rot = A(rad(180), 0, 0) })
	add(r, "FangR", "Head", V(0.6, 1.4, 0.6), V(1.3, -1, -0.2), V(0, 0, 0), fang, { Class = "WedgePart", Rot = A(rad(180), 0, 0) })
	teeth(r, "Tooth", "Jaw", V(0, 0.65, -0.3), 4, 2.6, V(0.35, 0.5, 0.35), false, fang)
	face(r, "Body", V(0, 2, -2), 1.25, V(0.9, 0.9, 0.4), RGB(50, 90, 40), 22)
	for i, p in { V(-1.5, 2.2, 1), V(1.2, 2.4, 0.6), V(0, 2.6, 1.6), V(-0.5, 1.6, 2.3), V(1.8, 1.2, 1.9) } do
		add(r, "Wart" .. i, "Body", V(0.8, 0.8, 0.8), p, V(0, 0, 0), skin:Lerp(RGB(0, 0, 0), 0.15), { Shape = "Ball" })
	end
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		limb(r, "Arm" .. n, "Body", V(side * 3, 0.4, -0.6), V(1.3, 1.6, 1.3), V(1.1, 1.4, 1.1), V(1.3, 0.8, 1.3), skin, skin, side < 0 and "armL" or "armR")
		teeth(r, "Claw" .. n, "Arm" .. n .. "Tip", V(0, -0.5, -0.5), 3, 1.1, V(0.25, 0.4, 0.3), true, fang)
		limb(r, "Leg" .. n, "Body", V(side * 1.6, -2.1, 0), V(1.8, 1.2, 1.8), V(1.6, 0.9, 1.6), V(2, 0.5, 2.4), RGB(75, 140, 65), belly, side < 0 and "legA" or "legB")
	end
	return r
end

-- (n) Skyfin: sky shark (style anchor) — blue upper body over a separate
-- pale belly, tapered snout with a jaw, mouth line and teeth row, brows,
-- three gill slits per side, tall dorsal fin, pectoral + pelvic fins,
-- short legs with webbed feet, tail stalk and a crescent tail
BUILD.Skyfin = function(s)
	local r = rig("Skyfin", s, 2)
	local blue, deep, pale = RGB(110, 175, 235), RGB(70, 130, 200), RGB(235, 242, 250)
	add(r, "Body", "HumanoidRootPart", V(4, 3, 6.4), V(0, 1, 0.4), V(0, 0, 0), blue, { Role = "body" })
	add(r, "Belly", "Body", V(3.6, 1.2, 6), V(0, -1.6, 0), V(0, 0, 0), pale, {})
	add(r, "BackRidge", "Body", V(2.6, 0.6, 5.4), V(0, 1.75, 0.2), V(0, 0, 0), deep, {})
	add(r, "Head", "Body", V(3.6, 2.8, 2.6), V(0, 0, -3.2), V(0, 0, 1.3), blue, { Role = "head" })
	add(r, "Snout", "Head", V(3.2, 1.8, 2.4), V(0, 0.4, -1.3), V(0, 0, 1.2), blue, { Class = "WedgePart" })
	add(r, "SnoutTip", "Snout", V(2, 0.9, 1), V(0, -0.2, -1.4), V(0, 0, 0.5), blue, { Class = "WedgePart" })
	add(r, "Jaw", "Head", V(3.2, 0.8, 2.6), V(0, -1.3, -0.2), V(0, 0.2, 1.1), pale, { Role = "jawBot" })
	add(r, "MouthLine", "Head", V(3.3, 0.18, 0.2), V(0, -0.85, -1.35), V(0, 0, 0), RGB(40, 50, 70), {})
	teeth(r, "Tooth", "Jaw", V(0, 0.55, -1.1), 5, 2.6, V(0.35, 0.5, 0.35), false)
	add(r, "DotEyeL", "Head", V(0.5, 0.55, 0.2), V(-1.82, 0.5, -0.4), V(0, 0, 0), RGB(25, 30, 45), { Rot = A(0, rad(90), 0) })
	add(r, "DotEyeR", "Head", V(0.5, 0.55, 0.2), V(1.82, 0.5, -0.4), V(0, 0, 0), RGB(25, 30, 45), { Rot = A(0, rad(-90), 0) })
	add(r, "BrowL", "Head", V(0.2, 0.25, 1), V(-1.83, 0.95, -0.35), V(0, 0, 0), deep, { Rot = A(rad(-15), 0, 0) })
	add(r, "BrowR", "Head", V(0.2, 0.25, 1), V(1.83, 0.95, -0.35), V(0, 0, 0), deep, { Rot = A(rad(-15), 0, 0) })
	for k = 1, 3 do
		for _, side in { -1, 1 } do
			add(r, "Gill" .. (side < 0 and "L" or "R") .. k, "Body", V(0.15, 1.3 - k * 0.15, 0.22), V(side * 2.02, 0.1, -2.5 + k * 0.5), V(0, 0, 0), deep, {})
		end
	end
	add(r, "Dorsal", "Body", V(0.7, 3, 2.8), V(0, 2, 0.6), V(0, -1.5, 0), deep, { Class = "WedgePart", Role = "wing", Rot = A(0, math.pi, 0) })
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "Fin" .. n, "Body", V(0.4, 1.8, 2.4), V(side * 2, -0.8, -1.4), V(0, 0.9, 0), deep, { Class = "WedgePart", Role = side < 0 and "armL" or "armR", Rot = A(0, math.pi, rad(side * 60)) })
		add(r, "PelvicFin" .. n, "Body", V(0.3, 1, 1.4), V(side * 1.7, -1.6, 2), V(0, 0.5, 0), deep, { Class = "WedgePart", Rot = A(0, math.pi, rad(side * 45)) })
	end
	for _, spec in { { "LegFL", -1.1, -1.4, "legA" }, { "LegFR", 1.1, -1.4, "legB" }, { "LegBL", -1.1, 1.8, "legB" }, { "LegBR", 1.1, 1.8, "legA" } } do
		limb(r, spec[1], "Body", V(spec[2], -2, spec[3]), V(1.1, 0.9, 1.1), V(0.9, 0.8, 0.9), V(1.3, 0.35, 1.6), pale, deep, spec[4])
	end
	add(r, "Tail", "Body", V(2.2, 2, 2.6), V(0, 0.2, 3.2), V(0, 0, -1.3), blue, { Role = "tail" })
	add(r, "TailStalk", "Tail", V(1.3, 1.3, 1.6), V(0, 0, 1.3), V(0, 0, -0.8), blue, {})
	add(r, "TailFinTop", "TailStalk", V(0.6, 3, 2), V(0, 0.7, 0.8), V(0, -1.5, -0.6), deep, { Class = "WedgePart", Rot = A(rad(-35), 0, 0) })
	add(r, "TailFinLow", "TailStalk", V(0.6, 2.2, 1.6), V(0, -0.6, 0.8), V(0, 1.1, -0.5), deep, { Class = "WedgePart", Rot = A(rad(215), 0, 0) })
	return r
end

-- ======================================================================
-- v2.6 SECOND MONSTER PER HABITAT (each a different animal type)
-- ======================================================================

-- (o) Puffhorn — Plateau: a cloud-wool ram. Dark face and legs, a body of
-- overlapping white wool puffs, big spiral horns, hooves, little tail puff
BUILD.Puffhorn = function(s)
	local r = rig("Puffhorn", s, 2.4)
	local wool, woolShade, face_, horn = RGB(248, 248, 252), RGB(220, 222, 232), RGB(70, 60, 70), RGB(215, 185, 140)
	add(r, "Body", "HumanoidRootPart", V(4, 3.2, 5.6), V(0, 0.9, 0), V(0, 0, 0), wool, { Role = "body" })
	for i, spec in { { V(-1.6, 1.4, -1.6), 2.6 }, { V(1.5, 1.5, -1.4), 2.6 }, { V(0, 1.9, 0.2), 3 }, { V(-1.5, 1.2, 1.8), 2.4 }, { V(1.6, 1.3, 1.9), 2.4 }, { V(0, 0.6, 2.8), 2.2 } } do
		add(r, "Wool" .. i, "Body", V(spec[2], spec[2], spec[2]), spec[1], V(0, 0, 0), i % 2 == 0 and woolShade or wool, { Shape = "Ball" })
	end
	add(r, "Neck", "Body", V(1.8, 1.8, 1.6), V(0, 1, -3), V(0, 0, 0.6), face_, {})
	add(r, "Head", "Neck", V(2, 2.2, 2.4), V(0, 0.6, -0.9), V(0, -0.3, 1), face_, { Role = "head" })
	add(r, "Muzzle", "Head", V(1.5, 1.1, 1), V(0, -0.5, -1.4), V(0, 0, 0), RGB(95, 85, 95), {})
	add(r, "Forelock", "Head", V(1.8, 1, 1.4), V(0, 1.2, 0), V(0, 0, 0), wool, { Shape = "Ball" })
	face(r, "Head", V(0, 0.35, -1.22), 0.6, V(0.45, 0.5, 0.2), RGB(40, 35, 40), 8)
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "HornA" .. n, "Head", V(0.9, 0.9, 1.6), V(side * 1, 0.8, 0.2), V(0, 0, -0.6), horn, { Rot = A(rad(20), rad(side * 35), 0) })
		add(r, "HornB" .. n, "HornA" .. n, V(0.75, 0.75, 1.4), V(side * 0.2, -0.3, 0.8), V(0, 0, -0.5), horn:Lerp(RGB(0, 0, 0), 0.08), { Rot = A(rad(70), rad(side * 25), 0) })
		add(r, "HornTip" .. n, "HornB" .. n, V(0.55, 0.55, 1.1), V(0, -0.2, 0.6), V(0, 0, -0.4), horn:Lerp(RGB(255, 255, 255), 0.2), { Rot = A(rad(70), 0, 0) })
		add(r, "Ear" .. n, "Head", V(1, 0.3, 0.6), V(side * 1.2, 0.3, 0.3), V(-side * 0.4, 0, 0), face_, { Rot = A(0, 0, rad(-side * 20)) })
	end
	for _, spec in { { "LegFL", -1.3, -1.8, "legA" }, { "LegFR", 1.3, -1.8, "legB" }, { "LegBL", -1.3, 2, "legB" }, { "LegBR", 1.3, 2, "legA" } } do
		limb(r, spec[1], "Body", V(spec[2], -1.4, spec[3]), V(0.9, 1.4, 0.9), V(0.7, 1.2, 0.7), V(0.9, 0.5, 1.1), face_, RGB(40, 35, 40), spec[4])
	end
	add(r, "Tail", "Body", V(1.3, 1.3, 1.3), V(0, 0.8, 3.1), V(0, 0, -0.5), wool, { Role = "tail", Shape = "Ball" })
	return r
end

-- (p) Snowpeck — Mountains: a huge snowy owl. Round white body with grey
-- chevron marks, a facial disc with big eyes and a hooked beak, ear tufts,
-- broad wings with grey flight feathers, a short tail fan and taloned feet
BUILD.Snowpeck = function(s)
	local r = rig("Snowpeck", s, 3)
	local white, grey, beak = RGB(250, 250, 255), RGB(150, 155, 170), RGB(60, 55, 50)
	add(r, "Body", "HumanoidRootPart", V(4.2, 5, 4), V(0, 1.4, 0), V(0, 0, 0), white, { Role = "body", Shape = "Ball" })
	for i = 1, 4 do
		add(r, "Chevron" .. i, "Body", V(0.8, 0.25, 0.3), V((i % 2 == 0) and 0.7 or -0.7, -0.4 + i * 0.4, -1.95), V(0, 0, 0), grey, { Rot = A(0, 0, rad((i % 2 == 0) and 20 or -20)) })
	end
	add(r, "Head", "Body", V(3.6, 3.2, 3.2), V(0, 2.6, -0.2), V(0, -1.4, 0), white, { Role = "head", Shape = "Ball" })
	add(r, "FaceDisc", "Head", V(3, 2.4, 0.4), V(0, 0, -1.45), V(0, 0, 0), RGB(235, 235, 240), {})
	face(r, "Head", V(0, 0.35, -1.7), 0.75, V(0.9, 0.9, 0.3), grey, 10)
	add(r, "Beak", "Head", V(0.7, 0.9, 0.8), V(0, -0.45, -1.85), V(0, 0, 0), beak, { Class = "WedgePart", Rot = A(rad(180), 0, 0) })
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "Tuft" .. n, "Head", V(0.6, 1.2, 0.8), V(side * 1.1, 1.5, 0), V(0, -0.6, 0), white, { Class = "WedgePart", Rot = A(0, 0, rad(-side * 20)) })
		add(r, "Wing" .. n, "Body", V(0.6, 4.4, 3.2), V(side * 2.2, 0.8, 0.4), V(0, 2, 0), white, { Role = side < 0 and "armL" or "armR" })
		for k = 1, 3 do
			add(r, "Feather" .. n .. k, "Wing" .. n, V(0.65, 1.4, 0.9), V(0, -2.2, -1 + k * 0.85), V(0, 0.7, 0), grey, { Class = "WedgePart", Rot = A(rad(180), 0, 0) })
		end
		limb(r, "Leg" .. n, "Body", V(side * 0.9, -2.2, -0.2), V(0.8, 0.8, 0.8), V(0.6, 0.7, 0.6), V(1, 0.3, 1.3), white, beak, side < 0 and "legA" or "legB")
		teeth(r, "Talon" .. n, "Leg" .. n .. "Tip", V(0, -0.15, -0.7), 3, 0.9, V(0.2, 0.3, 0.35), true, beak)
	end
	add(r, "TailFan", "Body", V(2.6, 0.4, 1.8), V(0, -1.4, 2), V(0, 0, -0.8), grey, { Role = "tail", Rot = A(rad(-25), 0, 0) })
	return r
end

-- (q) Glowmoth — Mushroom: a giant fuzzy moth. Furry thorax with a fluffy
-- collar, striped abdomen, feathery antennae, big dark eyes, and four broad
-- wings dotted with glowing spore spots
BUILD.Glowmoth = function(s)
	local r = rig("Glowmoth", s, 4)
	local fur, stripe, wing, glow = RGB(230, 215, 190), RGB(160, 120, 200), RGB(150, 110, 210), RGB(170, 255, 220)
	add(r, "Body", "HumanoidRootPart", V(2.6, 2.6, 3), V(0, 1, 0), V(0, 0, 0), fur, { Role = "body", Shape = "Ball" })
	add(r, "Collar", "Body", V(3.2, 1.6, 1.6), V(0, 0.6, -1.2), V(0, 0, 0), RGB(250, 245, 235), { Shape = "Ball" })
	for i = 1, 3 do
		add(r, "Abdomen" .. i, "Body", V(2.2 - i * 0.4, 2 - i * 0.35, 1.4), V(0, -0.3 - i * 0.2, 1.2 + i * 1.1), V(0, 0, 0), i % 2 == 0 and stripe or fur, { Shape = "Ball", Role = "tail" })
	end
	add(r, "Head", "Body", V(2, 1.8, 1.8), V(0, 0.9, -1.9), V(0, 0, 0.6), fur, { Role = "head", Shape = "Ball" })
	add(r, "EyeL", "Head", V(0.8, 0.9, 0.4), V(-0.6, 0.1, -0.8), V(0, 0, 0), RGB(30, 30, 40), {})
	add(r, "EyeR", "Head", V(0.8, 0.9, 0.4), V(0.6, 0.1, -0.8), V(0, 0, 0), RGB(30, 30, 40), {})
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "Antenna" .. n, "Head", V(0.2, 2.2, 0.2), V(side * 0.4, 0.8, -0.3), V(0, -1.1, 0), RGB(120, 90, 60), { Rot = A(rad(-30), 0, rad(-side * 25)) })
		for k = 1, 3 do
			add(r, "Plume" .. n .. k, "Antenna" .. n, V(0.9, 0.12, 0.3), V(0, 0.2 + k * 0.4, 0), V(0, 0, 0), RGB(200, 170, 130), {})
		end
		add(r, "Wing" .. n, "Body", V(5.2, 0.3, 4), V(side * 1.3, 0.8, -0.4), V(-side * 2.6, 0, 0), wing, { Role = "wing", Rot = A(0, rad(side * 10), rad(side * 10)) })
		add(r, "WingLow" .. n, "Body", V(3.6, 0.3, 2.8), V(side * 1.2, 0.5, 1.4), V(-side * 1.8, 0, 0), wing:Lerp(RGB(0, 0, 0), 0.12), { Role = "wing", Rot = A(0, rad(-side * 20), rad(side * 6)) })
		for k = 1, 3 do
			add(r, "SporeSpot" .. n .. k, "Wing" .. n, V(0.3, 0.9, 0.9), V(side * (0.6 + k * 1.1), 0.05, (k - 2) * 0.9), V(0, 0, 0), glow, { Shape = "Cylinder", Material = M.Neon, Rot = A(0, 0, rad(90)) })
		end
		for k = 1, 3 do
			add(r, "Leg" .. n .. k, "Body", V(0.25, 1.4, 0.25), V(side * 0.9, -1, -0.8 + k * 0.6), V(0, 0.7, 0), RGB(120, 90, 60), { Role = k % 2 == 0 and "legA" or "legB", Rot = A(0, 0, rad(side * 20)) })
		end
	end
	return r
end

-- (r) Croakle — Marsh: a storm frog. Wide squat body with a pale throat
-- sac, lightning-stripe back, bulging eyes on top, wide mouth, strong folded
-- back legs with webbed feet, short front arms
BUILD.Croakle = function(s)
	local r = rig("Croakle", s, 1.6)
	local skin, throat, bolt = RGB(60, 120, 120), RGB(210, 230, 200), RGB(110, 240, 255)
	add(r, "Body", "HumanoidRootPart", V(5, 2.8, 5), V(0, 0.8, 0), V(0, 0, 0), skin, { Role = "body", Shape = "Ball" })
	add(r, "Throat", "Body", V(3.2, 1.8, 1.4), V(0, -0.5, -2), V(0, 0, 0), throat, { Shape = "Ball" })
	add(r, "Head", "Body", V(4.4, 1.6, 3), V(0, 1, -1.4), V(0, -0.4, 1), skin, { Role = "jawTop" })
	add(r, "MouthLine", "Head", V(4, 0.18, 0.2), V(0, -0.5, -1.45), V(0, 0, 0), RGB(30, 50, 50), {})
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "EyeBump" .. n, "Head", V(1.3, 1.3, 1.3), V(side * 1.3, 0.8, -0.4), V(0, 0, 0), skin, { Shape = "Ball" })
		add(r, "Eye" .. n, "EyeBump" .. n, V(0.7, 0.8, 0.3), V(0, 0.1, -0.6), V(0, 0, 0), RGB(30, 30, 30), {})
		limb(r, "Leg" .. n, "Body", V(side * 2, -0.6, 1.4), V(1.4, 1.6, 2.2), V(1, 1.4, 1.8), V(1.8, 0.3, 2.2), skin, throat, side < 0 and "legA" or "legB", { Bend = 0.6 })
		limb(r, "Arm" .. n, "Body", V(side * 1.6, -0.6, -1.6), V(0.7, 1, 0.7), V(0.6, 0.8, 0.6), V(1.1, 0.25, 1.2), skin, throat, side < 0 and "armL" or "armR")
	end
	for i = 1, 3 do
		add(r, "BackBolt" .. i, "Body", V(0.3, 0.2, 1.4), V((i - 2) * 0.9, 1.35, 0.4 + (i % 2) * 0.4), V(0, 0, 0), bolt, { Material = M.Neon, Rot = A(0, rad((i - 2) * 30), 0) })
	end
	return r
end

-- (s) Geoscuttle — Canyon: a crystal scorpion-crab. Segmented shell with a
-- pale underside, six jointed legs, two big pincers, eye stalks, and a
-- curled segmented tail ending in a blue crystal stinger
BUILD.Geoscuttle = function(s)
	local r = rig("Geoscuttle", s, 1.6)
	local shell, under, blue = RGB(120, 90, 140), RGB(210, 200, 220), RGB(90, 170, 255)
	add(r, "Body", "HumanoidRootPart", V(5, 1.8, 4.4), V(0, 0.6, 0), V(0, 0, 0), shell, { Role = "body" })
	add(r, "Underside", "Body", V(4.4, 0.6, 3.8), V(0, -1.1, 0), V(0, 0, 0), under, {})
	add(r, "ShellTop", "Body", V(4, 0.8, 3.4), V(0, 1.2, 0), V(0, 0, 0), shell:Lerp(RGB(255, 255, 255), 0.08), {})
	add(r, "Head", "Body", V(3, 1.2, 1.4), V(0, 0.1, -2.6), V(0, 0, 0.6), shell, { Role = "head" })
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "EyeStalk" .. n, "Head", V(0.3, 1.2, 0.3), V(side * 0.7, 0.9, -0.2), V(0, -0.6, 0), shell, {})
		add(r, "Eye" .. n, "EyeStalk" .. n, V(0.5, 0.5, 0.5), V(0, 0.75, 0), V(0, 0, 0), RGB(30, 30, 30), { Shape = "Ball" })
		limb(r, "Claw" .. n, "Body", V(side * 2.2, 0, -2.4), V(1, 1, 2.2), V(1.2, 1, 1.6), nil, shell, nil, side < 0 and "armL" or "armR", { Bend = -0.5 })
		add(r, "PincerTop" .. n, "Claw" .. n .. "Lower", V(1.2, 0.6, 1.6), V(0, 0.2, -1.4), V(0, 0, 0.6), blue, { Class = "WedgePart", Rot = A(0, math.pi, 0) })
		add(r, "PincerLow" .. n, "Claw" .. n .. "Lower", V(1.1, 0.5, 1.3), V(0, -0.4, -1.3), V(0, 0, 0.5), under, { Class = "WedgePart", Rot = A(math.pi, 0, 0) })
		for k = 1, 3 do
			limb(r, "Leg" .. n .. k, "Body", V(side * 2.5, -0.4, -1.3 + k * 1.1), V(0.45, 1.3, 0.45), V(0.35, 1.3, 0.35), nil, shell, nil, (k % 2 == (side < 0 and 0 or 1)) and "legA" or "legB", { Bend = 0 })
		end
	end
	local last = "Body"
	for i = 1, 4 do
		local nm = "TailSeg" .. i
		add(r, nm, last, V(1.3 - i * 0.12, 1, 1.2), i == 1 and V(0, 0.4, 2.4) or V(0, 0.55, 0.5), V(0, 0, -0.5), shell:Lerp(RGB(0, 0, 0), i * 0.04), { Role = "tail", Rot = A(rad(-35), 0, 0) })
		last = nm
	end
	add(r, "Stinger", last, V(0.7, 1.6, 0.7), V(0, 0.6, 0.2), V(0, -0.8, 0), blue, { Class = "WedgePart", Material = M.Glass, Rot = A(rad(-40), 0, 0) })
	return r
end

-- (t) Scorchtail — Volcanic: a fast lava salamander. Long low body with a
-- glowing spine ridge, wide flat head with a grin and glowing eyes, four
-- splayed legs with toes, a long tapering tail ending in a flame
BUILD.Scorchtail = function(s)
	local r = rig("Scorchtail", s, 1.2)
	local skin, belly, magma = RGB(45, 35, 35), RGB(255, 160, 80), RGB(255, 120, 40)
	add(r, "Body", "HumanoidRootPart", V(2.6, 1.4, 5.4), V(0, 0.3, 0), V(0, 0, 0), skin, { Role = "body" })
	add(r, "Belly", "Body", V(2.2, 0.4, 5), V(0, -0.8, 0), V(0, 0, 0), belly, {})
	for i = 1, 5 do
		add(r, "Spine" .. i, "Body", V(0.5, 0.6, 0.7), V(0, 0.9, -2 + i * 0.85), V(0, 0, 0), magma, { Class = "WedgePart", Material = M.Neon })
	end
	add(r, "Head", "Body", V(2.4, 1.2, 2.2), V(0, 0.2, -3.4), V(0, 0, 0.8), skin, { Role = "head" })
	add(r, "Jaw", "Head", V(2.2, 0.4, 1.8), V(0, -0.7, -0.2), V(0, 0.15, 0.8), belly, { Role = "jawBot" })
	add(r, "Grin", "Head", V(1.8, 0.15, 0.2), V(0, -0.4, -1.12), V(0, 0, 0), magma, { Material = M.Neon })
	face(r, "Head", V(0, 0.45, -1.1), 0.65, V(0.45, 0.45, 0.2), RGB(25, 20, 20), 15)
	for _, spec in { { "LegFL", -1.4, -1.6, "legA" }, { "LegFR", 1.4, -1.6, "legB" }, { "LegBL", -1.4, 1.8, "legB" }, { "LegBR", 1.4, 1.8, "legA" } } do
		limb(r, spec[1], "Body", V(spec[2], -0.3, spec[3]), V(0.7, 1, 0.7), V(0.6, 0.9, 0.6), V(1.1, 0.25, 1.2), skin, magma, spec[4])
	end
	add(r, "Tail1", "Body", V(1.6, 1, 2.2), V(0, 0.1, 3.3), V(0, 0, -1), skin, { Role = "tail" })
	add(r, "Tail2", "Tail1", V(1.1, 0.8, 2), V(0, 0, 1.1), V(0, 0, -0.9), skin, { Role = "tail" })
	add(r, "Tail3", "Tail2", V(0.7, 0.6, 1.8), V(0, 0, 1), V(0, 0, -0.8), skin, { Role = "tail" })
	local tip = add(r, "TailFlame", "Tail3", V(0.8, 1.2, 0.8), V(0, 0.4, 0.9), V(0, -0.5, 0), magma, { Material = M.Neon, Class = "WedgePart" })
	local fire = Instance.new("Fire")
	fire.Size = 2.5 * s
	fire.Heat = 4
	fire.Parent = tip
	return r
end

-- (u) Octoblob — Coast: a little sea octopus. Round mantle with spots, big
-- eyes with brows, a small beak, six curling tentacles with suckers
BUILD.Octoblob = function(s)
	local r = rig("Octoblob", s, 2)
	local skin, spot, sucker = RGB(240, 120, 150), RGB(255, 170, 190), RGB(255, 225, 230)
	add(r, "Body", "HumanoidRootPart", V(4, 3, 4), V(0, 0.8, 0), V(0, 0, 0), skin, { Role = "body", Shape = "Ball" })
	add(r, "Mantle", "Body", V(3.6, 3.6, 3.6), V(0, 1.6, 0.6), V(0, 0, 0), skin, { Role = "head", Shape = "Ball" })
	for i, p in { V(-0.9, 1.2, -0.9), V(1, 0.6, -1.1), V(0.2, 1.6, 0.6), V(-1.2, 0, 0.8) } do
		add(r, "Spot" .. i, "Mantle", V(0.7, 0.7, 0.7), p, V(0, 0, 0), spot, { Shape = "Ball" })
	end
	face(r, "Body", V(0, 0.4, -1.85), 0.8, V(0.8, 0.9, 0.3), RGB(170, 70, 100), 12)
	add(r, "Beak", "Body", V(0.5, 0.5, 0.4), V(0, -0.5, -1.95), V(0, 0, 0), RGB(80, 50, 60), { Class = "WedgePart", Rot = A(rad(180), 0, 0) })
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local n = "Tentacle" .. i
		local base = V(math.cos(a) * 1.4, -1.2, math.sin(a) * 1.4)
		add(r, n, "Body", V(0.8, 1.6, 0.8), base, V(0, 0.8, 0), skin, { Role = i % 2 == 0 and "legA" or "legB", Rot = A(0, -a, rad(-25)) })
		add(r, n .. "Mid", n, V(0.6, 1.4, 0.6), V(0, -0.8, 0), V(0, 0.7, 0), skin, { Rot = A(0, 0, rad(-25)) })
		add(r, n .. "Curl", n .. "Mid", V(0.45, 1, 0.45), V(0, -0.7, 0), V(0, 0.5, 0), skin, { Rot = A(0, 0, rad(-40)) })
		add(r, n .. "Sucker", n .. "Mid", V(0.3, 0.3, 0.3), V(0.3, 0, 0), V(0, 0, 0), sucker, { Shape = "Ball" })
	end
	return r
end

-- ======================================================================
-- v2.10 BOSSES (one per biome, built big: Scale ~2.4-3 in MonsterDefs).
-- Each has a distinctive multi-part silhouette and many layered pieces;
-- the detail pass adds trims, plates and bumps on top.
-- ======================================================================

-- Mesa Colossus (Plateau): a walking tableland. Layered sandstone torso with
-- a grassy flat back carrying ruins, boulder shoulders, pillar arms with
-- slab fists, stumpy column legs, a carved stone mask face with glowing eyes
BUILD.MesaColossus = function(s)
	local r = rig("MesaColossus", s, 3.6)
	local sand, sand2, sand3, grass, ruin, glow = RGB(205, 160, 112), RGB(176, 128, 92), RGB(226, 186, 138), RGB(110, 190, 90), RGB(232, 226, 210), RGB(255, 210, 110)
	add(r, "Body", "HumanoidRootPart", V(6, 4, 4.4), V(0, 1, 0), V(0, 0, 0), sand, { Role = "body" })
	add(r, "Strata1", "Body", V(6.4, 1, 4.8), V(0, -1.6, 0), V(0, 0, 0), sand2, {})
	add(r, "Strata2", "Body", V(6.2, 1, 4.6), V(0, 0.4, 0), V(0, 0, 0), sand3, {})
	add(r, "Chest", "Body", V(6.8, 3, 5), V(0, 3.2, 0), V(0, 0, 0), sand2, {})
	add(r, "Mesa", "Chest", V(7.2, 0.8, 5.4), V(0, 1.9, 0.2), V(0, 0, 0), grass, {})
	for k = 1, 3 do
		add(r, "Ruin" .. k, "Mesa", V(0.6, 1.4 + k * 0.4, 0.6), V(-2 + k * 1.3, 0.4, 1.6), V(0, -(1.4 + k * 0.4) / 2, 0), ruin, {})
	end
	add(r, "RuinLintel", "Mesa", V(3.4, 0.5, 0.6), V(-0.7, 2.6, 1.6), V(0, 0, 0), ruin, {})
	add(r, "Bush", "Mesa", V(1.4, 1, 1.4), V(2.4, 0.7, -1.4), V(0, 0, 0), RGB(80, 160, 70), { Shape = "Ball" })
	add(r, "Head", "Chest", V(2.6, 2.4, 2.4), V(0, 1.4, -2.2), V(0, -1, 0.4), sand3, { Role = "head" })
	add(r, "Mask", "Head", V(2.4, 2, 0.4), V(0, 0, -1.3), V(0, 0, 0), ruin, {})
	add(r, "MaskBrow", "Mask", V(2.6, 0.5, 0.6), V(0, 0.75, -0.2), V(0, 0, 0), sand2, {})
	add(r, "EyeGlowL", "Mask", V(0.5, 0.35, 0.2), V(-0.55, 0.2, -0.25), V(0, 0, 0), glow, { Material = M.Neon })
	add(r, "EyeGlowR", "Mask", V(0.5, 0.35, 0.2), V(0.55, 0.2, -0.25), V(0, 0, 0), glow, { Material = M.Neon })
	add(r, "MouthSlot", "Mask", V(1.2, 0.25, 0.2), V(0, -0.55, -0.25), V(0, 0, 0), RGB(60, 40, 30), {})
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "Shoulder" .. n, "Chest", V(2.6, 2.4, 2.6), V(side * 4.2, 0.8, 0), V(0, 0, 0), sand3, { Shape = "Ball" })
		add(r, "ShoulderRock" .. n, "Shoulder" .. n, V(1.4, 1.2, 1.4), V(side * 0.4, 1.2, 0.3), V(0, 0, 0), sand2, { Rot = A(rad(15), rad(30), rad(side * 20)) })
		limb(r, "Arm" .. n, "Shoulder" .. n, V(side * 0.3, -0.6, 0), V(1.8, 3.4, 1.8), V(1.6, 3, 1.6), V(2.6, 2, 2.6), sand, sand2, side < 0 and "armL" or "armR")
		for k = 1, 3 do
			add(r, "Knuckle" .. n .. k, "Arm" .. n .. "Tip", V(0.7, 0.7, 0.7), V(-1 + k * 0.5, -0.9, -1), V(0, 0, 0), sand3, {})
		end
		limb(r, "Leg" .. n, "Body", V(side * 1.8, -2, 0), V(2.2, 2.4, 2.2), V(2, 1.8, 2), V(2.8, 0.9, 3.2), sand2, sand, side < 0 and "legA" or "legB")
	end
	return r
end

-- Frostpeak Warden (Mountains): an armoured yeti knight. Shaggy white fur
-- body under ice-blue armour plates, horned helm with a glowing visor, an
-- icicle crest, a huge glacier shield arm and an ice-blade arm, fur boots
BUILD.FrostpeakWarden = function(s)
	local r = rig("FrostpeakWarden", s, 3.4)
	local fur, fur2, armor, armor2, ice, glow = RGB(245, 248, 255), RGB(215, 222, 235), RGB(120, 170, 230), RGB(80, 120, 190), RGB(190, 235, 255), RGB(150, 230, 255)
	add(r, "Body", "HumanoidRootPart", V(4.8, 4, 3.6), V(0, 1, 0), V(0, 0, 0), fur, { Role = "body" })
	add(r, "Belt", "Body", V(5, 0.8, 3.8), V(0, -1.2, 0), V(0, 0, 0), armor2, {})
	add(r, "Chest", "Body", V(5.6, 3.2, 4), V(0, 3.2, 0), V(0, 0, 0), fur2, {})
	add(r, "Breastplate", "Chest", V(4.4, 2.6, 0.6), V(0, 0.1, -2.1), V(0, 0, 0), armor, {})
	add(r, "Rune", "Breastplate", V(1, 1, 0.2), V(0, 0, -0.35), V(0, 0, 0), glow, { Material = M.Neon })
	for k = 1, 4 do
		add(r, "FurTuft" .. k, "Chest", V(1.2, 1, 1.2), V(-2.2 + k * 0.9, 1.6, 1.4), V(0, 0, 0), fur, { Shape = "Ball" })
	end
	add(r, "Head", "Chest", V(2.6, 2.6, 2.6), V(0, 1.6, -0.4), V(0, -1.1, 0), fur, { Role = "head" })
	add(r, "Helm", "Head", V(2.9, 1.6, 2.9), V(0, 0.8, 0), V(0, 0, 0), armor, {})
	add(r, "Visor", "Head", V(2.2, 0.4, 0.3), V(0, 0.1, -1.4), V(0, 0, 0), glow, { Material = M.Neon })
	add(r, "Snout", "Head", V(1.4, 0.9, 0.8), V(0, -0.6, -1.4), V(0, 0, 0), fur2, {})
	teeth(r, "Fang", "Snout", V(0, -0.5, -0.3), 2, 1, V(0.25, 0.5, 0.25), true)
	for k = 1, 3 do
		add(r, "Crest" .. k, "Helm", V(0.4, 1 + k * 0.4, 0.8), V(0, 0.9, -0.8 + k * 0.6), V(0, -(1 + k * 0.4) / 2, 0), ice, { Material = M.Glass, Transparency = 0.1 })
	end
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "Horn" .. n, "Helm", V(0.6, 0.6, 2), V(side * 1.5, 0.3, 0), V(0, 0, 0.8), armor2, { Rot = A(rad(-30), rad(side * 60), 0) })
		add(r, "Pauldron" .. n, "Chest", V(2.6, 1.4, 3), V(side * 3.4, 1.4, 0), V(0, 0, 0), armor, { Rot = A(0, 0, rad(side * -15)) })
		add(r, "PauldronSpike" .. n, "Pauldron" .. n, V(0.6, 1.4, 0.6), V(side * 0.6, 1, 0), V(0, -0.6, 0), ice, { Material = M.Glass, Rot = A(0, 0, rad(side * -20)) })
		limb(r, "Arm" .. n, "Chest", V(side * 3.4, 0.4, 0), V(1.6, 3, 1.6), V(1.5, 2.8, 1.5), V(1.8, 1.4, 1.8), fur2, armor2, side < 0 and "armL" or "armR")
		limb(r, "Leg" .. n, "Body", V(side * 1.4, -1.6, 0), V(1.8, 2.4, 1.8), V(1.7, 2, 1.7), V(2.2, 0.9, 2.8), fur, armor2, side < 0 and "legA" or "legB")
	end
	add(r, "Shield", "ArmLTip", V(0.6, 5, 3.6), V(-0.8, 0, 0), V(0, 0, 0), ice, { Material = M.Glass, Transparency = 0.15 })
	add(r, "ShieldBoss", "Shield", V(0.4, 1.4, 1.4), V(-0.4, 0, 0), V(0, 0, 0), armor, {})
	add(r, "Blade", "ArmRTip", V(0.5, 1, 6), V(0, -0.2, -3), V(0, 0, 0), ice, { Material = M.Glass, Glow = glow })
	add(r, "Hilt", "ArmRTip", V(0.8, 0.8, 1.2), V(0, -0.2, -0.4), V(0, 0, 0), armor2, {})
	return r
end

-- Mycelium Monarch (Mushroom): a towering mushroom king. A thick gilled
-- stalk body with a frilled ring, a huge spotted crown cap with smaller caps
-- on top, a bearded fungal face, root-tendril arms ending in spore bulbs,
-- a robe of hanging mycelium strands and root feet
BUILD.MyceliumMonarch = function(s)
	local r = rig("MyceliumMonarch", s, 3.2)
	local stalk, stalk2, cap, cap2, spot, glow = RGB(240, 228, 205), RGB(210, 196, 170), RGB(170, 70, 190), RGB(220, 100, 170), RGB(255, 250, 235), RGB(190, 255, 210)
	add(r, "Body", "HumanoidRootPart", V(3.6, 5, 3.6), V(0, 1.4, 0), V(0, 0, 0), stalk, { Role = "body" })
	add(r, "Ring", "Body", V(0.6, 5.2, 5.2), V(0, 1.2, 0), V(0, 0, 0), stalk2, { Shape = "Cylinder", Rot = A(0, 0, rad(90)) })
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		add(r, "Strand" .. k, "Body", V(0.4, 2.4, 0.4), V(math.cos(a) * 2.2, 0, math.sin(a) * 2.2), V(0, 0, 0), stalk2, {})
	end
	add(r, "Head", "Body", V(3, 3, 3), V(0, 3.2, 0), V(0, 0, 0), stalk, { Role = "head" })
	add(r, "Gills", "Head", V(6.6, 0.5, 6.6), V(0, 1.4, 0), V(0, 0, 0), stalk2, { Shape = "Cylinder", Rot = A(0, 0, rad(90)) })
	add(r, "Crown", "Head", V(1.6, 8, 8), V(0, 2.2, 0), V(0, 0, 0), cap, { Shape = "Cylinder", Rot = A(0, 0, rad(90)) })
	add(r, "CrownDome", "Crown", V(1.4, 5.6, 5.6), V(1.2, 0, 0), V(0, 0, 0), cap2, { Shape = "Cylinder" })
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		add(r, "Spot" .. k, "Crown", V(0.3, 1, 1), V(0.85, math.cos(a) * 3, math.sin(a) * 3), V(0, 0, 0), spot, { Shape = "Cylinder" })
	end
	for k = 1, 3 do
		local a = k * 2.1
		add(r, "MiniStem" .. k, "CrownDome", V(1.4, 0.6, 0.6), V(1.2, math.cos(a) * 1.4, math.sin(a) * 1.4), V(-0.7, 0, 0), stalk, { Shape = "Cylinder" })
		add(r, "MiniCap" .. k, "MiniStem" .. k, V(0.6, 2, 2), V(0.8, 0, 0), V(0, 0, 0), k == 2 and glow or cap2, { Shape = "Cylinder", Material = k == 2 and M.Neon or nil })
	end
	face(r, "Head", V(0, 0.2, -1.5), 0.7, V(0.7, 0.8, 0.3), stalk2, -10)
	add(r, "Beard", "Head", V(2.2, 1.6, 0.8), V(0, -1.3, -1.2), V(0, 0, 0), stalk2, { Class = "WedgePart", Rot = A(rad(180), 0, 0) })
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		limb(r, "Arm" .. n, "Body", V(side * 2.2, 0.8, 0), V(1, 3.4, 1), V(0.8, 3, 0.8), V(1.8, 1.8, 1.8), stalk2, glow, side < 0 and "armL" or "armR")
		for k = 1, 3 do
			add(r, "Root" .. n .. k, "Body", V(0.8, 2.6, 0.8), V(side * 1.6, -2.4, (k - 2) * 1.2), V(0, 1.2, 0), stalk2, { Rot = A(rad((k - 2) * 25), 0, rad(side * 35)) })
		end
		limb(r, "Leg" .. n, "Body", V(side * 0.9, -2.4, 0), V(1.4, 1.6, 1.4), V(1.2, 1.2, 1.2), V(2.2, 0.6, 2.6), stalk2, stalk2, side < 0 and "legA" or "legB")
	end
	return r
end

-- Bogstorm Croaker (Marsh): a colossal storm toad. Warty swamp-green body,
-- a huge throat sac that glows with lightning, crown of storm-cloud lumps
-- with a lightning rod, mossy back, thick folded hind legs, webbed hands
BUILD.BogstormCroaker = function(s)
	local r = rig("BogstormCroaker", s, 2.4)
	local skin, skin2, belly, moss, sac, glow = RGB(80, 120, 70), RGB(55, 90, 55), RGB(200, 210, 150), RGB(70, 150, 80), RGB(150, 220, 255), RGB(220, 245, 255)
	add(r, "Body", "HumanoidRootPart", V(7, 4, 6.4), V(0, 0.8, 0), V(0, 0, 0), skin, { Role = "body", Shape = "Ball" })
	add(r, "Belly", "Body", V(5.4, 2.6, 4.6), V(0, -0.8, -0.8), V(0, 0, 0), belly, { Shape = "Ball" })
	for k = 1, 6 do
		local a = k * 1.05
		add(r, "Wart" .. k, "Body", V(0.8, 0.8, 0.8), V(math.cos(a) * 2.6, 1.6, math.sin(a) * 2.2 + 0.6), V(0, 0, 0), skin2, { Shape = "Ball" })
	end
	add(r, "Moss", "Body", V(4.4, 0.8, 3.6), V(0, 1.9, 1), V(0, 0, 0), moss, {})
	add(r, "Head", "Body", V(5.2, 2.4, 3.6), V(0, 1.4, -2.6), V(0, -0.4, 0.8), skin, { Role = "head" })
	add(r, "Sac", "Head", V(3.6, 2.4, 2.4), V(0, -1.6, -0.6), V(0, 0, 0), sac, { Shape = "Ball", Material = M.Glass, Transparency = 0.2, Glow = glow })
	add(r, "SacBolt", "Sac", V(0.3, 1.6, 0.3), V(0, 0, 0), V(0, 0, 0), glow, { Material = M.Neon, Rot = A(0, 0, rad(25)) })
	add(r, "Lip", "Head", V(5, 0.4, 1), V(0, -0.5, -1.7), V(0, 0, 0), skin2, {})
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "EyeBump" .. n, "Head", V(1.6, 1.6, 1.6), V(side * 1.7, 1.2, -0.6), V(0, 0, 0), skin, { Shape = "Ball" })
	end
	face(r, "Head", V(0, 1.3, -1.25), 1.7, V(0.8, 0.8, 0.4), skin2, 12)
	for k = 1, 4 do
		local a = k * 1.6
		add(r, "Storm" .. k, "Head", V(1.6, 1.2, 1.6), V(math.cos(a) * 1, 1.6, math.sin(a) * 0.8 + 0.4), V(0, 0, 0), RGB(90, 95, 120), { Shape = "Ball" })
	end
	add(r, "Rod", "Head", V(0.3, 2.6, 0.3), V(0, 2.4, 0.4), V(0, -1.2, 0), RGB(200, 200, 210), {})
	add(r, "RodSpark", "Rod", V(0.7, 0.7, 0.7), V(0, 1.4, 0), V(0, 0, 0), glow, { Material = M.Neon, Shape = "Ball" })
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		limb(r, "Arm" .. n, "Body", V(side * 2.6, -0.8, -2), V(1.2, 2.2, 1.2), V(1, 1.8, 1), V(2.2, 0.4, 2.4), skin, skin2, side < 0 and "legA" or "legB")
		add(r, "Thigh" .. n, "Body", V(2.4, 2.6, 3.6), V(side * 3, -0.6, 1.6), V(0, 0, 0), skin, { Shape = "Ball", Role = side < 0 and "legB" or "legA" })
		add(r, "Shin" .. n, "Thigh" .. n, V(1.2, 1.2, 3.2), V(side * 0.6, -1, -0.6), V(0, 0, 0), skin2, {})
		add(r, "Foot" .. n, "Shin" .. n, V(2.6, 0.4, 2.8), V(0, -0.6, -1.4), V(0, 0, 0), skin2, {})
	end
	return r
end

-- Prism Sovereign (Crystal Canyon): a floating crystal monarch. A faceted
-- core of blue prisms with a glowing heart, a crown of tall spikes, a
-- mask-like face plate, two hovering crystal hands, a ring of orbiting
-- shards and a trailing crystal tail
BUILD.PrismSovereign = function(s)
	local r = rig("PrismSovereign", s, 4)
	local blue, blue2, violet, pale, glow = RGB(80, 160, 255), RGB(60, 110, 230), RGB(150, 130, 255), RGB(220, 240, 255), RGB(170, 230, 255)
	local GL = { Material = M.Glass, Transparency = 0.1 }
	add(r, "Body", "HumanoidRootPart", V(4, 5, 4), V(0, 1.5, 0), V(0, 0, 0), blue, { Role = "body", Material = M.Glass, Transparency = 0.1 })
	add(r, "Heart", "Body", V(1.8, 1.8, 1.8), V(0, 0.4, 0), V(0, 0, 0), glow, { Material = M.Neon, Shape = "Ball", Glow = glow })
	add(r, "Facet1", "Body", V(4.4, 2, 4.4), V(0, -2.2, 0), V(0, 0, 0), blue2, GL)
	add(r, "Facet2", "Facet1", V(2.6, 1.6, 2.6), V(0, -1.6, 0), V(0, 0, 0), violet, GL)
	add(r, "Tail", "Facet2", V(1.2, 3, 1.2), V(0, -1.6, 0), V(0, 1.5, 0), blue, { Role = "tail", Material = M.Glass, Transparency = 0.1 })
	add(r, "Head", "Body", V(3, 3, 3), V(0, 3.6, 0), V(0, 0, 0), pale, { Role = "head", Material = M.Glass, Transparency = 0.05 })
	add(r, "FacePlate", "Head", V(2.4, 2, 0.4), V(0, 0, -1.6), V(0, 0, 0), RGB(240, 248, 255), {})
	add(r, "EyeGlowL", "FacePlate", V(0.6, 0.3, 0.2), V(-0.5, 0.25, -0.25), V(0, 0, 0), RGB(80, 220, 255), { Material = M.Neon })
	add(r, "EyeGlowR", "FacePlate", V(0.6, 0.3, 0.2), V(0.5, 0.25, -0.25), V(0, 0, 0), RGB(80, 220, 255), { Material = M.Neon })
	for k = 1, 5 do
		local a = (k - 3) * 0.45
		add(r, "Spike" .. k, "Head", V(0.7, 2.2 + (3 - math.abs(k - 3)) * 0.9, 0.7), V(math.sin(a) * 1.3, 1.6, 0), V(0, -1, 0), k % 2 == 0 and violet or blue, { Material = M.Glass, Rot = A(0, rad(45), a) })
	end
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "Hand" .. n, "Body", V(1.6, 2.6, 1.6), V(side * 4.2, 0.5, -0.6), V(0, 0, 0), blue2, { Role = side < 0 and "armL" or "armR", Material = M.Glass, Transparency = 0.1 })
		for k = 1, 3 do
			add(r, "Finger" .. n .. k, "Hand" .. n, V(0.4, 1.4, 0.4), V((k - 2) * 0.5, -1.8, -0.2), V(0, 0.6, 0), pale, { Material = M.Glass })
		end
		add(r, "Pauldron" .. n, "Body", V(2, 1.4, 2), V(side * 2.4, 2, 0), V(0, 0, 0), violet, { Material = M.Glass, Rot = A(0, rad(45), rad(side * -20)) })
	end
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		add(r, "Orbit" .. k, "Body", V(0.8, 2, 0.8), V(math.cos(a) * 5.5, 0.5 + (k % 2) * 1.2, math.sin(a) * 5.5), V(0, 0, 0), k % 2 == 0 and blue or violet, { Role = "orbit", Material = M.Glass, Rot = A(0, -a, rad(20)) })
	end
	return r
end

-- Caldera Titan (Volcanic): a magma giant. Basalt plate armour over a
-- cracked glowing core, a volcano-crater head pouring lava with ember horns,
-- huge rock fists with magma knuckles, obsidian spikes down the back,
-- column legs with glowing seams
BUILD.CalderaTitan = function(s)
	local r = rig("CalderaTitan", s, 3.6)
	local rock, rock2, obs, magma, glow = RGB(70, 58, 56), RGB(48, 40, 42), RGB(30, 25, 35), RGB(255, 110, 40), RGB(255, 200, 90)
	add(r, "Body", "HumanoidRootPart", V(6, 4.4, 4.6), V(0, 1, 0), V(0, 0, 0), rock, { Role = "body" })
	add(r, "Core", "Body", V(2.6, 2.6, 0.4), V(0, 1, -2.4), V(0, 0, 0), magma, { Material = M.Neon, Glow = magma })
	for k = 1, 4 do
		add(r, "Seam" .. k, "Body", V(0.3, 3, 0.3), V(-2.4 + k * 1, 0, -2.35), V(0, 0, 0), magma, { Material = M.Neon, Rot = A(0, 0, rad((k % 2 == 0) and 15 or -15)) })
	end
	add(r, "Chest", "Body", V(7, 3, 5), V(0, 3.4, 0), V(0, 0, 0), rock2, {})
	for k = 1, 5 do
		add(r, "BackSpike" .. k, "Chest", V(0.8, 2 + (k % 3) * 0.8, 0.8), V(-2.4 + k * 0.8, 1.2, 2.2), V(0, -1, 0), obs, { Rot = A(rad(-30), 0, 0) })
	end
	add(r, "Head", "Chest", V(3.4, 2.4, 3.2), V(0, 2.2, -0.6), V(0, -1, 0), rock, { Role = "head" })
	add(r, "Crater", "Head", V(2.6, 1, 2.4), V(0, 1.4, 0), V(0, 0, 0), rock2, {})
	add(r, "CraterLava", "Crater", V(1.8, 0.2, 1.6), V(0, 0.5, 0), V(0, 0, 0), magma, { Material = M.Neon, Glow = magma })
	add(r, "LavaDrip", "Crater", V(0.4, 1.6, 0.3), V(0.6, -0.4, -1.25), V(0, 0, 0), magma, { Material = M.Neon })
	add(r, "Jaw", "Head", V(3, 0.8, 1), V(0, -1, -1.4), V(0, 0, 0), rock2, { Role = "jawBot" })
	add(r, "Mouth", "Head", V(2.2, 0.4, 0.2), V(0, -0.5, -1.65), V(0, 0, 0), magma, { Material = M.Neon })
	add(r, "EyeGlowL", "Head", V(0.7, 0.4, 0.2), V(-0.7, 0.3, -1.65), V(0, 0, 0), glow, { Material = M.Neon })
	add(r, "EyeGlowR", "Head", V(0.7, 0.4, 0.2), V(0.7, 0.3, -1.65), V(0, 0, 0), glow, { Material = M.Neon })
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "Horn" .. n, "Head", V(0.7, 2.4, 0.7), V(side * 1.6, 1.2, 0), V(0, -1, 0), obs, { Rot = A(0, 0, rad(side * -30)) })
		add(r, "HornTip" .. n, "Horn" .. n, V(0.5, 0.8, 0.5), V(0, 1.4, 0), V(0, 0, 0), magma, { Material = M.Neon })
		add(r, "Shoulder" .. n, "Chest", V(3, 2.4, 3.2), V(side * 4.4, 0.8, 0), V(0, 0, 0), rock, {})
		add(r, "ShoulderSpike" .. n, "Shoulder" .. n, V(0.8, 2, 0.8), V(side * 0.6, 1.6, 0), V(0, -0.6, 0), obs, { Rot = A(0, 0, rad(side * -25)) })
		limb(r, "Arm" .. n, "Shoulder" .. n, V(side * 0.4, -0.8, 0), V(2, 3.4, 2), V(1.8, 3, 1.8), V(3, 2.4, 3), rock2, rock, side < 0 and "armL" or "armR")
		for k = 1, 3 do
			add(r, "Knuckle" .. n .. k, "Arm" .. n .. "Tip", V(0.7, 0.5, 0.7), V(-1 + k * 0.5, -1.1, -1.2), V(0, 0, 0), magma, { Material = M.Neon })
		end
		limb(r, "Leg" .. n, "Body", V(side * 1.9, -2.2, 0), V(2.4, 2.6, 2.4), V(2.2, 2, 2.2), V(3, 0.9, 3.4), rock, rock2, side < 0 and "legA" or "legB")
		add(r, "LegSeam" .. n, "Leg" .. n, V(0.3, 2, 0.3), V(0, 0, -1.25), V(0, 0, 0), magma, { Material = M.Neon })
	end
	return r
end

-- Tidebreaker (Coast): a giant hermit-crab sea guardian. A coiled spiral
-- shell carrying coral and a barnacle crown, a crab body with stalk eyes,
-- one huge crushing claw and one tentacle-whip arm, six jointed legs and a
-- fringe of kelp
BUILD.Tidebreaker = function(s)
	local r = rig("Tidebreaker", s, 2.8)
	local shell, shell2, shell3, crab, crab2, coral, kelp = RGB(235, 200, 160), RGB(210, 160, 120), RGB(250, 230, 200), RGB(220, 90, 70), RGB(180, 60, 55), RGB(255, 120, 150), RGB(60, 140, 90)
	add(r, "Body", "HumanoidRootPart", V(6, 2.6, 5), V(0, 0.6, 0), V(0, 0, 0), crab, { Role = "body" })
	add(r, "Underplate", "Body", V(5.2, 0.8, 4.2), V(0, -1.4, 0), V(0, 0, 0), crab2, {})
	add(r, "Shell", "Body", V(5.6, 5.6, 5.6), V(0, 3, 1), V(0, 0, 0), shell, { Shape = "Ball" })
	for k = 1, 4 do
		add(r, "Whorl" .. k, "Shell", V(4.6 - k * 0.9, 4.6 - k * 0.9, 4.6 - k * 0.9), V(0, 1.2 + k * 0.7, 0.6 + k * 0.3), V(0, 0, 0), k % 2 == 0 and shell2 or shell3, { Shape = "Ball" })
	end
	for k = 1, 5 do
		local a = k * 1.2
		add(r, "Coral" .. k, "Shell", V(0.5, 1.6 + (k % 3) * 0.5, 0.5), V(math.cos(a) * 2, 2.4, math.sin(a) * 2), V(0, -0.8, 0), coral, { Rot = A(rad(math.cos(a) * 20), 0, rad(math.sin(a) * 20)) })
		add(r, "Barnacle" .. k, "Shell", V(0.8, 0.6, 0.8), V(math.cos(a + 0.6) * 2.6, 0.8, math.sin(a + 0.6) * 2.6), V(0, 0, 0), RGB(220, 220, 210), {})
	end
	add(r, "Head", "Body", V(3.4, 1.6, 1.8), V(0, 0.6, -2.8), V(0, 0, 0.4), crab, { Role = "head" })
	add(r, "Mandible", "Head", V(2, 0.6, 0.8), V(0, -0.7, -0.8), V(0, 0, 0), crab2, { Role = "jawBot" })
	for _, side in { -1, 1 } do
		local n = side < 0 and "L" or "R"
		add(r, "EyeStalk" .. n, "Head", V(0.4, 1.8, 0.4), V(side * 0.9, 1.2, -0.3), V(0, -0.8, 0), crab2, { Rot = A(0, 0, rad(side * -10)) })
		add(r, "EyeBall" .. n, "EyeStalk" .. n, V(0.9, 0.9, 0.9), V(0, 1.1, 0), V(0, 0, 0), RGB(20, 20, 25), { Shape = "Ball" })
		for k = 1, 3 do
			limb(r, "Leg" .. n .. k, "Body", V(side * 3, -0.6, -1.6 + k * 1.4), V(0.6, 2.2, 0.6), V(0.5, 2, 0.5), nil, crab, nil, (k + (side < 0 and 0 or 1)) % 2 == 0 and "legA" or "legB", {})
		end
		for k = 1, 3 do
			add(r, "Kelp" .. n .. k, "Underplate", V(0.4, 1.8, 0.6), V(side * (1 + k * 0.6), -1, 1.6), V(0, 0.9, 0), kelp, { Rot = A(rad(10), 0, rad(side * 10)) })
		end
	end
	-- crushing claw (left)
	limb(r, "ArmL", "Body", V(-3.2, 0.4, -2.4), V(1.4, 2.4, 1.4), V(1.2, 2, 1.2), nil, crab, nil, "armL", {})
	add(r, "ClawPalm", "ArmLLower", V(2.4, 2, 2.6), V(0, -1.6, -0.6), V(0, 0, 0), crab, {})
	add(r, "ClawTop", "ClawPalm", V(1.2, 0.9, 2.6), V(0, 0.5, -2), V(0, 0, 0), crab2, { Role = "jawTop" })
	add(r, "ClawBottom", "ClawPalm", V(1.1, 0.7, 2.2), V(0, -0.6, -1.8), V(0, 0, 0), crab2, { Role = "jawBot" })
	-- tentacle whip (right)
	add(r, "ArmR", "Body", V(1, 1, 1.8), V(3.2, 0.4, -2.2), V(0, 0, 0.6), RGB(150, 90, 170), { Role = "armR", Shape = "Ball" })
	local prev = "ArmR"
	for k = 1, 4 do
		local name = "Tentacle" .. k
		add(r, name, prev, V(0.9 - k * 0.12, 0.9 - k * 0.12, 1.6), V(0, 0, -1.2), V(0, 0, 0.6), RGB(150, 90, 170):Lerp(RGB(200, 140, 220), k / 4), { Rot = A(rad(-8), rad(10), 0) })
		add(r, name .. "Sucker", name, V(0.35, 0.2, 0.35), V(0, -0.45, 0), V(0, 0, 0), RGB(240, 200, 230), {})
		prev = name
	end
	return r
end


-- Sprout (Capstride's summon): a tiny walking mushroom — stalk with a
-- face, orange spotted cap, two stubby feet
BUILD.Shroomling = function(s)
	local r = rig("Shroomling", s, 1)
	add(r, "Body", "HumanoidRootPart", V(1.6, 2, 1.6), V(0, 0.5, 0), V(0, 0, 0), RGB(240, 228, 205), { Role = "body", Transparency = 1 })
	add(r, "Stalk", "Body", V(2.2, 1.7, 1.7), V(0, 0, 0), V(0, 0, 0), RGB(240, 228, 205), { Shape = "Cylinder", Rot = UPRIGHT })
	capKit(r, "Head", "Body", V(0, 1.1, 0), 1.7, 0.8, RGB(240, 140, 60), "head")
	add(r, "EyeL", "Body", V(0.35, 0.4, 0.15), V(-0.35, 0.35, -0.85), V(0, 0, 0), RGB(30, 30, 30), {})
	add(r, "EyeR", "Body", V(0.35, 0.4, 0.15), V(0.35, 0.35, -0.85), V(0, 0, 0), RGB(30, 30, 30), {})
	add(r, "LegL", "Body", V(0.6, 1.2, 0.6), V(-0.4, -1, 0), V(0, 0.6, 0), RGB(220, 210, 190), { Role = "legA" })
	add(r, "LegR", "Body", V(0.6, 1.2, 0.6), V(0.4, -1, 0), V(0, 0.6, 0), RGB(220, 210, 190), { Role = "legB" })
	return r
end

-- v2.0 friendly face pass (Steal-a-Brainrot / Steal-an-Egg readability):
-- every EyeL/EyeR becomes a big white block eye with a black pupil block,
-- so all monsters share one cute, cartoony face language
local function cartoonEyes(r)
	for _, name in { "EyeL", "EyeR" } do
		local eye = r.Parts[name]
		if eye then
			eye.Size = Vector3.new(math.max(eye.Size.X, 0.55 * r.Scale), math.max(eye.Size.Y, 0.6 * r.Scale), eye.Size.Z) * 1.25
			eye.Color = Color3.fromRGB(255, 255, 255)
			eye.Material = Enum.Material.SmoothPlastic
			local pupil = Instance.new("Part")
			pupil.Name = name .. "Pupil"
			pupil.Size = Vector3.new(eye.Size.X * 0.45, eye.Size.Y * 0.5, 0.1)
			pupil.Color = Color3.fromRGB(20, 20, 28)
			pupil.Material = Enum.Material.SmoothPlastic
			pupil.CanCollide = false
			pupil.CanTouch = false
			pupil.Massless = true
			pupil.CastShadow = false
			pupil.CFrame = eye.CFrame * CFrame.new(0, -eye.Size.Y * 0.08, -eye.Size.Z / 2 - 0.04)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = eye
			weld.Part1 = pupil
			weld.Parent = pupil
			pupil.Parent = r.Model
		end
	end
end

-- v2.7 detail pass (director: more parts, more detail on every monster):
-- every sizable body piece gets classic Roblox build detailing, welded on
-- (WeldConstraint, so animations and published clips are unaffected):
--   blocks     a lighter studded panel inset on top + a darker trim lip at
--              the bottom edge + side plates on long pieces
--   balls      three small bumps/scales on the upper half
--   cylinders  a raised band around the middle
-- Eyes, teeth, glowing, glass and see-through parts are left alone.
local SKIP_NAME = { "Eye", "Pupil", "Brow", "Tooth", "Teeth", "Fang", "Claw", "Iris", "Spot", "Mouth" }
local function detailPass(model: Model)
	local list = {}
	for _, p in model:GetDescendants() do
		if p:IsA("Part") and p.Name ~= "HumanoidRootPart" and p.Transparency < 0.3
			and p.Material ~= M.Neon and p.Material ~= M.Glass and p.Material ~= M.ForceField
			and not p:FindFirstChildOfClass("SpecialMesh") then
			local skip = false
			for _, k in SKIP_NAME do
				if string.find(p.Name, k) then
					skip = true
					break
				end
			end
			local sz = p.Size
			if not skip and math.min(sz.X, sz.Y, sz.Z) >= 0.7 and math.max(sz.X, sz.Y, sz.Z) >= 1.3 then
				table.insert(list, p)
			end
		end
	end
	local rnd = Random.new(#list * 7 + 3)
	local function bit(base: Part, name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?)
		local d = Instance.new("Part")
		d.Name = base.Name .. name
		d.Size = size
		d.CFrame = cf
		d.Color = color
		d.Material = M.Plastic
		if shape then
			d.Shape = shape
		end
		d.TopSurface = shape == nil and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
		d.BottomSurface = Enum.SurfaceType.Smooth
		d.Anchored = false
		d.CanCollide = false
		d.CanTouch = false
		d.CanQuery = false
		d.Massless = true
		d.CastShadow = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = base
		w.Part1 = d
		w.Parent = d
		d.Parent = base.Parent
		return d
	end
	for _, p in list do
		local sz, cf = p.Size, p.CFrame
		local light = p.Color:Lerp(Color3.new(1, 1, 1), 0.14)
		local dark = p.Color:Lerp(Color3.new(0, 0, 0), 0.22)
		if p.Shape == Enum.PartType.Block then
			if sz.X >= 1 and sz.Z >= 1 then
				bit(p, "Panel", Vector3.new(sz.X * 0.68, 0.14, sz.Z * 0.68), cf * CFrame.new(0, sz.Y / 2 + 0.05, 0), light)
			end
			local lip = math.max(0.16, sz.Y * 0.14)
			bit(p, "Trim", Vector3.new(sz.X + 0.12, lip, sz.Z + 0.12), cf * CFrame.new(0, -sz.Y / 2 + lip / 2, 0), dark)
			if math.max(sz.X, sz.Z) >= 2.4 then
				-- plates on the two long sides
				local alongX = sz.X >= sz.Z
				for _, sgn in { -1, 1 } do
					local off = alongX and CFrame.new(0, sz.Y * 0.08, sgn * (sz.Z / 2 + 0.05)) or CFrame.new(sgn * (sz.X / 2 + 0.05), sz.Y * 0.08, 0)
					local psz = alongX and Vector3.new(sz.X * 0.5, sz.Y * 0.4, 0.14) or Vector3.new(0.14, sz.Y * 0.4, sz.Z * 0.5)
					bit(p, "Plate" .. sgn, psz, cf * off, dark:Lerp(p.Color, 0.5))
				end
			end
		elseif p.Shape == Enum.PartType.Ball then
			local rad = sz.X / 2
			for k = 1, 3 do
				local a = k * 2.1 + rnd:NextNumber(0, 0.7)
				local el = rnd:NextNumber(0.35, 1.0)
				local dir = Vector3.new(math.cos(a) * math.cos(el), math.sin(el), math.sin(a) * math.cos(el))
				local bs = rad * rnd:NextNumber(0.28, 0.4)
				bit(p, "Bump" .. k, Vector3.one * bs, cf * CFrame.new(dir * (rad - bs * 0.25)), k == 2 and light or dark:Lerp(p.Color, 0.6), Enum.PartType.Ball)
			end
		elseif p.Shape == Enum.PartType.Cylinder then
			bit(p, "Band", Vector3.new(math.max(0.2, sz.X * 0.18), sz.Y + 0.14, sz.Z + 0.14), cf, dark, Enum.PartType.Cylinder)
		end
	end
end

function MonsterRigs.Build(typeName: string, scale: number): Model
	local r = BUILD[typeName](scale)
	cartoonEyes(r)
	detailPass(r.Model)
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = r.Hip * scale
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.Parent = r.Model
	Instance.new("Animator").Parent = hum
	return r.Model
end

return MonsterRigs
