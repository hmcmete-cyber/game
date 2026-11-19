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

local BUILD = {}

-- (a) Prismaw: angular crystal quadruped, purple body, cyan/magenta shards
BUILD.Prismaw = function(s)
	local r = rig("Prismaw", s, 3)
	local purple, dark = RGB(110, 50, 170), RGB(60, 30, 95)
	add(r, "Body", "HumanoidRootPart", V(6, 3.4, 8), V(0, 0.6, 0), V(0, 0, 0), purple, { Role = "body", Material = M.Glass })
	add(r, "Head", "Body", V(3.4, 2.8, 3.2), V(0, 0.8, -4.2), V(0, 0, 1.4), purple, { Role = "head", Material = M.Glass })
	add(r, "Jaw", "Head", V(3, 0.9, 2.6), V(0, -1.3, -0.2), V(0, 0, 1.1), dark, { Role = "jawBot" })
	add(r, "EyeL", "Head", V(0.6, 0.5, 0.3), V(-0.9, 0.4, -1.65), V(0, 0, 0), RGB(80, 255, 255), { Material = M.Neon })
	add(r, "EyeR", "Head", V(0.6, 0.5, 0.3), V(0.9, 0.4, -1.65), V(0, 0, 0), RGB(80, 255, 255), { Material = M.Neon })
	legs4(r, "Body", 2.4, 3, 1.5, V(1.6, 3.2, 1.6), dark, M.Glass)
	local cyan, magenta = RGB(60, 230, 240), RGB(240, 70, 200)
	for i, spec in {
		{ V(0, 1.7, -2), A(rad(-15), 0, 0), cyan, V(1.2, 3, 2) }, { V(-1.6, 1.7, 0), A(0, rad(90), rad(20)), magenta, V(1, 2.6, 1.8) },
		{ V(1.6, 1.7, 0.5), A(0, rad(-90), rad(-20)), cyan, V(1, 2.8, 1.8) }, { V(0, 1.7, 2.2), A(rad(20), rad(180), 0), magenta, V(1.2, 2.4, 2) },
		{ V(-0.6, 1.4, -0.8), A(0, rad(45), 0), magenta, V(0.8, 2, 1.4) },
	} do
		crystal(r, "Shard" .. i, "Body", spec[4], spec[1], spec[2], spec[3])
	end
	crystal(r, "TailShard", "Body", V(1, 1.4, 3), V(0, 0.4, 4.6), A(rad(-60), rad(180), 0), cyan, "tail")
	return r
end

-- (b) Frostback: dark armoured tortoise with pale-green ice crystals
BUILD.Frostback = function(s)
	local r = rig("Frostback", s, 2.2)
	local dark, shell, ice = RGB(55, 48, 52), RGB(80, 72, 70), RGB(175, 235, 205)
	add(r, "Body", "HumanoidRootPart", V(7, 2.4, 8), V(0, 0.4, 0), V(0, 0, 0), dark, { Role = "body", Material = M.Slate })
	add(r, "Shell", "Body", V(6.4, 2.4, 7.2), V(0, 1.8, 0), V(0, 0, 0), shell, { Material = M.Slate })
	add(r, "Head", "Body", V(2.6, 2.2, 3), V(0, 0.4, -4.2), V(0, 0, 1.2), dark, { Role = "head", Material = M.Slate })
	add(r, "Jaw", "Head", V(2.2, 0.7, 2.4), V(0, -1.1, -0.2), V(0, 0, 1), RGB(40, 35, 38), { Role = "jawBot" })
	add(r, "EyeL", "Head", V(0.5, 0.4, 0.3), V(-0.8, 0.4, -1.55), V(0, 0, 0), ice, { Material = M.Neon })
	add(r, "EyeR", "Head", V(0.5, 0.4, 0.3), V(0.8, 0.4, -1.55), V(0, 0, 0), ice, { Material = M.Neon })
	legs4(r, "Body", 2.8, 3.1, 1, V(2.1, 2.4, 2.1), dark, M.Slate)
	for i, spec in {
		{ V(0, 3, -1.5), A(rad(-10), 0, 0), V(1.4, 3.2, 2.2) }, { V(-1.8, 2.9, 0.5), A(0, rad(90), rad(15)), V(1.2, 2.6, 2) },
		{ V(1.8, 2.9, 0.3), A(0, rad(-90), rad(-15)), V(1.2, 2.8, 2) }, { V(0, 3, 2.2), A(rad(15), rad(180), 0), V(1.4, 2.6, 2.2) },
		{ V(-1, 2.8, -2.6), A(0, rad(30), rad(10)), V(0.9, 2, 1.4) }, { V(1.2, 2.8, 2.8), A(0, rad(200), rad(-10)), V(0.9, 2.2, 1.4) },
		{ V(0.6, 3, 0), A(0, rad(60), 0), V(1, 3.6, 1.6) },
	} do
		crystal(r, "Ice" .. i, "Body", spec[3], spec[1], spec[2], ice)
	end
	crystal(r, "LegIceL", "LegFL", V(0.8, 1.4, 1.2), V(-0.6, 0.2, -0.6), A(0, rad(45), rad(25)), ice)
	crystal(r, "LegIceR", "LegFR", V(0.8, 1.4, 1.2), V(0.6, 0.2, -0.6), A(0, rad(-45), rad(-25)), ice)
	return r
