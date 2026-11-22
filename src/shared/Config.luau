-- Oyunun genel ayarları. Hem sunucu hem istemci buradan okur.
-- Dengeyi değiştirmek için çoğu zaman sadece bu dosyayı düzenlemek yeterli.

local Config = {
	GameName = "Steal a Cloud",
	Version = "2.41", -- shown in the server log (F9) so you can see which build a server runs
	-- v2.33 director: the QA account (UserId 2459147914) gets its QA tools in
	-- EVERY server (public ones too) until told otherwise. false = Studio +
	-- private servers only. Other players never get them (checked on the server).
	QaEverywhere = true,
	-- v2.33 names players SEE for the vendors (internal keys stay "Tayron" /
	-- "Aurelius": map markers, orbs and unlock data use them)
	VendorDisplay = { Tayron = "Zeus", Aurelius = "Aurelius" },
	StartingCoins = 0,

	-- Movement
	WalkSpeed = 16,
	CarrySpeed = 11, -- walking speed while carrying weather (v2.13: noticeably slow, no buffs)

	-- Wild weather spawning
	SpawnInterval = 1, -- seconds between spawns
	MaxWild = 90, -- max wild clouds in the world (huge continent, ~150 spawn points)

	-- Cloud Altars (rare spawner)
	AltarInterval = 45, -- seconds between altar spawns
	MythicChance = 0.0001, -- 0.01% per altar spawn

	-- E-key prompts (hold times in seconds)
	CatchHold = 0.3,
	MythicCatchHold = 1.5,
	StealHold = 1.2, -- stealing takes nerve
	PerkHold = 0.5,


	-- Leash: carried clouds float behind you on a rope held in your LEFT hand
	LeashLength = 16, -- v2.17: longer, the collected clouds are much bigger now
	LeashHeight = 9, -- how high above your root the cloud floats
	LeashBack = 11, -- how far behind you
	LeashResponsiveness = 12,

	-- Day / night cycle (DayNightService)
	DayLength = 600, -- seconds for a full 24 h
	NightStart = 19, -- ClockTime when night clouds start spawning
	NightEnd = 6.5,

	-- Items with aim
	LaserRange = 120,
	LaserCooldown = 0.8,
	LaserSlow = 0.5,
	LaserSlowTime = 3,
	LaserDamage = 10,
	GrappleRange = 90,
	GrappleSpeed = 95,

	-- Hub air columns (Map/AirColumns, attributes Lift / PushX / PushZ / PushAbove)
	AirAccel = 6, -- how quickly you match the column's vertical speed

	-- Perk abilities (keys G = perk slot 1, H = slot 2, J = slot 3)
	BlinkDistance = 22,
	BlinkInvisible = 3,
	BlinkCooldown = 12,
	DazzleRadius = 35,
	DazzleDuration = 1.6,
	DazzleCooldown = 15,
	StormAuraRadius = 14, -- Thunder Storm perk: rivals in range are slowed
	StormAuraSlow = 0.6,

	-- Inventories (both wiped on death)
	ItemSlots = 7, -- normal Inventory: shop items, keys 1-7
	ItemStack = 5, -- default max of one item per slot (items can set MaxStack)
	PerkSlots = 2, -- Quirks/Perks: clouds equipped from your own vault

	-- Gate 2: Electric River (pulses: calm -> warning -> shock)
	RiverCalm = 2.6,
	RiverWarn = 0.6,
	RiverShock = 1.2,
	RiverDamage = 10, -- per ElectricInterval tick while shocking
	RiverSlowCalm = 0.8,
	RiverSlowShock = 0.4,

	-- Gate 3: Storm Bridge (lightning strikes + side wind)
	LightningInterval = 1.6,
	LightningWarn = 1.0,
	LightningRadius = 5,
	LightningDamage = 35,
	LightningKnock = 45,
	WindStrength = 6,

	-- Hazards
	IceTraction = 1.6, -- how fast you can change direction on ice (per second)
	IceTractionCarrying = 0.6, -- much worse with a cloud on your head
	IceSlipChance = 0.35, -- per second, only while carrying on ice
	ElectricInterval = 0.5,
	ElectricDamage = 8,
	ElectricDamageCarrying = 14,
	ElectricSlow = 0.55, -- speed multiplier inside an Electric Swamp

	-- Base Lock (shield)
	LockDuration = 60,
	LockCooldown = 0, -- v2.17: lock again right away once the shield drops
	ShieldRadius = 16, -- rivals are pushed out of this radius around the Nest
	LockPadRadius = 3.5, -- how close the owner must be to press the pad

	-- Delivery
	DeliverRadius = 7, -- how close to your Nest you must be

	-- Vault spheres on your base (store caught weather; rivals can steal them)
	VaultCount = 4,
	-- v2.35 director: too much money -> passive income ~6x lower
	VaultIncomeInterval = 10, -- seconds between passive income ticks (was 5)
	VaultIncomeRate = 0.035, -- each stored cloud pays 3.5% of its reward per tick (was 10%)
	TouchRadius = 2.5, -- extra studs around a sphere that count as "touching"
	GrabCooldown = 1.5, -- after dropping/delivering, can't instantly grab again

	-- Carrying slows you a little
	CarryJumpHeight = 4.5, -- normal R15 jump height is 7.2
	CarryJumpPower = 38, -- for places that use JumpPower (normal 50)

	-- Rain cloud: slippery puddle trail
	PuddleInterval = 0.3,
	PuddleMinDistance = 3, -- don't stack puddles when standing still
	PuddleLifetime = 6,
	OwnerPuddleGrace = 1.5, -- your own fresh puddles don't make you slip
	SlipCooldown = 3,
	SlipDuration = 0.8,
	SlipPush = 22, -- forward slide
	SlipLift = 8, -- small hop
	SlipSpin = 3, -- how much you tip over

	-- Combo: Snow + rain puddle = ice road (speed boost)
	IceLifetime = 12,
	IceBoost = 14,

	-- Combo: Tornado + rain puddle = launch pad
	LaunchPower = 85,

	-- Pocket tornado: lifts LiftPlatforms
	LiftRange = 30,
	LiftHeight = 12,
	LiftHold = 3, -- seconds a platform stays up after the tornado leaves

	-- Snow cloud: freezes WaterGaps into bridges
	FreezeRange = 24,
	FreezeDuration = 8,

	-- Thunder cloud (rarest): fast but highlighted for everyone
	ThunderCarrySpeed = 22,
	ThunderFlashInterval = 2.5,

	-- Stealing
	AlarmCooldown = 4,
	IntruderRadius = 14, -- rival this close to your Nest (with a full vault) = alarm
	TagRadius = 5, -- owner touching the thief sends the storm back

	-- Central storm cloud that spawns weather
	StormHeight = 28,

	-- Saving
	DataStoreName = "PocketStorm_v1",
	AutosaveInterval = 60,
}

-- v1.4 perks
Config.QuakeRadius = 22
Config.QuakeKnock = 70
Config.QuakeCooldown = 20
Config.ChaosInterval = 20
Config.ChaosDuration = 8
Config.LavaDamage = 30 -- per second (Fire perks are immune)

-- v1.4 world events
Config.EventMinGap = 240 -- seconds between world events
Config.EventMaxGap = 420
Config.EventDuration = 75
Config.AcidDamage = 6 -- per second outside shelter (Poison perks are immune)
Config.FogStealHold = 0.7 -- steal hold during the Fog event (normal = StealHold)
Config.MeteorClouds = 4 -- clouds a meteor shower drops
Config.MeteorTiers = { Epic = 60, Legendary = 32, Mythic = 8 }

-- v1.7 notifications: only these tiers are announced to everyone
Config.AnnounceTier = 4 -- 4 = Legendary, 5 = Mythic (Common/Rare/Epic stay silent)
Config.AnnounceCooldown = 15 -- seconds between global rare-cloud messages (Mythic ignores it)

-- v1.7 combat feedback
Config.RagdollTime = 1.2 -- seconds a hit player ragdolls before getting up

return Config
