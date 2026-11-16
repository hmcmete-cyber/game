-- Weather creatures + Storm Crystals: spawning, catching, carrying, stealing,
-- world effects, delivery.
--
-- Rain cloud      -> leaves slippery puddles behind you
-- Pocket tornado  -> lifts nearby LiftPlatforms (shortcut)
-- Snow cloud      -> freezes nearby WaterGaps into bridges
-- Thunder cloud   -> rarest; you run faster but glow for everyone
-- Combos: Snow near puddles = ice road (speed), Tornado near puddles = launch pad
--
-- Storm Crystals: creatures on your display produce crystals around your Nest.
-- Rivals can grab them (alarm!) and run them to their own Nest. If the owner
-- touches the thief, the crystal goes back. Your display collection is never
-- stealable.
--
-- Movement effects (slip / ice / launch) are applied by the client, which
-- reads the puddle attributes. The server owns everything else.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Weather = require(ReplicatedStorage.Shared.WeatherTypes)

local WeatherService = {}

local MapService, DataService, Remotes

local weatherFolder, wildFolder, puddleFolder, crystalFolder
local stormPos: Vector3 = Vector3.zero

local wild = {} -- [Part] = { Type, Shiny, Spawn, Base, Phase, Spin, Ready }
local occupied = {} -- [spawn marker] = Part
local carriers = {} -- [Player] = { Kind = "Weather"|"Crystal", Type, Shiny, Value, Victim, Part, NextPuddle, LastPuddlePos, NextFlash }
local crystals = {} -- [Player owner] = { [Part] = true }
local crystalInfo = {} -- [Part] = { Owner, Value, Base }
local puddleExpire = {} -- [Part] = os.clock() time
local liftState = {} -- [Part] = { Rest, Up, LastNear }
local gapState = {} -- [Part] = { CanCollide, Material, Color, Transparency, FrozenUntil, Frozen }
local lastAlarm = {} -- [Player owner] = os.clock()

local CRYSTAL_COLOR = Color3.fromRGB(120, 225, 255)
local THIEF_COLOR = Color3.fromRGB(255, 60, 60)

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

local function setSpeed(player: Player, speed: number)
	player:SetAttribute("BaseSpeed", speed)
	local _, hum = getRoot(player)
	if hum then
		hum.WalkSpeed = speed
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

local function rollType(): string
	local total = 0
	for _, name in Weather.Order do
		total += Weather.Types[name].Weight
	end
	local roll = math.random() * total
	for _, name in Weather.Order do
		roll -= Weather.Types[name].Weight
		if roll <= 0 then
			return name
		end
	end
	return Weather.Order[1]
end

local function makeCreature(typeName: string, shiny: boolean, scale: number): BasePart
	local def = Weather.Types[typeName]
	local p = Instance.new("Part")
	p.Name = typeName
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * def.Size * scale
	p.Color = shiny and Weather.ShinyColor or def.Color
	p.Material = shiny and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p:SetAttribute("WeatherType", typeName)
	p:SetAttribute("Shiny", shiny)

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(shiny and Weather.ShinyColor or def.ParticleColor)
	particles.Acceleration = def.ParticleAcceleration
	particles.Rate = shiny and 30 or 15
	particles.Lifetime = NumberRange.new(0.6, 1.2)
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new(0.35 * scale)
	particles.LightEmission = shiny and 1 or 0.3
	particles.Parent = p

	if typeName == "Thunder" or shiny then
		local light = Instance.new("PointLight")
		light.Color = shiny and Weather.ShinyColor or def.ParticleColor
		light.Brightness = 2
		light.Range = 10 * scale
		light.Parent = p
	end

	return p
end

