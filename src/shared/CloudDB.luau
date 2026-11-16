-- CLOUD DATABASE — every cloud in the game (56). Add a line to add a cloud.
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

return list
