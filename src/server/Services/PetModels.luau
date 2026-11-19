-- v2.12 PET MODELS: builds every pet from its body plan (Arch) + features
-- + palette (PetDefs). 20 body plans, ~70 features, so silhouettes differ
-- pet to pet (not recoloured copies). Classic blocky/studded style.
--
-- PetModels.Build(petId) -> Model (PrimaryPart "Root", anchored; every other
-- part is welded to it, so moving Root moves the whole pet)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetDefs = require(ReplicatedStorage.Shared.PetDefs)

local PetModels = {}

local V = Vector3.new
local CF = CFrame.new
local A = CFrame.Angles
local rad = math.rad
local RGB = Color3.fromRGB
local WHITE, BLACK = RGB(255, 255, 255), RGB(25, 25, 30)

-- part helper: size, cframe relative to root, colour, kind ("Ball", "Cyl", "Wedge", "Corner", "Neon", "Glass")
local function mk(ctx, name: string, size: Vector3, cf: CFrame, color: Color3, kind: string?)
	local p
	if kind == "Wedge" then
		p = Instance.new("WedgePart")
	elseif kind == "Corner" then
		p = Instance.new("CornerWedgePart")
	else
		p = Instance.new("Part")
		if kind == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif kind == "Cyl" then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	p.Name = name
	p.Size = size * ctx.S
	p.CFrame = ctx.Root.CFrame * CFrame.new(cf.Position * ctx.S) * cf.Rotation
	p.Color = color
	p.Material = kind == "Neon" and Enum.Material.Neon or (kind == "Glass" and Enum.Material.Glass or Enum.Material.Plastic)
	if kind == "Glass" then
		p.Transparency = 0.15
	end
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	local w = Instance.new("WeldConstraint")
	w.Part0 = ctx.Root
	w.Part1 = p
	w.Parent = p
	p.Parent = ctx.Model
	return p
end

-- two eyes (white + pupil) facing -Z at a point
local function eyes(ctx, at: Vector3, spacing: number, size: number, single: boolean?)
	local list = single and { 0 } or { -spacing, spacing }
	for i, x in list do
		mk(ctx, "Eye" .. i, V(size, size, size * 0.4), CF(at + V(x, 0, 0)), WHITE)
		mk(ctx, "Pupil" .. i, V(size * 0.55, size * 0.55, size * 0.3), CF(at + V(x, -size * 0.05, -size * 0.12)), BLACK)
	end
end

------------------------------------------------------------------------
-- body plans: each sets anchors on ctx: Head (face point), HeadTop, Back,
-- Tail, Top (highest point), W (body half width)
------------------------------------------------------------------------
local ARCH = {}
ARCH.Quad = function(ctx, c1, c2)
	mk(ctx, "Body", V(1.6, 1.2, 2.2), CF(0, 1.3, 0), c1)
	mk(ctx, "Belly", V(1.3, 0.4, 1.8), CF(0, 0.75, 0), c2)
	mk(ctx, "Head", V(1.3, 1.2, 1.2), CF(0, 1.9, -1.3), c1)
	mk(ctx, "Muzzle", V(0.8, 0.5, 0.4), CF(0, 1.65, -1.95), c2)
	mk(ctx, "Nose", V(0.3, 0.2, 0.15), CF(0, 1.8, -2.18), BLACK)
	for _, p in { V(-0.55, 0.4, -0.8), V(0.55, 0.4, -0.8), V(-0.55, 0.4, 0.8), V(0.55, 0.4, 0.8) } do
		mk(ctx, "Leg", V(0.45, 0.8, 0.45), CF(p), c1)
	end
	eyes(ctx, V(0, 2.1, -1.92), 0.3, 0.32)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1.9, -1.9), V(0, 2.5, -1.3), V(0, 1.9, 0.2), V(0, 1.5, 1.1), 2.5, 0.8
end
ARCH.Biped = function(ctx, c1, c2)
	mk(ctx, "Body", V(1.5, 1.6, 1.1), CF(0, 1.6, 0), c1)
	mk(ctx, "Belly", V(1, 1, 0.2), CF(0, 1.5, -0.6), c2)
	mk(ctx, "Head", V(1.4, 1.2, 1.2), CF(0, 3, 0), c1)
	for _, x in { -0.45, 0.45 } do
		mk(ctx, "Leg", V(0.5, 0.8, 0.6), CF(x, 0.4, 0), c2)
	end
	for _, x in { -1, 1 } do
		mk(ctx, "Arm", V(0.45, 1.2, 0.45), CF(x, 1.7, 0) * A(0, 0, rad(-x * 12)), c1)
	end
	eyes(ctx, V(0, 3.1, -0.62), 0.3, 0.3)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 3, -0.6), V(0, 3.6, 0), V(0, 1.9, 0.6), V(0, 1.2, 0.6), 3.6, 1
end
ARCH.Bird = function(ctx, c1, c2)
	mk(ctx, "Body", V(1.5, 1.5, 1.5), CF(0, 1.4, 0), c1, "Ball")
	mk(ctx, "Chest", V(1, 1, 0.5), CF(0, 1.3, -0.6), c2, "Ball")
	mk(ctx, "Head", V(1.1, 1.1, 1.1), CF(0, 2.4, -0.3), c1, "Ball")
	for _, x in { -0.3, 0.3 } do
		mk(ctx, "Leg", V(0.15, 0.6, 0.15), CF(x, 0.4, 0), RGB(255, 180, 70))
	end
	eyes(ctx, V(0, 2.5, -0.82), 0.25, 0.28)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 2.3, -0.85), V(0, 2.95, -0.3), V(0, 1.9, 0.4), V(0, 1.4, 0.8), 2.9, 0.75
	ctx.Float = 1.2
end
ARCH.Fish = function(ctx, c1, c2)
	mk(ctx, "Body", V(1.2, 1.3, 2.2), CF(0, 1.6, 0), c1, "Ball")
	mk(ctx, "Belly", V(0.9, 0.6, 1.6), CF(0, 1.25, -0.1), c2, "Ball")
	eyes(ctx, V(0, 1.85, -0.95), 0.4, 0.3)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1.6, -1.1), V(0, 2.25, -0.3), V(0, 2.2, 0), V(0, 1.6, 1.1), 2.3, 0.6
	ctx.Float = 2
end
ARCH.Bug = function(ctx, c1, c2)
	mk(ctx, "Abdomen", V(1.2, 1, 1.6), CF(0, 1.1, 0.8), c1, "Ball")
	mk(ctx, "Thorax", V(1, 0.9, 0.9), CF(0, 1.2, -0.3), c2)
	mk(ctx, "Head", V(0.9, 0.8, 0.8), CF(0, 1.4, -1), c1)
	for k = -1, 1 do
		for _, x in { -1, 1 } do
			mk(ctx, "Leg", V(0.12, 0.12, 0.9), CF(x * 0.7, 0.6, k * 0.45) * A(0, rad(x * 90), rad(x * 30)), c2)
		end
	end
	eyes(ctx, V(0, 1.55, -1.4), 0.25, 0.28)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1.4, -1.4), V(0, 1.8, -1), V(0, 1.6, 0.3), V(0, 1.1, 1.6), 1.9, 0.6
