-- v2.12 BOSS EGGS -> INCUBATOR -> HATCH (director request)
--
-- 1. A boss dies -> a big blocky studded egg (its biome theme) drops at the
--    arena: workspace.EggDrops.<Biome>Egg, prompt "Take Egg". Every player
--    who helped (>= 5 % of the damage, or the final hit) can take one.
-- 2. Eggs go to Data.Eggs. At your base's Egg Nursery
--    (Map/Expansion/IncubatorHut<i>) press "Incubate": the egg sits in the
--    glass dome, the sign counts down 100 minutes (PetDefs.HatchMinutes,
--    shortened by the pets' Hatch buff). Saved as an absolute time
--    (Data.Incubator = { Egg, ReadyAt = os.time() }) so leaving / rejoining
--    never resets it.
-- 3. "Hatch!" -> the pet is rolled; the egg wobbles, glows and grows more for
--    rarer pets, bursts, and the pet pops out. Legendary hatches are
--    announced to the whole server.
-- QA: "QA Instant Hatch (test only)" tool for the director's account only
--     (Studio / private servers): incubates an egg (granting one if needed)
--     and hatches it at once.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetDefs = require(ReplicatedStorage.Shared.PetDefs)
local PetModels = require(game:GetService("ReplicatedStorage").Shared.PetModels) -- v2.35 shared (client nursery)
local Sfx = require(game:GetService("ReplicatedStorage").Shared.Sfx)

local EggService = {}

local DataService, PetService, Remotes
local QA_USER_IDS = { [2459147914] = true } -- Cubickzz
local dropsFolder

local function qaAllowed(player: Player): boolean
	return QA_USER_IDS[player.UserId] == true and (require(game:GetService("ReplicatedStorage").Shared.Config).QaEverywhere or RunService:IsStudio() or game.PrivateServerId ~= "")
end

local function data(player: Player)
	local d = DataService.Get(player)
	if d then
		d.Eggs = d.Eggs or {}
	end
	return d
end

local function hint(player: Player, text: string, t: number?)
	if Remotes and Remotes.Hint then
		Remotes.Hint:FireClient(player, text, t or 4)
	end
end

local function baseIndex(player: Player): number?
	local roofs = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Rooftops")
	for _, roof in roofs and roofs:GetChildren() or {} do
		if roof:GetAttribute("OwnerUserId") == player.UserId then
			return tonumber(string.match(roof.Name, "%d+"))
		end
	end
	return nil
end

-- v2.35: ONE shared nursery for the whole server (Map/Expansion/SharedNursery)
local function nurseryOf(_i: number?): Model?
	local exp = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Expansion")
	return exp and exp:FindFirstChild("SharedNursery") or nil
end

local function fx(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	game:GetService("Debris"):AddItem(p, 15)
	return p
end

local FxKit = require(game:GetService("ReplicatedStorage").Shared.FxKit)

local function emit(parent: Instance, color: Color3, count: number, speed: number, size: number, texture: string?)
	local e = Instance.new("ParticleEmitter")
	e.Color = FxKit.Hot(color)
	e.Texture = texture or FxKit.Texture("Glow")
	e.LightEmission = 1
	e.LightInfluence = 0
	pcall(function()
		(e :: any).Brightness = 2.5
	end)
	e.Size = FxKit.NS({ { 0, size * 0.5 }, { 0.15, size }, { 1, 0 } })
	e.Lifetime = NumberRange.new(0.6, 1.4)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = parent
	e:Emit(count)
	Debris:AddItem(e, 3)
end

------------------------------------------------------------------------
-- 1) boss egg drops (v2.13): the egg goes to the player who dealt the MOST
--    damage. Taking it puts it on your back ("CarryingEgg"); bring it to
--    your Egg Nursery. If you die (or leave) on the way it drops as a free
--    world pickup that ANY player can claim.
------------------------------------------------------------------------
local carried = {} -- [Player] = { Key, Model, Conns }
local spawnPickup -- forward

-- v2.22: a dropped egg always lands ON solid ground: straight below if
-- there is land, otherwise on the nearest land (it never hangs in the air
-- or falls into the void when its carrier dies / is flung off the edge)
local function groundSpot(at: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { dropsFolder }
	for _, n in { "Monsters", "Weather", "FxKit", "Pets", "SfxEmitters" } do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(ignore, f)
		end
	end
	local map = workspace:FindFirstChild("Map")
	local abyss = map and map:FindFirstChild("Abyss")
	if abyss then
		table.insert(ignore, abyss)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local function down(x: number, z: number, top: number): Vector3?
		local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -top + 12, 0), params)
		if hit and hit.Position.Y > 14 and hit.Normal.Y > 0.5 then
			return hit.Position
		end
		return nil
	end
	local top = math.max(at.Y + 4, 120) + 200
	local here = down(at.X, at.Z, at.Y + 4) or down(at.X, at.Z, top)
	if here then
		return here
	end
	for r = 10, 600, 10 do
		local n = math.clamp(math.floor(r / 4), 8, 48)
		local best, bestD
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2
			local p = down(at.X + math.cos(a) * r, at.Z + math.sin(a) * r, top)
			if p then
				local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(at.X, 0, at.Z)).Magnitude
				if not bestD or d < bestD then
					best, bestD = p, d
				end
			end
		end
		if best then
			-- step a little further onto the land so it isn't on the very edge
			local inward = (Vector3.new(best.X, 0, best.Z) - Vector3.new(at.X, 0, at.Z))
			return down(best.X + inward.Unit.X * 6, best.Z + inward.Unit.Z * 6, top) or best
		end
	end
	return nil
