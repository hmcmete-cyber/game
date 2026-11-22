-- CLOUD DATABASE — every cloud in the game (156). Add a line to add a cloud.
--
-- C(key, displayName, rarity, options)
--   key        saved in player data: NEVER rename a key once players have it
--   rarity     "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"
--   options
--     Biomes   where it spawns: { "Plateau", "Coast", "Mountains", "Valley" } or { "Any" }
--     Time     "Day" | "Night" | "Any"
--     Weight   chance inside its rarity tier (default 10)
--     Reward   coins on delivery (default by rarity)
--     Visual   look: Cumulus Rain Snow Tornado Storm Cosmic Aurora Chrono Phoenix Void Solar Mythic
--     Tint     main colour; Glow = particle/light colour
--     Perk     what it does in your Quirks/Perks inventory:
--              Speed, Jump, CoinMult (multipliers) · Regen (HP/s) · DamageResist (0-1)
--              NoSlip, IceGrip, WindImmune, ElectricImmune, LightningImmune, BlastResist, StormAura (flags)
--              ItemTime (item effect ×) · Ability = "Blink" | "Dazzle" (keys G/H/J)
--     AltarOnly true → only Cloud Altars can spawn it
--
-- Spawn chance of a cloud = tier chance (see WeatherTypes.Rarity) × its share
-- of the tier's weight among clouds allowed in that biome at that time.
-- WeatherTypes.ChanceTable(biome, isNight) lists the real percentages.

local rgb = Color3.fromRGB

local list = {}
local function C(key: string, name: string, rarity: string, o: { [string]: any })
	o.Key = key
	o.DisplayName = name
	o.Rarity = rarity
	table.insert(list, o)
end

local ALL = { "Any" }

------------------------------------------------------------------------
-- COMMON (16) — small buffs, cheap
------------------------------------------------------------------------
C("Cumulus", "Cumulus", "Common", { Biomes = { "Plateau", "Coast" }, Time = "Day", Weight = 14, Visual = "Cumulus",
	Perk = { Name = "Cloud Hop", Desc = "+10% jump", Jump = 1.1 } })
C("Rain", "Rain Cloud", "Common", { Biomes = { "Plateau", "Valley" }, Time = "Day", Weight = 12, Visual = "Rain",
	Perk = { Name = "Slick Feet", Desc = "Rain puddles can't make you slip", NoSlip = true } })
C("CottonPuff", "Cotton Puff", "Common", { Biomes = { "Plateau" }, Time = "Any", Visual = "Cumulus", Tint = rgb(255, 245, 250),
	Perk = { Name = "Soft Steps", Desc = "+5% speed", Speed = 1.05 } })
C("Drizzle", "Drizzle", "Common", { Biomes = { "Valley", "Coast" }, Time = "Any", Visual = "Rain", Tint = rgb(170, 190, 215),
	Perk = { Name = "Damp", Desc = "+1 HP/s", Regen = 1 } })
C("MorningMist", "Morning Mist", "Common", { Biomes = { "Plateau", "Valley" }, Time = "Day", Visual = "Cumulus", Tint = rgb(235, 240, 235),
	Perk = { Name = "Haze Walker", Desc = "+5% coins", CoinMult = 1.05 } })
C("Breeze", "Breeze Cloud", "Common", { Biomes = { "Coast", "Mountains" }, Time = "Day", Visual = "Tornado", Tint = rgb(225, 245, 245),
	Perk = { Name = "Light Wind", Desc = "+6% speed", Speed = 1.06 } })
C("Haze", "Haze", "Common", { Biomes = ALL, Time = "Any", Weight = 8, Visual = "Cumulus", Tint = rgb(220, 215, 205),
	Perk = { Name = "Blur", Desc = "+5% jump, +3% speed", Jump = 1.05, Speed = 1.03 } })
C("NimbusJr", "Nimbus Jr.", "Common", { Biomes = { "Plateau" }, Time = "Any", Visual = "Rain", Tint = rgb(160, 170, 190),
	Perk = { Name = "Little Storm", Desc = "+8% jump", Jump = 1.08 } })
C("Marshmallow", "Marshmallow Cloud", "Common", { Biomes = { "Plateau", "Coast" }, Time = "Day", Visual = "Cumulus", Tint = rgb(255, 230, 240),
	Perk = { Name = "Sugar Rush", Desc = "+7% speed", Speed = 1.07 } })
C("Dew", "Dew Cloud", "Common", { Biomes = { "Valley" }, Time = "Day", Visual = "Snow", Tint = rgb(210, 245, 230),
	Perk = { Name = "Fresh", Desc = "+1 HP/s", Regen = 1 } })
C("SandSquall", "Sand Squall", "Common", { Biomes = { "Coast" }, Time = "Day", Visual = "Tornado", Tint = rgb(240, 215, 160),
	Perk = { Name = "Grit", Desc = "10% less damage", DamageResist = 0.1 } })
C("SeaFoam", "Sea Foam Cloud", "Common", { Biomes = { "Coast" }, Time = "Any", Visual = "Snow", Tint = rgb(200, 245, 240),
	Perk = { Name = "Surf", Desc = "+6% speed", Speed = 1.06 } })
C("Pebble", "Pebble Cloud", "Common", { Biomes = { "Valley" }, Time = "Any", Visual = "Cumulus", Tint = rgb(190, 185, 180),
	Perk = { Name = "Sturdy", Desc = "10% less damage", DamageResist = 0.1 } })
C("PineFog", "Pine Fog", "Common", { Biomes = { "Mountains" }, Time = "Any", Visual = "Cumulus", Tint = rgb(200, 225, 205),
	Perk = { Name = "Climber", Desc = "+10% jump", Jump = 1.1 } })
C("DuskWisp", "Dusk Wisp", "Common", { Biomes = ALL, Time = "Night", Visual = "Aurora", Tint = rgb(210, 180, 230),
	Perk = { Name = "Twilight", Desc = "+5% coins", CoinMult = 1.05 } })
C("Moonlet", "Moonlet", "Common", { Biomes = { "Plateau", "Mountains" }, Time = "Night", Visual = "Snow", Tint = rgb(225, 230, 255),
	Perk = { Name = "Moon Hop", Desc = "+12% jump", Jump = 1.12 } })

------------------------------------------------------------------------
-- RARE (14)
------------------------------------------------------------------------
C("Snow", "Frost Cloud", "Rare", { Biomes = { "Mountains" }, Time = "Night", Weight = 14, Visual = "Snow",
	Perk = { Name = "Frost Grip", Desc = "Slippery ice can't make you lose control", IceGrip = true } })
C("Tornado", "Pocket Tornado", "Rare", { Biomes = { "Coast", "Valley" }, Time = "Day", Weight = 12, Visual = "Tornado",
	Perk = { Name = "Eye of the Storm", Desc = "Wind can't push you", WindImmune = true } })
