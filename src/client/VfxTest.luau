-- TEST ONLY (director): press K near the test dummy to play the showcase red
-- explosion on it (client-side preview, only you see it). QA account only,
-- in Studio or a private server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VfxTest = {}

local QA_USER = 2459147914

function VfxTest.Start()
	local player = Players.LocalPlayer
	if player.UserId ~= QA_USER or not (RunService:IsStudio() or game.PrivateServerId ~= "") then
		return
	end
	local FxKit = require(ReplicatedStorage.Shared.FxKit)
	local Sfx = require(ReplicatedStorage.Shared.Sfx)
	local busy = 0
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.K or os.clock() < busy then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		busy = os.clock() + 0.4
		-- nearest test dummy within 80 studs, else 14 studs in front of you
		local pos = root.Position + root.CFrame.LookVector * 14
		local best = 80
		for _, d in CollectionService:GetTagged("TestDummy") do
			local r = d:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and (r.Position - root.Position).Magnitude < best then
				best = (r.Position - root.Position).Magnitude
				pos = r.Position
			end
		end
		FxKit.RedExplosion(pos, 1)
		task.delay(0.15, function()
			Sfx.At("HatchBurst", pos, 0.8)
		end)
	end)
end

return VfxTest
