---
name: release
description: Release a new Lightbound version (CurseForge tag + docs wiki). Use when the maintainer asks to release, tag or ship a version ("release 4.6", "lag en beta").
---

# Releasing Lightbound

A release is a git tag: CurseForge packages it (`.pkgmeta`), and the docs wiki
(https://antnsn.github.io/Lightbound/) is built from `docs/` on every push to main
(`.github/workflows/pages.yml`). The point of this list: the wiki, the screenshots and the
changelog match the version people download.

Steps marked **(in game)** are done by the maintainer: ask, then wait until they say it's done.

## 1. Check the code
- `git status`: only intended changes. Never commit the maintainer's own local edits they haven't asked for
  (e.g. an uncommitted `Cleanse.lua`): pull and push with `git -c rebase.autoStash=true pull --rebase`.
- `for f in *.lua; do luac5.1 -p "$f" || echo "syntax error: $f"; done`
- `~/.luarocks/bin/luacheck .`
- `for t in tests/*.lua; do lua5.1 "$t" || echo "FAIL: $t"; done`
- `bd list --status=in_progress`: anything half done that the changelog mentions? Ask.
- Codex review of what is unreleased since the last tag, if not already reviewed.

## 2. Version and changelog
- Ask: version number, and beta or release (`v4.6-beta` / `v4.6`). Tags so far are all `-beta`.
- `Lightbound.toc`: `## Version:`.
- `CHANGELOG.md`: rename `## Unreleased` to `## <version>`. Each line says what changed for the
  player. Keep the line "Lightbound.toc loads a new file, so update with the game closed." when a
  new .lua file was added to the .toc since the last tag (`git diff <last tag> -- Lightbound.toc`).

## 3. Docs (wiki)
For every changelog line, the docs say the same:
- A new feature has a page in `docs/features/` (linked from `docs/features/index.md`), or a section
  on an existing one. Changed settings are updated in that page's settings table.
- New `/lb` commands are on `docs/commands.md`.
- A feature that guesses or can be wrong because Forever hides data in combat (the twist count,
  anything counted instead of read) says so on its page, in a `{: .note }` callout at the top.
- `CURSEFORGE.md` (the CurseForge description) lists the new headline features.
- Build it: in `docs/`, `bundle exec jekyll build -d <scratchpad>/site`, no errors; check links
  to new pages and images.

## 4. Screenshots (in game, then the script)
After the version bump, so the options window shows the new number. A changed `.toc` is read at
client start: restart the game, not just `/reload`.
1. **(in game)** Restart, mouse to the screen edge, best somewhere without other players around
   (names above heads are not hidden), then `/bk shots` and wait for the message mid-screen,
   then `/reload` (saves where the frames were).
2. `python3 "../Barkeep/tools/crop_shots.py"`: writes `docs/screenshots/` (chat pixelated).
3. Look at every changed image (`git status docs/screenshots`) before committing: frames cut off,
   other players' names or messages, the mouse cursor. `frames/` (single frames) is only
   committed for images a page uses.
4. Every options page has a screenshot on its feature page: `ls docs/screenshots/options-*.png`
   against `grep -rhoE "screenshots/[a-z0-9/-]+\.png" docs`. A new page's screenshot gets a place.
5. Other skins (for `docs/features/skins.md`): **(in game)** switch skin on the Skin page, `/reload`,
   `/bk shots`, `/reload`; the script writes them to `docs/screenshots/skins/<skin>/`. Only when
   a skin's look changed.

## 5. Ship
- Commit: `Lightbound <version>: <headline features>` (toc, changelog, docs, screenshots).
- `git tag -a v<version>[-beta] -m "Lightbound <version>: <headline features>"`
- `git push && git push origin v<version>[-beta]`
- `gh run list --limit 3`: the Docs workflow finished; open the changed wiki page.
- Say that the CurseForge upload comes from the tag (it takes a few minutes), and whether
  players must update with the game closed.
- Close the beads the release finished.
