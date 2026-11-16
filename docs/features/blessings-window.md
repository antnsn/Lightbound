---
title: Blessings window
parent: Features
nav_order: 2
description: The grid of paladins against classes that decides who blesses whom.
---

# Blessings window

One window decides which blessing every paladin gives every class, so paladins in a group stop overwriting each other's buffs.

## What it does

- One row per paladin in your group. Your row is first and highlighted.
- One column per class, then **Aura**, **Judgement** and **Cooldowns**.
- Your row is what the [buff key](buff-key.html) casts, solo, in a party and in a raid.
- Blessings you haven't learned yet show **red** in your row. The buff key skips them.
- Under each name: `you`, how many Symbols of Kings that paladin carries, `open` (anyone may change their row), `lead` (leader or assist), or `no addon` when that paladin runs neither Lightbound nor PallyPower.
- The **Cooldowns** column shows Lay on Hands, Divine Intervention and Blessing of Protection: `ok` when ready, otherwise the time left.
- Changes are sent to the other paladins in the group right away. Paladins using **PallyPower** see them too (see below).

## How to use it

1. Open the window with `/lb blessings`, a right-click on the minimap button, or the **Open blessings** button on the **Buff key** page of `/lb`.
2. **Left-click** a cell to step to the next blessing, **right-click** to step back. A dash (`-`) means nothing from that paladin.
3. To give one player a different blessing than the rest of their class, **Shift-click** the class cell. A list of that class's players opens. Click a name to step through blessings for that player, or back to "class blessing". The cell then shows a small `+1`, `+2`...
4. Click the **Aura** cell to set the aura that paladin keeps up.
5. Click the **Judgement** cell to set which Judgement that paladin keeps on the boss (see [Judgements](judgements.html)).
6. Close the window with the X or Esc.

![The Blessings window with several paladins]({{ '/screenshots/raid-blessings.png' | relative_url }})

### The buttons at the bottom

- **Auto-assign**: fills every row you are allowed to change, based on what each class wants. It looks at talents (Improved Blessing of Might and Wisdom) and spell ranks, picks the best paladin for each blessing, and does not double up on blessings from paladins you can't change. It also gives each of those paladins a different aura where it can. Salvation is never auto-assigned; set it by hand.
- **Refresh**: asks the other paladins for their rows again.
- **Others may assign me**: lets any paladin in the group change your row, not only the leader and assists.
- **Clear**: empties every row you can change. For most people that is only your own row; the leader and assists clear everyone.

The line at the very bottom tells you what you may change right now.

### Who can change what

| You are | You can change |
| --- | --- |
| Group leader or assist | Every row |
| Anyone else | Your own row, plus the rows of paladins who turned on **Others may assign me** |

When someone else changes your row, a line in chat tells you, for example "Uther assigned you Might on warriors."

## Settings

The window has no page in `/lb`. Its settings live in the window itself:

| Setting | Default | Where |
| --- | --- | --- |
| Others may assign me | Off | Footer of the Blessings window |
| On tanks | On | The line under your row (see [Tanks](tanks.html)) |

The line under your row is the **tank line**: what a tank gets from you instead of Salvation. It only shows under classes you give Salvation. See [Tanks](tanks.html).

Your own blessings on yourself are shown by the **My buffs** icons, see [Warnings and trackers](warnings-and-trackers.html#my-buffs).

## Good to know

**Can I change it in combat?**
Yes, the window works in combat, but the buff key only casts out of combat.

**Salvation shows up for other paladins even if they don't know it.**
PallyPower on Forever doesn't report whether a paladin knows Salvation, so it is always offered for other rows. For your own row Lightbound checks your spellbook.

**A paladin shows "no addon".**
That paladin runs neither Lightbound nor PallyPower, or hasn't answered yet. Try **Refresh**.

**Old rows of paladins you no longer play with** are forgotten after 30 days without seeing them. Your own characters are kept.

**Does it work with PallyPower?**
Yes.

- Lightbound speaks PallyPower's language. Paladins who still run PallyPower show up in your window, can assign you, and receive your assignments.
- Judgement assignments, the tank list and the Blessing of Protection cooldown are Lightbound only. PallyPower users don't see them.
- **While PallyPower itself is loaded**, Lightbound only reads PallyPower's assignments and sends nothing. The status line then says so. Disable PallyPower to let Lightbound take over.
- **Switching from PallyPower**: log in once with PallyPower still enabled. Lightbound copies your own assignments (once per character). Then disable PallyPower.

More on working with other paladins: [Playing in a raid](../raid.html).
