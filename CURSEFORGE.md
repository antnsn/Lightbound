# Lightbound

**The all-in-one paladin addon for World of Warcraft: Forever.**

Lightbound buffs your party and raid with a single key, sorts out who blesses which class with the other paladins, and reminds you about everything a paladin forgets. It replaces PallyPower and stays compatible with it: paladins who still run PallyPower see you, can assign you, and get your assignments.

## Buffing
- **One buff key.** Out of combat, each press casts the next thing that's needed: Righteous Fury, your aura, then the assigned blessing on the next group member who is missing it or about to lose it. It uses Greater Blessings in raids when you have Symbol of Kings, and checks range for you.
- **Raid blessings window (`/lb raid`).** A grid of paladins against classes, plus aura, Judgement and cooldowns (Lay on Hands, Divine Intervention, Blessing of Protection).
  - Click a cell to change it.
  - Shift-click to set blessings for individual players.
  - Auto-assign takes talents (Improved Might/Wisdom) and ranks into account.
  - The leader and assists can edit everyone, and other paladins can edit their own row.
- **Tank guard.** Never Blessing of Salvation on a tank. Marked tanks, raid main tanks and assists get another blessing instead (Might for warriors and druids, Kings otherwise, per class). The tank list is shared between Lightbound paladins.
- **Judgement assignments.** Who keeps Wisdom, Light, Crusader or Justice on the boss. Set in the raid window and shared with the other paladins. In combat, one icon per assigned Judgement shows whether it's on your target, with a sound when yours is missing.
- **Raid overview.** Every class you bless, with how many are missing it and the shortest time left. Click a row to bless the whole class.
- **Blessing requests.** When someone whispers "kings pls", "bom" or just "buff", a row with their name appears. Click it to bless them.

## Cleanse, cooldowns and Divine Intervention
- **Cleanse grid.** Decursive-style: one small cell per group member (and pet), coloured and iconed when they carry a Poison, Disease or Magic debuff you can remove. Click a cell to cleanse. Cells follow joins and leaves even in combat. Out-of-range players are dimmed. Switch to a list of afflicted units if you prefer. A cleanse key casts on the unit under your mouse (a cell, the list, any raid frame) or your target, in combat too.
- **Paladin cooldowns.** Every paladin's Blessing of Protection, Freedom and Sacrifice, Divine Shield and Divine Protection, plus your own Forbearance. Shared between Lightbound users.
- **Divine Intervention picker.** In raids, a short list of healers. Click one to cast Divine Intervention on them, in combat too. Shift-click pins a preferred target. The cast is announced in raid chat.
- **Resurrection announce.** "Resurrecting <name>" in party or raid chat when Redemption lands.

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

## Quality of life
- Buys Symbol of Kings and Symbol of Divinity automatically at vendors, and warns when you run low
- Click the Righteous Fury, aura or blessing icons to cast that spell (out of combat)
- Classic WoW-style options window (`/lb`), minimap button and addon compartment entry; shift-click the minimap button to unlock the frames
- Every frame can be moved, and resized with the mouse wheel while unlocked

## Commands
- `/lb` options
- `/lb raid` raid blessings
- `/lb why` explains what the buff key will do for each group member
- `/lb tank <name>` marks or unmarks a tank
- `/lb ignore <debuff>` hides a debuff from the cleanse list
- `/lb move`, `/lb reset` unlock or reset frames

## Switching from PallyPower
Log in once with PallyPower still enabled. Lightbound copies your assignments and stays quiet while PallyPower is loaded. Then disable PallyPower.

Source and issues: https://github.com/antnsn/Lightbound