end
ARCH.Blob = function(ctx, c1, c2)
	mk(ctx, "Body", V(1.9, 1.6, 1.9), CF(0, 0.9, 0), c1, "Ball")
	mk(ctx, "Base", V(2.1, 0.4, 2.1), CF(0, 0.2, 0), c2, "Cyl")
	eyes(ctx, V(0, 1.15, -0.86), 0.35, 0.36)
	mk(ctx, "Mouth", V(0.5, 0.12, 0.1), CF(0, 0.75, -0.92), BLACK)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1, -0.9), V(0, 1.7, 0), V(0, 1.4, 0.4), V(0, 0.8, 0.9), 1.7, 0.95
end
ARCH.Turtle = function(ctx, c1, c2)
	mk(ctx, "Plastron", V(1.8, 0.5, 2.2), CF(0, 0.7, 0), c1)
	mk(ctx, "Shell", V(2, 1.1, 2.4), CF(0, 1.3, 0.05), c2, "Ball")
	mk(ctx, "Head", V(0.8, 0.7, 0.9), CF(0, 0.95, -1.45), c1)
	for _, p in { V(-0.8, 0.35, -0.8), V(0.8, 0.35, -0.8), V(-0.8, 0.35, 0.8), V(0.8, 0.35, 0.8) } do
		mk(ctx, "Leg", V(0.5, 0.6, 0.5), CF(p), c1)
	end
	eyes(ctx, V(0, 1.1, -1.88), 0.22, 0.24)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1, -1.9), V(0, 1.35, -1.45), V(0, 1.9, 0), V(0, 0.8, 1.2), 1.9, 1
end
ARCH.Snail = function(ctx, c1, c2)
	mk(ctx, "Foot", V(0.9, 0.5, 2.2), CF(0, 0.3, 0), c1)
	mk(ctx, "Neck", V(0.7, 1, 0.6), CF(0, 0.9, -0.9), c1)
	mk(ctx, "Head", V(0.8, 0.7, 0.7), CF(0, 1.5, -1), c1, "Ball")
	mk(ctx, "Shell", V(0.9, 1.7, 1.7), CF(0, 1.3, 0.35), c2, "Cyl")
	eyes(ctx, V(0, 1.6, -1.32), 0.2, 0.22)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1.5, -1.35), V(0, 1.85, -1), V(0, 2.2, 0.35), V(0, 0.4, 1.1), 2.2, 0.5
end
ARCH.Shroom = function(ctx, c1, c2)
	mk(ctx, "Stem", V(1, 1.4, 1), CF(0, 0.9, 0), c2)
	mk(ctx, "Cap", V(0.6, 2.4, 2.4), CF(0, 1.9, 0) * A(0, 0, rad(90)), c1, "Cyl")
	mk(ctx, "CapTop", V(0.5, 1.6, 1.6), CF(0, 2.35, 0) * A(0, 0, rad(90)), c1:Lerp(WHITE, 0.1), "Cyl")
	eyes(ctx, V(0, 1.1, -0.52), 0.22, 0.26)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1.1, -0.5), V(0, 2.6, 0), V(0, 2.2, 0.6), V(0, 0.7, 0.5), 2.6, 1.2
end
ARCH.Orb = function(ctx, c1, c2)
	mk(ctx, "Core", V(1.4, 1.4, 1.4), CF(0, 1.8, 0), c1, "Ball")
	mk(ctx, "Glow", V(0.9, 0.9, 0.9), CF(0, 1.8, 0), c2, "Neon")
	mk(ctx, "Band", V(0.15, 2.2, 2.2), CF(0, 1.8, 0) * A(0, 0, rad(90)), c2, "Cyl")
	eyes(ctx, V(0, 1.95, -0.66), 0.25, 0.26)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1.8, -0.7), V(0, 2.5, 0), V(0, 2.2, 0.5), V(0, 1.6, 0.7), 2.5, 0.7
	ctx.Float = 1.5
end
ARCH.Puff = function(ctx, c1, c2)
	mk(ctx, "Core", V(1.5, 1.5, 1.5), CF(0, 2, 0), c1, "Ball")
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		mk(ctx, "Puff", V(0.9, 0.9, 0.9), CF(math.cos(a) * 0.75, 2 + math.sin(a * 2) * 0.2, math.sin(a) * 0.75), c1, "Ball")
	end
	eyes(ctx, V(0, 2.1, -0.75), 0.25, 0.26)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 2, -0.8), V(0, 2.75, 0), V(0, 2.4, 0.5), V(0, 1.5, 0), 2.8, 0.9
	ctx.Float = 1.4
end
ARCH.Flower = function(ctx, c1, c2)
	mk(ctx, "Stem", V(0.3, 1.8, 0.3), CF(0, 0.9, 0), RGB(90, 160, 70))
	mk(ctx, "Pot", V(1, 0.6, 1), CF(0, 0.3, 0), RGB(190, 110, 70))
	mk(ctx, "Face", V(1.1, 1.1, 0.4), CF(0, 2.2, 0), c2, "Cyl")
	eyes(ctx, V(0, 2.3, -0.24), 0.22, 0.24)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 2.2, -0.3), V(0, 3, 0), V(0, 2.2, 0.3), V(0, 0.6, 0.4), 3, 0.6
end
ARCH.Frog = function(ctx, c1, c2)
	mk(ctx, "Body", V(1.8, 1.1, 1.8), CF(0, 0.9, 0), c1, "Ball")
	mk(ctx, "Belly", V(1.3, 0.7, 1), CF(0, 0.75, -0.5), c2, "Ball")
	for _, x in { -1, 1 } do
		mk(ctx, "Thigh", V(0.6, 0.6, 1), CF(x * 0.9, 0.5, 0.4), c1, "Ball")
		mk(ctx, "Foot", V(0.6, 0.15, 0.7), CF(x * 0.95, 0.1, -0.2), c1)
	end
	eyes(ctx, V(0, 1.5, -0.55), 0.4, 0.38)
	mk(ctx, "Mouth", V(1, 0.1, 0.1), CF(0, 0.95, -0.9), BLACK)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1.1, -0.9), V(0, 1.6, -0.2), V(0, 1.4, 0.3), V(0, 0.8, 0.9), 1.7, 0.9
end
ARCH.Lizard = function(ctx, c1, c2)
	mk(ctx, "Body", V(1, 0.7, 2.2), CF(0, 0.8, 0), c1)
	mk(ctx, "Head", V(0.9, 0.6, 1), CF(0, 0.95, -1.5), c1)
	mk(ctx, "Tail1", V(0.6, 0.5, 1.2), CF(0, 0.75, 1.6) * A(rad(-5), rad(10), 0), c1)
	mk(ctx, "Tail2", V(0.35, 0.35, 1), CF(0.2, 0.7, 2.5) * A(0, rad(25), 0), c2)
	for _, p in { V(-0.65, 0.35, -0.7), V(0.65, 0.35, -0.7), V(-0.65, 0.35, 0.7), V(0.65, 0.35, 0.7) } do
		mk(ctx, "Leg", V(0.35, 0.5, 0.35), CF(p) * A(0, 0, rad(p.X > 0 and -25 or 25)), c2)
	end
	eyes(ctx, V(0, 1.2, -1.85), 0.3, 0.24)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 0.95, -2), V(0, 1.3, -1.5), V(0, 1.2, 0), V(0, 0.7, 2.6), 1.4, 0.55
