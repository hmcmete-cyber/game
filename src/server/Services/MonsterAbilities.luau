-- The 26 monster abilities (2 per monster) + shared effect helpers.
-- Every dangerous move is telegraphed first (red/orange ground circle, line
-- or wind-up animation) so players can dodge. All effect parts are cleaned
-- up with Debris; nothing keeps running after its owner dies.
--
-- An ability is fn(ctx, a) where a = its entry in MonsterDefs and ctx =
--   { Model, Root, Hum, Target (Player), TargetRoot, Alive() -> bool,
--     Play(animName), Summon(typeName, pos), SetDamageMult(mult, seconds) }

local Debris = game:GetService("Debris")
local Sfx = require(game:GetService("ReplicatedStorage").Shared.Sfx)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Abilities = {}

-- v2.23 signature hit VFX: every ability thread knows WHICH character casts
-- it (set by MonsterService.runAction), and threads it spawns inherit that,
-- so bursts/impacts play that character's own HitFx recipe.
local HitFx = require(game:GetService("ReplicatedStorage").Shared.HitFx)
local realTask = task
local Style = setmetatable({}, { __mode = "k" })
local function curStyle(): string?
	return Style[coroutine.running()]
end
local function inherit(f)
	if type(f) ~= "function" then
		return f
	end
	local st = curStyle()
	return function(...)
		Style[coroutine.running()] = st
		return f(...)
	end
end
local task = setmetatable({
	spawn = function(f, ...)
		return realTask.spawn(inherit(f), ...)
	end,
	delay = function(t, f, ...)
		return realTask.delay(t, inherit(f), ...)
	end,
	defer = function(f, ...)
		return realTask.defer(inherit(f), ...)
	end,
}, { __index = realTask })
function Abilities.SetStyle(typeName: string?)
	Style[coroutine.running()] = typeName
end
local function styledHit(st: string?, pos: Vector3, color: Color3, count: number, dir: Vector3?)
	local sc = math.clamp(count / 18, 0.5, 2.2)
	local r = st and HitFx.Styles[st]
	if r and r.Boss then
		sc *= 1.35
	end
	HitFx.Play(st or HitFx.StyleForColor(color), pos, sc, dir)
end

local Remotes
function Abilities.Init(remotes)
	Remotes = remotes
end

local RED = Color3.fromRGB(255, 70, 70)
local ORANGE = Color3.fromRGB(255, 150, 50)

local fxFolder = Instance.new("Folder")
fxFolder.Name = "MonsterFx"
fxFolder.Parent = workspace

------------------------------------------------------------------------
-- player effects (attributes read by the client: Movement / StatusFx)
------------------------------------------------------------------------
local function now(): number
	return workspace:GetServerTimeNow()
end

local function shielded(p: Player): boolean
	return (p:GetAttribute("ShieldUntil") or 0) > now()
end

function Abilities.Hurt(p: Player, dmg: number)
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and not shielded(p) then
		hum:TakeDamage(dmg * (1 - (p:GetAttribute("DamageResist") or 0)) * (1 - (p:GetAttribute("PetResist") or 0)))
		local root = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and os.clock() - (p:GetAttribute("HurtSfxAt") or 0) > 0.25 then
			p:SetAttribute("HurtSfxAt", os.clock())
			Sfx.At("PlayerHurt", root.Position)
			require(game:GetService("ReplicatedStorage").Shared.FxKit).Impact(root.Position, Color3.fromRGB(255, 70, 60), 0.7) -- v2.22 hit pop
		end
	end
end
local hurt = Abilities.Hurt

local function knock(p: Player, velocity: Vector3, stun: number?)
	if shielded(p) then
		return
	end
	local resist = (p:GetAttribute("BlastResist") and 0.5 or 1) * (1 - (p:GetAttribute("PetKnockResist") or 0))
	Remotes.Knock:FireClient(p, velocity * resist)
	if stun then
		p:SetAttribute("RagdollUntil", now() + stun)
	end
end
-- pets: Cleanse shortens debuffs, immunities cancel them
local function cleansed(p: Player, seconds: number): number
	return seconds * (1 - (p:GetAttribute("PetCleanse") or 0))
end
local function slow(p: Player, mult: number, seconds: number)
	if p:GetAttribute("SlowImmune") then
		return
	end
	seconds = cleansed(p, seconds)
	p:SetAttribute("MonsterSlow", mult)
	p:SetAttribute("MonsterSlowUntil", now() + seconds)
end
local function rootIn(p: Player, seconds: number)
	p:SetAttribute("RootedUntil", now() + cleansed(p, seconds))
end
local function slipNow(p: Player)
	if p:GetAttribute("SlipImmune") then
		return
	end
	p:SetAttribute("SlipAt", now())
end
local function blind(p: Player, seconds: number)
	if p:GetAttribute("BlindImmune") then
		return
	end
	p:SetAttribute("BlindUntil", now() + cleansed(p, seconds))
end
local function burn(p: Player, seconds: number)
	if not p:GetAttribute("FireImmune") then
		p:SetAttribute("BurnUntil", now() + cleansed(p, seconds))
	end
end

-- alive players near a point: { { Player, Root, Hum } }
local function near(pos: Vector3, radius: number)
	local out = {}
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and (root.Position - pos).Magnitude <= radius then
			table.insert(out, { p, root, hum })
		end
	end
	return out
end
Abilities.Near = near

------------------------------------------------------------------------
-- visual helpers
------------------------------------------------------------------------
local FxKit = require(game:GetService("ReplicatedStorage").Shared.FxKit)
local function fx(size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?, life: number?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cf
	p.Color = color
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.Parent = fxFolder
	Debris:AddItem(p, life or 3)
	return p
end

local function ground(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fxFolder, workspace:FindFirstChild("Monsters"), workspace:FindFirstChild("Weather") }
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or pos
end

-- telegraph circle on the ground; waits `time` and returns its centre
local function circle(pos: Vector3, radius: number, color: Color3, time: number): Vector3
	local g = ground(pos)
	local disc = fx(Vector3.new(0.2, radius * 2, radius * 2), CFrame.new(g + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, {
		Shape = Enum.PartType.Cylinder, Transparency = 0.75,
	}, time + 0.3)
	TweenService:Create(disc, TweenInfo.new(time), { Transparency = 0.25 }):Play()
	-- v2.22: energy gathers in the warning circle + a ring closing in
	FxKit.Charge(g + Vector3.new(0, 1, 0), color, math.clamp(radius / 6, 0.5, 2.5), time)
	task.wait(time)
	return g
end

local function ring(pos: Vector3, radius: number, color: Color3)
	FxKit.Shockwave(pos + Vector3.new(0, 0.3, 0), radius, color) -- v2.22 pro ring
	local r = fx(Vector3.new(0.3, 2, 2), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, {
		Shape = Enum.PartType.Cylinder, Transparency = 0.7, -- faint underlay
	}, 0.6)
	TweenService:Create(r, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, radius * 2, radius * 2), Transparency = 1,
	}):Play()
end

-- v2.22: layered pro burst (core, star flare, stretched sparks, glitter, ring);
-- big counts become a full explosion with dark spikes, embers and smoke
local function burst(pos: Vector3, color: Color3, count: number)
	if count < 8 then
		FxKit.Impact(pos, color, 0.6) -- small hit sparks
		return
	end
	styledHit(curStyle(), pos, color, count) -- v2.23: the caster's own effect
end

