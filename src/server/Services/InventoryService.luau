-- Two separate inventories (both saved, both WIPED when you die):
--
--   Inventory (items)  shop items bought from Tayron: potions, Nitro, flares…
--                      data.Items = { { Id, Count }, ... }  (max Config.ItemSlots)
--   Quirks / Perks     clouds equipped from YOUR OWN vault; their perk is active
--                      while equipped. Dying destroys the cloud for good.
--                      data.Perks = { { Type, Shiny }, ... } (max Config.PerkSlots)
--
-- Carried (leashed) clouds are in neither inventory.
--
-- Clients read player attributes:
--   Items "Nitro:2,Flare:1"   Perks "Cosmic:0,Snow:1" (Type:shiny)
--   PerkSpeed, PerkJump, NoSlip, IceGrip, WindImmune, ElectricImmune, LightningImmune
--   SpeedUntil/SpeedMult, JumpUntil/JumpMult, NitroUntil (server time)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local ShopItems = require(ReplicatedStorage.Shared.ShopItems)
local Weather = require(ReplicatedStorage.Shared.WeatherTypes)

local InventoryService = {}

-- Hooks filled in by other services (avoids require loops):
--   LaserHit(shooter, target) -> boolean   WeatherService: thief drops shooter's cloud?
--   ModelHit(shooter, model, dir, kind)    a non-player model was hit (CombatService)
--   AreaHit(player, pos, radius, kind)     area item hit (Flare)
--   OnOwnBase(player) -> boolean           near your own Nest?
--   ForceLock(player, seconds)             BaseLockService: raise your base shield now
InventoryService.Hooks = {} :: { [string]: any }

-- Set by WeatherService: puts a perk cloud back into the player's vault
InventoryService.ReturnToVault = nil :: ((Player, string, boolean) -> boolean)?

local DataService, Remotes

------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------

local function data(player: Player)
	local d = DataService.Get(player)
	if not d then
		return nil
	end
	if type(d.Items) ~= "table" then
		d.Items = {}
		-- migrate old Nitro charges
		if type(d.Inventory) == "table" and (d.Inventory.Nitro or 0) > 0 then
			table.insert(d.Items, { Id = "Nitro", Count = d.Inventory.Nitro })
		end
	end
	if type(d.Perks) ~= "table" then
		d.Perks = {}
	end
	d.Inventory = nil
	return d
end

local function perkTotals(perks)
	local t = {
		PerkSpeed = 1,
		PerkJump = 1,
		NoSlip = false,
		IceGrip = false,
		WindImmune = false,
		ElectricImmune = false,
		LightningImmune = false,
		Regen = 0,
		ItemTime = 1,
		CoinMult = 1,
		DamageResist = 0,
		StormAura = false,
		BlastResist = false,
		Gravity = 0, -- fraction of gravity removed (client applies it)
		FireImmune = false,
		PoisonImmune = false,
		Chaos = false,
	}
	for _, entry in perks do
		local def = Weather.Types[entry.Type]
		local perk = def and def.Perk
		if perk then
			t.PerkSpeed *= perk.Speed or 1
			t.PerkJump *= perk.Jump or 1
			t.NoSlip = t.NoSlip or perk.NoSlip == true
			t.IceGrip = t.IceGrip or perk.IceGrip == true
			t.WindImmune = t.WindImmune or perk.WindImmune == true
			t.ElectricImmune = t.ElectricImmune or perk.ElectricImmune == true
			t.LightningImmune = t.LightningImmune or perk.LightningImmune == true
			t.Regen += perk.Regen or 0
			t.ItemTime = math.max(t.ItemTime, perk.ItemTime or 1)
			t.CoinMult = math.max(t.CoinMult, perk.CoinMult or 1)
			t.DamageResist = math.min(0.75, t.DamageResist + (perk.DamageResist or 0))
			t.StormAura = t.StormAura or perk.StormAura == true
			t.BlastResist = t.BlastResist or perk.BlastResist == true
			t.Gravity = math.min(0.6, math.max(t.Gravity, perk.Gravity or 0))
			t.FireImmune = t.FireImmune or perk.FireImmune == true
			t.PoisonImmune = t.PoisonImmune or perk.PoisonImmune == true
			t.Chaos = t.Chaos or perk.Chaos == true
		end
	end
	return t
end

