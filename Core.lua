local ADDON, KL = ...

KL.ALLOWED_DIFFICULTY = { [15] = true }   -- 15 = Heroic raid. Add [16] = true for Mythic.
KL.WINDOW = 5                             -- seconds to listen for AOTC messages after a kill
KL.filter = { season = nil, search = "", range = "all", aotcOnly = false, bossOff = {} }
local DB

function KL.Norm(s) return (tostring(s or ""):lower():gsub("[^%w]", "")) end
local function Print(msg) print("|cffe8b84aWild Grace Kill Ledger:|r " .. msg) end
KL.Print = Print

-- ---------------------------------------------------------------- database
local function InitDB()
  KillLedgerDB = KillLedgerDB or {}
  DB = KillLedgerDB
  DB.version = DB.version or 1
  DB.nextId = DB.nextId or 1
  DB.kills = DB.kills or {}
  DB.tracked = DB.tracked or {}
  DB.trackedInfo = DB.trackedInfo or {}
  DB.goals = DB.goals or {}
  DB.manual = DB.manual or {}
  DB.bossNames = DB.bossNames or {}
  DB.goalShow = DB.goalShow or {}
  DB.viewers = DB.viewers or {}
  local v = DB.viewers
  if v.show == nil then v.show = true end
  v.layout = v.layout or "card"
  v.bg = v.bg or "dark"
  v.scale = v.scale or 1
  v.message = v.message or "{boss} AoTCs earned this season: {current}/{goal}"
  v.title = v.title or "AoTCs earned this season"
  DB.learned = DB.learned or {}
  DB.learnedAch = DB.learnedAch or {}
  DB.achOverride = DB.achOverride or {}
  DB.aotcWords = DB.aotcWords or {}
  for _, k in ipairs(DB.kills) do
    if k.adjust == nil then k.adjust = (k.aotc or 0) - #(k.who or {}) end
  end
  KL.db = DB
end

