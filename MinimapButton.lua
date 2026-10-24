local ADDON, KL = ...
local ICON = "Interface\\AddOns\\WildGraceKillLedger\\icon"
local btn

local function Place()
  local a = math.rad(KL.db.minimap.angle or 215)
  local r = (Minimap:GetWidth() / 2) + 5
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function Drag()
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  KL.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
  Place()
end

local function Build()
  btn = CreateFrame("Button", "WildGraceKillLedgerMinimapButton", Minimap)
  btn:SetSize(31, 31); btn:SetFrameStrata("MEDIUM"); btn:SetFrameLevel(8)
  btn:RegisterForClicks("LeftButtonUp"); btn:RegisterForDrag("LeftButton")
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(21, 21); icon:SetPoint("CENTER", 0, 0); icon:SetTexture(ICON)
  icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetPoint("TOPLEFT"); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  btn:SetScript("OnClick", function() KL.Toggle() end)
  btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", Drag) end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Wild Grace Kill Ledger", 0.91, 0.72, 0.29)
    GameTooltip:AddLine("Click to open or close", 1, 1, 1)
    GameTooltip:AddLine("Drag to move", 0.64, 0.62, 0.57)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  Place()
  btn:SetShown(not KL.db.minimap.hide)
end

function KL.ToggleMinimap()
  KL.db.minimap.hide = not KL.db.minimap.hide
  btn:SetShown(not KL.db.minimap.hide)
  KL.Print(KL.db.minimap.hide and "minimap button hidden. Type /kl minimap to show it again." or "minimap button shown.")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  KL.db.minimap = KL.db.minimap or { angle = 215, hide = false }
  Build()
end)
