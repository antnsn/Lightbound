---
title: Twist bar
parent: Features
nav_order: 11
description: For Retribution with Unsealed Wrath. Shows the seal copies your swings store, and when to swap seals.
---

# Twist bar

For Retribution paladins with **Unsealed Wrath**. The bar shows how many seal copies your swings have stored, and lights up just before the swing where you should swap seals.

## How Unsealed Wrath works

Each melee swing stores a copy of your active seal for 15 seconds, up to 3. When a swing lands with a **different** seal, all stored copies are used, and each one gets that seal's normal chance to proc. The usual twist:

1. Swing three times with Seal of Command.
2. Swap to Seal of Righteousness just before the fourth swing.
3. Swap back to Command after that swing and build again.

Judgement doesn't use up your seal, so you can judge at any time.

## What it shows

```
 [Seal]  ■ ■ ■                     [Judgement] [Holy Strike]
 [■■■■■■■■■■■■■■■■■■■■■■|SWAP » Righteousness|]
```

- **Seal icon**: the seal you have up. Greyed out with `NO SEAL` on the bar when you have none.
- **Three pips**: the copies stored so far, in the colour of their seal. They're filled by the game itself from your Echo buff, so they show the real count, in combat too.
- **Swing bar**: fills toward your next main-hand swing.
- **Swap window**: with three stored copies of your build seal, the end of the bar is marked. In the last moment before the swing (0.4 seconds by default) it turns bright and says `SWAP » Righteousness`.
- After you swap, the bar says `swing!` until the swing lands. Then it flashes and says `» Command`, so you swap back.
- A short flash also shows when a seal procs from your stored copies.
- **Judgement and Holy Strike**: greyed out with a cooldown sweep while they're on cooldown.

The bar only shows in combat, and only if you have Unsealed Wrath.

## Settings

Page **Twist** in `/lb`.

| Setting | Default | What it does |
| --- | --- | --- |
| Show the twist bar | On | |
| Build with | Seal of Command | The seal you stack. |
| Swap to | Seal of Righteousness | The seal whose swing uses the stored copies. |
| Swap window | 400 ms | How long before the swing the bar says swap. Raise it if your latency is high. |
| Judgement and Holy Strike icons | On | |
| Sound when the swap window opens | Off | |

## Good to know

**The pips are the real count, the swap advice is counted.** Forever hides the Echo buffs (the stored copies) from addons in combat. The pips are drawn by the game from the buff, so they're always right, but Lightbound itself can't read them. For the `SWAP` advice Lightbound counts your swings and seal casts. A swing your **target** dodges, parries or that misses doesn't count. Lightbound only sees that on your target, in the same moment as your swing. So if you hit a mob you don't have targeted, every swing counts. And in a group, someone else's attack being dodged at exactly the moment of your swing can, rarely, take one away. Out of combat the count is checked against the real buffs.

**Move it** by unlocking frames (`/lb unlock`). It shows a sample while unlocked.

**Slow weapons make it easier.** With a 3.3 second or slower two-hander the swap window is easier to hit.
