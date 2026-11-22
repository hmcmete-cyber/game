-- v2.22 FxKit: layered, "pro" style VFX (director: effects like real Roblox
-- VFX packs - glowing cores, star flares, stretched sparks, dark spiky
-- bursts, shockwave rings, embers, smoke, fire tornadoes, crackling energy).
-- Works on the server (replicates) and on the client.
--
-- Every effect is several layers, each a ParticleEmitter with real curves:
--   white-hot core -> element colour -> dark tail, size grows then shrinks,
--   sparks stretch along their velocity, light flash fades out.
-- Textures: our own (assets/vfx, ids in FxIds) or Roblox built-ins until then.
--
--   FxKit.Burst(pos, color, scale)        energy pop (flare + sparks + ring)
--   FxKit.Explosion(pos, color, scale)    big boom (+ dark spikes, smoke, embers)
--   FxKit.Impact(pos, color, scale)       small hit
--   FxKit.Shockwave(pos, radius, color)   flat ring on the ground
--   FxKit.Charge(pos, color, scale, t)    energy gathering inward
--   FxKit.Tornado(pos, color, scale, t)   spinning flame/energy vortex
--   FxKit.Lightning(a, b, color, width)   crackling bolt
--   FxKit.Pillar(pos, color, height, t)   light column
--   FxKit.Slash(cf, color, scale)         curved slash arc
--   FxKit.Trail(part, color, width)       glowing trail + sparkles on a moving part
--   FxKit.Aura(part, color, scale)        lasting aura (returns a cleanup function)

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FxKit = {}

local Ids = {}
pcall(function()
	Ids = require(script.Parent:WaitForChild("FxIds", 5))
end)
local P = "rbxasset://textures/particles/"
local BUILTIN = {
	Glow = P .. "forcefield_glow_main.dds",
	Flare = P .. "sparkles_main.dds",
	Streak = P .. "sparkles_main.dds",
	Spikes = P .. "explosion01_core_main.dds",
	Ring = P .. "explosion01_shockwave_main.dds",
	Swirl = P .. "forcefield_vortex_main.dds",
	Crackle = P .. "sparkles_main.dds",
	Flame = P .. "fire_main.dds",
	Smoke = P .. "smoke_main.dds",
	Shard = P .. "sparkles_main.dds",
	BeamSoft = "",
	Core = P .. "explosion01_core_main.dds",
	Implode = P .. "explosion01_implosion_main.dds",
	Embers = P .. "fire_sparks_main.dds",
}
local function tex(name: string): string
	local own = Ids[name]
	if own and own ~= "" then
		return own
	end
	return BUILTIN[name] or ""
end
FxKit.Texture = tex

local folder
local function holder(): Instance
	if not folder or not folder.Parent then
		folder = workspace:FindFirstChild("FxKit")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "FxKit"
			folder.Parent = workspace
		end
	end
	return folder
end

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
local function ns(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end
FxKit.NS = ns

-- white-hot -> colour -> darker colour
local function hot(color: Color3, darkEnd: boolean?): ColorSequence
	local white = Color3.new(1, 1, 1)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, white),
		ColorSequenceKeypoint.new(0.18, white:Lerp(color, 0.65)),
		ColorSequenceKeypoint.new(0.5, color),
		ColorSequenceKeypoint.new(1, darkEnd and color:Lerp(Color3.new(0, 0, 0), 0.55) or color),
	})
end
FxKit.Hot = hot

local function anchor(cf: CFrame, life: number, size: Vector3?): BasePart
	local a = Instance.new("Part")
	a.Name = "Fx"
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.CastShadow = true, false, false, false, false
	a.Transparency = 1
	a.Size = size or Vector3.one * 0.2
	a.CFrame = cf
	a.Parent = holder()
	Debris:AddItem(a, life)
	return a
end

local function set(obj: Instance, k: string, v: any)
	pcall(function()
		(obj :: any)[k] = v
	end)
end

