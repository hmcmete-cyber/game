-- v2.42 spins the cloud vortex around the updraft (Map/Decor/UpdraftVortex).
-- Strands 1-3 turn one way (each a bit faster higher up), the wispy rings
-- (Strand 0) turn the other way. Purely visual, local to each client.

local RunService = game:GetService("RunService")

local VortexFx = {}

function VortexFx.Start()
	local map = workspace:WaitForChild("Map")
	local vortex
	for _ = 1, 120 do
		vortex = map:FindFirstChild("UpdraftVortex", true)
		if vortex then
			break
		end
		task.wait(1)
	end
	if not vortex then
		return
	end
	task.wait(1) -- let every puff replicate
	local parts, base, speed = {}, {}, {}
	for _, p in vortex:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Strand") then
			table.insert(parts, p)
			table.insert(base, p.CFrame)
			local strand = p:GetAttribute("Strand")
			local up = math.clamp((p.Position.Y - 40) / 160, 0, 1)
			table.insert(speed, strand == 0 and -0.35 or (0.5 + up * 0.5))
		end
	end
	local cfs = table.create(#parts)
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam or (cam.CFrame.Position - Vector3.new(0, 120, 0)).Magnitude > 900 then
			return
		end
		t += dt
		for i, cf in base do
			cfs[i] = CFrame.Angles(0, t * speed[i], 0) * cf
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return VortexFx
