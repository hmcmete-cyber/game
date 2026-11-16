-- NPC Tayron, the Cloud Vendor. Spawned at Map/…/CloudShop/TayronSpot.
--
-- Built at runtime from a HumanoidDescription (no uploaded assets needed).
-- His idle sway and greeting wave are procedural, done on each client
-- (client NpcAnimator.luau) — so nobody needs animation IDs.
-- To use a real animation later: put an Animation in the model named "Idle"
-- or "Wave" and the client will play it instead.
--
-- Prompt: "Shop" · "Tayron - Cloud Vendor" (E) → opens the Shop UI.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local NpcService = {}

local function look()
	local d = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(234, 184, 146)
	d.HeadColor = skin
	d.LeftArmColor = skin
	d.RightArmColor = skin
	d.TorsoColor = Color3.fromRGB(120, 170, 255) -- sky-blue vendor shirt
	d.LeftLegColor = Color3.fromRGB(70, 70, 95)
	d.RightLegColor = Color3.fromRGB(70, 70, 95)
	return d
end

local function addApron(model: Model)
	-- small cloud-white apron + cloud hat so he reads as "the cloud guy"
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	local head = model:FindFirstChild("Head")
	if torso then
		local apron = Instance.new("Part")
		apron.Name = "Apron"
		apron.Size = Vector3.new(1.6, 1.4, 0.15)
		apron.Color = Color3.fromRGB(255, 252, 245)
		apron.Material = Enum.Material.Fabric
		apron.CanCollide = false
		apron.Massless = true
		apron.CFrame = torso.CFrame * CFrame.new(0, -0.3, -0.55)
		local w = Instance.new("WeldConstraint")
		w.Part0 = torso
		w.Part1 = apron
		w.Parent = apron
		apron.Parent = model
	end
	if head then
		for i, puff in { { Vector3.new(0, 0.85, 0), Vector3.new(1.8, 0.8, 1.6) }, { Vector3.new(0.5, 1.1, 0.1), Vector3.new(1, 0.7, 1) }, { Vector3.new(-0.45, 1.05, -0.1), Vector3.new(0.9, 0.6, 0.9) } } do
			local p = Instance.new("Part")
			p.Name = "HatPuff" .. i
			p.Size = puff[2]
			p.Color = Color3.new(1, 1, 1)
			p.CanCollide = false
			p.Massless = true
			p.CFrame = head.CFrame * CFrame.new(puff[1])
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			local w = Instance.new("WeldConstraint")
			w.Part0 = head
			w.Part1 = p
			w.Parent = p
			p.Parent = model
		end
	end
end

local function nameTag(model: Model)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(220, 56)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 60
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.6, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.Text = "Tayron"
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Parent = gui
	local role = Instance.new("TextLabel")
	role.Position = UDim2.fromScale(0, 0.6)
	role.Size = UDim2.new(1, 0, 0.4, 0)
	role.BackgroundTransparency = 1
	role.Font = Enum.Font.GothamBold
	role.TextScaled = true
	role.Text = "☁️ Cloud Vendor"
	role.TextColor3 = Color3.fromRGB(170, 215, 255)
	role.TextStrokeTransparency = 0.4
	role.Parent = gui
	gui.Parent = head
end

function NpcService.SpawnTayron(spot: BasePart, openShop: RemoteEvent)
	if spot.Parent:FindFirstChild("Tayron") then
		return spot.Parent.Tayron
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(look(), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[NPC] Could not build Tayron:", model)
		return nil
	end
	model.Name = "Tayron"
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- He shouldn't be killable or walk away
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model:PivotTo(spot.CFrame + Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)) -- spot = floor level
	root.Anchored = true

	addApron(model)
	nameTag(model)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Tayron - Cloud Vendor"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		openShop:FireClient(player)
	end)

	model.Parent = spot.Parent
	CollectionService:AddTag(model, "Npc")
	return model
end

function NpcService.Start(remotes)
	local spot = workspace.Map:FindFirstChild("TayronSpot", true)
	if spot and spot:IsA("BasePart") then
		NpcService.SpawnTayron(spot, remotes.OpenShop)
	else
		warn("[NPC] No TayronSpot in the map — Tayron not spawned")
	end
end

return NpcService
