-- Bottom-left: the two inventories (glass, rounded). Both are lost on death.
-- Your right hand is free (clouds hang on a leash from your left hand), so
-- items and perk abilities can be used any time.
-- Icons are coloured text chips (no emoji: they don't render everywhere).
--
-- PlayerGui
-- └── InventoryUI (ScreenGui)
--     ├── PerksPanel (Frame)            QUIRKS / PERKS - lost forever if you die
--     │   └── Card1..3 (Frame)          chip, perk name, desc, ability key + cooldown, [Vault] button
--     └── ItemsPanel (Frame)            INVENTORY - shop items
--         └── Slot1..4 (TextButton)     chip, name, count, key 1-4
--
-- Keys: 1-4 use items · G / H / J use the ability of perk slot 1 / 2 / 3

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerAnimator = require(script.Parent:WaitForChild("PlayerAnimator"))
local ShopItems = require(ReplicatedStorage.Shared.ShopItems)
local Weather = require(ReplicatedStorage.Shared.WeatherTypes)

local InventoryUi = {}

local player = Players.LocalPlayer
local remotes
local itemSlots = {}
local perkCards = {}
local perksPanel

local MAX_PERK_CARDS = 3
local ITEM_KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
	Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven,
}

-- Where am I aiming? Mouse on PC, screen center (camera) on touch/console.
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()
local function aimPoint(): Vector3
	if UserInputService.MouseEnabled and mouse.Hit then
		return mouse.Hit.Position
	end
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	return ray.Origin + ray.Direction * 150
end

local function useItem(id: string)
	local def = ShopItems.Types[id]
	remotes.UseItem:FireServer(id, def and def.Aim and aimPoint() or nil)
	PlayerAnimator.PlayItem(id)
end
local PERK_KEYS = { Enum.KeyCode.G, Enum.KeyCode.H, Enum.KeyCode.J }
local PERK_KEY_TEXT = { "G", "H", "J" }

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
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, radius)
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

-- coloured round icon with short text
local function chip(parent: Instance, size: number, pos: UDim2)
	local c = Instance.new("Frame")
	c.Name = "Chip"
	c.Size = UDim2.fromOffset(size, size)
	c.Position = pos
	c.BackgroundColor3 = Color3.fromRGB(120, 130, 160)
	c.Parent = parent
	Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = c
	local t = label(c, { Name = "Text", Font = Enum.Font.GothamBlack, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4) })
	return c, t
end

local function keyBadge(parent: Instance, text: string, pos: UDim2, anchor: Vector2?)
	local k = label(parent, {
		Name = "Key",
		Text = text,
		Size = UDim2.fromOffset(20, 20),
		Position = pos,
		AnchorPoint = anchor or Vector2.zero,
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Color3.fromRGB(30, 35, 55),
		ZIndex = 3,
	})
	Instance.new("UICorner", k).CornerRadius = UDim.new(0, 6)
	return k
end