-- straight projectile; onHit(player) once; stops at first player or range
local function projectile(from: Vector3, dir: Vector3, speed: number, range: number, radius: number, color: Color3, size: Vector3, onHit)
	local p = fx(size, CFrame.lookAt(from, from + dir), color, nil, range / speed + 0.5)
	FxKit.Trail(p, color) -- v2.22 glowing trail + halo
	local st = curStyle()
	local travelled = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not p.Parent then
			conn:Disconnect()
			return
		end
		local step = speed * dt
		travelled += step
		p.CFrame += dir * step
		local hits = near(p.Position, radius)
		if #hits > 0 or travelled >= range then
			conn:Disconnect()
			if hits[1] then
				onHit(hits[1][1], hits[1][2])
				styledHit(st, p.Position, color, 12, dir)
			end
			p:Destroy()
		end
	end)
end

-- arcing lob with a landing marker; calls onLand(pos) on impact
local function lob(from: Vector3, to: Vector3, time: number, color: Color3, size: number, onLand)
	local g = ground(to)
	fx(Vector3.new(0.2, size * 4, size * 4), CFrame.new(g + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), RED, {
		Shape = Enum.PartType.Cylinder, Transparency = 0.5,
	}, time)
	local ball = fx(Vector3.one * size, CFrame.new(from), color, { Shape = Enum.PartType.Ball, Material = Enum.Material.Slate }, time + 0.2)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local k = math.min(1, (os.clock() - t0) / time)
		local pos = from:Lerp(g, k) + Vector3.new(0, math.sin(k * math.pi) * 18, 0)
		if ball.Parent then
			ball.CFrame = CFrame.new(pos)
		end
		if k >= 1 then
			conn:Disconnect()
			ball:Destroy()
			onLand(g)
		end
	end)
end

local function flatDir(from: Vector3, to: Vector3): Vector3
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return d.Magnitude > 0.01 and d.Unit or Vector3.new(0, 0, -1)
end

local function face(ctx, pos: Vector3)
	local r = ctx.Root
	r.CFrame = CFrame.lookAt(r.Position, Vector3.new(pos.X, r.Position.Y, pos.Z))
end

------------------------------------------------------------------------
-- ABILITIES
------------------------------------------------------------------------
local F = {}

-- Prismaw ---------------------------------------------------------------
F.ShardVolley = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	task.wait(0.35)
	local from = ctx.Root.Position + Vector3.new(0, 2, 0)
	local base = flatDir(from, ctx.TargetRoot.Position)
	for i = 1, a.Shards do
		local ang = math.rad((i - (a.Shards + 1) / 2) * a.Spread)
		local dir = CFrame.Angles(0, ang, 0):VectorToWorldSpace(base)
		projectile(from, dir, 70, 60, 3, Color3.fromRGB(80, 240, 255), Vector3.new(0.8, 0.8, 2.6), function(p)
			hurt(p, a.Damage)
			slow(p, a.Slow, a.SlowTime)
		end)
	end
end
F.RefractionDash = function(ctx, _a)
	local t = ctx.TargetRoot
	local old = ctx.Root.CFrame
	-- afterimage where it stood
	local ghost = fx(Vector3.new(6, 4, 8), old, Color3.fromRGB(200, 120, 255), { Material = Enum.Material.Glass, Transparency = 0.5 }, 0.8)
	TweenService:Create(ghost, TweenInfo.new(0.8), { Transparency = 1 }):Play()
	ctx.Play("Ability2")
	task.wait(0.25)
	local behind = t.Position - t.CFrame.LookVector * 7
	ctx.Model:PivotTo(CFrame.lookAt(ground(behind) + Vector3.new(0, 4, 0), t.Position))
	burst(behind, Color3.fromRGB(240, 70, 200), 25)
end

-- Frostback -------------------------------------------------------------
F.PermafrostSlam = function(ctx, a)
	ctx.Play("Ability2")
	local c = circle(ctx.Root.Position, a.Radius, Color3.fromRGB(150, 230, 255), a.Windup)
	if not ctx.Alive() then
		return
	end
	ring(c, a.Radius, Color3.fromRGB(190, 245, 255))
	fx(Vector3.new(0.3, a.Radius * 2, a.Radius * 2), CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(200, 240, 255), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glacier, Transparency = 0.3 }, 3)
	for _, h in near(c, a.Radius) do
		hurt(h[1], a.Damage)
		if not h[1]:GetAttribute("IceGrip") then
			slipNow(h[1])
		end
		slow(h[1], 0.6, 3)
	end
end
F.ShellBastion = function(ctx, a)
	ctx.Play("Ability2")
	ctx.SetDamageMult(a.DamageMult, a.Duration)
	local shell = ctx.Model:FindFirstChild("Shell")
	if shell then
		local hl = Instance.new("Highlight")
		hl.FillColor = Color3.fromRGB(170, 235, 255)
		hl.FillTransparency = 0.6
		hl.Parent = ctx.Model
		Debris:AddItem(hl, a.Duration)
	end
	for _, h in near(ctx.Root.Position, 10) do
		knock(h[1], flatDir(ctx.Root.Position, h[2].Position) * 60 + Vector3.new(0, 25, 0))
	end
end

-- Voltwraith ------------------------------------------------------------
local function bolt(from: Vector3, to: Vector3)
	local prev = from
	for i = 1, 5 do
		local nextPos = i == 5 and to or from:Lerp(to, i / 5) + Vector3.new(math.random(-2, 2), math.random(-2, 2), math.random(-2, 2))
		fx(Vector3.new(0.4, 0.4, (nextPos - prev).Magnitude), CFrame.lookAt((prev + nextPos) / 2, nextPos), Color3.fromRGB(150, 245, 255), nil, 0.2)
		prev = nextPos
	end
end
F.ChainLightning = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	local hitSet = {}
	local from = ctx.Root.Position + Vector3.new(0, 3, 0)
	local current, currentRoot = ctx.Target, ctx.TargetRoot
	for jump = 0, a.Jumps do
		if not current or (currentRoot.Position - from).Magnitude > (jump == 0 and a.Range or a.JumpRange) then
			break
		end
		bolt(from, currentRoot.Position)
		hitSet[current] = true
		if not current:GetAttribute("ElectricImmune") then
			hurt(current, jump == 0 and a.Damage or a.ChainDamage)
			current:SetAttribute("ShockedUntil", now() + 1.5)
		end
		from = currentRoot.Position
		local nextP, nextR = nil, nil
		for _, h in near(from, a.JumpRange) do
			if not hitSet[h[1]] then
				nextP, nextR = h[1], h[2]
				break
			end
		end
		current, currentRoot = nextP, nextR
	end
end
F.StaticBlink = function(ctx, _a)
	burst(ctx.Root.Position, Color3.fromRGB(150, 245, 255), 30)
	ctx.Play("Ability2")
	task.wait(0.3)
	local t = ctx.TargetRoot
	local side = t.CFrame.RightVector * (math.random() < 0.5 and -8 or 8)
	ctx.Model:PivotTo(CFrame.lookAt(ground(t.Position + side) + Vector3.new(0, 6, 0), t.Position))
	burst(ctx.Root.Position, Color3.fromRGB(150, 245, 255), 30)
end

-- Cyclonox --------------------------------------------------------------
F.VortexPull = function(ctx, a)
	ctx.Play("Ability2")
	local t0 = os.clock()
	while os.clock() - t0 < a.Duration and ctx.Alive() do
		local c = ctx.Root.Position
		for _, h in near(c, a.Range) do
			local d = c - h[2].Position
			if d.Magnitude > 5 then
				knock(h[1], d.Unit * a.Pull + Vector3.new(0, 6, 0))
			end
		end
		burst(c + Vector3.new(0, 2, 0), Color3.fromRGB(200, 210, 230), 8)
		task.wait(0.3)
	end
