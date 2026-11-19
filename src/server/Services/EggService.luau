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
local PetModels = require(script.Parent:WaitForChild("PetModels"))

local EggService = {}

local DataService, PetService, Remotes
local QA_USER_IDS = { [2459147914] = true } -- Cubickzz
local dropsFolder

local function qaAllowed(player: Player): boolean
	return QA_USER_IDS[player.UserId] == true and (RunService:IsStudio() or game.PrivateServerId ~= "")
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

local function nurseryOf(i: number?): Model?
	local exp = i and workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Expansion")
	return exp and exp:FindFirstChild("IncubatorHut" .. i) or nil
end

local function emit(parent: Instance, color: Color3, count: number, speed: number, size: number, texture: string?)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Texture = texture or e.Texture
	e.LightEmission = 1
	e.Size = NumberSequence.new(size, 0)
	e.Lifetime = NumberRange.new(0.6, 1.4)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = parent
	e:Emit(count)
	Debris:AddItem(e, 3)
end

------------------------------------------------------------------------
-- 1) boss egg drops
------------------------------------------------------------------------
function EggService.BossDefeated(info, pos: Vector3)
	local eggKey = info.Def.Arena or info.Def.Habitat
	if not PetDefs.Eggs[eggKey] then
		return
	end
	local total = 0
	for _, d in info.Damage do
		total += d
	end
	local eligible = {}
	for p, d in info.Damage do
		if p.Parent and (p == info.LastHitBy or (total > 0 and d / total >= 0.05)) then
			eligible[p] = true
		end
	end
	local egg = PetModels.Egg(eggKey, 1.3)
	egg:PivotTo(CFrame.new(pos + Vector3.new(0, 1, 0)))
	egg.Parent = dropsFolder
	local root = egg.PrimaryPart
	-- glow, sparkle and a beam of light so it is easy to find
	local light = Instance.new("PointLight")
	light.Color = PetDefs.Eggs[eggKey].Color2
	light.Range = 30
	light.Brightness = 3
	light.Parent = root
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170))
	sp.Rate = 15
	sp.Size = NumberSequence.new(0.6, 0)
	sp.Lifetime = NumberRange.new(1, 1.6)
	sp.Speed = NumberRange.new(1, 3)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.LightEmission = 1
	sp.Parent = root
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take Egg"
	prompt.ObjectText = PetDefs.Eggs[eggKey].Name
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	local taken = {}
	prompt.Triggered:Connect(function(player)
		if not eligible[player] then
			hint(player, "Only players who fought this boss can take its egg.", 3)
			return
		end
		if taken[player] then
			return
		end
		local d = data(player)
		if not d then
			return
		end
		taken[player] = true
		table.insert(d.Eggs, eggKey)
		emit(root, PetDefs.Eggs[eggKey].Color2, 40, 14, 0.8)
		hint(player, `You got a {PetDefs.Eggs[eggKey].Name}! Bring it to the Egg Nursery at your base.`, 5)
	end)
	-- gentle bob + spin until it expires
	local t0 = os.clock()
	local base = egg:GetPivot()
	task.spawn(function()
		while egg.Parent and os.clock() - t0 < 120 do
			local t = os.clock() - t0
			egg:PivotTo(base * CFrame.new(0, math.sin(t * 2) * 0.6 + 0.6, 0) * CFrame.Angles(0, t * 0.8, 0))
			task.wait(0.05)
		end
		egg:Destroy()
	end)
	for p in eligible do
		hint(p, `The {info.Def.Title} dropped a {PetDefs.Eggs[eggKey].Name}!`, 4)
	end
end

------------------------------------------------------------------------
-- 2) incubator
------------------------------------------------------------------------
local shownEgg = {} -- [IncubatorHut] = egg Model

local function remaining(d): number?
	local inc = d and d.Incubator
	if not inc then
		return nil
	end
	return math.max(0, inc.ReadyAt - os.time())
end

local function refreshNursery(player: Player)
	local hut = nurseryOf(baseIndex(player))
	if not hut then
		return
	end
	local d = data(player)
	local inc = d and d.Incubator
	local spot = hut:FindFirstChild("EggSpot")
	local current = shownEgg[hut]
	if inc and spot then
		if not current or current:GetAttribute("Egg") ~= inc.Egg then
			if current then
				current:Destroy()
			end
			local egg = PetModels.Egg(inc.Egg, 0.8)
			egg:PivotTo(spot.CFrame)
			egg.Parent = hut
			shownEgg[hut] = egg
		end
	elseif current then
		current:Destroy()
		shownEgg[hut] = nil
	end
end

