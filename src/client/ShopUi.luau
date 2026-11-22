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
local VendorCatalog = require(ReplicatedStorage.Shared.VendorCatalog)
local ItemIcons = require(ReplicatedStorage.Shared.ItemIcons)
local PetDefs = require(ReplicatedStorage.Shared.PetDefs)
local logos = {} -- turning 3D logo models (cleared with the cards)
-- v2.13: locked catalogue entries (unlocked by offering a cloud at the vendor's Orb)
local function isUnlocked(id: string): boolean
	local s = Players.LocalPlayer:GetAttribute("Unlocks") or ""
	return string.find(s, "," .. id .. ",", 1, true) ~= nil
end
local function lockText(cloudId: string, vendor: string): string
	return `Locked - offer a {VendorCatalog.CloudNames[cloudId] or cloudId} at {vendor}'s Orb`
end

local ShopUi = {}

local player = Players.LocalPlayer
local remotes
local window, scale, grid, titleLabel, subtitleLabel, coinsLabel, avatarText
local currentShop = "Items"
-- v2.21: "Sell Pets" page (same window, both vendors buy pets)
local vendorShop = "Items" -- the vendor's own page, to go back to
local petList, petLimit = {}, PetDefs.StorageLimit
local sellToggle: TextButton?, sellToggleText: TextLabel?
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
	logos = {}
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
	-- v2.18: a turning 3D logo instead of the letters
	local def = ShopItems.Types[id] or Upgrades.Types[id]
	if not def then
		-- pet card: keep the coloured chip with its short text
		capText(label(c, { Name = "ItemName", Text = name, Position = UDim2.fromScale(0.3, 0), Size = UDim2.fromScale(0.7, levelText and 0.17 or 0.3), TextXAlignment = Enum.TextXAlignment.Left }), 20)
		if levelText then
			capText(label(c, { Name = "Level", Text = levelText, Font = Enum.Font.GothamMedium, Position = UDim2.fromScale(0.3, 0.18), Size = UDim2.fromScale(0.7, 0.12), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 225, 140) }), 14)
		end
		capText(label(c, { Name = "Desc", Text = desc, Font = Enum.Font.GothamMedium, TextWrapped = true, Position = UDim2.fromScale(0, 0.34), Size = UDim2.fromScale(1, 0.38), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(235, 235, 250) }), 15)
		table.insert(cards, c)
		return c
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Logo"
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(200, 200, 210)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-1, -1.5, -1)
	vp.ZIndex = (icon.ZIndex or 1) + 1
	local model = ItemIcons.Build(ItemIcons.KindFor(id, def), iconColor)
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.6, -8.5), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Parent = icon
	for _, d in icon:GetChildren() do
		if d:IsA("TextLabel") then
			d.Visible = false
		end
	end
	if icon:IsA("TextLabel") or icon:IsA("TextButton") then
		(icon :: any).Text = ""
	end
	table.insert(logos, model)

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
	if sellToggleText then
		sellToggleText.Text = currentShop == "SellPets" and "Back" or "Sell Pets"
	end
	if currentShop == "SellPets" then
		local who = vendorShop == "Items" and "Zeus" or "Aurelius"
		titleLabel.Text = `Sell Pets to {who}`
		subtitleLabel.Text = `Pet storage {#petList} / {petLimit}. Higher level + rarer = more coins.`
		avatarText.Text = "$"
		local order = table.clone(petList)
		table.sort(order, function(a, b)
			return (a.Price or 0) > (b.Price or 0)
		end)
		for i, p in order do
			local rc = PetDefs.RARITY[p.Rarity] and PetDefs.RARITY[p.Rarity].Color or Color3.fromRGB(200, 200, 210)
			local c = card(i, "Pet" .. p.Uid, "Lv" .. (p.Level or 1), rc, p.Name,
				`{p.Rarity}\n{p.Buff or ""}{p.Equipped and "\n(following you)" or ""}`, `Level {p.Level or 1} / {PetDefs.MaxLevel}`)
			buyButton(c, `Sell - {p.Price or 0} coins`, true, Color3.fromRGB(255, 150, 90), function()
				remotes.PetAction:FireServer("Sell", p.Uid)
			end)
		end
		if #order == 0 then
			local c = card(1, "PetNone", "-", Color3.fromRGB(150, 150, 170), "No pets", "Hatch boss eggs in your Egg Nursery to get pets.")
			c.Name = "CardEmpty"
		end
	elseif currentShop == "Items" then
		titleLabel.Text = "Zeus's Gear Shop"
		subtitleLabel.Text = "Gear is yours forever: hold it (keys 1-9) and click to use."
		avatarText.Text = "T"
		for i, id in ShopItems.Order do
			local item = ShopItems.Types[id]
			local locked = item.Cloud ~= nil and not isUnlocked(id)
			local owned = string.find(player:GetAttribute("Gear") or "", "," .. id .. ",", 1, true) ~= nil
			-- v2.31 gear: owned forever; simple = cooldown, OP = 3 charges
			local gearText = item.Op and `GEAR - {item.MaxCharges} charge(s), +1 every {item.Recharge}s` or `GEAR - reuse every {item.Cooldown}s`
			local desc = item.Desc .. "\n" .. gearText
			local c = card(i, id, item.IconText, item.IconColor, item.DisplayName, locked and (desc .. "\n" .. lockText(item.Cloud, "Zeus")) or desc)
			buyButton(c, locked and "Locked" or (owned and "OWNED" or (item.ComingSoon and "Coming soon" or `Buy - {item.Price} coins`)), not item.ComingSoon and not locked and not owned,
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
			local locked = def.Cloud ~= nil and not isUnlocked(id)
			local c = card(i, id, def.IconText, def.IconColor, def.DisplayName, locked and (def.Desc .. "\n" .. lockText(def.Cloud, "Aurelius")) or def.Desc,
				def.Boon and (maxed and "Owned" or "Not owned") or `Level {level} / {def.MaxLevel}`)
			buyButton(c, locked and "Locked" or (maxed and (def.Boon and "OWNED" or "MAX") or `Upgrade - {Upgrades.Cost(id, level)} coins`), not maxed and not locked,
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
	vendorShop = currentShop
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
		Size = UDim2.fromScale(0.4, 0.58),
		TextXAlignment = Enum.TextXAlignment.Left,
	}), 32)
	subtitleLabel = capText(label(header, {
		Name = "Subtitle",
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		Position = UDim2.fromScale(0.15, 0.6),
		Size = UDim2.fromScale(0.4, 0.4),
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

	-- v2.21: Sell Pets <-> vendor page toggle
	local st = glass("TextButton", header, "SellPets", 12, 0.25) :: TextButton
	st.BackgroundColor3 = Color3.fromRGB(255, 150, 90)
	st.AnchorPoint = Vector2.new(1, 0.5)
	st.Position = UDim2.fromScale(0.685, 0.5)
	st.Size = UDim2.fromScale(0.14, 0.62)
	sellToggle = st
	sellToggleText = capText(label(st, { Text = "Sell Pets", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.6) }), 18)
	st.Activated:Connect(function()
		currentShop = currentShop == "SellPets" and vendorShop or "SellPets"
		render()
	end)

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
	-- turn the shop logos slowly while the shop is open
	game:GetService("RunService").RenderStepped:Connect(function()
		if window and window.Visible then
			local t = os.clock()
			for i, m in logos do
				if m.Parent then
					m:PivotTo(CFrame.Angles(0, t * 0.8 + i, 0))
				end
			end
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("Gear"):Connect(function()
		if window and window.Visible then
			render()
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("Unlocks"):Connect(function()
		if window and window.Visible then
			render()
		end
	end)
	remotes = ReplicatedStorage:WaitForChild("Remotes")
	build()
	remotes:WaitForChild("OpenShop").OnClientEvent:Connect(open)
	-- pet list for the Sell Pets page (same data as the pet panel)
	task.spawn(function()
		remotes:WaitForChild("PetData").OnClientEvent:Connect(function(list, _, storage)
			petList = list or {}
			petLimit = storage or petLimit
			if window.Visible and currentShop == "SellPets" then
				render()
			end
		end)
	end)

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
