---
title: Judgements
parent: Features
nav_order: 4
description: Judgement assignments shared between paladins, and icons that show them on your target in combat.
---

# Judgements

Agree on who keeps which Judgement on the boss, and see in combat at a glance whether yours is up.

## What it does

- Each paladin can be given one Judgement to keep on the boss: **Wisdom**, **Light**, **Crusader** or **Justice** (or **None**).
- Assignments are set in the **Judgement** column of the [Blessings window](blessings-window.html) and shared with the other Lightbound paladins in the group.
- In combat, with a hostile target, a small row of icons shows one icon per assigned Judgement:
  - **bright, with seconds left**: that Judgement is on your target,
  - **grey, with the paladin's name**: it is missing. The name is red when it's yours, yellow for someone else's,
  - **`?`**: the game hides your target's debuffs right now, so Lightbound can't tell.
- A sound plays when **your** Judgement is missing, at most every 10 seconds.

This is separate from the single **Judgement icon** on the Combat page, which shows your own Judgement on the target whether or not anyone assigned it. See [Warnings and trackers](warnings-and-trackers.html#combat-alerts).

## How to use it

1. Open the Blessings window with `/lb blessings`.
2. Click the **Judgement** cell in a paladin's row (left-click next, right-click previous). The same rules apply as for blessings: the leader and assists can set anyone, everyone else their own row.
3. Or set only your own: `/lb`, page **Judgements**, **My Judgement**.
4. In combat, target the boss. The icons appear on their own.

<!-- screenshot needed: the Judgement assignment icons in combat on a boss, one bright with seconds, one grey with a paladin's name -->

## Settings

In `/lb`, page **Judgements**:

![Judgements options page]({{ '/screenshots/options-judgements.png' | relative_url }})

| Setting | Default | What it does |
| --- | --- | --- |
| Track the raid's Judgements on my target | On | The row of icons in combat. |
| Play a sound when my Judgement is missing | On | At most every 10 seconds. |
| Only show my own Judgement | Off | Hide the other paladins' icons. |
| My Judgement | None | Your own assignment. The same as your cell in the Blessings window. |

## Good to know

**When do the icons show?**
Only in combat, with a living hostile target, and only when at least one paladin in the group has a Judgement assigned. To see them while placing frames, unlock the frames (`/lb move`).

**Combat hides debuffs on Forever.**
When none of the target's debuffs can be read, every icon shows `?` instead of guessing. When only some are hidden, your own icon goes by your last Judgement on that mob.

**Only Lightbound users see Judgement assignments.**
PallyPower doesn't know about them. When you point at a Judgement cell of a paladin without Lightbound, the tooltip says so.

**Does this cast anything?**
No. It only shows. You still judge yourself.