C("Gale", "Gale Cloud", "Rare", { Biomes = { "Mountains", "Coast" }, Time = "Any", Visual = "Tornado", Tint = rgb(200, 230, 255),
	Perk = { Name = "Tailwind", Desc = "+12% speed, wind can't push you", Speed = 1.12, WindImmune = true } })
C("Hail", "Hail Cloud", "Rare", { Biomes = { "Mountains" }, Time = "Any", Visual = "Snow", Tint = rgb(190, 210, 235),
	Perk = { Name = "Hard Shell", Desc = "20% less damage", DamageResist = 0.2 } })
C("Blossom", "Cherry Blossom Cloud", "Rare", { Biomes = { "Plateau" }, Time = "Day", Visual = "Aurora", Tint = rgb(255, 190, 215), Glow = rgb(255, 170, 200),
	Perk = { Name = "Bloom", Desc = "+2 HP/s", Regen = 2 } })
C("Tidal", "Tidal Cloud", "Rare", { Biomes = { "Coast" }, Time = "Any", Visual = "Rain", Tint = rgb(110, 190, 220),
	Perk = { Name = "Current", Desc = "+14% speed", Speed = 1.14 } })
C("Ember", "Ember Cloud", "Rare", { Biomes = { "Valley" }, Time = "Any", Visual = "Phoenix", Tint = rgb(255, 160, 110),
	Perk = { Name = "Heat Proof", Desc = "Half lightning damage & knockback", BlastResist = true } })
C("Coral", "Coral Cloud", "Rare", { Biomes = { "Coast" }, Time = "Day", Visual = "Cumulus", Tint = rgb(255, 170, 160),
	Perk = { Name = "Reef Luck", Desc = "+12% coins", CoinMult = 1.12 } })
C("Avalanche", "Avalanche Cloud", "Rare", { Biomes = { "Mountains" }, Time = "Day", Visual = "Snow", Tint = rgb(240, 248, 255),
	Perk = { Name = "Snowshoe", Desc = "Ice grip, +10% jump", IceGrip = true, Jump = 1.1 } })
C("Firefly", "Firefly Cloud", "Rare", { Biomes = { "Plateau", "Valley" }, Time = "Night", Visual = "Solar", Tint = rgb(220, 255, 140), Glow = rgb(200, 255, 120),
	Perk = { Name = "Glow Mend", Desc = "+2 HP/s", Regen = 2 } })
C("Echo", "Echo Cloud", "Rare", { Biomes = { "Valley" }, Time = "Any", Visual = "Cumulus", Tint = rgb(200, 200, 230),
	Perk = { Name = "Rebound", Desc = "+22% jump", Jump = 1.22 } })
C("CopperStorm", "Copper Storm", "Rare", { Biomes = { "Valley", "Mountains" }, Time = "Night", Visual = "Storm", Tint = rgb(180, 120, 90), Glow = rgb(255, 190, 120),
	Perk = { Name = "Grounded", Desc = "Immune to electricity", ElectricImmune = true } })
C("Lavender", "Lavender Haze", "Rare", { Biomes = { "Plateau" }, Time = "Any", Visual = "Aurora", Tint = rgb(210, 190, 255),
	Perk = { Name = "Calm Profit", Desc = "+15% coins", CoinMult = 1.15 } })
C("Hourglass", "Hourglass Cloud", "Rare", { Biomes = ALL, Time = "Any", Weight = 6, Visual = "Chrono", Tint = rgb(240, 220, 170),
	Perk = { Name = "Slow Sand", Desc = "Items last 50% longer", ItemTime = 1.5 } })

------------------------------------------------------------------------
-- EPIC (12)
------------------------------------------------------------------------
C("Thunder", "Thunder Storm", "Epic", { Biomes = { "Valley", "Mountains" }, Time = "Night", Weight = 14, Visual = "Storm",
	Perk = { Name = "Static Field", Desc = "Slows rivals near you; immune to electricity", StormAura = true, ElectricImmune = true } })
C("Phoenix", "Phoenix Cloud", "Epic", { Biomes = { "Valley" }, Time = "Day", Weight = 12, Visual = "Phoenix",
	Perk = { Name = "Phoenix Blood", Desc = "+25% speed, half lightning damage", Speed = 1.25, BlastResist = true } })
C("Aurora", "Auroral Cloud", "Epic", { Biomes = { "Mountains", "Coast" }, Time = "Night", Weight = 12, Visual = "Aurora",
	Perk = { Name = "Aurora Mend", Desc = "+4 HP/s", Regen = 4 } })
C("Cosmic", "Speed Cloud", "Epic", { Biomes = { "Plateau" }, Time = "Day", Weight = 12, Visual = "Cosmic",
	Perk = { Name = "Nebula Dash", Desc = "+30% speed", Speed = 1.3 } })
C("Chrono", "Chrono Cloud", "Epic", { Biomes = ALL, Time = "Any", Weight = 8, Visual = "Chrono",
	Perk = { Name = "Time Stretch", Desc = "Items last twice as long", ItemTime = 2 } })
C("Prism", "Prism Cloud", "Epic", { Biomes = { "Plateau", "Coast" }, Time = "Day", Visual = "Cosmic", Tint = rgb(200, 240, 255),
	Perk = { Name = "Refraction", Desc = "+25% coins", CoinMult = 1.25 } })
C("Glacier", "Glacier Cloud", "Epic", { Biomes = { "Mountains" }, Time = "Any", Visual = "Snow", Tint = rgb(170, 220, 255),
	Perk = { Name = "Ice Armor", Desc = "Ice grip, 25% less damage", IceGrip = true, DamageResist = 0.25 } })
C("Magma", "Magma Cloud", "Epic", { Biomes = { "Valley" }, Time = "Any", Visual = "Phoenix", Tint = rgb(220, 80, 40),
	Perk = { Name = "Molten Core", Desc = "+15% speed, half lightning damage", Speed = 1.15, BlastResist = true } })
C("Monsoon", "Monsoon", "Epic", { Biomes = { "Coast", "Valley" }, Time = "Any", Visual = "Rain", Tint = rgb(90, 130, 190),
	Perk = { Name = "Downpour", Desc = "+20% speed, no puddle slips", Speed = 1.2, NoSlip = true } })
C("Cyclone", "Cyclone", "Epic", { Biomes = { "Coast" }, Time = "Any", Visual = "Tornado", Tint = rgb(180, 200, 215),
	Perk = { Name = "Spin Up", Desc = "+30% jump, wind can't push you", Jump = 1.3, WindImmune = true } })
C("Nebula", "Nebula Cloud", "Epic", { Biomes = { "Plateau", "Mountains" }, Time = "Night", Visual = "Cosmic", Tint = rgb(120, 70, 190),
	Perk = { Name = "Stardust", Desc = "+30% coins", CoinMult = 1.3 } })
