-- v2.18 SHOP ITEM LOGOS (director: letters on the cards looked plain).
-- Every item / upgrade / boon / gadget gets a little studded 3D logo that the
-- shop shows in a ViewportFrame and slowly turns: potion bottles, boots,
-- bombs, shields, coins, feathers, swords, hearts, hourglasses, eggs...
--   ItemIcons.KindFor(id, def) -> logo kind
--   ItemIcons.Build(kind, color) -> Model (centred on the origin, ~4 studs)

local ItemIcons = {}

local V = Vector3.new
local CF = CFrame.new
local A = CFrame.Angles
local rad = math.rad
local WHITE, DARK, GOLD = Color3.fromRGB(250, 250, 255), Color3.fromRGB(45, 45, 55), Color3.fromRGB(255, 205, 60)

local function p(m: Model, size: Vector3, cf: CFrame, color: Color3, shape: string?, neon: boolean?, glass: boolean?)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = neon and Enum.Material.Neon or (glass and Enum.Material.Glass or Enum.Material.Plastic)
	part.Transparency = glass and 0.25 or 0
	part.TopSurface = Enum.SurfaceType.Studs
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cyl" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Parent = m
	return part
end
local function wedge(m: Model, size: Vector3, cf: CFrame, color: Color3)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = Enum.Material.Plastic
	w.Parent = m
	return w
end
local UP = A(0, 0, rad(90)) -- cylinders stand upright

local B = {}
B.bottle = function(m, c)
	p(m, V(2.4, 2.4, 2.4), CF(0, -0.6, 0), c, "Ball", false, true)
	p(m, V(1.4, 1.2, 1.4), CF(0, -0.6, 0), c, "Ball", true)
	p(m, V(1.2, 0.9, 0.9), CF(0, 0.9, 0) * UP, c:Lerp(WHITE, 0.4), "Cyl", false, true)
	p(m, V(0.6, 0.7, 0.7), CF(0, 1.55, 0) * UP, Color3.fromRGB(160, 110, 70), "Cyl")
end
B.boots = function(m, c)
	for _, x in { -0.8, 0.8 } do
		p(m, V(1.2, 2, 1.2), CF(x, 0.2, 0.3), c)
		p(m, V(1.3, 0.7, 2.2), CF(x, -1, -0.2), c:Lerp(DARK, 0.3))
		p(m, V(1.3, 0.25, 1.3), CF(x, 1.1, 0.3), WHITE)
	end
end
B.candy = function(m, c)
	p(m, V(1.6, 1.6, 1.6), CF(), c, "Ball")
	for _, x in { -1, 1 } do
		wedge(m, V(1, 1.2, 0.9), CF(x * 1.25, 0, 0) * A(0, 0, rad(x * 90)), c:Lerp(WHITE, 0.4))
	end
	p(m, V(1.65, 0.3, 1.65), CF(0, 0.2, 0) * A(0, 0, rad(30)), WHITE)
end
B.bomb = function(m, c)
	p(m, V(2.8, 2.8, 2.8), CF(0, -0.3, 0), c:Lerp(DARK, 0.5), "Ball")
	p(m, V(0.9, 0.6, 0.9), CF(0, 1.2, 0) * UP, DARK, "Cyl")
	p(m, V(0.15, 0.8, 0.15), CF(0.2, 1.8, 0) * A(0, 0, rad(-20)), Color3.fromRGB(180, 150, 100))
	p(m, V(0.5, 0.5, 0.5), CF(0.4, 2.25, 0), c, "Ball", true)
end
B.barrel = function(m, c)
	p(m, V(3, 2.4, 2.4), CF() * UP, Color3.fromRGB(160, 100, 60), "Cyl")
	for _, y in { -0.9, 0.9 } do
		p(m, V(0.25, 2.5, 2.5), CF(0, y, 0) * UP, DARK, "Cyl")
	end
	p(m, V(0.6, 0.6, 0.15), CF(0, 0, -1.25), c, nil, true)
