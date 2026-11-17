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

------------------------------------------------------------------------
-- v2.3 SPECIES GAITS: Idle, Walk and Ability1 are built per gait so the
-- roster moves differently (MonsterDefs.Gait). Ability2 / Hit / Death stay
-- shared but act on each rig's own parts.
------------------------------------------------------------------------
local GAITS = {
	Trot = { Len = 0.55, Leg = 32, Bob = 0.2, Tail = 20, Head = 0, Idle = "Alert" }, -- light quadruped
	Plod = { Len = 1.1, Leg = 18, Bob = 0.25, Roll = 5, Tail = 10, Head = 0, Idle = "Heavy" }, -- heavy quadruped
	Prowl = { Len = 0.8, Leg = 26, Bob = 0.1, Pitch = -8, Tail = 14, Head = -12, Idle = "Alert" }, -- low, sneaky
	Stride = { Len = 0.8, Leg = 30, Arm = 28, Bob = 0.2, Twist = 6, Idle = "Look" }, -- light biped
	Stomp = { Len = 1.2, Leg = 22, Arm = 14, Bob = -0.35, Roll = 6, Idle = "Heavy", Attack = "Smash" }, -- heavy biped
	Knuckle = { Len = 0.9, Leg = 18, Arm = 42, Bob = 0.2, Pitch = -12, Idle = "Heavy", Attack = "Smash" }, -- gorilla brute
	Waddle = { Len = 0.7, Leg = 20, ArmFlap = 15, Roll = 12, Bob = 0.15, Idle = "Bouncy" }, -- round glutton
	Hop = { Len = 0.5, Leg = 25, Hop = 0.9, Idle = "Bouncy", Attack = "Pounce" }, -- small hopper
	Hover = { Len = 1.2, Float = 0.4, Pitch = -10, ArmTrail = -25, Tail = 25, Idle = "Float", Attack = "Dive" }, -- floaters
	Swim = { Len = 0.7, Leg = 25, Yaw = 10, Tail = 30, Fin = 20, Idle = "Alert" }, -- shark-like
	Rooted = { Len = 1.6, Idle = "Sway" }, -- plants that can't walk
}

local function continuous(role: string, p: number, c0: CFrame, speed: number?): CFrame?
	if role == "spin" then
		return A(0, p * TAU * (speed or 1), 0)
	elseif role == "orbit" then
		local pos = c0.Position
		return CFrame.new(A(0, p * TAU * (speed or 1), 0) * pos - pos)
	end
	return nil
end

local IDLES = {
	Alert = { Length = 2.4, Pose = function(role, p)
		local w = sin(p * TAU)
		if role == "body" then return CFrame.new(0, 0.08 * w, 0) end
		if role == "head" then return A(rad(3 * w), rad(18 * sin(p * TAU)), 0) end
		if role == "tail" then return A(0, rad(14 * w), 0) end
		if role == "wing" or role == "armL" then return A(0, 0, rad(-5 * w)) end
		if role == "armR" then return A(0, 0, rad(5 * w)) end
		return nil
	end },
	Heavy = { Length = 3.2, Pose = function(role, p)
		local w = sin(p * TAU)
		if role == "body" then return CFrame.new(0, 0.15 * w, 0) * A(rad(2 * w), 0, 0) end
		if role == "head" then return A(rad(-3 * w), rad(10 * sin(p * TAU)), 0) end
		if role == "armL" then return A(0, 0, rad(-3 * w)) end
		if role == "armR" then return A(0, 0, rad(3 * w)) end
		if role == "wing" then return A(0, 0, rad(6 * w)) end
		return nil
	end },
	Look = { Length = 2.8, Pose = function(role, p)
		local w = sin(p * TAU)
		if role == "body" then return CFrame.new(0, 0.1 * w, 0) end
		if role == "head" then return A(rad(5 * math.cos(p * TAU)), rad(25 * w), 0) end
		if role == "armL" then return A(rad(4 * w), 0, rad(-4)) end
		if role == "armR" then return A(rad(-4 * w), 0, rad(4)) end
		return nil
	end },
	Bouncy = { Length = 1.2, Pose = function(role, p)
		local w = sin(p * TAU)
		if role == "body" then return CFrame.new(0, 0.2 * math.abs(w), 0) end
		if role == "head" then return A(0, 0, rad(8 * w)) end
		if role == "armL" then return A(0, 0, rad(-10 * math.abs(w))) end
		if role == "armR" then return A(0, 0, rad(10 * math.abs(w))) end
		if role == "tail" then return A(rad(10 * w), 0, 0) end
		return nil
	end },
	Float = { Length = 2.4, Pose = function(role, p)
		local w = sin(p * TAU)
		if role == "body" then return CFrame.new(0, 0.35 * w, 0) * A(rad(4 * w), 0, 0) end
		if role == "head" then return A(0, rad(12 * sin(p * TAU)), 0) end
		if role == "armL" then return A(rad(6 * w), 0, rad(-10 * w)) end
		if role == "armR" then return A(rad(-6 * w), 0, rad(10 * w)) end
		if role == "tail" then return A(0, rad(20 * w), rad(6 * w)) end
		return nil
	end },
	Sway = { Length = 2, Pose = function(role, p)
		local w = sin(p * TAU)
		if role == "tail" then return A(rad(10 * w), rad(6 * math.cos(p * TAU)), 0) end
		if role == "jawTop" then return A(rad(-8 - 8 * math.abs(w)), 0, 0) end
		if role == "jawBot" then return A(rad(6 + 6 * math.abs(w)), 0, 0) end
		if role == "wing" then return A(0, 0, rad(12 * w)) end
		if role == "body" then return CFrame.new(0, 0.05 * w, 0) end
		return nil
	end },
}

