-- Plays the local player's character animations (see Shared/AnimationData):
--   loops:    LeashHold (carrying a cloud), UpdraftFloat (in an updraft), Slip
--   one-shot: Catch / Steal (holding E), Cheer (delivery), Knocked (lightning),
--             Shoot / Drink / Throw (items), Ability (perk G/H/J)
-- Other players see them too: animations on your own character replicate.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimLib = require(ReplicatedStorage.Shared.AnimLib)

local PlayerAnimator = {}

local player = Players.LocalPlayer
local tracks: { [string]: AnimationTrack | false } = {}
local animator: Animator? = nil

local ITEM_ANIM = {
	LaserGun = "Shoot",
	SpeedPotion = "Drink",
	JumpPotion = "Drink",
	Nitro = "Drink",
	Flare = "Throw",
	GrapplingHook = "Throw",
	ShieldGenerator = "Throw",
}

local function track(name: string): AnimationTrack?
	if not animator then
		return nil
	end
	if tracks[name] == nil then
		tracks[name] = AnimLib.Load(animator, name) or false
	end
	return tracks[name] or nil
end

function PlayerAnimator.Play(name: string, fade: number?)
	local t = track(name)
	if t then
		t:Play(fade or 0.1)
	end
end

function PlayerAnimator.Stop(name: string, fade: number?)
	local t = tracks[name]
	if t and t.IsPlaying then
		t:Stop(fade or 0.2)
	end
end

function PlayerAnimator.PlayItem(id: string)
	local name = ITEM_ANIM[id]
	if name then
		PlayerAnimator.Play(name)
	end
end

local function setLoop(name: string, on: boolean)
	local t = on and track(name) or tracks[name]
	if not t then
		return
	end
	if on and not t.IsPlaying then
		t:Play(0.2)
	elseif not on and t.IsPlaying then
		t:Stop(0.25)
	end
end

local function onCharacter(char: Model)
	tracks = {}
	animator = nil
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	animator = hum:WaitForChild("Animator", 10) :: Animator?
end

function PlayerAnimator.Start()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not animator or not hum or not root or hum.Health <= 0 then
			return
		end
		local carrying = player:GetAttribute("Carrying")
		local air = root:FindFirstChild("AirLift")
		-- v2.34: while ragdolled (laser, knocks) it's PURE physics: no pose on top
		-- (PlatformStand is also set by the ragdoll, which used to start "Slip")
		local ragdolled = (player:GetAttribute("RagdollUntil") or 0) > workspace:GetServerTimeNow()
		if ragdolled then
			for name, t in tracks do
				if t and t.IsPlaying then
					t:Stop(0.05)
				end
			end
			return
		end
		setLoop("LeashHold", carrying ~= nil and carrying ~= "")
		-- float pose only while riding UP (riding down plays UpdraftDive from Movement)
		setLoop("UpdraftFloat", air ~= nil and air.Enabled and (air :: LinearVelocity).VectorVelocity.Y > 0)
		setLoop("Slip", hum.PlatformStand)
	end)

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt.Name == "CatchPrompt" then
			PlayerAnimator.Play("Catch")
		elseif prompt.Name == "StealPrompt" then
			PlayerAnimator.Play("Steal")
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt.Name == "StealPrompt" then
			PlayerAnimator.Stop("Steal")
		end
	end)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Delivered").OnClientEvent:Connect(function()
		PlayerAnimator.Play("Cheer")
	end)
	remotes:WaitForChild("Knock").OnClientEvent:Connect(function()
		-- v2.34: when the hit ragdolls you (laser, big knocks) it's a pure ragdoll,
		-- no flinch animation on top
		task.delay(0.05, function()
			if (player:GetAttribute("RagdollUntil") or 0) > workspace:GetServerTimeNow() then
				return
			end
			PlayerAnimator.Play("Knocked")
		end)
	end)
end

return PlayerAnimator
