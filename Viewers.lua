local ADDON, KL = ...
local UI = KL.UI
local C = UI.C
local GOLD, MUTED = "|cffe8b84a", "|cffa39e90"
local BODY, HEAD = "Fonts\\ARIALN.TTF", "Fonts\\FRIZQT__.TTF"
local FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local WIDTH, GAP = 560, 8
local DEFAULT_MESSAGE = "{boss} AoTCs earned this season: {current}/{goal}"
local DEFAULT_TITLE = "AoTCs earned this season"
local SIZES = { 0.75, 1, 1.25, 1.5 }
local ROWS_PER_PAGE = 8
UI.goalPage = 1

-- ================================================================ data helpers
-- Total AOTCs logged per boss (deleted kills are already gone from the log).
function KL.AotcTotals()
  local t = {}
  for _, k in ipairs(KL.db.kills) do t[k.boss] = (t[k.boss] or 0) + (k.aotc or 0) end
  return t
end

-- Every boss that is tracked or has logged kills, with its total and target.
function KL.GoalBosses()
  local db, totals, seen, out = KL.db, KL.AotcTotals(), {}, {}
  local function add(key, name, raid)
    if seen[key] then return end
    seen[key] = true
    out[#out + 1] = { key = key, name = name or key, raid = raid or "", count = totals[key] or 0,
                      goal = db.goals[key], tracked = db.tracked[key] and true or false }
  end
  for key, b in pairs(db.trackedInfo) do add(key, b.name, b.raid) end
  for _, k in ipairs(db.kills) do add(k.boss, k.bossName, k.raid) end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

local function ShownItems()
  local out = {}
  for _, b in ipairs(KL.GoalBosses()) do
    if b.goal and b.goal > 0 and KL.db.goalShow[b.key] then out[#out + 1] = b end
  end
  return out
end

function KL.FormatMessage(tpl, b)
  local pct = (b.goal and b.goal > 0) and math.floor(b.count / b.goal * 100) or 0
  local map = { boss = b.name, current = GOLD .. b.count .. "|r", goal = tostring(b.goal or 0), percent = tostring(pct) }
  return (tostring(tpl):gsub("{(%w+)}", function(k) return map[k] end))
end

-- ================================================================ drawing helpers
local function FS(parent, size, face, color)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(face or BODY, size, "")
  fs:SetTextColor(color[1], color[2], color[3])
  fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1)
  fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
  return fs
end

local function MakeBar(parent)
  local track = parent:CreateTexture(nil, "ARTWORK"); track:SetColorTexture(C.line[1], C.line[2], C.line[3], 0.9)
  local fill = parent:CreateTexture(nil, "OVERLAY"); fill:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
  fill:SetPoint("TOPLEFT", track, "TOPLEFT"); fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")
  return track, fill
end

local function SetBar(fill, width, count, goal)
  local ratio = (goal and goal > 0) and math.min(1, count / goal) or 0
  fill:SetWidth(math.max(1, width * ratio)); fill:SetShown(ratio > 0)
end

local function Style(frame)
  local dark = KL.db.viewers.bg ~= "transparent"
  frame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], dark and 0.95 or 0)
  frame:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], dark and 1 or 0)
end

local function Message(b)
  local v = KL.db.viewers
  return KL.FormatMessage((v.message and v.message ~= "") and v.message or DEFAULT_MESSAGE, b)
end

local function Sub(b)
  if b.count >= b.goal then return GOLD .. "Goal reached. Thank you all!|r" end
  return math.floor(b.count / b.goal * 100) .. "% of the goal"
end

-- ================================================================ on-screen display
local D

local function MakeItem(parent)
  local it = CreateFrame("Frame", nil, parent, "BackdropTemplate"); it:SetBackdrop(FLAT)
  it.text = FS(it, 18, HEAD, C.text)
  it.sub = FS(it, 12, BODY, C.muted)
  it.track, it.fill = MakeBar(it)
  return it
end

