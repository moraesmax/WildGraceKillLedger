local ADDON, KL = ...
local UI = { panels = {}, cycles = {}, page = 1 }
KL.UI = UI
local ROWS, W = 12, 752
local GOLD, MUTED = "|cffe8b84a", "|cffa39e90"

-- ---------------------------------------------------------------- look (matches the design mockups)
local C = {
  bg = { 0.078, 0.086, 0.106 }, panel = { 0.106, 0.118, 0.145 }, line = { 0.173, 0.192, 0.227 },
  gold = { 0.91, 0.72, 0.29 }, text = { 0.925, 0.906, 0.855 }, muted = { 0.639, 0.62, 0.565 }, red = { 0.94, 0.54, 0.49 },
}
UI.C = C
local BODY, HEAD = "Fonts\\ARIALN.TTF", "Fonts\\FRIZQT__.TTF"
local FONTS = {
  GameFontHighlight = { BODY, 13, "text" }, GameFontHighlightSmall = { BODY, 11, "text" }, GameFontNormal = { BODY, 13, "gold" },
  GameFontNormalLarge = { HEAD, 15, "gold" }, GameFontNormalHuge = { HEAD, 24, "gold" },
}
local FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local function Skin(f, bg, border)
  f:SetBackdrop(FLAT); f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1); f:SetBackdropBorderColor(border[1], border[2], border[3], 1)
end
local function col(v) if type(v) == "string" then local c = C[v]; return c[1], c[2], c[3], 1 end return v[1], v[2], v[3], v[4] or 1 end

function UI.Label(parent, text, font)
  local f = FONTS[font or "GameFontHighlight"]
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(f[1], f[2], ""); fs:SetTextColor(unpack(C[f[3]]))
  fs:SetJustifyH("LEFT"); fs:SetText(text or "")
  return fs
end

local STYLES = {
  ghost = { bg = { 0, 0, 0, 0 }, border = "line", text = "text" },
  primary = { bg = { 0, 0, 0, 0 }, border = "gold", text = "gold" },
  chipOn = { bg = "gold", border = "gold", text = "bg" },
  chipOff = { bg = { 0, 0, 0, 0 }, border = "line", text = "text" },
  danger = { bg = { 0, 0, 0, 0 }, border = "red", text = "red" },
  field = { bg = "panel", border = "line", text = "text" },
}
local btnIndex = getmetatable(CreateFrame("Button")).__index
local function ApplyStyle(b, hover)
  local s = STYLES[b.style or "ghost"]
  b:SetBackdropColor(col(s.bg))
  if hover and b.style ~= "chipOn" then b:SetBackdropBorderColor(col("gold")) else b:SetBackdropBorderColor(col(s.border)) end
  b.label:SetTextColor(col(s.text))
end

function UI.Button(parent, text, w, h, fn, style)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h); b:SetBackdrop(FLAT)
  b.label = UI.Label(b, ""); b.label:SetPoint("CENTER"); b.label:SetJustifyH("CENTER")
  b.SetText = function(self, t) self.label:SetText(t) end
  b.GetFontString = function(self) return self.label end
  b.SetStyle = function(self, s) self.style = s; ApplyStyle(self, false) end
  b.SetEnabled = function(self, v)
    if v then btnIndex.Enable(self) else btnIndex.Disable(self) end
    self:SetAlpha(v and 1 or 0.4)
  end
  b.Enable = function(self) self:SetEnabled(true) end
  b.Disable = function(self) self:SetEnabled(false) end
  b:SetScript("OnEnter", function(self) ApplyStyle(self, true) end)
  b:SetScript("OnLeave", function(self) ApplyStyle(self, false) end)
  if fn then b:SetScript("OnClick", fn) end
  b.style = style or "ghost"; b:SetText(text); ApplyStyle(b, false)
  return b
end

function UI.Input(parent, w, hint)
  local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  e:SetSize(w, 24); Skin(e, C.panel, C.line)
  e:SetFont(BODY, 13, ""); e:SetTextColor(unpack(C.text)); e:SetTextInsets(8, 8, 0, 0); e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed", e.ClearFocus); e:SetScript("OnEnterPressed", e.ClearFocus)
  if hint then
    e.hint = UI.Label(e, hint, "GameFontHighlightSmall"); e.hint:SetTextColor(unpack(C.muted)); e.hint:SetPoint("LEFT", 8, 0)
    local function upd() e.hint:SetShown(e:GetText() == "" and not e:HasFocus()) end
    e:HookScript("OnTextChanged", upd); e:HookScript("OnEditFocusGained", upd); e:HookScript("OnEditFocusLost", upd)
  end
  return e
