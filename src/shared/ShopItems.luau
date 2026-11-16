-- The 7 items Tayron sells (Item Shop on the hub). Bought items go into the
-- normal Inventory (NOT Quirks/Perks). Everything is lost on death.
--   Charges  = uses you get per purchase      MaxStack = max uses you can hold
--   Aim      = true → the client sends where you're aiming (mouse / screen center)
-- Timed effects are doubled by the Chrono Cloud perk "Time Stretch".

local ShopItems = {}

ShopItems.Types = {
	LaserGun = {
		DisplayName = "Laser Gun",
		IconText = "LSR",
		IconColor = Color3.fromRGB(255, 70, 90),
		Price = 120,
		Charges = 5,
		MaxStack = 15,
		Aim = true,
		Desc = "Shoot thieves: they drop YOUR stolen cloud (it flies home). Others get slowed.",
		Effect = "Laser",
	},
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
		Desc = "Light pillar everyone can see - call your friends",
		Effect = "Flare",
		Duration = 10,
	},
	ShieldGenerator = {
		DisplayName = "Shield Generator",
		IconText = "SHD",
		IconColor = Color3.fromRGB(110, 210, 255),
		Price = 150,
		Desc = "On your base: instant 30 s base shield. Elsewhere: 10 s personal shield (no damage, can't be tagged or shot)",
		Effect = "Shield",
		Duration = 10,
		BaseDuration = 30,
	},
	GrapplingHook = {
		DisplayName = "Grappling Hook",
		IconText = "HOOK",
		IconColor = Color3.fromRGB(190, 160, 120),
		Price = 90,
		Charges = 3,
		MaxStack = 9,
		Aim = true,
		Desc = "Fire a hook up to 90 studs and zip to it - cross between islands fast",
		Effect = "Grapple",
	},
}

ShopItems.Order = { "LaserGun", "SpeedPotion", "JumpPotion", "Nitro", "Flare", "ShieldGenerator", "GrapplingHook" }

return ShopItems
