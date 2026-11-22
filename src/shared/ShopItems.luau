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

-- v2.13: Tayron's 40 Gadgets (VendorCatalog), locked until their cloud is
-- offered at Tayron's Orb. Handled in InventoryService.useItem.
do
	local ok, Catalog = pcall(require, script.Parent:WaitForChild("VendorCatalog"))
	if ok then
		local function desc(g): string
			if g.Effect == "Buff" then
				local pct = math.floor(g.Amount * 100 + 0.5)
				local txt = ({
					Speed = `+{pct}% speed`, Jump = `+{pct}% jump`, Resist = `-{pct}% damage taken`, KnockResist = `-{pct}% knockback`,
					Regen = `+{g.Amount} HP/s`, Damage = `+{pct}% damage`, XP = `+{pct}% XP`, Coins = `+{pct}% coins`, Crit = `{pct}% crit`,
					Lifesteal = `{pct}% lifesteal`, Haste = `-{pct}% attack cooldown`, Stealth = `monsters notice you {pct}% later`,
					SlipImmune = "no slipping", ElectricImmune = "shock immune", FireImmune = "burn immune", BlindImmune = "blind immune",
					Cleanse = `debuffs {pct}% shorter`,
				})[g.Kind] or g.Kind
				return `{txt} for {g.Duration} s`
			elseif g.Effect == "Heal" then
				return `Heal {g.Amount} HP`
			elseif g.Effect == "ShieldNow" then
				return `Shield bubble for {g.Duration} s`
			elseif g.Effect == "Blast" then
				return `Blast: {g.Damage} damage to monsters within {g.Radius} studs (+{g.Hit})`
			elseif g.Effect == "Freeze" then
				return `Freezes monsters within {g.Radius} studs for {g.Seconds} s`
			elseif g.Effect == "Recall" then
				return "Teleport to your base (not while carrying)"
			elseif g.Effect == "Dash" then
				return `Dash {g.Distance} studs forward`
			elseif g.Effect == "EggWarm" then
				return `Your incubating egg hatches {g.Minutes} min sooner`
			elseif g.Effect == "Cleanse" then
				return "Removes slows, roots, burns and blindness"
			end
			return ""
		end
		for _, id in Catalog.GadgetOrder do
			local g = Catalog.Gadgets[id]
			local item = table.clone(g)
			item.Desc = desc(g)
			item.Charges = 1
			item.MaxStack = 5
			ShopItems.Types[id] = item
			table.insert(ShopItems.Order, id)
		end
	end
end

-- v2.31 GEAR (director: "Tayron sells GEAR you hold and use, not one-shot
-- items"). Every item is a permanent Tool once bought:
--   simple gear : reusable, short Cooldown after each use
--   OP gear     : 3 charges that refill one by one (Recharge seconds each)
-- Prices are for owning it forever (x5 of the old one-shot price).
local OP_BASE = { LaserGun = 12, GrapplingHook = 8, ShieldGenerator = 90 }
local function cooldownFor(item): number
	local e = item.Effect
	if e == "EggWarm" then
		return item.Minutes * 60 * 2
	elseif e == "Speed" or e == "Jump" or e == "Buff" then
		return (item.Duration or 10) + 20
	elseif e == "Nitro" then
		return 12
	elseif e == "Flare" then
		return 30
	elseif e == "Heal" then
		return 20
	elseif e == "ShieldNow" or e == "Shield" then
		return (item.Duration or 4) * 4
	elseif e == "Cleanse" then
		return 15
	elseif e == "Recall" then
		return 60
	elseif e == "Dash" then
		return 5
	elseif e == "Blast" then
		return 8
	elseif e == "Freeze" then
		return 15
	end
	return 10
end
for id, item in ShopItems.Types do
	item.OneShotPrice = item.Price
	item.Price = math.floor((item.Price or 0) * 5 / 10 + 0.5) * 10
	if OP_BASE[id] or (item.Tier or 0) >= 3 then
		item.Op = true
		item.MaxCharges = 3
		item.Recharge = OP_BASE[id] or (item.Effect == "EggWarm" and item.Minutes * 60 * 2) or ((item.Tier or 3) >= 4 and 120 or 60)
	else
		item.Cooldown = cooldownFor(item)
	end
	-- bombs are thrown where you aim
	if item.Effect == "Blast" or item.Effect == "Freeze" or item.Effect == "Dash" then
		item.Aim = true
	end
end

return ShopItems