end

-- Cycle button: left click = next option, right click = previous
function UI.Cycle(parent, w, labelFn, stepFn)
  local b = UI.Button(parent, "", w, 24, nil, "field")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.Update = function() b:SetText(labelFn()) end
  b:SetScript("OnClick", function(_, btn) stepFn(btn == "RightButton" and -1 or 1); UI.page = 1; UI.RefreshAll() end)
  b.Update()
  UI.cycles[#UI.cycles + 1] = b
  return b
end

function UI.Check(parent, text, onChange)
  local c = CreateFrame("Button", nil, parent, "BackdropTemplate")
  c:SetSize(18, 18); Skin(c, C.panel, C.line)
  c.mark = c:CreateTexture(nil, "OVERLAY"); c.mark:SetColorTexture(unpack(C.gold))
  c.mark:SetPoint("TOPLEFT", 4, -4); c.mark:SetPoint("BOTTOMRIGHT", -4, 4); c.mark:Hide()
  c.SetChecked = function(self, v) self.on = v and true or false; self.mark:SetShown(self.on) end
  c.GetChecked = function(self) return self.on end
  c.label = UI.Label(parent, text); c.label:SetPoint("LEFT", c, "RIGHT", 8, 0)
  c:SetScript("OnClick", function(self) self:SetChecked(not self.on); onChange(self.on) end)
  return c
end

function UI.Box(parent)
  local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Skin(bg, C.panel, C.line)
  return bg
end

local function HLine(parent, y, anchorTo)   -- 1px divider
  local t = parent:CreateTexture(nil, "ARTWORK"); t:SetColorTexture(unpack(C.line)); t:SetHeight(1)
  return t
end

-- scrolling multi-line text box; returns the box, with .edit = the EditBox
function UI.TextArea(parent, w, h)
  local bg = UI.Box(parent); bg:SetSize(w, h)
  local sf = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 6, -6); sf:SetPoint("BOTTOMRIGHT", -28, 6)
  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true); eb:SetFont("Fonts\\ARIALN.TTF", 12, ""); eb:SetTextColor(unpack(C.text)); eb:SetAutoFocus(false)
  eb:SetWidth(w - 40); eb:SetHeight(h)
  eb:SetScript("OnEscapePressed", eb.ClearFocus)
  sf:SetScrollChild(eb)
  bg.edit = eb
  return bg
end

