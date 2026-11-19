-- Builds the look of every cloud: soft welded puffs + a smoke emitter that
-- breathes out of the center, plus a signature effect per type.
--
--   Cumulus   white cotton smoke drifting slowly
--   Storm     dark slate smoke, sparks; tag LightningCloud -> client arcs + flashes
--   Cosmic    deep purple puffs, rainbow star particles; tag RainbowCloud -> client hue cycle
--   Aurora    pale teal puffs, green->purple light ribbons below; tag AuroraCloud -> client waves
--   Chrono    golden puffs with cyan/gold time sparks spiralling
--   Mythic    huge black-purple storm with all of the above
--   Rain / Snow / Tornado: tinted puffs + drops / flakes / dust
--
-- Every cloud is a stack of soft rounded lobes (ellipsoids). Each visual
-- family arranges them differently (SHAPES): heap, bank, tiers, funnel,
-- anvil, ring, ribbon, hourglass, wings, crown, sun, spiral, pile, lumpy.
-- Clients animate each puff (breathing scale, per-type motion) in Effects.luau.
--
-- Returns the center Part ("Core"); every other piece is welded to it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weather = require(ReplicatedStorage.Shared.WeatherTypes)

local CloudVisuals = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- Asymmetric puffy cloud made of ellipsoids (Part + SpecialMesh "Sphere",
-- which stretches to the Part's size). Three layers:
--   base  wide, flat, slightly darker underside
--   body  medium lumps, offset to one side
--   crown small bright tops
-- Each entry: offset (in cloud widths), size (w, h, d in cloud widths), shade
-- v1.8: EVERY family is built only from rounded, soft lobes (no lobe is
-- flatter than ~1.6:1), so each type reads as a cloud first; the families
-- differ in how the lobes are arranged. Entry 1 is the core.
-- Format: offset, size (in cloud widths), shade.
local function V(x, y, z)
	return Vector3.new(x, y, z)
end
local LAYOUT = { -- Cumulus: tall cotton heap
	{ V(0, 0, 0), V(0.55, 0.42, 0.5), 0.92 },
	{ V(0.34, -0.03, 0.1), V(0.46, 0.36, 0.42), 0.9 },
	{ V(-0.36, -0.04, -0.06), V(0.44, 0.34, 0.4), 0.9 },
	{ V(-0.12, 0.2, 0.02), V(0.48, 0.44, 0.44), 1.0 },
	{ V(0.2, 0.22, -0.05), V(0.42, 0.4, 0.4), 1.02 },
	{ V(0.42, 0.12, 0.08), V(0.3, 0.28, 0.3), 0.98 },
	{ V(-0.42, 0.1, 0.1), V(0.28, 0.26, 0.28), 0.97 },
	{ V(-0.02, 0.42, 0.0), V(0.34, 0.32, 0.32), 1.06 },
	{ V(0.2, 0.38, 0.08), V(0.26, 0.24, 0.26), 1.08 },
}
local function ringOf(n: number, r: number, y: number, size: Vector3, shade: number, phase: number?)
	local t = {}
	for k = 0, n - 1 do
		local a = (k / n + (phase or 0)) * math.pi * 2
		table.insert(t, { V(math.cos(a) * r, y, math.sin(a) * r), size, shade })
	end
	return t
end
local function join(...)
	local out = {}
	for _, list in { ... } do
		for _, e in list do
			table.insert(out, e)
		end
	end
	return out
end
local SHAPES = {
	Cumulus = LAYOUT,
	-- Rain bank: a long, low chain of round lobes with a grey belly
	Rain = join({ { V(0, 0, 0), V(0.42, 0.32, 0.4), 0.85 } },
		{ { V(0.36, -0.02, 0.06), V(0.4, 0.3, 0.38), 0.84 }, { V(-0.36, -0.01, -0.05), V(0.4, 0.3, 0.38), 0.84 },
			{ V(0.7, -0.04, 0.02), V(0.32, 0.26, 0.32), 0.82 }, { V(-0.7, -0.03, 0.03), V(0.32, 0.26, 0.32), 0.82 },
			{ V(0.18, 0.18, 0), V(0.34, 0.28, 0.32), 0.96 }, { V(-0.2, 0.17, 0.02), V(0.32, 0.27, 0.3), 0.96 } }),
	-- Snow tiers: wide ring of puffs, a smaller ring above, one top puff
	Snow = join({ { V(0, 0, 0), V(0.44, 0.34, 0.44), 0.94 } }, ringOf(5, 0.34, -0.02, V(0.32, 0.26, 0.32), 0.92),
		ringOf(3, 0.18, 0.22, V(0.28, 0.24, 0.28), 1.02, 0.15), { { V(0, 0.42, 0), V(0.24, 0.22, 0.24), 1.08 } }),
	-- Funnel: round puffy head, then smaller and smaller puffs spiralling down
	Tornado = join({ { V(0, 0, 0), V(0.5, 0.38, 0.5), 0.96 } }, ringOf(3, 0.24, 0.04, V(0.34, 0.28, 0.34), 1.0),
		{ { V(0.05, -0.28, 0.02), V(0.32, 0.28, 0.32), 0.92 }, { V(0.1, -0.48, 0.06), V(0.24, 0.22, 0.24), 0.9 },
			{ V(0.08, -0.64, 0.1), V(0.17, 0.16, 0.17), 0.88 }, { V(0.02, -0.76, 0.12), V(0.11, 0.11, 0.11), 0.86 } }),
	-- Anvil: a tall stack of puffs that spreads into a crown of wide puffs on top
	Storm = join({ { V(0, 0, 0), V(0.5, 0.46, 0.48), 0.82 } }, { { V(0.05, 0.3, 0.02), V(0.44, 0.4, 0.42), 0.88 } },
		ringOf(5, 0.42, 0.52, V(0.42, 0.28, 0.4), 1.0, 0.1), { { V(0.1, -0.3, 0.04), V(0.48, 0.32, 0.44), 0.74 } }),
	-- Ring: soft core with a halo of eight small puffs around it
	Cosmic = join({ { V(0, 0, 0), V(0.42, 0.4, 0.42), 1.05 } }, ringOf(8, 0.46, 0, V(0.24, 0.22, 0.24), 0.98)),
	-- Ribbon: a wavy line of puffs (aurora)
	Aurora = (function()
		local t = { { V(0, 0, 0), V(0.34, 0.3, 0.3), 1.0 } }
		for k = -3, 3 do
			if k ~= 0 then
				table.insert(t, { V(k * 0.22, math.sin(k * 1.1) * 0.12, math.cos(k * 0.9) * 0.1), V(0.3 - math.abs(k) * 0.02, 0.26, 0.28), 1 + k * 0.02 })
			end
		end
		return t
	end)(),
	-- Hourglass: a puff cluster above and below a small waist puff
	Chrono = join({ { V(0, 0, 0), V(0.22, 0.2, 0.22), 1.1 } }, ringOf(3, 0.16, 0.28, V(0.32, 0.26, 0.32), 1.04),
		ringOf(3, 0.16, -0.28, V(0.32, 0.26, 0.32), 0.94, 0.17), { { V(0, 0.46, 0), V(0.22, 0.2, 0.22), 1.08 } }),
	-- Wings: round body with two rising wings made of puffs (phoenix)
	Phoenix = {
		{ V(0, 0, 0), V(0.42, 0.4, 0.44), 1.05 },
		{ V(0.36, 0.12, 0.08), V(0.36, 0.26, 0.3), 1.0 }, { V(0.66, 0.3, 0.16), V(0.26, 0.2, 0.22), 1.06 },
		{ V(-0.36, 0.12, 0.08), V(0.36, 0.26, 0.3), 1.0 }, { V(-0.66, 0.3, 0.16), V(0.26, 0.2, 0.22), 1.06 },
		{ V(0, 0.28, -0.12), V(0.26, 0.24, 0.24), 1.1 }, { V(0, -0.12, 0.34), V(0.24, 0.2, 0.3), 0.9 },
	},
	-- Crown: a heavy dark puff wearing a ring of small round puffs (void)
	Void = join({ { V(0, 0, 0), V(0.56, 0.46, 0.56), 0.9 } }, ringOf(6, 0.26, 0.28, V(0.2, 0.22, 0.2), 1.08),
		{ { V(0, -0.24, 0), V(0.4, 0.28, 0.4), 0.8 } }),
	-- Sun: a round bright puff with a ring of small puffs around its rim
	Solar = (function()
		local t = { { V(0, 0, 0), V(0.5, 0.48, 0.42), 1.08 } }
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			table.insert(t, { V(math.cos(a) * 0.42, math.sin(a) * 0.42, 0), V(0.2, 0.2, 0.2), 1.02 })
		end
		return t
	end)(),
	-- Spiral: a big puffy tower coiling upward (mythic)
	Mythic = (function()
		local t = { { V(0, 0, 0), V(0.62, 0.44, 0.62), 0.9 } }
		for k = 1, 8 do
			local a = k * 0.9
			local r = 0.4 - k * 0.03
			local w = 0.4 - k * 0.025
			table.insert(t, { V(math.cos(a) * r, k * 0.1, math.sin(a) * r), V(w, w * 0.8, w), 0.95 + k * 0.02 })
		end
		return t
	end)(),
	-- Economic: a neat pile of three round puffs with two side puffs ("coin pile")
	Economic = {
		{ V(0, 0, 0), V(0.5, 0.34, 0.5), 1.0 }, { V(0.04, 0.24, 0.02), V(0.42, 0.3, 0.42), 1.05 },
		{ V(-0.02, 0.44, -0.01), V(0.32, 0.26, 0.32), 1.1 }, { V(0.36, -0.06, 0.2), V(0.3, 0.26, 0.3), 0.95 },
		{ V(-0.36, -0.05, -0.2), V(0.3, 0.26, 0.3), 0.95 },
	},
	-- Chaos: lopsided, bumpy heap
	Chaos = {
		{ V(0, 0, 0), V(0.52, 0.46, 0.5), 1.0 }, { V(0.38, 0.22, 0.05), V(0.4, 0.42, 0.38), 1.05 },
		{ V(-0.34, -0.12, 0.2), V(0.42, 0.32, 0.4), 0.9 }, { V(0.05, 0.4, -0.18), V(0.28, 0.28, 0.28), 1.1 },
		{ V(-0.28, 0.26, -0.14), V(0.24, 0.3, 0.24), 1.0 }, { V(0.3, -0.22, -0.2), V(0.3, 0.24, 0.3), 0.92 },
	},
}

local function shapeFor(def): { any }
	if def.Shape and SHAPES[def.Shape] then
		return SHAPES[def.Shape]
	end
	if def.Category == "Economic" or def.Category == "Chaos" then
		return SHAPES[def.Category]
	end
	return SHAPES[def.Visual or "Cumulus"] or LAYOUT
end

local STYLE = {
	Cumulus = { Tint = Color3.fromRGB(250, 252, 255), Smoke = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic, Alpha = 0.4 },
	Rain = { Tint = Color3.fromRGB(185, 200, 225), Smoke = Color3.fromRGB(200, 215, 235), Material = Enum.Material.SmoothPlastic, Alpha = 0.4 },
	Snow = { Tint = Color3.fromRGB(250, 252, 255), Smoke = Color3.fromRGB(240, 248, 255), Material = Enum.Material.SmoothPlastic, Alpha = 0.35 },
	Tornado = { Tint = Color3.fromRGB(200, 195, 180), Smoke = Color3.fromRGB(190, 185, 165), Material = Enum.Material.SmoothPlastic, Alpha = 0.4 },
	Storm = { Tint = Color3.fromRGB(70, 72, 90), Smoke = Color3.fromRGB(45, 45, 60), Material = Enum.Material.Slate, Alpha = 0.1 },
	Cosmic = { Tint = Color3.fromRGB(70, 35, 130), Smoke = Color3.fromRGB(120, 60, 200), Material = Enum.Material.SmoothPlastic, Alpha = 0.3 },
	Aurora = { Tint = Color3.fromRGB(190, 255, 235), Smoke = Color3.fromRGB(160, 255, 210), Material = Enum.Material.SmoothPlastic, Alpha = 0.4 },
	Chrono = { Tint = Color3.fromRGB(255, 235, 175), Smoke = Color3.fromRGB(255, 225, 150), Material = Enum.Material.SmoothPlastic, Alpha = 0.35 },
	Phoenix = { Tint = Color3.fromRGB(255, 140, 70), Smoke = Color3.fromRGB(255, 110, 50), Material = Enum.Material.SmoothPlastic, Alpha = 0.25 },
	Void = { Tint = Color3.fromRGB(30, 18, 55), Smoke = Color3.fromRGB(70, 40, 120), Material = Enum.Material.SmoothPlastic, Alpha = 0.15 },
	Solar = { Tint = Color3.fromRGB(255, 232, 150), Smoke = Color3.fromRGB(255, 240, 170), Material = Enum.Material.SmoothPlastic, Alpha = 0.3 },
	Mythic = { Tint = Color3.fromRGB(45, 20, 70), Smoke = Color3.fromRGB(80, 30, 120), Material = Enum.Material.Slate, Alpha = 0.1 },
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 220, 80)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 255, 120)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(120, 100, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 230)),
})