end
F.GaleBurst = function(ctx, a)
	ctx.Play("Ability2")
	local c = circle(ctx.Root.Position, a.Radius, Color3.fromRGB(220, 230, 255), a.Windup)
	if not ctx.Alive() then
		return
	end
	ring(c, a.Radius, Color3.fromRGB(235, 240, 255))
	for _, h in near(c, a.Radius) do
		hurt(h[1], a.Damage)
		knock(h[1], flatDir(c, h[2].Position) * a.Knock + Vector3.new(0, 40, 0), 1)
	end
end

-- Cindermaw -------------------------------------------------------------
F.MagmaGeyser = function(ctx, a)
	ctx.Play("Ability2")
	local c = circle(ctx.TargetRoot.Position, a.Radius, ORANGE, a.Windup)
	if not ctx.Alive() then
		return
	end
	local col = fx(Vector3.new(a.Radius * 1.4, 2, a.Radius * 1.4), CFrame.new(c), Color3.fromRGB(255, 110, 30), nil, 1)
	TweenService:Create(col, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(a.Radius, 30, a.Radius), CFrame = CFrame.new(c + Vector3.new(0, 15, 0)), Transparency = 0.6,
	}):Play()
	burst(c, ORANGE, 40)
	for _, h in near(c, a.Radius) do
		hurt(h[1], a.Damage)
		burn(h[1], a.Burn)
		knock(h[1], Vector3.new(0, 70, 0))
	end
end
F.EmberWings = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	local origin = ctx.Root.Position
	local look = flatDir(origin, ctx.TargetRoot.Position)
	for i = -2, 2 do
		local dir = CFrame.Angles(0, math.rad(i * a.Angle / 4), 0):VectorToWorldSpace(look)
		burst(origin + dir * 10 + Vector3.new(0, 2, 0), ORANGE, 12)
	end
	for _, h in near(origin, a.Range) do
		local d = flatDir(origin, h[2].Position)
		if math.deg(math.acos(math.clamp(d:Dot(look), -1, 1))) <= a.Angle / 2 then
			hurt(h[1], a.Damage)
			burn(h[1], a.Burn)
		end
	end
end

-- Smoldlet --------------------------------------------------------------
F.FuseHop = function(ctx, a)
	local c = circle(ctx.TargetRoot.Position, a.Radius, ORANGE, a.Windup)
	if not ctx.Alive() then
		return
	end
	ctx.Model:PivotTo(CFrame.new(c + Vector3.new(0, 3, 0)))
	ctx.Play("Ability1")
	burst(c, ORANGE, 30)
	ring(c, a.Radius, ORANGE)
	for _, h in near(c, a.Radius) do
		hurt(h[1], a.Damage)
		knock(h[1], flatDir(c, h[2].Position) * 40 + Vector3.new(0, 30, 0))
	end
end
F.AshPuff = function(ctx, a)
	ctx.Play("Ability2")
	local c = ctx.Root.Position
	local cloud = fx(Vector3.one * 2, CFrame.new(c), Color3.fromRGB(60, 55, 55), { Transparency = 1 }, 4)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(70, 65, 65))
	e.Size = NumberSequence.new(6, 14)
	e.Lifetime = NumberRange.new(2, 3)
	e.Speed = NumberRange.new(4, 9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = cloud
	e:Emit(40)
	for _, h in near(c, a.Radius) do
		blind(h[1], a.BlindTime)
	end
end

-- Capstride -------------------------------------------------------------
F.SporeBloom = function(ctx, a)
	ctx.Play("Ability2")
	local c = ground(ctx.Root.Position)
	local zone = fx(Vector3.new(a.Radius * 2, 8, a.Radius * 2), CFrame.new(c + Vector3.new(0, 4, 0)), Color3.fromRGB(220, 255, 150), {
		Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Transparency = 0.8,
	}, a.Duration)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(230, 255, 160))
	e.LightEmission = 0.5
	e.Size = NumberSequence.new(0.6, 0)
	e.Rate = 30
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = zone
	local t0 = os.clock()
	while os.clock() - t0 < a.Duration do
		for _, h in near(c, a.Radius) do
			if not h[1]:GetAttribute("PoisonImmune") then
				hurt(h[1], a.Damage)
				slow(h[1], a.Slow, 1.2)
			end
		end
		task.wait(1)
	end
end
F.SproutSquad = function(ctx, a)
	ctx.Play("Ability2")
	task.wait(0.4)
	for i = 1, a.Minions do
		local off = CFrame.Angles(0, i * math.pi, 0):VectorToWorldSpace(Vector3.new(5, 0, 0))
		ctx.Summon("Shroomling", ground(ctx.Root.Position + off), a.MinionLife)
	end
end

-- Sporeback -------------------------------------------------------------
F.SpineSpray = function(ctx, a)
	ctx.Play("Ability2")
	task.wait(0.4)
	local from = ctx.Root.Position + Vector3.new(0, 2, 0)
	for i = 1, a.Spines do
		local ang = i / a.Spines * math.pi * 2
		projectile(from, Vector3.new(math.cos(ang), 0, math.sin(ang)), 55, a.Range, 2.5, Color3.fromRGB(230, 200, 235), Vector3.new(0.4, 0.4, 2.2), function(p)
			hurt(p, a.Damage)
		end)
	end
end
F.MyceliumGrip = function(ctx, a)
	ctx.Play("Ability1")
	local c = circle(ctx.TargetRoot.Position, 5, Color3.fromRGB(240, 130, 190), a.Windup)
	if not ctx.Alive() then
		return
	end
	for i = 1, 6 do
		local ang = i / 6 * math.pi * 2
		fx(Vector3.new(0.6, 4, 0.6), CFrame.new(c + Vector3.new(math.cos(ang) * 2.5, 2, math.sin(ang) * 2.5)) * CFrame.Angles(math.rad(15), ang, 0),
			Color3.fromRGB(200, 150, 220), { Material = Enum.Material.SmoothPlastic }, a.RootTime + 0.3)
	end
	for _, h in near(c, 5) do
		rootIn(h[1], a.RootTime)
	end
end

-- Rubbleye --------------------------------------------------------------
F.OrbitCrush = function(ctx, a)
	ctx.Play("Ability2")
	local c = circle(ctx.Root.Position, a.Radius, RED, a.Windup)
	if not ctx.Alive() then
		return
	end
	ring(c, a.Radius, Color3.fromRGB(190, 80, 255))
	for _, h in near(c, a.Radius) do
		hurt(h[1], a.Damage)
		knock(h[1], flatDir(c, h[2].Position) * a.Knock + Vector3.new(0, 30, 0))
	end
end
F.VoidGaze = function(ctx, a)
	local from = ctx.Root.Position
	local to = ctx.TargetRoot.Position
	face(ctx, to)
	local dir = flatDir(from, to)
	local len = math.min(a.Range, (to - from).Magnitude + 10)
	local mid = from + dir * len / 2
	fx(Vector3.new(a.Width, 0.2, len), CFrame.lookAt(ground(mid) + Vector3.new(0, 0.2, 0), ground(mid) + Vector3.new(0, 0.2, 0) + dir), RED, { Transparency = 0.6 }, a.Windup)
	ctx.Play("Ability1")
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	fx(Vector3.new(a.Width * 0.8, a.Width * 0.8, len), CFrame.lookAt(from + dir * len / 2 + Vector3.new(0, 1, 0), from + dir * len), Color3.fromRGB(190, 80, 255), { Transparency = 0.2 }, 0.3)
	for _, h in near(from + dir * len / 2, len / 2 + a.Width) do
		local rel = h[2].Position - from
		local along = rel:Dot(dir)
		local side = (rel - dir * along)
		if along >= 0 and along <= len and Vector3.new(side.X, 0, side.Z).Magnitude <= a.Width then
			hurt(h[1], a.Damage)
		end
	end