local function CycleList(list, current, dir)
  local idx = 1
  for i, v in ipairs(list) do if v == current then idx = i end end
  return list[(idx - 1 + dir) % #list + 1]
end
UI.CycleList = CycleList

local RANGES = { "all", "today", "7d", "30d" }
local RANGE_LABEL = { all = "All dates", today = "Today", ["7d"] = "Last 7 days", ["30d"] = "Last 30 days" }
function UI.SeasonLabel() return KL.filter.season and KL.SeasonName(KL.filter.season) or "All raids" end
function UI.StepSeason(dir)
  local list = { false }
  for _, id in ipairs(KL.SeasonsWithKills()) do list[#list + 1] = id end
  KL.filter.season = CycleList(list, KL.filter.season or false, dir) or nil
  KL.filter.bossOff = {}
end
function UI.RangeLabel() return RANGE_LABEL[KL.filter.range] end
function UI.StepRange(dir) KL.filter.range = CycleList(RANGES, KL.filter.range, dir) end

-- ---------------------------------------------------------------- main frame
local function MakeTab(parent, text, fn)
  local t = UI.Button(parent, text, 78, 44, fn, "ghost")
  t:SetBackdrop(nil)
  t.line = t:CreateTexture(nil, "OVERLAY"); t.line:SetColorTexture(unpack(C.gold)); t.line:SetHeight(2)
  t.line:SetPoint("BOTTOMLEFT"); t.line:SetPoint("BOTTOMRIGHT"); t.line:Hide()
  t.SetActive = function(self, a)
    self.line:SetShown(a); self.label:SetTextColor(unpack(a and C.gold or C.muted)); self.active = a
  end
  t:SetScript("OnEnter", function(self) if not self.active then self.label:SetTextColor(unpack(C.text)) end end)
  t:SetScript("OnLeave", function(self) self:SetActive(self.active) end)
  t:SetActive(false)
  return t
end

function UI.Build()
  if UI.frame then return end
  local f = CreateFrame("Frame", "KillLedgerFrame", UIParent, "BackdropTemplate")
  f:SetSize(780, 540); f:SetPoint("CENTER"); f:SetFrameStrata("HIGH"); Skin(f, C.bg, C.gold)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, "KillLedgerFrame")
  f:Hide()
  UI.frame = f
  local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
  header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1); header:SetHeight(44); Skin(header, C.panel, C.panel)
  local hl = HLine(header); hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT")
  UI.Label(header, "Wild Grace Kill Ledger", "GameFontNormalLarge"):SetPoint("LEFT", 16, 0)
  local close = UI.Button(header, "x", 28, 28, function() f:Hide() end, "ghost"); close:SetPoint("RIGHT", -8, 0)
  for i, n in ipairs({ "Log", "Bosses", "Viewers", "Stats", "Export" }) do
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", 14, -58); p:SetPoint("BOTTOMRIGHT", -14, 14); p:Hide()
    p.tab = MakeTab(header, n, function() UI.ShowTab(n) end)
    p.tab:SetPoint("RIGHT", header, "RIGHT", -44 - (5 - i) * 80, 0)
    UI.panels[n] = p
  end
  UI.BuildLog(); UI.BuildBosses(); UI.BuildViewers(); UI.BuildStats(); UI.BuildExport()
  UI.ShowTab("Log")
end

function UI.ShowTab(name)
  UI.current = name
  for k, p in pairs(UI.panels) do p:SetShown(k == name); p.tab:SetActive(k == name) end
  UI.RefreshAll()
end

function UI.RefreshAll()
  if UI.frame then
    for _, c in ipairs(UI.cycles) do c:Update() end
    local r = UI["Refresh" .. (UI.current or "Log")]
    if r and UI.frame:IsShown() then r() end
  end
  if UI.detail and UI.detail:IsShown() then UI.RefreshDetail() end
  if UI.RefreshDisplay then UI.RefreshDisplay() end
end

function KL.Toggle()
  UI.Build()
  UI.frame:SetShown(not UI.frame:IsShown())
  if UI.frame:IsShown() then
    if next(KL.db.tracked) == nil then UI.ShowTab("Bosses") else UI.RefreshAll() end
  end
end

-- ---------------------------------------------------------------- delete confirmation + undo
StaticPopupDialogs["KILLLEDGER_DELETE"] = {
  text = "Delete this kill from the log?\n%s",
  button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
  OnAccept = function(_, data)
    if KL.DeleteKill(data) then
      if UI.detail then UI.detail:Hide() end
      UI.UndoToast()
      UI.RefreshAll()
    end
  end,
}
function UI.ConfirmDelete(kill)
  StaticPopup_Show("KILLLEDGER_DELETE", kill.bossName .. " - " .. date("%b %d %H:%M", kill.ts), nil, kill.id)
end

function UI.UndoToast()
  local t = UI.toast
  if not t then
    t = CreateFrame("Frame", "KillLedgerToast", UIParent, "BackdropTemplate")
    t:SetSize(320, 56); t:SetPoint("TOP", UIParent, "TOP", 0, -120); t:SetFrameStrata("DIALOG"); Skin(t, C.panel, C.gold)
    UI.Label(t, "Kill deleted", "GameFontNormal"):SetPoint("TOPLEFT", 12, -10)
    UI.Label(t, MUTED .. "It no longer counts in your totals.|r", "GameFontHighlightSmall"):SetPoint("BOTTOMLEFT", 12, 10)
    local u = UI.Button(t, "Undo", 70, 26, function() if KL.Undo() then t:Hide(); UI.RefreshAll() end end, "primary")
    u:SetPoint("RIGHT", -10, 0)
    UI.toast = t
  end
  t:Show()
  local token = GetTime(); t.token = token
  C_Timer.After(8, function() if t.token == token then t:Hide() end end)
end

