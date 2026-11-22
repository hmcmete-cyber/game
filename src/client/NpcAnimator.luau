-- NPC animations (Tayron, Aurelius, … tagged "Npc") with real AnimationTracks.
--
-- Why the old version failed: it wrote Motor6D.Transform in RenderStepped,
-- but the Animator resets Transform every frame, so nothing moved.
--
-- Now, for every NPC:
--   1. If the model contains Animation objects named "Idle" / "Wave", play them.
--   2. Otherwise build KeyframeSequences in code (breathing idle, waving arm),
--      register them with KeyframeSequenceProvider and play them as
--      AnimationTracks through the NPC's Animator.
--   3. If registering isn't allowed on this device, fall back to posing the
--      joints in RunService.Stepped (that runs AFTER the Animator, so it sticks).
-- The NPC greets you (wave + speech bubble) when you walk up.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimLib = require(ReplicatedStorage.Shared.AnimLib)

local NpcAnimator = {}

local player = Players.LocalPlayer
local npcs = {} -- [Model] = state
local GREET_RANGE = 14

-- Idle/Wave come from Shared/AnimLib (published id in Shared/Animations,
-- or built from Shared/AnimationData in Studio).

local function makeAnimation(id: string): Animation
	local a = Instance.new("Animation")
	a.AnimationId = id
	return a
end

------------------------------------------------------------------------

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
	-- v1.7: the stall canopy sits ~4.5 studs above the head, so the bubble
	-- floats IN FRONT of the vendor (toward the customer), just above head
	-- height, and is drawn on top so the roof can never cut it.
	-- v2.0: in clear sky above the name tag (which sits above the roof)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 10.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
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

local GREETINGS = {
	Tayron = "Hi %s! Need gear?",
	Aurelius = "Hi %s! Get stronger?",
}

local function joint(model: Model, part: string, name: string): Motor6D?
	local p = model:FindFirstChild(part)
	local m = p and p:FindFirstChild(name)
	return (m and m:IsA("Motor6D")) and m or nil
end

local function add(model: Instance)
	if not model:IsA("Model") or npcs[model] then
		return
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)

	local state = {
		Root = model:FindFirstChild("HumanoidRootPart"),
		WasNear = false,
		WaveUntil = 0,
		Phase = math.random() * 6,
		Joints = {
			Waist = joint(model, "UpperTorso", "Waist"),
			Neck = joint(model, "Head", "Neck"),
			Shoulder = joint(model, "RightUpperArm", "RightShoulder"),
			Elbow = joint(model, "RightLowerArm", "RightElbow"),
		},
	}

	-- 1) custom Animation objects, 2) generated KeyframeSequences
	local idleAnim = model:FindFirstChild("Idle")
	local waveAnim = model:FindFirstChild("Wave")
	if not (idleAnim and idleAnim:IsA("Animation")) then
		local id = AnimLib.Id("NpcIdle")
		idleAnim = id and makeAnimation(id) or nil
	end
	if not (waveAnim and waveAnim:IsA("Animation")) then
		local id = AnimLib.Id("NpcWave")
		waveAnim = id and makeAnimation(id) or nil
	end
	local ok1, idleTrack = pcall(function()
		return idleAnim and animator:LoadAnimation(idleAnim)
	end)
	local ok2, waveTrack = pcall(function()
		return waveAnim and animator:LoadAnimation(waveAnim)
	end)
	state.Idle = ok1 and idleTrack or nil
	state.Wave = ok2 and waveTrack or nil
	-- v2.32 live servers: generated clips can't be registered -> play them
	-- procedurally (ProcAnim) so Tayron and Aurelius still breathe and wave
	if not state.Idle or not state.Wave then
		local ProcAnim = require(ReplicatedStorage.Shared.ProcAnim)
		ProcAnim.Own(model)
		state.Idle = state.Idle or AnimLib.Load(animator, "NpcIdle")
		state.Wave = state.Wave or AnimLib.Load(animator, "NpcWave")
	end
	if state.Idle then
		state.Idle.Looped = true
		state.Idle:Play(0.3)
	end

	npcs[model] = state
end

function NpcAnimator.Start()
	for _, m in CollectionService:GetTagged("Npc") do
		task.spawn(add, m)
	end
	CollectionService:GetInstanceAddedSignal("Npc"):Connect(function(m)
		task.spawn(add, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Npc"):Connect(function(m)
		npcs[m] = nil
	end)

	-- Greeting check (cheap, 5×/s)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			for model, s in npcs do
				if not model.Parent or not s.Root then
					npcs[model] = nil
					continue
				end
				local near = myRoot ~= nil and (myRoot.Position - s.Root.Position).Magnitude < GREET_RANGE
				if near and not s.WasNear then
					s.WaveUntil = os.clock() + 1.5
					if s.Wave then
						s.Wave:Play(0.1)
					end
					bubble(model, string.format(GREETINGS[model.Name] or "Hello, %s!", player.DisplayName))
				end
				s.WasNear = near
			end
		end
	end)

	-- 3) Fallback posing for NPCs without tracks. Stepped runs after the
	-- Animator has written Transform, so these poses actually show.
	RunService.Stepped:Connect(function()
		local t = os.clock()
		for _, s in npcs do
			local j = s.Joints
			if not s.Idle and j.Waist then
				j.Waist.Transform = CFrame.Angles(math.sin(t * 2.2 + s.Phase) * 0.03, math.sin(t * 0.9 + s.Phase) * 0.08, 0)
			end
			if not s.Wave and j.Shoulder then
				if t < s.WaveUntil then
					j.Shoulder.Transform = CFrame.Angles(math.rad(10), 0, math.rad(95))
					if j.Elbow then
						j.Elbow.Transform = CFrame.Angles(0, 0, math.rad(57 + math.sin(t * 12) * 22))
					end
				end
			end
		end
	end)
end

return NpcAnimator
