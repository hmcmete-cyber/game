-- Client entry point. Each feature lives in its own module next to this script.

local Hud = require(script.Parent:WaitForChild("Hud"))
local Movement = require(script.Parent:WaitForChild("Movement"))
local FloatingIslands = require(script.Parent:WaitForChild("FloatingIslands"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local InventoryUi = require(script.Parent:WaitForChild("InventoryUi"))
local Prompts = require(script.Parent:WaitForChild("Prompts"))

Hud.Start()
Movement.Start()
FloatingIslands.Start()
Effects.Start()
InventoryUi.Start()
Prompts.Start()
