-- v2.23 SIGNATURE HIT VFX (director: "every character gets its own hit
-- effect, at the same detail as the red showcase explosion").
--
-- One engine, many RECIPES. A recipe says which layers a hit has:
--   colours (Core / Main / Deep), implosion, star flares, dark splatter,
--   SPIKES of a kind:
--     Beam   tapered 3D light spikes (the showcase look)
--     Shard  solid crystal / ice prisms shooting out
--     Bolt   crackling lightning branches
--     Arc    curved wind / water slash arcs spinning outwards
--     Drop   water crown splash + droplets
--     Rock   chunky rocks flung with gravity
--     Spore  puffing spore cloud + drifting motes
--     Feather feathers / petals fluttering down
--   sparks, debris, ground (ring, scorch, dust), plume (smoke, embers),
--   EXTRAS: Pillars (ground spikes rising), Tornado, Geyser, Bubbles,
--           SkyBolts, Swirl, Ink.
--
-- HitFx.Play(style, pos, scale?, dir?, color?)
--   server: tells every client to build it (smooth + cheap for the server)
--   client: builds it now
-- Styles: monster type names (Prismaw...), "Pet<Element><Kind>", "Player*",
-- or element names (Fire, Ice...). Unknown styles fall back by element.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local FxKit = require(script.Parent:WaitForChild("FxKit"))
local L = FxKit.Lib
local tex, ns, emitter, emitNow, anchor, light = L.Tex, L.NS, L.Emitter, L.EmitNow, L.Anchor, L.Light

local HitFx = {}

local RGB = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

------------------------------------------------------------------------
-- recipes
------------------------------------------------------------------------
local function merge(base, over)
	local t = table.clone(base)
	for k, v in over or {} do
		t[k] = v
	end
	return t
end

-- element bases (every character starts from one and changes it)
local E = {}
E.Fire = {
	Core = RGB(255, 240, 200), Main = RGB(255, 110, 30), Deep = RGB(120, 20, 0), Implode = true, Flare = 2, Splat = true,
	Spikes = { Kind = "Beam", N = 34, Len = 13, Width = 1.1, Up = 0.35 },
	Sparks = { N = 60, Speed = 90, Grav = 60 }, Debris = { Tex = "Glow", N = 20, Color = RGB(255, 170, 60), Grav = -10, Speed = 30 },
	Ground = { Ring = true, Scorch = "Spikes", Dust = RGB(90, 40, 20) }, Plume = { Smoke = RGB(60, 30, 25), Embers = RGB(255, 150, 50) },
}
E.Ice = {
	Core = RGB(240, 252, 255), Main = RGB(140, 220, 255), Deep = RGB(40, 100, 180), Implode = true, Flare = 2,
	Spikes = { Kind = "Shard", N = 16, Len = 8, Width = 1, Up = 0.4, Mat = "Ice" },
	Sparks = { N = 40, Speed = 70, Grav = 50 }, Debris = { Tex = "Shard", N = 30, Color = RGB(220, 245, 255), Grav = 80, Speed = 35 },
	Ground = { Ring = true, Scorch = "Crackle", Dust = RGB(230, 245, 255) }, Plume = { Smoke = RGB(220, 240, 255) },
	Extra = { "Pillars" }, PillarMat = "Ice",
}
E.Crystal = {
	Core = WHITE, Main = RGB(150, 190, 255), Deep = RGB(110, 60, 230), Implode = true, Flare = 2,
	Spikes = { Kind = "Shard", N = 18, Len = 9, Width = 0.9, Up = 0.3, Mat = "Glass" },
	Sparks = { N = 55, Speed = 85, Grav = 30 }, Debris = { Tex = "Shard", N = 26, Color = RGB(200, 170, 255), Grav = 60, Speed = 40 },
	Ground = { Ring = true, Scorch = "Ring", Dust = RGB(190, 180, 255) }, Plume = { Embers = RGB(190, 220, 255) },
}
E.Electric = {
	Core = WHITE, Main = RGB(130, 190, 255), Deep = RGB(70, 60, 220), Flare = 2,
	Spikes = { Kind = "Bolt", N = 7, Len = 14, Width = 0.35, Up = 0.2 },
	Sparks = { N = 70, Speed = 110, Grav = 20 }, Debris = { Tex = "Glow", N = 24, Color = RGB(200, 230, 255), Grav = 0, Speed = 40 },
	Ground = { Ring = true, Scorch = "Crackle", Dust = RGB(120, 140, 200) }, Plume = { Embers = RGB(180, 220, 255) },
}
E.Spore = {
	Core = RGB(255, 235, 250), Main = RGB(235, 110, 220), Deep = RGB(110, 40, 140), Flare = 1,
	Spikes = { Kind = "Spore", N = 26, Len = 8, Width = 1, Up = 0.5 },
	Sparks = { N = 20, Speed = 40, Grav = -5 }, Debris = { Tex = "Glow", N = 40, Color = RGB(255, 190, 245), Grav = -6, Speed = 14 },
	Ground = { Ring = true, Scorch = "Smoke", Dust = RGB(200, 150, 210) }, Plume = { Smoke = RGB(200, 140, 210) },
}
E.Water = {
	Core = RGB(235, 250, 255), Main = RGB(60, 170, 255), Deep = RGB(10, 60, 150), Flare = 1,
	Spikes = { Kind = "Drop", N = 18, Len = 9, Width = 0.8, Up = 0.8 },
	Sparks = { N = 30, Speed = 60, Grav = 80 }, Debris = { Tex = "Glow", N = 50, Color = RGB(170, 225, 255), Grav = 90, Speed = 40 },
	Ground = { Ring = true, Scorch = "Ring", Dust = RGB(200, 235, 255) }, Plume = { Smoke = RGB(220, 240, 255) },
}
E.Wind = {
	Core = WHITE, Main = RGB(190, 240, 255), Deep = RGB(90, 160, 200), Flare = 1,
	Spikes = { Kind = "Arc", N = 8, Len = 7, Width = 1.2, Up = 0.2 },
	Sparks = { N = 30, Speed = 70, Grav = 0 }, Debris = { Tex = "Smoke", N = 14, Color = RGB(240, 250, 255), Grav = -2, Speed = 30 },
	Ground = { Ring = true, Dust = RGB(235, 245, 255) }, Extra = { "Swirl" },
}
E.Earth = {
	Core = RGB(255, 240, 210), Main = RGB(230, 170, 90), Deep = RGB(90, 60, 30), Flare = 1, Splat = true,
	Spikes = { Kind = "Rock", N = 14, Len = 8, Width = 1.4, Up = 0.7, Mat = "Slate", Color = RGB(150, 120, 90) },
	Sparks = { N = 30, Speed = 60, Grav = 70 }, Debris = { Tex = "Smoke", N = 16, Color = RGB(170, 140, 110), Grav = 10, Speed = 25 },
	Ground = { Ring = true, Scorch = "Crackle", Dust = RGB(170, 140, 100) }, Plume = { Smoke = RGB(140, 115, 90) },
	Extra = { "Pillars" }, PillarMat = "Slate",
}
E.Slash = merge(E.Fire, { Main = RGB(255, 60, 60), Deep = RGB(80, 0, 10), Extra = nil })
HitFx.Elements = E

-- every character (monster type name) gets its own recipe
local S = {}
-- Canyon (crystal)
S.Prismaw = merge(E.Crystal, { Main = RGB(120, 220, 255), Deep = RGB(60, 120, 255), Spikes = { Kind = "Shard", N = 12, Len = 10, Width = 0.6, Up = 0.1, Mat = "Glass" }, Flare = 2 })
S.Shardstorm = merge(E.Crystal, { Main = RGB(190, 150, 255), Spikes = { Kind = "Shard", N = 22, Len = 7, Width = 0.7, Up = 0.2, Mat = "Glass" }, Extra = { "Tornado" } })
S.Geoscuttle = merge(E.Crystal, { Main = RGB(255, 140, 220), Deep = RGB(150, 40, 160), Spikes = { Kind = "Shard", N = 10, Len = 6, Width = 1.2, Up = 0.6, Mat = "Glass" }, Extra = { "Pillars" }, PillarMat = "Glass" })
-- Mountains (ice)
S.Frostback = merge(E.Ice, { Spikes = { Kind = "Shard", N = 10, Len = 7, Width = 1.5, Up = 0.8, Mat = "Ice" }, Extra = { "Pillars" } })
S.Snowpeck = merge(E.Ice, { Main = RGB(230, 245, 255), Spikes = { Kind = "Feather", N = 26, Len = 8, Width = 1, Up = 0.3 }, Extra = { "Swirl" } })
S.Rubbleye = merge(E.Earth, { Main = RGB(200, 120, 255), Deep = RGB(60, 20, 90), Core = RGB(245, 220, 255), Implode = true,
	Spikes = { Kind = "Rock", N = 12, Len = 9, Width = 1.3, Up = 0.4, Mat = "Slate", Color = RGB(110, 100, 120) }, Extra = { "Swirl" } })
-- Marsh (storm)
S.Voltwraith = merge(E.Electric, { Main = RGB(170, 140, 255), Deep = RGB(90, 30, 200), Spikes = { Kind = "Bolt", N = 9, Len = 16, Width = 0.3, Up = 0 }, Extra = { "SkyBolts" } })
S.Gulpvine = merge(E.Electric, { Main = RGB(140, 255, 160), Deep = RGB(30, 120, 60), Spikes = { Kind = "Bolt", N = 6, Len = 11, Width = 0.35, Up = 0.3 }, Plume = { Smoke = RGB(80, 120, 70) } })
S.Croakle = merge(E.Electric, { Main = RGB(120, 220, 255), Spikes = { Kind = "Bolt", N = 6, Len = 12, Width = 0.4, Up = 0.4 }, Extra = { "Bubbles" } })
S.Gnashgut = merge(E.Water, { Main = RGB(150, 230, 80), Deep = RGB(40, 90, 20), Core = RGB(230, 255, 200), Splat = true,
	Spikes = { Kind = "Drop", N = 16, Len = 8, Width = 1, Up = 0.6 }, Ground = { Ring = true, Scorch = "Spikes", Dust = RGB(120, 160, 60) } })
-- Volcanic (fire)
S.Cindermaw = merge(E.Fire, { Spikes = { Kind = "Beam", N = 44, Len = 16, Width = 1.3, Up = 0.5 }, Extra = { "Geyser" } })
S.Smoldlet = merge(E.Fire, { Main = RGB(255, 160, 40), Spikes = { Kind = "Beam", N = 26, Len = 9, Width = 1, Up = 0.4 }, Plume = { Smoke = RGB(50, 45, 45), Embers = RGB(255, 180, 70) } })
S.Scorchtail = merge(E.Fire, { Main = RGB(255, 80, 30), Deep = RGB(140, 0, 0), Spikes = { Kind = "Beam", N = 30, Len = 12, Width = 0.8, Up = 0.1 }, Extra = { "Tornado" } })
-- Mushroom (spore)
S.Capstride = merge(E.Spore, { Main = RGB(255, 120, 150), Spikes = { Kind = "Spore", N = 30, Len = 9, Width = 1.2, Up = 0.6 } })
S.Sporeback = merge(E.Spore, { Main = RGB(200, 255, 120), Deep = RGB(60, 120, 30), Spikes = { Kind = "Beam", N = 28, Len = 9, Width = 0.5, Up = 0.4 }, Extra = { "Pillars" }, PillarMat = "Grass" })
S.Glowmoth = merge(E.Spore, { Main = RGB(140, 255, 230), Deep = RGB(40, 120, 140), Spikes = { Kind = "Feather", N = 30, Len = 8, Width = 0.8, Up = 0.4 }, Extra = { "Swirl" } })
-- Plateau (earth)
S.Bristlehulk = merge(E.Earth, { Main = RGB(140, 220, 90), Deep = RGB(70, 50, 20), Spikes = { Kind = "Beam", N = 30, Len = 10, Width = 0.7, Up = 0.5 }, Extra = { "Pillars" }, PillarMat = "Wood" })
S.Mossgrave = merge(E.Earth, { Main = RGB(130, 200, 90), Spikes = { Kind = "Rock", N = 16, Len = 10, Width = 1.8, Up = 0.8, Mat = "Slate", Color = RGB(100, 120, 80) } })
S.Puffhorn = merge(E.Wind, { Main = RGB(255, 250, 220), Spikes = { Kind = "Arc", N = 10, Len = 8, Width = 1.6, Up = 0.4 }, Extra = { "SkyBolts" } })
-- Coast (water)
S.Skyfin = merge(E.Water, { Spikes = { Kind = "Arc", N = 8, Len = 9, Width = 1.4, Up = 0.2 }, Extra = { "Bubbles" } })
S.Octoblob = merge(E.Water, { Main = RGB(150, 80, 230), Deep = RGB(30, 10, 50), Splat = true, Extra = { "Ink" } })
-- bosses: bigger, every layer turned up, plus their own signature extra
S.MesaColossus = merge(E.Earth, { Main = RGB(255, 200, 110), Spikes = { Kind = "Rock", N = 22, Len = 14, Width = 2.2, Up = 0.8, Mat = "Sandstone", Color = RGB(210, 160, 100) }, Extra = { "Pillars", "Geyser" }, PillarMat = "Sandstone", Boss = true })
S.FrostpeakWarden = merge(E.Ice, { Spikes = { Kind = "Shard", N = 22, Len = 12, Width = 1.6, Up = 0.6, Mat = "Ice" }, Extra = { "Pillars", "Swirl" }, Boss = true })
S.MyceliumMonarch = merge(E.Spore, { Main = RGB(255, 150, 230), Spikes = { Kind = "Spore", N = 40, Len = 12, Width = 1.6, Up = 0.6 }, Extra = { "Pillars", "Swirl" }, PillarMat = "Grass", Boss = true })
S.BogstormCroaker = merge(E.Electric, { Spikes = { Kind = "Bolt", N = 12, Len = 20, Width = 0.5, Up = 0.2 }, Extra = { "SkyBolts", "Bubbles" }, Boss = true })
S.PrismSovereign = merge(E.Crystal, { Spikes = { Kind = "Shard", N = 26, Len = 13, Width = 1.1, Up = 0.3, Mat = "Glass" }, Extra = { "Pillars", "Tornado" }, PillarMat = "Glass", Boss = true })
S.CalderaTitan = merge(E.Fire, { Spikes = { Kind = "Beam", N = 60, Len = 22, Width = 1.8, Up = 0.6 }, Extra = { "Geyser", "Pillars" }, PillarMat = "Basalt", Boss = true })
S.Tidebreaker = merge(E.Water, { Spikes = { Kind = "Drop", N = 26, Len = 14, Width = 1.3, Up = 0.9 }, Extra = { "Ink", "Bubbles", "Swirl" }, Boss = true })
-- minions
S.Shroomling = merge(E.Spore, { Spikes = { Kind = "Spore", N = 14, Len = 5, Width = 0.8, Up = 0.5 } })
-- the player (cloud wind) and the showcase red
S.PlayerPunch = merge(E.Wind, { Main = RGB(200, 235, 255), Spikes = { Kind = "Arc", N = 5, Len = 6, Width = 1.2, Up = 0 }, Extra = nil })
S.PlayerSlam = merge(E.Wind, { Spikes = { Kind = "Arc", N = 10, Len = 10, Width = 1.6, Up = 0.1 }, Extra = { "Swirl" }, Splat = false })
S.PlayerPuff = merge(E.Wind, { Spikes = { Kind = "Spore", N = 14, Len = 6, Width = 1.2, Up = 0.3 }, Extra = nil, Main = RGB(245, 250, 255) })
S.Red = merge(E.Fire, { Main = RGB(255, 45, 35), Deep = RGB(45, 0, 5), Spikes = { Kind = "Beam", N = 56, Len = 14, Width = 1.2, Up = 0.3 }, Extra = nil, Plume = { Smoke = RGB(110, 20, 20), Embers = RGB(255, 120, 90) } })
HitFx.Styles = S

-- pets: element of their egg's biome + attack kind
local BIOME_ELEMENT = { Plateau = "Earth", Mountains = "Ice", Mushroom = "Spore", Marsh = "Electric", Canyon = "Crystal", Volcanic = "Fire", Coast = "Water" }
local KIND_SPIKE = { Bite = "Beam", Bolt = nil, Lob = "Rock", Pulse = "Arc", Chain = "Bolt", Mend = "Spore" }
local function petStyleFor(el: string, kind: string?): string
	local name = "Pet" .. el .. (kind or "")
	if not S[name] then
		local base = E[el]
		local over = { Implode = false, Extra = nil }
		local k = KIND_SPIKE[kind or ""]
		if k then
			over.Spikes = merge(base.Spikes, { Kind = k, N = math.floor(base.Spikes.N * 0.6), Len = base.Spikes.Len * 0.75 })
		end
		if kind == "Lob" then
			over.Extra = { "Pillars" }
		elseif kind == "Pulse" then
			over.Extra = { "Swirl" }
		end
		S[name] = merge(base, over)
	end
	return name
end
function HitFx.PetStyle(biome: string?, kind: string?): string
	return petStyleFor(BIOME_ELEMENT[biome or ""] or "Wind", kind)
end

------------------------------------------------------------------------
-- engine (client)
------------------------------------------------------------------------
local function randDir(up: number, dir: Vector3?): Vector3
	local d = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1 + up, math.random() * 2 - 1)
	if dir then
		d += dir * 1.6
	end
	if d.Magnitude < 0.05 then
		return Vector3.yAxis
	end
	return d.Unit
