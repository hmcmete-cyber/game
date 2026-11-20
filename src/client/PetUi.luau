-- v2.12 Pet panel: opened from the Pet Hut prompt ("Pets"). Lists every pet
-- you own (name, rarity colour, buff, attack, look) with Equip / Unequip.
-- Equipped pets follow you and fight; the rest idle at your Pet Hut.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetDefs = require(ReplicatedStorage.Shared.PetDefs)

local PetUi = {}

local player = Players.LocalPlayer
local gui, listFrame, header
local roster, limit = {}, 3

local function render()
	if not listFrame then
		return
	end
	for _, c in listFrame:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local equippedCount = 0
	for _, p in roster do
		if p.Equipped then
			equippedCount += 1
		end
	end
	header.Text = `Pets ({#roster})   Equipped {equippedCount}/{limit}`
	table.sort(roster, function(a, b)
		if a.Equipped ~= b.Equipped then
			return a.Equipped
		end
		return (table.find(PetDefs.Rarities, a.Rarity) or 0) > (table.find(PetDefs.Rarities, b.Rarity) or 0)
	end)
	for i, p in roster do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -8, 0, 64)
		row.BackgroundColor3 = Color3.fromRGB(35, 38, 52)
		row.BorderSizePixel = 0
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 6, 1, 0)
		stripe.BackgroundColor3 = PetDefs.RARITY[p.Rarity] and PetDefs.RARITY[p.Rarity].Color or Color3.new(1, 1, 1)
		stripe.BorderSizePixel = 0
		stripe.Parent = row
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(14, 4)
		name.Size = UDim2.new(1, -120, 0, 22)
		name.Font = Enum.Font.GothamBold
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextScaled = true
		name.TextColor3 = stripe.BackgroundColor3
		local lv = p.Level or 1
		local xpText = lv < 3 and (" (" .. tostring(p.XP or 0) .. "/" .. tostring(p.NextXP or "?") .. " XP)") or " MAX"
		name.Text = `{p.Name}  ·  {p.Rarity}  ·  Lv {lv}{xpText}`
		name.Parent = row
		local info = Instance.new("TextLabel")
		info.BackgroundTransparency = 1
		info.Position = UDim2.fromOffset(14, 28)
		info.Size = UDim2.new(1, -120, 0, 32)
		info.Font = Enum.Font.Gotham
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextYAlignment = Enum.TextYAlignment.Top
		info.TextWrapped = true
		info.TextSize = 13
		info.TextColor3 = Color3.fromRGB(220, 225, 240)
		info.Text = `Buff: {p.Buff}\nAttack: {p.Attack}`
		info.Parent = row
		local btn = Instance.new("TextButton")
		btn.Position = UDim2.new(1, -100, 0.5, -16)
		btn.Size = UDim2.fromOffset(90, 32)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 15
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.BackgroundColor3 = p.Equipped and Color3.fromRGB(200, 80, 80) or Color3.fromRGB(80, 180, 100)
		btn.Text = p.Equipped and "Unequip" or "Equip"
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
		btn.Parent = row
		btn.Activated:Connect(function()
			ReplicatedStorage.Remotes.PetAction:FireServer(p.Equipped and "Unequip" or "Equip", p.Uid)
		end)
		row.Parent = listFrame
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "PetPanel"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(0.5, 0, 0.7, 0)
	frame.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
	frame.BorderSizePixel = 0
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
	local limitC = Instance.new("UISizeConstraint")
	limitC.MinSize = Vector2.new(320, 300)
	limitC.MaxSize = Vector2.new(620, 700)
	limitC.Parent = frame
	frame.Parent = gui
	header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(16, 8)
	header.Size = UDim2.new(1, -70, 0, 34)
	header.Font = Enum.Font.GothamBlack
	header.TextScaled = true
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Color3.fromRGB(255, 230, 150)
	header.Text = "Pets"
	header.Parent = frame
	local close = Instance.new("TextButton")
	close.Position = UDim2.new(1, -46, 0, 8)
	close.Size = UDim2.fromOffset(36, 36)
	close.Text = "X"
	close.Font = Enum.Font.GothamBlack
	close.TextSize = 20
	close.TextColor3 = Color3.new(1, 1, 1)
	close.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
	close.Parent = frame
	close.Activated:Connect(function()
		gui.Enabled = false
	end)
	listFrame = Instance.new("ScrollingFrame")
	listFrame.Position = UDim2.fromOffset(8, 50)
	listFrame.Size = UDim2.new(1, -16, 1, -58)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 6
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listFrame
	listFrame.Parent = frame
	gui.Parent = player:WaitForChild("PlayerGui")
end

function PetUi.Start()
	build()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("PetData").OnClientEvent:Connect(function(list, lim)
		roster, limit = list or {}, lim or 3
		render()
	end)
	remotes:WaitForChild("OpenPets").OnClientEvent:Connect(function()
		gui.Enabled = true
		render()
	end)
end

return PetUi
