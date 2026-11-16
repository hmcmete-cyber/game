-- Makes anything tagged "FloatingIsland" gently drift up and down.
--
-- Tag a Model or Part in Studio (Properties → Tags → "FloatingIsland").
-- Optional attributes on the tagged object:
--   FloatAmplitude (number, studs, default 1.2)
--   FloatSpeed     (number, default 0.6)
--   FloatSpin      (number, rad/s around Y, default 0 = gentle tilt only)
--
-- Runs on the client only, so it's smooth and costs the server nothing.
-- Use it for decoration (islands, clouds, rocks), not for platforms the
-- game logic depends on (Nests, LiftPlatforms, WaterGaps).
--
-- Why not TweenService? Tweens can't move a whole Model's pivot, and one
-- RenderStepped loop over all islands is cheaper than hundreds of tweens.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local FloatingIslands = {}

local TAG = "FloatingIsland"
local floaters = {} -- [Instance] = { Base: CFrame, Phase, Amp, Speed }

local function add(inst: Instance)
	if not (inst:IsA("Model") or inst:IsA("BasePart")) then
		return
	end
	floaters[inst] = {
		Base = (inst :: any):GetPivot(),
		Phase = math.random() * math.pi * 2,
		Amp = inst:GetAttribute("FloatAmplitude") or 1.2,
		Speed = inst:GetAttribute("FloatSpeed") or 0.6,
		Spin = inst:GetAttribute("FloatSpin") or 0,
	}
end

function FloatingIslands.Start()
	for _, inst in CollectionService:GetTagged(TAG) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		floaters[inst] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for inst, f in floaters do
			if not inst.Parent then
				floaters[inst] = nil
				continue
			end
			local y = math.sin(t * f.Speed + f.Phase) * f.Amp
			local tilt = math.sin(t * f.Speed * 0.5 + f.Phase) * 0.02
			;(inst :: any):PivotTo(f.Base * CFrame.new(0, y, 0) * CFrame.Angles(tilt, t * f.Spin, tilt * 0.5))
		end
	end)
end

return FloatingIslands
