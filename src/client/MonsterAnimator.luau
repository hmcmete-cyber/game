-- v2.32 Monster animations for PUBLISHED games. Outside Studio the server
-- can't register our generated clips, so it publishes the KeyframeSequences in
-- ReplicatedStorage.MonsterAnimSeqs and marks monsters with ProcAnim. Here
-- every client plays them with Shared/ProcAnim:
--   Idle always (base), Walk when the monster really moves (speed-scaled),
--   one-shots (Ability1/2, Hit, Death) from the AnimClip / AnimAt attributes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProcAnim = require(ReplicatedStorage.Shared.ProcAnim)

local MonsterAnimator = {}

local clipCache = {} -- ["Type_Clip"] = compiled clip | false
local states = {} -- [Model] = state
local RANGE = 260 -- only animate monsters near the camera

local function clip(typeName: string, name: string)
	local key = typeName .. "_" .. name
	if clipCache[key] == nil then
		local folder = ReplicatedStorage:FindFirstChild("MonsterAnimSeqs")
		local seq = folder and folder:FindFirstChild(key)
		clipCache[key] = seq and ProcAnim.Compile(seq) or false
	end
	return clipCache[key] or nil
end

local function setup(model: Model)
	if states[model] or not model:GetAttribute("ProcAnim") then
		return
	end
	local typeName = model:GetAttribute("MonsterType") or model.Name
	local idle = clip(typeName, "Idle")
	if not idle then
		return -- clips not replicated yet; retried by the loop below
	end
	ProcAnim.Own(model)
	local st = { Model = model, Type = typeName, Tracks = {}, LastAt = model:GetAttribute("AnimAt") or 0, Root = model:FindFirstChild("HumanoidRootPart") }
	local function track(name: string)
		if st.Tracks[name] == nil then
			local c = clip(typeName, name)
			st.Tracks[name] = c and ProcAnim.Track(model, c) or false
			if name == "Death" and st.Tracks[name] then
				st.Tracks[name].Hold = true
			end
		end
		return st.Tracks[name] or nil
	end
	st.Track = track
	local i = track("Idle")
	if i then
		i.Looped = true
		i:Play(0.3)
	end
	-- one-shots from the server
	model:GetAttributeChangedSignal("AnimAt"):Connect(function()
		local name = model:GetAttribute("AnimClip")
		local t = name and track(name)
		if t then
			t.Priority = name == "Death" and 4 or 3
			t:Play(0.08)
			if name == "Death" then
				local w = st.Tracks.Walk
				if w then
					w:Stop(0.1)
				end
			end
		end
	end)
	states[model] = st
end

function MonsterAnimator.Start()
	for _, m in CollectionService:GetTagged("Monster") do
		task.spawn(setup, m)
	end
	CollectionService:GetInstanceAddedSignal("Monster"):Connect(function(m)
		task.delay(0.2, setup, m)
	end)
	-- locomotion: Walk while the monster really moves (positions replicate)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local cam = workspace.CurrentCamera
			for _, m in CollectionService:GetTagged("Monster") do
				if not states[m] and m:GetAttribute("ProcAnim") then
					setup(m)
				end
			end
			for model, st in states do
				if not model.Parent then
					states[model] = nil
					continue
				end
				local root = st.Root
				if not root or not root.Parent then
					continue
				end
				local pos = root.Position
				local far = cam and (cam.CFrame.Position - pos).Magnitude > RANGE
				local speed = 0
				if st.LastPos then
					local d = pos - st.LastPos
					speed = Vector2.new(d.X, d.Z).Magnitude / 0.1
				end
				st.LastPos = pos
				local walk = st.Track("Walk")
				local dead = st.Tracks.Death and st.Tracks.Death.IsPlaying
				local moving = speed > 1.5 and not far and not dead
				if walk then
					if moving and not walk.IsPlaying then
						walk.Looped = true
						walk.Priority = 1
						walk:Play(0.15)
					elseif not moving and walk.IsPlaying then
						walk:Stop(0.25)
					end
					if moving then
						local def = require(ReplicatedStorage.Shared.MonsterDefs).Types[st.Type]
						walk:AdjustSpeed(math.clamp(speed / math.max(def and def.Speed or 12, 1), 0.6, 1.6))
					end
				end
			end
		end
	end)
end

return MonsterAnimator
