-- v2.24 SIGNATURE HIT VFX — every character has its OWN choreography
-- (director: "all looked dim and alike — every one must be unique and grand").
-- Shapes are solid neon geometry (daylight-readable, bloom glows them) built
-- from Shared/FxPrims; particles add sparkle on top.
--
-- HitFx.Play(style, pos, scale?, dir?)   server -> all clients build it
-- HitFx.Build(style, pos, scale?, dir?)  client: build now
-- Styles: monster type names, "PlayerPunch/Slam/Puff", "Pet<Element><Kind>",
-- element fallbacks (Fire, Ice, ...), "Red" (the showcase).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FxKit = require(script.Parent:WaitForChild("FxKit"))
local X = require(script.Parent:WaitForChild("FxPrims"))
local L = FxKit.Lib

local HitFx = {}
local RGB = Color3.fromRGB
local W = X.WHITE
local NEON, GLASS, ICE, FF = Enum.Material.Neon, Enum.Material.Glass, Enum.Material.Ice, Enum.Material.ForceField
local SLATE, SAND, WOOD, BASALT, PLASTIC = Enum.Material.Slate, Enum.Material.Sandstone, Enum.Material.Wood, Enum.Material.Basalt, Enum.Material.SmoothPlastic

local function after(t: number, f)
	task.delay(t, f)
