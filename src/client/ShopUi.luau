-- Vendor window (glassmorphism). Two shops, one window:
--   "Items"    Tayron   · temporary items -> normal Inventory (lost on death)
--   "Upgrades" Aurelius · permanent upgrades (kept forever)
-- Opened by the server (OpenShop remote) when you press E on a vendor.
-- No emoji: icons are coloured text chips that render on every device.
--
-- PlayerGui
-- └── ShopUI (ScreenGui)
--     └── Window (Frame, centered glass)
--         ├── Avatar (chip), Title, Subtitle, Coins, Close
--         └── Grid (ScrollingFrame + UIGridLayout) -> Card<Id> (icon chip, name, desc, level, Buy)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ShopItems = require(ReplicatedStorage.Shared.ShopItems)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local ShopUi = {}

local player = Players.LocalPlayer
local remotes
local window, scale, grid, titleLabel, subtitleLabel, coinsLabel, avatarText
local currentShop = "Items"
local cards = {} -- refreshed on open / attribute change

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

-- Round coloured badge with short text — our emoji-free icon
local function chip(parent: Instance, text: string, color: Color3, size: number, pos: UDim2)
	local c = Instance.new("Frame")
	c.Name = "Icon"
	c.Size = UDim2.fromOffset(size, size)
	c.Position = pos
	c.BackgroundColor3 = color
	c.Parent = parent
	Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = c
	label(c, {
		Text = text,
		Font = Enum.Font.GothamBlack,
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		TextStrokeTransparency = 0.4,
	})
	return c
end

local function coins(): number
	local ls = player:FindFirstChild("leaderstats")
	local c = ls and ls:FindFirstChild("Coins")
	return c and c.Value or 0
end

local function clearGrid()
	for _, c in cards do
		c:Destroy()
	end
	cards = {}
end

local function buyButton(card: Instance, text: string, enabled: boolean, color: Color3, onClick: () -> ())
	local buy = glass("TextButton", card, "Buy", 12, enabled and 0.15 or 0.75) :: TextButton
	buy.BackgroundColor3 = enabled and color or Color3.fromRGB(150, 150, 170)
	buy.Position = UDim2.new(0, 10, 1, -44)
	buy.Size = UDim2.new(1, -20, 0, 34)
	label(buy, { Text = text, Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(6, 5) })
	if enabled then
		buy.Activated:Connect(function()
			onClick()
			local s = Instance.new("UIScale", buy)
			s.Scale = 0.9
			TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			task.delay(0.25, function()
				s:Destroy()
			end)
		end)
	end
end

