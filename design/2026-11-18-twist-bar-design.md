# Twist bar (Unsealed Wrath) — design

Approved by the user in chat, 2026-11-18. Bead: Lightbound-0or.

## Why
Retribution on Forever takes Unsealed Wrath (31-point talent): each melee swing stores a copy of the
active Seal for 15 s, up to 3. Landing a swing with a different Seal consumes all stacks, and each one
gets the stored Seal's proc chance. The twist (build 3 with Seal of Command, swap to Righteousness just
before the 4th swing, swap back) is hard to time by eye. The bar shows the rhythm.

## What the client lets us see (tested in game, /bk watch)
- `PLAYER_SWING(duration, swingType)` in combat, readable (3.3 s with a 3.3 weapon). Type 0 = main hand.
- `UNIT_SPELLCAST_SUCCEEDED` spell IDs in combat: Seal of Command cast 20918, Righteousness 20291,
  Judgement 20271, Holy Strike 5569. 20424 "Seal of Command" also fires right after a swing: the proc,
  not a cast (not in the spellbook).
- Echo buffs: Echo of Command 1311703, Echo of Righteousness 1311704 (applications = stacks, 15 s).
  Readable out of combat only; in combat the aura API refuses addons entirely.

## Approaches
1. **Twist bar** (picked): swing bar + counted stacks + swap window, plus Judgement/Holy Strike icons.
2. "Press this next" icon (Hekili style): has to guess too much with hidden values; a wrong guess teaches
   the wrong rhythm.
3. Both: bar first, icon later if the bar proves reliable.

## Design
- New module Twist.lua, counting logic in TwistLogic.lua (no WoW API, tested with plain Lua 5.1).
- Stacks are counted: a main-hand swing with seal S stores one of S (max 3, refreshed 15 s). A swing
  while stacks are of another seal consumes them (burst) and stores one of the current seal.
  15 s without a swing clears them. Out of combat the Echo auras correct the count.
  A swing whose target shows MISS/DODGE/PARRY (UNIT_COMBAT "target", same moment, tested in game) is taken back.
- Seal changes come only from spellbook seal casts (IsPlayerSpell); the 20424-style procs are ignored.
  The same check goes into SealTimer.lua, which today restarts its 30 s timer on every Command proc.
- Bar: seal icon, 3 pips (gold at 3), swing fill toward the next swing. At 3 stacks of the build seal,
  the last `twistWindow` seconds (default 0.4) before the swing light up "SWAP → Righteousness".
  After the burst swing: short flash and "→ Command" until you swap back. Command proc: small flash.
- Settings (own options page "Twist"): show (on), build seal (Command), burst seal (Righteousness),
  swap window 0.2–1.0 s, Judgement/Holy Strike icons (on), sound when the window opens (off).
- Shown in combat when Unsealed Wrath is known (or an Echo buff has been seen), movable, sample when
  frames are unlocked. Not shown for other paladins.
- Not in scope: Hammer of Wrath (target health in combat untested), "next button" icon.

## Left to the builder
Exact sizes and colours (use ns.UI tokens like the other frames), cooldown fallback lengths.
