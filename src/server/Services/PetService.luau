-- v2.12 PETS: ownership, equip (PetDefs.EquipLimit), following, combat
-- assists, player buffs (capped per kind), and pets idling at the Pet Hut.
--
-- Data (DataService): Pets = { { Uid, Id } }, Equipped = { uid... }, NextPetUid
-- Live pets:   workspace.Pets.<PlayerName>.<PetId>   (follow the player)
-- Hut pets:    Map/Expansion/PetHut<i>/Residents       (unequipped, idle)
-- Remotes:     PetAction (client -> server: "Equip"/"Unequip", uid)
--              PetData   (server -> client: roster snapshot for the UI)
--              OpenPets  (server -> client: open the pet panel)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetDefs = require(ReplicatedStorage.Shared.PetDefs)
local BiomeMap = require(ReplicatedStorage.Shared.BiomeMap)
local PetModels = require(game:GetService("ReplicatedStorage").Shared.PetModels) -- v2.35 shared (client nursery)
local Sfx = require(game:GetService("ReplicatedStorage").Shared.Sfx)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local PetService = {}

local DataService, MonsterService
local Remotes = {}
local live = {} -- [Player] = { { Uid, Def, Model, Slot, NextAttack, Busy } }
local hutPets = {} -- [Player] = { Model }
local shieldNext = {} -- [Player] = os.clock() of next shield pulse
local folder

local function now(): number
	return workspace:GetServerTimeNow()
end

local function data(player: Player)
	local d = DataService.Get(player)
	if d then
		d.Pets = d.Pets or {}
		d.Equipped = d.Equipped or {}
		d.NextPetUid = d.NextPetUid or 1
	end
	return d
end

local function ownedById(d, uid: number)
	for _, p in d.Pets do
		if p.Uid == uid then
			return p
		end
	end
	return nil
end

------------------------------------------------------------------------
-- snapshot for the client UI
------------------------------------------------------------------------
local function sendData(player: Player)
	local d = data(player)
	if not d or not Remotes.PetData then
		return
	end
	local list = {}
	local equipped = {}
	for _, uid in d.Equipped do
		equipped[uid] = true
	end
	for _, p in d.Pets do
		local def = PetDefs.Types[p.Id]
		if def then
			table.insert(list, {
				Uid = p.Uid, Id = p.Id, Name = PetDefs.FormName(def, p.Level), Rarity = def.Rarity, Egg = def.Egg,
				Level = p.Level or 1, XP = p.XP or 0, NextXP = PetDefs.LevelXP[math.min((p.Level or 1) + 1, PetDefs.MaxLevel)],
				Buff = PetDefs.BuffText(def, p.Level), Attack = def.Attack.Kind .. " (" .. def.Attack.Effect .. ")", Hook = def.Hook,
				Equipped = equipped[p.Uid] == true, Price = PetDefs.SellPrice(def, p.Level, p.XP),
			})
		end
	end
	Remotes.PetData:FireClient(player, list, PetDefs.EquipLimit, PetDefs.StorageLimit)
end

------------------------------------------------------------------------
-- live (following) pets
------------------------------------------------------------------------
-- v2.15: two pets walk right beside you, the third just behind
local SLOTS = { Vector3.new(-3.6, 0, 0.4), Vector3.new(3.6, 0, 0.4), Vector3.new(0, 0, 3.8) }

local function clearLive(player: Player)
	for _, lp in live[player] or {} do
		if lp.Model then
			lp.Model:Destroy()
		end
	end
	live[player] = {}
end

