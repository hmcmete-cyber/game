-- MONSTERS: spawning per habitat, AI, damage, XP, cleanup.
--
--   workspace.Monsters.<Habitat>.<Name>   e.g. workspace.Monsters.Canyon.Prismaw
--   tag "Monster", attributes MonsterType, Habitat
--
-- Brain (every 0.25 s, only while a player is within WakeRadius):
--   * targets players CARRYING a cloud inside Aggro (or anyone who hit it in
--     the last 10 s); never targets inside the Sky Heart safe radius
--   * picks a ready ability whose range fits, else melee, else walks closer
--   * never leaves its habitat (BiomeMap) or strays > Tether from home: it
--     walks back, healing, and drops the chase
-- Death: Death animation, XP (killer 100 %, helpers >= 10 % damage get 50 %),
-- fade, cleanup of all connections; respawns after Respawn seconds.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Defs = require(ReplicatedStorage.Shared.MonsterDefs)
local BiomeMap = require(ReplicatedStorage.Shared.BiomeMap)
local MonsterRigs = require(script.Parent:WaitForChild("MonsterRigs"))
local MonsterAnims = require(script.Parent:WaitForChild("MonsterAnims"))
local Abilities = require(script.Parent:WaitForChild("MonsterAbilities"))
local MonsterDeaths = require(script.Parent:WaitForChild("MonsterDeaths"))
local Sfx = require(game:GetService("ReplicatedStorage").Shared.Sfx)
local HazardService = require(script.Parent:WaitForChild("HazardService"))

local MonsterService = {}

local MapService, DataService, Remotes
local root: Folder
local monsters = {} -- [Model] = info
local reported = {} -- [typeName] = true once its track count was printed

local function now(): number
	return workspace:GetServerTimeNow()
end

local function habitatFolder(habitat: string): Folder
	local f = root:FindFirstChild(habitat)
	if not f then
		f = Instance.new("Folder")
		f.Name = habitat
		f.Parent = root
	end
	return f :: Folder
end

local function habitatOf(pos: Vector3): string?
	local deg, rOld = BiomeMap.Polar(pos)
	return BiomeMap.HabitatAt(deg, rOld)
end

local function inSafeZone(pos: Vector3): boolean
	return Vector2.new(pos.X, pos.Z).Magnitude < Defs.SafeRadius
end

------------------------------------------------------------------------
-- health bar
------------------------------------------------------------------------
local function healthBar(info)
	local def = info.Def
	local gui = Instance.new("BillboardGui")
	gui.Name = "MonsterBar"
	gui.Size = UDim2.fromOffset(200, 44)
	-- above the model's real top (no more labels inside tall bodies)
	local bcf, bsize = info.Model:GetBoundingBox()
	local top = bcf.Position.Y + bsize.Y / 2 - info.Root.Position.Y
	-- v2.15: world-space offset (never drifts into the head with the camera angle)
	gui.StudsOffset = Vector3.zero
	gui.StudsOffsetWorldSpace = Vector3.new(0, top + (def.Boss and 6 or 3), 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.5, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Text = info.Type -- director: only the monster's name above its head
	if def.Boss then
		-- bosses: big gold name readable from far away, health bar always on
		gui.Size = UDim2.fromOffset(340, 70)
		gui.MaxDistance = 320
		name.Text = def.Title
		name.TextColor3 = Color3.fromRGB(255, 215, 90)
	end
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Visible = false -- the health bar appears only once the monster is hurt
	back.Position = UDim2.fromScale(0.1, 0.62)
	back.Size = UDim2.fromScale(0.8, 0.22)
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 25)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	gui.Parent = info.Root
	table.insert(info.Conns, info.Hum.HealthChanged:Connect(function(hp)
		fill.Size = UDim2.fromScale(math.clamp(hp / info.Hum.MaxHealth, 0, 1), 1)
		back.Visible = def.Boss or hp < info.Hum.MaxHealth
	end))
	if def.Boss then
		back.Visible = true
	end
end

------------------------------------------------------------------------
-- spawning
------------------------------------------------------------------------
local spawnMonster -- forward
local bossArrival -- forward

-- v2.10 bosses spawn on their temple arena (Map/Temples/<Biome>/BossSpawn)
local function arenaSpawn(biome: string): Vector3?
	local map = workspace:FindFirstChild("Map")
	local temples = map and map:FindFirstChild("Temples")
	local t = temples and temples:FindFirstChild(biome)
	local sp = t and t:FindFirstChild("BossSpawn")
	return sp and (sp :: BasePart).Position or nil