C("ThunderheadEpic", "Thunderhead", "Epic", { Biomes = { "Mountains" }, Time = "Any", Visual = "Storm", Tint = rgb(90, 95, 120),
	Perk = { Name = "Lightning Rod", Desc = "Immune to lightning", LightningImmune = true } })

------------------------------------------------------------------------
-- LEGENDARY (8)
------------------------------------------------------------------------
C("Void", "Void Star Cloud", "Legendary", { Biomes = { "Valley" }, Time = "Night", Weight = 12, Visual = "Void",
	Perk = { Name = "Void Step", Desc = "Blink forward + 3 s invisibility (G/H/J); +15% speed", Ability = "Blink", Speed = 1.15 } })
C("Solar", "Solar Flare Cloud", "Legendary", { Biomes = { "Plateau", "Coast" }, Time = "Day", Weight = 12, Visual = "Solar",
	Perk = { Name = "Solar Flare", Desc = "x1.5 coins; blind nearby rivals (G/H/J)", CoinMult = 1.5, Ability = "Dazzle" } })
C("Celestial", "Celestial Cloud", "Legendary", { Biomes = { "Mountains" }, Time = "Day", Visual = "Cosmic", Tint = rgb(255, 245, 220), Glow = rgb(255, 230, 160),
	Perk = { Name = "Heavenly", Desc = "+40% speed, +40% coins", Speed = 1.4, CoinMult = 1.4 } })
C("Tempest", "Tempest King", "Legendary", { Biomes = { "Valley", "Mountains" }, Time = "Night", Visual = "Storm", Tint = rgb(60, 60, 95),
	Perk = { Name = "Storm Crown", Desc = "Slow rivals near you, immune to lightning, +30% speed", StormAura = true, LightningImmune = true, Speed = 1.3 } })
C("Leviathan", "Leviathan Squall", "Legendary", { Biomes = { "Coast" }, Time = "Any", Visual = "Rain", Tint = rgb(40, 110, 150), Glow = rgb(120, 230, 255),
	Perk = { Name = "Deep Tide", Desc = "+5 HP/s, 30% less damage", Regen = 5, DamageResist = 0.3 } })
C("Starfall", "Starfall Cloud", "Legendary", { Biomes = { "Plateau", "Mountains" }, Time = "Night", Visual = "Void", Tint = rgb(60, 50, 110), Glow = rgb(255, 240, 200),
	Perk = { Name = "Shooting Star", Desc = "+60% jump, +30% coins", Jump = 1.6, CoinMult = 1.3 } })
C("Obsidian", "Obsidian Storm", "Legendary", { Biomes = { "Valley" }, Time = "Any", Visual = "Storm", Tint = rgb(35, 30, 40), Glow = rgb(255, 120, 80),
	Perk = { Name = "Black Glass", Desc = "40% less damage, half lightning knockback", DamageResist = 0.4, BlastResist = true } })
C("Zenith", "Zenith Cloud", "Legendary", { Biomes = { "Mountains" }, Time = "Day", Visual = "Solar", Tint = rgb(255, 250, 235),
	Perk = { Name = "Summit", Desc = "+45% speed, ice grip, wind-proof", Speed = 1.45, IceGrip = true, WindImmune = true } })

------------------------------------------------------------------------
-- MYTHIC (6)
------------------------------------------------------------------------
C("Mythic", "Mythic Storm Cloud", "Mythic", { Biomes = ALL, Time = "Any", AltarOnly = true, Reward = 5000, Visual = "Mythic",
	Perk = { Name = "Storm Lord", Desc = "+30% speed & jump, x1.25 coins, immune to lightning & electricity",
		Speed = 1.3, Jump = 1.3, CoinMult = 1.25, ElectricImmune = true, LightningImmune = true } })
C("Genesis", "Genesis Cloud", "Mythic", { Biomes = { "Plateau" }, Time = "Day", Visual = "Solar", Tint = rgb(255, 255, 240), Glow = rgb(255, 255, 200),
	Perk = { Name = "First Light", Desc = "+50% speed, jump and coins", Speed = 1.5, Jump = 1.5, CoinMult = 1.5 } })
C("Eclipse", "Eclipse Cloud", "Mythic", { Biomes = ALL, Time = "Night", Visual = "Void", Tint = rgb(15, 10, 20), Glow = rgb(255, 200, 120),
	Perk = { Name = "Totality", Desc = "Blink + invisibility (G/H/J), x1.6 coins, 30% less damage", Ability = "Blink", CoinMult = 1.6, DamageResist = 0.3 } })
C("Seraph", "Seraph Cloud", "Mythic", { Biomes = { "Mountains" }, Time = "Day", Visual = "Aurora", Tint = rgb(255, 250, 220), Glow = rgb(255, 230, 150),
	Perk = { Name = "Halo", Desc = "+8 HP/s, +80% jump, immune to lightning & electricity", Regen = 8, Jump = 1.8, LightningImmune = true, ElectricImmune = true } })
C("AbyssalMaw", "Abyssal Maw", "Mythic", { Biomes = { "Valley" }, Time = "Night", Visual = "Void", Tint = rgb(40, 10, 50), Glow = rgb(200, 60, 255),
	Perk = { Name = "Devour", Desc = "Slow rivals near you, 50% less damage, +40% speed", StormAura = true, DamageResist = 0.5, Speed = 1.4 } })
C("RainbowDragon", "Rainbow Dragon", "Mythic", { Biomes = { "Coast" }, Time = "Day", Visual = "Cosmic", Tint = rgb(255, 200, 230),
	Perk = { Name = "Dragon's Hoard", Desc = "+60% speed, x2 coins", Speed = 1.6, CoinMult = 2 } })

------------------------------------------------------------------------
-- v1.4 EXPANSION (50) — four categories, new biomes
--   Category: "Elemental" (Fire Ice Electric Poison Water Earth) · "SpaceTime"
--             · "Economic" (Bonus = { XP, ItemChance }) · "Chaos"
--   New perk stats: Gravity (0-0.6 = less gravity) · FireImmune (lava)
--             · PoisonImmune (acid rain) · Chaos (random buff/debuff every 20 s)
--             · Ability "Quake" (shakes everyone near you)
-- Biomes: Plateau Coast Mountains Mushroom Marsh Canyon Volcanic
--   ("Valley" in older entries = Canyon)
------------------------------------------------------------------------

-- COMMON (14)
C("Cinder", "Cinder Puff", "Common", { Category = "Elemental", Element = "Fire", Biomes = { "Volcanic" }, Time = "Any", Visual = "Phoenix", Tint = rgb(255, 150, 90),
	Perk = { Name = "Warm Soles", Desc = "+6% speed", Speed = 1.06 } })
C("Frostbite", "Frostbite", "Common", { Category = "Elemental", Element = "Ice", Biomes = { "Mountains" }, Time = "Any", Visual = "Snow", Tint = rgb(220, 240, 255),
	Perk = { Name = "Cold Grip", Desc = "Grip on ice", IceGrip = true } })
