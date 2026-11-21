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
local Sfx = require(game:GetService("ReplicatedStorage").Shared.Sfx)

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
-- 1) boss egg drops (v2.13): the egg goes to the player who dealt the MOST
--    damage. Taking it puts it on your back ("CarryingEgg"); bring it to
--    your Egg Nursery. If you die (or leave) on the way it drops as a free
--    world pickup that ANY player can claim.
------------------------------------------------------------------------
local carried = {} -- [Player] = { Key, Model, Conns }
local spawnPickup -- forward

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
	hint(player, `Carry the {PetDefs.Eggs[eggKey].Name} to the Egg Nursery at your base!`, 5)
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
	label.Text = owner and `{e.Name} · {owner.DisplayName}` or `{e.Name} · free!`
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
local function hatch(player: Player, forceTop: boolean?)
	local d = data(player)
	local inc = d and d.Incubator
	if not inc or hatching[player] then
		return
	end
	if #(d.Pets or {}) >= PetDefs.StorageLimit then
		-- v2.21: storage full - the egg waits until a pet is sold
		hint(player, `Pet storage full ({PetDefs.StorageLimit})! Sell a pet at Aurelius or Tayron to hatch this egg.`, 6)
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
			-- v2.17 EPIC / LEGENDARY CINEMATIC: a light pillar from the sky, three
			-- orbiting rings of glowing motes, the egg levitates higher with every
			-- pulse, shockwaves; at the burst: spinning light rays, a giant flash,
			-- confetti, and the pet descends from above in a halo
			local show = rar >= 4
			local showParts = {}
			if show then
				local top = base.Position
				local pillar = fx(Vector3.new(220, 1, 1), CFrame.new(top + Vector3.new(0, 110, 0)) * CFrame.Angles(0, 0, math.pi / 2), rcolor, Enum.PartType.Cylinder)
				pillar.Transparency = 0.35
				TweenService:Create(pillar, TweenInfo.new(1.2), { Size = Vector3.new(220, 9, 9) }):Play()
				table.insert(showParts, pillar)
				for ringN = 1, 3 do
					for k = 1, 8 do
						local mote = fx(Vector3.one * 0.7, CFrame.new(top), ringN == 2 and Color3.fromRGB(255, 240, 180) or rcolor, Enum.PartType.Ball)
						table.insert(showParts, mote)
						task.spawn(function()
							local t0 = os.clock()
							while mote.Parent do
								local t = os.clock() - t0
								local a = k / 8 * math.pi * 2 + t * (1.5 + ringN * 0.8) * (ringN % 2 == 0 and -1 or 1)
								local es = math.max(1, egg:GetScale() / 0.8) -- rings widen as the egg grows
								local r = (4 + ringN * 1.6) * es
								mote.CFrame = CFrame.new(egg:GetPivot().Position + Vector3.new(math.cos(a) * r, (ringN * 1.5 + math.sin(t * 2 + k) * 0.4) * es, math.sin(a) * r))
								task.wait()
							end
						end)
					end
				end
				Sfx.Global("BossArrive")
			end
			-- v2.21 director: the rarer the pet, the BIGGER the egg grows before it
			-- cracks (Legendary ~20 studs = 3-4 players tall). Big eggs rise up
			-- out of the glass dome so they never clip the hut.
			local TARGET_H = { 5.5, 7.5, 10, 15, 21 } -- egg height (studs) per rarity
			local EGG_H = 5.6 -- egg model height at scale 1
			local startScale = egg:GetScale()
			local endScale = math.max(startScale, (TARGET_H[rar] or 6) / EGG_H)
			local lift = rar >= 3 and 11 or 0 -- clear the dome top
			local base0 = base
			local steps = 1 + rar
			for step = 1, steps do
				local f = step / steps
				local grow = startScale + (endScale - startScale) * f
				egg:ScaleTo(grow)
				base = base0 + Vector3.new(0, lift * math.min(1, f * 1.5), 0)
				if show then
					base += Vector3.new(0, 0.7 * step, 0) -- levitate
					local ring = fx(Vector3.new(0.3, 2, 2), CFrame.new(spot.Position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), rcolor, Enum.PartType.Cylinder)
					TweenService:Create(ring, TweenInfo.new(0.6), { Size = Vector3.new(0.2, 26 + step * 4, 26 + step * 4), Transparency = 1 }):Play()
					game:GetService("Debris"):AddItem(ring, 0.7)
				end
				local deep = 1 / math.sqrt(grow / startScale) -- bigger egg = deeper crack
				for k = 1, 8 do
					egg:PivotTo(base * CFrame.Angles(0, 0, math.sin(k * 1.6) * 0.18 * (step / 2)))
					if k == 3 or k == 6 then
						Sfx.At("HatchCrack", egg:GetPivot().Position, deep * (0.9 + math.random() * 0.25))
					end
					task.wait(0.04)
				end
				light.Brightness = step * 1.2
				Sfx.At("HatchPulse", egg:GetPivot().Position, deep * (0.9 + step * 0.05))
				light.Range = 10 + step * 6 + grow * 4
				emit(egg.PrimaryPart, step >= 3 and rcolor or Color3.fromRGB(255, 255, 255), 8 + step * 10, 6 + step * 3, 0.4 + step * 0.1, "rbxasset://textures/particles/sparkles_main.dds")
				task.wait(0.35)
			end
			-- burst: shell layers fly apart
			local eggScale = egg:GetScale()
			local pos = egg:GetPivot().Position + Vector3.new(0, 2.8 * eggScale, 0) -- egg centre
			for _, w in egg:GetDescendants() do
				if w:IsA("WeldConstraint") or w:IsA("Weld") then
					w:Destroy()
				end
			end
			for _, p in egg:GetDescendants() do
				if p:IsA("BasePart") and p.Name ~= "Root" then
					p.Anchored = true
					local out = (p.Position - pos)
					out = out.Magnitude > 0.1 and out.Unit or Vector3.yAxis
					TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						CFrame = p.CFrame + out * (4 + eggScale * 3) + Vector3.new(0, 2, 0), Transparency = 1,
					}):Play()
				end
			end
			emit(egg.PrimaryPart, rcolor, 30 + rar * 25, 18 + rar * 4, 1)
			Sfx.At("HatchBurst", pos, 1 / math.sqrt(eggScale / startScale))
			if show then
				-- spinning light rays + flash + confetti
				local flash = Instance.new("PointLight")
				flash.Color = rcolor
				flash.Range = 60
				flash.Brightness = 10
				flash.Parent = spot
				TweenService:Create(flash, TweenInfo.new(2), { Brightness = 0 }):Play()
				game:GetService("Debris"):AddItem(flash, 2.2)
				for k = 1, 12 do
					local a = k / 12 * math.pi * 2
					local ray = fx(Vector3.new(0.6, 0.6, 30), CFrame.new(pos) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -15), k % 2 == 0 and rcolor or Color3.fromRGB(255, 245, 200))
					ray.Transparency = 0.2
					TweenService:Create(ray, TweenInfo.new(1.6), { CFrame = CFrame.new(pos) * CFrame.Angles(0, a + 1.2, 0) * CFrame.new(0, 0, -15), Transparency = 1 }):Play()
					game:GetService("Debris"):AddItem(ray, 1.7)
				end
				emit(spot, Color3.fromRGB(255, 230, 120), 200, 35, 0.9)
				emit(spot, rcolor, 200, 30, 0.8)
				for _, part in showParts do
					TweenService:Create(part, TweenInfo.new(1), { Transparency = 1 }):Play()
					game:GetService("Debris"):AddItem(part, 1.1)
				end
			end
			if rar >= 5 then
				Sfx.Global("HatchLegendary")
			end
			Debris:AddItem(egg, 1)
			-- the pet pops out, spins and lands
			local pet = PetModels.Build(petId)
			pet:SetAttribute("NoAnim", true) -- scaled during the reveal: PetAnimator leaves it alone
			pet:PivotTo(spot.CFrame + Vector3.new(0, 1, 0))
			pet:ScaleTo(0.3)
			pet.Parent = hut
			local frames = show and 40 or 12
			local halo = show and fx(Vector3.new(0.3, 5, 5), spot.CFrame, Color3.fromRGB(255, 235, 150), Enum.PartType.Cylinder) or nil
			for k = 1, frames do
				local f = k / frames
				pet:ScaleTo(0.3 + 0.7 * f)
				local h = show and (14 * (1 - f) + 1) or (1 + math.sin(f * math.pi) * 3)
				pet:PivotTo(spot.CFrame * CFrame.new(0, h, 0) * CFrame.Angles(0, f * math.pi * (show and 6 or 4), 0))
				if halo then
					halo.CFrame = CFrame.new(spot.Position + Vector3.new(0, h + 4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				end
				task.wait(0.04)
			end
			if halo then
				TweenService:Create(halo, TweenInfo.new(1), { Transparency = 1 }):Play()
				game:GetService("Debris"):AddItem(halo, 1.1)
			end
			task.wait(1.6)
			pet:Destroy()
		end
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
