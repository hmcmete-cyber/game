-- Player data: load, save, leaderstats.
-- If DataStores are unavailable (e.g. Studio without API access), the game
-- still works, it just doesn't save — and never overwrites real data.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)

local profiles = {} -- [Player] = data table
local canSave = {} -- [Player] = true only if load succeeded

local function defaults()
	return {
		Coins = Config.StartingCoins,
		Delivered = 0,
		Collection = {}, -- [typeName or typeName_Shiny] = count
		Recent = {}, -- newest first: { Type = string, Shiny = boolean }
	}
end

local function key(player: Player)
	return "Player_" .. player.UserId
end

function DataService.Load(player: Player)
	local data = defaults()
	local ok = false
	if store then
		local success, result = pcall(function()
			return store:GetAsync(key(player))
		end)
		if success then
			ok = true
			if type(result) == "table" then
				for k, v in result do
					data[k] = v
				end
			end
		else
			warn(`[Data] Could not load {player.Name} (saving disabled for this session): {result}`)
		end
	end
	profiles[player] = data
	canSave[player] = ok
	return data
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.Save(player: Player)
	local data = profiles[player]
	if not data or not canSave[player] or not store then
		return
	end
	local success, err = pcall(function()
		store:SetAsync(key(player), data)
	end)
	if not success then
		warn(`[Data] Could not save {player.Name}: {err}`)
	end
end

function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
	canSave[player] = nil
end

function DataService.SetupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats

	leaderstats.Parent = player
	DataService.Sync(player)
end

-- Copy data values into leaderstats
function DataService.Sync(player: Player)
	local data = profiles[player]
	local leaderstats = player:FindFirstChild("leaderstats")
	if data and leaderstats then
		leaderstats.Coins.Value = data.Coins
	end
end

function DataService.Start()
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.Save, player)
		end
		task.wait(2)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)
end

return DataService
