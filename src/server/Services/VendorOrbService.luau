-- v2.13 VENDOR ORBS (director): an Orb stands beside each vendor on the hub
--   workspace.Map.Decor.AureliusOrb   unlocks Aurelius' 40 Boons
--   workspace.Map.Decor.TayronOrb     unlocks Tayron's 40 Gadgets
-- Walk up while CARRYING a cloud and press "Offer Cloud". If that cloud type
-- is the key of one of this vendor's locked entries, the cloud is consumed
-- and the entry unlocks forever (Data.Unlocks[id] = true). Stolen clouds are
-- always refused (server check, see WeatherService.ConsumeCarry).
-- The Orb's sign shows "unlocked / 40"; the shop list shows each entry's
-- required cloud and lock state (player attribute "Unlocks").

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.VendorCatalog)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local VendorOrbService = {}
local Config = require(ReplicatedStorage.Shared.Config)
local function shown(vendor: string): string -- v2.33: Tayron is called Zeus in game
	return (Config.VendorDisplay and Config.VendorDisplay[vendor]) or vendor
end

local DataService, WeatherService, Remotes

local function hint(player: Player, text: string, t: number?)
	if Remotes and Remotes.Hint then
		Remotes.Hint:FireClient(player, text, t or 4)
	end
end

local function unlocks(player: Player)
	local d = DataService.Get(player)
	if d then
		d.Unlocks = d.Unlocks or {}
		return d.Unlocks
	end
	return nil
end

local function syncAttr(player: Player)
	local u = unlocks(player)
	if not u then
		return
	end
	local list = {}
	for id in u do
		table.insert(list, id)
	end
	player:SetAttribute("Unlocks", "," .. table.concat(list, ",") .. ",")
	local a, t = 0, 0
	for id in u do
		if Catalog.Boons[id] then
			a += 1
		elseif Catalog.Gadgets[id] then
			t += 1
		end
	end
	player:SetAttribute("UnlocksAurelius", a)
	player:SetAttribute("UnlocksTayron", t)
end

