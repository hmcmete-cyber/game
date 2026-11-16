# Steal a Cloud ☁️ (formerly Pocket Storm)

> "Catch the weather. Steal the thunder."

Concept proposed by Astra, approved by the director (2026-11-16). This file is the shared design reference. Change it only with the director's approval.

## Pitch

Catch living clouds, pocket tornadoes and bottled rainbows; grow and display them on your own rooftop garden. Hunt storms with friends or snatch rivals' open harvest crates — but the weather you carry changes the world around you, turning every escape into a funny disaster.

## Core idea

**The loot you carry changes your escape route.** The creature you collect, the cargo you carry, the mechanic that changes your escape and the object you display at home are the same thing.

| Carried weather | Effect on the world | Player decision |
|---|---|---|
| Rain cloud | Leaves a short-lived slippery trail | Make pursuers slip — but you can slip on the way back too |
| Pocket tornado | Lifts specific light platforms | Opens a shortcut — rivals can use it too |
| Snow cloud | Briefly freezes water gaps | Builds a safe bridge — but reveals your route |
| Thunder cloud | Triggers marked devices at intervals | Wait for the pulse to open a door, or take the long way? |

Weather combines between friends (e.g. rain trail + snow = ice road). Interactions are predefined and learnable, not random physics chaos.

## Update 2026-11-16 (director request)

- **Thunder Cloud** added as the 4th, rarest weather (5%): worth the most, you run faster carrying it, but you glow through walls for everyone.
- **Storm Crystals** = the harvest. Creatures on your display produce crystals in a ring around your Nest. Rivals can grab them (short hold), an **alarm** goes off for the owner, and the thief is outlined red. If the owner touches the thief, the crystal flies back. Standing on your Nest banks crystals. The display collection itself is never stealable.
- Weather is born in a central **storm cloud** and flies to its spawn spot.
- High-graphics pass: lighting/atmosphere preset, glass UI, burst VFX, drifting decorative islands (tag `FloatingIsland`).

## Update 2 — Vault Spheres (director request, replaces Storm Crystals)

- Wild weather floats inside **glass spheres**. **Touch** to grab; carrying slows speed and jump a bit.
- Each base has **5 Vault Spheres**. Delivering drops the storm into an empty vault: coins now + **passive income** while it stays (10% of its value every 5 s). Vault full → it's sold for double.
- **Rivals can touch a full vault to steal its storm** (this supersedes "the permanent collection is always safe"). Owner gets an alarm; everyone sees a red center banner "X stole Y's Storm!"; the thief is outlined red. If the owner touches the thief, the storm flies back to the vault.

## Update 3 — Steal a Cloud (director request)

- **Name: Steal a Cloud.**
- **Map**: Spawn Area (6 hex bases along a plaza) → long **Sky Path** with 3 zones. A new cloud spawns in **Breeze Zone 70% / Thunder Canyon 25% / Cosmic Stratosphere 5%**.
  - Breeze: Cumulus, Rain, Snow · Thunder Canyon: Cumulonimbus (key `Thunder`), Pocket Tornado · Cosmic: Cosmic Neon, Auroral, Chrono.
  - Thunder Canyon splits into a Snow lane (water gap), a Tornado lane (lift platform) and a longer detour.
- **Cloud Altars** (mid-map + end of zone 3): every 45 s an empty altar raises a zone-3 cloud; 0.01% chance of the **Mythic Storm Cloud** (server announcement).
- **Base Lock**: owner steps on the LockPad → 60 s ForceField shield; rivals are pushed out and can't steal; then 90 s recharge.
- **Cloud looks**: soft puffs + smoke breathing from the center; Cumulonimbus lightning arcs, Cosmic rainbow stars + hue cycle, Auroral waving light ribbons, Chrono time sparks, Mythic = all.

## Update 4 — Carry & inventory rules (final, director request)

- **E-key only**: every cloud has a ProximityPrompt (Catch 0.3 s hold, Mythic 1.5 s, Steal 1.2 s). Nothing is picked up by touch.
- **Carried clouds** (wild or stolen) are never in the inventory: welded over your head, slower walk, lower jump, worse grip on ice.
- **Inventory** (3 slots, saved) holds only **charms** made at your own vault (hold F): Snow → **Ice Charm** (Q: 8 s Frost Skates, 20 s cooldown), Cumulonimbus → **Storm Charm** (passive: immune to Electric Swamps).
- **Death** wipes the inventory and destroys the carried cloud (a stolen cloud does NOT go back).
- **Hazards** (`Map/Hazards`, attribute `HazardType`): narrow **Ice Path** bridge between Breeze Zone and Altar 1 (low grip, random slips while carrying, fall = death); **Electric Swamp** across Thunder Canyon (slow + 8 dmg / 0.5 s, 14 while carrying).

