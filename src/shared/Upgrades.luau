-- Permanent upgrades sold by Aurelius (one at every base). Saved forever —
-- unlike items and perks, upgrades are NOT lost on death.
-- Cost of the next level = BaseCost * (level + 1).

local Upgrades = {}

Upgrades.Types = {
	Speed = {
		DisplayName = "Sky Sprinter",
		IconText = "SPD",
		IconColor = Color3.fromRGB(255, 170, 80),
		Desc = "+4% walk speed per level",
		MaxLevel = 5,
		BaseCost = 150,
		Per = 0.04,
	},
	Jump = {
		DisplayName = "Cloud Legs",
		IconText = "JMP",
		IconColor = Color3.fromRGB(120, 200, 255),
		Desc = "+5% jump height per level",
		MaxLevel = 5,
		BaseCost = 120,
		Per = 0.05,
	},
	Carry = {
		DisplayName = "Strong Grip",
		IconText = "GRP",
		IconColor = Color3.fromRGB(180, 230, 140),
		Desc = "+1 walk speed while carrying a cloud, per level",
		MaxLevel = 4,
		BaseCost = 200,
		Per = 1,
	},
	Income = {
		DisplayName = "Vault Tuner",
		IconText = "VLT",
		IconColor = Color3.fromRGB(255, 220, 90),
		Desc = "+10% vault income per level",
		MaxLevel = 5,
		BaseCost = 250,
		Per = 0.1,
	},
	PerkSlot = {
		DisplayName = "Perk Pocket",
		IconText = "+1",
		IconColor = Color3.fromRGB(255, 140, 210),
		Desc = "+1 Quirks/Perks slot",
		MaxLevel = 1,
		BaseCost = 2000,
		Per = 1,
	},
}

Upgrades.Order = { "Speed", "Jump", "Carry", "Income", "PerkSlot" }

function Upgrades.Cost(id: string, level: number): number
	return Upgrades.Types[id].BaseCost * (level + 1)
end

return Upgrades