local function buildOrb(parent: Instance, name: string, at: Vector3, color: Color3, vendor: string)
	local m = Instance.new("Model")
	m.Name = name
	local function part(n: string, size: Vector3, cf: CFrame, c: Color3, props)
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size
		p.CFrame = cf
		p.Color = c
		p.Anchored = true
		p.Material = Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
		p.CastShadow = false
		for k, v in props or {} do
			(p :: any)[k] = v
		end
		p.Parent = m
		return p
	end
	-- stepped pedestal + 4 claw prongs holding the glowing orb
	part("Base", Vector3.new(6, 1, 6), CFrame.new(at + Vector3.new(0, 0.5, 0)), Color3.fromRGB(235, 235, 245))
	part("Base2", Vector3.new(4.4, 1, 4.4), CFrame.new(at + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(45), 0), color:Lerp(Color3.new(1, 1, 1), 0.4))
	part("Column", Vector3.new(2, 3, 2), CFrame.new(at + Vector3.new(0, 3.5, 0)), Color3.fromRGB(235, 235, 245))
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		part("Prong" .. k, Vector3.new(0.5, 2.6, 0.5), CFrame.new(at + Vector3.new(math.cos(a) * 1.4, 6, math.sin(a) * 1.4)) * CFrame.Angles(math.sin(a) * 0.35, 0, -math.cos(a) * 0.35), color)
	end
	local orb = part("Orb", Vector3.one * 3.4, CFrame.new(at + Vector3.new(0, 7.2, 0)), color, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false })
	local core = part("Core", Vector3.one * 1.6, orb.CFrame, Color3.new(1, 1, 1), { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 20
	light.Brightness = 2
	light.Parent = orb
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Rate = 10
	e.Size = NumberSequence.new(0.5, 0)
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Parent = orb
	-- sign: name + how it works (+ the viewer's own unlock count via the client)
	local gui = Instance.new("BillboardGui")
	gui.Name = "OrbSign"
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 80
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = color
	title.TextStrokeTransparency = 0.3
	title.Text = shown(vendor) .. "'s Orb"
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.Position = UDim2.fromScale(0, 0.55)
	sub.Size = UDim2.new(1, 0, 0.45, 0)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(240, 240, 250)
	sub.TextStrokeTransparency = 0.4
	sub.Text = "Offer a cloud you carry to unlock items"
	sub.Parent = gui
	gui.Parent = orb
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OrbPrompt"
	prompt.ActionText = "Offer Cloud"
	prompt.ObjectText = shown(vendor) .. "'s Orb"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = orb
	m:SetAttribute("Vendor", vendor)
	m.Parent = parent
	-- slow spin of the core
	task.spawn(function()
		while m.Parent do
			TweenService:Create(core, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = Vector3.one * 2 }):Play()
			task.wait(1.5)
			TweenService:Create(core, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = Vector3.one * 1.4 }):Play()
			task.wait(1.5)
		end
	end)
	return m, prompt, orb
end

local function offer(player: Player, vendor: string, orb: BasePart)
	local carrying = player:GetAttribute("Carrying")
	if not carrying then
		hint(player, `Bring a cloud here to unlock {shown(vendor)}'s items. Open the shop to see which clouds are needed.`, 5)
		return
	end
	if player:GetAttribute("CarryingStolen") then
		Sfx.At("OrbRefuse", orb.Position)
		hint(player, "The Orb refuses stolen clouds!", 4)
		return
	end
	local want = Catalog.ByCloud[carrying]
	local u = unlocks(player)
	if not u then
		return
	end
	if not want or want.Vendor ~= vendor then
		local other = want and want.Vendor or nil
		hint(player, other and `This cloud unlocks something at {shown(other)}'s Orb instead.` or "This Orb does not want that cloud.", 4)
		return
	end
	if u[want.Id] then
		hint(player, "You already unlocked that one.", 3)
		return
	end
	local taken = WeatherService.ConsumeCarry(player)
	if taken == "stolen" then
		hint(player, "The Orb refuses stolen clouds!", 4)
		return
	elseif taken ~= carrying then
		return
	end
	u[want.Id] = true
	Sfx.At("OrbOffer", orb.Position)
	syncAttr(player)
	DataService.SaveSoon(player)
	local entry = Catalog.Boons[want.Id] or Catalog.Gadgets[want.Id]
	hint(player, `Unlocked {entry.DisplayName} at {shown(vendor)}!`, 5)
	-- absorb flash
	local flash = orb:Clone()
	flash:ClearAllChildren()
	flash.Parent = orb.Parent
	TweenService:Create(flash, TweenInfo.new(0.6), { Size = Vector3.one * 12, Transparency = 1 }):Play()
	game:GetService("Debris"):AddItem(flash, 0.7)
	print(`[Orbs] {player.Name} unlocked {want.Id} with {carrying}`)
end

function VendorOrbService.Start(dataService, weatherService, remotes)
	DataService, WeatherService, Remotes = dataService, weatherService, remotes
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 60)
		local decor = map and map:WaitForChild("Decor", 60)
		if not decor then
			warn("[Orbs] no Map/Decor")
			return
		end
		local function place(shopName: string, orbName: string, vendor: string, color: Color3)
			local shop = decor:WaitForChild(shopName, 30)
			if not shop then
				return
			end
			local pivot = shop:GetPivot()
			-- beside the stall, on the hub floor (side away from the benches)
			local at = Vector3.new(pivot.Position.X, map:FindFirstChild("Hub") and pivot.Position.Y or pivot.Position.Y, pivot.Position.Z + 13)
			local ray = workspace:Raycast(at + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0))
			if ray then
				at = Vector3.new(at.X, ray.Position.Y, at.Z)
			end
			local _, prompt, orb = buildOrb(decor, orbName, at, color, vendor)
			prompt.Triggered:Connect(function(player)
				offer(player, vendor, orb)
			end)
		end
		place("UpgradeShop", "AureliusOrb", "Aurelius", Color3.fromRGB(255, 200, 90))
		place("ItemShop", "TayronOrb", "Tayron", Color3.fromRGB(120, 200, 255))
	end)
	local function setup(player: Player)
		task.spawn(function()
			for _ = 1, 40 do
				if DataService.Get(player) then
					break
				end
				task.wait(0.5)
			end
			syncAttr(player)
		end)
	end
	for _, p in Players:GetPlayers() do
		setup(p)
	end
	Players.PlayerAdded:Connect(setup)
end

return VendorOrbService