## Update 5 — Leash, single path, volumetric clouds, full HUD (director request)

- **Leash**: carried clouds float behind you on a rope held in your **left hand** (RopeConstraint + AlignPosition, network-owned by the carrier). The right hand stays free → items usable any time.
- **Inventory = 3 fixed slots**: 1 cloud charm (Q / passive), 2 **Nitro** charges (R, bought at the plaza Nitro Station, 25 coins, max 3), 3 reserved for ignite/fuel items (T). All lost on death.
- **Single path, no shortcuts or detours**: Spawn Area → **Gate 1 Ice Path** → Breeze → **Gate 2 Electric River** (pulses calm 2.6 s / warn 0.6 s / shock 1.2 s — time your crossing) → Thunder Canyon (+Altar 1) → **Gate 3 Storm Bridge** (6 studs wide, lightning on red warning circles, side gusts) → Cosmic Stratosphere → Altar 2. Water-gap / lift-platform shortcuts removed from the placeholder (code still supports them in custom maps).
- **Volumetric clouds**: puffs + 4 smoke layers (Fill, Wisps, Glow, Smoke) + breathing inner light.
- **HUD**: top-center zone pill + alert panel (red thefts, amber gate warnings) + hints; top-right status (coins, leashed cloud + rarity, vault x/y); bottom-left item slots.

## Update 6 — Perks, Tayron's Cloud Shop, new cloud shapes, pastel sky (director request)

- **Perks (risk/reward)**: every cloud type has a perk (Cumulus +40% jump, Rain no-slip, Snow ice grip, Cumulonimbus electric immunity, Tornado wind immunity, Cosmic +50% speed, Aurora regen, Chrono 2× item time, Mythic all-round). Hold **F** on a cloud in **your own vault** → it moves into the **Quirks/Perks inventory** (2 slots) and the perk is active. "↩ Vault" puts it back. **Die while equipped → the cloud is destroyed.**
- **Two inventories**: Inventory (shop items, 4 slots, keys 1-4) and Quirks/Perks. Charms (v0.7/v0.8) and the Q/R/T bar are replaced by this.
- **Cloud Shop** behind the spawn: wooden stall, pastel awning, cloud roof, lanterns, potions. **Tayron** (R15 NPC, procedural idle/look/wave, greeting bubble). E → glass Shop UI: Speed Potion, Jump Potion, Nitro, Signal Flare, Fuel Can (coming soon).
- **Clouds** are no longer spheres: asymmetric stacks of ellipsoids (SpecialMesh) + smoke layers; each puff breathes on its own rhythm, speed per type.
- **Sky**: golden-hour pastel lighting, lilac/peach atmosphere, Terrain Clouds, stronger sun rays.

## Update 7 — Hexagon Hub, 12 bases, updraft, two vendors per base (director request)

- **Fixes**: emoji removed from all UI text (newer emoji render as boxes) → coloured text chips; NPC animation now uses real AnimationTracks from KeyframeSequences built in code (fallback: joint posing in Stepped, after the Animator).
- **Map**: no baseplate/default spawn references. Central **Hexagon Hub** (radius 60) with 6 spawn pads, pillars, neon rim. **12 bases** around it (radius 95, facing the hub, bridges). **Updraft** in the hub center lifts you to the **Sky Landing** (Y 130); the **Descent** chute glides you back. Sky path: Gate 1 Ice → Breeze → Gate 2 River → Canyon (+Altar 1) → Gate 3 Storm Bridge → Cosmic → Altar 2.
- **New clouds/perks**: Frost Cloud (ice grip), Thunder Storm (static field slows rivals + electric immunity), **Phoenix** (+25% speed, half lightning damage/knockback), **Void Star** (G/H/J: blink + 3 s invisibility), **Solar Flare** (x1.5 coins, ability: blind nearby rivals).
- **Vendors on every base** (Market ledge): **Tayron** (temporary items) and **Aurelius** (permanent upgrades: speed, jump, carry speed, vault income, +1 perk slot — kept on death).

## Update 8 — Day/night, 2 hub shops, 7 items (director request)

