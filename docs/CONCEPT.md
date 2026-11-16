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

## Core loop

1. **Hunt** weather creatures in the shared zone.
2. **Choose**: deliver now for a safe reward, or push on for a better variant?
3. **Carry** it, using its effect to pass obstacles.
4. **Place** it on your rooftop: collection or production slot.
5. **Harvest** weather crystals → decoration, recipes, equipment.
6. **Risk** (optional): snatch rivals' harvest crates in the competition area, or defend yours.
7. **Display & share** your rooftop. Trading comes in later versions.

**The permanent collection is always safe.** Only harvest crates placed in the competition area and not yet delivered can be stolen.

## First 30 seconds

| Time | Experience |
|---|---|
| 0–5 s | A small rain cloud bounces in front of you. One instruction: **"Catch the cloud!"** |
| 5–12 s | One button catches it. It goes into a clear jar; small puddles form around you. |
| 12–22 s | Following a short path, you slip comically on your own water. No penalty for failing. |
| 22–30 s | Drop it at your rooftop nest, get the first (guaranteed) reward; another catchable type appears nearby. |

## Rarity

Variants depend on discovery conditions (e.g. a tornado caught in rain in a certain zone looks different) and on published random odds. **Rarest variants are never stronger in competition.**

## Monetization (no pay-to-win)

| Product | Value | Limit |
|---|---|---|
| Sky Architect Pass | Rooftop facades, decoration themes, ambient music | No production/defense boost |
| Collector Style Packs | Jar, catching tool and outfit looks | No range/speed/catch-rate change |
| Emote Packs | Cloud dance, scared-of-lightning, victory poses | No movement advantage |
| Celebration DevProduct | Short visual-only celebration after delivery | Doesn't block view or change rewards |

Never sold: luck boosts, paid stealing, paid immunity, stronger clouds. Cosmetics must never hide which weather type a rival is carrying.

## MVP (first prototype)

- One rooftop neighbourhood
- Three weather types: **Rain cloud, Pocket tornado, Snow cloud**
- Two weather interactions
- One delivery route
- One simple harvest-crate snatch area

Not in MVP: trading, big map, many variants.

**Playtest questions:** Can a new player make the first delivery without explanation? Do they start a second run on their own? Do they try a weather combo with a friend and want to repeat it?
