-- BattleText: your own fight as text that scrolls up beside your character
-- (hits on you on the left, your hits on the right, notices above) and a few
-- short alerts. Its page is in ClassicAPI's Settings window (AddOn Options, or /bt).
-- Doc headings are ClassicAPI's docs/API.md; "FrameXML" is the client's own code.
if not CLASSIC_API_VERSION then error("BattleText needs ClassicAPI.", 0) end

local _, BT = ...
BattleTextDB = BattleTextDB or {} -- restored first: LoadSavedVariablesFirst
local db = BattleTextDB

-- Claude's choices, and Parting's for the mana rows Claude has none of.
local DEFAULTS = { manaGains = true, alertWindfury = true, alertLowHealth = false, alertLowMana = true,
    alertClearcasting = true, alertReady = true }
-- The three areas: x and y of their bottom from the screen's centre (the places
-- Claude dragged them to, the same on both accounts), height, the side the text
-- keeps to, the handle's label.
BT.PLACES = {
    Incoming = { -159, -46, 222, "BOTTOMRIGHT", "Hits on you" },
    Outgoing = { 153, -43, 212, "BOTTOMLEFT", "Your hits" },
    Notification = { -5, 169, 150, "BOTTOM", "Notices" },
}

-- Fill the defaults now (the features start before the window registers the page),
-- and clear every saved key and place nothing owns (KNOWN_PATTERNS KP-64).
for key in pairs(db) do
    if DEFAULTS[key] == nil and key ~= "areas" then db[key] = nil end
end
for key, value in pairs(DEFAULTS) do
    if type(db[key]) ~= "boolean" then db[key] = value end
end
if type(db.areas) ~= "table" then db.areas = nil end
for name, at in pairs(db.areas or {}) do
    if not BT.PLACES[name] or type(at) ~= "table" or type(at.x) ~= "number" or type(at.y) ~= "number" then
        db.areas[name] = nil
    end
end

-- The areas: an unnamed frame each, so the client saves nothing of them (KP-66).
BT.areas = {}
local handles = {}
local function Place(name)
    local home, at = BT.PLACES[name], db.areas and db.areas[name]
    local x, y = at and at.x or home[1], at and at.y or home[2]
    local frame = BT.areas[name].frame
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOM", UIParent, "CENTER", x, y)
    if handles[name] then
        handles[name]:ClearAllPoints()
        handles[name]:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
end
for name, home in pairs(BT.PLACES) do
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetWidth(24)
    frame:SetHeight(24)
    frame:SetFrameStrata("HIGH")
    BT.areas[name] = { frame = frame, height = home[3], point = home[4], lines = {}, crits = {}, nextLine = 1, nextCrit = 1 }
    Place(name)
end

-- Move text areas: a handle on each area. Drag one to move its area; right-click
-- it for the area's own place. Escape or Done hides them (UISpecialFrames).
local function Drop(name, handle)
    local x, y = handle:GetCenter()
    local cx, cy = UIParent:GetCenter()
    db.areas = db.areas or {}
    db.areas[name] = { x = math.floor(x - cx + 0.5), y = math.floor(y - cy + 0.5) }
    Place(name)
end
local function Home(name)
    if db.areas then db.areas[name] = nil end
    Place(name)
end
local mover
function BT.Move()
    if not mover then
        mover = CreateFrame("Frame", "BattleTextMover", UIParent)
        mover:SetAllPoints(UIParent)
        mover:SetFrameStrata("DIALOG")
        UISpecialFrames[#UISpecialFrames + 1] = "BattleTextMover"
        local done = CreateFrame("Button", nil, mover, "UIPanelButtonTemplate")
        done:SetWidth(90)
        done:SetHeight(22)
        done:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
        done:SetText("Done")
        done:SetScript("OnClick", function() mover:Hide() end)
        for name, home in pairs(BT.PLACES) do
            local handle = CreateFrame("Button", nil, mover)
            handle:SetWidth(120)
            handle:SetHeight(24)
            handle:SetMovable(true)
            handle:EnableMouse(true)
            handle:RegisterForDrag("LeftButton")
            handle:RegisterForClicks("RightButtonUp")
            local back = handle:CreateTexture(nil, "BACKGROUND")
            back:SetAllPoints(handle)
            back:SetTexture(0, 0, 0, 0.6)
            local label = handle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("CENTER", handle, "CENTER", 0, 0)
            label:SetText(home[5])
            local area = name
            handle:SetScript("OnDragStart", function(self) self:StartMoving() end)
            handle:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); Drop(area, self) end)
            handle:SetScript("OnClick", function() Home(area) end)
            handles[name] = handle
            Place(name)
        end
    end
    mover:Show()
end

-- The page. A switch's change runs BT.apply[key] (Notices.lua) where events depend on it.
BT.apply = {}
local function HasMana() return BT.hasMana end
local function Clearcasts() return BT.class == "MAGE" or BT.class == "SHAMAN" end
local function KnowsReady() return BT.readyKnown end
local category
SettingsRegistrar:AddRegistrant(function()
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory("BattleText")
    local function Header(text, shown)
        local row = CreateSettingsListSectionHeaderInitializer(text)
        if shown then row:AddShownPredicate(shown) end
        layout:AddInitializer(row)
    end
    local function Switch(key, label, tip, shown)
        local setting = Settings.RegisterAddOnSetting(category, "BattleText_" .. key, key, db,
            Settings.VarType.Boolean, label, DEFAULTS[key])
        if BT.apply[key] then setting:SetValueChangedCallback(BT.apply[key]) end
        local row = Settings.CreateCheckbox(category, setting, tip)
        if shown then row:AddShownPredicate(shown) end
    end
    Header("Text")
    layout:AddInitializer(CreateSettingsButtonInitializer("Move text areas", "Move", BT.Move,
        "A handle on each area: drag it to move the area, right-click it to put it back. Escape or Done hides them.", true))
    Header("Mana", HasMana)
    Switch("manaGains", "All mana gains", "Every rise of your mana shows, from any source. Spell mana gains are then left out, so none shows twice.", HasMana)
    Header("Alerts")
    Switch("alertWindfury", "Windfury!", "When Windfury Totem lands on you, in place of its own line.")
    Switch("alertLowHealth", "Low Health!", "When your health falls below 40%.")
    Switch("alertLowMana", "Low Mana!", "When your mana falls below 35%.", HasMana)
    Switch("alertClearcasting", "Clearcasting!", "When Clearcasting lands on you, in place of its own line.", Clearcasts)
    Switch("alertReady", "Ready alerts", "Riposte!, Overpower!, Execute! and the like, the moment the spell can be used on your target. Only for spells you know.", KnowsReady)
    Settings.RegisterAddOnCategory(category)
end)

SLASH_BATTLETEXT1 = "/bt"
SlashCmdList.BATTLETEXT = function()
    if category then Settings.OpenToCategory(category:GetID()) end
end
