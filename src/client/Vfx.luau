-- Gameplay VFX (client only, costs the server nothing). Built from parts,
-- particles and the default Roblox particle textures — no uploaded assets.
--
--   Catch burst      ring shockwave + sparkles when anyone catches a cloud
--   Rarity aura      Rare+ carriers sparkle in the rarity colour; Legendary and
--                    Mythic also glow (soft light, no beam)
--   Delivery         gold coin fountain at your nest
--   Level up         golden pillar + ring on whoever levels up
--   Updraft          speed lines + wider FOV while riding, dust puff on landing
--   Footsteps        dust / snow / embers / splashes under your feet when running
--   Hit              camera shake + white flash when knocked (lightning, Quake)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Weather = require(ReplicatedStorage.Shared.WeatherTypes)

local Vfx = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local GOLD = Color3.fromRGB(255, 205, 70)

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientVfx"

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------

local function part(size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cf
	p.Color = color
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.Parent = fxFolder
	return p
end

local FxKit = require(ReplicatedStorage.Shared.FxKit)

-- One-shot particle burst at a position (v2.22: + layered pro burst)
local function burst(pos: Vector3, color: Color3, count: number, opts: { [string]: any }?)
	local o = opts or {}
	if not o.Texture or o.Texture == SPARKLE then
		FxKit.Burst(pos, color, math.clamp(count / 24, 0.4, 2))
	end
	local anchor = part(Vector3.one, CFrame.new(pos), color, { Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.Texture or SPARKLE
	e.Color = ColorSequence.new(color)
	e.LightEmission = o.LightEmission or 1
	e.Size = o.Size or NumberSequence.new(0.6, 0)
	e.Lifetime = o.Lifetime or NumberRange.new(0.6, 1.1)
	e.Speed = o.Speed or NumberRange.new(12, 22)
	e.SpreadAngle = o.Spread or Vector2.new(180, 180)
	e.Acceleration = o.Acceleration or Vector3.zero
	e.Drag = o.Drag or 2
	e.Rate = 0
	e.Parent = anchor
	e:Emit(count)
	task.delay(2.5, function()
		anchor:Destroy()
	end)
end

-- Flat expanding ring (shockwave)
local function ring(pos: Vector3, color: Color3, toSize: number, time: number)
	FxKit.Shockwave(pos, toSize / 2, color, time)
	local r = part(Vector3.new(0.3, 2, 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, {
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.7,
	})
	TweenService:Create(r, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, toSize, toSize),
		Transparency = 1,
	}):Play()
	task.delay(time + 0.1, function()
		r:Destroy()
	end)
end

-- Vertical light pillar
local function pillar(pos: Vector3, color: Color3, height: number, time: number)
	FxKit.Pillar(pos, color, height, time)
	local p = part(Vector3.new(height, 3, 3), CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, {
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.3,
	})
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(height, 0.2, 0.2),
		Transparency = 1,
	}):Play()
	task.delay(time + 0.1, function()
		p:Destroy()
	end)
end

local function rootOf(p: Player): BasePart?
	local char = p.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

------------------------------------------------------------------------
-- Catch burst + rarity aura (every player, from the Carrying attribute)
------------------------------------------------------------------------

local function clearAura(p: Player)
	local root = rootOf(p)
	if root then
		for _, name in { "VfxAura", "VfxPillar", "VfxPillarAtt0", "VfxPillarAtt1" } do
			local old = root:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
	end
end

local function setAura(p: Player)
	clearAura(p)
	local typeName = p:GetAttribute("Carrying")
	local root = rootOf(p)
	local def = typeName and Weather.Types[typeName]
	if not root or not def then
		return
	end
	local rarity = Weather.RarityOf(typeName)
	-- catch: shockwave + sparkles in the cloud's colour
	ring(root.Position - Vector3.new(0, 2.6, 0), def.ParticleColor, 14 + rarity.Tier * 4, 0.5)
	burst(root.Position + Vector3.new(0, 2, 0), def.ParticleColor, 14 + rarity.Tier * 8)

	if rarity.Tier < 2 then
		return
	end
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "VfxAura"
	aura.Texture = SPARKLE
	aura.Color = ColorSequence.new(rarity.Color)
	aura.LightEmission = 1
	aura.Size = NumberSequence.new(0.35 + rarity.Tier * 0.08, 0)
	aura.Lifetime = NumberRange.new(0.6, 1)
	aura.Rate = 4 + rarity.Tier * 4
	aura.Speed = NumberRange.new(1, 3)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = root

	if rarity.Tier >= 4 then
		-- v1.8: no light pillar (it read as a hard beam); a soft coloured glow instead
		local glow = Instance.new("PointLight")
		glow.Name = "VfxPillar"
		glow.Color = rarity.Color
		glow.Range = 16
		glow.Brightness = 1.5
		glow.Parent = root
	end
