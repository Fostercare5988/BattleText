-- Display: each line is a small frame whose animation groups move, pop and fade
-- it ("Animation"), so no Lua runs between messages. Lines about you and your
-- attacks wait 0.3 s, and like lines merge into one; notices show at once.
-- UNVERIFIED: test in game, the Scale pop on a font string (read from API.md only).
local _, BT = ...

local FONT = "Interface\\AddOns\\BattleText\\Fonts\\Inter-Bold.ttf"
local SPEED = 75              -- px a second: the old step of 1.5
local POP_IN, POP_HOLD, POP_OUT = 0.15, 2, 0.5
local STEP, GAP = 30, 2       -- px between popped lines; between scrolling ones
local LINES = 10              -- scrolling lines and popped lines per area
local MERGE = 0.3
-- Popped lines take the first free place around the middle of their area.
local PLACES = { 0, 1, -1, 2, -2, 3, -3, 4, -4, 5 }

-- Damage schools (the old defaults): the amount's colour, and the line's (holy keeps
-- the kind's); physical has none.
local SCHOOL = { [2] = "|cffF6F99E", [4] = "|cffFF4444", [8] = "|cff44FF44", [16] = "|cff4488FF",
    [32] = "|cff6600CC", [64] = "|cffCC66FF" }
local SCHOOL_RGB = { [4] = { 1, 0.27, 0.27 }, [8] = { 0.27, 1, 0.27 }, [16] = { 0.27, 0.53, 1 },
    [32] = { 0.4, 0, 0.8 }, [64] = { 0.8, 0.4, 1 } }
-- The trailers: the client's own strings (GlobalStrings), the old colours.
local PARTIAL = { ABSORB = "|cffFAFA00" .. ABSORB_TRAILER .. "|r", BLOCK = "|cff7F00FF" .. BLOCK_TRAILER .. "|r",
    RESIST = "|cff81007F" .. RESIST_TRAILER .. "|r", CRUSHING = "|cff7D0000" .. CRUSHING_TRAILER .. "|r",
    GLANCING = "|cffFA0000" .. GLANCING_TRAILER .. "|r", OVERHEAL = "|cff00B47F <%d>|r" }

local function Release(line)
    line.busy = nil
    if line.shake then line.shake:Stop() end
    line.frame:Hide()
end

local function NewLine(area, pop)
    local frame = CreateFrame("Frame", nil, area.frame)
    frame:SetWidth(1)
    frame:SetHeight(1)
    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 20, "OUTLINE")
    text:SetPoint(area.point, frame, area.point, 0, 0)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("RIGHT", text, "LEFT", -4, 0)
    icon:SetTexCoord(0.125, 0.875, 0.125, 0.875)
    local line = { frame = frame, text = text, icon = icon, size = 20 }
    local group = frame:CreateAnimationGroup()
    group:SetIgnoreFramerateThrottle(true)
    group:SetScript("OnFinished", function() Release(line) end)
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    if pop then
        for _, region in ipairs({ text, icon }) do
            local grow = group:CreateAnimation("Scale")
            grow:SetTarget(region)
            grow:SetScaleFrom(2, 2)
            grow:SetScaleTo(1, 1)
            grow:SetDuration(POP_IN)
        end
        fade:SetStartDelay(POP_IN + POP_HOLD)
        fade:SetDuration(POP_OUT)
        -- A crit shakes in place while it shows.
        local shake = frame:CreateAnimationGroup()
        shake:SetLooping("REPEAT")
        shake:SetIgnoreFramerateThrottle(true)
        local path = shake:CreateAnimation("Path")
        path:SetDuration(0.2)
        path:CreateControlPoint():SetOffset(1, 1)
        path:CreateControlPoint():SetOffset(-1, 1)
        path:CreateControlPoint():SetOffset(-1, -1)
        path:CreateControlPoint():SetOffset(0, 0)
        line.shake = shake
    else
        local seconds = area.height / SPEED
        local move = group:CreateAnimation("Translation")
        move:SetOffset(0, area.height)
        move:SetDuration(seconds)
        fade:SetStartDelay(seconds / 2)
        fade:SetDuration(seconds / 2)
    end
    line.group = group
    return line
end

local function Anchor(area, line, y)
    line.y = y
    line.frame:ClearAllPoints()
    line.frame:SetPoint(area.point, area.frame, area.point, 0, y)
end

-- A scrolling line starts at the bottom. A line still near the bottom is pushed
-- up out of its way, and the push runs on up the chain; the drawing keeps its
-- animated offset (Translation: "the drawing moves with it").
local function Scrolling(area, size)
    local slot = area.nextLine
    area.nextLine = slot % LINES + 1
    local line = area.lines[slot] or NewLine(area)
    area.lines[slot] = line
    if line.busy then line.group:Stop() end
    local floor, j = size + GAP, slot
    for _ = 2, LINES do
        j = j == 1 and LINES or j - 1
        local other = area.lines[j]
        if not (other and other.busy) then break end
        local y = other.y + area.height * other.group:GetProgress()
        if y >= floor then break end
        Anchor(area, other, other.y + floor - y)
        floor = floor + other.size + GAP
    end
    Anchor(area, line, 0)
    return line
end

local function Popped(area)
    local slot = area.nextCrit
    area.nextCrit = slot % LINES + 1
    local line = area.crits[slot] or NewLine(area, true)
    area.crits[slot] = line
    if line.busy then line.group:Stop(); Release(line) end
    for _, place in ipairs(PLACES) do
        local taken = false
        for i = 1, LINES do
            local other = area.crits[i]
            if other and other.busy and other.place == place then taken = true; break end
        end
        if not taken then line.place = place; break end
    end
    Anchor(area, line, area.height / 2 + line.place * STEP)
    return line