local function addLabel(part: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	gui.MaxDistance = 80
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

-- Weld a part above the player's head
local function attachOverhead(part: BasePart, root: BasePart, height: number)
	for _, child in part:GetChildren() do
		if child:IsA("ProximityPrompt") or child.Name == "Label" then
			child:Destroy()
		end
	end
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CFrame = root.CFrame * CFrame.new(0, height, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = root.Parent
end

------------------------------------------------------------------------
-- Display (safe collection)
------------------------------------------------------------------------

local function refreshDisplay(player: Player)
	local roof = MapService.GetRooftop(player)
	local data = DataService.Get(player)
	if not roof or not data then
		return
	end
	for i, slot in MapService.GetSlots(roof) do
		local old = slot:FindFirstChild("Shown")
		if old then
			old:Destroy()
		end
		local entry = data.Recent[i]
		if entry and Weather.Types[entry.Type] then
			local mini = makeCreature(entry.Type, entry.Shiny == true, 0.5)
			mini.Name = "Shown"
			mini.CFrame = slot.CFrame * CFrame.new(0, slot.Size.Y / 2 + mini.Size.Y / 2 + 0.3, 0)
			mini.Parent = slot
		end
	end
end

local function addCoins(player: Player, amount: number)
	local data = DataService.Get(player)
	if data then
		data.Coins += amount
	end
	DataService.Sync(player)
end

------------------------------------------------------------------------
-- Storm Crystals
------------------------------------------------------------------------

local createCrystal -- forward declaration

local function crystalCount(owner: Player): number
	local n = 0
	for _ in crystals[owner] or {} do
		n += 1
	end
	return n
end

-- Arrange an owner's crystals in a ring around their Nest
local function layoutCrystals(owner: Player)
	local nest = getNest(owner)
	local set = crystals[owner]
	if not nest or not set then
		return
	end
	local list = {}
	for part in set do
		table.insert(list, part)
	end
	for i, part in list do
		local angle = (i / #list) * math.pi * 2
		local pos = nest.Position + Vector3.new(math.cos(angle) * 4.5, 2.2, math.sin(angle) * 4.5)
		crystalInfo[part].Base = pos
		part.CFrame = CFrame.new(pos)
	end
end

local function removeCrystal(part: BasePart)
	local info = crystalInfo[part]
	if info and crystals[info.Owner] then
		crystals[info.Owner][part] = nil
	end
	crystalInfo[part] = nil
end

local function bankCrystals(owner: Player)
	local set = crystals[owner]
	local nest = getNest(owner)
	if not set or not nest then
		return
	end
	local total = 0
	for part in set do
		total += crystalInfo[part] and crystalInfo[part].Value or 0
		crystalInfo[part] = nil
		part:Destroy()
	end
	crystals[owner] = {}
	if total > 0 then
		addCoins(owner, total)
		burstAt(nest.Position + Vector3.new(0, 2, 0), CRYSTAL_COLOR, 40)
		Remotes.Delivered:FireClient(owner, total, "Crystal", false, nest.Position)
	end
end

local function alarm(owner: Player, thief: Player)
	local now = os.clock()
	if lastAlarm[owner] and now - lastAlarm[owner] < Config.AlarmCooldown then
		return
	end
	lastAlarm[owner] = now
	Remotes.Alarm:FireClient(owner, thief.DisplayName)

	-- Red flashing light on the roof, visible to everyone
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

local function onCrystalTriggered(player: Player, part: BasePart)
	local info = crystalInfo[part]
	if not info then
		return
	end
	local owner = info.Owner
	if player == owner then
		bankCrystals(owner)
		return
	end
	if carriers[player] then
		return
	end
	local root = getRoot(player)
	if not root then
		return
	end

	local value = info.Value
	removeCrystal(part)
	layoutCrystals(owner)
	attachOverhead(part, root, 4)

	carriers[player] = { Kind = "Crystal", Type = "Crystal", Value = value, Victim = owner, Part = part }
	player:SetAttribute("Carrying", "Crystal")
	setSpeed(player, Config.CarrySpeed)
	setHighlight(player, THIEF_COLOR)
	burstAt(root.Position + Vector3.new(0, 4, 0), THIEF_COLOR, 20)
	alarm(owner, player)
	hint(player, `You grabbed a Storm Crystal (+{value})! Run home — if {owner.DisplayName} tags you, it goes back!`, 5)
end

createCrystal = function(owner: Player, value: number)
	local p = Instance.new("Part")
	p.Name = "StormCrystal"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * 1.6
	p.Color = CRYSTAL_COLOR
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false

	local light = Instance.new("PointLight")
	light.Color = CRYSTAL_COLOR
	light.Brightness = 1.5
	light.Range = 6
	light.Parent = p

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = `Storm Crystal (+{value})`
	prompt.HoldDuration = 0.4 -- a short hold: stealing takes nerve
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = p
	prompt.Triggered:Connect(function(player)
		onCrystalTriggered(player, p)
	end)

	crystals[owner] = crystals[owner] or {}
	crystals[owner][p] = true
	crystalInfo[p] = { Owner = owner, Value = value, Base = Vector3.zero }
	p.Parent = crystalFolder
	layoutCrystals(owner)
	return p
end

local function crystalLoop()
	while true do
		task.wait(Config.CrystalInterval)
		for owner in crystals do
			local data = DataService.Get(owner)
			local pets = data and #data.Recent or 0
			if owner.Parent and pets > 0 and crystalCount(owner) < Config.MaxCrystals then
				createCrystal(owner, Config.CrystalBaseValue + Config.CrystalValuePerPet * pets)
			end
		end
	end
end

------------------------------------------------------------------------
-- Carrying
------------------------------------------------------------------------

-- returnStolen: a dropped stolen crystal goes back to its owner
local function clearCarry(player: Player, returnStolen: boolean?)
	local c = carriers[player]
	if not c then
		return nil
	end
	carriers[player] = nil
	player:SetAttribute("Carrying", nil)
	setHighlight(player, nil)
	if c.Part then
		c.Part:Destroy()
	end
	setSpeed(player, Config.WalkSpeed)
	if returnStolen and c.Kind == "Crystal" and c.Victim and c.Victim.Parent and crystals[c.Victim] then
		createCrystal(c.Victim, c.Value)
	end
	return c
end

local function deliver(player: Player, c, nest: BasePart)
	if c.Kind == "Crystal" then
		addCoins(player, c.Value)
		burstAt(nest.Position + Vector3.new(0, 2, 0), CRYSTAL_COLOR, 45)
		Remotes.Delivered:FireClient(player, c.Value, "Crystal", false, nest.Position)
		hint(player, `Heist complete! +{c.Value} coins 😈`, 3)
		return
	end

	local def = Weather.Types[c.Type]
	local reward = def.Reward * (c.Shiny and Weather.ShinyMultiplier or 1)
	local data = DataService.Get(player)
	if data then
		data.Delivered += 1
		local key = c.Shiny and (c.Type .. "_Shiny") or c.Type
		data.Collection[key] = (data.Collection[key] or 0) + 1
		table.insert(data.Recent, 1, { Type = c.Type, Shiny = c.Shiny })
		while #data.Recent > Config.DisplaySlots do
			table.remove(data.Recent)
		end
	end
	addCoins(player, reward)
	refreshDisplay(player)

	burstAt(nest.Position + Vector3.new(0, 2, 0), c.Shiny and Weather.ShinyColor or def.Color, c.Shiny and 80 or 40)
	Remotes.Delivered:FireClient(player, reward, c.Type, c.Shiny, nest.Position)
	hint(player, `{def.DisplayName} added to your roof. It makes Storm Crystals — guard them!`, 3)
end

local function catch(player: Player, creature: BasePart)
	local info = wild[creature]
	if not info or not info.Ready or carriers[player] then
		return
	end
	local root = getRoot(player)
	if not root then
		return
	end

	wild[creature] = nil
	if info.Spawn then
		occupied[info.Spawn] = nil
	end

	burstAt(creature.Position, info.Shiny and Weather.ShinyColor or Weather.Types[info.Type].Color, 25)
	creature.Size *= 0.7
	attachOverhead(creature, root, 4.5)

	carriers[player] = {
		Kind = "Weather",
		Type = info.Type,
		Shiny = info.Shiny,
		Part = creature,
		NextPuddle = 0,
		LastPuddlePos = nil,
		NextFlash = 0,
	}
	player:SetAttribute("Carrying", info.Type)

	local def = Weather.Types[info.Type]
	if info.Type == "Thunder" then
		setSpeed(player, Config.ThunderCarrySpeed)
		setHighlight(player, def.ParticleColor)
		hintAll(`⚡ {player.DisplayName} has a THUNDER CLOUD! ⚡`, 4)
	else
		setSpeed(player, Config.CarrySpeed)
	end
	hint(player, `You caught a {def.DisplayName}! Bring it to your roof — follow the beam`, 5)
	if info.Shiny then
		hintAll(`✨ {player.DisplayName} caught a SHINY {def.DisplayName}! ✨`, 6)
	end
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
	local spawns = MapService.GetSpawns()
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

local function spawnWild(spawnPart: BasePart, typeName: string, shiny: boolean)
	local def = Weather.Types[typeName]
	local creature = makeCreature(typeName, shiny, 1)
	local base = spawnPart.Position + Vector3.new(0, 1.5, 0)
	creature.CFrame = CFrame.new(stormPos) -- born inside the storm
	addLabel(creature, shiny and `✨ SHINY {def.DisplayName} ✨` or def.DisplayName, shiny and Weather.ShinyColor or Color3.new(1, 1, 1))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Catch"
	prompt.ObjectText = def.DisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = creature
	prompt.Triggered:Connect(function(player)
		catch(player, creature)
	end)

	creature.Parent = wildFolder
	local info = {
		Type = typeName,
		Shiny = shiny,
		Spawn = spawnPart,
		Base = base,
		Phase = math.random() * math.pi * 2,
		Spin = def.Spin,
		Ready = false,
	}
	wild[creature] = info
	occupied[spawnPart] = creature

	-- Fly from the storm down to its spot
	local tween = TweenService:Create(creature, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(base),
	})
	tween.Completed:Connect(function()
		if wild[creature] then
			info.Ready = true
			prompt.Enabled = true
			burstAt(base, shiny and Weather.ShinyColor or def.Color, 12)
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

local function spawnLoop()
	while true do
		for i, spawnPart in MapService.GetSpawns() do
			local current = occupied[spawnPart]
			if current and not current.Parent then
				occupied[spawnPart] = nil
				current = nil
			end
			if not current and countWild() < Config.MaxWild then
				if i == 1 then
					-- Tutorial spot: always a normal Rain Cloud, always refilled
					spawnWild(spawnPart, "Rain", false)
				elseif math.random() < Config.SpawnChance then
					spawnWild(spawnPart, rollType(), math.random() < Weather.ShinyChance)
				end
			end
		end
		task.wait(Config.SpawnInterval)
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

-- Alarm when a rival walks onto a roof that has crystals
local function checkIntruders(players: { [Player]: BasePart })
	for owner, set in crystals do
		if next(set) == nil then
			continue
		end
		local nest = getNest(owner)
		if not nest then
			continue
		end
		for player, root in players do
			if player ~= owner and (root.Position - nest.Position).Magnitude <= Config.IntruderRadius then
				alarm(owner, player)
			end
		end
	end
end

local function mainLoop()
	while true do
		task.wait(0.1)
		local now = os.clock()

		local roots = {}
		for player in crystals do
			local root = getRoot(player)
			if root then
				roots[player] = root
			end
		end

		for player, c in carriers do
			local root = roots[player] or getRoot(player)
			if not root or not c.Part or not c.Part.Parent then
				clearCarry(player, true)
				continue
			end

			-- Owner tags the thief -> crystal goes back
			if c.Kind == "Crystal" then
				local victimRoot = c.Victim and roots[c.Victim]
				if victimRoot and (victimRoot.Position - root.Position).Magnitude <= Config.TagRadius then
					burstAt(root.Position + Vector3.new(0, 3, 0), THIEF_COLOR, 30)
					clearCarry(player, true)
					hint(player, `{c.Victim.DisplayName} caught you! The crystal flew back.`, 4)
					hint(c.Victim, `You caught {player.DisplayName}! Crystal recovered 🛡️`, 4)
					continue
				end
			end

			-- Delivery at your own Nest
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

		-- Owners standing on their Nest bank their crystals
		for owner, root in roots do
			local nest = getNest(owner)
			if nest and not carriers[owner] and next(crystals[owner]) ~= nil
				and (root.Position - nest.Position).Magnitude <= Config.DeliverRadius then
				bankCrystals(owner)
			end
		end

		checkIntruders(roots)
		updateWorld(now)
	end
end

local function bobLoop()
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for part, info in wild do
			if info.Ready then
				part.CFrame = CFrame.new(info.Base + Vector3.new(0, math.sin(t * 2 + info.Phase) * 0.8, 0))
					* CFrame.Angles(0, t * info.Spin, 0)
			end
		end
		for part, info in crystalInfo do
			if part.Parent == crystalFolder then
				part.CFrame = CFrame.new(info.Base + Vector3.new(0, math.sin(t * 3 + info.Base.X) * 0.4, 0))
			end
		end
	end)
end

------------------------------------------------------------------------
-- Players
------------------------------------------------------------------------

function WeatherService.OnPlayerAdded(player: Player)
	player:SetAttribute("BaseSpeed", Config.WalkSpeed)
	crystals[player] = {}
	refreshDisplay(player)

	local function onCharacter(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.WalkSpeed = Config.WalkSpeed
		player:SetAttribute("BaseSpeed", Config.WalkSpeed)
		hum.Died:Connect(function()
			clearCarry(player, true)
		end)
		task.delay(1.5, function()
			if carriers[player] then
				return
			end
			local data = DataService.Get(player)
			if data and data.Delivered == 0 then
				hint(player, "Catch the cloud! ☁️  Walk up to it and press E", 8)
			else
				hint(player, "Catch weather, guard your crystals, raid other roofs!", 5)
			end
		end)
	end

	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(function()
		clearCarry(player, true)
	end)
end

function WeatherService.OnPlayerRemoving(player: Player)
	clearCarry(player, true)
	for part in crystals[player] or {} do
		crystalInfo[part] = nil
		part:Destroy()
	end
	crystals[player] = nil
	lastAlarm[player] = nil
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
	crystalFolder = Instance.new("Folder")
	crystalFolder.Name = "Crystals"
	crystalFolder.Parent = weatherFolder
	weatherFolder.Parent = workspace

	setupStorm()
	bobLoop()
	task.spawn(spawnLoop)
	task.spawn(mainLoop)
	task.spawn(crystalLoop)
end

return WeatherService