end

-- (c) Voltwraith: floating shadow humanoid crackling with cyan lightning
BUILD.Voltwraith = function(s)
	local r = rig("Voltwraith", s, 5)
	local shadow, bolt = RGB(38, 42, 58), RGB(110, 240, 255)
	add(r, "Body", "HumanoidRootPart", V(3.2, 4, 2), V(0, 1, 0), V(0, 0, 0), shadow, { Role = "body", Material = M.Slate, Transparency = 0.1 })
	add(r, "Head", "Body", V(2.2, 2.2, 2), V(0, 2, 0), V(0, -1.1, 0), shadow, { Role = "head", Material = M.Slate, Transparency = 0.1 })
	add(r, "EyeL", "Head", V(0.5, 0.3, 0.2), V(-0.5, 0.2, -1), V(0, 0, 0), bolt, { Material = M.Neon })
	add(r, "EyeR", "Head", V(0.5, 0.3, 0.2), V(0.5, 0.2, -1), V(0, 0, 0), bolt, { Material = M.Neon, Glow = bolt })
	add(r, "ArmL", "Body", V(1, 4.6, 1), V(-2.1, 1.7, 0), V(0, 2.1, 0), shadow, { Role = "armL", Material = M.Slate, Transparency = 0.1 })
	add(r, "ArmR", "Body", V(1, 4.6, 1), V(2.1, 1.7, 0), V(0, 2.1, 0), shadow, { Role = "armR", Material = M.Slate, Transparency = 0.1 })
	add(r, "BoltL", "ArmL", V(0.25, 4, 0.25), V(-0.3, 0, -0.4), V(0, 0, 0), bolt, { Material = M.Neon, Rot = A(0, 0, rad(10)) })
	add(r, "BoltR", "ArmR", V(0.25, 4, 0.25), V(0.3, 0, -0.4), V(0, 0, 0), bolt, { Material = M.Neon, Rot = A(0, 0, rad(-10)) })
	add(r, "Tail1", "Body", V(2.4, 2, 1.6), V(0, -2, 0), V(0, 1, 0), shadow, { Role = "tail", Material = M.Slate, Transparency = 0.2 })
	add(r, "Tail2", "Tail1", V(1.6, 1.8, 1.2), V(0, -1, 0), V(0, 0.9, 0), shadow, { Role = "tail", Material = M.Slate, Transparency = 0.35 })
	add(r, "Tail3", "Tail2", V(0.9, 1.6, 0.8), V(0, -0.9, 0), V(0, 0.8, 0), shadow, { Role = "tail", Material = M.Slate, Transparency = 0.5 })
	return r
end