end
B.meteor = function(m, c)
	p(m, V(2.2, 2, 2.2), CF(0.3, -0.4, 0) * A(0.4, 0.6, 0.2), Color3.fromRGB(80, 70, 70))
	for k = 1, 3 do
		p(m, V(0.5, 1.6 - k * 0.3, 0.5), CF(-0.6 - k * 0.3, 0.6 + k * 0.4, 0) * A(0, 0, rad(40)), k == 1 and Color3.fromRGB(255, 230, 120) or c, nil, true)
	end
end
B.shield = function(m, c)
	p(m, V(3.2, 3.2, 3.2), CF(0, -0.6, 0), c, "Ball", false, true)
	p(m, V(3.4, 0.4, 3.4), CF(0, -1.3, 0), c:Lerp(DARK, 0.3))
	p(m, V(0.9, 0.9, 0.9), CF(0, -0.4, 0), WHITE, "Ball", true)
end
B.coin = function(m, c)
	p(m, V(0.5, 3, 3), CF() * A(0, rad(90), 0), GOLD, "Cyl")
	p(m, V(0.55, 1.6, 0.4), CF(0, 0, -0.1), Color3.fromRGB(255, 240, 150))
end
B.coinstack = function(m, c)
	for k = 0, 3 do
		p(m, V(0.45, 2.4, 2.4), CF(k * 0.12 - 0.2, -1 + k * 0.5, 0) * UP, GOLD, "Cyl")
	end
	p(m, V(0.4, 2, 2), CF(1.2, -1.1, 0.6) * UP, GOLD, "Cyl")
end
B.feather = function(m, c)
	p(m, V(0.15, 3.4, 0.15), CF() * A(0, 0, rad(25)), WHITE)
	for k = -3, 3 do
		wedge(m, V(0.12, 0.5, 1.1), CF(-k * 0.2, k * 0.42, 0.3) * A(0, rad(90), rad(25)), k % 2 == 0 and c or c:Lerp(WHITE, 0.5))
	end
end
B.ring = function(m, c)
	p(m, V(0.5, 2.8, 2.8), CF() * A(0, rad(90), 0), GOLD, "Cyl")
	p(m, V(0.55, 1.9, 1.9), CF(0, 0, -0.01) * A(0, rad(90), 0), DARK, "Cyl")
	p(m, V(0.9, 0.9, 0.9), CF(0, 1.5, 0) * A(0, rad(45), 0), c, nil, false, true)
end
B.glove = function(m, c)
	p(m, V(2, 2, 1), CF(0, -0.2, 0), c)
	for k = -1, 1 do
		p(m, V(0.5, 1, 0.8), CF(k * 0.6, 1.2, 0), c:Lerp(WHITE, 0.15))
	end
	p(m, V(0.5, 0.9, 0.8), CF(-1.2, 0.1, 0) * A(0, 0, rad(40)), c:Lerp(WHITE, 0.15))
	p(m, V(2.2, 0.6, 1.1), CF(0, -1.3, 0), WHITE)
end
B.glasses = function(m, c)
	for _, x in { -0.9, 0.9 } do
		p(m, V(0.3, 1.5, 1.5), CF(x, 0, 0) * A(0, rad(90), 0), c, "Cyl", false, true)
	end
	p(m, V(0.6, 0.2, 0.2), CF(), DARK)
	for _, x in { -1, 1 } do
		p(m, V(0.15, 0.15, 1.6), CF(x * 1.65, 0.2, 0.8), DARK)
	end
end
B.smokebomb = function(m, c)
	p(m, V(2.4, 2.4, 2.4), CF(0, -0.5, 0), DARK, "Ball")
	for k = 1, 3 do
		p(m, V(1.2, 1.2, 1.2), CF(-0.5 + k * 0.4, 0.8 + k * 0.35, 0), Color3.fromRGB(190, 190, 200), "Ball")
	end
end
B.egg = function(m, c)
	p(m, V(2.2, 3, 2.2), CF(0, -0.2, 0), WHITE:Lerp(c, 0.3), "Ball")
	for k = -1, 1 do
		p(m, V(0.6, 0.35, 0.3), CF(k * 0.5, 0.2 + math.abs(k) * 0.2, -1.05) * A(0, 0, rad(k * 30)), c)
	end
	p(m, V(0.5, 0.8, 0.5), CF(0, -1.9, -0.6), Color3.fromRGB(255, 150, 50), nil, true)
