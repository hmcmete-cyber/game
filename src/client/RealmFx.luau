-- v2.42 inside a totem realm (sealed cube, no sky): the room would be lit by
-- the outdoor Ambient only, so while you stand inside one we hold
-- Lighting.Ambient at the realm's own value (the server's day cycle rewrites
-- it 4x/s, so it is re-applied every frame) and tint the screen a little.
-- Leaving restores the last outdoor value.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RealmFx = {}

function RealmFx.Start()
	local player = Players.LocalPlayer
	local realms = workspace:WaitForChild("Realms", 60)
	if not realms then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "RealmTint"
	cc.Enabled = false
	cc.Parent = Lighting
	local inside: Model? = nil
	local outdoorAmbient = Lighting.Ambient

	-- realm models can stream out; keep their boxes from the attributes
	local boxes = {}
	local function track(m: Instance)
		if m:IsA("Model") and m:GetAttribute("RealmCenter") then
			boxes[m] = { m:GetAttribute("RealmCenter"), m:GetAttribute("RealmSize"), m:GetAttribute("RealmAmbient"), m:GetAttribute("RealmTint") }
		end
	end
	for _, m in realms:GetChildren() do
		track(m)
	end
	realms.ChildAdded:Connect(track)

	RunService.RenderStepped:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local now: Model? = nil
		local box
		if root then
			for m, b in boxes do
				local d = root.Position - b[1]
				if math.abs(d.X) < b[2].X / 2 and math.abs(d.Y) < b[2].Y / 2 and math.abs(d.Z) < b[2].Z / 2 then
					now, box = m, b
					break
				end
			end
		end
		if now ~= inside then
			if now and not inside then
				outdoorAmbient = Lighting.Ambient
			elseif not now then
				Lighting.Ambient = outdoorAmbient
				cc.Enabled = false
			end
			inside = now
		end
		if inside and box then
			Lighting.Ambient = box[3]
			cc.TintColor = box[4]
			cc.Saturation = 0.12
			cc.Enabled = true
		end
	end)
end

return RealmFx
