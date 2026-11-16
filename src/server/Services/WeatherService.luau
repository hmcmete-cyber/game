-- Weather creatures: spawning, catching, carrying, world effects, delivery.
--
-- Rain cloud   -> leaves slippery puddles behind you
-- Pocket tornado -> lifts nearby LiftPlatforms (shortcut)
-- Snow cloud   -> freezes nearby WaterGaps into bridges
-- Combos: Snow near puddles = ice road (speed), Tornado near puddles = launch pad
--
-- Movement effects (slip / ice / launch) are applied by the client, which
-- reads the puddle attributes. The server owns everything else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Weather = require(ReplicatedStorage.Shared.WeatherTypes)

local WeatherService = {}

local MapService, DataService, Remotes

local weatherFolder, wildFolder, puddleFolder

local wild = {} -- [Part] = { Type, Shiny, Spawn, Base: Vector3, Phase, Spin }
local occupied = {} -- [spawn marker] = Part
local carriers = {} -- [Player] = { Type, Shiny, Part, NextPuddle, LastPuddlePos }
local puddleExpire = {} -- [Part] = os.clock() time
local liftState = {} -- [Part] = { Rest: CFrame, Up: boolean, LastNear: number }
local gapState = {} -- [Part] = { CanCollide, Material, Color, Transparency, FrozenUntil, Frozen }

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

local function setSpeed(player: Player, speed: number)
	player:SetAttribute("BaseSpeed", speed)
	local _, hum = getRoot(player)
	if hum then
		hum.WalkSpeed = speed
	end
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

-- Build the visual for a weather creature
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

	return p
end

local function addLabel(part: BasePart, typeName: string, shiny: boolean)
	local def = Weather.Types[typeName]
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
	label.TextColor3 = shiny and Weather.ShinyColor or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = shiny and `✨ SHINY {def.DisplayName} ✨` or def.DisplayName
	label.Parent = gui
	gui.Parent = part
end

------------------------------------------------------------------------
-- Carrying
------------------------------------------------------------------------

local function clearCarry(player: Player)
	local c = carriers[player]
	if not c then
		return nil
	end
	carriers[player] = nil
	player:SetAttribute("Carrying", nil)
	if c.Part then
		c.Part:Destroy()
	end
	setSpeed(player, Config.WalkSpeed)
	return c
end

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

local function deliver(player: Player, c, nest: BasePart)
	local def = Weather.Types[c.Type]
	local reward = def.Reward * (c.Shiny and Weather.ShinyMultiplier or 1)
	local data = DataService.Get(player)
	if data then
		data.Coins += reward
		data.Delivered += 1
		local key = c.Shiny and (c.Type .. "_Shiny") or c.Type
		data.Collection[key] = (data.Collection[key] or 0) + 1
		table.insert(data.Recent, 1, { Type = c.Type, Shiny = c.Shiny })
		while #data.Recent > Config.DisplaySlots do
			table.remove(data.Recent)
		end
	end
	DataService.Sync(player)
	refreshDisplay(player)

	-- Celebration burst everyone can see
	local burst = nest:FindFirstChild("DeliverBurst")
	if not burst then
		burst = Instance.new("ParticleEmitter")
		burst.Name = "DeliverBurst"
		burst.Enabled = false
		burst.Lifetime = NumberRange.new(0.6, 1)
		burst.Speed = NumberRange.new(12, 20)
		burst.SpreadAngle = Vector2.new(60, 60)
		burst.EmissionDirection = Enum.NormalId.Top
		burst.Acceleration = Vector3.new(0, -30, 0)
		burst.Size = NumberSequence.new(0.5, 0)
		burst.LightEmission = 1
		burst.Parent = nest
	end
	burst.Color = ColorSequence.new(c.Shiny and Weather.ShinyColor or def.Color)
	burst:Emit(c.Shiny and 80 or 35)

	Remotes.Delivered:FireClient(player, reward, c.Type, c.Shiny, nest.Position)
	hint(player, `{def.DisplayName} added to your roof. Catch another one!`, 3)
end

