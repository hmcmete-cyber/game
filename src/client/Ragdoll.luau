-- Brief ragdoll when you get hit (laser, Quake, lightning).
-- The server sets player attribute RagdollUntil (server time, Config.RagdollTime
-- = 1.2 s). This client owns its character's physics, so it swaps the joints
-- for ball sockets locally; the limb positions replicate to everyone.
-- Recovery is guaranteed: a timer always restores the joints and puts the
-- humanoid back into GettingUp, even if a newer hit extended the ragdoll.
-- A carried cloud stays on its leash (rules for dropping are unchanged).

local Players = game:GetService("Players")

local Ragdoll = {}

local player = Players.LocalPlayer
local RagdollLib = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RagdollLib"))
local active: RagdollLib.State? = nil

local function stop(char: Model)
	local st = active
	active = nil
	RagdollLib.Disable(char, st)
end

local function start(char: Model)
	if active then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	active = RagdollLib.Enable(char)
end

local function check()
	local char = player.Character
	if not char then
		return
	end
	local untilT = player:GetAttribute("RagdollUntil") or 0
	local left = untilT - workspace:GetServerTimeNow()
	if left > 0.05 then
		start(char)
		task.delay(left, check) -- re-check: a later hit may have extended it
	elseif active then
		stop(char)
	end
end

function Ragdoll.Start()
	player:GetAttributeChangedSignal("RagdollUntil"):Connect(check)
	player.CharacterAdded:Connect(function()
		active = nil -- the old character took its constraints with it
	end)
end

return Ragdoll
