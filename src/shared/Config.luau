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
