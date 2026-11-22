-- TEST ONLY: the "QA Item Spawner" panel (opened by the QA tool; the server
-- checks the QA account on every request). Tabs: Items, Upgrades, Pets,
-- Eggs, Extra (coins, unlock all). Click a name to get it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopItems = require(ReplicatedStorage.Shared.ShopItems)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local PetDefs = require(ReplicatedStorage.Shared.PetDefs)

local QaSpawnerUi = {}

local gui, list, remote

local function clear()
	for _, c in list:GetChildren() do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
end

local function entry(text: string, color: Color3, onClick: () -> ())
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -10, 0, 34)
	b.BackgroundColor3 = Color3.fromRGB(40, 44, 62)
	b.TextColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Text = "   " .. text
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	b.Parent = list
	b.Activated:Connect(function()
		onClick()
		b.BackgroundColor3 = Color3.fromRGB(70, 140, 90)
		task.delay(0.25, function()
			if b.Parent then
				b.BackgroundColor3 = Color3.fromRGB(40, 44, 62)
			end
		end)
	end)
end

local TABS = {
	Items = function()
		for _, id in ShopItems.Order do
			local it = ShopItems.Types[id]
			entry(it.DisplayName, Color3.fromRGB(150, 220, 255), function()
				remote:FireServer("Item", id)
			end)
		end
	end,
	Upgrades = function()
		for _, id in Upgrades.Order do
			local u = Upgrades.Types[id]
			entry(u.DisplayName .. (u.Boon and "  (boon)" or "  (max level)"), Color3.fromRGB(255, 215, 120), function()
				remote:FireServer("Upgrade", id)
			end)
		end
	end,
	Pets = function()
		for _, id in PetDefs.Order do
			local p = PetDefs.Types[id]
			entry(`{p.Name}  ·  {p.Rarity}  ·  {p.Egg}`, PetDefs.RARITY[p.Rarity].Color, function()
				remote:FireServer("Pet", id)
			end)
		end
	end,
	Eggs = function()
		for key, e in PetDefs.Eggs do
			entry(e.Name, e.Color2, function()
				remote:FireServer("Egg", key)
			end)
		end
	end,
	Extra = function()
		entry("+10,000 coins", Color3.fromRGB(255, 220, 90), function()
			remote:FireServer("Coins")
		end)
		entry("Unlock all Orb items", Color3.fromRGB(180, 255, 180), function()
			remote:FireServer("UnlockAll")
		end)
		entry("+5 of every forge material", Color3.fromRGB(255, 170, 90), function()
			remote:FireServer("Materials")
		end)
		entry("+1 of every biome totem", Color3.fromRGB(120, 200, 255), function()
			remote:FireServer("Totems")
		end)
	end,
}

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "QaSpawner"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 40
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(0.42, 0, 0.72, 0)
	frame.BackgroundColor3 = Color3.fromRGB(22, 24, 36)
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
	local lim = Instance.new("UISizeConstraint")
	lim.MinSize = Vector2.new(320, 320)
	lim.MaxSize = Vector2.new(560, 720)
	lim.Parent = frame
	frame.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 6)
	title.Size = UDim2.new(1, -60, 0, 32)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 140, 80)
	title.Text = "QA Item Spawner"
	title.Parent = frame
	local close = Instance.new("TextButton")
	close.Position = UDim2.new(1, -42, 0, 6)
	close.Size = UDim2.fromOffset(34, 34)
	close.Text = "X"
	close.Font = Enum.Font.GothamBlack
	close.TextSize = 18
	close.TextColor3 = Color3.new(1, 1, 1)
	close.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
	close.Parent = frame
	close.Activated:Connect(function()
		gui.Enabled = false
	end)
	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(8, 44)
	tabs.Size = UDim2.new(1, -16, 0, 32)
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 6)
	tl.Parent = tabs
	tabs.Parent = frame
	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(8, 84)
	list.Size = UDim2.new(1, -16, 1, -92)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 4)
	ll.Parent = list
	list.Parent = frame
	for _, name in { "Items", "Upgrades", "Pets", "Eggs", "Extra" } do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.2, -5, 1, 0)
		b.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.Text = name
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		b.Parent = tabs
		b.Activated:Connect(function()
			clear()
			TABS[name]()
		end)
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function QaSpawnerUi.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("QaOpenSpawner", 30)
	local open = remotes:FindFirstChild("QaOpenSpawner")
	remote = remotes:WaitForChild("QaSpawn", 30)
	if not open or not remote then
		return
	end
	build()
	open.OnClientEvent:Connect(function()
		gui.Enabled = true
		clear()
		TABS.Items()
	end)
end

return QaSpawnerUi
