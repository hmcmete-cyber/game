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
	root.AssemblyLinearVelocity = dir * Config.SlipPush + Vector3.new(0, 18, 0)
	root.AssemblyAngularVelocity = Vector3.new(dir.Z, 0, -dir.X) * 8
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
