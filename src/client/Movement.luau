-- Everything that changes how YOUR character moves:
--   Puddles (from Rain clouds): Slip / Ice road / Launch pad
--   Hazards (Map/Hazards):
--     Ice Path      -> you lose grip: your velocity only slowly follows your input.
--                     Carrying a cloud = much less grip + random slips.
--                     Frost Grip perk (Snow Cloud) = full grip.
--     Electric      -> slower (damage is done by the server). Grounded perk (Cumulonimbus) = immune.
--     Electric River-> pulses Calm/Warn/Shock (same clock as the server): slower,
--                     much slower while shocking. Grounded perk (Cumulonimbus) = immune.
--     Storm Bridge  -> side wind gusts push you (worse with a cloud: it's a balloon!)
--   Lightning knockback (server Knock remote)
--   Perks (PerkSpeed, PerkJump, NoSlip, IceGrip, WindImmune, ElectricImmune)
--   Shop items (SpeedUntil/SpeedMult, JumpUntil/JumpMult, NitroUntil)
--
-- The ice slide uses a LinearVelocity constraint (plane mode) so the Humanoid's
-- own walking can't instantly cancel the slide.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Movement = {}
local PlayerAnimator = require(script.Parent:WaitForChild("PlayerAnimator"))

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

-- Same clock as HazardService: Calm -> Warn -> Shock
local function riverShocking(): boolean
	local period = Config.RiverCalm + Config.RiverWarn + Config.RiverShock
	return workspace:GetServerTimeNow() % period >= Config.RiverCalm + Config.RiverWarn
end

-- Frost Grip perk (Snow Cloud equipped) = full control on Ice Paths
local function skatesOn(): boolean
	return player:GetAttribute("IceGrip") == true
end

local function active(untilAttr: string): boolean
	return (player:GetAttribute(untilAttr) or 0) > workspace:GetServerTimeNow()
end

local function getHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

-- Speed & jump = base × perks × potions. Recomputed every frame (cheap),
-- so perks, potions and hazards always combine correctly.
local function applySpeed()
	local hum = getHumanoid()
	if not hum then
		return
	end
	local speed = baseSpeed()
	if onIceRoad then
		speed += Config.IceBoost
	end
	if active("NitroUntil") then
		speed += Config.NitroBoost
	end
	speed *= player:GetAttribute("PerkSpeed") or 1
	speed *= player:GetAttribute("UpgradeSpeed") or 1 -- Aurelius
	if active("LaserSlowUntil") then
		speed *= Config.LaserSlow -- hit by a Laser Gun
	end
	if active("ShockedUntil") and not player:GetAttribute("ElectricImmune") then
		speed *= Config.StormAuraSlow -- someone's Thunder Storm static field
	end
	if active("SpeedUntil") then
		speed *= player:GetAttribute("SpeedMult") or 1
	end
	if active("MonsterSlowUntil") then
		speed *= player:GetAttribute("MonsterSlow") or 0.6 -- monster frost / spores / shards
	end
	local immune = player:GetAttribute("ElectricImmune")
	if inSwamp and not immune then
		speed *= Config.ElectricSlow
	end
	if inRiver and not immune then
		speed *= riverShock and Config.RiverSlowShock or Config.RiverSlowCalm
	end

	local carrying = player:GetAttribute("Carrying") ~= nil
	local jump = (carrying and Config.CarryJumpHeight or 7.2) * (player:GetAttribute("PerkJump") or 1)
		* (player:GetAttribute("UpgradeJump") or 1)
	if active("JumpUntil") then
		jump *= player:GetAttribute("JumpMult") or 1
	end
	if active("RootedUntil") then
		speed, jump = 0, 0 -- held by roots / a bite
	end

	if math.abs(hum.WalkSpeed - speed) > 0.01 then
		hum.WalkSpeed = speed
	end
	if math.abs(hum.JumpHeight - jump) > 0.01 then
		hum.UseJumpPower = false
		hum.JumpHeight = jump
	end
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

------------------------------------------------------------------------
-- Air columns (hub updraft)
--
-- Inside a column a LinearVelocity constraint carries you up at a steady
-- speed (it can't be cancelled by gravity or the Humanoid like plain
-- velocity edits could) and gently centres you in the column.
-- At ExitHeight you get ONE launch whose velocity is computed so the arc
-- lands exactly on LaunchTarget (the sky landing) — no more falling short.
-- Column attributes: Lift (studs/s), ExitHeight, LaunchTarget (Vector3),
-- LaunchTime (s). Old columns with only Lift/PushX/PushZ still work.
------------------------------------------------------------------------

local airLift: LinearVelocity? = nil
-- Low-gravity perks (Gravity = fraction of gravity removed): an upward force
local gravityForce: VectorForce? = nil
local function updateGravity(root: BasePart)
	local frac = player:GetAttribute("Gravity") or 0
	if frac <= 0 then
		if gravityForce then
			gravityForce.Enabled = false
		end
		return
	end
	if not gravityForce or gravityForce.Parent ~= root then
		local att = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
		local vf = Instance.new("VectorForce")
		vf.Name = "LowGravity"
		vf.Attachment0 = att :: Attachment
		vf.RelativeTo = Enum.ActuatorRelativeTo.World
		vf.ApplyAtCenterOfMass = true
		vf.Parent = root
		gravityForce = vf
	end
	local vf = gravityForce :: VectorForce
	vf.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * frac, 0)
	vf.Enabled = true
