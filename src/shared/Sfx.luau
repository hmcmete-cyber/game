-- v2.17 SOUND EFFECTS (director: sounds for everything — hits, deaths, bosses,
-- hatching, offerings... "for dopamine").
--
-- Every cue = one or more layers { Id, Volume, Pitch, (PitchJitter) }.
-- They use Roblox's built-in client sounds (rbxasset://sounds/...) so they work
-- right away; layering + pitch makes each cue distinct. To swap in nicer
-- Creator Store sounds later, just replace an Id with "rbxassetid://<id>"
-- (Astra: see the cue list in COMMS).
--
-- Server: Sfx.At(cue, position)  (3D, everyone nearby hears it)
--         Sfx.Global(cue)        (2D, everyone)
-- Elements for monster abilities / deaths come from Sfx.ElementOf(name).

local Debris = game:GetService("Debris")

local Sfx = {}

local S = "rbxasset://sounds/"
local SLASH, LUNGE, UNSHEATH = S .. "swordslash.wav", S .. "swordlunge.wav", S .. "unsheath.wav"
local SHOT, WHOOSH, LAUNCH = S .. "Rocket shot.wav", S .. "Rocket whoosh 01.wav", S .. "Launching rocket.wav"
local THUD, CLICK, CLICKFAST, SNAP = S .. "collide.wav", S .. "button.wav", S .. "clickfast.wav", S .. "snap.mp3"
local PING, SPLASH, THUNDER, GHOST = S .. "electronicpingshort.wav", S .. "impact_water.mp3", S .. "HalloweenThunder.wav", S .. "HalloweenGhost.wav"
local GLASS, SPLAT, VICTORY, LAND = S .. "glassbreak.wav", S .. "splat.wav", S .. "victory.wav", S .. "action_jump_land.mp3"

-- layer: id, volume, pitch, fx list, start time (TimePosition), jitter
-- fx (v2.18 variety): Reverb, Echo, Distort, Flange, Chorus, Tremolo,
-- Low (muffled/boomy), High (thin/bright) — so cues sharing a source sound
-- still sound clearly different
local function L(id, vol, pitch, fx, start, jitter)
	return { Id = id, Volume = vol, Pitch = pitch, Fx = fx, Start = start, Jitter = jitter or 0.08 }
end

