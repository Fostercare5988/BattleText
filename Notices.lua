-- Notices: combat state, combo points, XP, reputation, honor and skill-ups, and
-- the alerts that read your health, mana and spells. Unit events are registered
-- only while a switch needs them.
local _, BT = ...
local db = BattleTextDB
local KINDS = BT.kinds
local LOW_HEALTH, LOW_MANA = 0.4, 0.35 -- the old triggers' thresholds
local HEALTH_ICON = "Interface\\Icons\\Spell_Holy_SealOfSacrifice"

local frame = CreateFrame("Frame")
local on = {}
frame:SetScript("OnEvent", function(_, event, a1, a2, a3) on[event](a1, a2, a3) end)

on.PLAYER_IN_COMBAT_CHANGED = function(inCombat)
    BT.Notice(inCombat and KINDS.COMBAT_ENTER or KINDS.COMBAT_LEAVE, nil, nil, nil, BT.SWORDS)
end

on.PLAYER_COMBO_POINTS = function()
    local points = GetComboPoints("player", "target")
    if points > 0 then BT.Notice(points == MAX_COMBO_POINTS and KINDS.CP_FULL or KINDS.CP, points) end
end

-- XP: the change in UnitXP; across a level-up, the rest of the old level plus the new.
local lastXP, lastMax
local function ReadXP() lastXP, lastMax = UnitXP("player"), UnitXPMax("player") end
on.PLAYER_XP_UPDATE = function()
    if not lastXP then return ReadXP() end
    local xp, max = UnitXP("player"), UnitXPMax("player")
    local gain = xp - lastXP
    if gain < 0 then gain = lastMax - lastXP + xp end
    if gain > 0 then BT.Notice(KINDS.XP, gain) end
    lastXP, lastMax = xp, max
end

on.FACTION_STANDING_CHANGED = function(factionID, _, change)
    change = tonumber(change) or 0
    if change == 0 then return end
    local name = factionID and GetFactionInfoByID(factionID)
    BT.Notice(change > 0 and KINDS.REP_GAIN or KINDS.REP_LOSS, math.abs(change), nil, name or nil)
end