end

local MATS = {
	Ice = Enum.Material.Ice, Glass = Enum.Material.Glass, Slate = Enum.Material.Slate, Sandstone = Enum.Material.Sandstone,
	Grass = Enum.Material.Grass, Wood = Enum.Material.Wood, Basalt = Enum.Material.Basalt,
}

local function fxPart(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, life: number): BasePart
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Parent = L.Holder()
	Debris:AddItem(p, life)
	return p
end

-- animate a value 0..1 over t seconds with a per-frame callback
local function animate(t: number, step: (number) -> ())
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local f = (os.clock() - t0) / t
		if f >= 1 then
			conn:Disconnect()
			step(1)
			return
		end
		step(f)
	end)
end

local SPIKE = {}
SPIKE.Beam = function(r, a, c, sc, dir)
	local sp = r.Spikes
	for _ = 1, sp.N do
		L.Spike(a, randDir(sp.Up or 0, dir), (sp.Len * (0.5 + math.random() * 0.8)) * sc, (sp.Width * (0.45 + math.random() * 0.8)) * sc,
			r.Main, r.Deep, 0.5, 0.07, 0.05 + math.random() * 0.08, 0.45)
	end
	for _ = 1, math.floor(sp.N * 0.45) do
		L.Spike(a, randDir(sp.Up or 0, dir), (sp.Len * (0.3 + math.random() * 0.4)) * sc, (sp.Width * 0.25) * sc, WHITE, r.Main, 1, 0.05, 0.03, 0.22)
	end
