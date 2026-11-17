-- Brief ragdoll when you get hit (laser, Quake, lightning).
-- The server sets player attribute RagdollUntil (server time, Config.RagdollTime
-- = 1.2 s). This client owns its character's physics, so it swaps the joints
-- for ball sockets locally; the limb positions replicate to everyone.
-- Recovery is guaranteed: a timer always restores the joints and puts the
-- humanoid back into GettingUp, even if a newer hit extended the ragdoll.
-- A carried cloud stays on its leash (rules for dropping are unchanged).

local Players = game:GetService("Players")

local Ragdoll = {}

local player = Players.LocalPlayer
local active: { Motors: { Motor6D }, Made: { Instance }, Collide: { [BasePart]: boolean } }? = nil

local function stop(char: Model)
	local st = active
	active = nil
	if not st then
		return
	end
	for _, inst in st.Made do
		inst:Destroy()
	end
	for _, m in st.Motors do
		if m.Parent then
			m.Enabled = true
		end
	end
	for p, was in st.Collide do
		if p.Parent then
			p.CanCollide = was
		end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function start(char: Model)
	if active then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local st = { Motors = {}, Made = {}, Collide = {} }
	for _, m in char:GetDescendants() do
		if m:IsA("Motor6D") and m.Name ~= "Root" and m.Part0 and m.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollA0"
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollA1"
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local ball = Instance.new("BallSocketConstraint")
			ball.Name = "RagdollJoint"
			ball.Attachment0 = a0
			ball.Attachment1 = a1
			ball.LimitsEnabled = true
			ball.UpperAngle = m.Name == "Neck" and 30 or 70
			ball.TwistLimitsEnabled = true
			ball.TwistLowerAngle = -35
			ball.TwistUpperAngle = 35
			ball.Parent = m.Part1
			table.insert(st.Made, a0)
			table.insert(st.Made, a1)
			table.insert(st.Made, ball)
			m.Enabled = false
			table.insert(st.Motors, m)
			-- limbs must collide with the floor while floppy
			local p1 = m.Part1 :: BasePart
			if st.Collide[p1] == nil then
				st.Collide[p1] = p1.CanCollide
				p1.CanCollide = true
			end
		end
	end
	active = st
	hum.PlatformStand = true
end

local function check()
	local char = player.Character
	if not char then
		return
	end
	local untilT = player:GetAttribute("RagdollUntil") or 0
	local left = untilT - workspace:GetServerTimeNow()
	if left > 0.05 then
		start(char)
		task.delay(left, check) -- re-check: a later hit may have extended it
	elseif active then
		stop(char)
	end
end

function Ragdoll.Start()
	player:GetAttributeChangedSignal("RagdollUntil"):Connect(check)
	player.CharacterAdded:Connect(function()
		active = nil -- the old character took its constraints with it
	end)
end

return Ragdoll
