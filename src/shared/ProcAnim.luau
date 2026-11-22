-- v2.32 PROCEDURAL ANIMATION PLAYER (live-server fix).
-- Our animations are generated as KeyframeSequences in code. Roblox only lets
-- KeyframeSequenceProvider:RegisterKeyframeSequence work in STUDIO, so in a
-- published game monsters, NPCs and player moves stood frozen. This plays the
-- same KeyframeSequences by writing Motor6D.Transform every frame, so no
-- animation upload is needed.
--
--   local clip = ProcAnim.Compile(keyframeSequence)
--   local track = ProcAnim.Track(model, clip)   -- AnimationTrack-like:
--   track:Play(fade?, weight?, speed?)  track:Stop(fade?)  track:AdjustSpeed(s)
--   track.IsPlaying  track.Looped  track.Length  track.Hold (keep last frame)
--
-- Runs after Roblox's own animation step (RunService.Stepped), blending on top
-- of whatever the Animator produced (default walk etc.), joint by joint.
-- Note: Transform written on a client is only seen by that client.

local RunService = game:GetService("RunService")

local ProcAnim = {}

-- ---------------------------------------------------------------- compile
function ProcAnim.Compile(seq: KeyframeSequence)
	local frames = {}
	for _, kf in seq:GetChildren() do
		if kf:IsA("Keyframe") then
			table.insert(frames, kf)
		end
	end
	table.sort(frames, function(a, b)
		return a.Time < b.Time
	end)
	local joints = {} -- [partName] = { T = {}, CF = {}, Linear = bool }
	local length = 0
	for _, kf in frames do
		length = math.max(length, kf.Time)
		local function walk(pose: Instance)
			for _, p in pose:GetChildren() do
				if p:IsA("Pose") then
					if p.Weight > 0 then
						local j = joints[p.Name]
						if not j then
							j = { T = {}, CF = {}, Linear = p.EasingStyle == Enum.PoseEasingStyle.Linear }
							joints[p.Name] = j
						end
						table.insert(j.T, kf.Time)
						table.insert(j.CF, p.CFrame)
					end
					walk(p)
				end
			end
		end
		walk(kf)
	end
	return { Length = math.max(length, 0.05), Loop = seq.Loop, Priority = seq.Priority.Value, Joints = joints, Name = seq.Name }
end

-- plain-text form (JSON) so clips reach every client for sure (a StringValue
-- always replicates; runtime KeyframeSequences might not)
local HttpService = game:GetService("HttpService")
local function r4(x: number): number
	return math.floor(x * 10000 + 0.5) / 10000
end
function ProcAnim.Serialize(clip): string
	local j = {}
	for name, data in clip.Joints do
		local cfs = {}
		for _, cf in data.CF do
			for _, v in { cf:GetComponents() } do
				table.insert(cfs, r4(v))
			end
		end
		j[name] = { T = data.T, C = cfs, L = data.Linear }
	end
	return HttpService:JSONEncode({ Len = clip.Length, Loop = clip.Loop, Pri = clip.Priority, Name = clip.Name, J = j })
end
function ProcAnim.Deserialize(text: string)
	local ok, d = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if not ok or type(d) ~= "table" then
		return nil
	end
	local joints = {}
	for name, data in d.J or {} do
		local cfs = {}
		for i = 1, #data.C, 12 do
			table.insert(cfs, CFrame.new(table.unpack(data.C, i, i + 11)))
		end
		joints[name] = { T = data.T, CF = cfs, Linear = data.L == true }
	end
	return { Length = d.Len or 1, Loop = d.Loop == true, Priority = d.Pri or 0, Joints = joints, Name = d.Name }
end

local function smooth(f: number): number
	return f * f * (3 - 2 * f) -- cubic in-out
end

local function sample(j, t: number): CFrame
	local T, CF = j.T, j.CF
	local n = #T
	if n == 1 or t <= T[1] then
		return CF[1]
	end
	if t >= T[n] then
		return CF[n]
	end
	for i = 1, n - 1 do
		if t <= T[i + 1] then
			local span = T[i + 1] - T[i]
			local f = span > 0 and (t - T[i]) / span or 1
			return CF[i]:Lerp(CF[i + 1], j.Linear and f or smooth(f))
		end
	end
	return CF[n]
end

