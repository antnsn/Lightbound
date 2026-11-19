---
title: Warnings and trackers
parent: Features
nav_order: 8
description: Reminders for Righteous Fury, your aura, your seal and your own blessings, combat alerts, the trackers row, and Well-Rested and Well Fed.
---

# Warnings and trackers

Small reminders for everything a paladin forgets mid-dungeon: a missing Righteous Fury or aura, an empty seal, a Judgement that fell off, a Hammer of Wrath you could be casting.

## What it does

### Righteous Fury

- A card titled **Righteous Fury** with "Not active, click to cast" and a sound, when you are in a group without Righteous Fury.
- It warns in dungeons. Outside instances and in raids it warns too, unless you turn that off.
- It stays quiet while you rest in a city or inn, are dead, or are on a flight.

### Aura

- A card with the aura you should have, when you have **no aura** up ("Not active, click to cast").
- Optionally also when **the wrong aura** is up ("Retribution Aura is up instead").
- The aura it asks for is the one you pick on the **Aura** page. In a raid where you have blessing assignments, the aura set for you in the [Blessings window](blessings-window.html) wins. If you haven't learned the chosen aura yet, it falls back to any aura you know.
- Another paladin's aura on you doesn't count as yours.
- It stays quiet while you rest in a city or inn.

### Seal timer

- A vertical bar that empties while your seal runs out, coloured by the seal, with the seal's icon on top and the seconds below. The seconds turn red in the last 5.
- In combat with no seal up, an empty bar says **NO SEAL**.
- Only a seal you cast starts the timer again. A Seal of Command proc doesn't.

### My buffs

- A row of icons for the blessings you want on **yourself**, with the time left under each.
- A missing blessing is grey with a red border and its name in red. One that is running low gets a gold border.

### Combat alerts

- **HAMMER**: a big Hammer of Wrath icon with the game's proc glow and a sound, when your target is below 20% and Hammer of Wrath is ready.
- **EXORCISM**: the same for Exorcism, when your target is undead or a demon and Exorcism is ready. It works even when Forever hides the creature type.
- **Judgement icon**: your Judgement on the target, with its name and the seconds left. In combat, when your target has no Judgement from you, a dim **Judge** icon reminds you.

![Your Judgement of the Crusader on the target, 9 seconds left]({{ '/screenshots/judgements-combat-light.png' | relative_url }})
![No Judgement from you on the target: the dim Judge reminder]({{ '/screenshots/judgements-combat-gray.png' | relative_url }})

### Trackers row

One row of small icons, each with its own switch. Icons that don't apply right now are left out and the rest close up.

- **RECKONING**: your Reckoning stacks. The number turns gold at 4.
- **CONSECRATE**: an 8 second countdown from your Consecration cast. Dim while Consecration is still on cooldown.
- **SHOCK**: Holy Shock's cooldown. Bright when it's ready.
- **WISDOM**: in combat, when your mana drops below the limit (30% by default) and your target has no Judgement of Wisdom from you.

### Well-Rested and Well Fed

- A warning on screen, in chat and with a sound when **Well-Rested** (the Cozy Sleeping Bag buff) or **Well Fed** is about to run out. On Forever, Well Fed also gives more experience.
- After the warning, a card counts down the time left.
- Well Fed also tells you when it is gone.
- Optionally, a card stays up after the buff is gone ("Buff has run out"), with one rebuff warning.

## How to use it

