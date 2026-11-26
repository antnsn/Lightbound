---
title: Buff key
parent: Features
nav_order: 1
description: One key that casts Righteous Fury, your aura and every blessing your group needs.
---

# Buff key

Press one key, out of combat, and Lightbound casts the next buff that is missing: no hunting for party frames and no counting who still needs Might.

## What it does

- Each press casts **one** spell: the next thing that is needed.
- The order is always the same:
  1. **Righteous Fury** on yourself, if the Righteous Fury warning is showing.
  2. **Your aura**, if you have none up.
  3. **The blessings from your row in the [Blessings window](blessings-window.html)**, one group member at a time. You come first, then your party or raid.
- It skips players who are offline, dead, too far away or out of range.
- It also rebuffs a blessing that is about to run out (1 minute left by default).
- **Lower-level players get the rank they can take.** A blessing only goes on someone at most 10 levels below the rank's spell level, so a level 22 gets Blessing of Might rank 4, not rank 6. Someone too low for any rank you know (Blessing of Light starts at 40) is skipped, and `/lb why` says so.
- In a raid it uses the **Greater Blessing** when you know it and carry Symbol of Kings.
- A small bar shows what the next press will cast, for example `Might > Thrall [SHIFT-Q]`.
- `/lb why` prints, for every group member, what the key would do and why.

## How to use it

1. Type `/lb` and open the **Buff key** page.
2. Click the button next to **Key**, then press the key you want (for example Shift-Q). Esc cancels.
3. Click **Open blessings**. Your row is the highlighted one at the top.
4. Click the cells in your row to pick a blessing for each class. Left-click goes to the next blessing, right-click to the previous one. In a group with other paladins, **Auto-assign** can fill the rows for you.
5. Out of combat, press your key until the bar says nothing is left. Each press casts one buff.

{: .tip }
Solo, your own row decides what you get yourself: the **Paladin** column in your row is the blessing the key puts on you.

## Settings

In `/lb`, page **Buff key**:

| Setting | Default | What it does |
| --- | --- | --- |
| Buff the group with one key | On | Turns the key on or off. |
| Key | Not set | The key itself. **Clear** removes it. |
| Show what the next press will cast | On | The small bar with the next spell and target. |
| Cast Righteous Fury first if it's missing | On | Righteous Fury comes before everything else (only when the Righteous Fury warning would show). |
| Greater Blessings in raid | On | Uses Greater Blessings in raids. Needs the spell and Symbol of Kings in your bags. |
| Rebuff with time left | 1 min | A blessing with less time than this counts as missing. 0 to 4 minutes. |

The aura step has its own switch on the **Aura** page: **Cast the aura with the buff key** (on by default). See [Warnings and trackers](warnings-and-trackers.html#aura).

![The Buff key page in the options]({{ '/screenshots/options-buff-key.png' | relative_url }})

## Good to know

**Does it work in combat?**
No. The game does not let addons pick targets for you in combat, so the key does nothing until combat ends. Buff before the pull.

**The key says "everyone in range is buffed" but someone is missing a blessing.**
Run `/lb why`. Common reasons: that class has no blessing in your row, the player is out of range, or another paladin covers that class.

**It says a blessing "is in your row but not learned yet".**
Your row asks for a blessing you don't have yet (it shows red in the Blessings window). Pick another one for that class.

**Why does it bless one player instead of the whole class?**
Greater Blessings are only used in a raid, with Symbol of Kings in your bags, and only for a whole class. A player with their own blessing (set with Shift-click in the Blessings window) gets a normal blessing.

**Why did a tank get Kings instead of Salvation?**
That is the tank guard. See [Tanks](tanks.html).

**When combat hides buffs from addons**, the key goes by the time you last blessed that player, so it doesn't rebuff everyone after a fight.

**Where do I change who gets what?**
Only in the [Blessings window](blessings-window.html). The buff key page is just about the key.
