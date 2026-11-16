-- Bottom-left: the two inventories (glass, rounded). Both are lost on death.
-- Your right hand is free (clouds hang on a leash from your left hand), so
-- items can be used any time.
--
-- PlayerGui
-- └── InventoryUI (ScreenGui)
--     ├── PerksPanel (Frame)                 QUIRKS / PERKS · risky!
--     │   ├── Title
--     │   └── Card1..N (Frame)               cloud emoji, perk name, desc, [Return] button
--     └── ItemsPanel (Frame)                 INVENTORY · shop items
--         ├── Title
--         └── Slot1..N (TextButton)          icon, name, count, key 1-4
--
-- Reads attributes from InventoryService: Items "Nitro:2,Flare:1",
-- Perks "Cosmic:0,Snow:1", SpeedUntil, JumpUntil, NitroUntil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local ShopItems = require(ReplicatedStorage.Shared.ShopItems)
local Weather = require(ReplicatedStorage.Shared.WeatherTypes)

local InventoryUi = {}

local player = Players.LocalPlayer
local remotes
local itemSlots = {}
local perkCards = {}

local CLOUD_ICON = {
	Cumulus = "☁️", Rain = "🌧️", Snow = "❄️", Thunder = "⛈️", Tornado = "🌪️",
	Cosmic = "🌌", Aurora = "🌈", Chrono = "⏳", Mythic = "🌀",
}
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

local function glass(class: string, parent: Instance, name: string, radius: number): GuiObject
	local f = Instance.new(class) :: GuiObject
	f.Name = name
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = 0.8
	f.BorderSizePixel = 0
	if f:IsA("TextButton") then
		f.Text = ""
	end
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.5
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 230))
	g.Parent = f
	return f
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.5
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

