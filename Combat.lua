-- Combat: your own fight from the combat log. The client's one filter is set to
-- you, so the fights of others never reach Lua (CombatLogAddFilter). BattleText
-- owns that filter; no other installed addon uses it (2026-11-22).
local _, BT = ...
local db = BattleTextDB

-- The kinds of line: area, text, colour, size, crit size, whether it pops.
-- The old defaults (BattleText 2.4.3 Defaults.lua), without the pet rows.
local I, O, N = "Incoming", "Outgoing", "Notification"
local MINUS = "|cffff0000-|r"
local function K(area, text, r, g, b, size, critSize, pop)
    return { area = area, text = text, r = r, g = g, b = b, size = size or 20, critSize = critSize or 26, pop = pop }
end
local SWORDS = "Interface\\Icons\\Ability_DualWield"
BT.kinds = {
    IN_HIT = K(I, MINUS .. "%a", 1, 1, 1), IN_SPELL = K(I, MINUS .. "%a", 1, 1, 0), IN_DOT = K(I, MINUS .. "%a", 1, 1, 0),
    IN_MISS = K(I, "Miss!", 0, 0, 1), IN_DODGE = K(I, "Dodge!", 0, 0, 1), IN_PARRY = K(I, "Parry!", 0, 0, 1),
    IN_BLOCK = K(I, "Block!", 0, 0, 1), IN_ABSORB = K(I, "Absorb!", 1, 1, 0), IN_IMMUNE = K(I, "Immune!", 1, 1, 0),
    IN_EVADE = K(I, "Evade!", 1, 1, 0),
    IN_SPELL_MISS = K(I, "Miss!", 0, 0, 1), IN_SPELL_DODGE = K(I, "Dodge!", 0, 0, 1), IN_SPELL_PARRY = K(I, "Parry!", 0, 0, 1),
    IN_SPELL_BLOCK = K(I, "Block!", 0, 0, 1), IN_SPELL_RESIST = K(I, "(%s) Resist!", 0.502, 0, 0.502),
    IN_SPELL_ABSORB = K(I, "(%s) Absorb!", 1, 1, 0), IN_SPELL_IMMUNE = K(I, "(%s) Immune!", 1, 1, 0),
    IN_SPELL_REFLECT = K(I, "(%s) Reflect!", 0.502, 0, 0.502), IN_SPELL_EVADE = K(I, "(%s) Evade!", 1, 1, 0),
    IN_HEAL = K(I, "+%a%n", 0, 1, 0), IN_HOT = K(I, "+%a%n", 0, 1, 0), IN_ENV = K(I, MINUS .. "%a %s", 1, 0, 0),

    OUT_HIT = K(O, "%a", 1, 1, 1), OUT_SPELL = K(O, "%a", 1, 1, 0), OUT_DOT = K(O, "%a", 1, 1, 0),
    OUT_MISS = K(O, "Miss!", 0, 0, 1), OUT_DODGE = K(O, "Dodge!", 0, 0, 1), OUT_PARRY = K(O, "Parry!", 0, 0, 1),
    OUT_BLOCK = K(O, "Block!", 0, 0, 1), OUT_ABSORB = K(O, "Absorb!", 1, 1, 0), OUT_IMMUNE = K(O, "Immune!", 1, 1, 0),
    OUT_EVADE = K(O, "Evade!", 1, 0.502, 0, 22),
    OUT_SPELL_MISS = K(O, "Miss!", 1, 1, 0), OUT_SPELL_DODGE = K(O, "Dodge!", 1, 1, 0), OUT_SPELL_PARRY = K(O, "Parry!", 1, 1, 0),
    OUT_SPELL_BLOCK = K(O, "Block!", 1, 1, 0), OUT_SPELL_RESIST = K(O, "Resist!", 0.502, 0.502, 0.698),
    OUT_SPELL_ABSORB = K(O, "(%s) Absorb!", 1, 1, 0), OUT_SPELL_IMMUNE = K(O, "(%s) Immune!", 1, 1, 0),
    OUT_SPELL_REFLECT = K(O, "(%s) Reflect!", 1, 1, 0), OUT_SPELL_EVADE = K(O, "(%s) Evade!", 1, 0.502, 0, 22),
    OUT_HEAL = K(O, "+%a", 0, 1, 0, 20, 22), OUT_HOT = K(O, "+%a", 0, 1, 0),

    DEBUFF = K(N, "[%s]", 0, 0.502, 0.502), DEBUFF_STACK = K(N, "[%s %a]", 0, 0.502, 0.502),
    BUFF = K(N, "[%s]", 0.698, 0.698, 0), BUFF_STACK = K(N, "[%s %a]", 0.698, 0.698, 0),
    BUFF_FADE = K(N, "-[%s]", 0.698, 0.698, 0),
    COMBAT_ENTER = K(N, "+Combat", 1, 0.25, 0.25), COMBAT_LEAVE = K(N, "-Combat", 0.25, 1, 0.25),
    POWER_GAIN = K(N, "+%a", 0.31, 0.31, 0.878), POWER_LOSS = K(N, MINUS .. "%a", 0.757, 0.271, 0.824),
    CP = K(N, "%a CP", 1, 0.502, 0), CP_FULL = K(N, "%a CP Finish It!", 1, 0.502, 0),
    HONOR = K(N, "+%a Honor", 0.502, 0.502, 0.698), SKILL = K(N, "%s: %a", 0.333, 0.333, 1),
    REP_GAIN = K(N, "+%a Reputation%n", 0.502, 0.502, 0.698), REP_LOSS = K(N, MINUS .. "%a Reputation%n", 0.502, 0.502, 0.698),
    XP = K(N, "%a XP", 0.756, 0.27, 0.823, 26, nil, true),
    KILL_PLAYER = K(N, "Killing Blow!%n", 0.333, 0.333, 1, 20, nil, true),
    KILL_NPC = K(N, "Killing Blow!%n", 0.333, 0.333, 1, 20, nil, true),
    -- The alerts (the old triggers).
    WINDFURY = K(N, "Windfury!", 1, 1, 0, 26, nil, true), CLEARCASTING = K(N, "Clearcasting!", 1, 1, 0, 26, nil, true),
    LOW_HEALTH = K(N, "Low Health! (%a)", 1, 0.502, 0.502, 26), LOW_MANA = K(N, "Low Mana! (%a)", 0.502, 0.502, 1, 26),
    READY = K(N, "%s!", 1, 1, 0, 26, nil, true),
}
local KINDS = BT.kinds
KINDS.COMBAT_ENTER.tint, KINDS.COMBAT_ENTER.iconScale = { 1, 0.2, 0.2 }, 2
KINDS.COMBAT_LEAVE.tint, KINDS.COMBAT_LEAVE.iconScale = { 0.2, 1, 0.2 }, 2
BT.SWORDS = SWORDS

