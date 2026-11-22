-- v2.35 POSEIDON THE BLACKSMITH + BIOME TOTEMS + REALM ALTARS (director).
--   * normal monsters (never bosses) drop their biome's materials to the killer
--   * Hephaestus (hub, south forge pad) forges a biome totem from its recipe
--     (Shared/ForgeDefs); client UI: Client/ForgeUi via OpenShop("Forge")
--   * the Altar on each temple shrine (behind the boss) takes that biome's
--     totem and teleports you into the biome's realm (placeholder platforms
--     far above the world, each with a return portal)
-- Data: d.Materials = { [id] = count }, d.Totems = { [biome] = count }
-- Client attributes (JSON): "Materials", "Totems"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ForgeDefs = require(ReplicatedStorage.Shared.ForgeDefs)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local FxKit = require(ReplicatedStorage.Shared.FxKit)
local TotemModels = require(ReplicatedStorage.Shared.TotemModels)

local ForgeService = {}

local DataService, Remotes
local REALM_Y = 1400
local realmSpots = {} -- [biome] = CFrame where you arrive
local altarSpots = {} -- [biome] = CFrame back at the temple

local function data(player: Player)
	local d = DataService.Get(player)
	if d then
		d.Materials = d.Materials or {}
		d.Totems = d.Totems or {}
		d.TotemsSeen = d.TotemsSeen or {} -- v2.39 ever owned -> forge window shows its 3D model
	end
	return d
end

-- v2.40 (director): totems are real items in your inventory (a Tool per
-- biome, "Mesa Totem x2"), held upright in the hand like the gear. The count
-- itself stays in d.Totems; the tools only mirror it.
local function makeTotemTool(biome: string): Tool?
	local model = TotemModels.Make(biome)
	if not model then
		return nil
	end
	local tool = Instance.new("Tool")
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = `Offer it at the altar behind the {biome} boss`
	tool:SetAttribute("TotemBiome", biome)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 0.5)
	handle.Transparency = 1
	handle.CanCollide, handle.CanQuery, handle.CanTouch, handle.Massless = false, false, false, true
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	tool.Grip = CFrame.new()
	-- grip at the bottom centre, ~2.6 studs tall, upright
	local bbCF, bbSize = model:GetBoundingBox()
	local grip = bbCF.Position - Vector3.new(0, bbSize.Y / 2 - 0.3, 0)
	local k = 2.6 / math.max(bbSize.X, bbSize.Y, bbSize.Z, 0.1)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local cf = CFrame.new(-grip) * part.CFrame
			part.Size *= k
			part.CFrame = CFrame.new(cf.Position * k) * cf.Rotation
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, false, true
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = handle, part
			w.Parent = part
		end
	end
	model.Parent = tool
	return tool
end

local function syncTools(player: Player)
	local d = DataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not d or not d.Totems or not backpack then
		return
	end
	local have = {}
	for _, where in { backpack, player.Character } do
		if where then
			for _, t in where:GetChildren() do
				local b = t:IsA("Tool") and t:GetAttribute("TotemBiome")
				if b then
					if have[b] then
						t:Destroy() -- duplicate
					else
						have[b] = t
					end
				end
			end
		end
	end
	for _, biome in ForgeDefs.Biomes do
		local n = d.Totems[biome] or 0
		local tool = have[biome]
		if n <= 0 then
			if tool then
				tool:Destroy()
			end
		else
			if not tool then
				tool = makeTotemTool(biome)
				if tool then
					tool.Parent = backpack
				end
			end
			if tool then
				local name = ForgeDefs.Totems[biome].Name
				tool.Name = n > 1 and `{name} x{n}` or name
			end
		end
	end
end

local function sync(player: Player)
	local d = data(player)
	if not d then
		return
	end
	player:SetAttribute("Materials", HttpService:JSONEncode(d.Materials))
	for biome, n in d.Totems do
		if n > 0 then
			d.TotemsSeen[biome] = true
		end
	end
	player:SetAttribute("Totems", HttpService:JSONEncode(d.Totems))
	player:SetAttribute("TotemsSeen", HttpService:JSONEncode(d.TotemsSeen))
	syncTools(player)
end
ForgeService.Sync = sync

local function hint(player: Player, text: string, t: number?)
	if Remotes and Remotes.Hint then
		Remotes.Hint:FireClient(player, text, t or 3)
	end
end

