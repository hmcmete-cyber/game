-- v2.24 VFX building blocks for the signature hits (client side).
-- Bold, daylight-readable shapes: solid NEON geometry (3D rings, domes,
-- crystals, fissures, pillars, snowflakes, runes, tentacles...) carries the
-- shape; particles add sparkle on top. Everything animates and fades itself.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FxKit = require(script.Parent:WaitForChild("FxKit"))
local L = FxKit.Lib
local tex, ns, emitter, emitNow, anchor = L.Tex, L.NS, L.Emitter, L.EmitNow, L.Anchor

local X = {}
local WHITE = Color3.new(1, 1, 1)
local NEON = Enum.Material.Neon
X.WHITE = WHITE

function X.Part(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, alpha: number?, life: number?, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or NEON
	p.Transparency = alpha or 0
	if shape then
		p.Shape = shape
	end
	p.Parent = L.Holder()
	Debris:AddItem(p, life or 3)
	return p
end
local Part = X.Part

function X.Tween(o: Instance, t: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local Tween = X.Tween

-- run step(f) every frame, f = 0..1 over t seconds
function X.Run(t: number, step: (number) -> ())
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local f = math.min(1, (os.clock() - t0) / t)
		local ok = pcall(step, f)
		if f >= 1 or not ok then
			conn:Disconnect()
		end
	end)
end
local Run = X.Run

local function eOut(f: number): number
	return 1 - (1 - f) ^ 3
end
X.EaseOut = eOut

function X.Horizontal(d: Vector3?): Vector3
	if d then
		local h = Vector3.new(d.X, 0, d.Z)
		if h.Magnitude > 0.05 then
			return h.Unit
		end
	end
	local a = math.random() * math.pi * 2
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

------------------------------------------------------------------------
-- solid shapes
------------------------------------------------------------------------
-- 3D ring of neon segments expanding in the plane of cf (cf.UpVector = ring axis)
function X.Ring(cf: CFrame, r0: number, r1: number, thick: number, height: number, color: Color3, t: number, o)
	o = o or {}
	local n = o.Segs or 28
	local a0 = o.Alpha or 0
	local spin = o.Spin or 0
	local parts = {}
	for i = 1, n do
		parts[i] = Part(Vector3.one * 0.1, cf, (o.Color2 and i % 2 == 0) and o.Color2 or color, o.Mat, a0, t + 0.2)
	end
	Run(t, function(f)
		local e = eOut(f)
		local r = r0 + (r1 - r0) * e
		local th = math.max(0.05, thick * (1 - f * 0.85))
		local seg = 2 * math.pi * r / n * 1.1
		for i, p in parts do
			local a = i / n * math.pi * 2 + spin * f
			p.Size = Vector3.new(th, math.max(0.05, height * (1 - f * (o.Keep and 0.1 or 0.6))), math.max(0.05, seg))
			p.CFrame = cf * CFrame.Angles(0, a, 0) * CFrame.new(r, 0, 0)
			p.Transparency = a0 + (1 - a0) * f ^ (o.Hold or 1.6)
		end
		if f >= 1 then
			for _, p in parts do
				p:Destroy()
			end
		end
	end)
end

-- expanding sphere (Neon flash ball or ForceField shimmer dome)
function X.Dome(pos: Vector3, r0: number, r1: number, color: Color3, t: number, mat: Enum.Material?, a0: number?, a1: number?)
	local p = Part(Vector3.one * r0 * 2, CFrame.new(pos), color, mat or NEON, a0 or 0, t + 0.1, Enum.PartType.Ball)
	Tween(p, t, { Size = Vector3.one * r1 * 2, Transparency = a1 or 1 })
	return p
end

-- bright solid flash ball + star flares (the "pop")
function X.Flash(pos: Vector3, color: Color3, s: number, flares: number?)
	X.Dome(pos, 0.6 * s, 4.5 * s, WHITE, 0.22, NEON, 0, 1)
	X.Dome(pos, 1 * s, 6.5 * s, color, 0.35, NEON, 0.15, 1)
	local a = anchor(CFrame.new(pos), 2)
	for k = 1, flares or 2 do
		emitNow(emitter(a, {
			Texture = tex("Flare"), Color = ColorSequence.new(WHITE, color), Brightness = 7, ZOffset = 5, LightEmission = 1,
			Size = ns({ { 0, 5 * s }, { 0.12, (26 - k * 7) * s }, { 1, 2 * s } }), Transparency = ns({ { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.5), Speed = NumberRange.new(0),
			Rotation = NumberRange.new((k - 1) * 45 - 4, (k - 1) * 45 + 4), RotSpeed = NumberRange.new(-30, 30),
		}), 1)
	end
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, math.min(60, 30 * s), 14, false
	l.Parent = a
	Tween(l, 0.8, { Brightness = 0 })
end

-- tapered 3D light spikes (the showcase look); dist(i) -> unit dir
function X.Spikes(pos: Vector3, n: number, len: number, width: number, cBase: Color3, cTip: Color3, dist: (number) -> Vector3, o)
	o = o or {}
	local a = anchor(CFrame.new(pos), 2.5)
	for i = 1, n do
		L.Spike(a, dist(i), len * (0.55 + math.random() * 0.75), width * (0.5 + math.random() * 0.8), cBase, cTip,
			o.Glow or 0.55, o.Grow or 0.08, (o.Hold or 0.1) + math.random() * 0.1, o.Fade or 0.55)
	end
end
function X.Sphere(up: number?, bias: Vector3?): (number) -> Vector3
	return function()
		local d = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1 + (up or 0), math.random() * 2 - 1)
		if bias then
			d += bias * 1.7
		end
		return d.Magnitude > 0.05 and d.Unit or Vector3.yAxis
	end
end
function X.Fan(dir: Vector3, n: number, spread: number, lift: number?): (number) -> Vector3
	local side = dir:Cross(Vector3.yAxis)
	side = side.Magnitude > 0.05 and side.Unit or Vector3.xAxis
	return function(i)
		local f = n > 1 and (i - 1) / (n - 1) - 0.5 or 0
		return (dir + side * f * spread * 2 + Vector3.new(0, (lift or 0.15) + (math.random() - 0.5) * 0.2, 0)).Unit
	end
end
function X.Flat(): (number) -> Vector3
	return function()
		local a = math.random() * math.pi * 2
		return Vector3.new(math.cos(a), math.random() * 0.25, math.sin(a)).Unit
	end
end

-- solid crystal prisms shooting from `from` along dirs
function X.Crystals(from: Vector3, n: number, len: number, w: number, color: Color3, core: Color3, mat: Enum.Material, dist: (number) -> Vector3, o)
	o = o or {}
	for i = 1, n do
		local d = dist(i)
		local L2 = len * (0.6 + math.random() * 0.7)
		local ww = w * (0.6 + math.random() * 0.6)
		local base = CFrame.lookAt(from, from + d) * CFrame.Angles(0, 0, math.rad(45))
		local p = Part(Vector3.new(ww, ww, 0.1), base, (i % 3 == 0 and o.Color2) or color, mat, mat == Enum.Material.Glass and 0.1 or 0, 3)
		local c = Part(Vector3.new(ww * 0.4, ww * 0.4, 0.1), base, core, NEON, 0, 3)
		local hold = (o.Hold or 0.35) + math.random() * 0.25
		Run(o.Grow or 0.12, function(f)
			local e = eOut(f) * L2
			p.Size = Vector3.new(ww, ww, math.max(0.1, e))
			p.CFrame = base * CFrame.new(0, 0, -e / 2 - (o.Offset or 0.3))
			c.Size = Vector3.new(ww * 0.4, ww * 0.4, math.max(0.1, e * 0.92))
			c.CFrame = p.CFrame
		end)
		task.delay((o.Grow or 0.12) + hold, function()
			Tween(p, 0.5, { Transparency = 1, Size = Vector3.new(0.05, 0.05, L2 * 1.1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Tween(c, 0.35, { Transparency = 1 })
		end)
	end
end

-- glowing cracks running out over the ground
function X.Fissures(g: Vector3, n: number, len: number, color: Color3, s: number, t: number?)
	for i = 1, n do
		local ang = i / n * math.pi * 2 + math.random() * 0.5
		local pos = g + Vector3.new(0, 0.12, 0)
		local segs = 3
		for k = 1, segs do
			ang += (math.random() - 0.5) * 0.9
			local seg = len / segs * (0.7 + math.random() * 0.6)
			local d = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local mid = pos + d * seg / 2
			local cf = CFrame.lookAt(mid, mid + d)
			local w = (0.7 - k * 0.15) * s
			local p = Part(Vector3.new(w, 0.2, 0.1), cf, color, NEON, 0, (t or 1.4) + 0.6)
			local glow = Part(Vector3.new(w * 2.4, 0.1, 0.1), cf, color, NEON, 0.6, (t or 1.4) + 0.6)
			task.delay(k * 0.05, function()
				Tween(p, 0.12, { Size = Vector3.new(w, 0.2, seg) })
				Tween(glow, 0.12, { Size = Vector3.new(w * 2.4, 0.1, seg) })
				task.delay(t or 1.4, function()
					Tween(p, 0.6, { Transparency = 1 })
					Tween(glow, 0.4, { Transparency = 1 })
				end)
			end)
			pos += d * seg
		end
	end
end

-- vertical light column
function X.Column(g: Vector3, h: number, w: number, color: Color3, t: number)
	local cf = CFrame.new(g + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local outer = Part(Vector3.new(h, 0.2, 0.2), cf, color, NEON, 0.15, t + 0.2, Enum.PartType.Cylinder)
	local inner = Part(Vector3.new(h, 0.1, 0.1), cf, WHITE, NEON, 0, t + 0.2, Enum.PartType.Cylinder)
	Tween(outer, 0.12, { Size = Vector3.new(h, w, w) })
	Tween(inner, 0.12, { Size = Vector3.new(h, w * 0.45, w * 0.45) })
	task.delay(0.12, function()
		Tween(outer, t, { Size = Vector3.new(h, 0.1, 0.1), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Tween(inner, t * 0.8, { Size = Vector3.new(h, 0.05, 0.05), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
end

-- motes spiralling upward (n strands)
function X.Helix(g: Vector3, h: number, r: number, color: Color3, strands: number, per: number, t: number, s: number)
	local motes = {}
	for i = 1, strands * per do
		motes[i] = Part(Vector3.one * 0.9 * s, CFrame.new(g), (i % 2 == 0) and WHITE or color, NEON, 0, t + 0.2, Enum.PartType.Ball)
	end
	Run(t, function(f)
		for i, m in motes do
			local strand = i % strands
			local k = math.floor((i - 1) / strands) / per
			local ff = math.clamp(f * 1.4 - k * 0.4, 0, 1)
			local ang = strand / strands * math.pi * 2 + ff * math.pi * 4
			local rr = r * (1 - ff * 0.5)
			m.CFrame = CFrame.new(g + Vector3.new(math.cos(ang) * rr, ff * h, math.sin(ang) * rr))
			m.Transparency = ff > 0.8 and (ff - 0.8) / 0.2 or 0
		end
		if f >= 1 then
			for _, m in motes do
				m:Destroy()
			end
		end
	end)
end

-- glowing balls falling from the sky with trails, each bursting on landing
function X.Meteors(g: Vector3, n: number, color: Color3, s: number, onLand: ((Vector3) -> ())?)
	for i = 1, n do
		task.delay((i - 1) * 0.08, function()
			local land = g + Vector3.new((math.random() - 0.5) * 14 * s, 0, (math.random() - 0.5) * 14 * s)
			local from = land + Vector3.new((math.random() - 0.5) * 30, 55, (math.random() - 0.5) * 30)
			local m = Part(Vector3.one * 1.6 * s, CFrame.new(from), color, NEON, 0, 1.2, Enum.PartType.Ball)
			FxKit.Trail(m, color, 1.6 * s)
			Run(0.32, function(f)
				m.CFrame = CFrame.new(from:Lerp(land, f))
				if f >= 1 then
					m:Destroy()
					X.Dome(land, 0.5 * s, 3 * s, color, 0.3)
					X.Ring(CFrame.new(land + Vector3.new(0, 0.2, 0)), 0.5 * s, 5 * s, 0.6 * s, 0.4 * s, color, 0.4)
					if onLand then
						onLand(land)
					end
				end
			end)
		end)
	end
end

-- 6-armed snowflake that spins and grows, flat-ish facing up and tilted
function X.Snowflake(pos: Vector3, color: Color3, size: number, t: number)
	local parts = {}
	for arm = 0, 5 do
		local a = arm / 6 * math.pi * 2
		table.insert(parts, { Part(Vector3.new(0.5, 0.3, 1), CFrame.new(pos), color, NEON, 0, t + 0.2), a, 0, 1, 0 })
		for b = 1, 2 do
			for side = -1, 1, 2 do
				table.insert(parts, { Part(Vector3.new(0.3, 0.25, 0.4), CFrame.new(pos), WHITE, NEON, 0, t + 0.2), a, b * 0.3, 0.32, side })
			end
		end
	end
	local tilt = CFrame.Angles(math.rad(70), 0, 0)
	Run(t, function(f)
		local sz = size * eOut(math.min(1, f * 2.2))
		local spin = f * 2
		for _, e in parts do
			local p, a, along, len, side = e[1], e[2], e[3], e[4], e[5]
			local base = CFrame.new(pos) * tilt * CFrame.Angles(0, a + spin, 0)
			if side == 0 then
				p.Size = Vector3.new(0.5 * sz / 6, 0.3, sz)
				p.CFrame = base * CFrame.new(0, 0, -sz / 2)
			else
				p.Size = Vector3.new(0.3 * sz / 6, 0.25, sz * len)
				p.CFrame = base * CFrame.new(0, 0, -sz * (0.35 + along)) * CFrame.Angles(0, side * math.rad(50), 0) * CFrame.new(0, 0, -sz * len / 2)
			end
			p.Transparency = f > 0.6 and (f - 0.6) / 0.4 or 0
		end
		if f >= 1 then
			for _, e in parts do
				e[1]:Destroy()
			end
		end
	end)
end

-- magic rune circle on the ground: ring + star lines, rotating
function X.Rune(g: Vector3, r: number, color: Color3, points: number, t: number)
	local cf0 = CFrame.new(g + Vector3.new(0, 0.15, 0))
	X.Ring(cf0, r, r, 0.4, 0.15, color, t, { Segs = 36, Spin = 1.5, Alpha = 0.05, Keep = true, Hold = 3 })
	X.Ring(cf0, r * 0.72, r * 0.72, 0.25, 0.12, WHITE, t, { Segs = 30, Spin = -2, Alpha = 0.1, Keep = true, Hold = 3 })
	local lines = {}
	for i = 0, points - 1 do
		lines[i + 1] = Part(Vector3.new(0.3, 0.12, 0.1), cf0, color, NEON, 0, t + 0.2)
	end
	local step = math.floor(points / 2)
	Run(t, function(f)
		local rot = f * 1.5
		for i, p in lines do
			local a1 = (i - 1) / points * math.pi * 2 + rot
			local a2 = ((i - 1 + step) % points) / points * math.pi * 2 + rot
			local p1 = g + Vector3.new(math.cos(a1) * r * 0.7, 0.16, math.sin(a1) * r * 0.7)
			local p2 = g + Vector3.new(math.cos(a2) * r * 0.7, 0.16, math.sin(a2) * r * 0.7)
			local grow = eOut(math.min(1, f * 4))
			local e = p1:Lerp(p2, grow)
			p.Size = Vector3.new(0.3, 0.12, math.max(0.1, (e - p1).Magnitude))
			p.CFrame = CFrame.lookAt((p1 + e) / 2, e)
			p.Transparency = f > 0.7 and (f - 0.7) / 0.3 or 0
		end
		if f >= 1 then
			for _, p in lines do
				p:Destroy()
			end
		end
	end)
end

-- curved camera-facing arc (crescent) in plane (u, v) spinning around n
function X.Arc(c: Vector3, n: Vector3, u: Vector3, R: number, width: number, color: Color3, t: number, spin: number, o)
	o = o or {}
	local a = anchor(CFrame.new(c), t + 0.3)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = a, a
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Segments = 24
	b.FaceCamera = true
	b.LightEmission, b.LightInfluence = o.Glow or 0.6, 0
	L.Set(b, "Brightness", 4)
	b.Texture = tex("BeamSoft")
	b.Color = ColorSequence.new(o.Tip or color, color)
	b.Width0, b.Width1 = 0.15, width
	b.Parent = a
	n = n.Unit
	u = u - n * u:Dot(n)
	u = u.Magnitude > 0.01 and u.Unit or n:Cross(Vector3.xAxis).Magnitude > 0.01 and n:Cross(Vector3.xAxis).Unit or Vector3.zAxis
	local v = n:Cross(u).Unit
	local sweep = o.Sweep or (math.pi / 2)
	local k = 4 / 3 * math.tan(sweep / 4)
	Run(t, function(f)
		local rr = R * ((o.R0 or 0.3) + (1 - (o.R0 or 0.3)) * eOut(f))
		local ang = spin * f
		local uu = u * math.cos(ang) + v * math.sin(ang)
		local vv = n:Cross(uu)
		local e1 = uu * math.cos(sweep) + vv * math.sin(sweep)
		local t1 = n:Cross(e1)
		a0.CFrame = CFrame.fromMatrix(uu * rr, vv, n)
		a1.CFrame = CFrame.fromMatrix(e1 * rr, t1, n)
		b.CurveSize0, b.CurveSize1 = rr * k, rr * k
		b.Transparency = ns({ { 0, 1 }, { 0.25, 0.1 + f * 0.85 }, { 1, f ^ 1.5 } })
		if f >= 1 then
			b:Destroy()
		end
	end)
end

-- rocks thrown out with gravity
function X.Rocks(c: Vector3, n: number, size: number, color: Color3, mat: Enum.Material, speed: number, dist: (number) -> Vector3)
	for i = 1, n do
		local d = dist(i)
		local w = size * (0.5 + math.random() * 0.8)
		local p = Part(Vector3.new(w, w * (0.6 + math.random() * 0.5), w * (0.7 + math.random() * 0.5)), CFrame.new(c), color, mat, 0, 1.8)
		local vel = d * speed * (0.6 + math.random() * 0.6) + Vector3.new(0, 12, 0)
		local rot = Vector3.new(math.random() * 10 - 5, math.random() * 10 - 5, math.random() * 10 - 5)
		Run(1.3, function(f)
			local t = f * 1.3
			p.CFrame = CFrame.new(c + vel * t + Vector3.new(0, -50 * t * t, 0)) * CFrame.Angles(rot.X * t, rot.Y * t, rot.Z * t)
			p.Transparency = f > 0.75 and (f - 0.75) / 0.25 or 0
		end)
	end
end

-- pillars erupting from the ground in a ring (tilted outwards)
function X.Pillars(g: Vector3, n: number, r: number, h: number, w: number, color: Color3, mat: Enum.Material, hold: number?)
	for k = 1, n do
		local ang = k / n * math.pi * 2 + math.random() * 0.3
		local dist = r * (0.7 + math.random() * 0.6)
		local at = g + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		local hh = h * (0.7 + math.random() * 0.6)
		local ww = w * (0.7 + math.random() * 0.5)
		local tilt = CFrame.Angles(math.sin(ang) * 0.4, 0, -math.cos(ang) * 0.4)
		local p = Part(Vector3.new(ww, hh, ww), CFrame.new(at - Vector3.new(0, hh / 2, 0)) * tilt * CFrame.Angles(0, ang, 0), color, mat, mat == Enum.Material.Glass and 0.1 or 0, 3)
		Tween(p, 0.15, { CFrame = CFrame.new(at + Vector3.new(0, hh * 0.3, 0)) * tilt * CFrame.Angles(0, ang, 0) }, Enum.EasingStyle.Back)
		task.delay(hold or 1, function()
			Tween(p, 0.6, { CFrame = CFrame.new(at - Vector3.new(0, hh * 0.6, 0)) * tilt, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
	end
end

-- curling tentacles (chains of balls) whipping out
function X.Tentacles(c: Vector3, n: number, len: number, w: number, color: Color3, tip: Color3, t: number)
	local all = {}
	for i = 1, n do
		local ang = i / n * math.pi * 2
		local segs = {}
		for k = 1, 8 do
			segs[k] = Part(Vector3.one * w * (1 - k * 0.09), CFrame.new(c), (k > 6) and tip or color, NEON, 0, t + 0.2, Enum.PartType.Ball)
		end
		table.insert(all, { ang, segs, math.random() < 0.5 and -1 or 1 })
	end
	Run(t, function(f)
		local reach = eOut(math.min(1, f * 2.5)) * len
		for _, e in all do
			local ang, segs, curl = e[1], e[2], e[3]
			for k, p in segs do
				local q = k / #segs
				local a = ang + curl * q * q * (1.2 + f * 1.5)
				local up = math.sin(q * math.pi) * len * 0.25
				p.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * reach * q, up, math.sin(a) * reach * q))
				p.Transparency = f > 0.65 and (f - 0.65) / 0.35 or 0
			end
		end
		if f >= 1 then
			for _, e in all do
				for _, p in e[2] do
					p:Destroy()
				end
			end
		end
	end)
end

------------------------------------------------------------------------
-- particle layers
------------------------------------------------------------------------
function X.Sparks(pos: Vector3, color: Color3, s: number, n: number, speed: number, grav: number?)
	local a = anchor(CFrame.new(pos), 2)
	emitNow(emitter(a, {
		Texture = tex("Streak"), Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.3, color:Lerp(WHITE, 0.4)), ColorSequenceKeypoint.new(1, color) }),
		Brightness = 5, LightEmission = 0.8,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns({ { 0, 3 }, { 1, 1.5 } }),
		Size = ns({ { 0, 0.4 * s }, { 0.3, 0.7 * s }, { 1, 0 } }), Transparency = ns({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.35, 0.9), Speed = NumberRange.new(speed * 0.5 * s, speed * s), Drag = 4,
		Acceleration = Vector3.new(0, -(grav or 50), 0), Rotation = NumberRange.new(0),
	}), n)
end
function X.Smoke(pos: Vector3, color: Color3, s: number, n: number, rise: number?, size: number?)
	local a = anchor(CFrame.new(pos), 3)
	emitNow(emitter(a, {
		Texture = tex("Smoke"), Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.5)), LightEmission = 0, LightInfluence = 0.5,
		Size = ns({ { 0, 2.5 * s * (size or 1) }, { 1, 9 * s * (size or 1) } }), Transparency = ns({ { 0, 0.15 }, { 0.5, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(4 * s, 14 * s), Drag = 1.5,
		Acceleration = Vector3.new(0, rise or 5, 0), RotSpeed = NumberRange.new(-40, 40),
	}), n)
end
function X.Motes(pos: Vector3, color: Color3, s: number, n: number, speed: number, grav: number?, life: number?)
	local a = anchor(CFrame.new(pos), 4)
	emitNow(emitter(a, {
		Texture = tex("Glow"), Color = ColorSequence.new(WHITE, color), Brightness = 4, LightEmission = 0.8,
		Size = ns({ { 0, 0.7 * s }, { 0.5, 0.5 * s }, { 1, 0 } }), Lifetime = NumberRange.new((life or 1.5) * 0.6, life or 1.5),
		Speed = NumberRange.new(speed * 0.3 * s, speed * s), Drag = 2, Acceleration = Vector3.new(0, -(grav or -4), 0),
	}), n)
end
function X.Debris(pos: Vector3, color: Color3, s: number, n: number, texName: string, speed: number, grav: number)
	local a = anchor(CFrame.new(pos), 3)
	emitNow(emitter(a, {
		Texture = tex(texName), Color = ColorSequence.new(color), LightEmission = 0.3, Brightness = 1.5,
		Size = ns({ { 0, 0.9 * s }, { 1, 0.5 * s } }), Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(speed * 0.4 * s, speed * s), Drag = 1.5, Acceleration = Vector3.new(0, -grav, 0),
		RotSpeed = NumberRange.new(-300, 300),
	}), n)
end
function X.Splat(pos: Vector3, color: Color3, deep: Color3, s: number)
	local a = anchor(CFrame.new(pos), 2)
	emitNow(emitter(a, {
		Texture = tex("Spikes"), Color = ColorSequence.new(color, deep), LightEmission = 0.3, Brightness = 2, ZOffset = -1,
		Size = ns({ { 0, 5 * s }, { 0.15, 18 * s }, { 1, 21 * s } }), Transparency = ns({ { 0, 0 }, { 0.45, 0.15 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.55), Speed = NumberRange.new(0), RotSpeed = NumberRange.new(-10, 10),
	}), 2)
end
-- flat decal-like mark on the ground (texture lying flat)
function X.Mark(g: Vector3, texName: string, color: Color3, size: number, life: number, glow: number?)
	local a = anchor(CFrame.new(g + Vector3.new(0, 0.2, 0)), life + 0.5)
	emitNow(emitter(a, {
		Texture = tex(texName), Color = ColorSequence.new(color), LightEmission = glow or 0, LightInfluence = 0.3, Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0), Speed = NumberRange.new(0.01),
		Size = ns({ { 0, size * 0.4 }, { 0.08, size }, { 1, size * 1.05 } }), Transparency = ns({ { 0, 0.05 }, { 0.7, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(life), Rotation = NumberRange.new(0, 360),
	}), 1)
end
function X.Dust(g: Vector3, color: Color3, s: number, n: number)
	local a = anchor(CFrame.new(g + Vector3.new(0, 0.3, 0)), 3, Vector3.new(2, 0.2, 2))
	emitNow(emitter(a, {
		Texture = tex("Smoke"), Color = ColorSequence.new(color), LightEmission = 0, LightInfluence = 0.6,
		Size = ns({ { 0, 2 * s }, { 1, 6 * s } }), Transparency = ns({ { 0, 0.25 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.7, 1.1), Speed = NumberRange.new(28 * s, 44 * s), Drag = 5,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(88, 88),
	}), n)
end
function X.Implode(pos: Vector3, color: Color3, s: number)
	local a = anchor(CFrame.new(pos), 1.5, Vector3.one * 9 * s)
	emitNow(emitter(a, {
		Texture = tex("Streak"), Color = ColorSequence.new(WHITE, color), Brightness = 5, LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns({ { 0, 2.5 }, { 1, 2.5 } }),
		Size = ns({ { 0, 0.5 * s }, { 1, 0.1 } }), Lifetime = NumberRange.new(0.14), Speed = NumberRange.new(32 * s, 44 * s),
	}), 26)
	X.Ring(CFrame.new(pos), 6 * s, 0.5, 0.5 * s, 0.5 * s, color, 0.14, { Segs = 20, Alpha = 0.2 })
end
function X.Shake(pos: Vector3, amount: number)
	local a = anchor(CFrame.new(pos), 1)
	a:SetAttribute("Shake", amount)
end

return X
