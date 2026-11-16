-- Two separate inventories (both saved, both WIPED when you die):
--
--   Inventory (items)  shop items bought from Tayron: potions, Nitro, flares…
--                      data.Items = { { Id, Count }, ... }  (max Config.ItemSlots)
--   Quirks / Perks     clouds equipped from YOUR OWN vault; their perk is active
--                      while equipped. Dying destroys the cloud for good.
--                      data.Perks = { { Type, Shiny }, ... } (max Config.PerkSlots)
--
-- Carried (leashed) clouds are in neither inventory.
--
-- Clients read player attributes:
--   Items "Nitro:2,Flare:1"   Perks "Cosmic:0,Snow:1" (Type:shiny)
--   PerkSpeed, PerkJump, NoSlip, IceGrip, WindImmune, ElectricImmune, LightningImmune
--   SpeedUntil/SpeedMult, JumpUntil/JumpMult, NitroUntil (server time)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local ShopItems = require(ReplicatedStorage.Shared.ShopItems)
local Weather = require(ReplicatedStorage.Shared.WeatherTypes)

local InventoryService = {}

-- Set by WeatherService: puts a perk cloud back into the player's vault
InventoryService.ReturnToVault = nil :: ((Player, string, boolean) -> boolean)?

local DataService, Remotes

------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------

local function data(player: Player)
	local d = DataService.Get(player)
	if not d then
		return nil
	end
	if type(d.Items) ~= "table" then
		d.Items = {}
		-- migrate old Nitro charges
		if type(d.Inventory) == "table" and (d.Inventory.Nitro or 0) > 0 then
			table.insert(d.Items, { Id = "Nitro", Count = d.Inventory.Nitro })
		end
	end
	if type(d.Perks) ~= "table" then
		d.Perks = {}
	end
	d.Inventory = nil
	return d
end

local function perkTotals(perks)
	local t = {
		PerkSpeed = 1,
		PerkJump = 1,
		NoSlip = false,
		IceGrip = false,
		WindImmune = false,
		ElectricImmune = false,
		LightningImmune = false,
		Regen = 0,
		ItemTime = 1,
	}
	for _, entry in perks do
		local def = Weather.Types[entry.Type]
		local perk = def and def.Perk
		if perk then
			t.PerkSpeed *= perk.Speed or 1
			t.PerkJump *= perk.Jump or 1
			t.NoSlip = t.NoSlip or perk.NoSlip == true
			t.IceGrip = t.IceGrip or perk.IceGrip == true
			t.WindImmune = t.WindImmune or perk.WindImmune == true
			t.ElectricImmune = t.ElectricImmune or perk.ElectricImmune == true
			t.LightningImmune = t.LightningImmune or perk.LightningImmune == true
			t.Regen += perk.Regen or 0
			t.ItemTime = math.max(t.ItemTime, perk.ItemTime or 1)
		end
	end
	return t
end

local function sync(player: Player)
	local d = data(player)
	if not d then
		return
	end
	local items = {}
	for _, it in d.Items do
		table.insert(items, `{it.Id}:{it.Count}`)
	end
	player:SetAttribute("Items", table.concat(items, ","))

	local perks = {}
	for _, p in d.Perks do
		table.insert(perks, `{p.Type}:{p.Shiny and 1 or 0}`)
	end
	player:SetAttribute("Perks", table.concat(perks, ","))
	for k, v in perkTotals(d.Perks) do
		player:SetAttribute(k, v)
	end
end

------------------------------------------------------------------------
-- Perks
------------------------------------------------------------------------

function InventoryService.EquipPerk(player: Player, typeName: string, shiny: boolean): boolean
	local d = data(player)
	if not d or #d.Perks >= Config.PerkSlots then
		return false
	end
	table.insert(d.Perks, { Type = typeName, Shiny = shiny })
	sync(player)
	return true
end

local function perkAction(player: Player, action: unknown, index: unknown)
	local d = data(player)
	if not d or action ~= "Return" or type(index) ~= "number" then
		return
	end
	local entry = d.Perks[index]
	if not entry or not InventoryService.ReturnToVault then
		return
	end
	if InventoryService.ReturnToVault(player, entry.Type, entry.Shiny == true) then
		table.remove(d.Perks, index)
		sync(player)
		Remotes.Hint:FireClient(player, `{Weather.Types[entry.Type].DisplayName} is safe in your vault again`, 3)
	else
		Remotes.Hint:FireClient(player, "Your vault is full!", 2)
	end