Sfx.Cues = {
	-- player / pet hits on monsters
	HitPunch = { L(THUD, 0.8, 1.2, { "High" }), L(SNAP, 0.5, 1.4) },
	HitLaser = { L(SHOT, 0.5, 2.3, { "Flange", "High" }), L(PING, 0.35, 2.6, { "Echo" }) },
	HitQuake = { L(THUD, 1, 0.45, { "Low", "Distort" }), L(LAND, 0.8, 0.6, { "Low" }) },
	HitGadget = { L(SHOT, 0.8, 0.8, { "Distort" }), L(THUD, 0.6, 0.6, { "Low" }) },
	HitBoss = { L(THUD, 1, 0.6, { "Low", "Reverb" }), L(SLASH, 0.6, 0.65, { "Distort" }) },
	-- pet attacks (by attack kind)
	PetBite = { L(SNAP, 0.7, 1.8, { "High" }), L(SNAP, 0.4, 1.3, nil, 0.02) },
	PetBolt = { L(SHOT, 0.45, 2.6, { "High", "Echo" }), L(PING, 0.3, 2.4) },
	PetLob = { L(WHOOSH, 0.5, 2, { "Chorus" }), L(SPLAT, 0.5, 1.5, { "High" }) },
	PetPulse = { L(PING, 0.6, 0.6, { "Reverb", "Chorus" }), L(THUD, 0.4, 1.1) },
	PetChain = { L(THUNDER, 0.4, 2.6, { "Flange", "High" }), L(PING, 0.35, 3, { "Tremolo" }) },
	-- monster abilities by element (cast sound) + melee
	Melee = { L(SLASH, 0.7, 0.85, { "Low" }), L(UNSHEATH, 0.3, 0.7) },
	Fire = { L(WHOOSH, 0.8, 0.7, { "Distort", "Low" }), L(LAUNCH, 0.5, 1.4, { "Chorus" }) },
	Ice = { L(GLASS, 0.7, 1.7, { "Reverb", "High" }), L(PING, 0.4, 2.8, { "Echo" }) },
	Electric = { L(THUNDER, 0.7, 2, { "Tremolo", "Flange" }), L(PING, 0.4, 3.2, { "Distort" }) },
	Earth = { L(THUD, 1, 0.4, { "Low", "Distort" }), L(LAND, 0.9, 0.45, { "Reverb" }) },
	Spore = { L(SPLAT, 0.7, 0.75, { "Chorus", "Echo" }), L(WHOOSH, 0.35, 2.4, { "High" }) },
	Water = { L(SPLASH, 0.9, 1.2, { "Chorus" }), L(SPLAT, 0.5, 0.7, { "Low" }) },
	Wind = { L(WHOOSH, 0.9, 1.5, { "Flange" }), L(GHOST, 0.3, 2.2, { "Echo" }) },
	Crystal = { L(GLASS, 0.7, 1.2, { "Echo", "High" }), L(PING, 0.6, 1.9, { "Reverb", "Chorus" }) },
	Slash = { L(SLASH, 0.8, 1.05), L(UNSHEATH, 0.5, 1.4, { "High" }) },
	-- player hurt
	PlayerHurt = { L(THUD, 0.6, 1.5, { "High" }), L(SNAP, 0.3, 0.8) },
	-- deaths by element (normal monsters)
	DeathFire = { L(LAUNCH, 0.7, 0.7, { "Distort", "Reverb" }), L(WHOOSH, 0.6, 0.5, { "Low" }) },
	DeathIce = { L(GLASS, 1, 0.9, { "Reverb" }), L(GLASS, 0.6, 1.8, { "Echo", "High" }, 0.05) },
	DeathElectric = { L(THUNDER, 0.8, 1.4, { "Tremolo" }), L(PING, 0.6, 0.5, { "Flange", "Distort" }) },
	DeathEarth = { L(THUD, 1, 0.35, { "Low", "Reverb" }), L(LAND, 1, 0.4, { "Distort" }) },
	DeathSpore = { L(SPLAT, 0.9, 0.55, { "Echo" }), L(WHOOSH, 0.6, 1.8, { "Chorus", "High" }) },
	DeathWater = { L(SPLASH, 1, 0.75, { "Reverb" }), L(SPLAT, 0.6, 0.5, { "Chorus" }) },
	DeathWind = { L(WHOOSH, 1, 0.6, { "Flange", "Reverb" }), L(GHOST, 0.4, 1.4, { "Echo" }) },
	DeathCrystal = { L(GLASS, 1, 0.8, { "Echo" }), L(PING, 0.7, 1.4, { "Reverb", "Chorus" }), L(PING, 0.5, 2.1, { "Echo" }, 0.05) },
	DeathSlash = { L(THUD, 0.8, 0.7, { "Low" }), L(SLASH, 0.6, 0.5, { "Reverb" }) },
	-- bosses
	BossRoar = { L(GHOST, 1, 0.45, { "Distort", "Reverb" }), L(THUNDER, 0.8, 0.5, { "Low" }), L(THUD, 0.8, 0.35, { "Low" }) },
	BossArrive = { L(THUNDER, 1, 0.6, { "Reverb", "Low" }), L(LAUNCH, 0.8, 0.45, { "Distort" }) },
	BossStagger = { L(THUD, 1, 0.45, { "Distort" }), L(THUNDER, 0.7, 1.1, { "Tremolo" }) },
	BossCollapse = { L(LAND, 1, 0.3, { "Low", "Reverb" }), L(THUD, 1, 0.25, { "Distort" }), L(GHOST, 0.7, 0.4, { "Echo" }) },
	BossDefeat = { L(THUNDER, 1, 0.45, { "Reverb", "Distort" }), L(SHOT, 1, 0.4, { "Low" }), L(GLASS, 0.7, 0.6, { "Echo" }) },
	BossReward = { L(VICTORY, 1, 1, { "Reverb" }), L(PING, 0.7, 1.2, { "Chorus" }), L(PING, 0.6, 1.6, { "Echo" }, 0.04) },
	-- eggs, hatching, pets
	EggTake = { L(CLICK, 0.8, 1.1), L(PING, 0.7, 1.5, { "Chorus" }) },
	EggDeliver = { L(PING, 0.8, 1.2, { "Echo" }), L(PING, 0.7, 1.8, { "Reverb" }, 0.05) },
	HatchPulse = { L(PING, 0.8, 1, { "Reverb", "Chorus" }) }, -- pitch rises per pulse
	HatchBurst = { L(GLASS, 0.8, 1.3, { "Echo" }), L(SHOT, 0.7, 1.4, { "High" }), L(VICTORY, 0.9, 1.05, { "Reverb" }) },
	HatchLegendary = { L(THUNDER, 1, 0.7, { "Reverb" }), L(VICTORY, 1, 0.85, { "Chorus", "Reverb" }), L(PING, 0.9, 2.2, { "Echo" }) },
	PetLevelUp = { L(VICTORY, 0.9, 1.35, { "Chorus" }), L(PING, 0.8, 2, { "Echo" }), L(PING, 0.6, 2.6, nil, 0.06) },
	-- vendors / orbs / base
	OrbOffer = { L(PING, 0.9, 0.6, { "Reverb", "Flange" }), L(WHOOSH, 0.7, 0.5, { "Echo" }), L(VICTORY, 0.8, 1.15, { "Chorus" }) },
	OrbRefuse = { L(CLICKFAST, 0.8, 0.5, { "Distort" }), L(THUD, 0.6, 1.3) },
	Buy = { L(CLICK, 0.8, 1.3, { "High" }), L(PING, 0.7, 2, { "Chorus" }) },
	BaseLock = { L(CLICK, 1, 0.7, { "Low" }), L(PING, 0.7, 0.8, { "Reverb", "Tremolo" }) },
	CloudCatch = { L(PING, 0.7, 1.6, { "Chorus" }), L(WHOOSH, 0.5, 2.2, { "High" }) },
	CloudDeliver = { L(VICTORY, 0.7, 1.25), L(CLICK, 0.6, 1.8, { "High" }) },
	TutorialStep = { L(CLICK, 0.6, 1.4), L(PING, 0.5, 1.7, { "Chorus" }) },
}