end
SPIKE.Shard = function(r, a, c, sc, dir)
	local sp = r.Spikes
	local mat = MATS[sp.Mat or "Glass"] or Enum.Material.Glass
	for k = 1, sp.N do
		local d = randDir(sp.Up or 0, dir)
		local len = sp.Len * (0.6 + math.random() * 0.7) * sc
		local w = sp.Width * (0.6 + math.random() * 0.6) * sc
		local col = (k % 3 == 0) and r.Deep or r.Main
		local base = CFrame.lookAt(c, c + d) * CFrame.Angles(0, 0, math.rad(45))
		local p = fxPart(Vector3.new(w, w, 0.1), base, col, mat, 1.4)
		p.Transparency = mat == Enum.Material.Glass and 0.15 or 0
		local core = fxPart(Vector3.new(w * 0.35, w * 0.35, 0.1), base, r.Core, Enum.Material.Neon, 1.4)
		local hold = 0.25 + math.random() * 0.2
		animate(0.12, function(f)
			local e = 1 - (1 - f) ^ 3
			local L2 = len * e
			p.Size = Vector3.new(w, w, L2)
			p.CFrame = base * CFrame.new(0, 0, -L2 / 2 - 0.4 * sc)
			core.Size = Vector3.new(w * 0.35, w * 0.35, L2 * 0.9)
			core.CFrame = p.CFrame
		end)
		task.delay(0.12 + hold, function()
			TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Size = Vector3.new(0.05, 0.05, len * 1.1) }):Play()
			TweenService:Create(core, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end)
	end
	SPIKE.Beam(merge(r, { Spikes = merge(sp, { N = math.floor(sp.N * 0.8), Width = sp.Width * 0.5 }) }), a, c, sc, dir)