end

-- Bristlehulk -----------------------------------------------------------
F.ThornCharge = function(ctx, a)
	local from = ctx.Root.Position
	local dir = flatDir(from, ctx.TargetRoot.Position)
	face(ctx, ctx.TargetRoot.Position)
	local len = a.Range
	local mid = ground(from + dir * len / 2)
	fx(Vector3.new(6, 0.2, len), CFrame.lookAt(mid + Vector3.new(0, 0.2, 0), mid + Vector3.new(0, 0.2, 0) + dir), RED, { Transparency = 0.6 }, a.Windup)
	ctx.Play("Ability1")
	task.wait(a.Windup)
	local hitSet = {}
	local t0 = os.clock()
	while os.clock() - t0 < 0.8 and ctx.Alive() do
		ctx.Model:PivotTo(ctx.Root.CFrame + dir * 2.4)
		for _, h in near(ctx.Root.Position, 6) do
			if not hitSet[h[1]] then
				hitSet[h[1]] = true
				hurt(h[1], a.Damage)
				knock(h[1], dir * a.Knock + Vector3.new(0, 35, 0), 0.6)
			end
		end
		task.wait(1 / 30)
	end
end
F.BrambleWall = function(ctx, a)
	ctx.Play("Ability2")
	local t = ctx.TargetRoot
	local away = flatDir(ctx.Root.Position, t.Position)
	local c = ground(t.Position + away * 7)
	local wall = CFrame.lookAt(c, c + away)
	for i = -3, 3 do
		fx(Vector3.new(2.4, 7, 2.4), wall * CFrame.new(i * 2.4, 3.5, 0), Color3.fromRGB(70, 120, 50), {
			Material = Enum.Material.Grass, CanCollide = true, Transparency = 0,
		}, a.Duration)
	end
end

-- Gulpvine (storm snapper) ---------------------------------------------
local VOLT = Color3.fromRGB(110, 240, 255)
-- Volt Snap: a charged bite — holds you 1 s and leaves you shocked (slowed)
F.SnapLunge = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	task.wait(0.25)
	if ctx.Alive() and (ctx.TargetRoot.Position - ctx.Root.Position).Magnitude <= a.Range then
		hurt(ctx.Target, a.Damage)
		rootIn(ctx.Target, a.HoldTime)
		if not ctx.Target:GetAttribute("ElectricImmune") then
			ctx.Target:SetAttribute("ShockedUntil", now() + a.ShockTime)
		end
		bolt(ctx.Root.Position + Vector3.new(0, 3, 0), ctx.TargetRoot.Position)
		burst(ctx.TargetRoot.Position, VOLT, 14)
	end