local function shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function ns(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

local function emitter(parent: Instance, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- Move a part and every BasePart under it, keeping relative offsets.
-- (Welds only act once parts are in workspace, so new models must be moved this way.)
function CloudVisuals.Move(root: BasePart, cf: CFrame)
	local old = root.CFrame
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = cf * old:ToObjectSpace(d.CFrame)
		end
	end
	root.CFrame = cf
end

function CloudVisuals.Make(typeName: string, shiny: boolean, scale: number): BasePart
	local def = Weather.Types[typeName]
	local visual = def.Visual or "Cumulus"
	local style = STYLE[visual] or STYLE.Cumulus
	local d = def.Size * 0.9 * scale -- cloud width
	-- CloudDB can recolour any style (Tint); smoke follows the tint
	local tint = shiny and Weather.ShinyColor or (def.Tint or style.Tint)
	local smoke = def.Tint and def.Tint:Lerp(Color3.new(1, 1, 1), 0.15) or style.Smoke

	-- Asymmetric puffy body. A random mirror + jitter makes every cloud unique.
	local rng = Random.new()
	local mirror = rng:NextNumber() < 0.5 and -1 or 1
	local center
	-- v2.0 coherence pass: every family is pulled together (offsets x0.72)
	-- and sits on one wide soft base lobe, so lobes always overlap into ONE
	-- cloud mass instead of separate floating balls
	local layout = { shapeFor(def)[1], { Vector3.new(0, -0.08, 0), Vector3.new(0.86, 0.4, 0.64), 0.9 } }
	for i, e in shapeFor(def) do
		if i > 1 then
			table.insert(layout, { e[1] * 0.72, e[2] * 1.08, e[3] })
		end
	end
	for i, puff in layout do
		local jitter = Vector3.new(rng:NextNumber(-0.04, 0.04), rng:NextNumber(-0.03, 0.03), rng:NextNumber(-0.04, 0.04))
		local offset = (Vector3.new(puff[1].X * mirror, puff[1].Y, puff[1].Z) + jitter) * d
		local size = puff[2] * d * rng:NextNumber(0.92, 1.08)

		local p = Instance.new("Part")
		p.Name = i == 1 and "Core" or ("Puff" .. i)
		p.Size = size
		p.Color = shade(tint, puff[3])
		p.Material = style.Material -- shiny = gold tint only (neon washed the shape out)
		p.Transparency = style.Alpha
		p.Anchored = i == 1
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere -- ellipsoid stretched to the part size
		mesh.Parent = p
		if center then
			p.CFrame = center.CFrame * CFrame.new(offset - layout[1][1] * d)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = center
			weld.Part1 = p
			weld.Parent = p
			p.Parent = center
		else
			center = p
		end
	end

	-- v2.7 detail pass (director: more parts, more detail): every lobe gets
	-- small bumps bulging out of its upper/outer surface (brighter, like
	-- sunlit cauliflower tops) and the big lobes a darker lobe under the belly,
	-- so the outline breaks into many soft curls instead of a few balls
	local lobes = {}
	for _, ch in center:GetChildren() do
		if ch:IsA("BasePart") then
			table.insert(lobes, ch)
		end
	end
	table.insert(lobes, center)
	local bumpN = 0
	for _, lobe in lobes do
		local half = lobe.Size / 2
		local out = lobe.Position - center.Position
		out = Vector3.new(out.X, 0, out.Z)
		local big = lobe.Size.X > d * 0.38
		for k = 1, big and 3 or 2 do
			local a = rng:NextNumber(0, math.pi * 2)
			local dir = Vector3.new(math.cos(a), rng:NextNumber(0.35, 1.1), math.sin(a))
			if out.Magnitude > 0.01 then
				dir += out.Unit * 0.8 -- lean toward the outside of the cloud
			end
			dir = dir.Unit
			local pos = lobe.Position + Vector3.new(dir.X * half.X, dir.Y * half.Y, dir.Z * half.Z) * 0.78
			local sz = lobe.Size * rng:NextNumber(0.34, 0.48)
			bumpN += 1
			local b = Instance.new("Part")
			b.Name = "Curl" .. bumpN
			b.Size = Vector3.new(sz.X, sz.Y * 0.9, sz.Z)
			b.CFrame = CFrame.new(pos)
			b.Color = shade(lobe.Color, 1.05)
			b.Material = style.Material
			b.Transparency = style.Alpha
			b.Anchored = false
			b.CanCollide = false
			b.CanQuery = false
			b.CanTouch = false
			b.CastShadow = false
			b.Massless = true
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = b
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = center
			weld.Part1 = b
			weld.Parent = b
			b.Parent = center
		end
		if big then
			bumpN += 1
			local b = Instance.new("Part")
			b.Name = "Belly" .. bumpN
			b.Size = Vector3.new(lobe.Size.X * 0.7, lobe.Size.Y * 0.35, lobe.Size.Z * 0.7)
			b.CFrame = CFrame.new(lobe.Position - Vector3.new(0, half.Y * 0.62, 0))
			b.Color = shade(lobe.Color, 0.86)
			b.Material = style.Material
			b.Transparency = style.Alpha
			b.CanCollide = false
			b.CanQuery = false
			b.CanTouch = false
			b.CastShadow = false
			b.Massless = true
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = b
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = center
			weld.Part1 = b
			weld.Parent = b
			b.Parent = center
		end
	end

	center:SetAttribute("Motion", visual)

	-- Puffy smoke breathing out of the center
	emitter(center, {
		Name = "Smoke",
		Texture = SMOKE,
		Color = ColorSequence.new(shiny and Weather.ShinyColor or smoke),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, d * 0.35),
			NumberSequenceKeypoint.new(1, d * 0.75),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1.6, 2.6),
		Rate = 7,
		Speed = NumberRange.new(0.2, 0.7),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-25, 25),
		Drag = 1,
		LightInfluence = 0.8,
		LightEmission = (visual == "Cosmic" or visual == "Mythic") and 0.4 or 0.05,
		Acceleration = def.ParticleAcceleration * 0.05,
	})

	-- Volumetric layers:
	--   Fill   dense, slow smoke packed in the middle (makes the cloud look solid)
	--   Wisps  big, faint smoke drifting outwards (soft edges that move)
	--   Glow   bright haze in the very center (inner light)
	local smokeColor = shiny and Weather.ShinyColor or smoke
	emitter(center, {
		Name = "Fill",
		Texture = SMOKE,
		Color = ColorSequence.new(smokeColor),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, d * 0.45),
			NumberSequenceKeypoint.new(1, d * 0.6),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.25),
			NumberSequenceKeypoint.new(0.7, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(2.5, 3.5),
		Rate = 10,
		Speed = NumberRange.new(0, 0.15),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-12, 12),
		LightInfluence = 0.7,
		ZOffset = -0.5,
	})
	emitter(center, {
		Name = "Wisps",
		Texture = SMOKE,
		Color = ColorSequence.new(smokeColor),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, d * 0.3),
			NumberSequenceKeypoint.new(1, d * 1.1),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(3, 4.5),
		Rate = 3,
		Speed = NumberRange.new(0.4, 1),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-8, 8),
		LightInfluence = 1,
	})
	emitter(center, {
		Name = "Glow",
		Texture = SMOKE,
		Color = ColorSequence.new(shiny and Weather.ShinyColor or def.ParticleColor),
		Size = NumberSequence.new(d * 0.35, d * 0.5),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1, 1.6),
		Rate = 6,
		Speed = NumberRange.new(0, 0.1),
		LightEmission = 0.8,
		LightInfluence = 0,
		ZOffset = 0.5,
	})

	local light = Instance.new("PointLight")
	light.Name = "CloudLight"
	light.Color = shiny and Weather.ShinyColor or def.ParticleColor
	light.Brightness = 1
	light.Range = 8 * scale
	light.Parent = center

	-- Signature effects
	if visual == "Rain" or visual == "Snow" or visual == "Tornado" then
		emitter(center, {
			Name = "Detail",
			Color = ColorSequence.new(def.ParticleColor),
			Acceleration = def.ParticleAcceleration,
			Lifetime = NumberRange.new(0.5, 1),
			Rate = 14,
			Speed = NumberRange.new(0.5, 2),
			SpreadAngle = Vector2.new(180, 180),
			Size = ns(0.25 * scale, 0.1 * scale),
			LightEmission = 0.3,
		})
	end

	if visual == "Storm" or visual == "Mythic" then
		emitter(center, {
			Name = "Sparks",
			Color = ColorSequence.new(Color3.fromRGB(255, 245, 160)),
			Lifetime = NumberRange.new(0.08, 0.2),
			Rate = 25,
			Speed = NumberRange.new(5, 10),
			SpreadAngle = Vector2.new(180, 180),
			Size = ns(0.18 * scale, 0),
			LightEmission = 1,
		})
		light.Brightness = 2.5
		CollectionService:AddTag(center, "LightningCloud")
	end

	if visual == "Cosmic" or visual == "Mythic" then
		emitter(center, {
			Name = "Stars",
			Color = RAINBOW,
			Lifetime = NumberRange.new(1, 2),
			Rate = 18,
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.2, 0.35 * scale),
				NumberSequenceKeypoint.new(1, 0),
			}),
			LightEmission = 1,
			RotSpeed = NumberRange.new(-90, 90),
		})
		light.Brightness = 2
		CollectionService:AddTag(center, "RainbowCloud")
	end

	if visual == "Aurora" or visual == "Mythic" then
		-- Light ribbons hanging under the cloud; the client waves them
		local auroraColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 255, 160)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
		})
		for i = 1, 4 do
			local a = (i / 4) * math.pi * 2
			local top = Instance.new("Attachment")
			top.Name = "AuroraTop" .. i
			top.Position = Vector3.new(math.cos(a) * d * 0.3, -d * 0.2, math.sin(a) * d * 0.3)
			top.Parent = center
			local bottom = Instance.new("Attachment")
			bottom.Name = "AuroraBottom" .. i
			bottom.Position = top.Position + Vector3.new(0, -d * 1.1, 0)
			bottom.Parent = center
			local beam = Instance.new("Beam")
			beam.Name = "Aurora" .. i
			beam.Attachment0 = top
			beam.Attachment1 = bottom
			beam.Color = auroraColor
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			})
			beam.Width0 = d * 0.3
			beam.Width1 = d * 0.12
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.FaceCamera = true
			beam.Segments = 16
			beam.Parent = center
		end
		light.Color = Color3.fromRGB(120, 255, 190)
		light.Brightness = 2
		CollectionService:AddTag(center, "AuroraCloud")
	end

	if visual == "Phoenix" then
		-- flames licking up + embers
		emitter(center, {
			Name = "Flames",
			Texture = SMOKE,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 140, 50)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 40, 20)),
			}),
			Size = NumberSequence.new(d * 0.35, d * 0.05),
			Transparency = NumberSequence.new(0.2, 1),
			Lifetime = NumberRange.new(0.5, 0.9),
			Rate = 22,
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Top,
			LightEmission = 1,
			LightInfluence = 0,
		})
		emitter(center, {
			Name = "Embers",
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 90)),
			Lifetime = NumberRange.new(1, 1.6),
			Rate = 12,
			Speed = NumberRange.new(1, 3),
			Acceleration = Vector3.new(0, 4, 0),
			SpreadAngle = Vector2.new(180, 180),
			Size = ns(0.2 * scale, 0),
			LightEmission = 1,
		})
		light.Color = Color3.fromRGB(255, 150, 70)
		light.Brightness = 2.5
	end

	if visual == "Void" then
		-- a dark hole full of white stars, purple rim glow
		emitter(center, {
			Name = "VoidStars",
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 160, 255)),
			Lifetime = NumberRange.new(1.2, 2),
			Rate = 20,
			Speed = NumberRange.new(0.2, 0.8),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.22 * scale),
				NumberSequenceKeypoint.new(1, 0),
			}),
			LightEmission = 1,
		})
		emitter(center, {
			Name = "Pull",
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(150, 90, 255)),
			Size = NumberSequence.new(d * 0.9, d * 0.2), -- shrinks inward
			Transparency = NumberSequence.new(0.8, 0.4),
			Lifetime = NumberRange.new(1.2, 1.6),
			Rate = 4,
			Speed = NumberRange.new(0, 0),
			LightEmission = 0.8,
		})
		light.Color = Color3.fromRGB(160, 100, 255)
		light.Brightness = 2
	end

	if visual == "Solar" then
		-- blinding golden core + flare rays
		emitter(center, {
			Name = "Rays",
			Color = ColorSequence.new(Color3.fromRGB(255, 245, 190), Color3.fromRGB(255, 190, 70)),
			Lifetime = NumberRange.new(0.4, 0.7),
			Rate = 18,
			Speed = NumberRange.new(5, 8),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.5 * scale, 0),
			LightEmission = 1,
		})
		light.Color = Color3.fromRGB(255, 230, 150)
		light.Brightness = 2 -- accent only: too much glow washed the puffs out
		light.Range = 12 * scale
	end

	if visual == "Chrono" then
		emitter(center, {
			Name = "TimeSparks",
			Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(120, 230, 255)),
			Lifetime = NumberRange.new(1, 1.6),
			Rate = 16,
			Speed = NumberRange.new(2, 3),
			SpreadAngle = Vector2.new(10, 180), -- a flat ring
			Size = ns(0.3 * scale, 0),
			Drag = 2,
			LightEmission = 1,
			RotSpeed = NumberRange.new(180, 360),
		})
		light.Brightness = 2
	end

	if shiny then
		light.Brightness = 3
	end

	-- Clients make every cloud "breathe" (light + glow pulse), see Effects.luau
	center:SetAttribute("BaseBrightness", light.Brightness)
	CollectionService:AddTag(center, "CloudCore")
	return center
end

return CloudVisuals
