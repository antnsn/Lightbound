# Lightbound changelog

## 4.4 (not released yet)

- New look for the reminders: aura, Righteous Fury, Well-Rested and Well Fed are cards built on the Lightbound emblem. The icon is a round medallion in a gold ring with the emblem's sunburst turning slowly behind it, on a dark panel with a double gilt rule. When a buff is gone the light fades and the icon greys.
- Exorcism and Hammer of Wrath use the game's own proc glow.
- Casting an aura in combat clears the aura card, even when combat hides the aura from addons.
- The cards stack above the proc and Judgement icons by default; frames you placed yourself stay put.

## 4.3.1

Fixes
- Request rows no longer cause "Interface action failed" when combat starts, and a row can't change your target mid-fight.
- Blessing requests only count short asks ("kings pls", "might?", "buff pls", "can i get kings"); "I might be late" is no longer a request.
- Tank lists: only the group leader shares the list, and an empty list no longer wipes everyone else's.
- Another paladin's aura on you no longer counts as yours, so the aura warning and the buff key work in groups with several paladins.
- No more false "WISDOM" low-mana reminder right after judging Wisdom; the trackers use the same per-mob Judgement tracking as the rest.
- Judgement: hidden ("restricted") debuff names and debuffs left out in combat fall back to your last Judgement instead of showing it as missing.
- Exorcism and Hammer of Wrath alerts go dark while the spell is on cooldown in combat.
- "NO SEAL" shows right at the pull, not seconds into the fight.
- No more false "Well Fed is gone" after a loading screen.
- The class overview uses the right blessing duration in combat and drops rows for players who died.
- `/lb why` no longer errors in combat.
- The buff key keeps working when you change "cast on key down", without a reload.
- The PallyPower import runs once per paladin instead of once per account.
- "Open blessings" always opens the window; closing the options only relocks frames it unlocked itself.
- The shift-click blessing popup has a close button and closes on Escape and when the roster changes.
- Reagent auto-buy keeps a little gold (1g or 10%, whichever is smaller) and checks bag space.
- Option notes no longer run into their labels.

Changes
- Divine Intervention and resurrection announcements are shown on your own screen when chat is locked for addons, instead of being lost.
- Sync messages wait while addon messages are locked (boss fights) instead of being dropped.
- Saved rows for paladins you haven't seen in 30 days are forgotten. Your own characters are kept.
- Tank lists from older versions are only accepted from the group leader. Paladins still on 4.3 may see a tank called "-" when the leader clears the list.

## 4.3

Blessings
- The Blessings window (`/lb blessings`, `/lb raid` still works) is the only place that decides who gets what, solo, in a party and in a raid. The Assignments setting and the Class blessings page are gone; your old class list is copied into your row once per paladin.
- Tank replacements for Salvation are set on a line under your row.
- Blessings you haven't learned show red in your row, and the buff key says when it skips one.

Frames
- Drag frames with live grid snapping (Shift places freely); a bar on the grid sets the size, toggles snapping and locks. `/lb grid [size]`.
- HUD frames no longer cover other windows.
- Well-Rested and Well Fed show as cards with a glow, and can keep following a buff after it's gone with a rebuff warning.

Judgements
- Which Judgement went out comes from the seal timer, so it works while combat hides your buffs.
- Tracked per mob and refreshed by your harmful spells on that target.

Fixes
- Seal timer: an expired seal could freeze the game for 1-2 seconds.

## 4.2

- Buff key Auto: saved group assignments only apply in raids; solo and in a party your own choices apply.

## 4.1

- Righteous Fury, aura and blessing icons cast their spell on click (out of combat).
- Mouse wheel resizes frames while unlocked; `/lb reset` clears sizes.
- Shift- or middle-click on the minimap button unlocks the frames.
- The cleanse grid shows when solo (option, on by default).

## 4.0

- New: cleanse grid and list, tank guard, Judgement assignments, paladin cooldowns, Divine Intervention picker, blessing requests, trackers (Reckoning, Consecration, Holy Shock, low-mana Wisdom reminder).

## 3.11

- The Exorcism alert works when the creature type is hidden.

## 3.10

- Fixed the Judgement fallback erroring in combat.

## 3.9

- Solid window backgrounds, fallback combat icons, screenshots.

## 3.8

- First release: one-key party and raid buffing with PallyPower-compatible assignments, warnings and trackers.
