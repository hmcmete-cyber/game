-- v2.19 SHOW-DON'T-TELL TUTORIAL (director: 5-6 year olds don't read).
-- Each step = one big turning 3D picture + 1-3 BIG words, a bouncing golden
-- arrow above the real target in the world, and a glowing trail from you to
-- it. Steps finish by DOING the thing (catch a cloud, bring it home, step on
-- the lock pad, ride the updraft...), or by tapping the big ▶ button.
-- ✕ skips. Finishing/skipping tells the server (saved: shown once).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ItemIcons = require(ReplicatedStorage.Shared.ItemIcons)
local BiomeMap = require(ReplicatedStorage.Shared.BiomeMap)

local TutorialUi = {}

local player = Players.LocalPlayer
local gui, panel, words, vp, model, nextBtn, hand
local arrow, beam, a0, a1
local stepIndex, running = 0, false
local stepStarted = 0
local baseline = {}

local function root(): BasePart?
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function myRoof(): Instance?
	local roofs = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Rooftops")
	for _, r in roofs and roofs:GetChildren() or {} do
		if r:GetAttribute("OwnerUserId") == player.UserId then
			return r
		end
	end
	return nil
end

local function nearestCloud(): BasePart?
	local w = workspace:FindFirstChild("Weather")
	local r = root()
	local best, bestD = nil, math.huge
	for _, d in w and w:GetDescendants() or {} do
		if d:IsA("ProximityPrompt") and d.Name == "CatchPrompt" and d.Parent:IsA("BasePart") and r then
			local dist = (d.Parent.Position - r.Position).Magnitude
			if dist < bestD then
				best, bestD = d.Parent, dist
			end
		end
	end
	return best
end

local function nearestMonster(): BasePart?
	local m = workspace:FindFirstChild("Monsters")
	local r = root()
	local best, bestD = nil, math.huge
	for _, d in m and m:GetDescendants() or {} do
		if d:IsA("Model") and d.PrimaryPart and r then
			local dist = (d.PrimaryPart.Position - r.Position).Magnitude
			if dist < bestD then
				best, bestD = d.PrimaryPart, dist
			end
		end
	end
	return best
end

-- { picture, colour, BIG WORDS, target(), done() }
local STEPS = {
	{ "star", Color3.fromRGB(255, 220, 90), "HI! ☁", nil, function()
		return os.clock() - stepStarted > 3
	end },
	{ "feather", Color3.fromRGB(150, 210, 255), "CATCH! ✋", nearestCloud, function()
		return player:GetAttribute("Carrying") ~= nil
	end },
	{ "wing", Color3.fromRGB(255, 255, 255), "GO HOME! 🏠", function()
		local roof = myRoof()
		return roof and roof:FindFirstChild("Nest", true)
	end, function()
		local ls = player:FindFirstChild("leaderstats")
		local n = 0
		for _, v in ls and ls:GetChildren() or {} do
			if v:IsA("IntValue") or v:IsA("NumberValue") then
				n += v.Value
			end
		end
		baseline.Home = baseline.Home or n
		return player:GetAttribute("Carrying") == nil and n ~= baseline.Home
	end },
	{ "shield", Color3.fromRGB(110, 255, 150), "LOCK! 🔒", function()
		local roof = myRoof()
		return roof and roof:FindFirstChild("LockPad", true)
	end, function()
		local roof = myRoof()
		local pad = roof and roof:FindFirstChild("LockPad", true) :: BasePart?
		local r = root()
		return pad ~= nil and r ~= nil and (pad.Position - r.Position).Magnitude < 5
	end },
	{ "spring", Color3.fromRGB(190, 235, 255), "UP! ⬆", function()
		local map = workspace:FindFirstChild("Map")
		local air = map and map:FindFirstChild("AirColumns")
		return air and air:FindFirstChild("Updraft", true)
	end, function()
		local r = root()
		return r ~= nil and r.Position.Y > BiomeMap.UP - 40
	end },
	{ "sword", Color3.fromRGB(255, 120, 120), "FIGHT! 👊", nearestMonster, function()
		return (player:GetAttribute("LastKillAt") or 0) > (baseline.Kill or math.huge)
	end },
	{ "egg", Color3.fromRGB(255, 170, 230), "PETS! 🥚", function()
		local roof = myRoof()
		local i = roof and tonumber(string.match(roof.Name, "%d+"))
		local exp = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Expansion")
		local hut = i and exp and exp:FindFirstChild("PetHut" .. i)
		return hut and hut:FindFirstChild("PetPrompt", true)
	end, function()
		return os.clock() - stepStarted > 8
	end },
}

local function targetPart(spec): BasePart?
	local t = spec[4] and spec[4]()
	if t and t:IsA("BasePart") then
		return t
	elseif t and t:IsA("Model") then
		return t.PrimaryPart
	end
	return nil
end

local function finish()
	running = false
	gui.Enabled = false
	if arrow then
		arrow.Parent = nil
	end
	if beam then
		beam.Enabled = false
	end
	ReplicatedStorage.Remotes.TutorialDone:FireServer()
end

local function show(i: number)
	if i > #STEPS then
		finish()
		return
	end
	stepIndex = i
	stepStarted = os.clock()
	baseline = { Kill = player:GetAttribute("LastKillAt") or 0 }
	local s = STEPS[i]
	words.Text = s[3]
	if model then
		model:Destroy()
	end
	model = ItemIcons.Build(s[1], s[2])
	model.Parent = vp
	-- pop-in
	panel.Size = UDim2.fromOffset(220, 120)
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(330, 170) }):Play()
end