end

local function pickSpawn(habitat: string): Vector3?
	local list = {}
	for _, s in MapService.GetSpawns() do
		if s:GetAttribute("Biome") == habitat and not inSafeZone(s.Position) then
			local clear = true
			for m in monsters do
				if m.PrimaryPart and (m.PrimaryPart.Position - s.Position).Magnitude < 30 then
					clear = false
					break
				end
			end
			if clear then
				table.insert(list, s.Position)
			end
		end
	end
	return #list > 0 and list[math.random(1, #list)] or nil
end

local function play(info, name: string)
	local t = info.Tracks[name]
	if t then
		t:Play(0.1)
	end
end

local function onDeath(info)
	if not info.Alive then
		return
	end
	info.Alive = false
	for _, c in info.Conns do
		c:Disconnect()
	end
	for name, t in info.Tracks do
		if name ~= "Death" then
			t:Stop(0.1)
		end
	end
	play(info, "Death")

	if info.LastHitBy and info.LastHitBy.Parent then
		info.LastHitBy:SetAttribute("LastKillAt", now()) -- pets: "after a kill" buffs
	end
	-- XP: killer 100 %, helpers with >= 10 % of the damage get AssistShare
	local total = 0
	for _, d in info.Damage do
		total += d
	end
	for p, d in info.Damage do
		if p.Parent then
			local share = (p == info.LastHitBy) and 1 or ((total > 0 and d / total >= 0.1) and Defs.AssistShare or 0)
			local xp = math.floor(info.Def.XP * share * (1 + (p:GetAttribute("PetXP") or 0)))
			if xp > 0 then
				if MonsterService.OnPlayerXP then
					task.spawn(MonsterService.OnPlayerXP, p, xp) -- pets level up from this
				end
				local levelUp = DataService.AddXP(p, xp)
				Remotes.Hint:FireClient(p, `+{xp} XP!`, 3)
				if levelUp then
					Remotes.Hint:FireClient(p, `Level {levelUp}!`, 4)
				end
			end
		end
	end

	-- v2.12: every species has its own death sequence (MonsterDeaths)
	local model = info.Model
	MonsterDeaths.Play(info, function()
		monsters[model] = nil
		model:Destroy()
	end)
	if not info.Def.Summon then
		task.delay(info.Def.Respawn, function()
			spawnMonster(info.Type)
		end)
	end
end

-- v2.12 boss spectacle: a themed aura around the body, smoke/embers/sparkles
-- from its signature part, and a little glow emitter on every neon detail
local BOSS_FX = {
	MesaColossus = { Color3.fromRGB(230, 200, 150), Color3.fromRGB(255, 220, 120), "Mesa" },
	FrostpeakWarden = { Color3.fromRGB(240, 250, 255), Color3.fromRGB(150, 230, 255), "Helm" },
	MyceliumMonarch = { Color3.fromRGB(255, 170, 220), Color3.fromRGB(190, 255, 210), "Crown" },
	BogstormCroaker = { Color3.fromRGB(170, 220, 255), Color3.fromRGB(230, 245, 255), "Sac" },
	PrismSovereign = { Color3.fromRGB(150, 210, 255), Color3.fromRGB(200, 170, 255), "Heart" },
	CalderaTitan = { Color3.fromRGB(255, 140, 50), Color3.fromRGB(80, 70, 70), "CraterLava" },
	Tidebreaker = { Color3.fromRGB(180, 230, 255), Color3.fromRGB(255, 150, 190), "Shell" },
}
local function bossAura(model: Model, typeName: string)
	local fx = BOSS_FX[typeName]
	if not fx then
		return
	end
	local root = model.PrimaryPart
	local function emitter(parent: Instance, color: Color3, rate: number, size: number, speed: number, accel: Vector3, life: number, smoke: boolean?)
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(color)
		e.Rate = rate
		e.Size = NumberSequence.new(size, smoke and size * 2.5 or 0)
		e.Transparency = NumberSequence.new(smoke and 0.4 or 0, 1)
		e.Lifetime = NumberRange.new(life * 0.6, life)
		e.Speed = NumberRange.new(speed * 0.5, speed)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = accel
		e.LightEmission = smoke and 0 or 0.9
		if smoke then
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		end
		e.Parent = parent
	end
	emitter(root, fx[1], 60, 0.8, 7, Vector3.new(0, 3, 0), 2.5)
	emitter(root, fx[2], 25, 1.4, 3, Vector3.new(0, 1, 0), 3)
	emitter(root, fx[1], 14, 3, 1, Vector3.new(0, 0.5, 0), 4, true)
	local sig = model:FindFirstChild(fx[3], true)
	if sig then
		emitter(sig, fx[1], 25, 1, 8, Vector3.new(0, 6, 0), 2)
		emitter(sig, fx[2], 6, 3, 4, Vector3.new(0, 4, 0), 4, typeName == "CalderaTitan")
	end
	local n = 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon and n < 24 then
			n += 1
			emitter(p, p.Color, 5, 0.35, 2, Vector3.new(0, 2, 0), 1.5)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = fx[1]
	light.Range = 40
	light.Brightness = 2
	light.Parent = root
