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
	task.spawn(function()
		for _, d in game:GetDescendants() do
			pcall(check, d, id, where)
		end
		local conn = game.DescendantAdded:Connect(function(d)
			pcall(check, d, id, where)
		end)
		task.wait(seconds or 60)
		conn:Disconnect()
		print(`[AssetProbe] {where}: finished watching {id}`)
	end)
end

return AssetProbe