local function parseList(attr: string): { { string } }
	local out = {}
	for entry in string.gmatch(player:GetAttribute(attr) or "", "[^,]+") do
		local a, b = string.match(entry, "([^:]+):(%d+)")
		if a then
			table.insert(out, { a, tonumber(b) })
		end
	end
	return out
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryUI"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Items --------------------------------------------------------------
	local items = Instance.new("Frame")
	items.Name = "ItemsPanel"
	items.AnchorPoint = Vector2.new(0, 1)
	items.Position = UDim2.new(0, 16, 1, -16)
	items.Size = UDim2.fromOffset(Config.ItemSlots * 78, 92)
	items.BackgroundTransparency = 1
	items.Parent = gui
	label(items, {
		Name = "Title",
		Text = "🎒 INVENTORY · shop items",
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(225, 232, 255),
	})
	for i = 1, Config.ItemSlots do
		local b = glass("TextButton", items, "Slot" .. i, 14) :: TextButton
		b.Size = UDim2.fromOffset(70, 70)
		b.Position = UDim2.fromOffset((i - 1) * 78, 20)
		local icon = label(b, { Name = "Icon", Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.fromScale(0, 0.08), TextStrokeTransparency = 1 })
		local name = label(b, { Name = "ItemName", Size = UDim2.new(1, -6, 0.22, 0), Position = UDim2.new(0, 3, 0.7, 0) })
		local key = label(b, {
			Name = "Key",
			Text = tostring(i),
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromOffset(3, 3),
			BackgroundTransparency = 0.15,
			BackgroundColor3 = Color3.fromRGB(30, 35, 55),
		})
		Instance.new("UICorner", key).CornerRadius = UDim.new(0, 6)
		local count = label(b, {
			Name = "Count",
			Size = UDim2.fromOffset(24, 20),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -3, 0, 3),
			TextColor3 = Color3.fromRGB(255, 220, 90),
		})
		b.Activated:Connect(function()
			local id = b:GetAttribute("ItemId")
			if id then
				remotes.UseItem:FireServer(id)
			end
		end)
		itemSlots[i] = { Button = b, Icon = icon, Name = name, Count = count }
	end

	-- Quirks / Perks -----------------------------------------------------
	local perks = glass("Frame", gui, "PerksPanel", 16)
	perks.AnchorPoint = Vector2.new(0, 1)
	perks.Position = UDim2.new(0, 16, 1, -118)
	perks.Size = UDim2.fromOffset(300, 30 + Config.PerkSlots * 58)
	label(perks, {
		Name = "Title",
		Text = "✨ QUIRKS / PERKS · lost forever if you die!",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 200, 230),
	})
	for i = 1, Config.PerkSlots do
		local card = glass("Frame", perks, "Card" .. i, 12)
		card.Position = UDim2.fromOffset(8, 26 + (i - 1) * 58)
		card.Size = UDim2.new(1, -16, 0, 52)
		local icon = label(card, { Name = "Icon", Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(6, 6), TextStrokeTransparency = 1 })
		local name = label(card, {
			Name = "PerkName",
			Size = UDim2.new(1, -130, 0, 22),
			Position = UDim2.fromOffset(52, 5),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local desc = label(card, {
			Name = "Desc",
			Font = Enum.Font.GothamMedium,
			Size = UDim2.new(1, -130, 0, 16),
			Position = UDim2.fromOffset(52, 29),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(225, 230, 245),
		})
		local back = glass("TextButton", card, "Return", 8) :: TextButton
		back.AnchorPoint = Vector2.new(1, 0.5)
		back.Position = UDim2.new(1, -6, 0.5, 0)
		back.Size = UDim2.fromOffset(68, 30)
		label(back, { Text = "↩ Vault", Size = UDim2.fromScale(1, 1) })
		back.Activated:Connect(function()
			remotes.PerkAction:FireServer("Return", i)
		end)
		perkCards[i] = { Card = card, Icon = icon, Name = name, Desc = desc, Return = back }
	end
end

local function renderItems()
	local list = parseList("Items")
	for i, s in itemSlots do
		local entry = list[i]
		local def = entry and ShopItems.Types[entry[1]]
		if def then
			s.Button:SetAttribute("ItemId", entry[1])
			s.Icon.Text = def.Icon
			s.Name.Text = def.DisplayName
			s.Count.Text = `×{entry[2]}`
			s.Button.BackgroundTransparency = 0.72
		else
			s.Button:SetAttribute("ItemId", nil)
			s.Icon.Text = ""
			s.Name.Text = ""
			s.Count.Text = ""
			s.Button.BackgroundTransparency = 0.88
		end
	end
end

local function renderPerks()
	local list = parseList("Perks")
	for i, c in perkCards do
		local entry = list[i]
		local def = entry and Weather.Types[entry[1]]
		if def and def.Perk then
			local rarity = Weather.RarityOf(entry[1])
			c.Icon.Text = CLOUD_ICON[entry[1]] or "☁️"
			c.Name.Text = `{entry[2] == 1 and "✨ " or ""}{def.Perk.Name}`
			c.Name.TextColor3 = rarity.Color
			c.Desc.Text = `{def.DisplayName} · {def.Perk.Desc}`
			c.Return.Visible = true
		else
			c.Icon.Text = "＋"
			c.Name.Text = "Empty perk slot"
			c.Name.TextColor3 = Color3.fromRGB(200, 205, 220)
			c.Desc.Text = "Hold F on a cloud in YOUR vault"
			c.Return.Visible = false
		end
	end
end

function InventoryUi.Start()
	remotes = ReplicatedStorage:WaitForChild("Remotes")
	build()
	renderItems()
	renderPerks()
	player:GetAttributeChangedSignal("Items"):Connect(renderItems)
	player:GetAttributeChangedSignal("Perks"):Connect(renderPerks)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for i, key in KEYS do
			if input.KeyCode == key and itemSlots[i] then
				local id = itemSlots[i].Button:GetAttribute("ItemId")
				if id then
					remotes.UseItem:FireServer(id)
				end
			end
		end
	end)

	-- Show remaining time on active items
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local timers = {
			SpeedPotion = player:GetAttribute("SpeedUntil") or 0,
			JumpPotion = player:GetAttribute("JumpUntil") or 0,
			Nitro = player:GetAttribute("NitroUntil") or 0,
		}
		for _, s in itemSlots do
			local id = s.Button:GetAttribute("ItemId")
			local untilT = id and timers[id]
			if untilT and now < untilT then
				s.Name.Text = `ON {math.ceil(untilT - now)}s`
				s.Name.TextColor3 = Color3.fromRGB(150, 255, 180)
			elseif id then
				s.Name.Text = ShopItems.Types[id].DisplayName
				s.Name.TextColor3 = Color3.new(1, 1, 1)
			end
		end
	end)
end

return InventoryUi
