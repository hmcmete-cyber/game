-- v2.15 PET ANIMATIONS (client side, smooth and free for the server).
-- Every pet piece carries a PetRole (PetModels) and is held by a Weld
-- "PetJoint"; this module moves the joints locally every frame:
--   Idle     breathing bob, head nods, tail wag, slow wing beat, ear/arm sway,
--            tentacle sway, orbiters circling
--   Walk     legs swing in trot pairs, faster wings, bouncy head, quick tail
--   Attack   (AnimKind "Attack", Bite/Bolt pets) wind-up, lunge forward with
--            arms/head snapping, recoil
--   Special  (AnimKind "Special", Lob/Pulse/Chain pets) crouch, hop with a
--            full spin and wings/arms thrown wide, landing squash
-- The server only moves the pet's Root and sets AnimKind / AnimAt.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PetAnimator = {}

local pets = {} -- [Model] = { Joints = { { Weld, Base, Role, Size, Side, Index } }, LastPos, Speed, Phase }
local A = CFrame.Angles

local function track(model: Instance)
	if not model:IsA("Model") or pets[model] or not model:GetAttribute("PetId") or model:GetAttribute("NoAnim") then
		return
	end
	local joints = {}
	for _, w in model:GetDescendants() do
		if w:IsA("Weld") and w.Name == "PetJoint" and w.Part1 then
			local p = w.Part1
			table.insert(joints, {
				Weld = w, Base = w.C0, Role = p:GetAttribute("PetRole") or "Body", Size = p.Size,
				Side = w.C0.Position.X >= 0 and 1 or -1, Front = w.C0.Position.Z < 0 and 1 or -1, Index = #joints,
			})
		end
	end
	pets[model] = { Joints = joints, LastPos = model:GetPivot().Position, Speed = 0, Phase = math.random() * 6 }
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			pets[model] = nil
		end
	end)
end

local function watchFolder(folder: Instance)
	for _, d in folder:GetDescendants() do
		track(d)
	end
	folder.DescendantAdded:Connect(function(d)
		task.defer(track, d)
	end)
end

-- pose for one joint
local function pose(j, t: number, moving: number, act: string?, k: number): CFrame
	local base = j.Base
	local role = j.Role
	local s = math.sin
	local out = base
	-- pivot for limbs: rotate around the top of the piece (hip/shoulder)
	local hip = CFrame.new(0, j.Size.Y / 2, 0)
	if role == "Head" then
		out = base * A(math.rad(4 * s(t * 2.2) + moving * 6 * s(t * 9)), math.rad(6 * s(t * 0.9)), 0)
	elseif role == "Leg" then
		local pair = (j.Side * j.Front > 0) and 1 or -1 -- trot pairs
		local swing = moving * math.rad(32) * s(t * 10) * pair + (1 - moving) * math.rad(2) * s(t * 2)
		out = base * hip * A(swing, 0, 0) * hip:Inverse()
	elseif role == "Wing" then
		local beat = moving > 0.3 and 14 or 4
		out = base * A(0, 0, j.Side * math.rad((moving > 0.3 and 32 or 12) * s(t * beat)))
	elseif role == "Tail" then
		out = base * A(math.rad(5 * s(t * 3)), math.rad((14 + moving * 14) * s(t * (3 + moving * 5))), 0)
	elseif role == "Arm" then
		out = base * A(math.rad(8 * s(t * 2 + j.Side) + moving * 20 * s(t * 10) * j.Side), 0, 0)
	elseif role == "Tentacle" then
		out = base * hip * A(math.rad(14 * s(t * 3 + j.Index)), 0, math.rad(10 * s(t * 2.4 + j.Index))) * hip:Inverse()
	elseif role == "Orbit" then
		out = A(0, t * 1.5, 0) * base
	end
	-- whole-body: breathing bob + walking bounce
	local bob = CFrame.new(0, 0.06 * s(t * 2.4) + moving * 0.18 * math.abs(s(t * 10)), 0)
	out = bob * out
	-- action overlays (k = 0..1 progress)
	if act == "Attack" then
		-- wind up (lean back), lunge (lean forward + push), recoil
		local lean = k < 0.3 and (k / 0.3) * 0.25 or (k < 0.6 and -0.45 * s((k - 0.3) / 0.3 * math.pi / 2) or -0.45 * (1 - (k - 0.6) / 0.4))
		local push = k > 0.3 and k < 0.8 and -0.6 * s((k - 0.3) / 0.5 * math.pi) or 0
		out = CFrame.new(0, 0, push) * A(lean, 0, 0) * out
		if role == "Arm" or role == "Head" then
			out = out * A(math.rad(-40) * s(math.clamp((k - 0.3) / 0.4, 0, 1) * math.pi), 0, 0)
		end
	elseif act == "Special" then
		-- crouch, hop + full spin, land squash
		local hop = k > 0.2 and k < 0.8 and 2.4 * s((k - 0.2) / 0.6 * math.pi) or 0
		local crouch = (k < 0.2 and -0.3 * (k / 0.2)) or (k > 0.8 and -0.3 * (1 - (k - 0.8) / 0.2)) or 0
		local spin = k > 0.2 and k < 0.8 and ((k - 0.2) / 0.6) * math.pi * 2 or 0
		out = CFrame.new(0, hop + crouch, 0) * A(0, spin, 0) * out
		if role == "Wing" or role == "Arm" then
			out = out * A(0, 0, j.Side * math.rad(50) * s(math.clamp((k - 0.2) / 0.6, 0, 1) * math.pi))
		end
	end
	return out
end

local DURATION = { Attack = 0.55, Special = 0.9 }

function PetAnimator.Start()
	task.spawn(function()
		watchFolder(workspace:WaitForChild("Pets"))
	end)
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 60)
		local exp = map and map:WaitForChild("Expansion", 60)
		if exp then
			watchFolder(exp)
		end
	end)
	local camera = workspace.CurrentCamera
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local nowS = workspace:GetServerTimeNow()
		local camPos = camera and camera.CFrame.Position or Vector3.zero
		for model, st in pets do
			local pos = model:GetPivot().Position
			if (pos - camPos).Magnitude < 160 then
				local v = Vector3.new(pos.X - st.LastPos.X, 0, pos.Z - st.LastPos.Z).Magnitude / math.max(dt, 1 / 240)
				st.LastPos = pos
				st.Speed += (v - st.Speed) * math.min(1, dt * 8)
				local moving = math.clamp(st.Speed / 12, 0, 1)
				local kind = model:GetAttribute("AnimKind")
				local at = model:GetAttribute("AnimAt") or -100
				local act, k = nil, 0
				if kind and DURATION[kind] and nowS - at < DURATION[kind] then
					act, k = kind, (nowS - at) / DURATION[kind]
				end
				local tt = t + st.Phase
				for _, j in st.Joints do
					if j.Weld.Parent then
						j.Weld.C0 = pose(j, tt, moving, act, k)
					end
				end
			end
		end
	end)
end

return PetAnimator
