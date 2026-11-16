-- Loads animations by name: published id from Animations.luau if set,
-- otherwise builds a KeyframeSequence from AnimationData and registers it
-- (KeyframeSequenceProvider works in Studio; returns nil where not allowed).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Ids = require(script.Parent:WaitForChild("Animations"))
local Data = require(script.Parent:WaitForChild("AnimationData"))

local AnimLib = {}

local PARENT = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
	RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
	LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
}

function AnimLib.Sequence(name: string): KeyframeSequence?
	local def = Data[name]
	if not def then
		return nil
	end
	-- parts animated anywhere in this sequence (weight 1) + their ancestors (weight 0)
	local keyed, need = {}, { HumanoidRootPart = true }
	for _, frame in def.Frames do
		for part in frame[2] do
			keyed[part] = true
			local p = part
			while p do
				need[p] = true
				p = PARENT[p]
			end
		end
	end

	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Loop = def.Loop
	seq.Priority = Enum.AnimationPriority[def.Priority]
	for _, frame in def.Frames do
		local kf = Instance.new("Keyframe")
		kf.Time = frame[1]
		local poses = {}
		local function getPose(part: string): Pose
			if poses[part] then
				return poses[part]
			end
			local pose = Instance.new("Pose")
			pose.Name = part
			pose.Weight = keyed[part] and 1 or 0
			pose.EasingStyle = Enum.PoseEasingStyle.CubicV2
			pose.EasingDirection = Enum.PoseEasingDirection.InOut
			local v = frame[2][part]
			if v then
				pose.CFrame = CFrame.new(v[4], v[5], v[6]) * CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
			end
			pose.Parent = PARENT[part] and getPose(PARENT[part]) or kf
			poses[part] = pose
			return pose
		end
		for part in need do
			getPose(part)
		end
		kf.Parent = seq
	end
	return seq
end

local cache = {}
function AnimLib.Id(name: string): string?
	local id = Ids[name]
	if id and id ~= "" then
		return id
	end
	if cache[name] == nil then
		local ok, res = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(AnimLib.Sequence(name))
		end)
		cache[name] = ok and res or false
	end
	return cache[name] or nil
end

function AnimLib.Load(animator: Animator, name: string): AnimationTrack?
	local id = AnimLib.Id(name)
	if not id then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	return ok and track or nil
end

return AnimLib