local function parseList(attr: string): { { any } }
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
	items.Size = UDim2.fromOffset(Config.ItemSlots * 66, 84)
	items.BackgroundTransparency = 1
	items.Visible = false -- v2.31: shop items are GEAR now (Roblox hotbar 1-9, hold + click)
	items.Parent = gui
	label(items, {
		Name = "Title",
		Text = "INVENTORY - shop items (keys 1-7, aimed items use your mouse)",
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(225, 232, 255),
	})
	for i = 1, Config.ItemSlots do
		local b = glass("TextButton", items, "Slot" .. i, 14) :: TextButton
		b.Size = UDim2.fromOffset(60, 60)
		b.Position = UDim2.fromOffset((i - 1) * 66, 20)
		local c, ct = chip(b, 30, UDim2.fromOffset(15, 5))
		local name = label(b, { Name = "ItemName", Size = UDim2.new(1, -6, 0.22, 0), Position = UDim2.new(0, 3, 0.7, 0) })
		keyBadge(b, tostring(i), UDim2.fromOffset(3, 3))
		local count = label(b, {
			Name = "Count",
			Size = UDim2.fromOffset(26, 18),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -3, 0, 3),
			TextColor3 = Color3.fromRGB(255, 220, 90),
		})
		b.Activated:Connect(function()
			local id = b:GetAttribute("ItemId")
			if id then
				useItem(id)
			end
		end)
		itemSlots[i] = { Button = b, Chip = c, ChipText = ct, Name = name, Count = count }
	end

	-- Quirks / Perks -----------------------------------------------------
	perksPanel = glass("Frame", gui, "PerksPanel", 16)
	perksPanel.AnchorPoint = Vector2.new(0, 1)
	perksPanel.Position = UDim2.new(0, 16, 1, -110)
	label(perksPanel, {
		Name = "Title",
		Text = "QUIRKS / PERKS - lost forever if you die!",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 200, 230),
	})
	for i = 1, MAX_PERK_CARDS do
		local card = glass("Frame", perksPanel, "Card" .. i, 12)
		card.Position = UDim2.fromOffset(8, 26 + (i - 1) * 58)
		card.Size = UDim2.new(1, -16, 0, 52)
		local c, ct = chip(card, 40, UDim2.fromOffset(6, 6))
		local name = label(card, {
			Name = "PerkName",
			Size = UDim2.new(1, -140, 0, 22),
			Position = UDim2.fromOffset(52, 5),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local desc = label(card, {
			Name = "Desc",
			Font = Enum.Font.GothamMedium,
			Size = UDim2.new(1, -140, 0, 16),
			Position = UDim2.fromOffset(52, 29),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(225, 230, 245),
		})
		local ability = label(card, {
			Name = "Ability",
			Size = UDim2.fromOffset(46, 18),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -82, 0, 6),
			TextColor3 = Color3.fromRGB(150, 255, 190),
		})
		local back = glass("TextButton", card, "Return", 8) :: TextButton
		back.AnchorPoint = Vector2.new(1, 0.5)
		back.Position = UDim2.new(1, -6, 0.5, 0)
		back.Size = UDim2.fromOffset(68, 30)
		label(back, { Text = "< Vault", Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5) })
		back.Activated:Connect(function()
			remotes.PerkAction:FireServer("Return", i)
		end)
		perkCards[i] = { Card = card, Chip = c, ChipText = ct, Name = name, Desc = desc, Ability = ability, Return = back }
	end
end

local function renderItems()
	local list = parseList("Items")
	for i, s in itemSlots do
		local entry = list[i]
		local def = entry and ShopItems.Types[entry[1]]
		if def then
			s.Button:SetAttribute("ItemId", entry[1])
			s.Chip.Visible = true
			s.Chip.BackgroundColor3 = def.IconColor
			s.ChipText.Text = def.IconText
			s.Name.Text = def.DisplayName
			s.Count.Text = `x{entry[2]}`
			s.Button.BackgroundTransparency = 0.72
		else
			s.Button:SetAttribute("ItemId", nil)
			s.Chip.Visible = false
			s.Name.Text = ""
			s.Count.Text = ""
			s.Button.BackgroundTransparency = 0.88
		end
	end
end

