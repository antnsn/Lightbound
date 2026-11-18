---
title: Cooldowns and Divine Intervention
parent: Features
nav_order: 7
description: Every paladin's big cooldowns, a Divine Intervention picker, and chat announcements for Divine Intervention and Redemption.
---

# Cooldowns and Divine Intervention

Know which paladin still has Blessing of Protection or Divine Shield, put Divine Intervention on the right healer in one click, and tell the group when you do.

## What it does

### Paladin cooldowns

- A frame titled **Paladin cooldowns**, one row per paladin in the group.
- Each row shows **Blessing of Protection**, **Blessing of Freedom**, **Blessing of Sacrifice**, **Divine Shield** and **Divine Protection**.
- Bright means ready. Dim with a number means on cooldown, with the time left.
- Your own row also shows **Forbearance** while it blocks Divine Shield and Blessing of Protection on you.
- Shared between Lightbound users. Paladins without Lightbound show `no sync`.

### Divine Intervention picker

- In raids, a short list of players titled **Divine Intervention**: healers first (priests, druids, shamans, paladins), then everyone else.
- **Click** a name to cast Divine Intervention on that player, **in combat too**.
- **Shift-click** a name (out of combat) to pin them as your preferred target. A pinned player sits at the top with a gold bar. Shift-click again to unpin.
- Dead players and players out of range are dimmed and marked `dead` or `far`.

### Announcements

- **Divine Intervention**: when your Divine Intervention goes off, Lightbound says "Divine Intervention on *name*!" in raid or party chat. As leader or assist in a raid it uses a raid warning.
- **Redemption**: as soon as you **start casting** Redemption, Lightbound says "Resurrecting *name*" in party or raid chat, so the player knows to wait for it. It can also whisper them "Resurrecting you".
- **Drinking**: when you sit down to drink in a group, Lightbound can say "Drinking (34% mana)" in party chat, so the group knows to wait. It says it once per drink. Off by default.

## How to use it

1. Join a group. The cooldowns frame appears on its own (it stays hidden when you are solo).
2. Learn Divine Intervention and join a raid. The picker appears on its own.
3. Before the pull, Shift-click your main healer in the picker to pin them.
4. When the wipe comes, click the healer's name. The cast is announced for you.
5. To move the frames, unlock them with `/lb move` (see [Quality of life](quality-of-life.html#moving-and-resizing-frames)).

<!-- screenshot needed: the Paladin cooldowns frame with two paladins (one cooldown running) and the Divine Intervention picker with a pinned healer -->

## Settings

In `/lb`, page **Cooldowns**:

| Setting | Default | What it does |
| --- | --- | --- |
| Show the cooldowns frame | On | The frame itself. |
| Only in raids | Off | Off: also in a party. |
| Include my own row | On | Your row, including Forbearance. |

In `/lb`, page **Announce**:

**Divine Intervention**

| Setting | Default | What it does |
| --- | --- | --- |
| Show the target picker in raids | On | The picker. |
| Also in parties | Off | Show the picker in a party too. |
| Picker rows | 6 | How many players the picker lists, 1 to 10. |
| Announce Divine Intervention in chat | On | |
| Use raid warning when you're leader or assist | On | |

**Redemption**

| Setting | Default | What it does |
| --- | --- | --- |
| Announce resurrections | On | "Resurrecting *name*" in party or raid chat when you start casting Redemption. |
| Also whisper the target | Off | Whispers "Resurrecting you" to the player. |

**Drinking**

| Setting | Default | What it does |
| --- | --- | --- |
| Say when you drink | Off | "Drinking (34% mana)" in party chat when you start drinking in a group. In a raid it goes to your own group. |

## Good to know

**Combat hides cooldown times on Forever.**
In combat your own row keeps the last known values. If you cast one of these spells in combat, Lightbound assumes its full cooldown started. The tooltip then says "assumed, hidden in combat". The real values are sent again when combat ends.

**The picker in combat.**
The names in each row stay where they were when combat started. Names, `dead` and `far` still update, but nobody moves up or down until the fight is over. Pinning only works out of combat.

**Chat is sometimes locked for addons** (for example during some boss fights). The announcement is then shown only on your own screen, with a note that only you see it.

**Recasting Redemption** on the same player right away is announced once, not twice.

**Divine Intervention needs Symbol of Divinity.** Lightbound can buy it for you, see [Quality of life](quality-of-life.html#reagents).

**The Blessings window** also shows Lay on Hands, Divine Intervention and Blessing of Protection in its Cooldowns column. See [Blessings window](blessings-window.html).
