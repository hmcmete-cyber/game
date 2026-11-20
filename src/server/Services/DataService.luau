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
		XP = 0,
		Collection = {}, -- [typeName or typeName_Shiny] = count
		Recent = {}, -- newest first: { Type = string, Shiny = boolean }
		-- v2.12 pets + eggs
		Pets = {}, -- { { Uid = number, Id = petId } }
		Equipped = {}, -- uids (max PetDefs.EquipLimit)
		NextPetUid = 1,
		Eggs = {}, -- egg keys waiting to be incubated
		Incubator = nil, -- { Egg = key, ReadyAt = os.time() }
		Unlocks = {}, -- v2.13 vendor orb unlocks: [catalog id] = true
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
	if not ok then
		-- v2.17: make it obvious why progress is not kept (usually Studio API access is off)
		player:SetAttribute("SaveDisabled", true)
		task.delay(8, function()
			local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
			local hintEvent = remotes and remotes:FindFirstChild("Hint")
			if hintEvent and player.Parent then
				hintEvent:FireClient(player, game:GetService("RunService"):IsStudio()
					and "Progress is NOT saving: Game Settings > Security > enable Studio Access to API Services (game must be published)."
					or "Progress could not load - it will not be saved this session.", 10)
			end
		end)
	end
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

-- v2.17: save shortly after important progress (hatches, unlocks, level ups),
-- at most once every 10 s per player, on top of the autosave and leave save
local pending = {}
function DataService.SaveSoon(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.delay(10, function()
		pending[player] = nil
		if profiles[player] then
			DataService.Save(player)
		end
	end)
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

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats

	leaderstats.Parent = player
	DataService.Sync(player)
end

-- Copy data values into leaderstats
function DataService.Sync(player: Player)
	local data = profiles[player]
	local leaderstats = player:FindFirstChild("leaderstats")
	if data and leaderstats then
		leaderstats.Coins.Value = data.Coins
		local level = leaderstats:FindFirstChild("Level")
		if level then
			level.Value = DataService.LevelOf(data.XP or 0)
		end
		player:SetAttribute("XP", data.XP or 0)
	end
end

-- Level curve: level n needs 50 * (n-1)^2 XP  (1:0, 2:50, 3:200, 5:800, 10:4050)
function DataService.LevelOf(xp: number): number
	return math.floor(math.sqrt(xp / 50)) + 1
end

-- Adds XP; returns the new level if the player levelled up
function DataService.AddXP(player: Player, amount: number): number?
	local data = profiles[player]
	if not data or amount <= 0 then
		return nil
	end
	local before = DataService.LevelOf(data.XP or 0)
	data.XP = (data.XP or 0) + amount
	DataService.Sync(player)
	local after = DataService.LevelOf(data.XP)
	return after > before and after or nil
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
