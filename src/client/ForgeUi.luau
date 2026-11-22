-- v2.35 POSEIDON'S FORGE window (glass, like the shop). Opened by the server
-- (OpenShop "Forge") when you press E on Poseidon. One card per biome:
-- the totem, its 3 materials with have / need, how many totems you own and a
-- FORGE button. Data: player attributes "Materials" / "Totems" (JSON).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ForgeDefs = require(ReplicatedStorage.Shared.ForgeDefs)

local ForgeUi = {}

local player = Players.LocalPlayer
local window, list, remotes

local function json(attr: string): { [string]: number }
	local raw = player:GetAttribute(attr)
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, t = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return ok and type(t) == "table" and t or {}
end

local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function glass(f: GuiObject, transparency: number)
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = transparency
	local st = Instance.new("UIStroke")
	st.Color = Color3.new(1, 1, 1)
	st.Transparency = 0.45
	st.Thickness = 1.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = f
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 210, 235))
	g.Parent = f
end

local function text(parent: Instance, props): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.55
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

local function render()
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local mats, totems = json("Materials"), json("Totems")
	for i, biome in ForgeDefs.Biomes do
		local t = ForgeDefs.Totems[biome]
		local card = Instance.new("Frame")
		card.LayoutOrder = i
		card.Size = UDim2.new(1, -8, 0, 92)
		glass(card, 0.72)
		corner(card, 14)
		card.Parent = list
		-- totem chip
		local chip = Instance.new("Frame")
		chip.Position = UDim2.fromOffset(10, 10)
		chip.Size = UDim2.fromOffset(72, 72)
		chip.BackgroundColor3 = t.Color
		corner(chip, 36)
		chip.Parent = card
		text(chip, { Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), Font = Enum.Font.GothamBlack, Text = string.upper(string.sub(biome, 1, 2)) })
		text(card, { Position = UDim2.fromOffset(92, 6), Size = UDim2.new(0.42, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Text = t.Name })
		text(card, {
			Position = UDim2.fromOffset(92, 32), Size = UDim2.new(0.42, 0, 0, 16), Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = t.Color:Lerp(Color3.new(1, 1, 1), 0.3),
			Text = `Opens the {t.Realm}  ·  you own {totems[biome] or 0}`,
		})
		-- recipe: 3 materials with have / need
		local can = true
		for k, m in ForgeDefs.ByBiome[biome] do
			local have = mats[m[1]] or 0
			local ok = have >= m[5]
			can = can and ok
			local box = Instance.new("Frame")
			box.Position = UDim2.new(0, 92 + (k - 1) * 120, 0, 54)
			box.Size = UDim2.fromOffset(114, 30)
			box.BackgroundColor3 = m[3]
			box.BackgroundTransparency = 0.35
			corner(box, 8)
			box.Parent = card
			text(box, {
				Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), Font = Enum.Font.GothamBold,
				Text = `{m[2]}  {have}/{m[5]}`, TextColor3 = ok and Color3.fromRGB(200, 255, 200) or Color3.fromRGB(255, 200, 200),
			})
		end
		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -12, 0.5, 0)
		btn.Size = UDim2.fromOffset(110, 46)
		btn.BackgroundColor3 = can and Color3.fromRGB(255, 160, 60) or Color3.fromRGB(140, 140, 155)
		btn.Font = Enum.Font.GothamBlack
		btn.TextScaled = true
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Text = can and "FORGE" or "NEED MORE"
		btn.AutoButtonColor = can
		corner(btn, 12)
		btn.Parent = card
		if can then
			btn.Activated:Connect(function()
				remotes.Forge:FireServer(biome)
			end)
		end
	end
end

local function open()
	window.Visible = true
	render()
end

function ForgeUi.Start()
	remotes = ReplicatedStorage:WaitForChild("Remotes")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ForgeUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11
	gui.Parent = player:WaitForChild("PlayerGui")

	window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.52)
	window.Size = UDim2.fromScale(0.92, 0.86)
	window.Visible = false
	glass(window, 0.7)
	corner(window, 22)
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(760, 600)
	lim.Parent = window
	window.Parent = gui
	text(window, { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -110, 0, 36), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Text = "Poseidon's Forge" })
	text(window, {
		Position = UDim2.fromOffset(20, 48), Size = UDim2.new(1, -40, 0, 18), Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(225, 240, 255),
		Text = "Monsters drop materials. Forge a totem, then offer it at the altar behind that biome's boss.",
	})
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 12)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	close.Font = Enum.Font.GothamBlack
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	corner(close, 20)
	close.Parent = window
	close.Activated:Connect(function()
		window.Visible = false
	end)
	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(14, 76)
	list.Size = UDim2.new(1, -28, 1, -90)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	remotes:WaitForChild("OpenShop").OnClientEvent:Connect(function(shop)
		if shop == "Forge" then
			open()
		end
	end)
	for _, attr in { "Materials", "Totems" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if window.Visible then
				render()
			end
		end)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			window.Visible = false
		end
	end)
	-- walking away from Poseidon closes it
	task.spawn(function()
		while true do
			task.wait(0.5)
			if window.Visible then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local near = false
				for _, npc in game:GetService("CollectionService"):GetTagged("Npc") do
					local r = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
					if npc.Name == "Poseidon" and root and r and (r.Position - root.Position).Magnitude < 20 then
						near = true
					end
				end
				if not near then
					window.Visible = false
				end
			end
		end
	end)
end

return ForgeUi
