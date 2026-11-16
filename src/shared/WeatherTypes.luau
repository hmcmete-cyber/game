-- Cloud definitions. Add new clouds here.
--
-- Time: "Day" | "Night" | "Any" — when it can spawn (see DayNightService).
--   Night-only clouds that are still wild at sunrise fade away (and vice versa).
-- Zone: which map zone it spawns in (1 Breeze, 2 Thunder Canyon, 3 Cosmic
-- Stratosphere, 0 = Cloud Altar only). Weight = chance inside its zone.
-- Visual: look built by server CloudVisuals.luau (+ client Effects.luau).
-- Perk: what the cloud does when you equip it from your vault into your
-- Quirks/Perks inventory (lost forever if you die while it's equipped).
-- Keys (Rain, Thunder, ...) are saved in player data — never rename a key,
-- change DisplayName instead.

local WeatherTypes = {}

WeatherTypes.Types = {
	-- Zone 1: Breeze Zone ------------------------------------------------
	Cumulus = {
		Time = "Day",
		Perk = { Name = "Cloud Hop", Desc = "+40% jump height", Jump = 1.4 },
		DisplayName = "Cumulus",
		Zone = 1,
		Weight = 50,
		Reward = 8,
		Size = 4,
		Color = Color3.fromRGB(250, 252, 255),
		ParticleColor = Color3.fromRGB(255, 255, 255),
		ParticleAcceleration = Vector3.new(0, 0.5, 0),
		Spin = 0.3,
		Visual = "Cumulus",
	},
	Rain = {
		Time = "Day",
		Perk = { Name = "Slick Feet", Desc = "Rain puddles can't make you slip", NoSlip = true },
		DisplayName = "Rain Cloud",
		Zone = 1,
		Weight = 30,
		Reward = 12,
		Size = 4,
		Color = Color3.fromRGB(110, 160, 230),
		ParticleColor = Color3.fromRGB(120, 180, 255),
		ParticleAcceleration = Vector3.new(0, -40, 0), -- falling drops
		Spin = 0.5,
		Visual = "Rain",
	},
	Snow = {
		Time = "Night",
		Perk = { Name = "Frost Grip", Desc = "Slippery ice can't make you lose control", IceGrip = true },
		DisplayName = "Frost Cloud",
		Zone = 1,
		Weight = 20,
		Reward = 15,
		Size = 4,
		Color = Color3.fromRGB(235, 245, 255),
		ParticleColor = Color3.fromRGB(255, 255, 255),
		ParticleAcceleration = Vector3.new(0, -8, 0), -- slow flakes
		Spin = 0.3,
		Visual = "Snow",
	},

	-- Zone 2: Thunder Canyon ---------------------------------------------
	Thunder = {
		Time = "Night",
		Perk = { Name = "Static Field", Desc = "Rivals near you are slowed; you're immune to electricity", StormAura = true, ElectricImmune = true },
		DisplayName = "Thunder Storm",
		Zone = 2,
		Weight = 40,
		Reward = 45,
		Size = 4.5,
		Color = Color3.fromRGB(55, 55, 75),
		ParticleColor = Color3.fromRGB(255, 240, 120),
		ParticleAcceleration = Vector3.new(0, 0, 0),
		Spin = 1,
		Visual = "Storm",
	},
	Tornado = {
		Time = "Day",
		Perk = { Name = "Eye of the Storm", Desc = "Storm Bridge wind can't push you", WindImmune = true },
		DisplayName = "Pocket Tornado",
		Zone = 2,
		Weight = 30,
		Reward = 35,
		Size = 3.5,
		Color = Color3.fromRGB(170, 165, 150),
		ParticleColor = Color3.fromRGB(210, 205, 190),
		ParticleAcceleration = Vector3.new(0, 15, 0), -- swirling up
		Spin = 8,
		Visual = "Tornado",
	},

	-- Zone 3: Cosmic Stratosphere ----------------------------------------
	Cosmic = {
		Time = "Day",
		Perk = { Name = "Nebula Dash", Desc = "+50% walk speed", Speed = 1.5 },
		DisplayName = "Speed Cloud",
		Zone = 3,
		Weight = 40,
		Reward = 150,
		Size = 4.5,
		Color = Color3.fromRGB(80, 40, 140),
		ParticleColor = Color3.fromRGB(255, 120, 255),
		ParticleAcceleration = Vector3.new(0, 1, 0),
		Spin = 0.8,
		Visual = "Cosmic",
	},
	Aurora = {
		Time = "Night",
		Perk = { Name = "Aurora Mend", Desc = "Regenerate 3 HP every second", Regen = 3 },
		DisplayName = "Auroral Cloud",
		Zone = 3,
		Weight = 40,
		Reward = 150,
		Size = 4.5,
		Color = Color3.fromRGB(150, 255, 210),
		ParticleColor = Color3.fromRGB(120, 255, 170),
		ParticleAcceleration = Vector3.new(0, -1, 0),
		Spin = 0.4,
		Visual = "Aurora",
	},
	Chrono = {
		Time = "Any",
		Perk = { Name = "Time Stretch", Desc = "Shop item effects last twice as long", ItemTime = 2 },
		DisplayName = "Chrono Cloud",
		Zone = 3,
		Weight = 20,
		Reward = 220,
		Size = 4.5,
		Color = Color3.fromRGB(255, 230, 160),
		ParticleColor = Color3.fromRGB(120, 230, 255),
		ParticleAcceleration = Vector3.new(0, 0, 0),
		Spin = 3,
		Visual = "Chrono",
	},

	Phoenix = {
		Time = "Day",
		Perk = { Name = "Phoenix Blood", Desc = "+25% speed, half damage & knockback from lightning", Speed = 1.25, BlastResist = true },
		DisplayName = "Phoenix Cloud",
		Zone = 2,
		Weight = 30,
		Reward = 60,
		Size = 4.5,
		Color = Color3.fromRGB(255, 120, 50),
		ParticleColor = Color3.fromRGB(255, 170, 60),
		ParticleAcceleration = Vector3.new(0, 8, 0), -- rising embers
		Spin = 1.2,
		Visual = "Phoenix",
	},
	Void = {
		Time = "Night",
		Perk = { Name = "Void Step", Desc = "Press the perk key: blink forward and turn invisible for 3 s", Ability = "Blink" },
		DisplayName = "Void Star Cloud",
		Zone = 3,
		Weight = 15,
		Reward = 200,
		Size = 4.5,
		Color = Color3.fromRGB(25, 15, 45),
		ParticleColor = Color3.fromRGB(200, 170, 255),
		ParticleAcceleration = Vector3.new(0, 0, 0),
		Spin = 0.6,
		Visual = "Void",
	},
	Solar = {
		Time = "Day",
		Perk = { Name = "Solar Flare", Desc = "x1.5 coins. Perk key: blind nearby rivals with a flash", CoinMult = 1.5, Ability = "Dazzle" },
		DisplayName = "Solar Flare Cloud",
		Zone = 3,
		Weight = 15,
		Reward = 220,
		Size = 4.5,
		Color = Color3.fromRGB(255, 215, 90),
		ParticleColor = Color3.fromRGB(255, 240, 160),
		ParticleAcceleration = Vector3.new(0, 2, 0),
		Spin = 0.8,
		Visual = "Solar",
	},

	-- Cloud Altar only ----------------------------------------------------
	Mythic = {
		Time = "Any",
		Perk = { Name = "Storm Lord", Desc = "+30% speed & jump, immune to lightning and electricity", Speed = 1.3, Jump = 1.3, ElectricImmune = true, LightningImmune = true, CoinMult = 1.25 },
		DisplayName = "Mythic Storm Cloud",
		Zone = 0,
		Weight = 0,
		Reward = 5000,
		Size = 6,
		Color = Color3.fromRGB(40, 20, 60),
		ParticleColor = Color3.fromRGB(200, 120, 255),
		ParticleAcceleration = Vector3.new(0, 0, 0),
		Spin = 1.5,
		Visual = "Mythic",
	},
}

-- Fixed order (UI lists)
WeatherTypes.Order = { "Cumulus", "Rain", "Snow", "Thunder", "Tornado", "Phoenix", "Cosmic", "Aurora", "Chrono", "Void", "Solar", "Mythic" }

-- Short text + colour for UI icon chips (emoji-free, renders everywhere)
WeatherTypes.Icon = {
	Cumulus = { "CU", Color3.fromRGB(230, 236, 245) },
	Rain = { "RN", Color3.fromRGB(110, 160, 230) },
	Snow = { "FR", Color3.fromRGB(170, 225, 255) },
	Thunder = { "TS", Color3.fromRGB(120, 110, 170) },
	Tornado = { "TO", Color3.fromRGB(190, 180, 150) },
	Phoenix = { "PX", Color3.fromRGB(255, 130, 60) },
	Cosmic = { "CO", Color3.fromRGB(190, 100, 255) },
	Aurora = { "AU", Color3.fromRGB(110, 240, 180) },
	Chrono = { "CH", Color3.fromRGB(255, 220, 140) },
	Void = { "VD", Color3.fromRGB(90, 60, 150) },
	Solar = { "SO", Color3.fromRGB(255, 210, 80) },
	Mythic = { "MY", Color3.fromRGB(255, 90, 120) },
}

-- Which zone a new cloud appears in (overall spawn split)
WeatherTypes.Zones = {
	[1] = { Name = "Breeze Zone", Chance = 70 },
	[2] = { Name = "Thunder Canyon", Chance = 25 },
	[3] = { Name = "Cosmic Stratosphere", Chance = 5 },
}

-- Rarity label shown in the UI (by zone)
WeatherTypes.Rarity = {
	[1] = { Name = "Common", Color = Color3.fromRGB(220, 230, 240) },
	[2] = { Name = "Rare", Color = Color3.fromRGB(110, 190, 255) },
	[3] = { Name = "Epic", Color = Color3.fromRGB(210, 120, 255) },
	[0] = { Name = "Mythic", Color = Color3.fromRGB(255, 90, 120) },
}

function WeatherTypes.RarityOf(typeName: string)
	local def = WeatherTypes.Types[typeName]
	return WeatherTypes.Rarity[def and def.Zone or 1]
end

-- Shiny variant: rare, golden, worth more. Never stronger.
WeatherTypes.ShinyChance = 0.01
WeatherTypes.ShinyMultiplier = 5
WeatherTypes.ShinyColor = Color3.fromRGB(255, 205, 60)

return WeatherTypes
