---
title: Tanks
parent: Features
nav_order: 3
description: The tank guard keeps Blessing of Salvation off your tanks.
---

# Tanks

Blessing of Salvation lowers threat, which is the last thing a tank wants: the tank guard makes sure your tanks never get it from you.

## What it does

- When your row gives a class Salvation, a **tank** of that class gets another blessing from you instead. That class's other players still get Salvation.
- The replacement is set per class. By default warriors and druids get **Might**, every other class gets **Kings**. You can also pick Wisdom, Light, Sanctuary, or **None** (skip tanks of that class).
- The replacement is always a normal blessing, never a Greater one, so it doesn't overwrite the rest of the class.
- When a class has a tank in the group, Lightbound also holds back **Greater** Salvation for that class (it would land on the tank too). The others get single Salvations.
- It works for the buff key, the raid overview and blessing requests. A tank who whispers "salv pls" gets the replacement.

### Who counts as a tank

Any one of these is enough:

- the player is on the **tank list** (set by you, or shared by the group leader),
- the player is a raid **main tank** or **main assist**,
- the player has the **tank role**.

## How to use it

1. Mark your tanks. Either type `/lb tank Name`, or open `/lb`, page **Tanks**, and tick their names in the list. Typing `/lb tank Name` again removes them.
2. Open the Blessings window (`/lb blessings`). If your row gives any class Salvation, a **tank line** appears under your row with a cell under each of those classes.
3. Click a cell on the tank line to choose what a tank of that class gets instead (left-click next, right-click previous).
4. Leave **On tanks** ticked at the start of the tank line.

Type `/lb tank` with no name to list the tanks, plus anyone who counts as a tank for another reason (main tank, main assist, tank role).

![The Tanks page with the group list]({{ '/screenshots/options-tanks.png' | relative_url }})

## Settings

In `/lb`, page **Tanks**:

| Setting | Default | What it does |
| --- | --- | --- |
| Never Blessing of Salvation on a tank | On | The tank guard itself. Same switch as **On tanks** in the Blessings window. |
| Tanks in the group | Empty | Your group, with a tick box per player. Badges show who already counts as a tank (`main tank`, `main assist`, `tank role`). Names that left the group show as `not in group`. |
| Clear list | | Empties the tank list. |

In the Blessings window, on the tank line under your row:

| Setting | Default |
| --- | --- |
| On tanks | On |
| Replacement per class | Might for Warrior and Druid, Kings for the rest |

## Good to know

**I don't see a tank line.**
It only shows when your row gives Salvation to a class (to the whole class, or to one player of it). Otherwise it says "You give no Salvation, so tanks just get your row."

**Who shares the tank list?**
Only the **group leader** (not assists). Their list goes to every Lightbound paladin in the group and replaces the list there. If you are not the leader, your own changes only apply to you; the addon tells you so.

**Do I need to mark the main tanks?**
No. Raid main tanks, main assists and players with the tank role already count. Mark off-tanks and anyone else.

**Names stay on the list when people leave the group.** Remove them in the list or with **Clear list**.

**PallyPower users** don't know about the tank list. The tank guard only changes what you cast.