end
ARCH.Crab = function(ctx, c1, c2)
	mk(ctx, "Body", V(2, 0.9, 1.5), CF(0, 0.9, 0), c1)
	mk(ctx, "Top", V(1.6, 0.4, 1.2), CF(0, 1.5, 0.05), c2)
	for k = -1, 1 do
		for _, x in { -1, 1 } do
			mk(ctx, "Leg", V(0.15, 0.15, 0.8), CF(x * 1.1, 0.5, k * 0.45) * A(0, rad(x * 90), rad(x * 35)), c1)
		end
	end
	for _, x in { -0.35, 0.35 } do
		mk(ctx, "Stalk", V(0.12, 0.5, 0.12), CF(x, 1.55, -0.6), c1)
	end
	eyes(ctx, V(0, 1.85, -0.62), 0.35, 0.25)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1, -0.8), V(0, 1.8, -0.4), V(0, 1.7, 0.1), V(0, 0.9, 0.8), 2, 1
end
ARCH.Crystal = function(ctx, c1, c2)
	mk(ctx, "Base", V(1.4, 0.6, 1.4), CF(0, 0.5, 0), c2)
	mk(ctx, "Main", V(0.9, 2, 0.9), CF(0, 1.6, 0) * A(0, rad(45), 0), c1, "Glass")
	mk(ctx, "Tip", V(0.9, 0.7, 0.45), CF(0, 2.95, 0.22) * A(0, rad(45), 0), c1:Lerp(WHITE, 0.3), "Wedge")
	eyes(ctx, V(0, 1.6, -0.68), 0.22, 0.24)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1.6, -0.7), V(0, 3.2, 0), V(0, 1.8, 0.5), V(0, 0.5, 0.6), 3.2, 0.7
end
ARCH.Jelly = function(ctx, c1, c2)
	mk(ctx, "Bell", V(1.8, 1.3, 1.8), CF(0, 2.2, 0), c1, "Glass")
	mk(ctx, "Inner", V(1, 0.7, 1), CF(0, 2.1, 0), c2, "Neon")
	eyes(ctx, V(0, 2.3, -0.86), 0.28, 0.26)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 2.2, -0.9), V(0, 2.9, 0), V(0, 2.6, 0.4), V(0, 1.4, 0), 2.9, 0.9
	ctx.Float = 1.6
end
ARCH.Drake = function(ctx, c1, c2)
	mk(ctx, "Body", V(1.3, 1.1, 2), CF(0, 1.3, 0), c1)
	mk(ctx, "Belly", V(1, 0.4, 1.6), CF(0, 0.85, -0.1), c2)
	mk(ctx, "Neck", V(0.7, 0.9, 0.7), CF(0, 2, -1) * A(rad(-25), 0, 0), c1)
	mk(ctx, "Head", V(1, 0.8, 1.2), CF(0, 2.5, -1.5), c1)
	mk(ctx, "Snout", V(0.6, 0.4, 0.5), CF(0, 2.35, -2.2), c1)
	mk(ctx, "Tail", V(0.5, 0.5, 1.6), CF(0, 1.2, 1.6) * A(rad(10), 0, 0), c1)
	for _, p in { V(-0.5, 0.4, -0.6), V(0.5, 0.4, -0.6), V(-0.5, 0.4, 0.6), V(0.5, 0.4, 0.6) } do
		mk(ctx, "Leg", V(0.4, 0.8, 0.4), CF(p), c1)
	end
	eyes(ctx, V(0, 2.7, -2.08), 0.28, 0.26)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 2.5, -2.1), V(0, 2.95, -1.5), V(0, 1.9, 0), V(0, 1.2, 2.4), 3, 0.7
end
ARCH.Star = function(ctx, c1, c2)
	mk(ctx, "Core", V(0.6, 1.2, 1.2), CF(0, 1.6, 0) * A(0, rad(90), 0), c1, "Cyl")
	eyes(ctx, V(0, 1.7, -0.32), 0.22, 0.24)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1.6, -0.35), V(0, 2.8, 0), V(0, 1.6, 0.3), V(0, 0.6, 0.2), 2.8, 0.6
	ctx.Float = 1
	ctx.Spin = true
end
ARCH.Octo = function(ctx, c1, c2)
	mk(ctx, "Head", V(1.6, 1.8, 1.6), CF(0, 1.9, 0.1), c1, "Ball")
	eyes(ctx, V(0, 1.8, -0.72), 0.38, 0.4)
	ctx.Head, ctx.HeadTop, ctx.Back, ctx.Tail, ctx.Top, ctx.W = V(0, 1.8, -0.8), V(0, 2.8, 0.1), V(0, 2.4, 0.6), V(0, 1, 0.6), 2.8, 0.8
	ctx.Float = 0.8
end

------------------------------------------------------------------------
-- features (silhouette pieces); c1 main, c2 second, c3 accent
------------------------------------------------------------------------
local F = {}
local function hp(ctx, off: Vector3): CFrame
	return CF(ctx.HeadTop + off)