end
SPIKE.Bolt = function(r, a, c, sc, dir)
	local sp = r.Spikes
	for _ = 1, sp.N do
		local d = randDir(sp.Up or 0, dir)
		FxKit.Lightning(c, c + d * sp.Len * (0.6 + math.random() * 0.6) * sc, r.Main, sp.Width * sc, true)
	end
	task.delay(0.1, function()
		for _ = 1, math.floor(sp.N / 2) do
			local d = randDir(sp.Up or 0, dir)
			FxKit.Lightning(c, c + d * sp.Len * 0.7 * sc, WHITE:Lerp(r.Main, 0.4), sp.Width * 0.7 * sc, true)
		end
	end)
	SPIKE.Beam(merge(r, { Spikes = merge(sp, { N = 14, Len = sp.Len * 0.5, Width = 0.5 }) }), a, c, sc, dir)
end
SPIKE.Arc = function(r, a, c, sc, dir)
	local sp = r.Spikes
	for k = 1, sp.N do
		local n = randDir(0, nil)
		if dir and k % 2 == 0 then
			n = dir:Cross(Vector3.yAxis).Magnitude > 0.1 and dir:Cross(Vector3.yAxis).Unit or n
		end
		local seed = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		local cu = n:Cross(seed)
		local u = cu.Magnitude > 0.01 and cu.Unit or n:Cross(Vector3.xAxis).Unit
		local v = n:Cross(u).Unit
		local R = sp.Len * (0.6 + math.random() * 0.6) * sc
		local spin = (math.random() < 0.5 and -1 or 1) * (6 + math.random() * 6)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = a, a
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Segments = 20
		b.FaceCamera = true
		b.LightEmission, b.LightInfluence = 1, 0
		L.Set(b, "Brightness", 3)
		b.Texture = tex("BeamSoft")
		b.Color = ColorSequence.new(WHITE, r.Main)
		b.Width0, b.Width1 = 0.1 * sc, sp.Width * sc
		b.Parent = a
		local ang0 = math.random() * math.pi * 2
		animate(0.55, function(f)
			if not b.Parent then
				return
			end
			local rr = R * (0.25 + 0.75 * (1 - (1 - f) ^ 2))
			local ang = ang0 + spin * f
			local uu = u * math.cos(ang) + v * math.sin(ang)
			local vv = n:Cross(uu)
			a0.CFrame = CFrame.fromMatrix(uu * rr, vv, n)
			a1.CFrame = CFrame.fromMatrix(vv * rr, -uu, n)
			b.CurveSize0, b.CurveSize1 = rr * 0.552, rr * 0.552
			b.Transparency = ns({ { 0, 1 }, { 0.35, f * 0.9 }, { 1, 0.2 + f * 0.8 } })
			if f >= 1 then
				b:Destroy()
			end
		end)
	end
