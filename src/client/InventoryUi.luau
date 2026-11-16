-- Bottom-left: Item & Power slots (glass, rounded). Your RIGHT hand is free
-- because carried clouds hang on a leash from your LEFT hand — so you can
-- use these any time, even while carrying.
--
-- PlayerGui
-- └── InventoryUI (ScreenGui)
--     ├── Title (TextLabel)        "ITEMS · lost on death"
--     └── Hotbar (Frame)
--         ├── Slot1 (TextButton)   cloud charm      [Q]
--         ├── Slot2 (TextButton)   Nitro ×charges   [R]
--         └── Slot3 (TextButton)   ignite / fuel    [T]  (coming soon)
--             each: Icon, ItemName, Key badge, Count badge, Cooldown fill
--
-- Reads player attributes from the server InventoryService:
--   Charm, NitroCharges, SkatesUntil, SkatesReadyAt, NitroUntil

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Charms = require(ReplicatedStorage.Shared.Charms)

local InventoryUi = {}

local player = Players.LocalPlayer
local useItem: RemoteEvent
local slots = {}

local KEYS = { Enum.KeyCode.Q, Enum.KeyCode.R, Enum.KeyCode.T }
local KEY_TEXT = { "Q", "R", "T" }

local function glassButton(parent: Instance, name: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = true
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	b.BackgroundTransparency = 0.78
	b.Size = UDim2.fromOffset(76, 76)
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 230))
	gradient.Parent = b
	return b
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

local function badge(parent: Instance, name: string, pos: UDim2, anchor: Vector2)
	local b = label(parent, {
		Name = name,
		Size = UDim2.fromOffset(22, 22),
		Position = pos,
		AnchorPoint = anchor,
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Color3.fromRGB(30, 35, 55),
		ZIndex = 4,
	})
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = b
	return b
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryUI"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	label(gui, {
		Name = "Title",
		Text = "ITEMS · lost on death",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -100),
		Size = UDim2.fromOffset(240, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(220, 230, 255),
	})

	local bar = Instance.new("Frame")
	bar.Name = "Hotbar"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 16, 1, -16)
	bar.Size = UDim2.fromOffset(3 * 86, 80)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.Parent = bar

	for i = 1, 3 do
		local b = glassButton(bar, "Slot" .. i)
		local fill = Instance.new("Frame")
		fill.Name = "Cooldown"
		fill.AnchorPoint = Vector2.new(0, 1)
		fill.Position = UDim2.fromScale(0, 1)
		fill.Size = UDim2.fromScale(1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
		fill.BackgroundTransparency = 0.35
		fill.BorderSizePixel = 0
		fill.ZIndex = 3
		fill.Parent = b
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0, 16)
		fc.Parent = fill

		local icon = label(b, { Name = "Icon", Size = UDim2.new(1, 0, 0.58, 0), Position = UDim2.fromScale(0, 0.06), TextStrokeTransparency = 1, ZIndex = 2 })
		local name = label(b, { Name = "ItemName", Size = UDim2.new(1, -8, 0.24, 0), Position = UDim2.new(0, 4, 0.68, 0), ZIndex = 2 })
		local key = badge(b, "Key", UDim2.fromOffset(4, 4), Vector2.zero)
		key.Text = KEY_TEXT[i]
		local count = badge(b, "Count", UDim2.new(1, -4, 0, 4), Vector2.new(1, 0))
		count.TextColor3 = Color3.fromRGB(255, 220, 90)

		b.Activated:Connect(function()
			useItem:FireServer(i)
		end)
		slots[i] = { Button = b, Icon = icon, Name = name, Key = key, Count = count, Fill = fill }
	end
end

local function setSlot(i: number, icon: string, name: string, enabled: boolean, count: number?)
	local s = slots[i]
	s.Icon.Text = icon
	s.Name.Text = name
	s.Icon.TextTransparency = enabled and 0 or 0.6
	s.Name.TextTransparency = enabled and 0 or 0.4
	s.Count.Visible = count ~= nil
	s.Count.Text = count and tostring(count) or ""
end

function InventoryUi.Start()
	useItem = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem")
	build()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for i, key in KEYS do
			if input.KeyCode == key then
				useItem:FireServer(i)
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()

		-- Slot 1: cloud charm
		local charmId = player:GetAttribute("Charm") or ""
		local charm = Charms.Types[charmId]
		local s1 = slots[1]
		s1.Fill.Size = UDim2.fromScale(1, 0)
		if not charm then
			setSlot(1, "☁️", "Charm", false)
		elseif charmId == "IceCharm" then
			local activeUntil = player:GetAttribute("SkatesUntil") or 0
			local readyAt = player:GetAttribute("SkatesReadyAt") or 0
			if now < activeUntil then
				setSlot(1, charm.Icon, `⛸️ {math.ceil(activeUntil - now)}s`, true)
			elseif now < readyAt then
				setSlot(1, charm.Icon, `{math.ceil(readyAt - now)}s`, true)
				s1.Fill.Size = UDim2.fromScale(1, (readyAt - now) / Config.SkatesCooldown)
			else
				setSlot(1, charm.Icon, charm.DisplayName, true)
			end
		else
			setSlot(1, charm.Icon, `{charm.DisplayName} ∞`, true)
		end

		-- Slot 2: Nitro
		local charges = player:GetAttribute("NitroCharges") or 0
		local nitroUntil = player:GetAttribute("NitroUntil") or 0
		if now < nitroUntil then
			setSlot(2, "🚀", `BOOST {math.ceil(nitroUntil - now)}s`, true, charges)
		else
			setSlot(2, "🚀", charges > 0 and "Nitro" or "Buy Nitro", charges > 0, charges)
		end

		-- Slot 3: reserved for ignite / fuel items
		setSlot(3, "🔥", "Soon", false)
	end)
end

return InventoryUi
