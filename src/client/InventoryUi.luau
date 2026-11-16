-- Inventory hotbar (charms only) + Q key for the Ice Charm.
--
-- PlayerGui
-- └── InventoryUI (ScreenGui)
--     └── Hotbar (Frame, bottom-left)
--         └── Slot1..N (TextButton, glass)  icon, name, key badge, cooldown fill
--
-- Reads player attributes set by the server InventoryService:
--   Inventory "IceCharm,StormCharm", SkatesUntil, SkatesReadyAt

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Charms = require(ReplicatedStorage.Shared.Charms)

local InventoryUi = {}

local player = Players.LocalPlayer
local useCharm: RemoteEvent
local slots = {} -- { { Button, Icon, Name, Key, Fill } }

local function items(): { string }
	local raw = player:GetAttribute("Inventory") or ""
	local list = {}
	for id in string.gmatch(raw, "[^,]+") do
		table.insert(list, id)
	end
	return list
end

local function glassButton(parent: Instance, name: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = true
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	b.BackgroundTransparency = 0.78
	b.Size = UDim2.fromOffset(72, 72)
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
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

local function tryUse(id: string?)
	if id == "IceCharm" then
		useCharm:FireServer("IceCharm")
	end
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryUI"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local bar = Instance.new("Frame")
	bar.Name = "Hotbar"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 16, 1, -16)
	bar.Size = UDim2.fromOffset(Config.InventorySize * 80, 96)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 8)
	layout.Parent = bar

	label(bar, {
		Name = "Title",
		Text = "INVENTORY · lost on death",
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, -2),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(220, 230, 255),
	}).Parent = gui
	-- put the title just above the bar
	local title = gui:FindFirstChild("Title") :: TextLabel
	title.AnchorPoint = Vector2.new(0, 1)
	title.Position = UDim2.new(0, 18, 1, -92)
	title.Size = UDim2.fromOffset(240, 16)

	for i = 1, Config.InventorySize do
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
		fc.CornerRadius = UDim.new(0, 14)
		fc.Parent = fill

		local icon = label(b, { Name = "Icon", Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.fromScale(0, 0.05), TextStrokeTransparency = 1, ZIndex = 2 })
		local name = label(b, { Name = "ItemName", Size = UDim2.new(1, -6, 0.25, 0), Position = UDim2.new(0, 3, 0.68, 0), ZIndex = 2 })
		local key = label(b, {
			Name = "Key",
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 0.2,
			BackgroundColor3 = Color3.fromRGB(30, 35, 55),
			ZIndex = 4,
		})
		local kc = Instance.new("UICorner")
		kc.CornerRadius = UDim.new(0, 6)
		kc.Parent = key

		b.Activated:Connect(function()
			tryUse(items()[i])
		end)
		slots[i] = { Button = b, Icon = icon, Name = name, Key = key, Fill = fill }
	end
end

local function render()
	local list = items()
	for i, s in slots do
		local id = list[i]
		local def = id and Charms.Types[id]
		if def then
			s.Icon.Text = def.Icon
			s.Name.Text = def.DisplayName
			s.Key.Visible = true
			s.Key.Text = def.Key or "∞"
			s.Button.BackgroundTransparency = 0.7
		else
			s.Icon.Text = ""
			s.Name.Text = ""
			s.Key.Visible = false
			s.Fill.Size = UDim2.fromScale(1, 0)
			s.Button.BackgroundTransparency = 0.85
		end
	end
end

function InventoryUi.Start()
	useCharm = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseCharm")
	build()
	render()
	player:GetAttributeChangedSignal("Inventory"):Connect(render)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			tryUse("IceCharm")
		end
	end)

	-- Cooldown / active overlay on Ice Charm slots
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local activeUntil = player:GetAttribute("SkatesUntil") or 0
		local readyAt = player:GetAttribute("SkatesReadyAt") or 0
		local list = items()
		for i, s in slots do
			if list[i] == "IceCharm" then
				if now < activeUntil then
					s.Name.Text = `⛸️ {math.ceil(activeUntil - now)}s`
					s.Fill.Size = UDim2.fromScale(1, 0)
					s.Button.BackgroundColor3 = Color3.fromRGB(150, 220, 255)
				elseif now < readyAt then
					s.Name.Text = `{math.ceil(readyAt - now)}s`
					s.Fill.Size = UDim2.fromScale(1, (readyAt - now) / Config.SkatesCooldown)
					s.Button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				else
					s.Name.Text = "Ice Charm"
					s.Fill.Size = UDim2.fromScale(1, 0)
					s.Button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				end
			end
		end
	end)
end

return InventoryUi