end

local updateAir -- defined below
local launchedFrom: Instance? = nil
local airParams: OverlapParams

local function getAirLift(root: BasePart): LinearVelocity
	if airLift and airLift.Parent == root then
		return airLift
	end
	local att = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
	local lv = Instance.new("LinearVelocity")
	lv.Name = "AirLift"
	lv.Attachment0 = att :: Attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = 200000
	lv.Enabled = false
	lv.Parent = root
	airLift = lv
	return lv
end

-- v1.8 DIRECTIONAL: the direction is latched once when you enter a column
--   from BELOW (anywhere under ExitHeight-12)  -> "Up": ride up, one launch
--   from ABOVE (dropping in near the top)      -> "Down": carried down at
--        DownSpeed, braking near the bottom, released when you touch ground
-- The latch only clears after you leave the column, so there is no flip-flop
-- at the boundary and no second launch; after landing you walk out to reset.
local awaitLanding: (Humanoid, string) -> ()
local airMode: string? = nil
local diving = false

-- play `anim` the moment the humanoid touches ground again (max 4 s)
awaitLanding = function(hum: Humanoid, anim: string)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 4 and hum.Parent and hum.FloorMaterial == Enum.Material.Air do
			task.wait()
		end
		if hum.Parent and hum.Health > 0 then
			PlayerAnimator.Play(anim)
		end
	end)
end

function Movement.AirMode(): string?
	return airMode
end

updateAir = function(root: BasePart, hum: Humanoid)
	local column = workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(2, 2, 2), airParams)[1]
	local lv = getAirLift(root)
	if not column or slipping then
		lv.Enabled = false
		if not column then
			launchedFrom = nil
			airMode = nil
			if diving then
				diving = false
				PlayerAnimator.Stop("UpdraftDive")
			end
		end
		return
	end
	if launchedFrom == column then
		lv.Enabled = false -- already launched / landed in this column
		return
	end

	local lift = column:GetAttribute("Lift") or 0
	local exitHeight = column:GetAttribute("ExitHeight")
	local target = column:GetAttribute("LaunchTarget")
	local bottomY = column:GetAttribute("BottomY") or (column.Position.Y - column.Size.X / 2)

	if airMode == nil then
		-- v2.4: direction comes from WHERE you enter, never from your speed.
		-- Anyone entering in the top part of the column (the Sky Heart hole,
		-- jumping, falling or brushing the rim) rides DOWN; anyone entering
		-- in the lower part rides UP. (Before, jumping into the hole still had
		-- upward speed, counted as "from below" and got launched back up.)
		local topY = column.Position.Y + column.Size.X / 2 -- cylinder stands on its X axis
		local fromAbove = exitHeight ~= nil and root.Position.Y > math.min(exitHeight, topY) - 40
		airMode = fromAbove and "Down" or "Up"
	end

	-- keep riders centred in the column
	local axis = column.Position
	local toAxis = Vector3.new(axis.X - root.Position.X, 0, axis.Z - root.Position.Z)
	local drift = toAxis * 2
	if drift.Magnitude > 12 then
		drift = drift.Unit * 12
	end

	if airMode == "Down" then
		local height = root.Position.Y - bottomY
		if height < 4 or (height < 10 and hum.FloorMaterial ~= Enum.Material.Air) then
			lv.Enabled = false
			launchedFrom = column -- landed: no re-lift until you step out
			root.AssemblyLinearVelocity = Vector3.new(0, math.max(root.AssemblyLinearVelocity.Y, -8), 0)
			PlayerAnimator.Stop("UpdraftDive")
			awaitLanding(hum, "UpdraftDropLand")
			return
		end
		if not diving then
			diving = true
			PlayerAnimator.Play("UpdraftDive")
		end
		local speed = column:GetAttribute("DownSpeed") or 70
		local down = height < 24 and math.max(10, speed * height / 24) or speed -- brake near the floor
		lv.VectorVelocity = Vector3.new(drift.X, -down, drift.Z)
		lv.Enabled = true
		if hum:GetState() ~= Enum.HumanoidStateType.Freefall then
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		return
	end

	if airMode == "Up" and exitHeight and typeof(target) == "Vector3" and root.Position.Y >= exitHeight then
		-- Ballistic launch: reach `target` in exactly T seconds under gravity.
		-- v2.0: a Humanoid in the air pulls its sideways speed back toward
		-- walking speed, which ate the launch and dropped players back into
		-- the hole. A Plane LinearVelocity now holds the sideways speed for
		-- the whole flight, then lets go.
		local T = column:GetAttribute("LaunchTime") or 0.9
		local g = workspace.Gravity
		local d = target - root.Position
		local v = Vector3.new(d.X / T, (d.Y + 0.5 * g * T * T) / T, d.Z / T)
		lv.Enabled = false
		launchedFrom = column
		root.AssemblyLinearVelocity = v
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		local att = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
		local carry = Instance.new("LinearVelocity")
		carry.Name = "LaunchCarry"
		carry.Attachment0 = att :: Attachment
		carry.RelativeTo = Enum.ActuatorRelativeTo.World
		carry.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		carry.PrimaryTangentAxis = Vector3.xAxis
		carry.SecondaryTangentAxis = Vector3.zAxis
		carry.PlaneVelocity = Vector2.new(v.X, v.Z)
		carry.MaxForce = 60000
		carry.Parent = root
		task.delay(T, function()
			carry:Destroy()
		end)
		PlayerAnimator.Play("UpdraftLaunch")
		awaitLanding(hum, "UpdraftLand")
		return
	end

	local push = Vector3.zero
	local pushAbove = column:GetAttribute("PushAbove")
	if pushAbove and root.Position.Y >= pushAbove then -- legacy columns
		push = Vector3.new(column:GetAttribute("PushX") or 0, 0, column:GetAttribute("PushZ") or 0)
		drift = Vector3.zero
	end
	lv.VectorVelocity = Vector3.new(drift.X + push.X, lift, drift.Z + push.Z)
	lv.Enabled = true
	if lift > 0 and hum:GetState() ~= Enum.HumanoidStateType.Freefall then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

