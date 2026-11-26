# BattleText

Your own fight as text that scrolls up beside your character, for World of
Warcraft 1.12.1: hits on you on the left, your hits on the right, notices
above, and a few short alerts.

## Features

- **Hits on you and your hits**: melee, spells and damage over time, each kind
  of miss, heals with the healer's name, falling and the other environment
  damage. Spell damage takes its school's colour, player names their class
  colour, and a spell's icon shows beside its line.
- **Partial effects**: absorbed, blocked, resisted, crushing and glancing, and
  the overheal in `<>`. A heal over time that healed nothing is not shown.
- **Crits pop** in the middle of their area and shake there.
- **Merging**: like lines within 0.3 s become one line, such as
  `350 [3 Hits, 1 Crit]`.
- **Notices**: buffs and debuffs gained, stacks and lost, entering and leaving
  combat, power gained or drained, combo points, honor, reputation, skill-ups,
  XP and killing blows.
- **Alerts**: Windfury!, Low Health!, Low Mana!, Clearcasting!, and the ready
  alerts (Riposte!, Overpower!, Execute! and the like) the moment the spell can
  be used on your target, only for spells you know (a window that opens
  during the spell's cooldown shows when the cooldown ends).
- **Hidden spells**: no line names Strength of Earth, Stoneskin, Healing
  Stream, Mana Spring, Lightning Shield, Judgement of Wisdom or Vigor.

The game moves and fades the text itself (animation groups), so no addon code
runs between messages.

## Settings

`/bt`, or Game Menu > AddOn Options > BattleText:

- **Move text areas**: a handle on each area. Drag it to move the area,
  right-click it to put it back. Escape or Done hides them.
- **All mana gains** (characters with mana): every rise of your mana shows.
- **Alerts**: a switch for each.

The game's own damage numbers are the game's "Show damage" setting.

## What it calls

ClassicAPI only: the combat log (`COMBAT_LOG_EVENT`,
`CombatLogGetCurrentEventInfo`, `CombatLogAddFilter`), animation groups,
`C_Spell.IsSpellReactiveReady`, `C_Spell.GetSpellCooldown`,
`C_Spell.GetSpellTexture`,
`GetPlayerInfoByGUID`, `C_ClassColor.GetClassColor`, `PLAYER_IN_COMBAT_CHANGED`,
`FACTION_STANDING_CHANGED`, `UNIT_POWER_UPDATE`, `RegisterUnitEvent`,
`C_Timer.After` and the Settings window. SuperWoW, NamPower and UnitXP are not
used.

The client has one combat log filter. BattleText sets it to you at login, so
the fights of others never reach any addon's `COMBAT_LOG_EVENT`. An addon that
needs every event listens to `COMBAT_LOG_EVENT_UNFILTERED`, which the filter
does not touch.

## Requirements

- World of Warcraft 1.12.1 (build 5875).
- [ClassicAPI](https://github.com/brues-code/ClassicAPI).

## Install or update

1. With WoW closed, download `BattleText.zip` from the
   [latest release](https://github.com/Fostercare5988/BattleText/releases/latest).
2. Extract it into `Interface/AddOns`, so the TOC is at
   `Interface/AddOns/BattleText/BattleText.toc`.