local FX = {
	Reverb = function() local e = Instance.new("ReverbSoundEffect"); e.DecayTime = 1.6; e.WetLevel = -4; return e end,
	Echo = function() local e = Instance.new("EchoSoundEffect"); e.Delay = 0.12; e.Feedback = 0.35; e.WetLevel = -4; return e end,
	Distort = function() local e = Instance.new("DistortionSoundEffect"); e.Level = 0.55; return e end,
	Flange = function() local e = Instance.new("FlangeSoundEffect"); e.Depth = 0.6; e.Rate = 6; e.Mix = 0.7; return e end,
	Chorus = function() local e = Instance.new("ChorusSoundEffect"); e.Depth = 0.45; e.Rate = 3; e.Mix = 0.6; return e end,
	Tremolo = function() local e = Instance.new("TremoloSoundEffect"); e.Frequency = 14; e.Depth = 0.85; e.Duty = 0.5; return e end,
	Low = function() local e = Instance.new("EqualizerSoundEffect"); e.LowGain = 8; e.MidGain = -6; e.HighGain = -30; return e end,
	High = function() local e = Instance.new("EqualizerSoundEffect"); e.LowGain = -30; e.MidGain = 0; e.HighGain = 6; return e end,
}

-- element of a monster ability / species by name keywords
local ELEMENTS = {
	{ "Crystal", { "Shard", "Crystal", "Prism", "Refract", "Geo", "Quartz", "Pincer" } },
	{ "Ice", { "Frost", "Ice", "Snow", "Glacier", "Avalanche", "Hail", "Permafrost", "Shell" } },
	{ "Electric", { "Volt", "Thunder", "Static", "Storm", "Spark", "Croak", "Zap", "Bolt", "Gulp" } },
	{ "Fire", { "Flame", "Ember", "Magma", "Lava", "Fire", "Cinder", "Scorch", "Smold", "Erupt", "Caldera", "Crater" } },
	{ "Spore", { "Spore", "Sprout", "Root", "Moss", "Lullaby", "Mycel", "Cap", "Shroom", "Glowmoth" } },
	{ "Water", { "Ink", "Tide", "Tentacle", "Bubble", "Tongue", "Octo", "Skyfin", "Wave" } },
	{ "Wind", { "Gust", "Cyclon", "Wind", "Wool", "Puff", "Snowpeck", "Wing" } },
	{ "Earth", { "Quake", "Slam", "Boulder", "Rubble", "Pillar", "Ridge", "Stomp", "Rock", "Mesa", "Bristle", "Gnash", "Mossgrave" } },
}
function Sfx.ElementOf(name: string): string
	for _, e in ELEMENTS do
		for _, k in e[2] do
			if string.find(name, k) then
				return e[1]
			end
		end
	end
	return "Slash"