end
F.EarsRound = function(ctx, c1, c2) for _, x in { -0.45, 0.45 } do mk(ctx, "Ear", V(0.45, 0.45, 0.2), hp(ctx, V(x, 0, 0)), c1, "Ball") end end
F.EarsPointy = function(ctx, c1, c2) for _, x in { -0.4, 0.4 } do mk(ctx, "Ear", V(0.35, 0.6, 0.3), hp(ctx, V(x, 0.15, 0)), c1, "Wedge") end end
F.EarsLong = function(ctx, c1, c2, c3) for _, x in { -0.3, 0.3 } do mk(ctx, "Ear", V(0.3, 1.3, 0.2), hp(ctx, V(x, 0.55, 0.1)) * A(rad(-15), 0, rad(x * 30)), c1); mk(ctx, "EarIn", V(0.15, 0.9, 0.1), hp(ctx, V(x, 0.55, 0.0)) * A(rad(-15), 0, rad(x * 30)), c3) end end
F.EarsBig = function(ctx, c1, c2, c3) for _, x in { -0.5, 0.5 } do mk(ctx, "Ear", V(0.6, 1, 0.25), hp(ctx, V(x, 0.4, 0)) * A(0, 0, rad(x * 30)), c1, "Wedge") end end
F.EarsFloppy = function(ctx, c1) for _, x in { -0.55, 0.55 } do mk(ctx, "Ear", V(0.4, 0.6, 0.2), hp(ctx, V(x, -0.3, -0.1)) * A(0, 0, rad(x * 60)), c1) end end
F.TailStub = function(ctx, c1) mk(ctx, "Tail", V(0.35, 0.35, 0.35), CF(ctx.Tail), c1, "Ball") end
F.TailPuff = function(ctx, c1) mk(ctx, "Tail", V(0.7, 0.7, 0.7), CF(ctx.Tail), c1, "Ball") end
F.TailLong = function(ctx, c1, c2) mk(ctx, "Tail", V(0.15, 0.15, 1.8), CF(ctx.Tail + V(0, 0.1, 0.8)) * A(rad(15), 0, 0), c2) end
F.TailFluffy = function(ctx, c1, c2) mk(ctx, "Tail", V(0.6, 0.6, 1.4), CF(ctx.Tail + V(0, 0.4, 0.6)) * A(rad(35), 0, 0), c1, "Ball"); mk(ctx, "TailTip", V(0.45, 0.45, 0.45), CF(ctx.Tail + V(0, 0.9, 1.2)), c2, "Ball") end
F.CrystalTail = function(ctx, c1, c2, c3) mk(ctx, "TailCrystal", V(0.35, 0.8, 0.35), CF(ctx.Tail + V(0, 1.2, 1.4)) * A(rad(30), rad(45), 0), c3, "Glass") end
F.FlameTail = function(ctx, c1, c2, c3) mk(ctx, "Tail", V(0.2, 0.2, 1), CF(ctx.Tail + V(0, 0.3, 0.4)) * A(rad(40), 0, 0), c1); mk(ctx, "Flame", V(0.5, 0.7, 0.5), CF(ctx.Tail + V(0, 0.8, 0.8)), c2, "Neon"); mk(ctx, "FlameTip", V(0.3, 0.4, 0.3), CF(ctx.Tail + V(0, 1.2, 0.85)), c3, "Neon") end
F.TailFin = function(ctx, c1, c2) mk(ctx, "TailFin", V(0.15, 1.1, 0.9), CF(ctx.Tail + V(0, 0, 0.4)), c2, "Wedge"); mk(ctx, "TailFin2", V(0.15, 1.1, 0.9), CF(ctx.Tail + V(0, 0, 0.4)) * A(rad(180), 0, 0), c2, "Wedge") end
F.LongTail = function(ctx, c1, c2) for k = 1, 3 do mk(ctx, "TailSeg", V(0.25, 0.25, 0.7), CF(ctx.Tail + V(0, 0, k * 0.65)), k % 2 == 0 and c1 or c2) end end
F.Pebbles = function(ctx, c1, c2, c3) for k = 1, 4 do mk(ctx, "Pebble", V(0.45, 0.35, 0.45), CF(ctx.Back + V(-0.45 + (k % 2) * 0.9, 0.05, -0.6 + k * 0.3)), k % 2 == 0 and c2 or c3, "Ball") end end
F.Clover = function(ctx, c1, c2, c3) mk(ctx, "CloverStem", V(0.1, 0.5, 0.1), hp(ctx, V(0, 0.25, 0)), c2); for k = 0, 3 do local a = k * math.pi / 2; mk(ctx, "Leaf", V(0.4, 0.1, 0.4), hp(ctx, V(math.cos(a) * 0.25, 0.55, math.sin(a) * 0.25)), RGB(90, 200, 90), "Ball") end end
F.Seeds = function(ctx, c1, c2, c3) for k = 1, 10 do local a = k * 2.4; local y = (k % 3) * 0.35; mk(ctx, "Seed", V(0.1, 0.6, 0.1), CF(V(0, 2, 0) + V(math.cos(a) * 0.9, 0.4 + y, math.sin(a) * 0.9)) * A(math.sin(a) * 0.7, 0, -math.cos(a) * 0.7), c1); mk(ctx, "Fluff", V(0.3, 0.3, 0.3), CF(V(0, 2, 0) + V(math.cos(a) * 1.15, 0.7 + y, math.sin(a) * 1.15)), WHITE, "Ball") end end
F.Stem = function(ctx, c1, c2, c3) mk(ctx, "Stem", V(0.15, 1.2, 0.15), CF(0, 0.9, 0), c3) end
F.Antenna = function(ctx, c1, c2, c3) for _, x in { -0.2, 0.2 } do mk(ctx, "Antenna", V(0.08, 0.8, 0.08), hp(ctx, V(x, 0.4, -0.1)) * A(rad(-20), 0, rad(x * 60)), c2); mk(ctx, "AntennaTip", V(0.2, 0.2, 0.2), hp(ctx, V(x * 2.2, 0.8, -0.25)), c3, "Ball") end end
F.LongLegs = function(ctx, c1, c2) for _, x in { -1, 1 } do mk(ctx, "HopLeg", V(0.2, 0.2, 1.4), CF(x * 0.7, 1.4, 0.9) * A(rad(50), 0, 0), c2); mk(ctx, "HopShin", V(0.15, 0.15, 1.2), CF(x * 0.75, 0.7, 1.2) * A(rad(-40), 0, 0), c2) end end
F.Straw = function(ctx, c1, c2, c3) for k = 1, 5 do mk(ctx, "Straw", V(0.06, 0.06, 1.2), CF(ctx.Back + V(-0.4 + k * 0.15, 0.1, 0)) * A(0, rad(k * 25), 0), RGB(240, 220, 140)) end end
F.Snout = function(ctx, c1, c2) mk(ctx, "Snout", V(0.5, 0.4, 0.4), CF(ctx.Head + V(0, -0.2, -0.25)), c2); mk(ctx, "Nostril", V(0.3, 0.1, 0.05), CF(ctx.Head + V(0, -0.15, -0.46)), BLACK) end
F.Claws = function(ctx, c1, c2, c3) for _, x in { -0.55, 0.55 } do for k = -1, 1 do mk(ctx, "Claw", V(0.1, 0.1, 0.35), CF(x + k * 0.12, 0.05, -1.05), c3) end end end
F.MesaHat = function(ctx, c1, c2, c3) mk(ctx, "HatBase", V(1, 0.4, 1), hp(ctx, V(0, 0.2, 0)), c2); mk(ctx, "HatTop", V(1.1, 0.15, 1.1), hp(ctx, V(0, 0.45, 0)), c3) end
F.Petals = function(ctx, c1, c2, c3) for k = 0, 9 do local a = k / 10 * math.pi * 2; mk(ctx, "Petal", V(0.25, 0.7, 0.15), CF(V(0, 2.2, 0.05) + V(math.cos(a) * 0.85, math.sin(a) * 0.85, 0)) * A(0, 0, a - math.pi / 2), c1, "Wedge") end end
F.Leaves = function(ctx, c1, c2, c3) for _, x in { -1, 1 } do mk(ctx, "Leaf", V(0.7, 0.1, 0.35), CF(x * 0.4, 1, 0) * A(0, 0, rad(x * -25)), c3) end end
F.Rune = function(ctx, c1, c2, c3) mk(ctx, "Rune", V(0.6, 0.6, 0.1), CF(0, 1.7, -0.62), c3, "Neon") end
F.Ruins = function(ctx, c1, c2, c3) for _, x in { -0.4, 0.4 } do mk(ctx, "RuinPillar", V(0.2, 0.6, 0.2), CF(ctx.Back + V(x, 0.4, 0)), WHITE) end; mk(ctx, "RuinTop", V(1, 0.15, 0.25), CF(ctx.Back + V(0, 0.75, 0)), WHITE) end
F.MesaBack = function(ctx, c1, c2, c3) mk(ctx, "Mesa", V(1.6, 0.3, 1), CF(ctx.Back + V(0, 0.1, 0)), c3); mk(ctx, "MesaSide", V(1.5, 0.3, 0.9), CF(ctx.Back + V(0, -0.15, 0)), c2) end
F.BigFists = function(ctx, c1, c2) for _, x in { -1.05, 1.05 } do mk(ctx, "Fist", V(0.75, 0.75, 0.75), CF(x * 1.05, 1, 0), c2) end end
F.Mane = function(ctx, c1, c2, c3) mk(ctx, "Mane", V(1.5, 0.9, 0.7), CF(ctx.HeadTop + V(0, -0.5, 0.5)), c2, "Ball") end
F.Shaggy = function(ctx, c1, c2) for k = 1, 4 do mk(ctx, "Shag", V(0.5, 0.4, 0.5), CF(ctx.Back + V(-0.5 + k * 0.25, -0.1, -0.5 + (k % 2) * 0.6)), c2, "Ball") end end
F.HornsCurved = function(ctx, c1, c2, c3) for _, x in { -1, 1 } do mk(ctx, "Horn", V(0.25, 0.25, 0.8), hp(ctx, V(x * 0.55, 0, 0.1)) * A(rad(30), rad(x * 60), 0), c3); mk(ctx, "HornTip", V(0.2, 0.2, 0.5), hp(ctx, V(x * 0.9, 0.2, 0.35)) * A(rad(-40), rad(x * 30), 0), c3) end end
F.HornsRam = function(ctx, c1, c2, c3) for _, x in { -1, 1 } do for k = 0, 3 do local a = k * 1.4; mk(ctx, "Horn", V(0.32, 0.32, 0.32), hp(ctx, V(x * (0.55 + math.sin(a) * 0.3), -math.cos(a) * 0.3 + 0.1, math.sin(a + 1) * 0.3)), c3, "Ball") end end end
F.HornsIce = function(ctx, c1, c2, c3) for _, x in { -0.35, 0.35 } do mk(ctx, "Horn", V(0.2, 0.9, 0.2), hp(ctx, V(x, 0.4, 0)) * A(0, 0, rad(x * 40)), c3, "Glass") end end
F.HornsBack = function(ctx, c1, c2, c3) for _, x in { -0.25, 0.25 } do mk(ctx, "Horn", V(0.15, 0.15, 0.8), hp(ctx, V(x, 0.1, 0.4)) * A(rad(30), 0, 0), c3) end end
F.Hooves = function(ctx, c1, c2) for _, p in { V(-0.55, 0.05, -0.8), V(0.55, 0.05, -0.8), V(-0.55, 0.05, 0.8), V(0.55, 0.05, 0.8) } do mk(ctx, "Hoof", V(0.5, 0.2, 0.5), CF(p), BLACK) end end
F.Tufts = function(ctx, c1, c2) for _, x in { -0.35, 0.35 } do mk(ctx, "Tuft", V(0.2, 0.5, 0.3), hp(ctx, V(x, 0.15, 0)) * A(0, 0, rad(x * 50)), c2, "Wedge") end end
F.Halo = function(ctx, c1, c2, c3) mk(ctx, "Halo", V(0.1, 1.1, 1.1), hp(ctx, V(0, 0.5, 0)) * A(0, 0, rad(90)), c3, "Neon") end
F.BigEyes = function(ctx) mk(ctx, "Brow", V(1, 0.1, 0.1), CF(ctx.Head + V(0, 0.45, -0.05)), BLACK) end
F.IceShell = function(ctx, c1, c2, c3) for k = 1, 4 do mk(ctx, "Ice", V(0.35, 0.7, 0.35), CF(ctx.Back + V(-0.5 + (k % 2) * 1, 0.2, -0.4 + k * 0.2)) * A(0, rad(45), rad(15)), c3, "Glass") end end
F.Crystals = function(ctx, c1, c2, c3) for k = 1, 3 do mk(ctx, "Crystal", V(0.25, 0.6, 0.25), CF(ctx.Back + V(-0.3 + k * 0.15, 0.25, -0.2 + k * 0.15)) * A(rad(k * 10), rad(45), rad(-15 + k * 10)), c3, "Glass") end end
F.Helm = function(ctx, c1, c2, c3) mk(ctx, "Helm", V(1.5, 0.6, 1.3), hp(ctx, V(0, -0.15, 0)), c2); mk(ctx, "Visor", V(1, 0.15, 0.1), CF(ctx.Head + V(0, 0.3, -0.05)), c3, "Neon") end
F.Shield = function(ctx, c1, c2, c3) mk(ctx, "Shield", V(0.2, 1.2, 0.9), CF(-1.25, 1.6, -0.2), c3, "Glass") end
F.CapSpots = function(ctx, c1, c2, c3) for k = 1, 4 do local a = k * 1.6; mk(ctx, "Spot", V(0.35, 0.1, 0.35), CF(math.cos(a) * 0.6, 2.62, math.sin(a) * 0.6), c3) end end
F.Feet = function(ctx, c1, c2) for _, x in { -0.3, 0.3 } do mk(ctx, "Foot", V(0.4, 0.25, 0.55), CF(x, 0.12, -0.1), c2) end end
F.MossShell = function(ctx, c1, c2, c3) mk(ctx, "Moss", V(0.95, 0.4, 1.2), CF(ctx.Back + V(0, -0.1, 0)), RGB(90, 160, 80)); mk(ctx, "Bloom", V(0.3, 0.3, 0.3), CF(ctx.Back + V(0.15, 0.15, 0)), RGB(255, 200, 230), "Ball") end
F.GlowCap = function(ctx, c1, c2, c3) mk(ctx, "GlowRim", V(0.15, 2.5, 2.5), CF(0, 1.62, 0) * A(0, 0, rad(90)), c3, "Neon") end
F.BackShroom = function(ctx, c1, c2, c3) mk(ctx, "TruffleStem", V(0.25, 0.4, 0.25), CF(ctx.Back + V(0, 0.2, 0)), RGB(240, 230, 210)); mk(ctx, "Truffle", V(0.25, 0.7, 0.7), CF(ctx.Back + V(0, 0.45, 0)) * A(0, 0, rad(90)), c3, "Cyl") end
F.ShroomRing = function(ctx, c1, c2, c3) for k = 1, 5 do local a = k / 5 * math.pi * 2; mk(ctx, "MiniStem", V(0.15, 0.3, 0.15), CF(math.cos(a) * 1.2, 1.2, math.sin(a) * 1.2), WHITE); mk(ctx, "MiniCap", V(0.15, 0.5, 0.5), CF(math.cos(a) * 1.2, 1.4, math.sin(a) * 1.2) * A(0, 0, rad(90)), c2, "Cyl") end end
F.Wings = function(ctx, c1, c2, c3) for _, x in { -1, 1 } do mk(ctx, "Wing", V(0.12, 0.9, 1.2), CF(ctx.Back + V(x * (ctx.W + 0.1), 0, 0)) * A(0, 0, rad(x * -35)), c2, "Wedge") end end
F.WingsBig = function(ctx, c1, c2, c3) for _, x in { -1, 1 } do mk(ctx, "Wing", V(0.1, 1.6, 1.4), CF(ctx.Back + V(x * 1, 0.4, 0)) * A(0, 0, rad(x * -55)), c2); mk(ctx, "WingSpot", V(0.12, 0.45, 0.45), CF(ctx.Back + V(x * 1.35, 0.65, 0)) * A(0, 0, rad(x * -55)), c3, "Neon") end end
F.Wings4 = function(ctx, c1, c2, c3) for _, x in { -1, 1 } do for k = 0, 1 do mk(ctx, "Wing", V(1.4, 0.05, 0.4), CF(ctx.Back + V(x * 0.9, 0.2, -0.3 + k * 0.6)) * A(0, rad(x * (k == 0 and -15 or 15)), 0), c3, "Glass") end end end
F.BatWings = function(ctx, c1, c2, c3) for _, x in { -1, 1 } do mk(ctx, "Wing", V(1.2, 0.08, 0.9), CF(ctx.Back + V(x * 1.1, 0.1, 0)) * A(0, 0, rad(x * 20)), c2); mk(ctx, "WingTip", V(0.5, 0.06, 0.5), CF(ctx.Back + V(x * 1.75, 0.35, 0.2)) * A(0, rad(45), rad(x * 30)), c2, "Wedge") end end
F.Fluff = function(ctx, c1) mk(ctx, "Collar", V(1.2, 0.5, 1), CF(ctx.Head + V(0, -0.3, 0.6)), WHITE, "Ball") end
F.CapHelm = function(ctx, c1, c2, c3) mk(ctx, "CapHelm", V(0.4, 1.8, 1.8), hp(ctx, V(0, 0, 0)) * A(0, 0, rad(90)), c1, "Cyl"); mk(ctx, "CapSpot", V(0.3, 0.1, 0.3), hp(ctx, V(0.35, 0.22, 0)), WHITE) end
F.Sword = function(ctx, c1, c2, c3) mk(ctx, "Blade", V(0.15, 1.4, 0.1), CF(1.15, 1.9, -0.4), RGB(150, 110, 70)); mk(ctx, "Guard", V(0.5, 0.12, 0.12), CF(1.15, 1.25, -0.4), c3, "Neon") end
F.Crown = function(ctx, c1, c2, c3) mk(ctx, "CrownBand", V(0.9, 0.3, 0.9), hp(ctx, V(0, 0.15, 0)), RGB(255, 210, 60)); for k = 0, 3 do local a = k * math.pi / 2; mk(ctx, "CrownPoint", V(0.18, 0.35, 0.18), hp(ctx, V(math.cos(a) * 0.35, 0.45, math.sin(a) * 0.35)), RGB(255, 210, 60)) end; mk(ctx, "Gem", V(0.2, 0.2, 0.1), hp(ctx, V(0, 0.15, -0.46)), RGB(255, 60, 90), "Neon") end
F.Beard = function(ctx, c1, c2) mk(ctx, "Beard", V(0.7, 0.5, 0.3), CF(ctx.Head + V(0, -0.45, -0.05)), c2, "Wedge") end
F.Bolt = function(ctx, c1, c2, c3) mk(ctx, "Bolt1", V(0.15, 0.6, 0.15), CF(ctx.Tail + V(0, 0.4, 0.3)) * A(0, 0, rad(30)), c3, "Neon"); mk(ctx, "Bolt2", V(0.15, 0.6, 0.15), CF(ctx.Tail + V(0.1, 0, 0.5)) * A(0, 0, rad(-30)), c3, "Neon") end
F.Reed = function(ctx, c1, c2, c3) mk(ctx, "Reed", V(0.08, 0.08, 1.4), CF(ctx.Head + V(0.3, -0.25, -0.1)) * A(0, rad(70), 0), c3); mk(ctx, "Cattail", V(0.18, 0.18, 0.4), CF(ctx.Head + V(0.9, -0.25, 0.1)) * A(0, rad(70), 0), RGB(120, 80, 50)) end
F.Bubble = function(ctx, c1, c2, c3) mk(ctx, "Bubble", V(0.7, 0.7, 0.7), CF(ctx.Head + V(0.4, 0.3, -0.4)), c3, "Glass") end
F.LilyPad = function(ctx, c1, c2, c3) mk(ctx, "Lily", V(0.12, 1.8, 1.8), CF(ctx.Back + V(0, 0.05, 0)) * A(0, 0, rad(90)), RGB(90, 170, 90), "Cyl") end
F.Flower = function(ctx, c1, c2, c3) mk(ctx, "Flower", V(0.45, 0.45, 0.45), CF(ctx.Back + V(0.3, 0.25, 0)), c3, "Ball"); mk(ctx, "FlowerMid", V(0.2, 0.2, 0.2), CF(ctx.Back + V(0.3, 0.45, 0)), RGB(255, 230, 80), "Ball") end
F.Drips = function(ctx, c1) for k = 1, 3 do local a = k * 2.1; mk(ctx, "Drip", V(0.3, 0.5, 0.3), CF(math.cos(a) * 0.85, 0.6, math.sin(a) * 0.85), c1, "Ball") end end
F.Puddle = function(ctx, c1, c2) mk(ctx, "Puddle", V(0.1, 2.8, 2.8), CF(0, 0.05, 0) * A(0, 0, rad(90)), c2, "Cyl") end
F.Crest = function(ctx, c1, c2, c3) for k = 0, 4 do mk(ctx, "Crest", V(0.1, 0.4, 0.3), CF(ctx.Back + V(0, 0.15, -0.8 + k * 0.4)), c2, "Wedge") end end
F.Sac = function(ctx, c1, c2, c3) mk(ctx, "Sac", V(0.9, 0.7, 0.6), CF(ctx.Head + V(0, -0.4, 0.15)), c3, "Glass") end
F.Shards = function(ctx, c1, c2, c3) for k = 1, 3 do local a = k * 2.1; mk(ctx, "Shard", V(0.35, 1, 0.35), CF(math.cos(a) * 0.55, 1.4, math.sin(a) * 0.55) * A(math.sin(a) * 0.5, rad(45), -math.cos(a) * 0.5), c1, "Glass") end end
F.Pincers = function(ctx, c1, c2, c3) for _, x in { -1, 1 } do mk(ctx, "Arm", V(0.25, 0.25, 0.7), CF(x * 0.95, 1, -0.9), c1); mk(ctx, "Pincer", V(0.5, 0.35, 0.6), CF(x * 1.05, 1.1, -1.35), c1); mk(ctx, "PincerTip", V(0.2, 0.15, 0.4), CF(x * 1.05, 1.32, -1.5), c3) end end
F.Geode = function(ctx, c1, c2, c3) for k = 1, 4 do mk(ctx, "GeodeCrystal", V(0.25, 0.5, 0.25), CF(ctx.Back + V(-0.4 + k * 0.2, 0.15, -0.1 + (k % 2) * 0.25)) * A(0, rad(45), 0), c2, "Glass") end end
F.Tentacles = function(ctx, c1, c2) for k = 1, 6 do local a = k / 6 * math.pi * 2; mk(ctx, "Tentacle", V(0.18, 1.1, 0.18), CF(math.cos(a) * 0.5, ctx.Tail.Y - 0.2, math.sin(a) * 0.5) * A(math.sin(a) * 0.25, 0, -math.cos(a) * 0.25), c2) end end
F.Glow = function(ctx, c1, c2, c3) mk(ctx, "GlowCore", V(0.35, 0.35, 0.35), CF(ctx.Back + V(0, 0.15, 0)), c3, "Neon") end
F.Spikes = function(ctx, c1, c2, c3) for k = 1, 5 do mk(ctx, "Spike", V(0.15, 0.5, 0.35), CF(ctx.Back + V(0, 0.2, -0.8 + k * 0.32)), c2, "Wedge") end end
F.Smoke = function(ctx, c1) mk(ctx, "SmokePuff", V(0.6, 0.6, 0.6), CF(ctx.HeadTop + V(0, 0.4, 0.2)), RGB(120, 115, 115), "Ball") end
F.GlowShell = function(ctx, c1, c2) for k = 1, 3 do mk(ctx, "Seam", V(0.1, 0.1, 1.2), CF(ctx.Back + V(-0.3 + k * 0.15, -0.05, 0.5)), c2, "Neon") end end
F.Horn = function(ctx, c1, c2, c3) mk(ctx, "Horn", V(0.15, 0.15, 1.3), CF(ctx.Head + V(0, 0.2, -0.6)) * A(rad(15), 0, 0), c3) end
F.Whiskers = function(ctx, c1, c2, c3) for _, x in { -1, 1 } do mk(ctx, "Whisker", V(0.05, 0.05, 0.9), CF(ctx.Head + V(x * 0.4, -0.1, 0.1)) * A(rad(20), rad(x * 50), 0), c3) end end
F.Flame = function(ctx, c1, c2, c3) mk(ctx, "Flame", V(0.6, 0.9, 0.6), CF(ctx.Back + V(0, 0.4, 0)), c2, "Neon"); mk(ctx, "FlameTip", V(0.35, 0.5, 0.35), CF(ctx.Back + V(0, 0.95, 0)), c3, "Neon") end
F.Spots = function(ctx, c1, c2) for k = 1, 4 do mk(ctx, "Spot", V(0.25, 0.08, 0.25), CF(ctx.Back + V(-0.3 + (k % 2) * 0.6, 0, -0.5 + k * 0.25)), c2) end end
F.VolcanoShell = function(ctx, c1, c2, c3) mk(ctx, "Volcano", V(1, 0.7, 1), CF(ctx.Back + V(0, 0.2, 0)), c2); mk(ctx, "VolcanoTop", V(0.6, 0.3, 0.6), CF(ctx.Back + V(0, 0.65, 0)), c2); mk(ctx, "Lava", V(0.4, 0.1, 0.4), CF(ctx.Back + V(0, 0.82, 0)), c3, "Neon") end
F.SpiralShell = function(ctx, c1, c2, c3) mk(ctx, "Whorl", V(0.7, 1.1, 1.1), CF(ctx.Back + V(0.15, -0.5, 0)) * A(0, 0, 0), c3, "Cyl"); mk(ctx, "WhorlTip", V(0.5, 0.5, 0.5), CF(ctx.Back + V(0.35, -0.3, 0)), c2, "Ball") end
F.Round = function(ctx, c1) mk(ctx, "Puffed", V(1.5, 1.5, 1.8), CF(0, 1.6, 0), c1, "Ball") end
F.Beak = function(ctx, c1, c2, c3) mk(ctx, "Beak", V(0.3, 0.25, 0.5), CF(ctx.Head + V(0, -0.05, -0.15)), c3, "Wedge") end
F.Arms5 = function(ctx, c1, c2) for k = 0, 4 do local a = k / 5 * math.pi * 2; mk(ctx, "StarArm", V(0.5, 1, 0.4), CF(0, 1.6, 0) * A(0, 0, a) * CF(0, 0.9, 0), c1, "Wedge") end end
F.Face = function(ctx) mk(ctx, "Smile", V(0.4, 0.08, 0.05), CF(ctx.Head + V(0, -0.2, -0.03)), BLACK) end
F.Coral = function(ctx, c1, c2, c3) for k = 1, 3 do mk(ctx, "Coral", V(0.15, 0.6, 0.15), CF(ctx.Back + V(-0.3 + k * 0.2, 0.3, 0)) * A(0, 0, rad(-20 + k * 15)), c3) end end
F.ShellArmor = function(ctx, c1, c2, c3) mk(ctx, "Chestplate", V(1.3, 1, 0.2), CF(0, 1.7, -0.62), c2); mk(ctx, "Pauldron", V(0.6, 0.4, 0.6), CF(-0.95, 2.3, 0), c2, "Ball"); mk(ctx, "Pauldron", V(0.6, 0.4, 0.6), CF(0.95, 2.3, 0), c2, "Ball") end
F.Trident = function(ctx, c1, c2, c3) mk(ctx, "Shaft", V(0.12, 2.4, 0.12), CF(1.25, 2, -0.3), c3); for x = -1, 1 do mk(ctx, "Prong", V(0.1, 0.5, 0.1), CF(1.25 + x * 0.18, 3.35, -0.3), c3) end end
F.QuartzShell = function(ctx, c1, c2, c3) for k = 1, 5 do local a = k * 1.25; mk(ctx, "Quartz", V(0.3, 0.9, 0.3), CF(ctx.Back + V(math.cos(a) * 0.5, 0.2, math.sin(a) * 0.5)) * A(math.sin(a) * 0.4, rad(45), -math.cos(a) * 0.4), c3, "Glass") end end
F.CrystalRing = function(ctx, c1, c2, c3) for k = 1, 6 do local a = k / 6 * math.pi * 2; mk(ctx, "Orbiter", V(0.25, 0.6, 0.25), CF(math.cos(a) * 1.3, 1.8 + math.sin(a * 3) * 0.2, math.sin(a) * 1.3) * A(0, -a, rad(20)), k % 2 == 0 and c1 or c2, "Glass") end end
F.Sprig = function(ctx, c1, c2, c3) mk(ctx, "Sprig", V(0.1, 0.6, 0.1), hp(ctx, V(0, 0.3, 0)), c3); mk(ctx, "Needle", V(0.4, 0.08, 0.08), hp(ctx, V(0, 0.5, 0)), c3) end
F.Scales = function(ctx, c1, c2) for k = 1, 6 do local a = k * 1.05; mk(ctx, "Scale", V(0.5, 0.3, 0.2), CF(math.cos(a) * 0.85, 0.7 + (k % 3) * 0.35, math.sin(a) * 0.85) * A(0, -a, 0), c2, "Wedge") end end

