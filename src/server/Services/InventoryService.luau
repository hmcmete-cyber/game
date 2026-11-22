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

local FxKit = require(game:GetService("ReplicatedStorage").Shared.FxKit)
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
	-- v2.31 gear: everything bought from Tayron is owned for good
	if type(d.Gear) ~= "table" then
		d.Gear = {}
	end
	if #d.Items > 0 then -- migrate old one-shot items into owned gear
		for _, it in d.Items do
			if ShopItems.Types[it.Id] then
				d.Gear[it.Id] = true
			end
		end
		d.Items = {}
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
	local gear = {}
	for id in d.Gear do
		table.insert(gear, id)
	end
	player:SetAttribute("Gear", "," .. table.concat(gear, ",") .. ",")

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

------------------------------------------------------------------------
-- v2.31 GEAR: owned forever, held in your hand as a Tool
--   simple gear: Cooldown after each use · OP gear: 3 charges refilling
--   (state lives on the server; the Tool carries Charges/ReadyAt/NextChargeAt
--    attributes so the client can show the timer)
------------------------------------------------------------------------
local ItemIcons = require(ReplicatedStorage.Shared.ItemIcons)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local HitFx = require(ReplicatedStorage.Shared.HitFx)
local gearState = {} -- [Player] = { [id] = { Charges, NextAt, ReadyAt } }

local function owns(d, id: string): boolean
	return d ~= nil and d.Gear ~= nil and d.Gear[id] == true
end

local function stateOf(player: Player, id: string)
	gearState[player] = gearState[player] or {}
	local st = gearState[player][id]
	if not st then
		st = { Charges = ShopItems.Types[id].MaxCharges or 0, NextAt = 0, ReadyAt = 0 }
		gearState[player][id] = st
	end
	return st
end

local function rechargeTick(st, item, t: number): boolean
	local changed = false
	while item.Op and st.Charges < item.MaxCharges and st.NextAt > 0 and t >= st.NextAt do
		st.Charges += 1
		st.NextAt = st.Charges < item.MaxCharges and (st.NextAt + item.Recharge) or 0
		changed = true
	end
	return changed
end

local function toolsOf(player: Player, id: string): { Tool }
	local out = {}
	for _, where in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, t in where and where:GetChildren() or {} do
			if t:IsA("Tool") and t:GetAttribute("GearId") == id then
				table.insert(out, t)
			end
		end
	end
	return out
end

local function refreshTool(player: Player, id: string)
	local st = stateOf(player, id)
	for _, tool in toolsOf(player, id) do
		tool:SetAttribute("Charges", st.Charges)
		tool:SetAttribute("ReadyAt", st.ReadyAt)
		tool:SetAttribute("NextChargeAt", st.NextAt)
	end
end

local function makeTool(id: string): Tool
	local item = ShopItems.Types[id]
	local tool = Instance.new("Tool")
	tool.Name = item.DisplayName or id
	tool.ToolTip = item.Desc or ""
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("GearId", id)
	tool:SetAttribute("MaxCharges", item.MaxCharges or 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 0.5)
	handle.Transparency = 1
	handle.CanCollide, handle.CanQuery, handle.CanTouch, handle.Massless = false, false, false, true
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	-- the shop's 3D logo becomes the gear you hold
	local ok, model = pcall(function()
		return ItemIcons.Build(ItemIcons.KindFor(id, item), item.IconColor or Color3.new(1, 1, 1))
	end)
	if ok and model then
		local ext = model:GetExtentsSize().Magnitude
		if ext > 0 then
			model:ScaleTo(model:GetScale() * 2 / ext)
		end
		model:PivotTo(CFrame.new(0, 0.7, -0.2))
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, false, true
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = handle, part
				w.Parent = part
			end
		end
		model.Parent = tool
	end
	return tool
end

local function giveTool(player: Player, id: string)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or #toolsOf(player, id) > 0 then
		return
	end
	makeTool(id).Parent = backpack
	refreshTool(player, id)
end

local function giveAllTools(player: Player)
	local d = data(player)
	if not d then
		return
	end
	for _, id in ShopItems.Order do -- hotbar in shop order
		if d.Gear[id] and ShopItems.Types[id] then
			giveTool(player, id)
		end
	end