C("Static", "Static Fluff", "Common", { Category = "Elemental", Element = "Electric", Biomes = { "Marsh", "Plateau" }, Time = "Any", Visual = "Storm", Tint = rgb(190, 190, 120),
	Perk = { Name = "Charged", Desc = "+5% speed, +5% jump", Speed = 1.05, Jump = 1.05 } })
C("Spore", "Spore Cloud", "Common", { Category = "Elemental", Element = "Poison", Biomes = { "Mushroom" }, Time = "Any", Weight = 14, Visual = "Cumulus", Tint = rgb(190, 230, 140), Glow = rgb(200, 255, 120),
	Perk = { Name = "Spore Lungs", Desc = "+1 HP/s", Regen = 1 } })
C("Puddle", "Puddle Cloud", "Common", { Category = "Elemental", Element = "Water", Biomes = { "Marsh", "Coast" }, Time = "Any", Visual = "Rain", Tint = rgb(130, 180, 220),
	Perk = { Name = "Splash", Desc = "Can't slip on puddles", NoSlip = true } })
C("Dust", "Dust Devil", "Common", { Category = "Elemental", Element = "Earth", Biomes = { "Canyon" }, Time = "Day", Visual = "Tornado", Tint = rgb(200, 170, 130),
	Perk = { Name = "Sandy", Desc = "8% less damage", DamageResist = 0.08 } })
C("Feather", "Feather Cloud", "Common", { Category = "SpaceTime", Biomes = { "Plateau", "Mushroom" }, Time = "Day", Visual = "Cumulus", Tint = rgb(255, 255, 255),
	Perk = { Name = "Featherweight", Desc = "15% less gravity", Gravity = 0.15 } })
C("Tick", "Tick Cloud", "Common", { Category = "SpaceTime", Biomes = { "Plateau" }, Time = "Any", Visual = "Chrono", Tint = rgb(245, 235, 200),
	Perk = { Name = "Quick Tick", Desc = "Items last 15% longer", ItemTime = 1.15 } })
C("Copper", "Copper Coin Cloud", "Common", { Category = "Economic", Biomes = ALL, Time = "Day", Weight = 8, Visual = "Solar", Tint = rgb(215, 150, 90), Reward = 25,
	Bonus = { XP = 10 }, Perk = { Name = "Penny Saver", Desc = "+8% coins", CoinMult = 1.08 } })
C("Satchel", "Satchel Cloud", "Common", { Category = "Economic", Biomes = { "Coast", "Plateau" }, Time = "Any", Visual = "Cumulus", Tint = rgb(225, 200, 160),
	Bonus = { ItemChance = 0.15 }, Perk = { Name = "Deep Pockets", Desc = "+5% coins", CoinMult = 1.05 } })
C("Hiccup", "Hiccup Cloud", "Common", { Category = "Chaos", Biomes = ALL, Time = "Any", Weight = 6, Visual = "Cosmic", Tint = rgb(255, 190, 220),
	Perk = { Name = "Hic!", Desc = "Random buff or debuff every 20 s", Chaos = true } })
C("Mushcap", "Mushcap Cloud", "Common", { Category = "Elemental", Element = "Earth", Biomes = { "Mushroom" }, Time = "Any", Visual = "Cumulus", Tint = rgb(230, 120, 120),
	Perk = { Name = "Bouncy Cap", Desc = "+12% jump", Jump = 1.12 } })
C("BogMist", "Bog Mist", "Common", { Category = "Elemental", Element = "Poison", Biomes = { "Marsh" }, Time = "Night", Visual = "Cumulus", Tint = rgb(150, 170, 130),
	Perk = { Name = "Bog Born", Desc = "Acid rain can't hurt you", PoisonImmune = true } })
C("Pumice", "Pumice Puff", "Common", { Category = "Elemental", Element = "Earth", Biomes = { "Volcanic" }, Time = "Day", Visual = "Cumulus", Tint = rgb(180, 170, 165),
	Perk = { Name = "Light Stone", Desc = "10% less gravity", Gravity = 0.1 } })

-- RARE (14)
C("Wildfire", "Wildfire Cloud", "Rare", { Category = "Elemental", Element = "Fire", Biomes = { "Volcanic" }, Time = "Any", Visual = "Phoenix", Tint = rgb(255, 110, 50),
	Perk = { Name = "Firewalker", Desc = "Lava can't hurt you, +10% speed", FireImmune = true, Speed = 1.1 } })
C("Icicle", "Icicle Cloud", "Rare", { Category = "Elemental", Element = "Ice", Biomes = { "Mountains" }, Time = "Night", Visual = "Snow", Tint = rgb(190, 225, 255),
	Perk = { Name = "Ice Skates", Desc = "Grip on ice, +12% speed", IceGrip = true, Speed = 1.12 } })
C("Sparkbolt", "Sparkbolt", "Rare", { Category = "Elemental", Element = "Electric", Biomes = { "Marsh" }, Time = "Any", Visual = "Storm", Tint = rgb(80, 80, 120), Glow = rgb(255, 255, 140),
	Perk = { Name = "Grounded", Desc = "Immune to electric water", ElectricImmune = true } })
C("Toxic", "Toxic Cloud", "Rare", { Category = "Elemental", Element = "Poison", Biomes = { "Marsh", "Mushroom" }, Time = "Night", Visual = "Rain", Tint = rgb(130, 200, 60), Glow = rgb(180, 255, 80),
	Perk = { Name = "Acid Proof", Desc = "Acid rain can't hurt you, +2 HP/s", PoisonImmune = true, Regen = 2 } })
C("Geyser", "Geyser Cloud", "Rare", { Category = "Elemental", Element = "Water", Biomes = { "Volcanic", "Coast" }, Time = "Day", Visual = "Rain", Tint = rgb(170, 220, 255),
	Perk = { Name = "Steam Jump", Desc = "+25% jump", Jump = 1.25 } })
C("Boulder", "Boulder Cloud", "Rare", { Category = "Elemental", Element = "Earth", Biomes = { "Canyon", "Mountains" }, Time = "Any", Visual = "Storm", Tint = rgb(140, 120, 100), Glow = rgb(220, 190, 150),
	Perk = { Name = "Rock Solid", Desc = "18% less damage, half lightning knockback", DamageResist = 0.18, BlastResist = true } })
C("Drift", "Drift Cloud", "Rare", { Category = "SpaceTime", Biomes = { "Plateau", "Coast" }, Time = "Any", Visual = "Cosmic", Tint = rgb(170, 160, 255),
	Perk = { Name = "Moonwalk", Desc = "30% less gravity", Gravity = 0.3 } })
C("Rewind", "Rewind Cloud", "Rare", { Category = "SpaceTime", Biomes = { "Canyon" }, Time = "Night", Visual = "Chrono", Tint = rgb(150, 220, 255),
	Perk = { Name = "Long Effects", Desc = "Items last 30% longer, +8% speed", ItemTime = 1.3, Speed = 1.08 } })
