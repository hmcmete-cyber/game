-- TEST ONLY (director): press K near the test dummy to play a signature hit
-- effect on it; L / Shift+L picks the character (client-side preview, only you see it). QA account only,
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
	local HitFx = require(ReplicatedStorage.Shared.HitFx)
	local Sfx = require(ReplicatedStorage.Shared.Sfx)
	-- v2.23: L cycles through every character's signature hit, K plays it
	local MonsterDefs = require(ReplicatedStorage.Shared.MonsterDefs)
	local list = { "Red" }
	for _, n in MonsterDefs.Order do
		if HitFx.Styles[n] then
			table.insert(list, n)
		end
	end
	-- v2.26: every special attack (in roster order)
	for _, n in MonsterDefs.Order do
		local def = MonsterDefs.Types[n]
		for _, a in def and def.Abilities or {} do
			if HitFx.Styles[a.Id] then
				table.insert(list, n .. ":" .. a.Id)
			end
		end
	end
	for _, n in { "Shroomling", "PlayerPunch", "PlayerSlam", "PlayerPuff" } do
		table.insert(list, n)
	end
	for _, el in { "Earth", "Ice", "Spore", "Electric", "Crystal", "Fire", "Water" } do
		for _, kind in { "Bite", "Bolt", "Lob", "Pulse", "Chain" } do
			table.insert(list, "Pet" .. el .. kind)
		end
	end
	local idx = 1
	local gui = Instance.new("ScreenGui")
	gui.Name = "VfxTest"
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 70)
	label.Size = UDim2.fromOffset(420, 30)
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	local function show()
		label.Text = `VFX TEST  [L] next  [K] play:  {list[idx]}  ({idx}/{#list})`
	end
	show()
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	-- only near a test dummy (80 studs): the label shows and the keys work
	local function nearDummy(): Vector3?
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return nil
		end
		local best, pos = 80, nil
		for _, dm in CollectionService:GetTagged("TestDummy") do
			local r = dm:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and (r.Position - root.Position).Magnitude < best then
				best = (r.Position - root.Position).Magnitude
				pos = r.Position
			end
		end
		return pos
	end
	task.spawn(function()
		while gui.Parent do
			gui.Enabled = nearDummy() ~= nil
			task.wait(0.3)
		end
	end)
	local busy = 0
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if not gui.Enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.L then
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			idx = (idx - 1 + (shift and -1 or 1)) % #list + 1
			show()
			return
		end
		if input.KeyCode ~= Enum.KeyCode.K or os.clock() < busy then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		busy = os.clock() + 0.4
		local pos = nearDummy()
		if not pos then
			return
		end
		local style = list[idx]
		local colon = string.find(style, ":", 1, true)
		if colon then
			style = string.sub(style, colon + 1) -- "Monster:Ability" -> ability effect
		end
		if style == "Red" then
			FxKit.RedExplosion(pos, 1)
		else
			local bossScale = HitFx.Styles[style] and HitFx.Styles[style].Boss and 1.1 or 1
			HitFx.Build(style, pos, bossScale)
		end
		task.delay(0.15, function()
			Sfx.At("HatchBurst", pos, 0.8)
		end)
	end)
end

return VfxTest
