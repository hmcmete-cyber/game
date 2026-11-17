-- Builds 6 KeyframeSequences for any monster rig from its joint ROLES:
--   Idle (loop) · Walk (loop) · Ability1 · Ability2 · Hit · Death
-- Each rig moves differently because its parts/roles differ (quadrupeds trot
-- with diagonal leg pairs, bipeds swing arms, funnels spin, rubble orbits,
-- jaws snap, wings flap). Studio: registered through KeyframeSequenceProvider
-- and played on the server (replicates). Live servers need published ids:
-- run MonsterAnims.ExportAll() from the Studio Command Bar (server), then
-- "Save to Roblox" each KeyframeSequence in ServerStorage/MonsterAnimExport.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local MonsterAnims = {}

local NAMES = { "Idle", "Walk", "Ability1", "Ability2", "Hit", "Death" }
MonsterAnims.Names = NAMES

local rad, sin = math.rad, math.sin
local A = CFrame.Angles
local TAU = math.pi * 2

-- pose for a role at phase p (0..1 of the clip); c0 = joint C0 (for orbits)
local CLIPS = {
	Idle = { Length = 2, Loop = true, Priority = Enum.AnimationPriority.Idle, Keys = 5, Pose = function(role, p, c0)
		local w = sin(p * TAU)
		if role == "body" then
			return CFrame.new(0, 0.12 * w, 0)
		elseif role == "head" then
			return A(rad(4 * w), rad(6 * sin(p * TAU + 1)), 0)
		elseif role == "armL" then
			return A(0, 0, rad(-4 * w))
		elseif role == "armR" then
			return A(0, 0, rad(4 * w))
		elseif role == "tail" then
			return A(0, rad(12 * w), 0)
		elseif role == "wing" then
			return A(0, 0, rad(6 * w))
		elseif role == "jawBot" then
			return A(rad(4 + 4 * w), 0, 0)
		elseif role == "spin" then
			return A(0, p * TAU, 0)
		elseif role == "orbit" then
			local pos = c0.Position
			return CFrame.new(A(0, p * TAU, 0) * pos - pos)
		end
		return nil
	end },
	Walk = { Length = 0.8, Loop = true, Priority = Enum.AnimationPriority.Movement, Keys = 5, Pose = function(role, p, c0)
		local w = sin(p * TAU)
		if role == "legA" then
			return A(rad(28 * w), 0, 0)
		elseif role == "legB" then
			return A(rad(-28 * w), 0, 0)
		elseif role == "armL" then
			return A(rad(-24 * w), 0, 0)
		elseif role == "armR" then
			return A(rad(24 * w), 0, 0)
		elseif role == "body" then
			return CFrame.new(0, 0.18 * math.abs(w), 0) * A(0, 0, rad(3 * w))
		elseif role == "head" then
			return A(rad(4 * sin(p * TAU * 2)), 0, 0)
		elseif role == "tail" then
			return A(0, rad(18 * w), 0)
		elseif role == "wing" then
			return A(0, 0, rad(10 * w))
		elseif role == "spin" then
			return A(0, p * TAU, 0)
		elseif role == "orbit" then
			local pos = c0.Position
			return CFrame.new(A(0, p * TAU, 0) * pos - pos)
		end
		return nil
	end },
	-- lunge / bite / throw: wind back, strike forward
	Ability1 = { Length = 0.9, Loop = false, Priority = Enum.AnimationPriority.Action, Times = { 0, 0.3, 0.5, 0.9 }, Pose = function(role, i)
		if i == 1 or i == 4 then
			return CFrame.new()
		end
		local wind = i == 2
		if role == "body" then
			return A(rad(wind and 12 or -16), 0, 0)
		elseif role == "head" then
			return A(rad(wind and 16 or -22), 0, 0)
		elseif role == "armL" or role == "armR" then
			return A(rad(wind and -50 or 95), 0, 0)
		elseif role == "jawTop" then
			return A(rad(wind and -35 or 0), 0, 0)
		elseif role == "jawBot" then
			return A(rad(wind and 30 or 0), 0, 0)
		elseif role == "legA" or role == "legB" then
			return A(rad(wind and -8 or 12), 0, 0)
		elseif role == "wing" then
			return A(0, 0, rad(wind and -20 or 25))
		elseif role == "tail" then
			return A(rad(wind and 20 or -15), 0, 0)
		end
		return nil
	end },
	-- rear up / spread / slam: big area move
	Ability2 = { Length = 1.1, Loop = false, Priority = Enum.AnimationPriority.Action, Times = { 0, 0.4, 0.62, 1.1 }, Pose = function(role, i, c0)
		if i == 1 or i == 4 then
			return CFrame.new()
		end
		local up = i == 2
		if role == "body" then
			return up and (CFrame.new(0, 0.6, 0) * A(rad(-22), 0, 0)) or (CFrame.new(0, -0.3, 0) * A(rad(14), 0, 0))
		elseif role == "head" then
			return A(rad(up and 25 or -15), 0, 0)
		elseif role == "armL" then
			return up and A(0, 0, rad(-120)) or A(rad(70), 0, rad(-20))
		elseif role == "armR" then
			return up and A(0, 0, rad(120)) or A(rad(70), 0, rad(20))
		elseif role == "legA" or role == "legB" then
			return A(rad(up and 10 or -10), 0, 0)
		elseif role == "wing" then
			return A(0, 0, rad(up and 40 or -10))
		elseif role == "jawTop" then
			return A(rad(up and -40 or 0), 0, 0)
		elseif role == "jawBot" then
			return A(rad(up and 35 or 0), 0, 0)
		elseif role == "spin" then
			return A(0, rad(up and 180 or 360), 0)
		elseif role == "orbit" then
			local pos = c0.Position
			local push = up and 1.5 or 0.7 -- boulders burst outward
			return CFrame.new(pos * push - pos)
		elseif role == "tail" then
			return A(rad(up and -25 or 10), 0, 0)
		end
		return nil
	end },
	Hit = { Length = 0.35, Loop = false, Priority = Enum.AnimationPriority.Action, Times = { 0, 0.1, 0.35 }, Pose = function(role, i)
		if i ~= 2 then
			return CFrame.new()
		end
		if role == "body" then
			return A(rad(12), 0, rad(-4))
		elseif role == "head" then
			return A(rad(18), 0, 0)
		elseif role == "armL" or role == "armR" then
			return A(rad(-20), 0, 0)
		end
		return nil
	end },
	Death = { Length = 1.4, Loop = false, Priority = Enum.AnimationPriority.Action2, Times = { 0, 0.5, 1.4 }, Pose = function(role, i)
		if i == 1 then
			return CFrame.new()
		end
		local fall = i == 3
		if role == "body" then
			return fall and (CFrame.new(0, -1.2, 0) * A(rad(10), 0, rad(85))) or A(rad(-10), 0, rad(30))
		elseif role == "head" then
			return A(rad(fall and 35 or 15), 0, 0)
		elseif role == "legA" or role == "legB" then
			return A(rad(fall and 40 or 15), 0, 0)
		elseif role == "armL" then
			return A(0, 0, rad(fall and -60 or -20))
		elseif role == "armR" then
			return A(0, 0, rad(fall and 60 or 20))
		elseif role == "jawBot" then
			return A(rad(30), 0, 0)
		elseif role == "wing" then
			return A(0, 0, rad(-30))
		end
		return nil
	end },
}