function KL.Recount(k) k.aotc = math.max(0, #k.who + (k.adjust or 0)) end

-- ---------------------------------------------------------------- bosses / seasons
-- Reads every raid boss from the Adventure Guide (Encounter Journal), newest expansion first. Groups = raids.
function KL.Journal()
  if KL.journal then return KL.journal, KL.journalGroups end
  local list, groups, seenGroup, seenKey = {}, {}, {}, {}
  if EJ_GetNumTiers and EJ_GetInstanceByIndex then
    local oldTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
    for tier = EJ_GetNumTiers(), 1, -1 do
      EJ_SelectTier(tier)
      local tierName = EJ_GetTierInfo(tier)
      local i = 1
      while true do
        local instID, instName = EJ_GetInstanceByIndex(i, true)
        if not instID then break end
        EJ_SelectInstance(instID)
        local label = instName
        local j = 1
        while true do
          local name, _, _, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(j)
          if not name then break end
          local key = "ej:" .. (dungeonEncounterID or KL.Norm(name))
          if not seenKey[key] then
            seenKey[key] = true
            list[#list + 1] = { key = key, name = name, raid = instName, seasonId = label, seasonName = label, encounterID = dungeonEncounterID }
            if not seenGroup[label] then seenGroup[label] = true; groups[#groups + 1] = label end
          end
          j = j + 1
        end
        i = i + 1
      end
    end
    if oldTier and EJ_SelectTier then EJ_SelectTier(oldTier) end
  end
  if #list > 0 then KL.journal, KL.journalGroups = list, groups end   -- retry later if the journal was not ready
  return list, groups
end

function KL.KnownBosses()
  local out = {}
  for _, b in pairs(DB.trackedInfo) do out[#out + 1] = b end
  for _, b in ipairs((KL.Journal())) do out[#out + 1] = b end
  return out
end

function KL.SeasonName(id)
  if id == nil then return "Unknown" end
  for _, k in ipairs(DB.kills) do if k.season == id and k.seasonName then return k.seasonName end end
  return tostring(id)
end

function KL.SeasonsWithKills()   -- newest activity first
  local last, ids = {}, {}
  for _, k in ipairs(DB.kills) do
    if not last[k.season] then ids[#ids + 1] = k.season; last[k.season] = k.ts
    elseif k.ts > last[k.season] then last[k.season] = k.ts end
  end
  table.sort(ids, function(a, b) return last[a] > last[b] end)
  return ids
end

function KL.BossesWithKills(season)
  local seen, out = {}, {}
  for _, k in ipairs(DB.kills) do
    if (not season or k.season == season) and not seen[k.boss] then
      seen[k.boss] = true
      out[#out + 1] = { key = k.boss, name = k.bossName, tracked = DB.tracked[k.boss] and true or false }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- boss = a record from the journal. A snapshot is stored so logging works without the journal.
function KL.SetTracked(boss, on)
  if on then
    DB.tracked[boss.key] = true
    DB.trackedInfo[boss.key] = { key = boss.key, name = boss.name, raid = boss.raid, seasonId = boss.seasonId,
                                 seasonName = boss.seasonName, encounterID = boss.encounterID }
  else
    DB.tracked[boss.key] = nil
    DB.trackedInfo[boss.key] = nil
  end
end

local function FindBoss(encID, encName)
  for _, b in pairs(DB.trackedInfo) do
    if b.encounterID and b.encounterID == encID then return b end
  end
  local n = KL.Norm(encName)
  if n == "" then return nil end
  for _, b in pairs(DB.trackedInfo) do
    local nb = KL.Norm(b.name)
    if n == nb or n:find(nb, 1, true) or nb:find(n, 1, true) then
      b.encounterID = encID   -- failsafe: remember the ID for next time
      return b
    end
  end
end

-- ---------------------------------------------------------------- AOTC detection
local function LooksLikeAotc(boss, achID, achName)
  local forced = DB.achOverride[boss.key] or DB.learnedAch[boss.key]
  if forced then return forced == achID end
  local n = KL.Norm(achName)
  if not n:find(KL.Norm(boss.name), 1, true) then return false end
  local words = {}
  for _, w in ipairs(KL.AotcWords) do words[#words + 1] = w end
  for _, w in ipairs(DB.aotcWords) do words[#words + 1] = w end
  local lower = tostring(achName or ""):lower()
  for _, w in ipairs(words) do
    if lower:find(w, 1, true) then return true end
  end
  return false
end

local function RegisterAchievement(achID, who)
  local w = KL.watch
  if not w or GetTime() > w.expires or not achID then return end
  local achName = select(2, GetAchievementInfo(achID))
  if not achName or not LooksLikeAotc(w.boss, achID, achName) then return end
  DB.learnedAch[w.boss.key] = DB.learnedAch[w.boss.key] or achID
  local short = (strsplit("-", who))
  if w.seen[short] then return end
  w.seen[short] = true
  local k = w.kill
  k.who[#k.who + 1] = who
  KL.Recount(k)
  if KL.UI and KL.UI.UpdateToast then KL.UI.UpdateToast(k) end
end

-- ---------------------------------------------------------------- events
function KL.ENCOUNTER_END(encID, encName, difficultyID, groupSize, success)
  if success ~= 1 or not KL.ALLOWED_DIFFICULTY[difficultyID] then return end
  local boss = FindBoss(encID, encName)
  if not boss then return end
  local kill = {
    id = DB.nextId, ts = time(), boss = boss.key, bossName = boss.name, raid = boss.raid,
    season = boss.seasonId, seasonName = boss.seasonName, aotc = 0, who = {}, adjust = 0,
    note = "",
  }
  DB.nextId = DB.nextId + 1
  DB.kills[#DB.kills + 1] = kill
  local watch = { kill = kill, boss = boss, seen = {}, expires = GetTime() + KL.WINDOW }
  KL.watch = watch
  C_Timer.After(KL.WINDOW + 0.5, function()
    if KL.watch == watch then KL.watch = nil end
    if KL.UI and KL.UI.RefreshAll then KL.UI.RefreshAll() end
  end)
  if KL.UI and KL.UI.OnKill then KL.UI.OnKill(kill) end
end

function KL.CHAT_MSG_ACHIEVEMENT(text, playerName)
  if issecretvalue and (issecretvalue(text) or issecretvalue(playerName)) then return end
  local id = tostring(text or ""):match("|Hachievement:(%d+)")
  if id and playerName and playerName ~= "" then RegisterAchievement(tonumber(id), Ambiguate(playerName, "none")) end
end

function KL.ACHIEVEMENT_EARNED(achID, alreadyEarned)
  if alreadyEarned then return end
  RegisterAchievement(achID, UnitName("player"))
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if (...) ~= ADDON then return end
    InitDB()
    for _, e in ipairs({ "ENCOUNTER_END", "CHAT_MSG_ACHIEVEMENT", "ACHIEVEMENT_EARNED" }) do ev:RegisterEvent(e) end
    ev:UnregisterEvent("ADDON_LOADED")
  elseif KL[event] then
    KL[event](...)
  end
end)

-- ---------------------------------------------------------------- queries
function KL.FilteredKills(f)
  f = f or KL.filter
  local cutoff
  if f.range == "today" then
    local t = date("*t"); t.hour, t.min, t.sec = 0, 0, 0; cutoff = time(t)
  elseif f.range == "7d" then cutoff = time() - 7 * 86400
  elseif f.range == "30d" then cutoff = time() - 30 * 86400 end
  local q = (f.search or ""):lower()
  local out = {}
  for _, k in ipairs(DB.kills) do
    local ok = (not f.season or k.season == f.season) and not f.bossOff[k.boss]
      and (not cutoff or k.ts >= cutoff) and (not f.aotcOnly or k.aotc > 0)
    if ok and q ~= "" then
      local hay = (k.bossName .. " " .. (k.raid or "") .. " " .. (k.note or "") .. " " .. table.concat(k.who, " ")
        .. " " .. date("%Y-%m-%d %H:%M", k.ts)):lower()
      ok = hay:find(q, 1, true) ~= nil
    end
    if ok then out[#out + 1] = k end
  end
  table.sort(out, function(a, b) if a.ts ~= b.ts then return a.ts > b.ts end return a.id > b.id end)
  return out
end

function KL.DeleteKill(id)
  for i, k in ipairs(DB.kills) do
    if k.id == id then
      table.remove(DB.kills, i); KL.lastDeleted = k
      if KL.UI and KL.UI.RefreshAll then KL.UI.RefreshAll() end
      return true
    end
  end
end
function KL.Undo()
  if KL.lastDeleted then
    table.insert(DB.kills, KL.lastDeleted); KL.lastDeleted = nil
    if KL.UI and KL.UI.RefreshAll then KL.UI.RefreshAll() end
    return true
  end
end

function KL.Stats(kills)
  local s = { kills = #kills, aotc = 0, bestDay = nil, bestCount = 0, days = {}, bosses = {} }
  local perDay, perBoss, dayKeys = {}, {}, {}
  for _, k in ipairs(kills) do
    s.aotc = s.aotc + k.aotc
    local d = date("%Y-%m-%d", k.ts)
    if not perDay[d] then perDay[d] = 0; dayKeys[#dayKeys + 1] = d end
    perDay[d] = perDay[d] + k.aotc
    local b = perBoss[k.bossName]
    if not b then b = { name = k.bossName, aotc = 0, kills = 0 }; perBoss[k.bossName] = b; s.bosses[#s.bosses + 1] = b end
    b.aotc, b.kills = b.aotc + k.aotc, b.kills + 1
  end
  table.sort(dayKeys)
  for _, d in ipairs(dayKeys) do
    if perDay[d] > s.bestCount then s.bestCount, s.bestDay = perDay[d], d end
  end
  for i = math.max(1, #dayKeys - 9), #dayKeys do s.days[#s.days + 1] = { day = dayKeys[i], aotc = perDay[dayKeys[i]] } end
  table.sort(s.bosses, function(a, b) return a.aotc > b.aotc end)
  s.avg = s.kills > 0 and (s.aotc / s.kills) or 0
  return s
end

-- ---------------------------------------------------------------- export / import
local function CsvEscape(s)
  s = tostring(s or "")
  if s:find('[,"\n]') then return '"' .. (s:gsub('"', '""')) .. '"' end
  return s
end

function KL.ExportText(kills, format, includeWho)
  local sorted = {}
  for i, k in ipairs(kills) do sorted[i] = k end
  table.sort(sorted, function(a, b) return a.ts > b.ts end)
  local lines, total = {}, 0
  if format == "plain" then
    for _, k in ipairs(sorted) do
      total = total + k.aotc
      local line = date("%Y-%m-%d %H:%M", k.ts) .. " | " .. k.bossName .. " (" .. (k.raid or "?") .. ") | +" .. k.aotc .. " AOTC"
      if includeWho and #k.who > 0 then line = line .. " | " .. table.concat(k.who, ", ") end
      lines[#lines + 1] = line
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = #sorted .. " kills, " .. total .. " AOTCs"
  else
    lines[1] = "date,time,boss,raid,season,aotcs,who,note"
    for _, k in ipairs(sorted) do
      lines[#lines + 1] = table.concat({
        date("%Y-%m-%d", k.ts), date("%H:%M", k.ts), CsvEscape(k.bossName), CsvEscape(k.raid), CsvEscape(k.season),
        k.aotc, CsvEscape(includeWho and table.concat(k.who, ";") or ""), CsvEscape(k.note) }, ",")
    end
  end
  return table.concat(lines, "\n")
end

local function ParseCsvLine(line)
  local f, i, n = {}, 1, #line
  while i <= n + 1 do
    if line:sub(i, i) == '"' then
      local j, buf = i + 1, {}
      while true do
        local c = line:sub(j, j)
        if c == "" then break end
        if c == '"' then
          if line:sub(j + 1, j + 1) == '"' then buf[#buf + 1] = '"'; j = j + 2 else break end
        else buf[#buf + 1] = c; j = j + 1 end
      end
      f[#f + 1] = table.concat(buf); i = j + 2
    else
      local j = line:find(",", i, true) or (n + 1)
      f[#f + 1] = line:sub(i, j - 1); i = j + 1
    end
  end
  return f
end

function KL.Import(text)
  local added, skipped, bad = 0, 0, 0
  local have = {}
  for _, k in ipairs(DB.kills) do have[math.floor(k.ts / 60) .. KL.Norm(k.bossName)] = true end
  local byName = {}
  for _, b in ipairs(KL.KnownBosses()) do byName[KL.Norm(b.name)] = b end
  for line in tostring(text):gmatch("[^\r\n]+") do
    local f = ParseCsvLine(line)
    if f[1] ~= "date" then
      local y, m, d = (f[1] or ""):match("^(%d+)-(%d+)-(%d+)$")
      local hh, mm = (f[2] or ""):match("^(%d+):(%d+)$")
      if y and hh and f[3] and f[3] ~= "" then
        local ts = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = tonumber(hh), min = tonumber(mm), sec = 0 })
        local sig = math.floor(ts / 60) .. KL.Norm(f[3])
        if have[sig] then skipped = skipped + 1
        else
          have[sig] = true
          local known = byName[KL.Norm(f[3])]
          local who = {}
          for name in (f[7] or ""):gmatch("[^;]+") do who[#who + 1] = name end
          DB.kills[#DB.kills + 1] = {
            id = DB.nextId, ts = ts, boss = known and known.key or ("imported:" .. KL.Norm(f[3])), bossName = f[3],
            raid = f[4], season = (f[5] ~= "" and f[5]) or (known and known.seasonId) or "imported",
            seasonName = known and known.seasonName, aotc = tonumber(f[6]) or 0, who = who, adjust = (tonumber(f[6]) or 0) - #who, note = f[8] or "",
            }
          DB.nextId = DB.nextId + 1
          added = added + 1
        end
      else bad = bad + 1 end
    end
  end
  return added, skipped, bad
end

-- ---------------------------------------------------------------- slash commands
function KillLedger_OnCompartmentClick() KL.Toggle() end

SLASH_KILLLEDGER1, SLASH_KILLLEDGER2 = "/kl", "/killledger"
SlashCmdList["KILLLEDGER"] = function(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "" then KL.Toggle()
  elseif cmd == "minimap" then KL.ToggleMinimap()
  elseif cmd == "viewers" then KL.UI.ToggleDisplay()
  elseif cmd == "undo" then Print(KL.Undo() and "last deleted kill restored." or "nothing to undo.")
  elseif cmd == "test" then
    local b = KL.KnownBosses()[1]
    if not b then return Print("no bosses found yet; open the Adventure Guide once and try again.") end
    local n, who = math.random(1, 12), {}
    for i = 1, n do who[i] = ("Testplayer%d-Realm"):format(i) end
    local kill = { id = DB.nextId, ts = time(), boss = b.key, bossName = b.name, raid = b.raid, season = b.seasonId,
      seasonName = b.seasonName, aotc = n, who = who, adjust = 0,
      note = "TEST - safe to delete" }
    DB.nextId = DB.nextId + 1
    DB.kills[#DB.kills + 1] = kill
    if KL.UI and KL.UI.OnKill then KL.UI.OnKill(kill) end
  elseif cmd == "aotcword" and rest ~= "" then
    DB.aotcWords[#DB.aotcWords + 1] = rest:lower(); Print("added match word: " .. rest:lower())
  elseif cmd == "ach" then
    local key, id = rest:match("^(%S+)%s+(%d+)$")
    if not key then return Print("usage: /kl ach <bossKey> <achievementID>   (keys are in Data.lua)") end
    DB.achOverride[key] = tonumber(id); Print("achievement for " .. key .. " set to " .. id)
  elseif cmd == "findach" and rest ~= "" then
    local needle, id, found = KL.Norm(rest), 0, 0
    local function scan()
      for _ = 1, 1500 do
        id = id + 1
        local name = select(2, GetAchievementInfo(id))
        if name and KL.Norm(name):find(needle, 1, true) then found = found + 1; Print(id .. "  " .. name) end
      end
      if id < 90000 then C_Timer.After(0, scan) else Print("scan finished, " .. found .. " match(es).") end
    end
    Print("scanning achievements for '" .. rest .. "'...")
    scan()
  else
    Print("/kl  open | /kl undo | /kl minimap | /kl viewers | /kl test | /kl findach <text> | /kl ach <bossKey> <id> | /kl aotcword <text>")
  end
end