end
InventoryService.GiveAllTools = giveAllTools

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
	if owns(d, id :: string) then
		Remotes.Hint:FireClient(player, "You already own this gear.", 2)
		return
	end
	if d.Coins < item.Price then
		Remotes.Hint:FireClient(player, `Need {item.Price} coins`, 2)
		return
	end
	d.Gear[id :: string] = true
	giveTool(player, id :: string)
	DataService.SaveSoon(player)
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
	FxKit.Explosion(root.Position, pillar.Color, 1.2) -- v2.22
	FxKit.Pillar(root.Position, pillar.Color, 120, 1.5)
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
	-- v2.22: muzzle flash + impact burst around the laser line
	FxKit.Impact(from, color, 0.5)
	FxKit.Burst(to, color, 0.7)
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

-- feedback: every gear use shows and sounds like something
local BUFF_COLOR = {
	Speed = Color3.fromRGB(255, 200, 80), Jump = Color3.fromRGB(150, 255, 150), Resist = Color3.fromRGB(170, 190, 220),
	KnockResist = Color3.fromRGB(200, 170, 120), Regen = Color3.fromRGB(120, 255, 150), Damage = Color3.fromRGB(255, 90, 80),
	XP = Color3.fromRGB(140, 200, 255), Coins = Color3.fromRGB(255, 215, 70), Crit = Color3.fromRGB(255, 140, 60),
	Lifesteal = Color3.fromRGB(220, 40, 70), Haste = Color3.fromRGB(255, 255, 140), Stealth = Color3.fromRGB(120, 110, 160),
}
local BLAST_STYLE = { Burn = "Fire", Slow = "Ice", Shock = "Electric", Knock = "Earth", Expose = "Crystal" }
local BLAST_SFX = { Burn = "Fire", Slow = "Ice", Shock = "Electric", Knock = "Earth", Expose = "Crystal" }
local function feedback(root: BasePart, color: Color3, cue: string?)
	FxKit.Burst(root.Position, color, 0.8)
	if cue then
		Sfx.At(cue, root.Position)
	end
end

-- timed buff that never DOWNGRADES a stronger active one (just extends it)
local function setTimed(player: Player, amountAttr: string, untilAttr: string, amount: number, untilT: number, now: number)
	local cur = player:GetAttribute(amountAttr) or 0
	local curUntil = player:GetAttribute(untilAttr) or 0
	if curUntil > now and cur > amount then
		player:SetAttribute(untilAttr, math.max(curUntil, untilT))
	else
		player:SetAttribute(amountAttr, amount)
		player:SetAttribute(untilAttr, untilT)
	end
end

-- groundsafe point for Dash: stop before walls, never over the void
local function dashTarget(player: Player, root: BasePart, dir: Vector3, dist: number): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("Weather"), workspace:FindFirstChild("FxKit") }
	local wall = workspace:Raycast(root.Position, dir * dist, params)
	local reach = wall and math.max(0, (wall.Position - root.Position).Magnitude - 3) or dist
	for d = reach, 4, -4 do
		local p = root.Position + dir * d
		local floor = workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
		if floor and floor.Position.Y > 14 then
			return floor.Position + Vector3.new(0, 3, 0)
		end
	end
	return nil
end

-- throw a bomb: glowing ball lobbed to the aim point, then it blows up there
local function throwBomb(player: Player, root: BasePart, aim: unknown, item, onLand: (Vector3) -> ())
	local from = root.Position + Vector3.new(0, 2, 0)
	local target = typeof(aim) == "Vector3" and aim or (root.Position + root.CFrame.LookVector * 20)
	local off = target - from
	if off.Magnitude > 60 then
		target = from + off.Unit * 60
	end
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 1.4
	ball.Material = Enum.Material.Neon
	ball.Color = item.IconColor or Color3.fromRGB(255, 200, 120)
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
	ball.CFrame = CFrame.new(from)
	ball.Parent = workspace
	FxKit.Trail(ball, ball.Color, 1.2)
	Debris:AddItem(ball, 2)
	task.spawn(function()
		local t0, T = os.clock(), 0.55
		while os.clock() - t0 < T do
			local f = (os.clock() - t0) / T
			ball.CFrame = CFrame.new(from:Lerp(target, f) + Vector3.new(0, math.sin(f * math.pi) * 10, 0))
			task.wait()
		end
		ball:Destroy()
		onLand(target)
	end)
end

