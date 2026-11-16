-- Items sold by Tayron at the Cloud Shop. Bought items go into the normal
-- Inventory (NOT the Quirks/Perks inventory). Everything is lost on death.
-- Effects are timed boosts; the Chrono Cloud perk "Time Stretch" doubles them.

local ShopItems = {}

ShopItems.Types = {
	SpeedPotion = {
		DisplayName = "Speed Potion",
		Icon = "🧪",
		Price = 40,
		Desc = "+40% walk speed for 10 s",
		Effect = "Speed",
		Amount = 1.4,
		Duration = 10,
	},
	JumpPotion = {
		DisplayName = "Jump Potion",
		Icon = "🫧",
		Price = 30,
		Desc = "+60% jump height for 10 s",
		Effect = "Jump",
		Amount = 1.6,
		Duration = 10,
	},
	Nitro = {
		DisplayName = "Nitro",
		Icon = "🚀",
		Price = 25,
		Desc = "+12 speed burst for 4 s",
		Effect = "Nitro",
		Amount = 12,
		Duration = 4,
	},
	Flare = {
		DisplayName = "Signal Flare",
		Icon = "📍",
		Price = 20,
		Desc = "Shoots a light pillar everyone can see (call your friends!)",
		Effect = "Flare",
		Duration = 10,
	},
	FuelCan = {
		DisplayName = "Fuel Can",
		Icon = "⛽",
		Price = 50,
		Desc = "For ignite items — coming soon",
		ComingSoon = true,
	},
}

ShopItems.Order = { "SpeedPotion", "JumpPotion", "Nitro", "Flare", "FuelCan" }

return ShopItems
