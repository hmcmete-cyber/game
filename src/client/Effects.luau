-- Client-only eye candy (costs the server nothing):
--   SpinRing       models rotate around their own axis (attribute SpinSpeed, rad/s)
--   VaultSphere    flashes when a storm is deposited (server sets Pulse/PulseFrom/PulseColor)
--   LightningCloud dark storm clouds crackle with small electric arcs

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Effects = {}

local camera = workspace.CurrentCamera

------------------------------------------------------------------------
-- Spinning energy rings
------------------------------------------------------------------------

local rings = {} -- [Model] = { Base: CFrame, Speed: number }

local function addRing(model: Instance)
	if model:IsA("Model") and model.PrimaryPart then
		rings[model] = { Base = model:GetPivot(), Speed = model:GetAttribute("SpinSpeed") or 0.4 }
	end
end

------------------------------------------------------------------------
-- Vault deposit flash: a glowing puff flies into the sphere, the glass
-- lights up and a shockwave ring expands.
------------------------------------------------------------------------

local function quickPart(size: Vector3, cf: CFrame, color: Color3, transparency: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Shape = Enum.PartType.Ball
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Transparency = transparency
	p.Parent = workspace
	return p
end

local function pulseVault(vault: BasePart)
	local color = vault:GetAttribute("PulseColor") or Color3.fromRGB(200, 230, 255)
	local from = vault:GetAttribute("PulseFrom")

	local function flash()
		-- glass lights up, then settles back
		local restT, restR = vault.Transparency, vault.Reflectance
		vault.Transparency = 0.15
		vault.Reflectance = 0.4
		TweenService:Create(vault, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = restT,
			Reflectance = restR,
		}):Play()

		-- shockwave
		local wave = quickPart(vault.Size, vault.CFrame, color, 0.3)
		TweenService:Create(wave, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = vault.Size * 2.6,
			Transparency = 1,
		}):Play()
		task.delay(0.65, function()
			wave:Destroy()
		end)
	end

	if typeof(from) == "Vector3" then
		-- glowing puff travels from the player's head into the sphere
		local puff = quickPart(Vector3.one * 1.6, CFrame.new(from), color, 0.1)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 3
		light.Range = 10
		light.Parent = puff
		local t = TweenService:Create(puff, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = vault.CFrame,
			Size = Vector3.one * 0.4,
		})
		t.Completed:Connect(function()
			puff:Destroy()
			flash()
		end)
		t:Play()
	else
		flash()
	end
end

local function addVault(vault: Instance)
	if vault:IsA("BasePart") then
		vault:GetAttributeChangedSignal("Pulse"):Connect(function()
			pulseVault(vault)
		end)
	end
end

------------------------------------------------------------------------
-- Electric arcs on storm clouds
------------------------------------------------------------------------

local clouds = {} -- [BasePart] = { Next: number, Light: PointLight? }

local function addCloud(core: Instance)
	if core:IsA("BasePart") then
		clouds[core] = { Next = 0, Light = core:FindFirstChild("CloudLight") }
	end
end

local ARC_COLOR = ColorSequence.new(Color3.fromRGB(200, 235, 255), Color3.fromRGB(150, 200, 255))

local function arc(core: BasePart)
	local radius = core.Size.X * 0.9
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit * radius
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(math.random() - 0.5, math.random() - 0.6, math.random() - 0.5).Unit * radius
	a1.Parent = core

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ARC_COLOR
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Width0 = 0.18
	beam.Width1 = 0.08
	beam.CurveSize0 = (math.random() - 0.5) * radius * 2
	beam.CurveSize1 = (math.random() - 0.5) * radius * 2
	beam.Parent = core

	task.delay(0.07 + math.random() * 0.06, function()
		beam:Destroy()
		a0:Destroy()
		a1:Destroy()
	end)
end

------------------------------------------------------------------------

local function watch(tag: string, add: (Instance) -> (), remove: ((Instance) -> ())?)
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	if remove then
		CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
	end
end

function Effects.Start()
	watch("SpinRing", addRing, function(inst)
		rings[inst] = nil
	end)
	watch("VaultSphere", addVault)
	watch("LightningCloud", addCloud, function(inst)
		clouds[inst] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()

		for model, r in rings do
			if model.Parent then
				model:PivotTo(r.Base * CFrame.Angles(0, t * r.Speed, 0))
			else
				rings[model] = nil
			end
		end

		local camPos = camera.CFrame.Position
		for core, c in clouds do
			if not core.Parent then
				clouds[core] = nil
				continue
			end
			if t >= c.Next and (core.Position - camPos).Magnitude < 160 then
				c.Next = t + 0.12 + math.random() * 0.35
				arc(core)
				if math.random() < 0.5 then
					arc(core)
				end
				if c.Light then
					c.Light.Brightness = 6
					task.delay(0.05, function()
						if c.Light then
							c.Light.Brightness = 2.5
						end
					end)
				end
			end
		end
	end)
end

return Effects