-- (d) Cyclonox: a spinning funnel of storm rings with a face and cloud fists
BUILD.Cyclonox = function(s)
	local r = rig("Cyclonox", s, 5)
	local storm, dark, eye = RGB(95, 100, 115), RGB(60, 62, 75), RGB(140, 230, 255)
	add(r, "Body", "HumanoidRootPart", V(4, 3, 4), V(0, 2, 0), V(0, 0, 0), dark, { Role = "body", Shape = "Ball", Transparency = 0.1 })
	add(r, "Head", "Body", V(5.4, 2.4, 5.4), V(0, 2.4, 0), V(0, 0, 0), storm, { Role = "head", Shape = "Ball", Transparency = 0.1 })
	add(r, "EyeL", "Head", V(0.8, 0.4, 0.3), V(-1, 0.3, -2.6), V(0, 0, 0), eye, { Material = M.Neon })
	add(r, "EyeR", "Head", V(0.8, 0.4, 0.3), V(1, 0.3, -2.6), V(0, 0, 0), eye, { Material = M.Neon, Glow = eye })
	local last = "Body"
	for i, w in { 3.6, 2.8, 2.0, 1.3 } do
		add(r, "Funnel" .. i, last, V(w, 1.5, w), V(0.15 * i, -1.4, 0), V(0, 0, 0), storm:Lerp(dark, i / 5), {
			Role = "spin", Shape = "Ball", Transparency = 0.15 + i * 0.05,
		})
		last = "Funnel" .. i
	end
	add(r, "ArmL", "Head", V(1.6, 4, 1.6), V(-3, -0.4, 0), V(0, 1.8, 0), storm, { Role = "armL", Transparency = 0.1 })
	add(r, "ArmR", "Head", V(1.6, 4, 1.6), V(3, -0.4, 0), V(0, 1.8, 0), storm, { Role = "armR", Transparency = 0.1 })
	add(r, "FistL", "ArmL", V(2.2, 2.2, 2.2), V(0, -2.2, 0), V(0, 0, 0), dark, { Shape = "Ball" })
	add(r, "FistR", "ArmR", V(2.2, 2.2, 2.2), V(0, -2.2, 0), V(0, 0, 0), dark, { Shape = "Ball" })
	for i = 1, 3 do
		local a = i * 2.1
		add(r, "Debris" .. i, "Body", V(0.8, 0.8, 0.8), V(math.cos(a) * 3.4, 0.5 * i - 1, math.sin(a) * 3.4), V(0, 0, 0), RGB(120, 100, 80), {
			Role = "orbit", Material = M.Slate,
		})
	end
	return r
end

-- (e) Cindermaw: towering basalt demon, magma seams, wing-like shoulder plates
BUILD.Cindermaw = function(s)
	local r = rig("Cindermaw", s, 4)
	local rock, magma = RGB(42, 32, 32), RGB(255, 110, 30)
	add(r, "Body", "HumanoidRootPart", V(5, 5, 3), V(0, 2.4, 0), V(0, 0, 0), rock, { Role = "body", Material = M.Basalt })
	add(r, "Core", "Body", V(1.8, 1.8, 0.4), V(0, 0.6, -1.5), V(0, 0, 0), magma, { Material = M.Neon, Glow = magma })
	add(r, "SeamA", "Body", V(0.3, 4.4, 0.2), V(-1.3, 0, -1.5), V(0, 0, 0), magma, { Material = M.Neon, Rot = A(0, 0, rad(12)) })
	add(r, "SeamB", "Body", V(0.3, 4, 0.2), V(1.4, -0.2, -1.5), V(0, 0, 0), magma, { Material = M.Neon, Rot = A(0, 0, rad(-15)) })
	add(r, "Head", "Body", V(2.6, 2.4, 2.4), V(0, 2.5, -0.3), V(0, -1.2, 0), rock, { Role = "head", Material = M.Basalt })
	add(r, "Mouth", "Head", V(1.6, 0.4, 0.2), V(0, -0.6, -1.2), V(0, 0, 0), magma, { Material = M.Neon })
	add(r, "HornL", "Head", V(0.6, 2, 1.2), V(-1, 1.2, 0), V(0, -1, 0), RGB(30, 25, 25), { Class = "WedgePart", Rot = A(0, 0, rad(25)) })
	add(r, "HornR", "Head", V(0.6, 2, 1.2), V(1, 1.2, 0), V(0, -1, 0), RGB(30, 25, 25), { Class = "WedgePart", Rot = A(0, 0, rad(-25)) })
	add(r, "WingL", "Body", V(0.6, 5, 4), V(-2.2, 2, 1.4), V(0, -2.2, 1.4), rock, { Class = "WedgePart", Role = "wing", Material = M.Basalt, Rot = A(rad(-20), rad(-90), rad(35)) })
	add(r, "WingR", "Body", V(0.6, 5, 4), V(2.2, 2, 1.4), V(0, -2.2, 1.4), rock, { Class = "WedgePart", Role = "wing", Material = M.Basalt, Rot = A(rad(-20), rad(90), rad(-35)) })
	biped(r, "Body", -2.5, 1.5, V(2, 4.2, 2), 1.8, 3.4, V(1.8, 5, 1.8), rock, rock, M.Basalt)
	add(r, "MagmaFistL", "ArmL", V(2.2, 1.4, 2.2), V(0, -2.6, 0), V(0, 0, 0), magma, { Material = M.Neon })
	add(r, "MagmaFistR", "ArmR", V(2.2, 1.4, 2.2), V(0, -2.6, 0), V(0, 0, 0), magma, { Material = M.Neon, Glow = magma })
	return r
