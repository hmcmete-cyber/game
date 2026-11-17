-- QA panel for testers (Studio only — never shows in a live game).
-- Press F8 or click "QA" (bottom-left). Every button prints a line to the
-- panel log AND to Output, prefixed with [QA], so results can be copied.
-- Client-only: it moves your own character (you own its physics) and uses
-- ProximityPrompt:InputHoldBegin/End to "hold E" through the real game path.
-- It never touches saved data.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local QaPanel = {}

local player = Players.LocalPlayer
local logLabel: TextLabel
local busy = false

local function log(text: string)
	print("[QA] " .. text)
	if logLabel then
		local lines = string.split(logLabel.Text, "\n")
		table.insert(lines, text)
		while #lines > 14 do
			table.remove(lines, 1)
		end
		logLabel.Text = table.concat(lines, "\n")
	end
end

local function charParts()
	local char = player.Character
	return char, char and char:FindFirstChildOfClass("Humanoid"), char and char:FindFirstChild("HumanoidRootPart")
end

local function map(): Instance?
	return workspace:FindFirstChild("Map")
end

local function v3(v: Vector3): string
	return string.format("(%.0f, %.0f, %.0f)", v.X, v.Y, v.Z)
end

-- Ground under a point: returns part, ZoneName/Biome text
local function groundAt(pos: Vector3): (BasePart?, string)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(pos, Vector3.new(0, -40, 0), params)
	if not hit then
		return nil, "none"
	end
	local p: Instance? = hit.Instance
	while p and p ~= workspace do
		local zone = p:GetAttribute("ZoneName") or p:GetAttribute("Biome")
		if zone then
			return hit.Instance, tostring(zone)
		end
		p = p.Parent
	end
	return hit.Instance, hit.Instance.Name
end

local function myNest(): BasePart?
	local m = map()
	local roofs = m and m:FindFirstChild("Rooftops")
	if not roofs then
		return nil
	end
	for _, roof in roofs:GetChildren() do
		if roof:GetAttribute("OwnerUserId") == player.UserId then
			local nest = roof:FindFirstChild("Nest", true)
			return nest and nest:IsA("BasePart") and nest or nil
		end
	end
	return nil
end

local function teleport(pos: Vector3)
	local _, _, root = charParts()
	if root then
		pcall(function()
			player:RequestStreamAroundAsync(pos, 5) -- StreamingEnabled: load the target area first
		end)
		root.AssemblyLinearVelocity = Vector3.zero
		player.Character:PivotTo(CFrame.new(pos))
	end
end

local function spawnsByBiome(): { [string]: BasePart }
	local out = {}
	local m = map()
	local folder = m and m:FindFirstChild("HuntZone") and m.HuntZone:FindFirstChild("WeatherSpawns")
	if folder then
		for _, s in folder:GetChildren() do
			local b = s:GetAttribute("Biome")
			if b and not out[b] and s:IsA("BasePart") then
				out[b] = s
			end
		end
	end
	return out
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------

local function info()
	local m = map()
	if not m then
		log("Map: MISSING")
		return
	end
	local parts = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	log(`Map version {tostring(m:GetAttribute("MapVersion"))}, Custom={tostring(m:GetAttribute("Custom"))}, parts={parts}`)
	local up = m:FindFirstChild("AirColumns") and m.AirColumns:FindFirstChild("Updraft")
	if up then
		log(`Updraft at {v3(up.Position)} Lift={up:GetAttribute("Lift")} Exit={up:GetAttribute("ExitHeight")} Target={tostring(up:GetAttribute("LaunchTarget"))}`)
	else
		log("Updraft: MISSING")
	end
	local _, hum, root = charParts()
	if root and hum then
		local _, zone = groundAt(root.Position)
		log(`Me at {v3(root.Position)} ground={zone} hp={math.floor(hum.Health)} walk={hum.WalkSpeed}`)
	end
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	log(`Coins={coins and coins.Value or "?"} Carrying={tostring(player:GetAttribute("Carrying"))} Night={tostring(workspace:GetAttribute("IsNight"))}`)
	local nest = myNest()
	log(nest and `My nest at {v3(nest.Position)}` or "My nest: NOT ASSIGNED")
	local other = 0
	for _, p in Players:GetPlayers() do
		if p ~= player then
			other += 1
		end
	end
	log(`Players in server: {#Players:GetPlayers()} (others {other})`)
end