end

------------------------------------------------------------------------
-- Items (shop)
------------------------------------------------------------------------

local function addItem(d, id: string): boolean
	for _, it in d.Items do
		if it.Id == id then
			if it.Count >= Config.ItemStack then
				return false
			end
			it.Count += 1
			return true
		end
	end
	if #d.Items >= Config.ItemSlots then
		return false
	end
	table.insert(d.Items, { Id = id, Count = 1 })
	return true
end

local function buy(player: Player, id: unknown)
	local d = data(player)
	local item = type(id) == "string" and ShopItems.Types[id]
	if not d or not item or item.ComingSoon then
		return
	end
	if d.Coins < item.Price then
		Remotes.Hint:FireClient(player, `Not enough coins — {item.DisplayName} costs {item.Price}`, 2)
		return
	end
	if not addItem(d, id :: string) then
		Remotes.Hint:FireClient(player, "Inventory full!", 2)
		return
	end
	d.Coins -= item.Price
	DataService.Sync(player)
	sync(player)
	Remotes.Hint:FireClient(player, `{item.Icon} Bought {item.DisplayName}!`, 2)
end

local function flare(player: Player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pillar = Instance.new("Part")
	pillar.Name = "Flare"
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = Color3.fromRGB(255, 120, 200)
	pillar.Transparency = 0.3
	pillar.Size = Vector3.new(1.5, 300, 1.5)
	pillar.Position = root.Position + Vector3.new(0, 150, 0)
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 4
	light.Color = pillar.Color
	light.Parent = pillar
	pillar.Parent = workspace
	Debris:AddItem(pillar, ShopItems.Types.Flare.Duration)
	Remotes.Hint:FireAllClients(`📍 {player.DisplayName} sent a flare!`, 3)
end

local function useItem(player: Player, id: unknown)
	local d = data(player)
	local item = type(id) == "string" and ShopItems.Types[id]
	if not d or not item or item.ComingSoon then
		return
	end
	local slot
	for i, it in d.Items do
		if it.Id == id then
			slot = i
			break
		end
	end
	if not slot then
		return
	end

	local now = workspace:GetServerTimeNow()
	local duration = (item.Duration or 0) * (player:GetAttribute("ItemTime") or 1)
	if item.Effect == "Speed" then
		player:SetAttribute("SpeedMult", item.Amount)
		player:SetAttribute("SpeedUntil", now + duration)
	elseif item.Effect == "Jump" then
		player:SetAttribute("JumpMult", item.Amount)
		player:SetAttribute("JumpUntil", now + duration)
	elseif item.Effect == "Nitro" then
		if now < (player:GetAttribute("NitroUntil") or 0) then
			return -- already boosting
		end
		player:SetAttribute("NitroUntil", now + duration)
	elseif item.Effect == "Flare" then
		flare(player)
	end

	local it = d.Items[slot]
	it.Count -= 1
	if it.Count <= 0 then
		table.remove(d.Items, slot)
	end
	sync(player)
end

------------------------------------------------------------------------
-- Death + regen
------------------------------------------------------------------------

function InventoryService.Wipe(player: Player): (number, number)
	local d = data(player)
	if not d then
		return 0, 0
	end
	local lostItems, lostPerks = #d.Items, #d.Perks
	d.Items = {}
	d.Perks = {}
	for _, attr in { "SpeedUntil", "JumpUntil", "NitroUntil" } do
		player:SetAttribute(attr, 0)
	end
	sync(player)
	return lostItems, lostPerks
end

local function regenLoop()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local regen = player:GetAttribute("Regen") or 0
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if regen > 0 and hum and hum.Health > 0 then
				hum.Health = math.min(hum.MaxHealth, hum.Health + regen)
			end
		end
	end
end

function InventoryService.OnPlayerAdded(player: Player)
	sync(player)
	local function onCharacter(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			local items, perks = InventoryService.Wipe(player)
			if perks > 0 then
				Remotes.Hint:FireClient(player, `💀 You died — {perks} perk cloud(s) and your items are GONE!`, 5)
			elseif items > 0 then
				Remotes.Hint:FireClient(player, "💀 You died — your items were lost!", 4)
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
	Remotes.BuyItem.OnServerEvent:Connect(buy)
	Remotes.PerkAction.OnServerEvent:Connect(perkAction)
	task.spawn(regenLoop)
end

return InventoryService
