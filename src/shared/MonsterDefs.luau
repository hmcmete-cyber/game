-- MONSTER ROSTER (normal monsters only — bosses come later).
-- Each monster lives in ONE habitat (Shared/BiomeMap), hunts players who
-- CARRY a cloud (or who hit it), uses two signature abilities with a visible
-- wind-up, and gives XP only when defeated (killer 100 %, helpers 50 %).
--
-- Fields
--   Habitat     BiomeMap habitat it roams (never leaves it)
--   Count       how many live at once        Respawn  seconds after death
--   HP, Speed   Humanoid health / walk speed  Scale    rig size multiplier
--   XP          experience on defeat (difficulty-based)
--   Melee       { Damage, Range, Cooldown } basic contact attack
--   Aggro       chase radius (only carriers / attackers)
--   Abilities   two entries { Id, Name, Cooldown, Range, ...params }
--               (implemented in Services/MonsterAbilities.luau)
--   Rig         rig builder in Services/MonsterRigs.luau

local M = {}

M.Order = {
	"Prismaw", "Frostback", "Voltwraith", "Cyclonox", "Cindermaw", "Smoldlet", "Capstride",
	"Sporeback", "Rubbleye", "Bristlehulk", "Gulpvine", "Mossgrave", "Gnashgut",
}

