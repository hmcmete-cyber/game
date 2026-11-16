-- Client entry point: hints, the beam to your roof, and puddle movement effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local hintEvent = remotes:WaitForChild("Hint")

------------------------------------------------------------------------
-- Hint banner
------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "PocketStormHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.AnchorPoint = Vector2.new(0.5, 0)
hintLabel.Position = UDim2.new(0.5, 0, 0, 70)
hintLabel.Size = UDim2.new(0.6, 0, 0, 48)
hintLabel.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
hintLabel.BackgroundTransparency = 0.25
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextScaled = true
hintLabel.Visible = false
hintLabel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = hintLabel
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.Parent = hintLabel

local hintToken = 0
local function showHint(text: string, duration: number?)
	hintToken += 1
	local mine = hintToken
	hintLabel.Text = text
	hintLabel.Visible = true
	if duration and duration > 0 then
		task.delay(duration, function()
			if hintToken == mine then
				hintLabel.Visible = false
			end
		end)
	end
end
hintEvent.OnClientEvent:Connect(showHint)

------------------------------------------------------------------------
-- Beam from you to your Nest while carrying
------------------------------------------------------------------------

local beam, att0, att1
local function clearBeam()
	if beam then
		beam:Destroy()
	end
	if att0 then
		att0:Destroy()
	end
	if att1 then
		att1:Destroy()
	end
	beam, att0, att1 = nil, nil, nil
end

local function getNest()
	local map = workspace:FindFirstChild("Map")
	local roofs = map and map:FindFirstChild("Rooftops")
	local roofName = player:GetAttribute("Rooftop")
	local roof = roofs and roofName and roofs:FindFirstChild(roofName)
	return roof and roof:FindFirstChild("Nest")
end

local function updateBeam()
	clearBeam()
	if not player:GetAttribute("Carrying") then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local nest = getNest()
	if not root or not nest then
		return
	end
	att0 = Instance.new("Attachment")
	att0.Parent = root
	att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, 3, 0)
	att1.Parent = nest
	beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
	beam.Transparency = NumberSequence.new(0.2)
	beam.Parent = root
end

player:GetAttributeChangedSignal("Carrying"):Connect(updateBeam)
player.CharacterAdded:Connect(clearBeam)

------------------------------------------------------------------------
-- Puddle effects: slip / ice road / launch pad
------------------------------------------------------------------------

local onIce = false
local slipping = false
local lastSlip = 0
local lastLaunch = 0

local function baseSpeed(): number
	return player:GetAttribute("BaseSpeed") or Config.WalkSpeed
end

local function getHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function applySpeed()
	local hum = getHumanoid()
	if hum then
		hum.WalkSpeed = baseSpeed() + (onIce and Config.IceBoost or 0)
	end
end
player:GetAttributeChangedSignal("BaseSpeed"):Connect(applySpeed)

local function slip(hum: Humanoid, root: BasePart)
	slipping = true
	local dir = hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection or root.CFrame.LookVector
	hum.PlatformStand = true
	root.AssemblyLinearVelocity = dir * Config.SlipPush + Vector3.new(0, Config.SlipLift, 0)
	root.AssemblyAngularVelocity = Vector3.new(dir.Z, 0, -dir.X) * Config.SlipSpin
	task.delay(Config.SlipDuration, function()
		if hum.Parent then
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		slipping = false
	end)
end

local function launch(root: BasePart)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, Config.LaunchPower, v.Z)
end

