-- Vendor NPCs. Every Part in the map with attribute Npc = "Tayron" | "Aurelius"
-- (BaseBuilder puts one of each on every base's Market ledge) gets an R15 NPC.
--
--   Tayron   · Cloud Vendor      -> opens the "items" shop (temporary items)
--   Aurelius · Upgrade Master    -> opens the "upgrades" shop (permanent upgrades)
--
-- NPCs are built from a HumanoidDescription (no uploaded assets). Their idle
-- and wave are real AnimationTracks created on each client (NpcAnimator.luau).
-- To use your own animations instead, put Animation objects named "Idle" and
-- "Wave" inside the NPC model — the client plays those first.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local NpcService = {}

local SKIN = Color3.fromRGB(234, 184, 146)

local LOOKS = {
	Tayron = {
		Title = "Cloud Vendor",
		Shop = "Items",
		Torso = Color3.fromRGB(120, 170, 255),
		Legs = Color3.fromRGB(70, 70, 95),
		Hat = Color3.fromRGB(255, 255, 255),
		TitleColor = Color3.fromRGB(170, 215, 255),
	},
	Aurelius = {
		Title = "Upgrade Master",
		Shop = "Upgrades",
		Torso = Color3.fromRGB(150, 90, 200),
		Legs = Color3.fromRGB(60, 45, 80),
		Hat = Color3.fromRGB(255, 210, 90),
		TitleColor = Color3.fromRGB(255, 215, 120),
	},
}

local function weldTo(part: BasePart, to: BasePart, offset: CFrame, model: Model)
	part.CanCollide = false
	part.Massless = true
	part.CFrame = to.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
	part.Parent = model
end

local function decorate(model: Model, look)
	local torso = model:FindFirstChild("UpperTorso") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	if torso then
		local apron = Instance.new("Part")
		apron.Name = "Apron"
		apron.Size = Vector3.new(1.6, 1.4, 0.15)
		apron.Color = Color3.fromRGB(255, 252, 245)
		apron.Material = Enum.Material.Fabric
		weldTo(apron, torso, CFrame.new(0, -0.3, -0.55), model)
	end
	if head then
		-- puffy hat: white cloud for Tayron, golden crown-cloud for Aurelius
		for i, puff in { { Vector3.new(0, 0.85, 0), Vector3.new(1.8, 0.8, 1.6) }, { Vector3.new(0.5, 1.1, 0.1), Vector3.new(1, 0.7, 1) }, { Vector3.new(-0.45, 1.05, -0.1), Vector3.new(0.9, 0.6, 0.9) } } do
			local p = Instance.new("Part")
			p.Name = "HatPuff" .. i
			p.Size = puff[2]
			p.Color = look.Hat
			p.Material = Enum.Material.SmoothPlastic
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			weldTo(p, head, CFrame.new(puff[1]), model)
		end

		local gui = Instance.new("BillboardGui")
		gui.Name = "NameTag"
		gui.Size = UDim2.fromOffset(200, 50)
		gui.StudsOffset = Vector3.new(0, 3.2, 0)
		gui.MaxDistance = 45
		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, 0, 0.6, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.Text = model.Name
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.3
		name.Parent = gui
		local role = Instance.new("TextLabel")
		role.Position = UDim2.fromScale(0, 0.6)
		role.Size = UDim2.new(1, 0, 0.4, 0)
		role.BackgroundTransparency = 1
		role.Font = Enum.Font.GothamBold
		role.TextScaled = true
		role.Text = look.Title
		role.TextColor3 = look.TitleColor
		role.TextStrokeTransparency = 0.4
		role.Parent = gui
		gui.Parent = head
	end
end

function NpcService.Spawn(spot: BasePart, who: string, openShop: RemoteEvent)
	local look = LOOKS[who]
	if not look or spot:FindFirstChild("NpcModel") then
		return nil
	end
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = SKIN
	d.LeftArmColor = SKIN
	d.RightArmColor = SKIN
	d.TorsoColor = look.Torso
	d.LeftLegColor = look.Legs
	d.RightLegColor = look.Legs

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn(`[NPC] Could not build {who}: {model}`)
		return nil
	end
	model.Name = who
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	if not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = hum
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model:PivotTo(spot.CFrame + Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)) -- spot = floor level
	root.Anchored = true

	decorate(model, look)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = look.Shop == "Items" and "Shop" or "Upgrades"
	prompt.ObjectText = `{who} - {look.Title}`
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		openShop:FireClient(player, look.Shop, who)
	end)

	model:SetAttribute("Vendor", who)
	model.Parent = spot.Parent
	local marker = Instance.new("ObjectValue")
	marker.Name = "NpcModel"
	marker.Value = model
	marker.Parent = spot
	CollectionService:AddTag(model, "Npc")
	return model
end

function NpcService.Start(remotes)
	local count = 0
	for _, d in workspace.Map:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Npc") then
			if NpcService.Spawn(d, d:GetAttribute("Npc"), remotes.OpenShop) then
				count += 1
			end
		end
	end
	print(`[NPC] spawned {count} vendors`)
end

return NpcService
