-- TEST ONLY (director request): an OP weapon for the director's QA account so
-- monster/boss deaths can be tested. Given only to QA_USER_IDS, and only in
-- Studio or a private server (never in public live servers).
-- To remove after testing: delete this file, its line in main.server.luau and
-- the QaSpeed block in client/Movement.luau.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local QaWeaponService = {}

local QA_USER_IDS = { [2459147914] = true } -- Cubickzz
local RANGE = 60 -- studs
local DAMAGE = 1e6

local function allowed(player: Player): boolean
	return QA_USER_IDS[player.UserId] == true and (require(game:GetService("ReplicatedStorage").Shared.Config).QaEverywhere or RunService:IsStudio() or game.PrivateServerId ~= "")
end

local function makeTool(monsterService): Tool
	local tool = Instance.new("Tool")
	tool.Name = "QA OP Smasher (test only)"
	tool.ToolTip = "Test weapon: kills every monster within 60 studs"
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 4.5, 0.8)
	handle.Color = Color3.fromRGB(255, 60, 200)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Parent = tool
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.4, 1.4, 1.4)
	head.Color = Color3.fromRGB(255, 220, 60)
	head.Material = Enum.Material.Neon
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 2.4, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = handle, head
	weld.Parent = head
	head.Parent = tool
	tool.GripPos = Vector3.new(0, -1.6, 0)

	local busy = false
	tool.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local character = tool.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if player and root and allowed(player) then
			local killed = 0
			for _, m in CollectionService:GetTagged("Monster") do
				local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r and (r.Position - root.Position).Magnitude <= RANGE then
					monsterService.Damage(m, DAMAGE, player, "QA")
					killed += 1
				end
			end
			require(game:GetService("ReplicatedStorage").Shared.FxKit).Explosion(root.Position, Color3.fromRGB(255, 80, 220), 2.5)
			-- shock ring so the hit is visible
			local ring = Instance.new("Part")
			ring.Shape = Enum.PartType.Cylinder
			ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
			ring.Material = Enum.Material.Neon
			ring.Color = Color3.fromRGB(255, 80, 220)
			ring.Transparency = 0.4
			ring.Size = Vector3.new(0.4, RANGE * 2, RANGE * 2)
			ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			ring.Parent = workspace
			task.delay(0.35, function()
				ring:Destroy()
			end)
			print(`[QA] {player.Name} OP smash: {killed} monster(s) hit`)
		end
		task.wait(0.5)
		busy = false
	end)
	return tool
end

-- TEST ONLY: speed tool. Click to cycle walk speed x1 -> x4 -> x8 -> x12 -> x1
-- (jump gets up to x3). The client Movement reads the QaSpeed attribute.
local SPEEDS = { 1, 4, 8, 12 }
local function makeSpeedTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "QA Speed (test only)"
	tool.ToolTip = "Test tool: click to change speed x1 / x4 / x8 / x12"
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 2)
	handle.Color = Color3.fromRGB(60, 255, 140)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Parent = tool
	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player or not allowed(player) then
			return
		end
		local cur = player:GetAttribute("QaSpeed") or 1
		local idx = table.find(SPEEDS, cur) or 1
		local nextSpeed = SPEEDS[idx % #SPEEDS + 1]
		player:SetAttribute("QaSpeed", nextSpeed)
		print(`[QA] {player.Name} speed x{nextSpeed}`)
	end)
	return tool
end

-- TEST ONLY: "Respawner" brings back every defeated monster and boss now.
-- Same guard: QA account + Studio/private server only.
local function makeBossTool(monsterService): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Respawner"
	tool.ToolTip = "Test tool: respawn every defeated monster and boss"
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 2.4, 1)
	handle.Color = Color3.fromRGB(255, 90, 60)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Parent = tool
	local busy = false
	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if busy or not player or not allowed(player) then
			return
		end
		busy = true
		local n = monsterService.RespawnAll()
		print(`[QA] {player.Name} Respawner: {n} monster(s) back`)
		task.wait(2)
		busy = false
	end)
	return tool
end

local spawnRemote, openRemote -- set in Start (declared early: EXTRA_TOOLS uses openRemote)

-- TEST ONLY: simple one-click QA tools (same guard as the others)
local function makeClickTool(name: string, tip: string, color: Color3, onUse: (Player) -> ()): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = tip
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1.6, 1)
	handle.Color = color
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Parent = tool
	local busy = false
	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if busy or not player or not allowed(player) then
			return
		end
		busy = true
		onUse(player)
		task.wait(0.5)
		busy = false
	end)
	return tool
