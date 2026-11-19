---
title: Twist bar
parent: Features
nav_order: 11
description: For Retribution with Unsealed Wrath. Shows the seal copies your swings store, and when to swap seals.
---

# Twist bar

For Retribution paladins with **Unsealed Wrath**. The bar shows how many seal copies your swings have stored, and lights up just before the swing where you should swap seals.

{: .note }
> The twist bar is a best effort. Forever doesn't let addons read the combat log or your buffs during combat, so Lightbound counts your swings to know when to say `TWIST`, and that count can sometimes be one off. The three pips are drawn by the game itself and are always right: when the two disagree, trust the pips. See [Good to know](#good-to-know).

## How Unsealed Wrath works

Each melee swing stores a copy of your active seal for 15 seconds, up to 3. When a swing lands with a **different** seal, all stored copies are used, and each one gets that seal's normal chance to proc. The usual twist:

1. Swing three times with Seal of Command.
2. Swap to Seal of Righteousness as soon as the third copy is stored. The copies last 15 seconds, so there's no need to wait for the last moment. Wait too long and the fourth swing only refreshes the three copies, so the burst comes one swing later.
3. Swap back to Command after that swing and build again.

Judgement doesn't use up your seal, so you can judge at any time.

## What it shows

```
                      TWIST
 [Seal]  ■ ■ ■                     [Judgement] [Holy Strike]
 [■■■■■■■■■■■■■■  » Righteousness  ░░░░░░░░░░░]
```

- **Seal icon**: the seal you have up. Greyed out with `NO SEAL` on the bar when you have none.
- **Three pips**: the copies stored so far, in the colour of their seal. They're filled by the game itself from your Echo buff, so they show the real count, in combat too.
- **Swing bar**: fills toward your next main-hand swing.
- **TWIST**: as soon as you have three copies of your build seal, a large `TWIST` pulses above the bar, and the bar says `» Righteousness`.
- After you swap, the bar says `swing!` until the swing lands. Then it flashes, and `TWIST` pulses again with `» Command`, so you swap back.
- With the one-key macro below it's the same key both times.
- A short flash also shows when a seal procs from your stored copies.
- **Judgement and Holy Strike**: greyed out with a cooldown sweep while they're on cooldown.

The bar only shows in combat, and only if you have Unsealed Wrath.

## One key for both seals

```
#showtooltip
/castsequence reset=combat/target Seal of Command, Seal of Righteousness
```

Press it when `TWIST` shows. It casts the next seal in the sequence, starting over with Command after combat or when you change target.

## Settings

Page **Twist** in `/lb`.

![Twist options page]({{ '/screenshots/options-twist.png' | relative_url }})

| Setting | Default | What it does |
| --- | --- | --- |
| Show the twist bar | On | |
| Build with | Seal of Command | The seal you stack. |
| Swap to | Seal of Righteousness | The seal whose swing uses the stored copies. |
| Judgement and Holy Strike icons | On | |
| Sound when it's time to twist | Off | Once each time TWIST shows. |

## Good to know

**The pips are the real count, TWIST is counted.** Forever hides the Echo buffs (the stored copies) from addons in combat. The pips are drawn by the game from the buff, so they're always right, but Lightbound itself can't read them. For `TWIST` Lightbound counts your swings and seal casts. A swing that misses, or is dodged or parried, doesn't count. Lightbound sees that two ways: a swing that lands updates your Echo buff right away, and one that doesn't, doesn't. Your target also shows the miss, dodge or parry. If the count still drifts, the pips show the real number. Out of combat the count is checked against the real buffs.

**Move it** by unlocking frames (`/lb unlock`). It shows a sample while unlocked.

**Slow weapons make it easier.** You need time for two seal casts between swings (one global cooldown each), so a 3.3 second or slower two-hander leaves room to spare.
