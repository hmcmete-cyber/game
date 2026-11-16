-- Everything that changes how YOUR character moves:
--   Puddles (from Rain clouds): Slip / Ice road / Launch pad
--   Hazards (Map/Hazards):
--     Ice Path      → you lose grip: your velocity only slowly follows your input.
--                     Carrying a cloud = much less grip + random slips.
--                     Frost Skates (Ice Charm, Q) = full grip + speed boost.
--     Electric      → slower (damage is done by the server). Storm Charm = immune.
--     Electric River→ pulses Calm/Warn/Shock (same clock as the server): slower,
--                     much slower while shocking. Storm Charm = immune.
--     Storm Bridge  → side wind gusts push you (worse with a cloud: it's a balloon!)
--   Lightning knockback (server Knock remote), Nitro speed burst (NitroUntil)
--
-- The ice slide uses a LinearVelocity constraint (plane mode) so the Humanoid's
-- own walking can't instantly cancel the slide.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Movement = {}

local player = Players.LocalPlayer
local onIceRoad = false
local onIceHazard = false
local inSwamp = false
local inRiver = false
local riverShock = false
local slipping = false
local lastSlip = 0
local lastLaunch = 0

local slide: LinearVelocity? = nil
local slideVel = Vector2.zero

local function baseSpeed(): number
	return player:GetAttribute("BaseSpeed") or Config.WalkSpeed
end

-- Same clock as HazardService: Calm → Warn → Shock
local function riverShocking(): boolean
	local period = Config.RiverCalm + Config.RiverWarn + Config.RiverShock
	return workspace:GetServerTimeNow() % period >= Config.RiverCalm + Config.RiverWarn
end

local function skatesOn(): boolean
	return (player:GetAttribute("SkatesUntil") or 0) > workspace:GetServerTimeNow()
end

local function getHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function applySpeed()
	local hum = getHumanoid()
	if not hum then
		return
	end
	local speed = baseSpeed()
	if onIceRoad then
		speed += Config.IceBoost
	end
	if onIceHazard and skatesOn() then
		speed += Config.SkatesBoost
	end
	local immune = player:GetAttribute("ElectricImmune")
	if inSwamp and not immune then
		speed *= Config.ElectricSlow
	end
	if inRiver and not immune then
		speed *= riverShock and Config.RiverSlowShock or Config.RiverSlowCalm
	end
	if (player:GetAttribute("NitroUntil") or 0) > workspace:GetServerTimeNow() then
		speed += Config.NitroBoost
	end
	hum.WalkSpeed = speed
end

local function slip(hum: Humanoid, root: BasePart)
	slipping = true
	lastSlip = os.clock()
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

local function getSlide(root: BasePart): LinearVelocity
	if slide and slide.Parent == root then
		return slide
	end
	local att = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
	local lv = Instance.new("LinearVelocity")
	lv.Name = "IceSlide"
	lv.Attachment0 = att :: Attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = 60000
	lv.Enabled = false
	lv.Parent = root
	slide = lv
	return lv
end

local function updateIce(hum: Humanoid, root: BasePart, dt: number)
	local lv = getSlide(root)
	if not onIceHazard or skatesOn() or slipping then
		if lv.Enabled then
			lv.Enabled = false
		end
		local v = root.AssemblyLinearVelocity
		slideVel = Vector2.new(v.X, v.Z)
		return
	end

	-- Low grip: velocity creeps toward where you want to go
	local carrying = player:GetAttribute("Carrying") ~= nil
	local traction = carrying and Config.IceTractionCarrying or Config.IceTraction
	local desired = Vector2.new(hum.MoveDirection.X, hum.MoveDirection.Z) * hum.WalkSpeed
	slideVel = slideVel:Lerp(desired, math.clamp(dt * traction, 0, 1))
	lv.PlaneVelocity = slideVel
	lv.Enabled = true

	-- With a heavy cloud you can lose your footing completely
	if carrying and os.clock() - lastSlip > Config.SlipCooldown and math.random() < dt * Config.IceSlipChance then
		lv.Enabled = false
		slip(hum, root)
	end
end

function Movement.Start()
	player:GetAttributeChangedSignal("BaseSpeed"):Connect(applySpeed)
	player:GetAttributeChangedSignal("SkatesUntil"):Connect(function()
		applySpeed()
		-- re-check when skates expire
		local untilT = player:GetAttribute("SkatesUntil") or 0
		task.delay(math.max(0, untilT - workspace:GetServerTimeNow()) + 0.05, applySpeed)
	end)
	player:GetAttributeChangedSignal("ElectricImmune"):Connect(applySpeed)
	player:GetAttributeChangedSignal("NitroUntil"):Connect(function()
		applySpeed()
		local untilT = player:GetAttribute("NitroUntil") or 0
		task.delay(math.max(0, untilT - workspace:GetServerTimeNow()) + 0.05, applySpeed)
	end)

	-- Lightning knockback from the server
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Knock").OnClientEvent:Connect(function(velocity: Vector3)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum then
			if slide then
				slide.Enabled = false
			end
			root.AssemblyLinearVelocity = velocity
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end)
	player.CharacterAdded:Connect(function()
		slide = nil
		onIceRoad, onIceHazard, inSwamp, inRiver = false, false, false, false
	end)

	local weather = workspace:WaitForChild("Weather")
	local puddles = weather:WaitForChild("Puddles")
	local hazards = workspace:WaitForChild("Map"):WaitForChild("Hazards")

	local puddleParams = OverlapParams.new()
	puddleParams.FilterType = Enum.RaycastFilterType.Include
	puddleParams.FilterDescendantsInstances = { puddles }

	local hazardParams = OverlapParams.new()
	hazardParams.FilterType = Enum.RaycastFilterType.Include
	hazardParams.FilterDescendantsInstances = { hazards }

	RunService.Heartbeat:Connect(function(dt)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 then
			return
		end

		local feet = root.CFrame * CFrame.new(0, -3, 0)
		local now = os.clock()

		-- Puddles
		local iceRoad = false
		local moving = hum.MoveDirection.Magnitude > 0.1
		for _, p in workspace:GetPartBoundsInBox(feet, Vector3.new(2.5, 2.5, 2.5), puddleParams) do
			local kind = p:GetAttribute("Kind")
			if kind == "Ice" then
				iceRoad = true
			elseif kind == "Launch" and now - lastLaunch > 1 then
				lastLaunch = now
				launch(root)
			elseif kind == "Slip" and moving and not slipping and now - lastSlip > Config.SlipCooldown then
				local owner = p:GetAttribute("OwnerUserId")
				local created = p:GetAttribute("CreatedAt") or 0
				local fresh = workspace:GetServerTimeNow() - created < Config.OwnerPuddleGrace
				if not (owner == player.UserId and fresh) then
					slip(hum, root)
				end
			end
		end

		-- Hazards
		local ice, swamp, river, storm = false, false, false, false
		for _, h in workspace:GetPartBoundsInBox(feet, Vector3.new(2, 3, 2), hazardParams) do
			local t = h:GetAttribute("HazardType")
			if t == "Ice" then
				ice = true
			elseif t == "Electric" then
				swamp = true
			elseif t == "River" then
				river = true
			elseif t == "Storm" then
				storm = true
			end
		end
		local shock = river and riverShocking()

		if iceRoad ~= onIceRoad or ice ~= onIceHazard or swamp ~= inSwamp or river ~= inRiver or shock ~= riverShock then
			onIceRoad, onIceHazard, inSwamp, inRiver, riverShock = iceRoad, ice, swamp, river, shock
			applySpeed()
		end

		-- Storm Bridge: side gusts (a cloud on a leash catches extra wind)
		if storm and not slipping then
			local t = os.clock()
			local gust = math.sin(t * 0.7) + 0.5 * math.sin(t * 1.9 + 1)
			local strength = Config.WindStrength * (player:GetAttribute("Carrying") and 1.5 or 1)
			-- bridges run along Z, so the wind blows along X (across the bridge)
			root.CFrame += Vector3.xAxis * gust * strength * dt
		end

		updateIce(hum, root, dt)
	end)
end

return Movement