local function card(i: number, id: string, iconText: string, iconColor: Color3, name: string, desc: string)
	local c = glass("Frame", grid, "Card" .. id, 16, 0.72)
	c.LayoutOrder = i
	chip(c, iconText, iconColor, 44, UDim2.fromOffset(10, 8))
	label(c, {
		Name = "ItemName",
		Text = name,
		Position = UDim2.fromOffset(62, 10),
		Size = UDim2.new(1, -70, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label(c, {
		Name = "Desc",
		Text = desc,
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		Position = UDim2.fromOffset(10, 58),
		Size = UDim2.new(1, -20, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(235, 235, 250),
	})
	table.insert(cards, c)
	return c
end

local function render()
	clearGrid()
	coinsLabel.Text = `{coins()} coins`
	if currentShop == "Items" then
		titleLabel.Text = "Tayron's Cloud Shop"
		subtitleLabel.Text = "Temporary items go to your Inventory - lost if you die."
		avatarText.Text = "T"
		for i, id in ShopItems.Order do
			local item = ShopItems.Types[id]
			local c = card(i, id, item.IconText, item.IconColor, item.DisplayName, item.Desc)
			buyButton(c, item.ComingSoon and "Coming soon" or `Buy - {item.Price} coins`, not item.ComingSoon,
				Color3.fromRGB(120, 220, 160), function()
					remotes.BuyItem:FireServer(id)
				end)
		end
	else
		titleLabel.Text = "Aurelius' Upgrades"
		subtitleLabel.Text = "Permanent upgrades - you keep them forever, even when you die."
		avatarText.Text = "A"
		for i, id in Upgrades.Order do
			local def = Upgrades.Types[id]
			local level = player:GetAttribute("Up_" .. id) or 0
			local maxed = level >= def.MaxLevel
			local c = card(i, id, def.IconText, def.IconColor, def.DisplayName, def.Desc)
			label(c, {
				Name = "Level",
				Text = `Level {level} / {def.MaxLevel}`,
				Font = Enum.Font.GothamMedium,
				Position = UDim2.fromOffset(62, 32),
				Size = UDim2.new(1, -70, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = maxed and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(220, 225, 245),
			})
			buyButton(c, maxed and "MAX" or `Upgrade - {Upgrades.Cost(id, level)} coins`, not maxed,
				Color3.fromRGB(255, 200, 90), function()
					remotes.BuyUpgrade:FireServer(id)
				end)
		end
	end
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

local function open(shop: string?)
	currentShop = shop == "Upgrades" and "Upgrades" or "Items"
	render()
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
	window.Size = UDim2.fromOffset(620, 440)
	window.Visible = false
	scale = Instance.new("UIScale")
	scale.Parent = window

	local avatar = chip(window, "T", Color3.fromRGB(150, 140, 230), 60, UDim2.fromOffset(18, 16))
	avatarText = avatar:FindFirstChildOfClass("TextLabel")
	titleLabel = label(window, {
		Name = "Title",
		Font = Enum.Font.FredokaOne,
		Position = UDim2.fromOffset(90, 16),
		Size = UDim2.new(1, -250, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	subtitleLabel = label(window, {
		Name = "Subtitle",
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(90, 52),
		Size = UDim2.new(1, -250, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(235, 230, 255),
	})
	local coinBox = glass("Frame", window, "Coins", 12, 0.6)
	coinBox.AnchorPoint = Vector2.new(1, 0)
	coinBox.Position = UDim2.new(1, -66, 0, 22)
	coinBox.Size = UDim2.fromOffset(130, 40)
	coinsLabel = label(coinBox, { Size = UDim2.new(1, -16, 1, -12), Position = UDim2.fromOffset(8, 6), TextColor3 = Color3.fromRGB(255, 220, 90) })
	local x = glass("TextButton", window, "Close", 12, 0.55) :: TextButton
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, -16, 0, 22)
	x.Size = UDim2.fromOffset(40, 40)
	label(x, { Text = "X", Size = UDim2.new(1, -14, 1, -14), Position = UDim2.fromOffset(7, 7) })
	x.Activated:Connect(close)

	grid = Instance.new("ScrollingFrame")
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
end

function ShopUi.Start()
	remotes = ReplicatedStorage:WaitForChild("Remotes")
	build()
	remotes:WaitForChild("OpenShop").OnClientEvent:Connect(open)

	-- refresh while open (coins, upgrade levels)
	task.spawn(function()
		local c = player:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue
		c.Changed:Connect(function()
			if window.Visible then
				coinsLabel.Text = `{coins()} coins`
			end
		end)
	end)
	player.AttributeChanged:Connect(function(attr)
		if window.Visible and currentShop == "Upgrades" and string.sub(attr, 1, 3) == "Up_" then
			render()
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			close()
		end
	end)

	-- walking away from every vendor closes the window
	task.spawn(function()
		while true do
			task.wait(0.5)
			if window.Visible then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local near = false
				if root then
					for _, npc in game:GetService("CollectionService"):GetTagged("Npc") do
						local r = npc:FindFirstChild("HumanoidRootPart")
						if r and (r.Position - root.Position).Magnitude < 18 then
							near = true
							break
						end
					end
				end
				if not near then
					close()
				end
			end
		end
	end)
end

return ShopUi