end

local function dropCarried(player: Player, at: Vector3?)
	local c = carried[player]
	if not c then
		return
	end
	carried[player] = nil
	for _, conn in c.Conns do
		conn:Disconnect()
	end
	if c.Model then
		c.Model:Destroy()
	end
	player:SetAttribute("CarryingEgg", nil)
	if at then
		at = groundSpot(at) or at
		spawnPickup(c.Key, at, nil, 120)
		hint(player, "You dropped the egg! Anyone can grab it now.", 4)
	end
end

local function carryEgg(player: Player, eggKey: string)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return false
	end
	dropCarried(player, nil)
	local egg = PetModels.Egg(eggKey, 0.5)
	local eroot = egg.PrimaryPart
	egg:PivotTo(root.CFrame * CFrame.new(0, -1.2, 1.6))
	eroot.Anchored = false
	eroot.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = eroot
	w.Parent = eroot
	egg.Parent = char
	player:SetAttribute("CarryingEgg", eggKey)
	local conns = {}
	table.insert(conns, hum.Died:Connect(function()
		dropCarried(player, root.Position)
	end))
	carried[player] = { Key = eggKey, Model = egg, Conns = conns }
	hint(player, `Carry the {PetDefs.Eggs[eggKey].Name} to the Egg Nursery on the hub!`, 5)
	return true
end

