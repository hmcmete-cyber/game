-- v2.18 TUTORIAL panel: 8 short steps with a turning 3D picture each,
-- Back / Next / Skip. Shown on the first visit (server decides) and from the
-- QA "Tutorial" tool. Finishing or skipping tells the server (saved).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ItemIcons = require(ReplicatedStorage.Shared.ItemIcons)

local TutorialUi = {}

local STEPS = {
	{ "Welcome to Steal a Cloud!", "Catch magical clouds, bring them home and grow your sky empire. Here is how it works.", "star", Color3.fromRGB(255, 220, 90) },
	{ "Catch clouds", "Walk up to a floating cloud and press E to grab it. Rare clouds are worth much more!", "feather", Color3.fromRGB(150, 210, 255) },
	{ "Bring it home", "Carry the cloud to the golden nest on your base. Careful: you walk slowly while carrying, and all your boosts are off.", "wing", Color3.fromRGB(255, 255, 255) },
	{ "Earn coins", "Clouds stored in your base's vault spheres make coins for you over time.", "coinstack", Color3.fromRGB(255, 205, 60) },
	{ "Guard your base", "Other players can steal your clouds! Stand on the green pad at your base to raise a shield.", "shield", Color3.fromRGB(110, 255, 150) },
	{ "Fly up to the continent", "Jump into the updraft in the middle of the hub to ride up to the floating continent full of clouds, monsters and temples.", "spring", Color3.fromRGB(190, 235, 255) },
	{ "Fight and hatch pets", "R = punch, T = shoot. Beat a temple boss to win its egg, carry it to your Egg Nursery and hatch a pet that fights and buffs you.", "egg", Color3.fromRGB(255, 160, 220) },
	{ "Shops and Orbs", "Tayron sells items, Aurelius sells upgrades. Offer clouds at their Orbs to unlock many more. Have fun!", "coin", Color3.fromRGB(255, 205, 60) },
}

local player = Players.LocalPlayer
local gui, title, body, counter, backBtn, nextBtn, vp, model
local step = 1

local function button(parent: Instance, text: string, color: Color3, pos: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(120, 42)
	b.Position = pos
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 18
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	b.Parent = parent
	return b
end

local function finish()
	gui.Enabled = false
	ReplicatedStorage.Remotes.TutorialDone:FireServer()
end

local function show(i: number)
	step = math.clamp(i, 1, #STEPS)
	local s = STEPS[step]
	title.Text = s[1]
	body.Text = s[2]
	counter.Text = `{step} / {#STEPS}`
	backBtn.Visible = step > 1
	nextBtn.Text = step == #STEPS and "Let's go!" or "Next"
	if model then
		model:Destroy()
	end
	model = ItemIcons.Build(s[3], s[4])
	model.Parent = vp
	local frame = gui:FindFirstChild("Panel")
	if frame then
		frame.Size = UDim2.fromOffset(500, 300)
		TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(520, 320) }):Play()
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 50
	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(520, 320)
	frame.BackgroundColor3 = Color3.fromRGB(28, 32, 52)
	frame.BackgroundTransparency = 0.05
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(150, 210, 255)
	stroke.Thickness = 3
	stroke.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	frame.Parent = gui
	vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromOffset(150, 150)
	vp.Position = UDim2.fromOffset(18, 60)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(200, 200, 210)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.6, -9), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Parent = frame
	title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -36, 0, 40)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 230, 140)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame
	body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(180, 64)
	body.Size = UDim2.new(1, -200, 0, 160)
	body.Font = Enum.Font.GothamMedium
	body.TextSize = 20
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(235, 240, 255)
	body.Parent = frame
	counter = Instance.new("TextLabel")
	counter.BackgroundTransparency = 1
	counter.AnchorPoint = Vector2.new(0.5, 1)
	counter.Position = UDim2.new(0.5, 0, 1, -64)
	counter.Size = UDim2.fromOffset(120, 22)
	counter.Font = Enum.Font.GothamBold
	counter.TextSize = 16
	counter.TextColor3 = Color3.fromRGB(170, 185, 220)
	counter.Parent = frame
	local skip = button(frame, "Skip", Color3.fromRGB(120, 125, 150), UDim2.new(0, 80, 1, -14))
	backBtn = button(frame, "Back", Color3.fromRGB(90, 130, 200), UDim2.new(0.5, 0, 1, -14))
	nextBtn = button(frame, "Next", Color3.fromRGB(80, 190, 110), UDim2.new(1, -80, 1, -14))
	skip.Activated:Connect(finish)
	backBtn.Activated:Connect(function()
		show(step - 1)
	end)
	nextBtn.Activated:Connect(function()
		if step >= #STEPS then
			finish()
		else
			show(step + 1)
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	-- fit small screens
	local camera = workspace.CurrentCamera
	local function fit()
		local vs = camera and camera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.min(1, (vs.X - 32) / 540, (vs.Y - 32) / 340)
	end
	fit()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end

function TutorialUi.Start()
	build()
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShowTutorial").OnClientEvent:Connect(function()
		gui.Enabled = true
		show(1)
	end)
	RunService.RenderStepped:Connect(function()
		if gui.Enabled and model and model.Parent then
			model:PivotTo(CFrame.Angles(0, os.clock() * 0.9, 0))
		end
	end)
end

return TutorialUi