-- ---------------------------------------------------------------- log panel
local function MakeChip(p, i)
  local c = UI.Button(p, "", 100, 24, function(self)
    local off = KL.filter.bossOff
    off[self.key] = (not off[self.key]) or nil
    UI.page = 1; UI.RefreshAll()
  end, "chipOn")
  p.chips[i] = c
  return c
end

function UI.BuildLog()
  local p = UI.panels.Log
  p.chips, p.rows = {}, {}
  local search = UI.Input(p, 400, "Search boss, player, note...")
  search:SetPoint("TOPLEFT", 0, -2)
  search:HookScript("OnTextChanged", function(self, user)
    if user then KL.filter.search = self:GetText(); UI.page = 1; UI.RefreshLog() end
  end)
  p.search = search
  local season = UI.Cycle(p, 160, UI.SeasonLabel, UI.StepSeason); season:SetPoint("LEFT", search, "RIGHT", 10, 0)
  UI.panels.Log.only = UI.Check(p, "AOTCs > 0", function(v) KL.filter.aotcOnly = v; UI.page = 1; UI.RefreshLog() end)
  p.only:SetPoint("LEFT", season, "RIGHT", 14, 0)
  local lbl = UI.Label(p, MUTED .. "Bosses with kills|r", "GameFontHighlightSmall"); lbl:SetPoint("TOPLEFT", 0, -44)

  local hdr = CreateFrame("Frame", nil, p); hdr:SetSize(W, 22); hdr:SetPoint("TOPLEFT", 0, -70)
  for _, h in ipairs({ { "DATE", 12 }, { "TIME", 84 }, { "AOTC BOSS", 150 }, { "AOTCs", 580 } }) do
    UI.Label(hdr, MUTED .. h[1] .. "|r", "GameFontHighlightSmall"):SetPoint("LEFT", h[2], 0)
  end
  local hl = HLine(hdr); hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT")
  for i = 1, ROWS do
    local row = CreateFrame("Button", nil, p)
    row:SetSize(W, 28); row:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -(i - 1) * 28)
    row.hl = row:CreateTexture(nil, "BACKGROUND"); row.hl:SetAllPoints(); row.hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.08); row.hl:Hide()
    row:SetScript("OnEnter", function() row.hl:Show() end); row:SetScript("OnLeave", function() row.hl:Hide() end)
    local line = HLine(row); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
    row.date = UI.Label(row, ""); row.date:SetPoint("LEFT", 12, 0)
    row.time = UI.Label(row, ""); row.time:SetPoint("LEFT", 84, 0)
    row.boss = UI.Label(row, ""); row.boss:SetPoint("TOPLEFT", 150, -2)
    row.raid = UI.Label(row, "", "GameFontHighlightSmall"); row.raid:SetPoint("BOTTOMLEFT", 150, 3)
    row.aotc = UI.Label(row, "", "GameFontNormal"); row.aotc:SetPoint("LEFT", 580, 0)
    row.del = UI.Button(row, "x", 22, 22, function() UI.ConfirmDelete(row.kill) end, "ghost")
    row.del:SetPoint("RIGHT", -8, 0)
    row:SetScript("OnClick", function() UI.ShowDetail(row.kill) end)
    p.rows[i] = row
  end
  local foot = UI.Box(p); foot:SetPoint("BOTTOMLEFT", 0, 0); foot:SetPoint("BOTTOMRIGHT", 0, 0); foot:SetHeight(38)
  p.summary = UI.Label(foot, "", "GameFontHighlight"); p.summary:SetPoint("LEFT", 12, 0)
  p.next = UI.Button(foot, ">", 28, 24, function() UI.page = UI.page + 1; UI.RefreshLog() end); p.next:SetPoint("RIGHT", -8, 0)
  p.pageText = UI.Label(foot, "", "GameFontHighlightSmall"); p.pageText:SetPoint("RIGHT", p.next, "LEFT", -8, 0)
  p.prev = UI.Button(foot, "<", 28, 24, function() UI.page = UI.page - 1; UI.RefreshLog() end); p.prev:SetPoint("RIGHT", p.pageText, "LEFT", -8, 0)
end