local puddles = workspace:WaitForChild("Weather"):WaitForChild("Puddles")
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { puddles }

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end

	-- Small box at the feet
	local hits = workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0, -3, 0), Vector3.new(2.5, 2.5, 2.5), overlap)
	local now = os.clock()
	local iceNow = false
	local moving = hum.MoveDirection.Magnitude > 0.1

	for _, p in hits do
		local kind = p:GetAttribute("Kind")
		if kind == "Ice" then
			iceNow = true
		elseif kind == "Launch" and now - lastLaunch > 1 then
			lastLaunch = now
			launch(root)
		elseif kind == "Slip" and moving and not slipping and now - lastSlip > Config.SlipCooldown then
			local owner = p:GetAttribute("OwnerUserId")
			local created = p:GetAttribute("CreatedAt") or 0
			local fresh = workspace:GetServerTimeNow() - created < Config.OwnerPuddleGrace
			if not (owner == player.UserId and fresh) then
				lastSlip = now
				slip(hum, root)
			end
		end
	end

	if iceNow ~= onIce then
		onIce = iceNow
		applySpeed()
	end
end)

------------------------------------------------------------------------
-- HUD: coin counter + carrying panel + delivery celebration
------------------------------------------------------------------------

local TweenService = game:GetService("TweenService")
local Weather = require(ReplicatedStorage.Shared.WeatherTypes)
local deliveredEvent = remotes:WaitForChild("Delivered")

local function makePanel(name: string, position: UDim2, size: UDim2)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	frame.BackgroundTransparency = 0.2
	frame.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = frame
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	label.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = label
	return frame, label
end

local coinFrame, coinLabel = makePanel("Coins", UDim2.new(0.5, 0, 1, -20), UDim2.fromOffset(200, 52))
local coinScale = Instance.new("UIScale")
coinScale.Parent = coinFrame

local carryFrame, carryLabel = makePanel("Carrying", UDim2.new(0.5, 0, 1, -80), UDim2.fromOffset(300, 40))
carryLabel.TextColor3 = Color3.new(1, 1, 1)
carryFrame.Visible = false

local shownCoins = 0
local function setCoinText(value: number)
	coinLabel.Text = `🪙 {value}`
end

-- Count up smoothly and bounce
local function animateCoins(target: number)
	local from = shownCoins
	shownCoins = target
	if target <= from then
		setCoinText(target)
		return
	end
	coinScale.Scale = 1.25
	TweenService:Create(coinScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local steps = 15
	for i = 1, steps do
		if shownCoins ~= target then
			return -- a newer update took over
		end
		setCoinText(math.floor(from + (target - from) * i / steps))
		task.wait(0.03)
	end
end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local coins = leaderstats:WaitForChild("Coins") :: IntValue
	shownCoins = coins.Value
	setCoinText(coins.Value)
	coins.Changed:Connect(function(v)
		task.spawn(animateCoins, v)
	end)
end)

local function updateCarryPanel()
	local typeName = player:GetAttribute("Carrying")
	local def = typeName and Weather.Types[typeName]
	if def then
		carryFrame.Visible = true
		carryLabel.Text = `Carrying: {def.DisplayName}`
		carryFrame.BackgroundColor3 = def.Color:Lerp(Color3.new(0, 0, 0), 0.55)
	else
		carryFrame.Visible = false
	end
end
player:GetAttributeChangedSignal("Carrying"):Connect(updateCarryPanel)

local function playSound(id: string, volume: number, pitch: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.Parent = gui
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(5, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Floating "+N" above the nest
local function floatText(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(0, 3, 0)
	anchor.Parent = workspace

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 80)
	bb.AlwaysOnTop = true
	bb.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = bb

	TweenService:Create(anchor, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = anchor.Position + Vector3.new(0, 7, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

deliveredEvent.OnClientEvent:Connect(function(reward: number, typeName: string, shiny: boolean, nestPos: Vector3)
	local color = shiny and Weather.ShinyColor or Color3.fromRGB(255, 220, 80)
	floatText(nestPos, shiny and `✨ +{reward} ✨` or `+{reward}`, color)
	playSound("rbxasset://sounds/electronicpingshort.wav", 0.7, shiny and 0.8 or 1.2)
end)

-- Little "pop" when you catch something
player:GetAttributeChangedSignal("Carrying"):Connect(function()
	if player:GetAttribute("Carrying") then
		playSound("rbxasset://sounds/electronicpingshort.wav", 0.5, 1.8)
	end
end)
