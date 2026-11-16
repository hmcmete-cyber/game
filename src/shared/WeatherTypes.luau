-- Public cloud API used by the whole game. The actual list of clouds lives in
-- CloudDB.luau (56 clouds) — edit that file to add or tune clouds.
-- This module fills in defaults per rarity and exposes helpers.

local CloudDB = require(script.Parent:WaitForChild("CloudDB"))

local WeatherTypes = {}

-- Rarity tiers: Chance = % of normal spawns that roll this tier.
-- Defaults fill in Reward / Size / Weight when a cloud doesn't set them.
WeatherTypes.Rarity = {
	Common = { Name = "Common", Tier = 1, Chance = 60, Color = Color3.fromRGB(215, 225, 235), Reward = 10, Size = 4 },
	Rare = { Name = "Rare", Tier = 2, Chance = 25, Color = Color3.fromRGB(100, 185, 255), Reward = 40, Size = 4.3 },
	Epic = { Name = "Epic", Tier = 3, Chance = 10.5, Color = Color3.fromRGB(200, 110, 255), Reward = 120, Size = 4.6 },
	Legendary = { Name = "Legendary", Tier = 4, Chance = 4, Color = Color3.fromRGB(255, 190, 60), Reward = 450, Size = 5 },
	Mythic = { Name = "Mythic", Tier = 5, Chance = 0.5, Color = Color3.fromRGB(255, 80, 120), Reward = 2000, Size = 5.6 },
}
WeatherTypes.TierOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

-- Cloud Altars roll only Epic and better
WeatherTypes.AltarTiers = { Epic = 70, Legendary = 25, Mythic = 5 }

WeatherTypes.Biomes = { "Plateau", "Coast", "Mountains", "Valley" }

-- Default looks per visual style (particle colour + motion)
local VISUAL = {
	Cumulus = { Glow = Color3.fromRGB(255, 255, 255), Accel = Vector3.new(0, 0.5, 0), Spin = 0.3 },
	Rain = { Glow = Color3.fromRGB(120, 180, 255), Accel = Vector3.new(0, -40, 0), Spin = 0.5 },
	Snow = { Glow = Color3.fromRGB(255, 255, 255), Accel = Vector3.new(0, -8, 0), Spin = 0.3 },
	Tornado = { Glow = Color3.fromRGB(210, 205, 190), Accel = Vector3.new(0, 15, 0), Spin = 8 },
	Storm = { Glow = Color3.fromRGB(255, 240, 120), Accel = Vector3.zero, Spin = 1 },
	Cosmic = { Glow = Color3.fromRGB(255, 120, 255), Accel = Vector3.new(0, 1, 0), Spin = 0.8 },
	Aurora = { Glow = Color3.fromRGB(120, 255, 170), Accel = Vector3.new(0, -1, 0), Spin = 0.4 },
	Chrono = { Glow = Color3.fromRGB(120, 230, 255), Accel = Vector3.zero, Spin = 3 },
	Phoenix = { Glow = Color3.fromRGB(255, 170, 60), Accel = Vector3.new(0, 8, 0), Spin = 1.2 },
	Void = { Glow = Color3.fromRGB(200, 170, 255), Accel = Vector3.zero, Spin = 0.6 },
	Solar = { Glow = Color3.fromRGB(255, 240, 160), Accel = Vector3.new(0, 2, 0), Spin = 0.8 },
	Mythic = { Glow = Color3.fromRGB(200, 120, 255), Accel = Vector3.zero, Spin = 1.5 },
}

-- Base colour if a cloud has no Tint (used for vault tint, UI, bursts)
local DEFAULT_TINT = {
	Cumulus = Color3.fromRGB(250, 252, 255), Rain = Color3.fromRGB(110, 160, 230), Snow = Color3.fromRGB(235, 245, 255),
	Tornado = Color3.fromRGB(170, 165, 150), Storm = Color3.fromRGB(55, 55, 75), Cosmic = Color3.fromRGB(80, 40, 140),
	Aurora = Color3.fromRGB(150, 255, 210), Chrono = Color3.fromRGB(255, 230, 160), Phoenix = Color3.fromRGB(255, 120, 50),
	Void = Color3.fromRGB(25, 15, 45), Solar = Color3.fromRGB(255, 215, 90), Mythic = Color3.fromRGB(40, 20, 60),
}

