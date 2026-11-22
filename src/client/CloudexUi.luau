-- v2.34 CLOUDEX (director: a tracker of every cloud you ever collected; a
-- cloud that entered your base once stays in it).
-- Right side button "CLOUDEX n/N" opens a grid of ALL cloud types, sorted by
-- rarity: found ones show their colour chip, name, rarity, perk and how many
-- you delivered (★ = you also got the shiny one); unfound ones are "???".
-- Data: player attribute "Cloudex" (JSON { Type = count, Type_Shiny = count }).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Weather = require(ReplicatedStorage.Shared.WeatherTypes)

local CloudexUi = {}

local player = Players.LocalPlayer
local gui, button, buttonText, window, grid, titleLabel, toast
local known = nil -- set of found types (for "new!" toasts)

local function found(): { [string]: number }
	local raw = player:GetAttribute("Cloudex")
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, t = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return ok and type(t) == "table" and t or {}
end

local function sortedTypes(): { string }
	local list = {}
	for _, key in Weather.Order do
		local def = Weather.Types[key]
		if def and not def.Hidden then
			table.insert(list, key)
		end
	end
	table.sort(list, function(a, b)
		local da, db = Weather.Types[a], Weather.Types[b]
		if da.Tier ~= db.Tier then
			return da.Tier < db.Tier
		end
		return da.DisplayName < db.DisplayName
	end)
	return list
end

local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function text(parent: Instance, props): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

local function render()
	if not grid then
		return
	end
	for _, c in grid:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local have = found()
	local types = sortedTypes()
	local n = 0
	for i, key in types do
		local def = Weather.Types[key]
		local rar = Weather.Rarity[def.Rarity]
		local count = have[key]
		local shiny = (have[key .. "_Shiny"] or 0) > 0
		if count then
			n += 1
		end
		local card = Instance.new("Frame")
		card.Name = key
		card.LayoutOrder = i
		card.BackgroundColor3 = count and Color3.fromRGB(28, 34, 58) or Color3.fromRGB(22, 24, 34)
		card.BackgroundTransparency = 0.15
		corner(card, 12)
		local stroke = Instance.new("UIStroke")
		stroke.Color = count and rar.Color or Color3.fromRGB(70, 72, 90)
		stroke.Thickness = count and 2 or 1
		stroke.Parent = card
		-- colour chip with initials (or ?)
		local chip = Instance.new("Frame")
		chip.AnchorPoint = Vector2.new(0.5, 0)
		chip.Position = UDim2.fromScale(0.5, 0.06)
		chip.Size = UDim2.fromScale(0.5, 0.5)
		chip.BackgroundColor3 = count and def.Color or Color3.fromRGB(45, 47, 60)
		corner(chip, 100)
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.Parent = chip
		local cs = Instance.new("UIStroke")
		cs.Color = count and Color3.new(1, 1, 1) or Color3.fromRGB(90, 92, 110)
		cs.Thickness = 2
		cs.Parent = chip
		chip.Parent = card
		local icon = Weather.Icon[key]
		text(chip, {
			Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), Font = Enum.Font.GothamBlack,
			Text = count and (icon and icon[1] or "?") or "?",
			TextColor3 = count and ((def.Color.R + def.Color.G + def.Color.B) > 1.8 and Color3.fromRGB(40, 40, 60) or Color3.new(1, 1, 1)) or Color3.fromRGB(150, 150, 170),
		})
		if shiny then
			text(card, { Size = UDim2.fromScale(0.28, 0.22), Position = UDim2.fromScale(0.7, 0.02), Text = "★", TextColor3 = Weather.ShinyColor })
		end
		text(card, {
			Size = UDim2.fromScale(0.92, 0.16), Position = UDim2.fromScale(0.04, 0.58),
			Text = count and def.DisplayName or "???", TextColor3 = count and Color3.new(1, 1, 1) or Color3.fromRGB(140, 140, 160),
		})
		text(card, {
			Size = UDim2.fromScale(0.92, 0.11), Position = UDim2.fromScale(0.04, 0.75), Font = Enum.Font.GothamMedium,
			Text = def.Rarity .. (count and `  x{count}` or ""), TextColor3 = rar.Color,
		})
		if count and def.Perk and def.Perk.Name then
			text(card, {
				Size = UDim2.fromScale(0.92, 0.1), Position = UDim2.fromScale(0.04, 0.87), Font = Enum.Font.GothamMedium,
				Text = def.Perk.Name, TextColor3 = Color3.fromRGB(180, 220, 255),
			})
		end
		card.Parent = grid
	end
	titleLabel.Text = `CLOUDEX   {n} / {#types}`
	buttonText.Text = `CLOUDEX\n{n}/{#types}`
end

local function showToast(name: string)
	toast.Text = `NEW in Cloudex: {name}!`
	toast.Visible = true
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.2
	task.delay(3, function()
		TweenService:Create(toast, TweenInfo.new(0.6), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	end)
end

local function onChanged()
	local have = found()
	if known then
		for key in have do
			if not known[key] and not string.find(key, "_Shiny$") and Weather.Types[key] then
				showToast(Weather.Types[key].DisplayName)
			end
		end
	end
	known = {}
	for key in have do
		known[key] = true
	end
	render()
end

local function toggle(open: boolean?)
	if open == nil then
		open = not window.Visible
	end
	window.Visible = open
	if open then
		render()
	end
end

function CloudexUi.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "CloudexUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")

	-- right-side button
	button = Instance.new("TextButton")
	button.Name = "CloudexButton"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -16, 0.5, 150)
	button.Size = UDim2.fromOffset(112, 54)
	button.BackgroundColor3 = Color3.fromRGB(90, 140, 255)
	button.Text = ""
	button.AutoButtonColor = true
	corner(button, 14)
	local bs = Instance.new("UIStroke")
	bs.Color = Color3.new(1, 1, 1)
	bs.Thickness = 2
	bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bs.Parent = button
	buttonText = text(button, { Size = UDim2.new(1, -10, 1, -8), Position = UDim2.fromOffset(5, 4), Font = Enum.Font.GothamBlack, Text = "CLOUDEX" })
	button.Parent = gui
	button.Activated:Connect(function()
		toggle()
	end)

	-- window
	window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.9, 0.84)
	window.BackgroundColor3 = Color3.fromRGB(14, 18, 34)
	window.BackgroundTransparency = 0.08
	window.Visible = false
	corner(window, 20)
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(860, 600)
	lim.Parent = window
	window.Parent = gui
	titleLabel = text(window, { Size = UDim2.new(1, -120, 0, 40), Position = UDim2.fromOffset(20, 12), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Text = "CLOUDEX" })
	text(window, {
		Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(20, 52), Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 200, 230),
		Text = "Every cloud you bring home once stays here forever.  ★ = shiny found",
	})
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 14)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	close.Font = Enum.Font.GothamBlack
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	corner(close, 100)
	close.Parent = window
	close.Activated:Connect(function()
		toggle(false)
	end)
	grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(16, 80)
	grid.Size = UDim2.new(1, -32, 1, -96)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = window
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(118, 132)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid

	-- "new cloud" toast
	toast = text(gui, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(420, 40),
		BackgroundColor3 = Color3.fromRGB(90, 140, 255), BackgroundTransparency = 1, TextTransparency = 1, Visible = false,
		Font = Enum.Font.GothamBlack,
	})
	corner(toast, 12)

	player:GetAttributeChangedSignal("Cloudex"):Connect(onChanged)
	onChanged()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and window.Visible then
			toggle(false)
		end
	end)
end

return CloudexUi