local function sync(player: Player)
	local d = data(player)
	if not d then
		return
	end
	local items = {}
	for _, it in d.Items do
		table.insert(items, `{it.Id}:{it.Count}`)
	end
	player:SetAttribute("Items", table.concat(items, ","))

	local perks = {}
	for _, p in d.Perks do
		table.insert(perks, `{p.Type}:{p.Shiny and 1 or 0}`)
	end
	player:SetAttribute("Perks", table.concat(perks, ","))
	for k, v in perkTotals(d.Perks) do
		player:SetAttribute(k, v)
	end
end

------------------------------------------------------------------------
-- Perks
------------------------------------------------------------------------

function InventoryService.EquipPerk(player: Player, typeName: string, shiny: boolean): boolean
	local d = data(player)
	if not d or #d.Perks >= (player:GetAttribute("PerkSlots") or Config.PerkSlots) then
		return false
	end
	table.insert(d.Perks, { Type = typeName, Shiny = shiny })
	sync(player)
	return true
end

local function perkAction(player: Player, action: unknown, index: unknown)
	local d = data(player)
	if not d or action ~= "Return" or type(index) ~= "number" then
		return
	end
	local entry = d.Perks[index]
	if not entry or not InventoryService.ReturnToVault then
		return
	end
	if InventoryService.ReturnToVault(player, entry.Type, entry.Shiny == true) then
		table.remove(d.Perks, index)
		sync(player)
		Remotes.Hint:FireClient(player, `Back in your vault`, 3)
	else
		Remotes.Hint:FireClient(player, "Vault full!", 2)
	end
end

------------------------------------------------------------------------
-- Perk abilities (G / H / J = perk slot 1 / 2 / 3)
------------------------------------------------------------------------

local function blink(player: Player, root: BasePart)
	local char = player.Character
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local dir = look.Magnitude > 0 and look.Unit or Vector3.zAxis
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, workspace:FindFirstChild("Weather") }
	local hit = workspace:Raycast(root.Position, dir * Config.BlinkDistance, params)
	local dist = hit and math.max(0, hit.Distance - 2) or Config.BlinkDistance
	root.CFrame = root.CFrame + dir * dist

	-- invisible for a moment (everyone sees it: server-side transparency)
	local saved = {}
	for _, d in char:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Decal")) and d.Name ~= "HumanoidRootPart" then
			saved[d] = d.Transparency
			d.Transparency = 1
		end
	end
	task.delay(Config.BlinkInvisible, function()
		for inst, t in saved do
			if inst.Parent then
				inst.Transparency = t
			end
		end
	end)
end

local function dazzle(player: Player, root: BasePart)
	for _, other in Players:GetPlayers() do
		local r = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - root.Position).Magnitude <= Config.DazzleRadius then
			Remotes.Dazzle:FireClient(other, Config.DazzleDuration)
		end
	end
	Remotes.Dazzle:FireClient(player, 0.25) -- small flash for yourself
end

-- Quake: everyone near you gets knocked up and away (blast-resist halves it)
local function quake(player: Player, root: BasePart)
	for _, other in Players:GetPlayers() do
		local r = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local offset = r.Position - root.Position
			if offset.Magnitude <= Config.QuakeRadius and not ((other:GetAttribute("ShieldUntil") or 0) > workspace:GetServerTimeNow()) then
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
				local resist = other:GetAttribute("BlastResist") and 0.5 or 1
				Remotes.Knock:FireClient(other, (dir * Config.QuakeKnock + Vector3.new(0, 35, 0)) * resist)
				other:SetAttribute("RagdollUntil", workspace:GetServerTimeNow() + Config.RagdollTime)
			end
		end
	end
	if InventoryService.Hooks.ModelHit then
		for _, tag in { "TestDummy", "Monster" } do
			for _, model in CollectionService:GetTagged(tag) do
				local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r and (r.Position - root.Position).Magnitude <= Config.QuakeRadius then
					InventoryService.Hooks.ModelHit(player, model, (r.Position - root.Position).Unit, "Quake")
				end
			end
		end
	end
	Remotes.Dazzle:FireClient(player, 0.15)
end

local ABILITIES = {
	Quake = { Run = quake, Cooldown = Config.QuakeCooldown },
	Blink = { Run = blink, Cooldown = Config.BlinkCooldown },
	Dazzle = { Run = dazzle, Cooldown = Config.DazzleCooldown },
}

local function perkAbility(player: Player, slot: unknown)
	local d = data(player)
	if not d or type(slot) ~= "number" then
		return
	end
	local entry = d.Perks[slot]
	local perk = entry and Weather.Types[entry.Type] and Weather.Types[entry.Type].Perk
	local ability = perk and perk.Ability and ABILITIES[perk.Ability]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not ability or not root then
		return
	end
	local now = workspace:GetServerTimeNow()
	local key = "AbilityReady" .. slot
	if now < (player:GetAttribute(key) or 0) then
		return
	end
	player:SetAttribute(key, now + ability.Cooldown)
	ability.Run(player, root)