function UI.RefreshLog()
  local p = UI.panels.Log
  local kills = KL.FilteredKills()
  local f = KL.filter
  p.only:SetChecked(f.aotcOnly)
  for _, c in ipairs(p.chips) do c:Hide() end
  local prev
  for i, b in ipairs(KL.BossesWithKills(f.season)) do
    if i > 8 then break end
    local c = p.chips[i] or MakeChip(p, i)
    c.key = b.key
    c:SetText(b.name .. (b.tracked and "" or " (not tracked)"))
    c:SetWidth(c.label:GetStringWidth() + 26)
    c:SetStyle(f.bossOff[b.key] and "chipOff" or "chipOn")
    c:ClearAllPoints()
    if prev then c:SetPoint("LEFT", prev, "RIGHT", 6, 0) else c:SetPoint("TOPLEFT", 112, -40) end
    c:Show(); prev = c
  end
  local pages = math.max(1, math.ceil(#kills / ROWS))
  UI.page = math.min(math.max(UI.page, 1), pages)
  for i, row in ipairs(p.rows) do
    local k = kills[(UI.page - 1) * ROWS + i]
    row.kill = k
    if k then
      row.date:SetText(date("%b %d", k.ts)); row.time:SetText(MUTED .. date("%H:%M", k.ts) .. "|r")
      row.boss:SetText(k.bossName); row.raid:SetText(MUTED .. (k.raid or "") .. "|r")
      row.aotc:SetText(k.aotc > 0 and (GOLD .. "+" .. k.aotc .. "|r") or (MUTED .. "0|r"))
      row:Show()
    else row:Hide() end
  end
  local total = 0
  for _, k in ipairs(kills) do total = total + k.aotc end
  p.summary:SetText(("%d kills  -  %s%d AOTCs|r  -  %s"):format(#kills, GOLD, total, UI.SeasonLabel()))
  p.pageText:SetText(("Page %d / %d"):format(UI.page, pages))
  p.prev:SetEnabled(UI.page > 1); p.next:SetEnabled(UI.page < pages)
end

-- ---------------------------------------------------------------- kill popup + details (one panel)
local function BuildDetail()
  local d = CreateFrame("Frame", "KillLedgerDetail", UIParent, "BackdropTemplate")
  d:SetSize(430, 520); d:SetPoint("CENTER", 0, 30); d:SetFrameStrata("DIALOG"); Skin(d, C.bg, C.gold)
  d:SetMovable(true); d:EnableMouse(true); d:RegisterForDrag("LeftButton")
  d:SetScript("OnDragStart", d.StartMoving); d:SetScript("OnDragStop", d.StopMovingOrSizing)
  tinsert(UISpecialFrames, "KillLedgerDetail")
  UI.Button(d, "x", 26, 26, function() d:Hide() end, "ghost"):SetPoint("TOPRIGHT", -8, -8)
  UI.Label(d, "Wild Grace Kill Ledger", "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -14)

  local banner = UI.Box(d); banner:SetPoint("TOPLEFT", 16, -42); banner:SetSize(398, 72)
  banner:SetBackdropBorderColor(unpack(C.gold))
  d.title = UI.Label(banner, "", "GameFontNormalLarge"); d.title:SetPoint("TOPLEFT", 14, -12); d.title:SetWidth(290)
  d.sub = UI.Label(banner, "", "GameFontHighlightSmall"); d.sub:SetPoint("BOTTOMLEFT", 14, 12); d.sub:SetWidth(290)
  d.big = UI.Label(banner, "", "GameFontNormalHuge"); d.big:SetPoint("RIGHT", -16, 0)

  UI.Label(d, "Kill details", "GameFontNormalLarge"):SetPoint("TOPLEFT", 16, -132)
  d.info = UI.Label(d, "", "GameFontHighlightSmall"); d.info:SetPoint("TOPLEFT", 16, -158); d.info:SetWidth(398)
  d.achLine = UI.Label(d, "", "GameFontHighlightSmall"); d.achLine:SetPoint("TOPLEFT", 16, -174); d.achLine:SetWidth(398)
  d.whoHead = UI.Label(d, "", "GameFontHighlightSmall"); d.whoHead:SetPoint("TOPLEFT", 16, -196)
  d.pills = {}
  d.noWho = UI.Label(d, "", "GameFontHighlightSmall"); d.noWho:SetPoint("TOPLEFT", 16, -220); d.noWho:SetWidth(398)

  UI.Label(d, MUTED .. "ADJUST COUNT|r", "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -330)
  d.minus = UI.Button(d, "-", 34, 34, function() UI.Adjust(-1) end, "field"); d.minus:SetPoint("TOPLEFT", 16, -350)
  d.count = UI.Label(d, "", "GameFontNormalLarge"); d.count:SetPoint("LEFT", d.minus, "RIGHT", 14, 0); d.count:SetWidth(44)
  d.plus = UI.Button(d, "+", 34, 34, function() UI.Adjust(1) end, "field"); d.plus:SetPoint("LEFT", d.minus, "RIGHT", 62, 0)
  d.adjHint = UI.Label(d, "", "GameFontHighlightSmall"); d.adjHint:SetPoint("LEFT", d.plus, "RIGHT", 12, 0); d.adjHint:SetWidth(250)

  UI.Label(d, MUTED .. "NOTE / TAGS|r", "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -398)
  d.note = UI.Input(d, 398, "e.g. Stream #214, sub train run"); d.note:SetPoint("TOPLEFT", 16, -418); d.note:SetHeight(28)
  d.note:HookScript("OnEditFocusLost", function(self) if d.kill then d.kill.note = self:GetText() end end)

  UI.Button(d, "Delete this kill", 130, 28, function() UI.ConfirmDelete(d.kill) end, "danger"):SetPoint("BOTTOMLEFT", 16, 16)
  UI.Button(d, "Close", 100, 28, function() d:Hide() end, "primary"):SetPoint("BOTTOMRIGHT", -16, 16)
  UI.detail = d
  return d
end

function UI.Adjust(delta)
  local d = UI.detail; local k = d and d.kill
  if not k then return end
  k.adjust = (k.adjust or 0) + delta
  if #k.who + k.adjust < 0 then k.adjust = -#k.who end
  KL.Recount(k)
  UI.RefreshAll()
end

function UI.ShowDetail(kill)
  if not kill then return end
  local d = UI.detail or BuildDetail()
  d.kill = kill; d:Show(); UI.RefreshDetail()
end

function UI.OnKill(kill) UI.ShowDetail(kill); UI.RefreshDisplay() end
function UI.UpdateToast() UI.RefreshAll() end   -- called by Core whenever a kill's count changes

function UI.RefreshDetail()
  local d, k = UI.detail, UI.detail and UI.detail.kill
  if not k then return end
  if k.adjust == nil then k.adjust = k.aotc - #k.who end
  local counting = KL.watch and KL.watch.kill == k
  d.title:SetText(k.bossName .. " defeated")
  d.sub:SetText(counting and "Counting AOTCs, updates live..." or ((k.raid or "") .. " - logged to Wild Grace Kill Ledger"))
  d.big:SetText("+" .. k.aotc)
  d.info:SetText(("%s  -  %s"):format(date("%a %b %d, %H:%M", k.ts), k.raid or "?"))
  local names = {}
  for name in pairs(k.ach or {}) do names[#names + 1] = name end
  table.sort(names)
  d.achLine:SetText(#names > 0 and (MUTED .. "Counted from: " .. table.concat(names, ", ") .. "|r") or "")
  d.whoHead:SetText(MUTED .. ("EARNED BY (%d DETECTED)"):format(#k.who) .. "|r")
  -- name pills
  for _, pl in ipairs(d.pills) do pl:Hide() end
  local x, y, maxw = 0, 0, 398
  for i, name in ipairs(k.who) do
    if i > 18 then break end
    local pl = d.pills[i]
    if not pl then pl = UI.Button(d, "", 80, 24, nil, "field"); d.pills[i] = pl end
    pl:SetText(name); pl:SetWidth(pl.label:GetStringWidth() + 20)
    local w = pl:GetWidth()
    if x + w > maxw then x = 0; y = y + 30 end
    pl:ClearAllPoints(); pl:SetPoint("TOPLEFT", d, "TOPLEFT", 16 + x, -216 - y)
    pl:Show(); x = x + w + 6
  end
  d.noWho:SetText(#k.who == 0 and (MUTED .. "Nobody detected yet. Use + to add manually.|r") or "")
  d.count:SetText(tostring(k.aotc))
  local adj = k.adjust
  d.adjHint:SetText(MUTED .. (adj == 0 and "All auto-detected from chat" or
    (("%d detected, %s%d added manually"):format(#k.who, adj > 0 and "+" or "", adj))) .. "|r")
  if not d.note:HasFocus() then d.note:SetText(k.note or "") end
end