-- ---------------------------------------------------------------- tracks
local active = {} -- [Model] = { tracks }
local motorsCache = setmetatable({}, { __mode = "k" }) -- [Model] = { [partName] = Motor6D }

local motorsAt = setmetatable({}, { __mode = "k" })
local function motorsOf(model: Model)
	local m = motorsCache[model]
	-- rebuild every second: StreamingEnabled can re-create a model's parts
	if not m or os.clock() - (motorsAt[model] or 0) > 1 then
		m = {}
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and d.Part1 then
				m[d.Part1.Name] = d
			end
		end
		motorsCache[model] = m
		motorsAt[model] = os.clock()
	end
	return m
end
function ProcAnim.Refresh(model: Model)
	motorsCache[model] = nil
end

-- models animated ONLY by us (no Animator tracks): blend from the rest pose
-- and put joints back to rest when no clip moves them any more
local owned = setmetatable({}, { __mode = "k" })
local touched = setmetatable({}, { __mode = "k" })
function ProcAnim.Own(model: Model)
	owned[model] = true
end

local Track = {}
Track.__index = Track

function ProcAnim.Track(model: Model, clip)
	return setmetatable({
		Model = model, Clip = clip, Length = clip.Length, Looped = clip.Loop, Priority = clip.Priority or 0,
		IsPlaying = false, TimePosition = 0, Speed = 1, Weight = 0, Target = 0, Fade = 0.1, Hold = false,
	}, Track)
end

function Track:Play(fade: number?, weight: number?, speed: number?)
	self.TimePosition = 0
	self.Target = weight or 1
	self.Fade = math.max(fade or 0.1, 0.001)
	self.Speed = speed or self.Speed or 1
	self.IsPlaying = true
	self.Stopping = false
	local list = active[self.Model]
	if not list then
		list = {}
		active[self.Model] = list
	end
	if not table.find(list, self) then
		table.insert(list, self)
	end
end

function Track:Stop(fade: number?)
	self.Target = 0
	self.Fade = math.max(fade or 0.1, 0.001)
	self.Stopping = true
	self.IsPlaying = false
end

function Track:AdjustSpeed(s: number)
	self.Speed = s
end

function Track:Destroy()
	self:Stop(0)
	self.Weight = 0
end

local function step(dt: number)
	for model, list in active do
		if not model.Parent then
			active[model] = nil
			continue
		end
		-- advance time + weights
		for i = #list, 1, -1 do
			local tr = list[i]
			local rate = dt / tr.Fade
			if tr.Weight < tr.Target then
				tr.Weight = math.min(tr.Target, tr.Weight + rate)
			elseif tr.Weight > tr.Target then
				tr.Weight = math.max(tr.Target, tr.Weight - rate)
			end
			if not tr.Stopping then
				tr.TimePosition += dt * tr.Speed
				if tr.TimePosition >= tr.Length then
					if tr.Looped then
						tr.TimePosition %= tr.Length
					elseif tr.Hold then
						tr.TimePosition = tr.Length
					else
						tr.TimePosition = tr.Length
						tr:Stop(0.15)
					end
				end
			end
			if tr.Stopping and tr.Weight <= 0 then
				table.remove(list, i)
			end
		end
		if #list == 0 then
			active[model] = nil
			if owned[model] and touched[model] then
				local motors = motorsOf(model)
				for name in touched[model] do
					if motors[name] then
						motors[name].Transform = CFrame.new()
					end
				end
				touched[model] = nil
			end
			continue
		end
		-- blend: lower priority first, higher priority on top
		table.sort(list, function(a, b)
			return a.Priority < b.Priority
		end)
		local motors = motorsOf(model)
		local out = {}
		for _, tr in list do
			if tr.Weight > 0 then
				for name, j in tr.Clip.Joints do
					local motor = motors[name]
					if motor then
						local base = out[name] or (owned[model] and CFrame.new() or motor.Transform)
						out[name] = base:Lerp(sample(j, tr.TimePosition), tr.Weight)
					end
				end
			end
		end
		for name, cf in out do
			local motor = motors[name]
			if motor and motor.Parent then
				motor.Transform = cf
			end
		end
		if owned[model] then
			local prev = touched[model]
			if prev then
				for name in prev do
					if not out[name] and motors[name] then
						motors[name].Transform = CFrame.new()
					end
				end
			end
			touched[model] = out
		end
	end
end

RunService.Stepped:Connect(function(_, dt)
	step(dt)
end)

return ProcAnim
