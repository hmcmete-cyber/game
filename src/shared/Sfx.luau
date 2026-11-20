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

local function L(id, vol, pitch, jitter)
	return { Id = id, Volume = vol, Pitch = pitch, Jitter = jitter or 0.08 }
end

Sfx.Cues = {
	-- player / pet hits on monsters
	HitPunch = { L(THUD, 0.7, 1.1), L(SNAP, 0.5, 1.3) },
	HitLaser = { L(SHOT, 0.5, 1.8), L(PING, 0.3, 1.6) },
	HitQuake = { L(THUD, 0.9, 0.55), L(LAND, 0.7, 0.7) },
	HitGadget = { L(SHOT, 0.7, 0.9), L(THUD, 0.6, 0.7) },
	HitBoss = { L(THUD, 0.9, 0.75), L(SLASH, 0.5, 0.8) },
	-- pet attacks (by attack kind)
	PetBite = { L(SNAP, 0.6, 1.5), L(THUD, 0.4, 1.4) },
	PetBolt = { L(SHOT, 0.45, 2.1), L(PING, 0.3, 2) },
	PetLob = { L(WHOOSH, 0.5, 1.7), L(SPLAT, 0.45, 1.2) },
	PetPulse = { L(THUD, 0.6, 0.9), L(PING, 0.4, 0.8) },
	PetChain = { L(THUNDER, 0.35, 2.2), L(PING, 0.35, 2.4) },
	-- monster abilities by element (cast sound) + melee
	Melee = { L(SLASH, 0.6, 0.9) },
	Fire = { L(WHOOSH, 0.7, 0.8), L(LAUNCH, 0.4, 1.3) },
	Ice = { L(GLASS, 0.6, 1.5), L(WHOOSH, 0.4, 1.8) },
	Electric = { L(THUNDER, 0.6, 1.8), L(PING, 0.4, 2.2) },
	Earth = { L(THUD, 0.9, 0.5), L(LAND, 0.8, 0.6) },
	Spore = { L(SPLAT, 0.6, 0.9), L(WHOOSH, 0.3, 2) },
	Water = { L(SPLASH, 0.8, 1.1), L(SPLAT, 0.4, 0.8) },
	Wind = { L(WHOOSH, 0.8, 1.4), L(WHOOSH, 0.5, 0.9) },
	Crystal = { L(GLASS, 0.7, 1.1), L(PING, 0.5, 1.4) },
	Slash = { L(SLASH, 0.7, 1), L(UNSHEATH, 0.4, 1.2) },
	-- player hurt
	PlayerHurt = { L(THUD, 0.6, 1.3) },
	-- deaths by element (normal monsters)
	DeathFire = { L(LAUNCH, 0.6, 0.9), L(THUD, 0.6, 0.7) },
	DeathIce = { L(GLASS, 0.9, 1), L(GLASS, 0.5, 1.6) },
	DeathElectric = { L(THUNDER, 0.7, 1.5), L(PING, 0.5, 0.7) },
	DeathEarth = { L(THUD, 1, 0.45), L(LAND, 0.9, 0.5) },
	DeathSpore = { L(SPLAT, 0.8, 0.7), L(WHOOSH, 0.5, 1.4) },
	DeathWater = { L(SPLASH, 1, 0.9), L(SPLAT, 0.6, 0.6) },
	DeathWind = { L(WHOOSH, 0.9, 0.7), L(GHOST, 0.3, 1.6) },
	DeathCrystal = { L(GLASS, 1, 0.9), L(PING, 0.6, 1.8) },
	DeathSlash = { L(THUD, 0.8, 0.8), L(SLASH, 0.5, 0.6) },
	-- bosses
	BossRoar = { L(GHOST, 0.9, 0.55), L(THUNDER, 0.8, 0.6), L(THUD, 0.8, 0.4) },
	BossArrive = { L(THUNDER, 1, 0.7), L(LAUNCH, 0.7, 0.6) },
	BossStagger = { L(THUD, 1, 0.5), L(THUNDER, 0.6, 0.9) },
	BossCollapse = { L(LAND, 1, 0.35), L(THUD, 1, 0.3), L(GHOST, 0.6, 0.45) },
	BossDefeat = { L(THUNDER, 1, 0.5), L(SHOT, 0.9, 0.5), L(GLASS, 0.6, 0.7) },
	BossReward = { L(VICTORY, 1, 1), L(PING, 0.7, 1.2) },
	-- eggs, hatching, pets
	EggTake = { L(CLICK, 0.7, 1), L(PING, 0.6, 1.3) },
	EggDeliver = { L(PING, 0.8, 1), L(PING, 0.6, 1.5) },
	HatchPulse = { L(PING, 0.7, 1) }, -- pitch rises per pulse (see Sfx.At pitch scale)
	HatchBurst = { L(SHOT, 0.8, 1.2), L(GLASS, 0.6, 1.4), L(VICTORY, 0.9, 1) },
	HatchLegendary = { L(THUNDER, 1, 0.8), L(VICTORY, 1, 0.9), L(PING, 0.9, 2) },
	PetLevelUp = { L(VICTORY, 0.9, 1.3), L(PING, 0.8, 1.8) },
	-- vendors / orbs / base
	OrbOffer = { L(PING, 0.9, 0.7), L(WHOOSH, 0.6, 0.6), L(VICTORY, 0.8, 1.1) },
	OrbRefuse = { L(CLICKFAST, 0.7, 0.6), L(THUD, 0.5, 1.2) },
	Buy = { L(CLICK, 0.8, 1.2), L(PING, 0.6, 1.6) },
	BaseLock = { L(CLICK, 0.9, 0.8), L(PING, 0.7, 0.9) },
	CloudCatch = { L(PING, 0.7, 1.4), L(WHOOSH, 0.4, 2) },
	CloudDeliver = { L(VICTORY, 0.7, 1.2) },
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

local function playLayers(parent: Instance, cue, pitchScale: number?)
	for _, layer in cue do
		local s = Instance.new("Sound")
		s.SoundId = layer.Id
		s.Volume = layer.Volume
		s.PlaybackSpeed = layer.Pitch * (pitchScale or 1) * (1 + (math.random() * 2 - 1) * layer.Jitter)
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 220
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
	playLayers(a, cue, pitchScale)
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
		playLayers(holder, cue, pitchScale) -- sounds not inside a part play 2D for everyone
	end
end

return Sfx