end

local function watchPlayer(p: Player)
	p:GetAttributeChangedSignal("Carrying"):Connect(function()
		setAura(p)
	end)
	p.CharacterAdded:Connect(function()
		task.wait(0.5)
		setAura(p)
	end)
	-- level up (leaderstats.Level goes up)
	task.spawn(function()
		local ls = p:WaitForChild("leaderstats", 30)
		local level = ls and ls:WaitForChild("Level", 30) :: IntValue?
		if not level then
			return
		end
		local last = level.Value
		level.Changed:Connect(function(v)
			local root = rootOf(p)
			if v > last and last > 0 and root then
				local feet = root.Position - Vector3.new(0, 3, 0)
				pillar(feet, GOLD, 60, 1.4)
				ring(feet + Vector3.new(0, 0.2, 0), GOLD, 30, 0.8)
				burst(root.Position, GOLD, 60, { Speed = NumberRange.new(18, 30), Acceleration = Vector3.new(0, -20, 0) })
			end
			last = v
		end)
	end)
end

------------------------------------------------------------------------
-- Delivery coin fountain
------------------------------------------------------------------------

local function onDelivered(_reward: number, _kind: string, shiny: boolean, nestPos: Vector3)
	local pos = nestPos + Vector3.new(0, 1, 0)
	burst(pos, GOLD, shiny and 90 or 45, {
		Speed = NumberRange.new(20, 32),
		Spread = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, -45, 0),
		Lifetime = NumberRange.new(1, 1.6),
		Size = NumberSequence.new(0.8, 0.2),
		Drag = 0.5,
	})
	ring(pos, GOLD, 22, 0.6)
end

------------------------------------------------------------------------
-- Hit: camera shake + flash
------------------------------------------------------------------------

local shakeUntil, shakeStrength = 0, 0
local flash: Frame

local function onKnock()
	shakeUntil = os.clock() + 0.35
	shakeStrength = 0.6
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

------------------------------------------------------------------------
-- Footsteps + updraft (local player)
------------------------------------------------------------------------

local FOOT = {
	[Enum.Material.Snow] = { Color3.fromRGB(245, 250, 255), SMOKE },
	[Enum.Material.Glacier] = { Color3.fromRGB(210, 240, 255), SPARKLE },
	[Enum.Material.Sand] = { Color3.fromRGB(235, 215, 165), SMOKE },
	[Enum.Material.Sandstone] = { Color3.fromRGB(200, 160, 170), SMOKE },
	[Enum.Material.Mud] = { Color3.fromRGB(90, 100, 80), SMOKE },
	[Enum.Material.Basalt] = { Color3.fromRGB(255, 140, 60), SPARKLE },
	[Enum.Material.Glass] = { Color3.fromRGB(160, 220, 255), SPARKLE },
	[Enum.Material.Grass] = { Color3.fromRGB(200, 230, 190), SMOKE },
	[Enum.Material.Rock] = { Color3.fromRGB(190, 185, 180), SMOKE },
}

