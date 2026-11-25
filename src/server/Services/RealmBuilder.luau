-- v2.42 (director): every totem realm is a huge SEALED cube far away from the
-- world (nothing outside is visible from inside, nothing inside from the
-- world). Inside: an immersive biome-themed landscape - walls, painted
-- "sky" ceiling, landmarks, props, particles and lights. No monsters yet.
--
-- RealmBuilder.Build(parent, biome, center, rng) -> { Model, Arrive, Portal }
--   center = middle of the floor (floor top at center.Y)
--   Arrive = where a player lands (on the entrance dais, facing inward)
--   Portal = the return-portal part (ForgeService puts the prompt on it)
-- Model attributes (read by Client/RealmFx): RealmCenter, RealmSize,
-- RealmAmbient, RealmTint, RealmName

local FxIds = require(game:GetService("ReplicatedStorage").Shared.FxIds)

local RealmBuilder = {}

local S, H, T = 400, 200, 8 -- inner width/depth, inner height, shell thickness
RealmBuilder.Size = Vector3.new(S, H, S)

local V, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local rad = math.rad
local M = Enum.Material

------------------------------------------------------------------------
-- context helpers
------------------------------------------------------------------------
local function newCtx(model: Model, shell: Model, C: Vector3, rng: Random)
	local ctx = { Model = model, Shell = shell, C = C, Rng = rng, Taken = {} }

	function ctx.L(x: number, y: number, z: number): Vector3
		return C + V(x, y, z)
	end

	function ctx.part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?, parent: Instance?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or M.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in props or {} do
			(p :: any)[k] = v
		end
		p.Parent = parent or model
		return p
	end

	function ctx.ball(name: string, d: number, pos: Vector3, color: Color3, mat: Enum.Material?, props: { [string]: any }?): Part
		local pr = { Shape = Enum.PartType.Ball }
		for k, v in props or {} do
			pr[k] = v
		end
		return ctx.part(name, V(d, d, d), CF(pos), color, mat, pr)
	end

	-- squashed sphere (a Ball part is always round: use a sphere mesh on a block)
	function ctx.blob(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?): Part
		local p = ctx.part(name, size, cf, color, mat, props)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end

	-- standing cylinder (Roblox cylinders lie along X)
	function ctx.cyl(name: string, height: number, d: number, pos: Vector3, color: Color3, mat: Enum.Material?, props: { [string]: any }?, tilt: CFrame?): Part
		local pr = { Shape = Enum.PartType.Cylinder }
		for k, v in props or {} do
			pr[k] = v
		end
		return ctx.part(name, V(height, d, d), CF(pos) * (tilt or CFrame.identity) * CFrame.Angles(0, 0, rad(90)), color, mat, pr)
	end

	function ctx.light(p: BasePart, color: Color3, range: number, brightness: number?)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness or 1.5
		l.Shadows = false
		l.Parent = p
		return l
	end

	-- random free floor spot (x, z) at least `gap` from other taken spots,
	-- outside the entrance area and `edge` studs from the walls
	function ctx.spot(gap: number, edge: number?): (number?, number?)
		local e = S / 2 - (edge or 20)
		for _ = 1, 40 do
			local x, z = rng:NextNumber(-e, e), rng:NextNumber(-e, e)
			local ok = (V(x, 0, z) - V(0, 0, -S / 2 + 40)).Magnitude > 60 -- entrance dais + its view
			if ok then
				for _, t in ctx.Taken do
					if (V(x, 0, z) - V(t[1], 0, t[2])).Magnitude < math.max(gap, t[3]) then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(ctx.Taken, { x, z, gap })
				return x, z
			end
		end
		return nil, nil
	end

	function ctx.emitter(name: string, size: Vector3, pos: Vector3, props: { [string]: any })
		local p = ctx.part(name, size, CF(pos), RGB(255, 255, 255), nil, {
			Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		})
		local e = Instance.new("ParticleEmitter")
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Parent = p
		return e
	end

	return ctx
end

local function jitter(c: Color3, rng: Random, amt: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, math.clamp(s + rng:NextNumber(-amt, amt) * 0.5, 0, 1), math.clamp(v + rng:NextNumber(-amt, amt), 0, 1))
end

------------------------------------------------------------------------
-- the sealed shell: floor, rugged walls with strata, ceiling "sky"
------------------------------------------------------------------------
local function buildShell(ctx, th)
	local rng, L, shell = ctx.Rng, ctx.L, ctx.Shell
	local function sp(name, size, cf, color, mat, props)
		return ctx.part(name, size, cf, color, mat, props, shell)
	end
	-- floor slab + a patchwork of ground tiles
	sp("FloorSlab", V(S + 2 * T, T, S + 2 * T), CF(L(0, -T / 2, 0)), th.Floor, th.FloorMat)
	local n, w = 10, S / 10
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local x, z = -S / 2 + (i + 0.5) * w, -S / 2 + (j + 0.5) * w
			sp("Ground" .. i .. "_" .. j, V(w, 1, w), CF(L(x, -0.5 + rng:NextNumber(0.1, 0.45), z)), jitter(th.Floor, rng, 0.06), th.FloorMat)
		end
	end
	-- ceiling = the realm's sky
	sp("Ceiling", V(S + 2 * T, T, S + 2 * T), CF(L(0, H + T / 2, 0)), th.Sky, th.SkyMat or M.SmoothPlastic)
	-- walls: rugged vertical slabs with a jittered inner face
	local seg = 20
	for side = 0, 3 do
		local yaw = side * math.pi / 2
		local rot = CFrame.Angles(0, yaw, 0)
		for k = 0, S / seg - 1 do
			local along = -S / 2 + (k + 0.5) * seg
			local off = rng:NextNumber(0, 7)
			local depth = T + off
			local pos = rot * V(along, H / 2, S / 2 + T / 2 - off / 2)
			sp("Wall" .. side .. "_" .. k, V(seg + 0.4, H + 2, depth), CF(L(pos.X, pos.Y, pos.Z)) * rot, jitter(th.Wall, rng, 0.07), th.WallMat)
		end
		-- corner pillar
		local cpos = rot * V(S / 2 + T / 2, H / 2, S / 2 + T / 2)
		sp("Corner" .. side, V(T * 2, H + 2, T * 2), CF(L(cpos.X, cpos.Y, cpos.Z)), th.Wall, th.WallMat)
		-- strata bands / trims running round the room
		for b, band in th.Bands or {} do
			local bpos = rot * V(0, band[1], S / 2 - 6)
			sp("Band" .. side .. "_" .. b, V(S, band[2], 2.5), CF(L(bpos.X, bpos.Y, bpos.Z)) * rot, band[3], band[4] or th.WallMat)
		end
	end
