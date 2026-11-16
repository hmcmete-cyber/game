-- All on-screen UI: glass score panel, carrying pill, hint banner,
-- beam to your Nest, delivery celebration, theft alarm.
--
-- Hierarchy (built in code, so Rojo owns it):
-- PlayerGui
-- └── PocketStormHUD (ScreenGui)
--     ├── ScorePanel (Frame, glass)      top center
--     │   ├── Icon (TextLabel "☁️")
--     │   ├── Title (TextLabel "STORM COINS")
--     │   └── Value (TextLabel)
--     ├── CarryPill (Frame, glass)       bottom center
--     ├── Hint (TextLabel)               under the score panel
--     ├── StealBanner (Frame, red glass) center of the screen, flashes on thefts
--     └── AlarmFlash (Frame, red)        full screen, normally invisible

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Weather = require(ReplicatedStorage.Shared.WeatherTypes)

local Hud = {}

local player = Players.LocalPlayer
local gui: ScreenGui

local GOLD = Color3.fromRGB(255, 220, 90)
local THIEF = Color3.fromRGB(255, 70, 70)

------------------------------------------------------------------------
-- Glass building blocks
------------------------------------------------------------------------

local function glass(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = 0.78
	f.BorderSizePixel = 0
	f.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = f

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f

	-- light from the top, darker at the bottom = "frosted glass"
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 230))
	gradient.Transparency = NumberSequence.new(0.1, 0.35)
	gradient.Parent = f

	return f
end

