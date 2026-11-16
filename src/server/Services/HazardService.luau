-- Hazard zones (Map/Hazards/*, attribute HazardType):
--   "Ice"      slippery: you lose control (handled on the client, Movement.luau)
--   "Electric" swamp: slows you (client) and hurts you every ElectricInterval (here)
-- Carrying a cloud makes both worse. A Storm Charm makes you immune to Electric.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HazardService = {}

local MapService

-- Is a position standing on/inside a hazard part?
function HazardService.Inside(hazard: BasePart, pos: Vector3): boolean
	local rel = hazard.CFrame:PointToObjectSpace(pos)
	local half = hazard.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and rel.Y > -2 and rel.Y < 6
end

local function loop()
	while true do
		task.wait(Config.ElectricInterval)
		local hazards = MapService.GetHazards()
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("ElectricImmune") then
				continue
			end
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not root or not hum or hum.Health <= 0 then
				continue
			end
			for _, hazard in hazards do
				if hazard:GetAttribute("HazardType") == "Electric" and HazardService.Inside(hazard, root.Position) then
					local carrying = player:GetAttribute("Carrying") ~= nil
					hum:TakeDamage(carrying and Config.ElectricDamageCarrying or Config.ElectricDamage)
					break
				end
			end
		end
	end
end

function HazardService.Start(mapService)
	MapService = mapService
	task.spawn(loop)
end

return HazardService