function Movement.Start()
	player:GetAttributeChangedSignal("BaseSpeed"):Connect(applySpeed)
	-- monster Permafrost Slam / Sprout trip: slip right now
	player:GetAttributeChangedSignal("SlipAt"):Connect(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root and not slipping then
			slip(hum, root :: BasePart)
		end
	end)
	player:GetAttributeChangedSignal("ElectricImmune"):Connect(applySpeed)
	player:GetAttributeChangedSignal("NitroUntil"):Connect(function()
		applySpeed()
		local untilT = player:GetAttribute("NitroUntil") or 0
		task.delay(math.max(0, untilT - workspace:GetServerTimeNow()) + 0.05, applySpeed)
	end)

	-- Grappling Hook: zip toward the hooked point (we own our character's physics)
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Grapple").OnClientEvent:Connect(function(point: Vector3)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum then
			return
		end
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		local started = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local toPoint = point + Vector3.new(0, 3, 0) - root.Position
			if toPoint.Magnitude < 4 or os.clock() - started > 1.6 or not root.Parent then
				conn:Disconnect()
				root.AssemblyLinearVelocity = root.AssemblyLinearVelocity * 0.4 + Vector3.new(0, 20, 0)
				return
			end
			root.AssemblyLinearVelocity = toPoint.Unit * Config.GrappleSpeed
		end)
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
		airLift = nil
		launchedFrom = nil
		onIceRoad, onIceHazard, inSwamp, inRiver = false, false, false, false
	end)

	local weather = workspace:WaitForChild("Weather")
	local puddles = weather:WaitForChild("Puddles")
	local hazards = workspace:WaitForChild("Map"):WaitForChild("Hazards")

	local puddleParams = OverlapParams.new()
	puddleParams.FilterType = Enum.RaycastFilterType.Include
	puddleParams.FilterDescendantsInstances = { puddles }

	-- Air columns (hub updraft / descent chute)
	local airFolder = workspace:WaitForChild("Map"):WaitForChild("AirColumns")
	airParams = OverlapParams.new()
	airParams.FilterType = Enum.RaycastFilterType.Include
	airParams.FilterDescendantsInstances = { airFolder }

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
			elseif kind == "Slip" and moving and not slipping and now - lastSlip > Config.SlipCooldown
				and not player:GetAttribute("NoSlip") then
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
		if storm and not slipping and not player:GetAttribute("WindImmune") then
			local t = os.clock()
			local gust = math.sin(t * 0.7) + 0.5 * math.sin(t * 1.9 + 1)
			local strength = Config.WindStrength * (player:GetAttribute("Carrying") and 1.5 or 1)
			-- bridges run along Z, so the wind blows along X (across the bridge)
			root.CFrame += Vector3.xAxis * gust * strength * dt
		end

		updateIce(hum, root, dt)
		applySpeed()

		updateAir(root, hum)
		updateGravity(root)
	end)
end

return Movement
