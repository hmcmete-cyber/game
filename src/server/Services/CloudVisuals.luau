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
	local d = def.Size * 0.9 * scale * 2.2 -- cloud width (v2.16: 2.2x, readable from far away)
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
	-- v2.12 (director: clouds were indistinguishable at a distance): every
	-- type gets its OWN proportions from a stable hash of its id (wide/flat,
	-- tall/narrow, deep...) and drops or doubles a few lobes, so even two
	-- clouds of the same family read differently. Signature features follow.
	local h = 0
	for k = 1, #typeName do
		h = (h * 31 + string.byte(typeName, k)) % 100003
	end
	local hr = Random.new(h)
	local stretch = Vector3.new(hr:NextNumber(0.78, 1.38), hr:NextNumber(0.72, 1.35), hr:NextNumber(0.82, 1.18))
	local shaped = {}
	for i, e in layout do
		if i <= 2 or hr:NextNumber() > 0.18 then
			table.insert(shaped, { e[1] * stretch, e[2] * stretch, e[3] })
		end
		if i > 2 and hr:NextNumber() < 0.15 then
			local o = e[1] * stretch
			table.insert(shaped, { Vector3.new(-o.X, o.Y + 0.08, o.Z * 0.6), e[2] * stretch * 0.75, e[3] * 1.03 })
		end
	end
	layout = shaped
	for i, puff in layout do
		local jitter = Vector3.new(rng:NextNumber(-0.04, 0.04), rng:NextNumber(-0.03, 0.03), rng:NextNumber(-0.04, 0.04))
		local offset = (Vector3.new(puff[1].X * mirror, puff[1].Y, puff[1].Z) + jitter) * d
		local size = puff[2] * d * rng:NextNumber(0.92, 1.08)

		local p = Instance.new("Part")
		p.Name = i == 1 and "Core" or ("Puff" .. i)
		p.Size = size
		p.Color = shade(tint, puff[3])
		p.Material = style.Material -- shiny = gold tint only (neon washed the shape out)
		p.Transparency = 0 -- v2.15: collected clouds are fully opaque
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
			b.Transparency = 0
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
			b.Transparency = 0
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

	CloudVisuals.Signature(center, typeName, def, d, tint, style)
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