end

-- boss (re)spawn: a beam from the sky, shock rings, a burst and a banner
bossArrival = function(model: Model, pos: Vector3)
	local fx = BOSS_FX[model:GetAttribute("MonsterType") or model.Name]
	local color = fx and fx[1] or Color3.fromRGB(255, 220, 120)
	local beam = Instance.new("Part")
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.3
	beam.Size = Vector3.new(200, 2, 2)
	beam.CFrame = CFrame.new(pos + Vector3.new(0, 100, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(0.6), { Size = Vector3.new(200, 22, 22) }):Play()
	task.delay(1.4, function()
		TweenService:Create(beam, TweenInfo.new(1), { Size = Vector3.new(200, 1, 1), Transparency = 1 }):Play()
	end)
	game:GetService("Debris"):AddItem(beam, 3)
	Sfx.At("BossArrive", pos)
	for k = 1, 3 do
		task.delay(k * 0.25, function()
			Abilities.BossRoar(model, color)
		end)
	end
	for _, p in Players:GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and (r.Position - pos).Magnitude < 220 and Remotes and Remotes.Hint then
			Remotes.Hint:FireClient(p, `⚡ {Defs.Types[model:GetAttribute("MonsterType")].Title} has appeared!`, 4)
		end
	end
end

-- QA Respawner: bring back every defeated monster and boss right now
-- (fills each species up to its Count; living ones are left alone)
function MonsterService.RespawnAll(): number
	local n = 0
	for _, typeName in Defs.Order do
		local def = Defs.Types[typeName]
		if not def.Summon then
			local alive = 0
			for _, info in monsters do
				if info.Type == typeName and info.Alive then
					alive += 1
				end
			end
			for _ = alive + 1, def.Count do
				if spawnMonster(typeName) then
					n += 1
				end
			end
		end
	end
	return n
end

-- QA: remove the living boss of this type (no reward) and bring it back now
function MonsterService.RespawnBoss(typeName: string)
	for m, info in monsters do
		if info.Type == typeName then
			info.Alive = false
			for _, c in info.Conns do
				c:Disconnect()
			end
			monsters[m] = nil
			m:Destroy()
		end
	end
	return spawnMonster(typeName)
end

spawnMonster = function(typeName: string, at: Vector3?, life: number?, target: Player?)
	local def = Defs.Types[typeName]
	-- never above a species' Count (QA respawns + death timers can overlap)
	if not at and not def.Summon then
		local alive = 0
		for _, other in monsters do
			if other.Type == typeName and other.Alive then
				alive += 1
			end
		end
		if alive >= def.Count then
			return nil
		end
	end
	if def.Boss then
		-- one of each boss at a time (QA respawns + the death timer can overlap)
		for _, other in monsters do
			if other.Type == typeName and other.Alive then
				return nil
			end
		end
	end
	local pos = at or (def.Arena and arenaSpawn(def.Arena)) or (not def.Arena and pickSpawn(def.Habitat)) or nil
	if not pos then
		task.delay(30, function()
			spawnMonster(typeName)
		end)
		return nil
	end
	local model = MonsterRigs.Build(typeName, def.Scale)
	model:SetAttribute("MonsterType", typeName)
	model:SetAttribute("Habitat", def.Habitat)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.MaxHealth = def.HP
	hum.Health = def.HP
	hum.WalkSpeed = def.Speed
	hum.HipHeight += def.Hover or 0
	if def.Rooted then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end
	model:PivotTo(CFrame.new(pos + Vector3.new(0, 4 + (def.Hover or 0), 0)) * CFrame.Angles(0, math.random() * 6.28, 0))
	model.Parent = habitatFolder(def.Habitat)
	CollectionService:AddTag(model, "Monster")
	local r = model.PrimaryPart :: BasePart
	pcall(function()
		r:SetNetworkOwner(nil)
	end)

	local info = {
		Type = typeName, Def = def, Model = model, Root = r, Hum = hum, Home = pos,
		Alive = true, Busy = false, Target = target, Aggro = {}, Damage = {}, LastHitBy = nil,
		Cooldowns = {}, MeleeReady = 0, DamageMult = 1, MultUntil = 0, Conns = {}, Tracks = {},
		NextRoam = 0, Returning = false, LastHit = 0, Expires = life and (os.clock() + life) or nil,
	}
	-- stagger first ability use so monsters don't open with everything at once
	for i, a in def.Abilities do
		info.Cooldowns[i] = os.clock() + math.random() * a.Cooldown * 0.6
	end
	monsters[model] = info
	info.Tracks = MonsterAnims.Load(typeName, model)
	if not reported[typeName] then
		reported[typeName] = true
		local n = 0
		for _ in info.Tracks do
			n += 1
		end
		print(`[Monsters] {typeName}: {n}/6 animation tracks loaded (gait {def.Gait or "?"})`)
	end
	play(info, "Idle")
	healthBar(info)
	if def.Boss then
		bossAura(model, typeName)
		bossArrival(model, pos)
	end
	table.insert(info.Conns, hum.Died:Connect(function()
		onDeath(info)
	end))
	return model
end
MonsterService.Spawn = spawnMonster

------------------------------------------------------------------------
-- damage from players (CombatService, Laser, Quake, Flare)
------------------------------------------------------------------------
function MonsterService.Get(model: Instance)
	while model and model ~= workspace do
		if monsters[model] then
			return monsters[model]
		end
		model = model.Parent :: Instance
	end
	return nil
end

function MonsterService.Damage(model: Instance, amount: number, player: Player?, _kind: string?)
	local info = MonsterService.Get(model)
	if not info or not info.Alive then
		return false
	end
	local mult = os.clock() < info.MultUntil and info.DamageMult or 1
	local dmg = amount * mult
	info.Hum:TakeDamage(dmg)
	if player then
		info.Damage[player] = (info.Damage[player] or 0) + dmg
		info.LastHitBy = player
		info.Aggro[player] = now() + 10
		if not info.Target then
			info.Target = player
		end
	end
	-- enrage at low health
	if not info.Enraged and info.Hum.Health > 0 and info.Hum.Health / info.Hum.MaxHealth < Defs.EnrageAt then
		info.Enraged = true
		info.Hum.WalkSpeed *= Defs.EnrageSpeed
		local hl = Instance.new("Highlight")
		hl.Name = "Enraged"
		hl.FillColor = Color3.fromRGB(255, 60, 40)
		hl.FillTransparency = 0.75
		hl.OutlineColor = Color3.fromRGB(255, 120, 60)
		hl.Parent = info.Model
		Abilities.Burst(info.Root.Position + Vector3.new(0, 3, 0), Color3.fromRGB(255, 80, 50), 30)
	end
	-- pack: neighbours of the same habitat join the fight
	if player and not info.Def.Boss then
		for _, other in monsters do
			if other ~= info and other.Alive and not other.Target and other.Def.Habitat == info.Def.Habitat
				and (other.Root.Position - info.Root.Position).Magnitude <= Defs.PackRadius then
				other.Aggro[player] = now() + 8
				other.Target = player
			end
		end
	end
	if not info.Busy and os.clock() - info.LastHit > 0.5 then
		info.LastHit = os.clock()
		play(info, "Hit")
	end
	Abilities.Burst(info.Root.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 240, 200), 6)
	-- hit sound (pets play their own); throttled per monster
	if _kind ~= "Pet" and os.clock() - (info.LastHitSfx or 0) > 0.08 then
		info.LastHitSfx = os.clock()
		local cue = (_kind == "Laser" or _kind == "Flare") and "HitLaser" or ((_kind == "Slam" or _kind == "Quake") and "HitQuake")
			or ((_kind == "Gadget" or _kind == "Blast") and "HitGadget") or "HitPunch"
		Sfx.At(info.Def.Boss and "HitBoss" or cue, info.Root.Position)
	end
	return true
