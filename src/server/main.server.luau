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
local useCharmEvent = Instance.new("RemoteEvent") -- client -> server: use a charm (Q)
useCharmEvent.Name = "UseCharm"
useCharmEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

LightingService.Apply()
DataService.Start()
MapService.Start()
local remoteTable = { Hint = hintEvent, Delivered = deliveredEvent, Alarm = alarmEvent, Stolen = stolenEvent, UseCharm = useCharmEvent }
WeatherService.Start(MapService, DataService, remoteTable)
BaseLockService.Start(MapService, remoteTable)
InventoryService.Start(DataService, remoteTable)
HazardService.Start(MapService)

local function onPlayerAdded(player: Player)
	DataService.Load(player)
	DataService.SetupLeaderstats(player)

	local roof = MapService.AssignRooftop(player)
	if roof then
		player:SetAttribute("Rooftop", roof.Name)
	else
		warn(`[Server] No free rooftop for {player.Name}`)
	end

	WeatherService.OnPlayerAdded(player)
	InventoryService.OnPlayerAdded(player)
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

print(`[{Config.GameName}] Server ready`)
