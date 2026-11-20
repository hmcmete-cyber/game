-- v2.12 PETS (director: 50+ genuinely distinct pets from boss eggs; every pet
-- both FIGHTS for you and gives YOU a buff; sensible equip/stack limits).
--
-- 7 boss eggs x 8 pets = 56 pets. Per egg: 2 Common, 2 Uncommon, 2 Rare,
-- 1 Epic, 1 Legendary. Every pet has its own:
--   Look   archetype (body plan) + features + palette -> PetModels builds it
--   Buff   { Kind, When }  (unique pair across the whole roster)
--   Attack { Kind, Effect } its combat assist
-- Strength scales with rarity (RARITY[r].Power). Team limits: EquipLimit
-- pets at once, and every buff kind is capped (CAPS) however many stack.

local PetDefs = {}

PetDefs.EquipLimit = 3
PetDefs.HatchMinutes = 100

PetDefs.Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
PetDefs.RARITY = {
	Common = { Weight = 26, Power = 1, Color = Color3.fromRGB(200, 205, 215), Damage = 8, Cooldown = 3.2 },
	Uncommon = { Weight = 15, Power = 1.5, Color = Color3.fromRGB(110, 220, 110), Damage = 11, Cooldown = 3 },
	Rare = { Weight = 6, Power = 2, Color = Color3.fromRGB(90, 160, 255), Damage = 15, Cooldown = 2.8 },
	Epic = { Weight = 4.5, Power = 3, Color = Color3.fromRGB(190, 100, 255), Damage = 21, Cooldown = 2.5 },
	Legendary = { Weight = 1.5, Power = 4, Color = Color3.fromRGB(255, 200, 60), Damage = 30, Cooldown = 2.2 },
}
-- Legendary hatches are announced to the whole server
PetDefs.AnnounceRarity = "Legendary"

-- buff kinds: base value per Power point and the team cap
--   Speed/Jump  walk / jump multiplier bonus (no pet buff works while carrying a cloud)
--   Resist      less damage taken            KnockResist  less knockback
--   Regen       health per second            Damage       more attack damage
--   XP / Coins  more XP / coins              Crit         chance of double damage
--   Lifesteal   heal % of damage dealt       Haste        shorter attack cooldowns
--   Stealth     monsters notice you later    Hatch        faster incubator
--   Shield      a short shield every (30 / power) seconds
--   Cleanse     shortens slows / roots / burns
--   immunities  FireImmune, ElectricImmune, SlipImmune, BlindImmune, SlowImmune
PetDefs.BUFF = {
	Speed = { Base = 0.04, Cap = 0.3, Label = "+%d%% walk speed" },
	Jump = { Base = 0.06, Cap = 0.4, Label = "+%d%% jump" },
	CarrySpeed = { Base = 0.06, Cap = 0.35, Label = "+%d%% speed while carrying" },
	Resist = { Base = 0.03, Cap = 0.35, Label = "-%d%% damage taken" },
	KnockResist = { Base = 0.1, Cap = 0.6, Label = "-%d%% knockback" },
	Regen = { Base = 0.4, Cap = 3, Label = "+%.1f HP/s", Flat = true },
	Damage = { Base = 0.05, Cap = 0.5, Label = "+%d%% attack damage" },
	XP = { Base = 0.06, Cap = 0.6, Label = "+%d%% XP" },
	Coins = { Base = 0.06, Cap = 0.6, Label = "+%d%% coins" },
	Crit = { Base = 0.03, Cap = 0.25, Label = "%d%% crit chance" },
	Lifesteal = { Base = 0.03, Cap = 0.15, Label = "%d%% lifesteal" },
	Haste = { Base = 0.04, Cap = 0.3, Label = "-%d%% attack cooldown" },
	Stealth = { Base = 0.08, Cap = 0.5, Label = "monsters notice you %d%% later" },
	Hatch = { Base = 0.04, Cap = 0.35, Label = "eggs hatch %d%% faster" },
	Shield = { Base = 1, Cap = 4, Label = "shield every %ds", Flat = true },
	Cleanse = { Base = 0.12, Cap = 0.6, Label = "debuffs %d%% shorter" },
	FireImmune = { Flag = true, Label = "immune to burning" },
	ElectricImmune = { Flag = true, Label = "immune to shocks" },
	SlipImmune = { Flag = true, Label = "never slips on ice" },
	BlindImmune = { Flag = true, Label = "immune to blinding" },
	SlowImmune = { Flag = true, Label = "immune to slows" },
}
PetDefs.WHEN = {
	Always = { Mult = 1, Label = "" },
	NearBase = { Mult = 1.6, Label = " near your base" }, -- v2.13: no pet buffs while carrying a cloud
	LowHP = { Mult = 1.8, Label = " below half health" },
	AfterKill = { Mult = 1.8, Label = " for 6s after a kill" },
	InHome = { Mult = 1.6, Label = " in its home biome" },
}
-- attack kinds: Bite (dash + hit), Bolt (projectile), Lob (arcing splash),
-- Pulse (ring around the pet), Chain (jumps to 3 monsters), Mend (heals you + small hit)
-- effects: Slow, Burn, Shock (stun), Knock, Expose (target takes +25 % damage)

