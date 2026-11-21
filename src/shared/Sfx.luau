-- v2.17 SOUND EFFECTS (director: sounds for everything — hits, deaths, bosses,
-- hatching, offerings... "for dopamine").
--
-- Every cue = one or more layers { Id, Volume, Pitch, (PitchJitter) }.
-- Creator Store effects lead the cues listed in COMMS. Built-in Roblox
-- layers provide accents and still play if a Store asset is unavailable.
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
	HitPunch = { L("rbxassetid://9119641536", 0.62, 1), L(SNAP, 0.5, 1.4) },
	HitLaser = { L("rbxassetid://9119902088", 0.48, 1.18), L(PING, 0.35, 2.6, { "Echo" }) },
	HitQuake = { L("rbxassetid://9125402735", 0.68, 0.78), L(LAND, 0.8, 0.6, { "Low" }) },
	HitGadget = { L("rbxassetid://165969964", 0.72, 1.1), L(THUD, 0.6, 0.6, { "Low" }) },
	HitBoss = { L("rbxassetid://9113511616", 0.75, 0.92), L(SLASH, 0.6, 0.65, { "Distort" }) },
	-- pet attacks (by attack kind)
	PetBite = { L("rbxassetid://8933011987", 0.55, 1.22), L(SNAP, 0.4, 1.3, nil, 0.02) },
	PetBolt = { L("rbxassetid://248435147", 0.44, 1.24), L(PING, 0.3, 2.4) },
	PetLob = { L("rbxassetid://112418678933929", 0.51, 0.92), L(SPLAT, 0.5, 1.5, { "High" }) },
	PetPulse = { L("rbxassetid://9125785014", 0.43, 0.83), L(THUD, 0.4, 1.1) },
	PetChain = { L("rbxassetid://9114235460", 0.48, 1.35), L(PING, 0.35, 3, { "Tremolo" }) },
	-- monster abilities by element (cast sound) + melee
	Melee = { L("rbxassetid://9113841825", 0.63, 1.15), L(UNSHEATH, 0.3, 0.7) },
	Fire = { L("rbxassetid://9117986652", 0.67, 1.05), L(LAUNCH, 0.5, 1.4, { "Chorus" }) },
	Ice = { L("rbxassetid://41763367", 0.55, 1.15), L(PING, 0.4, 2.8, { "Echo" }) },
	Electric = { L("rbxassetid://9116281362", 0.56, 1), L(PING, 0.4, 3.2, { "Distort" }) },
	Earth = { L("rbxassetid://9118628948", 0.64, 1.02), L(LAND, 0.9, 0.45, { "Reverb" }) },
	Spore = { L("rbxassetid://9113057346", 0.47, 1.24), L(WHOOSH, 0.35, 2.4, { "High" }) },
	Water = { L("rbxassetid://18756308263", 0.58, 1.08), L(SPLAT, 0.5, 0.7, { "Low" }) },
	Wind = { L("rbxassetid://231731980", 0.51, 1.02), L(GHOST, 0.3, 2.2, { "Echo" }) },
	Crystal = { L("rbxassetid://158050602", 0.48, 1.31), L(PING, 0.6, 1.9, { "Reverb", "Chorus" }) },
	Slash = { L("rbxassetid://135603822713110", 0.57, 1), L(UNSHEATH, 0.5, 1.4, { "High" }) },
	-- player hurt
	PlayerHurt = { L("rbxassetid://1198923651", 0.52, 1.1), L(SNAP, 0.3, 0.8) },
	-- deaths by element (normal monsters)
	DeathFire = { L("rbxassetid://9119623155", 0.70, 0.81), L(WHOOSH, 0.6, 0.5, { "Low" }) },
	DeathIce = { L("rbxassetid://9114890176", 0.64, 1.19), L(GLASS, 0.6, 1.8, { "Echo", "High" }, 0.05) },
	DeathElectric = { L("rbxassetid://9116279358", 0.59, 0.81), L(PING, 0.6, 0.5, { "Flange", "Distort" }) },
	DeathEarth = { L("rbxassetid://9118614058", 0.72, 0.70), L(LAND, 1, 0.4, { "Distort" }) },
	DeathSpore = { L("rbxassetid://140323850218372", 0.55, 0.76), L(WHOOSH, 0.6, 1.8, { "Chorus", "High" }) },
	DeathWater = { L("rbxassetid://9125498759", 0.63, 0.84), L(SPLAT, 0.6, 0.5, { "Chorus" }) },
	DeathWind = { L("rbxassetid://9120697984", 0.57, 0.78), L(GHOST, 0.4, 1.4, { "Echo" }) },
	DeathCrystal = { L("rbxassetid://8295269333", 0.57, 1), L(PING, 0.7, 1.4, { "Reverb", "Chorus" }), L(PING, 0.5, 2.1, { "Echo" }, 0.05) },
	DeathSlash = { L("rbxassetid://9116802497", 0.54, 0.73), L(SLASH, 0.6, 0.5, { "Reverb" }) },
	-- bosses
	BossRoar = { L("rbxassetid://21420962", 0.80, 0.86), L(THUNDER, 0.8, 0.5, { "Low" }), L(THUD, 0.8, 0.35, { "Low" }) },
	BossArrive = { L("rbxassetid://9125403260", 0.85, 0.69), L(LAUNCH, 0.8, 0.45, { "Distort" }) },
	BossStagger = { L("rbxassetid://9116673915", 0.85, 1), L(THUNDER, 0.7, 1.1, { "Tremolo" }) },
	BossCollapse = { L("rbxassetid://9118658081", 0.9, 1.5), L(THUD, 1, 0.25, { "Distort" }), L(GHOST, 0.7, 0.4, { "Echo" }) },
	BossDefeat = { L("rbxassetid://55224766", 0.82, 0.92), L(SHOT, 1, 0.4, { "Low" }), L(GLASS, 0.7, 0.6, { "Echo" }) },
	BossReward = { L("rbxassetid://1839321582", 0.68, 1), L(PING, 0.7, 1.2, { "Chorus" }), L(PING, 0.6, 1.6, { "Echo" }, 0.04) },
	-- eggs, hatching, pets
	EggTake = { L("rbxassetid://8863377426", 0.65, 1.15), L(PING, 0.7, 1.5, { "Chorus" }) },
	EggDeliver = { L("rbxassetid://9272158182", 0.68, 1.05), L(PING, 0.7, 1.8, { "Reverb" }, 0.05) },
	-- v2.21 director: hatching = serious CRACKLING shell sounds, nothing shiny
	-- (built-in layers only, so every layer plays together)
	HatchPulse = { L(SNAP, 0.85, 0.55, nil, nil, 0.15), L(GLASS, 0.22, 0.42, nil, nil, 0.1), L(THUD, 0.6, 0.45) }, -- pitch drops for big eggs
	HatchCrack = { L(SNAP, 0.7, 0.7, nil, nil, 0.3), L(CLICKFAST, 0.45, 0.5, nil, nil, 0.2) },
	HatchBurst = { L(GLASS, 0.95, 0.55), L(SNAP, 0.9, 0.4), L(LAND, 1, 0.45) },
	HatchLegendary = { L(THUNDER, 0.85, 0.75), L(GLASS, 0.7, 0.35), L(LAND, 1, 0.3) },
	PetLevelUp = { L("rbxassetid://9067086084", 0.58, 1.18), L(PING, 0.8, 2, { "Echo" }), L(PING, 0.6, 2.6, nil, 0.06) },
	-- vendors / orbs / base
	OrbOffer = { L("rbxassetid://136730840543746", 0.52, 0.88), L(WHOOSH, 0.7, 0.5, { "Echo" }), L(VICTORY, 0.8, 1.15, { "Chorus" }) },
	OrbRefuse = { L("rbxassetid://8708720217", 0.38, 1), L(THUD, 0.6, 1.3) },
	Buy = { L("rbxassetid://6787582810", 0.55, 1.05), L(PING, 0.7, 2, { "Chorus" }) },
	BaseLock = { L("rbxassetid://226892749", 0.52, 0.83), L(PING, 0.7, 0.8, { "Reverb", "Tremolo" }) },
	CloudCatch = { L("rbxassetid://9126229716", 0.48, 1.35), L(WHOOSH, 0.5, 2.2, { "High" }) },
	CloudDeliver = { L("rbxassetid://330274138", 0.61, 1.19), L(CLICK, 0.6, 1.8, { "High" }) },
	TutorialStep = { L("rbxassetid://10066936758", 0.48, 1.1), L(PING, 0.5, 1.7, { "Chorus" }) },
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
	-- v2.20: when a cue has a Creator Store sound (first layer), play ONLY that
	-- one: the shared built-in accent layers made different events sound alike
	local layers = cue
	if cue[1] and string.sub(cue[1].Id, 1, 13) == "rbxassetid://" then
		layers = { cue[1] }
	end
	for _, layer in layers do
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