------------------------------------------------------------------------
-- v2.12 SIGNATURE FEATURES: one or two readable details per cloud type that
-- say what it is (director: face/expression, horns, frost fringe, lightning
-- core, raindrop belly, tornado tail, halo/arc...). Restrained, blocky,
-- welded to the core. SIG maps every type id to its features.
------------------------------------------------------------------------
local SIG = {
	Cumulus = { "FaceHappy" }, Rain = { "Raindrops", "FaceSleepy" }, CottonPuff = { "FaceHappy", "Tuft" }, Drizzle = { "RaindropsSmall" },
	MorningMist = { "SunPeek" }, Breeze = { "Ribbons", "FacePuff" }, Haze = { "Veil" }, NimbusJr = { "FaceGrumpy", "RaindropsSmall" },
	Marshmallow = { "Toasted", "FaceHappy" }, Dew = { "Dew" }, SandSquall = { "SandRing" }, SeaFoam = { "Bubbles" },
	Pebble = { "Rocks" }, PineFog = { "PineTips" }, DuskWisp = { "Moon" }, Moonlet = { "Moon", "FaceSleepy" },
	Snow = { "Snowflake", "Fringe" }, Tornado = { "Rocks" }, Gale = { "Ribbons", "FacePuff" }, Hail = { "IceBalls" },
	Blossom = { "Petals" }, Tidal = { "Wave" }, Ember = { "FlamesSmall" }, Coral = { "Coral" },
	Avalanche = { "SnowBoulders", "Fringe" }, Firefly = { "Fireflies" }, Echo = { "SoundRings" }, CopperStorm = { "Coins", "LightningCore" },
	Lavender = { "Flowers" }, Hourglass = { "SandStream" }, Thunder = { "Anvil", "LightningCore", "FaceAngry" }, Phoenix = { "Crest" },
	Aurora = { "Stars" }, Cosmic = { "PlanetRing", "Stars" }, Chrono = { "ClockHands" }, Prism = { "Gems", "Arc" },
	Glacier = { "Fringe", "IceShelf" }, Magma = { "Flames", "Rocks" }, Monsoon = { "Raindrops", "FaceSleepy" }, Cyclone = { "Eye" },
	Nebula = { "Stars", "PlanetRing" }, ThunderheadEpic = { "Horns", "LightningCore" }, Void = { "Eye" }, Solar = { "Crown" },
	Celestial = { "Halo", "Wings" }, Tempest = { "Horns", "LightningCore", "FaceAngry" }, Leviathan = { "Teeth", "Fins" }, Starfall = { "StarTrail" },
	Obsidian = { "RocksDark", "LightningCore" }, Zenith = { "Halo", "Arc" }, Mythic = { "Crown", "Horns" }, Genesis = { "Sprout", "Halo" },
	Eclipse = { "Corona" }, Seraph = { "Wings", "Halo" }, AbyssalMaw = { "Teeth", "Eye" }, RainbowDragon = { "Horns", "Arc", "Whiskers" },
	Cinder = { "FlamesSmall", "RocksDark" }, Frostbite = { "Fringe", "FaceShiver" }, Static = { "Sparks" }, Spore = { "Shrooms" },
	Puddle = { "RaindropsSmall", "Puddle" }, Dust = { "SandRing" }, Feather = { "Feathers" }, Tick = { "ClockHands" },
	Copper = { "Coins" }, Satchel = { "Satchel" }, Hiccup = { "FaceHiccup", "Bubbles" }, Mushcap = { "Shrooms", "FaceHappy" },
	BogMist = { "Reeds" }, Pumice = { "Rocks" }, Wildfire = { "Flames" }, Icicle = { "Fringe" },
	Sparkbolt = { "LightningCore" }, Toxic = { "BubblesGreen", "FaceSick" }, Geyser = { "Geyser" }, Boulder = { "SnowBoulders" },
	Drift = { "Ribbons", "Stars" }, Rewind = { "ClockHands", "Arrows" }, Silver = { "SilverRim" }, Merchant = { "Coins", "TopHat" },
	Jester = { "JesterHat", "FaceMischief" }, Rumble = { "LightningCore", "FaceAngry" }, Glowcap = { "ShroomsGlow" }, Quartz = { "Gems" },
	Inferno = { "Flames", "Horns" }, Blizzard = { "Snowflake", "Fringe" }, Thunderhead2 = { "Anvil", "Horns" }, Plague = { "BubblesGreen", "FaceSick" },
	Tsunami = { "Wave" }, Tectonic = { "Rocks", "Cracks" }, Wormhole = { "PlanetRing", "Eye" }, Hyperdrive = { "Streaks", "Stars" },
	GoldRush = { "Coins", "Gems" }, Poltergeist = { "FaceSpooky" }, Sporestorm = { "Shrooms", "Ribbons" }, Ragnarok = { "Horns", "Flames" },
	Permafrost = { "Fringe", "CrownIce" }, Gravitas = { "OrbitRocks" }, Treasury = { "Coins", "Crown" }, Maelstrom = { "Eye", "Wave" },
	Mycelium = { "ShroomsGlow", "Halo" }, Geode = { "Gems", "Rocks" }, Primordial = { "Horns", "Teeth" }, Singularity = { "Eye", "PlanetRing" },
	Midas = { "Crown", "Coins" }, Pandemonium = { "FaceMischief", "Horns", "Stars" },
}