-- a world egg pickup; owner = only that player may take it (nil = anyone)
spawnPickup = function(eggKey: string, pos: Vector3, owner: Player?, life: number)
	local egg = PetModels.Egg(eggKey, 1.6, true)
	egg:PivotTo(CFrame.new(pos + Vector3.new(0, 0.5, 0)))
	egg.Parent = dropsFolder
	local root = egg.PrimaryPart
	local e = PetDefs.Eggs[eggKey]
	local light = Instance.new("PointLight")
	light.Color = e.Color2
	light.Range = 34
	light.Brightness = 3
	light.Parent = root
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170))
	sp.Rate = 18
	sp.Size = NumberSequence.new(0.7, 0)
	sp.Lifetime = NumberRange.new(1, 1.8)
	sp.Speed = NumberRange.new(1, 3)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.LightEmission = 1
	sp.Parent = root
	-- name tag so players see whose egg it is
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 46)
	gui.StudsOffset = Vector3.new(0, 11, 0)
	gui.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 140)
	label.TextStrokeTransparency = 0.3
	label.Text = owner and `{e.Name} · {owner.DisplayName}` or e.Name
	label.Parent = gui
	gui.Parent = root
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EggPickup"
	prompt.ActionText = "Take Egg"
	prompt.ObjectText = e.Name
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	local done = false
	prompt.Triggered:Connect(function(player)
		if done then
			return
		end
		if owner and owner.Parent and player ~= owner then
			hint(player, `This egg belongs to {owner.DisplayName} (most damage).`, 3)
			return
		end
		if player:GetAttribute("CarryingEgg") then
			hint(player, "You are already carrying an egg.", 3)
			return
		end
		if carryEgg(player, eggKey) then
			Sfx.At("EggTake", root.Position)
			done = true
			egg:Destroy()
		end
	end)
	local t0 = os.clock()
	local base = egg:GetPivot()
	task.spawn(function()
		while egg.Parent and os.clock() - t0 < life do
			local t = os.clock() - t0
			egg:PivotTo(base * CFrame.new(0, math.sin(t * 2) * 0.5 + 0.5, 0) * CFrame.Angles(0, t * 0.7, 0))
			task.wait(0.05)
		end
		if egg.Parent then
			egg:Destroy()
		end
	end)
	return egg
end

function EggService.BossDefeated(info, pos: Vector3)
	local eggKey = info.Def.Arena or info.Def.Habitat
	if not PetDefs.Eggs[eggKey] then
		warn("[Eggs] no egg for " .. tostring(info.Type))
		return
	end
	-- winner = most total damage (ties: the final hit)
	local winner, best = nil, -1
	for p, d in info.Damage do
		if p.Parent and (d > best or (d == best and p == info.LastHitBy)) then
			winner, best = p, d
		end
	end
	spawnPickup(eggKey, pos, winner, 180)
	print(`[Eggs] {info.Type} dropped a {eggKey} egg for {winner and winner.Name or "anyone"} ({math.floor(best)} dmg)`)
	if winner then
		hint(winner, `You dealt the most damage! The {PetDefs.Eggs[eggKey].Name} is yours. Take it!`, 5)
	end
	for p in info.Damage do
		if p ~= winner and p.Parent then
			hint(p, `{winner and winner.DisplayName or "Someone"} dealt the most damage and wins the egg.`, 4)
		end
	end
end

------------------------------------------------------------------------
-- 2) incubator
------------------------------------------------------------------------
local hatchRemote: RemoteEvent? = nil -- v2.35 "play your hatch show" (client)

local function remaining(d): number?
	local inc = d and d.Incubator
	if not inc then
		return nil
	end
	return math.max(0, inc.ReadyAt - os.time())
end

-- v2.35 shared nursery: the egg, the timer board and the prompt text are
-- drawn per player by the CLIENT (Client/NurseryClient) from attributes, so
-- everyone in the one nursery sees only their own egg.
--   IncubEgg = egg key | nil   IncubReadyAt = server time it is ready
--   EggsWaiting = eggs in storage
local function refreshNursery(player: Player)
	local d = data(player)
	if not d then
		return
	end
	local inc = d.Incubator
	local left = remaining(d)
	player:SetAttribute("IncubEgg", inc and inc.Egg or nil)
	player:SetAttribute("IncubReadyAt", left and (workspace:GetServerTimeNow() + left) or nil)
	player:SetAttribute("EggsWaiting", #d.Eggs)
end

local hatching = {}

local RARITY_INDEX = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }

-- 3) the hatch reveal at the nursery
local function hatch(player: Player, forceTop: boolean?)
	local d = data(player)
	local inc = d and d.Incubator
	if not inc or hatching[player] then
		return
	end
	if #(d.Pets or {}) >= PetDefs.StorageLimit then
		-- v2.21: storage full - the egg waits until a pet is sold
		hint(player, `Pet storage full ({PetDefs.StorageLimit})! Sell a pet at Aurelius or Zeus to hatch this egg.`, 6)
		return
	end
	hatching[player] = true
	local eggKey = inc.Egg
	local petId = PetDefs.Roll(eggKey)
	if not forceTop and qaAllowed(player) and player:GetAttribute("QaMaxLuck") then
		forceTop = true -- QA Max Luck: every hatch gives the rarest pet
	end
	if forceTop then
		-- QA: the rarest pet of this egg
		for _, id in PetDefs.ByEgg[eggKey] do
			if PetDefs.Types[id].Rarity == "Legendary" then
				petId = id
			end
		end
	end
	local def = PetDefs.Types[petId]
	d.Incubator = nil -- consume first (no double hatch)
	local rar = RARITY_INDEX[def.Rarity] or 1
	refreshNursery(player)
	-- v2.35: the hatch show plays on THIS player's screen only (shared nursery)
	if hatchRemote then
		hatchRemote:FireClient(player, eggKey, petId)
	end
	task.spawn(function()
		task.wait(2.2 + (1 + rar) * 0.7 + (rar >= 4 and 2.4 or 1.2))
		PetService.Grant(player, petId)
		DataService.SaveSoon(player)
		local msg = `You hatched a {def.Rarity} {def.Name}! {PetDefs.BuffText(def)}`
		hint(player, msg, 6)
		if def.Rarity == PetDefs.AnnounceRarity then
			for _, p in Players:GetPlayers() do
				if p ~= player then
					hint(p, `★ {player.DisplayName} hatched a LEGENDARY {def.Name}! ★`, 6)
				end
			end
		end
		print(`[Eggs] {player.Name} hatched {petId} ({def.Rarity}) from {eggKey}`)
		hatching[player] = nil
		refreshNursery(player)
	end)
end

local function startIncubating(player: Player): boolean
	local d = data(player)
	if not d or d.Incubator or #d.Eggs == 0 then
		return false
	end
	local eggKey = table.remove(d.Eggs, 1)
	local minutes = PetDefs.HatchMinutes * (1 - (player:GetAttribute("PetHatch") or 0))
	d.Incubator = { Egg = eggKey, ReadyAt = os.time() + math.floor(minutes * 60) }
	refreshNursery(player)
	hint(player, `{PetDefs.Eggs[eggKey].Name} is incubating: {math.floor(minutes)} minutes.`, 4)
	return true
end

local function onNurseryPrompt(player: Player, _hut: Model)
	local d = data(player)
	local left = remaining(d)
	if left == nil then
		if not startIncubating(player) then
			hint(player, "No eggs yet. Defeat a temple boss to get one!", 4)
		end
	elseif left > 0 then
		hint(player, string.format("Hatching in %d:%02d", math.floor(left / 60), left % 60), 3)
	else
		hatch(player)
	end
end

