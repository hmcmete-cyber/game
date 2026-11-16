-- Weather spheres: spawning, catching, carrying, vault storage, stealing,
-- world effects.
--
-- Wild weather floats inside glass spheres. Hold E to catch it: it sticks
-- above your head and you get a bit slower (speed + jump).
-- Bring it to your base: it drops into an empty Vault sphere, pays coins now
-- and keeps paying passive income while it stays in your vault.
-- Rivals can sneak onto your base and hold E on a full vault to steal it.
-- Carried clouds NEVER go into the inventory; dying destroys them.
-- Everyone sees "X stole Y's Storm!". If the owner touches the thief, the
-- storm flies back.
--
-- Weather effects while carrying:
--   Rain cloud      -> slippery puddles behind you
--   Pocket tornado  -> lifts nearby LiftPlatforms (shortcut)
--   Snow cloud      -> freezes nearby WaterGaps into bridges
--   Cumulonimbus    -> (key "Thunder") faster but glows for everyone
--   Combos: Snow near puddles = ice road, Tornado near puddles = launch pad
--
-- "Touch" is checked by distance every 0.1 s on the server. That's more
-- reliable than .Touched for anchored parts and fast-moving players.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Weather = require(ReplicatedStorage.Shared.WeatherTypes)
local CloudVisuals = require(script.Parent:WaitForChild("CloudVisuals"))
local BaseLock = require(script.Parent:WaitForChild("BaseLockService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))


local WeatherService = {}

local MapService, DataService, Remotes

local weatherFolder, wildFolder, puddleFolder
local stormPos: Vector3 = Vector3.zero

local wild = {} -- [Part] = { Type, Shiny, Spawn, Base, Phase, Spin, Ready }
local occupied = {} -- [spawn marker] = Part
local carriers = {} -- [Player] = { Type, Shiny, Part, Victim?, NextPuddle, LastPuddlePos, NextFlash }
local grabCooldown = {} -- [Player] = os.clock() when they may grab again
local puddleExpire = {} -- [Part] = os.clock() time
local liftState = {} -- [Part] = { Rest, Up, LastNear }
local gapState = {} -- [Part] = { CanCollide, Material, Color, Transparency, FrozenUntil, Frozen }
local lastAlarm = {} -- [Player owner] = os.clock()
local vaultGlow = {} -- [vault Part] = PointLight

local THIEF_COLOR = Color3.fromRGB(255, 60, 60)
local SPHERE_COLOR = Color3.fromRGB(200, 230, 255)

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function hint(player: Player, text: string, duration: number?)
	Remotes.Hint:FireClient(player, text, duration or 4)
end

local function hintAll(text: string, duration: number?)
	Remotes.Hint:FireAllClients(text, duration or 5)
end

local function getRoot(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return root, hum
	end
	return nil, nil
end

local function getNest(player: Player): BasePart?
	local roof = MapService.GetRooftop(player)
	return roof and roof:FindFirstChild("Nest")
end

-- Speed + jump. Carrying = slower and lower jumps.
local function setMovement(player: Player, speed: number, carrying: boolean)
	if carrying then
		speed += player:GetAttribute("CarryBonus") or 0 -- Aurelius "Strong Grip"
	end
	player:SetAttribute("BaseSpeed", speed)
	local _, hum = getRoot(player)
	if hum then
		hum.WalkSpeed = speed
		hum.JumpHeight = carrying and Config.CarryJumpHeight or 7.2
		hum.JumpPower = carrying and Config.CarryJumpPower or 50
	end
end

-- Outline visible through walls (thieves, thunder carriers)
local function setHighlight(player: Player, color: Color3?)
	local char = player.Character
	if not char then
		return
	end
	local h = char:FindFirstChild("CarryHighlight")
	if not color then
		if h then
			h:Destroy()
		end
		return
	end
	if not h then
		h = Instance.new("Highlight")
		h.Name = "CarryHighlight"
		h.FillTransparency = 0.65
		h.OutlineTransparency = 0
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = char
	end
	h.FillColor = color
	h.OutlineColor = color
end

-- Soft glowing burst + light flash, visible to everyone
local function burstAt(position: Vector3, color: Color3, count: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position

	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.9
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(8, 16)
	e.Drag = 4
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = anchor

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 4
	light.Range = 16
	light.Parent = anchor

	anchor.Parent = weatherFolder
	e:Emit(count)
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	Debris:AddItem(anchor, 2)
end

-- Day clouds spawn by day, night clouds only at night ("Any" = always)
local function timeOk(typeName: string): boolean
	return Weather.TimeOk(Weather.Types[typeName], workspace:GetAttribute("IsNight") == true)
end

local function weightedPick(weights: { [string]: number }): string?
	local total = 0
	for _, w in weights do
		total += w
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	for key, w in weights do
		roll -= w
		if roll <= 0 then
			return key
		end
	end
	return nil
end

-- 1) roll a rarity tier, 2) pick a cloud of that tier that lives in this
-- biome at this time of day (by Weight). Falls back to lower tiers.
local function rollCloud(biome: string, tierChances: { [string]: number }?, allowAltarOnly: boolean?): string?
	local chances = {}
	if tierChances then
		chances = tierChances
	else
		for name, r in Weather.Rarity do
			chances[name] = r.Chance
		end
	end
	local tier = weightedPick(chances) or "Common"
	local tierIndex = Weather.Rarity[tier].Tier
	for t = tierIndex, 1, -1 do
		local tierName = Weather.TierOrder[t]
		local pool = {}
		for _, key in Weather.Order do
			local def = Weather.Types[key]
			if def.Rarity == tierName and (allowAltarOnly or not def.AltarOnly)
				and Weather.InBiome(def, biome) and timeOk(key) then
				pool[key] = def.Weight
			end
		end
		local pick = weightedPick(pool)
		if pick then
			return pick
		end
	end
	return nil
end

-- Solar Flare perk etc.
local function coinMult(player: Player): number
	return player:GetAttribute("CoinMult") or 1
end

local function rewardOf(typeName: string, shiny: boolean): number
	return Weather.Types[typeName].Reward * (shiny and Weather.ShinyMultiplier or 1)
end

-- Cloud look lives in CloudVisuals.luau
local moveAssembly = CloudVisuals.Move
local function makeCore(typeName: string, shiny: boolean, scale: number): BasePart
	return CloudVisuals.Make(typeName, shiny, scale)
end

-- A cloud body: an invisible handle part (prompt, leash, physics) with the
-- visible puffy cloud welded to it. No glass sphere around it anymore.
local function makeSphere(typeName: string, shiny: boolean, scale: number): BasePart
	local def = Weather.Types[typeName]
	local shell = Instance.new("Part")
	shell.Name = typeName
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.one * def.Size * scale
	shell.Transparency = 1
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CastShadow = false
	shell:SetAttribute("WeatherType", typeName)
	shell:SetAttribute("Shiny", shiny)

	local core = makeCore(typeName, shiny, scale)
	moveAssembly(core, shell.CFrame)
	core.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = shell
	weld.Part1 = core
	weld.Parent = core
	core.Parent = shell
	return shell
end

local function addLabel(part: BasePart, text: string, color: Color3, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	gui.MaxDistance = maxDistance or 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

-- Tie a sphere to the player's LEFT hand with a rope. It floats behind them
-- like a balloon (AlignPosition), so the right hand stays free for items.
-- Returns the attachments made on the character (removed when dropped).
local function attachLeash(part: BasePart, player: Player, root: BasePart, color: Color3): { Instance }
	CollectionService:RemoveTag(part, "FloatingIsland")
	for _, child in part:GetChildren() do
		if child:IsA("ProximityPrompt") or child.Name == "Label" then
			child:Destroy()
		end
	end
	local char = root.Parent
	local hand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm") or root
	local grip = hand:FindFirstChild("LeftGripAttachment")

	-- light, non-colliding balloon
	local light = PhysicalProperties.new(0.05, 0.3, 0.5)
	for _, d in part:GetDescendants() do
		if d:IsA("BasePart") then
			d.CustomPhysicalProperties = light
		end
	end
	part.CustomPhysicalProperties = light
	part.Anchored = false
	part.Massless = false
	part.CanCollide = false
	part.CFrame = root.CFrame * CFrame.new(0, Config.LeashHeight, Config.LeashBack)

	local handAtt = Instance.new("Attachment")
	handAtt.Name = "LeashHand"
	handAtt.CFrame = grip and grip.CFrame or CFrame.new()
	handAtt.Parent = hand

	local target = Instance.new("Attachment")
	target.Name = "LeashTarget"
	target.Position = Vector3.new(0, Config.LeashHeight, Config.LeashBack)
	target.Parent = root

	local knot = Instance.new("Attachment")
	knot.Name = "LeashKnot"
	knot.Position = Vector3.new(0, -part.Size.Y / 2, 0)
	knot.Parent = part
	local centerAtt = Instance.new("Attachment")
	centerAtt.Name = "LeashCenter"
	centerAtt.Parent = part

	local rope = Instance.new("RopeConstraint")
	rope.Name = "Leash"
	rope.Attachment0 = handAtt
	rope.Attachment1 = knot
	rope.Length = Config.LeashLength
	rope.Visible = true
	rope.Thickness = 0.12
	rope.Color = BrickColor.new(color)
	rope.Parent = part

	local align = Instance.new("AlignPosition")
	align.Name = "Float"
	align.Mode = Enum.PositionAlignmentMode.TwoAttachment
	align.Attachment0 = centerAtt
	align.Attachment1 = target
	align.Responsiveness = Config.LeashResponsiveness
	align.MaxForce = 6000
	align.Parent = part

	part.Parent = weatherFolder
	pcall(function()
		part:SetNetworkOwner(player) -- smooth on the carrier's screen
	end)
	return { handAtt, target }
end

local function addCoins(player: Player, amount: number)
	local data = DataService.Get(player)
	if data then
		data.Coins += amount
	end
	DataService.Sync(player)
end

------------------------------------------------------------------------
-- Vaults
------------------------------------------------------------------------

-- data.Vault = array of { Type, Shiny } or false (empty), length VaultCount
local function getVaultData(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	if type(data.Vault) ~= "table" then
		data.Vault = {}
		-- migrate the old display list
		for i, entry in data.Recent or {} do
			if i <= Config.VaultCount then
				data.Vault[i] = entry
			end
		end
	end
	for i = 1, Config.VaultCount do
		if data.Vault[i] == nil then
			data.Vault[i] = false
		end
	end
	return data.Vault
end

-- E-key prompt. Role/OwnerUserId attributes let each client hide prompts
-- that aren't for them (owners don't see "Steal", rivals don't see "Equip Perk").
local function makePrompt(parent: Instance, name: string, action: string, object: string, hold: number, role: string?, ownerId: number?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	if role then
		prompt:SetAttribute("Role", role)
	end
	if ownerId then
		prompt:SetAttribute("OwnerUserId", ownerId)
	end
	prompt.Parent = parent
	return prompt
end

local onStealPrompt, onPerkPrompt -- defined further down

-- Empty spheres breathe softly; full spheres show their storm
local function renderVault(vault: BasePart, entry, owner: Player?)
	for _, name in { "StealPrompt", "PerkPrompt" } do
		local p = vault:FindFirstChild(name)
		if p then
			p:Destroy()
		end
	end
	local old = vault:FindFirstChild("Stored")
	if old then
		old:Destroy()
	end
	local oldLabel = vault:FindFirstChild("Label")
	if oldLabel then
		oldLabel:Destroy()
	end

	local glow = vaultGlow[vault]
	if not glow then
		glow = Instance.new("PointLight")
		glow.Name = "VaultGlow"
		glow.Range = 8
		glow.Parent = vault
		vaultGlow[vault] = glow
		local pulse = TweenService:Create(glow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Brightness = 1.6,
		})
		glow.Brightness = 0.4
		pulse:Play()
	end

	if entry and Weather.Types[entry.Type] then
		local def = Weather.Types[entry.Type]
		local core = makeCore(entry.Type, entry.Shiny == true, vault.Size.X / def.Size * 1.1)
		core.Name = "Stored"
		core.Anchored = false -- welded, so it follows the vault when clients float it
		moveAssembly(core, vault.CFrame)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = vault
		weld.Part1 = core
		weld.Parent = core
		core.Parent = vault
		vault.Transparency = 0.45
		vault.Color = entry.Shiny and Weather.ShinyColor or def.Color:Lerp(Color3.new(1, 1, 1), 0.5)
		glow.Color = entry.Shiny and Weather.ShinyColor or def.ParticleColor
		local perTick = math.max(1, math.floor(rewardOf(entry.Type, entry.Shiny) * Config.VaultIncomeRate))
		addLabel(vault, `{entry.Shiny and "* " or ""}{def.DisplayName}  +{perTick}/{Config.VaultIncomeInterval}s`,
			entry.Shiny and Weather.ShinyColor or Color3.new(1, 1, 1), 50)

		if owner then
			local steal = makePrompt(vault, "StealPrompt", "Steal", def.DisplayName,
				workspace:GetAttribute("Event") == "Fog" and Config.FogStealHold or Config.StealHold, "Steal", owner.UserId)
			steal.Triggered:Connect(function(player)
				onStealPrompt(player, owner, vault)
			end)
			if def.Perk then
				local perk = makePrompt(vault, "PerkPrompt", `Equip Perk: {def.Perk.Name}`, def.Perk.Desc,
					Config.PerkHold, "Perk", owner.UserId)
				perk.UIOffset = Vector2.new(0, 60)
				perk.KeyboardKeyCode = Enum.KeyCode.F
				perk.Triggered:Connect(function(player)
					onPerkPrompt(player, owner, vault)
				end)
			end
		end
	else
		vault.Transparency = 0.6
		vault.Color = SPHERE_COLOR
		glow.Color = SPHERE_COLOR
	end
end

local function refreshVaults(player: Player)
	local roof = MapService.GetRooftop(player)
	local slots = getVaultData(player)
	if not roof or not slots then
		return
	end
	local vaults = MapService.GetVaults(roof)
	local filled = 0
	for i, vault in vaults do
		vault:SetAttribute("Slot", i)
		renderVault(vault, slots[i], player)
		if slots[i] then
			filled += 1
		end
	end
	-- for the status panel (top-right)
	player:SetAttribute("VaultFilled", filled)
	player:SetAttribute("VaultSize", #vaults)
end

local function clearVaultVisuals(player: Player)
	local roof = MapService.GetRooftop(player)
	if not roof then
		return
	end
	for _, vault in MapService.GetVaults(roof) do
		renderVault(vault, nil)
	end
end

-- Put a storm into the first empty vault. Returns slot index or nil if full.
local function storeInVault(player: Player, typeName: string, shiny: boolean)
	local slots = getVaultData(player)
	if not slots then
		return nil
	end
	for i = 1, Config.VaultCount do
		if not slots[i] then
			slots[i] = { Type = typeName, Shiny = shiny }
			return i
		end
	end
	return nil
end

local function alarm(owner: Player, thief: Player)
	local now = os.clock()
	if lastAlarm[owner] and now - lastAlarm[owner] < Config.AlarmCooldown then
		return
	end
	lastAlarm[owner] = now
	Remotes.Alarm:FireClient(owner, thief.DisplayName)

	-- Red flashing light on the base, visible to everyone
	local nest = getNest(owner)
	if nest then
		local light = Instance.new("PointLight")
		light.Color = THIEF_COLOR
		light.Range = 30
		light.Brightness = 0
		light.Parent = nest
		task.spawn(function()
			for _ = 1, 3 do
				light.Brightness = 6
				task.wait(0.25)
				light.Brightness = 0
				task.wait(0.25)
			end
			light:Destroy()
		end)
	end
end

------------------------------------------------------------------------
-- Carrying
------------------------------------------------------------------------

local function startCarry(player: Player, root: BasePart, sphere: BasePart, typeName: string, shiny: boolean, victim: Player?)
	local ropeColor = victim and THIEF_COLOR or (shiny and Weather.ShinyColor or Weather.RarityOf(typeName).Color)
	local attachments = attachLeash(sphere, player, root, ropeColor)
	carriers[player] = {
		Attachments = attachments,
		Type = typeName,
		Shiny = shiny,
		Part = sphere,
		Victim = victim,
		NextPuddle = 0,
		LastPuddlePos = nil,
		NextFlash = 0,
	}
	player:SetAttribute("Carrying", typeName)
	player:SetAttribute("CarryingStolen", victim ~= nil)

	if typeName == "Thunder" then
		setMovement(player, Config.ThunderCarrySpeed, true)
	else
		setMovement(player, Config.CarrySpeed, true)
	end
	if victim then
		setHighlight(player, THIEF_COLOR)
	elseif typeName == "Thunder" then
		setHighlight(player, Weather.Types.Thunder.ParticleColor)
	end
end

-- sendBack: a stolen storm that is dropped returns to its victim's vault
local function clearCarry(player: Player, sendBack: boolean?)
	local c = carriers[player]
	if not c then
		return nil
	end
	carriers[player] = nil
	grabCooldown[player] = os.clock() + Config.GrabCooldown
	player:SetAttribute("Carrying", nil)
	player:SetAttribute("CarryingStolen", nil)
	setHighlight(player, nil)
	if c.Part then
		c.Part:Destroy()
	end
	for _, att in c.Attachments or {} do
		att:Destroy()
	end
	setMovement(player, Config.WalkSpeed, false)
	if sendBack and c.Victim and c.Victim.Parent then
		if storeInVault(c.Victim, c.Type, c.Shiny) then
			refreshVaults(c.Victim)
		end
	end
	return c
end

local function deliver(player: Player, c, nest: BasePart)
	local def = Weather.Types[c.Type]
	local reward = math.floor(rewardOf(c.Type, c.Shiny) * coinMult(player))
	local data = DataService.Get(player)
	if data then
		data.Delivered += 1
		local key = c.Shiny and (c.Type .. "_Shiny") or c.Type
		data.Collection[key] = (data.Collection[key] or 0) + 1
	end

	local slot = storeInVault(player, c.Type, c.Shiny)
	if slot then
		addCoins(player, reward)
		refreshVaults(player)
		local vault = MapService.GetVaults(MapService.GetRooftop(player))[slot]
		if vault then
			-- clients play the "cloud flies into the sphere" flash
			local root = getRoot(player)
			vault:SetAttribute("PulseFrom", root and (root.Position + Vector3.new(0, 4.5, 0)) or nest.Position)
			vault:SetAttribute("PulseColor", c.Shiny and Weather.ShinyColor or def.ParticleColor)
			vault:SetAttribute("Pulse", os.clock())
		end
		burstAt(vault and vault.Position or nest.Position, c.Shiny and Weather.ShinyColor or def.Color, c.Shiny and 80 or 40)
		hint(player, c.Victim and `Heist complete! {def.DisplayName} is yours now `
			or `{def.DisplayName} stored in your vault — it earns coins while it stays!`, 3)
	else
		-- Vault full: sell it for double
		reward *= 2
		addCoins(player, reward)
		burstAt(nest.Position + Vector3.new(0, 2, 0), Weather.ShinyColor, 40)
		hint(player, `Vault full — sold {def.DisplayName} for {reward} coins!`, 3)
	end
	-- XP + Economic cloud bonuses
	local levelUp = DataService.AddXP(player, def.XP * (c.Shiny and 2 or 1))
	if levelUp then
		hint(player, `LEVEL UP! You are now level {levelUp}`, 4)
	end
	if def.ItemChance > 0 and math.random() < def.ItemChance then
		local itemId = InventoryService.GiveRandomItem(player)
		if itemId then
			hint(player, `Bonus drop from {def.DisplayName}: {itemId}!`, 3)
		end
	end
	Remotes.Delivered:FireClient(player, reward, c.Type, c.Shiny, nest.Position)
end

local function catch(player: Player, sphere: BasePart)
	local info = wild[sphere]
	if not info or not info.Ready or carriers[player] then
		return
	end
	local root = getRoot(player)
	if not root then
		return
	end
	wild[sphere] = nil
	if info.Spawn then
		occupied[info.Spawn] = nil
	end

	local def = Weather.Types[info.Type]
	burstAt(sphere.Position, info.Shiny and Weather.ShinyColor or def.Color, 25)
	sphere.Size *= 0.75
	startCarry(player, root, sphere, info.Type, info.Shiny, nil)

	hint(player, `You caught a {def.DisplayName}! Bring it to your base — follow the beam`, 5)
	if info.Type == "Mythic" then
		hintAll(`{player.DisplayName} CAUGHT THE MYTHIC STORM CLOUD!`, 8)
	elseif def.Tier >= 3 then
		hintAll(`{player.DisplayName} has a {string.upper(def.DisplayName)}!`, 4)
	end
	if info.Shiny then
		hintAll(`* {player.DisplayName} caught a SHINY {def.DisplayName}! *`, 6)
	end
end

local function steal(thief: Player, root: BasePart, owner: Player, slot: number, vault: BasePart)
	local slots = getVaultData(owner)
	local entry = slots and slots[slot]
	if not entry then
		return
	end
	slots[slot] = false
	refreshVaults(owner)

	local def = Weather.Types[entry.Type]
	local sphere = makeSphere(entry.Type, entry.Shiny == true, 0.75)
	moveAssembly(sphere, vault.CFrame)
	sphere.Parent = weatherFolder
	burstAt(vault.Position, THIEF_COLOR, 30)
	startCarry(thief, root, sphere, entry.Type, entry.Shiny == true, owner)

	alarm(owner, thief)
	Remotes.Stolen:FireAllClients(thief.DisplayName, owner.DisplayName, def.DisplayName)
	hint(thief, `You stole {owner.DisplayName}'s {def.DisplayName}! Run home — if they tag you, it flies back!`, 5)
end

-- Rival holds E on a full vault
onStealPrompt = function(player: Player, owner: Player, vault: BasePart)
	if player == owner or carriers[player] or not owner.Parent then
		return
	end
	local roof = MapService.GetRooftop(owner)
	if not roof or not vault:IsDescendantOf(roof) then
		return
	end
	if BaseLock.IsLocked(roof) then
		hint(player, "This base is shielded!", 2)
		return
	end
	local root = getRoot(player)
	if root then
		steal(player, root, owner, vault:GetAttribute("Slot") or 1, vault)
	end
end

-- Owner holds F on their own vault: the cloud moves into the Quirks/Perks
-- inventory and its perk turns on. Risk: dying destroys it.
onPerkPrompt = function(player: Player, owner: Player, vault: BasePart)
	if player ~= owner then
		return
	end
	local slots = getVaultData(owner)
	local slot = vault:GetAttribute("Slot") or 1
	local entry = slots and slots[slot]
	local def = entry and Weather.Types[entry.Type]
	if not def or not def.Perk then
		return
	end
	if not InventoryService.EquipPerk(player, entry.Type, entry.Shiny == true) then
		hint(player, `Perk slots full ({Config.PerkSlots}) — return one to your vault first`, 3)
		return
	end
	slots[slot] = false
	refreshVaults(owner)
	burstAt(vault.Position, def.ParticleColor, 30)
	hint(player, `* {def.Perk.Name} active — {def.Perk.Desc}. If you die, this cloud is GONE!`, 5)
end

-- Perks inventory -> back into the vault (called by InventoryService)
local function returnToVault(player: Player, typeName: string, shiny: boolean): boolean
	if not storeInVault(player, typeName, shiny) then
		return false
	end
	refreshVaults(player)
	return true
end

------------------------------------------------------------------------
-- Storm cloud + wild spawning
------------------------------------------------------------------------

local function setupStorm()
	local hunt = workspace.Map.HuntZone
	local existing = hunt:FindFirstChild("StormCloud")
	if existing then
		stormPos = existing:IsA("BasePart") and existing.Position or existing:GetPivot().Position
		return
	end

	-- No storm in the map: place a visual one above the spawn points
	-- Hover over the Mountains biome if the map has one
	local spawns = {}
	for _, sp in MapService.GetSpawns() do
		if sp:GetAttribute("Biome") == "Mountains" then
			table.insert(spawns, sp)
		end
	end
	if #spawns == 0 then
		spawns = MapService.GetSpawns()
	end
	local sum = Vector3.zero
	for _, s in spawns do
		sum += s.Position
	end
	local center = #spawns > 0 and sum / #spawns or Vector3.new(0, 40, 0)
	stormPos = center + Vector3.new(0, Config.StormHeight, 0)

	local storm = Instance.new("Model")
	storm.Name = "StormCloud"
	local puffs = {
		{ Vector3.new(0, 0, 0), 16 },
		{ Vector3.new(9, -1, 3), 12 },
		{ Vector3.new(-9, -1, -2), 12 },
		{ Vector3.new(3, 3, -7), 11 },
		{ Vector3.new(-4, 2, 7), 10 },
	}
	for i, puff in puffs do
		local p = Instance.new("Part")
		p.Name = "Puff" .. i
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * puff[2]
		p.Position = stormPos + puff[1]
		p.Color = Color3.fromRGB(85, 90, 115)
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = storm
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 220, 255)
	light.Range = 40
	light.Brightness = 0
	light.Parent = storm:FindFirstChild("Puff1")
	CollectionService:AddTag(storm:FindFirstChild("Puff1"), "LightningCloud") -- clients add arcs
	storm.Parent = weatherFolder

	-- Occasional lightning flicker inside the storm
	task.spawn(function()
		while storm.Parent do
			task.wait(2 + math.random() * 4)
			for _ = 1, math.random(1, 3) do
				light.Brightness = 8
				task.wait(0.06)
				light.Brightness = 0
				task.wait(0.08)
			end
		end
	end)
end

local function spawnWild(spawnPart: BasePart, typeName: string, shiny: boolean, fromPos: Vector3?)
	local def = Weather.Types[typeName]
	local sphere = makeSphere(typeName, shiny, 1)
	local base = spawnPart.Position + Vector3.new(0, 1.5, 0)
	moveAssembly(sphere, CFrame.new(fromPos or stormPos)) -- born inside the storm (or a meteor)
	addLabel(sphere, shiny and `* SHINY {def.DisplayName} *` or def.DisplayName, shiny and Weather.ShinyColor or Color3.new(1, 1, 1))
	local prompt = makePrompt(sphere, "CatchPrompt", "Catch", def.DisplayName,
		typeName == "Mythic" and Config.MythicCatchHold or Config.CatchHold)
	prompt.Enabled = false -- until it lands
	prompt:SetAttribute("Ready", false)
	prompt.Triggered:Connect(function(player)
		catch(player, sphere)
	end)
	sphere.Parent = wildFolder

	local info = {
		Type = typeName,
		Shiny = shiny,
		Spawn = spawnPart,
		Base = base,
		Phase = math.random() * math.pi * 2,
		Spin = def.Spin,
		Ready = false,
	}
	wild[sphere] = info
	occupied[spawnPart] = sphere

	-- Fly from the storm down to its spot
	local tween = TweenService:Create(sphere, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(base),
	})
	tween.Completed:Connect(function()
		if wild[sphere] then
			info.Ready = true
			prompt:SetAttribute("Ready", true)
			prompt.Enabled = true
			burstAt(base, shiny and Weather.ShinyColor or def.Color, 12)
			-- clients make it bob and spin (see FloatingIslands.luau)
			sphere:SetAttribute("FloatAmplitude", 0.8)
			sphere:SetAttribute("FloatSpeed", 2)
			sphere:SetAttribute("FloatSpin", def.Spin)
			CollectionService:AddTag(sphere, "FloatingIsland")
		end
	end)
	tween:Play()
end

local function countWild()
	local n = 0
	for _ in wild do
		n += 1
	end
	return n
end

local function freeSpawns()
	local list = {}
	for _, spawnPart in MapService.GetSpawns() do
		local current = occupied[spawnPart]
		if current and not current.Parent then
			occupied[spawnPart] = nil
			current = nil
		end
		if not current then
			table.insert(list, spawnPart)
		end
	end
	return list
end

-- World events (EventService): drop a cloud of the given tiers on a spawn.
-- Returns the cloud key, or nil if the spot is taken / nothing fits.
function WeatherService.SpawnEventCloud(spawnPart: BasePart, tierChances: { [string]: number }, fromPos: Vector3?): string?
	local current = occupied[spawnPart]
	if current and current.Parent then
		return nil
	end
	local typeName = rollCloud(spawnPart:GetAttribute("Biome") or "Plateau", tierChances)
	if typeName then
		spawnWild(spawnPart, typeName, math.random() < Weather.ShinyChance, fromPos)
	end
	return typeName
end

-- Wild clouds that don't belong to the current time of day fade away
local function despawnOutOfTime()
	for sphere, info in wild do
		if info.Ready and not timeOk(info.Type) then
			wild[sphere] = nil
			if info.Spawn then
				occupied[info.Spawn] = nil
			end
			burstAt(sphere.Position, Weather.Types[info.Type].ParticleColor, 20)
			sphere:Destroy()
		end
	end
end

local function spawnLoop()
	local wasNight = workspace:GetAttribute("IsNight")
	while true do
		local night = workspace:GetAttribute("IsNight")
		if night ~= wasNight then
			wasNight = night
			despawnOutOfTime()
			hintAll(night and "Night falls... night clouds are out!" or "The sun rises - day clouds are back!", 5)
		end

		if countWild() < Config.MaxWild then
			local spots = freeSpawns()
			if #spots > 0 then
				local spot = spots[math.random(1, #spots)]
				local typeName = rollCloud(spot:GetAttribute("Biome") or "Plateau")
				if typeName then
					spawnWild(spot, typeName, math.random() < Weather.ShinyChance)
					local def = Weather.Types[typeName]
					if def.Tier >= 4 then
						hintAll(`A {string.upper(def.Rarity)} {def.DisplayName} appeared in the {spot:GetAttribute("Biome") or "sky"}!`, 5)
					end
				end
			end
		end
		task.wait(Config.SpawnInterval)
	end
end

-- Cloud Altars: every AltarInterval, an empty altar raises a rare cloud.
-- 0.01% of the time it's the Mythic Storm Cloud.
local function altarLoop()
	while true do
		task.wait(Config.AltarInterval)
		for _, altar in MapService.GetAltars() do
			if occupied[altar] and occupied[altar].Parent then
				continue
			end
			local mythic = math.random() < Config.MythicChance
			local typeName = mythic and "Mythic"
				or rollCloud(altar:GetAttribute("Biome") or "Plateau", Weather.AltarTiers)
				or "Chrono"
			spawnWild(altar, typeName, not mythic and math.random() < Weather.ShinyChance * 5)
			burstAt(altar.Position, Weather.Types[typeName].ParticleColor, 60)
			if mythic then
				hintAll("A MYTHIC STORM CLOUD has appeared at a Cloud Altar!", 10)
			else
				hintAll(`* A {Weather.Types[typeName].DisplayName} rose from a Cloud Altar!`, 5)
			end
		end
	end
end

local function incomeLoop()
	while true do
		task.wait(Config.VaultIncomeInterval)
		for _, player in game:GetService("Players"):GetPlayers() do
			local slots = getVaultData(player)
			if slots then
				local total = 0
				for i = 1, Config.VaultCount do
					local entry = slots[i]
					if entry and Weather.Types[entry.Type] then
						total += math.max(1, math.floor(rewardOf(entry.Type, entry.Shiny == true) * Config.VaultIncomeRate))
					end
				end
				total = math.floor(total * (player:GetAttribute("IncomeMult") or 1) * coinMult(player))
				if total > 0 then
					addCoins(player, total)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- World effects
------------------------------------------------------------------------

local function stylePuddle(p: BasePart, kind: string)
	p:SetAttribute("Kind", kind)
	if kind == "Slip" then
		p.Color = Color3.fromRGB(70, 140, 230)
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.35
	elseif kind == "Ice" then
		p.Color = Color3.fromRGB(205, 235, 255)
		p.Material = Enum.Material.Ice
		p.Transparency = 0.1
	elseif kind == "Launch" then
		p.Color = Color3.fromRGB(120, 255, 230)
		p.Material = Enum.Material.Neon
		p.Transparency = 0.2
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function spawnPuddle(player: Player, c, root: BasePart, now: number)
	if now < c.NextPuddle then
		return
	end
	c.NextPuddle = now + Config.PuddleInterval

	rayParams.FilterDescendantsInstances = { player.Character, weatherFolder }
	local result = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), rayParams)
	if not result then
		return -- in the air
	end
	local pos = result.Position
	if c.LastPuddlePos and (pos - c.LastPuddlePos).Magnitude < Config.PuddleMinDistance then
		return
	end
	c.LastPuddlePos = pos

	local p = Instance.new("Part")
	p.Name = "Puddle"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.2, 6, 6)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true -- the client detects puddles with an overlap query
	p:SetAttribute("OwnerUserId", player.UserId)
	p:SetAttribute("CreatedAt", workspace:GetServerTimeNow())
	stylePuddle(p, "Slip")
	p.Parent = puddleFolder
	puddleExpire[p] = now + Config.PuddleLifetime
end

local function horizontalDistance(a: Vector3, b: Vector3)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function updateWorld(now: number)
	local tornadoes, snows = {}, {}
	for player, c in carriers do
		local root = getRoot(player)
		if root then
			if c.Type == "Tornado" then
				table.insert(tornadoes, root.Position)
			elseif c.Type == "Snow" then
				table.insert(snows, root.Position)
			end
		end
	end

	-- Lift platforms (Tornado)
	for _, plat in MapService.GetLiftPlatforms() do
		local st = liftState[plat]
		if not st then
			st = { Rest = plat.CFrame, Up = false, LastNear = 0 }
			liftState[plat] = st
		end
		local near = false
		for _, pos in tornadoes do
			if horizontalDistance(pos, st.Rest.Position) <= Config.LiftRange then
				near = true
				break
			end
		end
		if near then
			st.LastNear = now
			if not st.Up then
				st.Up = true
				TweenService:Create(plat, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					CFrame = st.Rest + Vector3.new(0, Config.LiftHeight, 0),
				}):Play()
			end
		elseif st.Up and now - st.LastNear > Config.LiftHold then
			st.Up = false
			TweenService:Create(plat, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = st.Rest,
			}):Play()
		end
	end

	-- Water gaps (Snow)
	for _, gap in MapService.GetWaterGaps() do
		local st = gapState[gap]
		if not st then
			st = {
				CanCollide = gap.CanCollide,
				Material = gap.Material,
				Color = gap.Color,
				Transparency = gap.Transparency,
				FrozenUntil = 0,
				Frozen = false,
			}
			gapState[gap] = st
		end
		for _, pos in snows do
			if horizontalDistance(pos, gap.Position) <= Config.FreezeRange + math.max(gap.Size.X, gap.Size.Z) / 2 then
				st.FrozenUntil = now + Config.FreezeDuration
				break
			end
		end
		if now < st.FrozenUntil and not st.Frozen then
			st.Frozen = true
			gap.CanCollide = true
			gap.Material = Enum.Material.Ice
			gap.Color = Color3.fromRGB(200, 230, 255)
			gap.Transparency = 0.05
		elseif now >= st.FrozenUntil and st.Frozen then
			st.Frozen = false
			gap.CanCollide = st.CanCollide
			gap.Material = st.Material
			gap.Color = st.Color
			gap.Transparency = st.Transparency
		end
	end

	-- Puddles: expire + combos
	for p, expires in puddleExpire do
		if now >= expires or not p.Parent then
			puddleExpire[p] = nil
			p:Destroy()
			continue
		end
		if p:GetAttribute("Kind") == "Slip" then
			for _, pos in snows do
				if (pos - p.Position).Magnitude <= Config.FreezeRange then
					stylePuddle(p, "Ice")
					puddleExpire[p] = now + Config.IceLifetime
					break
				end
			end
		end
		if p:GetAttribute("Kind") == "Slip" then
			for _, pos in tornadoes do
				if (pos - p.Position).Magnitude <= Config.LiftRange / 2 then
					stylePuddle(p, "Launch")
					break
				end
			end
		end
	end