C("Silver", "Silver Lining", "Rare", { Category = "Economic", Biomes = ALL, Time = "Day", Weight = 7, Visual = "Solar", Tint = rgb(220, 225, 235), Reward = 90,
	Bonus = { XP = 30 }, Perk = { Name = "Silver Tongue", Desc = "+15% coins", CoinMult = 1.15 } })
C("Merchant", "Merchant Cloud", "Rare", { Category = "Economic", Biomes = { "Coast", "Mushroom" }, Time = "Any", Visual = "Cumulus", Tint = rgb(255, 220, 150),
	Bonus = { ItemChance = 0.35 }, Perk = { Name = "Bargain", Desc = "+10% coins, items last 15% longer", CoinMult = 1.1, ItemTime = 1.15 } })
C("Jester", "Jester Cloud", "Rare", { Category = "Chaos", Biomes = ALL, Time = "Any", Weight = 6, Visual = "Cosmic", Tint = rgb(255, 120, 200),
	Perk = { Name = "Wild Card", Desc = "Random buff/debuff every 20 s, +10% coins", Chaos = true, CoinMult = 1.1 } })
C("Rumble", "Rumble Cloud", "Rare", { Category = "Chaos", Biomes = { "Canyon", "Volcanic" }, Time = "Any", Visual = "Storm", Tint = rgb(120, 90, 80), Glow = rgb(255, 170, 90),
	Perk = { Name = "Rumble", Desc = "Quake (G/H/J): shake everyone near you", Ability = "Quake" } })
C("Glowcap", "Glowcap Cloud", "Rare", { Category = "Elemental", Element = "Poison", Biomes = { "Mushroom" }, Time = "Night", Visual = "Aurora", Tint = rgb(120, 230, 255), Glow = rgb(120, 255, 240),
	Perk = { Name = "Bioluminescent", Desc = "+20% jump, +2 HP/s", Jump = 1.2, Regen = 2 } })
C("Quartz", "Quartz Cloud", "Rare", { Category = "Elemental", Element = "Earth", Biomes = { "Canyon" }, Time = "Any", Visual = "Chrono", Tint = rgb(255, 200, 240), Glow = rgb(255, 160, 230),
	Perk = { Name = "Crystal Skin", Desc = "15% less damage, +10% coins", DamageResist = 0.15, CoinMult = 1.1 } })

-- EPIC (11)
C("Inferno", "Inferno Cloud", "Epic", { Category = "Elemental", Element = "Fire", Biomes = { "Volcanic" }, Time = "Night", Visual = "Phoenix", Tint = rgb(255, 70, 30), Glow = rgb(255, 200, 80),
	Perk = { Name = "Inferno", Desc = "Lava-proof, +25% speed, slows rivals near you", FireImmune = true, Speed = 1.25, StormAura = true } })
C("Blizzard", "Blizzard", "Epic", { Category = "Elemental", Element = "Ice", Biomes = { "Mountains" }, Time = "Any", Visual = "Snow", Tint = rgb(240, 250, 255), Glow = rgb(180, 230, 255),
	Perk = { Name = "Whiteout", Desc = "Ice grip, wind-proof, +20% speed", IceGrip = true, WindImmune = true, Speed = 1.2 } })
C("Thunderhead2", "Volt Marsh Storm", "Epic", { Category = "Elemental", Element = "Electric", Biomes = { "Marsh" }, Time = "Night", Visual = "Storm", Tint = rgb(40, 40, 80), Glow = rgb(140, 220, 255),
	Perk = { Name = "Voltage", Desc = "Immune to electricity & lightning, +15% speed", ElectricImmune = true, LightningImmune = true, Speed = 1.15 } })
C("Plague", "Plague Cloud", "Epic", { Category = "Elemental", Element = "Poison", Biomes = { "Marsh" }, Time = "Night", Visual = "Void", Tint = rgb(70, 110, 40), Glow = rgb(170, 255, 60),
	Perk = { Name = "Miasma", Desc = "Acid-proof, slows rivals near you, +3 HP/s", PoisonImmune = true, StormAura = true, Regen = 3 } })
C("Tsunami", "Tsunami Cloud", "Epic", { Category = "Elemental", Element = "Water", Biomes = { "Coast" }, Time = "Any", Visual = "Rain", Tint = rgb(40, 110, 200),
	Perk = { Name = "Wave Rider", Desc = "+30% speed, can't slip", Speed = 1.3, NoSlip = true } })
C("Tectonic", "Tectonic Cloud", "Epic", { Category = "Elemental", Element = "Earth", Biomes = { "Canyon" }, Time = "Any", Visual = "Storm", Tint = rgb(110, 80, 60), Glow = rgb(255, 140, 60),
	Perk = { Name = "Fault Line", Desc = "Quake (G/H/J), 25% less damage", Ability = "Quake", DamageResist = 0.25 } })
C("Wormhole", "Wormhole Cloud", "Epic", { Category = "SpaceTime", Biomes = { "Canyon", "Plateau" }, Time = "Night", Visual = "Void", Tint = rgb(50, 20, 90), Glow = rgb(190, 120, 255),
	Perk = { Name = "Fold Space", Desc = "Blink (G/H/J), 20% less gravity", Ability = "Blink", Gravity = 0.2 } })
C("Hyperdrive", "Hyperdrive Cloud", "Epic", { Category = "SpaceTime", Biomes = { "Plateau" }, Time = "Day", Visual = "Cosmic", Tint = rgb(120, 200, 255),
	Perk = { Name = "Overclock", Desc = "+35% speed, items last 20% longer", Speed = 1.35, ItemTime = 1.2 } })
C("GoldRush", "Gold Rush Cloud", "Epic", { Category = "Economic", Biomes = ALL, Time = "Day", Weight = 6, Visual = "Solar", Tint = rgb(255, 210, 70), Reward = 400,
	Bonus = { XP = 90, ItemChance = 0.25 }, Perk = { Name = "Gold Fever", Desc = "+35% coins", CoinMult = 1.35 } })
C("Poltergeist", "Poltergeist Cloud", "Epic", { Category = "Chaos", Biomes = ALL, Time = "Night", Weight = 6, Visual = "Void", Tint = rgb(150, 140, 200), Glow = rgb(220, 220, 255),
	Perk = { Name = "Haunted", Desc = "Random buff/debuff every 20 s, Dazzle (G/H/J)", Chaos = true, Ability = "Dazzle" } })
C("Sporestorm", "Sporestorm", "Epic", { Category = "Elemental", Element = "Poison", Biomes = { "Mushroom" }, Time = "Any", Visual = "Tornado", Tint = rgb(210, 160, 220), Glow = rgb(230, 255, 150),
	Perk = { Name = "Spore Cyclone", Desc = "+40% jump, acid-proof", Jump = 1.4, PoisonImmune = true } })