------------------------------------------------------------------------
-- QA instant hatch tool
------------------------------------------------------------------------
local function qaTool(top: boolean?): Tool
	local tool = Instance.new("Tool")
	tool.Name = top and "QA Legendary Hatch (test only)" or "QA Instant Hatch (test only)"
	tool.ToolTip = top and "Test tool: hatch an egg now and get its rarest (Legendary) pet" or "Test tool: incubate + hatch an egg instantly"
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.2, 1.6, 1.2)
	handle.Color = top and Color3.fromRGB(255, 120, 230) or Color3.fromRGB(255, 220, 90)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Parent = tool
	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player or not qaAllowed(player) then
			return
		end
		local d = data(player)
		if not d then
			return
		end
		if not d.Incubator then
			if #d.Eggs == 0 then
				local keys = {}
				for k in PetDefs.Eggs do
					table.insert(keys, k)
				end
				table.insert(d.Eggs, keys[math.random(1, #keys)])
			end
			startIncubating(player)
		end
		d.Incubator.ReadyAt = os.time()
		hatch(player, top)
	end)
	return tool
end

------------------------------------------------------------------------
function EggService.Start(dataService, petService, remotes, monsterDeaths)
	DataService, PetService, Remotes = dataService, petService, remotes
	dropsFolder = Instance.new("Folder")
	dropsFolder.Name = "EggDrops"
	dropsFolder.Parent = workspace
	monsterDeaths.OnBossDefeated = EggService.BossDefeated
	do -- v2.35: per-player hatch show (shared nursery)
		local folder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
		local r = Instance.new("RemoteEvent")
		r.Name = "NurseryHatch"
		r.Parent = folder
		hatchRemote = r
	end

	-- hook prompts once the map exists
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 60)
		local exp = map and map:WaitForChild("Expansion", 60)
		if not exp then
			warn("[Eggs] no Map/Expansion: huts missing")
			return
		end
		task.wait(1)
		local function hook(inst: Instance)
			if inst:IsA("ProximityPrompt") and inst.Name == "IncubatorPrompt" then
				local hut = inst:FindFirstAncestorWhichIsA("Model")
				inst.Triggered:Connect(function(player)
					onNurseryPrompt(player, hut)
				end)
			elseif inst:IsA("ProximityPrompt") and inst.Name == "PetsPrompt" then
				inst.Triggered:Connect(function(player)
					PetService.Open(player)
				end)
			end
		end
		for _, d in exp:GetDescendants() do
			hook(d)
		end
		exp.DescendantAdded:Connect(hook)
	end)

	local function setup(player: Player)
		task.spawn(function()
			for _ = 1, 40 do
				if DataService.Get(player) then
					break
				end
				task.wait(0.5)
			end
			refreshNursery(player)
		end)
		if qaAllowed(player) then
			local function give()
				local bp = player:WaitForChild("Backpack", 10)
				if bp and not bp:FindFirstChild("QA Instant Hatch (test only)") then
					qaTool().Parent = bp
				end
				if bp and not bp:FindFirstChild("QA Max Luck (test only)") then
					local t = Instance.new("Tool")
					t.Name = "QA Max Luck (test only)"
					t.ToolTip = "Test tool: toggle max hatch luck (every hatch = rarest pet)"
					t.CanBeDropped = false
					local h = Instance.new("Part")
					h.Name = "Handle"
					h.Size = Vector3.new(1, 1, 1)
					h.Shape = Enum.PartType.Ball
					h.Color = Color3.fromRGB(120, 255, 160)
					h.Material = Enum.Material.Neon
					h.CanCollide = false
					h.Parent = t
					t.Activated:Connect(function()
						if qaAllowed(player) then
							local on = not player:GetAttribute("QaMaxLuck")
							player:SetAttribute("QaMaxLuck", on)
							hint(player, on and "Max hatch luck ON: every hatch gives the rarest pet." or "Max hatch luck OFF.", 3)
						end
					end)
					t.Parent = bp
				end
			end
			player.CharacterAdded:Connect(function()
				task.wait(1)
				give()
			end)
			if player.Character then
				give()
			end
		end
	end
	for _, p in Players:GetPlayers() do
		setup(p)
	end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(p)
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		dropCarried(p, r and r.Position or nil)
		hatching[p] = nil
	end)
	-- carried eggs are delivered when you reach your own nursery
	task.spawn(function()
		while true do
			task.wait(0.4)
			for player, c in carried do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hut = nurseryOf(baseIndex(player))
				local spot = hut and hut:FindFirstChild("EggSpot")
				if root and spot and (root.Position - spot.Position).Magnitude < 16 then
					local d = data(player)
					if d then
						local key = c.Key
						dropCarried(player, nil)
						table.insert(d.Eggs, key)
						Sfx.At("EggDeliver", root.Position)
						hint(player, `{PetDefs.Eggs[key].Name} delivered to your nursery!`, 4)
						if not d.Incubator then
							startIncubating(player)
						end
					end
				end
			end
		end
	end)
end

return EggService