end
-- Storm Spit: lobs a crackling glob; it leaves an electric puddle that
-- zaps and slows anyone inside (Electric-immune perks are safe)
F.AcidSpit = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability2")
	lob(ctx.Root.Position + Vector3.new(0, 4, 0), ctx.TargetRoot.Position, 1, VOLT, 1.5, function(g)
		fx(Vector3.new(0.2, a.Radius * 2, a.Radius * 2), CFrame.new(g + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(60, 140, 200), { Shape = Enum.PartType.Cylinder, Transparency = 0.35 }, a.Duration)
		local t0 = os.clock()
		task.spawn(function()
			while os.clock() - t0 < a.Duration do
				burst(g + Vector3.new(0, 0.5, 0), VOLT, 6)
				for _, h in near(g, a.Radius) do
					if not h[1]:GetAttribute("ElectricImmune") then
						hurt(h[1], a.Damage)
						h[1]:SetAttribute("ShockedUntil", now() + 1.2)
					end
				end
				task.wait(1)
			end
		end)
	end)
end

-- Mossgrave -------------------------------------------------------------
F.BoulderToss = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability2")
	lob(ctx.Root.Position + Vector3.new(0, 7, 0), ctx.TargetRoot.Position, a.Windup, Color3.fromRGB(130, 130, 128), 4, function(g)
		burst(g, Color3.fromRGB(150, 140, 120), 25)
		ring(g, a.Radius, Color3.fromRGB(200, 190, 170))
		for _, h in near(g, a.Radius) do
			hurt(h[1], a.Damage)
			knock(h[1], flatDir(g, h[2].Position) * 45 + Vector3.new(0, 30, 0))
		end
	end)
end
F.VineLash = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	task.wait(0.3)
	local from = ctx.Root.Position + Vector3.new(0, 3, 0)
	local dir = (ctx.TargetRoot.Position - from).Unit
	projectile(from, dir, 80, a.Range, 3, Color3.fromRGB(70, 140, 50), Vector3.new(0.5, 0.5, 4), function(p, root)
		local back = ctx.Root.Position - root.Position
		knock(p, back.Unit * a.Pull + Vector3.new(0, 20, 0))
	end)
end

-- Gnashgut --------------------------------------------------------------
F.FrenzyBite = function(ctx, a)
	for _ = 1, a.Bites do
		if not ctx.Alive() then
			return
		end
		face(ctx, ctx.TargetRoot.Position)
		ctx.Play("Ability1")
		task.wait(0.25)
		if (ctx.TargetRoot.Position - ctx.Root.Position).Magnitude <= a.Range then
			hurt(ctx.Target, a.Damage)
			burst(ctx.TargetRoot.Position, Color3.fromRGB(255, 240, 200), 6)
		end
	end
end
F.GroundPound = function(ctx, a)
	ctx.Play("Ability2")
	local c = circle(ctx.Root.Position, a.Radius, RED, a.Windup)
	if not ctx.Alive() then
		return
	end
	ring(c, a.Radius, Color3.fromRGB(160, 220, 120))
	for _, h in near(c, a.Radius) do
		hurt(h[1], a.Damage)
		knock(h[1], Vector3.new(0, 25, 0), a.Stun)
	end
end

-- Skyfin ----------------------------------------------------------------
-- Fin Dive: sinks so only its fin cuts through the sand toward a carrier,
-- a circle warns where it will burst out, then it leaps up under them
F.FinDive = function(ctx, a)
	ctx.Play("Ability2")
	local start = ctx.Root.CFrame
	local down = start - Vector3.new(0, 3.5, 0)
	ctx.Model:PivotTo(down)
	local target = ctx.TargetRoot.Position
	local steps = 12
	for i = 1, steps do
		if not ctx.Alive() then
			return
		end
		local p = down.Position:Lerp(Vector3.new(target.X, down.Position.Y, target.Z), i / steps)
		ctx.Model:PivotTo(CFrame.lookAt(p, Vector3.new(target.X, p.Y, target.Z)))
		burst(Vector3.new(p.X, start.Position.Y - 1, p.Z), Color3.fromRGB(240, 225, 180), 3)
		task.wait(0.05)
	end
	local c = circle(target, a.Radius, RED, a.Windup)
	if not ctx.Alive() then
		return
	end
	ctx.Model:PivotTo(CFrame.new(c + Vector3.new(0, 4, 0)))
	ctx.Play("Ability1")
	burst(c, Color3.fromRGB(150, 210, 255), 30)
	for _, h in near(c, a.Radius) do
		hurt(h[1], a.Damage)
		knock(h[1], Vector3.new(0, 55, 0) + flatDir(c, h[2].Position) * 20)
	end
end
-- Tail Spin: winds up, then spins and swats everyone around it away
F.TailSpin = function(ctx, a)
	ctx.Play("Ability2")
	local c = circle(ctx.Root.Position, a.Radius, ORANGE, a.Windup)
	if not ctx.Alive() then
		return
	end
	local base = ctx.Root.CFrame
	for i = 1, 8 do
		ctx.Model:PivotTo(base * CFrame.Angles(0, i * math.pi / 4, 0))
		task.wait(0.03)
	end
	ring(c, a.Radius, Color3.fromRGB(150, 210, 255))
	for _, h in near(c, a.Radius) do
		hurt(h[1], a.Damage)
		knock(h[1], flatDir(c, h[2].Position) * a.Knock + Vector3.new(0, 25, 0))
	end
end

-- ======================================================================
-- v2.6 abilities of the second monster per habitat
-- ======================================================================
-- Puffhorn: bounces high on its wool and lands with a shockwave
F.WoolBounce = function(ctx, a)
	ctx.Play("Ability2")
	local c = circle(ctx.Root.Position, a.Radius, ORANGE, a.Windup)
	if not ctx.Alive() then
		return
	end
	local base = ctx.Root.CFrame
	for i = 1, 6 do
		ctx.Model:PivotTo(base + Vector3.new(0, math.sin(i / 6 * math.pi) * 8, 0))
		task.wait(0.04)
	end
	ctx.Model:PivotTo(base)
	ring(c, a.Radius, Color3.fromRGB(250, 250, 255))
	burst(c, Color3.fromRGB(250, 250, 255), 25)
	for _, h in near(c, a.Radius) do
		hurt(h[1], a.Damage)
		knock(h[1], flatDir(c, h[2].Position) * a.Knock + Vector3.new(0, 30, 0))
	end
end
-- Puffhorn: rubs its wool and zaps everyone close with static
F.StaticFluff = function(ctx, a)
	ctx.Play("Ability1")
	task.wait(0.4)
	if not ctx.Alive() then
		return
	end
	for _, h in near(ctx.Root.Position, a.Radius) do
		bolt(ctx.Root.Position + Vector3.new(0, 2, 0), h[2].Position)
		if not h[1]:GetAttribute("ElectricImmune") then
			hurt(h[1], a.Damage)
			h[1]:SetAttribute("ShockedUntil", now() + a.Shock)
		end
	end
	burst(ctx.Root.Position, Color3.fromRGB(255, 255, 160), 20)
end
-- Snowpeck: throws three snowballs that land around the target
F.SnowballBarrage = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	for i = 1, a.Balls do
		if not ctx.Alive() then
			return
		end
		local off = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		lob(ctx.Root.Position + Vector3.new(0, 4, 0), ctx.TargetRoot.Position + off, 0.9, Color3.fromRGB(250, 252, 255), 1.6, function(g)
			burst(g, Color3.fromRGB(255, 255, 255), 14)
			for _, h in near(g, a.Radius) do
				hurt(h[1], a.Damage)
				slow(h[1], 0.6, 2)
			end
		end)
		task.wait(0.25)
	end
end
-- Snowpeck: one huge wing beat that blows players away in a cone
F.WingGust = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability2")
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	local origin = ctx.Root.Position
	local look = flatDir(origin, ctx.TargetRoot.Position)
	for i = -2, 2 do
		burst(origin + CFrame.Angles(0, math.rad(i * 15), 0):VectorToWorldSpace(look) * 10, Color3.fromRGB(230, 240, 255), 10)
	end
	for _, h in near(origin, a.Range) do
		local d = flatDir(origin, h[2].Position)
		if math.deg(math.acos(math.clamp(d:Dot(look), -1, 1))) <= a.Angle / 2 then
			hurt(h[1], a.Damage)
			knock(h[1], d * a.Knock + Vector3.new(0, 25, 0))
		end
	end
end
-- Glowmoth: a spinning ring of glowing spores flies outward
F.SporeSpiral = function(ctx, a)
	ctx.Play("Ability2")
	task.wait(0.4)
	local from = ctx.Root.Position + Vector3.new(0, 1, 0)
	for i = 1, a.Spores do
		local ang = i / a.Spores * math.pi * 2
		projectile(from, Vector3.new(math.cos(ang), -0.15, math.sin(ang)).Unit, 40, a.Range, 2.5, Color3.fromRGB(170, 255, 220), Vector3.new(0.9, 0.9, 0.9), function(p)
			if not p:GetAttribute("PoisonImmune") then
				hurt(p, a.Damage)
			end
		end)
		task.wait(0.03)
	end
end
-- Glowmoth: sleepy dust falls on a circle; players inside doze (rooted)
F.LullabyDust = function(ctx, a)
	ctx.Play("Ability1")
	local c = circle(ctx.TargetRoot.Position, a.Radius, Color3.fromRGB(200, 170, 255), a.Windup)
	if not ctx.Alive() then
		return
	end
	burst(c + Vector3.new(0, 3, 0), Color3.fromRGB(220, 200, 255), 30)
	for _, h in near(c, a.Radius) do
		rootIn(h[1], a.RootTime)
		blind(h[1], a.RootTime)
	end
end
-- Croakle: a long sticky tongue pulls the carrier in
F.TongueLash = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	task.wait(0.2)
	local from = ctx.Root.Position + Vector3.new(0, 1.5, 0)
	projectile(from, (ctx.TargetRoot.Position - from).Unit, 90, a.Range, 2.5, Color3.fromRGB(255, 120, 150), Vector3.new(0.6, 0.6, 3), function(p, root)
		hurt(p, a.Damage)
		knock(p, (ctx.Root.Position - root.Position).Unit * a.Pull + Vector3.new(0, 15, 0))
	end)
end
-- Croakle: a booming croak sends a thunder ring out
F.ThunderCroak = function(ctx, a)
	ctx.Play("Ability2")
	local c = circle(ctx.Root.Position, a.Radius, Color3.fromRGB(110, 240, 255), a.Windup)
	if not ctx.Alive() then
		return
	end
	ring(c, a.Radius, Color3.fromRGB(110, 240, 255))
	for _, h in near(c, a.Radius) do
		hurt(h[1], a.Damage)
		if not h[1]:GetAttribute("ElectricImmune") then
			h[1]:SetAttribute("ShockedUntil", now() + 2)
		end
		knock(h[1], flatDir(c, h[2].Position) * 35 + Vector3.new(0, 20, 0), 0.5)
	end
end
-- Geoscuttle: snaps a pincer shut on a close carrier and holds on
F.PincerSnap = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	task.wait(0.25)
	if ctx.Alive() and (ctx.TargetRoot.Position - ctx.Root.Position).Magnitude <= a.Range then
		hurt(ctx.Target, a.Damage)
		rootIn(ctx.Target, a.HoldTime)
		burst(ctx.TargetRoot.Position, Color3.fromRGB(90, 170, 255), 12)
	end
end
-- Geoscuttle: flicks its tail and fires a crystal stinger
F.CrystalSting = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability2")
	task.wait(0.35)
	local from = ctx.Root.Position + Vector3.new(0, 4, 0)
	projectile(from, (ctx.TargetRoot.Position - from).Unit, 75, a.Range, 2.5, Color3.fromRGB(90, 170, 255), Vector3.new(0.7, 0.7, 2.4), function(p)
		hurt(p, a.Damage)
		slow(p, a.Slow, a.SlowTime)
	end)
end
-- Scorchtail: dashes at the carrier, leaving a burning trail behind it
F.FlameDash = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	local dir = flatDir(ctx.Root.Position, ctx.TargetRoot.Position)
	local trail = {}
	for _ = 1, 10 do
		if not ctx.Alive() then
			break
		end
		ctx.Model:PivotTo(ctx.Root.CFrame + dir * 3)
		local g = ground(ctx.Root.Position)
		fx(Vector3.new(0.2, 4, 4), CFrame.new(g + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), ORANGE, { Shape = Enum.PartType.Cylinder, Transparency = 0.3 }, 3)
		table.insert(trail, g)
		task.wait(0.05)
	end
	local t0 = os.clock()
	while os.clock() - t0 < 3 do
		for _, g in trail do
			for _, h in near(g, 2.5) do
				hurt(h[1], a.Damage * 0.25)
				burn(h[1], a.Burn)
			end
		end
		task.wait(0.5)
	end
end
-- Scorchtail: spits a glob of embers that bursts into flames
F.EmberSpit = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability2")
	lob(ctx.Root.Position + Vector3.new(0, 2, 0), ctx.TargetRoot.Position, 0.9, ORANGE, 1.4, function(g)
		burst(g, ORANGE, 25)
		for _, h in near(g, a.Radius) do
			hurt(h[1], a.Damage)
			burn(h[1], a.Burn)
		end
	end)
end
-- Octoblob: squirts an ink cloud that blinds and slows
F.InkCloud = function(ctx, a)
	ctx.Play("Ability2")
	local c = ctx.Root.Position
	local cloud = fx(Vector3.one * 2, CFrame.new(c), Color3.fromRGB(30, 25, 50), { Transparency = 1 }, 4)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(40, 30, 70))
	e.Size = NumberSequence.new(6, 14)
	e.Lifetime = NumberRange.new(2, 3)
	e.Speed = NumberRange.new(4, 9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = cloud
	e:Emit(40)
	for _, h in near(c, a.Radius) do
		blind(h[1], a.BlindTime)
		slow(h[1], 0.6, a.BlindTime)
	end
end
-- Octoblob: slams all six tentacles down around itself
F.TentacleSlam = function(ctx, a)
	ctx.Play("Ability2")
	local c = circle(ctx.Root.Position, a.Radius, RED, a.Windup)
	if not ctx.Alive() then
		return
	end
	ring(c, a.Radius, Color3.fromRGB(255, 150, 180))
	for _, h in near(c, a.Radius) do
		hurt(h[1], a.Damage)
		knock(h[1], flatDir(c, h[2].Position) * a.Knock + Vector3.new(0, 25, 0), a.Stun)
	end
end

-- ======================================================================
-- v2.10 BOSS ABILITIES (big, always telegraphed: circles, lines, cones)
-- ======================================================================
-- red/orange ground strip from `from` along `dir`; waits `time`
local function lineTel(from: Vector3, dir: Vector3, length: number, width: number, color: Color3, time: number)
	local g = ground(from)
	local mid = g + dir * (length / 2) + Vector3.new(0, 0.15, 0)
	local strip = fx(Vector3.new(width, 0.2, length), CFrame.lookAt(mid, mid + dir), color, { Transparency = 0.75 }, time + 0.3)
	TweenService:Create(strip, TweenInfo.new(time), { Transparency = 0.25 }):Play()
end
-- players inside a strip (flat check)
local function inStrip(from: Vector3, dir: Vector3, length: number, width: number)
	local out = {}
	for _, h in near(from, length + width) do
		local rel = h[2].Position - from
		local along = rel:Dot(dir)
		local side = (rel - dir * along)
		side = Vector3.new(side.X, 0, side.Z)
		if along >= -2 and along <= length and side.Magnitude <= width / 2 + 1.5 then
			table.insert(out, h)
		end
	end
	return out
end
local function airborne(h): boolean
	return h[3].FloorMaterial == Enum.Material.Air
end
local function bossRoar(ctx, color: Color3)
	ctx.Play("Ability1")
	ring(ctx.Root.Position - Vector3.new(0, 3, 0), 26, color)
	burst(ctx.Root.Position, color, 30)
end
Abilities.BossRoar = function(model: Model, color: Color3)
	local root = model.PrimaryPart
	if root then
		Sfx.At("BossRoar", root.Position)
		ring(root.Position - Vector3.new(0, 3, 0), 40, color)
		burst(root.Position + Vector3.new(0, 4, 0), color, 60)
	end
end

-- Mesa Colossus: stone pillars burst up under the target and around it
F.PillarRise = function(ctx, a)
	bossRoar(ctx, Color3.fromRGB(230, 190, 130))
	local centre = ctx.TargetRoot.Position
	local spots = { centre }
	for k = 2, a.Pillars do
		table.insert(spots, centre + Vector3.new(math.cos(k * 1.3) * 14, 0, math.sin(k * 1.3) * 14))
	end
	for _, p in spots do
		task.spawn(circle, p, a.Radius, ORANGE, a.Windup)
	end
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	for _, p in spots do
		local g = ground(p)
		local pillar = fx(Vector3.new(a.Radius * 1.3, 2, a.Radius * 1.3), CFrame.new(g), Color3.fromRGB(205, 160, 112), { Material = Enum.Material.Plastic, CanCollide = true }, 3)
		TweenService:Create(pillar, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = Vector3.new(a.Radius * 1.3, 14, a.Radius * 1.3), CFrame = CFrame.new(g + Vector3.new(0, 7, 0)) }):Play()
		burst(g, Color3.fromRGB(205, 160, 112), 14)
		for _, h in near(g, a.Radius) do
			hurt(h[1], a.Damage)
			knock(h[1], Vector3.new(0, 70, 0) + flatDir(g, h[2].Position) * 20, 0.6)
		end
	end