end

------------------------------------------------------------------------
-- brain
------------------------------------------------------------------------
local function playerRoot(p: Player): (BasePart?, Humanoid?)
	local char = p.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?, char and char:FindFirstChildOfClass("Humanoid")
end

local function validTarget(info, p: Player?): boolean
	if not p or not p.Parent then
		return false
	end
	local r, h = playerRoot(p)
	if not r or not h or h.Health <= 0 or inSafeZone(r.Position) then
		return false
	end
	-- bosses guard their arena: anyone who walks into range is attacked
	local wanted = info.Def.Boss or p:GetAttribute("Carrying") ~= nil or (info.Aggro[p] or 0) > now()
	return wanted and (r.Position - info.Root.Position).Magnitude <= info.Def.Aggro * 1.5
end

local function findTarget(info): Player?
	local best, bestD = nil, info.Def.Aggro
	for _, p in Players:GetPlayers() do
		local r = playerRoot(p)
		if r then
			local d = (r.Position - info.Root.Position).Magnitude / math.max(0.3, 1 - (p:GetAttribute("PetStealth") or 0))
			if d <= bestD and validTarget(info, p) then
				best, bestD = p, d
			end
		end
	end
	return best
end

local function anyoneNear(pos: Vector3): boolean
	for _, p in Players:GetPlayers() do
		local r = playerRoot(p)
		if r and (r.Position - pos).Magnitude < Defs.WakeRadius then
			return true
		end
	end
	return false
