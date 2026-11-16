-- Items sold by Tayron (Cloud Vendor, one at every base). Bought items go into the normal
-- Inventory (NOT the Quirks/Perks inventory). Everything is lost on death.
-- Effects are timed boosts; the Chrono Cloud perk "Time Stretch" doubles them.

local ShopItems = {}

ShopItems.Types = {
	SpeedPotion = {
		DisplayName = "Speed Potion",
		IconText = "SPD",
		IconColor = Color3.fromRGB(255, 150, 70),
		Price = 40,
		Desc = "+40% walk speed for 10 s",
		Effect = "Speed",
		Amount = 1.4,
		Duration = 10,
	},
	JumpPotion = {
		DisplayName = "Jump Potion",
		IconText = "JMP",
		IconColor = Color3.fromRGB(120, 200, 255),
		Price = 30,
		Desc = "+60% jump height for 10 s",
		Effect = "Jump",
		Amount = 1.6,
		Duration = 10,
	},
	Nitro = {
		DisplayName = "Nitro",
		IconText = "NOS",
		IconColor = Color3.fromRGB(255, 90, 90),
		Price = 25,
		Desc = "+12 speed burst for 4 s",
		Effect = "Nitro",
		Amount = 12,
		Duration = 4,
	},
	Flare = {
		DisplayName = "Signal Flare",
		IconText = "FLR",
		IconColor = Color3.fromRGB(255, 120, 200),
		Price = 20,
		Desc = "Shoots a light pillar everyone can see (call your friends!)",
		Effect = "Flare",
		Duration = 10,
	},
	FuelCan = {
		DisplayName = "Fuel Can",
		IconText = "FUEL",
		IconColor = Color3.fromRGB(150, 150, 165),
		Price = 50,
		Desc = "For ignite items — coming soon",
		ComingSoon = true,
	},
}

ShopItems.Order = { "SpeedPotion", "JumpPotion", "Nitro", "Flare", "FuelCan" }

return ShopItems