-- QA helper
function ForgeService.Give(player: Player, id: string, n: number, quiet: boolean?)
	local d = data(player)
	if d and ForgeDefs.Materials[id] then
		d.Materials[id] = (d.Materials[id] or 0) + n
		sync(player)
		if not quiet then
			hint(player, `+{n} {ForgeDefs.Materials[id].Name} (see Hephaestus' Forge)`, 2)
		end
	end
end
function ForgeService.GiveTotem(player: Player, biome: string, n: number, quiet: boolean?)
	local d = data(player)
	if d and ForgeDefs.Totems[biome] then
		d.Totems[biome] = (d.Totems[biome] or 0) + n
		sync(player)
		if not quiet then
			hint(player, `+{n} {ForgeDefs.Totems[biome].Name} (in your inventory)`, 2)
		end
	end
end

-- a normal monster died: its killer may get a material
local function onKill(player: Player?, info)
	if not player or not player.Parent or not info or info.Def.Boss or info.Def.Summon then
		return
	end
	local biome = info.Def.Habitat
	local id = ForgeDefs.Roll(biome)
	if not id then
		return
	end
	local d = data(player)
	if not d then
		return
	end
	d.Materials[id] = (d.Materials[id] or 0) + 1
	sync(player)
	local m = ForgeDefs.Materials[id]
	hint(player, `+1 {m.Name}  (bring it to Hephaestus)`, 3)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		FxKit.Impact(root.Position + Vector3.new(0, 2, 0), m.Color, 0.6)
	end
end

-- forge a totem at Hephaestus
local function forge(player: Player, biome: unknown)
	if type(biome) ~= "string" or not ForgeDefs.Totems[biome] then
		return
	end
	-- must stand at Hephaestus
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local near = false
	for _, npc in game:GetService("CollectionService"):GetTagged("Npc") do
		local r = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
		if npc.Name == "Hephaestus" and root and r and (r.Position - root.Position).Magnitude < 24 then
			near = true
		end
	end
	if not near then
		return
	end
	local d = data(player)
	if not d then
		return
	end
	for _, m in ForgeDefs.ByBiome[biome] do
		if (d.Materials[m[1]] or 0) < m[5] then
			hint(player, `Not enough {m[2]} (need {m[5]}).`, 3)
			return
		end
	end
	for _, m in ForgeDefs.ByBiome[biome] do
		d.Materials[m[1]] -= m[5]
	end
	d.Totems[biome] = (d.Totems[biome] or 0) + 1
	sync(player)
	DataService.SaveSoon(player)
	local t = ForgeDefs.Totems[biome]
	hint(player, `Hephaestus forged a {t.Name}! Offer it at the altar behind the {biome} boss.`, 5)
	if root then
		FxKit.Explosion(root.Position + Vector3.new(0, 2, 0), t.Color, 0.8)
		Sfx.At("HitGadget", root.Position)
	end
end

------------------------------------------------------------------------
-- realms (placeholders: themed platform + sign + return portal)
------------------------------------------------------------------------
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function teleport(player: Player, cf: CFrame)
	local char = player.Character
	if not char then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)
	char:PivotTo(cf + Vector3.new(0, 4, 0))
end

local function buildRealms()
	local folder = Instance.new("Model")
	folder.Name = "Realms"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for i, biome in ForgeDefs.Biomes do
		local t = ForgeDefs.Totems[biome]
		local center = Vector3.new(-3000 + i * 500, REALM_Y, 3000)
		local m = Instance.new("Model")
		m.Name = biome .. "Realm"
		local deck = part(m, "Floor", Vector3.new(140, 4, 140), CFrame.new(center), t.Color:Lerp(Color3.new(1, 1, 1), 0.35), { Material = Enum.Material.Slate })
		deck.TopSurface = Enum.SurfaceType.Studs
		part(m, "Rim", Vector3.new(146, 2, 146), CFrame.new(center - Vector3.new(0, 2.5, 0)), t.Color, { Material = Enum.Material.Neon })
		-- a few themed pillars so it reads as that biome
		for k = 1, 8 do
			local a = k / 8 * math.pi * 2
			local p = center + Vector3.new(math.cos(a) * 55, 0, math.sin(a) * 55)
			part(m, "Pillar" .. k, Vector3.new(5, 18 + (k % 3) * 6, 5), CFrame.new(p + Vector3.new(0, 11, 0)) * CFrame.Angles(0, a, 0), t.Color:Lerp(Color3.new(0, 0, 0), 0.25))
			part(m, "PillarGlow" .. k, Vector3.one * 3, CFrame.new(p + Vector3.new(0, 23 + (k % 3) * 6, 0)), t.Color, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, CanCollide = false })
		end
		-- sign
		local sign = part(m, "Sign", Vector3.new(30, 8, 1), CFrame.new(center + Vector3.new(0, 14, -40)), Color3.fromRGB(30, 30, 45))
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = t.Color:Lerp(Color3.new(1, 1, 1), 0.4)
		label.Text = `{t.Realm}\ncoming soon`
		label.Parent = gui
		gui.Parent = sign
		-- arrival point + return portal
		local arrive = CFrame.new(center + Vector3.new(0, 3, 20))
		realmSpots[biome] = arrive
		local ring = part(m, "ReturnPortal", Vector3.new(1, 14, 14), CFrame.new(center + Vector3.new(0, 9, 45)) * CFrame.Angles(0, math.pi / 2, 0), t.Color,
			{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false })
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Return"
		prompt.ObjectText = "Portal home"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = ring
		prompt.Triggered:Connect(function(player)
			local back = altarSpots[biome]
			if back then
				teleport(player, back)
				hint(player, "Back from " .. t.Realm .. "!", 3)
			end
		end)
		m.Parent = folder
	end
	folder.Parent = workspace