end
B.medkit = function(m, c)
	p(m, V(3, 2.2, 1.4), CF(), WHITE)
	p(m, V(0.5, 1.4, 0.2), CF(0, 0, -0.75), Color3.fromRGB(230, 50, 60))
	p(m, V(1.4, 0.5, 0.2), CF(0, 0, -0.75), Color3.fromRGB(230, 50, 60))
	p(m, V(1, 0.4, 0.5), CF(0, 1.3, 0), DARK)
end
B.crystal = function(m, c)
	p(m, V(1.2, 3, 1.2), CF(0, 0, 0) * A(0, rad(45), 0), c, nil, false, true)
	wedge(m, V(1.2, 0.9, 0.6), CF(0, 1.95, 0.3) * A(0, rad(45), 0), c:Lerp(WHITE, 0.4))
	p(m, V(0.7, 1.6, 0.7), CF(1, -0.6, 0) * A(0, rad(45), rad(-25)), c:Lerp(WHITE, 0.3), nil, false, true)
end
B.beacon = function(m, c)
	p(m, V(1.6, 0.5, 1.6), CF(0, -1.5, 0), DARK)
	p(m, V(0.6, 2.4, 0.6), CF(0, -0.1, 0), Color3.fromRGB(200, 200, 210))
	p(m, V(1.2, 1.2, 1.2), CF(0, 1.4, 0), c, "Ball", true)
end
B.book = function(m, c)
	p(m, V(2.6, 3, 0.7), CF(), c)
	p(m, V(2.4, 2.8, 0.5), CF(0.15, 0, 0), WHITE)
	p(m, V(1.2, 0.3, 0.1), CF(0, 0.6, -0.36), GOLD)
end
B.cloak = function(m, c)
	wedge(m, V(0.4, 3, 2.6), CF(0, 0, 0) * A(0, rad(90), 0), c)
	p(m, V(2.2, 0.4, 0.5), CF(0, 1.4, 0), GOLD)
end
B.incense = function(m, c)
	p(m, V(1.4, 0.5, 1.4), CF(0, -1.4, 0), Color3.fromRGB(150, 110, 80))
	p(m, V(0.15, 2.4, 0.15), CF(0, -0.1, 0), Color3.fromRGB(200, 120, 90))
	for k = 1, 3 do
		p(m, V(0.6, 0.6, 0.6), CF(math.sin(k) * 0.4, 1.2 + k * 0.4, 0), c:Lerp(WHITE, 0.6), "Ball")
	end
end
B.gun = function(m, c)
	p(m, V(2.8, 0.9, 0.7), CF(0, 0.4, 0), c)
	p(m, V(0.7, 1.4, 0.6), CF(-0.7, -0.5, 0) * A(0, 0, rad(-15)), DARK)
	p(m, V(0.6, 0.4, 0.4), CF(1.6, 0.4, 0), c, nil, true)
end
B.hook = function(m, c)
	p(m, V(0.3, 2.6, 0.3), CF(0, 0.6, 0), DARK)
	for _, x in { -1, 1 } do
		p(m, V(0.3, 1.2, 0.3), CF(x * 0.5, -0.9, 0) * A(0, 0, rad(x * 45)), c)
	end
end
B.canister = function(m, c)
	p(m, V(2.6, 1.6, 1.6), CF() * UP, c, "Cyl")
	p(m, V(0.5, 0.8, 0.8), CF(0, 1.5, 0) * UP, DARK, "Cyl")
	p(m, V(0.2, 1.7, 1.7), CF(0, 0.4, 0) * UP, WHITE, "Cyl")
end
B.flare = function(m, c)
	p(m, V(0.4, 2.6, 0.4), CF(0, -0.4, 0) * A(0, 0, rad(15)), Color3.fromRGB(200, 60, 60))
	p(m, V(0.9, 0.9, 0.9), CF(0.3, 1.2, 0), c, "Ball", true)
end
B.wing = function(m, c)
	for k = 0, 3 do
		wedge(m, V(0.2, 0.8 + k * 0.3, 2 - k * 0.3), CF(0, 0.8 - k * 0.55, k * 0.2) * A(0, rad(90), rad(20)), k % 2 == 0 and WHITE or c)
	end
