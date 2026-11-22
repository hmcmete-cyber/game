-- Server entry point: wires the services together.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local MapService = require(Services.MapService)
local WeatherService = require(Services.WeatherService)
local LightingService = require(Services.LightingService)
local BaseLockService = require(Services.BaseLockService)
local InventoryService = require(Services.InventoryService)
local HazardService = require(Services.HazardService)
local NpcService = require(Services.NpcService)
local UpgradeService = require(Services.UpgradeService)
local EventService = require(Services.EventService)
local DummyService = require(Services.DummyService)
local MonsterService = require(Services.MonsterService)
local CombatService = require(Services.CombatService)
local StyleSample = require(Services.StyleSample)

-- Remotes (server -> client messages)
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local hintEvent = Instance.new("RemoteEvent")
hintEvent.Name = "Hint"
hintEvent.Parent = remotes
local deliveredEvent = Instance.new("RemoteEvent")
deliveredEvent.Name = "Delivered"
deliveredEvent.Parent = remotes
local alarmEvent = Instance.new("RemoteEvent")
alarmEvent.Name = "Alarm"
alarmEvent.Parent = remotes
local stolenEvent = Instance.new("RemoteEvent")
stolenEvent.Name = "Stolen"
stolenEvent.Parent = remotes
local function remote(name: string)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local useItemEvent = remote("UseItem") -- client -> server: use a shop item (id)
local buyItemEvent = remote("BuyItem") -- client -> server: buy from Tayron (id)
local perkActionEvent = remote("PerkAction") -- client -> server: ("Return", index)
local openShopEvent = remote("OpenShop") -- server -> client: open a shop ("Items" | "Upgrades", vendor)
local buyUpgradeEvent = remote("BuyUpgrade") -- client -> server: Aurelius upgrade (id)
local perkAbilityEvent = remote("PerkAbility") -- client -> server: use perk ability (slot)
local dazzleEvent = remote("Dazzle") -- server -> client: white-out flash (seconds)
local grappleEvent = remote("Grapple") -- server -> client: zip to this point (Grappling Hook)
local attackEvent = remote("Attack") -- client -> server: ("Punch" | "Slam" | "Puff", aim)
local knockEvent = Instance.new("RemoteEvent") -- server -> client: lightning knockback
knockEvent.Name = "Knock"
knockEvent.Parent = remotes
remotes.Parent = ReplicatedStorage
require(ReplicatedStorage.Shared.AssetProbe).Watch("203785492") -- Studio only: who loads the bad asset?

-- One broken service must not stop the rest (bases, coins, weather...).
-- The error is still printed in red with its stack.
local function safe(name: string, fn: (...any) -> ...any, ...)
	local ok, err = xpcall(fn, debug.traceback, ...)
	if not ok then
		warn(`[Server] {name} FAILED: {err}`)
	end
end

safe("LightingService.Apply", LightingService.Apply)
-- v2.9: classic stud tile on every part (map, monsters, clouds, NPCs, bases)
local StudStyle = require(ReplicatedStorage.Shared.StudStyle)
safe("StudStyle.SetupMaterial", StudStyle.SetupMaterial)
safe("StudStyle.Watch", StudStyle.Watch)
safe("LightingService.StartCycle", LightingService.StartCycle)
safe("DataService.Start", DataService.Start)
safe("MapService.Start", MapService.Start)
local remoteTable = { Hint = hintEvent, Delivered = deliveredEvent, Alarm = alarmEvent, Stolen = stolenEvent, UseItem = useItemEvent, Knock = knockEvent,
	BuyItem = buyItemEvent, PerkAction = perkActionEvent, OpenShop = openShopEvent,
	BuyUpgrade = buyUpgradeEvent, PerkAbility = perkAbilityEvent, Dazzle = dazzleEvent, Grapple = grappleEvent, Attack = attackEvent }
safe("WeatherService.Start", WeatherService.Start, MapService, DataService, remoteTable)
safe("BaseLockService.Start", BaseLockService.Start, MapService, remoteTable)
safe("InventoryService.Start", InventoryService.Start, DataService, remoteTable)
InventoryService.Hooks.ForceLock = BaseLockService.ForceLock
InventoryService.Hooks.OnOwnBase = function(player: Player): boolean
	local roof = MapService.GetRooftop(player)
	local nest = roof and roof:FindFirstChild("Nest")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return nest ~= nil and root ~= nil and (root.Position - nest.Position).Magnitude <= Config.ShieldRadius
end
safe("HazardService.Start", HazardService.Start, MapService, remoteTable)
safe("UpgradeService.Start", UpgradeService.Start, DataService, remoteTable)
safe("NpcService.Start", NpcService.Start, remoteTable)
safe("EventService.Start", EventService.Start, MapService, WeatherService, remoteTable)
safe("DummyService.Start", DummyService.Start, WeatherService) -- Studio only
safe("MonsterService.Start", MonsterService.Start, MapService, DataService, remoteTable)
safe("CombatService.Start", CombatService.Start, remoteTable, InventoryService, MonsterService, DummyService)
safe("require(Services.QaWeaponService).Start", require(Services.QaWeaponService).Start, MonsterService) -- TEST ONLY: director QA weapon (Studio/private servers)
-- v2.12 pets + boss eggs + incubator
local PetService = require(Services.PetService)
safe("PetService.Start", PetService.Start, DataService, MonsterService)
InventoryService.Hooks.MonsterBlast = PetService.Blast -- v2.13 Tayron gadgets
safe("require(Services.VendorOrbService).Start", require(Services.VendorOrbService).Start, DataService, WeatherService, remoteTable) -- v2.13 vendor orbs
safe("require(Services.TutorialService).Start", require(Services.TutorialService).Start, DataService) -- v2.18 first-visit tutorial
safe("ForgeService.Start", require(Services.ForgeService).Start, DataService, MonsterService, remoteTable) -- v2.35 Poseidon + totems + realms
safe("require(Services.EggService).Start", require(Services.EggService).Start, DataService, PetService, remoteTable, require(Services.MonsterDeaths))
safe("StyleSample.Start", StyleSample.Start, require(Services.MonsterRigs)) -- Studio only: v2.1 style review island

local function onPlayerAdded(player: Player)
	safe("DataService.Load", DataService.Load, player)
	safe("DataService.SetupLeaderstats", DataService.SetupLeaderstats, player)

	local okRoof, roof = pcall(MapService.AssignRooftop, player)
	if not okRoof then
		warn(`[Server] AssignRooftop FAILED: {roof}`)
		roof = nil
	end
	if roof then
		player:SetAttribute("Rooftop", roof.Name)
	else
		warn(`[Server] No free rooftop for {player.Name}`)
	end

	safe("WeatherService.OnPlayerAdded", WeatherService.OnPlayerAdded, player)
	safe("InventoryService.OnPlayerAdded", InventoryService.OnPlayerAdded, player)
	safe("UpgradeService.OnPlayerAdded", UpgradeService.OnPlayerAdded, player)
end

local function onPlayerRemoving(player: Player)
	WeatherService.OnPlayerRemoving(player)
	MapService.ReleaseRooftop(player)
	DataService.Release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print(`[{Config.GameName}] Server ready - build {Config.Version} - QaEverywhere={tostring(Config.QaEverywhere)}`)
