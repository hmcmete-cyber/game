-- Player attacks (server: CombatService) + monster status overlays.
--   R  Gust Punch (on the ground) / Air Slam (while in the air)
--   T  Puff Shot toward the mouse / screen centre
-- Touch devices get two round buttons. Also draws the Ash Puff blindness
-- overlay (BlindUntil) for monster status effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PlayerAnimator = require(script.Parent:WaitForChild("PlayerAnimator"))

local CombatInput = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()
local COOLDOWN = { Punch = 0.6, Slam = 3, Puff = 1.2 } -- mirrors CombatService (UI only)
local readyAt = {}

local function aimPoint(): Vector3
	if UserInputService.MouseEnabled and mouse.Hit then
		return mouse.Hit.Position
	end
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	return ray.Origin + ray.Direction * 70
end

local remote
local function send(kind: string)
	if os.clock() < (readyAt[kind] or 0) then
		return
	end
	readyAt[kind] = os.clock() + COOLDOWN[kind]
	remote:FireServer(kind, kind == "Puff" and aimPoint() or nil)
	PlayerAnimator.Play(kind == "Puff" and "Shoot" or (kind == "Slam" and "Ability" or "Throw"))
end

local function punchOrSlam()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.FloorMaterial == Enum.Material.Air then
		send("Slam")
	else
		send("Punch")
	end
end

local function roundButton(gui: ScreenGui, text: string, pos: UDim2, fn)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(64, 64)
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = pos
	b.BackgroundColor3 = Color3.fromRGB(16, 27, 48)
	b.BackgroundTransparency = 0.15
	b.TextColor3 = Color3.fromRGB(244, 247, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.Text = text
	b.Parent = gui
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(105, 222, 239)
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- v2.40 ring, not letter outline
	stroke.Parent = b
	b.Activated:Connect(fn)
end

function CombatInput.Start()
	remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Attack")
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			punchOrSlam()
		elseif input.KeyCode == Enum.KeyCode.T then
			send("Puff")
		end
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Combat"
	gui.ResetOnSpawn = false
	if UserInputService.TouchEnabled then
		roundButton(gui, "PUNCH", UDim2.new(1, -110, 1, -150), punchOrSlam)
		roundButton(gui, "PUFF", UDim2.new(1, -40, 1, -210), function()
			send("Puff")
		end)
	end
	-- Ash Puff blindness
	local ash = Instance.new("Frame")
	ash.Size = UDim2.fromScale(1, 1)
	ash.BackgroundColor3 = Color3.fromRGB(45, 40, 40)
	ash.BackgroundTransparency = 1
	ash.BorderSizePixel = 0
	ash.ZIndex = 0
	ash.Parent = gui
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(function()
		local left = (player:GetAttribute("BlindUntil") or 0) - workspace:GetServerTimeNow()
		local want = left > 0 and math.clamp(0.15 + (1 - left / 3) * 0.6, 0.15, 0.85) or 1
		ash.BackgroundTransparency += (want - ash.BackgroundTransparency) * 0.2
	end)
end

return CombatInput
