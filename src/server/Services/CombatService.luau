-- PLAYER DAMAGE: every way a player can hurt monsters (and knock the Studio
-- test dummy). Server-validated: cooldowns, range and line checks here.
--
--   Gust Punch  R (ground)       12 dmg, 8-stud cone in front, 0.6 s cooldown
--   Air Slam    R (in the air)   18 dmg in 10 studs where you land, 3 s cooldown
--   Puff Shot   T (aim)          8 dmg cloud ball, 90 studs/s, 70 range, 1.2 s
--   Laser Gun   item             25 dmg (InventoryService raycast)
--   Quake       perk ability     40 dmg in Config.QuakeRadius
--   Flare       item             20 dmg in 16 studs around you
--   Hazards     lure monsters into lava / electric water (MonsterService)
-- Remote: Attack(kind: "Punch" | "Slam" | "Puff", aim: Vector3?)

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CombatService = {}

local MonsterService, DummyService
local ATTACKS = {
	Punch = { Damage = 12, Range = 8, Cone = 70, Cooldown = 0.6 },
	Slam = { Damage = 18, Radius = 10, Cooldown = 3 },
	Puff = { Damage = 8, Speed = 90, Range = 70, Cooldown = 1.2 },
}
CombatService.Attacks = ATTACKS
local DAMAGE = { Laser = 25, Quake = 40, Flare = 20 }

local ready = {} -- [Player] = { [kind] = os.clock() }

-- everything a player can hit: monsters + the Studio dummy
local function targets(): { Model }
	local list = {}
	for _, m in CollectionService:GetTagged("Monster") do
		table.insert(list, m)
	end
	for _, m in CollectionService:GetTagged("TestDummy") do
		table.insert(list, m)
	end
	return list
end

local function centre(m: Model): Vector3?
	local r = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
	return r and (r :: BasePart).Position or nil
end

-- one hit on a model (monster takes damage, dummy gets knocked)
local function hit(player: Player?, model: Model, amount: number, dir: Vector3?, kind: string)
	if CollectionService:HasTag(model, "TestDummy") then
		DummyService.HandleHit(model, dir)
	elseif MonsterService then
		MonsterService.Damage(model, amount, player, kind)
	end
end
CombatService.Hit = hit

local function puffFx(pos: Vector3)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * 3
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(245, 248, 255)
	p.Transparency = 0.15
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	return p
end

local function attack(player: Player, kind: unknown, aim: unknown)
	local spec = type(kind) == "string" and ATTACKS[kind]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not spec or not root or not hum or hum.Health <= 0 then
		return
	end
	ready[player] = ready[player] or {}
	if os.clock() < (ready[player][kind] or 0) then
		return
	end
	ready[player][kind] = os.clock() + spec.Cooldown

	if kind == "Punch" then
		local look = root.CFrame.LookVector
		for _, m in targets() do
			local c = centre(m)
			if c then
				local rel = c - root.Position
				local flat = Vector3.new(rel.X, 0, rel.Z)
				local size = m:GetExtentsSize()
				local reach = spec.Range + math.max(size.X, size.Z) / 2
				if flat.Magnitude <= reach and math.abs(rel.Y) < size.Y + 4 then
					local ang = flat.Magnitude > 0.1 and math.deg(math.acos(math.clamp(flat.Unit:Dot(look), -1, 1))) or 0
					if ang <= spec.Cone then
						hit(player, m, spec.Damage, flat.Magnitude > 0.1 and flat.Unit or look, "Punch")
					end
				end
			end
		end
	elseif kind == "Slam" then
		-- resolve when the player lands (max 1.5 s)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 1.5 and hum.FloorMaterial == Enum.Material.Air do
				task.wait()
			end
			local pos = root.Position
			local ring = puffFx(pos - Vector3.new(0, 2.5, 0))
			ring.Size = Vector3.new(spec.Radius * 2, 1, spec.Radius * 2)
			Debris:AddItem(ring, 0.3)
			for _, m in targets() do
				local c = centre(m)
				if c and (c - pos).Magnitude <= spec.Radius + 3 then
					hit(player, m, spec.Damage, (c - pos).Unit, "Slam")
				end
			end
		end)
	elseif kind == "Puff" then
		if typeof(aim) ~= "Vector3" then
			return
		end
		local from = root.Position + Vector3.new(0, 1.5, 0)
		local dir = ((aim :: Vector3) - from)
		if dir.Magnitude < 1 then
			return
		end
		dir = dir.Unit
		local ball = puffFx(from)
		Debris:AddItem(ball, spec.Range / spec.Speed + 0.3)
		local travelled = 0
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if not ball.Parent then
				conn:Disconnect()
				return
			end
			local step = spec.Speed * dt
			travelled += step
			ball.CFrame += dir * step
			for _, m in targets() do
				local c = centre(m)
				if c then
					local size = m:GetExtentsSize()
					if (c - ball.Position).Magnitude <= math.max(size.X, size.Y, size.Z) / 2 + 1.5 then
						hit(player, m, spec.Damage, dir, "Puff")
						conn:Disconnect()
						ball:Destroy()
						return
					end
				end
			end
			if travelled >= spec.Range then
				conn:Disconnect()
				ball:Destroy()
			end
		end)
	end
end

function CombatService.Start(remotes, inventoryService, monsterService, dummyService)
	MonsterService, DummyService = monsterService, dummyService
	remotes.Attack.OnServerEvent:Connect(attack)
	Players.PlayerRemoving:Connect(function(p)
		ready[p] = nil
	end)
	Players.PlayerAdded:Connect(function(p)
		task.delay(12, function()
			if p.Parent then
				remotes.Hint:FireClient(p, "Monsters chase cloud carriers! R = punch, T = shoot", 6)
			end
		end)
	end)
	-- Laser Gun / Quake hit a non-player model
	inventoryService.Hooks.ModelHit = function(player: Player, model: Model, dir: Vector3?, kind: string?)
		local m = model
		while m and m.Parent ~= workspace and not CollectionService:HasTag(m, "Monster") and not CollectionService:HasTag(m, "TestDummy") do
			m = m.Parent :: Model
		end
		if m and (CollectionService:HasTag(m, "Monster") or CollectionService:HasTag(m, "TestDummy")) then
			hit(player, m, DAMAGE[kind or "Laser"] or 25, dir, kind or "Laser")
		end
	end
	-- Flare / area items
	inventoryService.Hooks.AreaHit = function(player: Player, pos: Vector3, radius: number, kind: string)
		for _, m in targets() do
			local c = centre(m)
			if c and (c - pos).Magnitude <= radius then
				hit(player, m, DAMAGE[kind] or 20, (c - pos).Unit, kind)
			end
		end
	end
end

return CombatService