- **Lighting** toned down (exposure −0.1…−0.25, bloom only on neon, gentle grading). **Day/night cycle**: 10 min per day; sky haze, ambient, tint and sky clouds blend through dawn/day/dusk/night. `workspace.IsNight`.
- **Clouds by time**: Day — Cumulus, Rain, Tornado, Phoenix, Speed Cloud (Cosmic), Solar. Night — Frost (Snow), Thunder Storm, Void, Aurora. Any — Chrono, Mythic. At sunrise/sunset the wild clouds of the other half fade. The tutorial Cumulus on the hub is gone.
- **No descent chute**: jump down from the sky to return. Updraft only goes up.
- **Only 2 shops**, on opposite corners of the hub: Item Shop (Tayron, west) and Upgrades (Aurelius, east). Per-base vendors removed.
- **7 items**: Laser Gun (shoot a thief carrying YOUR cloud → it flies home; others slowed + 10 dmg), Speed Potion, Jump Potion, Nitro, Signal Flare, Shield Generator (on your base: instant 30 s base shield; elsewhere: 10 s personal ForceField, can't be tagged/shot), Grappling Hook (zip up to 90 studs). Keys 1-7; aimed items use the mouse.

## Update 9 — Floating Continent, 56 clouds, death-cloud floor (director request)

- **Updraft**: Lift 110, rises through a hole in the continent's center and launches you onto the continent (ballistic arc to r ≈ 28).
- **Floating Continent** (Y 200, radius ~182, 48 slices): Plateau (center + east/west), Mountains (north, three terraced peaks with icy ledges, Altar 1 on the summit), Valley (south, stepped down 12 studs, pits to the death clouds, electric river arcs, storm bridge over the pit), Coast (sand ring + shallows, Altar 2). Floor parts carry biome attributes; the HUD reads the ground under you.
- **56 clouds** in `Shared/CloudDB.luau`: 16 Common, 14 Rare, 12 Epic, 8 Legendary, 6 Mythic. Tier roll 60/25/10.5/4/0.5 %, then weighted pick among clouds allowed in that biome at that time. Rarer = bigger perks and rewards. Altars roll Epic+. `WeatherTypes.ChanceTable(biome, isNight)` shows real %.
- **Bases** moved to radius 140 with an empty **Expansion pad** beside each.
- **Death Cloud floor** at Y −20 replaces the void: thick cloud sea; touching it kills, you respawn at your own base.

## Update 10 — Huge continent, 7 biomes, 106 clouds, world events (director request)

- **Continent** radius ~314 (was ~182), built by `Services/ContinentBuilder.luau`: Sky Heart center, six 60° sectors (Plateau Meadows, Mountains & Snowpeaks, Mushroom Plateaus, Storm Marshes, Crystal Canyons with pits + caves, Volcanic Caldera with lava), Coast ring. 3 altars. ~85 spawn points.
- **106 clouds** (`CloudDB`), new categories: Elemental (Fire/Ice/Electric/Poison/Water/Earth), SpaceTime, Economic (bonus XP, item drops), Chaos. New perks: low gravity, lava/acid immunity, Chaos (random buff/debuff every 20 s), Quake ability. XP + Level leaderstat.
- **World events** (`EventService`, every 4-7 min, 75 s): Meteor Shower (Epic+ clouds crash into a biome), Acid Rain (damage outside shelter in one biome), Fog Bank (dense fog, faster stealing).
- **Performance**: StreamingEnabled (set in `default.project.json`), persistent updraft/base models, client LOD for decor particles and lights.
- **Updraft**: Lift 140, one arc into the Sky Heart.

## CURRENT RULES (authoritative — overrides anything above)

The "Update" sections above are history. If they conflict with this section, this section wins.

**Core loop**
1. Ride the **updraft** from the Hexagon Hub up to the Floating Continent.
2. **Catch** a wild cloud (hold E). It follows you on a **leash**; your hands stay free for items.
3. Bring it home over the bridges to your **base** (one of 12) and drop it into an empty **Vault Sphere** (4 per base).
4. Filled vaults pay **passive income**; a cloud in a vault can be equipped as a **Perk** (up to the PerkSlots limit).
5. **Steal**: rivals can take clouds out of your vaults (hold E) unless your base is **locked** (LockPad, 60 s, then cooldown). Owner gets an alarm; touching the thief tags the cloud back.
6. Spend coins at the two hub shops: **Tayron** (7 consumable items) and **Aurelius** (permanent upgrades).

**Rules**
- Clouds come from `Shared/CloudDB.luau` (106, five rarity tiers, categories Classic/Elemental/SpaceTime/Economic/Chaos). Rarer = bigger reward and stronger perk. Shiny variants are worth more but never stronger.
- Spawns depend on biome (Plateau, Coast, Mountains, Mushroom, Marsh, Canyon, Volcanic) and day/night. Altars roll Epic or better. World events add meteor clouds, acid rain and fog.
- Falling into the Death Cloud floor kills you; you respawn at your own base. Dying drops your carried cloud and wipes items.
- No tutorial guaranteed cloud, no crystal crates, no "safe permanent collection": vault clouds CAN be stolen.
- UI: English only, no emoji (colour text chips).

**Monetization (later, no pay-to-win)**: cosmetics only (base themes, leash/jar looks, emotes, visual-only celebrations). Never sell luck, stealing power, immunity or stronger clouds.

**Playtest questions**: Can a new player reach the continent and make the first delivery without help? Does a steal feel fair to both players? Do players come back for rarer clouds?
