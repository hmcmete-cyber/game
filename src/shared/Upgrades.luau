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

-- v2.13: Aurelius' 40 Boons (VendorCatalog). One level each, locked until
-- their cloud is offered at Aurelius' Orb. Effects run in PetService.
do
	local ok, Catalog = pcall(require, script.Parent:WaitForChild("VendorCatalog"))
	local PetDefs = require(script.Parent:WaitForChild("PetDefs"))
	if ok then
		for _, id in Catalog.BoonOrder do
			local b = Catalog.Boons[id]
			local spec = PetDefs.BUFF[b.Kind]
			local v = spec.Flag and 1 or spec.Base * b.Tier * 1.5
			local desc
			if spec.Flag then
				desc = spec.Label
			elseif b.Kind == "Shield" then
				desc = string.format(spec.Label, math.floor(30 / v))
			elseif spec.Flat then
				desc = string.format(spec.Label, v)
			else
				desc = string.format(spec.Label, math.floor(v * 100 + 0.5))
			end
			Upgrades.Types[id] = {
				DisplayName = b.DisplayName, IconText = b.IconText, IconColor = b.IconColor,
				Desc = desc .. b.WhenText .. " (permanent)", MaxLevel = 1, BaseCost = b.BaseCost,
				Boon = b, BoonValue = v, Cloud = b.Cloud,
			}
			table.insert(Upgrades.Order, id)
		end
	end
end

function Upgrades.Cost(id: string, level: number): number
	return Upgrades.Types[id].BaseCost * (level + 1)
end

return Upgrades
