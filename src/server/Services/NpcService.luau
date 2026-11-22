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

local function block(model: Model, to: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	if p.Material == Enum.Material.Plastic then
		p.TopSurface = Enum.SurfaceType.Studs -- classic studded toy look
	end
	p.CastShadow = false
	weldTo(p, to, offset, model)
	return p
end

-- v2.0 blocky vendor outfits (chunky, readable silhouettes, no meshes)
local OUTFIT = {
	-- Tayron: cloud-gear tinkerer — square cap with brim, goggles, apron,
	-- backpack crate full of glowing cloud jars
	Tayron = function(model: Model, head: BasePart, torso: BasePart)
		local blue, white = Color3.fromRGB(90, 150, 240), Color3.fromRGB(250, 250, 255)
		block(model, head, "Cap", Vector3.new(1.35, 0.55, 1.35), CFrame.new(0, 0.85, 0), blue)
		block(model, head, "CapBrim", Vector3.new(1.35, 0.15, 0.6), CFrame.new(0, 0.62, -0.85), blue)
		block(model, head, "GogglesBand", Vector3.new(1.3, 0.2, 1.3), CFrame.new(0, 0.45, 0), Color3.fromRGB(50, 50, 60))
		block(model, head, "LensL", Vector3.new(0.35, 0.3, 0.12), CFrame.new(-0.28, 0.45, -0.66), Color3.fromRGB(150, 230, 255), Enum.Material.Neon)
		block(model, head, "LensR", Vector3.new(0.35, 0.3, 0.12), CFrame.new(0.28, 0.45, -0.66), Color3.fromRGB(150, 230, 255), Enum.Material.Neon)
		block(model, torso, "Apron", Vector3.new(1.7, 1.5, 0.15), CFrame.new(0, -0.3, -0.56), white)
		block(model, torso, "Pocket", Vector3.new(0.7, 0.45, 0.17), CFrame.new(0, -0.55, -0.6), blue)
		block(model, torso, "Crate", Vector3.new(1.6, 1.4, 0.9), CFrame.new(0, 0.1, 0.95), Color3.fromRGB(160, 110, 70), Enum.Material.WoodPlanks)
		for i = -1, 1 do
			block(model, torso, "Jar" .. (i + 2), Vector3.new(0.35, 0.5, 0.35), CFrame.new(i * 0.45, 1.0, 0.95), Color3.fromRGB(170, 235, 255), Enum.Material.Neon)
		end
		-- v2.5: tool belt with pouches, work gloves, a wrench in hand
		block(model, torso, "ToolBelt", Vector3.new(2.05, 0.3, 1.1), CFrame.new(0, -0.8, 0), Color3.fromRGB(120, 80, 50))
		block(model, torso, "PouchL", Vector3.new(0.45, 0.5, 0.35), CFrame.new(-0.75, -0.95, -0.6), Color3.fromRGB(150, 100, 60))
		block(model, torso, "PouchR", Vector3.new(0.45, 0.5, 0.35), CFrame.new(0.75, -0.95, -0.6), Color3.fromRGB(150, 100, 60))
		for _, handName in { "LeftHand", "RightHand" } do
			local hand = model:FindFirstChild(handName) :: BasePart?
			if hand then
				block(model, hand, "Glove" .. handName, hand.Size * 1.15, CFrame.new(), Color3.fromRGB(240, 200, 70))
			end
		end
		-- v2.22: staff in the LEFT hand - the greeting wave uses the right arm
		-- and used to swing the staff through his head
		local rh = model:FindFirstChild("LeftHand") :: BasePart?
		if rh then
			block(model, rh, "Wrench", Vector3.new(0.25, 1.4, 0.25), CFrame.new(0, -0.5, -0.3) * CFrame.Angles(math.rad(70), 0, 0), Color3.fromRGB(170, 175, 185))
			block(model, rh, "WrenchHead", Vector3.new(0.6, 0.3, 0.3), CFrame.new(0, -0.8, -0.95), Color3.fromRGB(170, 175, 185))
		end
	end,
	-- Aurelius: royal upgrade master — square crown with prongs, cape, gold belt
	Aurelius = function(model: Model, head: BasePart, torso: BasePart)
		local gold, purple = Color3.fromRGB(255, 205, 80), Color3.fromRGB(130, 70, 190)
		block(model, head, "CrownBase", Vector3.new(1.35, 0.35, 1.35), CFrame.new(0, 0.75, 0), gold, Enum.Material.SmoothPlastic)
		for i, off in { Vector3.new(-0.5, 1.05, -0.5), Vector3.new(0.5, 1.05, -0.5), Vector3.new(-0.5, 1.05, 0.5), Vector3.new(0.5, 1.05, 0.5) } do
			block(model, head, "Prong" .. i, Vector3.new(0.3, 0.35, 0.3), CFrame.new(off), gold)
		end
		block(model, head, "Gem", Vector3.new(0.3, 0.3, 0.12), CFrame.new(0, 0.78, -0.7), Color3.fromRGB(255, 80, 140), Enum.Material.Neon)
		block(model, torso, "Cape", Vector3.new(1.9, 2.6, 0.18), CFrame.new(0, -0.6, 0.6), purple, Enum.Material.Fabric)
		block(model, torso, "CapeTrim", Vector3.new(1.95, 0.22, 0.2), CFrame.new(0, 0.62, 0.62), gold)
		block(model, torso, "Belt", Vector3.new(2.05, 0.3, 1.1), CFrame.new(0, -0.75, 0), gold)
		-- v2.5: robe front panel, beard block, and a staff topped with a cloud gem
		block(model, torso, "RobePanel", Vector3.new(1, 1.8, 0.15), CFrame.new(0, -0.3, -0.56), purple:Lerp(Color3.new(1, 1, 1), 0.15))
		block(model, head, "Beard", Vector3.new(0.9, 0.7, 0.3), CFrame.new(0, -0.55, -0.55), Color3.fromRGB(240, 240, 245))
		-- v2.22: staff in the LEFT hand - the greeting wave uses the right arm
		-- and used to swing the staff through his head
		local rh = model:FindFirstChild("LeftHand") :: BasePart?
		if rh then
			block(model, rh, "Staff", Vector3.new(0.3, 5, 0.3), CFrame.new(0, 1, -0.2), Color3.fromRGB(120, 80, 50))
			local gem = Instance.new("Part")
			gem.Name = "StaffGem"
			gem.Shape = Enum.PartType.Ball
			gem.Size = Vector3.one * 0.8
			gem.Color = Color3.fromRGB(150, 220, 255)
			gem.Material = Enum.Material.Neon
			gem.CastShadow = false
			weldTo(gem, rh, CFrame.new(0, 3.7, -0.2), model)
		end
	end,
}

local function decorate(model: Model, look)
	local torso = model:FindFirstChild("UpperTorso") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	if torso and head and OUTFIT[model.Name] then
		OUTFIT[model.Name](model, head, torso)
	end
	if head then
		-- short name tag in clear sky ABOVE the stall roof (roof ~10 studs up,
		-- tag ~11.5): dark rounded plate, big name, one small word
		local gui = Instance.new("BillboardGui")
		gui.Name = "NameTag"
		gui.Size = UDim2.fromOffset(150, 46)
		gui.StudsOffset = Vector3.new(0, 7, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = 60
		local plate = Instance.new("Frame")
		plate.Size = UDim2.fromScale(1, 1)
		plate.BackgroundColor3 = Color3.fromRGB(16, 27, 48)
		plate.BackgroundTransparency = 0.15
		plate.Parent = gui
		Instance.new("UICorner", plate).CornerRadius = UDim.new(0, 12)
		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -10, 0.62, 0)
		name.Position = UDim2.fromOffset(5, 2)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.Text = model.Name
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Parent = plate
		local role = Instance.new("TextLabel")
		role.Position = UDim2.fromScale(0, 0.6)
		role.Size = UDim2.new(1, 0, 0.36, 0)
		role.BackgroundTransparency = 1
		role.Font = Enum.Font.GothamBold
		role.TextScaled = true
		role.Text = look.Shop == "Items" and "SHOP" or "UPGRADES"
		role.TextColor3 = look.TitleColor
		role.Parent = plate
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
	if ok and model then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
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