end

-- (f) Smoldlet: squat black ember blob with glowing cracks
BUILD.Smoldlet = function(s)
	local r = rig("Smoldlet", s, 1.2)
	local coal, ember = RGB(30, 25, 25), RGB(255, 140, 40)
	add(r, "Body", "HumanoidRootPart", V(4.2, 3.4, 4), V(0, 0.8, 0), V(0, 0, 0), coal, { Role = "body", Shape = "Ball", Material = M.Basalt })
	add(r, "Crack1", "Body", V(0.25, 2.6, 0.2), V(-0.8, 0, -1.95), V(0, 0, 0), ember, { Material = M.Neon, Rot = A(0, 0, rad(20)) })
	add(r, "Crack2", "Body", V(0.25, 2, 0.2), V(0.9, 0.2, -1.9), V(0, 0, 0), ember, { Material = M.Neon, Rot = A(0, 0, rad(-25)) })
	add(r, "Head", "Body", V(2.6, 0.3, 0.2), V(0, -0.2, -2), V(0, 0, 0), ember, { Role = "head", Material = M.Neon, Glow = ember })
	add(r, "EyeL", "Body", V(0.6, 0.7, 0.3), V(-0.75, 0.6, -1.9), V(0, 0, 0), ember, {})
	add(r, "EyeR", "Body", V(0.6, 0.7, 0.3), V(0.75, 0.6, -1.9), V(0, 0, 0), ember, {})
	add(r, "FootL", "Body", V(1.2, 1, 1.4), V(-1.1, -1.6, 0), V(0, 0.5, 0), coal, { Role = "legA" })
	add(r, "FootR", "Body", V(1.2, 1, 1.4), V(1.1, -1.6, 0), V(0, 0.5, 0), coal, { Role = "legB" })
	local flame = add(r, "Flame", "Body", V(1.4, 1.4, 1.4), V(0, 1.9, 0), V(0, 0, 0), ember, { Shape = "Ball", Material = M.Neon, Role = "tail" })
	local fire = Instance.new("Fire")
	fire.Size = 4 * s
	fire.Heat = 6
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

-- (g) Capstride: tall walking mushroom — round cream stalk body with its
-- face under a wide red spotted cap, stubby arms and feet, a small
-- mushroom sprouting from each shoulder
BUILD.Capstride = function(s)
	local r = rig("Capstride", s, 2.4)
	local stem, cap = RGB(240, 228, 205), RGB(215, 50, 50)
	-- invisible core keeps the limb maths simple; the round stalk is a child
	add(r, "Body", "HumanoidRootPart", V(2.4, 5, 2.4), V(0, 2.4, 0), V(0, 0, 0), stem, { Role = "body", Transparency = 1 })
	add(r, "Stalk", "Body", V(5.2, 3, 3), V(0, 0, 0), V(0, 0, 0), stem, { Shape = "Cylinder", Rot = UPRIGHT })
	add(r, "StalkRing", "Body", V(0.5, 3.8, 3.8), V(0, 0.4, 0), V(0, 0, 0), SPOT, { Shape = "Cylinder", Rot = UPRIGHT })
	capKit(r, "Head", "Body", V(0, 2.6, 0), 3.8, 1.5, cap, "head")
	add(r, "EyeL", "Body", V(0.55, 0.65, 0.2), V(-0.6, 1.4, -1.5), V(0, 0, 0), RGB(30, 30, 30), {})
	add(r, "EyeR", "Body", V(0.55, 0.65, 0.2), V(0.6, 1.4, -1.5), V(0, 0, 0), RGB(30, 30, 30), {})
	add(r, "Mouth", "Body", V(0.9, 0.2, 0.15), V(0, 0.6, -1.52), V(0, 0, 0), RGB(120, 60, 50), {})
	biped(r, "Body", -2.4, 0.8, V(1, 2.2, 1.2), 0.9, 1.7, V(0.8, 2.4, 0.8), stem, stem, M.SmoothPlastic)
	sprout(r, "ShoulderShroomL", "Body", V(-1.1, 1.9, 0.6), 1.2, 0.9, RGB(240, 140, 60))
	sprout(r, "ShoulderShroomR", "Body", V(1.1, 1.6, 0.5), 1, 0.75, RGB(240, 140, 60))
	return r
end