end

local function mainLoop()
	local Players = game:GetService("Players")
	while true do
		task.wait(0.1)
		local now = os.clock()

		local roots = {}
		for _, player in Players:GetPlayers() do
			local root = getRoot(player)
			if root then
				roots[player] = root
			end
		end

		-- Carriers: tag-back, delivery, weather effects
		for player, c in carriers do
			local root = roots[player]
			if not root or not c.Part or not c.Part.Parent then
				clearCarry(player, false)
				continue
			end

			if c.Victim then
				local victimRoot = roots[c.Victim]
				local shielded = (player:GetAttribute("ShieldUntil") or 0) > workspace:GetServerTimeNow()
				if victimRoot and not shielded and (victimRoot.Position - root.Position).Magnitude <= Config.TagRadius then
					burstAt(root.Position + Vector3.new(0, 3, 0), THIEF_COLOR, 30)
					local victim = c.Victim
					clearCarry(player, true)
					hint(player, `{victim.DisplayName} caught you! The storm flew back.`, 4)
					hint(victim, `You caught {player.DisplayName}! Storm recovered`, 4)
					continue
				end
			end

			local nest = getNest(player)
			if nest and (root.Position - nest.Position).Magnitude <= Config.DeliverRadius then
				local delivered = clearCarry(player, false)
				if delivered then
					deliver(player, delivered, nest)
				end
				continue
			end

			if c.Type == "Rain" then
				spawnPuddle(player, c, root, now)
			elseif c.Type == "Thunder" and now >= (c.NextFlash or 0) then
				c.NextFlash = now + Config.ThunderFlashInterval
				burstAt(root.Position + Vector3.new(0, 6, 0), Weather.Types.Thunder.ParticleColor, 15)
			end
		end

		-- Alarm when a rival walks onto a base with a full vault
		for _, owner in Players:GetPlayers() do
			local roof = MapService.GetRooftop(owner)
			local nest = roof and not BaseLock.IsLocked(roof) and getNest(owner)
			local slots = nest and getVaultData(owner)
			local hasLoot = false
			for i = 1, Config.VaultCount do
				if slots and slots[i] then
					hasLoot = true
					break
				end
			end
			if hasLoot then
				for player, root in roots do
					if player ~= owner and (root.Position - nest.Position).Magnitude <= Config.IntruderRadius then
						alarm(owner, player)
					end
				end
			end
		end

		updateWorld(now)
	end