------------------------------------------------------------------------
local RARITY_SCALE = { Common = 1, Uncommon = 1.08, Rare = 1.16, Epic = 1.26, Legendary = 1.38 }

function PetModels.Build(petId: string): Model
	local def = PetDefs.Types[petId]
	local model = Instance.new("Model")
	model.Name = petId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.5
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local ctx = { Model = model, Root = root, S = 0.9 * (RARITY_SCALE[def.Rarity] or 1) }
	local c1, c2, c3 = def.Palette[1], def.Palette[2], def.Palette[3]
	local arch = ARCH[def.Arch] or ARCH.Blob
	arch(ctx, c1, c2, c3)
	for _, f in def.Features do
		local fn = F[f]
		if fn then
			fn(ctx, c1, c2, c3)
		end
	end
	model:SetAttribute("PetId", petId)
	model:SetAttribute("Float", (ctx.Float or 0) * ctx.S)
	model:SetAttribute("Spin", ctx.Spin == true)
	-- rarity sparkle for Rare+
	if def.Rarity ~= "Common" and def.Rarity ~= "Uncommon" then
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(PetDefs.RARITY[def.Rarity].Color)
		e.Rate = def.Rarity == "Legendary" and 8 or 3
		e.Size = NumberSequence.new(0.35, 0)
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e.Parent = root
	end
	return model
