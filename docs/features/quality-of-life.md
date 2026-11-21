---
title: Quality of life
parent: Features
nav_order: 9
description: Reagent shopping, the minimap button, Carrot on a Stick while mounted, and moving and resizing every frame.
---

# Quality of life

The small things: never run out of Symbols of Kings, open Lightbound from the minimap, and put every frame exactly where you want it.

## What it does

### Reagents

- When you open any vendor that sells them, Lightbound tops up **Symbol of Kings** (for Greater Blessings) and **Symbol of Divinity** (for Divine Intervention).
- It keeps a little gold back (1 gold or 10% of your money, whichever is smaller) and checks your bag space first.
- Symbol of Kings is only bought once you know a Greater Blessing, Symbol of Divinity once you know Divine Intervention.
- A chat warning tells you when your Symbols of Kings run low.

### Travel panel

Press Escape: beside the game menu sits your Hearthstone, with the inn it's set to. Click it to use it; the menu closes. The Hearthstone row only shows while you carry one, and the panel never shows in combat.

### Explanations in tooltips

Hover over a card or button and the tooltip explains what it does and why. Turn the explanations off with **Explain things in tooltips** on the **Skin** page, or `/lb explain`.

### Minimap button and addon menu

| Click | Does |
| --- | --- |
| Left-click | Opens the options (`/lb`). |
| Right-click | Opens the [Blessings window](blessings-window.html). |
| Shift-click or middle-click | Unlocks the frames (and locks them again). |
| Drag | Moves the button around the minimap. |

Where the game has an addon menu (the puzzle-piece button), Lightbound is listed there too, with the same clicks. The game's **Settings > AddOns** list also has a Lightbound entry with an **Open options** button.

### Carrot on a Stick

Turn it on and pick a trinket slot, and Lightbound puts Carrot on a Stick on when you mount and your own trinket back when you get off. It needs the carrot in your bags. It does nothing in instances, and in combat it waits until the fight is over, since the game blocks gear changes then. If you change that trinket yourself while riding, Lightbound leaves it alone.

### Moving and resizing frames

- Unlocking shows **every** Lightbound frame, with sample content, so you can place frames that are normally hidden.
- Drag a frame to move it. Frames snap to a grid around the centre of your screen. Hold **Shift** while dragging to place a frame freely.
- Scroll the **mouse wheel** over a frame to make it bigger or smaller (50% to 250%).
- While unlocked, a small bar at the top of the screen sets the grid size (**-** and **+**, or the mouse wheel; hold Shift for 1 pixel steps), turns **Snap** on or off, and has a **Lock** button.
- **Reset positions** puts every frame back in its default place and size.

## How to use it

**Reagents**

1. Open `/lb`, page **Reagents**. Check that **Buy reagents at vendors automatically** is ticked.
2. Set how many of each symbol you want to carry.
3. Talk to any reagent vendor. Lightbound buys what's missing and says so in chat.

**Moving frames**

1. Type `/lb move`, Shift-click the minimap button, or click **Unlock frames** at the bottom of the `/lb` window.
2. Drag frames into place. Scroll on a frame to resize it.
3. Click **Lock** on the bar at the top, or type `/lb move` again.
4. Made a mess? `/lb reset` (or **Reset positions** in `/lb`) puts everything back.

![Frames unlocked, with the grid]({{ '/screenshots/frames-unlocked.png' | relative_url }})

## Settings

In `/lb`, page **Reagents**:

![Reagents options page]({{ '/screenshots/options-reagents.png' | relative_url }})

| Setting | Default | What it does |
| --- | --- | --- |
| Buy reagents at vendors automatically | On | |
| Keep Symbol of Kings | 100 | How many to carry, 0 to 200. 0 turns buying it off. |
| Keep Symbol of Divinity | 5 | How many to carry, 0 to 20. 0 turns buying it off. |
| Warn below (Symbol of Kings) | 20 | Chat warning below this many, 0 to 100. 0 turns the warning off. |

In `/lb`, page **Extras**:

| Setting | Default | What it does |
| --- | --- | --- |
| Minimap button (left-click options, right-click blessings) | On | Shows or hides the minimap button. Also `/lb minimap`. |
| Wear it while mounted (Carrot on a Stick) | Off | Off, Top trinket or Bottom trinket: the slot the carrot goes into when you mount. Your own trinket goes back on when you get off; an empty slot is emptied again (the carrot goes into a bag). |

The grid has no options page. Change it on the bar shown while frames are unlocked, or with `/lb grid`:

| Command | Does |
| --- | --- |
| `/lb grid` | Turns snapping on or off (on by default). |
| `/lb grid 30` | Sets the grid size (4 to 100, default 20) and turns snapping on. |

## Good to know

**Not in combat.**
Unlocking, locking, moving, resizing and resetting frames all wait until you leave combat.

**Closing the options window** locks the frames again, but only if you unlocked them with the options' own button. Frames unlocked with `/lb move` stay unlocked until you lock them.

**"Not enough money" or "no bag space" in chat** means Lightbound bought less than you asked for, or nothing. Make room or bring gold.

**The Blessings window and the options window** are moved by dragging their title bar, not with unlock.