-- (h) Sporeback: hunched purple-grey fungal beast — a big pink mushroom cap
-- on its back, a grove of small mushrooms along its spine, low head, legs
BUILD.Sporeback = function(s)
	local r = rig("Sporeback", s, 2.6)
	local hide, cap = RGB(115, 95, 125), RGB(240, 130, 190)
	add(r, "Body", "HumanoidRootPart", V(5, 3.6, 6.4), V(0, 0.8, 0), V(0, 0, 0), hide, { Role = "body" })
	add(r, "CapStem", "Body", V(1.6, 2.2, 2.2), V(0, 1.8, 0.4), V(-0.8, 0, 0), RGB(235, 220, 230), { Shape = "Cylinder", Rot = UPRIGHT })
	capKit(r, "Cap", "Body", V(0, 3.4, 0.4), 3.3, 1.2, cap)
	add(r, "Head", "Body", V(2.6, 2.2, 2.6), V(0, -0.4, -3.6), V(0, 0, 1.1), hide, { Role = "head" })
	add(r, "Jaw", "Head", V(2.2, 0.7, 2), V(0, -1.1, -0.2), V(0, 0, 0.9), RGB(70, 55, 80), { Role = "jawBot" })
	add(r, "EyeL", "Head", V(0.5, 0.4, 0.2), V(-0.7, 0.4, -1.3), V(0, 0, 0), RGB(255, 200, 240), {})
	add(r, "EyeR", "Head", V(0.5, 0.4, 0.2), V(0.7, 0.4, -1.3), V(0, 0, 0), RGB(255, 200, 240), {})
	legs4(r, "Body", 2, 2.4, 1.2, V(1.5, 3, 1.5), hide, M.Slate)
	sprout(r, "BackShroomA", "Body", V(-1.4, 1.8, -1.8), 1.4, 1, RGB(250, 160, 205))
	sprout(r, "BackShroomB", "Body", V(1.5, 1.8, 2.3), 1.1, 0.8, RGB(250, 160, 205))
	sprout(r, "BackShroomC", "Body", V(-1.2, 1.8, 2.6), 0.9, 0.65, RGB(200, 150, 230))
	for i = 1, 3 do
		add(r, "Spine" .. i, "Body", V(0.5, 1.6, 1.2), V(0, 1.9, -2.9 + i * 0.5), V(0, -0.8, 0), RGB(200, 190, 205), { Class = "WedgePart", Rot = A(rad(-25), 0, 0) })
	end
	return r
end

-- (i) Rubbleye: floating cluster of dark boulders around a glowing purple eye
BUILD.Rubbleye = function(s)
	local r = rig("Rubbleye", s, 6)
	local rock, eye = RGB(60, 55, 65), RGB(190, 80, 255)
	add(r, "Body", "HumanoidRootPart", V(4, 4, 4), V(0, 1.5, 0), V(0, 0, 0), rock, { Role = "body", Shape = "Ball", Material = M.Slate })
	add(r, "Head", "Body", V(1.8, 1.8, 0.6), V(0, 0.2, -1.8), V(0, 0, 0), eye, { Role = "head", Shape = "Ball", Material = M.Neon, Glow = eye })
	add(r, "Pupil", "Head", V(0.7, 0.7, 0.3), V(0, 0, -0.25), V(0, 0, 0), RGB(20, 0, 30), { Shape = "Ball" })
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local size = 1.4 + (i % 3) * 0.5
		add(r, "Boulder" .. i, "Body", V(size, size * 0.9, size), V(math.cos(a) * 3.8, (i % 2) * 1.2 - 0.6, math.sin(a) * 3.8), V(0, 0, 0), rock:Lerp(RGB(90, 80, 90), (i % 3) / 3), {
			Role = "orbit", Material = M.Slate, Shape = (i % 2 == 0) and "Ball" or nil,
		})
	end
	return r
end