end
-- Mesa Colossus: slams the ground; a ridge of rock races toward the target
F.RidgeShockwave = function(ctx, a)
	local from = ctx.Root.Position
	local dir = flatDir(from, ctx.TargetRoot.Position)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability2")
	lineTel(from, dir, a.Length, a.Width, RED, a.Windup)
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	for k = 1, 10 do
		local p = ground(from + dir * (k * a.Length / 10))
		local rock = fx(Vector3.new(a.Width * 0.8, 1, 4), CFrame.lookAt(p, p + dir), Color3.fromRGB(176, 128, 92), { Material = Enum.Material.Plastic }, 1.2)
		TweenService:Create(rock, TweenInfo.new(0.12), { Size = Vector3.new(a.Width * 0.8, 7, 4), CFrame = CFrame.lookAt(p + Vector3.new(0, 3.5, 0), p + Vector3.new(0, 3.5, 0) + dir) }):Play()
		task.wait(0.05)
	end
	for _, h in inStrip(from, dir, a.Length, a.Width) do
		hurt(h[1], a.Damage)
		knock(h[1], dir * 60 + Vector3.new(0, 45, 0), 0.8)
	end
end

-- Frostpeak Warden: a wide cone of snow boulders rolls down at the players
F.AvalancheSweep = function(ctx, a)
	local from = ctx.Root.Position
	local dir = flatDir(from, ctx.TargetRoot.Position)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	lineTel(from, dir, a.Length, a.Width, ORANGE, a.Windup)
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	local right = dir:Cross(Vector3.yAxis)
	for k = 1, a.Boulders do
		local off = right * ((k - (a.Boulders + 1) / 2) * a.Width / a.Boulders)
		projectile(from + off + Vector3.new(0, 2, 0), dir, 55, a.Length, 5, Color3.fromRGB(240, 248, 255), Vector3.new(6, 6, 6), function(p)
			hurt(p, a.Damage)
			slow(p, 0.5, 3)
			slipNow(p)
			knock(p, dir * 45 + Vector3.new(0, 25, 0))
		end)
	end
