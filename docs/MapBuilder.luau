--[[
	Steal a Cloud — save the generated map into your place (Studio Command Bar)

	1. Rojo connected, Studio in EDIT mode.
	2. Open the Command Bar (View → Command Bar), paste the LINE below, Enter.
	3. File → Save (Ctrl+S).

	It builds exactly the map the game builds at runtime (Hexagon Hub, 12 bases,
	updraft, Floating Continent, death clouds) and stamps it with MapVersion.
	If workspace.Map is an OLDER generated map it is replaced; if it is the
	current version it is kept. A hand-decorated map is protected: give it the
	attribute Custom = true and nothing will ever replace it.

	The line looks for the Rojo *Folder* named "Server" on purpose: an old
	Rojo-template *Script* also named "Server" may still exist and shadow it.
]]

local s = game.ServerScriptService:GetChildren() local f for _, c in s do if c.Name == "Server" and c:IsA("Folder") then f = c end end print(require(f.Services.MapService).BuildPlaceholder():GetFullName(), f and "ok")

--[[
	One-time cleanup of the old Rojo "Hello world" template (EDIT mode, Command Bar).
	Deletes ONLY empty leftover scripts named Server / Client / Shared that are not
	Rojo folders, then prints what it removed. Save the place afterwards.
]]

for _, root in { game.ServerScriptService, game.StarterPlayer.StarterPlayerScripts, game.ReplicatedStorage } do for _, c in root:GetChildren() do if (c.Name == "Server" or c.Name == "Client" or c.Name == "Shared") and c:IsA("LuaSourceContainer") then print("removed", c:GetFullName()) c:Destroy() end end end
