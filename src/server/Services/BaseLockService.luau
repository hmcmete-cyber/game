-- Base Lock: each base has a LockPad. The owner steps on it -> a big
-- ForceField shield covers the base for Config.LockDuration seconds. While it's
-- up, rivals are pushed out and can't steal. Then it recharges for
-- Config.LockCooldown seconds.
--
-- Map contract: RooftopN/LockPad (Part). If missing, one is created next to
-- the Nest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local BaseLock = {}

local MapService, Remotes
local state = {} -- [roof Model] = { LockedUntil, CooldownUntil, Shield, Owner, LastHint }

local READY = Color3.fromRGB(90, 255, 140)
local LOCKED = Color3.fromRGB(110, 210, 255)
local RECHARGE = Color3.fromRGB(170, 170, 185)

function BaseLock.IsLocked(roof: Instance?): boolean
	local st = roof and state[roof]
	return st ~= nil and os.clock() < st.LockedUntil
end

local function getPad(roof: Model): BasePart?
	local pad = roof:FindFirstChild("LockPad")
	if pad then
		return pad
	end
	local nest = roof:FindFirstChild("Nest") :: BasePart
	if not nest then
		return nil
	end
	pad = Instance.new("Part")
	pad.Name = "LockPad"
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.5, 3.5, 3.5)
	pad.CFrame = CFrame.new(nest.Position + Vector3.new(0, 0, -8.5)) * CFrame.Angles(0, 0, math.pi / 2)
	pad.Color = READY
	pad.Material = Enum.Material.Neon
	pad.Anchored = true
	pad.Parent = roof
	return pad
end

local function setPadLook(pad: BasePart, color: Color3, text: string)
	pad.Color = color
	local gui = pad:FindFirstChild("Status")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Status"
		gui.Size = UDim2.fromOffset(160, 40)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.MaxDistance = 70
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
		gui.Parent = pad
	end
	gui.Text.Text = text
	gui.Text.TextColor3 = color
end

local function raiseShield(roof: Model, nest: BasePart): BasePart
	local shield = Instance.new("Part")
	shield.Name = "Shield"
	shield.Shape = Enum.PartType.Ball
	shield.Size = Vector3.one
	shield.CFrame = CFrame.new(nest.Position + Vector3.new(0, 2, 0))
	shield.Color = LOCKED
	shield.Material = Enum.Material.ForceField
	shield.Transparency = 0
	shield.Anchored = true
	shield.CanCollide = false
	shield.CanQuery = false
	shield.CanTouch = false
	shield.CastShadow = false
	shield.Parent = roof
	TweenService:Create(shield, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.one * (Config.ShieldRadius * 2 + 2),
	}):Play()
	return shield
end

local function dropShield(shield: BasePart?)
	if not shield then
		return
	end
	local t = TweenService:Create(shield, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.one,
		Transparency = 1,
	})
	t.Completed:Connect(function()
		shield:Destroy()
	end)
	t:Play()
end

local function tryLock(player: Player, roof: Model, nest: BasePart)
	local now = os.clock()
	local st = state[roof]
	if st and now < st.LockedUntil then
		return
	end
	if st and now < st.CooldownUntil then
		if now - (st.LastHint or 0) > 3 then
			st.LastHint = now
			Remotes.Hint:FireClient(player, `Shield recharging — {math.ceil(st.CooldownUntil - now)}s`, 2)
		end
		return
	end
	if st and st.Shield then
		st.Shield:Destroy()
	end
	state[roof] = {
		Owner = player,
		LockedUntil = now + Config.LockDuration,
		CooldownUntil = now + Config.LockDuration + Config.LockCooldown,
		Shield = raiseShield(roof, nest),
		LastHint = now,
	}
	roof:SetAttribute("Locked", true)
	Remotes.Hint:FireClient(player, `Base locked for {Config.LockDuration}s — nobody can steal!`, 4)
end

-- Shield Generator item: raise the shield right now, ignoring the recharge
function BaseLock.ForceLock(player: Player, seconds: number)
	local roof = MapService.GetRooftop(player)
	local nest = roof and roof:FindFirstChild("Nest")
	if not nest then
		return
	end
	local now = os.clock()
	local st = state[roof]
	if st and st.Shield and now < st.LockedUntil then
		st.LockedUntil = math.max(st.LockedUntil, now + seconds)
	else
		if st and st.Shield then
			st.Shield:Destroy()
		end
		state[roof] = {
			Owner = player,
			LockedUntil = now + seconds,
			CooldownUntil = math.max(st and st.CooldownUntil or 0, now + seconds),
			Shield = raiseShield(roof, nest),
			LastHint = now,
		}
	end
	roof:SetAttribute("Locked", true)
	Remotes.Hint:FireClient(player, `Shield Generator: base locked for {math.floor(seconds)} s!`, 3)
end

-- Push a rival out of the shield
local function pushOut(root: BasePart, nest: BasePart)
	local flat = Vector3.new(root.Position.X - nest.Position.X, 0, root.Position.Z - nest.Position.Z)
	if flat.Magnitude >= Config.ShieldRadius or math.abs(root.Position.Y - nest.Position.Y) > 25 then
		return
	end
	local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.xAxis
	local target = nest.Position + dir * (Config.ShieldRadius + 3)
	root.CFrame = CFrame.new(target.X, root.Position.Y + 1, target.Z) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = dir * 35 + Vector3.new(0, 25, 0)
end

local function loop()
	while true do
		task.wait(0.2)
		local now = os.clock()

		-- Owners pressing their pad
		for _, player in Players:GetPlayers() do
			local roof = MapService.GetRooftop(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local nest = roof and roof:FindFirstChild("Nest")
			local pad = roof and getPad(roof)
			if root and nest and pad then
				local flat = Vector3.new(root.Position.X - pad.Position.X, 0, root.Position.Z - pad.Position.Z)
				if flat.Magnitude <= Config.LockPadRadius and math.abs(root.Position.Y - pad.Position.Y) < 6 then
					tryLock(player, roof, nest)
				end
			end
		end

		-- Shields, pad labels
		for _, roof in workspace.Map.Rooftops:GetChildren() do
			local pad = roof:FindFirstChild("Nest") and getPad(roof)
			if not pad then
				continue
			end
			local st = state[roof]
			if st and (not st.Owner.Parent or MapService.GetRooftop(st.Owner) ~= roof) then
				-- owner left
				dropShield(st.Shield)
				state[roof] = nil
				roof:SetAttribute("Locked", nil)
				st = nil
			end

			if st and now < st.LockedUntil then
				setPadLook(pad, LOCKED, `{math.ceil(st.LockedUntil - now)}s`)
				local nest = roof.Nest
				for _, player in Players:GetPlayers() do
					if player ~= st.Owner then
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						if root then
							pushOut(root, nest)
						end
					end
				end
			else
				if st and st.Shield then
					dropShield(st.Shield)
					st.Shield = nil
					roof:SetAttribute("Locked", nil)
					if st.Owner.Parent then
						Remotes.Hint:FireClient(st.Owner, "Your shield is down — guard your clouds!", 4)
					end
				end
				if st and now < st.CooldownUntil then
					setPadLook(pad, RECHARGE, `{math.ceil(st.CooldownUntil - now)}s`)
				else
					setPadLook(pad, READY, roof:GetAttribute("OwnerUserId") and "LOCK BASE" or "")
				end
			end
		end
	end
end

function BaseLock.Start(mapService, remotes)
	MapService = mapService
	Remotes = remotes
	task.spawn(loop)
end

return BaseLock