local function sequence(model: Model, clipName: string): KeyframeSequence
	local clip = CLIPS[clipName]
	-- joint tree from the rig's Motor6Ds
	local parentOf, c0Of, roleOf = {}, {}, {}
	for _, m in model:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			parentOf[m.Part1.Name] = m.Part0.Name
			c0Of[m.Part1.Name] = m.C0
			roleOf[m.Part1.Name] = m.Part1:GetAttribute("Role") or "deco"
		end
	end
	local times = clip.Times
	if not times then
		times = {}
		for k = 0, clip.Keys - 1 do
			table.insert(times, clip.Length * k / (clip.Keys - 1))
		end
	end
	-- which parts get keyed at all in this clip
	local keyed, need = {}, { HumanoidRootPart = true }
	for name, role in roleOf do
		local probe = clip.Times and 2 or 0.25 -- a non-rest key of the clip
		if clip.Pose(role, probe, c0Of[name]) ~= nil then
			keyed[name] = true
			local n = name
			while n do
				need[n] = true
				n = parentOf[n]
			end
		end
	end

	local seq = Instance.new("KeyframeSequence")
	seq.Name = model.Name .. "_" .. clipName
	seq.Loop = clip.Loop
	seq.Priority = clip.Priority
	for i, t in times do
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local poses = {}
		local function getPose(name: string): Pose
			if poses[name] then
				return poses[name]
			end
			local pose = Instance.new("Pose")
			pose.Name = name
			pose.Weight = keyed[name] and 1 or 0
			local role = roleOf[name]
			local continuous = role == "spin" or role == "orbit"
			pose.EasingStyle = continuous and Enum.PoseEasingStyle.Linear or Enum.PoseEasingStyle.CubicV2
			pose.EasingDirection = Enum.PoseEasingDirection.InOut
			if keyed[name] then
				local arg = clip.Times and i or (t / clip.Length)
				pose.CFrame = clip.Pose(role, arg, c0Of[name]) or CFrame.new()
			end
			pose.Parent = parentOf[name] and getPose(parentOf[name]) or kf
			poses[name] = pose
			return pose
		end
		for name in need do
			getPose(name)
		end
		kf.Parent = seq
	end
	return seq
end

local cache: { [string]: { [string]: string | false } } = {}

-- Animation ids for a monster type (Studio: registered temporary ids)
function MonsterAnims.Ids(typeName: string, model: Model): { [string]: string | false }
	if cache[typeName] then
		return cache[typeName]
	end
	local published = require(game:GetService("ReplicatedStorage").Shared.MonsterAnimIds)
	local ids = {}
	for _, name in NAMES do
		local pub = published[typeName .. "_" .. name]
		if pub and pub ~= "" then
			ids[name] = pub
			continue
		end
		local ok, id = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence(model, name))
		end)
		ids[name] = ok and id or false
	end
	cache[typeName] = ids
	return ids
end

-- Loads all six tracks on a monster's Animator
function MonsterAnims.Load(typeName: string, model: Model): { [string]: AnimationTrack }
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local tracks = {}
	if not animator then
		return tracks
	end
	for name, id in MonsterAnims.Ids(typeName, model) do
		if id then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok and track then
				tracks[name] = track
			end
		end
	end
	return tracks
end

-- Studio helper: puts every monster's KeyframeSequences in ServerStorage for publishing
function MonsterAnims.ExportAll()
	local MonsterRigs = require(script.Parent.MonsterRigs)
	local Defs = require(game:GetService("ReplicatedStorage").Shared.MonsterDefs)
	local folder = Instance.new("Folder")
	folder.Name = "MonsterAnimExport"
	for typeName, def in Defs.Types do
		local model = MonsterRigs.Build(typeName, def.Scale)
		for _, name in NAMES do
			sequence(model, name).Parent = folder
		end
		model:Destroy()
	end
	folder.Parent = game:GetService("ServerStorage")
	print("[MonsterAnims] exported " .. #folder:GetChildren() .. " KeyframeSequences to ServerStorage.MonsterAnimExport")
end

return MonsterAnims