local function placeHutPets(player: Player)
	for _, m in hutPets[player] or {} do
		m:Destroy()
	end
	hutPets[player] = {}
	local d = data(player)
	if not d then
		return
	end
	-- find this player's base -> its pet hut
	local map = workspace:FindFirstChild("Map")
	local roofs = map and map:FindFirstChild("Rooftops")
	local hut
	for _, roof in roofs and roofs:GetChildren() or {} do
		if roof:GetAttribute("OwnerUserId") == player.UserId then
			local i = tonumber(string.match(roof.Name, "%d+"))
			local exp = map:FindFirstChild("Expansion")
			hut = exp and i and exp:FindFirstChild("PetHut" .. i)
		end
	end
	if not hut then
		return
	end
	local residents = hut:FindFirstChild("Residents") or Instance.new("Folder")
	residents.Name = "Residents"
	residents.Parent = hut
	local equipped = {}
	for _, uid in d.Equipped do
		equipped[uid] = true
	end
	local spots = {}
	for _, s in hut:GetDescendants() do
		if s:IsA("BasePart") and s.Name == "PetSpot" then
			table.insert(spots, s)
		end
	end
	local n = 0
	for _, p in d.Pets do
		if not equipped[p.Uid] and PetDefs.Types[p.Id] and n < #spots then
			n += 1
			local m = PetModels.Build(p.Id, p.Level)
			-- v2.20: big forms rest at baby size inside the hut (they kept the
			-- form pieces, but poked through the walls at full size)
			local lvlScale = m:GetScale()
			if lvlScale > 1 then
				m:ScaleTo(1)
				m:SetAttribute("Float", (m:GetAttribute("Float") or 0) / lvlScale)
			end
			m:PivotTo(spots[n].CFrame + Vector3.new(0, 0.2 + (m:GetAttribute("Float") or 0) * 0.4, 0))
			m.Parent = residents
			table.insert(hutPets[player], m)
		end
	end
end

local function spawnLive(player: Player)
	clearLive(player)
	local d = data(player)
	if not d then
		return
	end
	local pf = folder:FindFirstChild(player.Name) or Instance.new("Folder")
	pf.Name = player.Name
	pf.Parent = folder
	for i, uid in d.Equipped do
		local owned = ownedById(d, uid)
		local def = owned and PetDefs.Types[owned.Id]
		if def and i <= PetDefs.EquipLimit then
			local m = PetModels.Build(owned.Id, owned.Level)
			m.Parent = pf
			table.insert(live[player], { Uid = uid, Def = def, Model = m, Slot = i, NextAttack = 0, Busy = false, Phase = math.random() * 6, Level = owned.Level or 1 })
		end
	end
	placeHutPets(player)
end

function PetService.Grant(player: Player, petId: string): number?
	local d = data(player)
	if not d or not PetDefs.Types[petId] then
		return nil
	end
	local uid = d.NextPetUid
	d.NextPetUid += 1
	table.insert(d.Pets, { Uid = uid, Id = petId })
	if #d.Equipped < PetDefs.EquipLimit then
		table.insert(d.Equipped, uid)
	end
	spawnLive(player)
	sendData(player)
	return uid
end

local function onAction(player: Player, action: unknown, uid: unknown)
	local d = data(player)
	if not d or type(uid) ~= "number" or not ownedById(d, uid) then
		return
	end
	local idx = table.find(d.Equipped, uid)
	if action == "Sell" then
		-- v2.21: sell a pet to Aurelius or Tayron (must stand near one)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local near = false
		for _, npc in game:GetService("CollectionService"):GetTagged("Npc") do
			local r = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and r and (r.Position - root.Position).Magnitude < 22 then
				near = true
				break
			end
		end
		if not near then
			return
		end
		for i, p in d.Pets do
			if p.Uid == uid then
				local def = PetDefs.Types[p.Id]
				local price = def and PetDefs.SellPrice(def, p.Level, p.XP) or 0
				table.remove(d.Pets, i)
				if idx then
					table.remove(d.Equipped, idx)
				end
				d.Coins = (d.Coins or 0) + price
				DataService.Sync(player)
				DataService.SaveSoon(player)
				if root then
					Sfx.At("Buy", root.Position)
				end
				if Remotes.Hint and def then
					Remotes.Hint:FireClient(player, `Sold {PetDefs.FormName(def, p.Level)} for {price} coins`, 3)
				end
				break
			end
		end
		spawnLive(player)
		sendData(player)
		return
	end
	if action == "Equip" and not idx then
		if #d.Equipped >= PetDefs.EquipLimit then
			table.remove(d.Equipped, 1) -- swap out the oldest
		end
		table.insert(d.Equipped, uid)
	elseif action == "Unequip" and idx then
		table.remove(d.Equipped, idx)
	else
		return
	end
	spawnLive(player)
	sendData(player)
