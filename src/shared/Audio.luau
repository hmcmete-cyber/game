-- Music & sound settings. Change music here — nothing else needs editing.
--
-- HOW TO ADD MUSIC
--   1. Studio → Toolbox (or create.roblox.com/store) → Audio → Music.
--      Pick tracks you're allowed to use (Roblox's licensed library is safe).
--   2. Right-click the track → "Copy Asset ID".
--   3. Paste it below as "rbxassetid://123456789".
-- An empty SoundId ("") is simply skipped, so the game works without music.
--
-- Tracks
--   Hub      calm, airy — the hexagon hub and your base
--   Sky      faster, upbeat — the cloud zones up in the sky
--   HubNight / SkyNight (optional) — used at night; empty = use the day track

local Audio = {}

Audio.Music = {
	Hub = { SoundId = "", Volume = 0.45 },
	Sky = { SoundId = "", Volume = 0.55 },
	HubNight = { SoundId = "", Volume = 0.4 },
	SkyNight = { SoundId = "", Volume = 0.5 },
}

-- Master volumes (SoundService SoundGroups). Players can mute music with M.
Audio.Groups = {
	Music = 0.6,
	SFX = 0.8,
}

-- Height above which you're "up in the clouds" (sky level is 130)
Audio.SkyHeight = 110

-- Seconds to crossfade between tracks
Audio.FadeTime = 2.5

return Audio
