-- Permanent upgrades (Aurelius). Saved in data.Upgrades = { [id] = level }.
-- NOT lost on death. Applied through player attributes:
--   UpgradeSpeed (×), UpgradeJump (×), CarryBonus (+studs/s), IncomeMult (×),
--   PerkSlots (Config.PerkSlots + Perk Pocket), Up_<id> = level (for the UI)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local UpgradeService = {}

local DataService, Remotes

local function levels(player: Player)
	local d = DataService.Get(player)
	if not d then
		return nil, nil
	end
	if type(d.Upgrades) ~= "table" then
		d.Upgrades = {}
	end
	return d.Upgrades, d
end

function UpgradeService.Sync(player: Player)
	local lv = levels(player)
	if not lv then
		return
	end
	for _, id in Upgrades.Order do
		player:SetAttribute("Up_" .. id, lv[id] or 0)
	end
	player:SetAttribute("UpgradeSpeed", 1 + (lv.Speed or 0) * Upgrades.Types.Speed.Per)
	player:SetAttribute("UpgradeJump", 1 + (lv.Jump or 0) * Upgrades.Types.Jump.Per)
	player:SetAttribute("CarryBonus", (lv.Carry or 0) * Upgrades.Types.Carry.Per)
	player:SetAttribute("IncomeMult", 1 + (lv.Income or 0) * Upgrades.Types.Income.Per)
	player:SetAttribute("PerkSlots", Config.PerkSlots + (lv.PerkSlot or 0))
end

local function buy(player: Player, id: unknown)
	local def = type(id) == "string" and Upgrades.Types[id]
	local lv, d = levels(player)
	if not def or not lv or not d then
		return
	end
	local level = lv[id] or 0
	if level >= def.MaxLevel then
		Remotes.Hint:FireClient(player, `Max level!`, 2)
		return
	end
	local cost = Upgrades.Cost(id :: string, level)
	if d.Coins < cost then
		Remotes.Hint:FireClient(player, `Need {cost} coins`, 2)
		return
	end
	d.Coins -= cost
	lv[id] = level + 1
	DataService.Sync(player)
	UpgradeService.Sync(player)
	Remotes.Hint:FireClient(player, `Upgraded!`, 3)
end

function UpgradeService.OnPlayerAdded(player: Player)
	UpgradeService.Sync(player)
end

function UpgradeService.Start(dataService, remotes)
	DataService = dataService
	Remotes = remotes
	Remotes.BuyUpgrade.OnServerEvent:Connect(buy)
end

return UpgradeService