end

------------------------------------------------------------------------
-- combat assists
------------------------------------------------------------------------
local function fxPart(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?, life: number): BasePart
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
	Debris:AddItem(p, life)
	return p
end

local FxKit = require(ReplicatedStorage.Shared.FxKit)
local HitFx = require(ReplicatedStorage.Shared.HitFx)

local EFFECT_COLOR = {
	Slow = Color3.fromRGB(150, 220, 255), Burn = Color3.fromRGB(255, 130, 50), Shock = Color3.fromRGB(230, 245, 255),
	Knock = Color3.fromRGB(255, 240, 200), Expose = Color3.fromRGB(255, 90, 160),
}

local function applyEffect(player: Player, model: Model, effect: string, dmg: number, from: Vector3)
	local info = MonsterService.Get(model)
	if not info or not info.Alive then
		return
	end
	if effect == "Slow" then
		local hum = info.Hum
		if not info.PetSlowed then
			info.PetSlowed = true
			local old = hum.WalkSpeed
			hum.WalkSpeed = old * 0.6
			task.delay(2, function()
				info.PetSlowed = nil
				if hum.Parent then
					hum.WalkSpeed = old
				end
			end)
		end
	elseif effect == "Burn" then
		task.spawn(function()
			for _ = 1, 4 do
				task.wait(0.5)
				if info.Alive then
					MonsterService.Damage(model, dmg * 0.2, player, "Pet")
				end
			end
		end)
	elseif effect == "Shock" then
		if not info.PetShocked then
			info.PetShocked = true
			local hum = info.Hum
			local old = hum.WalkSpeed
			hum.WalkSpeed = 0
			task.delay(0.8, function()
				info.PetShocked = nil
				if hum.Parent then
					hum.WalkSpeed = old
				end
			end)
		end
	elseif effect == "Knock" then
		local dir = info.Root.Position - from
		dir = Vector3.new(dir.X, 0, dir.Z)
		if dir.Magnitude > 0.1 then
			info.Root.AssemblyLinearVelocity = dir.Unit * 35 + Vector3.new(0, 18, 0)
		end
	elseif effect == "Expose" then
		if (info.DamageMult or 1) >= 1 then
			info.DamageMult = 1.25
			info.MultUntil = os.clock() + 4
		end
	end
end

local function strike(player: Player, lp, model: Model, dmg: number)
	MonsterService.Damage(model, dmg, player, "Pet")
	local r = model.PrimaryPart
	if r then
		applyEffect(player, model, lp.Def.Attack.Effect, dmg, lp.Model:GetPivot().Position)
	end
end

local function monstersNear(pos: Vector3, radius: number): { Model }
	local out = {}
	for _, m in CollectionService:GetTagged("Monster") do
		local r = m.PrimaryPart
		local info = r and MonsterService.Get(m)
		if info and info.Alive and (r.Position - pos).Magnitude <= radius then
			table.insert(out, m)
		end
	end
	return out
end