-- LEGENDARY (7)
C("Ragnarok", "Ragnarok Cloud", "Legendary", { Category = "Elemental", Element = "Fire", Biomes = { "Volcanic" }, Time = "Any", Visual = "Phoenix", Tint = rgb(180, 30, 20), Glow = rgb(255, 160, 40),
	Perk = { Name = "World Fire", Desc = "Lava-proof, +45% speed, 30% less damage", FireImmune = true, Speed = 1.45, DamageResist = 0.3 } })
C("Permafrost", "Permafrost", "Legendary", { Category = "Elemental", Element = "Ice", Biomes = { "Mountains" }, Time = "Night", Visual = "Aurora", Tint = rgb(200, 235, 255), Glow = rgb(150, 220, 255),
	Perk = { Name = "Eternal Ice", Desc = "Ice grip, +60% jump, 30% less damage", IceGrip = true, Jump = 1.6, DamageResist = 0.3 } })
C("Gravitas", "Gravitas Cloud", "Legendary", { Category = "SpaceTime", Biomes = { "Plateau", "Canyon" }, Time = "Any", Visual = "Void", Tint = rgb(30, 25, 60), Glow = rgb(140, 160, 255),
	Perk = { Name = "Zero G", Desc = "45% less gravity, Blink (G/H/J)", Gravity = 0.45, Ability = "Blink" } })
C("Treasury", "Treasury Cloud", "Legendary", { Category = "Economic", Biomes = ALL, Time = "Any", Weight = 6, Visual = "Solar", Tint = rgb(255, 225, 120), Reward = 1400,
	Bonus = { XP = 300, ItemChance = 0.6 }, Perk = { Name = "Royal Treasury", Desc = "x1.6 coins", CoinMult = 1.6 } })
C("Maelstrom", "Maelstrom", "Legendary", { Category = "Chaos", Biomes = { "Marsh", "Coast" }, Time = "Night", Visual = "Tornado", Tint = rgb(40, 60, 90), Glow = rgb(120, 200, 255),
	Perk = { Name = "Whirlpool", Desc = "Chaos buffs, Quake (G/H/J), +30% speed", Chaos = true, Ability = "Quake", Speed = 1.3 } })
C("Mycelium", "Mycelium Crown", "Legendary", { Category = "Elemental", Element = "Poison", Biomes = { "Mushroom" }, Time = "Night", Visual = "Aurora", Tint = rgb(170, 120, 255), Glow = rgb(120, 255, 200),
	Perk = { Name = "Hive Mind", Desc = "+6 HP/s, acid-proof, x1.3 coins", Regen = 6, PoisonImmune = true, CoinMult = 1.3 } })
C("Geode", "Geode Heart", "Legendary", { Category = "Elemental", Element = "Earth", Biomes = { "Canyon" }, Time = "Any", Visual = "Chrono", Tint = rgb(150, 80, 220), Glow = rgb(255, 150, 255),
	Perk = { Name = "Diamond Core", Desc = "45% less damage, x1.3 coins", DamageResist = 0.45, CoinMult = 1.3 } })

-- MYTHIC (4)
C("Primordial", "Primordial Storm", "Mythic", { Category = "Elemental", Element = "Electric", Biomes = { "Marsh", "Volcanic" }, Time = "Night", Visual = "Storm", Tint = rgb(20, 10, 30), Glow = rgb(255, 120, 255),
	Perk = { Name = "Elder Storm", Desc = "Immune to lava, lightning, electricity & acid; +40% speed", FireImmune = true, LightningImmune = true, ElectricImmune = true, PoisonImmune = true, Speed = 1.4 } })
C("Singularity", "Singularity", "Mythic", { Category = "SpaceTime", Biomes = ALL, Time = "Night", Visual = "Void", Tint = rgb(5, 5, 10), Glow = rgb(255, 255, 255),
	Perk = { Name = "Event Horizon", Desc = "60% less gravity, Blink, x1.5 coins", Gravity = 0.6, Ability = "Blink", CoinMult = 1.5 } })
C("Midas", "Midas Cloud", "Mythic", { Category = "Economic", Biomes = ALL, Time = "Day", Visual = "Solar", Tint = rgb(255, 200, 40), Glow = rgb(255, 240, 150), Reward = 8000,
	Bonus = { XP = 1000, ItemChance = 1 }, Perk = { Name = "Golden Touch", Desc = "x2.5 coins", CoinMult = 2.5 } })
C("Pandemonium", "Pandemonium", "Mythic", { Category = "Chaos", Biomes = ALL, Time = "Any", Visual = "Cosmic", Tint = rgb(255, 60, 180), Glow = rgb(120, 255, 255),
	Perk = { Name = "Total Chaos", Desc = "Chaos buffs (mostly good), Quake, +50% speed & jump", Chaos = true, Ability = "Quake", Speed = 1.5, Jump = 1.5 } })

------------------------------------------------------------------------
-- v2.35 FIFTY NEW CLOUDS (director: unique designs). New signature
-- features in CloudVisuals: ears, antlers, umbrella, lantern, gears, ...
------------------------------------------------------------------------
C("Bunnypuff", "Bunny Puff", "Common", { Biomes = { "Plateau" }, Time = "Day", Visual = "Cumulus", Tint = rgb(255, 240, 245),
	Perk = { Name = "Hoppity", Desc = "+14% jump", Jump = 1.14 } })
C("Kitten", "Kitten Cloud", "Common", { Biomes = { "Coast" }, Time = "Any", Visual = "Cumulus", Tint = rgb(250, 225, 200),
	Perk = { Name = "Nine Lives", Desc = "8% less damage", DamageResist = 0.08 } })
C("Acorn", "Acorn Puff", "Common", { Biomes = { "Plateau" }, Time = "Any", Visual = "Tornado", Tint = rgb(205, 160, 110),
	Perk = { Name = "Squirrel Feet", Desc = "+7% speed", Speed = 1.07 } })
C("Beanie", "Beanie Cloud", "Common", { Biomes = { "Mountains" }, Time = "Day", Visual = "Snow", Tint = rgb(235, 240, 255),
	Perk = { Name = "Whirly", Desc = "8% less gravity", Gravity = 0.08 } })
C("Drizzlebrella", "Brolly Cloud", "Common", { Biomes = { "Marsh" }, Time = "Day", Visual = "Rain", Tint = rgb(170, 190, 220),
	Perk = { Name = "Dry Head", Desc = "Acid rain can't hurt you", PoisonImmune = true } })
C("Lanternfly", "Lantern Fly", "Common", { Biomes = { "Mushroom" }, Time = "Night", Visual = "Aurora", Tint = rgb(255, 215, 150), Glow = rgb(255, 200, 100),
	Perk = { Name = "Night Light", Desc = "+6% coins", CoinMult = 1.06 } })
