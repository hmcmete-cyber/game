-- Studio-only helper: finds which object uses a given asset id at RUNTIME
-- (scans now + watches new objects for 60 s). Prints "[AssetProbe] ..." lines.
-- Started automatically in Studio for the id Astra reported.

local RunService = game:GetService("RunService")

local AssetProbe = {}

local PROPS = {
	"SoundId", "Texture", "TextureId", "TextureID", "MeshId", "Image", "AnimationId", "ColorMap", "ShirtTemplate",
	"PantsTemplate", "Graphic", "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId",
	"MoonTextureId", "Face", "Head", "Shirt", "Pants", "GraphicTShirt", "Torso", "LeftArm", "RightArm", "LeftLeg",
	"RightLeg", "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation",
	"SwimAnimation", "HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory", "ShouldersAccessory",
	"FrontAccessory", "BackAccessory", "WaistAccessory", "CursorIcon", "HoverImage", "PressedImage", "ImageContent",
}

local function check(inst: Instance, id: string, where: string)
	for _, prop in PROPS do
		local ok, v = pcall(function()
			return (inst :: any)[prop]
		end)
		if ok and v ~= nil and string.find(tostring(v), id, 1, true) then
			print(`[AssetProbe] {where}: {id} used by {inst:GetFullName()} ({inst.ClassName}).{prop}`)
		end
	end
end

function AssetProbe.Watch(id: string, seconds: number?)
	if not RunService:IsStudio() then
		return
	end
	local where = RunService:IsServer() and "SERVER" or "CLIENT"
	task.defer(function()
		task.wait(5) -- let the game start first; never block startup
		-- scan service by service: some (CoreGui etc.) are locked and would error
		local conns = {}
		for _, svc in game:GetChildren() do
			pcall(function()
				for i, d in svc:GetDescendants() do
					pcall(check, d, id, where)
					if i % 300 == 0 then
						task.wait() -- spread the scan over frames
					end
				end
				table.insert(conns, svc.DescendantAdded:Connect(function(d)
					pcall(check, d, id, where)
				end))
			end)
		end
		task.wait(seconds or 60)
		for _, c in conns do
			c:Disconnect()
		end
		print(`[AssetProbe] {where}: finished watching {id}`)
	end)
end

return AssetProbe