end

------------------------------------------------------------------------
-- Items (shop)
------------------------------------------------------------------------

local function addItem(d, id: string): boolean
	local item = ShopItems.Types[id]
	local charges = item.Charges or 1
	local max = item.MaxStack or Config.ItemStack
	for _, it in d.Items do
		if it.Id == id then
			if it.Count + charges > max then
				return false
			end
			it.Count += charges
			return true
		end
	end
	if #d.Items >= Config.ItemSlots then
		return false
	end
	table.insert(d.Items, { Id = id, Count = charges })
	return true
end

local function buy(player: Player, id: unknown)
	local d = data(player)
	local item = type(id) == "string" and ShopItems.Types[id]
	if not d or not item or item.ComingSoon then
		return
	end
	-- v2.13: gadgets are locked until their cloud is offered at Tayron's Orb
	if item.Cloud and not (d.Unlocks and d.Unlocks[id]) then
		Remotes.Hint:FireClient(player, "Locked: offer the required cloud at Tayron's Orb first.", 3)
		return
	end
	if d.Coins < item.Price then
		Remotes.Hint:FireClient(player, `Need {item.Price} coins`, 2)
		return
	end
	if not addItem(d, id :: string) then
		Remotes.Hint:FireClient(player, "Bag full!", 2)
		return
	end
	d.Coins -= item.Price
	DataService.Sync(player)
	do
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if r then
			require(game:GetService("ReplicatedStorage").Shared.Sfx).At("Buy", r.Position)
		end
	end
	sync(player)
	Remotes.Hint:FireClient(player, `Got {item.DisplayName}!`, 2)
end

local function flare(player: Player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pillar = Instance.new("Part")
	pillar.Name = "Flare"
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = Color3.fromRGB(255, 120, 200)
	pillar.Transparency = 0.3
	pillar.Size = Vector3.new(1.5, 300, 1.5)
	pillar.Position = root.Position + Vector3.new(0, 150, 0)
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 4
	light.Color = pillar.Color
	light.Parent = pillar
	pillar.Parent = workspace
	Debris:AddItem(pillar, ShopItems.Types.Flare.Duration)
	Remotes.Hint:FireAllClients(`{player.DisplayName} sent a flare!`, 3)
	if InventoryService.Hooks.AreaHit then
		InventoryService.Hooks.AreaHit(player, root.Position, 16, "Flare") -- the flash burns monsters nearby
	end
end

------------------------------------------------------------------------
-- Aimed items: Laser Gun, Grappling Hook
------------------------------------------------------------------------

local function aimRay(player: Player, root: BasePart, aim: unknown, range: number)
	if typeof(aim) ~= "Vector3" then
		return nil, nil
	end
	local dir = (aim :: Vector3) - root.Position
	if dir.Magnitude < 1 then
		return nil, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("Weather") }
	return workspace:Raycast(root.Position, dir.Unit * range, params), dir.Unit
end

