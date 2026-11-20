-- v2.12 UNIQUE DEATHS (director: every species dies in its own readable,
-- child-friendly way; bosses get a multi-beat cinematic).
--
-- MonsterDeaths.Play(info) runs the sequence for info.Type and returns how
-- many seconds the model needs before it can be destroyed.
--
-- Vocabulary (combined differently per species, never one shared dissolve):
--   freeze/anchor  hold the pose        fling      joints break, pieces fly
--   sink           melt into the ground  rise       float away like a balloon
--   shrinkAll      deflate / wither      recolor    turn to stone / ice / ash
--   topple / flip  whole body falls      spin       whirl around
--   emit           element particles     ring/flash shockwaves and light
-- Bosses: STAGGER (shake + sparks) -> COLLAPSE (kneel, cracks blaze)
--   -> species DEFEAT moment -> REWARD (light pillar + confetti, egg drop
--   via MonsterDeaths.OnBossDefeated).

local Debris = game:GetService("Debris")
local Sfx = require(game:GetService("ReplicatedStorage").Shared.Sfx)
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local MonsterDeaths = {}
MonsterDeaths.OnBossDefeated = nil :: ((info: any, pos: Vector3) -> ())?

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- v2.18: flying death debris lands on the ground but never bumps players
-- (collision group "DeathDebris" ignores the "Players" group)
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
pcall(function()
	PhysicsService:RegisterCollisionGroup("DeathDebris")
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:CollisionGroupSetCollidable("DeathDebris", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("DeathDebris", "DeathDebris", false)
end)
local function playerGroup(char: Model)
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Players"
		end
	end
	char.DescendantAdded:Connect(function(p)
		if p:IsA("BasePart") then
			p.CollisionGroup = "Players"
		end
	end)
end
local function hookPlayer(pl: Player)
	if pl.Character then
		playerGroup(pl.Character)
	end
	pl.CharacterAdded:Connect(playerGroup)
end
for _, pl in Players:GetPlayers() do
	hookPlayer(pl)
end
Players.PlayerAdded:Connect(hookPlayer)

local fxFolder = Instance.new("Folder")
fxFolder.Name = "DeathFx"
fxFolder.Parent = workspace

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
local function parts(model: Model): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			table.insert(out, d)
		end
	end
	return out
end

local function tween(inst: Instance, t: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- hold the current pose (joints kept, whole body can still be pivoted)
local function freeze(model: Model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
end

-- break every joint so pieces can move on their own
local function breakJoints(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("WeldConstraint") or d:IsA("Weld") then
			d:Destroy()
		end
	end
end

local function fling(model: Model, power: number, up: number, filter: ((BasePart) -> boolean)?)
	breakJoints(model)
	local centre = model:GetPivot().Position
	for _, p in parts(model) do
		if not filter or filter(p) then
			p.Anchored = false
			p.CanCollide = true
			p.CanTouch = false
			p.CollisionGroup = "DeathDebris"
			p.Massless = false
			local out = p.Position - centre
			out = Vector3.new(out.X, 0, out.Z)
			out = out.Magnitude > 0.1 and out.Unit or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
			p.AssemblyLinearVelocity = out * power * (0.6 + math.random() * 0.8) + Vector3.new(0, up * (0.6 + math.random() * 0.8), 0)
			p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 12
		end
	end
end

local function fadeAll(model: Model, delay: number, t: number)
	task.delay(delay, function()
		for _, p in parts(model) do
			if p.Parent then
				tween(p, t, { Transparency = 1 })
			end
		end
	end)
end

local function recolor(model: Model, color: Color3, t: number, material: Enum.Material?, filter: ((BasePart) -> boolean)?)
	for _, p in parts(model) do
		if p.Transparency < 1 and (not filter or filter(p)) then
			tween(p, t, { Color = color })
			if material then
				task.delay(t, function()
					if p.Parent then
						p.Material = material
					end
				end)
			end
		end
	end
end

local function shrinkAll(model: Model, t: number, toward: Vector3?, filter: ((BasePart) -> boolean)?)
	freeze(model)
	breakJoints(model)
	for _, p in parts(model) do
		if not filter or filter(p) then
			local goal = { Size = p.Size * 0.05 }
			if toward then
				goal.CFrame = p.CFrame.Rotation + p.Position:Lerp(toward, 0.85)
			end
			tween(p, t, goal, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		end
	end
end

local function sink(model: Model, depth: number, t: number, flatten: boolean?)
	freeze(model)
	breakJoints(model)
	for _, p in parts(model) do
		local goal = { CFrame = p.CFrame - Vector3.new(0, depth, 0) }
		if flatten then
			goal.Size = Vector3.new(p.Size.X * 1.3, p.Size.Y * 0.15, p.Size.Z * 1.3)
		end
		tween(p, t, goal, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
end

local function rise(model: Model, height: number, t: number, wobble: number?)
	freeze(model)
	local start = model:GetPivot()
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local k = (os.clock() - t0) / t
		if k >= 1 or not model.Parent then
			conn:Disconnect()
			return
		end
		model:PivotTo(start * CFrame.new(math.sin(k * 12) * (wobble or 0), height * k * k, 0) * CFrame.Angles(0, k * 3, math.sin(k * 9) * 0.15))
	end)
end

-- rotate the whole body around a pivot point at its feet
local function topple(model: Model, axis: Vector3, angle: number, t: number)
	freeze(model)
	local start = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local foot = start * CFrame.new(0, -size.Y / 2, 0)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local k = math.min(1, (os.clock() - t0) / t)
		local eased = k * k
		local rot = CFrame.fromAxisAngle(axis, angle * eased)
		model:PivotTo(foot * rot * foot:Inverse() * start)
		if k >= 1 or not model.Parent then
			conn:Disconnect()
		end
	end)
end

local function spin(model: Model, turns: number, t: number, lift: number?)
	freeze(model)
	local start = model:GetPivot()
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local k = math.min(1, (os.clock() - t0) / t)
		model:PivotTo(start * CFrame.new(0, (lift or 0) * k, 0) * CFrame.Angles(0, turns * math.pi * 2 * k * k, 0))
		if k >= 1 or not model.Parent then
			conn:Disconnect()
		end
	end)
end

local function shake(model: Model, t: number, amount: number)
	freeze(model)
	local start = model:GetPivot()
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local k = (os.clock() - t0) / t
		if k >= 1 or not model.Parent then
			conn:Disconnect()
			if model.Parent then
				model:PivotTo(start)
			end
			return
		end
		local a = amount * (1 - k * 0.3)
		model:PivotTo(start * CFrame.new((math.random() - 0.5) * a, 0, (math.random() - 0.5) * a))
	end)
end

local function anchorPart(pos: Vector3, life: number): BasePart
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.one
	a.CFrame = CFrame.new(pos)
	a.Parent = fxFolder
	Debris:AddItem(a, life)
	return a
end

-- one-shot particle burst
local function emit(pos: Vector3, color: Color3 | ColorSequence, count: number, o)
	o = o or {}
	local a = anchorPart(pos, (o.Life or 2) + 1)
	local e = Instance.new("ParticleEmitter")
	e.Color = typeof(color) == "Color3" and ColorSequence.new(color) or color
	e.Texture = o.Texture or e.Texture
	e.LightEmission = o.Glow or 0.6
	e.Size = NumberSequence.new(o.Size or 1, o.SizeEnd or 0)
	e.Transparency = NumberSequence.new(o.Alpha or 0, 1)
	e.Lifetime = NumberRange.new((o.Life or 2) * 0.5, o.Life or 2)
	e.Speed = NumberRange.new((o.Speed or 15) * 0.4, o.Speed or 15)
	e.SpreadAngle = o.Spread or Vector2.new(180, 180)
	e.Acceleration = o.Accel or Vector3.zero
	e.Drag = o.Drag or 0
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = o.Dir or Enum.NormalId.Top
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
	return e
end

-- continuous emitter for a while
local function stream(pos: Vector3, color: Color3, rate: number, t: number, o)
	o = o or {}
	local a = anchorPart(pos, t + (o.Life or 2) + 1)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Texture = o.Texture or e.Texture
	e.LightEmission = o.Glow or 0.6
	e.Size = NumberSequence.new(o.Size or 1, o.SizeEnd or 0)
	e.Transparency = NumberSequence.new(o.Alpha or 0, 1)
	e.Lifetime = NumberRange.new((o.Life or 2) * 0.5, o.Life or 2)
	e.Speed = NumberRange.new((o.Speed or 6) * 0.4, o.Speed or 6)
	e.SpreadAngle = o.Spread or Vector2.new(180, 180)
	e.Acceleration = o.Accel or Vector3.zero
	e.Rate = rate
	e.Parent = a
	task.delay(t, function()
		e.Enabled = false
	end)
	return e
end

local function ring(pos: Vector3, radius: number, color: Color3, t: number?)
	local r = Instance.new("Part")
	r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch, r.CastShadow = true, false, false, false, false
	r.Shape = Enum.PartType.Cylinder
	r.Material = Enum.Material.Neon
	r.Color = color
	r.Transparency = 0.2
	r.Size = Vector3.new(0.3, 2, 2)
	r.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	r.Parent = fxFolder
	tween(r, t or 0.6, { Size = Vector3.new(0.1, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(r, (t or 0.6) + 0.2)
end

local function flash(pos: Vector3, color: Color3, range: number, t: number)
	local a = anchorPart(pos, t + 0.5)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 8
	l.Parent = a
	tween(l, t, { Brightness = 0 })
end

local function puddle(pos: Vector3, color: Color3, radius: number, neon: boolean, life: number)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = Enum.PartType.Cylinder
	p.Material = neon and Enum.Material.Neon or Enum.Material.Glass
	p.Color = color
	p.Transparency = 0.15
	p.Size = Vector3.new(0.2, 0.5, 0.5)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = fxFolder
	tween(p, 0.8, { Size = Vector3.new(0.2, radius * 2, radius * 2) })
	task.delay(life - 1, function()
		tween(p, 1, { Transparency = 1 })
	end)
	Debris:AddItem(p, life)
end

local function bolt(from: Vector3, to: Vector3, color: Color3)
	local prev = from
	for i = 1, 5 do
		local nextPos = i == 5 and to or from:Lerp(to, i / 5) + Vector3.new(math.random(-2, 2), math.random(-2, 2), math.random(-2, 2))
		local seg = Instance.new("Part")
		seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
		seg.Material = Enum.Material.Neon
		seg.Color = color
		seg.Size = Vector3.new(0.3, 0.3, (nextPos - prev).Magnitude)
		seg.CFrame = CFrame.lookAt((prev + nextPos) / 2, nextPos)
		seg.Parent = fxFolder
		Debris:AddItem(seg, 0.25)
		prev = nextPos
	end
end

local function named(pattern: string): (BasePart) -> boolean
	return function(p)
		return string.find(p.Name, pattern) ~= nil
	end
end
local function notNamed(pattern: string): (BasePart) -> boolean
	return function(p)
		return string.find(p.Name, pattern) == nil
	end
end

-- leaves a few small decorations on the ground for a while (flowers, coal…)
local function leave(pos: Vector3, n: number, color: Color3, size: number, life: number, shape: Enum.PartType?)
	for k = 1, n do
		local a = k / n * math.pi * 2 + math.random()
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Shape = shape or Enum.PartType.Block
		p.Color = color
		p.Size = Vector3.one * size * (0.7 + math.random() * 0.6)
		p.CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * (1 + math.random() * 3), size / 2, math.sin(a) * (1 + math.random() * 3))) * CFrame.Angles(0, a, 0)
		p.Parent = fxFolder
		task.delay(life - 1, function()
			tween(p, 1, { Transparency = 1 })
		end)
		Debris:AddItem(p, life)
	end
end

------------------------------------------------------------------------
-- species
------------------------------------------------------------------------
local RGB = Color3.fromRGB
local D = {}

-- Prismaw: turns to clear crystal, then shatters into glittering shards
D.Prismaw = function(m, pos)
	recolor(m, RGB(170, 230, 255), 0.5, Enum.Material.Glass)
	task.wait(0.6)
	emit(pos, RGB(140, 230, 255), 40, { Texture = SPARKLE, Size = 1.2, Speed = 22, Glow = 1 })
	ring(pos, 14, RGB(150, 230, 255))
	fling(m, 30, 35)
	fadeAll(m, 1.2, 0.8)
	return 2.4
end
-- Frostback: pulls into its shell, the shell ices over, cracks and bursts into snow
D.Frostback = function(m, pos)
	shrinkAll(m, 0.6, pos, notNamed("Shell"))
	task.wait(0.7)
	recolor(m, RGB(200, 240, 255), 0.6, Enum.Material.Glass, named("Shell"))
	task.wait(0.8)
	emit(pos + Vector3.new(0, 2, 0), RGB(250, 252, 255), 60, { Size = 1.4, Speed = 18, Accel = Vector3.new(0, -12, 0), Life = 2.5, Glow = 0.2 })
	ring(pos, 16, RGB(220, 245, 255))
	fling(m, 18, 25)
	fadeAll(m, 0.8, 0.8)
	return 2.8
end
-- Voltwraith: overloads, flickers white with bolts and vanishes in a flash
D.Voltwraith = function(m, pos)
	freeze(m)
	for _ = 1, 6 do
		bolt(pos + Vector3.new(0, 3, 0), pos + Vector3.new(math.random(-10, 10), math.random(-2, 8), math.random(-10, 10)), RGB(200, 240, 255))
		task.wait(0.08)
	end
	recolor(m, RGB(255, 255, 255), 0.3, Enum.Material.Neon)
	task.wait(0.35)
	flash(pos, RGB(200, 235, 255), 40, 0.6)
	emit(pos, RGB(220, 245, 255), 50, { Size = 0.6, Speed = 30, Glow = 1, Life = 0.8 })
	shrinkAll(m, 0.25, pos + Vector3.new(0, 3, 0))
	return 1.6
end
-- Shardstorm: spins up faster and faster, then bursts into glittering shards
D.Shardstorm = function(m, pos)
	spin(m, 5, 1.3, 4)
	stream(pos + Vector3.new(0, 3, 0), RGB(160, 220, 255), 30, 1.3, { Texture = SPARKLE, Size = 0.8, Speed = 10, Glow = 1 })
	task.wait(1.2)
	recolor(m, RGB(200, 235, 255), 0.2, Enum.Material.Glass)
	emit(pos + Vector3.new(0, 4, 0), RGB(150, 210, 255), 60, { Texture = SPARKLE, Size = 1.3, Speed = 28, Glow = 1 })
	ring(pos, 18, RGB(160, 220, 255))
	fling(m, 30, 40)
	fadeAll(m, 0.8, 0.8)
	return 2.2
end
-- Cindermaw: cools to grey stone, cracks glow one last time and it crumbles
D.Cindermaw = function(m, pos)
	freeze(m)
	recolor(m, RGB(110, 105, 100), 1, Enum.Material.Slate, notNamed("Magma"))
	stream(pos + Vector3.new(0, 4, 0), RGB(255, 150, 60), 20, 1.2, { Size = 0.4, Speed = 6, Accel = Vector3.new(0, 6, 0), Glow = 1 })
	task.wait(1.2)
	emit(pos, RGB(120, 110, 100), 30, { Size = 2, Speed = 8, Texture = SMOKE, Alpha = 0.3, Glow = 0 })
	fling(m, 8, 10)
	fadeAll(m, 1, 1)
	return 3
end
-- Smoldlet: its flame fizzles out, a black puff, a lump of coal is left
D.Smoldlet = function(m, pos)
	emit(pos + Vector3.new(0, 2, 0), RGB(40, 40, 45), 25, { Size = 2, SizeEnd = 3, Speed = 4, Texture = SMOKE, Accel = Vector3.new(0, 4, 0), Glow = 0, Alpha = 0.2 })
	shrinkAll(m, 0.7, pos)
	leave(pos, 3, RGB(40, 38, 40), 1, 6)
	return 1.2
end
-- Capstride: its cap droops, it wilts forward and sinks into the soil
D.Capstride = function(m, pos)
	topple(m, Vector3.new(1, 0, 0), math.rad(35), 0.7)
	task.wait(0.8)
	emit(pos + Vector3.new(0, 4, 0), RGB(255, 180, 200), 30, { Size = 0.5, Speed = 5, Accel = Vector3.new(0, 2, 0), Glow = 0.8, Life = 3 })
	sink(m, 6, 1.4)
	return 2.4
end
-- Sporeback: bursts into a big pink spore cloud and dissolves inside it
D.Sporeback = function(m, pos)
	emit(pos + Vector3.new(0, 3, 0), RGB(255, 150, 210), 70, { Size = 0.7, Speed = 10, Drag = 2, Glow = 0.9, Life = 3 })
	emit(pos + Vector3.new(0, 2, 0), RGB(240, 180, 220), 15, { Size = 4, SizeEnd = 6, Speed = 3, Texture = SMOKE, Alpha = 0.4, Glow = 0.2 })
	shrinkAll(m, 1, pos + Vector3.new(0, 2, 0))
	return 1.6
end
-- Rubbleye: the eye goes dark, the orbiting boulders drop, the core crumbles
D.Rubbleye = function(m, pos)
	freeze(m)
	recolor(m, RGB(20, 20, 25), 0.4, nil, named("Eye"))
	task.wait(0.5)
	fling(m, 4, 2, named("Orbit"))
	task.wait(0.5)
	fling(m, 10, 12)
	emit(pos, RGB(150, 140, 130), 25, { Size = 1.5, Speed = 10, Texture = SMOKE, Glow = 0, Alpha = 0.3 })
	fadeAll(m, 1.2, 1)
	return 3
end
-- Bristlehulk: topples backwards like a felled tree, leaves scatter
D.Bristlehulk = function(m, pos)
	topple(m, Vector3.new(1, 0, 0), math.rad(-85), 1)
	task.wait(1)
	ring(pos, 14, RGB(120, 180, 90))
	emit(pos + Vector3.new(0, 3, 0), RGB(110, 190, 80), 45, { Size = 0.8, Speed = 14, Accel = Vector3.new(0, -6, 0), Life = 3, Glow = 0 })
	fadeAll(m, 0.8, 1)
	return 2.8
end
-- Gulpvine: withers brown, droops and sinks back into the marsh
D.Gulpvine = function(m, pos)
	freeze(m)
	recolor(m, RGB(120, 95, 60), 0.9)
	topple(m, Vector3.new(0, 0, 1), math.rad(30), 0.9)
	emit(pos + Vector3.new(0, 4, 0), RGB(150, 120, 70), 20, { Size = 0.8, Speed = 4, Accel = Vector3.new(0, -5, 0), Life = 3, Glow = 0 })
	task.wait(1)
	sink(m, 7, 1.2)
	return 2.4
end
-- Mossgrave: crumbles into a mossy rubble pile; flowers bloom where it fell
D.Mossgrave = function(m, pos)
	fling(m, 6, 8)
	emit(pos, RGB(140, 130, 110), 30, { Size = 2, Speed = 6, Texture = SMOKE, Glow = 0, Alpha = 0.3 })
	task.wait(0.8)
	leave(pos, 6, RGB(255, 210, 90), 0.8, 8, Enum.PartType.Ball)
	leave(pos, 4, RGB(255, 150, 200), 0.7, 8, Enum.PartType.Ball)
	fadeAll(m, 1, 1)
	return 2.4
end
-- Gnashgut: deflates like a balloon with a wobble, ends in a little pop
D.Gnashgut = function(m, pos)
	shake(m, 0.6, 0.6)
	task.wait(0.6)
	shrinkAll(m, 0.9, pos + Vector3.new(0, 1, 0))
	task.wait(0.8)
	emit(pos + Vector3.new(0, 1, 0), RGB(200, 255, 200), 25, { Size = 0.6, Speed = 12, Glow = 0.5 })
	return 1.6
end
-- Skyfin: flips belly-up and floats away like a balloon fish, bubbles trailing
D.Skyfin = function(m, pos)
	topple(m, Vector3.new(0, 0, 1), math.pi, 0.5)
	task.wait(0.5)
	rise(m, 30, 2.5, 1)
	stream(pos, RGB(200, 235, 255), 12, 2.5, { Size = 0.6, Speed = 4, Accel = Vector3.new(0, 6, 0), Glow = 0.3 })
	fadeAll(m, 1.6, 0.9)
	return 2.7
end
-- Puffhorn: its wool poofs off in all directions, the bare ram blinks out
D.Puffhorn = function(m, pos)
	freeze(m)
	fling(m, 22, 30, named("Wool"))
	emit(pos + Vector3.new(0, 2, 0), RGB(255, 255, 255), 50, { Size = 1.4, Speed = 14, Drag = 2, Glow = 0.1, Life = 2.5 })
	task.wait(0.6)
	shrinkAll(m, 0.5, pos, notNamed("Wool"))
	fadeAll(m, 0.9, 0.6)
	return 2
end
-- Snowpeck: a burst of white feathers, then it spins down into a snowball that melts
D.Snowpeck = function(m, pos)
	emit(pos + Vector3.new(0, 3, 0), RGB(250, 250, 255), 45, { Size = 0.9, Speed = 12, Accel = Vector3.new(0, -3, 0), Drag = 3, Life = 3, Glow = 0 })
	spin(m, 3, 0.9, -2)
	task.wait(0.9)
	shrinkAll(m, 0.6, pos + Vector3.new(0, 1, 0))
	puddle(pos, RGB(200, 230, 255), 3, false, 4)
	return 1.6
end
-- Glowmoth: wings fold, its glow drains into motes that drift up into the sky
D.Glowmoth = function(m, pos)
	freeze(m)
	recolor(m, RGB(90, 80, 100), 1)
	stream(pos + Vector3.new(0, 3, 0), RGB(170, 255, 220), 30, 1.5, { Size = 0.4, Speed = 3, Accel = Vector3.new(0, 5, 0), Glow = 1, Life = 3 })
	task.wait(1)
	shrinkAll(m, 0.8, pos + Vector3.new(0, 2, 0))
	return 1.9
end
-- Croakle: a last zappy croak, then it plops into a puddle and is gone
D.Croakle = function(m, pos)
	freeze(m)
	for _ = 1, 3 do
		bolt(pos + Vector3.new(0, 2, 0), pos + Vector3.new(math.random(-6, 6), math.random(0, 5), math.random(-6, 6)), RGB(220, 245, 255))
		task.wait(0.1)
	end
	sink(m, 3, 0.6, true)
	puddle(pos, RGB(90, 150, 200), 4, false, 4)
	ring(pos, 8, RGB(150, 220, 255))
	return 1.4
end
-- Geoscuttle: flips onto its back, legs twitch, its crystals pop off
D.Geoscuttle = function(m, pos)
	topple(m, Vector3.new(0, 0, 1), math.pi, 0.6)
	task.wait(0.9)
	fling(m, 14, 26, named("Crystal"))
	emit(pos + Vector3.new(0, 2, 0), RGB(255, 170, 240), 30, { Texture = SPARKLE, Size = 1, Speed = 15, Glow = 1 })
	fadeAll(m, 1, 0.8)
	return 2.2
end
-- Scorchtail: its tail flame bursts, then it melts into a glowing lava puddle
D.Scorchtail = function(m, pos)
	emit(pos + Vector3.new(0, 2, 0), RGB(255, 140, 40), 40, { Size = 1.2, Speed = 12, Accel = Vector3.new(0, 10, 0), Glow = 1, Life = 1.2 })
	recolor(m, RGB(255, 120, 40), 0.4, Enum.Material.Neon)
	task.wait(0.4)
	sink(m, 2.5, 1, true)
	puddle(pos, RGB(255, 110, 40), 4, true, 5)
	return 1.5
end
-- Octoblob: squishes flat with an ink splash and melts away
D.Octoblob = function(m, pos)
	emit(pos + Vector3.new(0, 1, 0), RGB(40, 30, 60), 40, { Size = 1.6, Speed = 12, Texture = SMOKE, Glow = 0, Alpha = 0.1 })
	sink(m, 1.5, 0.7, true)
	puddle(pos, RGB(50, 35, 70), 5, false, 5)
	return 1.2
end
-- Shroomling (summoned sprout): pops into a tiny spore puff
D.Shroomling = function(m, pos)
	emit(pos + Vector3.new(0, 1, 0), RGB(255, 200, 220), 14, { Size = 0.5, Speed = 6, Glow = 0.6 })
	shrinkAll(m, 0.35, pos)
	return 0.6
end

------------------------------------------------------------------------
-- bosses: STAGGER -> COLLAPSE -> DEFEAT -> REWARD
------------------------------------------------------------------------
local function stagger(m: Model, pos: Vector3, color: Color3)
	shake(m, 1.4, 1.6)
	for k = 1, 5 do
		emit(pos + Vector3.new(math.random(-6, 6), math.random(2, 10), math.random(-6, 6)), color, 25, { Size = 1, Speed = 22, Glow = 1, Life = 0.8 })
		ring(pos, 10 + k * 4, color, 0.5)
		task.wait(0.28)
	end
end
local function collapse(m: Model, pos: Vector3, color: Color3)
	freeze(m)
	local start = m:GetPivot()
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local k = math.min(1, (os.clock() - t0) / 1.2)
		m:PivotTo(start * CFrame.new(0, -3 * k, 0) * CFrame.Angles(math.rad(14) * k, 0, 0))
		if k >= 1 or not m.Parent then
			conn:Disconnect()
		end
	end)
	stream(pos + Vector3.new(0, 4, 0), color, 60, 1.4, { Size = 1.2, Speed = 10, Accel = Vector3.new(0, 8, 0), Glow = 1 })
	flash(pos + Vector3.new(0, 6, 0), color, 60, 1.6)
	task.wait(1.4)
end
local function reward(pos: Vector3)
	-- golden light pillar + confetti + sparkle rain
	local beam = Instance.new("Part")
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
	beam.Material = Enum.Material.Neon
	beam.Color = RGB(255, 225, 120)
	beam.Transparency = 0.35
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(160, 1, 1)
	beam.CFrame = CFrame.new(pos + Vector3.new(0, 80, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Parent = fxFolder
	tween(beam, 0.5, { Size = Vector3.new(160, 10, 10) })
	task.delay(3, function()
		tween(beam, 1.5, { Transparency = 1, Size = Vector3.new(160, 1, 1) })
	end)
	Debris:AddItem(beam, 5)
	local confetti = ColorSequence.new({
		ColorSequenceKeypoint.new(0, RGB(255, 90, 90)), ColorSequenceKeypoint.new(0.25, RGB(255, 220, 80)),
		ColorSequenceKeypoint.new(0.5, RGB(90, 255, 140)), ColorSequenceKeypoint.new(0.75, RGB(90, 180, 255)), ColorSequenceKeypoint.new(1, RGB(230, 110, 255)),
	})
	emit(pos + Vector3.new(0, 6, 0), confetti, 160, { Size = 0.7, Speed = 40, Accel = Vector3.new(0, -25, 0), Life = 3, Glow = 0.4 })
	emit(pos + Vector3.new(0, 30, 0), RGB(255, 240, 170), 80, { Texture = SPARKLE, Size = 1.5, Speed = 8, Accel = Vector3.new(0, -6, 0), Life = 3, Glow = 1 })
	ring(pos, 40, RGB(255, 225, 120), 1)
	flash(pos + Vector3.new(0, 10, 0), RGB(255, 230, 150), 90, 2.5)
end

local B = {}
-- Mesa Colossus: its strata split and it slumps into a rubble mesa, the ruins topple
B.MesaColossus = function(m, pos)
	fling(m, 6, 4, named("Ruin"))
	emit(pos + Vector3.new(0, 10, 0), RGB(205, 170, 120), 80, { Size = 4, SizeEnd = 8, Speed = 10, Texture = SMOKE, Glow = 0, Alpha = 0.3, Life = 4 })
	sink(m, 8, 2.2)
	ring(pos, 40, RGB(230, 190, 130), 1)
	leave(pos, 10, RGB(190, 150, 105), 3, 10)
	task.wait(2.2)
end
-- Frostpeak Warden: freezes into an ice statue, then explodes into a snowstorm
B.FrostpeakWarden = function(m, pos)
	recolor(m, RGB(200, 240, 255), 1, Enum.Material.Glass)
	stream(pos + Vector3.new(0, 8, 0), RGB(230, 245, 255), 60, 1.2, { Size = 0.6, Speed = 4, Glow = 0.8 })
	task.wait(1.3)
	flash(pos, RGB(200, 240, 255), 80, 1)
	emit(pos + Vector3.new(0, 8, 0), RGB(250, 252, 255), 220, { Size = 1.6, Speed = 40, Accel = Vector3.new(0, -14, 0), Drag = 1, Life = 4, Glow = 0.2 })
	fling(m, 45, 50)
	fadeAll(m, 1.4, 1)
	task.wait(1.5)
end
-- Mycelium Monarch: its crown cap blooms one giant spore cloud, the body
-- withers and a fairy ring of little mushrooms springs up around it
B.MyceliumMonarch = function(m, pos)
	emit(pos + Vector3.new(0, 16, 0), RGB(255, 160, 220), 200, { Size = 1, Speed = 20, Drag = 1.5, Glow = 1, Life = 4 })
	emit(pos + Vector3.new(0, 14, 0), RGB(230, 190, 230), 30, { Size = 8, SizeEnd = 14, Speed = 4, Texture = SMOKE, Glow = 0.2, Alpha = 0.4, Life = 4 })
	recolor(m, RGB(140, 110, 90), 1.2)
	task.wait(1)
	shrinkAll(m, 1.5, pos + Vector3.new(0, 2, 0))
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		local at = pos + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14)
		leave(at, 1, RGB(240, 230, 210), 1.2, 10)
		leave(at + Vector3.new(0, 1.2, 0), 1, RGB(230, 90, 160), 1.6, 10, Enum.PartType.Ball)
	end
	task.wait(1.5)
end
-- Bogstorm Croaker: the throat sac overcharges into a storm of bolts, then it deflates
B.BogstormCroaker = function(m, pos)
	for _ = 1, 14 do
		bolt(pos + Vector3.new(0, 8, 0), pos + Vector3.new(math.random(-30, 30), math.random(0, 25), math.random(-30, 30)), RGB(200, 240, 255))
		emit(pos + Vector3.new(0, 8, 0), RGB(220, 245, 255), 10, { Size = 0.6, Speed = 30, Glow = 1, Life = 0.5 })
		task.wait(0.09)
	end
	flash(pos, RGB(200, 235, 255), 90, 0.8)
	ring(pos, 45, RGB(170, 230, 255), 0.8)
	shrinkAll(m, 1.4, pos + Vector3.new(0, 2, 0))
	puddle(pos, RGB(70, 110, 90), 16, false, 8)
	task.wait(1.4)
end
-- Prism Sovereign: everything implodes into its heart, then a crystal supernova
B.PrismSovereign = function(m, pos)
	local heart = pos + Vector3.new(0, 10, 0)
	shrinkAll(m, 1.2, heart)
	stream(heart, RGB(170, 230, 255), 80, 1.2, { Size = 0.8, Speed = 3, Glow = 1, Life = 1 })
	task.wait(1.3)
	flash(heart, RGB(180, 230, 255), 120, 1.5)
	ring(heart, 50, RGB(150, 220, 255), 1)
	emit(heart, RGB(140, 210, 255), 250, { Texture = SPARKLE, Size = 2, Speed = 55, Glow = 1, Life = 2.5 })
	for k = 1, 16 do
		local a = k / 16 * math.pi * 2
		local shard = Instance.new("Part")
		shard.Anchored, shard.CanCollide, shard.CanQuery, shard.CanTouch, shard.CastShadow = true, false, false, false, false
		shard.Material = Enum.Material.Glass
		shard.Color = k % 2 == 0 and RGB(80, 160, 255) or RGB(150, 130, 255)
		shard.Size = Vector3.new(1.2, 4, 1.2)
		shard.CFrame = CFrame.new(heart) * CFrame.Angles(0, a, math.rad(70))
		shard.Parent = fxFolder
		tween(shard, 1.2, { CFrame = CFrame.new(heart + Vector3.new(math.cos(a) * 40, -6, math.sin(a) * 40)) * CFrame.Angles(0, a, math.rad(70)), Transparency = 0.6 })
		Debris:AddItem(shard, 3)
	end
	task.wait(1.3)
end
-- Caldera Titan: erupts like a volcano, then hardens to obsidian and crumbles
B.CalderaTitan = function(m, pos)
	local top = pos + Vector3.new(0, 18, 0)
	stream(top, RGB(255, 120, 40), 90, 1.6, { Size = 1.6, Speed = 45, Spread = Vector2.new(25, 25), Accel = Vector3.new(0, -50, 0), Glow = 1, Life = 2.5 })
	stream(top, RGB(70, 60, 60), 20, 2, { Size = 6, SizeEnd = 12, Speed = 12, Texture = SMOKE, Glow = 0, Alpha = 0.3, Life = 4 })
	flash(top, RGB(255, 140, 60), 90, 2)
	task.wait(1.6)
	recolor(m, RGB(25, 20, 30), 0.8, Enum.Material.Glass)
	task.wait(0.9)
	puddle(pos, RGB(255, 110, 40), 18, true, 8)
	fling(m, 18, 22)
	fadeAll(m, 1.4, 1.2)
	task.wait(1.2)
end
-- Tidebreaker: its shell cracks, a tidal splash rolls out and it sinks into foam
B.Tidebreaker = function(m, pos)
	fling(m, 10, 18, named("Coral"))
	fling(m, 6, 10, named("Barnacle"))
	task.wait(0.6)
	for k = 1, 3 do
		ring(pos, 18 + k * 12, RGB(90, 180, 240), 0.8)
		emit(pos + Vector3.new(0, 2, 0), RGB(200, 240, 255), 80, { Size = 1.2, Speed = 25 + k * 8, Accel = Vector3.new(0, -30, 0), Life = 1.6, Glow = 0.3 })
		task.wait(0.35)
	end
	sink(m, 9, 1.6)
	puddle(pos, RGB(230, 245, 255), 16, false, 8)
	task.wait(1.6)
end

local BOSS_COLOR = {
	MesaColossus = RGB(255, 210, 110), FrostpeakWarden = RGB(170, 230, 255), MyceliumMonarch = RGB(200, 255, 210),
	BogstormCroaker = RGB(180, 230, 255), PrismSovereign = RGB(150, 210, 255), CalderaTitan = RGB(255, 130, 50), Tidebreaker = RGB(120, 200, 255),
}

-- runs the sequence in its own thread; calls onDone() when the model can go
function MonsterDeaths.Play(info, onDone: () -> ())
	local model: Model = info.Model
	local pos = info.Root.Position - Vector3.new(0, (info.Root.Size.Y / 2) + (info.Hum.HipHeight or 0), 0)
	local typeName = info.Type
	local fired = false
	local function fireReward()
		-- always runs (even if a VFX step errors): the egg must drop
		if not fired and info.Def.Boss and MonsterDeaths.OnBossDefeated then
			fired = true
			task.spawn(MonsterDeaths.OnBossDefeated, info, pos)
		end
	end
	task.spawn(function()
		task.wait(0.35) -- let the Death clip start
		local ok, err = pcall(function()
			if info.Def.Boss then
				local color = BOSS_COLOR[typeName] or RGB(255, 220, 120)
				Sfx.At("BossStagger", pos)
				stagger(model, pos, color)
				Sfx.At("BossCollapse", pos)
				collapse(model, pos, color)
				Sfx.Global("BossDefeat")
				local f = B[typeName]
				if f then
					f(model, pos)
				else
					fling(model, 20, 30)
				end
				reward(pos)
				Sfx.Global("BossReward")
				fireReward()
				task.wait(2.5)
			else
				Sfx.At("Death" .. Sfx.ElementOf(typeName), pos)
				local f = D[typeName]
				local tail
				if f then
					tail = f(model, pos)
				else
					fling(model, 15, 20)
					fadeAll(model, 0.8, 0.8)
					tail = 2
				end
				task.wait((tail or 2) + 0.3)
			end
		end)
		if not ok then
			warn(`[Deaths] {typeName}: {err}`)
		end
		fireReward()
		onDone()
	end)
end

return MonsterDeaths