end

------------------------------------------------------------------------
-- entrance dais + return portal (south wall, z = -S/2)
------------------------------------------------------------------------
local function buildEntrance(ctx, th, title: string)
	local L = ctx.L
	local z0 = -S / 2 + 26
	ctx.part("Dais", V(44, 4, 36), CF(L(0, 2, z0)), th.Trim, M.Slate)
	ctx.part("DaisTop", V(40, 0.4, 32), CF(L(0, 4.2, z0)), th.Accent, M.Marble)
	for k = 1, 3 do -- steps down into the realm
		ctx.part("Step" .. k, V(24, 4 - k, 4), CF(L(0, (4 - k) / 2, z0 + 18 + k * 4 - 2)), th.Trim, M.Slate)
	end
	for s = -1, 1, 2 do
		local b = ctx.part("Brazier" .. s, V(3, 3, 3), CF(L(s * 17, 5.7, z0 + 12)), th.Trim, M.Slate)
		local flame = ctx.part("BrazierGlow" .. s, V(2.2, 1, 2.2), CF(L(s * 17, 7.7, z0 + 12)), th.Accent, M.Neon, { CanCollide = false })
		ctx.light(flame, th.Accent, 30, 2)
		local f = Instance.new("Fire")
		f.Size = 4
		f.Color = th.Accent
		f.SecondaryColor = th.Glow
		f.Parent = b
	end
	-- portal: two pillars, a lintel and a glowing disc
	local pz = -S / 2 + 12
	for s = -1, 1, 2 do
		ctx.part("PortalPillar" .. s, V(3, 16, 3), CF(L(s * 9, 12, pz)), th.Trim, M.Slate)
		ctx.part("PortalCap" .. s, V(4, 1.5, 4), CF(L(s * 9, 20.5, pz)), th.Accent, M.Neon)
	end
	ctx.part("PortalLintel", V(22, 2.5, 3.5), CF(L(0, 21.5, pz)), th.Trim, M.Slate)
	-- a standing disc facing into the room (cylinder axis along Z)
	local portal = ctx.part("ReturnPortal", V(1, 15, 15), CF(L(0, 12, pz)) * CFrame.Angles(0, rad(90), 0), th.Glow, M.Neon,
		{ Shape = Enum.PartType.Cylinder, Transparency = 0.25, CanCollide = false })
	ctx.light(portal, th.Glow, 24, 2)
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = FxIds.Swirl or "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Color = ColorSequence.new(th.Glow)
	swirl.LightEmission = 0.8
	swirl.Size = NumberSequence.new(4, 0)
	swirl.Lifetime = NumberRange.new(1, 1.6)
	swirl.Rate = 14
	swirl.Speed = NumberRange.new(0)
	swirl.RotSpeed = NumberRange.new(120, 200)
	swirl.Parent = portal
	-- title plate above the portal
	local sign = ctx.part("Title", V(34, 6, 1), CF(L(0, 28, pz)), th.Trim, M.Slate)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = th.Glow
	label.Text = title
	label.Parent = gui
	gui.Parent = sign
	local arrive = CFrame.lookAt(L(0, 5, z0 + 4), L(0, 5, 0))
	return arrive, portal
end

