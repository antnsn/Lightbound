---
title: Getting started
nav_order: 2
description: Install Lightbound and set it up in about two minutes.
---

# Getting started
{: .no_toc }

Two minutes from install to a paladin who buffs with one key.
{: .fs-6 .fw-300 }

1. TOC
{:toc}

---

## 1. Install it

Pick one:

- **CurseForge app or WowUp:** search for **Lightbound** and click Install.
- **By hand:** download it from [CurseForge](https://www.curseforge.com/wow/addons/lightbound) and unzip it into your `World of Warcraft\_forever_\Interface\AddOns` folder, so you get a folder called `Lightbound` there.

Start the game (or type `/reload` if it was already running) and log in on your paladin.

## 2. Open the options

Type `/lb` in chat, or click the Lightbound button on your minimap.

The options window has one page per feature on the left. Almost everything is on by default, so you mostly turn off what you don't want.

## 3. Pick your buff key

This is the one thing Lightbound can't choose for you.

1. In `/lb`, open the **Buff key** page.
2. Click the key button and press the key you want, for example a mouse button or a key next to your movement keys.
3. Out of combat, press it. Each press casts the next thing that's needed: Righteous Fury if it's missing, your aura, then your blessing on the next group member who is missing it.

![The Buff key page in the options]({{ '/screenshots/options-buff-key.png' | relative_url }})

{: .tip }
Not sure what the key will do next? Type `/lb why`. It explains, for each group member, what the key will cast and why.

## 4. Put the frames where you want them

Lightbound shows small icons and cards: reminders, procs, trackers.

1. Type `/lb move` (or Shift-click the minimap button) to unlock the frames.
2. Drag each frame where you want it. Scroll the mouse wheel over a frame to resize it.
3. Type `/lb move` again to lock them.

![Every Lightbound frame unlocked, ready to be moved]({{ '/screenshots/frames-unlocked.png' | relative_url }})

`/lb reset` puts every frame back where it started.

Using EllesmereUI, ElvUI or another flat UI? Pick the **Flat** look on the **Skin** page in `/lb`. See [Skins](features/skins.html).

## 5. In a group

When you join a group with other paladins, open the Blessings window with `/lb blessings`. Each paladin has a row; the cells say which blessing you give each class. The group leader and assists can set everyone's row, every paladin can set their own, and **Auto-assign** fills the grid for you.

Your buff key always follows your row. More in [Blessings window](features/blessings-window.html) and [Playing in a raid](raid.html).

## Coming from PallyPower

1. Log in once with PallyPower still enabled. Lightbound copies your assignments and stays quiet while PallyPower is loaded.
2. Disable PallyPower in the addon list and `/reload`.

The other paladins don't need to switch: those who still run PallyPower see you, can assign you, and get your assignments.

## That's it

Everything else works on its own. When you want to know what a warning means or change how something behaves, look it up under [Features](features/).
