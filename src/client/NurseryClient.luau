-- v2.35 SHARED NURSERY, client side. There is ONE Egg Nursery per server
-- (Map/Expansion/SharedNursery). Everybody uses it, but each player only sees
-- THEIR OWN egg on the cradle, their own timer on the board, their own prompt
-- text and their own hatch show - all drawn locally from player attributes:
--   IncubEgg (egg key | nil), IncubReadyAt (server time), EggsWaiting (count)
-- The server sends NurseryHatch(eggKey, petId) to play the hatch reveal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local PetDefs = require(ReplicatedStorage.Shared.PetDefs)
local PetModels = require(ReplicatedStorage.Shared.PetModels)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local FxKit = require(ReplicatedStorage.Shared.FxKit)

local NurseryClient = {}

local player = Players.LocalPlayer
local RARITY_INDEX = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
local localEgg: Model? = nil
local hatchingNow = false

local function nursery(): Model?
	local map = workspace:FindFirstChild("Map")
	local exp = map and map:FindFirstChild("Expansion")
	return exp and exp:FindFirstChild("SharedNursery") or nil
end

local function fx(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	Debris:AddItem(p, 15)
	return p
end

local FxKit = require(game:GetService("ReplicatedStorage").Shared.FxKit)

local function emit(parent: Instance, color: Color3, count: number, speed: number, size: number, texture: string?)
	local e = Instance.new("ParticleEmitter")
	e.Color = FxKit.Hot(color)
	e.Texture = texture or FxKit.Texture("Glow")
	e.LightEmission = 1
	e.LightInfluence = 0
	pcall(function()
		(e :: any).Brightness = 2.5
	end)
	e.Size = FxKit.NS({ { 0, size * 0.5 }, { 0.15, size }, { 1, 0 } })
	e.Lifetime = NumberRange.new(0.6, 1.4)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = parent
	e:Emit(count)
	Debris:AddItem(e, 3)
end



local function showEgg()
	if hatchingNow then
		return
	end
	local hut = nursery()
	local spot = hut and hut:FindFirstChild("EggSpot")
	local key = player:GetAttribute("IncubEgg")
	if localEgg and (not key or localEgg:GetAttribute("Egg") ~= key) then
		localEgg:Destroy()
		localEgg = nil
	end
	if key and spot and not localEgg and PetDefs.Eggs[key] then
		local egg = PetModels.Egg(key, 0.8)
		egg:SetAttribute("Egg", key)
		egg:PivotTo(spot.CFrame)
		egg.Parent = workspace
		localEgg = egg
	end
end

local function hatchShow(eggKey: string, petId: string)
	local def = PetDefs.Types[petId]
	local hut = nursery()
	local spot = hut and hut:FindFirstChild("EggSpot")
	if not def or not spot then
		return
	end
	hatchingNow = true
	local egg = localEgg
	localEgg = nil
	if not egg then
		egg = PetModels.Egg(eggKey, 0.8)
		egg:PivotTo(spot.CFrame)
		egg.Parent = workspace
	end
	local rar = RARITY_INDEX[def.Rarity] or 1
	local rcolor = PetDefs.RARITY[def.Rarity].Color
		if egg and spot then
			local base = egg:GetPivot()
			local light = Instance.new("PointLight")
			light.Color = rcolor
			light.Range = 12
			light.Brightness = 0
			light.Parent = egg.PrimaryPart
			-- escalating charge: one wobble+pulse per rarity step
			-- v2.17 EPIC / LEGENDARY CINEMATIC: a light pillar from the sky, three
			-- orbiting rings of glowing motes, the egg levitates higher with every
			-- pulse, shockwaves; at the burst: spinning light rays, a giant flash,
			-- confetti, and the pet descends from above in a halo
			local show = rar >= 4
			local showParts = {}
			if show then
				local top = base.Position
				local pillar = fx(Vector3.new(220, 1, 1), CFrame.new(top + Vector3.new(0, 110, 0)) * CFrame.Angles(0, 0, math.pi / 2), rcolor, Enum.PartType.Cylinder)
				pillar.Transparency = 0.35
				TweenService:Create(pillar, TweenInfo.new(1.2), { Size = Vector3.new(220, 9, 9) }):Play()
				table.insert(showParts, pillar)
				for ringN = 1, 3 do
					for k = 1, 8 do
						local mote = fx(Vector3.one * 0.7, CFrame.new(top), ringN == 2 and Color3.fromRGB(255, 240, 180) or rcolor, Enum.PartType.Ball)
						table.insert(showParts, mote)
						task.spawn(function()
							local t0 = os.clock()
							while mote.Parent do
								local t = os.clock() - t0
								local a = k / 8 * math.pi * 2 + t * (1.5 + ringN * 0.8) * (ringN % 2 == 0 and -1 or 1)
								local es = math.max(1, egg:GetScale() / 0.8) -- rings widen as the egg grows
								local r = (4 + ringN * 1.6) * es
								mote.CFrame = CFrame.new(egg:GetPivot().Position + Vector3.new(math.cos(a) * r, (ringN * 1.5 + math.sin(t * 2 + k) * 0.4) * es, math.sin(a) * r))
								task.wait()
							end
						end)
					end
				end
				Sfx.Global("BossArrive")
			end
			-- v2.21 director: the rarer the pet, the BIGGER the egg grows before it
			-- cracks (Legendary ~20 studs = 3-4 players tall). Big eggs rise up
			-- out of the glass dome so they never clip the hut.
			local TARGET_H = { 5.5, 7.5, 10, 15, 21 } -- egg height (studs) per rarity
			local EGG_H = 5.6 -- egg model height at scale 1
			local startScale = egg:GetScale()
			local endScale = math.max(startScale, (TARGET_H[rar] or 6) / EGG_H)
			local lift = rar >= 3 and 11 or 0 -- clear the dome top
			local base0 = base
			local steps = 1 + rar
			for step = 1, steps do
				local f = step / steps
				local grow = startScale + (endScale - startScale) * f
				egg:ScaleTo(grow)
				base = base0 + Vector3.new(0, lift * math.min(1, f * 1.5), 0)
				if show then
					base += Vector3.new(0, 0.7 * step, 0) -- levitate
					local ring = fx(Vector3.new(0.3, 2, 2), CFrame.new(spot.Position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), rcolor, Enum.PartType.Cylinder)
					TweenService:Create(ring, TweenInfo.new(0.6), { Size = Vector3.new(0.2, 26 + step * 4, 26 + step * 4), Transparency = 1 }):Play()
					game:GetService("Debris"):AddItem(ring, 0.7)
				end
				local deep = 1 / math.sqrt(grow / startScale) -- bigger egg = deeper crack
				for k = 1, 8 do
					egg:PivotTo(base * CFrame.Angles(0, 0, math.sin(k * 1.6) * 0.18 * (step / 2)))
					if k == 3 or k == 6 then
						Sfx.At("HatchCrack", egg:GetPivot().Position, deep * (0.9 + math.random() * 0.25))
					end
					task.wait(0.04)
				end
				light.Brightness = step * 1.2
				Sfx.At("HatchPulse", egg:GetPivot().Position, deep * (0.9 + step * 0.05))
				-- v2.22: a crack flash on the shell each pulse
				FxKit.Impact(egg:GetPivot().Position + Vector3.new(math.random(-10, 10) / 10, 2.8 * grow, math.random(-10, 10) / 10), step >= 3 and rcolor or Color3.fromRGB(255, 245, 220), 0.6 + grow * 0.4)
				light.Range = 10 + step * 6 + grow * 4
				emit(egg.PrimaryPart, step >= 3 and rcolor or Color3.fromRGB(255, 255, 255), 8 + step * 10, 6 + step * 3, 0.4 + step * 0.1, "rbxasset://textures/particles/sparkles_main.dds")
				task.wait(0.35)
			end
			-- burst: shell layers fly apart
			local eggScale = egg:GetScale()
			local pos = egg:GetPivot().Position + Vector3.new(0, 2.8 * eggScale, 0) -- egg centre
			for _, w in egg:GetDescendants() do
				if w:IsA("WeldConstraint") or w:IsA("Weld") then
					w:Destroy()
				end
			end
			for _, p in egg:GetDescendants() do
				if p:IsA("BasePart") and p.Name ~= "Root" then
					p.Anchored = true
					local out = (p.Position - pos)
					out = out.Magnitude > 0.1 and out.Unit or Vector3.yAxis
					TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						CFrame = p.CFrame + out * (4 + eggScale * 3) + Vector3.new(0, 2, 0), Transparency = 1,
					}):Play()
				end
			end
			emit(egg.PrimaryPart, rcolor, 30 + rar * 25, 18 + rar * 4, 1)
			-- v2.22 layered burst, bigger for rarer eggs
			if rar >= 4 then
				FxKit.Explosion(pos, rcolor, 0.8 + eggScale * 0.5)
				FxKit.Tornado(spot.Position, rcolor, 1.2 + rar * 0.2, 1.8)
			else
				FxKit.Burst(pos, rcolor, 0.7 + eggScale * 0.4)
			end
			Sfx.At("HatchBurst", pos, 1 / math.sqrt(eggScale / startScale))
			if show then
				-- spinning light rays + flash + confetti
				local flash = Instance.new("PointLight")
				flash.Color = rcolor
				flash.Range = 60
				flash.Brightness = 10
				flash.Parent = spot
				TweenService:Create(flash, TweenInfo.new(2), { Brightness = 0 }):Play()
				game:GetService("Debris"):AddItem(flash, 2.2)
				for k = 1, 12 do
					local a = k / 12 * math.pi * 2
					local ray = fx(Vector3.new(0.6, 0.6, 30), CFrame.new(pos) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -15), k % 2 == 0 and rcolor or Color3.fromRGB(255, 245, 200))
					ray.Transparency = 0.2
					TweenService:Create(ray, TweenInfo.new(1.6), { CFrame = CFrame.new(pos) * CFrame.Angles(0, a + 1.2, 0) * CFrame.new(0, 0, -15), Transparency = 1 }):Play()
					game:GetService("Debris"):AddItem(ray, 1.7)
				end
				emit(spot, Color3.fromRGB(255, 230, 120), 200, 35, 0.9)
				emit(spot, rcolor, 200, 30, 0.8)
				for _, part in showParts do
					TweenService:Create(part, TweenInfo.new(1), { Transparency = 1 }):Play()
					game:GetService("Debris"):AddItem(part, 1.1)
				end
			end
			if rar >= 5 then
				Sfx.Global("HatchLegendary")
			end
			Debris:AddItem(egg, 1)
			-- the pet pops out, spins and lands
			local pet = PetModels.Build(petId)
			pet:SetAttribute("NoAnim", true) -- scaled during the reveal: PetAnimator leaves it alone
			pet:PivotTo(spot.CFrame + Vector3.new(0, 1, 0))
			pet:ScaleTo(0.3)
			pet.Parent = hut
			local frames = show and 40 or 12
			local halo = show and fx(Vector3.new(0.3, 5, 5), spot.CFrame, Color3.fromRGB(255, 235, 150), Enum.PartType.Cylinder) or nil
			for k = 1, frames do
				local f = k / frames
				pet:ScaleTo(0.3 + 0.7 * f)
				local h = show and (14 * (1 - f) + 1) or (1 + math.sin(f * math.pi) * 3)
				pet:PivotTo(spot.CFrame * CFrame.new(0, h, 0) * CFrame.Angles(0, f * math.pi * (show and 6 or 4), 0))
				if halo then
					halo.CFrame = CFrame.new(spot.Position + Vector3.new(0, h + 4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				end
				task.wait(0.04)
			end
			if halo then
				TweenService:Create(halo, TweenInfo.new(1), { Transparency = 1 }):Play()
				game:GetService("Debris"):AddItem(halo, 1.1)
			end
			task.wait(1.6)
			pet:Destroy()
		end

	hatchingNow = false
	showEgg()
end

-- the board above the door + the prompt text: yours only
local function updateBoard()
	local hut = nursery()
	if not hut then
		return
	end
	local board = hut:FindFirstChild("TimerBoard")
	local label = board and board:FindFirstChild("Timer") and board.Timer:FindFirstChild("Text")
	local promptPart = hut:FindFirstChild("IncubatorPrompt")
	local prompt = promptPart and promptPart:FindFirstChild("IncubatorPrompt")
	local key = player:GetAttribute("IncubEgg")
	local readyAt = player:GetAttribute("IncubReadyAt")
	local text, action, color
	if not key then
		local n = player:GetAttribute("EggsWaiting") or 0
		text = n > 0 and `{n} egg(s) waiting` or "Bring an egg!"
		action = "Incubate"
		color = Color3.fromRGB(255, 240, 200)
	else
		local left = math.max(0, math.floor((readyAt or 0) - workspace:GetServerTimeNow()))
		if left > 0 then
			text = string.format("%d:%02d", left // 60, left % 60)
			action = "Check"
			color = Color3.fromRGB(255, 240, 200)
		else
			text = "READY!"
			action = "Hatch!"
			color = Color3.fromRGB(120, 255, 140)
		end
	end
	if label then
		label.Text = text
		label.TextColor3 = color
	end
	if prompt then
		prompt.ActionText = action
		prompt.ObjectText = "Egg Nursery"
	end
end

function NurseryClient.Start()
	player:GetAttributeChangedSignal("IncubEgg"):Connect(showEgg)
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NurseryHatch", 60).OnClientEvent:Connect(function(eggKey, petId)
		task.spawn(hatchShow, eggKey, petId)
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			pcall(showEgg) -- also catches the nursery streaming in later
			pcall(updateBoard)
		end
	end)
end

return NurseryClient