-- (j) Bristlehulk: big green leafy brute with bristles and long arms
BUILD.Bristlehulk = function(s)
	local r = rig("Bristlehulk", s, 2.6)
	local leaf, dark = RGB(80, 150, 70), RGB(50, 100, 45)
	add(r, "Body", "HumanoidRootPart", V(5, 4.4, 3.4), V(0, 2, 0), V(0, 0, 0), leaf, { Role = "body", Material = M.Grass })
	add(r, "Head", "Body", V(2.4, 2, 2.2), V(0, 2.2, -0.6), V(0, -1, 0), dark, { Role = "head", Material = M.Grass })
	add(r, "EyeL", "Head", V(0.4, 0.4, 0.2), V(-0.6, 0.2, -1.1), V(0, 0, 0), RGB(255, 230, 90), { Material = M.Neon })
	add(r, "EyeR", "Head", V(0.4, 0.4, 0.2), V(0.6, 0.2, -1.1), V(0, 0, 0), RGB(255, 230, 90), { Material = M.Neon })
	biped(r, "Body", -2.2, 1.3, V(1.8, 3, 1.8), 1.6, 3.2, V(1.6, 5.4, 1.6), dark, leaf, M.Grass)
	for i = 1, 8 do
		local a = i * 0.78
		add(r, "Bristle" .. i, "Body", V(0.5, 2.2, 1), V(math.cos(a) * 2.2, 2 + (i % 2) * 0.4, math.sin(a) * 1.4), V(0, -1.1, 0), RGB(110, 190, 90), {
			Class = "WedgePart", Rot = A(rad(-30), a, 0),
		})
	end
	add(r, "LeafCrown", "Head", V(2.6, 0.8, 2.6), V(0, 1.2, 0), V(0, 0, 0), RGB(130, 210, 100), { Material = M.Grass, Shape = "Ball" })
	return r
end

-- (k) Gulpvine: storm-charged snapping plant of the Storm Marshes —
-- dark indigo stalk, slate-blue maw lined with glowing cyan veins and
-- lightning-tipped teeth, leaves that crackle with static
BUILD.Gulpvine = function(s)
	local r = rig("Gulpvine", s, 0.6)
	local stalk, maw, jaw = RGB(40, 50, 75), RGB(55, 70, 105), RGB(35, 42, 65)
	local volt, tooth = RGB(110, 240, 255), RGB(220, 245, 255)
	add(r, "Body", "HumanoidRootPart", V(4, 1, 4), V(0, -0.2, 0), V(0, 0, 0), RGB(35, 45, 60), { Role = "body", Material = M.Slate })
	add(r, "Stem", "Body", V(1.2, 3, 1.2), V(0, 0.4, 0), V(0, -1.5, 0), stalk, { Role = "tail", Material = M.Slate })
	add(r, "StemVein", "Stem", V(0.2, 2.8, 0.2), V(0, 0, -0.62), V(0, 0, 0), volt, { Material = M.Neon })
	add(r, "Head", "Stem", V(3.4, 1.2, 3.4), V(0, 1.6, 0), V(0, -0.6, 1.2), maw, { Role = "jawTop", Material = M.Slate })
	add(r, "Jaw", "Stem", V(3.2, 1, 3.2), V(0, 1.4, 0), V(0, 0.5, 1.1), jaw, { Role = "jawBot", Material = M.Slate })
	add(r, "EyeL", "Head", V(0.5, 0.5, 0.3), V(-0.8, 0.75, -1.2), V(0, 0, 0), volt, {})
	add(r, "EyeR", "Head", V(0.5, 0.5, 0.3), V(0.8, 0.75, -1.2), V(0, 0, 0), volt, {})
	add(r, "MawVeinT", "Head", V(3, 0.15, 0.2), V(0, 0.62, -0.6), V(0, 0, 0), volt, { Material = M.Neon })
	add(r, "MawVeinB", "Jaw", V(2.8, 0.15, 0.2), V(0, -0.52, -0.6), V(0, 0, 0), volt, { Material = M.Neon, Glow = volt })
	for i = 1, 4 do
		add(r, "ToothT" .. i, "Head", V(0.4, 0.7, 0.4), V(-1.2 + i * 0.6, -0.8, -1.4), V(0, 0, 0), tooth, { Class = "WedgePart", Material = M.Neon, Rot = A(rad(180), 0, 0) })
		add(r, "ToothB" .. i, "Jaw", V(0.4, 0.7, 0.4), V(-1.5 + i * 0.6, 0.7, -1.3), V(0, 0, 0), tooth, { Class = "WedgePart", Material = M.Neon })
	end
	for i = 1, 4 do
		local a = i * 1.57 + 0.4
		local leaf = add(r, "Leaf" .. i, "Body", V(1.4, 0.25, 3), V(math.cos(a) * 1.8, 0.5, math.sin(a) * 1.8), V(0, 0, -1.3), stalk, {
			Material = M.Slate, Rot = A(rad(-15), -a + math.pi / 2, 0), Role = "wing",
		})
		if i % 2 == 0 then
			local sparks = Instance.new("ParticleEmitter")
			sparks.Color = ColorSequence.new(volt)
			sparks.LightEmission = 1
			sparks.Size = NumberSequence.new(0.25, 0)
			sparks.Lifetime = NumberRange.new(0.15, 0.3)
			sparks.Rate = 6
			sparks.Speed = NumberRange.new(4, 8)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks.Parent = leaf
		end
	end
	return r