local function gaitClip(clipName: string, gaitName: string?)
	local g = GAITS[gaitName or "Trot"] or GAITS.Trot
	if clipName == "Idle" then
		local idle = IDLES[g.Idle] or IDLES.Alert
		return { Length = idle.Length, Loop = true, Priority = Enum.AnimationPriority.Idle, Keys = 9, Pose = function(role, p, c0)
			return continuous(role, p, c0, 1) or idle.Pose(role, p)
		end }
	elseif clipName == "Walk" then
		return { Length = g.Len, Loop = true, Priority = Enum.AnimationPriority.Movement, Keys = 9, Pose = function(role, p, c0)
			local c = continuous(role, p, c0, 1)
			if c then
				return c
			end
			local w = sin(p * TAU)
			local aw = math.abs(w)
			if role == "legA" then
				return g.Hop and A(rad(g.Leg * aw), 0, 0) or (g.Leg and A(rad(g.Leg * w), 0, 0))
			elseif role == "legB" then
				return g.Hop and A(rad(g.Leg * aw), 0, 0) or (g.Leg and A(rad(-g.Leg * w), 0, 0))
			elseif role == "armL" or role == "armR" then
				local side = role == "armL" and -1 or 1
				if g.ArmFlap then
					return A(0, 0, rad(side * g.ArmFlap * aw))
				elseif g.ArmTrail then
					return A(rad(g.ArmTrail + 6 * w * side), 0, rad(side * 8))
				elseif g.Fin then
					return A(0, 0, rad(side * g.Fin * w))
				elseif g.Arm then
					return A(rad(side * g.Arm * w), 0, 0)
				end
				return nil
			elseif role == "body" then
				local y = g.Hop and g.Hop * aw or (g.Float and g.Float * w or (g.Bob or 0) * aw)
				return CFrame.new(0, y, 0) * A(rad(g.Pitch or 0), rad(((g.Yaw or 0) + (g.Twist or 0)) * w), rad((g.Roll or 0) * w))
			elseif role == "head" then
				return A(rad((g.Head or 0) + 4 * sin(p * TAU * 2)), rad(-(g.Yaw or 0) * w), 0)
			elseif role == "tail" then
				return g.Tail and A(0, rad(g.Tail * sin(p * TAU + 1.2)), 0) or nil
			elseif role == "wing" then
				return A(0, 0, rad((g.Float and 20 or 10) * w))
			elseif role == "jawBot" and g.Yaw then
				return A(rad(6 + 6 * aw), 0, 0)
			end
			return nil
		end }
	elseif clipName == "Ability1" then
		local kind = g.Attack
		if kind == "Smash" then
			return { Length = 0.9, Loop = false, Priority = Enum.AnimationPriority.Action, Times = { 0, 0.35, 0.5, 0.9 }, Pose = function(role, i)
				if i == 1 or i == 4 then return CFrame.new() end
				local up = i == 2
				if role == "body" then return A(rad(up and -15 or 20), 0, 0) end
				if role == "armL" then return up and A(0, 0, rad(-150)) or A(rad(100), 0, rad(-10)) end
				if role == "armR" then return up and A(0, 0, rad(150)) or A(rad(100), 0, rad(10)) end
				if role == "head" then return A(rad(up and 15 or -15), 0, 0) end
				if role == "legA" or role == "legB" then return A(rad(up and -6 or 10), 0, 0) end
				return nil
			end }
		elseif kind == "Pounce" then
			return { Length = 0.7, Loop = false, Priority = Enum.AnimationPriority.Action, Times = { 0, 0.25, 0.4, 0.7 }, Pose = function(role, i)
				if i == 1 or i == 4 then return CFrame.new() end
				local crouch = i == 2
				if role == "body" then return crouch and CFrame.new(0, -0.3, 0) * A(rad(10), 0, 0) or CFrame.new(0, 0.8, -0.4) * A(rad(-25), 0, 0) end
				if role == "legA" or role == "legB" then return A(rad(crouch and 30 or -20), 0, 0) end
				if role == "head" then return A(rad(crouch and 10 or -20), 0, 0) end
				return nil
			end }
		elseif kind == "Dive" then
			return { Length = 0.9, Loop = false, Priority = Enum.AnimationPriority.Action, Times = { 0, 0.3, 0.5, 0.9 }, Pose = function(role, i)
				if i == 1 or i == 4 then return CFrame.new() end
				local rise = i == 2
				if role == "body" then return rise and CFrame.new(0, 0.5, 0) * A(rad(15), 0, 0) or A(rad(-35), 0, 0) end
				if role == "armL" or role == "armR" then return A(rad(rise and -40 or 85), 0, 0) end
				if role == "head" then return A(rad(rise and 15 or -20), 0, 0) end
				if role == "tail" then return A(rad(rise and -20 or 25), 0, 0) end
				return nil
			end }
		end
		return nil -- default lunge/bite (CLIPS.Ability1)
	end
	return nil
end

local function sequence(model: Model, clipName: string, gaitName: string?): KeyframeSequence
	local clip = gaitClip(clipName, gaitName) or CLIPS[clipName]
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

local function gaitOf(typeName: string): string?
	local def = require(game:GetService("ReplicatedStorage").Shared.MonsterDefs).Types[typeName]
	return def and def.Gait
end

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
			return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence(model, name, gaitOf(typeName)))
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
			sequence(model, name, def.Gait).Parent = folder
		end
		model:Destroy()
	end
	folder.Parent = game:GetService("ServerStorage")
	print("[MonsterAnims] exported " .. #folder:GetChildren() .. " KeyframeSequences to ServerStorage.MonsterAnimExport")
end

return MonsterAnims
