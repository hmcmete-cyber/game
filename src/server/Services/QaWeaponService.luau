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
	return QA_USER_IDS[player.UserId] == true and (RunService:IsStudio() or game.PrivateServerId ~= "")
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

-- TEST ONLY: respawn the boss of the nearest temple right now (with its
-- arrival effect). Same guard: QA account + Studio/private server only.
local function makeBossTool(monsterService): Tool
	local Defs = require(game:GetService("ReplicatedStorage").Shared.MonsterDefs)
	local tool = Instance.new("Tool")
	tool.Name = "QA Boss Respawner (test only)"
	tool.ToolTip = "Test tool: respawn the boss of the nearest temple"
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
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if busy or not player or not root or not allowed(player) then
			return
		end
		busy = true
		local temples = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Temples")
		local best, bestD = nil, math.huge
		for _, t in temples and temples:GetChildren() or {} do
			local sp = t:FindFirstChild("BossSpawn")
			if sp and (sp.Position - root.Position).Magnitude < bestD then
				best, bestD = t.Name, (sp.Position - root.Position).Magnitude
			end
		end
		for typeName, def in Defs.Types do
			if def.Boss and def.Arena == best then
				monsterService.RespawnBoss(typeName)
				print(`[QA] {player.Name} respawned {typeName}`)
			end
		end
		task.wait(1)
		busy = false
	end)
	return tool
end

function QaWeaponService.Start(monsterService)
	local function give(player: Player)
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
			if backpack and not backpack:FindFirstChild("QA Boss Respawner (test only)") then
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
