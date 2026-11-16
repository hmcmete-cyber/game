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

-- Every card uses the same layout, all in scale + padding, so it looks
-- the same on phones and PCs:
--   [chip] Name            (top row, 30%)
--          Level x / y
--   Description           (middle, wraps)
--   [  Buy button  ]      (bottom, 26%)
local function buyButton(card: Instance, text: string, enabled: boolean, color: Color3, onClick: () -> ())
	local buy = glass("TextButton", card, "Buy", 12, enabled and 0.15 or 0.75) :: TextButton
	buy.BackgroundColor3 = enabled and color or Color3.fromRGB(150, 150, 170)
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.fromScale(0.5, 1)
	buy.Size = UDim2.fromScale(1, 0.24)
	local t = label(buy, {
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.62),
	})
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 18
	cap.Parent = t
	if enabled then
		buy.Activated:Connect(function()
			onClick()
			local s = Instance.new("UIScale", buy)
			s.Scale = 0.92
			TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			task.delay(0.25, function()
				s:Destroy()
			end)
		end)
	end
end

local function capText(t: TextLabel, max: number)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = max
	c.MinTextSize = 8
	c.Parent = t
	return t
end

local function card(i: number, id: string, iconText: string, iconColor: Color3, name: string, desc: string, levelText: string?)
	local c = glass("Frame", grid, "Card" .. id, 16, 0.72)
	c.LayoutOrder = i
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = c

	-- icon chip: always round, whatever the card size
	local icon = chip(c, iconText, iconColor, 44, UDim2.fromScale(0, 0))
	icon.Size = UDim2.fromScale(0.26, 0.3)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.DominantAxis = Enum.DominantAxis.Height
	ratio.Parent = icon

	capText(label(c, {
		Name = "ItemName",
		Text = name,
		Position = UDim2.fromScale(0.3, 0),
		Size = UDim2.fromScale(0.7, levelText and 0.17 or 0.3),
		TextXAlignment = Enum.TextXAlignment.Left,
	}), 20)
	if levelText then
		capText(label(c, {
			Name = "Level",
			Text = levelText,
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromScale(0.3, 0.18),
			Size = UDim2.fromScale(0.7, 0.12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 225, 140),
		}), 14)
	end
	capText(label(c, {
		Name = "Desc",
		Text = desc,
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		Position = UDim2.fromScale(0, 0.34),
		Size = UDim2.fromScale(1, 0.38),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(235, 235, 250),
	}), 15)
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
			local c = card(i, id, def.IconText, def.IconColor, def.DisplayName, def.Desc, `Level {level} / {def.MaxLevel}`)
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

	-- Window: 92% of the screen on phones, capped at 760x540 on PCs,
	-- always the same shape (aspect 1.45)
	window = glass("Frame", gui, "Window", 22, 0.7)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.52)
	window.Size = UDim2.fromScale(0.92, 0.86)
	window.Visible = false
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.45
	aspect.Parent = window
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(760, 540)
	limit.MinSize = Vector2.new(300, 220)
	limit.Parent = window
	scale = Instance.new("UIScale")
	scale.Parent = window

	-- Header (top 18%): avatar chip | title + subtitle | coins | close
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromScale(0.03, 0.03)
	header.Size = UDim2.fromScale(0.94, 0.16)
	header.Parent = window

	local avatar = chip(header, "T", Color3.fromRGB(150, 140, 230), 60, UDim2.fromScale(0, 0))
	avatar.Size = UDim2.fromScale(1, 1)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.DominantAxis = Enum.DominantAxis.Height
	ar.Parent = avatar
	avatarText = avatar:FindFirstChildOfClass("TextLabel")

	titleLabel = capText(label(header, {
		Name = "Title",
		Font = Enum.Font.FredokaOne,
		Position = UDim2.fromScale(0.15, 0),
		Size = UDim2.fromScale(0.55, 0.58),
		TextXAlignment = Enum.TextXAlignment.Left,
	}), 32)
	subtitleLabel = capText(label(header, {
		Name = "Subtitle",
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		Position = UDim2.fromScale(0.15, 0.6),
		Size = UDim2.fromScale(0.55, 0.4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(235, 230, 255),
	}), 15)

	local coinBox = glass("Frame", header, "Coins", 12, 0.6)
	coinBox.AnchorPoint = Vector2.new(1, 0.5)
	coinBox.Position = UDim2.fromScale(0.86, 0.5)
	coinBox.Size = UDim2.fromScale(0.16, 0.62)
	coinsLabel = capText(label(coinBox, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.7),
		TextColor3 = Color3.fromRGB(255, 220, 90),
	}), 20)

	local x = glass("TextButton", header, "Close", 12, 0.55) :: TextButton
	x.AnchorPoint = Vector2.new(1, 0.5)
	x.Position = UDim2.fromScale(1, 0.5)
	x.Size = UDim2.fromScale(0.62, 0.62)
	local xr = Instance.new("UIAspectRatioConstraint")
	xr.AspectRatio = 1
	xr.DominantAxis = Enum.DominantAxis.Height
	xr.Parent = x
	capText(label(x, { Text = "X", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6) }), 22)
	x.Activated:Connect(close)

	-- Grid (rest of the window): 3 columns on wide screens, 2 on narrow
	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromScale(0.03, 0.22)
	grid.Size = UDim2.fromScale(0.94, 0.75)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 5
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = window
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid
	local function relayout()
		local w = grid.AbsoluteSize.X - grid.ScrollBarThickness - 4
		local cols = w < 420 and 2 or 3
		local cellW = math.floor((w - (cols - 1) * 10) / cols)
		layout.CellSize = UDim2.fromOffset(cellW, math.floor(cellW * 0.95))
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()
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