WeatherTypes.Types = {}
WeatherTypes.Order = {}

for _, c in CloudDB do
	local rarity = WeatherTypes.Rarity[c.Rarity] or WeatherTypes.Rarity.Common
	local v = VISUAL[c.Visual or "Cumulus"] or VISUAL.Cumulus
	local def = {
		Key = c.Key,
		DisplayName = c.DisplayName,
		Rarity = rarity.Name,
		Tier = rarity.Tier,
		Biomes = c.Biomes or { "Any" },
		Time = c.Time or "Any",
		Weight = c.Weight or 10,
		Reward = c.Reward or rarity.Reward,
		Size = c.Size or rarity.Size,
		Visual = c.Visual or "Cumulus",
		Tint = c.Tint, -- nil = the visual style's own colours
		Color = c.Tint or DEFAULT_TINT[c.Visual or "Cumulus"] or Color3.new(1, 1, 1),
		ParticleColor = c.Glow or v.Glow,
		ParticleAcceleration = v.Accel,
		Spin = c.Spin or v.Spin,
		Perk = c.Perk,
		AltarOnly = c.AltarOnly == true,
	}
	WeatherTypes.Types[c.Key] = def
	table.insert(WeatherTypes.Order, c.Key)
end

function WeatherTypes.RarityOf(typeName: string)
	local def = WeatherTypes.Types[typeName]
	return WeatherTypes.Rarity[def and def.Rarity or "Common"]
end

function WeatherTypes.InBiome(def, biome: string): boolean
	for _, b in def.Biomes do
		if b == "Any" or b == biome then
			return true
		end
	end
	return false
end

function WeatherTypes.TimeOk(def, isNight: boolean): boolean
	return def.Time == "Any" or (def.Time == "Night") == isNight
end

-- Real spawn % of every cloud for a biome + time (handy for balancing / UI)
function WeatherTypes.ChanceTable(biome: string, isNight: boolean): { [string]: number }
	local out = {}
	for _, tierName in WeatherTypes.TierOrder do
		local total = 0
		for _, key in WeatherTypes.Order do
			local def = WeatherTypes.Types[key]
			if def.Rarity == tierName and not def.AltarOnly and WeatherTypes.InBiome(def, biome) and WeatherTypes.TimeOk(def, isNight) then
				total += def.Weight
			end
		end
		for _, key in WeatherTypes.Order do
			local def = WeatherTypes.Types[key]
			if total > 0 and def.Rarity == tierName and not def.AltarOnly and WeatherTypes.InBiome(def, biome) and WeatherTypes.TimeOk(def, isNight) then
				out[key] = WeatherTypes.Rarity[tierName].Chance * def.Weight / total
			end
		end
	end
	return out
end

-- Short text + colour for UI chips: initials of the name, cloud's colour
WeatherTypes.Icon = setmetatable({}, {
	__index = function(_, key)
		local def = WeatherTypes.Types[key]
		if not def then
			return nil
		end
		local initials = ""
		for word in string.gmatch(def.DisplayName, "%a+") do
			initials ..= string.upper(string.sub(word, 1, 1))
			if #initials >= 2 then
				break
			end
		end
		if #initials < 2 then
			initials = string.upper(string.sub(def.DisplayName, 1, 2))
		end
		return { initials, def.Color }
	end,
})

-- Shiny variant: rare, golden, worth more. Never stronger.
WeatherTypes.ShinyChance = 0.01
WeatherTypes.ShinyMultiplier = 5
WeatherTypes.ShinyColor = Color3.fromRGB(255, 205, 60)

return WeatherTypes