end

-- a stable pitch per name (0.8-1.25): two monsters of the same element
-- still sound different
function Sfx.PitchFor(name: string): number
	local h = 0
	for k = 1, #name do
		h = (h * 31 + string.byte(name, k)) % 997
	end
	return 0.8 + (h % 46) / 100
end

-- v2.19: our own generated sounds (tools/make_sfx.py) win when uploaded
local Uploaded = {}
pcall(function()
	Uploaded = require(script.Parent:WaitForChild("SfxIds", 5))
end)
-- the director wants different SOUNDS, not effects on one sound: the effect
-- chains are off; only the plain fallback layers play until ids are uploaded
local USE_FX = false

local function playLayers(parent: Instance, cue, pitchScale: number?, cueName: string?)
	local own = cueName and Uploaded[cueName]
	if own and own ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = own
		s.Volume = 0.8
		s.PlaybackSpeed = (pitchScale or 1) * (1 + (math.random() * 2 - 1) * 0.04)
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 220
		s.Parent = parent
		s:Play()
		Debris:AddItem(s, 8)
		return
	end
	for _, layer in cue do
		local s = Instance.new("Sound")
		s.SoundId = layer.Id
		s.Volume = layer.Volume
		s.PlaybackSpeed = layer.Pitch * (pitchScale or 1) * (1 + (math.random() * 2 - 1) * layer.Jitter)
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 220
		for _, name in USE_FX and layer.Fx or {} do
			local make = FX[name]
			if make then
				make().Parent = s
			end
		end
		if layer.Start then
			s.TimePosition = layer.Start
		end
		s.Parent = parent
		s:Play()
		Debris:AddItem(s, 6)
	end
end

local holder
-- 3D sound at a world position (server: everyone nearby hears it)
function Sfx.At(cueName: string, pos: Vector3, pitchScale: number?)
	local cue = Sfx.Cues[cueName]
	if not cue then
		return
	end
	if not holder or not holder.Parent then
		holder = Instance.new("Folder")
		holder.Name = "SfxEmitters"
		holder.Parent = workspace
	end
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
	a.Size = Vector3.one * 0.2
	a.CFrame = CFrame.new(pos)
	a.Parent = holder
	playLayers(a, cue, pitchScale, cueName)
	Debris:AddItem(a, 6)
end

-- 2D sound for everyone (big moments: legendary hatch, boss defeat)
function Sfx.Global(cueName: string, pitchScale: number?)
	local cue = Sfx.Cues[cueName]
	if cue then
		if not holder or not holder.Parent then
			holder = Instance.new("Folder")
			holder.Name = "SfxEmitters"
			holder.Parent = workspace
		end
		playLayers(holder, cue, pitchScale, cueName) -- sounds not inside a part play 2D for everyone
	end
end

return Sfx
