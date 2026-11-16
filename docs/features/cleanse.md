---
title: Cleanse
parent: Features
nav_order: 6
description: A grid of your group that shows who carries a debuff you can remove, plus a cleanse key.
---

# Cleanse

See at a glance who has a Poison, Disease or Magic debuff you can remove, and cleanse them with one click or one key, in combat too.

## What it does

- Uses **Cleanse** (removes Poison, Disease and Magic) or, before you learn it, **Purify** (Poison and Disease).
- **Grid** (the default): one small cell per group member, like Decursive. A cell lights up in the debuff's colour (green Poison, brown Disease, blue Magic) with its icon and stack count.
- **List**: one row per player who has something you can remove.
- **Click** a cell or row to cleanse that player.
- The **cleanse key** cleanses whoever is under your mouse: a grid cell, a list row, or any raid or party frame. With nothing under the mouse, it cleanses your target.
- Players out of range are dimmed. A sound plays when someone new needs a cleanse.
- An **ignore list** hides debuffs you don't want to see.

## How to use it

1. Type `/lb` and open the **Cleanse** page.
2. Under **Key**, click the button next to **Cleanse key** and press a key. Esc cancels.
3. Pick **Grid** or **List** under **Layout**.
4. In a fight, click a coloured cell, or hover over a player (in the grid or any raid frame) and press your cleanse key.
5. To hide a debuff you never want to cleanse, type `/lb ignore` followed by its full name, for example `/lb ignore Debuff Name`. The same command again removes it. `/lb ignore` on its own lists what you ignore.

<!-- screenshot needed: the cleanse grid in a party or raid with one or two coloured cells -->
![The Cleanse page in the options]({{ '/screenshots/options-cleanse.png' | relative_url }})

## Settings

In `/lb`, page **Cleanse**:

**Show**

| Setting | Default | What it does |
| --- | --- | --- |
| Show the cleanse frame | On | The grid or list. |
| Include pets | Off | Adds group pets (and your own pet). |
| Dim players out of range | On | |
| Sound when someone new needs it | On | |
| Show when solo | On | Just you, and your pet with pets on. Off: only in a group. |
| Names in grid cells | Off | Three letters of each name, from 26 px cells up. |

**Layout**

| Setting | Default | What it does |
| --- | --- | --- |
| Grid or list | Grid | Grid: a cell per group member that follows the roster in combat. List: a row per afflicted player. |
| Grid: cells per row | 5 | 1 to 10. |
| Grid: cell size | 22 px | 14 to 40 px. |
| List: rows | 5 | 1 to 10. |

**Key**

| Setting | Default | What it does |
| --- | --- | --- |
| Cleanse key | Not set | Cleanses the player under your mouse, else your target. Works in combat. |

The bottom of the page lists your ignored debuffs.

## Good to know

**Does it work in combat?**
Yes. Clicking cells and the cleanse key work in combat. The grid also follows players joining, leaving and moving between raid groups during a fight.

**Layout changes wait for the end of combat.**
Switching between grid and list, cell size, cells per row and pets change after combat. Lightbound tells you in chat.

**Combat hides debuff details on Forever.**
In the grid, the game itself draws the debuff colour and icon in each cell, so the grid keeps working in combat. The tooltip may say "Debuff details hidden right now". The **list** relies on what the addon can read, so in combat it can miss debuffs, and its rows can't be rearranged. It says `fixed in combat` when more players need a cleanse than it shows.

**The ignore list in combat.**
The list view always respects it. In the grid, an ignored debuff can still colour a cell in combat in some cases, because the game draws those cells. Debuff names are not case sensitive.

**Clicking a cell that isn't lit** still casts Cleanse on that player. That is on purpose: in combat the addon may not see a debuff the game hides.

**Paladins below Purify level** see no cleanse frame.
