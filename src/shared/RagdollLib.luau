-- Ball-socket ragdoll for any R15 character (players on their own client,
-- the Studio test dummy on the server). Enable() swaps every Motor6D except
-- the Root joint for a limited BallSocketConstraint and lets limbs collide;
-- Disable() restores everything exactly. Whoever owns the physics must call it.

local RagdollLib = {}

export type State = { Motors: { Instance }, Made: { Instance }, Collide: { [BasePart]: boolean } }

function RagdollLib.Enable(char: Model): State?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local st: State = { Motors = {}, Made = {}, Collide = {} }
	for _, m in char:GetDescendants() do
		-- newer avatar rigs drive joints with AnimationConstraints instead of
		-- Motor6Ds: those get a ball socket on their own two attachments
		if m:IsA("AnimationConstraint") and m.Name ~= "Root" and m.Enabled and m.Attachment0 and m.Attachment1 then
			local ball = Instance.new("BallSocketConstraint")
			ball.Name = "RagdollJoint"
			ball.Attachment0 = m.Attachment0
			ball.Attachment1 = m.Attachment1
			ball.LimitsEnabled = true
			ball.UpperAngle = 70
			ball.TwistLimitsEnabled = true
			ball.TwistLowerAngle = -35
			ball.TwistUpperAngle = 35
			ball.Parent = m.Parent
			table.insert(st.Made, ball)
			m.Enabled = false
			table.insert(st.Motors, m)
			local p1 = (m.Attachment1 :: Attachment).Parent
			if p1 and p1:IsA("BasePart") and st.Collide[p1] == nil then
				st.Collide[p1] = p1.CanCollide
				p1.CanCollide = true
			end
			continue
		end
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
			local p1 = m.Part1 :: BasePart
			if st.Collide[p1] == nil then
				st.Collide[p1] = p1.CanCollide
				p1.CanCollide = true -- floppy limbs must rest on the floor
			end
		end
	end
	hum.PlatformStand = true
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	return st
end

function RagdollLib.Disable(char: Model, st: State?)
	if not st then
		return
	end
	for _, inst in st.Made do
		inst:Destroy()
	end
	for _, m in st.Motors do
		if m.Parent then
			(m :: any).Enabled = true
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

return RagdollLib
