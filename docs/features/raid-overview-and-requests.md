---
title: Raid overview and requests
parent: Features
nav_order: 5
description: See which classes are missing your blessing, and bless players who ask for one in chat.
---

# Raid overview and requests

Two small frames that answer "who still needs my blessing?": one counts it per class, the other catches players who ask in chat.

## What it does

### Raid overview

- One row per class you bless, in the frame titled **Blessings**.
- Each row shows the class and either how many players are missing your blessing (red, for example `2/5 missing`), or the shortest time left (gold when it's running low, green when it's fine).
- The title shows how many Symbols of Kings you carry. It turns red when you are below your reagent warning.
- Click a row to bless that class. In a raid that is the Greater Blessing on the whole class (needs Symbol of Kings). Otherwise it blesses the next player of that class who needs it and is in range.

### Blessing requests

- When someone whispers a short request like "kings pls", "bom" or "buff?", a row appears in the **Blessing requests** frame with their name and the blessing.
- Click the row to bless them.
- The row goes away once they have the blessing, when your cast lands, or after a minute.

## How to use it

**Raid overview**

1. Join a raid. The frame shows up on its own when you have blessings in your row.
2. Look for red rows (someone is missing it) and gold rows (running out soon).
3. Out of combat, click a row to bless that class.

**Requests**

1. Nothing to set up. When a group member whispers you a request, a row appears and a sound plays.
2. Out of combat, click the row.

These words count as a request:

| They type | They get |
| --- | --- |
| kings, bok | Blessing of Kings |
| might, bom | Blessing of Might |
| wisdom, wis, bow | Blessing of Wisdom |
| salvation, salv, bos | Blessing of Salvation |
| light, bol | Blessing of Light |
| sanctuary, sanc, sanct | Blessing of Sanctuary |
| buff, bless, blessing | The blessing your row gives their class. If your row has none for them: Kings if you know it, else Might. |

The message must be short: just the blessing ("kings", "might?", "bom me"), or the blessing plus a clear ask ("kings pls", "can i get wis"). Normal chat like "I might be late" is ignored.

![Raid overview options page]({{ '/screenshots/options-raid-overview.png' | relative_url }})

<!-- screenshot needed: the Blessing requests frame with two or three rows -->

## Settings

In `/lb`, page **Raid overview**:

| Setting | Default | What it does |
| --- | --- | --- |
| Show the overview | On | The frame itself. |
| Only in raids | On | Off: also in a party. |

In `/lb`, page **Requests**:

![Requests options page]({{ '/screenshots/options-requests.png' | relative_url }})

| Setting | Default | What it does |
| --- | --- | --- |
| Show blessing requests | On | Turns requests on or off. |
| Also read party, raid and say | Off | Off: whispers only. |
| Only from people in your group | On | Off: whispers from anyone count. Clicking then targets them by name first. |
| Sound on a new request | On | |
| Requests disappear after | 60 s | 15 to 180 seconds. |
| Rows | 4 | 1 to 8. When the frame is full, the oldest request makes room. |

## Good to know

**Clicks only work out of combat.**
In combat the rows stay visible but do nothing. Request rows say `after combat`. If a request comes in during combat and the frame isn't up yet, a line in chat tells you instead.

**A row says "not known".**
They asked for a blessing you haven't learned. You can't cast it.

**A tank asks for Salvation.**
The [tank guard](tanks.html) still applies: you cast the tank's replacement blessing instead, or nothing if it's set to None.

**The tooltip of an overview row says "Nobody in range needs it".**
Either everyone has it, or the players who need it are out of range or out of sight. Clicking does nothing then.

**Combat hides buffs on Forever.**
When the overview can't read a player's buffs, it goes by the time you last blessed them.
