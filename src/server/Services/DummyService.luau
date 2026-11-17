-- STUDIO-ONLY TEST DUMMY that holds a cloud on the real leash.
--
--   Dummy:  workspace.TestArea.CloudDummy        (R15, tag "TestDummy")
--   Cloud:  workspace.Weather.<sphere>            attribute TestDummyCloud = true
--   Spot:   Hexagon Hub, Y 40, at (0, 40, -42) on a glowing pad workspace.TestArea.DummyPad
--
-- Hit it with:  the Laser Gun · a Quake perk ability · its "Hit dummy" prompt (E)
--               · Command Bar (server): require(game.ServerScriptService.Server.Services.DummyService).Knock()
-- Then:  the leash is cut and the cloud flies off the hand → the dummy falls →
--        after ~2.5 s it stands up → the SAME cloud instance is re-leashed.
-- Every cycle prints a check line to Output:
--   [Dummy] cycle N: detached=true reattached=true sameCloud=true clouds=1 ropes=1 aligns=1 handAtts=1 targets=1 -> PASS
--
-- Never runs in a live game (RunService:IsStudio()).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AnimLib = require(ReplicatedStorage.Shared.AnimLib)
local RagdollLib = require(ReplicatedStorage.Shared.RagdollLib)

local DummyService = {}

local CLOUD_TYPE = "Cumulus"
local SPOT = Vector3.new(0, 40, -42)

local WeatherService
local dummy: Model? = nil
local state = {
	Sphere = nil :: BasePart?,
	Attachments = {} :: { Instance },
	Busy = false,
	Cycle = 0,
	Tracks = {} :: { [string]: AnimationTrack },
}

local function root(): BasePart?
	return dummy and dummy:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function play(name: string, looped: boolean?)
	local hum = dummy and dummy:FindFirstChildOfClass("Humanoid")
	local animator = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum))
	if not animator then
		return
	end
	local track = state.Tracks[name]
	if not track then
		track = AnimLib.Load(animator, name)
		if not track then
			return
		end
		track.Looped = looped == true
		state.Tracks[name] = track
	end
	track:Play(0.15)
end

local function stop(name: string)
	local t = state.Tracks[name]
	if t then
		t:Stop(0.2)
	end
end

local function countCheck(): { [string]: number }
	local r = root()
	local hand = dummy and dummy:FindFirstChild("LeftHand")
	local weather = workspace:FindFirstChild("Weather")
	local out = { clouds = 0, ropes = 0, aligns = 0, handAtts = 0, targets = 0 }
	for _, d in weather and weather:GetDescendants() or {} do
		if d:IsA("BasePart") and d:GetAttribute("TestDummyCloud") then
			out.clouds += 1
		end
	end
	local s = state.Sphere
	for _, c in s and s:GetChildren() or {} do
		if c:IsA("RopeConstraint") then
			out.ropes += 1
		elseif c:IsA("AlignPosition") then
			out.aligns += 1
		end
	end
	for _, c in hand and hand:GetChildren() or {} do
		if c.Name == "LeashHand" then
			out.handAtts += 1
		end
	end
	for _, c in r and r:GetChildren() or {} do
		if c.Name == "LeashTarget" then
			out.targets += 1
		end
	end
	return out
end

local function leash()
	local r = root()
	if not r then
		return
	end
	if state.Sphere and state.Sphere.Parent then
		state.Attachments = WeatherService.TestReattach(state.Sphere, CLOUD_TYPE, r)
	else
		if state.Sphere then
			print("[Dummy] previous cloud was destroyed - creating a new one")
		end
		state.Sphere, state.Attachments = WeatherService.TestLeash(CLOUD_TYPE, r)
	end
	play("LeashHold", true)
end

local function build()
	local folder = workspace:FindFirstChild("TestArea") or Instance.new("Folder")
	folder.Name = "TestArea"
	folder.Parent = workspace

	local d = Instance.new("HumanoidDescription")
	d.HeadColor = Color3.fromRGB(200, 205, 215)
	d.TorsoColor = Color3.fromRGB(120, 130, 150)
	d.LeftArmColor, d.RightArmColor = d.HeadColor, d.HeadColor
	d.LeftLegColor, d.RightLegColor = d.TorsoColor, d.TorsoColor
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Dummy] could not build the dummy: " .. tostring(model))
		return
	end
	model.Name = "CloudDummy"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayName = "Test Dummy (hit me)"
	hum.MaxHealth = 1e6
	hum.Health = 1e6
	hum.BreakJointsOnDeath = false
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	model:PivotTo(CFrame.new(SPOT + Vector3.new(0, 3, 0)))
	model.Parent = folder
	CollectionService:AddTag(model, "TestDummy")
	local r = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		r:SetNetworkOwner(nil) -- the server drives the dummy
	end)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HitDummyPrompt"
	prompt.ActionText = "Hit dummy"
	prompt.ObjectText = "Test Dummy"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = r
	prompt.Triggered:Connect(function(player)
		local pr = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		DummyService.Knock(pr and (r.Position - pr.Position).Unit or nil)
	end)

	dummy = model
	task.wait(0.5)
	leash()
	print("[Dummy] ready at workspace.TestArea.CloudDummy - hit it (Laser, Quake, prompt E or DummyService.Knock())")