function CloudVisuals.Signature(center: BasePart, typeName: string, def, d: number, tint: Color3, style)
	local feats = SIG[typeName]
	if not feats then
		return
	end
	local RGB = Color3.fromRGB
	local cf0 = center.CFrame
	local function add(name: string, size: Vector3, rel: CFrame, color: Color3, kind: string?, alpha: number?)
		local p
		if kind == "Wedge" then
			p = Instance.new("WedgePart")
		else
			p = Instance.new("Part")
			if kind == "Ball" then
				p.Shape = Enum.PartType.Ball
			elseif kind == "Cyl" then
				p.Shape = Enum.PartType.Cylinder
			end
		end
		p.Name = "Sig" .. name
		p.Size = size * d
		p.CFrame = cf0 * CFrame.new(rel.Position * d) * rel.Rotation
		p.Color = color
		p.Material = (kind == "Neon") and Enum.Material.Neon or ((kind == "Glass") and Enum.Material.Glass or Enum.Material.Plastic)
		p.Transparency = alpha or ((kind == "Glass") and 0.2 or 0)
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = center
		w.Part1 = p
		w.Parent = p
		p.Parent = center
		return p
	end
	local A, CF = CFrame.Angles, CFrame.new
	local front = -(center.Size.Z / 2) / d - 0.01 -- the face sits on the front of the core lobe
	local INK = RGB(35, 35, 45)
	local function eyes(y: number, w: number, h: number, shut: boolean?)
		for _, x in { -0.1, 0.1 } do
			if shut then
				add("EyeShut", Vector3.new(w, 0.02, 0.02), CF(x, y, front), INK)
			else
				add("Eye", Vector3.new(w, h, 0.03), CF(x, y, front), INK)
				add("Glint", Vector3.new(w * 0.35, h * 0.35, 0.03), CF(x + w * 0.2, y + h * 0.2, front - 0.01), RGB(255, 255, 255))
			end
		end
	end
	local function brows(y: number, tilt: number)
		for _, x in { -1, 1 } do
			add("Brow", Vector3.new(0.09, 0.022, 0.02), CF(x * 0.1, y, front - 0.005) * A(0, 0, math.rad(x * tilt)), INK)
		end
	end
	local F = {}
	F.FaceHappy = function() eyes(0.04, 0.045, 0.07); add("Smile", Vector3.new(0.12, 0.025, 0.02), CF(0, -0.06, front), INK); add("CheekL", Vector3.new(0.05, 0.03, 0.02), CF(-0.17, -0.03, front + 0.01), RGB(255, 170, 180)); add("CheekR", Vector3.new(0.05, 0.03, 0.02), CF(0.17, -0.03, front + 0.01), RGB(255, 170, 180)) end
	F.FaceSleepy = function() eyes(0.03, 0.07, 0, true); add("Mouth", Vector3.new(0.04, 0.04, 0.02), CF(0, -0.06, front), INK, "Cyl"); add("Zzz", Vector3.new(0.06, 0.06, 0.01), CF(0.24, 0.24, front), RGB(255, 255, 255)) end
	F.FaceGrumpy = function() eyes(0.03, 0.05, 0.05); brows(0.09, -20); add("Frown", Vector3.new(0.1, 0.022, 0.02), CF(0, -0.07, front), INK) end
	F.FaceAngry = function() eyes(0.03, 0.06, 0.05); brows(0.1, -32); add("Grit", Vector3.new(0.14, 0.04, 0.02), CF(0, -0.08, front), RGB(255, 255, 255)) end
	F.FacePuff = function() eyes(0.05, 0.045, 0.06); add("PuffCheeks", Vector3.new(0.12, 0.08, 0.06), CF(0, -0.05, front), tint:Lerp(RGB(255, 255, 255), 0.4), "Ball"); add("Blow", Vector3.new(0.03, 0.03, 0.02), CF(0, -0.05, front - 0.04), INK) end
	F.FaceShiver = function() eyes(0.04, 0.05, 0.06); add("Teeth", Vector3.new(0.14, 0.04, 0.02), CF(0, -0.07, front), RGB(255, 255, 255)); add("Chatter", Vector3.new(0.14, 0.006, 0.021), CF(0, -0.07, front - 0.002), INK) end
	F.FaceHiccup = function() eyes(0.05, 0.05, 0.08); add("O", Vector3.new(0.02, 0.05, 0.05), CF(0, -0.07, front) * A(0, math.rad(90), 0), INK, "Cyl") end
	F.FaceSick = function() eyes(0.03, 0.06, 0, true); add("Wobble", Vector3.new(0.12, 0.02, 0.02), CF(0, -0.07, front) * A(0, 0, 0.2), INK); add("Green", Vector3.new(0.3, 0.1, 0.01), CF(0, -0.02, front + 0.01), RGB(150, 220, 120), nil, 0.5) end
	F.FaceMischief = function() eyes(0.04, 0.05, 0.05); brows(0.1, 25); add("Grin", Vector3.new(0.16, 0.03, 0.02), CF(0.02, -0.06, front) * A(0, 0, -0.15), INK); add("Tongue", Vector3.new(0.04, 0.04, 0.02), CF(0.06, -0.09, front), RGB(255, 120, 140)) end
	F.FaceSpooky = function() eyes(0.05, 0.06, 0.09); add("Wail", Vector3.new(0.02, 0.08, 0.06), CF(0, -0.08, front) * A(0, math.rad(90), 0), INK, "Cyl"); for k = -2, 2 do add("Tatter", Vector3.new(0.08, 0.14, 0.08), CF(k * 0.12, -0.32, 0) * A(math.pi, 0, 0), tint, "Wedge") end end
	F.Raindrops = function() for k = -3, 3 do add("Drop", Vector3.new(0.035, 0.07, 0.035), CF(k * 0.09, -0.32 - (k % 2) * 0.06, (k % 3) * 0.04), RGB(110, 170, 255), "Ball") end end
	F.RaindropsSmall = function() for k = -2, 2 do add("Drop", Vector3.new(0.025, 0.05, 0.025), CF(k * 0.1, -0.3 - (k % 2) * 0.05, 0), RGB(130, 190, 255), "Ball") end end
	F.Tuft = function() add("Tuft", Vector3.new(0.12, 0.12, 0.12), CF(0.02, 0.42, 0), tint, "Ball"); add("Tuft2", Vector3.new(0.08, 0.08, 0.08), CF(0.08, 0.5, 0), tint, "Ball") end
	F.SunPeek = function() add("Sun", Vector3.new(0.05, 0.4, 0.4), CF(0.28, 0.18, 0.1) * A(0, math.rad(90), 0), RGB(255, 210, 90), "Cyl") end
	F.Ribbons = function() for k = 1, 3 do add("Wind", Vector3.new(0.5, 0.02, 0.06), CF(-0.15 + k * 0.08, -0.05 + k * 0.1, -0.3 + k * 0.04) * A(0, 0, 0.1 * k), RGB(235, 245, 255), nil, 0.2) end end
	F.Veil = function() add("Veil", Vector3.new(1.1, 0.04, 0.8), CF(0, -0.18, 0), tint, nil, 0.55) end
	F.Toasted = function() for k = 1, 4 do add("Toast", Vector3.new(0.08, 0.02, 0.08), CF(-0.2 + k * 0.1, 0.33, -0.05 + (k % 2) * 0.1), RGB(210, 150, 90)) end end
	F.Dew = function() for k = 1, 5 do add("Dew", Vector3.new(0.05, 0.05, 0.05), CF(-0.25 + k * 0.1, 0.3 + (k % 2) * 0.04, 0), RGB(200, 240, 255), "Glass") end end
	F.SandRing = function() for k = 1, 10 do local a = k / 10 * math.pi * 2; add("Sand", Vector3.new(0.05, 0.05, 0.05), CF(math.cos(a) * 0.5, -0.1 + math.sin(a * 3) * 0.04, math.sin(a) * 0.5), RGB(225, 195, 140)) end end
	F.Bubbles = function() for k = 1, 5 do add("Bubble", Vector3.one * (0.06 + k * 0.01), CF(-0.3 + k * 0.13, 0.32 + (k % 2) * 0.08, 0.05), RGB(210, 240, 255), "Glass") end end
	F.BubblesGreen = function() for k = 1, 5 do add("Bubble", Vector3.one * (0.06 + k * 0.01), CF(-0.3 + k * 0.13, 0.32 + (k % 2) * 0.08, 0.05), RGB(150, 230, 120), "Glass") end end
	F.Rocks = function() for k = 1, 4 do local a = k * 1.6; add("Rock", Vector3.new(0.09, 0.07, 0.09), CF(math.cos(a) * 0.35, -0.3, math.sin(a) * 0.3) * A(k, k * 2, 0), RGB(140, 130, 120)) end end
	F.RocksDark = function() for k = 1, 4 do local a = k * 1.6; add("Rock", Vector3.new(0.09, 0.07, 0.09), CF(math.cos(a) * 0.35, -0.3, math.sin(a) * 0.3) * A(k, k * 2, 0), RGB(40, 32, 38)) end end
	F.PineTips = function() for k = 1, 3 do add("Pine", Vector3.new(0.1, 0.18, 0.1), CF(-0.2 + k * 0.1, 0.38, 0), RGB(60, 130, 80), "Wedge") end end
	F.Moon = function() add("Moon", Vector3.new(0.05, 0.3, 0.3), CF(-0.3, 0.3, 0) * A(0, math.rad(90), 0), RGB(255, 245, 200), "Cyl"); add("Bite", Vector3.new(0.06, 0.25, 0.25), CF(-0.25, 0.34, -0.02) * A(0, math.rad(90), 0), tint, "Cyl") end
	F.Snowflake = function() for k = 0, 2 do add("Flake", Vector3.new(0.025, 0.3, 0.025), CF(0, 0.45, 0) * A(0, 0, k * math.pi / 3), RGB(255, 255, 255), "Neon") end end
	F.Fringe = function() for k = -4, 4 do add("Icicle", Vector3.new(0.05, 0.14 + (k % 2) * 0.06, 0.05), CF(k * 0.09, -0.33, -0.15) * A(math.pi, 0, 0), RGB(200, 235, 255), "Glass") end end
	F.IceBalls = function() for k = -2, 2 do add("Hail", Vector3.one * 0.07, CF(k * 0.12, -0.34 - (k % 2) * 0.05, 0), RGB(230, 245, 255), "Ball") end end
	F.Petals = function() for k = 1, 6 do local a = k * 1.05; add("Petal", Vector3.new(0.09, 0.02, 0.06), CF(math.cos(a) * 0.4, 0.2 + (k % 2) * 0.1, math.sin(a) * 0.3) * A(0, a, 0.3), RGB(255, 180, 210)) end end
	F.Wave = function() add("Crest", Vector3.new(0.5, 0.16, 0.12), CF(0, 0.38, -0.05) * A(0, 0, 0), RGB(80, 170, 240), "Wedge"); add("Foam", Vector3.new(0.5, 0.05, 0.12), CF(0, 0.47, 0.01), RGB(240, 250, 255)) end
	F.FlamesSmall = function() for k = -1, 1 do add("Flame", Vector3.new(0.07, 0.14, 0.07), CF(k * 0.12, 0.4, 0), RGB(255, 150, 50), "Neon") end end
	F.Flames = function() for k = -2, 2 do add("Flame", Vector3.new(0.09, 0.2 + (2 - math.abs(k)) * 0.06, 0.09), CF(k * 0.12, 0.42, 0), k == 0 and RGB(255, 230, 120) or RGB(255, 120, 40), "Neon") end end
	F.Coral = function() for k = 1, 3 do add("Coral", Vector3.new(0.03, 0.2, 0.03), CF(-0.15 + k * 0.1, 0.38, 0) * A(0, 0, -0.3 + k * 0.2), RGB(255, 120, 150)) end end
	F.SnowBoulders = function() for k = 1, 3 do add("Boulder", Vector3.one * 0.13, CF(-0.25 + k * 0.15, -0.33, 0), RGB(245, 248, 255), "Ball") end end
	F.Fireflies = function() for k = 1, 6 do local a = k * 1.05; add("Firefly", Vector3.one * 0.04, CF(math.cos(a) * 0.55, 0.1 + math.sin(a * 2) * 0.15, math.sin(a) * 0.45), RGB(255, 240, 120), "Neon") end end
	F.SoundRings = function() for k = 1, 3 do add("Ring", Vector3.new(0.01, 0.3 + k * 0.15, 0.3 + k * 0.15), CF(0.35 + k * 0.05, 0, 0) * A(0, 0, 0), RGB(220, 230, 255), "Cyl", 0.4) end end
	F.Coins = function() for k = 1, 5 do local a = k / 5 * math.pi * 2; add("Coin", Vector3.new(0.02, 0.1, 0.1), CF(math.cos(a) * 0.5, 0.05, math.sin(a) * 0.45) * A(0, -a, 0), RGB(255, 205, 60), "Cyl") end end
	F.Flowers = function() for k = 1, 4 do add("Flower", Vector3.one * 0.07, CF(-0.22 + k * 0.11, 0.37, (k % 2) * 0.05), RGB(180, 140, 230), "Ball") end end
	F.SandStream = function() add("Stream", Vector3.new(0.03, 0.4, 0.03), CF(0, -0.35, 0), RGB(240, 210, 140), "Neon") end
	F.Anvil = function() add("Anvil", Vector3.new(1.1, 0.12, 0.6), CF(0.08, 0.5, 0), tint:Lerp(RGB(255, 255, 255), 0.15)) end
	F.LightningCore = function() -- v2.15: on the front of the (now opaque) cloud so it stays visible
		local z = front - 0.08
		add("CoreGlass", Vector3.one * 0.26, CF(0.12, -0.02, z), RGB(200, 230, 255), "Glass", 0.3)
		add("BoltA", Vector3.new(0.035, 0.16, 0.035), CF(0.1, 0.03, z - 0.02) * A(0, 0, 0.5), RGB(255, 245, 160), "Neon")
		add("BoltB", Vector3.new(0.035, 0.16, 0.035), CF(0.14, -0.08, z - 0.02) * A(0, 0, -0.5), RGB(255, 245, 160), "Neon")
	end
	F.Crest = function() for k = 1, 4 do add("Crest", Vector3.new(0.04, 0.16, 0.12), CF(0, 0.42, -0.15 + k * 0.08), RGB(255, 170, 60), "Neon") end end
	F.Stars = function() for k = 1, 5 do local a = k * 1.25; add("Star", Vector3.one * 0.05, CF(math.cos(a) * 0.55, 0.25 + (k % 2) * 0.12, math.sin(a) * 0.4) * A(0, 0, math.pi / 4), RGB(255, 250, 200), "Neon") end end
	F.PlanetRing = function() add("Ring", Vector3.new(0.02, 1.2, 1.2), CF(0, 0, 0) * A(0.4, 0, math.rad(90)), RGB(230, 200, 255), "Cyl", 0.35) end
	F.ClockHands = function() add("Dial", Vector3.new(0.02, 0.3, 0.3), CF(0, 0.02, front) * A(0, math.rad(90), 0), RGB(255, 245, 220), "Cyl"); add("HandL", Vector3.new(0.015, 0.11, 0.015), CF(0, 0.07, front - 0.015), INK); add("HandS", Vector3.new(0.08, 0.015, 0.015), CF(0.04, 0.02, front - 0.015), INK) end
	F.Arrows = function() for _, x in { -1, 1 } do add("Arrow", Vector3.new(0.05, 0.1, 0.03), CF(x * 0.4, 0.1, 0) * A(0, 0, x * math.pi / 2), RGB(120, 230, 255), "Wedge") end end
	F.Gems = function() for k = 1, 3 do add("Gem", Vector3.new(0.08, 0.14, 0.08), CF(-0.15 + k * 0.1, 0.4, 0) * A(0, math.rad(45), 0), k == 2 and RGB(255, 90, 180) or RGB(110, 200, 255), "Glass") end end
	F.Arc = function() for k = 0, 6 do local t = k / 6 * math.pi; add("Arc", Vector3.new(0.06, 0.06, 0.06), CF(math.cos(t) * 0.55, 0.15 + math.sin(t) * 0.45, 0.2), Color3.fromHSV(k / 7, 0.7, 1), "Neon") end end
	F.Eye = function() add("EyeWhite", Vector3.new(0.02, 0.26, 0.26), CF(0, 0.02, front) * A(0, math.rad(90), 0), RGB(255, 255, 255), "Cyl"); add("Iris", Vector3.new(0.025, 0.14, 0.14), CF(0, 0.02, front - 0.01) * A(0, math.rad(90), 0), RGB(200, 60, 220), "Cyl"); add("Pupil", Vector3.new(0.03, 0.06, 0.06), CF(0, 0.02, front - 0.02) * A(0, math.rad(90), 0), INK, "Cyl") end
	F.Horns = function() for _, x in { -1, 1 } do add("Horn", Vector3.new(0.07, 0.22, 0.07), CF(x * 0.2, 0.42, 0) * A(0, 0, -x * 0.4), RGB(250, 235, 200), "Wedge") end end
	F.Crown = function() add("Band", Vector3.new(0.3, 0.07, 0.3), CF(0, 0.44, 0), RGB(255, 210, 60)); for k = 0, 3 do local a = k * math.pi / 2; add("Point", Vector3.new(0.05, 0.09, 0.05), CF(math.cos(a) * 0.12, 0.52, math.sin(a) * 0.12), RGB(255, 210, 60)) end; add("Jewel", Vector3.one * 0.05, CF(0, 0.45, -0.16), RGB(255, 60, 90), "Neon") end
	F.CrownIce = function() for k = 0, 4 do local a = k / 5 * math.pi * 2; add("IceSpike", Vector3.new(0.04, 0.14, 0.04), CF(math.cos(a) * 0.12, 0.5, math.sin(a) * 0.12), RGB(200, 240, 255), "Glass") end end
	F.Halo = function() add("Halo", Vector3.new(0.02, 0.4, 0.4), CF(0, 0.58, 0) * A(0, 0, math.rad(90)), RGB(255, 235, 140), "Neon") end
	F.Wings = function() for _, x in { -1, 1 } do add("Wing", Vector3.new(0.04, 0.35, 0.3), CF(x * 0.55, 0.15, 0.1) * A(0, 0, x * -0.6), RGB(255, 255, 255), "Wedge") end end
	F.Teeth = function() for k = -3, 3 do add("Tooth", Vector3.new(0.05, 0.08, 0.04), CF(k * 0.06, -0.12, front) * A(math.pi, 0, 0), RGB(255, 255, 245), "Wedge") end end
	F.Fins = function() add("Fin", Vector3.new(0.04, 0.3, 0.3), CF(0, 0.42, 0.1), tint, "Wedge") end
	F.StarTrail = function() for k = 1, 4 do add("Trail", Vector3.one * (0.08 - k * 0.012), CF(0.35 + k * 0.1, -0.1 - k * 0.08, 0), RGB(255, 240, 180), "Neon") end end
	F.Sprout = function() add("Stem", Vector3.new(0.025, 0.15, 0.025), CF(0, 0.45, 0), RGB(90, 170, 80)); add("Leaf", Vector3.new(0.12, 0.02, 0.06), CF(0.05, 0.52, 0), RGB(110, 200, 90)) end
	F.Corona = function() add("Disc", Vector3.new(0.03, 0.42, 0.42), CF(0, 0.05, front - 0.02) * A(0, math.rad(90), 0), RGB(15, 10, 20), "Cyl"); add("Glow", Vector3.new(0.02, 0.5, 0.5), CF(0, 0.05, front + 0.01) * A(0, math.rad(90), 0), RGB(255, 200, 120), "Neon") end
	F.Whiskers = function() for _, x in { -1, 1 } do add("Whisker", Vector3.new(0.4, 0.015, 0.015), CF(x * 0.3, -0.05, front) * A(0, 0, x * 0.2), RGB(255, 230, 150)) end end
	F.Sparks = function() for k = 1, 4 do local a = k * 1.6; add("Spark", Vector3.new(0.02, 0.1, 0.02), CF(math.cos(a) * 0.45, 0.2, math.sin(a) * 0.35) * A(0, 0, 0.6), RGB(255, 250, 170), "Neon") end end
	F.Shrooms = function() for k = 1, 3 do add("Cap", Vector3.new(0.04, 0.14, 0.14), CF(-0.15 + k * 0.1, 0.4, 0) * A(0, 0, math.rad(90)), RGB(230, 90, 110), "Cyl") end end
	F.ShroomsGlow = function() for k = 1, 3 do add("Cap", Vector3.new(0.04, 0.14, 0.14), CF(-0.15 + k * 0.1, 0.4, 0) * A(0, 0, math.rad(90)), RGB(140, 255, 210), "Neon") end end
	F.Puddle = function() add("Puddle", Vector3.new(0.01, 0.5, 0.5), CF(0, -0.5, 0) * A(0, 0, math.rad(90)), RGB(120, 180, 240), "Cyl", 0.3) end
	F.Feathers = function() for k = 1, 3 do add("Feather", Vector3.new(0.03, 0.22, 0.07), CF(0.3 + k * 0.05, 0.2, 0) * A(0, 0, -0.6 + k * 0.3), RGB(255, 255, 255)) end end
	F.Satchel = function() add("Bag", Vector3.new(0.18, 0.16, 0.12), CF(0, -0.32, 0), RGB(170, 120, 70)); add("Tie", Vector3.new(0.19, 0.02, 0.13), CF(0, -0.27, 0), RGB(255, 205, 60)) end
	F.TopHat = function() add("Brim", Vector3.new(0.3, 0.02, 0.3), CF(0, 0.42, 0), INK); add("Hat", Vector3.new(0.18, 0.18, 0.18), CF(0, 0.52, 0), INK); add("HatBand", Vector3.new(0.19, 0.03, 0.19), CF(0, 0.46, 0), RGB(200, 60, 60)) end
	F.JesterHat = function() for _, x in { -1, 1 } do add("Flop", Vector3.new(0.08, 0.22, 0.08), CF(x * 0.12, 0.48, 0) * A(0, 0, -x * 0.8), x < 0 and RGB(230, 60, 90) or RGB(90, 120, 255)); add("Bell", Vector3.one * 0.05, CF(x * 0.24, 0.52, 0), RGB(255, 210, 60), "Ball") end end
	F.Geyser = function() add("Spout", Vector3.new(0.08, 0.5, 0.08), CF(0, 0.55, 0), RGB(170, 220, 255), "Glass"); add("SpoutTop", Vector3.one * 0.16, CF(0, 0.82, 0), RGB(220, 245, 255), "Ball") end
	F.SilverRim = function() add("Rim", Vector3.new(1.0, 0.03, 0.7), CF(0, -0.22, 0), RGB(230, 235, 245), "Neon", 0.2) end
	F.Streaks = function() for k = 1, 3 do add("Streak", Vector3.new(0.02, 0.02, 0.5), CF(-0.2 + k * 0.1, 0.05, 0.5), RGB(200, 230, 255), "Neon") end end
	F.Cracks = function() add("Crack", Vector3.new(0.03, 0.3, 0.02), CF(0.05, 0, front) * A(0, 0, 0.4), RGB(255, 120, 40), "Neon") end
	F.OrbitRocks = function() for k = 1, 5 do local a = k / 5 * math.pi * 2; add("Orbit", Vector3.one * 0.1, CF(math.cos(a) * 0.6, math.sin(a * 2) * 0.1, math.sin(a) * 0.6) * A(k, k, 0), RGB(90, 80, 100)) end end
	F.Reeds = function() for k = 1, 4 do add("Reed", Vector3.new(0.02, 0.3, 0.02), CF(-0.2 + k * 0.08, -0.4, 0.1) * A(0, 0, -0.2 + k * 0.1), RGB(110, 150, 80)); add("Cattail", Vector3.new(0.04, 0.09, 0.04), CF(-0.2 + k * 0.08 + 0.01, -0.27, 0.1), RGB(120, 80, 50)) end end
	F.IceShelf = function() add("Shelf", Vector3.new(0.9, 0.06, 0.6), CF(0, -0.25, 0), RGB(200, 235, 255), "Glass") end
	for _, f in feats do
		if F[f] then
			F[f]()
		end
	end
end

return CloudVisuals
