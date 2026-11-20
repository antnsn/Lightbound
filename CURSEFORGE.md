<!-- summary (CurseForge "Summary" field, at most 256 characters):
All-in-one paladin addon for WoW: Forever: party and raid buffs on one key, blessing assignments shared with the other paladins, and reminders for everything a paladin forgets. Replaces PallyPower and stays compatible with it.
-->

# Lightbound

**The all-in-one paladin addon for World of Warcraft: Forever.**

Lightbound buffs your party and raid with a single key, sorts out who blesses which class with the other paladins, and reminds you about everything a paladin forgets. It replaces PallyPower and stays compatible with it: paladins who still run PallyPower see you, can assign you, and get your assignments.

**Full guide with screenshots: https://antnsn.github.io/Lightbound/**

## What's new in 5.0.1
Bug fixes.

- **Twist bar** shows in the first fight after a relog, and its Judgement and Holy Strike icons no longer stay question marks.
- An error in one part of Lightbound no longer stops the parts loaded after it; the error is printed in chat once.

## What's new in 5.0
The first release out of beta.

- **Twist bar** for Retribution with Unsealed Wrath: three pips with your real Echo stacks (drawn by the game, in combat too), a swing bar, and a pulsing TWIST when it's time to swap seals, and again when it's time to swap back. Judgement and Holy Strike icons alongside.
- **Blessings window: Players tab.** One line per player: give one player their own blessing, and mark tanks right there.
- **Carrot on a Stick** goes on when you mount and your trinket comes back when you get off (off by default).
- **"Drinking"** in party chat when you sit down to drink, by default only in dungeons and raids (off by default).
- The seal timer no longer restarts on a Seal of Command proc.
- Update with the game closed: this version loads new files.

Every version's changes are in the changelog at the bottom of this page.

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
- **Drinking announce.** "Drinking" in party chat when you sit down to drink (optional, dungeons and raids only by default). Best effort: spotted by the drink buff's name.

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

## Changelog
<!-- changelog:start -->
### 5.0.1

- The Twist page and the drinking setting say they are a best effort, with why.
- An error in one part of Lightbound no longer stops the parts loaded after it (the twist bar,
  Carrot on a Stick and others could silently never start). The error is now printed in chat
  once, with the file and line.
- Twist bar: shows in the first fight after a relog too. The client can't always look up the
  Unsealed Wrath talent by name at login, and its Echo buff is only readable out of combat, so
  the bar used to stay away until the second fight. Once seen, the talent is remembered per
  character until a respec.
- Twist bar: the Judgement and Holy Strike icons no longer stay question marks when the client
  had no picture for them at login; they are fetched again until they have one.

### 5.0

The first release out of beta.

