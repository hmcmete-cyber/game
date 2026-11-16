-- Client entry point. Each feature lives in its own module next to this script.

local Hud = require(script.Parent:WaitForChild("Hud"))
local Movement = require(script.Parent:WaitForChild("Movement"))
local FloatingIslands = require(script.Parent:WaitForChild("FloatingIslands"))

Hud.Start()
Movement.Start()
FloatingIslands.Start()
