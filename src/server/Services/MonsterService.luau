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
local HazardService = require(script.Parent:WaitForChild("HazardService"))

local MonsterService = {}

local MapService, DataService, Remotes
local root: Folder
local monsters = {} -- [Model] = info

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
	gui.StudsOffset = Vector3.new(0, 7 * def.Scale + (def.Hover or 0), 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.5, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Text = info.Type .. "  -  " .. def.Title
	name.Parent = gui
	local back = Instance.new("Frame")
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
	end))
end

------------------------------------------------------------------------
-- spawning
------------------------------------------------------------------------
local spawnMonster -- forward

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
	Abilities.Burst(info.Root.Position, Color3.fromRGB(255, 255, 255), 25)

	-- XP: killer 100 %, helpers with >= 10 % of the damage get AssistShare
	local total = 0
	for _, d in info.Damage do
		total += d
	end
	for p, d in info.Damage do
		if p.Parent then
			local share = (p == info.LastHitBy) and 1 or ((total > 0 and d / total >= 0.1) and Defs.AssistShare or 0)
			local xp = math.floor(info.Def.XP * share)
			if xp > 0 then
				local levelUp = DataService.AddXP(p, xp)
				Remotes.Hint:FireClient(p, `+{xp} XP!`, 3)
				if levelUp then
					Remotes.Hint:FireClient(p, `Level {levelUp}!`, 4)
				end
			end
		end
	end

	local model = info.Model
	task.delay(1.4, function()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				TweenService:Create(d, TweenInfo.new(1), { Transparency = 1 }):Play()
			end
		end
		task.wait(1.1)
		monsters[model] = nil
		model:Destroy()
	end)
	if not info.Def.Summon then
		task.delay(info.Def.Respawn, function()
			spawnMonster(info.Type)
		end)
	end
end

spawnMonster = function(typeName: string, at: Vector3?, life: number?, target: Player?)
	local def = Defs.Types[typeName]
	local pos = at or pickSpawn(def.Habitat)
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
	play(info, "Idle")
	healthBar(info)
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
	if not info.Busy and os.clock() - info.LastHit > 0.5 then
		info.LastHit = os.clock()
		play(info, "Hit")
	end
	Abilities.Burst(info.Root.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 240, 200), 6)
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
	local wanted = p:GetAttribute("Carrying") ~= nil or (info.Aggro[p] or 0) > now()
	return wanted and (r.Position - info.Root.Position).Magnitude <= info.Def.Aggro * 1.5
end

local function findTarget(info): Player?
	local best, bestD = nil, info.Def.Aggro
	for _, p in Players:GetPlayers() do
		local r = playerRoot(p)
		if r then
			local d = (r.Position - info.Root.Position).Magnitude
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
		task.wait(0.3)
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

	-- animation: walk while moving
	local moving = info.Hum.MoveDirection.Magnitude > 0.1
	local walk, idle = info.Tracks.Walk, info.Tracks.Idle
	if walk and moving and not walk.IsPlaying then
		walk:Play(0.2)
	elseif walk and not moving and walk.IsPlaying then
		walk:Stop(0.2)
	end
	if idle and not idle.IsPlaying then
		idle:Play(0.3)
	end

	-- tether: never leave the habitat / stray too far from home
	local here = info.Root.Position
	local strayed = (here - info.Home).Magnitude > Defs.Tether
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
			info.Cooldowns[i] = os.clock() + a.Cooldown
			runAction(info, Abilities.F[a.Id], makeCtx(info, target, tRoot), a)
			return
		end
	end
	if dist <= def.Melee.Range and os.clock() >= info.MeleeReady then
		info.MeleeReady = os.clock() + def.Melee.Cooldown
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

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		for _, info in monsters do
			if info.Alive and (info.Busy or anyoneNear(info.Root.Position)) then
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