local function updraftTest()
	local m = map()
	local up = m and m:FindFirstChild("AirColumns") and m.AirColumns:FindFirstChild("Updraft")
	if not up then
		log("UPDRAFT TEST: FAIL - no Updraft column")
		return
	end
	local bottom = up.Position.Y - up.Size.X / 2 -- cylinder stands on its X axis
	teleport(Vector3.new(up.Position.X, bottom + 4, up.Position.Z))
	log("Updraft test: placed in column, measuring 8 s ...")
	local start = os.clock()
	local maxY, died = -math.huge, false
	local _, hum = charParts()
	local conn = hum and hum.Died:Connect(function()
		died = true
	end)
	while os.clock() - start < 8 and not died do
		local _, _, root = charParts()
		if root then
			maxY = math.max(maxY, root.Position.Y)
		end
		task.wait(0.05)
	end
	if conn then
		conn:Disconnect()
	end
	local _, h2, root = charParts()
	local zone = "none"
	if root then
		_, zone = groundAt(root.Position)
	end
	local exitY = up:GetAttribute("ExitHeight") or 0
	local ok = not died and h2 and h2.Health > 0 and root and root.Position.Y > exitY - 20 and zone ~= "none"
	log(`UPDRAFT TEST: {ok and "PASS" or "FAIL"} maxY={math.floor(maxY)} (exit {exitY}) now {root and v3(root.Position) or "?"} ground={zone} died={died}`)
end

local function biomeTp(biome: string)
	local s = spawnsByBiome()[biome]
	if not s then
		log(`TP {biome}: no spawn marker with Biome={biome}`)
		return
	end
	teleport(s.Position + Vector3.new(4, 4, 0))
	task.wait(0.5)
	local _, _, root = charParts()
	local _, zone = groundAt(root and root.Position or s.Position)
	log(`TP {biome}: at {v3(s.Position)} ground={zone}`)
end

local function deathTest()
	local nest = myNest()
	if not nest then
		log("DEATH TEST: FAIL - no nest assigned")
		return
	end
	local _, hum = charParts()
	if not hum then
		return
	end
	-- the map marks a canyon pit for us (Map/Decor/PitMarker, v1.7+)
	local marker = map() and map():FindFirstChild("PitMarker", true)
	if not marker then
		log("DEATH TEST: FAIL - no Map/Decor/PitMarker (rebuild the map)")
		return
	end
	teleport(marker.Position)
	log("Death test: dropped above a canyon pit, waiting up to 12 s ...")
	local diedAt
	local c1 = hum.Died:Connect(function()
		diedAt = os.clock()
	end)
	local t0 = os.clock()
	while not diedAt and os.clock() - t0 < 12 do
		task.wait(0.1)
	end
	c1:Disconnect()
	if not diedAt then
		local _, _, root = charParts()
		log(`DEATH TEST: FAIL - not dead after 12 s, at {root and v3(root.Position) or "?"}`)
		return
	end
	local char = player.CharacterAdded:Wait()
	local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart
	task.wait(1)
	local nest2 = myNest() or nest
	local dist = root and (root.Position - nest2.Position).Magnitude or math.huge
	log(`DEATH TEST: died after {string.format("%.1f", diedAt - t0)} s; respawn {math.floor(dist)} studs from nest -> {dist < 30 and "PASS" or "FAIL"}`)
end

local function walk(seconds: number)
	local _, hum, root = charParts()
	if not hum or not root then
		return
	end
	local from = root.Position
	local dir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		hum:Move(dir.Unit, false)
		task.wait()
	end
	hum:Move(Vector3.zero, false)
	log(`Walked {seconds} s: moved {math.floor((root.Position - from).Magnitude)} studs, now {v3(root.Position)}`)
end

local function turn(deg: number)
	local _, _, root = charParts()
	if root then
		root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(deg), 0)
	end
end