-- world arrow + trail
local function buildWorldPointer()
	arrow = Instance.new("Model")
	arrow.Name = "TutorialArrow"
	local function part(size, cf, wedge)
		local p = Instance.new(wedge and "WedgePart" or "Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 215, 60)
		p.Size = size
		p.CFrame = cf
		p.Parent = arrow
		return p
	end
	local shaft = part(Vector3.new(1.4, 3, 1.4), CFrame.new(0, 2.5, 0))
	part(Vector3.new(1.6, 1.6, 1.8), CFrame.new(0, 0.4, 0.45) * CFrame.Angles(math.rad(180), 0, 0), true)
	part(Vector3.new(1.6, 1.6, 1.8), CFrame.new(0, 0.4, -0.45) * CFrame.Angles(math.rad(180), math.rad(180), 0), true)
	arrow.PrimaryPart = shaft
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.Transparency = true, false, false, false, 1
	anchor.Size = Vector3.one * 0.2
	anchor.Parent = arrow
	a1 = Instance.new("Attachment")
	a1.Parent = anchor
	beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
	beam.LightEmission = 1
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 3
	beam.TextureSpeed = 2
	beam.Transparency = NumberSequence.new(0.2, 0.6)
	beam.Attachment1 = a1
	beam.Enabled = false
	beam.Parent = anchor
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 50
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 70)
	panel.Size = UDim2.fromOffset(330, 170)
	panel.BackgroundColor3 = Color3.fromRGB(28, 32, 52)
	panel.BackgroundTransparency = 0.1
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 26)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 60)
	stroke.Thickness = 4
	stroke.Parent = panel
	panel.Parent = gui
	vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(0.42, 0, 1, -10)
	vp.Position = UDim2.fromOffset(6, 5)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(210, 210, 220)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.6, -8.5), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Parent = panel
	words = Instance.new("TextLabel")
	words.BackgroundTransparency = 1
	words.Position = UDim2.new(0.42, 0, 0, 10)
	words.Size = UDim2.new(0.58, -12, 0.62, 0)
	words.Font = Enum.Font.FredokaOne
	words.TextScaled = true
	words.TextColor3 = Color3.fromRGB(255, 235, 140)
	words.TextStrokeTransparency = 0.4
	words.Parent = panel
	-- big ▶ (next) and small ✕ (skip): no reading needed
	nextBtn = Instance.new("TextButton")
	nextBtn.AnchorPoint = Vector2.new(1, 1)
	nextBtn.Position = UDim2.new(1, -12, 1, -10)
	nextBtn.Size = UDim2.fromOffset(84, 48)
	nextBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 110)
	nextBtn.Font = Enum.Font.FredokaOne
	nextBtn.TextScaled = true
	nextBtn.TextColor3 = Color3.new(1, 1, 1)
	nextBtn.Text = "▶"
	Instance.new("UICorner", nextBtn).CornerRadius = UDim.new(0, 14)
	nextBtn.Parent = panel
	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, 8, 0, -8)
	skip.Size = UDim2.fromOffset(36, 36)
	skip.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	skip.Font = Enum.Font.FredokaOne
	skip.TextScaled = true
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.Text = "✕"
	Instance.new("UICorner", skip).CornerRadius = UDim.new(1, 0)
	skip.Parent = panel
	-- a little pointing hand that bounces toward the ▶ button
	hand = Instance.new("TextLabel")
	hand.BackgroundTransparency = 1
	hand.Size = UDim2.fromOffset(40, 40)
	hand.Font = Enum.Font.FredokaOne
	hand.TextScaled = true
	hand.Text = "👉"
	hand.Parent = panel
	nextBtn.Activated:Connect(function()
		show(stepIndex + 1)
	end)
	skip.Activated:Connect(finish)
	gui.Parent = player:WaitForChild("PlayerGui")
	buildWorldPointer()
end

function TutorialUi.Start()
	build()
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShowTutorial").OnClientEvent:Connect(function()
		running = true
		gui.Enabled = true
		show(1)
	end)
	RunService.RenderStepped:Connect(function()
		if not running then
			return
		end
		local t = os.clock()
		if model and model.Parent then
			model:PivotTo(CFrame.Angles(0, t * 1.2, 0) * CFrame.new(0, math.sin(t * 3) * 0.2, 0))
		end
		hand.Position = UDim2.new(1, -150 + math.sin(t * 6) * 8, 1, -54)
		local spec = STEPS[stepIndex]
		if not spec then
			return
		end
		-- world pointer on the step's target
		local target = targetPart(spec)
		local r = root()
		if target and r then
			arrow.Parent = workspace
			local top = target.Position + Vector3.new(0, target.Size.Y / 2 + 4 + math.abs(math.sin(t * 4)) * 2, 0)
			arrow:PivotTo(CFrame.new(top) * CFrame.Angles(0, t * 2, 0) * CFrame.new(0, -2.5, 0))
			local anchor = a1.Parent :: BasePart
			anchor.CFrame = CFrame.new(target.Position)
			if not a0 or a0.Parent ~= r then
				a0 = Instance.new("Attachment")
				a0.Name = "TutorialTrail"
				a0.Parent = r
				beam.Attachment0 = a0
			end
			beam.Enabled = true
		else
			arrow.Parent = nil
			beam.Enabled = false
		end
		-- done by doing it
		local ok, done = pcall(spec[5])
		if ok and done then
			show(stepIndex + 1)
		end
	end)
end

return TutorialUi