-- Lookups made once: hits by side and kind, misses by side, spell or melee, and
-- missType (a parry deflected is a parry; a melee resist or reflect is a spell's).
local HITS, MISSES, HEALS = {}, {}, { IN = { [false] = KINDS.IN_HEAL, [true] = KINDS.IN_HOT },
    OUT = { [false] = KINDS.OUT_HEAL, [true] = KINDS.OUT_HOT } }
for _, side in ipairs({ "IN", "OUT" }) do
    HITS[side] = { melee = KINDS[side .. "_HIT"], spell = KINDS[side .. "_SPELL"], dot = KINDS[side .. "_DOT"] }
    MISSES[side] = { [false] = {}, [true] = {} }
    for _, miss in ipairs({ "MISS", "DODGE", "PARRY", "BLOCK", "ABSORB", "IMMUNE", "EVADE", "RESIST", "REFLECT" }) do
        local spell = KINDS[side .. "_SPELL_" .. miss]
        MISSES[side][true][miss] = spell
        MISSES[side][false][miss] = KINDS[side .. "_" .. miss] or spell
    end
    MISSES[side][true].DEFLECT, MISSES[side][false].DEFLECT = MISSES[side][true].PARRY, MISSES[side][false].PARRY
end
local POWER = { [0] = "Mana", [1] = "Rage", [3] = "Energy" }

-- No line names these spells: the seven filters on, on both accounts (2.4.3
-- profiles, 2026-11-22). The line's spell name is searched, never its text.
-- UNVERIFIED: test in game, that "Vigor" is the rogue talent's aura (14983): /run print(GetSpellInfo(14983))
local HIDDEN = { "Strength of Earth", "Stoneskin", "Healing Stream", "Mana Spring", "Lightning Shield",
    "Judgement of Wisdom", "Vigor" }
local function Hidden(spell)
    if not spell then return false end
    for i = 1, #HIDDEN do
        if string.find(spell, HIDDEN[i], 1, true) then return true end
    end
    return false
end

-- Alerts that replace their aura's line. UNVERIFIED: test in game, the aura names
-- (the old addon matched them by these names in play).
local AURA_ALERTS = { ["Windfury Totem"] = "alertWindfury", Clearcasting = "alertClearcasting" }
local function AuraAlert(spell, spellID)
    local key = AURA_ALERTS[spell]
    if not key or not db[key] then return false end
    if key == "alertClearcasting" and BT.class ~= "MAGE" and BT.class ~= "SHAMAN" then return false end
    BT.Notice(key == "alertWindfury" and KINDS.WINDFURY or KINDS.CLEARCASTING, nil, nil, nil, C_Spell.GetSpellTexture(spellID))
    return true
end

-- The values of the event being handled (COMBAT_LOG_EVENT): v1... follow the 11 common ones.
local me
local sub, srcGUID, srcName, dstGUID, dstName, dstFlags
local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12
local handlers = {}

-- Your side of the event and the other unit: hits on you, else your hits.
local function Other()
    if dstGUID == me then return "IN", srcName, srcGUID end
    if srcGUID == me then return "OUT", dstName, dstGUID end
end

local function Hit(spellID, spell, amount, school, resisted, blocked, absorbed, critical, glancing, crushing, dot)
    local side, name, guid = Other()
    if not side or Hidden(spell) then return end
    if (amount or 0) == 0 and absorbed then
        return BT.Queue(MISSES[side][spell ~= nil].ABSORB, nil, spell, spellID, name, guid)
    end
    local partial, part
    if crushing then partial = "CRUSHING"
    elseif glancing then partial = "GLANCING"
    elseif absorbed then partial, part = "ABSORB", absorbed
    elseif blocked then partial, part = "BLOCK", blocked
    elseif resisted then partial, part = "RESIST", resisted end
    local kind = HITS[side][dot and "dot" or spell and "spell" or "melee"]
    BT.Queue(kind, amount or 0, spell, spellID, name, guid, school, critical, partial, part)
end

local function Miss(spellID, spell, missType)
    local side, name, guid = Other()
    if not side or Hidden(spell) then return end
    local kind = MISSES[side][spell ~= nil][missType]
    if kind then BT.Queue(kind, nil, spell, spellID, name, guid) end
end

-- Melee: amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing.
handlers.SWING_DAMAGE = function() Hit(nil, nil, v1, v3, v4, v5, v6, v7, v8, v9) end
handlers.SWING_MISSED = function() Miss(nil, nil, v1) end
-- Spells: spellId, spellName, spellSchool, then the same.
local function SpellHit() Hit(v1, v2, v4, v6, v7, v8, v9, v10, v11, v12, sub == "SPELL_PERIODIC_DAMAGE") end
handlers.SPELL_DAMAGE, handlers.SPELL_PERIODIC_DAMAGE, handlers.RANGE_DAMAGE, handlers.DAMAGE_SPLIT = SpellHit, SpellHit, SpellHit, SpellHit
local function SpellMiss() Miss(v1, v2, v4) end
handlers.SPELL_MISSED, handlers.SPELL_PERIODIC_MISSED, handlers.RANGE_MISSED = SpellMiss, SpellMiss, SpellMiss
-- A damage shield names its spell when its owner has one of that school; else spell 0, no name.
handlers.DAMAGE_SHIELD = function()
    if v1 == 0 then Hit(nil, "Damage Shield", v4, v6, v7, v8, v9, v10, v11, v12)
    else Hit(v1, v2 or "Damage Shield", v4, v6, v7, v8, v9, v10, v11, v12) end
end
handlers.DAMAGE_SHIELD_MISSED = function()
    if v1 == 0 then Miss(nil, "Damage Shield", v4) else Miss(v1, v2 or "Damage Shield", v4) end
end

-- Heals: amount, overhealing, absorbed, critical. Shown is what it healed, the
-- overheal after it; an over-time tick that healed nothing is left out.
local function Heal()
    local side, name, guid = Other()
    if not side or Hidden(v2) then return end
    local overheal = v5 or 0
    local amount = math.max((v4 or 0) - overheal, 0)
    local hot = sub == "SPELL_PERIODIC_HEAL"
    if hot and amount == 0 and overheal > 0 then return end
    BT.Queue(HEALS[side][hot], amount, v2, v1, name, guid, nil, v7, overheal > 0 and "OVERHEAL" or nil, overheal)
end
handlers.SPELL_HEAL, handlers.SPELL_PERIODIC_HEAL = Heal, Heal

-- Power you gain (amount, powerType); spell mana is left out while every rise of mana shows.
local function Energize()
    local power = dstGUID == me and POWER[tonumber(v5)]
    if not power or Hidden(v2) or (power == "Mana" and BT.hasMana and db.manaGains) then return end
    BT.Notice(KINDS.POWER_GAIN, (v4 or 0) .. " " .. power, v2, nil, v1 and C_Spell.GetSpellTexture(v1))
end
handlers.SPELL_ENERGIZE, handlers.SPELL_PERIODIC_ENERGIZE = Energize, Energize
-- Power taken from you.
local function Drain()
    local power = dstGUID == me and POWER[tonumber(v5)]
    if not power or (v4 or 0) <= 0 or Hidden(v2) then return end
    BT.Notice(KINDS.POWER_LOSS, v4 .. " " .. power, v2, nil, v1 and C_Spell.GetSpellTexture(v1))
end
handlers.SPELL_DRAIN, handlers.SPELL_PERIODIC_DRAIN, handlers.SPELL_LEECH, handlers.SPELL_PERIODIC_LEECH = Drain, Drain, Drain, Drain

-- Your auras: auraType, then the stacks after a gain. A lost stack is no fade.
local function Aura()
    if dstGUID ~= me then return end
    local spell = v2 or (v1 and v1 ~= 0 and GetSpellInfo(v1)) or nil
    if not spell or Hidden(spell) then return end
    local kind
    if sub == "SPELL_AURA_REMOVED" then kind = KINDS.BUFF_FADE
    elseif sub == "SPELL_AURA_APPLIED" then
        if AuraAlert(spell, v1) then return end
        kind = v4 == "DEBUFF" and KINDS.DEBUFF or KINDS.BUFF
    else kind = v4 == "DEBUFF" and KINDS.DEBUFF_STACK or KINDS.BUFF_STACK end
    BT.Notice(kind, v5, spell, nil, v1 and v1 ~= 0 and C_Spell.GetSpellTexture(v1) or nil)
end
handlers.SPELL_AURA_APPLIED, handlers.SPELL_AURA_APPLIED_DOSE, handlers.SPELL_AURA_REMOVED = Aura, Aura, Aura

-- Your killing blows: the victim's flags say whether it was a player.
handlers.PARTY_KILL = function()
    if srcGUID ~= me then return end
    local player = bit.band(dstFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0
    BT.Notice(player and KINDS.KILL_PLAYER or KINDS.KILL_NPC, nil, nil, dstName)
end

-- Falling, drowning and the rest: type, amount, overkill, school, resisted, blocked, absorbed.
handlers.ENVIRONMENTAL_DAMAGE = function()
    if dstGUID ~= me then return end
    local partial, part
    if v7 then partial, part = "ABSORB", v7 elseif v5 then partial, part = "RESIST", v5 end
    BT.Queue(KINDS.IN_ENV, v2 or 0, v1, nil, nil, nil, nil, nil, partial, part)
end

local SUBEVENTS = {}
for name in pairs(handlers) do SUBEVENTS[#SUBEVENTS + 1] = name end
table.sort(SUBEVENTS)
SUBEVENTS = table.concat(SUBEVENTS, ",")

local log = CreateFrame("Frame")
log:SetScript("OnEvent", function()
    local _
    _, sub, _, srcGUID, srcName, _, _, dstGUID, dstName, dstFlags, _,
        v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12 = CombatLogGetCurrentEventInfo()
    local handler = handlers[sub]
    if handler then handler() end
end)

-- At login: the filter, set once (it stays over /reload), and your GUID.
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event)
    me = UnitGUID("player")
    BT.playerGUID = me
    if event == "PLAYER_LOGIN" then
        CombatLogResetFilter()
        CombatLogAddFilter(SUBEVENTS, COMBATLOG_FILTER_ME)
        CombatLogAddFilter(SUBEVENTS, nil, COMBATLOG_FILTER_ME)
        log:RegisterEvent("COMBAT_LOG_EVENT")
    end
end)
