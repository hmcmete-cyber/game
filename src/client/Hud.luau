-- Main HUD (glassmorphism, rounded):
--
-- PlayerGui
-- └── StealACloudHUD (ScreenGui)
--     ├── TopCenter (Frame)                    where am I + danger
--     │   ├── ZonePill (Frame)  ZoneText       "Breeze Zone"
--     │   ├── Alert (Frame)     AlertText      red: thefts / alarms · yellow: gate warnings
--     │   └── Hint (TextLabel)                 tutorial / info messages
--     ├── Status (Frame, top-right)            cloud & vault status
--     │   ├── CoinsTitle, CoinsValue
--     │   ├── CarryTitle, CarryValue, Rarity   "Mythic Storm Cloud" · MYTHIC
--     │   └── VaultTitle, VaultValue, Dots     "2 / 4 spheres full" # # o o
--     └── AlarmFlash (Frame)                   full-screen red flash when robbed
--
-- Also: the yellow beam from you to your Nest while carrying, "+N" popups.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Weather = require(ReplicatedStorage.Shared.WeatherTypes)

local BiomeMap = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BiomeMap"))
local Hud = {}

local player = Players.LocalPlayer
local gui: ScreenGui

local GOLD = Color3.fromRGB(255, 220, 90)
local RED = Color3.fromRGB(255, 70, 70)
local AMBER = Color3.fromRGB(255, 190, 60)
local PING = "rbxasset://sounds/electronicpingshort.wav"

------------------------------------------------------------------------
-- Glass building blocks
------------------------------------------------------------------------

local function glass(name: string, parent: Instance, radius: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = 0.78
	f.BorderSizePixel = 0
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 18)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
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

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------

local zonePill, zoneText
local alert, alertText, alertScale
local hintLabel
local coinsValue, coinsScale
local carryValue, rarityText
local vaultValue, dots
local alarmFlash