-- Prompts currently shown to us (the real "press E" ones)
local shown: { [ProximityPrompt]: boolean } = {}
local function holdNearestPrompt()
	local _, _, root = charParts()
	local best, bestD = nil, math.huge
	for prompt in shown do
		local parent = prompt.Parent
		local pos = parent and (parent:IsA("BasePart") and parent.Position or parent:IsA("Attachment") and parent.WorldPosition)
		if pos and root and prompt.Enabled then
			local d = (pos - root.Position).Magnitude
			if d < bestD then
				best, bestD = prompt, d
			end
		end
	end
	if not best then
		log("HOLD E: no prompt in range - walk/teleport closer")
		return
	end
	local p = best :: ProximityPrompt
	local fired = false
	local conn = p.Triggered:Connect(function()
		fired = true
	end)
	log(`HOLD E: {p.Name} "{p.ActionText} {p.ObjectText}" ({math.floor(bestD)} studs, hold {p.HoldDuration} s)`)
	p:InputHoldBegin()
	task.wait(p.HoldDuration + 0.15)
	p:InputHoldEnd()
	task.wait(0.3)
	conn:Disconnect()
	log(`HOLD E result: triggered={fired} Carrying={tostring(player:GetAttribute("Carrying"))}`)
end

local function tpNearestCloud()
	local wildFolder = workspace:FindFirstChild("Weather") and workspace.Weather:FindFirstChild("Wild")
	local _, _, root = charParts()
	if not wildFolder or not root then
		log("TP cloud: no Weather/Wild folder")
		return
	end
	local best, bestD = nil, math.huge
	for _, c in wildFolder:GetChildren() do
		if c:IsA("BasePart") then
			local prompt = c:FindFirstChild("CatchPrompt")
			if prompt and prompt:GetAttribute("Ready") then
				local d = (c.Position - root.Position).Magnitude
				if d < bestD then
					best, bestD = c, d
				end
			end
		end
	end
	if not best then
		log("TP cloud: no ready wild cloud")
		return
	end
	teleport(best.Position + Vector3.new(0, 1, 5))
	log(`TP cloud: next to {best.Name} at {v3(best.Position)}`)
end

local function tpOtherBase()
	local m = map()
	local roofs = m and m:FindFirstChild("Rooftops")
	for _, roof in roofs and roofs:GetChildren() or {} do
		local owner = roof:GetAttribute("OwnerUserId")
		if owner and owner ~= player.UserId then
			local nest = roof:FindFirstChild("Nest", true)
			if nest then
				teleport(nest.Position + Vector3.new(0, 4, 0))
				log(`TP rival base: {roof.Name} (owner {owner})`)
				return
			end
		end
	end
	log("TP rival base: no other player's base (start a 2-player test)")
end

local function assetScan()
	local props = { "SoundId", "Texture", "TextureId", "MeshId", "Image", "AnimationId", "ColorMap", "SkyboxBk", "SkyboxDn",
		"SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId" }
	local list, owners = {}, {}
	for _, d in game:GetDescendants() do
		for _, prop in props do
			local ok, v = pcall(function()
				return (d :: any)[prop]
			end)
			if ok and type(v) == "string" and v:find("rbxassetid://") then
				if not owners[v] then
					owners[v] = {}
					table.insert(list, v)
				end
				table.insert(owners[v], d:GetFullName() .. "." .. prop)
			end
		end
	end
	log(`Asset scan: {#list} asset ids, preloading ...`)
	local failed = 0
	pcall(function()
		ContentProvider:PreloadAsync(list, function(id, status)
			if status == Enum.AssetFetchStatus.Failure then
				failed += 1
				log(`ASSET FAIL {id} used by {table.concat(owners[id] or {}, ", ")}`)
			end
		end)
	end)
	log(`Asset scan done: {failed} failed`)
end

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------

local function run(fn, ...)
	if busy then
		log("busy - wait for the current test")
		return
	end
	busy = true
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(fn, table.unpack(args, 1, args.n))
		if not ok then
			log("ERROR " .. tostring(err))
		end
		busy = false
	end)
end