-- The chat lines of the client's own strings (GlobalStrings) as patterns: %s and %d capture.
local function Pattern(format)
    local pattern = string.gsub(format, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    pattern = string.gsub(string.gsub(pattern, "%%s", "(.+)"), "%%d", "(%%d+)")
    return "^" .. pattern .. "$"
end
local HONOR_KILL, HONOR_AWARD = Pattern(COMBATLOG_HONORGAIN), Pattern(COMBATLOG_HONORAWARD)
local SKILL_UP = Pattern(SKILL_RANK_UP)
-- GAP: no event carries an honor gain. A DLL should fire one with the amount (and
-- the victim's GUID), or give a getter inside the chat event.
on.CHAT_MSG_COMBAT_HONOR_GAIN = function(text)
    local _, _, honor = string.match(text or "", HONOR_KILL)
    honor = honor or string.match(text or "", HONOR_AWARD)
    if honor then BT.Notice(KINDS.HONOR, honor) end
end
-- GAP: no event carries a skill-up. A DLL should fire SKILL_RANK_CHANGED(skillLineID,
-- newRank), or give a getter inside the chat event.
on.CHAT_MSG_SKILL = function(text)
    local skill, rank = string.match(text or "", SKILL_UP)
    if skill then BT.Notice(KINDS.SKILL, rank, skill) end
end

-- Mana (in every form: UnitPower with type 0) and health; an alert shows when the
-- value falls through its line, and again only after it rose above.
local lastMana, manaArmed, healthArmed
on.UNIT_POWER_UPDATE = function(_, power)
    if power ~= "MANA" then return end
    local mana, max = UnitPower("player", 0), UnitPowerMax("player", 0)
    if db.manaGains and mana > lastMana then BT.Notice(KINDS.POWER_GAIN, mana - lastMana .. " Mana") end
    lastMana = mana
    if db.alertLowMana and max > 0 then
        local low = mana < max * LOW_MANA
        if low and manaArmed then BT.Notice(KINDS.LOW_MANA, mana) end
        manaArmed = not low
    end
end
on.UNIT_HEALTH = function()
    local health, max = UnitHealth("player"), UnitHealthMax("player")
    if max <= 0 then return end
    local low = health < max * LOW_HEALTH
    -- health > 0: the hit that kills you is no alert.
    if low and healthArmed and health > 0 then BT.Notice(KINDS.LOW_HEALTH, health, nil, nil, HEALTH_ICON) end
    healthArmed = not low
end

local function Units()
    if BT.hasMana and (db.manaGains or db.alertLowMana) then
        lastMana = UnitPower("player", 0)
        manaArmed = lastMana >= UnitPowerMax("player", 0) * LOW_MANA
        frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    else
        frame:UnregisterEvent("UNIT_POWER_UPDATE")
    end
    if db.alertLowHealth then
        healthArmed = UnitHealth("player") >= UnitHealthMax("player") * LOW_HEALTH
        frame:RegisterUnitEvent("UNIT_HEALTH", "player")
    else
        frame:UnregisterEvent("UNIT_HEALTH")
    end
end

-- Ready alerts: the spell record says when the window is open
-- (C_Spell.IsSpellReactiveReady), in any stance; a dodge on another unit is not
-- this target's. The record leaves the cooldown out, so a window that opens while
-- the spell cools down shows when the cooldown ends. Riposte 14251, Overpower
-- 7384, Counterattack 19306 and Mongoose Bite 1495 read in the OctoWoW database, 2026-11-22.
-- UNVERIFIED: test in game, Execute and Hammer of Wrath by name: /run print(GetSpellInfo("Execute"))
local READY = { "Riposte", "Overpower", "Counterattack", "Mongoose Bite", "Execute", "Hammer of Wrath" }
local known, open, cooling = {}, {}, false -- known: name -> the spell ID you have
local Recheck
local function Ready()
    BT.readyKnown = false
    for _, name in ipairs(READY) do
        known[name] = select(10, GetSpellInfo(name))
        BT.readyKnown = BT.readyKnown or known[name] ~= nil
    end
    if BT.readyKnown and db.alertReady then
        frame:RegisterEvent("SPELL_UPDATE_USABLE")
    else
        frame:UnregisterEvent("SPELL_UPDATE_USABLE")
    end
end
-- Seconds left on the spell's own cooldown; the global cooldown does not count.
local function CooldownLeft(id)
    local cd = C_Spell.GetSpellCooldown(id)
    if not cd or cd.duration == 0 or cd.isOnGCD then return 0 end
    return cd.startTime + cd.duration - GetTime()
end
on.SPELLS_CHANGED = Ready
on.SPELL_UPDATE_USABLE = function()
    local target = UnitGUID("target")
    for _, name in ipairs(READY) do
        if known[name] then
            local ready, comboTarget = C_Spell.IsSpellReactiveReady(name)
            ready = ready and (comboTarget == nil or comboTarget == target) or false
            if ready and not open[name] then
                local left = CooldownLeft(known[name])
                if left > 0 then
                    ready = false
                    if not cooling then cooling = true; C_Timer.After(left, Recheck) end
                else
                    local _, _, icon = GetSpellInfo(name)
                    BT.Notice(KINDS.READY, nil, name, nil, icon)
                end
            end
            open[name] = ready
        end
    end
end
-- C_Timer swallows a callback's errors (C_Timer.After), so the check runs under the error handler.
Recheck = function()
    cooling = false
    if BT.readyKnown and db.alertReady then xpcall(on.SPELL_UPDATE_USABLE, geterrorhandler()) end
end

BT.apply.manaGains, BT.apply.alertLowMana, BT.apply.alertLowHealth, BT.apply.alertReady = Units, Units, Units, Ready

on.PLAYER_LOGIN = function()
    local _, class = UnitClass("player")
    BT.class, BT.hasMana = class, class ~= "WARRIOR" and class ~= "ROGUE"
    Units()
    Ready()
end
on.PLAYER_ENTERING_WORLD = function()
    ReadXP()
    if lastMana then lastMana = UnitPower("player", 0) end
end

for event in pairs(on) do
    if event ~= "UNIT_POWER_UPDATE" and event ~= "UNIT_HEALTH" and event ~= "SPELL_UPDATE_USABLE" then
        frame:RegisterEvent(event)
    end
end