-- ParticleEmitter with sensible VFX defaults; o = property overrides
local function emitter(parent: Instance, o: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.LightEmission = 1
	e.LightInfluence = 0
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	for k, v in o do
		set(e, k, v)
	end
	e.Parent = parent
	return e
end

local function emitNow(e: ParticleEmitter, n: number)
	e:Emit(math.max(1, math.floor(n + 0.5)))
end

local function light(parent: Instance, color: Color3, range: number, brightness: number, t: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = math.min(60, range)
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	TweenService:Create(l, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
end

------------------------------------------------------------------------
-- layers (each one reusable)
------------------------------------------------------------------------
-- bright core flash
local function core(a: BasePart, color: Color3, s: number)
	emitNow(emitter(a, {
		Texture = tex("Glow"), Color = hot(color), Brightness = 3, ZOffset = 2,
		Size = ns({ { 0, 1.5 * s }, { 0.25, 5.5 * s }, { 1, 7 * s } }),
		Transparency = ns({ { 0, 0 }, { 0.6, 0.35 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.18, 0.28), Speed = NumberRange.new(0),
	}), 2)
end

-- 4-point star flare that pops and spins a little
local function flare(a: BasePart, color: Color3, s: number)
	emitNow(emitter(a, {
		Texture = tex("Flare"), Color = ColorSequence.new(Color3.new(1, 1, 1), color), Brightness = 4, ZOffset = 3,
		Size = ns({ { 0, 2 * s }, { 0.15, 9 * s }, { 1, 0 } }),
		Transparency = ns({ { 0, 0 }, { 1, 0.6 } }),
		Lifetime = NumberRange.new(0.25, 0.35), Speed = NumberRange.new(0),
		Rotation = NumberRange.new(-15, 15), RotSpeed = NumberRange.new(-60, 60),
	}), 2)
end

-- long thin sparks stretched along their flight direction
local function streaks(a: BasePart, color: Color3, s: number, n: number, speed: number?)
	local sp = (speed or 60) * math.sqrt(s)
	emitNow(emitter(a, {
		Texture = tex("Streak"), Color = hot(color), Brightness = 3,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = ns({ { 0, 0.35 * s }, { 0.3, 0.55 * s }, { 1, 0 } }),
		Squash = ns({ { 0, 2.5 }, { 1, 1.2 } }),
		Transparency = ns({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.25, 0.55), Speed = NumberRange.new(sp * 0.5, sp),
		Drag = 5, Acceleration = Vector3.new(0, -20, 0), Rotation = NumberRange.new(0),
	}), n)
end

-- little glowing orbs / glitter flying out
local function glitter(a: BasePart, color: Color3, s: number, n: number)
	emitNow(emitter(a, {
		Texture = tex("Glow"), Color = hot(color), Brightness = 2,
		Size = ns({ { 0, 0.5 * s }, { 0.5, 0.35 * s }, { 1, 0 } }),
		Transparency = ns({ { 0, 0 }, { 1, 0.4 } }),
		Lifetime = NumberRange.new(0.5, 1.1), Speed = NumberRange.new(10 * s, 28 * s), Drag = 3,
		Acceleration = Vector3.new(0, 4, 0),
	}), n)
end

-- dark spiky splatter (image 3 style), drawn behind the bright core
local function spikes(a: BasePart, color: Color3, s: number)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.55)
	emitNow(emitter(a, {
		Texture = tex("Spikes"), Color = ColorSequence.new(color, dark), LightEmission = 0.35, Brightness = 1.5, ZOffset = 1,
		Size = ns({ { 0, 3 * s }, { 0.2, 10 * s }, { 1, 12 * s } }),
		Transparency = ns({ { 0, 0.05 }, { 0.5, 0.35 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.35, 0.5), Speed = NumberRange.new(0), RotSpeed = NumberRange.new(-20, 20),
	}), 2)
end

local function smoke(a: BasePart, color: Color3, s: number, n: number)
	emitNow(emitter(a, {
		Texture = tex("Smoke"), Color = ColorSequence.new(color:Lerp(Color3.fromRGB(60, 55, 60), 0.6), Color3.fromRGB(40, 38, 42)),
		LightEmission = 0, LightInfluence = 0.6, ZOffset = -1,
		Size = ns({ { 0, 2 * s }, { 1, 7 * s } }),
		Transparency = ns({ { 0, 0.45 }, { 0.3, 0.35 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.9, 1.6), Speed = NumberRange.new(4 * s, 12 * s), Drag = 2,
		Acceleration = Vector3.new(0, 3, 0), RotSpeed = NumberRange.new(-40, 40),
	}), n)
end

local function embers(a: BasePart, color: Color3, s: number, n: number)
	emitNow(emitter(a, {
		Texture = tex("Glow"), Color = ColorSequence.new(Color3.new(1, 1, 0.9), color), Brightness = 2.5,
		Size = ns({ { 0, 0.25 * s }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.8, 1.8), Speed = NumberRange.new(8 * s, 22 * s), Drag = 1.5,
		Acceleration = Vector3.new(0, 6, 0), SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top,
	}), n)
end

-- flat ring lying on the ground, growing outwards
local function ringLayer(pos: Vector3, radius: number, color: Color3, t: number)
	local a = anchor(CFrame.new(pos), t + 0.5)
	emitNow(emitter(a, {
		Texture = tex("Ring"), Color = hot(color), Brightness = 3,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(0, 0), Speed = NumberRange.new(0.01),
		Size = ns({ { 0, radius * 0.15 }, { 0.4, radius * 0.85 }, { 1, radius } }),
		Transparency = ns({ { 0, 0 }, { 0.5, 0.25 }, { 1, 1 } }),
		Lifetime = NumberRange.new(t), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
	}), 1)
	-- a second, softer dust ring
	emitNow(emitter(a, {
		Texture = tex("Smoke"), Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4)), LightEmission = 0.2,
		Size = ns({ { 0, 1.2 }, { 1, 3.2 } }), Transparency = ns({ { 0, 0.5 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(radius * 1.2, radius * 1.6), Drag = 4,
		SpreadAngle = Vector2.new(0, 180), EmissionDirection = Enum.NormalId.Front,
	}), math.clamp(radius * 1.5, 8, 30))
end

------------------------------------------------------------------------
-- presets
------------------------------------------------------------------------
function FxKit.Flare(pos: Vector3, color: Color3, s: number?)
	local sc = s or 1
	local a = anchor(CFrame.new(pos), 1.5)
	core(a, color, sc * 0.7)
	flare(a, color, sc)
	light(a, color, 14 * sc, 5, 0.4)
end

function FxKit.Impact(pos: Vector3, color: Color3, s: number?)
	local sc = s or 1
	local a = anchor(CFrame.new(pos), 1.5)
	flare(a, color, sc * 0.6)
	core(a, color, sc * 0.4)
	streaks(a, color, sc * 0.7, 8 * sc, 45)
	light(a, color, 10 * sc, 3, 0.25)
end

function FxKit.Burst(pos: Vector3, color: Color3, s: number?)
	local sc = s or 1
	local a = anchor(CFrame.new(pos), 2.5)
	core(a, color, sc)
	flare(a, color, sc)
	streaks(a, color, sc, 18 * sc)
	glitter(a, color, sc, 14 * sc)
	ringLayer(pos, 6 * sc, color, 0.45)
	light(a, color, 18 * sc, 6, 0.5)
end

function FxKit.Explosion(pos: Vector3, color: Color3, s: number?)
	local sc = s or 1
	local a = anchor(CFrame.new(pos), 3.5)
	spikes(a, color, sc)
	core(a, color, sc * 1.2)
	flare(a, color, sc * 1.3)
	streaks(a, color, sc, 28 * sc, 75)
	glitter(a, color, sc, 10 * sc)
	embers(a, color, sc, 16 * sc)
	smoke(a, color, sc, 6 + 3 * sc)
	ringLayer(pos, 9 * sc, color, 0.55)
	light(a, color, 26 * sc, 9, 0.8)
end

function FxKit.Shockwave(pos: Vector3, radius: number, color: Color3, t: number?)
	ringLayer(pos, radius, color, t or 0.55)
end

-- energy gathering inward for `t` seconds (then call Burst/Explosion)
function FxKit.Charge(pos: Vector3, color: Color3, s: number?, t: number?)
	local sc, tt = s or 1, t or 0.8
	local a = anchor(CFrame.new(pos), tt + 1.5, Vector3.one * 8 * sc)
	local inward = emitter(a, {
		Texture = tex("Streak"), Color = hot(color), Brightness = 3, Rate = 40 * sc,
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns({ { 0, 2 }, { 1, 2 } }),
		Size = ns({ { 0, 0.2 * sc }, { 0.5, 0.45 * sc }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.25, 0.35), Speed = NumberRange.new(14 * sc, 18 * sc),
	})
	local orb = emitter(a, {
		Texture = tex("Glow"), Color = hot(color), Brightness = 2.5, Rate = 14, ZOffset = 1,
		Size = ns({ { 0, 0 }, { 0.5, 3 * sc }, { 1, 0 } }), Transparency = ns({ { 0, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.3), Speed = NumberRange.new(0),
	})
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, 12 * sc, 0, false
	l.Parent = a
	TweenService:Create(l, TweenInfo.new(tt), { Brightness = 5 }):Play()
	task.delay(tt, function()
		inward.Enabled = false
		orb.Enabled = false
		l:Destroy()
	end)
end

-- fire / energy vortex (image 2 style): spinning arcs + rising flames
function FxKit.Tornado(pos: Vector3, color: Color3, s: number?, t: number?)
	local sc, tt = s or 1, t or 1.6
	local base = anchor(CFrame.new(pos), tt + 1.5, Vector3.new(6 * sc, 0.2, 6 * sc))
	local spinner = anchor(CFrame.new(pos), tt + 1.5)
	local beams = {}
	local layers = 6
	for i = 1, layers do
		local h = (i - 1) / (layers - 1)
		local r = (1.6 + h * 4.2) * sc
		local y = h * 11 * sc
		for side = 0, 1 do
			local a0 = Instance.new("Attachment")
			local a1 = Instance.new("Attachment")
			local sgn = side == 0 and 1 or -1
			-- half circle from +X to -X bulging toward +/-Z (beam curve handles)
			a0.CFrame = CFrame.fromMatrix(Vector3.new(r * sgn, y, 0), Vector3.new(0, 0, sgn), Vector3.yAxis)
			a1.CFrame = CFrame.fromMatrix(Vector3.new(-r * sgn, y + 0.8 * sc, 0), Vector3.new(0, 0, sgn), Vector3.yAxis)
			a0.Parent, a1.Parent = spinner, spinner
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = a0, a1
			b.CurveSize0, b.CurveSize1 = r * 1.33, -r * 1.33
			b.Width0, b.Width1 = (0.4 + h * 1.4) * sc, (0.1 + h * 0.5) * sc
			b.Segments = 24
			b.FaceCamera = true
			b.LightEmission, b.LightInfluence = 1, 0
			set(b, "Brightness", 3)
			b.Texture = tex("Swirl") ~= BUILTIN.Swirl and tex("Swirl") or tex("BeamSoft")
			b.TextureSpeed = 2.5
			b.TextureMode = Enum.TextureMode.Stretch
			b.Color = ColorSequence.new(Color3.new(1, 1, 0.92), color)
			b.Transparency = ns({ { 0, 1 }, { 0.15, 0.15 }, { 0.75, 0.25 }, { 1, 1 } })
			b.Parent = spinner
			table.insert(beams, b)
		end
	end
	-- flames licking upward from a disc at the base
	local flames = emitter(base, {
		Texture = tex("Flame"), Color = hot(color, true), Brightness = 2.5, Rate = 55 * sc,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12),
		Size = ns({ { 0, 1.2 * sc }, { 0.4, 2.4 * sc }, { 1, 0.2 * sc } }),
		Transparency = ns({ { 0, 0.3 }, { 0.6, 0.4 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(10 * sc, 18 * sc), Rotation = NumberRange.new(-10, 10),
	})
	local sparks = emitter(base, {
		Texture = tex("Streak"), Color = hot(color), Brightness = 3, Rate = 30 * sc,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns({ { 0, 2 }, { 1, 1 } }),
		Shape = Enum.ParticleEmitterShape.Disc, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25),
		Size = ns({ { 0, 0.3 * sc }, { 1, 0 } }), Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(14 * sc, 26 * sc),
	})
	ringLayer(pos, 7 * sc, color, 0.6)
	light(base, color, 22 * sc, 5, tt + 0.5)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local e = os.clock() - t0
		if not spinner.Parent or e > tt + 0.6 then
			conn:Disconnect()
			return
		end
		spinner.CFrame = CFrame.new(pos) * CFrame.Angles(0, e * 9, 0)
		if e > tt then
			local f = (e - tt) / 0.6
			for _, b in beams do
				b.Transparency = ns({ { 0, 1 }, { 0.5, 0.2 + 0.8 * f }, { 1, 1 } })
			end
		end
	end)
	task.delay(tt, function()
		flames.Enabled = false
		sparks.Enabled = false
	end)
end

-- crackling bolt from a to b
function FxKit.Lightning(a: Vector3, b: Vector3, color: Color3, w: number?)
	local width = w or 0.35
	local dist = (b - a).Magnitude
	local n = math.clamp(math.floor(dist / 3), 3, 18)
	local dir = (b - a).Unit
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then
		side = dir:Cross(Vector3.xAxis)
	end
	side = side.Unit
	local up = side:Cross(dir).Unit
	local prev = a
	for i = 1, n do
		local f = i / n
		local nextP = i == n and b or a + (b - a) * f + side * (math.random() - 0.5) * dist * 0.12 + up * (math.random() - 0.5) * dist * 0.12
		local seg = Instance.new("Part")
		seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
		seg.Material = Enum.Material.Neon
		seg.Color = Color3.new(1, 1, 1):Lerp(color, 0.35)
		seg.Size = Vector3.new(width, width, (nextP - prev).Magnitude + width)
		seg.CFrame = CFrame.lookAt((prev + nextP) / 2, nextP)
		seg.Parent = holder()
		TweenService:Create(seg, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(0.05, 0.05, seg.Size.Z) }):Play()
		Debris:AddItem(seg, 0.3)
		prev = nextP
	end
	FxKit.Impact(b, color, 0.8)
end

function FxKit.Pillar(pos: Vector3, color: Color3, h: number?, t: number?)
	local height, tt = h or 30, t or 1
	local a = anchor(CFrame.new(pos), tt + 1.5, Vector3.new(3, 0.2, 3))
	emitNow(emitter(a, {
		Texture = tex("Glow"), Color = hot(color), Brightness = 2.5,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns({ { 0, 3 }, { 1, 3 } }),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(0, 0),
		Size = ns({ { 0, 3 }, { 0.3, 5 }, { 1, 0 } }), Transparency = ns({ { 0, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(tt * 0.6, tt), Speed = NumberRange.new(height / tt * 0.7, height / tt),
	}), 10)
	local rise = emitter(a, {
		Texture = tex("Streak"), Color = hot(color), Brightness = 3, Rate = 60,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns({ { 0, 2.5 }, { 1, 2.5 } }),
		Shape = Enum.ParticleEmitterShape.Disc, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(4, 4),
		Size = ns({ { 0, 0.4 }, { 1, 0 } }), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(height * 0.8, height * 1.2),
	})
	ringLayer(pos, 6, color, 0.5)
	light(a, color, 20, 5, tt)
	task.delay(tt * 0.7, function()
		rise.Enabled = false
	end)
end

-- curved slash arc (cf looks where the slash goes)
function FxKit.Slash(cf: CFrame, color: Color3, s: number?)
	local sc = s or 1
	local a = anchor(cf, 0.8)
	local r = 3.2 * sc
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.CFrame = CFrame.fromMatrix(Vector3.new(-r, 0.4 * sc, -1), Vector3.new(0, 0, -1), Vector3.yAxis)
	a1.CFrame = CFrame.fromMatrix(Vector3.new(r, -0.4 * sc, -1), Vector3.new(0, 0, -1), Vector3.yAxis)
	a0.Parent, a1.Parent = a, a
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.CurveSize0, b.CurveSize1 = r * 1.2, -r * 1.2
	b.Width0, b.Width1 = 0.2 * sc, 1.6 * sc
	b.Segments = 20
	b.FaceCamera = true
	b.LightEmission, b.LightInfluence = 1, 0
	set(b, "Brightness", 3)
	b.Texture = tex("BeamSoft")
	b.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	b.Transparency = ns({ { 0, 1 }, { 0.3, 0.2 }, { 1, 0 } })
	b.Parent = a
	TweenService:Create(b, TweenInfo.new(0.35), { Width1 = 0 }):Play()
	task.delay(0.15, function()
		b.Transparency = ns({ { 0, 1 }, { 0.6, 0.5 }, { 1, 0.4 } })
	end)
	streaks(a, color, sc * 0.6, 6, 30)
end

-- glowing trail + sparkle wake on a moving part (projectiles)
function FxKit.Trail(part: BasePart, color: Color3, width: number?)
	local w = width or math.max(part.Size.X, part.Size.Y)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, w / 2, 0), Vector3.new(0, -w / 2, 0)
	a0.Parent, a1.Parent = part, part
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.3
	tr.LightEmission, tr.LightInfluence = 1, 0
	set(tr, "Brightness", 3)
	tr.FaceCamera = true
	tr.Texture = tex("BeamSoft")
	tr.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	tr.Transparency = ns({ { 0, 0.1 }, { 1, 1 } })
	tr.WidthScale = ns({ { 0, 1 }, { 1, 0 } })
	tr.Parent = part
	emitter(part, {
		Texture = tex("Glow"), Color = hot(color), Brightness = 2.5, Rate = 30, LockedToPart = false,
		Size = ns({ { 0, w * 0.9 }, { 1, 0 } }), Transparency = ns({ { 0, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(0, 2),
	})
	emitter(part, {
		Texture = tex("Glow"), Color = hot(color), Brightness = 3, Rate = 4, LockedToPart = true, ZOffset = 1,
		Size = ns({ { 0, w * 2.2 }, { 1, w * 2.2 } }), Transparency = ns({ { 0, 0.4 }, { 1, 0.4 } }),
		Lifetime = NumberRange.new(0.3), Speed = NumberRange.new(0),
	})
end

-- lasting aura around a part; returns a cleanup function
function FxKit.Aura(part: BasePart, color: Color3, s: number?): () -> ()
	local sc = s or 1
	local list = {
		emitter(part, {
			Texture = tex("Glow"), Color = hot(color), Brightness = 1.5, Rate = 6, LockedToPart = true,
			Size = ns({ { 0, 3 * sc }, { 0.5, 4 * sc }, { 1, 3 * sc } }), Transparency = ns({ { 0, 1 }, { 0.5, 0.65 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.8), Speed = NumberRange.new(0),
		}),
		emitter(part, {
			Texture = tex("Streak"), Color = hot(color), Brightness = 2, Rate = 10 * sc,
			Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns({ { 0, 2 }, { 1, 2 } }),
			Shape = Enum.ParticleEmitterShape.Cylinder, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(5, 5),
			Size = ns({ { 0, 0.25 * sc }, { 1, 0 } }), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(4, 8),
		}),
	}
	return function()
		for _, e in list do
			e:Destroy()
		end
	end
end

-- element colours (names from Sfx.ElementOf)
FxKit.ElementColor = {
	Crystal = Color3.fromRGB(150, 200, 255), Ice = Color3.fromRGB(170, 235, 255), Electric = Color3.fromRGB(140, 170, 255),
	Fire = Color3.fromRGB(255, 120, 40), Spore = Color3.fromRGB(230, 120, 255), Water = Color3.fromRGB(70, 170, 255),
	Wind = Color3.fromRGB(200, 255, 230), Earth = Color3.fromRGB(255, 190, 90), Slash = Color3.fromRGB(255, 80, 80),
}

return FxKit
