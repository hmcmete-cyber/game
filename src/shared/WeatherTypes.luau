-- Cloud definitions. Add new clouds here.
--
-- Zone: which map zone it spawns in (1 Breeze, 2 Thunder Canyon, 3 Cosmic
-- Stratosphere, 0 = Cloud Altar only). Weight = chance inside its zone.
-- Visual: look built by server CloudVisuals.luau (+ client Effects.luau).
-- Keys (Rain, Thunder, ...) are saved in player data — never rename a key,
-- change DisplayName instead.

local WeatherTypes = {}

WeatherTypes.Types = {
	-- Zone 1: Breeze Zone ------------------------------------------------
	Cumulus = {
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
		DisplayName = "Snow Cloud",
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
		DisplayName = "Cumulonimbus",
		Zone = 2,
		Weight = 50,
		Reward = 45,
		Size = 4.5,
		Color = Color3.fromRGB(55, 55, 75),
		ParticleColor = Color3.fromRGB(255, 240, 120),
		ParticleAcceleration = Vector3.new(0, 0, 0),
		Spin = 1,
		Visual = "Storm",
	},
	Tornado = {
		DisplayName = "Pocket Tornado",
		Zone = 2,
		Weight = 50,
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
		DisplayName = "Cosmic Neon Cloud",
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

	-- Cloud Altar only ----------------------------------------------------
	Mythic = {
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
WeatherTypes.Order = { "Cumulus", "Rain", "Snow", "Thunder", "Tornado", "Cosmic", "Aurora", "Chrono", "Mythic" }

-- Which zone a new cloud appears in (overall spawn split)
WeatherTypes.Zones = {
	[1] = { Name = "Breeze Zone", Chance = 70 },
	[2] = { Name = "Thunder Canyon", Chance = 25 },
	[3] = { Name = "Cosmic Stratosphere", Chance = 5 },
}

-- Shiny variant: rare, golden, worth more. Never stronger.
WeatherTypes.ShinyChance = 0.01
WeatherTypes.ShinyMultiplier = 5
WeatherTypes.ShinyColor = Color3.fromRGB(255, 205, 60)

return WeatherTypes