end

-- a blocky studded egg (pickups, carried eggs, the incubator, hatching).
-- v2.13 (director: larger + much more detailed): an 11-layer stepped egg
-- silhouette in alternating shades, a zig-zag crack band, raised spots,
-- glowing seam rings and a themed topper per boss egg
local EGG_TOPPER = {}
EGG_TOPPER.Plateau = function(ctx, c1, c2) mk(ctx, "Sprout", V(0.25, 0.9, 0.25), CF(0, 6.3, 0), RGB(90, 170, 70)); for _, x in { -1, 1 } do mk(ctx, "Leaf", V(0.8, 0.12, 0.4), CF(x * 0.4, 6.6, 0) * A(0, 0, rad(x * -25)), RGB(110, 200, 90)) end end
EGG_TOPPER.Mountains = function(ctx, c1, c2) mk(ctx, "SnowCap", V(1.6, 0.5, 1.6), CF(0, 6, 0), WHITE); for k = 0, 5 do local a = k / 6 * math.pi * 2; mk(ctx, "Icicle", V(0.2, 0.7, 0.2), CF(math.cos(a) * 1.35, 4.9, math.sin(a) * 1.35) * A(math.pi, 0, 0), RGB(200, 235, 255), "Glass") end end
EGG_TOPPER.Mushroom = function(ctx, c1, c2) mk(ctx, "Cap", V(0.5, 2.2, 2.2), CF(0, 6.2, 0) * A(0, 0, rad(90)), c1, "Cyl"); for k = 1, 4 do local a = k * 1.57; mk(ctx, "CapSpot", V(0.35, 0.1, 0.35), CF(math.cos(a) * 0.6, 6.48, math.sin(a) * 0.6), WHITE) end end
EGG_TOPPER.Marsh = function(ctx, c1, c2) mk(ctx, "Rod", V(0.15, 1.4, 0.15), CF(0, 6.5, 0), RGB(200, 200, 210)); mk(ctx, "Spark", V(0.45, 0.45, 0.45), CF(0, 7.3, 0), c2, "Neon") end
EGG_TOPPER.Canyon = function(ctx, c1, c2) for k = 0, 4 do local a = k / 5 * math.pi * 2; mk(ctx, "Crystal", V(0.3, 1, 0.3), CF(math.cos(a) * 0.35, 6.3, math.sin(a) * 0.35) * A(math.sin(a) * 0.35, rad(45), -math.cos(a) * 0.35), k % 2 == 0 and c1 or c2, "Glass") end end
EGG_TOPPER.Volcanic = function(ctx, c1, c2) mk(ctx, "Crater", V(1.2, 0.4, 1.2), CF(0, 6.05, 0), c1); mk(ctx, "Lava", V(0.8, 0.1, 0.8), CF(0, 6.3, 0), c2, "Neon"); for k = 1, 3 do local a = k * 2.1; mk(ctx, "LavaCrack", V(0.12, 1.6, 0.1), CF(math.cos(a) * 1.18, 3.4, math.sin(a) * 1.18) * A(0, -a, rad(15)), c2, "Neon") end end
EGG_TOPPER.Coast = function(ctx, c1, c2) mk(ctx, "Shell", V(0.6, 1.1, 1.1), CF(0, 6.3, 0) * A(0, rad(90), 0), RGB(255, 190, 200), "Cyl"); mk(ctx, "ShellTip", V(0.45, 0.45, 0.45), CF(0.1, 6.9, 0), RGB(255, 220, 230), "Ball") end