end
B.spring = function(m, c)
	for k = 0, 4 do
		p(m, V(0.3, 2.2, 2.2), CF(0, -1.2 + k * 0.55, 0) * A(0, 0, rad(90 + (k % 2 == 0 and 8 or -8))), c, "Cyl")
	end
	p(m, V(2, 0.3, 2), CF(0, 1.6, 0), DARK)
end
B.anchor = function(m, c)
	p(m, V(0.4, 3, 0.4), CF(), c)
	p(m, V(2.4, 0.4, 0.4), CF(0, 0.9, 0), c)
	p(m, V(0.4, 0.8, 0.8), CF(0, 1.7, 0) * A(0, rad(90), 0), c, "Cyl")
	for _, x in { -1, 1 } do
		wedge(m, V(0.4, 0.8, 1), CF(x * 0.8, -1.3, 0) * A(0, rad(x * 90), 0), c)
	end
end
B.heart = function(m, c)
	for _, x in { -0.55, 0.55 } do
		p(m, V(1.6, 1.6, 1.4), CF(x, 0.4, 0), c, "Ball")
	end
	wedge(m, V(1.2, 1.4, 2.4), CF(0, -0.75, 0) * A(rad(180), rad(90), 0), c)
end
B.sword = function(m, c)
	p(m, V(0.5, 3, 0.15), CF(0, 0.6, 0), Color3.fromRGB(220, 230, 245))
	p(m, V(1.6, 0.3, 0.3), CF(0, -0.9, 0), GOLD)
	p(m, V(0.35, 0.9, 0.35), CF(0, -1.5, 0), c)
end
B.star = function(m, c)
	for k = 0, 4 do
		wedge(m, V(0.4, 1.4, 0.8), CF() * A(0, 0, k / 5 * math.pi * 2) * CF(0, 0.9, 0), c)
	end
	p(m, V(0.5, 1, 1), CF() * A(0, rad(90), 0), c, "Cyl", true)
end
B.target = function(m, c)
	for k, r in { 3, 2.1, 1.2 } do
		p(m, V(0.2 + k * 0.05, r, r), CF(0, 0, -k * 0.05) * A(0, rad(90), 0), k % 2 == 1 and c or WHITE, "Cyl")
	end
end
B.fang = function(m, c)
	for _, x in { -0.6, 0.6 } do
		wedge(m, V(0.5, 1.8, 0.6), CF(x, 0, 0) * A(rad(180), 0, 0), WHITE)
	end
	p(m, V(0.5, 0.7, 0.5), CF(0.6, -1.3, 0), Color3.fromRGB(220, 40, 60), "Ball")
end
B.hourglass = function(m, c)
	p(m, V(2, 0.3, 2), CF(0, 1.6, 0), Color3.fromRGB(150, 110, 70))
	p(m, V(2, 0.3, 2), CF(0, -1.6, 0), Color3.fromRGB(150, 110, 70))
	p(m, V(1.4, 1.4, 1.4), CF(0, 0.75, 0), c, "Ball", false, true)
	p(m, V(1.4, 1.4, 1.4), CF(0, -0.75, 0), c, "Ball", false, true)
	p(m, V(0.9, 0.5, 0.9), CF(0, -1.1, 0), GOLD, "Ball")
end
B.mask = function(m, c)
	p(m, V(2.8, 1.6, 0.4), CF(), c)
	for _, x in { -0.6, 0.6 } do
		p(m, V(0.6, 0.35, 0.1), CF(x, 0.1, -0.25), DARK)
	end
	for _, x in { -1, 1 } do
		p(m, V(0.12, 0.12, 1.4), CF(x * 1.5, 0.1, 0.6), DARK)
	end
end
B.sparkle = function(m, c)
	p(m, V(0.5, 3, 0.5), CF(), c, nil, true)
	p(m, V(3, 0.5, 0.5), CF(), c, nil, true)
	p(m, V(0.4, 1.8, 0.4), CF() * A(0, 0, rad(45)), WHITE, nil, true)
	p(m, V(0.4, 1.8, 0.4), CF() * A(0, 0, rad(-45)), WHITE, nil, true)