end
local EXTRA_TOOLS = {
	{ "QA Daytime (test only)", "Test tool: set the time to midday", Color3.fromRGB(255, 230, 120), function(player)
		game:GetService("Lighting").ClockTime = 12
		print(`[QA] {player.Name} set midday`)
	end },
	{ "QA Pet Level Up (test only)", "Test tool: +500 XP for every equipped pet", Color3.fromRGB(255, 160, 255), function(player)
		require(script.Parent:WaitForChild("PetService")).AddXP(player, 500 / 0.6)
		print(`[QA] {player.Name} gave pets 500 XP`)
	end },
	{ "QA Tutorial (test only)", "Test tool: show the tutorial again", Color3.fromRGB(255, 255, 255), function(player)
		require(script.Parent:WaitForChild("TutorialService")).Show(player)
	end },
	{ "QA Item Spawner (test only)", "Test tool: give yourself any item, upgrade, pet or egg", Color3.fromRGB(255, 120, 60), function(player)
		if openRemote then
			openRemote:FireClient(player)
		end
	end },
	{ "QA Clear Event (test only)", "Test tool: end the running sky event (fog, acid rain, meteors)", Color3.fromRGB(150, 220, 255), function(player)
		local ok = require(script.Parent:WaitForChild("EventService")).StopNow()
		print(`[QA] {player.Name} clear event: {ok and "stopped" or "none running"}`)
	end },
}

-- TEST ONLY: "QA Item Spawner" opens a panel to give yourself ANY item,
-- upgrade/boon, pet, egg, coins, or unlock everything. Checked on the server.
local function onSpawn(player: Player, category: unknown, id: unknown)
	if not allowed(player) or type(category) ~= "string" then
		return
	end
	local RS = game:GetService("ReplicatedStorage")
	local DataService = require(script.Parent:WaitForChild("DataService"))
	local d = DataService.Get(player)
	if not d then
		return
	end
	if category == "Item" and type(id) == "string" then
		require(script.Parent:WaitForChild("InventoryService")).GiveItem(player, id)
	elseif category == "Upgrade" and type(id) == "string" then
		local def = require(RS.Shared.Upgrades).Types[id]
		if def then
			d.Upgrades = d.Upgrades or {}
			d.Upgrades[id] = def.MaxLevel
			d.Unlocks = d.Unlocks or {}
			d.Unlocks[id] = true
			require(script.Parent:WaitForChild("UpgradeService")).Sync(player)
		end
	elseif category == "Pet" and type(id) == "string" then
		require(script.Parent:WaitForChild("PetService")).Grant(player, id)
	elseif category == "Egg" and type(id) == "string" then
		if require(RS.Shared.PetDefs).Eggs[id] then
			d.Eggs = d.Eggs or {}
			table.insert(d.Eggs, id)
		end
	elseif category == "Coins" then
		d.Coins = (d.Coins or 0) + 10000
		DataService.Sync(player)
	elseif category == "Totem" and type(id) == "string" then
		require(script.Parent:WaitForChild("ForgeService")).GiveTotem(player, id, 1)
	elseif category == "Material" and type(id) == "string" then
		require(script.Parent:WaitForChild("ForgeService")).Give(player, id, 5)
	elseif category == "Materials" then
		local Forge = require(script.Parent:WaitForChild("ForgeService"))
		for mid in require(RS.Shared.ForgeDefs).Materials do
			Forge.Give(player, mid, 5, true)
		end
	elseif category == "Totems" then
		local Forge = require(script.Parent:WaitForChild("ForgeService"))
		for _, biome in require(RS.Shared.ForgeDefs).Biomes do
			Forge.GiveTotem(player, biome, 1, true)
		end
	elseif category == "UnlockAll" then
		local Catalog = require(RS.Shared.VendorCatalog)
		d.Unlocks = d.Unlocks or {}
		for cid in Catalog.Boons do
			d.Unlocks[cid] = true
		end
		for cid in Catalog.Gadgets do
			d.Unlocks[cid] = true
		end
		local list = {}
		for cid in d.Unlocks do
			table.insert(list, cid)
		end
		player:SetAttribute("Unlocks", "," .. table.concat(list, ",") .. ",")
	end
	print(`[QA] {player.Name} spawned {category} {tostring(id)}`)
end

function QaWeaponService.Start(monsterService)
	local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
	spawnRemote = Instance.new("RemoteEvent")
	spawnRemote.Name = "QaSpawn"
	spawnRemote.Parent = remotes
	openRemote = Instance.new("RemoteEvent")
	openRemote.Name = "QaOpenSpawner"
	openRemote.Parent = remotes
	spawnRemote.OnServerEvent:Connect(onSpawn)
	local function give(player: Player)
		print(`[QA] {player.Name} ({player.UserId}) joined - QA tools: {allowed(player) and "YES" or "no"}`)
		if not allowed(player) then
			return
		end
		local function equip()
			local backpack = player:WaitForChild("Backpack", 10)
			if backpack and not backpack:FindFirstChild("QA OP Smasher (test only)") then
				makeTool(monsterService).Parent = backpack
			end
			if backpack and not backpack:FindFirstChild("QA Speed (test only)") then
				makeSpeedTool().Parent = backpack
			end
			for _, spec in EXTRA_TOOLS do
				if backpack and not backpack:FindFirstChild(spec[1]) then
					makeClickTool(spec[1], spec[2], spec[3], spec[4]).Parent = backpack
				end
			end
			if backpack and not backpack:FindFirstChild("Respawner") then
				makeBossTool(monsterService).Parent = backpack
			end
		end
		player.CharacterAdded:Connect(function()
			task.wait(1)
			equip()
		end)
		if player.Character then
			equip()
		end
	end
	for _, p in Players:GetPlayers() do
		give(p)
	end
	Players.PlayerAdded:Connect(give)
end

return QaWeaponService