function QaPanel.Start()
	if not RunService:IsStudio() then
		return
	end
	require(game:GetService("ReplicatedStorage").Shared.AssetProbe).Watch("203785492")
	ProximityPromptService.PromptShown:Connect(function(p)
		shown[p] = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(p)
		shown[p] = nil
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "QaPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.fromOffset(46, 26)
	toggle.Position = UDim2.new(0, 8, 1, -34)
	toggle.Text = "QA"
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 14
	toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.Parent = gui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(430, 540)
	frame.Position = UDim2.new(0, 8, 1, -582)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	frame.BackgroundTransparency = 0.1
	frame.Visible = false
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(1, -12, 0, 300)
	grid.Position = UDim2.fromOffset(6, 6)
	grid.BackgroundTransparency = 1
	grid.Parent = frame
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(136, 30)
	layout.CellPadding = UDim2.fromOffset(4, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	logLabel = Instance.new("TextLabel")
	logLabel.Size = UDim2.new(1, -12, 1, -316)
	logLabel.Position = UDim2.fromOffset(6, 310)
	logLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	logLabel.TextColor3 = Color3.fromRGB(190, 255, 200)
	logLabel.Font = Enum.Font.Code
	logLabel.TextSize = 12
	logLabel.TextWrapped = true
	logLabel.TextXAlignment = Enum.TextXAlignment.Left
	logLabel.TextYAlignment = Enum.TextYAlignment.Bottom
	logLabel.Text = "QA panel ready (Studio only). Results also go to Output."
	logLabel.Parent = frame

	local order = 0
	-- While the panel is open, these keys press the buttons in order
	-- (for testers whose mouse clicks don't reach the UI)
	local HOTKEYS = {
		Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V, Enum.KeyCode.B, Enum.KeyCode.N,
		Enum.KeyCode.U, Enum.KeyCode.I, Enum.KeyCode.O, Enum.KeyCode.P, Enum.KeyCode.K, Enum.KeyCode.L,
		Enum.KeyCode.T, Enum.KeyCode.Y, Enum.KeyCode.R, Enum.KeyCode.Q, Enum.KeyCode.Comma, Enum.KeyCode.Period,
		Enum.KeyCode.Semicolon,
	}
	local hotkeys: { [Enum.KeyCode]: () -> () } = {}
	local actions: { [string]: () -> () } = {}
	local function button(text: string, fn, ...)
		order += 1
		local args = table.pack(...)
		local b = Instance.new("TextButton")
		b.LayoutOrder = order
		b.Text = text
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 12
		b.BackgroundColor3 = Color3.fromRGB(55, 65, 100)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Parent = grid
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		local last = 0
		local function fire()
			if os.clock() - last < 0.4 then
				return -- Activated + MouseButton1Down can both fire for one click
			end
			last = os.clock()
			run(fn, table.unpack(args, 1, args.n))
		end
		b.Activated:Connect(fire)
		b.MouseButton1Down:Connect(fire)
		actions[string.lower(text)] = fire
		local key = HOTKEYS[order]
		if key then
			hotkeys[key] = fire
			b.Text = `[{key.Name}] {text}`
		end
	end

	button("Info", info)
	button("Updraft test", updraftTest)
	button("Death test (pit)", deathTest)
	button("TP Plateau", biomeTp, "Plateau")
	button("TP Mountains", biomeTp, "Mountains")
	button("TP Mushroom", biomeTp, "Mushroom")
	button("TP Marsh", biomeTp, "Marsh")
	button("TP Canyon", biomeTp, "Canyon")
	button("TP Volcanic", biomeTp, "Volcanic")
	button("TP Coast", biomeTp, "Coast")
	button("TP Hub", teleport, Vector3.new(0, 46, 20))
	button("TP My base", function()
		local nest = myNest()
		if nest then
			teleport(nest.Position + Vector3.new(0, 4, 0))
			log("TP my base")
		else
			log("TP my base: no nest")
		end
	end)
	button("TP nearest cloud", tpNearestCloud)
	button("Hold E (nearest)", holdNearestPrompt)
	button("TP rival base", tpOtherBase)
	button("Walk 2 s", walk, 2)
	button("Turn 90", turn, 90)
	button("Asset scan", assetScan)

	local function flip()
		frame.Visible = not frame.Visible
	end
	toggle.Activated:Connect(flip)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F8 then
			flip()
		elseif frame.Visible and hotkeys[input.KeyCode] then
			hotkeys[input.KeyCode]()
		end
	end)

	-- Command Bar entry point (Studio, Command Bar set to CLIENT during Play):
	--   game.Players.LocalPlayer.PlayerGui.QaPanel.Run:Invoke("info")
	-- names = button texts in lower case, e.g. "updraft test", "tp canyon", "hold e (nearest)"
	local bf = Instance.new("BindableFunction")
	bf.Name = "Run"
	bf.OnInvoke = function(name: string)
		local fire = actions[string.lower(name or "")]
		if not fire then
			local names = {}
			for k in actions do
				table.insert(names, k)
			end
			table.sort(names)
			return "unknown QA action; try: " .. table.concat(names, ", ")
		end
		fire()
		return "started " .. name .. " (see [QA] lines in Output)"
	end
	bf.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	log("QA: F8 or the QA button toggles this panel")
end

return QaPanel
