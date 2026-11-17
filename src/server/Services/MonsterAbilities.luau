-- The 26 monster abilities (2 per monster) + shared effect helpers.
-- Every dangerous move is telegraphed first (red/orange ground circle, line
-- or wind-up animation) so players can dodge. All effect parts are cleaned
-- up with Debris; nothing keeps running after its owner dies.
--
-- An ability is fn(ctx, a) where a = its entry in MonsterDefs and ctx =
--   { Model, Root, Hum, Target (Player), TargetRoot, Alive() -> bool,
--     Play(animName), Summon(typeName, pos), SetDamageMult(mult, seconds) }

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Abilities = {}

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
		hum:TakeDamage(dmg * (1 - (p:GetAttribute("DamageResist") or 0)))
	end
end
local hurt = Abilities.Hurt

local function knock(p: Player, velocity: Vector3, stun: number?)
	if shielded(p) then
		return
	end
	local resist = p:GetAttribute("BlastResist") and 0.5 or 1
	Remotes.Knock:FireClient(p, velocity * resist)
	if stun then
		p:SetAttribute("RagdollUntil", now() + stun)
	end
end
local function slow(p: Player, mult: number, seconds: number)
	p:SetAttribute("MonsterSlow", mult)
	p:SetAttribute("MonsterSlowUntil", now() + seconds)
end
local function rootIn(p: Player, seconds: number)
	p:SetAttribute("RootedUntil", now() + seconds)
end
local function slipNow(p: Player)
	p:SetAttribute("SlipAt", now())
end
local function blind(p: Player, seconds: number)
	p:SetAttribute("BlindUntil", now() + seconds)
end
local function burn(p: Player, seconds: number)
	if not p:GetAttribute("FireImmune") then
		p:SetAttribute("BurnUntil", now() + seconds)
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
	task.wait(time)
	return g
end

local function ring(pos: Vector3, radius: number, color: Color3)
	local r = fx(Vector3.new(0.3, 2, 2), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, {
		Shape = Enum.PartType.Cylinder, Transparency = 0.2,
	}, 0.6)
	TweenService:Create(r, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, radius * 2, radius * 2), Transparency = 1,
	}):Play()
end

local function burst(pos: Vector3, color: Color3, count: number)
	local a = fx(Vector3.one, CFrame.new(pos), color, { Transparency = 1 }, 2)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(1, 0)
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(14, 26)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
end

-- straight projectile; onHit(player) once; stops at first player or range
local function projectile(from: Vector3, dir: Vector3, speed: number, range: number, radius: number, color: Color3, size: Vector3, onHit)
	local p = fx(size, CFrame.lookAt(from, from + dir), color, nil, range / speed + 0.5)
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
				burst(p.Position, color, 10)
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

Abilities.F = F
Abilities.Burst = burst

-- Basic melee contact attack (all monsters)
function Abilities.Melee(ctx, melee)
	face(ctx, ctx.TargetRoot.Position)
	ctx.Play("Ability1")
	task.wait(0.2)
	if ctx.Alive() and (ctx.TargetRoot.Position - ctx.Root.Position).Magnitude <= melee.Range + 1 then
		hurt(ctx.Target, melee.Damage)
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
