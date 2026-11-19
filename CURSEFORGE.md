# Lightbound

**The all-in-one paladin addon for World of Warcraft: Forever.**

Lightbound buffs your party and raid with a single key, sorts out who blesses which class with the other paladins, and reminds you about everything a paladin forgets. It replaces PallyPower and stays compatible with it: paladins who still run PallyPower see you, can assign you, and get your assignments.

**Full guide with screenshots: https://antnsn.github.io/Lightbound/**

## What's new in 4.6
- **Twist bar** for Retribution with Unsealed Wrath: three pips with your real Echo stacks (drawn by the game, in combat too), a swing bar, and a pulsing TWIST when it's time to swap seals, and again when it's time to swap back. Judgement and Holy Strike icons alongside.
- **Blessings window: Players tab.** One line per player: give one player their own blessing, and mark tanks right there.
- **Carrot on a Stick** goes on when you mount and your trinket comes back when you get off (off by default).
- **"Drinking"** in party chat when you sit down to drink, by default only in dungeons and raids (off by default).
- The seal timer no longer restarts on a Seal of Command proc.

Every version's changes are in the changelog on the Files tab.

## Buffing
- **One buff key.** Out of combat, each press casts the next thing that's needed: Righteous Fury, your aura, then the blessing from your row in the Blessings window on the next group member who is missing it or about to lose it. It uses Greater Blessings in raids when you have Symbol of Kings, and checks range for you.
- **Blessings window (`/lb blessings`).** The one place that decides who gets what: a grid of paladins against classes, plus aura, Judgement and cooldowns (Lay on Hands, Divine Intervention, Blessing of Protection).
  - Click a cell to change it.
  - Shift-click to set blessings for individual players.
  - Auto-assign takes talents (Improved Might/Wisdom) and ranks into account.
  - The leader and assists can edit everyone, and other paladins can edit their own row.
  - The **Players** tab lists every player: give one of them their own blessing, or mark them as a tank.
- **Tank guard.** Never Blessing of Salvation on a tank. Marked tanks, raid main tanks and assists get another blessing instead (Might for warriors and druids, Kings otherwise, per class, set under your row in the Blessings window). The group leader's tank list is shared with the other Lightbound paladins.
- **Judgement assignments.** Who keeps Wisdom, Light, Crusader or Justice on the boss. Set in the Blessings window and shared with the other paladins. In combat, one icon per assigned Judgement shows whether it's on your target, with a sound when yours is missing.
- **Raid overview.** Every class you bless, with how many are missing it and the shortest time left. Click a row to bless the whole class.
- **Blessing requests.** When someone whispers a short request like "kings pls", "bom" or "buff?", a row with their name appears. Click it to bless them.

## Cleanse, cooldowns and Divine Intervention
- **Cleanse grid.** Decursive-style: one small cell per group member (and pet), coloured and iconed when they carry a Poison, Disease or Magic debuff you can remove. Click a cell to cleanse. Cells follow joins and leaves even in combat. Out-of-range players are dimmed. Switch to a list of afflicted units if you prefer. A cleanse key casts on the unit under your mouse (a cell, the list, any raid frame) or your target, in combat too.
- **Paladin cooldowns.** Every paladin's Blessing of Protection, Freedom and Sacrifice, Divine Shield and Divine Protection, plus your own Forbearance. Shared between Lightbound users.
- **Divine Intervention picker.** In raids, a short list of healers. Click one to cast Divine Intervention on them, in combat too. Shift-click pins a preferred target. The cast is announced in raid chat.
- **Resurrection announce.** "Resurrecting <name>" in party or raid chat when you start casting Redemption.
- **Drinking announce.** "Drinking" in party chat when you sit down to drink (optional, dungeons and raids only by default).

## Retribution: twist bar
For Unsealed Wrath. Each swing stores a copy of your seal, up to three, and a swing with another seal uses them all. The bar shows the stored copies (drawn by the game from your Echo buff, so always right), a swing timer, and a pulsing **TWIST** when it's time to swap seals and to swap back. Judgement and Holy Strike cooldowns sit next to it. One-key macro on the wiki.

Best effort: Forever doesn't let addons read the combat log or your buffs in combat, so the TWIST call comes from counting your swings and can be one off. The pips are always right.

## Warnings and trackers
- Righteous Fury missing while grouped
- Missing aura, or the wrong aura
- Seal timer bar
- Your own blessings, with time left
- **Hammer of Wrath alert.** Big icon and sound the moment the target drops under 20% and the spell is ready.
- **Exorcism alert.** Big icon and sound when your target is undead or a demon and Exorcism is ready. Works even when Forever hides the creature type.
- Your **Judgement** on the target, plus a reminder when it's missing in combat
- **Trackers row:** Reckoning stacks (gold at 4), Consecration countdown, Holy Shock cooldown, and a Judgement of Wisdom reminder when your mana runs low
- **Well-Rested** and **Well Fed** warnings before they run out, so you keep the levelling bonuses on Forever

## Look
- **Skins:** Lightbound (gold, the default), Blizzard (the game's own grey and silver frames) or Flat (thin black edges on dark grey, next to EllesmereUI or ElvUI).
- The aura, Righteous Fury, Well-Rested and Well Fed reminders are cards built on the Lightbound emblem. Hammer of Wrath and Exorcism use the game's own proc glow.

## Quality of life
- Loads only on paladins: on your other characters it does nothing and switches itself off for them
- **Carrot on a Stick** in a trinket slot of your choice while mounted, outside instances
- Buys Symbol of Kings and Symbol of Divinity automatically at vendors (keeping a little gold and checking bag space), and warns when you run low
- Click the Righteous Fury, aura or blessing icons to cast that spell (out of combat)
- Classic WoW-style options window (`/lb`), minimap button and addon compartment entry; shift-click the minimap button to unlock the frames
- Every frame can be moved, snapped to a grid, and resized with the mouse wheel while unlocked

## Commands
- `/lb` options
- `/lb blessings` (or `/lb raid`) blessings window
- `/lb grid [size]` grid snapping
- `/lb why` explains what the buff key will do for each group member
- `/lb tank <name>` marks or unmarks a tank
- `/lb ignore <debuff>` hides a debuff from the cleanse list
- `/lb move`, `/lb reset` unlock or reset frames

## Switching from PallyPower
Log in once with PallyPower still enabled. Lightbound copies your assignments and stays quiet while PallyPower is loaded. Then disable PallyPower.

Source and issues: https://github.com/antnsn/Lightbound