end
-- Frostpeak Warden: an expanding ring of ice; jump over it (airborne = safe)
F.IceRing = function(ctx, a)
	ctx.Play("Ability2")
	local c = circle(ctx.Root.Position, 10, Color3.fromRGB(150, 220, 255), a.Windup)
	if not ctx.Alive() then
		return
	end
	local hit = {}
	for k = 1, 10 do
		local rad = a.Radius * k / 10
		ring(c, rad, Color3.fromRGB(180, 235, 255))
		for _, h in near(c, rad) do
			if not hit[h[1]] and (h[2].Position - c).Magnitude > rad - a.Radius / 10 - 2 and not airborne(h) then
				hit[h[1]] = true
				hurt(h[1], a.Damage)
				slow(h[1], 0.4, 3)
				slipNow(h[1])
			end
		end
		task.wait(0.07)
	end
end

-- Mycelium Monarch: splits off spore doubles (little sprouts) around itself
F.SporeDoubles = function(ctx, a)
	bossRoar(ctx, Color3.fromRGB(200, 255, 220))
	task.wait(0.6)
	for k = 1, a.Doubles do
		if not ctx.Alive() then
			return
		end
		local p = ctx.Root.Position + Vector3.new(math.cos(k * 2.1) * 10, 0, math.sin(k * 2.1) * 10)
		burst(p, Color3.fromRGB(200, 255, 220), 18)
		ctx.Summon("Shroomling", ground(p), a.Life)
		task.wait(0.2)
	end
end
-- Mycelium Monarch: roots burst from the ground under every nearby player
F.RootSnare = function(ctx, a)
	ctx.Play("Ability2")
	local targets = near(ctx.Root.Position, a.Range)
	for _, h in targets do
		task.spawn(circle, h[2].Position, a.Radius, Color3.fromRGB(160, 120, 90), a.Windup)
	end
	local spots = {}
	for _, h in targets do
		table.insert(spots, h[2].Position)
	end
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	for _, p in spots do
		local g = ground(p)
		for k = 1, 5 do
			local ang = k * 1.25
			fx(Vector3.new(1, 6, 1), CFrame.new(g + Vector3.new(math.cos(ang) * 3, 3, math.sin(ang) * 3)) * CFrame.Angles(math.cos(ang) * 0.4, 0, math.sin(ang) * 0.4), Color3.fromRGB(150, 110, 80), { Material = Enum.Material.Plastic }, 2.5)
		end
		for _, h in near(g, a.Radius) do
			hurt(h[1], a.Damage)
			rootIn(h[1], a.Root)
		end
	end
end

-- Bogstorm Croaker: puffs its glowing throat sac and croaks a thunder wave
F.ThunderWave = function(ctx, a)
	ctx.Play("Ability1")
	local c = circle(ctx.Root.Position, a.Radius, Color3.fromRGB(150, 230, 255), a.Windup)
	if not ctx.Alive() then
		return
	end
	ring(c, a.Radius, Color3.fromRGB(200, 240, 255))
	burst(c, Color3.fromRGB(220, 245, 255), 40)
	for _, h in near(c, a.Radius) do
		bolt(ctx.Root.Position + Vector3.new(0, 6, 0), h[2].Position)
		if not airborne(h) and not h[1]:GetAttribute("ElectricImmune") then
			hurt(h[1], a.Damage)
			h[1]:SetAttribute("ShockedUntil", now() + a.Shock)
		end
	end
end
-- Bogstorm Croaker: a long tongue lashes down a line and yanks players in
F.TongueSweep = function(ctx, a)
	local from = ctx.Root.Position
	local dir = flatDir(from, ctx.TargetRoot.Position)
	face(ctx, ctx.TargetRoot.Position)
	lineTel(from, dir, a.Length, a.Width, RED, a.Windup)
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	ctx.Play("Ability2")
	local mid = from + dir * (a.Length / 2) + Vector3.new(0, 2, 0)
	fx(Vector3.new(1.6, 1, a.Length), CFrame.lookAt(mid, mid + dir), Color3.fromRGB(230, 110, 140), { Material = Enum.Material.Plastic }, 0.4)
	for _, h in inStrip(from, dir, a.Length, a.Width) do
		hurt(h[1], a.Damage)
		knock(h[1], -dir * a.Pull + Vector3.new(0, 20, 0))
	end
end

-- Prism Sovereign: three waves of refracting crystal shards in a fan
F.ShardBarrage = function(ctx, a)
	ctx.Play("Ability1")
	for w = 1, a.Waves do
		if not ctx.Alive() then
			return
		end
		face(ctx, ctx.TargetRoot.Position)
		local from = ctx.Root.Position + Vector3.new(0, 3, 0)
		local base = flatDir(from, ctx.TargetRoot.Position)
		for i = 1, a.Shards do
			local ang = math.rad((i - (a.Shards + 1) / 2) * a.Spread + (w % 2 == 0 and a.Spread / 2 or 0))
			local dir = CFrame.Angles(0, ang, 0):VectorToWorldSpace(base)
			projectile(from, dir, 75, a.Range, 3, Color3.fromRGB(120, 200, 255), Vector3.new(1, 1, 3.4), function(p)
				hurt(p, a.Damage)
				slow(p, a.Slow, a.SlowTime)
			end)
		end
		task.wait(0.55)
	end
end
-- Prism Sovereign: crystal walls erupt along parallel lanes; stand between them
F.CrystalWalls = function(ctx, a)
	bossRoar(ctx, Color3.fromRGB(140, 200, 255))
	local from = ctx.Root.Position
	local dir = flatDir(from, ctx.TargetRoot.Position)
	local right = dir:Cross(Vector3.yAxis)
	local lanes = {}
	for k = 1, a.Lanes do
		local off = right * ((k - (a.Lanes + 1) / 2) * a.Width * 2)
		table.insert(lanes, from + off)
		lineTel(from + off, dir, a.Length, a.Width, Color3.fromRGB(120, 180, 255), a.Windup)
	end
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	for _, start in lanes do
		for k = 1, 7 do
			local p = ground(start + dir * (k * a.Length / 7))
			fx(Vector3.new(a.Width * 0.8, 10, 3), CFrame.lookAt(p + Vector3.new(0, 5, 0), p + Vector3.new(0, 5, 0) + dir) * CFrame.Angles(0, 0, math.rad(math.random(-10, 10))),
				Color3.fromRGB(110, 180, 255), { Material = Enum.Material.Glass, Transparency = 0.2 }, 1.8)
		end
		for _, h in inStrip(start, dir, a.Length, a.Width) do
			hurt(h[1], a.Damage)
			knock(h[1], Vector3.new(0, 55, 0), 0.5)
		end
	end
end