function PetModels.Egg(eggKey: string, scale: number?, nest: boolean?): Model
	local e = PetDefs.Eggs[eggKey]
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = eggKey .. "Egg"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.5
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root
	local ctx = { Model = model, Root = root, S = s }
	local c1, c2 = e.Color, e.Color2
	-- stepped egg silhouette (wider below the middle, narrow pointed top)
	local rows = { { 0.3, 1.4 }, { 0.8, 2 }, { 1.3, 2.4 }, { 1.8, 2.65 }, { 2.3, 2.75 }, { 2.8, 2.7 }, { 3.3, 2.5 }, { 3.8, 2.2 }, { 4.3, 1.8 }, { 4.8, 1.3 }, { 5.3, 0.8 } }
	for i, r in rows do
		local shade = (i % 2 == 0) and c1 or c1:Lerp(Color3.new(1, 1, 1), 0.1)
		mk(ctx, "Layer" .. i, V(r[2], 0.55, r[2]), CF(0, r[1], 0), shade)
		-- corner blocks rotated 45° round the silhouette off
		mk(ctx, "LayerR" .. i, V(r[2] * 0.82, 0.5, r[2] * 0.82), CF(0, r[1], 0) * A(0, rad(45), 0), shade)
	end
	-- zig-zag crack band in the second colour
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		mk(ctx, "Zig" .. k, V(0.5, 0.35, 0.2), CF(math.cos(a) * 1.38, 2.8 + (k % 2) * 0.3, math.sin(a) * 1.38) * A(0, -a + math.pi / 2, rad(k % 2 == 0 and 30 or -30)), c2)
	end
	-- raised spots
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + 0.3
		local y = (k % 2 == 0) and 1.6 or 4
		local r = (k % 2 == 0) and 1.28 or 1.05
		mk(ctx, "Spot" .. k, V(0.45, 0.45, 0.25), CF(math.cos(a) * r, y, math.sin(a) * r) * A(0, -a + math.pi / 2, 0), c2)
	end
	-- glowing seam rings
	for _, y in { 1.05, 4.55 } do
		mk(ctx, "Seam", V(0.12, (y < 2 and 2.45 or 1.6), (y < 2 and 2.45 or 1.6)), CF(0, y, 0) * A(0, 0, rad(90)), c2:Lerp(Color3.new(1, 1, 1), 0.3), "Neon")
	end
	local top = EGG_TOPPER[eggKey]
	if top then
		top(ctx, c1, c2)
	end
	if nest then
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			mk(ctx, "Nest" .. k, V(1.2, 0.5, 0.5), CF(math.cos(a) * 1.5, 0.15, math.sin(a) * 1.5) * A(0, -a, rad(10)), RGB(190, 150, 90))
		end
	end
	model:SetAttribute("Egg", eggKey)
	return model
end

return PetModels