------------------------------------------------------------------------
-- reusable props
------------------------------------------------------------------------
local function mesa(ctx, x, z, r, h, colors)
	local L, rng = ctx.L, ctx.Rng
	local y = 0
	local tiers = math.max(2, math.floor(h / 10))
	for k = 1, tiers do
		local th = h / tiers
		local rr = r * (1 - (k - 1) * 0.12)
		ctx.part("Mesa", V(rr * 2, th, rr * 2 * rng:NextNumber(0.8, 1.1)), CF(L(x, y + th / 2, z)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), colors[(k - 1) % #colors + 1], M.Sandstone)
		y += th
	end
	return y
end

local function pine(ctx, x, z, h, leaf, snow)
	local L = ctx.L
	ctx.cyl("Trunk", h * 0.3, h * 0.08, L(x, h * 0.15, z), RGB(95, 70, 50), M.Wood)
	for k = 0, 2 do
		local w = h * (0.55 - k * 0.14)
		local y = h * (0.3 + k * 0.22)
		ctx.part("Needles", V(w, h * 0.22, w), CF(L(x, y, z)) * CFrame.Angles(0, rad(45 * k), 0), leaf, M.Grass)
		if snow then
			ctx.part("SnowCap", V(w * 0.8, h * 0.05, w * 0.8), CF(L(x, y + h * 0.12, z)) * CFrame.Angles(0, rad(45 * k), 0), RGB(250, 252, 255), M.Snow)
		end
	end
end

local function crystal(ctx, base: Vector3, h: number, w: number, tilt: CFrame, color: Color3, glow: boolean?)
	local cf = CF(base) * tilt
	ctx.part("Crystal", V(w, h, w), cf * CF(0, h / 2, 0) * CFrame.Angles(0, rad(45), 0), color, glow and M.Neon or M.Glass,
		{ Transparency = glow and 0.1 or 0.2, CastShadow = false })
	ctx.part("CrystalTip", V(w * 0.6, w * 0.9, w * 0.6), cf * CF(0, h + w * 0.3, 0) * CFrame.Angles(0, rad(45), rad(45)), color:Lerp(RGB(255, 255, 255), 0.4), M.Neon,
		{ CastShadow = false })
end

local function mushroom(ctx, x, z, h, capD, capColor, stemColor, lightIt)
	local L, rng = ctx.L, ctx.Rng
	local tilt = CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
	ctx.cyl("Stem", h, capD * 0.22, L(x, h / 2, z), stemColor, M.SmoothPlastic, nil, tilt)
	local top = (CF(L(x, 0, z)) * tilt * CF(0, h, 0)).Position
	ctx.blob("Cap", V(capD, capD * 0.42, capD), CF(top), capColor, M.SmoothPlastic)
	ctx.part("Gill", V(capD * 0.9, 0.6, capD * 0.9), CF(top - V(0, capD * 0.08, 0)), capColor:Lerp(RGB(255, 255, 255), 0.5), M.Neon,
		{ Shape = Enum.PartType.Cylinder, CFrame = CF(top - V(0, capD * 0.08, 0)) * CFrame.Angles(0, 0, rad(90)), Size = V(0.6, capD * 0.9, capD * 0.9) })
	for k = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local rr = rng:NextNumber(0.15, 0.4) * capD
		ctx.ball("CapDot", capD * 0.1, top + V(math.cos(a) * rr, capD * 0.17, math.sin(a) * rr), RGB(255, 255, 255), M.Neon)
	end
	if lightIt then
		local glowP = ctx.part("CapLight", V(1, 1, 1), CF(top - V(0, capD * 0.2, 0)), capColor, nil, { Transparency = 1, CanCollide = false })
		ctx.light(glowP, capColor, math.min(capD * 1.6, 60), 2)
	end
end

------------------------------------------------------------------------
-- THEMES
------------------------------------------------------------------------
local THEMES = {}

THEMES.Plateau = {
	Floor = RGB(226, 190, 130), FloorMat = M.Sand, Sky = RGB(255, 200, 140),
	Wall = RGB(205, 120, 70), WallMat = M.Sandstone, Trim = RGB(150, 95, 60), Accent = RGB(255, 205, 90), Glow = RGB(255, 220, 120),
	Bands = { { 40, 6, RGB(240, 190, 130) }, { 85, 4, RGB(170, 80, 50) }, { 130, 8, RGB(250, 215, 160) }, { 175, 5, RGB(185, 100, 60) } },
	Ambient = RGB(185, 150, 115), Tint = RGB(255, 240, 220),
	Build = function(ctx)
		local L, rng = ctx.L, ctx.Rng
		-- giant sun on the ceiling with rays
		ctx.cyl("Sun", 2, 70, L(0, H - 1.5, 40), RGB(255, 230, 140), M.Neon)
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			ctx.part("SunRay", V(6, 1, 34), CF(L(math.cos(a) * 58, H - 1, 40 + math.sin(a) * 58)) * CFrame.Angles(0, -a + math.pi / 2, 0), RGB(255, 200, 90), M.Neon)
		end
		-- tablelands
		local COL = { RGB(210, 120, 70), RGB(235, 175, 115), RGB(190, 100, 60), RGB(245, 205, 150) }
		for _ = 1, 9 do
			local x, z = ctx.spot(70, 40)
			if x then
				local top = mesa(ctx, x, z, rng:NextNumber(14, 24), rng:NextNumber(30, 70), COL)
				for _ = 1, 3 do -- shrubs on top
					ctx.ball("TopShrub", rng:NextNumber(3, 5), L(x + rng:NextNumber(-8, 8), top + 1.5, z + rng:NextNumber(-8, 8)), RGB(120, 150, 70), M.Grass)
				end
			end
		end
		-- stone arches
		for _ = 1, 3 do
			local x, z = ctx.spot(60, 50)
			if x then
				local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
				local base = CF(L(x, 0, z)) * yaw
				for s = -1, 1, 2 do
					ctx.part("ArchLeg", V(8, 34, 8), base * CF(s * 16, 17, 0), RGB(200, 115, 70), M.Sandstone)
				end
				ctx.part("ArchTop", V(44, 9, 9), base * CF(0, 38, 0), RGB(215, 135, 85), M.Sandstone)
			end
		end
		-- golden sun obelisk in the middle
		ctx.part("ObeliskBase", V(16, 4, 16), CF(L(0, 2, 30)), RGB(150, 95, 60), M.Sandstone)
		ctx.part("Obelisk", V(6, 40, 6), CF(L(0, 24, 30)), RGB(240, 190, 80), M.Metal)
		local cap = ctx.part("ObeliskCap", V(5, 5, 5), CF(L(0, 46, 30)) * CFrame.Angles(rad(45), 0, rad(45)), RGB(255, 225, 120), M.Neon)
		ctx.light(cap, RGB(255, 210, 120), 50, 2)
		-- cacti, dry bushes, bones of rock
		for _ = 1, 40 do
			local x, z = ctx.spot(10)
			if x then
				local hgt = rng:NextNumber(5, 12)
				ctx.cyl("Cactus", hgt, 2.2, L(x, hgt / 2, z), RGB(85, 150, 80), M.Grass)
				for s = -1, 1, 2 do
					if rng:NextNumber() < 0.7 then
						local ay = rng:NextNumber(hgt * 0.4, hgt * 0.7)
						ctx.part("CactusArm", V(2.4, 1.6, 1.6), CF(L(x + s * 1.8, ay, z)), RGB(85, 150, 80), M.Grass)
						ctx.cyl("CactusArmUp", 3, 1.5, L(x + s * 2.6, ay + 1.6, z), RGB(85, 150, 80), M.Grass)
					end
				end
			end
		end
		for _ = 1, 50 do
			local x, z = ctx.spot(6)
			if x then
				ctx.ball("DryBush", rng:NextNumber(2, 4), L(x, 1, z), RGB(170, 150, 80), M.Grass)
			end
		end
		-- gold veins on the walls
		for _ = 1, 24 do
			local side = rng:NextInteger(0, 3)
			local rot = CFrame.Angles(0, side * math.pi / 2, 0)
			local p = rot * V(rng:NextNumber(-S / 2 + 20, S / 2 - 20), rng:NextNumber(10, H - 20), S / 2 - 7)
			ctx.part("GoldVein", V(rng:NextNumber(6, 18), 1, 0.6), CF(L(p.X, p.Y, p.Z)) * rot * CFrame.Angles(0, 0, rng:NextNumber(-0.6, 0.6)), RGB(255, 210, 80), M.Neon)
		end
		ctx.emitter("Dust", V(S - 20, 60, S - 20), L(0, 40, 0), {
			Texture = FxIds.Glow, Color = ColorSequence.new(RGB(255, 225, 160)), LightEmission = 0.6, Rate = 60,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180),
			Transparency = NumberSequence.new(0.3),
		})
	end,
}

THEMES.Mountains = {
	Floor = RGB(240, 246, 252), FloorMat = M.Snow, Sky = RGB(40, 50, 90),
	Wall = RGB(160, 195, 225), WallMat = M.Glacier, Trim = RGB(110, 140, 170), Accent = RGB(170, 230, 255), Glow = RGB(190, 240, 255),
	Bands = { { 60, 3, RGB(230, 245, 255), M.Snow }, { 120, 3, RGB(230, 245, 255), M.Snow } },
	Ambient = RGB(150, 170, 205), Tint = RGB(225, 240, 255),
	Build = function(ctx)
		local L, rng = ctx.L, ctx.Rng
		-- aurora ribbons across the night ceiling + stars
		for k = 0, 5 do
			local col = k % 2 == 0 and RGB(110, 255, 190) or RGB(180, 120, 255)
			for j = -6, 6 do
				ctx.part("Aurora", V(30, 1, 10), CF(L(j * 30, H - 2 - math.sin(j * 0.7 + k) * 4, -120 + k * 50 + math.sin(j * 0.5 + k) * 14)) * CFrame.Angles(0, math.sin(j + k) * 0.4, 0),
					col, M.Neon, { Transparency = 0.45, CanCollide = false, CastShadow = false })
			end
		end
		for _ = 1, 80 do
			ctx.ball("Star", rng:NextNumber(0.8, 1.6), L(rng:NextNumber(-190, 190), H - 0.6, rng:NextNumber(-190, 190)), RGB(255, 255, 255), M.Neon, { CanCollide = false })
		end
		-- frozen lake in the middle
		ctx.cyl("Lake", 1, 120, L(0, 0.4, 40), RGB(170, 220, 255), M.Ice, { Transparency = 0.1 })
		ctx.cyl("LakeRim", 0.8, 128, L(0, 0.3, 40), RGB(230, 240, 250), M.Snow)
		table.insert(ctx.Taken, { 0, 40, 75 })
		-- ice spires
		for _ = 1, 10 do
			local x, z = ctx.spot(40, 30)
			if x then
				local hh = rng:NextNumber(30, 80)
				for k = 0, 2 do
					crystal(ctx, L(x + rng:NextNumber(-6, 6), 0, z + rng:NextNumber(-6, 6)), hh * (1 - k * 0.3), rng:NextNumber(5, 9),
						CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)), RGB(160, 215, 255), k == 0)
				end
			end
		end
		-- snowy pines
		for _ = 1, 45 do
			local x, z = ctx.spot(14)
			if x then
				pine(ctx, x, z, rng:NextNumber(12, 26), RGB(50, 105, 85), true)
			end
		end
		-- snow drifts
		for _ = 1, 30 do
			local x, z = ctx.spot(10)
			if x then
				ctx.blob("Drift", V(rng:NextNumber(8, 16), rng:NextNumber(2, 4), rng:NextNumber(6, 12)), CF(L(x, 1, z)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), RGB(250, 252, 255), M.Snow,
					{ CanCollide = false })
			end
		end
		-- icicles hanging from the ceiling
		for _ = 1, 90 do
			local len = rng:NextNumber(6, 22)
			ctx.part("Icicle", V(1.5, len, 1.5), CF(L(rng:NextNumber(-190, 190), H - len / 2, rng:NextNumber(-190, 190))) * CFrame.Angles(0, rad(45), 0), RGB(200, 235, 255), M.Ice,
				{ Transparency = 0.15, CanCollide = false })
		end
		ctx.emitter("Snowfall", V(S - 10, 2, S - 10), L(0, H - 6, 0), {
			Texture = FxIds.Snowflake, Color = ColorSequence.new(RGB(255, 255, 255)), LightEmission = 0.3, Rate = 260,
			Size = NumberSequence.new(0.7), Lifetime = NumberRange.new(14, 18), Speed = NumberRange.new(10, 15),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(15, 15), RotSpeed = NumberRange.new(-60, 60),
		})
	end,
}

