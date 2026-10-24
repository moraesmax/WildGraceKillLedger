local ADDON, KL = ...
local UI = KL.UI
local GOLD, MUTED = "|cffe8b84a", "|cffa39e90"

-- ================================================================ BOSSES
UI.addSeason, UI.addFilter, UI.addPage = nil, "", 1
local ADD_ROWS = 9

local function MakeBossRow(p, list, i, x, w)
  local row = CreateFrame("Frame", nil, p)
  row:SetSize(w, 30); row:SetPoint("TOPLEFT", x, -92 - (i - 1) * 30)
  row.text = UI.Label(row, ""); row.text:SetPoint("LEFT", 4, 0); row.text:SetWidth(w - 110); row.text:SetWordWrap(false)
  row.btn = UI.Button(row, "", 96, 22, function(self) self.fn() end)
  row.btn:SetPoint("RIGHT", 0, 0)
  list[i] = row
  return row
end

function UI.BuildBosses()
  local p = UI.panels.Bosses
  p.trackedRows, p.addRows = {}, {}
  UI.Label(p, GOLD .. "Currently tracked|r", "GameFontNormalLarge"):SetPoint("TOPLEFT", 8, -4)
  UI.Label(p, MUTED .. "Only these bosses are logged. Stopping never deletes past kills.|r", "GameFontHighlightSmall"):SetPoint("TOPLEFT", 8, -28)
  UI.Label(p, GOLD .. "All raid bosses (Adventure Guide)|r", "GameFontNormalLarge"):SetPoint("TOPLEFT", 400, -4)
  local season = UI.Cycle(p, 190, function()
    return UI.addSeason and KL.SeasonName(UI.addSeason) or "All raids"
  end, function(dir)
    local _, groups = KL.Journal()
    local list = { false }
    for _, g in ipairs(groups or {}) do list[#list + 1] = g end
    UI.addSeason = UI.CycleList(list, UI.addSeason or false, dir) or nil
    UI.addAll = (UI.addSeason == nil)
    UI.addPage = 1
  end)
  season:SetPoint("TOPLEFT", 400, -30)
  p.seasonBtn = season
  local filter = UI.Input(p, 130, "Search boss or raid..."); filter:SetPoint("LEFT", season, "RIGHT", 14, 0)
  filter:HookScript("OnTextChanged", function(self, user)
    if user then UI.addFilter = self:GetText():lower(); UI.addPage = 1; UI.RefreshBosses() end
  end)
  p.msg = UI.Label(p, "", "GameFontHighlightSmall"); p.msg:SetPoint("TOPLEFT", 400, -62); p.msg:SetWidth(340)
  p.all = UI.Button(p, "Track all shown", 120, 22, function()
    for _, b in ipairs(p.shown or {}) do KL.SetTracked(b, true) end
    UI.RefreshBosses()
  end)
  p.all:SetPoint("BOTTOMLEFT", 400, 4); p.all:SetStyle("primary")
  p.next = UI.Button(p, ">", 28, 22, function() UI.addPage = UI.addPage + 1; UI.RefreshBosses() end); p.next:SetPoint("BOTTOMRIGHT", -4, 4)
  p.pageText = UI.Label(p, "", "GameFontHighlightSmall"); p.pageText:SetPoint("RIGHT", p.next, "LEFT", -8, 0)
  p.prev = UI.Button(p, "<", 28, 22, function() UI.addPage = UI.addPage - 1; UI.RefreshBosses() end); p.prev:SetPoint("RIGHT", p.pageText, "LEFT", -8, 0)
end

function UI.RefreshBosses()
  local p = UI.panels.Bosses
  for _, r in ipairs(p.trackedRows) do r:Hide() end
  for _, r in ipairs(p.addRows) do r:Hide() end
  local db = KL.db
  -- tracked (from snapshots), grouped by season
  local bySeason, order, count = {}, {}, 0
  for _, b in pairs(db.trackedInfo) do
    if not bySeason[b.seasonId] then bySeason[b.seasonId] = {}; order[#order + 1] = b.seasonId end
    table.insert(bySeason[b.seasonId], b); count = count + 1
  end
  table.sort(order)
  local i = 0
  for _, sid in ipairs(order) do
    table.sort(bySeason[sid], function(a, b) return a.name < b.name end)
    if i < 10 then
      i = i + 1
      local h = p.trackedRows[i] or MakeBossRow(p, p.trackedRows, i, 0, 380)
      h.text:SetText(GOLD .. KL.SeasonName(sid) .. "|r"); h.btn:Hide(); h:Show()
    end
    for _, b in ipairs(bySeason[sid]) do
      if i >= 11 then break end
      i = i + 1
      local r = p.trackedRows[i] or MakeBossRow(p, p.trackedRows, i, 0, 380)
      r.text:SetText(b.name)
      r.btn:SetText("Stop tracking"); r.btn:SetStyle("ghost"); r.btn:Show()
      r.btn.fn = function() KL.SetTracked(b, false); UI.RefreshBosses() end
      r:Show()
    end
  end
  if count == 0 then
    local r = p.trackedRows[1] or MakeBossRow(p, p.trackedRows, 1, 0, 380)
    r.text:SetText(MUTED .. "Nothing tracked yet. Pick bosses on the right.|r"); r.btn:Hide(); r:Show()
  elseif count > 10 then
    local r = p.trackedRows[12] or MakeBossRow(p, p.trackedRows, 12, 0, 380)
    r.text:SetText(MUTED .. "(" .. count .. " tracked; showing the first ones)|r"); r.btn:Hide(); r:Show()
  end
  -- journal list
  local list, groups = KL.Journal()
  if #list == 0 then
    p.msg:SetText("|cffff8080Adventure Guide data is not ready yet. Open it once (Shift+J), close it, then reopen this tab.|r")
    p.shown = {}; p.pageText:SetText(""); p.prev:Disable(); p.next:Disable(); return
  end
  if UI.addSeason == nil and not UI.addAll then UI.addSeason = groups[1] end
  p.seasonBtn:Update()
  p.msg:SetText("")
  local shown = {}
  for _, b in ipairs(list) do
    if (not UI.addSeason or b.seasonId == UI.addSeason)
      and (UI.addFilter == "" or (b.name .. " " .. b.raid):lower():find(UI.addFilter, 1, true)) then
      shown[#shown + 1] = b
    end
  end
  p.shown = shown
  local pages = math.max(1, math.ceil(#shown / ADD_ROWS))
  UI.addPage = math.min(math.max(UI.addPage, 1), pages)
  for n = 1, ADD_ROWS do
    local b = shown[(UI.addPage - 1) * ADD_ROWS + n]
    if b then
      local r = p.addRows[n] or MakeBossRow(p, p.addRows, n, 400, 350)
      r.text:SetText(UI.addSeason and b.name or (b.name .. MUTED .. "  " .. b.raid .. "|r"))
      local on = db.tracked[b.key]
      r.btn:SetText(on and "Stop" or "+ Track"); r.btn:SetStyle(on and "ghost" or "primary"); r.btn:Show()
      r.btn.fn = function() KL.SetTracked(b, not db.tracked[b.key]); UI.RefreshBosses() end
      r:Show()
    end
  end
  p.pageText:SetText(("Page %d / %d"):format(UI.addPage, pages))
  p.prev:SetEnabled(UI.addPage > 1); p.next:SetEnabled(UI.addPage < pages)
end

-- ================================================================ STATS
function UI.BuildStats()
  local p = UI.panels.Stats
  p.kpi, p.dayBars, p.bossBars = {}, {}, {}
  local season = UI.Cycle(p, 170, UI.SeasonLabel, UI.StepSeason); season:SetPoint("TOPLEFT", 8, -2)
  UI.Label(p, MUTED .. "Same raid filter as the Log tab|r", "GameFontHighlightSmall"):SetPoint("LEFT", season, "RIGHT", 12, 0)
  for i, cap in ipairs({ "Kills logged", "AOTCs gained", "Best day", "Avg AOTCs per kill" }) do
    local card = UI.Box(p); card:SetSize(176, 62); card:SetPoint("TOPLEFT", 8 + (i - 1) * 186, -38)
    local big = UI.Label(card, "", "GameFontNormalHuge"); big:SetPoint("TOPLEFT", 12, -8)
    local c = UI.Label(card, MUTED .. cap .. "|r", "GameFontHighlightSmall"); c:SetPoint("BOTTOMLEFT", 12, 8)
    p.kpi[i] = big
  end
  UI.Label(p, GOLD .. "AOTCs per day|r", "GameFontNormalLarge"):SetPoint("TOPLEFT", 8, -120)
  UI.Label(p, GOLD .. "By boss|r", "GameFontNormalLarge"):SetPoint("TOPLEFT", 440, -120)
  for i = 1, 10 do
    local b = {}
    b.tex = p:CreateTexture(nil, "ARTWORK"); b.tex:SetColorTexture(0.91, 0.72, 0.29, 1); b.tex:SetWidth(26)
    b.val = UI.Label(p, "", "GameFontHighlightSmall")
    b.day = UI.Label(p, "", "GameFontHighlightSmall")
    local x = 10 + (i - 1) * 42
    b.tex:SetPoint("BOTTOMLEFT", p, "TOPLEFT", x, -400)
    b.val:SetPoint("BOTTOM", b.tex, "TOP", 0, 2)
    b.day:SetPoint("TOP", b.tex, "BOTTOM", 0, -4)
    p.dayBars[i] = b
  end
  for i = 1, 6 do
    local r = {}
    r.name = UI.Label(p, ""); r.name:SetPoint("TOPLEFT", 440, -150 - (i - 1) * 44)
    r.bar = p:CreateTexture(nil, "ARTWORK"); r.bar:SetColorTexture(0.91, 0.72, 0.29, 1); r.bar:SetHeight(10)
    r.bar:SetPoint("TOPLEFT", 440, -170 - (i - 1) * 44)
    r.val = UI.Label(p, "", "GameFontHighlightSmall"); r.val:SetPoint("LEFT", r.bar, "RIGHT", 6, 0)
    p.bossBars[i] = r
  end
end

function UI.RefreshStats()
  local p = UI.panels.Stats
  local s = KL.Stats(KL.FilteredKills())
  p.kpi[1]:SetText(s.kills); p.kpi[2]:SetText(GOLD .. s.aotc .. "|r")
  p.kpi[3]:SetText(s.bestDay and (s.bestCount .. MUTED .. " (" .. s.bestDay:sub(6) .. ")|r") or "-")
  p.kpi[4]:SetText(("%.1f"):format(s.avg))
  local mx = 1
  for _, d in ipairs(s.days) do mx = math.max(mx, d.aotc) end
  for i, b in ipairs(p.dayBars) do
    local d = s.days[i]
    if d then
      b.tex:SetHeight(math.max(2, d.aotc / mx * 200)); b.tex:Show()
      b.val:SetText(d.aotc); b.day:SetText(d.day:sub(6)); b.val:Show(); b.day:Show()
    else b.tex:Hide(); b.val:Hide(); b.day:Hide() end
  end
  local top = 1
  for _, b in ipairs(s.bosses) do top = math.max(top, b.aotc) end
  for i, r in ipairs(p.bossBars) do
    local b = s.bosses[i]
    if b then
      r.name:SetText(b.name); r.bar:SetWidth(math.max(2, b.aotc / top * 200))
      r.val:SetText(("%d AOTCs - %d kills"):format(b.aotc, b.kills))
      r.name:Show(); r.bar:Show(); r.val:Show()
    else r.name:Hide(); r.bar:Hide(); r.val:Hide() end
  end
end

-- ================================================================ EXPORT / IMPORT
UI.export = { scope = "season", format = "csv", who = true }

function UI.BuildExport()
  local p = UI.panels.Export
  local ex = UI.export
  local scopes = { "filters", "season", "all" }
  local scopeLabel = { filters = "Current Log filters", season = "Selected raid", all = "Everything" }
  UI.Cycle(p, 190, function() return "Scope: " .. scopeLabel[ex.scope] end,
    function(dir) ex.scope = UI.CycleList(scopes, ex.scope, dir) end):SetPoint("TOPLEFT", 8, -2)
  UI.Cycle(p, 130, function() return "Format: " .. (ex.format == "csv" and "CSV" or "Plain text") end,
    function(dir) ex.format = ex.format == "csv" and "plain" or "csv" end):SetPoint("TOPLEFT", 206, -2)
  local who = UI.Check(p, "Include who earned AOTC", function(v) ex.who = v; UI.RefreshExport() end)
  who:SetPoint("TOPLEFT", 350, 0); who:SetChecked(true)
  UI.Label(p, MUTED .. "Click inside the box, Ctrl+A then Ctrl+C to copy.|r", "GameFontHighlightSmall"):SetPoint("TOPLEFT", 10, -34)
  p.out = UI.TextArea(p, 752, 200); p.out:SetPoint("TOPLEFT", 4, -54)
  p.out.edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  p.count = UI.Label(p, "", "GameFontHighlightSmall"); p.count:SetPoint("TOPLEFT", 10, -260)
  UI.Label(p, GOLD .. "Import backup|r", "GameFontNormalLarge"):SetPoint("TOPLEFT", 8, -292)
  UI.Label(p, MUTED .. "Paste a previous CSV export. Kills already in the log are skipped.|r", "GameFontHighlightSmall"):SetPoint("TOPLEFT", 10, -318)
  p.inp = UI.TextArea(p, 752, 70); p.inp:SetPoint("TOPLEFT", 4, -336)
  p.result = UI.Label(p, "", "GameFontHighlight"); p.result:SetPoint("BOTTOMLEFT", 10, 8)
  UI.Button(p, "Import and merge", 140, 24, function()
    local a, s, b = KL.Import(p.inp.edit:GetText())
    p.result:SetText(("%d added, %d already present, %d unreadable lines."):format(a, s, b))
    p.inp.edit:SetText(""); UI.RefreshExport()
  end, "primary"):SetPoint("BOTTOMRIGHT", -4, 4)
end

function UI.RefreshExport()
  local p, ex = UI.panels.Export, UI.export
  local kills
  if ex.scope == "filters" then kills = KL.FilteredKills()
  elseif ex.scope == "season" then
    kills = KL.FilteredKills({ season = KL.filter.season, search = "", range = "all", aotcOnly = false, bossOff = {} })
  else kills = KL.FilteredKills({ search = "", range = "all", aotcOnly = false, bossOff = {} }) end
  p.out.edit:SetText(KL.ExportText(kills, ex.format, ex.who))
  p.count:SetText(#kills .. " kills ready.")
end