local function beam(from: Vector3, to: Vector3, color: Color3, width: number, life: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(width, width, (to - from).Magnitude)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = workspace
	Debris:AddItem(p, life)
end

local lastShot = {} -- [Player] = os.clock()

local function fireLaser(player: Player, root: BasePart, aim: unknown): boolean
	if os.clock() - (lastShot[player] or 0) < Config.LaserCooldown then
		return false
	end
	local hit, dir = aimRay(player, root, aim, Config.LaserRange)
	if not dir then
		return false
	end
	lastShot[player] = os.clock()
	local from = root.Position + Vector3.new(0, 1.5, 0)
	local to = hit and hit.Position or root.Position + dir * Config.LaserRange
	beam(from, to, Color3.fromRGB(255, 60, 90), 0.35, 0.15)

	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	local target = model and Players:GetPlayerFromCharacter(model)
	if not target and model and InventoryService.Hooks.ModelHit then
		InventoryService.Hooks.ModelHit(player, model, dir, "Laser") -- monsters / the Studio test dummy
	end
	if not target or target == player then
		return true
	end
	local now = workspace:GetServerTimeNow()
	if (target:GetAttribute("ShieldUntil") or 0) > now then
		Remotes.Hint:FireClient(player, `Shielded!`, 2)
		return true
	end
	-- a thief carrying YOUR stolen cloud drops it: it flies back to your vault
	if InventoryService.Hooks.LaserHit and InventoryService.Hooks.LaserHit(player, target) then
		return true
	end
	target:SetAttribute("LaserSlowUntil", now + Config.LaserSlowTime)
	target:SetAttribute("RagdollUntil", now + Config.RagdollTime) -- brief ragdoll (client: Ragdoll.luau)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:TakeDamage(Config.LaserDamage * (1 - (target:GetAttribute("DamageResist") or 0)))
	end
	return true
end

local function fireGrapple(player: Player, root: BasePart, aim: unknown): boolean
	local hit = aimRay(player, root, aim, Config.GrappleRange)
	if not hit then
		Remotes.Hint:FireClient(player, "Nothing to grab", 1.5)
		return false
	end
	beam(root.Position, hit.Position, Color3.fromRGB(190, 160, 120), 0.15, 0.6)
	Remotes.Grapple:FireClient(player, hit.Position) -- client does the zip (it owns the character)
	return true
end

local function shield(player: Player, item, duration: number)
	local hooks = InventoryService.Hooks
	if hooks.OnOwnBase and hooks.OnOwnBase(player) and hooks.ForceLock then
		hooks.ForceLock(player, item.BaseDuration * (player:GetAttribute("ItemTime") or 1))
		return
	end
	local char = player.Character
	if not char then
		return
	end
	player:SetAttribute("ShieldUntil", workspace:GetServerTimeNow() + duration)
	local ff = Instance.new("ForceField") -- built-in bubble: blocks damage too
	ff.Name = "ShieldGenerator"
	ff.Parent = char
	Debris:AddItem(ff, duration)
	Remotes.Hint:FireClient(player, `Shield on!`, 2)
end

local function useItem(player: Player, id: unknown, aim: unknown)
	local d = data(player)
	local item = type(id) == "string" and ShopItems.Types[id]
	if not d or not item or item.ComingSoon then
		return
	end
	local slot
	for i, it in d.Items do
		if it.Id == id then
			slot = i
			break
		end
	end
	if not slot then
		return
	end

	local now = workspace:GetServerTimeNow()
	local duration = (item.Duration or 0) * (player:GetAttribute("ItemTime") or 1)
	if item.Effect == "Speed" then
		player:SetAttribute("SpeedMult", item.Amount)
		player:SetAttribute("SpeedUntil", now + duration)
	elseif item.Effect == "Jump" then
		player:SetAttribute("JumpMult", item.Amount)
		player:SetAttribute("JumpUntil", now + duration)
	elseif item.Effect == "Nitro" then
		if now < (player:GetAttribute("NitroUntil") or 0) then
			return -- already boosting
		end
		player:SetAttribute("NitroUntil", now + duration)
	elseif item.Effect == "Flare" then
		flare(player)
	elseif item.Effect == "Shield" then
		shield(player, item, duration)
	-- v2.13 Tayron gadgets ------------------------------------------------
	elseif item.Effect == "Buff" then
		-- timed buff, summed with pets/boons (and switched off while carrying) in PetService
		player:SetAttribute("GB_" .. item.Kind, item.Amount)
		player:SetAttribute("GBUntil_" .. item.Kind, now + duration)
	elseif item.Effect == "Heal" then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end
		hum.Health = math.min(hum.MaxHealth, hum.Health + item.Amount)
	elseif item.Effect == "ShieldNow" then
		player:SetAttribute("ShieldUntil", now + duration)
	elseif item.Effect == "Cleanse" then
		for _, attr in { "MonsterSlowUntil", "RootedUntil", "BurnUntil", "BlindUntil", "ShockedUntil", "LaserSlowUntil" } do
			player:SetAttribute(attr, 0)
		end
	elseif item.Effect == "EggWarm" then
		if not d.Incubator then
			Remotes.Hint:FireClient(player, "No egg is incubating.", 2)
			return
		end
		d.Incubator.ReadyAt -= item.Minutes * 60
	elseif item.Effect == "Recall" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or player:GetAttribute("Carrying") then
			Remotes.Hint:FireClient(player, "Can't recall while carrying a cloud.", 2)
			return
		end
		local roofs = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Rooftops")
		local nest
		for _, roof in roofs and roofs:GetChildren() or {} do
			if roof:GetAttribute("OwnerUserId") == player.UserId then
				nest = roof:FindFirstChild("Nest", true)
			end
		end
		if not nest then
			return
		end
		player.Character:PivotTo(CFrame.new(nest.Position + Vector3.new(0, 5, 4)))
	elseif item.Effect == "Dash" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not Remotes.Grapple then
			return
		end
		Remotes.Grapple:FireClient(player, root.Position + root.CFrame.LookVector * item.Distance)
	elseif item.Effect == "Blast" or item.Effect == "Freeze" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hook = InventoryService.Hooks.MonsterBlast
		if not root or not hook then
			return
		end
		hook(player, root.Position, item)
	elseif item.Effect == "Laser" or item.Effect == "Grapple" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local used = item.Effect == "Laser" and fireLaser(player, root, aim) or (item.Effect == "Grapple" and fireGrapple(player, root, aim))
		if not used then
			return
		end
	end

	local it = d.Items[slot]
	it.Count -= 1
	if it.Count <= 0 then
		table.remove(d.Items, slot)
	end
	sync(player)
end

------------------------------------------------------------------------
-- Death + regen
------------------------------------------------------------------------

function InventoryService.Wipe(player: Player): (number, number)
	local d = data(player)
	if not d then
		return 0, 0
	end
	local lostItems, lostPerks = #d.Items, #d.Perks
	d.Items = {}
	d.Perks = {}
	for _, attr in { "SpeedUntil", "JumpUntil", "NitroUntil", "ShieldUntil" } do
		player:SetAttribute(attr, 0)
	end
	sync(player)
	return lostItems, lostPerks
end

-- Give a random shop item (used by Economic clouds on delivery). Returns its name or nil.
function InventoryService.GiveRandomItem(player: Player): string?
	local d = data(player)
	if not d then
		return nil
	end
	local ids = {}
	for id, item in ShopItems.Types do
		if not item.ComingSoon then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _ = 1, 4 do
		local id = ids[math.random(1, #ids)]
		if addItem(d, id) then
			sync(player)
			return ShopItems.Types[id].DisplayName or id
		end
	end
	return nil
end

-- Chaos perk: every ChaosInterval s a random buff or debuff for ChaosDuration s
local CHAOS = {
	{ "Speed Burst", "SpeedUntil", "SpeedMult", 1.4, true },
	{ "Moon Jump", "JumpUntil", "JumpMult", 1.6, true },
	{ "Heavy Feet", "SpeedUntil", "SpeedMult", 0.75, false },
	{ "Wobbly Legs", "JumpUntil", "JumpMult", 0.7, false },
}
local function chaosLoop()
	while true do
		task.wait(Config.ChaosInterval)
		local now = workspace:GetServerTimeNow()
		for _, player in Players:GetPlayers() do
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if player:GetAttribute("Chaos") and hum and hum.Health > 0 then
				local roll = math.random()
				if roll < 0.15 then
					local hp = math.random(0, 1) == 1 and 30 or -15
					hum.Health = math.clamp(hum.Health + hp, 1, hum.MaxHealth)
					Remotes.Hint:FireClient(player, hp > 0 and "CHAOS: +30 HP!" or "CHAOS: ouch, -15 HP", 2)
				else
					-- 2 of 4 effects are good; weight toward good ones (65%)
					local good = math.random() < 0.65
					local pool = {}
					for _, e in CHAOS do
						if e[5] == good then
							table.insert(pool, e)
						end
					end
					local e = pool[math.random(1, #pool)]
					player:SetAttribute(e[3], e[4])
					player:SetAttribute(e[2], now + Config.ChaosDuration)
					Remotes.Hint:FireClient(player, `CHAOS: {e[1]}!`, 2)
				end
			end
		end
	end
end

local function regenLoop()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local regen = player:GetAttribute("Regen") or 0
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if regen > 0 and hum and hum.Health > 0 then
				hum.Health = math.min(hum.MaxHealth, hum.Health + regen)
			end
		end
	end
end

function InventoryService.OnPlayerAdded(player: Player)
	sync(player)
	local function onCharacter(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			local items, perks = InventoryService.Wipe(player)
			if perks > 0 then
				Remotes.Hint:FireClient(player, `Oh no! You lost your perks and items`, 5)
			elseif items > 0 then
				Remotes.Hint:FireClient(player, "Oh no! You lost your items", 4)
			end
		end)
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

function InventoryService.Start(dataService, remotes)
	DataService = dataService
	Remotes = remotes
	Remotes.UseItem.OnServerEvent:Connect(useItem)
	Remotes.BuyItem.OnServerEvent:Connect(buy)
	Remotes.PerkAction.OnServerEvent:Connect(perkAction)
	Remotes.PerkAbility.OnServerEvent:Connect(perkAbility)
	task.spawn(regenLoop)
	task.spawn(chaosLoop)
end

return InventoryService
