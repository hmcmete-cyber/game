-- v2.39 3D biome totems (and the spinning "?" for totems you never had).
-- Used by the forge window (ViewportFrame). Every totem: stone base, three
-- carved blocks in the totem colour with eyes, side wings, and a biome symbol
-- on top. Pivot = model centre; total height ~8 studs.

local ForgeDefs = require(script.Parent.ForgeDefs)

local TotemModels = {}

local V, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB

local function part(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.Parent = m
	return p
end

local NEON = { Material = Enum.Material.Neon }
local BALL = { Shape = Enum.PartType.Ball }

-- biome symbol on top of the pole, centred at `top`
local SYMBOL = {
	Plateau = function(m, top, c) -- sun disc with rays
		part(m, "Sun", V(0.6, 2.2, 2.2), CF(top) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0), RGB(255, 210, 80), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon })
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			part(m, "Ray" .. k, V(0.3, 1, 0.3), CF(top) * CFrame.Angles(0, 0, a) * CF(0, 1.6, 0), c, NEON)
		end
	end,
	Mountains = function(m, top, c) -- ice crystal snowflake
		for k = 0, 2 do
			part(m, "Arm" .. k, V(0.35, 3, 0.35), CF(top) * CFrame.Angles(0, 0, k * math.pi / 3), c, NEON)
		end
		part(m, "Core", V(0.9, 0.9, 0.9), CF(top) * CFrame.Angles(0, math.pi / 4, math.pi / 4), RGB(255, 255, 255), NEON)
	end,
	Mushroom = function(m, top, c) -- glowing mushroom
		part(m, "Stem", V(0.7, 1.2, 0.7), CF(top - V(0, 0.4, 0)), RGB(250, 240, 225))
		part(m, "Cap", V(2.6, 1.2, 2.6), CF(top + V(0, 0.5, 0)), c, BALL)
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			part(m, "Dot" .. k, V(0.4, 0.4, 0.4), CF(top + V(math.cos(a) * 0.8, 0.95, math.sin(a) * 0.8)), RGB(255, 255, 255), NEON)
		end
	end,
	Marsh = function(m, top, c) -- lightning bolt
		part(m, "Bolt1", V(0.45, 1.3, 0.35), CF(top + V(0.25, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(-25)), RGB(255, 240, 110), NEON)
		part(m, "Bolt2", V(1.1, 0.35, 0.35), CF(top), RGB(255, 240, 110), NEON)
		part(m, "Bolt3", V(0.45, 1.3, 0.35), CF(top + V(-0.25, -0.6, 0)) * CFrame.Angles(0, 0, math.rad(-25)), RGB(255, 240, 110), NEON)
		part(m, "Cloud", V(2, 0.8, 1), CF(top + V(0, 1.4, 0)), c, BALL)
	end,
	Canyon = function(m, top, c) -- crystal prism cluster
		part(m, "Prism", V(0.9, 2.6, 0.9), CF(top + V(0, 0.3, 0)) * CFrame.Angles(0, math.pi / 4, 0), c, { Material = Enum.Material.Glass, Transparency = 0.15 })
		part(m, "PrismL", V(0.6, 1.6, 0.6), CF(top + V(-0.6, -0.2, 0)) * CFrame.Angles(0, 0, math.rad(25)), RGB(150, 200, 255), NEON)
		part(m, "PrismR", V(0.6, 1.6, 0.6), CF(top + V(0.6, -0.2, 0)) * CFrame.Angles(0, 0, math.rad(-25)), RGB(255, 150, 220), NEON)
	end,
	Volcanic = function(m, top, c) -- flame
		part(m, "Flame1", V(1.6, 1.6, 1.6), CF(top - V(0, 0.3, 0)), c, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon })
		part(m, "Flame2", V(1.1, 1.4, 1.1), CF(top + V(0, 0.7, 0)) * CFrame.Angles(0, math.pi / 4, 0), RGB(255, 190, 60), NEON)
		part(m, "Flame3", V(0.6, 1, 0.6), CF(top + V(0, 1.5, 0)) * CFrame.Angles(0, math.pi / 4, 0), RGB(255, 245, 180), NEON)
	end,
	Coast = function(m, top, c) -- wave crest + pearl
		for k = 0, 4 do
			local a = math.rad(-60 + k * 40)
			part(m, "Wave" .. k, V(0.5, 0.5, 0.9), CF(top + V(math.sin(a) * 1, math.cos(a) * 1 - 0.3, 0)), c, NEON)
		end
		part(m, "Pearl", V(0.8, 0.8, 0.8), CF(top + V(0, -0.2, 0)), RGB(250, 250, 240), BALL)
	end,
}

function TotemModels.Make(biome: string): Model?
	local t = ForgeDefs.Totems[biome]
	if not t then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = biome .. "Totem"
	local c = t.Color
	local dark = c:Lerp(RGB(30, 25, 25), 0.45)
	local y = -4
	part(m, "Base", V(3, 0.8, 3), CF(0, y + 0.4, 0), RGB(110, 100, 95))
	part(m, "BaseTrim", V(3.2, 0.25, 3.2), CF(0, y + 0.9, 0), c, NEON)
	-- three carved blocks, alternating light / dark, each with a face
	for k = 0, 2 do
		local cy = y + 1.75 + k * 1.6
		local col = k % 2 == 0 and c or dark
		part(m, "Block" .. k, V(2, 1.5, 2), CF(0, cy, 0), col)
		for s = -1, 1, 2 do
			part(m, "Eye" .. k .. s, V(0.35, 0.3, 0.1), CF(s * 0.45, cy + 0.2, -1.02), RGB(255, 255, 255), NEON)
		end
		part(m, "Mouth" .. k, V(0.9, 0.18, 0.1), CF(0, cy - 0.35, -1.02), RGB(40, 30, 30))
	end
	-- wings on the top block
	for s = -1, 1, 2 do
		part(m, "Wing" .. s, V(1.3, 0.5, 0.4), CF(s * 1.5, y + 5.2, 0) * CFrame.Angles(0, 0, math.rad(s * 20)), c:Lerp(RGB(255, 255, 255), 0.35))
	end
	SYMBOL[biome](m, Vector3.new(0, y + 7.2, 0), c)
	m.PrimaryPart = m:FindFirstChild("Base") :: BasePart
	return m
end

-- a chunky 3D question mark (for totems you have never owned)
function TotemModels.Mystery(): Model
	local m = Instance.new("Model")
	m.Name = "Mystery"
	local col = RGB(235, 240, 255)
	-- hook: blocks along a 270 deg arc
	for k = 0, 8 do
		local a = math.rad(180 - k * 30)
		part(m, "Arc" .. k, V(0.9, 0.9, 0.9), CF(math.cos(a) * 1.6, 2 + math.sin(a) * 1.6, 0), col)
	end
	part(m, "Stem", V(0.9, 1.4, 0.9), CF(0, -0.3, 0), col)
	part(m, "Dot", V(1, 1, 1), CF(0, -2.3, 0), RGB(255, 210, 90), NEON)
	m.PrimaryPart = m:FindFirstChild("Stem") :: BasePart
	return m
end

return TotemModels