end

-- Shows one line. A crit pops and shakes; a kind marked pop only pops.
function BT.Draw(kind, text, icon, crit, school)
    local area = BT.areas[kind.area]
    local pop = crit or kind.pop
    local size = crit and kind.critSize or kind.size
    local line = pop and Popped(area) or Scrolling(area, size)
    if line.size ~= size then line.text:SetFont(FONT, size, "OUTLINE"); line.size = size end
    local rgb = SCHOOL_RGB[school]
    if rgb then line.text:SetTextColor(rgb[1], rgb[2], rgb[3]) else line.text:SetTextColor(kind.r, kind.g, kind.b) end
    line.text:SetText(text)
    if icon then
        local width = size * (kind.iconScale or 1)
        line.icon:SetTexture(icon)
        line.icon:SetWidth(width)
        line.icon:SetHeight(width)
        line.icon:SetDesaturated(kind.tint and true or false)
        if kind.tint then line.icon:SetVertexColor(kind.tint[1], kind.tint[2], kind.tint[3]) else line.icon:SetVertexColor(1, 1, 1) end
        line.icon:Show()
    else
        line.icon:Hide()
    end
    line.busy = true
    line.frame:Show()
    line.group:Play()
    if crit then line.shake:Play() end
end

-- A line's text in one pass: %a the amount, %s the spell, %n " (name)" or nothing.
-- One table replacement (### string.gsub replacements), no closure.
local fill = {}
function BT.Text(template, amount, spell, name)
    fill.a, fill.s, fill.n = amount or "", spell or "", name and " (" .. name .. ")" or ""
    return (string.gsub(template, "%%(%a)", fill))
end

-- A notice shows at once.
function BT.Notice(kind, amount, spell, name, icon)
    BT.Draw(kind, BT.Text(kind.text, amount, spell, name), icon)
end

-- Class colours by GUID, made once per class from the interface's own colours.
local classHex = {}
local function Named(name, guid)
    if not guid or not name then return name end
    if guid == BT.playerGUID then return nil end
    local _, class = GetPlayerInfoByGUID(guid)
    if not class then return name end
    local hex = classHex[class]
    if hex == nil then
        local color = C_ClassColor.GetClassColor(class)
        hex = color and color:GenerateHexColorMarkup() or false
        classHex[class] = hex
    end
    return hex and hex .. name .. "|r" or name
end

-- The merge queue: entries come from a pool; one timer per window.
local queue, spare, count, waiting = {}, {}, 0, false

local function Like(a, b)
    if a.kind ~= b.kind or a.spell ~= b.spell or a.spellID ~= b.spellID then return false end
    if a.spell then return true end
    if a.guid or b.guid then return a.guid == b.guid end
    return a.name ~= nil and a.name == b.name
end

local function Show(e)
    local amount = e.amount
    if amount and SCHOOL[e.school] then amount = SCHOOL[e.school] .. amount .. "|r" end
    local text = BT.Text(e.kind.text, amount, e.spell, Named(e.name, e.guid))
    if e.count > 1 then
        local crits = e.crits > 1 and ", " .. e.crits .. " Crits" or e.crits == 1 and ", 1 Crit" or ""
        text = text .. " [" .. e.count .. " Hits" .. crits .. "]"
    elseif e.partial then
        text = text .. string.format(PARTIAL[e.partial], e.partialAmount or 0)
    end
    local icon = e.spellID and e.spellID ~= 0 and C_Spell.GetSpellTexture(e.spellID) or nil
    BT.Draw(e.kind, text, icon, e.count == 1 and e.crit, e.school)
end

local function Work()
    for i = 1, count do
        local e = queue[i]
        if not e.gone then
            for j = i + 1, count do
                local o = queue[j]
                if not o.gone and Like(e, o) then
                    if e.spell and (e.guid ~= o.guid or e.name ~= o.name) then e.name, e.guid = "Multiple", nil end
                    if e.amount and o.amount then e.amount = e.amount + o.amount end
                    e.count, e.crits, o.gone = e.count + 1, e.crits + o.crits, true
                end
            end
            Show(e)
        end
    end
end

local function Clear()
    for i = 1, count do
        local e = queue[i]
        e.gone, queue[i] = nil, nil
        spare[#spare + 1] = e
    end
    count = 0
end

-- C_Timer swallows a callback's errors (C_Timer.After), so the work runs under the error handler.
local function Flush()
    waiting = false
    xpcall(Work, geterrorhandler())
    Clear()
end

function BT.Queue(kind, amount, spell, spellID, name, guid, school, crit, partial, partialAmount)
    local e = spare[#spare]
    if e then spare[#spare] = nil else e = {} end
    e.kind, e.amount, e.spell, e.spellID, e.name, e.guid = kind, amount, spell, spellID, name, guid
    e.school, e.crit, e.partial, e.partialAmount = school, crit, partial, partialAmount
    e.count, e.crits = 1, crit and 1 or 0
    count = count + 1
    queue[count] = e
    if not waiting then
        waiting = true
        C_Timer.After(MERGE, Flush)
    end
end

-- A loading screen: every line stops and goes back, and the queue empties.
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
    for _, area in pairs(BT.areas) do
        area.frame:StopAnimating()
        for i = 1, LINES do
            if area.lines[i] then Release(area.lines[i]) end
            if area.crits[i] then Release(area.crits[i]) end
        end
    end
    Clear()
end)
