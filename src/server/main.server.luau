-- Server entry point: wires the services together.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local MapService = require(Services.MapService)
local WeatherService = require(Services.WeatherService)

-- Remotes (server -> client messages)
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local hintEvent = Instance.new("RemoteEvent")
hintEvent.Name = "Hint"
hintEvent.Parent = remotes
local deliveredEvent = Instance.new("RemoteEvent")
deliveredEvent.Name = "Delivered"
deliveredEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

DataService.Start()
MapService.Start()
WeatherService.Start(MapService, DataService, { Hint = hintEvent, Delivered = deliveredEvent })

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