C("Ribbonette", "Ribbon Puff", "Common", { Biomes = { "Coast" }, Time = "Day", Visual = "Cumulus", Tint = rgb(255, 210, 230),
	Perk = { Name = "Gift Wrap", Desc = "+1 HP/s", Regen = 1 } })
C("Professor", "Professor Puff", "Common", { Biomes = { "Canyon" }, Time = "Any", Visual = "Chrono", Tint = rgb(240, 230, 200),
	Perk = { Name = "Studious", Desc = "Items last 15% longer", ItemTime = 1.15 } })
C("Snugscarf", "Snug Cloud", "Common", { Biomes = { "Mountains" }, Time = "Night", Visual = "Snow", Tint = rgb(245, 248, 255),
	Perk = { Name = "Cozy", Desc = "No slipping on ice", IceGrip = true } })
C("Melody", "Melody Cloud", "Common", { Biomes = { "Plateau" }, Time = "Any", Visual = "Aurora", Tint = rgb(215, 235, 255),
	Perk = { Name = "Rhythm", Desc = "+6% speed", Speed = 1.06 } })
C("Pricklepuff", "Prickle Puff", "Common", { Biomes = { "Canyon" }, Time = "Day", Visual = "Cumulus", Tint = rgb(240, 225, 195),
	Perk = { Name = "Spiny", Desc = "10% less knockback", BlastResist = true } })
C("Bubbleglass", "Snorkel Cloud", "Common", { Biomes = { "Coast" }, Time = "Any", Visual = "Rain", Tint = rgb(170, 225, 240),
	Perk = { Name = "Diver", Desc = "+10% jump", Jump = 1.1 } })
C("Jinglebell", "Jingle Cloud", "Common", { Biomes = { "Mountains" }, Time = "Any", Visual = "Snow", Tint = rgb(255, 250, 240),
	Perk = { Name = "Jingle", Desc = "+5% coins", CoinMult = 1.05 } })
C("Kiteling", "Kite Cloud", "Common", { Biomes = { "Plateau" }, Time = "Day", Visual = "Cumulus", Tint = rgb(230, 245, 255),
	Perk = { Name = "Updraft", Desc = "Wind can't push you", WindImmune = true } })
C("Stagmist", "Stag Mist", "Rare", { Biomes = { "Mountains" }, Time = "Any", Visual = "Cumulus", Tint = rgb(220, 215, 200),
	Perk = { Name = "Stag Leap", Desc = "+18% jump", Jump = 1.18 } })
C("Sweetcane", "Candy Cane Cloud", "Rare", { Biomes = { "Mountains" }, Time = "Night", Visual = "Cumulus", Tint = rgb(255, 235, 240),
	Perk = { Name = "Sugar Rush", Desc = "+12% speed", Speed = 1.12 } })
C("Jackolantern", "Jack-o-Cloud", "Rare", { Biomes = { "Mushroom" }, Time = "Night", Visual = "Storm", Tint = rgb(90, 70, 90), Glow = rgb(255, 150, 40),
	Perk = { Name = "Spooky", Desc = "+10% coins at night", CoinMult = 1.1 } })
C("Squidpuff", "Squid Puff", "Rare", { Biomes = { "Coast" }, Time = "Any", Visual = "Rain", Tint = rgb(200, 170, 230),
	Perk = { Name = "Ink Jet", Desc = "+10% speed", Speed = 1.1 } })
C("Lovecloud", "Heartbeat Cloud", "Rare", { Biomes = { "Plateau" }, Time = "Day", Visual = "Aurora", Tint = rgb(255, 200, 220), Glow = rgb(255, 120, 160),
	Perk = { Name = "Warm Heart", Desc = "+2 HP/s", Regen = 2 } })
C("Wingflutter", "Flutter Cloud", "Rare", { Biomes = { "Mushroom" }, Time = "Day", Visual = "Aurora", Tint = rgb(220, 240, 255), Glow = rgb(160, 220, 255),
	Perk = { Name = "Flutter", Desc = "12% less gravity", Gravity = 0.12 } })
C("Cogwork", "Cogwork Cloud", "Rare", { Biomes = { "Canyon" }, Time = "Any", Visual = "Chrono", Tint = rgb(210, 195, 160),
	Perk = { Name = "Tinker", Desc = "Items last 20% longer", ItemTime = 1.2 } })
C("Brainstorm", "Brainstorm", "Rare", { Biomes = { "Marsh" }, Time = "Any", Visual = "Storm", Tint = rgb(110, 115, 150), Glow = rgb(255, 245, 160),
	Perk = { Name = "Bright Idea", Desc = "Shock immune", ElectricImmune = true } })
C("Thornback", "Thornback Cloud", "Rare", { Biomes = { "Volcanic" }, Time = "Any", Visual = "Storm", Tint = rgb(95, 85, 105), Glow = rgb(255, 120, 60),
	Perk = { Name = "Thorny", Desc = "12% less damage", DamageResist = 0.12 } })
C("Maplefall", "Maplefall", "Rare", { Biomes = { "Plateau" }, Time = "Any", Visual = "Tornado", Tint = rgb(230, 150, 80),
	Perk = { Name = "Autumn Wind", Desc = "+10% speed, wind-proof", Speed = 1.1, WindImmune = true } })
C("Sunbrella", "Sunbrella", "Rare", { Biomes = { "Canyon" }, Time = "Day", Visual = "Solar", Tint = rgb(255, 230, 160),
	Perk = { Name = "Shade", Desc = "Burn immune", FireImmune = true } })
C("Choirpuff", "Choir Cloud", "Rare", { Biomes = { "Coast" }, Time = "Night", Visual = "Aurora", Tint = rgb(200, 220, 255), Glow = rgb(200, 220, 255),
	Perk = { Name = "Hymn", Desc = "+2 HP/s", Regen = 2 } })
C("Lampwick", "Lampwick Cloud", "Rare", { Biomes = { "Marsh" }, Time = "Night", Visual = "Phoenix", Tint = rgb(255, 190, 120), Glow = rgb(255, 200, 90),
	Perk = { Name = "Wick", Desc = "+8% coins", CoinMult = 1.08 } })
C("Kittycomet", "Comet Kitty", "Rare", { Biomes = { "Canyon" }, Time = "Night", Visual = "Cosmic", Tint = rgb(120, 90, 200), Glow = rgb(255, 240, 180),
	Perk = { Name = "Star Paws", Desc = "+12% jump", Jump = 1.12 } })
C("Reindeer", "Reindeer Storm", "Epic", { Biomes = { "Mountains" }, Time = "Night", Visual = "Snow", Tint = rgb(235, 240, 250), Glow = rgb(255, 90, 90),
	Perk = { Name = "Sleigh Ride", Desc = "+18% speed on any ground", Speed = 1.18, IceGrip = true } })
