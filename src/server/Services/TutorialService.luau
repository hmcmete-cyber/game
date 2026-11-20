-- v2.18 TUTORIAL: shown once on a player's first visit (Data.TutorialDone),
-- skippable. TutorialService.Show(player) opens it again (QA tool).
-- Remotes: ShowTutorial (server -> client), TutorialDone (client -> server)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialService = {}

local DataService
local showRemote, doneRemote

function TutorialService.Show(player: Player)
	if showRemote then
		showRemote:FireClient(player)
	end
end

function TutorialService.Start(dataService)
	DataService = dataService
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	showRemote = Instance.new("RemoteEvent")
	showRemote.Name = "ShowTutorial"
	showRemote.Parent = remotes
	doneRemote = Instance.new("RemoteEvent")
	doneRemote.Name = "TutorialDone"
	doneRemote.Parent = remotes
	doneRemote.OnServerEvent:Connect(function(player)
		local d = DataService.Get(player)
		if d and not d.TutorialDone then
			d.TutorialDone = true
			DataService.SaveSoon(player)
		end
	end)
	local function setup(player: Player)
		task.spawn(function()
			for _ = 1, 40 do
				if DataService.Get(player) then
					break
				end
				task.wait(0.5)
			end
			local d = DataService.Get(player)
			if d and not d.TutorialDone then
				task.wait(4) -- let the world load first
				if player.Parent then
					TutorialService.Show(player)
				end
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		setup(p)
	end
	Players.PlayerAdded:Connect(setup)
end

return TutorialService
