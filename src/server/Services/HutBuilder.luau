-- v2.12 base side buildings (director): beside every base
--   Map/Expansion/PetHut<i>        a cosy cloud cottage where your unequipped
--                                  pets idle (PetSpot parts; Residents folder)
--   Map/Expansion/IncubatorHut<i>  the egg nursery on the opposite plot: glass
--                                  dome, egg cradle (EggSpot), timer sign
--                                  (TimerBoard with BillboardGui "Timer")
-- Classic blocky + studded; everything anchored, walkable floors.

local HutBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local A = CFrame.Angles
local rad = math.rad
local RGB = Color3.fromRGB

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
	p.CastShadow = false
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end
local function ball(parent: Instance, name: string, d: number, cf: CFrame, color: Color3, props)
	local p = part(parent, name, V(d, d, d), cf, color, props)
	p.Shape = Enum.PartType.Ball
	return p
end

-- cloud cottage on a 20x20 pad; `base` = pad top centre, -Z faces the base
function HutBuilder.PetHut(parent: Instance, i: number, base: CFrame, accent: Color3): Model
	local m = Instance.new("Model")
	m.Name = "PetHut" .. i
	local cloud, cloud2, wood, roofC = RGB(250, 251, 255), RGB(225, 232, 248), RGB(170, 120, 80), accent:Lerp(RGB(255, 255, 255), 0.35)
	-- floor deck + cloud skirt around it
	part(m, "Floor", V(18, 0.6, 18), base * CF(0, 0.3, 0), RGB(235, 225, 210))
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		ball(m, "Skirt" .. k, 3.4, base * CF(math.cos(a) * 9, 0.4, math.sin(a) * 9), k % 2 == 0 and cloud or cloud2, { CanCollide = false })
	end
	-- walls: rounded cloud walls built from overlapping puffs (back + sides)
	for k = -2, 2 do
		ball(m, "BackPuff" .. k, 4.2, base * CF(k * 2.8, 3, 5.4), cloud)
		ball(m, "BackPuffTop" .. k, 3.4, base * CF(k * 2.6 + 1.2, 5.6, 5.2), cloud2)
	end
	for _, sx in { -1, 1 } do
		for k = -1, 1 do
			ball(m, "SidePuff" .. sx .. k, 4.2, base * CF(sx * 6.4, 3, k * 2.8 + 1.6), cloud)
			ball(m, "SidePuffTop" .. sx .. k, 3.2, base * CF(sx * 6, 5.6, k * 2.6 + 1.2), cloud2)
		end
	end
	-- front wall with a round door and two round windows
	for _, sx in { -1, 1 } do
		ball(m, "FrontPuff" .. sx, 4.2, base * CF(sx * 4.6, 3, -2.6), cloud)
		ball(m, "FrontPuffTop" .. sx, 3.4, base * CF(sx * 3.6, 5.6, -2.4), cloud2)
		local win = part(m, "Window" .. sx, V(0.3, 1.6, 1.6), base * CF(sx * 4.6, 3.6, -4.7) * A(0, rad(90), 0), RGB(150, 210, 255), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false })
		part(m, "WindowFrame" .. sx, V(0.25, 2, 2), win.CFrame * CF(0.1, 0, 0), wood, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	end
	part(m, "DoorArch", V(0.4, 5, 5), base * CF(0, 2.6, -3.4) * A(0, rad(90), 0), wood, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	part(m, "DoorOpening", V(0.5, 4, 4), base * CF(0, 2.2, -3.5) * A(0, rad(90), 0), RGB(60, 45, 40), { Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.3 })
	part(m, "Doormat", V(3.6, 0.15, 2), base * CF(0, 0.67, -5.5), accent)
	-- roof: puffy cloud dome with a coloured ridge and a chimney
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		ball(m, "Roof" .. k, 5, base * CF(math.cos(a) * 3.6, 7.2, math.sin(a) * 3.6 + 1.4), k % 2 == 0 and cloud or cloud2)
	end
	ball(m, "RoofTop", 6, base * CF(0, 8.6, 1.4), cloud)
	part(m, "Ridge", V(1, 0.6, 9), base * CF(0, 11.2, 1.4), roofC)
	part(m, "Chimney", V(1.4, 3, 1.4), base * CF(3.2, 11, 3.6), RGB(200, 170, 150))
	local smoke = part(m, "ChimneyTop", V(1.8, 0.5, 1.8), base * CF(3.2, 12.7, 3.6), RGB(160, 130, 120))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(RGB(250, 250, 255))
	e.Size = NumberSequence.new(1, 3)
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Lifetime = NumberRange.new(2, 3)
	e.Rate = 3
	e.Speed = NumberRange.new(1, 2)
	e.Acceleration = V(0, 1, 0)
	e.Parent = smoke
	-- paw emblem over the door (no text)
	part(m, "PawPad", V(0.3, 1.2, 1.2), base * CF(0, 6.4, -4.4) * A(0, rad(90), 0), accent, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	for k = -1, 1 do
		part(m, "PawToe" .. k, V(0.3, 0.5, 0.5), base * CF(k * 0.7, 7.3 - math.abs(k) * 0.2, -4.4) * A(0, rad(90), 0), accent, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	end
	-- little fence + food bowl + bed cushions inside/outside
	for k = -3, 3 do
		if math.abs(k) > 1 then
			part(m, "Fence" .. k, V(0.4, 1.4, 0.4), base * CF(k * 2.4, 1.3, -8.4), wood)
		end
	end
	part(m, "FenceRail", V(16, 0.3, 0.3), base * CF(0, 1.7, -8.4), wood)
	part(m, "Bowl", V(1.6, 0.5, 1.6), base * CF(-5.5, 0.85, -6.5), accent)
	part(m, "Cushion1", V(3, 0.5, 3), base * CF(-3, 0.85, 2.5), RGB(255, 190, 200))
	part(m, "Cushion2", V(3, 0.5, 3), base * CF(3, 0.85, 2.5), RGB(190, 220, 255))
	-- pet spots (invisible): where unequipped pets idle
	local spots = { V(-3, 0.85, 2.5), V(3, 0.85, 2.5), V(0, 0.65, 0.5), V(-5.5, 0.65, -6.5), V(5, 0.65, -6.5), V(0, 0.65, -6.8) }
	for k, p in spots do
		part(m, "PetSpot", V(1, 0.2, 1), base * CF(p) * A(0, rad(180 + (k - 3) * 20), 0), RGB(255, 0, 0), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	-- prompt: open the pet panel
	local promptPart = part(m, "PetPrompt", V(2, 2, 1), base * CF(0, 2.5, -5.6), RGB(255, 255, 255), { Transparency = 1, CanCollide = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PetsPrompt"
	prompt.ActionText = "Pets"
	prompt.ObjectText = "Pet Hut"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	m:SetAttribute("BaseIndex", i)
	m.Parent = parent
	return m
end

-- egg nursery on the opposite pad; `base` = pad top centre, -Z faces the base
function HutBuilder.IncubatorHut(parent: Instance, i: number, base: CFrame, accent: Color3): Model
	local m = Instance.new("Model")
	m.Name = "IncubatorHut" .. i
	local stone, trim, glassC, warm = RGB(240, 232, 220), accent:Lerp(RGB(255, 255, 255), 0.3), RGB(200, 235, 255), RGB(255, 190, 90)
	part(m, "Floor", V(18, 0.6, 18), base * CF(0, 0.3, 0), RGB(230, 220, 205))
	-- raised round-ish floor + an octagonal low wall with an OPEN front
	-- (v2.13 director: nothing may block the entrance)
	for x = 0, 1 do
		-- v2.34: the two rotated squares overlapped at the SAME height and z-fought
		part(m, "Inner" .. x, V(13, 2.3, 13), base * CF(0, 1.75 - x * 0.04, 0) * A(0, x * math.pi / 4, 0), RGB(250, 240, 225))
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		if k ~= 6 then -- k = 6 points at -Z: the entrance faces the base
			part(m, "Wall" .. k, V(5.6, 1.4, 0.8), base * CF(math.cos(a) * 7.1, 3.6, math.sin(a) * 7.1) * A(0, -a + math.pi / 2, 0), stone)
		end
	end
	-- glass dome (readable from outside) on 8 posts
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		part(m, "Post" .. k, V(0.8, 7, 0.8), base * CF(math.cos(a) * 6.8, 6, math.sin(a) * 6.8), trim)
	end
	part(m, "Dome", V(14, 9, 14), base * CF(0, 9.5, 0), glassC, { Shape = Enum.PartType.Ball, Material = Enum.Material.Glass, Transparency = 0.55, CanCollide = false })
	part(m, "DomeRing", V(0.6, 15, 15), base * CF(0, 9.6, 0) * A(0, 0, rad(90)), trim, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	part(m, "DomeCap", V(2, 1, 2), base * CF(0, 14.2, 0), trim)
	-- warm heat lamp + cradle with straw
	local lamp = part(m, "HeatLamp", V(1.6, 1, 1.6), base * CF(0, 12.8, 0), warm, { Material = Enum.Material.Neon })
	local l = Instance.new("PointLight")
	l.Color = warm
	l.Range = 18
	l.Brightness = 1.5
	l.Parent = lamp
	part(m, "Cradle", V(5, 1.2, 5), base * CF(0, 3.5, 0), RGB(170, 120, 80))
	for k = 1, 8 do
		local a = k * 0.8
		part(m, "Straw" .. k, V(0.2, 0.2, 2.4), base * CF(math.cos(a) * 1.3, 4.2, math.sin(a) * 1.3) * A(0, a, rad(10)), RGB(240, 215, 130), { CanCollide = false })
	end
	-- where the egg sits (EggService puts the egg model here)
	part(m, "EggSpot", V(1, 0.2, 1), base * CF(0, 4.2, 0), RGB(255, 0, 0), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	-- entrance gap in the low wall: steps over it
	part(m, "Step", V(5, 1, 2), base * CF(0, 1.1, -8), trim)
	part(m, "Step2", V(5, 1, 1.2), base * CF(0, 1.9, -7), trim)
	-- timer sign facing the base
	-- v2.15: the sign stands on two posts in front of the entrance, clear of the dome
	for _, x in { -3.4, 3.4 } do
		part(m, "SignPost" .. x, V(0.5, 11, 0.5), base * CF(x, 5.5, -10.2), trim)
	end
	local board = part(m, "TimerBoard", V(7.4, 3, 0.5), base * CF(0, 12.2, -10.2), RGB(60, 50, 70))
	-- v2.16: the text is painted ON the board's front face (a floating label
	-- used to sink into the board)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Timer"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = RGB(255, 240, 200)
	label.TextStrokeTransparency = 0.3
	label.Text = "Empty"
	label.Parent = gui
	gui.Parent = board
	-- prompt
	local promptPart = part(m, "IncubatorPrompt", V(2, 2, 1), base * CF(0, 2.5, -8), RGB(255, 255, 255), { Transparency = 1, CanCollide = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "IncubatorPrompt"
	prompt.ActionText = "Incubate"
	prompt.ObjectText = "Egg Nursery"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	m:SetAttribute("BaseIndex", i)
	m.Parent = parent
	return m
end

return HutBuilder