end

local function hazardTick(info)
	for _, h in MapService.GetHazards() do
		local kind = h:GetAttribute("HazardType")
		if (kind == "Lava" and info.Def.Habitat ~= "Volcanic") or (kind == "Electric" and info.Def.Habitat ~= "Marsh") then
			if HazardService.Inside(h, info.Root.Position) then
				MonsterService.Damage(info.Model, kind == "Lava" and 8 or 3, nil, "Hazard")
				return
			end
		end
	end
end

-- v2.3 locomotion state (runs every 0.1 s, separate from the brain):
-- moving = real ground speed (not MoveDirection, which stayed 0 for most
-- server-driven monsters -> they slid in their idle pose). The Walk loop
-- starts/stops only on state CHANGES (no restarting every frame) and its
-- cadence follows the actual speed, so chasing looks faster than roaming.
local function animTick(info)
	local walk, idle = info.Tracks.Walk, info.Tracks.Idle
	if idle and not idle.IsPlaying then
		idle:Play(0.3)
	end
	if not walk or info.Def.Rooted then
		return
	end
	local v = info.Root.AssemblyLinearVelocity
	local speed = Vector2.new(v.X, v.Z).Magnitude
	local moving = speed > 1.5
	if moving ~= info.Moving then
		info.Moving = moving
		if moving then
			walk:Play(0.15)
		else
			walk:Stop(0.25)
		end
	end
	if moving then
		walk:AdjustSpeed(math.clamp(speed / math.max(info.Def.Speed, 1), 0.6, 1.6))
	end
end

local function makeCtx(info, target: Player, targetRoot: BasePart)
	return {
		Model = info.Model, Root = info.Root, Hum = info.Hum, Target = target, TargetRoot = targetRoot,
		Alive = function()
			return info.Alive and targetRoot.Parent ~= nil
		end,
		Play = function(name)
			play(info, name)
		end,
		Summon = function(typeName, pos, life)
			spawnMonster(typeName, pos, life, target)
		end,
		SetDamageMult = function(mult, seconds)
			info.DamageMult = mult
			info.MultUntil = os.clock() + seconds
		end,
	}
end

local function runAction(info, fn, ...)
	info.Busy = true
	info.Hum:MoveTo(info.Root.Position)
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(fn, table.unpack(args, 1, args.n))
		if not ok then
			warn(`[Monsters] {info.Type} ability failed: {err}`)
		end
		-- recovery window after a special ability (fair counter-attack moment)
		task.wait(info.RecoverNext or 0.3)
		info.RecoverNext = nil
		info.Busy = false
	end)
end