end

------------------------------------------------------------------------
-- Players
------------------------------------------------------------------------

function WeatherService.OnPlayerAdded(player: Player)
	player:SetAttribute("BaseSpeed", Config.WalkSpeed)
	refreshVaults(player)

	local function onCharacter(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		-- (re)spawn at your own base, not on the hub
		task.defer(function()
			local nest = getNest(player)
			if nest and char.Parent then
				local target = nest.Position + Vector3.new(0, 4, 0)
				pcall(function()
					player:RequestStreamAroundAsync(target, 5) -- StreamingEnabled: load the base first
				end)
				char:PivotTo(CFrame.new(target))
			end
		end)
		hum.WalkSpeed = Config.WalkSpeed
		player:SetAttribute("BaseSpeed", Config.WalkSpeed)
		hum.Died:Connect(function()
			clearCarry(player, false) -- dying destroys the carried cloud
		end)
		task.delay(1.5, function()
			if carriers[player] then
				return
			end
			local data = DataService.Get(player)
			if data and data.Delivered == 0 then
				hint(player, "Jump into the UPDRAFT in the middle of the hub to reach the clouds!", 8)
			else
				hint(player, "Catch storms, fill your vaults, raid other bases!", 5)
			end
		end)
	end

	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(function()
		clearCarry(player, false)
	end)
end

-- Call BEFORE the rooftop is released
function WeatherService.OnPlayerRemoving(player: Player)
	clearCarry(player, true)
	clearVaultVisuals(player)
	lastAlarm[player] = nil
	grabCooldown[player] = nil
	-- thieves carrying this player's storms just keep them
	for _, c in carriers do
		if c.Victim == player then
			c.Victim = nil
		end
	end
end

function WeatherService.Start(mapService, dataService, remotes)
	MapService = mapService
	DataService = dataService
	Remotes = remotes

	weatherFolder = Instance.new("Folder")
	weatherFolder.Name = "Weather"
	wildFolder = Instance.new("Folder")
	wildFolder.Name = "Wild"
	wildFolder.Parent = weatherFolder
	puddleFolder = Instance.new("Folder")
	puddleFolder.Name = "Puddles"
	puddleFolder.Parent = weatherFolder
	weatherFolder.Parent = workspace

	InventoryService.ReturnToVault = returnToVault
	-- Laser Gun: a thief hit by the cloud's owner drops it and it flies home
	InventoryService.Hooks.LaserHit = function(shooter: Player, target: Player): boolean
		local c = carriers[target]
		if not c or c.Victim ~= shooter then
			return false
		end
		local pos = c.Part and c.Part.Position
		clearCarry(target, true)
		if pos then
			burstAt(pos, THIEF_COLOR, 35)
		end
		hint(target, `{shooter.DisplayName} lasered you - the cloud flew back home!`, 4)
		hint(shooter, "Direct hit! Your cloud is back in your vault.", 4)
		return true
	end
	setupStorm()
	task.spawn(spawnLoop)
	task.spawn(mainLoop)
	task.spawn(incomeLoop)
	task.spawn(altarLoop)
end

return WeatherService