end
B.flame = function(m, c)
	p(m, V(2, 2.4, 2), CF(0, -0.4, 0), Color3.fromRGB(255, 110, 40), "Ball", true)
	p(m, V(1.3, 1.8, 1.3), CF(0, 0.6, 0), Color3.fromRGB(255, 190, 70), "Ball", true)
	p(m, V(0.7, 1.1, 0.7), CF(0, 1.4, 0), Color3.fromRGB(255, 245, 170), "Ball", true)
end
B.vault = function(m, c)
	p(m, V(2.8, 2.8, 2.8), CF(), c, "Ball", false, true)
	p(m, V(1.4, 1.4, 1.4), CF(), WHITE, "Ball")
	p(m, V(2.4, 0.5, 2.4), CF(0, -1.5, 0), DARK)
end
B.slots = function(m, c)
	for k = -1, 1 do
		p(m, V(0.9, 0.9, 0.4), CF(k * 1.1, 0, 0), k == 1 and c or WHITE)
	end
	p(m, V(3.4, 1.3, 0.3), CF(0, 0, 0.3), DARK)
end
B.whetstone = function(m, c)
	p(m, V(2.8, 0.9, 1.2), CF(0, -0.6, 0), Color3.fromRGB(130, 130, 140))
	p(m, V(0.3, 2.4, 0.12), CF(0.3, 0.6, 0) * A(0, 0, rad(-30)), Color3.fromRGB(220, 230, 245))
	p(m, V(0.5, 0.5, 0.5), CF(0, 0.2, -0.5), c, "Ball", true)
end

local GADGET_WORDS = {
	{ "Soda", "bottle" }, { "Tonic", "bottle" }, { "Tea", "bottle" }, { "Broth", "bottle" }, { "Potion", "bottle" }, { "Drops", "bottle" },
	{ "Boots", "boots" }, { "Gum", "candy" }, { "Jerky", "candy" }, { "Candy", "candy" }, { "Pepper", "candy" },
	{ "Barrel", "barrel" }, { "Meteor", "meteor" }, { "Smoke", "smokebomb" }, { "Cracker", "bomb" }, { "Grenade", "bomb" },
	{ "Mine", "bomb" }, { "Bomb", "bomb" }, { "Shield", "shield" }, { "Dome", "shield" }, { "Coin", "coin" }, { "Feather", "feather" },
	{ "Ring", "ring" }, { "Gloves", "glove" }, { "Goggles", "glasses" }, { "Shades", "glasses" }, { "Heat", "egg" }, { "Coil", "egg" },
	{ "Bandage", "medkit" }, { "Kit", "medkit" }, { "Trap", "crystal" }, { "Beacon", "beacon" }, { "Notes", "book" },
	{ "Cloak", "cloak" }, { "Incense", "incense" }, { "Stone", "whetstone" },
}
local BASE_ITEMS = { LaserGun = "gun", SpeedPotion = "bottle", JumpPotion = "bottle", Nitro = "canister", Flare = "flare", ShieldGenerator = "shield", GrapplingHook = "hook" }
local BASE_UPGRADES = { Speed = "wing", Jump = "spring", Carry = "glove", Income = "vault", PerkSlot = "slots" }
local BOON_KINDS = {
	Speed = "wing", Jump = "spring", Resist = "shield", KnockResist = "anchor", Regen = "heart", Damage = "sword", XP = "book",
	Coins = "coinstack", Crit = "target", Lifesteal = "fang", Haste = "hourglass", Stealth = "mask", Hatch = "egg", Shield = "shield",
	Cleanse = "sparkle", FireImmune = "flame",
}

function ItemIcons.KindFor(id: string, def): string
	if BASE_ITEMS[id] then
		return BASE_ITEMS[id]
	elseif BASE_UPGRADES[id] then
		return BASE_UPGRADES[id]
	elseif def and def.Boon then
		return BOON_KINDS[def.Boon.Kind] or "star"
	end
	local name = def and def.DisplayName or id
	for _, w in GADGET_WORDS do
		if string.find(name, w[1]) then
			return w[2]
		end
	end
	return "star"
end

function ItemIcons.Build(kind: string, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "Icon"
	;(B[kind] or B.star)(m, color)
	return m
end

return ItemIcons