THEMES.Mushroom = {
	Floor = RGB(70, 55, 90), FloorMat = M.Grass, Sky = RGB(25, 15, 45),
	Wall = RGB(60, 40, 85), WallMat = M.Slate, Trim = RGB(90, 60, 120), Accent = RGB(255, 120, 220), Glow = RGB(150, 255, 230),
	Bands = { { 50, 2, RGB(140, 255, 220), M.Neon } },
	Ambient = RGB(120, 90, 155), Tint = RGB(240, 225, 255),
	Build = function(ctx)
		local L, rng = ctx.L, ctx.Rng
		local CAPS = { RGB(255, 110, 200), RGB(130, 230, 255), RGB(180, 120, 255), RGB(255, 160, 90), RGB(120, 255, 170) }
		-- giant glowing mushrooms
		for _ = 1, 12 do
			local x, z = ctx.spot(55, 35)
			if x then
				mushroom(ctx, x, z, rng:NextNumber(30, 70), rng:NextNumber(30, 55), CAPS[rng:NextInteger(1, #CAPS)], RGB(235, 225, 245), true)
			end
		end
		-- small mushroom clusters
		for _ = 1, 50 do
			local x, z = ctx.spot(8)
			if x then
				for _ = 1, rng:NextInteger(2, 4) do
					mushroom(ctx, x + rng:NextNumber(-3, 3), z + rng:NextNumber(-3, 3), rng:NextNumber(2, 6), rng:NextNumber(2.5, 5), CAPS[rng:NextInteger(1, #CAPS)], RGB(240, 230, 250), false)
				end
			end
		end
		-- glowing shelf fungus on the walls
		for _ = 1, 60 do
			local side = rng:NextInteger(0, 3)
			local rot = CFrame.Angles(0, side * math.pi / 2, 0)
			local p = rot * V(rng:NextNumber(-S / 2 + 10, S / 2 - 10), rng:NextNumber(6, H - 30), S / 2 - 8)
			local c = CAPS[rng:NextInteger(1, #CAPS)]
			ctx.part("ShelfFungus", V(rng:NextNumber(6, 12), 1.2, 5), CF(L(p.X, p.Y, p.Z)) * rot, c, M.Neon, { Shape = Enum.PartType.Cylinder,
				CFrame = CF(L(p.X, p.Y, p.Z)) * rot * CFrame.Angles(0, 0, rad(90)), Size = V(1.2, rng:NextNumber(6, 12), 6) })
		end
		-- glowing vines hanging from the ceiling
		for _ = 1, 50 do
			local len = rng:NextNumber(20, 70)
			local x, z = rng:NextNumber(-190, 190), rng:NextNumber(-190, 190)
			ctx.part("Vine", V(0.8, len, 0.8), CF(L(x, H - len / 2, z)), RGB(80, 160, 110), M.Grass, { CanCollide = false })
			ctx.ball("VineBulb", 2, L(x, H - len, z), CAPS[rng:NextInteger(1, #CAPS)], M.Neon, { CanCollide = false })
		end
		-- floating spore orbs
		for _ = 1, 60 do
			ctx.ball("SporeOrb", rng:NextNumber(1, 2.5), L(rng:NextNumber(-180, 180), rng:NextNumber(8, 120), rng:NextNumber(-180, 180)), RGB(170, 255, 230), M.Neon,
				{ CanCollide = false, Transparency = 0.2 })
		end
		ctx.emitter("Spores", V(S - 20, 2, S - 20), L(0, 2, 0), {
			Texture = FxIds.Spore, Color = ColorSequence.new(RGB(255, 170, 240), RGB(150, 255, 230)), LightEmission = 0.9, Rate = 120,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(10, 14), Speed = NumberRange.new(3, 7), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30),
		})
	end,
}

THEMES.Marsh = {
	Floor = RGB(70, 85, 60), FloorMat = M.Mud, Sky = RGB(50, 55, 70),
	Wall = RGB(70, 80, 75), WallMat = M.Slate, Trim = RGB(95, 80, 60), Accent = RGB(255, 240, 120), Glow = RGB(160, 200, 255),
	Bands = { { 30, 4, RGB(60, 90, 60), M.Grass } },
	Ambient = RGB(100, 115, 120), Tint = RGB(215, 230, 235),
	Build = function(ctx)
		local L, rng = ctx.L, ctx.Rng
		-- storm clouds under the ceiling (+ lightning, animated by ForgeService)
		for _ = 1, 40 do
			ctx.ball("StormCloud", rng:NextNumber(30, 60), L(rng:NextNumber(-180, 180), H - rng:NextNumber(5, 20), rng:NextNumber(-180, 180)),
				jitter(RGB(80, 85, 105), rng, 0.08), M.SmoothPlastic, { CanCollide = false, CastShadow = false })
		end
		for k = 1, 6 do
			local x, z = rng:NextNumber(-150, 150), rng:NextNumber(-150, 150)
			local bolt = ctx.part("Lightning" .. k, V(2, H - 40, 2), CF(L(x, (H - 40) / 2 + 10, z)) * CFrame.Angles(0, 0, rng:NextNumber(-0.08, 0.08)), RGB(240, 240, 255), M.Neon,
				{ Transparency = 1, CanCollide = false, CastShadow = false })
			bolt:SetAttribute("Lightning", true)
			local l = ctx.light(bolt, RGB(200, 210, 255), 60, 0)
			l.Name = "Flash"
		end
		-- murky pools + lily pads
		for _ = 1, 14 do
			local x, z = ctx.spot(40, 25)
			if x then
				local d = rng:NextNumber(24, 44)
				ctx.cyl("Pool", 1, d, L(x, 0.5, z), RGB(60, 110, 100), M.Glass, { Transparency = 0.3 })
				for _ = 1, 4 do
					local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, d * 0.4)
					ctx.cyl("LilyPad", 0.3, rng:NextNumber(3, 5), L(x + math.cos(a) * r, 1.1, z + math.sin(a) * r), RGB(80, 170, 80), M.Grass)
				end
			end
		end
		-- dead twisted trees
		for _ = 1, 22 do
			local x, z = ctx.spot(22)
			if x then
				local hh = rng:NextNumber(18, 36)
				ctx.cyl("DeadTrunk", hh, 3, L(x, hh / 2, z), RGB(75, 65, 55), M.Wood, nil, CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)))
				for _ = 1, 4 do
					local by = rng:NextNumber(hh * 0.5, hh * 0.95)
					local a = rng:NextNumber(0, 6.28)
					ctx.part("Branch", V(1.2, 1.2, rng:NextNumber(6, 12)), CF(L(x, by, z)) * CFrame.Angles(0, a, 0) * CFrame.Angles(rad(rng:NextNumber(20, 50)), 0, 0) * CF(0, 0, -4),
						RGB(75, 65, 55), M.Wood)
				end
				ctx.part("Moss", V(4, 6, 0.4), CF(L(x + 1.5, hh * 0.7, z)), RGB(110, 140, 80), M.Grass, { CanCollide = false })
			end
		end
		-- reeds
		for _ = 1, 70 do
			local x, z = ctx.spot(4)
			if x then
				for _ = 1, 4 do
					local hh = rng:NextNumber(4, 8)
					ctx.part("Reed", V(0.4, hh, 0.4), CF(L(x + rng:NextNumber(-1.5, 1.5), hh / 2, z + rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2)),
						RGB(120, 140, 70), M.Grass)
				end
			end
		end
		-- boardwalk from the entrance into the bog
		for k = 0, 14 do
			ctx.part("Boardwalk", V(10, 1, 9.5), CF(L(math.sin(k * 0.4) * 20, 1.5, -150 + k * 10)) * CFrame.Angles(0, math.cos(k * 0.4) * 0.3, 0), RGB(130, 95, 60), M.WoodPlanks)
		end
		-- will-o-wisps
		for _ = 1, 30 do
			local w = ctx.ball("Wisp", 1.6, L(rng:NextNumber(-180, 180), rng:NextNumber(3, 12), rng:NextNumber(-180, 180)), RGB(170, 255, 200), M.Neon, { CanCollide = false })
			ctx.light(w, RGB(170, 255, 200), 14, 1)
		end
		ctx.emitter("Rain", V(S - 10, 2, S - 10), L(0, H - 20, 0), {
			Texture = FxIds.Streak, Color = ColorSequence.new(RGB(190, 210, 255)), LightEmission = 0.2, Rate = 400,
			Size = NumberSequence.new(1.2), Lifetime = NumberRange.new(2.5, 3), Speed = NumberRange.new(70, 80),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(3, 3), Transparency = NumberSequence.new(0.4),
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		})
	end,
}

THEMES.Canyon = {
	Floor = RGB(225, 215, 245), FloorMat = M.Marble, Sky = RGB(70, 50, 120),
	Wall = RGB(150, 120, 200), WallMat = M.Slate, Trim = RGB(110, 90, 160), Accent = RGB(150, 220, 255), Glow = RGB(210, 170, 255),
	Bands = { { 45, 3, RGB(190, 160, 255), M.Neon }, { 110, 3, RGB(140, 220, 255), M.Neon } },
	Ambient = RGB(165, 150, 205), Tint = RGB(240, 235, 255),
	Build = function(ctx)
		local L, rng = ctx.L, ctx.Rng
		local CRYS = { RGB(150, 200, 255), RGB(255, 150, 220), RGB(190, 150, 255), RGB(150, 255, 230), RGB(255, 240, 150) }
		-- giant crystal clusters
		for _ = 1, 12 do
			local x, z = ctx.spot(50, 30)
			if x then
				local base = rng:NextNumber(30, 75)
				for k = 0, 4 do
					local c = CRYS[rng:NextInteger(1, #CRYS)]
					crystal(ctx, L(x + rng:NextNumber(-8, 8), 0, z + rng:NextNumber(-8, 8)), base * rng:NextNumber(0.4, 1), rng:NextNumber(5, 11),
						CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), c, k == 0)
				end
				local glowP = ctx.part("ClusterLight", V(1, 1, 1), CF(L(x, 10, z)), RGB(255, 255, 255), nil, { Transparency = 1, CanCollide = false })
				ctx.light(glowP, CRYS[rng:NextInteger(1, #CRYS)], 50, 1.8)
			end
		end
		-- crystal shards in the walls
		for _ = 1, 50 do
			local side = rng:NextInteger(0, 3)
			local rot = CFrame.Angles(0, side * math.pi / 2, 0)
			local p = rot * V(rng:NextNumber(-S / 2 + 10, S / 2 - 10), rng:NextNumber(4, H - 20), S / 2 - 7)
			crystal(ctx, L(p.X, p.Y, p.Z), rng:NextNumber(6, 16), rng:NextNumber(2, 5), rot * CFrame.Angles(rad(-70), 0, rng:NextNumber(-0.5, 0.5)), CRYS[rng:NextInteger(1, #CRYS)], false)
		end
		-- stalactites from the ceiling
		for _ = 1, 50 do
			local len = rng:NextNumber(8, 30)
			ctx.part("Stalactite", V(3, len, 3), CF(L(rng:NextNumber(-190, 190), H - len / 2, rng:NextNumber(-190, 190))) * CFrame.Angles(0, rad(45), 0), CRYS[rng:NextInteger(1, #CRYS)], M.Glass,
				{ Transparency = 0.2, CanCollide = false })
		end
		-- prism beams criss-crossing the air
		for k = 1, 8 do
			local a = rng:NextNumber(0, math.pi)
			ctx.part("PrismBeam", V(0.8, 0.8, S * 0.8), CF(L(rng:NextNumber(-80, 80), rng:NextNumber(30, 120), rng:NextNumber(-80, 80))) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), a, 0),
				CRYS[(k % #CRYS) + 1], M.Neon, { Transparency = 0.5, CanCollide = false, CastShadow = false })
		end
		-- floating shards
		for _ = 1, 40 do
			ctx.part("FloatShard", V(1.5, 4, 1.5), CF(L(rng:NextNumber(-180, 180), rng:NextNumber(10, 100), rng:NextNumber(-180, 180))) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
				CRYS[rng:NextInteger(1, #CRYS)], M.Neon, { CanCollide = false })
		end
		ctx.emitter("Sparkle", V(S - 20, 100, S - 20), L(0, 50, 0), {
			Texture = FxIds.Star, Color = ColorSequence.new(RGB(220, 200, 255), RGB(180, 240, 255)), LightEmission = 1, Rate = 80,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(0, 1), RotSpeed = NumberRange.new(-90, 90),
		})
	end,
}

THEMES.Volcanic = {
	Floor = RGB(45, 40, 40), FloorMat = M.Basalt, Sky = RGB(60, 20, 15),
	Wall = RGB(40, 35, 35), WallMat = M.Basalt, Trim = RGB(70, 55, 50), Accent = RGB(255, 120, 40), Glow = RGB(255, 170, 60),
	Bands = { { 20, 2, RGB(255, 100, 30), M.Neon }, { 140, 2, RGB(255, 100, 30), M.Neon } },
	Ambient = RGB(150, 85, 60), Tint = RGB(255, 225, 205),
	Build = function(ctx)
		local L, rng = ctx.L, ctx.Rng
		local LAVA = RGB(255, 110, 30)
		-- the central volcano
		local vz = 60
		for k = 0, 6 do
			local d = 110 - k * 14
			ctx.cyl("VolcanoTier", 9, d, L(0, 4.5 + k * 9, vz), jitter(RGB(55, 45, 42), rng, 0.05), M.Basalt)
		end
		ctx.cyl("CraterLava", 1.2, 22, L(0, 63.6, vz), LAVA, M.Neon)
		local crater = ctx.part("CraterLight", V(1, 1, 1), CF(L(0, 70, vz)), LAVA, nil, { Transparency = 1, CanCollide = false })
		ctx.light(crater, LAVA, 60, 3)
		local f = Instance.new("Fire")
		f.Size = 25
		f.Heat = 25
		f.Color = LAVA
		f.SecondaryColor = RGB(255, 220, 120)
		f.Parent = crater
		for k = 0, 3 do -- lava streams down the cone
			local a = k / 4 * math.pi * 2 + 0.4
			ctx.part("LavaFlow", V(5, 1, 52), CF(L(math.cos(a) * 30, 34, vz + math.sin(a) * 30)) * CFrame.Angles(0, -a - math.pi / 2, 0) * CFrame.Angles(rad(48), 0, 0), LAVA, M.Neon,
				{ CanCollide = false })
		end
		table.insert(ctx.Taken, { 0, vz, 70 })
		-- lava rivers winding across the floor
		for r = 0, 1 do
			local x = r == 0 and -120 or 120
			for k = 0, 18 do
				local z = -170 + k * 19
				x += rng:NextNumber(-10, 10)
				ctx.part("LavaRiver", V(14, 0.6, 20), CF(L(x, 0.5, z)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), LAVA, M.Neon)
				if k % 4 == 0 then
					local glowP = ctx.part("RiverGlow", V(1, 1, 1), CF(L(x, 4, z)), LAVA, nil, { Transparency = 1, CanCollide = false })
					ctx.light(glowP, LAVA, 40, 2)
				end
				if k == 9 then -- basalt bridge
					ctx.part("Bridge", V(20, 2, 8), CF(L(x, 2, z)), RGB(70, 60, 55), M.Basalt)
				end
			end
		end
		-- lavafalls on the walls
		for k = 1, 6 do
			local side = rng:NextInteger(1, 3)
			local rot = CFrame.Angles(0, side * math.pi / 2, 0)
			local p = rot * V(rng:NextNumber(-150, 150), H / 2, S / 2 - 8)
			ctx.part("Lavafall" .. k, V(10, H - 10, 1.5), CF(L(p.X, p.Y, p.Z)) * rot, LAVA, M.Neon, { CanCollide = false })
		end
		-- obsidian spikes and lava cracks
		for _ = 1, 45 do
			local x, z = ctx.spot(14)
			if x then
				local hh = rng:NextNumber(6, 24)
				ctx.part("Obsidian", V(3, hh, 3), CF(L(x, hh / 2 - 1, z)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 3), rng:NextNumber(-0.25, 0.25)),
					RGB(25, 20, 30), M.Glass, { Transparency = 0 })
			end
		end
		for _ = 1, 40 do
			local x, z = ctx.spot(6)
			if x then
				ctx.part("Crack", V(rng:NextNumber(6, 14), 0.3, 0.8), CF(L(x, 0.65, z)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), LAVA, M.Neon)
			end
		end
		ctx.emitter("Embers", V(S - 20, 2, S - 20), L(0, 2, 0), {
			Texture = FxIds.Glow, Color = ColorSequence.new(RGB(255, 200, 80), RGB(255, 80, 20)), LightEmission = 1, Rate = 160,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(8, 18), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25),
		})
		ctx.emitter("Ash", V(S - 20, 2, S - 20), L(0, H - 10, 0), {
			Texture = FxIds.Smoke, Color = ColorSequence.new(RGB(90, 80, 80)), Rate = 30, Transparency = NumberSequence.new(0.6, 1),
			Size = NumberSequence.new(8, 14), Lifetime = NumberRange.new(8, 10), Speed = NumberRange.new(2, 4),
			EmissionDirection = Enum.NormalId.Bottom,
		})
	end,
}

THEMES.Coast = {
	Floor = RGB(230, 215, 170), FloorMat = M.Sand, Sky = RGB(70, 170, 220),
	Wall = RGB(30, 80, 130), WallMat = M.Slate, Trim = RGB(40, 100, 140), Accent = RGB(100, 230, 220), Glow = RGB(120, 220, 255),
	SkyMat = M.Glass,
	Bands = { { 25, 6, RGB(240, 120, 140), M.Grass }, { 70, 3, RGB(60, 130, 170) } },
	Ambient = RGB(80, 140, 180), Tint = RGB(200, 235, 255),
	Build = function(ctx)
		local L, rng = ctx.L, ctx.Rng
		-- water surface ripples under the ceiling + light shafts
		for _ = 1, 30 do
			ctx.part("Ripple", V(rng:NextNumber(30, 70), 0.6, rng:NextNumber(8, 18)), CF(L(rng:NextNumber(-170, 170), H - 1.5, rng:NextNumber(-170, 170))) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
				RGB(170, 235, 255), M.Neon, { Transparency = 0.5, CanCollide = false })
		end
		for _ = 1, 12 do
			ctx.part("LightShaft", V(rng:NextNumber(10, 20), H - 10, 2), CF(L(rng:NextNumber(-150, 150), H / 2, rng:NextNumber(-150, 150))) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 3), 0),
				RGB(200, 245, 255), M.Neon, { Transparency = 0.85, CanCollide = false, CastShadow = false })
		end
		-- coral reefs
		local CORAL = { RGB(255, 120, 140), RGB(255, 180, 80), RGB(190, 120, 255), RGB(110, 220, 200), RGB(255, 230, 120) }
		for _ = 1, 16 do
			local x, z = ctx.spot(30, 25)
			if x then
				ctx.ball("ReefRock", rng:NextNumber(14, 24), L(x, 0, z), RGB(150, 140, 130), M.Rock)
				for _ = 1, 8 do
					local c = CORAL[rng:NextInteger(1, #CORAL)]
					local px, pz = x + rng:NextNumber(-9, 9), z + rng:NextNumber(-9, 9)
					local hh = rng:NextNumber(3, 9)
					if rng:NextNumber() < 0.5 then
						ctx.cyl("CoralTube", hh, rng:NextNumber(1, 2.4), L(px, 5 + hh / 2, pz), c, M.SmoothPlastic, nil, CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)))
					else
						ctx.ball("CoralBrain", rng:NextNumber(3, 6), L(px, 6, pz), c, M.SmoothPlastic)
					end
				end
			end
		end
		-- kelp forests
		for _ = 1, 40 do
			local x, z = ctx.spot(8)
			if x then
				local hh = rng:NextNumber(25, 70)
				local segs = math.floor(hh / 8)
				for k = 0, segs - 1 do
					ctx.part("Kelp", V(1.6, 8.4, 0.5), CF(L(x + math.sin(k * 0.8) * 1.5, k * 8 + 4, z)) * CFrame.Angles(0, k * 0.5, math.sin(k) * 0.15), RGB(60, 140, 80), M.Grass,
						{ CanCollide = false })
				end
			end
		end
		-- sunken ship
		do
			local x, z = ctx.spot(70, 50)
			if x then
				local base = CF(L(x, 0, z)) * CFrame.Angles(0, rng:NextNumber(0, 3), rad(14))
				ctx.part("Hull", V(18, 12, 60), base * CF(0, 5, 0), RGB(100, 70, 45), M.WoodPlanks)
				ctx.part("Deck", V(16, 1, 56), base * CF(0, 11.5, 0), RGB(140, 100, 60), M.WoodPlanks)
				ctx.part("Mast", V(2, 40, 2), base * CF(0, 30, -6), RGB(90, 65, 40), M.Wood)
				ctx.part("Sail", V(0.5, 18, 20), base * CF(1.2, 32, -6) * CFrame.Angles(0, rad(90), 0), RGB(220, 210, 190), M.Fabric, { CanCollide = false, Transparency = 0.2 })
				ctx.part("Chest", V(4, 3, 3), base * CF(0, 13.5, 14), RGB(150, 100, 50), M.Wood)
				local gold = ctx.part("Gold", V(3.5, 0.6, 2.5), base * CF(0, 15.2, 14), RGB(255, 210, 80), M.Neon)
				ctx.light(gold, RGB(255, 210, 120), 16, 1.5)
			end
		end
		-- giant clam with a pearl
		do
			local x, z = 0, 60
			table.insert(ctx.Taken, { x, z, 30 })
			ctx.blob("ClamBottom", V(26, 10, 22), CF(L(x, 2, z)), RGB(220, 200, 230), M.SmoothPlastic)
			ctx.blob("ClamTop", V(26, 8, 22), CF(L(x, 12, z + 6)) * CFrame.Angles(rad(-35), 0, 0), RGB(235, 215, 245), M.SmoothPlastic, { CanCollide = false })
			local pearl = ctx.ball("Pearl", 7, L(x, 9, z), RGB(255, 250, 245), M.Neon)
			ctx.light(pearl, RGB(255, 240, 255), 40, 2)
		end
		-- jellyfish drifting in the water
		for _ = 1, 24 do
			local p = L(rng:NextNumber(-170, 170), rng:NextNumber(30, 150), rng:NextNumber(-170, 170))
			local c = CORAL[rng:NextInteger(1, #CORAL)]
			ctx.blob("JellyBell", V(6, 4, 6), CF(p), c, M.Neon, { Transparency = 0.35, CanCollide = false })
			for k = 1, 4 do
				ctx.part("Tentacle", V(0.3, 6, 0.3), CF(p + V(math.cos(k * 1.57) * 1.5, -4, math.sin(k * 1.57) * 1.5)), c, M.Neon, { Transparency = 0.5, CanCollide = false })
			end
		end
		ctx.emitter("Bubbles", V(S - 20, 2, S - 20), L(0, 2, 0), {
			Texture = FxIds.Bubble, Color = ColorSequence.new(RGB(220, 245, 255)), LightEmission = 0.3, Rate = 140,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.2) }),
			Lifetime = NumberRange.new(10, 14), Speed = NumberRange.new(12, 18), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10),
		})
	end,
}

------------------------------------------------------------------------
function RealmBuilder.Build(parent: Instance, biome: string, center: Vector3, title: string, rng: Random)
	local th = THEMES[biome]
	if not th then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = biome .. "Realm"
	local shell = Instance.new("Model")
	shell.Name = "Shell"
	shell.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the walls always stream in together
	shell.Parent = m
	local ctx = newCtx(m, shell, center, rng)
	buildShell(ctx, th)
	local arrive, portal = buildEntrance(ctx, th, title)
	th.Build(ctx)
	m:SetAttribute("RealmCenter", center + V(0, H / 2, 0))
	m:SetAttribute("RealmSize", V(S + 2 * T, H + 2 * T, S + 2 * T))
	m:SetAttribute("RealmAmbient", th.Ambient)
	m:SetAttribute("RealmTint", th.Tint)
	m:SetAttribute("RealmName", title)
	m.Parent = parent
	return { Model = m, Arrive = arrive, Portal = portal }
end

return RealmBuilder
