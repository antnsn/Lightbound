---
title: Skins
parent: Features
nav_order: 10
description: Pick how Lightbound looks, Lightbound gold, classic Blizzard or flat, to match the rest of your UI.
---

# Skins

Lightbound comes in three looks. They all work the same way, only the frames look different, so you can match the rest of your UI.

## The three skins

| Skin | Looks like | Good with |
|:--|:--|:--|
| **Lightbound** (default) | Warm gold frames, reminder cards on the Lightbound emblem with a slow sunburst behind the icon. | The default UI, or if you just like the paladin look. |
| **Blizzard** | The game's own grey and silver tooltips and dialogs, white text, the classic buttons and check boxes. | A mostly default UI where gold would stand out. |
| **Flat** | Thin black edges on dark grey, Arial Narrow text, square icons. Gold stays as the one accent. | EllesmereUI, ElvUI and other flat UI packs. |

## How to switch

![Skin options page]({{ '/screenshots/options-skin.png' | relative_url }})

1. Type `/lb` and open the **Skin** page.
2. Click the **Skin** button to step through the skins (right-click goes back).
3. Click **Reload now**, or type `/reload` later. The new skin shows after the reload.

The skin is saved with your other Lightbound settings.

## What changes, and what doesn't

A skin changes the frames: colours, borders, fonts, buttons and check boxes in the options window, the reminder cards and the icons.

Colours that tell you something stay the same in every skin:
- red for anything missing or about to run out,
- the debuff type colours in the [Cleanse](cleanse.html) grid (green Poison, brown Disease, blue Magic),
- class colours on player names,
- the game's own spinning glow on Exorcism and Hammer of Wrath when they light up.

## Things to know

**Why does it need a reload?**
Lightbound builds its frames once, when you log in. Switching in the middle of a session would leave some frames in the old look and some in the new one, so the switch waits for the next reload.

**Does Flat take its colours from EllesmereUI or ElvUI?**
Not yet. Flat uses its own dark grey and gold for now.
