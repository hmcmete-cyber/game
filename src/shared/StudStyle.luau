-- v2.9 CLASSIC STUD STYLE EVERYWHERE (director: every surface of every part,
-- tiny or huge, monsters included, must show the classic Roblox stud tile).
--
-- Two layers:
--  1. Surfaces: every block / wedge / corner wedge gets Studs on ALL six
--     faces and Plastic material. Works right away, no assets needed, but
--     Roblox only draws surface studs on flat faces of blocks and wedges.
--  2. Stud tile MaterialVariant "ClassicStuds" overriding Plastic: puts the
--     stud tile texture on EVERY Plastic part, including balls, cylinders,
--     mesh-shaped cloud lobes and curved monster parts. Needs the two images
--     in assets/textures uploaded to Roblox; paste their ids below.
--     (Upload: Studio > Asset Manager > Images > Bulk Import, or Create >
--     Decals; copy each Image id.) Empty ids = layer 2 is skipped.
--
-- Skipped on purpose: player avatars, Neon (glow), Glass (crystals),
-- ForceField, Glacier (ice hazard look), invisible parts.

local Players = game:GetService("Players")
local MaterialService = game:GetService("MaterialService")

local StudStyle = {}

StudStyle.ColorMap = "" -- e.g. "rbxassetid://123" (assets/textures/stud_color.png)
StudStyle.NormalMap = "" -- e.g. "rbxassetid://456" (assets/textures/stud_normal.png)
StudStyle.StudsPerTile = 4 -- the images hold 4 x 4 studs

local KEEP = {
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.Glacier] = true,
}
local FACES = { "Top", "Bottom", "Front", "Back", "Left", "Right" }

local function isAvatar(inst: Instance): boolean
	if inst:FindFirstAncestorOfClass("Accessory") then
		return true
	end
	local model = inst:FindFirstAncestorOfClass("Model")
	while model do
		if Players:GetPlayerFromCharacter(model) or (model:FindFirstChildOfClass("Humanoid") and Players:FindFirstChild(model.Name)) then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

function StudStyle.Apply(p: Instance)
	if not p:IsA("BasePart") or p:IsA("Terrain") or p.Transparency >= 0.95 or isAvatar(p) then
		return
	end
	if not KEEP[p.Material] then
		p.Material = Enum.Material.Plastic
	end
	if p:IsA("Part") or p:IsA("WedgePart") or p:IsA("CornerWedgePart") or p:IsA("TrussPart") then
		for _, f in FACES do
			(p :: any)[f .. "Surface"] = Enum.SurfaceType.Studs
		end
	end
end

function StudStyle.ApplyTree(root: Instance)
	if root:IsA("BasePart") then
		StudStyle.Apply(root)
	end
	for _, d in root:GetDescendants() do
		StudStyle.Apply(d)
	end
end

-- Creates the stud tile MaterialVariant and makes it the look of Plastic.
-- Safe to call on server and client (the client call keeps the override
-- even if it did not replicate).
function StudStyle.SetupMaterial()
	if StudStyle.ColorMap == "" then
		return false
	end
	local v = MaterialService:FindFirstChild("ClassicStuds")
	if not v then
		if game:GetService("RunService"):IsClient() then
			v = MaterialService:WaitForChild("ClassicStuds", 10)
			if not v then
				return false
			end
		else
			v = Instance.new("MaterialVariant")
			v.Name = "ClassicStuds"
			v.BaseMaterial = Enum.Material.Plastic
			v.ColorMap = StudStyle.ColorMap
			if StudStyle.NormalMap ~= "" then
				v.NormalMap = StudStyle.NormalMap
			end
			v.StudsPerTile = StudStyle.StudsPerTile
			v.Pattern = Enum.MaterialPattern.Regular
			v.Parent = MaterialService
		end
	end
	local ok, err = pcall(function()
		MaterialService:SetBaseMaterialOverride(Enum.Material.Plastic, "ClassicStuds")
	end)
	if not ok then
		warn("[StudStyle] material override failed: " .. tostring(err))
	end
	return ok
end

-- Server: style everything in workspace now and every part added later
-- (monsters, clouds, NPCs, bases, effects).
function StudStyle.Watch()
	StudStyle.ApplyTree(workspace)
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			StudStyle.Apply(d)
		end
	end)
end

return StudStyle