local function buildUi()
	gui = Instance.new("ScreenGui")
	gui.Name = "StealACloudHUD"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Top center ---------------------------------------------------------
	local top = Instance.new("Frame")
	top.Name = "TopCenter"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 8)
	top.Size = UDim2.fromOffset(520, 170)
	top.BackgroundTransparency = 1
	top.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = top

	zonePill = glass("ZonePill", top, 20)
	zonePill.LayoutOrder = 1
	zonePill.Size = UDim2.fromOffset(300, 40)
	zoneText = text("ZoneText", zonePill, {
		Text = "",
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 1, -12),
		Font = Enum.Font.GothamBlack,
	})

	alert = glass("Alert", top, 14)
	alert.LayoutOrder = 2
	alert.Size = UDim2.fromOffset(500, 52)
	alert.BackgroundColor3 = RED
	alert.BackgroundTransparency = 0.3
	alert.Visible = false
	alertScale = Instance.new("UIScale")
	alertScale.Parent = alert
	alertText = text("AlertText", alert, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 1, -16),
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.3,
	})

	hintLabel = text("Hint", top, {
		LayoutOrder = 3,
		Size = UDim2.fromOffset(500, 30),
		TextStrokeTransparency = 0.2,
		Visible = false,
	})

	-- Top right: status ---------------------------------------------------
	local status = glass("Status", gui, 18)
	status.AnchorPoint = Vector2.new(1, 0)
	status.Position = UDim2.new(1, -16, 0.2, 0)
	status.Size = UDim2.fromOffset(260, 220)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = status

	local function small(name: string, y: number, label: string)
		return text(name, status, {
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(230, 236, 255),
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	small("CoinsTitle", 0, "COINS")
	coinsValue = text("CoinsValue", status, {
		Text = "0",
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	coinsScale = Instance.new("UIScale")
	coinsScale.Parent = coinsValue

	small("CarryTitle", 56, "CARRYING")
	carryValue = text("CarryValue", status, {
		Text = "—",
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	rarityText = text("Rarity", status, {
		Text = "",
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	small("VaultTitle", 120, "VAULT")
	vaultValue = text("VaultValue", status, {
		Text = "0 / 0",
		Position = UDim2.fromOffset(0, 136),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	dots = text("Dots", status, {
		Text = "",
		Position = UDim2.fromOffset(0, 158),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(150, 220, 255),
	})

	-- Time of day (night clouds only spawn at night)
	local clock = text("Clock", status, {
		Text = "",
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(0, 182),
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	task.spawn(function()
		local Lighting = game:GetService("Lighting")
		while true do
			local t = Lighting.ClockTime
			local night = workspace:GetAttribute("IsNight") == true
			clock.Text = string.format("%s  %02d:%02d", night and "NIGHT" or "DAY", math.floor(t), math.floor((t % 1) * 60))
			clock.TextColor3 = night and Color3.fromRGB(170, 160, 255) or Color3.fromRGB(255, 220, 140)
			task.wait(1)
		end
	end)

	-- Robbery flash --------------------------------------------------------
	alarmFlash = Instance.new("Frame")
	alarmFlash.Name = "AlarmFlash"
	alarmFlash.Size = UDim2.fromScale(1, 1)
	alarmFlash.BackgroundColor3 = RED
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
	if duration and duration > 0 then
		task.delay(duration, function()
			if hintToken == mine then
				hintLabel.Visible = false
			end
		end)
	end
end

-- Alert panel: urgent (red, blinking) or warning (amber, steady)
local alertToken = 0
local gateWarning: string? = nil
local function showAlert(message: string, urgent: boolean, duration: number)
	alertToken += 1
	local mine = alertToken
	alertText.Text = message
	alert.BackgroundColor3 = urgent and RED or AMBER
	alert.BackgroundTransparency = 0.3
	alert.Visible = true
	alertScale.Scale = 0.7
	TweenService:Create(alertScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.spawn(function()
		if urgent then
			for i = 1, 6 do
				if alertToken ~= mine then
					return
				end
				alert.BackgroundTransparency = (i % 2 == 1) and 0.05 or 0.45
				task.wait(0.25)
			end
			alert.BackgroundTransparency = 0.3
		end
		task.wait(duration)
		if alertToken == mine then
			if gateWarning then
				alertText.Text = gateWarning
				alert.BackgroundColor3 = AMBER
			else
				alert.Visible = false
			end
		end
	end)
end

local shownCoins = 0
local function animateCoins(target: number)
	local from = shownCoins
	shownCoins = target
	if target <= from then
		coinsValue.Text = tostring(target)
		return
	end
	coinsScale.Scale = 1.15
	TweenService:Create(coinsScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	for i = 1, 15 do
		if shownCoins ~= target then
			return
		end
		coinsValue.Text = tostring(math.floor(from + (target - from) * i / 15))
		task.wait(0.03)
	end
end

local function updateCarry()
	local kind = player:GetAttribute("Carrying")
	local def = kind and Weather.Types[kind]
	if not def then
		carryValue.Text = "Find a cloud!"
		carryValue.TextColor3 = Color3.fromRGB(200, 205, 220)
		rarityText.Text = ""
		return
	end
	local rarity = Weather.RarityOf(kind)
	carryValue.Text = def.DisplayName
	carryValue.TextColor3 = rarity.Color
	local stolen = player:GetAttribute("CarryingStolen")
	rarityText.Text = string.upper(rarity.Name) .. (stolen and "  -  STOLEN!" or "")
	rarityText.TextColor3 = stolen and RED or rarity.Color
end

local function updateVault()
	local filled = player:GetAttribute("VaultFilled") or 0
	local size = player:GetAttribute("VaultSize") or 0
	vaultValue.Text = `{filled} / {size}`
	vaultValue.TextColor3 = (size > 0 and filled >= size) and GOLD or Color3.new(1, 1, 1)
	dots.Text = string.rep("[#] ", filled) .. string.rep("[  ] ", math.max(0, size - filled))
end

-- v2.0: a small floating ARROW above your head while carrying (the old beam
-- to the nest became a huge vertical line from the continent). It points to
-- the Sky Heart hole while you're up on the continent (ride down), and to
-- your Nest once you're down at the hub.
local arrow: Model? = nil
local arrowConn: RBXScriptConnection? = nil
local function clearBeam()
	if arrowConn then
		arrowConn:Disconnect()
		arrowConn = nil
	end
	if arrow then
		arrow:Destroy()
		arrow = nil
	end
end

local function getNest()
	local map = workspace:FindFirstChild("Map")
	local roofs = map and map:FindFirstChild("Rooftops")
	local roofName = player:GetAttribute("Rooftop")
	local roof = roofs and roofName and roofs:FindFirstChild(roofName)
	return roof and roof:FindFirstChild("Nest")
end

local function arrowPart(parent: Instance, class: string, size: Vector3, color: Color3): BasePart
	local p = Instance.new(class) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Parent = parent
	return p
end

local function updateBeam()
	clearBeam()
	if not player:GetAttribute("Carrying") then
		return
	end
	local color = player:GetAttribute("CarryingStolen") and RED or GOLD
	local m = Instance.new("Model")
	m.Name = "CarryArrow"
	local shaft = arrowPart(m, "Part", Vector3.new(0.5, 0.25, 1.6), color)
	-- arrow head = a chevron of two bars (reads clearly from any angle)
	local headL = arrowPart(m, "Part", Vector3.new(0.45, 0.25, 1.3), color)
	local headR = arrowPart(m, "Part", Vector3.new(0.45, 0.25, 1.3), color)
	m.Parent = workspace.CurrentCamera
	arrow = m
	arrowConn = RunService.RenderStepped:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local goal: Vector3?
		if root.Position.Y > BiomeMap.UP - 50 then
			goal = Vector3.new(0, root.Position.Y, 0) -- the Sky Heart hole: ride the updraft down
		else
			local nest = getNest()
			goal = nest and (nest :: BasePart).Position
		end
		if not goal then
			return
		end
		local from = root.Position + Vector3.new(0, 4.6 + math.sin(os.clock() * 4) * 0.15, 0)
		local flat = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
		local look = flat.Magnitude > 0.5 and CFrame.lookAt(from, from + flat) or CFrame.new(from)
		shaft.CFrame = look * CFrame.new(0, 0, 0.4)
		headL.CFrame = look * CFrame.new(-0.35, 0, -0.75) * CFrame.Angles(0, math.rad(-40), 0)
		headR.CFrame = look * CFrame.new(0.35, 0, -0.75) * CFrame.Angles(0, math.rad(40), 0)
	end)
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

local function onDelivered(reward: number, _kind: string, shiny: boolean, nestPos: Vector3)
	floatText(nestPos, shiny and `* +{reward} *` or `+{reward}`, shiny and Weather.ShinyColor or GOLD)
	playSound(PING, 0.7, shiny and 0.8 or 1.2)
end

local function onStolen(thiefName: string, victimName: string, stormName: string)
	if victimName == player.DisplayName then
		showAlert(`{thiefName} stole your cloud!`, true, 3)
	else
		showAlert(`{thiefName} stole a cloud!`, true, 2.5)
	end
end

local function onAlarm(thiefName: string)
	showAlert("Someone is in your base!", true, 3) -- v2.35 director wording
	for i = 1, 3 do
		task.delay((i - 1) * 0.35, function()
			playSound(PING, 0.9, 0.6)
			alarmFlash.BackgroundTransparency = 0.7
			TweenService:Create(alarmFlash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		end)
	end
end

-- Which zone am I in? (Map/Zones volumes)
-- Where am I? 1) zone volumes (Map/Zones), 2) otherwise the ground under
-- your feet: continent floor parts carry ZoneName/ZoneColor/Warning (biomes).
local currentZoneName: string? = "__start" -- forces the first update
local function zoneLoop()
	local zones = workspace:WaitForChild("Map"):WaitForChild("Zones")
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { zones }
	local down = RaycastParams.new()
	down.FilterType = Enum.RaycastFilterType.Exclude
	while true do
		task.wait(0.25)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		-- zone info table { ZoneName, ZoneColor, Warning } from a zone volume,
		-- a tagged part under you, or BiomeMap when the ground is Terrain
		local zone = nil
		if root then
			local vol = workspace:GetPartBoundsInBox(root.CFrame, Vector3.one, params)[1]
			if vol then
				zone = { ZoneName = vol:GetAttribute("ZoneName"), ZoneColor = vol:GetAttribute("ZoneColor"), Warning = vol:GetAttribute("Warning") }
			else
				down.FilterDescendantsInstances = { char, workspace:FindFirstChild("Weather") }
				local info = BiomeMap.ZoneOfHit(workspace:Raycast(root.Position, Vector3.new(0, -40, 0), down))
				if info and info.ZoneName then
					zone = info
				end
			end
		end
		local name = zone and zone.ZoneName or nil
		if name ~= currentZoneName then
			-- keep showing the last biome while you're in the air
			if not zone and root and root.AssemblyLinearVelocity.Y < -5 then
				continue
			end
			currentZoneName = name
			if zone then
				zoneText.Text = name
				zoneText.TextColor3 = zone.ZoneColor or Color3.new(1, 1, 1)
			else
				-- never show a blank pill
				local fallback = "Skylands"
				local roofs = workspace.Map:FindFirstChild("Rooftops")
				for _, roof in roofs and roofs:GetChildren() or {} do
					if roof:GetAttribute("OwnerUserId") == player.UserId and root then
						local nest = roof:FindFirstChild("Nest", true)
						if nest and nest:IsA("BasePart") and (nest.Position - root.Position).Magnitude < 45 then
							fallback = "Your Base"
						end
					end
				end
				if fallback == "Skylands" and root and root.Position.Y > BiomeMap.UP - 50 then
					fallback = "Floating Continent"
				end
				zoneText.Text = fallback
				zoneText.TextColor3 = Color3.fromRGB(220, 230, 255)
			end
			zonePill.Visible = zoneText.Text ~= ""
			gateWarning = nil -- director: zone name only, no slogan under biome labels
			if gateWarning then
				showAlert(`{gateWarning}`, false, 4)
			elseif alert.BackgroundColor3 == AMBER then
				alert.Visible = false
			end
		end
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
	-- Solar Flare perk: someone blinded you
	remotes:WaitForChild("Dazzle").OnClientEvent:Connect(function(seconds: number)
		alarmFlash.BackgroundColor3 = Color3.fromRGB(255, 252, 235)
		alarmFlash.BackgroundTransparency = 0
		TweenService:Create(alarmFlash, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(seconds, function()
			alarmFlash.BackgroundColor3 = RED
		end)
	end)

	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		task.defer(function() -- wait for CarryingStolen to be set too
			updateCarry()
			updateBeam()
			if player:GetAttribute("Carrying") then
				playSound(PING, 0.5, 1.8)
			end
		end)
	end)
	player:GetAttributeChangedSignal("VaultFilled"):Connect(updateVault)
	player:GetAttributeChangedSignal("VaultSize"):Connect(updateVault)
	player.CharacterAdded:Connect(clearBeam)
	updateCarry()
	updateVault()

	task.spawn(function()
		local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue
		shownCoins = coins.Value
		coinsValue.Text = tostring(coins.Value)
		coins.Changed:Connect(function(v)
			task.spawn(animateCoins, v)
		end)
	end)
	task.spawn(zoneLoop)
end

return Hud