local function LayoutItem(it, b, layout)
  Style(it); it:Show()
  it.text:SetText(Message(b))
  it.text:ClearAllPoints(); it.track:ClearAllPoints(); it.sub:ClearAllPoints()
  if layout == "slim" then
    it:SetSize(WIDTH, 34)
    it.text:SetFont(BODY, 15, ""); it.text:SetPoint("LEFT", 14, 0); it.text:SetWidth(WIDTH - 28 - 170)
    it.track:SetSize(150, 10); it.track:SetPoint("RIGHT", -14, 0)
    it.sub:Hide(); SetBar(it.fill, 150, b.count, b.goal)
  else
    it:SetSize(WIDTH, 88)
    it.text:SetFont(HEAD, 18, ""); it.text:SetPoint("TOPLEFT", 22, -16); it.text:SetWidth(WIDTH - 44)
    it.track:SetSize(WIDTH - 44, 14); it.track:SetPoint("BOTTOMLEFT", 22, 30)
    it.sub:SetPoint("BOTTOMLEFT", 22, 10); it.sub:SetText(Sub(b)); it.sub:Show()
    SetBar(it.fill, WIDTH - 44, b.count, b.goal)
  end
end

local function MakeAllRow(parent)
  local r = {}
  r.name = FS(parent, 15, BODY, C.text)
  r.cnt = FS(parent, 15, BODY, C.text); r.cnt:SetJustifyH("RIGHT")
  r.track, r.fill = MakeBar(parent)
  return r
end

local function BuildDisplay()
  local f = CreateFrame("Frame", "WildGraceKillLedgerViewers", UIParent)
  f:SetSize(WIDTH, 90); f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true); f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if UI.displayUnlocked then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    KL.db.viewers.pos = { p, rp, x, y }
  end)
  f.glow = f:CreateTexture(nil, "BACKGROUND"); f.glow:SetAllPoints(); f.glow:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.15); f.glow:Hide()
  f.hint = FS(f, 12, BODY, C.gold); f.hint:SetPoint("BOTTOM", f, "TOP", 0, 4)
  f.hint:SetText("Drag to move. Press Lock position in the Viewers tab when done."); f.hint:Hide()
  f.items = {}
  f.all = CreateFrame("Frame", nil, f, "BackdropTemplate"); f.all:SetBackdrop(FLAT)
  f.all.title = FS(f.all, 16, HEAD, C.gold); f.all.title:SetPoint("TOPLEFT", 22, -14)
  f.all.rows = {}
  local pos = KL.db.viewers.pos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("TOP", UIParent, "TOP", 0, -70) end
  return f
end

