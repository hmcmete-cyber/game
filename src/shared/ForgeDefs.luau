-- v2.35 POSEIDON THE BLACKSMITH (director): every biome has its own crafting
-- materials. ONLY normal monsters drop them (never bosses). Bring them to
-- Hephaestus on the hub to forge that biome's TOTEM. Offer a totem at the altar
-- behind the biome's boss (temple shrine) to be teleported into that biome's
-- own realm (the realms are placeholders for now).
--
-- Drops: the killer of a normal monster gets one material of the monster's
-- habitat with DropChance; which one is rolled by Weight (common -> rare).
-- Recipe of every totem: 3x the common one, 2x the uncommon one, 1x the rare one.

local RGB = Color3.fromRGB

local ForgeDefs = {}

ForgeDefs.DropChance = 0.65

-- [biome] = { { id, name, colour, weight, need }, ... }  (common, uncommon, rare)
ForgeDefs.ByBiome = {
	Plateau = {
		{ "SunClay", "Sun Clay", RGB(230, 180, 110), 60, 3 },
		{ "BrambleThorn", "Bramble Thorn", RGB(130, 170, 70), 30, 2 },
		{ "MesaGold", "Mesa Gold", RGB(255, 205, 70), 10, 1 },
	},
	Mountains = {
		{ "FrostShard", "Frost Shard", RGB(170, 225, 255), 60, 3 },
		{ "OwlFeather", "Snow Owl Feather", RGB(240, 245, 255), 30, 2 },
		{ "GlacierHeart", "Glacier Heart", RGB(90, 170, 255), 10, 1 },
	},
	Mushroom = {
		{ "GlowSpore", "Glow Spore", RGB(255, 150, 230), 60, 3 },
		{ "CapFiber", "Cap Fiber", RGB(240, 110, 120), 30, 2 },
		{ "MothDust", "Moth Dust", RGB(140, 255, 230), 10, 1 },
	},
	Marsh = {
		{ "BogMoss", "Bog Moss", RGB(110, 160, 90), 60, 3 },
		{ "StormScale", "Storm Scale", RGB(150, 180, 255), 30, 2 },
		{ "ThunderGem", "Thunder Gem", RGB(255, 245, 120), 10, 1 },
	},
	Canyon = {
		{ "QuartzDust", "Quartz Dust", RGB(220, 210, 255), 60, 3 },
		{ "ScuttlerClaw", "Scuttler Claw", RGB(255, 140, 210), 30, 2 },
		{ "PrismCore", "Prism Core", RGB(150, 200, 255), 10, 1 },
	},
	Volcanic = {
		{ "EmberCoal", "Ember Coal", RGB(80, 60, 55), 60, 3 },
		{ "MagmaScale", "Magma Scale", RGB(255, 110, 40), 30, 2 },
		{ "AshPearl", "Ash Pearl", RGB(255, 225, 200), 10, 1 },
	},
	Coast = {
		{ "SeaGlass", "Sea Glass", RGB(140, 230, 220), 60, 3 },
		{ "InkSac", "Ink Sac", RGB(90, 50, 140), 30, 2 },
		{ "SharkTooth", "Shark Tooth", RGB(250, 250, 240), 10, 1 },
	},
}

ForgeDefs.Biomes = { "Plateau", "Mountains", "Mushroom", "Marsh", "Canyon", "Volcanic", "Coast" }

ForgeDefs.Totems = {
	Plateau = { Name = "Mesa Totem", Realm = "Golden Mesa Realm", Color = RGB(255, 200, 110) },
	Mountains = { Name = "Frost Totem", Realm = "Frozen Peak Realm", Color = RGB(170, 230, 255) },
	Mushroom = { Name = "Spore Totem", Realm = "Glowing Spore Realm", Color = RGB(255, 140, 220) },
	Marsh = { Name = "Storm Totem", Realm = "Thunder Bog Realm", Color = RGB(150, 200, 255) },
	Canyon = { Name = "Prism Totem", Realm = "Crystal Prism Realm", Color = RGB(170, 160, 255) },
	Volcanic = { Name = "Magma Totem", Realm = "Molten Core Realm", Color = RGB(255, 120, 40) },
	Coast = { Name = "Tide Totem", Realm = "Deep Tide Realm", Color = RGB(80, 180, 255) },
}

-- flat lookups
ForgeDefs.Materials = {} -- [id] = { Name, Color, Biome, Weight, Need }
for biome, list in ForgeDefs.ByBiome do
	for _, m in list do
		ForgeDefs.Materials[m[1]] = { Id = m[1], Name = m[2], Color = m[3], Weight = m[4], Need = m[5], Biome = biome }
	end
end

-- roll which material a monster of this biome drops (nil = none)
function ForgeDefs.Roll(biome: string): string?
	local list = ForgeDefs.ByBiome[biome]
	if not list or math.random() > ForgeDefs.DropChance then
		return nil
	end
	local total = 0
	for _, m in list do
		total += m[4]
	end
	local r = math.random() * total
	for _, m in list do
		r -= m[4]
		if r <= 0 then
			return m[1]
		end
	end
	return list[1][1]
end

return ForgeDefs