end
SPIKE.Drop = function(r, a, c, sc, dir)
	local sp = r.Spikes
	-- water crown: arcs leaping up and out, then droplets fall
	for k = 1, sp.N do
		local ang = k / sp.N * math.pi * 2 + math.random() * 0.3
		local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local len = sp.Len * (0.6 + math.random() * 0.6) * sc
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = a, a
		local side = out:Cross(Vector3.yAxis).Unit
		a0.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, side)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Segments = 16
		b.FaceCamera = true
		b.LightEmission, b.LightInfluence = 0.7, 0.2
		L.Set(b, "Brightness", 2)
		b.Texture = tex("BeamSoft")
		b.Color = ColorSequence.new(r.Core, r.Main)
		b.Width0, b.Width1 = sp.Width * sc, 0.15 * sc
		b.Parent = a
		animate(0.6, function(f)
			if not b.Parent then
				return
			end
			local e = 1 - (1 - f) ^ 2
			a1.CFrame = CFrame.fromMatrix(out * len * e - Vector3.new(0, 1.5 * sc * f, 0), Vector3.yAxis, side)
			b.CurveSize0 = len * (sp.Up or 0.8) * (1 - f * 0.5)
			b.CurveSize1 = -len * 0.3
			b.Transparency = ns({ { 0, f * 0.8 }, { 1, 0.3 + f * 0.7 } })
			if f >= 1 then
				b:Destroy()
			end
		end)
	end
	emitNow(emitter(a, {
		Texture = tex("Glow"), Color = ColorSequence.new(r.Core, r.Main), Brightness = 2, LightEmission = 0.6,
		Size = ns({ { 0, 0.7 * sc }, { 1, 0.2 * sc } }), Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(18 * sc, 38 * sc), SpreadAngle = Vector2.new(55, 55), EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -90, 0),
	}), 40)
end
SPIKE.Rock = function(r, a, c, sc, dir)
	local sp = r.Spikes
	local mat = MATS[sp.Mat or "Slate"] or Enum.Material.Slate
	for _ = 1, sp.N do
		local d = randDir(sp.Up or 0.6, dir)
		local w = sp.Width * (0.5 + math.random() * 0.8) * sc
		local p = fxPart(Vector3.new(w, w * (0.7 + math.random() * 0.5), w * (0.7 + math.random() * 0.5)), CFrame.new(c), sp.Color or r.Deep, mat, 1.6)
		local vel = d * (sp.Len * 4 * (0.6 + math.random() * 0.6)) * math.sqrt(sc) + Vector3.new(0, 10, 0)
		local rot = Vector3.new(math.random() * 10 - 5, math.random() * 10 - 5, math.random() * 10 - 5)
		animate(1.1, function(f)
			if not p.Parent then
				return
			end
			local t = f * 1.1
			local pos = c + vel * t + Vector3.new(0, -45 * t * t, 0)
			p.CFrame = CFrame.new(pos) * CFrame.Angles(rot.X * t, rot.Y * t, rot.Z * t)
			if f > 0.7 then
				p.Transparency = (f - 0.7) / 0.3
			end
		end)
	end
	SPIKE.Beam(merge(r, { Spikes = merge(sp, { N = math.floor(sp.N * 1.2), Width = sp.Width * 0.5 }) }), a, c, sc, dir)