end

------------------------------------------------------------------------
-- altars on the temple shrines
------------------------------------------------------------------------
local function hookAltars()
	local map = workspace:WaitForChild("Map", 120)
	local temples = map and map:WaitForChild("Temples", 120)
	if not temples then
		warn("[Forge] no Map/Temples: totem altars missing")
		return
	end
	task.wait(1)
	for _, temple in temples:GetChildren() do
		local biome = temple:GetAttribute("Biome")
		local altar = temple:FindFirstChild("Altar", true) :: BasePart?
		local t = biome and ForgeDefs.Totems[biome]
		if altar and t and not altar:FindFirstChild("TotemPrompt") then
			altarSpots[biome] = altar.CFrame * CFrame.new(0, 0, -6)
			local glow = Instance.new("PointLight")
			glow.Color = t.Color
			glow.Range = 16
			glow.Brightness = 2
			glow.Parent = altar
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "TotemPrompt"
			prompt.ActionText = "Offer " .. t.Name
			prompt.ObjectText = t.Realm
			prompt.HoldDuration = 1
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = altar
			prompt.Triggered:Connect(function(player)
				local d = data(player)
				if not d then
					return
				end
				if (d.Totems[biome] or 0) <= 0 then
					hint(player, `You need a {t.Name}. Hephaestus forges it from {biome} materials.`, 4)
					return
				end
				if player:GetAttribute("Carrying") or player:GetAttribute("CarryingEgg") then
					hint(player, "Put down what you carry first.", 3)
					return
				end
				d.Totems[biome] -= 1
				sync(player)
				DataService.SaveSoon(player)
				-- v2.39 the offered totem appears on the altar, then fades into the pillar
				local shown = TotemModels.Make(biome)
				if shown then
					shown:PivotTo(CFrame.new(altar.Position + Vector3.new(0, altar.Size.Y / 2 + 4, 0)))
					shown.Parent = workspace
					task.delay(2.5, function()
						shown:Destroy()
					end)
				end
				FxKit.Pillar(altar.Position, t.Color, 60, 1.2)
				Sfx.At("OrbOffer", altar.Position)
				task.wait(0.8)
				local spot = realmSpots[biome]
				if spot then
					teleport(player, spot)
					hint(player, `Welcome to the {t.Realm}!`, 4)
				end
			end)
		end
	end
end

function ForgeService.Start(dataService, monsterService, remotes)
	DataService, Remotes = dataService, remotes
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	local forgeRemote = Instance.new("RemoteEvent")
	forgeRemote.Name = "Forge"
	forgeRemote.Parent = folder
	forgeRemote.OnServerEvent:Connect(forge)
	monsterService.OnKill = onKill
	buildRealms()
	task.spawn(hookAltars)
	local function setup(player: Player)
		task.spawn(function()
			for _ = 1, 40 do
				if DataService.Get(player) then
					break
				end
				task.wait(0.5)
			end
			sync(player)
		end)
		-- the Backpack is rebuilt on every respawn: put the totems back
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			syncTools(player)
		end)
	end
	for _, p in Players:GetPlayers() do
		setup(p)
	end
	Players.PlayerAdded:Connect(setup)
end

return ForgeService
