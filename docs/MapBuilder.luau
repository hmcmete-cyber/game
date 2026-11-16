--[[
	Pocket Storm — save the placeholder map into your place (Studio Command Bar)

	1. Rojo connected (so ServerScriptService.Server exists), Studio in EDIT mode.
	2. Open the Command Bar (Ctrl+P → "Command Bar"), paste the line below, Enter.
	3. File → Save to File.

	It builds exactly the same map the game builds at runtime when workspace.Map
	is missing: start pad, storm hunt zone, shortcut route (water gap + lift
	platform), long detour, central walkway and 6 hexagon floating bases
	(metal/glass deck, rock underside, glowing rim, 2 spinning energy rings,
	Nest + 4 Containment Spheres each), plus decorative floating islands.

	Safe: if workspace.Map already exists it does nothing. Inserts no scripts.
	The bases are built by ServerScriptService.Server.Services.BaseBuilder —
	you can also call BaseBuilder.Build(parent, "Rooftop7", topPosition, accentColor)
	to add more bases by hand.
]]

print(require(game.ServerScriptService.Server.Services.MapService).BuildPlaceholder():GetFullName())