end
SPIKE.Spore = function(r, a, c, sc, dir)
	local sp = r.Spikes
	-- puffing cloud of spores + motes drifting up
	emitNow(emitter(a, {
		Texture = tex("Smoke"), Color = ColorSequence.new(r.Main:Lerp(WHITE, 0.3), r.Deep), LightEmission = 0.3, LightInfluence = 0.4,
		Size = ns({ { 0, 2 * sc }, { 0.3, 5 * sc }, { 1, 8 * sc } }), Transparency = ns({ { 0, 0.2 }, { 0.6, 0.45 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(sp.Len * 1.4 * sc, sp.Len * 2.4 * sc), Drag = 3,
		RotSpeed = NumberRange.new(-60, 60), Acceleration = Vector3.new(0, 3, 0),
	}), sp.N)
	emitNow(emitter(a, {
		Texture = tex("Glow"), Color = ColorSequence.new(WHITE, r.Main), Brightness = 3,
		Size = ns({ { 0, 0.5 * sc }, { 0.5, 0.35 * sc }, { 1, 0 } }), Lifetime = NumberRange.new(1.2, 2.4),
		Speed = NumberRange.new(6 * sc, 20 * sc), Drag = 2, Acceleration = Vector3.new(0, 4, 0),
	}), sp.N * 2)
	SPIKE.Beam(merge(r, { Spikes = merge(sp, { N = math.floor(sp.N * 0.5), Width = sp.Width * 0.5 }) }), a, c, sc, dir)
end
SPIKE.Feather = function(r, a, c, sc, dir)
	local sp = r.Spikes
	emitNow(emitter(a, {
		Texture = tex("Shard"), Color = ColorSequence.new(WHITE, r.Main), Brightness = 1.5, LightEmission = 0.4,
		Size = ns({ { 0, 0.9 * sc }, { 1, 0.6 * sc } }), Squash = ns({ { 0, -1.5 }, { 1, -1.5 } }),
		Lifetime = NumberRange.new(1.2, 2.2), Speed = NumberRange.new(sp.Len * 2 * sc, sp.Len * 3.5 * sc), Drag = 4,
		Acceleration = Vector3.new(0, -6, 0), RotSpeed = NumberRange.new(-200, 200),
	}), sp.N)
	SPIKE.Arc(merge(r, { Spikes = merge(sp, { N = 5 }) }), a, c, sc, dir)
end

local EXTRA = {}
EXTRA.Pillars = function(r, g, sc)
	local mat = MATS[r.PillarMat or "Slate"] or Enum.Material.Slate
	local n = r.Boss and 10 or 6
	for k = 1, n do
		local ang = k / n * math.pi * 2 + math.random() * 0.4
		local dist = (3 + math.random() * 4) * sc * (r.Boss and 1.5 or 1)
		local at = g + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		local h = (3 + math.random() * 4) * sc
		local w = (0.8 + math.random() * 0.8) * sc
		local tilt = CFrame.Angles(math.sin(ang) * 0.35, 0, -math.cos(ang) * 0.35)
		local col = (k % 2 == 0) and r.Main or r.Deep:Lerp(r.Main, 0.4)
		if mat == Enum.Material.Slate or mat == Enum.Material.Sandstone or mat == Enum.Material.Basalt or mat == Enum.Material.Wood or mat == Enum.Material.Grass then
			col = (r.Spikes and r.Spikes.Color) or r.Deep:Lerp(RGB(150, 130, 110), 0.5)
		end
		local p = fxPart(Vector3.new(w, h, w), CFrame.new(at - Vector3.new(0, h / 2, 0)) * tilt * CFrame.Angles(0, ang, 0), col, mat, 2.2)
		if mat == Enum.Material.Glass then
			p.Transparency = 0.15
		end
		TweenService:Create(p, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = CFrame.new(at + Vector3.new(0, h * 0.35, 0)) * tilt * CFrame.Angles(0, ang, 0) }):Play()
		task.delay(0.9, function()
			TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(at - Vector3.new(0, h * 0.6, 0)) * tilt, Transparency = 1 }):Play()
		end)
	end
end
EXTRA.Tornado = function(r, g, sc)
	FxKit.Tornado(g, r.Main, 0.8 * sc, 0.9)
