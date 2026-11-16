-- Tayron's Cloud Shop window (glassmorphism). Opens when the server fires
-- OpenShop (you pressed E on Tayron). Bought items go to your normal
-- Inventory — the server checks coins and space (InventoryService).
--
-- PlayerGui
-- └── ShopUI (ScreenGui)
--     └── Window (Frame, centered glass)
--         ├── Header: Avatar "☁️", Title "Tayron's Cloud Shop", Subtitle, Coins, Close (X)
--         └── Grid (ScrollingFrame + UIGridLayout)
--             └── Card<ItemId> (Frame): Icon, Name, Desc, Buy (TextButton "🪙 40")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ShopItems = require(ReplicatedStorage.Shared.ShopItems)

local ShopUi = {}

local player = Players.LocalPlayer
local window, scale, coinsLabel
local remotes

local function glass(class: string, parent: Instance, name: string, radius: number, transparency: number?): GuiObject
	local f = Instance.new(class) :: GuiObject
	f.Name = name
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = transparency or 0.75
	f.BorderSizePixel = 0
	if f:IsA("TextButton") then
		f.Text = ""
	end
	f.Parent = parent
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, radius)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 175, 235))
	g.Parent = f
	return f
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.6
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

local function close()
	if not window.Visible then
		return
	end
	local t = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 })
	t.Completed:Connect(function()
		window.Visible = false
	end)
	t:Play()
end

local function open()
	local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
	coinsLabel.Text = `🪙 {coins and coins.Value or 0}`
	window.Visible = true
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	window = glass("Frame", gui, "Window", 22, 0.7)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.52)
	window.Size = UDim2.fromOffset(620, 430)
	window.Visible = false
	scale = Instance.new("UIScale")
	scale.Parent = window

	-- Header
	local avatar = glass("Frame", window, "Avatar", 30, 0.5)
	avatar.Position = UDim2.fromOffset(18, 16)
	avatar.Size = UDim2.fromOffset(60, 60)
	label(avatar, { Text = "☁️", Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 1 })
	label(window, {
		Name = "Title",
		Text = "Tayron's Cloud Shop",
		Font = Enum.Font.FredokaOne,
		Position = UDim2.fromOffset(90, 16),
		Size = UDim2.new(1, -230, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label(window, {
		Name = "Subtitle",
		Text = "\"Fresh potions, flares and more! Items go to your Inventory — lost if you fall.\"",
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(90, 52),
		Size = UDim2.new(1, -230, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(235, 230, 255),
	})
	local coinBox = glass("Frame", window, "Coins", 12, 0.6)
	coinBox.AnchorPoint = Vector2.new(1, 0)
	coinBox.Position = UDim2.new(1, -66, 0, 22)
	coinBox.Size = UDim2.fromOffset(110, 40)
	coinsLabel = label(coinBox, { Text = "🪙 0", Size = UDim2.new(1, -16, 1, -12), Position = UDim2.fromOffset(8, 6), TextColor3 = Color3.fromRGB(255, 220, 90) })
	local x = glass("TextButton", window, "Close", 12, 0.55) :: TextButton
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, -16, 0, 22)
	x.Size = UDim2.fromOffset(40, 40)
	label(x, { Text = "✕", Size = UDim2.fromScale(1, 1) })
	x.Activated:Connect(close)

	-- Item grid
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromOffset(18, 90)
	grid.Size = UDim2.new(1, -36, 1, -108)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = window
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(186, 150)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for i, id in ShopItems.Order do
		local item = ShopItems.Types[id]
		local card = glass("Frame", grid, "Card" .. id, 16, 0.72)
		card.LayoutOrder = i
		label(card, { Name = "Icon", Text = item.Icon, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(44, 44), TextStrokeTransparency = 1 })
		label(card, {
			Name = "ItemName",
			Text = item.DisplayName,
			Position = UDim2.fromOffset(60, 12),
			Size = UDim2.new(1, -70, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		label(card, {
			Name = "Desc",
			Text = item.Desc,
			Font = Enum.Font.GothamMedium,
			TextWrapped = true,
			Position = UDim2.fromOffset(10, 58),
			Size = UDim2.new(1, -20, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(235, 235, 250),
		})
		local buy = glass("TextButton", card, "Buy", 12, item.ComingSoon and 0.75 or 0.2) :: TextButton
		buy.BackgroundColor3 = item.ComingSoon and Color3.fromRGB(150, 150, 170) or Color3.fromRGB(120, 220, 160)
		buy.Position = UDim2.new(0, 10, 1, -44)
		buy.Size = UDim2.new(1, -20, 0, 34)
		label(buy, {
			Text = item.ComingSoon and "Coming soon" or `Buy · 🪙 {item.Price}`,
			Size = UDim2.new(1, -12, 1, -10),
			Position = UDim2.fromOffset(6, 5),
		})
		if not item.ComingSoon then
			buy.Activated:Connect(function()
				remotes.BuyItem:FireServer(id)
				local s = Instance.new("UIScale", buy)
				s.Scale = 0.9
				TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				task.delay(0.25, function()
					s:Destroy()
				end)
			end)
		end
	end
end

function ShopUi.Start()
	remotes = ReplicatedStorage:WaitForChild("Remotes")
	build()
	remotes:WaitForChild("OpenShop").OnClientEvent:Connect(open)

	-- live coin counter while open
	task.spawn(function()
		local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue
		coins.Changed:Connect(function(v)
			coinsLabel.Text = `🪙 {v}`
		end)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape or (not processed and input.KeyCode == Enum.KeyCode.Backspace) then
			close()
		end
	end)

	-- walking away closes the shop
	task.spawn(function()
		while true do
			task.wait(0.5)
			if window.Visible then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local tayron = workspace.Map:FindFirstChild("Tayron", true)
				local troot = tayron and tayron:FindFirstChild("HumanoidRootPart")
				if root and troot and (root.Position - troot.Position).Magnitude > 20 then
					close()
				end
			end
		end
	end)
end

return ShopUi
