-- Hides E-prompts that aren't meant for you. The server still checks
-- everything; this only keeps the screen clean.
--   Role "Steal" → hidden on your own base
--   Role "Perk"  → only shown on your own base
-- Also hides catch prompts while you're already carrying a cloud.

local Players = game:GetService("Players")

local Prompts = {}

local player = Players.LocalPlayer
local tracked = {} -- [ProximityPrompt] = true

local function apply(prompt: ProximityPrompt)
	local role = prompt:GetAttribute("Role")
	local owner = prompt:GetAttribute("OwnerUserId")
	local carrying = player:GetAttribute("Carrying") ~= nil
	local show = true
	if role == "Steal" then
		show = owner ~= player.UserId and not carrying
	elseif role == "Perk" then
		show = owner == player.UserId
	elseif prompt.Name == "CatchPrompt" then
		show = not carrying
	end
	-- Ready = false while a cloud is still flying in from the storm
	prompt.Enabled = show and prompt:GetAttribute("Ready") ~= false
end

local function track(inst: Instance)
	if not inst:IsA("ProximityPrompt") or tracked[inst] then
		return
	end
	if not (inst:GetAttribute("Role") or inst.Name == "CatchPrompt") then
		return
	end
	tracked[inst] = true
	apply(inst)
	inst:GetAttributeChangedSignal("Ready"):Connect(function()
		apply(inst)
	end)
	inst.AncestryChanged:Connect(function()
		if not inst:IsDescendantOf(game) then
			tracked[inst] = nil
		end
	end)
end

function Prompts.Start()
	for _, d in workspace:GetDescendants() do
		track(d)
	end
	workspace.DescendantAdded:Connect(track)
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		for prompt in tracked do
			apply(prompt)
		end
	end)
end

return Prompts
