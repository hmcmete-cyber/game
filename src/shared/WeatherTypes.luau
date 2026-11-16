-- Weather creature definitions. Add new weather types here.

local WeatherTypes = {}

WeatherTypes.Types = {
	Rain = {
		DisplayName = "Rain Cloud",
		Color = Color3.fromRGB(110, 160, 230),
		Size = 4,
		Reward = 10,
		Weight = 60, -- relative spawn chance
		ParticleColor = Color3.fromRGB(120, 180, 255),
		ParticleAcceleration = Vector3.new(0, -40, 0), -- falling drops
		Spin = 0.5,
	},
	Tornado = {
		DisplayName = "Pocket Tornado",
		Color = Color3.fromRGB(170, 165, 150),
		Size = 3.5,
		Reward = 25,
		Weight = 20,
		ParticleColor = Color3.fromRGB(210, 205, 190),
		ParticleAcceleration = Vector3.new(0, 15, 0), -- swirling up
		Spin = 8,
	},
	Snow = {
		DisplayName = "Snow Cloud",
		Color = Color3.fromRGB(235, 245, 255),
		Size = 4,
		Reward = 25,
		Weight = 15,
		ParticleColor = Color3.fromRGB(255, 255, 255),
		ParticleAcceleration = Vector3.new(0, -8, 0), -- slow flakes
		Spin = 0.3,
	},
	Thunder = {
		DisplayName = "Thunder Cloud",
		Color = Color3.fromRGB(55, 55, 75),
		Size = 4.5,
		Reward = 60,
		Weight = 5, -- rarest: fast to carry, but everyone can see you
		ParticleColor = Color3.fromRGB(255, 240, 120),
		ParticleAcceleration = Vector3.new(0, 0, 0), -- crackling sparks
		Spin = 1,
	},
}

-- Fixed order (for weighted rolls and UI)
WeatherTypes.Order = { "Rain", "Tornado", "Snow", "Thunder" }

-- Shiny variant: rare, golden, worth more. Never stronger.
WeatherTypes.ShinyChance = 0.01
WeatherTypes.ShinyMultiplier = 5
WeatherTypes.ShinyColor = Color3.fromRGB(255, 205, 60)

return WeatherTypes