C("Krakenling", "Krakenling", "Epic", { Biomes = { "Coast" }, Time = "Night", Visual = "Storm", Tint = rgb(70, 60, 110), Glow = rgb(160, 90, 255),
	Perk = { Name = "Deep Grip", Desc = "20% less damage", DamageResist = 0.2 } })
C("Clockwork", "Clockwork Titan", "Epic", { Biomes = { "Canyon" }, Time = "Any", Visual = "Chrono", Tint = rgb(200, 180, 130), Glow = rgb(255, 220, 140),
	Perk = { Name = "Overclock", Desc = "Items last 35% longer", ItemTime = 1.35 } })
C("Sugarplum", "Sugarplum", "Epic", { Biomes = { "Mushroom" }, Time = "Any", Visual = "Aurora", Tint = rgb(255, 190, 230), Glow = rgb(255, 150, 210),
	Perk = { Name = "Sweet Tooth", Desc = "+15% coins", CoinMult = 1.15 } })
C("Gourdlord", "Gourd Lord", "Epic", { Biomes = { "Mushroom" }, Time = "Night", Visual = "Void", Tint = rgb(60, 40, 70), Glow = rgb(255, 140, 40),
	Perk = { Name = "Harvest", Desc = "+3 HP/s", Regen = 3 } })
C("Monarchwing", "Monarch Wing", "Epic", { Biomes = { "Plateau" }, Time = "Day", Visual = "Phoenix", Tint = rgb(255, 170, 90), Glow = rgb(255, 200, 120),
	Perk = { Name = "Migration", Desc = "18% less gravity", Gravity = 0.18 } })
C("Thunderbunny", "Thunder Bunny", "Epic", { Biomes = { "Marsh" }, Time = "Any", Visual = "Storm", Tint = rgb(90, 95, 130), Glow = rgb(255, 255, 150),
	Perk = { Name = "Zap Hop", Desc = "+25% jump, shock immune", Jump = 1.25, ElectricImmune = true } })
C("Inventor", "Inventor Cloud", "Epic", { Biomes = { "Canyon" }, Time = "Day", Visual = "Solar", Tint = rgb(255, 225, 150), Glow = rgb(255, 245, 170),
	Perk = { Name = "Eureka", Desc = "Blink ability", Ability = "Blink" } })
C("Orchestra", "Orchestra", "Epic", { Biomes = { "Coast" }, Time = "Any", Visual = "Aurora", Tint = rgb(180, 210, 255), Glow = rgb(220, 240, 255),
	Perk = { Name = "Crescendo", Desc = "Dazzle ability", Ability = "Dazzle" } })
C("Cactusking", "Cactus King", "Epic", { Biomes = { "Canyon" }, Time = "Day", Visual = "Solar", Tint = rgb(240, 210, 140),
	Perk = { Name = "Desert Lord", Desc = "Burn immune, +12% speed", FireImmune = true, Speed = 1.12 } })
C("Stormkite", "Storm Kite", "Epic", { Biomes = { "Plateau" }, Time = "Any", Visual = "Storm", Tint = rgb(100, 110, 140), Glow = rgb(200, 230, 255),
	Perk = { Name = "Gale Rider", Desc = "Lightning can't hit you", LightningImmune = true } })
C("Elderstag", "Elder Stag", "Legendary", { Biomes = { "Mountains" }, Time = "Night", Visual = "Aurora", Tint = rgb(210, 255, 230), Glow = rgb(140, 255, 200),
	Perk = { Name = "Forest King", Desc = "+25% speed, +3 HP/s", Speed = 1.25, Regen = 3 } })
C("Abyssquid", "Abyss Squid", "Legendary", { Biomes = { "Coast" }, Time = "Night", Visual = "Void", Tint = rgb(30, 20, 60), Glow = rgb(120, 80, 255),
	Perk = { Name = "Abyssal", Desc = "30% less damage, blast resist", DamageResist = 0.3, BlastResist = true } })
C("Grandclock", "Grand Clockwork", "Legendary", { Biomes = { "Canyon" }, Time = "Any", Visual = "Chrono", Tint = rgb(230, 200, 130), Glow = rgb(255, 230, 150),
	Perk = { Name = "Time Lord", Desc = "Items last 60% longer", ItemTime = 1.6 } })
C("Heartqueen", "Queen of Hearts", "Legendary", { Biomes = { "Plateau" }, Time = "Day", Visual = "Phoenix", Tint = rgb(255, 120, 150), Glow = rgb(255, 180, 200),
	Perk = { Name = "Royal Love", Desc = "+5 HP/s", Regen = 5 } })
C("Pumpkinking", "Pumpkin King", "Legendary", { Biomes = { "Mushroom" }, Time = "Night", Visual = "Mythic", Tint = rgb(50, 30, 60), Glow = rgb(255, 140, 40),
	Perk = { Name = "Halloween", Desc = "+30% coins", CoinMult = 1.3 } })
C("Skybutterfly", "Sky Butterfly", "Legendary", { Biomes = { "Mushroom" }, Time = "Day", Visual = "Aurora", Tint = rgb(200, 240, 255), Glow = rgb(255, 190, 240),
	Perk = { Name = "Featherlight", Desc = "30% less gravity, +20% jump", Gravity = 0.3, Jump = 1.2 } })
C("Maestro", "Maestro", "Legendary", { Biomes = { "Coast" }, Time = "Any", Visual = "Solar", Tint = rgb(255, 235, 190), Glow = rgb(255, 250, 200),
	Perk = { Name = "Encore", Desc = "Blink ability, +20% speed", Ability = "Blink", Speed = 1.2 } })
C("Krakenking", "Kraken King", "Mythic", { Biomes = { "Coast" }, Time = "Night", Visual = "Mythic", Tint = rgb(25, 15, 50), Glow = rgb(150, 90, 255),
	Perk = { Name = "Sea Sovereign", Desc = "40% less damage, Quake ability", DamageResist = 0.4, Ability = "Quake" } })
C("Cosmicstag", "Cosmic Stag", "Mythic", { Biomes = { "Mountains" }, Time = "Night", Visual = "Cosmic", Tint = rgb(80, 50, 160), Glow = rgb(200, 170, 255),
	Perk = { Name = "Starborne", Desc = "+40% speed & jump", Speed = 1.4, Jump = 1.4 } })
C("Machina", "Deus Machina", "Mythic", { Biomes = { "Canyon" }, Time = "Any", Visual = "Chrono", Tint = rgb(240, 215, 140), Glow = rgb(255, 240, 170),
	Perk = { Name = "Perpetual", Desc = "Items last 2x, x1.5 coins", ItemTime = 2, CoinMult = 1.5 } })
C("Lovebird", "Eternal Lovebird", "Mythic", { Biomes = { "Plateau" }, Time = "Day", Visual = "Phoenix", Tint = rgb(255, 140, 170), Glow = rgb(255, 200, 220),
	Perk = { Name = "True Love", Desc = "+8 HP/s, 25% less damage", Regen = 8, DamageResist = 0.25 } })

return list