function Vfx.Start()
	fxFolder.Parent = workspace

	local gui = Instance.new("ScreenGui")
	gui.Name = "VfxFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui
	-- speed lines while in the updraft
	local lines = Instance.new("Frame")
	lines.Size = UDim2.fromScale(1, 1)
	lines.BackgroundTransparency = 1
	lines.Visible = false
	lines.Parent = gui
	local streaks = {}
	for i = 1, 18 do
		local s = Instance.new("Frame")
		s.BorderSizePixel = 0
		s.BackgroundColor3 = Color3.new(1, 1, 1)
		s.BackgroundTransparency = 0.6
		s.Size = UDim2.new(0, 2, 0.12 + (i % 4) * 0.04, 0)
		s.Parent = lines
		streaks[i] = { Frame = s, X = math.random(), Speed = 1.5 + math.random() * 1.5, Y = math.random() }
	end
	gui.Parent = player:WaitForChild("PlayerGui")

	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Delivered").OnClientEvent:Connect(onDelivered)
	remotes:WaitForChild("Knock").OnClientEvent:Connect(onKnock)
	-- v2.22: big FxKit explosions shake the camera + tint flash, by distance
	task.spawn(function()
		local fxk = workspace:WaitForChild("FxKit", 120)
		if not fxk then
			return
		end
		fxk.ChildAdded:Connect(function(a)
			task.defer(function()
				local sc = a:GetAttribute("Shake")
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not sc or not root or not a:IsA("BasePart") then
					return
				end
				local d = (a.Position - root.Position).Magnitude
				local k = math.clamp(sc * (1 - d / (40 + sc * 30)), 0, 1.6)
				if k > 0.05 then
					local still = os.clock() < shakeUntil and shakeStrength or 0
					shakeUntil = os.clock() + 0.35
					shakeStrength = math.max(still, 0.35 * k)
					if k > 0.5 then
						flash.BackgroundTransparency = 1 - 0.25 * math.min(k, 1.6)
						TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
					end
				end
			end)
		end)
	end)

	local baseFov = camera.FieldOfView
	local wasRiding = false
	local stepTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		-- camera shake (applied after the camera script moved the camera)
		if os.clock() < shakeUntil then
			local k = shakeStrength * (shakeUntil - os.clock()) / 0.35
			camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * 4 * k), math.rad((math.random() - 0.5) * 4 * k), 0)
		end

		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum then
			return
		end

		-- updraft: speed lines + FOV
		local air = root:FindFirstChild("AirLift") :: LinearVelocity?
		local riding = air ~= nil and air.Enabled
		lines.Visible = riding
		camera.FieldOfView += ((riding and baseFov + 14 or baseFov) - camera.FieldOfView) * math.min(1, dt * 4)
		if riding then
			for _, s in streaks do
				s.Y -= dt * s.Speed
				if s.Y < -0.2 then
					s.Y, s.X = 1.1, math.random()
				end
				s.Frame.Position = UDim2.fromScale(s.X, s.Y)
			end
		end
		if wasRiding and not riding then
			-- landing puff once we touch ground again
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < 3 and hum.FloorMaterial == Enum.Material.Air do
					task.wait()
				end
				if hum.FloorMaterial ~= Enum.Material.Air then
					burst(root.Position - Vector3.new(0, 2.8, 0), Color3.fromRGB(235, 240, 250), 25, {
						Texture = SMOKE, LightEmission = 0, Size = NumberSequence.new(2, 4),
						Speed = NumberRange.new(10, 16), Spread = Vector2.new(80, 80), Lifetime = NumberRange.new(0.6, 1),
					})
					ring(root.Position - Vector3.new(0, 2.8, 0), Color3.fromRGB(200, 235, 255), 18, 0.5)
				end
			end)
		end
		wasRiding = riding

		-- footsteps
		stepTimer -= dt
		local floor = hum.FloorMaterial
		if stepTimer <= 0 and floor ~= Enum.Material.Air and hum.MoveDirection.Magnitude > 0.5 then
			stepTimer = 0.28
			local f = FOOT[floor]
			if f then
				burst(root.Position - Vector3.new(0, 2.8, 0), f[1], f[2] == SMOKE and 3 or 5, {
					Texture = f[2], LightEmission = f[2] == SMOKE and 0 or 0.8,
					Size = f[2] == SMOKE and NumberSequence.new(0.8, 1.6) or NumberSequence.new(0.3, 0),
					Speed = NumberRange.new(2, 5), Spread = Vector2.new(60, 60), Lifetime = NumberRange.new(0.4, 0.7),
				})
			end
		end
	end)
end

return Vfx