-- apply one gear use; returns false when nothing happened (no cooldown spent)
local function apply(player: Player, d, item, aim: unknown): boolean
	local now = workspace:GetServerTimeNow()
	local duration = (item.Duration or 0) * (player:GetAttribute("ItemTime") or 1)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local e = item.Effect
	if e == "Speed" then
		setTimed(player, "SpeedMult", "SpeedUntil", item.Amount, now + duration, now)
		feedback(root, BUFF_COLOR.Speed, "PetPulse")
	elseif e == "Jump" then
		setTimed(player, "JumpMult", "JumpUntil", item.Amount, now + duration, now)
		feedback(root, BUFF_COLOR.Jump, "PetPulse")
	elseif e == "Nitro" then
		if now < (player:GetAttribute("NitroUntil") or 0) then
			return false -- already boosting
		end
		player:SetAttribute("NitroUntil", now + duration)
		HitFx.Play("PlayerPunch", root.Position - root.CFrame.LookVector * 2, 0.7, -root.CFrame.LookVector)
		Sfx.At("Wind", root.Position)
	elseif e == "Flare" then
		flare(player)
	elseif e == "Shield" then
		shield(player, item, duration)
		Sfx.At("BaseLock", root.Position)
	elseif e == "Buff" then
		-- summed with pets/boons in PetService; a weaker one never replaces a stronger one
		setTimed(player, "GB_" .. item.Kind, "GBUntil_" .. item.Kind, item.Amount, now + duration, now)
		feedback(root, BUFF_COLOR[item.Kind] or Color3.fromRGB(200, 220, 255), "PetPulse")
	elseif e == "Heal" then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return false
		end
		if hum.Health >= hum.MaxHealth - 0.5 then
			Remotes.Hint:FireClient(player, "Your health is already full.", 2)
			return false
		end
		hum.Health = math.min(hum.MaxHealth, hum.Health + item.Amount)
		HitFx.Play("PetSporeMend", root.Position - Vector3.new(0, 2.5, 0), 0.9)
		Sfx.At("PetLevelUp", root.Position)
	elseif e == "ShieldNow" then
		player:SetAttribute("ShieldUntil", now + duration)
		local ff = Instance.new("ForceField") -- visible bubble
		ff.Name = "GearShield"
		ff.Parent = player.Character
		Debris:AddItem(ff, duration)
		Sfx.At("BaseLock", root.Position)
	elseif e == "Cleanse" then
		for _, attr in { "MonsterSlowUntil", "RootedUntil", "BurnUntil", "BlindUntil", "ShockedUntil", "LaserSlowUntil" } do
			player:SetAttribute(attr, 0)
		end
		feedback(root, Color3.fromRGB(240, 250, 255), "Spore")
	elseif e == "EggWarm" then
		if not d.Incubator then
			Remotes.Hint:FireClient(player, "No egg is incubating.", 2)
			return false
		end
		d.Incubator.ReadyAt -= item.Minutes * 60
		feedback(root, Color3.fromRGB(255, 170, 80), "HatchPulse")
		Remotes.Hint:FireClient(player, `Your egg hatches {item.Minutes} min sooner!`, 3)
	elseif e == "Recall" then
		if player:GetAttribute("Carrying") or player:GetAttribute("CarryingEgg") then
			Remotes.Hint:FireClient(player, "Can't recall while carrying a cloud or an egg.", 2)
			return false
		end
		local roofs = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Rooftops")
		local nest
		for _, roof in roofs and roofs:GetChildren() or {} do
			if roof:GetAttribute("OwnerUserId") == player.UserId then
				nest = roof:FindFirstChild("Nest", true)
			end
		end
		if not nest then
			return false
		end
		FxKit.Pillar(root.Position - Vector3.new(0, 3, 0), Color3.fromRGB(255, 140, 220), 30, 0.8)
		player.Character:PivotTo(CFrame.new(nest.Position + Vector3.new(0, 5, 4)))
		FxKit.Pillar(nest.Position, Color3.fromRGB(255, 140, 220), 30, 0.8)
		Sfx.At("OrbOffer", nest.Position)
	elseif e == "Dash" then
		if not Remotes.Grapple then
			return false
		end
		local dir = root.CFrame.LookVector
		if typeof(aim) == "Vector3" then
			local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
			if flat.Magnitude > 1 then
				dir = flat.Unit
			end
		end
		local to = dashTarget(player, root, Vector3.new(dir.X, 0, dir.Z).Unit, item.Distance)
		if not to then
			Remotes.Hint:FireClient(player, "No safe ground to dash to!", 2)
			return false
		end
		HitFx.Play("PlayerPunch", root.Position, 0.8, dir)
		Sfx.At("Wind", root.Position)
		Remotes.Grapple:FireClient(player, to)
	elseif e == "Blast" or e == "Freeze" then
		local hook = InventoryService.Hooks.MonsterBlast
		if not hook then
			return false
		end
		Sfx.At("PetLob", root.Position)
		throwBomb(player, root, aim, item, function(at)
			hook(player, at, item)
			local style = e == "Freeze" and "IceRing" or (item.Radius >= 20 and "Cindermaw") or BLAST_STYLE[item.Hit or ""] or "Fire"
			HitFx.Play(style, at, math.clamp(item.Radius / 14, 0.7, 1.6))
			Sfx.At(e == "Freeze" and "DeathIce" or ("Death" .. (BLAST_SFX[item.Hit or ""] or "Fire")), at)
		end)
	elseif e == "Laser" or e == "Grapple" then
		local used = e == "Laser" and fireLaser(player, root, aim) or (e == "Grapple" and fireGrapple(player, root, aim))
		if not used then
			return false
		end
		Sfx.At(e == "Laser" and "HitLaser" or "Wind", root.Position)
	end
	return true