end
-- CFrame whose UpVector points along dir (rings facing a direction)
local function facing(c: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(c, c + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
end
local function groundCF(g: Vector3): CFrame
	return CFrame.new(g + Vector3.new(0, 0.3, 0))
end
local function bolts(from: Vector3, n: number, len: number, color: Color3, w: number, dist)
	for i = 1, n do
		FxKit.Lightning(from, from + dist(i) * len * (0.6 + math.random() * 0.6), color, w, true)
	end
end
local function skyBolts(g: Vector3, n: number, color: Color3, s: number)
	for k = 1, n do
		after((k - 1) * 0.07, function()
			local off = Vector3.new((math.random() - 0.5) * 10 * s, 0, (math.random() - 0.5) * 10 * s)
			FxKit.Lightning(g + off + Vector3.new(0, 55, 0), g + off, W:Lerp(color, 0.3), 0.9 * s, true)
			X.Dome(g + off, 0.5 * s, 3.5 * s, color, 0.3)
		end)
	end
end
-- jaws: two crescents in the vertical plane of `fwd` snapping shut
local function jaws(c: Vector3, fwd: Vector3, R: number, width: number, color: Color3, tip: Color3)
	local side = fwd:Cross(Vector3.yAxis)
	side = side.Magnitude > 0.05 and side.Unit or Vector3.xAxis
	X.Arc(c, side, Vector3.yAxis, R, width, color, 0.45, -1.4, { Sweep = math.pi * 0.8, Tip = tip, R0 = 0.8 })
	X.Arc(c, side, -Vector3.yAxis, R, width, color, 0.45, 1.4, { Sweep = math.pi * 0.8, Tip = tip, R0 = 0.8 })
end
-- ellipsoid (mushroom cap / cloud): Part + Sphere mesh, grows and fades
local function blob(pos: Vector3, size: Vector3, toSize: Vector3, color: Color3, mat: Enum.Material, a0: number, t: number)
	local p = X.Part(Vector3.one, CFrame.new(pos), color, mat, a0, t + 0.2)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Scale = size
	m.Parent = p
	X.Tween(m, t, { Scale = toSize })
	X.Tween(p, t, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	return p
end

-- v2.25 second-sheet layers (shapes + flipbooks; fall back until uploaded)
local function fireball(c: Vector3, col: Color3, deep: Color3, s: number, n: number?)
	X.Tex(c, "ExplosionFlip", col, s, n or 5, { Size = 11, Size1 = 13, Speed = 5, Life = 0.9, Glow = 0.85, Bright = 4, Color2 = deep, Rot = 30 })
	X.Tex(c, "FireFlip", col, s, (n or 5) + 4, { Size = 6, Speed = 14, Life = 0.8, Glow = 0.9, Bright = 4, Grav = -14, Color2 = deep })
end
local function smokeFlip(c: Vector3, col: Color3, s: number, n: number?)
	X.Tex(c, "SmokeFlip", col, s, n or 8, { Size = 8, Size1 = 12, Speed = 8, Life = 1.6, Glow = 0, Grav = -6, Rot = 40, Color2 = col:Lerp(Color3.new(0, 0, 0), 0.5) })
end
local function crackle(c: Vector3, col: Color3, s: number, n: number?)
	X.Tex(c, "ElectricFlip", col, s, n or 8, { Size = 7, Speed = 10, Life = 0.6, Glow = 1, Bright = 5, Loop = true, Rot = 300 })
end

------------------------------------------------------------------------
-- signatures: fn(c = hit centre, g = ground below, s = scale, d = direction?)
------------------------------------------------------------------------
local S = {}
local function def(name: string, fn, boss: boolean?)
	S[name] = { Fn = fn, Boss = boss == true }
end

-- ===== CANYON (crystal) =====
-- Crystal Stalker: refraction lances — a fan of cyan crystal spears and a
-- full rainbow split of light, with a prism ring facing the strike
def("Prismaw", function(c, g, s, d)
	X.Tex(c, "Star", RGB(200, 240, 255), s, 18, { Size = 2.2, Speed = 30, Life = 1.2, Glow = 1, Bright = 4, Rot = 200, Color2 = RGB(220, 160, 255) })
	local fwd = X.Horizontal(d)
	X.Implode(c, RGB(120, 230, 255), s)
	after(0.14, function()
		X.Flash(c, RGB(140, 230, 255), s, 2)
		X.Crystals(c, 7, 13 * s, 1.1 * s, RGB(120, 220, 255), W, GLASS, X.Fan(fwd, 7, 0.55, 0.1), { Color2 = RGB(200, 160, 255) })
		for i, col in { RGB(255, 60, 60), RGB(255, 160, 40), RGB(255, 240, 60), RGB(80, 255, 120), RGB(60, 160, 255), RGB(190, 90, 255) } do
			X.Spikes(c, 3, 16 * s, 0.5 * s, col, col, X.Fan((fwd + Vector3.new(0, (i - 3.5) * 0.08, 0)).Unit, 3, 0.35, 0.05), { Glow = 0.9 })
		end
		X.Ring(facing(c, fwd), 1, 10 * s, 0.9 * s, 0.6 * s, RGB(140, 230, 255), 0.5, { Color2 = RGB(220, 150, 255) })
		X.Sparks(c, RGB(160, 230, 255), s, 50, 90, 20)
		X.Shake(c, s)
	end)
end)
-- Crystal Whirlwind: violet shards orbit in a spinning ring, then the
-- whirl flings them outward while a crystal tornado rises
def("Shardstorm", function(c, g, s, d)
	X.Tex(c, "Star", RGB(210, 170, 255), s, 14, { Size = 1.8, Speed = 26, Life = 1.1, Glow = 1, Bright = 4, Rot = 300 })
	local shards = {}
	for i = 1, 10 do
		shards[i] = X.Part(Vector3.new(0.9 * s, 0.9 * s, 3 * s), CFrame.new(c), i % 2 == 0 and RGB(190, 140, 255) or RGB(240, 220, 255), GLASS, 0.05, 1.5)
	end
	X.Run(0.4, function(f)
		for i, p in shards do
			local a = i / 10 * math.pi * 2 + f * 9
			local pos = c + Vector3.new(math.cos(a) * 5 * s, (f - 0.5) * 3 * s, math.sin(a) * 5 * s)
			p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0.2, math.cos(a)))
		end
		if f >= 1 then
			for i, p in shards do
				local a = i / 10 * math.pi * 2 + 9
				local out = Vector3.new(math.cos(a), 0.15, math.sin(a))
				X.Tween(p, 0.45, { CFrame = p.CFrame + out * 16 * s, Transparency = 1 })
			end
		end
	end)
	FxKit.Tornado(g, RGB(170, 120, 255), 0.9 * s, 1)
	after(0.4, function()
		X.Flash(c, RGB(190, 140, 255), s, 1)
		X.Crystals(c, 10, 9 * s, 0.8 * s, RGB(190, 150, 255), W, GLASS, X.Flat())
		X.Ring(groundCF(g), 2, 13 * s, 1 * s, 0.6 * s, RGB(170, 120, 255), 0.55, { Spin = 3 })
		X.Shake(c, s)
	end)
end)
-- Crystal Scuttler: pink crystal pincers burst from the ground on both
-- sides and clamp shut on the target
def("Geoscuttle", function(c, g, s, d)
	X.Tex(c, "Claw", RGB(255, 140, 220), s, 2, { Size = 9, Speed = 0.1, Life = 0.5, Glow = 1, Bright = 5, Rot = 0 })
	local fwd = X.Horizontal(d)
	local side = fwd:Cross(Vector3.yAxis).Unit
	for sgn = -1, 1, 2 do
		for k = 1, 5 do
			local a = (k / 5) * math.pi * 0.8
			local at = g + side * sgn * math.cos(a) * 6 * s + fwd * (math.sin(a) * 6 - 3) * s
			local h = (3 + k) * s
			local p = X.Part(Vector3.new(1.2 * s, h, 1.2 * s), CFrame.new(at - Vector3.new(0, h / 2, 0)), k % 2 == 0 and RGB(255, 120, 210) or RGB(255, 200, 240), GLASS, 0.05, 2.2)
			local tilt = CFrame.Angles(0, 0, -sgn * 0.5)
			after(k * 0.04, function()
				X.Tween(p, 0.14, { CFrame = CFrame.new(at + Vector3.new(0, h * 0.3, 0)) * CFrame.lookAt(Vector3.zero, fwd).Rotation * tilt }, Enum.EasingStyle.Back)
				after(0.9, function()
					X.Tween(p, 0.5, { Transparency = 1, Size = Vector3.new(0.1, h, 0.1) })
				end)
			end)
		end
	end
	jaws(c, fwd, 6 * s, 1.6 * s, RGB(255, 110, 200), W)
	after(0.25, function()
		X.Flash(c, RGB(255, 130, 220), s, 2)
		X.Spikes(c, 18, 9 * s, 0.6 * s, RGB(255, 150, 230), RGB(150, 40, 160), X.Sphere(0.3))
		X.Sparks(c, RGB(255, 170, 230), s, 40, 70, 40)
		X.Shake(c, s)
	end)
end)

-- ===== MOUNTAINS (ice) =====
-- Glacier Tortoise: a frost dome bursts outward, a ring of great ice spikes
-- erupts and the ground freezes over with cracks
def("Frostback", function(c, g, s, d)
	X.Tex(c + Vector3.new(0, 3 * s, 0), "Snowflake", W, s, 16, { Size = 2.4, Speed = 18, Life = 2, Glow = 0.7, Grav = 4, Rot = 90 })
	X.Flash(c, RGB(170, 230, 255), s, 1)
	X.Dome(c, 2 * s, 13 * s, RGB(150, 220, 255), 0.8, FF, 0.1, 1)
	X.Pillars(g, 9, 7 * s, 8 * s, 2 * s, RGB(170, 225, 255), ICE, 1.1)
	X.Ring(groundCF(g), 1, 15 * s, 1.6 * s, 0.4 * s, W, 0.7, { Color2 = RGB(170, 230, 255) })
	X.Mark(g, "Crackle", RGB(140, 210, 255), 22 * s, 2.5, 0.7)
	X.Motes(c + Vector3.new(0, 6 * s, 0), W, s, 40, 14, 6, 2.2)
	X.Shake(c, s)
end)
-- Snow Owl: a giant spinning snowflake blooms, feathers flutter down and
-- icy wind arcs whirl around it
def("Snowpeck", function(c, g, s, d)
	X.Tex(c, "Feather", W, s, 18, { Size = 2.6, Speed = 22, Life = 2.2, Glow = 0.3, Grav = 3, Rot = 160, Drag = 3 })
	X.Tex(c, "Snowflake", RGB(220, 245, 255), s, 12, { Size = 1.8, Speed = 26, Life = 1.8, Glow = 0.8, Grav = 2, Rot = 120 })
	X.Snowflake(c + Vector3.new(0, 1 * s, 0), RGB(200, 240, 255), 11 * s, 1.2)
	X.Flash(c, RGB(220, 245, 255), 0.8 * s, 2)
	for k = 1, 4 do
		X.Arc(c, Vector3.yAxis, Vector3.new(math.cos(k * 1.6), 0, math.sin(k * 1.6)), 8 * s, 1.4 * s, RGB(220, 245, 255), 0.6, 4, { Tip = W })
	end
	X.Debris(c + Vector3.new(0, 3 * s, 0), W, s * 1.3, 26, "Shard", 22, 6)
	X.Shake(c, 0.7 * s)
end)
-- Watching Rubble: a black void sphere swallows the light, then the eye
-- blinks open — purple shock, rocks blasted out
def("Rubbleye", function(c, g, s, d)
	X.Tex(c, "Rock", RGB(110, 100, 125), s, 14, { Size = 1.6, Speed = 30, Life = 1.4, Glow = 0, Grav = 40, Rot = 300 })
	local void = X.Dome(c, 6 * s, 0.6 * s, RGB(15, 5, 25), 0.35, PLASTIC, 0.05, 0.05)
	X.Implode(c, RGB(170, 90, 255), s)
	X.Ring(facing(c, Vector3.yAxis), 9 * s, 1, 0.7 * s, 0.7 * s, RGB(170, 90, 255), 0.35, { Spin = -4 })
	after(0.35, function()
		void:Destroy()
		X.Flash(c, RGB(180, 90, 255), s * 1.1, 2)
		X.Spikes(c, 26, 12 * s, 1 * s, RGB(150, 70, 255), RGB(20, 0, 40), X.Sphere(0.1), { Glow = 0.4 })
		X.Rocks(c, 10, 1.6 * s, RGB(100, 95, 115), SLATE, 30 * s, X.Sphere(0.4))
		X.Ring(facing(c, Vector3.yAxis), 1, 14 * s, 1 * s, 0.6 * s, RGB(190, 110, 255), 0.5)
		X.Mark(g, "Spikes", RGB(30, 0, 50), 16 * s, 2)
		X.Shake(c, 1.2 * s)
	end)
end)

-- ===== MARSH (storm) =====
-- Storm Wraith: lightning rains from the sky, a crackling violet dome and a
-- web of bolts across the ground
def("Voltwraith", function(c, g, s, d)
	crackle(c, RGB(190, 160, 255), s, 12)
	skyBolts(g, 5, RGB(170, 140, 255), s)
	after(0.2, function()
		X.Flash(c, RGB(170, 140, 255), s, 2)
		X.Dome(c, 2 * s, 10 * s, RGB(160, 120, 255), 0.25, FF, 0, 1)
		after(0.12, function()
			X.Dome(c, 3 * s, 12 * s, RGB(200, 180, 255), 0.3, FF, 0.1, 1)
		end)
		bolts(g + Vector3.new(0, 0.5, 0), 8, 14 * s, RGB(190, 170, 255), 0.45 * s, X.Flat())
		X.Sparks(c, RGB(190, 170, 255), s, 70, 110, 15)
		X.Mark(g, "Crackle", RGB(150, 120, 255), 20 * s, 1.5, 1)
		X.Shake(c, 1.2 * s)
	end)
end)
-- Storm Snapper: giant green jaws snap, thorny vines spike up and green
-- lightning crackles from the bite
def("Gulpvine", function(c, g, s, d)
	crackle(c, RGB(170, 255, 170), s, 8)
	X.Tex(c, "Leaf", RGB(120, 220, 90), s, 16, { Size = 1.8, Speed = 24, Life = 1.8, Glow = 0.2, Grav = 6, Rot = 200, Drag = 3 })
	local fwd = X.Horizontal(d)
	jaws(c, fwd, 7 * s, 2 * s, RGB(120, 255, 120), RGB(230, 255, 150))
	after(0.3, function()
		X.Flash(c, RGB(150, 255, 140), s, 1)
		bolts(c, 6, 12 * s, RGB(170, 255, 170), 0.4 * s, X.Sphere(0.2))
		X.Spikes(g, 20, 8 * s, 0.7 * s, RGB(90, 200, 70), RGB(60, 40, 20), X.Sphere(1.2), { Glow = 0.3 })
		X.Ring(groundCF(g), 1, 10 * s, 0.9 * s, 0.5 * s, RGB(120, 255, 120), 0.5)
		X.Shake(c, s)
	end)
end)
-- Storm Frog: three booming sound-wave rings roll forward, bubbles burst
-- and little bolts jump between them
def("Croakle", function(c, g, s, d)
	X.Tex(c, "Bubble", RGB(170, 235, 255), s, 22, { Size = 1.6, Size1 = 2.4, Speed = 14, Life = 1.8, Glow = 0.5, Grav = -6, Rot = 20 })
	crackle(c, RGB(160, 225, 255), s, 5)
	local fwd = X.Horizontal(d)
	for k = 0, 2 do
		after(k * 0.11, function()
			X.Ring(facing(c + fwd * k * 2 * s, fwd), 1.5 * s, (7 + k * 3) * s, 0.8 * s, 0.6 * s, k == 1 and W or RGB(100, 220, 255), 0.5)
		end)
	end
	X.Flash(c, RGB(120, 220, 255), 0.8 * s, 1)
	X.Motes(c, RGB(160, 235, 255), 1.2 * s, 30, 16, -8, 1.8)
	bolts(c, 4, 9 * s, RGB(170, 230, 255), 0.35 * s, X.Sphere(0.3, fwd))
	X.Shake(c, 0.8 * s)
end)
-- Fanged Glutton: rows of fangs CHOMP shut, then acid sprays and hisses
def("Gnashgut", function(c, g, s, d)
	X.Tex(c, "Claw", RGB(230, 255, 200), s, 2, { Size = 10, Speed = 0.1, Life = 0.45, Glow = 1, Bright = 5, Rot = 0 })
	X.Tex(g + Vector3.new(0, 1, 0), "Bubble", RGB(180, 255, 90), s, 18, { Size = 1.4, Speed = 8, Life = 1.6, Glow = 0.6, Grav = -6, Rot = 10 })
	local fwd = X.Horizontal(d)
	local side = fwd:Cross(Vector3.yAxis).Unit
	for row = -1, 1, 2 do
		for k = -3, 3 do
			local at = c + side * k * 1.2 * s - fwd * 1 * s
			local tooth = X.Part(Vector3.new(0.8 * s, 2.2 * s, 0.8 * s), CFrame.new(at + Vector3.new(0, row * 4 * s, 0)) * CFrame.Angles(0, 0, row > 0 and math.pi or 0), W, NEON, 0, 1.2)
			X.Tween(tooth, 0.16, { CFrame = CFrame.new(at + Vector3.new(0, row * 1.1 * s, 0)) * CFrame.Angles(0, 0, row > 0 and math.pi or 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			after(0.45, function()
				X.Tween(tooth, 0.3, { Transparency = 1 })
			end)
		end
	end
	after(0.17, function()
		X.Flash(c, RGB(170, 255, 90), s, 1)
		X.Splat(c, RGB(160, 255, 60), RGB(40, 90, 10), s)
		X.Spikes(c, 22, 9 * s, 0.8 * s, RGB(190, 255, 80), RGB(60, 120, 20), X.Sphere(0.6), { Glow = 0.5 })
		X.Mark(g, "Spikes", RGB(120, 220, 40), 14 * s, 2.5, 0.6)
		X.Motes(g + Vector3.new(0, 1, 0), RGB(180, 255, 90), s, 30, 10, -6, 1.6)
		X.Shake(c, s)
	end)
end)

-- ===== VOLCANIC (fire) =====
-- Magma Tyrant: the ground splits with glowing magma cracks, a lava column
-- erupts and molten meteors rain down
def("Cindermaw", function(c, g, s, d)
	fireball(c, RGB(255, 130, 40), RGB(140, 20, 0), 1.2 * s, 6)
	smokeFlip(c + Vector3.new(0, 5 * s, 0), RGB(70, 45, 40), s, 8)
	X.Fissures(g, 7, 15 * s, RGB(255, 120, 30), s, 1.6)
	after(0.12, function()
		X.Column(g, 34 * s, 6 * s, RGB(255, 110, 30), 0.9)
		X.Flash(c, RGB(255, 140, 40), 1.2 * s, 2)
		X.Splat(c, RGB(255, 90, 20), RGB(90, 10, 0), s)
		X.Spikes(c, 40, 15 * s, 1.3 * s, RGB(255, 120, 30), RGB(120, 10, 0), X.Sphere(0.5))
		X.Meteors(g, 4, RGB(255, 130, 40), s)
		X.Smoke(c + Vector3.new(0, 4 * s, 0), RGB(70, 40, 35), s, 10, 10)
		X.Motes(c, RGB(255, 160, 60), s, 40, 24, -9, 2)
		X.Shake(c, 1.4 * s)
	end)
end)
-- Ember Blob: the fuse pops — a fat orange fireball dome, then a little
-- mushroom cloud of smoke with embers
def("Smoldlet", function(c, g, s, d)
	fireball(c, RGB(255, 170, 50), RGB(150, 40, 0), s, 5)
	smokeFlip(c + Vector3.new(0, 4 * s, 0), RGB(85, 70, 65), s, 10)
	X.Implode(c, RGB(255, 170, 60), s * 0.8)
	after(0.14, function()
		X.Dome(c, 1 * s, 9 * s, RGB(255, 150, 40), 0.4, NEON, 0, 1)
		X.Dome(c, 0.5 * s, 6 * s, RGB(255, 240, 180), 0.25, NEON, 0, 1)
		X.Ring(groundCF(g), 1, 12 * s, 1.2 * s, 0.5 * s, RGB(255, 150, 40), 0.5)
		blob(c + Vector3.new(0, 6 * s, 0), Vector3.new(4, 2, 4) * s, Vector3.new(14, 6, 14) * s, RGB(90, 70, 65), PLASTIC, 0.2, 1.4)
		X.Smoke(c, RGB(80, 60, 55), s, 12, 22)
		X.Motes(c, RGB(255, 180, 70), s, 36, 26, -10, 1.8)
		X.Shake(c, s)
	end)
end)
-- Lava Salamander: a flaming dash — a chain of fire blasts runs forward
-- along a burning trail and ends in a fire twister
def("Scorchtail", function(c, g, s, d)
	fireball(c, RGB(255, 80, 30), RGB(120, 0, 0), 0.8 * s, 3)
	local fwd = X.Horizontal(d)
	local start = g - fwd * 6 * s
	for k = 0, 5 do
		after(k * 0.06, function()
			local p = start + fwd * k * 2.6 * s
			X.Dome(p + Vector3.new(0, 1.2 * s, 0), 0.6 * s, 3.6 * s, k % 2 == 0 and RGB(255, 70, 30) or RGB(255, 180, 60), 0.3)
			X.Spikes(p + Vector3.new(0, 1 * s, 0), 6, 6 * s, 0.6 * s, RGB(255, 90, 30), RGB(120, 0, 0), X.Sphere(1))
			local trail = X.Part(Vector3.new(1.4 * s, 0.2, 2.8 * s), CFrame.lookAt(p + Vector3.new(0, 0.15, 0), p + Vector3.new(0, 0.15, 0) + fwd), RGB(255, 90, 30), NEON, 0, 2)
			after(0.8, function()
				X.Tween(trail, 0.6, { Transparency = 1 })
			end)
		end)
	end
	after(0.36, function()
		FxKit.Tornado(g + fwd * 9 * s, RGB(255, 80, 30), 0.8 * s, 0.9)
		X.Flash(c + fwd * 8 * s, RGB(255, 90, 30), s, 1)
		X.Shake(c, s)
	end)
end)

-- ===== MUSHROOM (spore) =====
-- Toadstool Strider: a pink mushroom-shaped spore cloud blooms (stem +
-- cap) with polka-dot motes drifting out
def("Capstride", function(c, g, s, d)
	X.Tex(g + Vector3.new(0, 8 * s, 0), "Spore", RGB(255, 160, 200), s, 14, { Size = 3, Size1 = 4, Speed = 12, Life = 2, Glow = 0.4, Grav = -2, Rot = 60 })
	X.Column(g, 9 * s, 3 * s, RGB(255, 220, 230), 0.8)
	blob(g + Vector3.new(0, 9 * s, 0), Vector3.new(4, 1.5, 4) * s, Vector3.new(18, 6, 18) * s, RGB(255, 90, 140), NEON, 0.1, 1.2)
	blob(g + Vector3.new(0, 9.5 * s, 0), Vector3.new(3, 1.2, 3) * s, Vector3.new(14, 5, 14) * s, RGB(255, 200, 220), FF, 0, 1.2)
	X.Smoke(g + Vector3.new(0, 4 * s, 0), RGB(255, 160, 200), s, 14, 6)
	X.Motes(g + Vector3.new(0, 9 * s, 0), W, 1.3 * s, 30, 18, 3, 2.2)
	X.Ring(groundCF(g), 1, 11 * s, 1 * s, 0.4 * s, RGB(255, 120, 170), 0.6)
	X.Shake(c, 0.8 * s)
end)
-- Fungal Brute: spine spray — a hedgehog burst of lime spines and green
-- spore puffs
def("Sporeback", function(c, g, s, d)
	X.Tex(c, "Spore", RGB(200, 255, 120), s, 12, { Size = 2.6, Size1 = 3.5, Speed = 16, Life = 1.8, Glow = 0.4, Grav = -2, Rot = 60 })
	X.Flash(c, RGB(190, 255, 110), 0.9 * s, 1)
	X.Spikes(c, 46, 14 * s, 0.45 * s, RGB(200, 255, 110), RGB(50, 110, 20), X.Sphere(0.9), { Glow = 0.6, Grow = 0.06 })
	X.Crystals(c, 8, 7 * s, 0.6 * s, RGB(160, 230, 80), RGB(240, 255, 200), NEON, X.Sphere(0.6))
	X.Smoke(c, RGB(150, 210, 90), s, 12, 4)
	X.Mark(g, "Smoke", RGB(90, 150, 40), 14 * s, 2)
	X.Shake(c, s)
end)
-- Spore Moth: glowing dust spirals up in a triple helix, two shimmering
-- wings flare open
def("Glowmoth", function(c, g, s, d)
	X.Tex(c, "Petal", RGB(140, 255, 230), s, 20, { Size = 1.6, Speed = 18, Life = 2, Glow = 0.8, Bright = 3, Grav = 2, Rot = 200, Drag = 3 })
	X.Tex(c, "Spore", RGB(160, 255, 235), s, 8, { Size = 2, Speed = 10, Life = 2, Glow = 0.8, Grav = -3 })
	X.Helix(g, 14 * s, 4 * s, RGB(120, 255, 230), 3, 6, 1.3, s)
	local a = L.Anchor(CFrame.new(c), 2)
	for k = -1, 1, 2 do
		L.EmitNow(L.Emitter(a, {
			Texture = L.Tex("Flare"), Color = ColorSequence.new(W, RGB(120, 255, 230)), Brightness = 6, LightEmission = 1, ZOffset = 3,
			Size = L.NS({ { 0, 3 * s }, { 0.2, 16 * s }, { 1, 0 } }), Squash = L.NS({ { 0, -1.2 }, { 1, -1.2 } }),
			Rotation = NumberRange.new(k * 35), Lifetime = NumberRange.new(0.7), Speed = NumberRange.new(0),
		}), 1)
	end
	X.Motes(c, RGB(160, 255, 235), 1.2 * s, 50, 12, -2, 2.5)
	X.Arc(c, Vector3.yAxis, Vector3.xAxis, 7 * s, 1.2 * s, RGB(120, 255, 230), 0.8, 5)
	X.Shake(c, 0.6 * s)
end)
def("Shroomling", function(c, g, s, d)
	X.Tex(c, "Spore", RGB(255, 170, 210), s, 6, { Size = 2, Speed = 10, Life = 1.4, Glow = 0.4, Grav = -2 })
	blob(c, Vector3.new(2, 1.5, 2) * s, Vector3.new(9, 5, 9) * s, RGB(255, 150, 200), NEON, 0.15, 0.7)
	X.Motes(c, RGB(255, 200, 230), s, 20, 12, 2, 1.5)
end)

-- ===== PLATEAU (earth) =====
-- Bramble Brute: a ring of thorny brambles bursts from the ground with
-- flying leaves
def("Bristlehulk", function(c, g, s, d)
	X.Tex(c, "Leaf", RGB(130, 210, 70), s, 26, { Size = 2, Speed = 28, Life = 2, Glow = 0.2, Grav = 8, Rot = 260, Drag = 3, Color2 = RGB(200, 180, 60) })
	X.Pillars(g, 12, 5 * s, 5 * s, 0.9 * s, RGB(110, 80, 45), WOOD, 0.9)
	X.Spikes(g + Vector3.new(0, 0.5, 0), 30, 9 * s, 0.6 * s, RGB(140, 220, 70), RGB(70, 50, 20), X.Sphere(1.1), { Glow = 0.35 })
	X.Flash(c, RGB(190, 255, 120), 0.8 * s, 1)
	X.Debris(c, RGB(120, 200, 70), s * 1.2, 30, "Shard", 30, 15)
	X.Ring(groundCF(g), 1, 10 * s, 1 * s, 0.6 * s, RGB(150, 230, 90), 0.5)
	X.Shake(c, s)
end)
-- Mossy Golem: an earthquake — mossy fissures, a rolling ring of rock and a
-- big dust wave
def("Mossgrave", function(c, g, s, d)
	X.Tex(c, "Rock", RGB(120, 130, 95), s, 18, { Size = 2, Speed = 34, Life = 1.5, Glow = 0, Grav = 50, Rot = 300 })
	X.Tex(g, "Wave", RGB(180, 160, 120), s, 1, { Size = 26, Size1 = 30, Life = 0.7, Glow = 0.2, Flat = true, Rot = 0 })
	X.Fissures(g, 6, 13 * s, RGB(170, 255, 110), s, 1.4)
	X.Ring(groundCF(g), 1, 14 * s, 2.2 * s, 1.6 * s, RGB(105, 120, 85), 0.8, { Mat = SLATE, Color2 = RGB(80, 110, 60), Segs = 22 })
	X.Rocks(c, 12, 2 * s, RGB(110, 125, 90), SLATE, 34 * s, X.Sphere(0.8))
	X.Dust(g, RGB(150, 135, 105), s, 30)
	X.Flash(c, RGB(200, 255, 150), 0.8 * s, 1)
	X.Motes(c, RGB(160, 240, 110), s, 24, 14, -3, 1.8)
	X.Shake(c, 1.3 * s)
end)
-- Cloud Ram: a fluffy thunder-wool puff with yellow static zaps
def("Puffhorn", function(c, g, s, d)
	smokeFlip(c, RGB(250, 250, 255), 1.2 * s, 8)
	crackle(c, RGB(255, 240, 110), s, 6)
	blob(c, Vector3.new(4, 3, 4) * s, Vector3.new(16, 11, 16) * s, RGB(250, 250, 255), PLASTIC, 0.05, 0.9)
	X.Smoke(c, RGB(245, 245, 255), 1.3 * s, 14, 2)
	bolts(c, 6, 10 * s, RGB(255, 240, 90), 0.35 * s, X.Sphere(0.2))
	X.Ring(groundCF(g), 1, 12 * s, 0.8 * s, 0.4 * s, RGB(255, 240, 110), 0.5)
	X.Sparks(c, RGB(255, 240, 100), s, 40, 80, 10)
	X.Shake(c, 0.8 * s)
end)

-- ===== COAST (water) =====
-- Sky Shark: an X-shaped bite of two water crescents, a splash crown and
-- falling droplets
def("Skyfin", function(c, g, s, d)
	X.Tex(g + Vector3.new(0, 2 * s, 0), "Splash", RGB(150, 215, 255), s, 3, { Size = 12, Speed = 0.1, Life = 0.6, Glow = 0.6, Rot = 0, Squash = 0 })
	X.Tex(c, "Bubble", RGB(170, 230, 255), s, 16, { Size = 1.4, Speed = 14, Life = 1.6, Glow = 0.5, Grav = -5, Rot = 20 })
	local fwd = X.Horizontal(d)
	local side = fwd:Cross(Vector3.yAxis).Unit
	X.Arc(c, fwd, (Vector3.yAxis + side).Unit, 7 * s, 2 * s, RGB(80, 190, 255), 0.5, -2.2, { Sweep = math.pi, Tip = W })
	X.Arc(c, fwd, (Vector3.yAxis - side).Unit, 7 * s, 2 * s, RGB(80, 190, 255), 0.5, 2.2, { Sweep = math.pi, Tip = W })
	after(0.15, function()
		X.Flash(c, RGB(110, 200, 255), s, 1)
		X.Spikes(g + Vector3.new(0, 0.5, 0), 22, 10 * s, 1 * s, RGB(200, 240, 255), RGB(40, 120, 220), X.Sphere(2), { Glow = 0.5 })
		X.Motes(c, RGB(170, 225, 255), 1.3 * s, 40, 30, 80, 1.2)
		X.Ring(groundCF(g), 1, 12 * s, 1.2 * s, 1.2 * s, RGB(120, 210, 255), 0.6, { Mat = GLASS })
		X.Shake(c, s)
	end)
end)
-- Tide Octopus: eight ink tentacles whip out from a dark splat
def("Octoblob", function(c, g, s, d)
	X.Tex(g, "Ink", RGB(25, 10, 40), s, 1, { Size = 20, Size1 = 22, Life = 3, Glow = 0, Flat = true, Rot = 0 })
	X.Tex(c, "Ink", RGB(60, 20, 90), s, 8, { Size = 3, Speed = 20, Life = 1, Glow = 0, Grav = 30, Rot = 100 })
	X.Tentacles(c, 8, 12 * s, 1.4 * s, RGB(150, 70, 230), RGB(40, 10, 60), 1.1)
	X.Flash(c, RGB(170, 90, 255), 0.9 * s, 1)
	X.Splat(c, RGB(90, 30, 140), RGB(10, 0, 20), s)
	X.Mark(g, "Spikes", RGB(20, 5, 35), 18 * s, 3)
	X.Smoke(c, RGB(50, 20, 70), s, 14, 2)
	X.Shake(c, s)
end)

-- ===== BOSSES (everything bigger, several stages) =====
def("MesaColossus", function(c, g, s, d)
	X.Tex(c, "Rock", RGB(210, 165, 110), 1.5 * s, 24, { Size = 2.4, Speed = 40, Life = 1.6, Glow = 0, Grav = 50, Rot = 300 })
	X.Tex(g, "Wave", RGB(240, 210, 150), s, 1, { Size = 50, Size1 = 60, Life = 0.9, Glow = 0.3, Flat = true, Rot = 0 })
	X.Fissures(g, 9, 22 * s, RGB(255, 200, 90), s * 1.3, 2)
	after(0.15, function()
		X.Pillars(g, 14, 10 * s, 14 * s, 3 * s, RGB(215, 165, 105), SAND, 1.4)
		X.Column(g, 60 * s, 7 * s, RGB(255, 210, 110), 1.1)
		X.Flash(c, RGB(255, 210, 120), 1.5 * s, 2)
		X.Rocks(c, 16, 3 * s, RGB(200, 150, 95), SAND, 40 * s, X.Sphere(0.9))
		X.Ring(groundCF(g), 2, 26 * s, 3 * s, 2 * s, RGB(200, 155, 100), 1, { Mat = SAND, Segs = 30 })
		X.Dust(g, RGB(220, 190, 140), 1.5 * s, 40)
		X.Shake(c, 2 * s)
	end)
end, true)
def("FrostpeakWarden", function(c, g, s, d)
	X.Tex(c + Vector3.new(0, 6 * s, 0), "Snowflake", W, 1.5 * s, 30, { Size = 3, Speed = 26, Life = 2.6, Glow = 0.8, Grav = 5, Rot = 90 })
	X.Snowflake(c + Vector3.new(0, 4 * s, 0), RGB(190, 235, 255), 22 * s, 1.5)
	X.Dome(c, 3 * s, 22 * s, RGB(160, 220, 255), 1, FF, 0.05, 1)
	X.Pillars(g, 14, 12 * s, 14 * s, 3 * s, RGB(175, 225, 255), ICE, 1.5)
	X.Ring(groundCF(g), 2, 26 * s, 2.5 * s, 0.6 * s, W, 0.9, { Color2 = RGB(170, 230, 255), Segs = 36 })
	X.Flash(c, RGB(200, 240, 255), 1.5 * s, 2)
	X.Motes(c + Vector3.new(0, 12 * s, 0), W, 1.5 * s, 70, 20, 8, 3)
	X.Shake(c, 2 * s)
end, true)
def("MyceliumMonarch", function(c, g, s, d)
	X.Tex(g, "Rune", RGB(255, 140, 230), s, 1, { Size = 30, Size1 = 32, Life = 2.2, Glow = 1, Bright = 4, Flat = true, Rot = 30 })
	X.Tex(g + Vector3.new(0, 16 * s, 0), "Spore", RGB(255, 150, 220), 1.5 * s, 20, { Size = 3, Speed = 18, Life = 2.4, Glow = 0.5, Grav = -2 })
	X.Rune(g, 14 * s, RGB(255, 120, 220), 6, 1.8)
	X.Helix(g, 24 * s, 7 * s, RGB(255, 140, 230), 4, 8, 1.6, 1.3 * s)
	after(0.3, function()
		X.Column(g, 18 * s, 5 * s, RGB(255, 220, 240), 1)
		blob(g + Vector3.new(0, 18 * s, 0), Vector3.new(6, 2, 6) * s, Vector3.new(34, 11, 34) * s, RGB(255, 90, 190), NEON, 0.1, 1.6)
		X.Flash(c, RGB(255, 140, 230), 1.5 * s, 2)
		X.Motes(g + Vector3.new(0, 16 * s, 0), W, 1.6 * s, 60, 24, 3, 3)
		X.Shake(c, 1.8 * s)
	end)
end, true)
def("BogstormCroaker", function(c, g, s, d)
	crackle(c, RGB(170, 220, 255), 1.5 * s, 16)
	X.Tex(g + Vector3.new(0, 1, 0), "Bubble", RGB(160, 220, 255), 1.4 * s, 26, { Size = 2, Speed = 12, Life = 2, Glow = 0.5, Grav = -6 })
	skyBolts(g, 9, RGB(150, 210, 255), 1.3 * s)
	for k = 0, 3 do
		after(k * 0.1, function()
			X.Ring(groundCF(g + Vector3.new(0, k * 1.5 * s, 0)), 2, (14 + k * 6) * s, 1.2 * s, 0.8 * s, k % 2 == 0 and W or RGB(120, 200, 255), 0.6)
		end)
	end
	after(0.25, function()
		X.Dome(c, 3 * s, 18 * s, RGB(140, 200, 255), 0.4, FF, 0, 1)
		bolts(g + Vector3.new(0, 0.5, 0), 12, 24 * s, RGB(180, 230, 255), 0.6 * s, X.Flat())
		X.Flash(c, RGB(170, 220, 255), 1.5 * s, 2)
		X.Shake(c, 2 * s)
	end)
end, true)
def("PrismSovereign", function(c, g, s, d)
	X.Tex(g, "Rune", RGB(160, 200, 255), s, 1, { Size = 34, Size1 = 36, Life = 2.2, Glow = 1, Bright = 4, Flat = true, Rot = 30 })
	X.Tex(c, "Star", W, 1.5 * s, 30, { Size = 2.4, Speed = 40, Life = 1.5, Glow = 1, Bright = 5, Rot = 300, Color2 = RGB(190, 150, 255) })
	X.Rune(g, 16 * s, RGB(150, 200, 255), 5, 1.8)
	-- crystal cage: spears from a ring converge on the centre, then burst
	for k = 1, 12 do
		local a = k / 12 * math.pi * 2
		local from = c + Vector3.new(math.cos(a) * 18 * s, 6 * s, math.sin(a) * 18 * s)
		local p = X.Part(Vector3.new(1.2 * s, 1.2 * s, 6 * s), CFrame.lookAt(from, c), k % 2 == 0 and RGB(150, 200, 255) or RGB(210, 170, 255), GLASS, 0.05, 1.5)
		X.Tween(p, 0.4, { CFrame = CFrame.lookAt(c + (from - c).Unit * 3 * s, c) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		after(0.4, function()
			X.Tween(p, 0.3, { Transparency = 1 })
		end)
	end
	after(0.42, function()
		X.Flash(c, W, 1.8 * s, 2)
		X.Column(g, 70 * s, 8 * s, RGB(200, 220, 255), 1.2)
		X.Crystals(c, 20, 16 * s, 1.4 * s, RGB(150, 200, 255), W, GLASS, X.Sphere(0.3), { Color2 = RGB(210, 160, 255) })
		for _, col in { RGB(255, 60, 60), RGB(255, 200, 40), RGB(80, 255, 120), RGB(60, 160, 255), RGB(190, 90, 255) } do
			X.Spikes(c, 6, 20 * s, 0.7 * s, col, col, X.Sphere(0.2), { Glow = 0.9 })
		end
		X.Shake(c, 2 * s)
	end)
end, true)
def("CalderaTitan", function(c, g, s, d)
	fireball(c, RGB(255, 120, 30), RGB(120, 10, 0), 2 * s, 8)
	smokeFlip(c + Vector3.new(0, 12 * s, 0), RGB(60, 40, 35), 1.8 * s, 12)
	X.Fissures(g, 10, 24 * s, RGB(255, 110, 20), 1.4 * s, 2.2)
	after(0.15, function()
		X.Column(g, 70 * s, 10 * s, RGB(255, 100, 20), 1.3)
		X.Pillars(g, 12, 11 * s, 10 * s, 3 * s, RGB(50, 35, 35), BASALT, 1.5)
		X.Flash(c, RGB(255, 130, 40), 1.8 * s, 2)
		X.Splat(c, RGB(255, 80, 10), RGB(80, 5, 0), 1.6 * s)
		X.Spikes(c, 60, 22 * s, 1.8 * s, RGB(255, 110, 20), RGB(110, 5, 0), X.Sphere(0.6))
		X.Meteors(g, 10, RGB(255, 120, 30), 1.4 * s)
		X.Smoke(c + Vector3.new(0, 10 * s, 0), RGB(60, 40, 35), 1.6 * s, 18, 14)
		X.Shake(c, 2.4 * s)
	end)
end, true)
def("Tidebreaker", function(c, g, s, d)
	X.Tex(g + Vector3.new(0, 3 * s, 0), "Splash", RGB(160, 220, 255), 1.8 * s, 4, { Size = 14, Speed = 0.1, Life = 0.7, Glow = 0.6, Rot = 0 })
	X.Tex(g, "Ink", RGB(15, 25, 60), s, 1, { Size = 30, Life = 3, Glow = 0, Flat = true, Rot = 0 })
	X.Ring(groundCF(g), 3, 24 * s, 2.5 * s, 7 * s, RGB(70, 170, 255), 1.1, { Mat = GLASS, Alpha = 0.15, Color2 = RGB(150, 220, 255), Segs = 34 })
	X.Tentacles(c, 8, 18 * s, 2 * s, RGB(80, 170, 255), RGB(20, 60, 140), 1.3)
	after(0.2, function()
		X.Flash(c, RGB(120, 210, 255), 1.5 * s, 2)
		X.Spikes(g + Vector3.new(0, 1, 0), 34, 18 * s, 1.4 * s, RGB(210, 245, 255), RGB(30, 110, 220), X.Sphere(2))
		X.Motes(c, RGB(170, 225, 255), 1.6 * s, 70, 40, 80, 1.4)
		X.Mark(g, "Spikes", RGB(15, 20, 50), 22 * s, 3)
		X.Shake(c, 2 * s)
	end)
end, true)

-- ===== PLAYER (cloud wind) =====
def("PlayerPunch", function(c, g, s, d)
	X.Tex(c, "Crescent", RGB(210, 240, 255), s, 2, { Size = 6, Speed = 0.1, Life = 0.35, Glow = 1, Bright = 4, Rot = 0 })
	local fwd = d or X.Horizontal(nil)
	for k = 1, 3 do
		X.Arc(c, fwd, Vector3.new(math.cos(k * 2.1), math.sin(k * 2.1), 0), (3 + k) * s, 1.3 * s, RGB(190, 230, 255), 0.35, 3, { Tip = W, Sweep = math.pi * 0.6 })
	end
	X.Dome(c, 0.4 * s, 3 * s, W, 0.2)
	X.Sparks(c, RGB(200, 235, 255), s, 18, 60, 10)
end)
def("PlayerSlam", function(c, g, s, d)
	X.Tex(g, "Wave", W, s, 1, { Size = 24, Size1 = 30, Life = 0.6, Glow = 0.6, Flat = true, Rot = 0 })
	X.Ring(groundCF(g), 1, 13 * s, 1.6 * s, 0.8 * s, W, 0.55, { Color2 = RGB(190, 230, 255) })
	blob(g + Vector3.new(0, 1.5 * s, 0), Vector3.new(4, 1.5, 4) * s, Vector3.new(16, 4, 16) * s, W, PLASTIC, 0.1, 0.6)
	X.Dust(g, RGB(240, 245, 255), s, 30)
	for k = 1, 4 do
		X.Arc(g + Vector3.new(0, 1, 0), Vector3.yAxis, Vector3.new(math.cos(k * 1.57), 0, math.sin(k * 1.57)), 9 * s, 1.4 * s, RGB(200, 235, 255), 0.5, 3, { Tip = W })
	end
	X.Shake(c, s)
end)
def("PlayerPuff", function(c, g, s, d)
	smokeFlip(c, W, 0.8 * s, 6)
	blob(c, Vector3.new(2, 2, 2) * s, Vector3.new(9, 8, 9) * s, W, PLASTIC, 0.05, 0.6)
	X.Smoke(c, RGB(245, 248, 255), s, 10, 3)
	X.Motes(c, RGB(210, 235, 255), s, 18, 18, 0, 1)
end)

-- the showcase red (kept as its own style)
def("Red", function(c, g, s, d)
	FxKit.RedExplosion(c, s)
end)

------------------------------------------------------------------------
-- v2.26 ABILITY VFX: every special attack has its own effect, fitting its
-- name (played where it hits; casts without a hit play on the caster)
------------------------------------------------------------------------
local Y = Vector3.yAxis
-- Crystal Stalker
def("ShardVolley", function(c, g, s, d)
	local fwd = X.Horizontal(d)
	X.Crystals(c - fwd * 2 * s, 5, 6 * s, 0.6 * s, RGB(130, 225, 255), W, GLASS, X.Fan(fwd, 5, 0.4, 0.05))
	X.Tex(c, "Star", RGB(200, 240, 255), s, 8, { Size = 1.6, Speed = 22, Life = 0.8, Glow = 1, Bright = 4 })
	X.Dome(c, 0.4 * s, 3 * s, RGB(160, 235, 255), 0.25)
end)
def("RefractionDash", function(c, g, s, d)
	local fwd = X.Horizontal(d)
	for i, col in { RGB(255, 70, 70), RGB(255, 220, 60), RGB(80, 255, 140), RGB(80, 160, 255), RGB(200, 100, 255) } do
		after(i * 0.03, function()
			X.Ring(facing(c - fwd * i * 1.2 * s, fwd), 0.5, 5 * s, 0.4 * s, 0.3 * s, col, 0.4)
		end)
	end
	X.Flash(c, W, 0.7 * s, 2)
	X.Tex(c, "Star", W, s, 12, { Size = 1.4, Speed = 26, Life = 0.9, Glow = 1, Bright = 5, Color2 = RGB(160, 220, 255) })
end)
-- Glacier Tortoise
def("PermafrostSlam", function(c, g, s, d)
	X.Pillars(g, 7, 5 * s, 5 * s, 1.4 * s, RGB(170, 225, 255), ICE, 1)
	X.Tex(g, "Snowflake", RGB(190, 235, 255), s, 1, { Size = 18, Size1 = 20, Life = 1.6, Glow = 0.8, Bright = 3, Flat = true, Rot = 20 })
	X.Ring(groundCF(g), 1, 12 * s, 1.3 * s, 0.4 * s, W, 0.6)
	X.Shake(c, s)
end)
def("ShellBastion", function(c, g, s, d)
	local dome = X.Part(Vector3.one * 14 * s, CFrame.new(c), RGB(150, 220, 255), FF, 0.15, 4.5, Enum.PartType.Ball)
	X.Tween(dome, 4, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	X.Tex(c, "Snowflake", W, s, 14, { Size = 1.6, Speed = 10, Life = 2.5, Glow = 0.8, Grav = 2 })
	X.Ring(groundCF(g), 7 * s, 7 * s, 0.6 * s, 0.4 * s, RGB(180, 235, 255), 1.5, { Keep = true, Hold = 3, Spin = 2 })
end)
-- Storm Wraith
def("ChainLightning", function(c, g, s, d)
	bolts(c, 5, 8 * s, RGB(200, 180, 255), 0.35 * s, X.Sphere(0.2))
	crackle(c, RGB(190, 160, 255), s, 8)
	X.Dome(c, 0.5 * s, 4 * s, RGB(190, 160, 255), 0.25)
end)
def("StaticBlink", function(c, g, s, d)
	X.Dome(c, 4 * s, 0.4 * s, RGB(170, 140, 255), 0.25, FF, 0.1, 0.4)
	crackle(c, RGB(200, 180, 255), s, 10)
	X.Ring(facing(c, Y), 0.5, 7 * s, 0.5 * s, 0.4 * s, RGB(180, 150, 255), 0.35, { Spin = 6 })
end)
-- Crystal Whirlwind (+ old wind moves)
def("PrismVortex", function(c, g, s, d)
	FxKit.Tornado(g, RGB(180, 140, 255), 0.9 * s, 1.4)
	X.Tex(c, "Star", RGB(220, 190, 255), s, 16, { Size = 1.4, Speed = 18, Life = 1.4, Glow = 1, Rot = 400 })
end)
def("ShardCyclone", function(c, g, s, d)
	X.Crystals(c, 12, 8 * s, 0.6 * s, RGB(200, 160, 255), W, GLASS, X.Flat())
	X.Ring(groundCF(g), 1, 10 * s, 0.6 * s, 0.4 * s, RGB(200, 160, 255), 0.45, { Spin = 6 })
end)
def("VortexPull", function(c, g, s, d)
	for k = 1, 4 do
		X.Arc(c, Y, Vector3.new(math.cos(k * 1.57), 0, math.sin(k * 1.57)), 9 * s, 1.4 * s, RGB(200, 240, 255), 0.7, -6, { R0 = 1, Tip = W })
	end
end)
def("GaleBurst", function(c, g, s, d)
	X.Tex(c, "Crescent", RGB(220, 245, 255), s, 4, { Size = 7, Speed = 18, Life = 0.6, Glow = 1, Rot = 200 })
	X.Tex(g, "Wave", W, s, 1, { Size = 20, Size1 = 26, Life = 0.6, Glow = 0.6, Flat = true, Rot = 0 })
end)
-- Magma Tyrant
def("MagmaGeyser", function(c, g, s, d)
	X.Fissures(g, 5, 7 * s, RGB(255, 110, 30), 0.9 * s, 1.4)
	X.Column(g, 28 * s, 5 * s, RGB(255, 120, 30), 0.9)
	fireball(g + Vector3.new(0, 6 * s, 0), RGB(255, 140, 40), RGB(150, 20, 0), s, 4)
	X.Tex(g + Vector3.new(0, 2, 0), "FireFlip", RGB(255, 150, 50), s, 14, { Size = 4, Speed = 34, Life = 0.9, Glow = 0.9, Spread = Vector2.new(15, 15), Grav = 30 })
	X.Shake(c, 1.2 * s)
end)
def("EmberWings", function(c, g, s, d)
	local fwd = X.Horizontal(d)
	local side = fwd:Cross(Y).Unit
	for sg = -1, 1, 2 do
		X.Arc(c, fwd, (Y + side * sg * 0.3).Unit, 9 * s, 2.4 * s, RGB(255, 120, 30), 0.55, sg * 2.2, { Sweep = math.pi * 0.7, Tip = RGB(255, 230, 150) })
	end
	X.Tex(c, "FireFlip", RGB(255, 140, 40), s, 10, { Size = 4, Speed = 22, Life = 0.8, Glow = 0.9, Grav = -8 })
end)
-- Ember Blob
def("FuseHop", function(c, g, s, d)
	fireball(c, RGB(255, 170, 50), RGB(150, 40, 0), 1.1 * s, 6)
	X.Ring(groundCF(g), 1, 10 * s, 1.2 * s, 0.5 * s, RGB(255, 160, 40), 0.5)
	smokeFlip(c + Vector3.new(0, 3 * s, 0), RGB(80, 65, 60), s, 8)
	X.Shake(c, s)
end)
def("AshPuff", function(c, g, s, d)
	smokeFlip(c, RGB(110, 100, 100), 1.6 * s, 14)
	blob(c, Vector3.new(4, 3, 4) * s, Vector3.new(18, 10, 18) * s, RGB(90, 85, 85), PLASTIC, 0.2, 1.2)
	X.Motes(c, RGB(255, 150, 60), s, 20, 14, -4, 1.6)
end)
-- Toadstool Strider
def("SporeBloom", function(c, g, s, d)
	X.Tex(g, "Petal", RGB(255, 130, 180), s, 1, { Size = 3, Speed = 0.1, Life = 0.1 })
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		local p = g + Vector3.new(math.cos(a), 0.3, math.sin(a)) * 3 * s
		X.Tex(p, "Petal", RGB(255, 120, 170), s, 1, { Size = 5, Size1 = 6, Speed = 0.1, Life = 1.6, Glow = 0.6, Bright = 3, Flat = true, Rot = 10 })
	end
	X.Tex(c, "Spore", RGB(255, 180, 210), s, 12, { Size = 2.4, Speed = 8, Life = 2.4, Glow = 0.4, Grav = -2 })
end)
def("SproutSquad", function(c, g, s, d)
	X.Tex(g + Vector3.new(0, 1, 0), "Leaf", RGB(140, 230, 90), s, 18, { Size = 1.8, Speed = 18, Life = 1.6, Grav = 10, Spread = Vector2.new(50, 50) })
	X.Ring(groundCF(g), 1, 8 * s, 0.6 * s, 0.4 * s, RGB(140, 230, 90), 0.5)
	X.Helix(g, 6 * s, 2 * s, RGB(160, 255, 110), 2, 5, 0.9, 0.7 * s)
end)
-- Fungal Brute
def("SpineSpray", function(c, g, s, d)
	X.Spikes(c, 12, 6 * s, 0.4 * s, RGB(200, 255, 110), RGB(50, 110, 20), X.Sphere(0.4, d), { Glow = 0.6 })
	X.Tex(c, "Spore", RGB(200, 255, 120), s, 4, { Size = 2, Speed = 6, Life = 1.4, Grav = -2 })
end)
def("MyceliumGrip", function(c, g, s, d)
	X.Tentacles(g + Vector3.new(0, 0.5, 0), 6, 5 * s, 0.8 * s, RGB(170, 140, 100), RGB(220, 255, 150), 1.4)
	X.Tex(g, "Rune", RGB(190, 255, 130), s, 1, { Size = 10, Size1 = 11, Life = 1.6, Glow = 0.8, Flat = true, Rot = 40 })
end)
-- Watching Rubble
def("OrbitCrush", function(c, g, s, d)
	X.Rocks(c + Vector3.new(0, 6 * s, 0), 8, 1.6 * s, RGB(110, 100, 120), SLATE, 10 * s, X.Sphere(-2))
	X.Ring(groundCF(g), 1, 12 * s, 2 * s, 1.2 * s, RGB(100, 95, 110), 0.7, { Mat = SLATE, Segs = 20 })
	X.Tex(c, "Rock", RGB(120, 110, 135), s, 10, { Size = 1.4, Speed = 26, Life = 1.2, Grav = 40 })
	X.Dust(g, RGB(150, 140, 160), s, 20)
	X.Shake(c, s)
end)
def("VoidGaze", function(c, g, s, d)
	X.Dome(c, 3 * s, 0.4 * s, RGB(15, 5, 25), 0.3, PLASTIC, 0, 0.2)
	after(0.3, function()
		X.Flash(c, RGB(180, 90, 255), 0.8 * s, 1)
		X.Spikes(c, 16, 8 * s, 0.6 * s, RGB(170, 90, 255), RGB(20, 0, 40), X.Sphere(0), { Glow = 0.5 })
	end)
end)
-- Bramble Brute
def("ThornCharge", function(c, g, s, d)
	local fwd = X.Horizontal(d)
	X.Spikes(c, 18, 9 * s, 0.6 * s, RGB(150, 220, 70), RGB(70, 50, 20), X.Fan(fwd, 18, 0.8, 0.2), { Glow = 0.35 })
	X.Tex(c, "Claw", RGB(180, 240, 120), s, 1, { Size = 7, Speed = 0.1, Life = 0.4, Glow = 1, Rot = 0 })
	X.Tex(c, "Leaf", RGB(130, 210, 70), s, 14, { Size = 1.6, Speed = 22, Life = 1.6, Grav = 8, Drag = 3 })
end)
def("BrambleWall", function(c, g, s, d)
	X.Pillars(g, 10, 4 * s, 6 * s, 1.1 * s, RGB(105, 75, 45), WOOD, 4)
	X.Tex(g + Vector3.new(0, 2, 0), "Leaf", RGB(120, 200, 70), s, 20, { Size = 1.8, Speed = 14, Life = 2, Grav = 6, Drag = 3 })
end)
-- Storm Snapper
def("SnapLunge", function(c, g, s, d)
	jaws(c, X.Horizontal(d), 4 * s, 1.4 * s, RGB(140, 255, 140), RGB(240, 255, 170))
	crackle(c, RGB(170, 255, 170), s, 6)
end)
def("AcidSpit", function(c, g, s, d)
	X.Splat(c, RGB(170, 255, 70), RGB(40, 90, 10), 0.6 * s)
	X.Tex(g, "Ink", RGB(130, 230, 40), s, 1, { Size = 8, Size1 = 9, Life = 4, Glow = 0.5, Flat = true, Rot = 0 })
	X.Tex(g + Vector3.new(0, 0.6, 0), "Bubble", RGB(180, 255, 90), s, 14, { Size = 1, Speed = 5, Life = 2, Glow = 0.6, Grav = -4, Box = 3, Shape = Enum.ParticleEmitterShape.Box })
end)
-- Mossy Golem
def("BoulderToss", function(c, g, s, d)
	X.Rocks(c, 10, 1.8 * s, RGB(110, 125, 90), SLATE, 28 * s, X.Sphere(0.9))
	X.Ring(groundCF(g), 1, 12 * s, 1.8 * s, 1.2 * s, RGB(100, 115, 85), 0.7, { Mat = SLATE, Segs = 20 })
	X.Tex(g, "Wave", RGB(170, 150, 110), s, 1, { Size = 22, Size1 = 26, Life = 0.6, Glow = 0.2, Flat = true, Rot = 0 })
	X.Dust(g, RGB(150, 135, 105), s, 26)
	X.Shake(c, 1.2 * s)
end)
def("VineLash", function(c, g, s, d)
	X.Tentacles(c, 3, 7 * s, 0.7 * s, RGB(90, 170, 60), RGB(170, 240, 110), 0.8)
	X.Tex(c, "Leaf", RGB(120, 200, 70), s, 10, { Size = 1.4, Speed = 16, Life = 1.4, Grav = 8 })
end)
-- Fanged Glutton
def("FrenzyBite", function(c, g, s, d)
	for k = 0, 2 do
		after(k * 0.09, function()
			X.Tex(c + Vector3.new(0, (k - 1) * 0.8, 0), "Claw", k == 1 and W or RGB(255, 120, 120), s, 1, { Size = 7, Speed = 0.1, Life = 0.35, Glow = 1, Bright = 5, Rot = 0 })
		end)
	end
	jaws(c, X.Horizontal(d), 3.5 * s, 1.2 * s, RGB(255, 90, 90), W)
end)
def("GroundPound", function(c, g, s, d)
	X.Fissures(g, 6, 9 * s, RGB(255, 200, 120), 0.8 * s, 1.2)
	X.Ring(groundCF(g), 1, 11 * s, 1.5 * s, 0.8 * s, RGB(170, 140, 100), 0.6, { Mat = SLATE })
	X.Dust(g, RGB(170, 150, 120), s, 24)
	X.Shake(c, s)
end)
-- Sky Shark
def("FinDive", function(c, g, s, d)
	X.Tex(g + Vector3.new(0, 2 * s, 0), "Splash", RGB(150, 215, 255), s, 3, { Size = 12, Speed = 0.1, Life = 0.6, Glow = 0.6, Rot = 0 })
	X.Spikes(g + Vector3.new(0, 0.5, 0), 16, 9 * s, 0.9 * s, RGB(210, 245, 255), RGB(40, 120, 220), X.Sphere(2.2), { Glow = 0.5 })
	X.Motes(c, RGB(170, 225, 255), s, 30, 26, 80, 1.1)
end)
def("TailSpin", function(c, g, s, d)
	for k = 1, 4 do
		X.Arc(c, Y, Vector3.new(math.cos(k * 1.57), 0, math.sin(k * 1.57)), 8 * s, 2 * s, RGB(80, 190, 255), 0.6, 7, { Tip = W })
	end
	X.Ring(groundCF(g), 1, 10 * s, 1 * s, 1 * s, RGB(120, 210, 255), 0.5, { Mat = GLASS })
	X.Tex(c, "Bubble", RGB(170, 230, 255), s, 10, { Size = 1.2, Speed = 14, Life = 1.4, Grav = -4 })
end)
-- Cloud Ram
def("WoolBounce", function(c, g, s, d)
	blob(g + Vector3.new(0, 1.5 * s, 0), Vector3.new(4, 2, 4) * s, Vector3.new(14, 6, 14) * s, W, PLASTIC, 0.05, 0.7)
	X.Ring(groundCF(g), 1, 11 * s, 1.2 * s, 0.6 * s, RGB(255, 250, 225), 0.5)
	X.Dust(g, RGB(250, 250, 255), s, 20)
end)
def("StaticFluff", function(c, g, s, d)
	crackle(c, RGB(255, 240, 110), s, 12)
	bolts(c, 5, 8 * s, RGB(255, 240, 100), 0.3 * s, X.Sphere(0.1))
	X.Tex(c, "Spore", W, s, 6, { Size = 2.4, Speed = 6, Life = 1.4, Grav = -1 })
end)
-- Snow Owl
def("SnowballBarrage", function(c, g, s, d)
	X.Dome(c, 0.6 * s, 4 * s, W, 0.3, PLASTIC, 0, 1)
	X.Tex(c, "Snowflake", RGB(220, 245, 255), s, 8, { Size = 1.4, Speed = 18, Life = 1.2, Glow = 0.7, Grav = 6 })
	X.Smoke(c, RGB(245, 250, 255), 0.6 * s, 6, 1)
end)
def("WingGust", function(c, g, s, d)
	local fwd = X.Horizontal(d)
	X.Tex(c, "Feather", W, s, 16, { Size = 2.2, Speed = 26, Life = 1.8, Grav = 3, Rot = 200, Drag = 3 })
	for k = -1, 1 do
		X.Arc(c, fwd, Vector3.new(math.cos(k), math.sin(k), 0), 6 * s, 1.6 * s, RGB(220, 245, 255), 0.45, 3, { Tip = W })
	end
	X.Tex(c, "Crescent", W, s, 3, { Size = 7, Speed = 0.1, Life = 0.35, Glow = 1, Rot = 0 })
end)
-- Spore Moth
def("SporeSpiral", function(c, g, s, d)
	X.Helix(c - Vector3.new(0, 2 * s, 0), 6 * s, 1.6 * s, RGB(120, 255, 230), 2, 5, 0.8, 0.6 * s)
	X.Tex(c, "Petal", RGB(140, 255, 230), s, 8, { Size = 1.2, Speed = 12, Life = 1.4, Glow = 0.8, Grav = 2 })
end)
def("LullabyDust", function(c, g, s, d)
	X.Dome(c, 2 * s, 9 * s, RGB(170, 140, 255), 1.4, FF, 0.2, 1)
	X.Tex(c, "Star", RGB(220, 200, 255), s, 14, { Size = 1.2, Speed = 6, Life = 2.4, Glow = 1, Grav = 1, Rot = 40 })
	X.Tex(c, "Spore", RGB(160, 255, 235), s, 10, { Size = 2, Speed = 4, Life = 2.4, Glow = 0.6, Grav = 1 })
end)
-- Storm Frog
def("TongueLash", function(c, g, s, d)
	jaws(c, X.Horizontal(d), 3 * s, 1 * s, RGB(255, 120, 160), RGB(255, 200, 220))
	X.Tex(c, "Bubble", RGB(170, 235, 255), s, 8, { Size = 1, Speed = 10, Life = 1.2, Grav = -4 })
end)
def("ThunderCroak", function(c, g, s, d)
	for k = 0, 2 do
		after(k * 0.1, function()
			X.Ring(groundCF(g + Vector3.new(0, k * 1.2 * s, 0)), 1, (8 + k * 3) * s, 0.8 * s, 0.5 * s, k == 1 and W or RGB(120, 220, 255), 0.5)
		end)
	end
	skyBolts(g, 2, RGB(150, 220, 255), 0.8 * s)
	crackle(c, RGB(160, 225, 255), s, 8)
end)
-- Crystal Scuttler
def("PincerSnap", function(c, g, s, d)
	jaws(c, X.Horizontal(d), 4 * s, 1.6 * s, RGB(255, 120, 210), W)
	X.Tex(c, "Claw", RGB(255, 170, 230), s, 1, { Size = 7, Speed = 0.1, Life = 0.4, Glow = 1, Bright = 5, Rot = 0 })
	X.Crystals(c, 5, 4 * s, 0.6 * s, RGB(255, 150, 220), W, GLASS, X.Sphere(0.4))
end)
def("CrystalSting", function(c, g, s, d)
	X.Crystals(c, 6, 6 * s, 0.5 * s, RGB(255, 140, 220), W, GLASS, X.Sphere(0.2, d))
	X.Tex(c, "Star", RGB(255, 180, 230), s, 8, { Size = 1.4, Speed = 20, Life = 0.9, Glow = 1 })
end)
-- Lava Salamander
def("FlameDash", function(c, g, s, d)
	local fwd = X.Horizontal(d)
	for k = 0, 3 do
		after(k * 0.05, function()
			X.Tex(g + fwd * (k - 2) * 2.5 * s + Vector3.new(0, 1, 0), "FireFlip", RGB(255, 90, 30), s, 5, { Size = 4, Speed = 10, Life = 0.8, Glow = 0.9, Grav = -12 })
		end)
	end
	fireball(c, RGB(255, 80, 30), RGB(120, 0, 0), 0.7 * s, 3)
end)
def("EmberSpit", function(c, g, s, d)
	fireball(c, RGB(255, 140, 40), RGB(140, 20, 0), 0.6 * s, 3)
	X.Motes(c, RGB(255, 170, 60), s, 16, 16, -6, 1.2)
	X.Tex(g, "Ink", RGB(40, 15, 10), s, 1, { Size = 6, Life = 2.5, Glow = 0, Flat = true, Rot = 0 })
end)
-- Tide Octopus
def("InkCloud", function(c, g, s, d)
	X.Tex(c, "SmokeFlip", RGB(40, 15, 60), 1.6 * s, 12, { Size = 9, Size1 = 14, Speed = 6, Life = 2.4, Glow = 0, Grav = -2 })
	X.Tex(g, "Ink", RGB(20, 5, 35), s, 1, { Size = 16, Size1 = 18, Life = 3.5, Glow = 0, Flat = true, Rot = 0 })
end)
def("TentacleSlam", function(c, g, s, d)
	X.Tentacles(c, 4, 9 * s, 1.2 * s, RGB(150, 70, 230), RGB(40, 10, 60), 0.9)
	X.Tex(g + Vector3.new(0, 2 * s, 0), "Splash", RGB(170, 120, 255), s, 2, { Size = 11, Speed = 0.1, Life = 0.6, Glow = 0.6, Rot = 0 })
	X.Ring(groundCF(g), 1, 10 * s, 1 * s, 0.7 * s, RGB(150, 80, 230), 0.5)
	X.Shake(c, s)
end)
-- ===== boss abilities =====
def("PillarRise", function(c, g, s, d)
	X.Pillars(g, 6, 3 * s, 10 * s, 2.4 * s, RGB(215, 165, 105), SAND, 1.2)
	X.Column(g, 30 * s, 4 * s, RGB(255, 210, 110), 0.7)
	X.Tex(c, "Rock", RGB(210, 165, 110), s, 14, { Size = 1.8, Speed = 30, Life = 1.4, Grav = 50 })
	X.Shake(c, 1.4 * s)
end, true)
def("RidgeShockwave", function(c, g, s, d)
	local fwd = X.Horizontal(d)
	for k = 0, 5 do
		after(k * 0.05, function()
			local at = g + fwd * (k - 2) * 3 * s
			X.Pillars(at, 2, 1 * s, 5 * s, 1.6 * s, RGB(200, 155, 100), SAND, 0.6)
			X.Dust(at, RGB(220, 190, 140), 0.6 * s, 8)
		end)
	end
	X.Shake(c, 1.3 * s)
end, true)
def("AvalancheSweep", function(c, g, s, d)
	X.Smoke(c, RGB(245, 250, 255), 1.5 * s, 14, 2, 1.4)
	X.Rocks(c, 8, 1.6 * s, RGB(220, 240, 255), ICE, 24 * s, X.Sphere(0.6, d))
	X.Tex(c, "Snowflake", W, s, 16, { Size = 1.8, Speed = 24, Life = 1.8, Glow = 0.7, Grav = 6 })
	X.Shake(c, 1.2 * s)
end, true)
def("IceRing", function(c, g, s, d)
	X.Pillars(g, 10, 7 * s, 7 * s, 2 * s, RGB(170, 225, 255), ICE, 1.2)
	X.Dome(c, 2 * s, 12 * s, RGB(160, 220, 255), 0.7, FF, 0.1, 1)
	X.Tex(g, "Snowflake", RGB(200, 240, 255), s, 1, { Size = 26, Size1 = 30, Life = 1.6, Glow = 0.9, Flat = true, Rot = 30 })
end, true)
def("SporeDoubles", function(c, g, s, d)
	X.Tex(g, "Rune", RGB(255, 130, 220), s, 1, { Size = 16, Size1 = 18, Life = 1.6, Glow = 1, Bright = 4, Flat = true, Rot = 60 })
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2
		blob(g + Vector3.new(math.cos(a) * 6 * s, 3 * s, math.sin(a) * 6 * s), Vector3.new(2, 2, 2) * s, Vector3.new(8, 7, 8) * s, RGB(255, 140, 220), NEON, 0.2, 0.8)
	end
end, true)
def("RootSnare", function(c, g, s, d)
	X.Tentacles(g + Vector3.new(0, 0.4, 0), 8, 6 * s, 1 * s, RGB(130, 95, 60), RGB(255, 150, 230), 1.6)
	X.Tex(g, "Rune", RGB(255, 140, 220), s, 1, { Size = 12, Size1 = 13, Life = 1.8, Glow = 0.9, Flat = true, Rot = 40 })
	X.Tex(c, "Leaf", RGB(150, 210, 90), s, 10, { Size = 1.4, Speed = 14, Life = 1.4, Grav = 6 })
end, true)
def("ThunderWave", function(c, g, s, d)
	for k = 0, 2 do
		after(k * 0.1, function()
			X.Ring(groundCF(g), 2, (14 + k * 7) * s, 1.4 * s, 1 * s, k == 1 and W or RGB(140, 210, 255), 0.6)
		end)
	end
	skyBolts(g, 5, RGB(160, 220, 255), s)
	crackle(c, RGB(170, 225, 255), 1.3 * s, 14)
	X.Shake(c, 1.6 * s)
end, true)
def("TongueSweep", function(c, g, s, d)
	X.Arc(c, Y, X.Horizontal(d), 10 * s, 3 * s, RGB(255, 110, 150), 0.5, 3, { Sweep = math.pi * 0.9, Tip = RGB(255, 200, 220), R0 = 0.9 })
	X.Tex(c, "Bubble", RGB(170, 235, 255), s, 12, { Size = 1.4, Speed = 14, Life = 1.4, Grav = -4 })
end, true)
def("ShardBarrage", function(c, g, s, d)
	X.Crystals(c, 7, 7 * s, 0.6 * s, RGB(150, 200, 255), W, GLASS, X.Sphere(0.3, d), { Color2 = RGB(210, 160, 255) })
	for _, col in { RGB(255, 80, 80), RGB(255, 220, 60), RGB(80, 255, 140), RGB(100, 170, 255) } do
		X.Tex(c, "Star", col, s, 3, { Size = 1.5, Speed = 20, Life = 0.9, Glow = 1, Bright = 5 })
	end
end, true)
def("CrystalWalls", function(c, g, s, d)
	local fwd = X.Horizontal(d)
	for k = 0, 4 do
		after(k * 0.05, function()
			X.Pillars(g + fwd * (k - 2) * 3 * s, 2, 1 * s, 8 * s, 1.4 * s, k % 2 == 0 and RGB(150, 200, 255) or RGB(210, 170, 255), GLASS, 1)
		end)
	end
	X.Tex(c, "Star", W, s, 12, { Size = 1.6, Speed = 22, Life = 1, Glow = 1 })
end, true)
def("LavaLanes", function(c, g, s, d)
	X.Fissures(g, 4, 10 * s, RGB(255, 100, 20), s, 1.6)
	X.Column(g, 24 * s, 4 * s, RGB(255, 110, 20), 0.7)
	fireball(c, RGB(255, 120, 30), RGB(130, 10, 0), s, 4)
end, true)
def("CraterStomp", function(c, g, s, d)
	X.Fissures(g, 10, 16 * s, RGB(255, 110, 20), 1.2 * s, 2)
	X.Ring(groundCF(g), 2, 22 * s, 2.5 * s, 1.8 * s, RGB(55, 40, 40), 0.9, { Mat = BASALT, Segs = 28 })
	fireball(c, RGB(255, 130, 40), RGB(130, 10, 0), 1.6 * s, 8)
	X.Tex(g, "Wave", RGB(255, 150, 80), s, 1, { Size = 40, Size1 = 48, Life = 0.8, Glow = 0.8, Flat = true, Rot = 0 })
	X.Meteors(g, 4, RGB(255, 120, 30), s)
	X.Shake(c, 2 * s)
end, true)
def("TideWall", function(c, g, s, d)
	X.Ring(facing(g + Vector3.new(0, 3 * s, 0), X.Horizontal(d)), 2, 10 * s, 2 * s, 5 * s, RGB(80, 170, 255), 0.7, { Mat = GLASS, Alpha = 0.15, Color2 = RGB(160, 225, 255) })
	X.Tex(g + Vector3.new(0, 3 * s, 0), "Splash", RGB(170, 225, 255), 1.4 * s, 4, { Size = 12, Speed = 0.1, Life = 0.7, Glow = 0.6, Rot = 0 })
	X.Motes(c, RGB(170, 225, 255), 1.3 * s, 40, 30, 80, 1.2)
	X.Shake(c, 1.4 * s)
end, true)
def("InkSweep", function(c, g, s, d)
	X.Arc(c, Y, X.Horizontal(d), 11 * s, 3 * s, RGB(50, 20, 80), 0.55, 2.4, { Sweep = math.pi * 0.8, Tip = RGB(140, 80, 220), R0 = 0.8, Glow = 0.2 })
	X.Tex(g, "Ink", RGB(15, 10, 35), s, 1, { Size = 18, Size1 = 20, Life = 3, Glow = 0, Flat = true, Rot = 0 })
	X.Tex(c, "Ink", RGB(40, 15, 70), s, 10, { Size = 2.6, Speed = 22, Life = 1, Grav = 30 })
end, true)

-- abilities that never hit anyone show their effect on the caster when cast
HitFx.CastFx = { ShellBastion = true, SproutSquad = true, BrambleWall = true, AshPuff = true, InkCloud = true, SporeDoubles = true, VortexPull = true }

-- element fallbacks (ability hits whose caster is unknown)
local ELEMENT_STYLE = {
	Fire = "Smoldlet", Ice = "Frostback", Crystal = "Prismaw", Electric = "Voltwraith", Spore = "Capstride",
	Water = "Skyfin", Wind = "Puffhorn", Earth = "Mossgrave", Slash = "Red",
}

------------------------------------------------------------------------
-- pets: element palette x attack kind (+ an element accent)
------------------------------------------------------------------------
local PAL = {
	Earth = { RGB(230, 180, 90), RGB(90, 60, 30) }, Ice = { RGB(160, 225, 255), RGB(40, 100, 180) },
	Spore = { RGB(240, 120, 220), RGB(110, 40, 140) }, Electric = { RGB(140, 190, 255), RGB(70, 60, 220) },
	Crystal = { RGB(170, 150, 255), RGB(90, 50, 200) }, Fire = { RGB(255, 120, 40), RGB(120, 20, 0) },
	Water = { RGB(70, 180, 255), RGB(10, 60, 150) }, Wind = { RGB(200, 240, 255), RGB(90, 160, 200) },
}
local ACCENT = {
	Earth = function(c, g, s) X.Rocks(c, 5, 1 * s, RGB(150, 120, 90), SLATE, 22 * s, X.Sphere(0.8)) X.Tex(c, "Leaf", RGB(150, 210, 90), s, 8, { Size = 1.4, Speed = 16, Life = 1.6, Grav = 6, Drag = 3 }) end,
	Ice = function(c, g, s) X.Crystals(c, 6, 5 * s, 0.6 * s, RGB(180, 230, 255), W, ICE, X.Sphere(0.4)) end,
	Spore = function(c, g, s) X.Tex(c, "Spore", RGB(240, 160, 230), s, 6, { Size = 2, Speed = 10, Life = 1.6, Glow = 0.4, Grav = -2 }) X.Motes(c, W, s, 14, 10, -3, 1.6) end,
	Electric = function(c, g, s) bolts(c, 3, 7 * s, RGB(180, 210, 255), 0.25 * s, X.Sphere(0.2)) crackle(c, RGB(180, 210, 255), 0.6 * s, 4) end,
	Crystal = function(c, g, s) X.Crystals(c, 6, 5 * s, 0.6 * s, RGB(190, 160, 255), W, GLASS, X.Sphere(0.3)) end,
	Fire = function(c, g, s) X.Motes(c, RGB(255, 160, 60), s, 20, 16, -8, 1.5) fireball(c, RGB(255, 140, 50), RGB(140, 20, 0), 0.5 * s, 2) end,
	Water = function(c, g, s) X.Motes(c, RGB(160, 220, 255), s, 22, 20, 70, 1) X.Tex(c, "Bubble", RGB(170, 230, 255), s, 8, { Size = 1.2, Speed = 10, Life = 1.4, Grav = -5 }) end,
	Wind = function(c, g, s) X.Arc(c, Vector3.yAxis, Vector3.xAxis, 5 * s, 1 * s, W, 0.5, 4) end,
}
local KIND = {
	Bite = function(c, g, s, d, m, k)
		jaws(c, X.Horizontal(d), 4 * s, 1.2 * s, m, W)
		X.Tex(c, "Claw", m:Lerp(W, 0.4), s, 1, { Size = 6, Speed = 0.1, Life = 0.4, Glow = 1, Bright = 5, Rot = 0 })
		after(0.25, function()
			X.Flash(c, m, 0.6 * s, 1)
		end)
	end,
	Bolt = function(c, g, s, d, m, k)
		X.Flash(c, m, 0.7 * s, 2)
		X.Spikes(c, 12, 8 * s, 0.5 * s, m, k, d and X.Fan(X.Horizontal(d), 12, 0.6, 0.15) or X.Sphere(0.3))
		X.Ring(facing(c, X.Horizontal(d)), 0.5, 6 * s, 0.6 * s, 0.4 * s, m, 0.4)
	end,
	Lob = function(c, g, s, d, m, k)
		X.Meteors(g, 1, m, s)
		after(0.35, function()
			X.Fissures(g, 4, 6 * s, m, 0.7 * s, 1)
		end)
	end,
	Pulse = function(c, g, s, d, m, k)
		X.Ring(groundCF(g), 1, 10 * s, 0.9 * s, 0.5 * s, m, 0.5)
		after(0.1, function()
			X.Ring(groundCF(g), 1, 7 * s, 0.7 * s, 0.4 * s, W, 0.45)
		end)
		X.Dome(c, 1 * s, 7 * s, m, 0.5, FF, 0.1, 1)
	end,
	Chain = function(c, g, s, d, m, k)
		X.Flash(c, m, 0.6 * s, 1)
		bolts(c, 5, 8 * s, W:Lerp(m, 0.4), 0.3 * s, X.Sphere(0.2))
	end,
	Mend = function(c, g, s, d, m, k)
		X.Helix(g, 8 * s, 2.5 * s, m, 2, 5, 1, 0.8 * s)
	end,
}
local BIOME_ELEMENT = { Plateau = "Earth", Mountains = "Ice", Mushroom = "Spore", Marsh = "Electric", Canyon = "Crystal", Volcanic = "Fire", Coast = "Water" }
local function petStyleFor(el: string, kind: string?): string
	local name = "Pet" .. el .. (kind or "")
	if not S[name] then
		local pal = PAL[el] or PAL.Wind
		def(name, function(c, g, s, d)
			local f = KIND[kind or ""] or KIND.Bolt
			f(c, g, s, d, pal[1], pal[2])
			local acc = ACCENT[el]
			if acc then
				acc(c, g, s)
			end
		end)
	end
	return name
end
function HitFx.PetStyle(biome: string?, kind: string?): string
	return petStyleFor(BIOME_ELEMENT[biome or ""] or "Wind", kind)
end

HitFx.Styles = S

------------------------------------------------------------------------
-- public
------------------------------------------------------------------------
local ELEMENT_OF_COLOR = {
	{ RGB(255, 120, 40), "Fire" }, { RGB(170, 235, 255), "Ice" }, { RGB(150, 200, 255), "Crystal" }, { RGB(140, 170, 255), "Electric" },
	{ RGB(230, 120, 255), "Spore" }, { RGB(70, 170, 255), "Water" }, { RGB(220, 255, 235), "Wind" }, { RGB(230, 180, 100), "Earth" },
}
function HitFx.StyleForColor(col: Color3): string
	local best, bd = "Fire", math.huge
	for _, e in ELEMENT_OF_COLOR do
		local dd = (e[1].R - col.R) ^ 2 + (e[1].G - col.G) ^ 2 + (e[1].B - col.B) ^ 2
		if dd < bd then
			best, bd = e[2], dd
		end
	end
	return best
end

local function resolve(style: string)
	if S[style] then
		return S[style]
	end
	if string.sub(style, 1, 3) == "Pet" then
		for el in PAL do
			if string.sub(style, 4, 3 + #el) == el then
				return S[petStyleFor(el, string.sub(style, 4 + #el))]
			end
		end
	end
	local alias = ELEMENT_STYLE[style]
	if alias then
		return S[alias]
	end
	local Sfx = require(script.Parent:WaitForChild("Sfx"))
	return S[ELEMENT_STYLE[Sfx.ElementOf(style)] or "Red"]
end

function HitFx.Build(style: string, pos: Vector3, scale: number?, dir: Vector3?)
	local entry = resolve(style)
	if not entry then
		return
	end
	local s = math.clamp(scale or 1, 0.25, 4)
	local g = L.Ground(pos)
	local c = pos
	if (pos - g).Magnitude < 1.5 then
		c = g + Vector3.new(0, 2.5 * s, 0)
	end
	entry.Fn(c, g, s, dir)
end

local remote: RemoteEvent?
local function getRemote(): RemoteEvent?
	if remote and remote.Parent then
		return remote
	end
	remote = ReplicatedStorage:FindFirstChild("HitFxPlay") :: RemoteEvent?
	if not remote and RunService:IsServer() then
		local r = Instance.new("RemoteEvent")
		r.Name = "HitFxPlay"
		r.Parent = ReplicatedStorage
		remote = r
	end
	return remote
end

function HitFx.Play(style: string, pos: Vector3, scale: number?, dir: Vector3?)
	if RunService:IsServer() then
		local r = getRemote()
		if r then
			r:FireAllClients(style, pos, scale or 1, dir)
		end
	else
		HitFx.Build(style, pos, scale, dir)
	end
end

function HitFx.Listen()
	task.spawn(function()
		local r = ReplicatedStorage:WaitForChild("HitFxPlay", 120) :: RemoteEvent?
		if not r then
			return
		end
		r.OnClientEvent:Connect(function(style, pos, scale, dir)
			local cam = workspace.CurrentCamera
			if typeof(pos) ~= "Vector3" or type(style) ~= "string" or (cam and (cam.CFrame.Position - pos).Magnitude > 450) then
				return
			end
			local ok, err = pcall(HitFx.Build, style, pos, scale, typeof(dir) == "Vector3" and dir or nil)
			if not ok then
				warn("[HitFx] " .. tostring(err))
			end
		end)
	end)
end

return HitFx