local function renderPerks()
	local slotsOwned = math.clamp(player:GetAttribute("PerkSlots") or Config.PerkSlots, 1, MAX_PERK_CARDS)
	perksPanel.Size = UDim2.fromOffset(320, 30 + slotsOwned * 58)
	local list = parseList("Perks")
	for i, c in perkCards do
		c.Card.Visible = i <= slotsOwned
		local entry = list[i]
		local def = entry and Weather.Types[entry[1]]
		if def and def.Perk then
			local icon = Weather.Icon[entry[1]] or { "??", Color3.new(0.5, 0.5, 0.5) }
			c.Chip.BackgroundColor3 = icon[2]
			c.ChipText.Text = icon[1]
			c.Name.Text = (entry[2] == 1 and "* " or "") .. def.Perk.Name
			c.Name.TextColor3 = Weather.RarityOf(entry[1]).Color
			c.Desc.Text = def.Perk.Desc
			c.Return.Visible = true
			c.HasAbility = def.Perk.Ability ~= nil
		else
			c.Chip.BackgroundColor3 = Color3.fromRGB(120, 130, 160)
			c.ChipText.Text = "+"
			c.Name.Text = "Empty perk slot"
			c.Name.TextColor3 = Color3.fromRGB(200, 205, 220)
			c.Desc.Text = "Hold F on a cloud in YOUR vault"
			c.Return.Visible = false
			c.HasAbility = false
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
	player:GetAttributeChangedSignal("PerkSlots"):Connect(renderPerks)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for i, key in PERK_KEYS do
			if input.KeyCode == key then
				remotes.PerkAbility:FireServer(i)
				PlayerAnimator.Play("Ability")
			end
		end
	end)

	-- v2.31 GEAR: clicking with a held gear uses it (aimed ones use your mouse)
	local hookedTools = {}
	local function hookTool(t: Instance)
		if not t:IsA("Tool") or hookedTools[t] or not t:GetAttribute("GearId") then
			return
		end
		hookedTools[t] = true
		t.Activated:Connect(function()
			useItem(t:GetAttribute("GearId"))
		end)
		t.AncestryChanged:Connect(function()
			if not t.Parent then
				hookedTools[t] = nil
			end
		end)
	end
	local function watch(container: Instance?)
		if not container then
			return
		end
		for _, t in container:GetChildren() do
			hookTool(t)
		end
		container.ChildAdded:Connect(hookTool)
	end
	watch(player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10))
	watch(player.Character)
	player.CharacterAdded:Connect(function(char)
		watch(char)
		watch(player:WaitForChild("Backpack", 10))
	end)
	-- gear timer above the hotbar: READY / cooldown / charges
	local gearLabel = Instance.new("TextLabel")
	gearLabel.Name = "GearStatus"
	gearLabel.AnchorPoint = Vector2.new(0.5, 1)
	gearLabel.Position = UDim2.new(0.5, 0, 1, -86)
	gearLabel.Size = UDim2.fromOffset(320, 26)
	gearLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 35)
	gearLabel.BackgroundTransparency = 0.35
	gearLabel.TextColor3 = Color3.new(1, 1, 1)
	gearLabel.Font = Enum.Font.GothamBold
	gearLabel.TextScaled = true
	gearLabel.Visible = false
	Instance.new("UICorner", gearLabel).CornerRadius = UDim.new(0, 10)
	gearLabel.Parent = player:WaitForChild("PlayerGui"):WaitForChild("InventoryUI")
	RunService.RenderStepped:Connect(function()
		local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
		local id = tool and tool:GetAttribute("GearId")
		if not id then
			gearLabel.Visible = false
			return
		end
		gearLabel.Visible = true
		local now = workspace:GetServerTimeNow()
		local maxC = tool:GetAttribute("MaxCharges") or 0
		if maxC > 0 then
			local c = tool:GetAttribute("Charges") or maxC
			local pips = string.rep("●", c) .. string.rep("○", maxC - c)
			local nextAt = tool:GetAttribute("NextChargeAt") or 0
			local extra = (c < maxC and nextAt > now) and `  +1 in {math.ceil(nextAt - now)}s` or ""
			gearLabel.Text = `{tool.Name}  {pips}{extra}`
			gearLabel.TextColor3 = c > 0 and Color3.fromRGB(150, 255, 190) or Color3.fromRGB(255, 170, 120)
		else
			local ready = tool:GetAttribute("ReadyAt") or 0
			if now < ready then
				gearLabel.Text = `{tool.Name}  {math.ceil(ready - now)}s`
				gearLabel.TextColor3 = Color3.fromRGB(255, 200, 120)
			else
				gearLabel.Text = `{tool.Name}  READY - click`
				gearLabel.TextColor3 = Color3.fromRGB(150, 255, 190)
			end
		end
	end)

	-- Timers: active items + perk ability cooldowns
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local timers = {
			SpeedPotion = player:GetAttribute("SpeedUntil") or 0,
			JumpPotion = player:GetAttribute("JumpUntil") or 0,
			Nitro = player:GetAttribute("NitroUntil") or 0,
			ShieldGenerator = player:GetAttribute("ShieldUntil") or 0,
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
		for i, c in perkCards do
			if c.HasAbility then
				local ready = player:GetAttribute("AbilityReady" .. i) or 0
				c.Ability.Text = now < ready and `{math.ceil(ready - now)}s` or `[{PERK_KEY_TEXT[i]}]`
				c.Ability.TextColor3 = now < ready and Color3.fromRGB(200, 200, 210) or Color3.fromRGB(150, 255, 190)
			else
				c.Ability.Text = ""
			end
		end
	end)
end

return InventoryUi
