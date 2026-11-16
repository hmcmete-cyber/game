-- Oyunun genel ayarları. Hem sunucu hem istemci buradan okur.
-- Dengeyi değiştirmek için çoğu zaman sadece bu dosyayı düzenlemek yeterli.

local Config = {
	GameName = "Steal a Cloud",
	StartingCoins = 0,

	-- Movement
	WalkSpeed = 16,
	CarrySpeed = 14, -- walking speed while carrying weather

	-- Wild weather spawning
	SpawnInterval = 2, -- seconds between spawns
	MaxWild = 14, -- max wild clouds in the world

	-- Cloud Altars (rare spawner)
	AltarInterval = 45, -- seconds between altar spawns
	MythicChance = 0.0001, -- 0.01% per altar spawn

	-- E-key prompts (hold times in seconds)
	CatchHold = 0.3,
	MythicCatchHold = 1.5,
	StealHold = 1.2, -- stealing takes nerve
	CharmHold = 0.5,

	-- Inventory (charms only; wiped on death)
	InventorySize = 3,
	SkatesDuration = 8, -- Ice Charm (Q)
	SkatesCooldown = 20,
	SkatesBoost = 10,

	-- Leash: carried clouds float behind you on a rope held in your LEFT hand
	LeashLength = 9,
	LeashHeight = 5, -- how high above your root the cloud floats
	LeashBack = 5, -- how far behind you
	LeashResponsiveness = 12,

	-- Nitro (inventory slot 2, key R): bought at the Nitro Station
	NitroPrice = 25,
	NitroMax = 3,
	NitroBoost = 12,
	NitroDuration = 4,

	-- Gate 2: Electric River (pulses: calm → warning → shock)
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
	LockCooldown = 90, -- recharge after the shield drops
	ShieldRadius = 16, -- rivals are pushed out of this radius around the Nest
	LockPadRadius = 3.5, -- how close the owner must be to press the pad

	-- Delivery
	DeliverRadius = 7, -- how close to your Nest you must be

	-- Vault spheres on your base (store caught weather; rivals can steal them)
	VaultCount = 4,
	VaultIncomeInterval = 5, -- seconds between passive income ticks
	VaultIncomeRate = 0.1, -- each stored weather pays 10% of its reward per tick
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

return Config
