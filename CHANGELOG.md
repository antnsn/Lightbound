# Lightbound changelog

## Unreleased

- **Buff key: the right rank for lower-level players**: someone more than 10 levels below a rank of their blessing gets the best rank they can take (a level 22 gets Might rank 4); someone too low for any rank is skipped, and `/lb why` says why.
- Carrot on a Stick now comes from LibBound, so every Bound addon has it. Your settings stay as they are.
- The Extras page is tidier: the Well-Rested and Well Fed switches sit in one row each.

## 5.1.1

- **The Cooldown Manager page is gone.** Lightbound no longer restyles Blizzard's Cooldown Manager: its icons were only a look, and it fought EllesmereUI's Cooldown Manager. To track buffs in combat, use the Cooldown Manager itself (`/cdm`, or `/eui` with EllesmereUI). If you picked Lightbound there, turn **EllesmereUI Cooldown Manager** back on in the AddOns list.

## 5.1.0

- **Cooldown Manager in the Lightbound look**: Blizzard's Cooldown Manager counts your buffs (Seals, Holy Shield, Righteous Fury, Blessings and more) with stacks and time left, also in combat, where addons can't read them on Forever. Lightbound gives its icons the gold edge and font, and a new **Cooldown Manager** page opens Blizzard's settings and suggests what to track. In the Blizzard skin the icons keep the game's look.
- **Built on LibBound**, the shared core of the Bound addons (Chronobound, Stormbound, Packbound, Spiritbound, Felbound, Dreambound). Your settings, pages, skins, buff key and commands stay the same.
- **Travel panel**: press Escape, and your Hearthstone, with the inn it's set to, sits beside the game menu. Click it to use it.
- **Explanations in tooltips** can be turned off: Skin page, or `/lb explain`.
- **Commands without a space**: `/lbrested`, `/lbmove`, `/lbgrid` and so on work next to `/lb rested`.
- **Minimap button** through LibDBIcon, so minimap addons (EllesmereUI, SexyMap, ElvUI, MinimapButtonBag) can collect it. Its place is kept.

## 5.0.1

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

## 5.0

The first release out of beta.

- Twist bar (new page Twist): for Retribution with Unsealed Wrath. Three pips that show your real Echo stacks (drawn by the game, in combat too), a swing bar, and a pulsing TWIST above it as soon as three copies are stored, and again when it is time to go back. Judgement and Holy Strike icons alongside. A swing your target dodges, parries or that misses isn't counted.
- Seal timer: a Seal of Command proc no longer restarts the 30 second timer.
- Announce: "Say when you drink" posts "Drinking" in party chat when you start drinking in a group, by default only in dungeons and raids. Off by default, under Announce.
- Blessings window: a new **Players** tab with one line per player. Set a blessing for one player only (grey follows the class, gold is that player's own), and mark tanks right there. A player with their own blessing no longer counts as missing the class blessing.
- Carrot on a Stick (page Extras, off by default): worn while you're mounted, in the trinket slot you pick, and your own trinket goes back on when you get off. Not in instances; waits until combat is over.
- Cleanse page: "Show when solo" and "Names in grid cells" share a row, so the ignore list at the bottom fits.
- Lightbound.toc loads new files, so update with the game closed.

## 4.5

- Skins: pick how Lightbound looks on the new Skin page in `/lb`. Lightbound (the gold look, default), Blizzard (the game's own grey and silver frames) or Flat (thin black edges on dark grey, to sit next to EllesmereUI or ElvUI). A new skin applies after a reload. Colours that mean something (missing, debuff types, class colours) stay the same in every skin.
- Lightbound only loads on paladins. On any other class it does nothing, and it unticks itself for that character in the AddOns list.
- Lightbound.toc loads a new file, so update with the game closed.

## 4.4

- New look for the reminders: aura, Righteous Fury, Well-Rested and Well Fed are cards built on the Lightbound emblem. The icon is a round medallion in a gold ring with the emblem's sunburst turning slowly behind it, on a dark panel with a double gilt rule. When a buff is gone the light fades and the icon greys.
- Exorcism and Hammer of Wrath use the game's own proc glow.
- Casting an aura in combat clears the aura card, even when combat hides the aura from addons.
- The Redemption announcement and whisper go out when you start casting, not after the resurrection lands.
- The cards stack above the proc and Judgement icons by default; frames you placed yourself stay put.
- Cleanse grid: the game draws each cell's debuff (type colour, icon, stacks), so it keeps showing in combat when addons can't read auras. Slightly roomier frame.
- Changing the cleanse ignore list with `/lb` updates the cleanse frame right away.

## 4.3.1

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

## 4.3

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

## 4.2

- Buff key Auto: saved group assignments only apply in raids; solo and in a party your own choices apply.

## 4.1

- Righteous Fury, aura and blessing icons cast their spell on click (out of combat).
- Mouse wheel resizes frames while unlocked; `/lb reset` clears sizes.
- Shift- or middle-click on the minimap button unlocks the frames.
- The cleanse grid shows when solo (option, on by default).

## 4.0

- New: cleanse grid and list, tank guard, Judgement assignments, paladin cooldowns, Divine Intervention picker, blessing requests, trackers (Reckoning, Consecration, Holy Shock, low-mana Wisdom reminder).

## 3.11

- The Exorcism alert works when the creature type is hidden.

## 3.10

- Fixed the Judgement fallback erroring in combat.

## 3.9

- Solid window backgrounds, fallback combat icons, screenshots.

## 3.8

- First release: one-key party and raid buffing with PallyPower-compatible assignments, warnings and trackers.