end

-- Knock the dummy down; returns false if a cycle is already running
function DummyService.Knock(dir: Vector3?): boolean
	local r = root()
	local hum = dummy and dummy:FindFirstChildOfClass("Humanoid")
	if state.Busy or not r or not hum or not state.Sphere then
		return false
	end
	state.Busy = true
	state.Cycle += 1
	local cycle = state.Cycle
	local sphere = state.Sphere :: BasePart
	local push = Vector3.new((dir or r.CFrame.LookVector * -1).X, 0, (dir or r.CFrame.LookVector * -1).Z)
	push = push.Magnitude > 0.01 and push.Unit or Vector3.new(1, 0, 0)

	-- 1) cloud leaves the hand: leash cut, small pop away
	WeatherService.TestDetach(sphere, state.Attachments)
	state.Attachments = {}
	-- the cloud has no collision, so it would fall through the hub: let it
	-- drift off the hand and hover there until the dummy gets up
	sphere.Anchored = true
	TweenService:Create(sphere, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(r.Position + push * 9 + Vector3.new(0, 5, 0)),
	}):Play()
	local afterDetach = countCheck()
	local detached = afterDetach.ropes == 0 and afterDetach.aligns == 0 and afterDetach.handAtts == 0 and afterDetach.targets == 0

	-- 2) dummy falls as a REAL ragdoll (v1.8): Motor6Ds -> ball sockets
	stop("LeashHold")
	local rag = RagdollLib.Enable(dummy :: Model)
	for _, part in (dummy :: Model):GetDescendants() do
		if part:IsA("BasePart") then
			pcall(function()
				part:SetNetworkOwner(nil) -- limbs are separate bodies now; keep them on the server
			end)
		end
	end
	local torso = (dummy :: Model):FindFirstChild("UpperTorso") :: BasePart?
	r.AssemblyLinearVelocity = push * 28 + Vector3.new(0, 16, 0)
	if torso then
		torso:ApplyImpulse((push * 40 + Vector3.new(0, 20, 0)) * torso.AssemblyMass)
	end
	local ragdolled = rag ~= nil and #rag.Motors > 0

	task.spawn(function()
		task.wait(2.2)
		-- 3) stand up: joints back, upright at the spot again
		RagdollLib.Disable(dummy :: Model, rag)
		for _, part in (dummy :: Model):GetDescendants() do
			if part:IsA("BasePart") then
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
			end
		end
		dummy:PivotTo(CFrame.new(SPOT + Vector3.new(0, 3, 0)))
		task.wait(0.8)

		-- 4) the SAME cloud comes back to the hand
		leash()
		local c = countCheck()
		local same = state.Sphere == sphere
		local pass = detached and same and c.clouds == 1 and c.ropes == 1 and c.aligns == 1 and c.handAtts == 1 and c.targets == 1
		local motorsBack = true
		for _, m in (dummy :: Model):GetDescendants() do
			if m:IsA("Motor6D") and not m.Enabled then
				motorsBack = false
			end
		end
		local leftovers = 0
		for _, d in (dummy :: Model):GetDescendants() do
			if d.Name == "RagdollJoint" then
				leftovers += 1
			end
		end
		pass = pass and ragdolled and motorsBack and leftovers == 0
		print(string.format("[Dummy] cycle %d: ragdolled=%s jointsRestored=%s staleJoints=%d detached=%s reattached=%s sameCloud=%s clouds=%d ropes=%d aligns=%d handAtts=%d targets=%d -> %s",
			cycle, tostring(ragdolled), tostring(motorsBack), leftovers, tostring(detached), tostring(c.ropes == 1), tostring(same),
			c.clouds, c.ropes, c.aligns, c.handAtts, c.targets, pass and "PASS" or "FAIL"))
		state.Busy = false
	end)
	return true
end

function DummyService.Start(weatherService, inventoryService)
	if not RunService:IsStudio() then
		return
	end
	WeatherService = weatherService
	inventoryService.Hooks.ModelHit = function(_shooter: Player, model: Model, dir: Vector3?)
		if model == dummy then
			DummyService.Knock(dir)
		end
	end
	-- a small pad + sign so testers can find it
	local map = workspace:FindFirstChild("Map")
	if map and not workspace:FindFirstChild("TestArea") then
		local pad = Instance.new("Part")
		pad.Name = "DummyPad"
		pad.Anchored = true
		pad.Size = Vector3.new(10, 0.3, 10)
		pad.CFrame = CFrame.new(SPOT + Vector3.new(0, 0.15, 0))
		pad.Color = Color3.fromRGB(255, 200, 80)
		pad.Material = Enum.Material.Neon
		pad.Transparency = 0.5
		pad.CanCollide = false
		local folder = Instance.new("Folder")
		folder.Name = "TestArea"
		folder.Parent = workspace
		pad.Parent = folder
	end
	task.spawn(build)
end

return DummyService