PetDefs.Eggs = {
	Plateau = { Name = "Meadow Egg", Boss = "MesaColossus", Color = Color3.fromRGB(150, 210, 110), Color2 = Color3.fromRGB(220, 190, 140) },
	Mountains = { Name = "Frost Egg", Boss = "FrostpeakWarden", Color = Color3.fromRGB(210, 235, 255), Color2 = Color3.fromRGB(120, 170, 230) },
	Mushroom = { Name = "Spore Egg", Boss = "MyceliumMonarch", Color = Color3.fromRGB(230, 110, 180), Color2 = Color3.fromRGB(250, 245, 230) },
	Marsh = { Name = "Storm Egg", Boss = "BogstormCroaker", Color = Color3.fromRGB(90, 140, 110), Color2 = Color3.fromRGB(170, 230, 255) },
	Canyon = { Name = "Crystal Egg", Boss = "PrismSovereign", Color = Color3.fromRGB(110, 150, 255), Color2 = Color3.fromRGB(190, 140, 255) },
	Volcanic = { Name = "Magma Egg", Boss = "CalderaTitan", Color = Color3.fromRGB(70, 55, 55), Color2 = Color3.fromRGB(255, 120, 40) },
	Coast = { Name = "Tide Egg", Boss = "Tidebreaker", Color = Color3.fromRGB(240, 225, 195), Color2 = Color3.fromRGB(80, 180, 230) },
}