end

-- (l) Mossgrave: grey stone golem draped in vines and moss
BUILD.Mossgrave = function(s)
	local r = rig("Mossgrave", s, 3)
	local stone, moss, vine = RGB(130, 130, 128), RGB(90, 140, 70), RGB(60, 110, 50)
	add(r, "Body", "HumanoidRootPart", V(5, 4.6, 3.4), V(0, 2.2, 0), V(0, 0, 0), stone, { Role = "body", Material = M.Slate })
	add(r, "Head", "Body", V(2.6, 2.2, 2.4), V(0, 2.3, -0.3), V(0, -1.1, 0), stone, { Role = "head", Material = M.Slate })
	add(r, "EyeL", "Head", V(0.5, 0.3, 0.2), V(-0.6, 0.2, -1.2), V(0, 0, 0), RGB(150, 255, 150), { Material = M.Neon })
	add(r, "EyeR", "Head", V(0.5, 0.3, 0.2), V(0.6, 0.2, -1.2), V(0, 0, 0), RGB(150, 255, 150), { Material = M.Neon })
	add(r, "MossTop", "Head", V(2.8, 0.6, 2.6), V(0, 1.2, 0), V(0, 0, 0), moss, { Material = M.Grass })
	biped(r, "Body", -2.4, 1.4, V(2, 3.4, 2), 1.7, 3.4, V(2, 4.8, 2), stone, stone, M.Slate)
	add(r, "VineA", "Body", V(0.3, 4.4, 0.3), V(-1, 0, -1.75), V(0, 0, 0), vine, { Material = M.Grass, Rot = A(0, 0, rad(15)) })
	add(r, "VineB", "Body", V(0.3, 3.8, 0.3), V(1.4, 0.3, -1.75), V(0, 0, 0), vine, { Material = M.Grass, Rot = A(0, 0, rad(-20)) })
	add(r, "VineArm", "ArmR", V(0.3, 4.4, 0.3), V(0.6, -0.4, -1), V(0, 0, 0), vine, { Material = M.Grass })
	add(r, "MossShoulder", "ArmL", V(2.2, 0.6, 2.2), V(0, 2.2, 0), V(0, 0, 0), moss, { Material = M.Grass })
	return r
end

-- (m) Gnashgut: bulky green glutton with a huge fanged mouth
BUILD.Gnashgut = function(s)
	local r = rig("Gnashgut", s, 1.6)
	local skin, mouth, fang = RGB(95, 170, 80), RGB(60, 20, 30), RGB(250, 245, 225)
	add(r, "Body", "HumanoidRootPart", V(6, 5, 5), V(0, 1.6, 0), V(0, 0, 0), skin, { Role = "body", Shape = "Ball" })
	add(r, "Head", "Body", V(4.4, 1.4, 1.2), V(0, 0.6, -2.2), V(0, 0, 0), mouth, { Role = "jawTop" })
	add(r, "Jaw", "Body", V(4, 1.2, 1.2), V(0, -0.5, -2.1), V(0, 0, 0), RGB(80, 140, 65), { Role = "jawBot" })
	for i = 1, 3 do
		add(r, "Fang" .. i, "Head", V(0.5, 1.2, 0.5), V(-1.4 + (i - 1) * 1.4, -0.9, -0.2), V(0, 0, 0), fang, { Class = "WedgePart", Rot = A(rad(180), 0, 0) })
	end
	add(r, "EyeL", "Body", V(0.9, 0.9, 0.4), V(-1.2, 2, -2), V(0, 0, 0), RGB(255, 240, 120), { Shape = "Ball", Material = M.Neon })
	add(r, "EyeR", "Body", V(0.7, 0.7, 0.4), V(1.3, 2.1, -2), V(0, 0, 0), RGB(255, 240, 120), { Shape = "Ball", Material = M.Neon })
	biped(r, "Body", -2, 1.6, V(1.8, 2, 1.8), 0.6, 3.2, V(1.4, 3, 1.4), RGB(70, 130, 60), skin, M.SmoothPlastic)
	return r
end