M.Types = {
	Prismaw = {
		Title = "Crystal Stalker", Habitat = "Canyon", Count = 2, Respawn = 90,
		HP = 160, Speed = 17, Scale = 1, XP = 60, Aggro = 60,
		Melee = { Damage = 10, Range = 7, Cooldown = 1.4 },
		Abilities = {
			{ Id = "ShardVolley", Name = "Shard Volley", Cooldown = 7, Range = 45, Damage = 10, Shards = 3, Spread = 15, Slow = 0.6, SlowTime = 2 },
			{ Id = "RefractionDash", Name = "Refraction Dash", Cooldown = 11, Range = 35 },
		},
	},
	Frostback = {
		Title = "Glacier Tortoise", Habitat = "Mountains", Count = 1, Respawn = 120,
		HP = 300, Speed = 10, Scale = 1.3, XP = 110, Aggro = 55,
		Melee = { Damage = 16, Range = 9, Cooldown = 2 },
		Abilities = {
			{ Id = "PermafrostSlam", Name = "Permafrost Slam", Cooldown = 9, Range = 16, Damage = 14, Radius = 16, Windup = 0.9 },
			{ Id = "ShellBastion", Name = "Shell Bastion", Cooldown = 15, Range = 12, Duration = 4, DamageMult = 0.3 },
		},
	},
	Voltwraith = {
		Title = "Storm Wraith", Habitat = "Marsh", Count = 1, Respawn = 110,
		HP = 210, Speed = 18, Scale = 1.1, XP = 85, Aggro = 65, Hover = 3,
		Melee = { Damage = 12, Range = 7, Cooldown = 1.5 },
		Abilities = {
			{ Id = "ChainLightning", Name = "Chain Lightning", Cooldown = 8, Range = 32, Damage = 16, ChainDamage = 10, Jumps = 2, JumpRange = 18, Windup = 0.6 },
			{ Id = "StaticBlink", Name = "Static Blink", Cooldown = 10, Range = 45 },
		},
	},
	Cyclonox = {
		Title = "Living Twister", Habitat = "Plateau", Count = 1, Respawn = 130,
		HP = 300, Speed = 15, Scale = 1.4, XP = 120, Aggro = 70, Hover = 2,
		Melee = { Damage = 14, Range = 9, Cooldown = 1.8 },
		Abilities = {
			{ Id = "VortexPull", Name = "Vortex Pull", Cooldown = 10, Range = 40, Duration = 2.5, Pull = 26 },
			{ Id = "GaleBurst", Name = "Gale Burst", Cooldown = 9, Range = 22, Radius = 24, Damage = 12, Knock = 90, Windup = 0.8 },
		},
	},
	Cindermaw = {
		Title = "Magma Tyrant", Habitat = "Volcanic", Count = 1, Respawn = 140,
		HP = 360, Speed = 12, Scale = 1.4, XP = 140, Aggro = 60,
		Melee = { Damage = 18, Range = 10, Cooldown = 2 },
		Abilities = {
			{ Id = "MagmaGeyser", Name = "Magma Geyser", Cooldown = 8, Range = 50, Damage = 30, Radius = 10, Windup = 1.2, Burn = 3 },
			{ Id = "EmberWings", Name = "Ember Wings", Cooldown = 10, Range = 22, Damage = 15, Angle = 60, Burn = 3, Windup = 0.7 },
		},
	},
	Smoldlet = {
		Title = "Ember Blob", Habitat = "Volcanic", Count = 3, Respawn = 60,
		HP = 60, Speed = 19, Scale = 0.8, XP = 25, Aggro = 50,
		Melee = { Damage = 6, Range = 5, Cooldown = 1.2 },
		Abilities = {
			{ Id = "FuseHop", Name = "Fuse Hop", Cooldown = 7, Range = 30, Damage = 18, Radius = 8, Windup = 0.8 },
			{ Id = "AshPuff", Name = "Ash Puff", Cooldown = 12, Range = 14, Radius = 16, BlindTime = 3 },
		},
	},
	Capstride = {
		Title = "Toadstool Strider", Habitat = "Mushroom", Count = 2, Respawn = 100,
		HP = 170, Speed = 14, Scale = 1.2, XP = 70, Aggro = 55,
		Melee = { Damage = 10, Range = 8, Cooldown = 1.6 },
		Abilities = {
			{ Id = "SporeBloom", Name = "Spore Bloom", Cooldown = 10, Range = 18, Radius = 14, Duration = 5, Damage = 3, Slow = 0.55 },
			{ Id = "SproutSquad", Name = "Sprout Squad", Cooldown = 18, Range = 40, Minions = 2, MinionLife = 20 },
		},
	},
	Sporeback = {
		Title = "Fungal Brute", Habitat = "Mushroom", Count = 1, Respawn = 110,
		HP = 190, Speed = 15, Scale = 1.15, XP = 75, Aggro = 55,
		Melee = { Damage = 12, Range = 8, Cooldown = 1.6 },
		Abilities = {
			{ Id = "SpineSpray", Name = "Spine Spray", Cooldown = 8, Range = 30, Damage = 10, Spines = 12 },
			{ Id = "MyceliumGrip", Name = "Mycelium Grip", Cooldown = 11, Range = 35, RootTime = 1.5, Windup = 0.8 },
		},
	},
	Rubbleye = {
		Title = "Watching Rubble", Habitat = "Mountains", Count = 2, Respawn = 100,
		HP = 200, Speed = 13, Scale = 1.1, XP = 80, Aggro = 60, Hover = 4,
		Melee = { Damage = 12, Range = 8, Cooldown = 1.6 },
		Abilities = {
			{ Id = "OrbitCrush", Name = "Orbit Crush", Cooldown = 9, Range = 14, Radius = 14, Damage = 15, Knock = 60, Windup = 0.8 },
			{ Id = "VoidGaze", Name = "Void Gaze", Cooldown = 10, Range = 50, Damage = 25, Width = 3, Windup = 1.0 },
		},
	},
	Bristlehulk = {
		Title = "Bramble Brute", Habitat = "Plateau", Count = 2, Respawn = 100,
		HP = 180, Speed = 15, Scale = 1.2, XP = 65, Aggro = 55,
		Melee = { Damage = 12, Range = 8, Cooldown = 1.5 },
		Abilities = {
			{ Id = "ThornCharge", Name = "Thorn Charge", Cooldown = 9, Range = 40, Damage = 18, Knock = 70, Windup = 0.7 },
			{ Id = "BrambleWall", Name = "Bramble Wall", Cooldown = 14, Range = 35, Duration = 5 },
		},
	},
	Gulpvine = {
		Title = "Storm Snapper", Habitat = "Marsh", Count = 3, Respawn = 70,
		HP = 110, Speed = 0, Scale = 1, XP = 40, Aggro = 30, Rooted = true,
		Melee = { Damage = 8, Range = 9, Cooldown = 1.4 },
		Abilities = {
			{ Id = "SnapLunge", Name = "Volt Snap", Cooldown = 6, Range = 12, Damage = 15, HoldTime = 1, ShockTime = 2 },
			{ Id = "AcidSpit", Name = "Storm Spit", Cooldown = 7, Range = 32, Damage = 6, Radius = 6, Duration = 4 },
		},
	},
	Mossgrave = {
		Title = "Mossy Golem", Habitat = "Canyon", Count = 1, Respawn = 120,
		HP = 260, Speed = 11, Scale = 1.35, XP = 95, Aggro = 60,
		Melee = { Damage = 16, Range = 10, Cooldown = 2 },
		Abilities = {
			{ Id = "BoulderToss", Name = "Boulder Toss", Cooldown = 8, Range = 55, Damage = 22, Radius = 9, Windup = 1.2 },
			{ Id = "VineLash", Name = "Vine Lash", Cooldown = 10, Range = 30, Pull = 70 },
		},
	},
	Gnashgut = {
		Title = "Fanged Glutton", Habitat = "Marsh", Count = 1, Respawn = 100,
		HP = 180, Speed = 16, Scale = 1.2, XP = 70, Aggro = 55,
		Melee = { Damage = 10, Range = 8, Cooldown = 1.5 },
		Abilities = {
			{ Id = "FrenzyBite", Name = "Frenzy Bite", Cooldown = 7, Range = 8, Damage = 8, Bites = 3 },
			{ Id = "GroundPound", Name = "Ground Pound", Cooldown = 10, Range = 12, Radius = 12, Damage = 12, Stun = 0.8, Windup = 0.7 },
		},
	},
	-- summoned by Capstride's Sprout Squad (not part of the habitat population)
	Shroomling = {
		Title = "Sprout", Habitat = "Mushroom", Count = 0, Respawn = 0, Summon = true,
		HP = 30, Speed = 20, Scale = 0.6, XP = 5, Aggro = 60,
		Melee = { Damage = 4, Range = 5, Cooldown = 1.2, Trip = true },
		Abilities = {},
	},
}

-- Global tuning
M.WakeRadius = 260 -- monsters only think when a player is this close
M.SafeRadius = 130 -- no spawns/aggro this close to the Sky Heart (updraft landing)
M.Tether = 240 -- max distance from home before a monster walks back
M.AssistShare = 0.5 -- XP share for players who helped (>= 10 % of the damage)

return M