local RGB = Color3.fromRGB
-- Id = { Name, Egg, Rarity, Arch, Features, Palette {main, second, accent}, Buff {Kind, When}, Attack {Kind, Effect}, Hook }
local LIST = {
	-- PLATEAU (Meadow Egg)
	{ "Pebblepup", "Pebblepup", "Plateau", "Common", "Quad", { "EarsRound", "TailStub", "Pebbles" }, { RGB(170, 160, 150), RGB(120, 112, 105), RGB(240, 230, 200) }, { "Resist", "Always" }, { "Bite", "Knock" }, "a puppy made of round pebbles" },
	{ "Clovercub", "Clovercub", "Plateau", "Common", "Quad", { "EarsRound", "Clover", "TailStub" }, { RGB(120, 190, 90), RGB(80, 140, 60), RGB(255, 255, 255) }, { "Regen", "Always" }, { "Bolt", "Slow" }, "bear cub with a four-leaf clover sprouting on its head" },
	{ "Dandefluff", "Dandefluff", "Plateau", "Uncommon", "Puff", { "Seeds", "Stem" }, { RGB(250, 250, 240), RGB(255, 225, 90), RGB(120, 180, 80) }, { "Jump", "Always" }, { "Lob", "Slow" }, "a dandelion puffball that drifts after you" },
	{ "Hayhopper", "Hayhopper", "Plateau", "Uncommon", "Bug", { "Antenna", "LongLegs", "Straw" }, { RGB(220, 190, 110), RGB(170, 140, 70), RGB(120, 180, 80) }, { "Speed", "Always" }, { "Bite", "Knock" }, "grasshopper with a straw-bale body" },
	{ "Mesamole", "Mesa Mole", "Plateau", "Rare", "Quad", { "Snout", "Claws", "MesaHat" }, { RGB(150, 110, 90), RGB(200, 160, 112), RGB(110, 190, 90) }, { "Coins", "Always" }, { "Pulse", "Knock" }, "a mole wearing a tiny grassy mesa as a hat" },
	{ "Sunbloom", "Sunbloom", "Plateau", "Rare", "Flower", { "Petals", "Leaves" }, { RGB(255, 210, 60), RGB(140, 90, 40), RGB(90, 170, 70) }, { "XP", "Always" }, { "Bolt", "Burn" }, "a walking sunflower that fires sunbeams" },
	{ "Runegolem", "Rune Golem", "Plateau", "Epic", "Biped", { "Rune", "Ruins" }, { RGB(225, 215, 190), RGB(150, 130, 100), RGB(255, 210, 110) }, { "Damage", "Always" }, { "Pulse", "Expose" }, "a pocket ruin golem with a glowing rune chest" },
	{ "Colossusjr", "Colossus Jr", "Plateau", "Legendary", "Biped", { "MesaBack", "BigFists", "Ruins" }, { RGB(205, 160, 112), RGB(176, 128, 92), RGB(110, 190, 90) }, { "Shield", "Always" }, { "Lob", "Knock" }, "a mini Mesa Colossus with a grassy tableland back" },
	-- MOUNTAINS (Frost Egg)
	{ "Snowbun", "Snowbun", "Mountains", "Common", "Quad", { "EarsLong", "TailPuff" }, { RGB(250, 250, 255), RGB(220, 225, 240), RGB(255, 170, 190) }, { "SlipImmune", "Always" }, { "Bite", "Slow" }, "a snow bunny with long floppy ears" },
	{ "Pineconepip", "Pinecone Pip", "Mountains", "Common", "Blob", { "Scales", "Sprig" }, { RGB(150, 100, 60), RGB(110, 70, 40), RGB(60, 130, 70) }, { "Regen", "LowHP" }, { "Bolt", "Slow" }, "a round pinecone that flicks needles" },
	{ "Icicleimp", "Icicle Imp", "Mountains", "Uncommon", "Biped", { "HornsIce", "Crystals" }, { RGB(170, 220, 255), RGB(120, 170, 230), RGB(240, 250, 255) }, { "Resist", "LowHP" }, { "Bolt", "Slow" }, "a cheeky imp with icicle horns" },
	{ "Yakling", "Yakling", "Mountains", "Uncommon", "Quad", { "HornsCurved", "Mane", "Shaggy" }, { RGB(120, 95, 75), RGB(230, 225, 215), RGB(200, 200, 210) }, { "KnockResist", "NearBase" }, { "Bite", "Knock" }, "a shaggy baby yak with a snowy mane" },
	{ "Auroraowl", "Aurora Owl", "Mountains", "Rare", "Bird", { "Tufts", "Halo", "BigEyes" }, { RGB(235, 240, 255), RGB(140, 160, 200), RGB(120, 255, 200) }, { "Stealth", "Always" }, { "Chain", "Slow" }, "a snowy owl trailing aurora light" },
	{ "Glacierturtle", "Glacier Turtle", "Mountains", "Rare", "Turtle", { "IceShell", "Crystals" }, { RGB(120, 170, 140), RGB(200, 235, 255), RGB(150, 210, 255) }, { "KnockResist", "Always" }, { "Pulse", "Slow" }, "a turtle carrying a little glacier" },
	{ "Peakram", "Peak Ram", "Mountains", "Epic", "Quad", { "HornsRam", "Shaggy", "Hooves" }, { RGB(235, 230, 220), RGB(140, 130, 120), RGB(120, 170, 230) }, { "Jump", "NearBase" }, { "Bite", "Knock" }, "a mountain ram with huge spiral horns" },
	{ "Wardencub", "Warden Cub", "Mountains", "Legendary", "Biped", { "Helm", "Shield", "Shaggy" }, { RGB(245, 248, 255), RGB(120, 170, 230), RGB(150, 230, 255) }, { "Cleanse", "Always" }, { "Pulse", "Slow" }, "a tiny yeti knight with an ice shield" },
	-- MUSHROOM (Spore Egg)
	{ "Sporelet", "Sporelet", "Mushroom", "Common", "Shroom", { "CapSpots", "Feet" }, { RGB(230, 90, 100), RGB(245, 235, 215), RGB(255, 255, 255) }, { "Regen", "AfterKill" }, { "Lob", "Slow" }, "a toddling red-capped mushroom" },
	{ "Mossnail", "Mossnail", "Mushroom", "Common", "Snail", { "MossShell", "Antenna" }, { RGB(150, 200, 140), RGB(90, 150, 80), RGB(230, 200, 160) }, { "Hatch", "Always" }, { "Bite", "Slow" }, "a snail with a mossy, flowering shell" },
	{ "Glowcap", "Glowcap", "Mushroom", "Uncommon", "Shroom", { "GlowCap", "Feet" }, { RGB(120, 230, 200), RGB(235, 230, 215), RGB(190, 255, 230) }, { "XP", "AfterKill" }, { "Bolt", "Expose" }, "a mushroom with a glowing teal cap" },
	{ "Trufflepig", "Truffle Pig", "Mushroom", "Uncommon", "Quad", { "Snout", "EarsFloppy", "BackShroom" }, { RGB(240, 175, 175), RGB(200, 130, 130), RGB(150, 100, 70) }, { "Coins", "AfterKill" }, { "Bite", "Knock" }, "a piglet with a truffle growing on its back" },
	{ "Fairyringling", "Fairy Ringling", "Mushroom", "Rare", "Orb", { "ShroomRing", "Wings" }, { RGB(255, 200, 240), RGB(230, 110, 180), RGB(255, 255, 200) }, { "Lifesteal", "Always" }, { "Chain", "Slow" }, "a fairy orb circled by tiny mushrooms" },
	{ "Mothsprite", "Moth Sprite", "Mushroom", "Rare", "Bug", { "WingsBig", "Fluff", "Antenna" }, { RGB(200, 170, 230), RGB(150, 110, 210), RGB(170, 255, 220) }, { "BlindImmune", "Always" }, { "Pulse", "Slow" }, "a fluffy moth with glowing wing spots" },
	{ "Mycoknight", "Myco Knight", "Mushroom", "Epic", "Biped", { "CapHelm", "Sword" }, { RGB(170, 70, 190), RGB(240, 228, 205), RGB(190, 255, 210) }, { "Damage", "LowHP" }, { "Bite", "Expose" }, "a mushroom knight with a cap helmet and twig sword" },
	{ "Monarchspawn", "Monarch Spawn", "Mushroom", "Legendary", "Shroom", { "Crown", "GlowCap", "Beard" }, { RGB(170, 70, 190), RGB(240, 228, 205), RGB(255, 220, 90) }, { "Haste", "Always" }, { "Lob", "Expose" }, "a baby Mycelium Monarch wearing a crown cap" },
	-- MARSH (Storm Egg)
	{ "Tadbolt", "Tadbolt", "Marsh", "Common", "Fish", { "TailFin", "Bolt" }, { RGB(70, 90, 80), RGB(120, 150, 130), RGB(220, 245, 255) }, { "ElectricImmune", "Always" }, { "Chain", "Shock" }, "a tadpole with a lightning-bolt tail" },
	{ "Reedrat", "Reedrat", "Marsh", "Common", "Quad", { "EarsRound", "TailLong", "Reed" }, { RGB(140, 120, 90), RGB(100, 85, 65), RGB(110, 160, 90) }, { "Stealth", "NearBase" }, { "Bite", "Slow" }, "a marsh rat chewing a reed" },
	{ "Bubblefrog", "Bubblefrog", "Marsh", "Uncommon", "Frog", { "BigEyes", "Bubble" }, { RGB(100, 180, 110), RGB(220, 230, 170), RGB(170, 230, 255) }, { "Jump", "AfterKill" }, { "Lob", "Slow" }, "a frog that blows soap-bubble shots" },
	{ "Lilyturtle", "Lily Turtle", "Marsh", "Uncommon", "Turtle", { "LilyPad", "Flower" }, { RGB(110, 160, 110), RGB(80, 130, 90), RGB(255, 200, 230) }, { "Regen", "InHome" }, { "Pulse", "Knock" }, "a turtle wearing a lily pad with a flower" },
	{ "Zapfly", "Zap Dragonfly", "Marsh", "Rare", "Bug", { "Wings4", "LongTail" }, { RGB(80, 200, 220), RGB(40, 90, 120), RGB(220, 245, 255) }, { "Speed", "AfterKill" }, { "Chain", "Shock" }, "a dragonfly with four crackling wings" },
	{ "Mudpuddle", "Mudpuddle", "Marsh", "Rare", "Blob", { "Drips", "Puddle" }, { RGB(120, 90, 60), RGB(90, 65, 45), RGB(150, 200, 120) }, { "SlowImmune", "Always" }, { "Pulse", "Slow" }, "a happy living mud puddle" },
	{ "Thundernewt", "Thunder Newt", "Marsh", "Epic", "Lizard", { "Crest", "Bolt" }, { RGB(60, 70, 110), RGB(255, 210, 60), RGB(200, 240, 255) }, { "Crit", "Always" }, { "Chain", "Shock" }, "a storm newt with a glowing crest" },
	{ "Croakerking", "Croaker King", "Marsh", "Legendary", "Frog", { "Crown", "Sac", "BigEyes" }, { RGB(80, 120, 70), RGB(200, 210, 150), RGB(150, 220, 255) }, { "Damage", "AfterKill" }, { "Pulse", "Shock" }, "a crowned toad with a storm-glowing throat" },
	-- CANYON (Crystal Egg)
	{ "Shardling", "Shardling", "Canyon", "Common", "Crystal", { "Shards", "Feet" }, { RGB(120, 170, 255), RGB(80, 120, 220), RGB(200, 230, 255) }, { "Crit", "LowHP" }, { "Bolt", "Slow" }, "a walking crystal cluster" },
	{ "Geodecrab", "Geode Crab", "Canyon", "Common", "Crab", { "Pincers", "Geode" }, { RGB(150, 120, 110), RGB(190, 140, 255), RGB(220, 200, 255) }, { "Resist", "NearBase" }, { "Bite", "Knock" }, "a crab whose shell is a split geode" },
	{ "Prismbat", "Prism Bat", "Canyon", "Uncommon", "Bird", { "BatWings", "EarsPointy" }, { RGB(120, 90, 170), RGB(80, 60, 120), RGB(150, 220, 255) }, { "Speed", "InHome" }, { "Bolt", "Expose" }, "a bat with prism-glass wings" },
	{ "Quartztortoise", "Quartz Tortoise", "Canyon", "Uncommon", "Turtle", { "QuartzShell" }, { RGB(170, 140, 200), RGB(240, 230, 255), RGB(200, 160, 255) }, { "Shield", "NearBase" }, { "Pulse", "Knock" }, "a tortoise with a quartz-point shell" },
	{ "Echofox", "Echo Fox", "Canyon", "Rare", "Quad", { "EarsBig", "TailFluffy", "CrystalTail" }, { RGB(150, 130, 220), RGB(240, 235, 255), RGB(120, 200, 255) }, { "Haste", "AfterKill" }, { "Bite", "Expose" }, "a fox with huge ears and a crystal tail tip" },
	{ "Lumenjelly", "Lumen Jelly", "Canyon", "Rare", "Jelly", { "Tentacles", "Glow" }, { RGB(170, 200, 255), RGB(230, 190, 255), RGB(150, 230, 255) }, { "Regen", "NearBase" }, { "Chain", "Slow" }, "a floating glow-jelly" },
	{ "Sapphiredrake", "Sapphire Drake", "Canyon", "Epic", "Drake", { "Wings", "HornsBack" }, { RGB(70, 110, 230), RGB(150, 190, 255), RGB(200, 240, 255) }, { "XP", "InHome" }, { "Bolt", "Expose" }, "a baby crystal dragon" },
	{ "Sovereignshard", "Sovereign Shard", "Canyon", "Legendary", "Orb", { "CrystalRing", "Crown" }, { RGB(80, 160, 255), RGB(150, 130, 255), RGB(170, 230, 255) }, { "Crit", "NearBase" }, { "Chain", "Expose" }, "a floating heart of the Prism Sovereign with orbiting shards" },
	-- VOLCANIC (Magma Egg)
	{ "Emberkit", "Emberkit", "Volcanic", "Common", "Quad", { "EarsPointy", "FlameTail" }, { RGB(70, 55, 55), RGB(255, 120, 40), RGB(255, 200, 90) }, { "FireImmune", "Always" }, { "Bolt", "Burn" }, "a soot kitten with a flame tail" },
	{ "Cinderbeetle", "Cinder Beetle", "Volcanic", "Common", "Bug", { "GlowShell", "Horn" }, { RGB(50, 40, 45), RGB(255, 110, 40), RGB(255, 200, 90) }, { "Damage", "NearBase" }, { "Bite", "Burn" }, "a beetle with a glowing ember shell" },
	{ "Ashbat", "Ashbat", "Volcanic", "Uncommon", "Bird", { "BatWings", "EarsPointy", "Smoke" }, { RGB(90, 85, 85), RGB(60, 55, 55), RGB(255, 140, 60) }, { "Stealth", "AfterKill" }, { "Bolt", "Burn" }, "a smoky bat with ember eyes" },
	{ "Magmaslime", "Magma Slime", "Volcanic", "Uncommon", "Blob", { "Glow", "Drips" }, { RGB(255, 110, 40), RGB(200, 70, 30), RGB(255, 210, 100) }, { "Lifesteal", "AfterKill" }, { "Lob", "Burn" }, "a bubbling magma slime" },
	{ "Obsidianhound", "Obsidian Hound", "Volcanic", "Rare", "Quad", { "Spikes", "EarsPointy", "Glow" }, { RGB(30, 25, 35), RGB(60, 50, 60), RGB(255, 120, 40) }, { "Speed", "LowHP" }, { "Bite", "Burn" }, "a glassy black hound with lava seams" },
	{ "Lavakoi", "Lava Koi", "Volcanic", "Rare", "Fish", { "TailFin", "Whiskers", "Glow" }, { RGB(255, 140, 50), RGB(255, 240, 220), RGB(255, 80, 40) }, { "XP", "NearBase" }, { "Bolt", "Burn" }, "a koi that swims through the air on heat" },
	{ "Pyrosalamander", "Pyro Salamander", "Volcanic", "Epic", "Lizard", { "Flame", "Spots" }, { RGB(255, 90, 40), RGB(255, 200, 60), RGB(255, 240, 160) }, { "Haste", "NearBase" }, { "Pulse", "Burn" }, "a salamander wrapped in flames" },
	{ "Titanhatchling", "Titan Hatchling", "Volcanic", "Legendary", "Turtle", { "VolcanoShell", "HornsBack" }, { RGB(70, 58, 56), RGB(48, 40, 42), RGB(255, 110, 40) }, { "Shield", "AfterKill" }, { "Lob", "Burn" }, "a baby lava tortoise with a tiny erupting volcano" },
	-- COAST (Tide Egg)
	{ "Shellby", "Shellby", "Coast", "Common", "Snail", { "SpiralShell" }, { RGB(240, 200, 170), RGB(250, 230, 200), RGB(255, 150, 160) }, { "Coins", "NearBase" }, { "Bite", "Slow" }, "a hermit snail in a pink spiral shell" },
	{ "Pufferpal", "Puffer Pal", "Coast", "Common", "Fish", { "Spikes", "Round" }, { RGB(250, 220, 120), RGB(255, 250, 230), RGB(255, 160, 80) }, { "Resist", "AfterKill" }, { "Pulse", "Knock" }, "a spiky pufferfish that puffs up" },
	{ "Seagullet", "Seagullet", "Coast", "Uncommon", "Bird", { "Beak", "Wings" }, { RGB(250, 250, 255), RGB(160, 165, 175), RGB(255, 190, 60) }, { "KnockResist", "AfterKill" }, { "Bolt", "Knock" }, "a seagull chick that dives at monsters" },
	{ "Starfin", "Starfin", "Coast", "Uncommon", "Star", { "Arms5", "Face" }, { RGB(255, 140, 120), RGB(255, 200, 170), RGB(255, 255, 255) }, { "Jump", "LowHP" }, { "Bolt", "Slow" }, "a starfish that spins like a throwing star" },
	{ "Inkling", "Inkling", "Coast", "Rare", "Octo", { "Tentacles", "BigEyes" }, { RGB(150, 90, 170), RGB(200, 140, 220), RGB(40, 30, 60) }, { "Stealth", "LowHP" }, { "Lob", "Slow" }, "a baby octopus that squirts ink" },
	{ "Coralcrab", "Coral Crab", "Coast", "Rare", "Crab", { "Pincers", "Coral" }, { RGB(220, 90, 70), RGB(180, 60, 55), RGB(255, 130, 160) }, { "Haste", "LowHP" }, { "Bite", "Expose" }, "a crab growing a coral crown" },
	{ "Narwhalo", "Narwhalo", "Coast", "Epic", "Fish", { "Horn", "TailFin", "Spots" }, { RGB(130, 170, 220), RGB(240, 245, 255), RGB(255, 255, 220) }, { "Speed", "NearBase" }, { "Bite", "Knock" }, "a little narwhal with a spiral horn" },
	{ "Tideguardian", "Tide Guardian", "Coast", "Legendary", "Biped", { "ShellArmor", "Trident" }, { RGB(80, 170, 220), RGB(240, 225, 195), RGB(255, 220, 120) }, { "Cleanse", "NearBase" }, { "Pulse", "Knock" }, "a tiny sea knight in shell armour with a trident" },
}

