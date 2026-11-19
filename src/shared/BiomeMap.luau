-- ONE source of truth for "which habitat is this spot in" on the Floating
-- Continent. The map builder uses it to lay out the terrain and the client /
-- server use it whenever the ground under someone is Terrain (which has no
-- attributes). Pure math: same answer on server and client.
--
-- Layout is authored in v1.4 units (heart 16-70, habitats 70-262, coast
-- 262-314). R() stretches them to studs (heart 16-110, habitats 110-590,
-- coast 590-680) and Wr() bends the outline by angle (coast ~555-805).
-- Habitats are six 60° sectors whose borders wander with distance (wobble).

local BiomeMap = {}

BiomeMap.UP = 320 -- continent top (v2.4: raised from 200)
BiomeMap.HEART = 70 -- authoring radius of the heart edge
BiomeMap.COAST = 262 -- authoring radius where the coast begins
BiomeMap.EDGE = 314 -- authoring radius of the outer shoreline

function BiomeMap.R(r: number): number
	if r <= 70 then
		return 16 + (r - 16) * (94 / 54)
	elseif r <= 262 then
		return 110 + (r - 70) * (480 / 192)
	end
	return 590 + (r - 262) * (90 / 52)
end

-- inverse of R (studs -> authoring units)
function BiomeMap.Rinv(s: number): number
	if s <= 110 then
		return 16 + (s - 16) * (54 / 94)
	elseif s <= 590 then
		return 70 + (s - 110) * (192 / 480)
	end
	return 262 + (s - 590) * (52 / 90)
end

function BiomeMap.Warp(deg: number): number
	local t = math.rad(deg)
	return 1 + 0.09 * math.sin(3 * t + 0.7) + 0.05 * math.sin(5 * t + 2.1) + 0.03 * math.sin(9 * t + 4.0) + 0.015 * math.sin(17 * t + 1.3)
end

-- studs -> warped studs (the heart stays round, the bend grows outward)
function BiomeMap.Wr(r: number, deg: number): number
	local k = math.clamp((r - 110) / 480, 0, 1)
	return r * (1 + (BiomeMap.Warp(deg) - 1) * k)
end

-- warped studs -> unwarped studs (fixed-point; converges in a few steps)
function BiomeMap.Unwarp(rw: number, deg: number): number
	local r = rw
	for _ = 1, 6 do
		local k = math.clamp((r - 110) / 480, 0, 1)
		r = rw / (1 + (BiomeMap.Warp(deg) - 1) * k)
	end
	return r
end

function BiomeMap.Wobble(deg: number, rOld: number): number
	return (deg + 11 * math.sin(rOld / 19 + 1.7) + 6 * math.sin(rOld / 7.3 + deg * 0.05)) % 360
end

function BiomeMap.Sector(deg: number): string
	deg %= 360
	if deg >= 330 or deg < 30 then
		return "Plateau"
	elseif deg < 90 then
		return "Mountains"
	elseif deg < 150 then
		return "Mushroom"
	elseif deg < 210 then
		return "Marsh"
	elseif deg < 270 then
		return "Canyon"
	end
	return "Volcanic"
end

-- habitat at an authoring radius + angle (Heart / Coast / sector)
function BiomeMap.HabitatAt(deg: number, rOld: number): string
	if rOld < BiomeMap.HEART then
		return "Heart"
	elseif rOld >= BiomeMap.COAST then
		return "Coast"
	end
	return BiomeMap.Sector(BiomeMap.Wobble(deg % 360, rOld))
end

-- world position -> deg, authoring radius
function BiomeMap.Polar(pos: Vector3): (number, number)
	local deg = math.deg(math.atan2(pos.Z, pos.X)) % 360
	local rw = Vector2.new(pos.X, pos.Z).Magnitude
	return deg, BiomeMap.Rinv(BiomeMap.Unwarp(rw, deg))
end

BiomeMap.Zones = {
	Heart = { ZoneName = "Sky Heart", ZoneColor = Color3.fromRGB(190, 235, 255), Biome = "Plateau" },
	Plateau = { ZoneName = "Plateau Meadows", ZoneColor = Color3.fromRGB(150, 230, 150), Biome = "Plateau" },
	Mountains = { ZoneName = "Mountains", ZoneColor = Color3.fromRGB(210, 220, 235), Biome = "Mountains" },
	Mushroom = { ZoneName = "Mushroom Plateaus", ZoneColor = Color3.fromRGB(230, 150, 220), Biome = "Mushroom" },
	Marsh = { ZoneName = "Storm Marshes", ZoneColor = Color3.fromRGB(140, 190, 170), Biome = "Marsh" },
	Canyon = { ZoneName = "Crystal Canyons", ZoneColor = Color3.fromRGB(190, 140, 255), Biome = "Canyon" },
	Volcanic = { ZoneName = "Volcanic Caldera", ZoneColor = Color3.fromRGB(255, 140, 90), Biome = "Volcanic" },
	Coast = { ZoneName = "Coast", ZoneColor = Color3.fromRGB(255, 225, 160), Biome = "Coast" },
}

-- Zone info for a world position on the continent (nil if far below / outside)
function BiomeMap.ZoneAt(pos: Vector3)
	if pos.Y < BiomeMap.UP - 40 then
		return nil
	end
	local deg, rOld = BiomeMap.Polar(pos)
	if rOld > BiomeMap.EDGE + 4 then
		return nil
	end
	return BiomeMap.Zones[BiomeMap.HabitatAt(deg, rOld)]
end

-- Zone info for a raycast hit: the part's own attributes, or the map for Terrain
function BiomeMap.ZoneOfHit(hit: RaycastResult?)
	if not hit then
		return nil
	end
	local inst: Instance? = hit.Instance
	if inst and inst:IsA("Terrain") then
		return BiomeMap.ZoneAt(hit.Position)
	end
	while inst and inst ~= workspace do
		if inst:GetAttribute("ZoneName") or inst:GetAttribute("Biome") then
			return {
				ZoneName = inst:GetAttribute("ZoneName"),
				ZoneColor = inst:GetAttribute("ZoneColor"),
				Biome = inst:GetAttribute("Biome"),
				Warning = inst:GetAttribute("Warning"),
			}
		end
		inst = inst.Parent
	end
	return nil
end

return BiomeMap