-- the monster this pet should fight: one hunting / fighting its owner nearby
local function pickTarget(player: Player, root: BasePart): Model?
	local best, bestD = nil, 45
	for _, m in monstersNear(root.Position, 45) do
		local info = MonsterService.Get(m)
		if info.Target == player or (info.Damage and (info.Damage[player] or 0) > 0) then
			local d = (m.PrimaryPart.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

local function attack(player: Player, root: BasePart, lp, target: Model)
	local def = lp.Def
	local rar = PetDefs.RARITY[def.Rarity]
	lp.NextAttack = os.clock() + rar.Cooldown
	lp.Busy = true
	local color = EFFECT_COLOR[def.Attack.Effect] or rar.Color
	local from = lp.Model:GetPivot()
	local tPos = target.PrimaryPart.Position
	local dmg = rar.Damage * PetDefs.LevelDamage[lp.Level or 1]
	local kind = def.Attack.Kind
	local lvl = (lp.Level or 1) - 1 -- bigger forms = bigger effects
	local style = HitFx.PetStyle(def.Egg, kind) -- v2.23 element of its egg + attack kind
	local hdir = (tPos - from.Position)
	hdir = hdir.Magnitude > 0.1 and hdir.Unit or nil
	local psc = (0.55 + lvl * 0.3) * (0.8 + rar.Power * 0.12)
	-- tell the clients which attack animation to play (PetAnimator)
	local special = kind == "Pulse" or kind == "Chain" or kind == "Lob"
	lp.Model:SetAttribute("AnimKind", special and "Special" or "Attack")
	lp.Model:SetAttribute("AnimAt", now())
	-- v2.28: own sound per egg element x attack kind (bigger forms a bit deeper)
	Sfx.At(Sfx.Has(style) and style or ("Pet" .. kind), from.Position, 1 + (lp.Level or 1) * -0.08)
	task.spawn(function()
		if kind == "Bite" then
			-- dash in, bite, hop back
			local goal = CFrame.lookAt(tPos:Lerp(from.Position, 0.25), tPos)
			for k = 1, 6 do
				lp.Model:PivotTo(from:Lerp(goal, k / 6) + Vector3.new(0, math.sin(k / 6 * math.pi) * 2, 0))
				task.wait(0.03)
			end
			strike(player, lp, target, dmg)
			FxKit.Slash(CFrame.lookAt(tPos:Lerp(from.Position, 0.3), tPos), color, 0.8 + lvl * 0.25)
			HitFx.Play(style, tPos, psc, hdir)
			task.wait(0.15)
		elseif kind == "Bolt" or kind == "Mend" then
			local shot = fxPart(Vector3.new(0.6, 0.6, 1.6), CFrame.lookAt(from.Position, tPos), color, nil, 0.6)
			FxKit.Trail(shot, color, 0.8)
			TweenService:Create(shot, TweenInfo.new(0.25), { CFrame = CFrame.lookAt(tPos, tPos + (tPos - from.Position)) }):Play()
			task.wait(0.25)
			strike(player, lp, target, dmg)
			HitFx.Play(style, tPos, psc, hdir)
		elseif kind == "Lob" then
			local ball = fxPart(Vector3.one * 1.2, from, color, Enum.PartType.Ball, 1)
			FxKit.Trail(ball, color, 1.2)
			local t0 = os.clock()
			while os.clock() - t0 < 0.5 do
				local k = (os.clock() - t0) / 0.5
				ball.CFrame = CFrame.new(from.Position:Lerp(tPos, k) + Vector3.new(0, math.sin(k * math.pi) * 8, 0))
				task.wait()
			end
			ball:Destroy()
			HitFx.Play(style, tPos, psc * 1.25)
			for _, m in monstersNear(tPos, 8) do
				strike(player, lp, m, dmg * 0.8)
			end
		elseif kind == "Pulse" then
			FxKit.Charge(from.Position, color, 0.6, 0.25)
			FxKit.Shockwave(tPos, 11, color)
			HitFx.Play(style, tPos, psc * 1.1)
			for _, m in monstersNear(tPos, 11) do
				strike(player, lp, m, dmg * 0.75)
			end
		elseif kind == "Chain" then
			local hitList = { target }
			for _, m in monstersNear(tPos, 22) do
				if #hitList < 3 and m ~= target then
					table.insert(hitList, m)
				end
			end
			local prev = from.Position
			for _, m in hitList do
				local p = m.PrimaryPart.Position
				FxKit.Lightning(prev, p, color, 0.25 + lvl * 0.08)
				strike(player, lp, m, dmg * 0.7)
				prev = p
				task.wait(0.06)
			end
		end
		lp.Busy = false
	end)
end

------------------------------------------------------------------------
-- buffs
------------------------------------------------------------------------
local ATTR = {
	Speed = "PetSpeed", Jump = "PetJump", CarrySpeed = "PetCarrySpeed", Resist = "PetResist", KnockResist = "PetKnockResist",
	Damage = "PetDamage", XP = "PetXP", Coins = "PetCoins", Crit = "PetCrit", Lifesteal = "PetLifesteal", Haste = "PetHaste",
	Stealth = "PetStealth", Hatch = "PetHatch", Cleanse = "PetCleanse",
}
local FLAGS = { "FireImmune", "ElectricImmune", "SlipImmune", "BlindImmune", "SlowImmune" }
local petFlagged = {} -- [Player] = { [flag] = true } flags we set (so perks' own flags survive)

local function biomeUnder(root: BasePart): string?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent, folder }
	local info = BiomeMap.ZoneOfHit(workspace:Raycast(root.Position, Vector3.new(0, -20, 0), params))
	return info and info.Biome or nil
end

local function buffTick(player: Player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local totals = {}
	local flags = {}
	-- v2.13 theft rule: while carrying a cloud no pet buff is active (the
	-- check runs here on the server, so re-equipping mid-carry changes nothing)
	if root and hum and hum.Health > 0 and player:GetAttribute("Carrying") == nil then
		local nearBase = false
		local roofs = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Rooftops")
		for _, roof in roofs and roofs:GetChildren() or {} do
			local nest = roof:GetAttribute("OwnerUserId") == player.UserId and roof:FindFirstChild("Nest", true)
			if nest and (nest.Position - root.Position).Magnitude < 80 then
				nearBase = true
			end
		end
		local low = hum.Health < hum.MaxHealth * 0.5
		local afterKill = now() - (player:GetAttribute("LastKillAt") or -100) < 6
		local here = biomeUnder(root)
		for _, lp in live[player] or {} do
			local def = lp.Def
			local when = def.Buff.When
			local on = when == "Always" or (when == "NearBase" and nearBase) or (when == "LowHP" and low)
				or (when == "AfterKill" and afterKill) or (when == "InHome" and here == def.Egg)
			if on then
				local v = PetDefs.BuffValue(def, lp.Level)
				if v == true then
					flags[def.Buff.Kind] = true
				else
					totals[def.Buff.Kind] = (totals[def.Buff.Kind] or 0) + (v :: number)
				end
			end
		end
		-- v2.13: Aurelius boons (permanent) + Tayron gadgets (timed) add to the
		-- same totals; everything together is capped at 1.5x the pet cap
		local function add(kind: string, v: number)
			local spec = PetDefs.BUFF[kind]
			if not spec then
				return
			end
			if spec.Flag then
				flags[kind] = true
			else
				totals[kind] = (totals[kind] or 0) + v
			end
		end
		local hour = game:GetService("Lighting").ClockTime
		local night = hour < 6 or hour >= 18
		local function condOn(when: string): boolean
			if when == "Always" then
				return true
			elseif when == "NearBase" then
				return nearBase
			elseif when == "LowHP" then
				return low
			elseif when == "AfterKill" then
				return afterKill
			elseif when == "Night" then
				return night
			elseif when == "Day" then
				return not night
			elseif string.sub(when, 1, 2) == "In" then
				return here == string.sub(when, 3)
			end
			return false
		end
		local d = data(player)
		for id, lv in d and d.Upgrades or {} do
			local def = Upgrades.Types[id]
			if def and def.Boon and lv >= 1 and condOn(def.Boon.When) then
				add(def.Boon.Kind, def.BoonValue)
			end
		end
		local tnow = now()
		for kind in PetDefs.BUFF do
			if (player:GetAttribute("GBUntil_" .. kind) or 0) > tnow then
				add(kind, player:GetAttribute("GB_" .. kind) or 0)
			end
		end
		-- caps
		for kind, v in totals do
			totals[kind] = math.min(v, PetDefs.BUFF[kind].Cap * 1.5)
		end
		-- regen + shield pulse
		if totals.Regen then
			hum.Health = math.min(hum.MaxHealth, hum.Health + totals.Regen * 0.5)
		end
		if totals.Shield then
			local period = 30 / totals.Shield
			if os.clock() >= (shieldNext[player] or 0) then
				shieldNext[player] = os.clock() + period
				player:SetAttribute("ShieldUntil", now() + 1.5)
			end
		end
	end
	for kind, attr in ATTR do
		local v = totals[kind]
		if (player:GetAttribute(attr) or 0) ~= (v or 0) then
			player:SetAttribute(attr, v)
		end
	end
	petFlagged[player] = petFlagged[player] or {}
	for _, f in FLAGS do
		if flags[f] then
			if not player:GetAttribute(f) then
				player:SetAttribute(f, true)
				petFlagged[player][f] = true
			end
		elseif petFlagged[player][f] then
			player:SetAttribute(f, nil)
			petFlagged[player][f] = nil
		end
	end
end

------------------------------------------------------------------------
function PetService.Start(dataService, monsterService)
	DataService, MonsterService = dataService, monsterService
	monsterService.OnPlayerXP = function(player: Player, xp: number)
		PetService.AddXP(player, xp)
	end
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	for _, n in { "PetAction", "PetData", "OpenPets" } do
		local r = Instance.new("RemoteEvent")
		r.Name = n
		r.Parent = remotesFolder
		Remotes[n] = r
	end
	Remotes.PetAction.OnServerEvent:Connect(onAction)
	Remotes.Hint = remotesFolder:WaitForChild("Hint", 10)

	local function setup(player: Player)
		live[player] = {}
		task.spawn(function()
			for _ = 1, 40 do
				if DataService.Get(player) then
					break
				end
				task.wait(0.5)
			end
			spawnLive(player)
			sendData(player)
			task.wait(6) -- the base may be assigned a little later: fill the hut again
			placeHutPets(player)
		end)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			spawnLive(player)
		end)
	end
	for _, p in Players:GetPlayers() do
		setup(p)
	end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(p)
		clearLive(p)
		for _, m in hutPets[p] or {} do
			m:Destroy()
		end
		hutPets[p], live[p], shieldNext[p], petFlagged[p] = nil, nil, nil, nil
		local pf = folder:FindFirstChild(p.Name)
		if pf then
			pf:Destroy()
		end
	end)

	-- follow (every frame) + combat (5x per second) + buffs (2x per second)
	local combatAcc, buffAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		combatAcc += dt
		buffAcc += dt
		local doCombat = combatAcc >= 0.2
		local doBuffs = buffAcc >= 0.5
		if doCombat then
			combatAcc = 0
		end
		if doBuffs then
			buffAcc = 0
		end
		local t = os.clock()
		for player, list in live do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local target = doCombat and pickTarget(player, root) or nil
				for _, lp in list do
					if lp.Model.Parent and not lp.Busy then
						-- bigger forms stand a bit farther out
						local slot = (SLOTS[lp.Slot] or SLOTS[1]) * (1 + (PetDefs.LevelScale[lp.Level or 1] - 1) * 0.7)
						local float = lp.Model:GetAttribute("Float") or 0
						local bob = math.sin(t * 4 + lp.Phase) * (float > 0 and 0.4 or 0.15)
						local look = root.CFrame.LookVector
						local flat = Vector3.new(look.X, 0, look.Z)
						flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
						local goalPos = (CFrame.lookAt(root.Position, root.Position + flat) * CFrame.new(slot)).Position
						goalPos = Vector3.new(goalPos.X, root.Position.Y - 3 + float + bob, goalPos.Z)
						local cur = lp.Model:GetPivot()
						local nextPos = cur.Position:Lerp(goalPos, math.min(1, dt * 10))
						local face = (goalPos - cur.Position)
						face = Vector3.new(face.X, 0, face.Z)
						local rot = face.Magnitude > 0.3 and CFrame.lookAt(nextPos, nextPos + face.Unit) or CFrame.lookAt(nextPos, nextPos + flat)
						if lp.Model:GetAttribute("Spin") then
							rot *= CFrame.Angles(0, t * 3, 0)
						end
						if (cur.Position - goalPos).Magnitude > 60 then
							rot = CFrame.new(goalPos) -- teleport if left far behind
						end
						lp.Model:PivotTo(rot)
						if target and t >= lp.NextAttack then
							attack(player, root, lp, target)
						end
					end
				end
			end
			if doBuffs then
				buffTick(player)
			end
		end
	end)

	-- hut residents gently bob and turn
	task.spawn(function()
		while true do
			task.wait(0.1)
			local t = os.clock()
			for _, list in hutPets do
				for i, m in list do
					if m.Parent then
						local base = m:GetAttribute("HomeCF")
						if not base then
							m:SetAttribute("HomeCF", m:GetPivot())
							base = m:GetPivot()
						end
						m:PivotTo(base * CFrame.new(0, math.abs(math.sin(t * 2 + i)) * 0.6, 0) * CFrame.Angles(0, math.sin(t * 0.5 + i) * 0.8, 0))
					end
				end
			end
		end
	end)