PetDefs.Types = {}
PetDefs.Order = {}
PetDefs.ByEgg = {}
for _, row in LIST do
	local id = row[1]
	local def = {
		Id = id, Name = row[2], Egg = row[3], Rarity = row[4], Arch = row[5], Features = row[6], Palette = row[7],
		Buff = { Kind = row[8][1], When = row[8][2] }, Attack = { Kind = row[9][1], Effect = row[9][2] }, Hook = row[10],
	}
	PetDefs.Types[id] = def
	table.insert(PetDefs.Order, id)
	PetDefs.ByEgg[def.Egg] = PetDefs.ByEgg[def.Egg] or {}
	table.insert(PetDefs.ByEgg[def.Egg], id)
end

-- v2.17 LEVELS / FORMS: pets gain XP whenever their owner earns monster XP.
-- Level 2 and 3 are new FORMS: bigger (Form III is bigger than a player),
-- extra body pieces, a new name, more damage and a stronger buff.
PetDefs.MaxLevel = 3
PetDefs.LevelXP = { 0, 300, 1000 } -- total pet XP needed for level 1 / 2 / 3
PetDefs.LevelScale = { 1, 1.55, 2.25 } -- model size
PetDefs.LevelDamage = { 1, 1.6, 2.4 } -- attack damage
PetDefs.LevelBuff = { 1, 1.35, 1.75 } -- buff value (team caps still apply)
PetDefs.PetXPShare = 0.6 -- pets get 60 % of the monster XP their owner earns
local FORM2 = { Plateau = "Grand", Mountains = "Glacial", Mushroom = "Bloom", Marsh = "Storm", Canyon = "Prism", Volcanic = "Blaze", Coast = "Tidal" }
local FORM3 = { Plateau = "Titan", Mountains = "Warden", Mushroom = "Monarch", Marsh = "King", Canyon = "Sovereign", Volcanic = "Inferno", Coast = "Leviathan" }
function PetDefs.FormName(def, level: number?): string
	level = level or 1
	if level >= 3 then
		return def.Name .. " " .. FORM3[def.Egg]
	elseif level == 2 then
		return FORM2[def.Egg] .. " " .. def.Name
	end
	return def.Name