end
EXTRA.Geyser = function(r, g, sc)
	FxKit.Pillar(g, r.Main, 26 * sc, 0.8)
	local a = anchor(CFrame.new(g), 2.5, Vector3.new(3 * sc, 0.2, 3 * sc))
	emitNow(emitter(a, {
		Texture = tex("Flame"), Color = FxKit.Hot(r.Main, true), Brightness = 3,
		Shape = Enum.ParticleEmitterShape.Disc, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8),
		Size = ns({ { 0, 2 * sc }, { 0.5, 3 * sc }, { 1, 0.5 * sc } }), Transparency = ns({ { 0, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(30 * sc, 45 * sc),
	}), 40)
end
EXTRA.Bubbles = function(r, g, sc)
	local a = anchor(CFrame.new(g + Vector3.new(0, 1, 0)), 3.5, Vector3.new(6 * sc, 1, 6 * sc))
	emitNow(emitter(a, {
		Texture = tex("Ring"), Color = ColorSequence.new(WHITE, r.Main), Brightness = 2, LightEmission = 0.6,
		Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20),
		Size = ns({ { 0, 0.4 * sc }, { 1, 1.2 * sc } }), Transparency = ns({ { 0, 0.1 }, { 0.85, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1, 2.2), Speed = NumberRange.new(4 * sc, 10 * sc), Acceleration = Vector3.new(0, 3, 0),
	}), 26)
end
EXTRA.SkyBolts = function(r, g, sc)
	for k = 1, 3 do
		task.delay(k * 0.07, function()
			local off = Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)) * sc
			FxKit.Lightning(g + off + Vector3.new(0, 45, 0), g + off, WHITE:Lerp(r.Main, 0.3), 0.5 * sc, true)
		end)
	end
end
EXTRA.Swirl = function(r, g, sc)
	local a = anchor(CFrame.new(g + Vector3.new(0, 0.6, 0)), 1.5)
	SPIKE.Arc(merge(r, { Spikes = { N = 6, Len = 7, Width = 1.4 } }), a, a.Position, sc, nil)
end
EXTRA.Ink = function(r, g, sc)
	local a = anchor(CFrame.new(g + Vector3.new(0, 0.25, 0)), 4)
	emitNow(emitter(a, {
		Texture = tex("Spikes"), Color = ColorSequence.new(r.Deep), LightEmission = 0, LightInfluence = 0.3,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0), Speed = NumberRange.new(0.01),
		Size = ns({ { 0, 6 * sc }, { 0.1, 15 * sc }, { 1, 16 * sc } }), Transparency = ns({ { 0, 0.05 }, { 0.75, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(3),
	}), 1)
	emitNow(emitter(a, {
		Texture = tex("Smoke"), Color = ColorSequence.new(r.Deep, RGB(10, 5, 20)), LightEmission = 0, LightInfluence = 0.3,
		Size = ns({ { 0, 2 * sc }, { 1, 7 * sc } }), Transparency = ns({ { 0, 0.15 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(8 * sc, 18 * sc), Drag = 2,
	}), 18)
end

local function build(r, pos: Vector3, sc: number, dir: Vector3?)
	local g = L.Ground(pos)
	local c = pos
	if (pos - g).Magnitude < 1 then
		c = g + Vector3.new(0, 2 * sc, 0)
	end
	local function main()
		local a = anchor(CFrame.new(c), 4)
		a:SetAttribute("Shake", (r.Boss and 2 or 1) * sc)
		-- core + flares
		emitNow(emitter(a, {
			Texture = tex("Glow"), Color = ColorSequence.new(WHITE, r.Core:Lerp(r.Main, 0.4)), Brightness = 7, ZOffset = 4,
			Size = ns({ { 0, 3 * sc }, { 0.2, 7.5 * sc }, { 1, 1.5 * sc } }), Transparency = ns({ { 0, 0 }, { 0.5, 0.2 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.28), Speed = NumberRange.new(0),
		}), 2)
		for k = 1, r.Flare or 1 do
			emitNow(emitter(a, {
				Texture = tex("Flare"), Color = ColorSequence.new(WHITE, r.Main), Brightness = 6 - k, ZOffset = 5,
				Size = ns({ { 0, 4 * sc }, { 0.12, (22 - k * 8) * sc }, { 1, 2 * sc } }), Transparency = ns({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.42 - k * 0.06), Speed = NumberRange.new(0),
				Rotation = NumberRange.new((k - 1) * 45 - 4, (k - 1) * 45 + 4), RotSpeed = NumberRange.new(-25, 25),
			}), 1)
		end
		if r.Splat then
			emitNow(emitter(a, {
				Texture = tex("Spikes"), Color = ColorSequence.new(r.Main:Lerp(r.Deep, 0.5), r.Deep), LightEmission = 0.25, Brightness = 1.5, ZOffset = -1,
				Size = ns({ { 0, 5 * sc }, { 0.15, 16 * sc }, { 1, 19 * sc } }), Transparency = ns({ { 0, 0 }, { 0.4, 0.2 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.5), Speed = NumberRange.new(0), RotSpeed = NumberRange.new(-10, 10),
			}), 2)
		end
		-- spikes of this character's kind
		local f = r.Spikes and SPIKE[r.Spikes.Kind]
		if f then
			f(r, a, c, sc, dir)
		end
		-- sparks
		local sp = r.Sparks
		if sp then
			emitNow(emitter(a, {
				Texture = tex("Streak"), Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.25, r.Core:Lerp(r.Main, 0.5)), ColorSequenceKeypoint.new(1, r.Main),
				}), Brightness = 5,
				Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns({ { 0, 3 }, { 1, 1.5 } }),
				Size = ns({ { 0, 0.3 * sc }, { 0.3, 0.55 * sc }, { 1, 0 } }), Transparency = ns({ { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.3, 0.85), Speed = NumberRange.new(sp.Speed * 0.5 * sc, sp.Speed * sc), Drag = 4,
				Acceleration = Vector3.new(0, -(sp.Grav or 40), 0), Rotation = NumberRange.new(0),
			}), sp.N * math.min(1.5, sc))
		end
		-- debris
		local db = r.Debris
		if db then
			emitNow(emitter(a, {
				Texture = tex(db.Tex or "Shard"), Color = ColorSequence.new(db.Color, db.Color:Lerp(r.Deep, 0.5)),
				LightEmission = db.Tex == "Glow" and 1 or 0.2, Brightness = db.Tex == "Glow" and 3 or 1,
				Size = ns({ { 0, 0.55 * sc }, { 1, (db.Tex == "Smoke" and 2.5 or 0.2) * sc } }),
				Transparency = ns({ { 0, db.Tex == "Smoke" and 0.4 or 0 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.6, 1.3), Speed = NumberRange.new(db.Speed * 0.5 * sc, db.Speed * sc), Drag = 1.5,
				Acceleration = Vector3.new(0, -(db.Grav or 60), 0), RotSpeed = NumberRange.new(-300, 300),
			}), db.N)
		end
		-- ground
		local gr = r.Ground
		if gr then
			local ga = anchor(CFrame.new(g + Vector3.new(0, 0.2, 0)), 4)
			if gr.Ring then
				emitNow(emitter(ga, {
					Texture = tex("Ring"), Color = ColorSequence.new(r.Core, r.Main), Brightness = 4,
					Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top,
					SpreadAngle = Vector2.new(0, 0), Speed = NumberRange.new(0.01),
					Size = ns({ { 0, 2 * sc }, { 0.35, 16 * sc }, { 1, 22 * sc } }), Transparency = ns({ { 0, 0 }, { 0.5, 0.3 }, { 1, 1 } }),
					Lifetime = NumberRange.new(0.5),
				}), 1)
			end
			if gr.Scorch then
				emitNow(emitter(ga, {
					Texture = tex(gr.Scorch), Color = ColorSequence.new(r.Deep), LightEmission = gr.Scorch == "Crackle" and 0.6 or 0,
					LightInfluence = 0.3, Brightness = 1.5,
					Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top,
					SpreadAngle = Vector2.new(0, 0), Speed = NumberRange.new(0.01),
					Size = ns({ { 0, 6 * sc }, { 0.1, 12 * sc }, { 1, 13 * sc } }), Transparency = ns({ { 0, 0.15 }, { 0.7, 0.4 }, { 1, 1 } }),
					Lifetime = NumberRange.new(2.2),
				}), 1)
			end
			if gr.Dust then
				emitNow(emitter(ga, {
					Texture = tex("Smoke"), Color = ColorSequence.new(gr.Dust), LightEmission = 0, LightInfluence = 0.6,
					Size = ns({ { 0, 1.5 * sc }, { 1, 5 * sc } }), Transparency = ns({ { 0, 0.4 }, { 1, 1 } }),
					Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(24 * sc, 38 * sc), Drag = 5,
					Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(85, 85),
				}), 22)
			end
		end
		-- plume
		local pl = r.Plume
		if pl then
			if pl.Embers then
				emitNow(emitter(a, {
					Texture = tex("Glow"), Color = ColorSequence.new(WHITE, pl.Embers), Brightness = 4,
					Size = ns({ { 0, 0.3 * sc }, { 1, 0 } }), Lifetime = NumberRange.new(1, 2),
					Speed = NumberRange.new(6 * sc, 22 * sc), Drag = 1.2, Acceleration = Vector3.new(0, 9, 0),
				}), 28)
			end
			if pl.Smoke then
				emitNow(emitter(a, {
					Texture = tex("Smoke"), Color = ColorSequence.new(pl.Smoke, pl.Smoke:Lerp(Color3.new(0, 0, 0), 0.6)),
					LightEmission = 0, LightInfluence = 0.5, ZOffset = -2,
					Size = ns({ { 0, 2.5 * sc }, { 1, 9 * sc } }), Transparency = ns({ { 0, 0.35 }, { 0.4, 0.4 }, { 1, 1 } }),
					Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(3 * sc, 10 * sc), Drag = 1.5,
					Acceleration = Vector3.new(0, 5, 0), RotSpeed = NumberRange.new(-30, 30),
				}), 9)
			end
		end
		for _, name in r.Extra or {} do
			local fx = EXTRA[name]
			if fx then
				fx(r, g, sc)
			end
		end
		light(a, r.Main, 40 * sc, 12, 0.7)
	end
	if r.Implode then
		local pre = anchor(CFrame.new(c), 1.5, Vector3.one * 8 * sc)
		emitNow(emitter(pre, {
			Texture = tex("Streak"), Color = ColorSequence.new(WHITE, r.Main), Brightness = 4,
			Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns({ { 0, 2.5 }, { 1, 2.5 } }),
			Size = ns({ { 0, 0.45 * sc }, { 1, 0.1 } }), Lifetime = NumberRange.new(0.13), Speed = NumberRange.new(30 * sc, 40 * sc),
		}), 22)
		task.delay(0.13, main)
	else
		main()
	end
end

------------------------------------------------------------------------
-- public
------------------------------------------------------------------------
local remote: RemoteEvent?
local function getRemote(): RemoteEvent?
	if remote and remote.Parent then
		return remote
	end
	if RunService:IsServer() then
		remote = ReplicatedStorage:FindFirstChild("HitFxPlay") :: RemoteEvent?
		if not remote then
			local r = Instance.new("RemoteEvent")
			r.Name = "HitFxPlay"
			r.Parent = ReplicatedStorage
			remote = r
		end
	else
		remote = ReplicatedStorage:FindFirstChild("HitFxPlay") :: RemoteEvent?
	end
	return remote
end

local ELEMENT_OF_COLOR = {
	{ RGB(255, 120, 40), "Fire" }, { RGB(170, 235, 255), "Ice" }, { RGB(150, 200, 255), "Crystal" }, { RGB(140, 170, 255), "Electric" },
	{ RGB(230, 120, 255), "Spore" }, { RGB(70, 170, 255), "Water" }, { RGB(220, 255, 235), "Wind" }, { RGB(230, 180, 100), "Earth" },
}
-- nearest element for a colour (abilities without a known caster)
function HitFx.StyleForColor(c: Color3): string
	local best, bd = "Fire", math.huge
	for _, e in ELEMENT_OF_COLOR do
		local d = (e[1].R - c.R) ^ 2 + (e[1].G - c.G) ^ 2 + (e[1].B - c.B) ^ 2
		if d < bd then
			best, bd = e[2], d
		end
	end
	return best
end

function HitFx.Build(style: string, pos: Vector3, scale: number?, dir: Vector3?, color: Color3?)
	if not S[style] and string.sub(style, 1, 3) == "Pet" then
		-- "Pet<Element><Kind>" (built on demand on each client)
		for el in E do
			if string.sub(style, 4, 3 + #el) == el then
				petStyleFor(el, string.sub(style, 4 + #el))
				break
			end
		end
	end
	local r = S[style] or E[style]
	if not r then
		local sfx = require(script.Parent:WaitForChild("Sfx"))
		r = E[sfx.ElementOf(style)] or E.Fire
	end
	if color then
		r = merge(r, { Main = color, Deep = color:Lerp(Color3.new(0, 0, 0), 0.6) })
	end
	build(r, pos, math.clamp(scale or 1, 0.2, 4), dir)
end

-- server: every client builds it; client: build now
function HitFx.Play(style: string, pos: Vector3, scale: number?, dir: Vector3?, color: Color3?)
	if RunService:IsServer() then
		local r = getRemote()
		if r then
			r:FireAllClients(style, pos, scale or 1, dir, color)
		end
	else
		HitFx.Build(style, pos, scale, dir, color)
	end
end

-- client: listen for server requests (skip far away ones)
function HitFx.Listen()
	task.spawn(function()
		local r = ReplicatedStorage:WaitForChild("HitFxPlay", 60) :: RemoteEvent?
		if not r then
			return
		end
		r.OnClientEvent:Connect(function(style, pos, scale, dir, color)
			local cam = workspace.CurrentCamera
			if typeof(pos) ~= "Vector3" or (cam and (cam.CFrame.Position - pos).Magnitude > 450) then
				return
			end
			local ok, err = pcall(HitFx.Build, style, pos, scale, dir, color)
			if not ok then
				warn("[HitFx] " .. tostring(err))
			end
		end)
	end)
end

return HitFx
