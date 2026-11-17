-- STUDIO-ONLY STYLE SAMPLE (director review before the full v2.1 art pass).
-- A small floating island built in the classic studded Roblox style:
-- studded plastic plates for walkable surfaces, with ROUND/organic shapes
-- assembled from balls, cylinders, wedges and corner wedges (a round tower
-- with a dome, a rounded hill, an arch, a curving path, a tree, a pond,
-- rock underside) + a display Skyfin (the shark-style monster anchor).
--
--   workspace.StyleSample           (QA panel: "TP Style sample")
-- Never built in a live game.

local RunService = game:GetService("RunService")

local StyleSample = {}

local CENTER = Vector3.new(0, 90, 720) -- outside the continent edge, above the cloud bank

local folder: Folder

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, opts: { [string]: any }?)
	opts = opts or {}
	local p = Instance.new(opts.Class or "Part") :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = opts.Material or Enum.Material.Plastic
	if opts.Shape then
		(p :: Part).Shape = Enum.PartType[opts.Shape]
	end
	if opts.Studs ~= false and p.Material == Enum.Material.Plastic then
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Inlet
	end
	if opts.Transparency then
		p.Transparency = opts.Transparency
	end
	p.Parent = folder
	return p
end

local function build(MonsterRigs)
	folder = Instance.new("Folder")
	folder.Name = "StyleSample"
	folder.Parent = workspace
	local C = CFrame.new(CENTER)
	local grass, dirt, stone = Color3.fromRGB(95, 175, 75), Color3.fromRGB(150, 105, 70), Color3.fromRGB(160, 160, 165)

	-- island: studded grass plate with corner wedges to round the outline,
	-- a dirt layer and a rounded rock underside
	part("Plate", Vector3.new(56, 2, 40), C, grass)
	part("PlateX", Vector3.new(40, 2, 56), C, grass)
	for i, rot in { 0, 90, 180, 270 } do
		part("Corner" .. i, Vector3.new(8, 2, 8), C * CFrame.Angles(0, math.rad(rot), 0) * CFrame.new(24, 0, 24) * CFrame.Angles(0, math.rad(180), 0),
			grass, { Class = "CornerWedgePart" })
	end
	part("Dirt", Vector3.new(50, 6, 50), C * CFrame.new(0, -4, 0), dirt, { Studs = false })
	for i, spec in { { V = Vector3.new(0, -12, 0), S = 34 }, { V = Vector3.new(10, -18, 6), S = 18 }, { V = Vector3.new(-9, -17, -7), S = 16 } } do
		part("Rock" .. i, Vector3.one * spec.S, C * CFrame.new(spec.V), stone:Lerp(Color3.fromRGB(110, 105, 110), i / 4), { Shape = "Ball" })
	end

	-- rounded hill (balls half-sunk into the plate)
	part("Hill", Vector3.one * 16, C * CFrame.new(-14, -3, 12), Color3.fromRGB(110, 190, 85), { Shape = "Ball" })
	part("HillTop", Vector3.one * 7, C * CFrame.new(-12, 4, 11), Color3.fromRGB(125, 205, 95), { Shape = "Ball" })

	-- curving studded stone path with a wedge ramp
	for i = 0, 6 do
		local a = math.rad(-40 + i * 16)
		part("Path" .. i, Vector3.new(5, 0.4, 6.5), C * CFrame.new(math.cos(a) * 16, 1.2, math.sin(a) * 16) * CFrame.Angles(0, -a, 0), stone)
	end
	part("Ramp", Vector3.new(6, 2, 6), C * CFrame.new(22, 0, -12) * CFrame.Angles(0, math.rad(-90), 0), stone, { Class = "WedgePart" })

	-- round tower with a dome, windows and a flag
	local towerBase = C * CFrame.new(12, 1, 10)
	part("Tower", Vector3.new(18, 10, 10), towerBase * CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(205, 75, 65), { Shape = "Cylinder" })
	part("TowerRing", Vector3.new(1, 11.4, 11.4), towerBase * CFrame.new(0, 18, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(240, 240, 235), { Shape = "Cylinder" })
	part("Dome", Vector3.one * 10, towerBase * CFrame.new(0, 19.5, 0), Color3.fromRGB(70, 130, 220), { Shape = "Ball" })
	for i = 0, 2 do
		part("Window" .. i, Vector3.new(1.6, 2.4, 0.4), towerBase * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0, 10 + i * 2, -5), Color3.fromRGB(40, 40, 60), { Studs = false })
	end
	part("FlagPole", Vector3.new(0.4, 6, 0.4), towerBase * CFrame.new(0, 26, 0), Color3.fromRGB(230, 230, 230))
	part("Flag", Vector3.new(0.2, 2, 3), towerBase * CFrame.new(0, 28, 1.6), Color3.fromRGB(255, 210, 60))

	-- arch: two pillars, a lintel and wedges rounding the opening
	local archCF = C * CFrame.new(-6, 1, -16)
	part("ArchL", Vector3.new(2, 8, 3), archCF * CFrame.new(-4, 4, 0), Color3.fromRGB(240, 220, 160))
	part("ArchR", Vector3.new(2, 8, 3), archCF * CFrame.new(4, 4, 0), Color3.fromRGB(240, 220, 160))
	part("ArchTop", Vector3.new(10, 2, 3), archCF * CFrame.new(0, 9, 0), Color3.fromRGB(240, 220, 160))
	part("ArchWedgeL", Vector3.new(3, 2, 2), archCF * CFrame.new(-2, 7, 0) * CFrame.Angles(0, math.rad(-90), math.rad(180)), Color3.fromRGB(240, 220, 160), { Class = "WedgePart" })
	part("ArchWedgeR", Vector3.new(3, 2, 2), archCF * CFrame.new(2, 7, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)), Color3.fromRGB(240, 220, 160), { Class = "WedgePart" })

	-- tree: round trunk and a cluster of ball leaves
	local treeCF = C * CFrame.new(-18, 1, -4)
	part("Trunk", Vector3.new(8, 2, 2), treeCF * CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 80, 50), { Shape = "Cylinder" })
	for i, spec in { { Vector3.new(0, 9, 0), 7 }, { Vector3.new(2.5, 8, 1.5), 5 }, { Vector3.new(-2.5, 8, -1), 5 }, { Vector3.new(0, 11.5, 0), 4.5 } } do
		part("Leaves" .. i, Vector3.one * spec[2], treeCF * CFrame.new(spec[1]), Color3.fromRGB(70, 160, 70), { Shape = "Ball" })
	end

	-- pond with a studded rim
	part("Pond", Vector3.new(0.4, 10, 10), C * CFrame.new(8, 1.1, -12) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(90, 170, 230),
		{ Shape = "Cylinder", Material = Enum.Material.Glass, Transparency = 0.2 })

	-- display Skyfin (static, anchored)
	local ok, shark = pcall(MonsterRigs.Build, "Skyfin", 1.15)
	if ok and shark then
		shark.Name = "SkyfinDisplay"
		shark:PivotTo(C * CFrame.new(4, 5, 4) * CFrame.Angles(0, math.rad(200), 0))
		for _, d in shark:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		shark.Parent = folder
	end
	print("[StyleSample] built at workspace.StyleSample (QA: TP Style sample)")
end

function StyleSample.Start(MonsterRigs)
	if not RunService:IsStudio() then
		return
	end
	task.delay(4, function()
		build(MonsterRigs)
	end)
end

StyleSample.Center = CENTER
return StyleSample