end
function PetDefs.LevelOf(xp: number): number
	local lv = 1
	for i, need in PetDefs.LevelXP do
		if xp >= need then
			lv = i
		end
	end
	return math.min(lv, PetDefs.MaxLevel)
end

-- value of one pet's buff (before the team cap); flags return true
function PetDefs.BuffValue(def, level: number?): number | boolean
	local b = PetDefs.BUFF[def.Buff.Kind]
	if b.Flag then
		return true
	end
	return b.Base * PetDefs.RARITY[def.Rarity].Power * PetDefs.WHEN[def.Buff.When].Mult * PetDefs.LevelBuff[level or 1]
end

-- player-facing description of a pet's buff
function PetDefs.BuffText(def, level: number?): string
	local b = PetDefs.BUFF[def.Buff.Kind]
	local when = PetDefs.WHEN[def.Buff.When].Label
	if b.Flag then
		return b.Label .. when
	end
	local v = PetDefs.BuffValue(def, level) :: number
	if def.Buff.Kind == "Shield" then
		return string.format(b.Label, math.floor(30 / v)) .. when
	elseif b.Flat then
		return string.format(b.Label, v) .. when
	end
	return string.format(b.Label, math.floor(v * 100 + 0.5)) .. when
end

-- roll a pet from an egg (weighted by rarity)
function PetDefs.Roll(egg: string, rng: Random?): string
	local pool = PetDefs.ByEgg[egg]
	local total = 0
	for _, id in pool do
		total += PetDefs.RARITY[PetDefs.Types[id].Rarity].Weight
	end
	local roll = (rng or Random.new()):NextNumber(0, total)
	for _, id in pool do
		roll -= PetDefs.RARITY[PetDefs.Types[id].Rarity].Weight
		if roll <= 0 then
			return id
		end
	end
	return pool[1]
end

return PetDefs
