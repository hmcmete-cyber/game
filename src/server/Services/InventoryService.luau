-- Inventory: charms only (never carried clouds), max Config.InventorySize.
-- Saved with player data, but WIPED when the character dies.
--
-- Clients see it through player attributes:
--   Inventory        "IceCharm,StormCharm"  (comma list, in slot order)
--   ElectricImmune   true if a Storm Charm is held (passive)
--   SkatesUntil      server time when Frost Skates end
--   SkatesReadyAt    server time when Q can be used again

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Charms = require(ReplicatedStorage.Shared.Charms)

local InventoryService = {}

local DataService, Remotes

local function list(player: Player): { string }
	local data = DataService.Get(player)
	if not data then
		return {}
	end
	if type(data.Inventory) ~= "table" then
		data.Inventory = {}
	end
	return data.Inventory
end

local function sync(player: Player)
	local items = list(player)
	player:SetAttribute("Inventory", table.concat(items, ","))
	player:SetAttribute("ElectricImmune", table.find(items, "StormCharm") ~= nil)
end

function InventoryService.Has(player: Player, id: string): boolean
	return table.find(list(player), id) ~= nil
end

-- Returns true if added
function InventoryService.Add(player: Player, id: string): boolean
	if not Charms.Types[id] then
		return false
	end
	local items = list(player)
	if #items >= Config.InventorySize then
		return false
	end
	table.insert(items, id)
	sync(player)
	return true
end

function InventoryService.Wipe(player: Player)
	local data = DataService.Get(player)
	local had = data and type(data.Inventory) == "table" and #data.Inventory > 0
	if data then
		data.Inventory = {}
	end
	player:SetAttribute("SkatesUntil", 0)
	sync(player)
	return had
end

local function useCharm(player: Player, id: unknown)
	if id ~= "IceCharm" or not InventoryService.Has(player, "IceCharm") then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now < (player:GetAttribute("SkatesReadyAt") or 0) then
		return
	end
	player:SetAttribute("SkatesUntil", now + Config.SkatesDuration)
	player:SetAttribute("SkatesReadyAt", now + Config.SkatesDuration + Config.SkatesCooldown)
	Remotes.Hint:FireClient(player, `⛸️ Frost Skates on for {Config.SkatesDuration}s!`, 2)
end

function InventoryService.OnPlayerAdded(player: Player)
	sync(player)
	local function onCharacter(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			if InventoryService.Wipe(player) then
				Remotes.Hint:FireClient(player, "💀 You died — your inventory was lost!", 4)
			end
		end)
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

function InventoryService.Start(dataService, remotes)
	DataService = dataService
	Remotes = remotes
	Remotes.UseCharm.OnServerEvent:Connect(useCharm)
end

return InventoryService
