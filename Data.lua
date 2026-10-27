-- Data.lua : optional settings. Raids and bosses come from the in-game Adventure Guide (Encounter Journal).
local ADDON, KL = ...

-- The addon counts a player when an announced achievement contains the boss name AND one of these words
-- (lowercase, matched as plain text). "heroic:" covers bosses that have no AOTC, like "Heroic: Kith'ix".
-- Each player counts once per kill even if they earn several of these. Add your client's language with: /kl aotcword <text>
KL.AotcWords = { "ahead of the curve", "heroic:" }