function UI.RefreshDisplay()
  local db = KL.db
  if not db or not db.viewers then return end
  local v = db.viewers
  local items = ShownItems()
  local unlocked = UI.displayUnlocked and true or false
  if #items == 0 and unlocked then items = { { key = "sample", name = "Boss name", count = 0, goal = 1000 } } end
  if not v.show or #items == 0 then if D then D:Hide() end return end
  if not D then D = BuildDisplay() end
  D:SetScale(v.scale or 1); D:Show()
  D:EnableMouse(unlocked); D.glow:SetShown(unlocked); D.hint:SetShown(unlocked)
  for _, it in ipairs(D.items) do it:Hide() end
  D.all:Hide()
  if v.layout == "all" then
    local n = math.min(#items, 12)
    local all = D.all
    all:ClearAllPoints(); all:SetPoint("TOPLEFT", D, "TOPLEFT", 0, 0)
    all:SetSize(WIDTH, 56 + n * 42); Style(all); all:Show()
    all.title:SetText((v.title and v.title ~= "") and v.title or DEFAULT_TITLE)
    for _, r in ipairs(all.rows) do r.name:Hide(); r.cnt:Hide(); r.track:Hide(); r.fill:Hide() end
    for i = 1, n do
      local b = items[i]
      local r = all.rows[i] or MakeAllRow(all); all.rows[i] = r
      local y = -(46 + (i - 1) * 42)
      r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", 22, y); r.name:SetText(b.name); r.name:Show()
      r.cnt:ClearAllPoints(); r.cnt:SetPoint("TOPRIGHT", -22, y); r.cnt:SetText(GOLD .. b.count .. "|r / " .. b.goal); r.cnt:Show()
      r.track:ClearAllPoints(); r.track:SetSize(WIDTH - 44, 10); r.track:SetPoint("TOPLEFT", 22, y - 22); r.track:Show()
      SetBar(r.fill, WIDTH - 44, b.count, b.goal)
    end
    D:SetHeight(all:GetHeight())
  else
    local y = 0
    for i = 1, math.min(#items, 8) do
      local it = D.items[i] or MakeItem(D); D.items[i] = it
      it:ClearAllPoints(); it:SetPoint("TOPLEFT", D, "TOPLEFT", 0, -y)
      LayoutItem(it, items[i], v.layout)
      y = y + it:GetHeight() + GAP
    end
    D:SetHeight(math.max(1, y - GAP))
  end
end

function UI.ToggleDisplay()
  local v = KL.db.viewers
  v.show = not v.show
  KL.Print("viewer display " .. (v.show and "shown." or "hidden."))
  UI.RefreshAll()
end

-- ================================================================ Viewers tab
function UI.BuildViewers()
  local p = UI.panels.Viewers
  local db = KL.db
  p.rows = {}
  local intro = UI.Label(p, MUTED .. "Set a target for each boss. Only bosses with a target and Show ticked appear on screen.|r", "GameFontHighlightSmall")
  intro:SetPoint("TOPLEFT", 8, -2); intro:SetWidth(430); intro:SetWordWrap(true)
  for _, h in ipairs({ { "BOSS", 8 }, { "AOTCs", 196 }, { "TARGET", 256 }, { "PROGRESS", 334 }, { "SHOW", 410 } }) do
    UI.Label(p, MUTED .. h[1] .. "|r", "GameFontHighlightSmall"):SetPoint("TOPLEFT", h[2], -40)
  end
  for i = 1, ROWS_PER_PAGE do
    local row = CreateFrame("Frame", nil, p); row.i = i
    row:SetSize(440, 42); row:SetPoint("TOPLEFT", 0, -58 - (i - 1) * 42)
    local line = row:CreateTexture(nil, "ARTWORK"); line:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    row.name = UI.Label(row, ""); row.name:SetPoint("TOPLEFT", 8, -5); row.name:SetWidth(180); row.name:SetWordWrap(false)
    row.raid = UI.Label(row, "", "GameFontHighlightSmall"); row.raid:SetPoint("BOTTOMLEFT", 8, 5); row.raid:SetWidth(180); row.raid:SetWordWrap(false)
    row.count = UI.Label(row, "", "GameFontNormal"); row.count:SetPoint("LEFT", 196, 0)
    row.edit = UI.Input(row, 66, "No goal"); row.edit:SetPoint("LEFT", 252, 0)
    row.edit:SetNumeric(true); row.edit:SetMaxLetters(7); row.edit:SetJustifyH("RIGHT")
    row.edit:HookScript("OnTextChanged", function(self, user)
      if not user or not row.b then return end
      local n = tonumber(self:GetText())
      if n and n > 0 then
        db.goals[row.b.key] = math.floor(n)
        if db.goalShow[row.b.key] == nil then db.goalShow[row.b.key] = true end
      else
        db.goals[row.b.key] = nil
      end
      UI.RefreshViewers(); UI.RefreshDisplay()
    end)
    row.track, row.fill = MakeBar(row); row.track:SetSize(70, 10); row.track:SetPoint("TOPLEFT", 334, -12)
    row.pct = UI.Label(row, "", "GameFontHighlightSmall"); row.pct:SetPoint("TOPLEFT", 334, -24)
    row.show = UI.Check(row, "", function(v)
      if row.b then db.goalShow[row.b.key] = v and true or false end
      UI.RefreshViewers(); UI.RefreshDisplay()
    end)
    row.show:SetPoint("LEFT", 412, 0)
    p.rows[i] = row
  end
  UI.Label(p, MUTED .. "AOTCs is the total from your log for that boss. Deleted kills do not count.|r", "GameFontHighlightSmall"):SetPoint("BOTTOMLEFT", 8, 34)
  p.prev = UI.Button(p, "<", 28, 24, function() UI.goalPage = UI.goalPage - 1; UI.RefreshViewers() end); p.prev:SetPoint("BOTTOMLEFT", 8, 4)
  p.pageText = UI.Label(p, "", "GameFontHighlightSmall"); p.pageText:SetPoint("LEFT", p.prev, "RIGHT", 10, 0)
  p.next = UI.Button(p, ">", 28, 24, function() UI.goalPage = UI.goalPage + 1; UI.RefreshViewers() end); p.next:SetPoint("LEFT", p.prev, "RIGHT", 90, 0)

  -- right column: display settings
  local X = 470
  UI.Label(p, GOLD .. "Viewer display|r", "GameFontNormalLarge"):SetPoint("TOPLEFT", X, -2)
  p.chipShow = UI.Button(p, "Show on screen", 130, 26, function()
    db.viewers.show = not db.viewers.show; UI.RefreshAll()
  end, "chipOn"); p.chipShow:SetPoint("TOPLEFT", X, -30)
  p.chipMove = UI.Button(p, "Move", 110, 26, function()
    UI.displayUnlocked = not UI.displayUnlocked
    if UI.displayUnlocked then db.viewers.show = true end
    UI.RefreshAll()
  end, "chipOff"); p.chipMove:SetPoint("LEFT", p.chipShow, "RIGHT", 8, 0)

  UI.Label(p, MUTED .. "LAYOUT|r", "GameFontHighlightSmall"):SetPoint("TOPLEFT", X, -68)
  p.layoutChips = {}
  local lx = X
  for _, o in ipairs({ { "card", "Card", 62 }, { "all", "All bosses", 94 }, { "slim", "Slim bar", 84 } }) do
    local b = UI.Button(p, o[2], o[3], 26, function() db.viewers.layout = o[1]; UI.RefreshAll() end, "chipOff")
    b:SetPoint("TOPLEFT", lx, -86); lx = lx + o[3] + 8; p.layoutChips[o[1]] = b
  end

  UI.Label(p, MUTED .. "BACKGROUND|r", "GameFontHighlightSmall"):SetPoint("TOPLEFT", X, -124)
  p.bgChips = {}
  local bx = X
  for _, o in ipairs({ { "dark", "Dark", 56 }, { "transparent", "Transparent", 96 } }) do
    local b = UI.Button(p, o[2], o[3], 26, function() db.viewers.bg = o[1]; UI.RefreshAll() end, "chipOff")
    b:SetPoint("TOPLEFT", bx, -142); bx = bx + o[3] + 8; p.bgChips[o[1]] = b
  end
  local size = UI.Cycle(p, 100, function() return ("Size: %d%%"):format((db.viewers.scale or 1) * 100) end,
    function(dir) db.viewers.scale = UI.CycleList(SIZES, db.viewers.scale or 1, dir) end)
  size:SetPoint("TOPLEFT", X + 172, -142)

  UI.Label(p, MUTED .. "MESSAGE|r", "GameFontHighlightSmall"):SetPoint("TOPLEFT", X, -182)
  p.msg = UI.Input(p, 282); p.msg:SetPoint("TOPLEFT", X, -200); p.msg:SetMaxLetters(200)
  p.msg:HookScript("OnTextChanged", function(self, user)
    if user then db.viewers.message = self:GetText(); UI.RefreshViewers(); UI.RefreshDisplay() end
  end)
  UI.Label(p, MUTED .. "You can use {boss}, {current}, {goal} and {percent}|r", "GameFontHighlightSmall"):SetPoint("TOPLEFT", X, -228)
  UI.Label(p, MUTED .. "TITLE (ALL BOSSES LAYOUT)|r", "GameFontHighlightSmall"):SetPoint("TOPLEFT", X, -252)
  p.title = UI.Input(p, 282); p.title:SetPoint("TOPLEFT", X, -270); p.title:SetMaxLetters(100)
  p.title:HookScript("OnTextChanged", function(self, user)
    if user then db.viewers.title = self:GetText(); UI.RefreshViewers(); UI.RefreshDisplay() end
  end)

  p.prevCaption = UI.Label(p, MUTED .. "PREVIEW|r", "GameFontHighlightSmall"); p.prevCaption:SetPoint("TOPLEFT", X, -314)
  local box = UI.Box(p); box:SetSize(282, 84); box:SetPoint("TOPLEFT", X, -332)
  box:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1); box:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
  p.prevText = FS(box, 14, HEAD, C.text); p.prevText:SetPoint("TOPLEFT", 12, -12); p.prevText:SetWidth(258)
  p.prevTrack, p.prevFill = MakeBar(box); p.prevTrack:SetSize(258, 10); p.prevTrack:SetPoint("BOTTOMLEFT", 12, 26)
  p.prevSub = FS(box, 11, BODY, C.muted); p.prevSub:SetPoint("BOTTOMLEFT", 12, 8)
end

function UI.RefreshViewers()
  local p, db = UI.panels.Viewers, KL.db
  local v = db.viewers
  local list = KL.GoalBosses()
  local pages = math.max(1, math.ceil(#list / ROWS_PER_PAGE))
  UI.goalPage = math.min(math.max(UI.goalPage, 1), pages)
  for i, row in ipairs(p.rows) do
    local b = list[(UI.goalPage - 1) * ROWS_PER_PAGE + i]
    row.b = b
    if b then
      row.name:SetText(b.name)
      row.raid:SetText(MUTED .. b.raid .. (b.tracked and "" or "  (not tracked)") .. "|r")
      row.count:SetText(tostring(b.count))
      if not row.edit:HasFocus() then row.edit:SetText(b.goal and tostring(b.goal) or "") end
      if b.goal then
        row.track:Show(); SetBar(row.fill, 70, b.count, b.goal)
        row.pct:SetText(MUTED .. math.floor(b.count / b.goal * 100) .. "%|r")
      else
        row.track:Hide(); row.fill:Hide(); row.pct:SetText(MUTED .. "Not shown|r")
      end
      row.show:SetChecked(db.goalShow[b.key] and b.goal and true or false)
      row:Show()
    else row:Hide() end
  end
  if #list == 0 then
    p.pageText:SetText("No bosses yet. Track a boss on the Bosses tab.")
    p.next:Hide()
  else
    p.pageText:SetText(("Page %d / %d"):format(UI.goalPage, pages)); p.next:Show()
  end
  p.prev:SetEnabled(UI.goalPage > 1); p.next:SetEnabled(UI.goalPage < pages)

  p.chipShow:SetStyle(v.show and "chipOn" or "chipOff")
  p.chipMove:SetText(UI.displayUnlocked and "Lock position" or "Move")
  p.chipMove:SetStyle(UI.displayUnlocked and "chipOn" or "chipOff")
  for k, b in pairs(p.layoutChips) do b:SetStyle(v.layout == k and "chipOn" or "chipOff") end
  for k, b in pairs(p.bgChips) do b:SetStyle((v.bg or "dark") == k and "chipOn" or "chipOff") end
  if not p.msg:HasFocus() then p.msg:SetText(v.message or "") end
  if not p.title:HasFocus() then p.title:SetText(v.title or "") end

  local sample = ShownItems()[1]
  local b = sample or { name = "Ula'tek", count = 345, goal = 2000 }
  p.prevCaption:SetText(MUTED .. (sample and "PREVIEW" or "PREVIEW (SAMPLE NUMBERS)") .. "|r")
  p.prevText:SetText(Message(b)); p.prevSub:SetText(Sub(b))
  SetBar(p.prevFill, 258, b.count, b.goal)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() UI.RefreshDisplay() end)
