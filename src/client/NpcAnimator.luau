-- Procedural animation for NPCs tagged "Npc" (Tayron). No animation assets:
-- we drive the R15 Motor6D joints directly every frame.
--   Idle   gentle breathing + side-to-side sway
--   Look   head turns toward you when you're close
--   Wave   when you walk up (within 16 studs) he waves and greets you
-- If the model has an Animation named "Idle"/"Wave", those are played instead.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NpcAnimator = {}

local player = Players.LocalPlayer
local npcs = {} -- [Model] = state

local GREET_RANGE = 16

local function joint(model: Model, part: string, name: string): Motor6D?
	local p = model:FindFirstChild(part)
	local m = p and p:FindFirstChild(name)
	return (m and m:IsA("Motor6D")) and m or nil
end

local function bubble(model: Model, message: string)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("Bubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(240, 50)
	gui.StudsOffset = Vector3.new(0, 5.2, 0)
	gui.MaxDistance = 40
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -16, 1, -10)
	text.Position = UDim2.fromOffset(8, 5)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(70, 80, 120)
	text.Text = message
	text.Parent = frame
	gui.Parent = head
	task.delay(3.5, function()
		gui:Destroy()
	end)
end

local function playAsset(model: Model, name: string): boolean
	local anim = model:FindFirstChild(name)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if anim and anim:IsA("Animation") and hum then
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local track = animator:LoadAnimation(anim)
		track.Looped = name == "Idle"
		track:Play()
		return true
	end
	return false
end

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local state = {
		Waist = joint(model, "UpperTorso", "Waist"),
		Neck = joint(model, "Head", "Neck"),
		Shoulder = joint(model, "RightUpperArm", "RightShoulder"),
		Elbow = joint(model, "RightLowerArm", "RightElbow"),
		Root = model:FindFirstChild("HumanoidRootPart"),
		Phase = math.random() * 6,
		WaveUntil = 0,
		WasNear = false,
		HasIdleAsset = playAsset(model, "Idle"),
	}
	npcs[model] = state
end

function NpcAnimator.Start()
	for _, m in CollectionService:GetTagged("Npc") do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal("Npc"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Npc"):Connect(function(m)
		npcs[m] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		for model, s in npcs do
			if not model.Parent or not s.Root then
				npcs[model] = nil
				continue
			end
			local dist = myRoot and (myRoot.Position - s.Root.Position).Magnitude or math.huge
			local near = dist < GREET_RANGE

			-- Greeting when you arrive
			if near and not s.WasNear then
				s.WaveUntil = t + 2.2
				if not playAsset(model, "Wave") then
					bubble(model, `Hey {player.DisplayName}! Need some cloud gear? ☁️`)
				end
			end
			s.WasNear = near

			if s.HasIdleAsset then
				continue
			end

			-- Idle sway + breathing
			if s.Waist then
				s.Waist.Transform = CFrame.Angles(math.sin(t * 2.2 + s.Phase) * 0.03, math.sin(t * 0.9 + s.Phase) * 0.08, math.sin(t * 0.9 + s.Phase) * 0.04)
			end

			-- Look at you
			if s.Neck then
				local yaw = 0
				if near and myRoot then
					local rel = s.Root.CFrame:PointToObjectSpace(myRoot.Position)
					yaw = math.clamp(math.atan2(-rel.X, -rel.Z), -0.8, 0.8)
				end
				s.Neck.Transform = s.Neck.Transform:Lerp(CFrame.Angles(0, yaw, 0), 0.1)
			end

			-- Wave
			if s.Shoulder then
				if t < s.WaveUntil then
					s.Shoulder.Transform = CFrame.Angles(0, 0, math.rad(150))
					if s.Elbow then
						s.Elbow.Transform = CFrame.Angles(0, 0, math.sin(t * 12) * 0.5)
					end
				else
					s.Shoulder.Transform = s.Shoulder.Transform:Lerp(CFrame.Angles(0, 0, math.sin(t * 1.3 + s.Phase) * 0.05), 0.15)
					if s.Elbow then
						s.Elbow.Transform = s.Elbow.Transform:Lerp(CFrame.new(), 0.15)
					end
				end
			end
		end
	end)
end

return NpcAnimator