local function text(name: string, parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextScaled = true
	t.TextStrokeTransparency = 0.6
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

local function playSound(id: string, volume: number, pitch: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.Parent = gui
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end

local PING = "rbxasset://sounds/electronicpingshort.wav"

------------------------------------------------------------------------
-- Pieces
------------------------------------------------------------------------

local scorePanel, scoreValue, scoreScale
local carryPill, carryText
local hintLabel
local alarmFlash
local stealBanner, stealText, stealScale

local function buildUi()
	gui = Instance.new("ScreenGui")
	gui.Name = "PocketStormHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Score panel
	scorePanel = glass("ScorePanel", gui)
	scorePanel.AnchorPoint = Vector2.new(0.5, 0)
	scorePanel.Position = UDim2.new(0.5, 0, 0, 10)
	scorePanel.Size = UDim2.fromOffset(250, 66)
	scoreScale = Instance.new("UIScale")
	scoreScale.Parent = scorePanel

	text("Icon", scorePanel, {
		Text = "☁️",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(46, 46),
		TextStrokeTransparency = 1,
	})
	text("Title", scorePanel, {
		Text = "STORM COINS",
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(235, 240, 255),
		Position = UDim2.fromOffset(66, 8),
		Size = UDim2.new(1, -78, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	scoreValue = text("Value", scorePanel, {
		Text = "0",
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		Position = UDim2.fromOffset(66, 24),
		Size = UDim2.new(1, -78, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Carrying pill
	carryPill = glass("CarryPill", gui)
	carryPill.AnchorPoint = Vector2.new(0.5, 1)
	carryPill.Position = UDim2.new(0.5, 0, 1, -24)
	carryPill.Size = UDim2.fromOffset(320, 44)
	carryPill.Visible = false
	carryText = text("Text", carryPill, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 1, -16),
	})

	-- Hint banner
	hintLabel = text("Hint", gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 88),
		Size = UDim2.new(0.55, 0, 0, 36),
		TextStrokeTransparency = 0.2,
		Visible = false,
	})

	-- "X stole Y's Storm!" banner, center screen
	stealBanner = glass("StealBanner", gui)
	stealBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	stealBanner.Position = UDim2.fromScale(0.5, 0.38)
	stealBanner.Size = UDim2.fromOffset(520, 70)
	stealBanner.BackgroundColor3 = THIEF
	stealBanner.BackgroundTransparency = 0.35
	stealBanner.Visible = false
	stealBanner.ZIndex = 5
	stealScale = Instance.new("UIScale")
	stealScale.Parent = stealBanner
	stealText = text("Text", stealBanner, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 1, -20),
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.3,
		ZIndex = 6,
	})

	-- Theft alarm screen flash
	alarmFlash = Instance.new("Frame")
	alarmFlash.Name = "AlarmFlash"
	alarmFlash.Size = UDim2.fromScale(1, 1)
	alarmFlash.BackgroundColor3 = THIEF
	alarmFlash.BackgroundTransparency = 1
	alarmFlash.BorderSizePixel = 0
	alarmFlash.ZIndex = 0
	alarmFlash.Parent = gui
end

------------------------------------------------------------------------
-- Behaviour
------------------------------------------------------------------------

local hintToken = 0
local function showHint(message: string, duration: number?)
	hintToken += 1
	local mine = hintToken
	hintLabel.Text = message
	hintLabel.Visible = true
	hintLabel.TextTransparency = 0
	if duration and duration > 0 then
		task.delay(duration, function()
			if hintToken == mine then
				hintLabel.Visible = false
			end
		end)
	end
end

local shownCoins = 0
local function animateCoins(target: number)
	local from = shownCoins
	shownCoins = target
	if target <= from then
		scoreValue.Text = tostring(target)
		return
	end
	scoreScale.Scale = 1.15
	TweenService:Create(scoreScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local steps = 15
	for i = 1, steps do
		if shownCoins ~= target then
			return -- a newer update took over
		end
		scoreValue.Text = tostring(math.floor(from + (target - from) * i / steps))
		task.wait(0.03)
	end
end

local function updateCarry()
	local kind = player:GetAttribute("Carrying")
	if kind and player:GetAttribute("CarryingStolen") then
		carryPill.Visible = true
		carryText.Text = `🚨 STOLEN {Weather.Types[kind] and Weather.Types[kind].DisplayName or "storm"} — run home!`
		carryText.TextColor3 = THIEF
	elseif kind and Weather.Types[kind] then
		local def = Weather.Types[kind]
		carryPill.Visible = true
		carryText.Text = `Carrying: {def.DisplayName}`
		carryText.TextColor3 = def.Color:Lerp(Color3.new(1, 1, 1), 0.5)
	else
		carryPill.Visible = false
	end
	if kind then
		playSound(PING, 0.5, 1.8)
	end
end

-- Beam from you to your Nest while carrying
local beam, att0, att1
local function clearBeam()
	for _, obj in { beam, att0, att1 } do
		if obj then
			obj:Destroy()
		end
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
	local kind = player:GetAttribute("Carrying")
	if not kind then
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
	beam.Color = ColorSequence.new(player:GetAttribute("CarryingStolen") and THIEF or GOLD)
	beam.Transparency = NumberSequence.new(0.2)
	beam.Parent = root
end

-- Floating "+N" above the nest
local function floatText(position: Vector3, message: string, color: Color3)
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
	local label = text("Text", bb, {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		Text = message,
		TextColor3 = color,
		TextStrokeTransparency = 0,
	})

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

local function onDelivered(reward: number, kind: string, shiny: boolean, nestPos: Vector3)
	local color = shiny and Weather.ShinyColor or GOLD
	floatText(nestPos, shiny and `✨ +{reward} ✨` or `+{reward}`, color)
	playSound(PING, 0.7, shiny and 0.8 or 1.2)
end

local stealToken = 0
local function onStolen(thiefName: string, victimName: string, stormName: string)
	stealToken += 1
	local mine = stealToken
	if victimName == player.DisplayName then
		stealText.Text = `🚨 {thiefName} STOLE YOUR {string.upper(stormName)}! 🚨`
	else
		stealText.Text = `{thiefName} stole {victimName}'s {stormName}!`
	end
	stealBanner.Visible = true
	stealScale.Scale = 0.6
	TweenService:Create(stealScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- blink red
	task.spawn(function()
		for i = 1, 6 do
			if stealToken ~= mine then
				return
			end
			stealBanner.BackgroundTransparency = (i % 2 == 1) and 0.1 or 0.45
			task.wait(0.25)
		end
		task.wait(1.5)
		if stealToken == mine then
			stealBanner.Visible = false
		end
	end)
end

local function onAlarm(thiefName: string)
	showHint(`🚨 {thiefName} is on your base! Touch them to take your storm back!`, 5)
	for i = 1, 3 do
		task.delay((i - 1) * 0.35, function()
			playSound(PING, 0.9, 0.6)
			alarmFlash.BackgroundTransparency = 0.7
			TweenService:Create(alarmFlash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		end)
	end
end

------------------------------------------------------------------------

function Hud.Start()
	buildUi()

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Hint").OnClientEvent:Connect(showHint)
	remotes:WaitForChild("Delivered").OnClientEvent:Connect(onDelivered)
	remotes:WaitForChild("Alarm").OnClientEvent:Connect(onAlarm)
	remotes:WaitForChild("Stolen").OnClientEvent:Connect(onStolen)

	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		task.defer(function() -- wait for CarryingStolen to be set too
			updateCarry()
			updateBeam()
		end)
	end)
	player.CharacterAdded:Connect(clearBeam)

	task.spawn(function()
		local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue
		shownCoins = coins.Value
		scoreValue.Text = tostring(coins.Value)
		coins.Changed:Connect(function(v)
			task.spawn(animateCoins, v)
		end)
	end)
end

return Hud
