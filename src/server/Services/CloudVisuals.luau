-- Builds the look of every cloud: soft welded puffs + a smoke emitter that
-- breathes out of the center, plus a signature effect per type.
--
--   Cumulus   white cotton smoke drifting slowly
--   Storm     dark slate smoke, sparks; tag LightningCloud → client arcs + flashes
--   Cosmic    deep purple puffs, rainbow star particles; tag RainbowCloud → client hue cycle
--   Aurora    pale teal puffs, green→purple light ribbons below; tag AuroraCloud → client waves
--   Chrono    golden puffs with cyan/gold time sparks spiralling
--   Mythic    huge black-purple storm with all of the above
--   Rain / Snow / Tornado: tinted puffs + drops / flakes / dust
--
-- No balls: every cloud is an asymmetric stack of ellipsoids (see LAYOUT).
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
local LAYOUT = {
	-- base
	{ Vector3.new(0, -0.12, 0), Vector3.new(1.0, 0.32, 0.62), 0.9 },
	{ Vector3.new(0.32, -0.1, 0.12), Vector3.new(0.55, 0.28, 0.5), 0.88 },
	{ Vector3.new(-0.36, -0.11, -0.08), Vector3.new(0.5, 0.26, 0.46), 0.9 },
	-- body
	{ Vector3.new(-0.12, 0.06, 0.02), Vector3.new(0.58, 0.48, 0.5), 1 },
	{ Vector3.new(0.2, 0.08, -0.06), Vector3.new(0.5, 0.44, 0.46), 1.02 },
	{ Vector3.new(0.4, 0.0, 0.1), Vector3.new(0.34, 0.3, 0.34), 0.97 },
	{ Vector3.new(-0.4, 0.0, 0.12), Vector3.new(0.3, 0.28, 0.32), 0.96 },
	-- crown
	{ Vector3.new(-0.02, 0.24, 0.0), Vector3.new(0.36, 0.32, 0.34), 1.06 },
	{ Vector3.new(0.2, 0.2, 0.1), Vector3.new(0.26, 0.24, 0.26), 1.08 },
}

local STYLE = {
	Cumulus = { Tint = Color3.fromRGB(250, 252, 255), Smoke = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic, Alpha = 0.4 },
	Rain = { Tint = Color3.fromRGB(185, 200, 225), Smoke = Color3.fromRGB(200, 215, 235), Material = Enum.Material.SmoothPlastic, Alpha = 0.4 },
	Snow = { Tint = Color3.fromRGB(250, 252, 255), Smoke = Color3.fromRGB(240, 248, 255), Material = Enum.Material.SmoothPlastic, Alpha = 0.35 },
	Tornado = { Tint = Color3.fromRGB(200, 195, 180), Smoke = Color3.fromRGB(190, 185, 165), Material = Enum.Material.SmoothPlastic, Alpha = 0.4 },
	Storm = { Tint = Color3.fromRGB(70, 72, 90), Smoke = Color3.fromRGB(45, 45, 60), Material = Enum.Material.Slate, Alpha = 0.1 },
	Cosmic = { Tint = Color3.fromRGB(70, 35, 130), Smoke = Color3.fromRGB(120, 60, 200), Material = Enum.Material.SmoothPlastic, Alpha = 0.3 },
	Aurora = { Tint = Color3.fromRGB(190, 255, 235), Smoke = Color3.fromRGB(160, 255, 210), Material = Enum.Material.SmoothPlastic, Alpha = 0.4 },
	Chrono = { Tint = Color3.fromRGB(255, 235, 175), Smoke = Color3.fromRGB(255, 225, 150), Material = Enum.Material.SmoothPlastic, Alpha = 0.35 },
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
	local tint = shiny and Weather.ShinyColor or style.Tint

	-- Asymmetric puffy body. A random mirror + jitter makes every cloud unique.
	local rng = Random.new()
	local mirror = rng:NextNumber() < 0.5 and -1 or 1
	local center
	for i, puff in LAYOUT do
		local jitter = Vector3.new(rng:NextNumber(-0.04, 0.04), rng:NextNumber(-0.03, 0.03), rng:NextNumber(-0.04, 0.04))
		local offset = (Vector3.new(puff[1].X * mirror, puff[1].Y, puff[1].Z) + jitter) * d
		local size = puff[2] * d * rng:NextNumber(0.92, 1.08)

		local p = Instance.new("Part")
		p.Name = i == 1 and "Core" or ("Puff" .. i)
		p.Size = size
		p.Color = shade(tint, puff[3])
		p.Material = shiny and Enum.Material.Neon or style.Material
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
			p.CFrame = center.CFrame * CFrame.new(offset - LAYOUT[1][1] * d)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = center
			weld.Part1 = p
			weld.Parent = p
			p.Parent = center
		else
			center = p
		end
	end
	center:SetAttribute("Motion", visual)

	-- Puffy smoke breathing out of the center
	emitter(center, {
		Name = "Smoke",
		Texture = SMOKE,
		Color = ColorSequence.new(shiny and Weather.ShinyColor or style.Smoke),
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
	local smokeColor = shiny and Weather.ShinyColor or style.Smoke
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
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			})
			beam.Width0 = d * 0.35
			beam.Width1 = d * 0.15
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