local function updateBoards()
	for _, player in Players:GetPlayers() do
		local hut = nurseryOf(baseIndex(player))
		local d = data(player)
		if hut and d then
			local board = hut:FindFirstChild("TimerBoard")
			local label = board and board:FindFirstChild("Timer") and board.Timer:FindFirstChild("Text")
			local prompt = hut:FindFirstChild("IncubatorPrompt") and hut.IncubatorPrompt:FindFirstChild("IncubatorPrompt")
			local left = remaining(d)
			local text, action
			if left == nil then
				text = #d.Eggs > 0 and `{#d.Eggs} egg(s) waiting` or "Empty"
				action = "Incubate"
			elseif left > 0 then
				text = string.format("%d:%02d", math.floor(left / 60), left % 60)
				action = "Check"
			else
				text = "READY!"
				action = "Hatch!"
			end
			if label then
				label.Text = text
				label.TextColor3 = left == 0 and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 240, 200)
			end
			if prompt then
				prompt.ActionText = action
			end
		end
	end
end

local hatching = {}

local RARITY_INDEX = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }

-- 3) the hatch reveal at the nursery
local function hatch(player: Player)
	local d = data(player)
	local inc = d and d.Incubator
	if not inc or hatching[player] then
		return
	end
	hatching[player] = true
	local eggKey = inc.Egg
	local petId = PetDefs.Roll(eggKey)
	local def = PetDefs.Types[petId]
	d.Incubator = nil -- consume first (no double hatch)
	local hut = nurseryOf(baseIndex(player))
	local spot = hut and hut:FindFirstChild("EggSpot")
	local egg = hut and shownEgg[hut]
	if egg then
		shownEgg[hut] = nil
	end
	local rar = RARITY_INDEX[def.Rarity] or 1
	local rcolor = PetDefs.RARITY[def.Rarity].Color
	task.spawn(function()
		if egg and spot then
			local base = egg:GetPivot()
			local light = Instance.new("PointLight")
			light.Color = rcolor
			light.Range = 12
			light.Brightness = 0
			light.Parent = egg.PrimaryPart
			-- escalating charge: one wobble+pulse per rarity step
			for step = 1, 1 + rar do
				local grow = 0.8 + step * 0.08
				egg:ScaleTo(grow)
				for k = 1, 8 do
					egg:PivotTo(base * CFrame.Angles(0, 0, math.sin(k * 1.6) * 0.18 * (step / 2)))
					task.wait(0.04)
				end
				light.Brightness = step * 1.2
				light.Range = 10 + step * 6
				emit(egg.PrimaryPart, step >= 3 and rcolor or Color3.fromRGB(255, 255, 255), 8 + step * 10, 6 + step * 3, 0.4 + step * 0.1, "rbxasset://textures/particles/sparkles_main.dds")
				task.wait(0.35)
			end
			-- burst: shell layers fly apart
			local pos = egg:GetPivot().Position
			for _, w in egg:GetDescendants() do
				if w:IsA("WeldConstraint") then
					w:Destroy()
				end
			end
			for _, p in egg:GetDescendants() do
				if p:IsA("BasePart") and p.Name ~= "Root" then
					p.Anchored = true
					local out = (p.Position - pos)
					out = out.Magnitude > 0.1 and out.Unit or Vector3.yAxis
					TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						CFrame = p.CFrame + out * 6 + Vector3.new(0, 2, 0), Transparency = 1,
					}):Play()
				end
			end
			emit(egg.PrimaryPart, rcolor, 30 + rar * 25, 18 + rar * 4, 1)
			Debris:AddItem(egg, 1)
			-- the pet pops out, spins and lands
			local pet = PetModels.Build(petId)
			pet:PivotTo(spot.CFrame + Vector3.new(0, 1, 0))
			pet:ScaleTo(0.3)
			pet.Parent = hut
			for k = 1, 12 do
				pet:ScaleTo(0.3 + 0.7 * (k / 12))
				pet:PivotTo(spot.CFrame * CFrame.new(0, 1 + math.sin(k / 12 * math.pi) * 3, 0) * CFrame.Angles(0, k / 12 * math.pi * 4, 0))
				task.wait(0.04)
			end
			task.wait(1.6)
			pet:Destroy()
		end
		PetService.Grant(player, petId)
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

local function onNurseryPrompt(player: Player, hut: Model)
	local i = hut:GetAttribute("BaseIndex")
	if baseIndex(player) ~= i then
		hint(player, "This is someone else's nursery.", 3)
		return
	end
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
local function qaTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "QA Instant Hatch (test only)"
	tool.ToolTip = "Test tool: incubate + hatch an egg instantly"
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.2, 1.6, 1.2)
	handle.Color = Color3.fromRGB(255, 220, 90)
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
		hatch(player)
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
				if DataService.Get(player) and baseIndex(player) then
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
		hatching[p] = nil
		local hut = nurseryOf(baseIndex(p))
		if hut and shownEgg[hut] then
			shownEgg[hut]:Destroy()
			shownEgg[hut] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			updateBoards()
		end
	end)
end

return EggService
