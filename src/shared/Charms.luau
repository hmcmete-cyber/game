-- Inventory items. Only these can live in the inventory — never carried clouds.
-- A charm is made at YOUR OWN vault from a stored cloud of type `From`
-- (the cloud leaves the vault). All charms are lost when you die.

local Charms = {}

Charms.Types = {
	IceCharm = {
		DisplayName = "Ice Charm",
		Icon = "❄️",
		From = "Snow",
		Key = "Q", -- active: Frost Skates
		Description = "Q: Frost Skates — full grip and extra speed on Ice Paths",
	},
	StormCharm = {
		DisplayName = "Storm Charm",
		Icon = "⚡",
		From = "Thunder",
		Description = "Passive: Electric Swamps can't hurt or slow you",
	},
}

Charms.Order = { "IceCharm", "StormCharm" }

-- Which charm a stored cloud type can become (or nil)
function Charms.FromCloud(cloudType: string): string?
	for id, def in Charms.Types do
		if def.From == cloudType then
			return id
		end
	end
	return nil
end

return Charms
