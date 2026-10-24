-- Data.lua : optional settings. Raids and bosses come from the in-game Adventure Guide (Encounter Journal).
local ADDON, KL = ...

-- Words that must appear in the achievement name for AOTC detection (lowercase, matched as plain text).
-- Add your client's language with: /kl aotcword <text>
KL.AotcWords = { "ahead of the curve" }
