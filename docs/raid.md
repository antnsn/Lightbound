---
title: Playing in a raid
nav_order: 4
description: How several paladins split blessings, auras, tanks and Judgements with Lightbound.
---

# Playing in a raid

With three or four paladins in a raid, someone has to decide who blesses which class. Lightbound puts that in one shared window, so every paladin's buff key casts its own part and nobody overwrites anyone.

## The short version

1. Every paladin opens the Blessings window: `/lb blessings`.
2. The raid leader (or an assist) clicks **Auto-assign**, or fills the rows by hand.
3. Everyone presses their [buff key](features/buff-key.html) out of combat. Each key casts only that paladin's row.

That's it. The rest of this page explains who may change what, and how the extras fit in.

## One row per paladin

The [Blessings window](features/blessings-window.html) has one row per paladin in the raid and one column per class. A cell is the blessing that paladin gives that class. In a raid, a paladin with Symbol of Kings casts the Greater Blessing on the whole class.

Each row also has:

- an **Aura** cell: the aura that paladin keeps up. In a raid where you have blessing assignments, the aura warning and the buff key follow this cell.
- a **Judgement** cell: the Judgement that paladin keeps on the boss (Lightbound users only).
- the paladin's **Cooldowns**: Lay on Hands, Divine Intervention and Blessing of Protection.

## Who may change what

| You are | You can change |
| --- | --- |
| Raid leader or assist | Every paladin's row |
| Any other paladin | Your own row |
| Any other paladin, for someone who ticked **Others may assign me** | That paladin's row too |

Tick **Others may assign me** at the bottom of the window if you don't mind other paladins setting your row. When someone changes your row, chat tells you who and what.

**Clear** empties only the rows you are allowed to change. For a normal paladin that is your own row. For the leader or an assist it is everyone.

## Auto-assign

**Auto-assign** fills every row you can change:

- It gives each class the blessings it wants most (Might for warriors and rogues, Wisdom for casters, Kings next, and so on).
- For each blessing it picks the paladin with the most talent points in it (Improved Blessing of Might or Wisdom), then the highest rank.
- It keeps the blessings of paladins you can't change and works around them.
- It gives each paladin a different aura where it can.
- It never assigns Salvation. Add Salvation by hand where you want it; the [tank guard](features/tanks.html) keeps it off the tanks.

Paladins who have not synced yet (`no addon` under their name) are left out. Press **Refresh** first if someone is missing.

## Tanks

- Raid main tanks, main assists and players with the tank role count as tanks without any setup.
- The **raid leader** can mark more tanks with `/lb tank Name` or on the **Tanks** page of `/lb`. The leader's list is shared with every Lightbound paladin in the raid. Lists from assists or other paladins stay on their own side.
- Each paladin decides on their own **tank line** (under their row in the Blessings window) what a tank gets instead of Salvation. By default Might for warriors and druids, Kings for the rest.
- When a class has a tank in it, Salvation for that class goes out as single blessings, so the tank isn't caught by a Greater Salvation.

More: [Tanks](features/tanks.html).

## Judgements

Set one Judgement per paladin in the **Judgement** column: Wisdom, Light, Crusader or Justice. In combat each paladin sees one icon per assigned Judgement on their target, and hears a sound when their own is missing. More: [Judgements](features/judgements.html).

## Mixing with PallyPower users

- Paladins who still run PallyPower show up in your window. You can assign them (if you are leader or assist, or they allow it), and they can assign you.
- They don't see Judgement assignments, the tank list or the shared cooldowns of Blessing of Protection, Freedom, Sacrifice, Divine Shield and Divine Protection. Those are Lightbound only.
- If **you** still have PallyPower loaded next to Lightbound, Lightbound only reads PallyPower's assignments and sends nothing. The window says so at the bottom. Disable PallyPower to let Lightbound do the syncing.

## Keeping everyone in sync

- Lightbound asks the other paladins for their rows when you join a group, when you log in or zone in a group, and every time you open the Blessings window.
- **Refresh** asks again by hand.
- Every change is sent to the group right away.
- During some boss fights the game stops addons from talking to each other for a while. Lightbound holds its updates and sends them when it can, instead of losing them.
- Only players in your group are listened to.

## Good to know

**Your row also matters solo.**
The buff key always casts your row, in a raid, in a party and alone. If the raid leader rearranged it, it stays that way until someone changes it again.

**A paladin shows `no addon`.**
They run neither Lightbound nor PallyPower, or haven't answered yet. Press **Refresh**, or ask them to install Lightbound.

**Rows of paladins you no longer play with** are forgotten after 30 days. Your own characters are kept.

**See who is missing what.**
The [raid overview](features/raid-overview-and-requests.html) lists every class you bless with how many are missing it. Click a row to bless that class.