local function catch(player: Player, creature: BasePart)
	local info = wild[creature]
	if not info or carriers[player] then
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
	local prompt = creature:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end
	local label = creature:FindFirstChild("Label")
	if label then
		label:Destroy()
	end

	-- Attach above the player's head ("in the jar")
	creature.Size *= 0.7
	creature.Anchored = false
	creature.Massless = true
	creature.CFrame = root.CFrame * CFrame.new(0, 4.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = creature
	weld.Parent = creature
	creature.Parent = player.Character

	carriers[player] = {
		Type = info.Type,
		Shiny = info.Shiny,
		Part = creature,
		NextPuddle = 0,
		LastPuddlePos = nil,
	}
	player:SetAttribute("Carrying", info.Type)
	setSpeed(player, Config.CarrySpeed)

	local def = Weather.Types[info.Type]
	hint(player, `You caught a {def.DisplayName}! Bring it to your roof — follow the beam`, 5)
	if info.Shiny then
		hintAll(`✨ {player.DisplayName} caught a SHINY {def.DisplayName}! ✨`, 6)
	end
end

------------------------------------------------------------------------
-- Wild spawning
------------------------------------------------------------------------

local function spawnWild(spawnPart: BasePart, typeName: string, shiny: boolean)
	local creature = makeCreature(typeName, shiny, 1)
	local base = spawnPart.Position + Vector3.new(0, 1.5, 0)
	creature.CFrame = CFrame.new(base)
	addLabel(creature, typeName, shiny)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Catch"
	prompt.ObjectText = Weather.Types[typeName].DisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = creature
	prompt.Triggered:Connect(function(player)
		catch(player, creature)
	end)

	creature.Parent = wildFolder
	wild[creature] = {
		Type = typeName,
		Shiny = shiny,
		Spawn = spawnPart,
		Base = base,
		Phase = math.random() * math.pi * 2,
		Spin = Weather.Types[typeName].Spin,
	}
	occupied[spawnPart] = creature
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
	-- Collect carrier positions by type
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
	while true do
		task.wait(0.1)
		local now = os.clock()
		for player, c in carriers do
			local root = getRoot(player)
			if not root or not c.Part or not c.Part.Parent then
				clearCarry(player)
				continue
			end

			-- Delivery
			local roof = MapService.GetRooftop(player)
			local nest = roof and roof:FindFirstChild("Nest")
			if nest and (root.Position - nest.Position).Magnitude <= Config.DeliverRadius then
				local delivered = clearCarry(player)
				if delivered then
					deliver(player, delivered, nest)
				end
				continue
			end

			if c.Type == "Rain" then
				spawnPuddle(player, c, root, now)
			end
		end
		updateWorld(now)
	end
end

local function bobLoop()
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for part, info in wild do
			part.CFrame = CFrame.new(info.Base + Vector3.new(0, math.sin(t * 2 + info.Phase) * 0.8, 0))
				* CFrame.Angles(0, t * info.Spin, 0)
		end
	end)
end

------------------------------------------------------------------------
-- Players
------------------------------------------------------------------------

function WeatherService.OnPlayerAdded(player: Player)
	player:SetAttribute("BaseSpeed", Config.WalkSpeed)
	refreshDisplay(player)

	local function onCharacter(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.WalkSpeed = Config.WalkSpeed
		player:SetAttribute("BaseSpeed", Config.WalkSpeed)
		hum.Died:Connect(function()
			clearCarry(player)
		end)
		task.delay(1.5, function()
			if carriers[player] then
				return
			end
			local data = DataService.Get(player)
			if data and data.Delivered == 0 then
				hint(player, "Catch the cloud! ☁️  Walk up to it and press E", 8)
			else
				hint(player, "Catch weather and bring it to your roof!", 5)
			end
		end)
	end

	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(function()
		clearCarry(player)
	end)
end

function WeatherService.OnPlayerRemoving(player: Player)
	clearCarry(player)
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

	bobLoop()
	task.spawn(spawnLoop)
	task.spawn(mainLoop)
end

return WeatherService