1. Most of this works right after you install. Type `/lb` to change anything.
2. Each warning has its own page in `/lb`: **Righteous Fury**, **Aura**, **Seal timer**, **Combat**, **My buffs**, **Trackers**, and **Extras** for Well-Rested and Well Fed.
3. Set the aura you want on the **Aura** page, under **My aura**.
4. On the **My buffs** page, tick the blessings you want to see on yourself.
5. **Click** the Righteous Fury card, the aura card or a My buffs icon to cast that spell (out of combat).
6. To move or resize any of these, unlock the frames with `/lb move`. See [Quality of life](quality-of-life.html#moving-and-resizing-frames).

![Every Lightbound frame unlocked: reminder cards, proc icons, seal bar and trackers]({{ '/screenshots/frames-unlocked.png' | relative_url }})

## Settings

### Righteous Fury page

![Righteous Fury options page]({{ '/screenshots/options-righteous-fury.png' | relative_url }})

| Setting | Default | What it does |
| --- | --- | --- |
| Warn when Righteous Fury is missing | On | The warning itself. |
| Also in party outside instances | On | Also in the open world. Not while resting in a city or inn. |
| Also in raids | On | |
| Play a warning sound | On | |

### Aura page

![Aura options page]({{ '/screenshots/options-aura.png' | relative_url }})

| Setting | Default | What it does |
| --- | --- | --- |
| Warn when no aura is up | On | |
| Also warn when it isn't the assigned aura | Off | Also warns when another aura than the wanted one is up. |
| Only when in a group | Off | |
| Cast the aura with the buff key | On | The [buff key](buff-key.html) casts the aura before blessings. |
| My aura | Devotion | The aura you want. The text next to it shows which one is used right now. |

### Seal timer page

![Seal timer options page]({{ '/screenshots/options-seal-timer.png' | relative_url }})

| Setting | Default | What it does |
| --- | --- | --- |
| Show the seal timer | On | |
| Show an empty bar in combat | On | The **NO SEAL** reminder. |
| Bar height | 220 px | 60 to 600 px. |
| Bar width | 22 px | 10 to 60 px. |

### Combat page

![Combat options page]({{ '/screenshots/options-combat.png' | relative_url }})

| Setting | Default | What it does |
| --- | --- | --- |
| Hammer of Wrath and Exorcism alert | On | Only when the spell is off cooldown. |
| Play a sound when it shows | On | |
| Show your Judgement on the target | On | Icon with seconds left. |
| Remind me when it's missing | On | The dim **Judge** icon in combat. |

### My buffs page

| Setting | Default | What it does |
| --- | --- | --- |
| Show my blessings | On | |
| Track: Might, Wisdom, Kings, Salvation, Light, Sanctuary | Might and Kings on | Which blessings get an icon. |
| Only show missing or nearly expired blessings | Off | |
| Only when in a group | Off | |
| Hide in cities and inns | On | |
| Nearly expired at | 1 min | 1 to 10 minutes. |

![The My buffs page in the options]({{ '/screenshots/options-my-buffs.png' | relative_url }})

### Trackers page

| Setting | Default | What it does |
| --- | --- | --- |
| Show the trackers | On | The whole row. |
| Reckoning: Stack count | On | |
| Reckoning: Sound at 4 stacks | Off | |
| Consecration: 8 second countdown from your cast | On | |
| Holy Shock: Cooldown | On | |
| Holy Shock: Sound when ready in combat | Off | |
| Low mana: Judgement of Wisdom reminder | On | |
| Low mana: Sound once per fight | On | |
| Remind below | 30 % mana | 10 to 60 %. |

![The Trackers page in the options]({{ '/screenshots/options-trackers.png' | relative_url }})

### Extras page (Well-Rested and Well Fed)

Each of the two has the same block, with a **Test** button that shows the warning:

| Setting | Default | What it does |
| --- | --- | --- |
| Warn | On | The warning before it runs out. |
| Sound | On | |
| Countdown icon | On | The card that counts down after the warning. |
| Keep following it after it's gone (rebuff warning) | Off | A "Buff has run out" card and one rebuff warning. |
| Warn with time left | 5 min (Well-Rested), 3 min (Well Fed) | 1 to 30 minutes. |

![The Extras page in the options]({{ '/screenshots/options-extras.png' | relative_url }})

## Good to know

**Forever hides buffs from addons in combat.**
Lightbound keeps the last thing it knew instead of raising a false alarm. Your seal is followed from the moment you cast it. Your aura counts as up once you cast it, even when combat hides it. Your Judgement is followed from your last Judgement on that mob for its usual length.

**Clicking a card does nothing in combat.**
Click-to-cast only works out of combat. The warnings themselves still show.

**Not tanking?**
The Righteous Fury warning shows in every group by default. Turn off **Warn when Righteous Fury is missing**, or type `/lb toggle`.

**The seal bar restarts only on a new seal.**
Judging doesn't restart it.

**Why don't I see the WISDOM reminder?**
It needs Judgement and Seal of Wisdom learned, combat, a hostile target, and mana below the limit. It disappears once your Judgement of Wisdom is on the target.

**The Well Fed card only appears after the warning.**
Before that, nothing shows. Use **Test** to see the warning.

**Quick toggles in chat:** `/lb toggle` (Righteous Fury warning), `/lb seal`, `/lb rested`, `/lb fed`. All commands: [Commands](../commands.html).
