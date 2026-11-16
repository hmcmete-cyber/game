-- The Cloud Shop: an open-air wooden stall with a cloud roof, behind the
-- spawn. Built from parts so it works without any uploaded assets.
--
-- CloudShop (Model)
-- ├── Deck, Steps                     wooden floor + stairs
-- ├── Counter, CounterTop, Shelf*      the stall
-- ├── Post1..4, Beam*                  frame
-- ├── Awning* (striped)                pastel canopy
-- ├── RoofCloud* (ellipsoids)          fluffy cloud on the roof
-- ├── Lantern* (+PointLight)           warm lights
-- ├── Bottle*, Crate*, Pot*, Flower*   props
-- ├── Sign (SurfaceGui "☁️ CLOUD SHOP")
-- └── TayronSpot (invisible)           where NpcService puts Tayron

local ShopBuilder = {}

local WOOD = Color3.fromRGB(165, 112, 72)
local DARK_WOOD = Color3.fromRGB(110, 72, 45)
local PASTELS = {
	Color3.fromRGB(255, 182, 214),
	Color3.fromRGB(255, 245, 250),
	Color3.fromRGB(170, 215, 255),
	Color3.fromRGB(255, 245, 250),
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function ellipsoid(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3)
	local p = part(parent, name, size, cf, color, {
		CanCollide = false,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- origin: floor center (top of the deck). The shop faces -Z (toward the spawn).
function ShopBuilder.Build(parent: Instance, origin: Vector3): Model
	local shop = Instance.new("Model")
	shop.Name = "CloudShop"
	local o = CFrame.new(origin)
	local function at(x: number, y: number, z: number)
		return o * CFrame.new(x, y, z)
	end

	-- Deck of planks
	for i = 0, 7 do
		part(shop, "Plank" .. i, Vector3.new(4, 1, 26), at(-14 + i * 4, -0.5, 0), i % 2 == 0 and WOOD or Color3.fromRGB(150, 100, 64), {
			Material = Enum.Material.WoodPlanks,
		})
	end

	-- Counter (front) and back shelves
	part(shop, "Counter", Vector3.new(18, 3.2, 2.5), at(0, 1.6, -4), DARK_WOOD, { Material = Enum.Material.Wood })
	part(shop, "CounterTop", Vector3.new(19, 0.4, 3.2), at(0, 3.4, -4), Color3.fromRGB(240, 230, 215), { Material = Enum.Material.Marble })
	for row = 0, 2 do
		part(shop, "Shelf" .. row, Vector3.new(16, 0.4, 2), at(0, 2 + row * 2.2, 6), WOOD, { Material = Enum.Material.Wood })
	end
	part(shop, "ShelfBack", Vector3.new(16.5, 7.5, 0.5), at(0, 3.9, 7.2), DARK_WOOD, { Material = Enum.Material.Wood })

	-- Potion bottles on shelves (glowing)
	local potionColors = {
		Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 130, 200), Color3.fromRGB(180, 255, 150),
		Color3.fromRGB(255, 220, 110), Color3.fromRGB(200, 160, 255),
	}
	local n = 0
	for row = 0, 2 do
		for i = 0, 6 do
			n += 1
			local c = potionColors[(n % #potionColors) + 1]
			part(shop, "Bottle" .. n, Vector3.new(1.4, 0.8, 0.8), at(-6.5 + i * 2.1, 2.9 + row * 2.2, 6) * CFrame.Angles(0, 0, math.pi / 2), c, {
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Neon,
				Transparency = 0.15,
				CanCollide = false,
			})
		end
	end

	-- Posts + beams
	for i, xz in { { -14, -12 }, { 14, -12 }, { -14, 11 }, { 14, 11 } } do
		part(shop, "Post" .. i, Vector3.new(1.2, 13, 1.2), at(xz[1], 6.5, xz[2]), DARK_WOOD, { Material = Enum.Material.Wood })
	end
	part(shop, "BeamFront", Vector3.new(30, 1, 1), at(0, 12.5, -12), DARK_WOOD, { Material = Enum.Material.Wood })
	part(shop, "BeamBack", Vector3.new(30, 1, 1), at(0, 12.5, 11), DARK_WOOD, { Material = Enum.Material.Wood })

	-- Striped pastel awning (sloping toward the front)
	for i = 0, 9 do
		part(shop, "Awning" .. i, Vector3.new(3, 0.3, 25), at(-13.5 + i * 3, 13.2, -0.5) * CFrame.Angles(math.rad(-8), 0, 0),
			PASTELS[(i % #PASTELS) + 1], { Material = Enum.Material.Fabric })
	end
	-- Scalloped front edge
	for i = 0, 9 do
		ellipsoid(shop, "Scallop" .. i, Vector3.new(3, 1.6, 0.8), at(-13.5 + i * 3, 11.7, -13.2), PASTELS[(i % #PASTELS) + 1])
	end

	-- Fluffy cloud sitting on the roof
	local puffs = {
		{ Vector3.new(0, 15.5, 0), Vector3.new(16, 6, 12) },
		{ Vector3.new(-8, 15, 2), Vector3.new(10, 5, 9) },
		{ Vector3.new(8, 15.2, -1), Vector3.new(11, 5.5, 9) },
		{ Vector3.new(-3, 18, 1), Vector3.new(8, 5, 7) },
		{ Vector3.new(4, 17.5, -2), Vector3.new(7, 4.5, 6) },
		{ Vector3.new(12, 14.5, 3), Vector3.new(6, 3.5, 6) },
	}
	for i, puff in puffs do
		ellipsoid(shop, "RoofCloud" .. i, puff[2], at(puff[1].X, puff[1].Y, puff[1].Z), Color3.fromRGB(255, 252, 255))
	end

	-- Sign on the front beam
	local signBoard = part(shop, "Sign", Vector3.new(14, 3, 0.4), at(0, 10.2, -12.6), Color3.fromRGB(255, 250, 240), {
		Material = Enum.Material.Wood,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.PixelsPerStud = 40
	surface.Parent = signBoard
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "☁️ CLOUD SHOP ☁️"
	label.TextColor3 = Color3.fromRGB(120, 140, 220)
	label.Parent = surface

	-- Lanterns
	for i, x in { -12, -4, 4, 12 } do
		local lantern = part(shop, "Lantern" .. i, Vector3.new(1, 1.4, 1), at(x, 10.8, -11.5), Color3.fromRGB(255, 210, 140), {
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Range = 14
		light.Brightness = 1.6
		light.Parent = lantern
	end

	-- Props: crates, flower pots
	for i, xz in { { -11, -8 }, { 11, -8 }, { -12, 4 } } do
		part(shop, "Crate" .. i, Vector3.new(2.6, 2.6, 2.6), at(xz[1], 1.3, xz[2]) * CFrame.Angles(0, math.rad(i * 17), 0), WOOD, {
			Material = Enum.Material.WoodPlanks,
		})
	end
	for i, x in { -9, 9 } do
		part(shop, "Pot" .. i, Vector3.new(2, 1.6, 1.6), at(x, 0.8, -11.5) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(205, 120, 90), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Brick,
		})
		ellipsoid(shop, "Flower" .. i, Vector3.new(2.2, 1.6, 2.2), at(x, 2.2, -11.5), PASTELS[i])
	end

	-- Where Tayron stands (behind the counter, facing the customers)
	part(shop, "TayronSpot", Vector3.one, at(0, 0, 0), Color3.new(1, 1, 1), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})

	shop.PrimaryPart = shop:FindFirstChild("Plank0") :: BasePart
	shop.Parent = parent
	return shop
end

return ShopBuilder
