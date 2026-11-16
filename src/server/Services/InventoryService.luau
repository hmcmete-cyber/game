-- Inventory: 3 fixed slots, never holds carried clouds. Saved with player
-- data, but WIPED when the character dies.
--   Slot 1  Charm   one cloud charm (IceCharm = Q skates, StormCharm = passive)
--   Slot 2  Nitro   charges bought at a Nitro Station (R = speed burst)
--   Slot 3  Fire    reserved for the upcoming ignite/fuel items (T)
--
-- Clients read player attributes:
--   Charm "IceCharm" | "StormCharm" | ""      NitroCharges number
--   ElectricImmune bool   SkatesUntil / SkatesReadyAt / NitroUntil (server time)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Charms = require(ReplicatedStorage.Shared.Charms)

local InventoryService = {}

local DataService, Remotes

-- data.Inventory = { Charm = string?, Nitro = number }
local function inv(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local i = data.Inventory
	if type(i) ~= "table" then
		i = {}
	end
	if i[1] ~= nil then
		-- migrate the old list format: keep the first charm
		i = { Charm = i[1] }
	end
	i.Nitro = i.Nitro or 0
	data.Inventory = i
	return i
end

local function sync(player: Player)
	local i = inv(player)
	player:SetAttribute("Charm", i and i.Charm or "")
	player:SetAttribute("NitroCharges", i and i.Nitro or 0)
	player:SetAttribute("ElectricImmune", i ~= nil and i.Charm == "StormCharm")
end

function InventoryService.Has(player: Player, id: string): boolean
	local i = inv(player)
	return i ~= nil and i.Charm == id
end

-- Put a charm in slot 1 (replaces the old one). Returns the replaced id.
function InventoryService.SetCharm(player: Player, id: string): string?
	local i = inv(player)
	if not i or not Charms.Types[id] then
		return nil
	end
	local old = i.Charm
	i.Charm = id
	sync(player)
	return old
end

function InventoryService.Wipe(player: Player): boolean
	local i = inv(player)
	local had = i ~= nil and (i.Charm ~= nil or i.Nitro > 0)
	local data = DataService.Get(player)
	if data then
		data.Inventory = { Nitro = 0 }
	end
	player:SetAttribute("SkatesUntil", 0)
	player:SetAttribute("NitroUntil", 0)
	sync(player)
	return had
end

local function useItem(player: Player, slot: unknown)
	local i = inv(player)
	if not i then
		return
	end
	local now = workspace:GetServerTimeNow()
	if slot == 1 then
		if i.Charm ~= "IceCharm" or now < (player:GetAttribute("SkatesReadyAt") or 0) then
			return
		end
		player:SetAttribute("SkatesUntil", now + Config.SkatesDuration)
		player:SetAttribute("SkatesReadyAt", now + Config.SkatesDuration + Config.SkatesCooldown)
		Remotes.Hint:FireClient(player, `⛸️ Frost Skates on for {Config.SkatesDuration}s!`, 2)
	elseif slot == 2 then
		if i.Nitro <= 0 or now < (player:GetAttribute("NitroUntil") or 0) then
			return
		end
		i.Nitro -= 1
		player:SetAttribute("NitroUntil", now + Config.NitroDuration)
		sync(player)
	end
end

local function buyNitro(player: Player)
	local i = inv(player)
	local data = DataService.Get(player)
	if not i or not data then
		return
	end
	if i.Nitro >= Config.NitroMax then
		Remotes.Hint:FireClient(player, `Nitro full ({Config.NitroMax})`, 2)
		return
	end
	if data.Coins < Config.NitroPrice then
		Remotes.Hint:FireClient(player, `Need {Config.NitroPrice} coins for Nitro`, 2)
		return
	end
	data.Coins -= Config.NitroPrice
	DataService.Sync(player)
	i.Nitro += 1
	sync(player)
	Remotes.Hint:FireClient(player, `🚀 Nitro +1 ({i.Nitro}/{Config.NitroMax}) — press R`, 2)
end

-- Every Part in Map/Shops with attribute Shop = "Nitro" sells Nitro
local function setupShops()
	local shops = workspace.Map:FindFirstChild("Shops")
	if not shops then
		return
	end
	for _, part in shops:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Shop") == "Nitro" then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = `Buy Nitro ({Config.NitroPrice} coins)`
			prompt.ObjectText = "Nitro Station"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0.2
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			prompt.Triggered:Connect(buyNitro)
		end
	end
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
	Remotes.UseItem.OnServerEvent:Connect(useItem)
	setupShops()
end

return InventoryService