end

-- v2.13 Tayron blast / freeze gadgets
function PetService.Blast(player: Player, pos: Vector3, item)
	local color = EFFECT_COLOR[item.Hit or "Slow"] or Color3.fromRGB(255, 200, 120)
	local ring = fxPart(Vector3.new(0.3, 2, 2), CFrame.new(pos - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.PartType.Cylinder, 0.7)
	TweenService:Create(ring, TweenInfo.new(0.5), { Size = Vector3.new(0.2, item.Radius * 2, item.Radius * 2), Transparency = 1 }):Play()
	for _, m in monstersNear(pos, item.Radius) do
		if item.Effect == "Freeze" then
			local info = MonsterService.Get(m)
			if info and not info.PetShocked then
				info.PetShocked = true
				local hum = info.Hum
				local old = hum.WalkSpeed
				hum.WalkSpeed = 0
				task.delay(item.Seconds, function()
					info.PetShocked = nil
					if hum.Parent then
						hum.WalkSpeed = old
					end
				end)
			end
		else
			MonsterService.Damage(m, item.Damage, player, "Gadget")
			applyEffect(player, m, item.Hit, item.Damage, pos)
		end
	end
end

-- v2.17 pet XP: every equipped pet shares the monster XP its owner earns
function PetService.AddXP(player: Player, xp: number)
	local d = data(player)
	if not d or xp <= 0 then
		return
	end
	local gain = math.max(1, math.floor(xp * PetDefs.PetXPShare))
	local evolved = {}
	for _, uid in d.Equipped do
		local p = ownedById(d, uid)
		local def = p and PetDefs.Types[p.Id]
		if p and def then
			local before = p.Level or 1
			p.XP = (p.XP or 0) + gain
			p.Level = PetDefs.LevelOf(p.XP)
			if p.Level > before then
				table.insert(evolved, { Def = def, From = before, To = p.Level })
			end
		end
	end
	if #evolved > 0 then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		spawnLive(player) -- rebuild in the new form
		for _, e in evolved do
			if root then
				Sfx.At("PetLevelUp", root.Position)
				local ring = fxPart(Vector3.new(0.3, 2, 2), CFrame.new(root.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), PetDefs.RARITY[e.Def.Rarity].Color, Enum.PartType.Cylinder, 1)
				TweenService:Create(ring, TweenInfo.new(0.8), { Size = Vector3.new(0.2, 30, 30), Transparency = 1 }):Play()
				local col = fxPart(Vector3.new(40, 3, 3), CFrame.new(root.Position + Vector3.new(0, 18, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 235, 150), Enum.PartType.Cylinder, 1.4)
				col.Transparency = 0.4
				TweenService:Create(col, TweenInfo.new(1.3), { Size = Vector3.new(40, 0.5, 0.5), Transparency = 1 }):Play()
			end
			if Remotes.Hint then
				Remotes.Hint:FireClient(player, `✨ {PetDefs.FormName(e.Def, e.From)} evolved into {PetDefs.FormName(e.Def, e.To)}! (Level {e.To})`, 5)
			end
		end
		DataService.SaveSoon(player)
	end
	sendData(player)
end

PetService.SendData = sendData
PetService.Open = function(player: Player)
	sendData(player)
	if Remotes.OpenPets then
		Remotes.OpenPets:FireClient(player)
	end
end
PetService.Refresh = spawnLive

return PetService