-- Caldera Titan: lava lanes fan out from the titan and erupt
F.LavaLanes = function(ctx, a)
	ctx.Play("Ability1")
	local from = ctx.Root.Position
	local base = flatDir(from, ctx.TargetRoot.Position)
	local dirs = {}
	for k = 1, a.Lanes do
		local dir = CFrame.Angles(0, math.rad((k - (a.Lanes + 1) / 2) * 24), 0):VectorToWorldSpace(base)
		table.insert(dirs, dir)
		lineTel(from, dir, a.Length, a.Width, ORANGE, a.Windup)
	end
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	for _, dir in dirs do
		local mid = ground(from + dir * (a.Length / 2))
		fx(Vector3.new(a.Width, 0.6, a.Length), CFrame.lookAt(mid + Vector3.new(0, 0.3, 0), mid + Vector3.new(0, 0.3, 0) + dir), Color3.fromRGB(255, 110, 40), {}, 1.5)
		for k = 1, 4 do
			burst(ground(from + dir * (k * a.Length / 4)), Color3.fromRGB(255, 170, 70), 10)
		end
		for _, h in inStrip(from, dir, a.Length, a.Width) do
			hurt(h[1], a.Damage)
			burn(h[1], a.Burn)
		end
	end
end
-- Caldera Titan: jumps and crashes down; the whole crater shakes (jump to dodge)
F.CraterStomp = function(ctx, a)
	ctx.Play("Ability2")
	local c = circle(ctx.Root.Position, a.Radius, RED, a.Windup)
	if not ctx.Alive() then
		return
	end
	ring(c, a.Radius, Color3.fromRGB(255, 140, 60))
	burst(c, Color3.fromRGB(255, 120, 40), 50)
	for _, h in near(c, a.Radius) do
		if not airborne(h) then
			hurt(h[1], a.Damage)
			knock(h[1], flatDir(c, h[2].Position) * a.Knock + Vector3.new(0, 40, 0), 0.8)
		end
	end
end

-- Tidebreaker: a wall of water rolls forward and shoves everyone back
F.TideWall = function(ctx, a)
	local from = ctx.Root.Position
	local dir = flatDir(from, ctx.TargetRoot.Position)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	lineTel(from, dir, a.Length, a.Width, Color3.fromRGB(90, 180, 255), a.Windup)
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	local wall = fx(Vector3.new(a.Width, 10, 3), CFrame.lookAt(ground(from) + Vector3.new(0, 5, 0), ground(from) + Vector3.new(0, 5, 0) + dir), Color3.fromRGB(80, 170, 240),
		{ Material = Enum.Material.Glass, Transparency = 0.3 }, 1.6)
	TweenService:Create(wall, TweenInfo.new(1.1, Enum.EasingStyle.Linear), { CFrame = wall.CFrame + dir * a.Length }):Play()
	local hit = {}
	for _ = 1, 11 do
		for _, h in near(wall.Position, a.Width / 2 + 2) do
			local rel = h[2].Position - wall.Position
			if not hit[h[1]] and math.abs(rel:Dot(dir)) < 4 then
				hit[h[1]] = true
				hurt(h[1], a.Damage)
				slow(h[1], 0.6, 2)
				knock(h[1], dir * a.Knock + Vector3.new(0, 25, 0), 0.6)
			end
		end
		task.wait(0.1)
	end
end
-- Tidebreaker: sprays a cone of ink in front of it (blinds)
F.InkSweep = function(ctx, a)
	face(ctx, ctx.TargetRoot.Position)
	local from = ctx.Root.Position
	local dir = flatDir(from, ctx.TargetRoot.Position)
	lineTel(from, dir, a.Radius, a.Radius * 0.9, Color3.fromRGB(60, 40, 90), a.Windup)
	task.wait(a.Windup)
	if not ctx.Alive() then
		return
	end
	ctx.Play("Ability2")
	for k = 1, 6 do
		burst(from + dir * (k * a.Radius / 6) + Vector3.new(0, 2, 0), Color3.fromRGB(40, 30, 60), 12)
	end
	for _, h in near(from, a.Radius) do
		local rel = flatDir(from, h[2].Position)
		if math.deg(math.acos(math.clamp(rel:Dot(dir), -1, 1))) <= a.Cone / 2 then
			hurt(h[1], a.Damage)
			blind(h[1], a.Blind)
		end
	end
end

-- Shardstorm (v2.18, crystal whirlwind) ---------------------------------
-- Prism Vortex: a glittering whirl that drags players in and nicks them
F.PrismVortex = function(ctx, a)
	ctx.Play("Ability2")
	local t0 = os.clock()
	local nextTick = 0
	while os.clock() - t0 < a.Duration and ctx.Alive() do
		local c = ctx.Root.Position
		ring(c - Vector3.new(0, 3, 0), a.Range * 0.6, Color3.fromRGB(150, 210, 255))
		for k = 1, 3 do
			local ang = os.clock() * 6 + k * 2.1
			fx(Vector3.new(0.6, 1.6, 0.6), CFrame.new(c + Vector3.new(math.cos(ang) * 8, 1, math.sin(ang) * 8)) * CFrame.Angles(0, -ang, 0.5), Color3.fromRGB(140, 200, 255),
				{ Material = Enum.Material.Glass, Transparency = 0.2 }, 0.3)
		end
		for _, h in near(c, a.Range) do
			knock(h[1], flatDir(h[2].Position, c) * a.Pull)
			if os.clock() >= nextTick and (h[2].Position - c).Magnitude < 14 then
				hurt(h[1], a.Damage)
				slow(h[1], a.Slow, 1)
			end
		end
		if os.clock() >= nextTick then
			nextTick = os.clock() + 0.5
		end
		task.wait(0.25)
	end
end
-- Shard Cyclone: spins up, then fires a full ring of crystal shards outward
F.ShardCyclone = function(ctx, a)
	ctx.Play("Ability1")
	local c = circle(ctx.Root.Position, 10, Color3.fromRGB(150, 210, 255), a.Windup)
	if not ctx.Alive() then
		return
	end
	burst(c, Color3.fromRGB(170, 230, 255), 30)
	for k = 1, a.Shards do
		local ang = k / a.Shards * math.pi * 2
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		projectile(ctx.Root.Position + Vector3.new(0, 1, 0), dir, 55, a.Range, 3, k % 2 == 0 and Color3.fromRGB(160, 130, 255) or Color3.fromRGB(110, 190, 255),
			Vector3.new(0.7, 0.7, 2.6), function(p)
				hurt(p, a.Damage)
				slow(p, a.Slow, a.SlowTime)
			end)
	end
end

Abilities.F = F
Abilities.Burst = burst

-- Basic melee contact attack (all monsters)
function Abilities.Melee(ctx, melee)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	task.wait(0.2)
	if ctx.Alive() and (ctx.TargetRoot.Position - ctx.Root.Position).Magnitude <= melee.Range + 1 then
		hurt(ctx.Target, melee.Damage)
		local tp = ctx.TargetRoot.Position
		local dir = (tp - ctx.Root.Position)
		dir = dir.Magnitude > 0.1 and dir.Unit or nil
		styledHit(curStyle(), tp, Color3.fromRGB(255, 120, 90), 14, dir) -- v2.23 own melee hit
		if melee.Trip then
			slipNow(ctx.Target)
		end
	end
end

-- Burn damage over time (BurnUntil) — called once a second by MonsterService
function Abilities.BurnTick()
	local t = now()
	for _, p in Players:GetPlayers() do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local burning = (p:GetAttribute("BurnUntil") or 0) > t
		if hum and root then
			local fire = root:FindFirstChild("MonsterBurn")
			if burning and hum.Health > 0 then
				hurt(p, 4)
				if not fire then
					fire = Instance.new("Fire")
					fire.Name = "MonsterBurn"
					fire.Size = 5
					fire.Parent = root
				end
			elseif fire then
				fire:Destroy()
			end
		end
	end
end

return Abilities
