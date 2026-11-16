-- Puddle effects on your own character: slip / ice road / launch pad.
-- The server creates puddles with a "Kind" attribute; we just react.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Movement = {}

local player = Players.LocalPlayer
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

function Movement.Start()
	player:GetAttributeChangedSignal("BaseSpeed"):Connect(applySpeed)

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
end

return Movement