end

-- gear that only buffs you: not while carrying a cloud (theft balance)
local BUFF_GEAR = { Speed = true, Jump = true, Nitro = true, Buff = true }

local function useItem(player: Player, id: unknown, aim: unknown)
	local d = data(player)
	local item = type(id) == "string" and ShopItems.Types[id]
	if not d or not item or item.ComingSoon or not owns(d, id :: string) then
		return
	end
	-- you must be HOLDING that gear
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if not held or held:GetAttribute("GearId") ~= id then
		return
	end
	local st = stateOf(player, id :: string)
	local t = workspace:GetServerTimeNow()
	rechargeTick(st, item, t)
	if item.Op then
		if st.Charges <= 0 then
			Remotes.Hint:FireClient(player, `Recharging... next charge in {math.ceil(st.NextAt - t)}s`, 2)
			return
		end
	elseif t < st.ReadyAt then
		Remotes.Hint:FireClient(player, `Ready in {math.ceil(st.ReadyAt - t)}s`, 1.5)
		return
	end
	if BUFF_GEAR[item.Effect] and player:GetAttribute("Carrying") then
		Remotes.Hint:FireClient(player, "Buff gear doesn't work while you carry a cloud!", 2.5)
		return
	end
	if not apply(player, d, item, aim) then
		return
	end
	if item.Op then
		if st.Charges >= item.MaxCharges then
			st.NextAt = t + item.Recharge
		end
		st.Charges -= 1
	else
		st.ReadyAt = t + item.Cooldown
	end
	refreshTool(player, id :: string)
end

-- refill OP charges over time (and tell the Tools)
task.spawn(function()
	while true do
		task.wait(1)
		local t = workspace:GetServerTimeNow()
		for player, list in gearState do
			if not player.Parent then
				gearState[player] = nil
			else
				for gid, st in list do
					local item = ShopItems.Types[gid]
					if item and rechargeTick(st, item, t) then
						refreshTool(player, gid)
					end
				end
			end
		end
	end
end)

------------------------------------------------------------------------
-- Death + regen
------------------------------------------------------------------------

-- QA spawner: give one item (any id, no coins, no lock)
function InventoryService.GiveItem(player: Player, id: string): boolean
	local d = data(player)
	if not d or not ShopItems.Types[id] then
		return false
	end
	d.Gear[id] = true -- v2.31: gear is owned
	giveTool(player, id)
	sync(player)
	return true
end

function InventoryService.Wipe(player: Player): (number, number)
	local d = data(player)
	if not d then
		return 0, 0
	end
	local lostItems, lostPerks = 0, #d.Perks -- v2.31: gear is kept on death
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
	-- v2.31: a random gear you don't own yet (simple gear only, no locked ones)
	local ids = {}
	for id, item in ShopItems.Types do
		if not item.ComingSoon and not item.Op and not item.Cloud and not d.Gear[id] then
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		return nil
	end
	table.sort(ids)
	local id = ids[math.random(1, #ids)]
	d.Gear[id] = true
	giveTool(player, id)
	sync(player)
	return ShopItems.Types[id].DisplayName or id
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
		task.delay(0.5, giveAllTools, player) -- v2.31 owned gear back in your hotbar
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