local function think(info)
	local def = info.Def
	if info.Expires and os.clock() > info.Expires then
		info.Hum.Health = 0
		return
	end
	hazardTick(info)
	if not info.Alive or info.Busy then
		return
	end

	-- tether: never leave the habitat / stray too far from home
	local here = info.Root.Position
	local strayed = (here - info.Home).Magnitude > (def.Tether or Defs.Tether)
	local habitat = habitatOf(here)
	if not def.Summon and habitat ~= def.Habitat and habitat ~= nil and (here - info.Home).Magnitude > 20 then
		strayed = true
	end
	if strayed or info.Returning then
		info.Returning = (here - info.Home).Magnitude > 12
		info.Target = nil
		info.Hum:MoveTo(info.Home)
		info.Hum.Health = math.min(info.Hum.MaxHealth, info.Hum.Health + info.Hum.MaxHealth * 0.02)
		return
	end

	if not validTarget(info, info.Target) then
		info.Target = findTarget(info)
		-- boss introduction: roar + shockwave + a banner for everyone nearby
		if info.Target and def.Boss and not info.Introduced then
			info.Introduced = true
			Abilities.BossRoar(info.Model, Color3.fromRGB(255, 220, 120))
			for _, p in Players:GetPlayers() do
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r and (r.Position - info.Root.Position).Magnitude < 160 and Remotes and Remotes.Hint then
					Remotes.Hint:FireClient(p, `⚠ {def.Title} awakens!`, 4)
				end
			end
		end
	end
	local target = info.Target
	if not target then
		-- roam inside the habitat
		if not def.Rooted and os.clock() > info.NextRoam then
			info.NextRoam = os.clock() + math.random(4, 9)
			for _ = 1, 4 do
				local p = info.Home + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40))
				if def.Summon or habitatOf(p) == def.Habitat then
					info.Hum:MoveTo(p)
					break
				end
			end
		end
		return
	end

	local tRoot = playerRoot(target)
	if not tRoot then
		return
	end
	local dist = (tRoot.Position - here).Magnitude
	-- try the abilities in random order
	local order = {}
	for i in def.Abilities do
		table.insert(order, i)
	end
	if #order == 2 and math.random() < 0.5 then
		order[1], order[2] = order[2], order[1]
	end
	for _, i in order do
		local a = def.Abilities[i]
		if os.clock() >= info.Cooldowns[i] and dist <= a.Range then
			info.Cooldowns[i] = os.clock() + a.Cooldown * (info.Enraged and Defs.EnrageCooldown or 1)
			info.RecoverNext = Defs.Recovery
			Sfx.At(Sfx.ElementOf(a.Id), info.Root.Position, (def.Boss and 0.75 or 1) * Sfx.PitchFor(a.Id)) -- cast sound by element, pitched per ability
			runAction(info, Abilities.F[a.Id], makeCtx(info, target, tRoot), a)
			return
		end
	end
	if dist <= def.Melee.Range and os.clock() >= info.MeleeReady then
		info.MeleeReady = os.clock() + def.Melee.Cooldown
		Sfx.At("Melee", info.Root.Position, def.Boss and 0.7 or 1)
		runAction(info, Abilities.Melee, makeCtx(info, target, tRoot), def.Melee)
		return
	end
	if not def.Rooted then
		info.Hum:MoveTo(tRoot.Position)
	end
end

------------------------------------------------------------------------

function MonsterService.Start(mapService, dataService, remotes)
	MapService, DataService, Remotes = mapService, dataService, remotes
	Abilities.Init(remotes)
	root = Instance.new("Folder")
	root.Name = "Monsters"
	root.Parent = workspace

	task.spawn(function()
		task.wait(3) -- let the map finish
		local n = 0
		for _, typeName in Defs.Order do
			for _ = 1, Defs.Types[typeName].Count do
				if spawnMonster(typeName) then
					n += 1
				end
			end
		end
		print(`[Monsters] spawned {n} monsters`)
	end)

	local animAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		animAcc += dt
		if animAcc < 0.1 then
			return
		end
		animAcc = 0
		for _, info in monsters do
			if info.Alive and info.Awake then
				pcall(animTick, info)
			end
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		for _, info in monsters do
			info.Awake = info.Alive and (info.Busy or anyoneNear(info.Root.Position))
			if info.Awake then
				local ok, err = pcall(think, info)
				if not ok then
					warn(`[Monsters] {info.Type} brain error: {err}`)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			Abilities.BurnTick()
		end
	end)
end

return MonsterService