-- (n) Skyfin: sky shark of the Coast — v2.1 STYLE ANCHOR (director's blue
-- shark reference): light-blue studded body, pale belly, pointed snout,
-- small dark eyes, tall dorsal fin, side fins, short legs, crescent tail.
-- Built only from Roblox parts (blocks, wedges, balls) with visible studs.
BUILD.Skyfin = function(s)
	local r = rig("Skyfin", s, 2)
	local blue, deep, pale = RGB(110, 175, 235), RGB(70, 130, 200), RGB(235, 242, 250)
	local ST = { Studs = true }
	local function o(t)
		for k, v in ST do
			t[k] = v
		end
		return t
	end
	add(r, "Body", "HumanoidRootPart", V(4, 3.4, 6.4), V(0, 0.8, 0.4), V(0, 0, 0), blue, o({ Role = "body" }))
	add(r, "Belly", "Body", V(3.4, 1, 5.8), V(0, -1.5, 0), V(0, 0, 0), pale, o({}))
	add(r, "Head", "Body", V(3.6, 3, 2.6), V(0, -0.1, -3.2), V(0, 0, 1.3), blue, o({ Role = "head" }))
	add(r, "Snout", "Head", V(3.6, 2, 2.4), V(0, 0.5, -1.3), V(0, 0, 1.2), blue, o({ Class = "WedgePart" }))
	add(r, "Jaw", "Head", V(3.2, 0.8, 2.6), V(0, -1.3, -0.2), V(0, 0.2, 1.1), pale, o({ Role = "jawBot" }))
	for i = 1, 3 do
		add(r, "Tooth" .. i, "Jaw", V(0.45, 0.6, 0.45), V(-0.9 + (i - 1) * 0.9, 0.6, -1.1), V(0, 0, 0), RGB(255, 255, 255), { Class = "WedgePart" })
	end
	add(r, "DotEyeL", "Head", V(0.45, 0.5, 0.2), V(-1.82, 0.5, -0.4), V(0, 0, 0), RGB(25, 30, 45), { Rot = CFrame.Angles(0, math.rad(90), 0) })
	add(r, "DotEyeR", "Head", V(0.45, 0.5, 0.2), V(1.82, 0.5, -0.4), V(0, 0, 0), RGB(25, 30, 45), { Rot = CFrame.Angles(0, math.rad(-90), 0) })
	add(r, "Dorsal", "Body", V(0.7, 3, 2.8), V(0, 1.7, 0.6), V(0, -1.5, 0), deep, o({ Class = "WedgePart", Role = "wing", Rot = CFrame.Angles(0, math.pi, 0) }))
	add(r, "FinL", "Body", V(0.4, 1.6, 2.2), V(-2, -0.6, -1.2), V(0, 0.8, 0), deep, o({ Class = "WedgePart", Role = "armL", Rot = CFrame.Angles(0, math.pi, math.rad(-60)) }))
	add(r, "FinR", "Body", V(0.4, 1.6, 2.2), V(2, -0.6, -1.2), V(0, 0.8, 0), deep, o({ Class = "WedgePart", Role = "armR", Rot = CFrame.Angles(0, math.pi, math.rad(60)) }))
	for i, spec in { { -1.1, -1.4 }, { 1.1, -1.4 }, { -1.1, 1.8 }, { 1.1, 1.8 } } do
		add(r, "Leg" .. i, "Body", V(1.1, 1.6, 1.1), V(spec[1], -1.8, spec[2]), V(0, 0.8, 0), pale, o({ Role = (i == 1 or i == 4) and "legA" or "legB" }))
	end
	add(r, "Gill", "Body", V(0.15, 1.2, 0.2), V(-2.02, 0.2, -2.2), V(0, 0, 0), deep, {})
	add(r, "Gill2", "Body", V(0.15, 1.2, 0.2), V(2.02, 0.2, -2.2), V(0, 0, 0), deep, {})
	add(r, "Tail", "Body", V(2.2, 2.2, 2.6), V(0, 0.2, 3.2), V(0, 0, -1.3), blue, o({ Role = "tail" }))
	add(r, "TailFinTop", "Tail", V(0.6, 2.8, 2), V(0, 0.8, 1.3), V(0, -1.4, -0.6), deep, o({ Class = "WedgePart", Rot = CFrame.Angles(math.rad(-35), 0, 0) }))
	add(r, "TailFinLow", "Tail", V(0.6, 2, 1.6), V(0, -0.6, 1.3), V(0, 1, -0.5), deep, o({ Class = "WedgePart", Rot = CFrame.Angles(math.rad(215), 0, 0) }))
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

function MonsterRigs.Build(typeName: string, scale: number): Model
	local r = BUILD[typeName](scale)
	cartoonEyes(r)
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