- Twist bar (new page Twist): for Retribution with Unsealed Wrath. Three pips that show your real Echo stacks (drawn by the game, in combat too), a swing bar, and a pulsing TWIST above it as soon as three copies are stored, and again when it is time to go back. Judgement and Holy Strike icons alongside. A swing your target dodges, parries or that misses isn't counted.
- Seal timer: a Seal of Command proc no longer restarts the 30 second timer.
- Announce: "Say when you drink" posts "Drinking" in party chat when you start drinking in a group, by default only in dungeons and raids. Off by default, under Announce.
- Blessings window: a new **Players** tab with one line per player. Set a blessing for one player only (grey follows the class, gold is that player's own), and mark tanks right there. A player with their own blessing no longer counts as missing the class blessing.
- Carrot on a Stick (page Extras, off by default): worn while you're mounted, in the trinket slot you pick, and your own trinket goes back on when you get off. Not in instances; waits until combat is over.
- Cleanse page: "Show when solo" and "Names in grid cells" share a row, so the ignore list at the bottom fits.
- Lightbound.toc loads new files, so update with the game closed.

### 4.5

- Skins: pick how Lightbound looks on the new Skin page in `/lb`. Lightbound (the gold look, default), Blizzard (the game's own grey and silver frames) or Flat (thin black edges on dark grey, to sit next to EllesmereUI or ElvUI). A new skin applies after a reload. Colours that mean something (missing, debuff types, class colours) stay the same in every skin.
- Lightbound only loads on paladins. On any other class it does nothing, and it unticks itself for that character in the AddOns list.
- Lightbound.toc loads a new file, so update with the game closed.

### 4.4

- New look for the reminders: aura, Righteous Fury, Well-Rested and Well Fed are cards built on the Lightbound emblem. The icon is a round medallion in a gold ring with the emblem's sunburst turning slowly behind it, on a dark panel with a double gilt rule. When a buff is gone the light fades and the icon greys.
- Exorcism and Hammer of Wrath use the game's own proc glow.
- Casting an aura in combat clears the aura card, even when combat hides the aura from addons.
- The Redemption announcement and whisper go out when you start casting, not after the resurrection lands.
- The cards stack above the proc and Judgement icons by default; frames you placed yourself stay put.
- Cleanse grid: the game draws each cell's debuff (type colour, icon, stacks), so it keeps showing in combat when addons can't read auras. Slightly roomier frame.
- Changing the cleanse ignore list with `/lb` updates the cleanse frame right away.

### 4.3.1

Fixes
- Request rows no longer cause "Interface action failed" when combat starts, and a row can't change your target mid-fight.
- Blessing requests only count short asks ("kings pls", "might?", "buff pls", "can i get kings"); "I might be late" is no longer a request.
- Tank lists: only the group leader shares the list, and an empty list no longer wipes everyone else's.
- Another paladin's aura on you no longer counts as yours, so the aura warning and the buff key work in groups with several paladins.
- No more false "WISDOM" low-mana reminder right after judging Wisdom; the trackers use the same per-mob Judgement tracking as the rest.
- Judgement: hidden ("restricted") debuff names and debuffs left out in combat fall back to your last Judgement instead of showing it as missing.
- Exorcism and Hammer of Wrath alerts go dark while the spell is on cooldown in combat.
- "NO SEAL" shows right at the pull, not seconds into the fight.
- No more false "Well Fed is gone" after a loading screen.
- The class overview uses the right blessing duration in combat and drops rows for players who died.
- `/lb why` no longer errors in combat.
- The buff key keeps working when you change "cast on key down", without a reload.
- The PallyPower import runs once per paladin instead of once per account.
- "Open blessings" always opens the window; closing the options only relocks frames it unlocked itself.
- The shift-click blessing popup has a close button and closes on Escape and when the roster changes.
- Reagent auto-buy keeps a little gold (1g or 10%, whichever is smaller) and checks bag space.
- Option notes no longer run into their labels.

Changes
- Divine Intervention and resurrection announcements are shown on your own screen when chat is locked for addons, instead of being lost.
- Sync messages wait while addon messages are locked (boss fights) instead of being dropped.
- Saved rows for paladins you haven't seen in 30 days are forgotten. Your own characters are kept.
- Tank lists from older versions are only accepted from the group leader. Paladins still on 4.3 may see a tank called "-" when the leader clears the list.

### 4.3

Blessings
- The Blessings window (`/lb blessings`, `/lb raid` still works) is the only place that decides who gets what, solo, in a party and in a raid. The Assignments setting and the Class blessings page are gone; your old class list is copied into your row once per paladin.
- Tank replacements for Salvation are set on a line under your row.
- Blessings you haven't learned show red in your row, and the buff key says when it skips one.

Frames
- Drag frames with live grid snapping (Shift places freely); a bar on the grid sets the size, toggles snapping and locks. `/lb grid [size]`.
- HUD frames no longer cover other windows.
- Well-Rested and Well Fed show as cards with a glow, and can keep following a buff after it's gone with a rebuff warning.

Judgements
- Which Judgement went out comes from the seal timer, so it works while combat hides your buffs.
- Tracked per mob and refreshed by your harmful spells on that target.

Fixes
- Seal timer: an expired seal could freeze the game for 1-2 seconds.

### 4.2

- Buff key Auto: saved group assignments only apply in raids; solo and in a party your own choices apply.

### 4.1

- Righteous Fury, aura and blessing icons cast their spell on click (out of combat).
- Mouse wheel resizes frames while unlocked; `/lb reset` clears sizes.
- Shift- or middle-click on the minimap button unlocks the frames.
- The cleanse grid shows when solo (option, on by default).

### 4.0

- New: cleanse grid and list, tank guard, Judgement assignments, paladin cooldowns, Divine Intervention picker, blessing requests, trackers (Reckoning, Consecration, Holy Shock, low-mana Wisdom reminder).

### 3.11

- The Exorcism alert works when the creature type is hidden.

### 3.10

- Fixed the Judgement fallback erroring in combat.

### 3.9

- Solid window backgrounds, fallback combat icons, screenshots.

### 3.8

- First release: one-key party and raid buffing with PallyPower-compatible assignments, warnings and trackers.
<!-- changelog:end -->
