#!/usr/bin/env bash
# Copies ../LibBound into Libs/LibBound so the addon runs in game and in wowbench while LibBound
# is developed next to it. Libs/LibBound is not tracked: release zips embed LibBound through
# wowbench pack ([[pack.embed]] in wowbench.toml).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
src="$here/../LibBound"
dst="$here/Libs/LibBound"
rm -rf "$dst"; mkdir -p "$dst"
for f in LibBound.xml Core.lua Skin.lua Card.lua Options.lua Minimap.lua Travel.lua BuffTimer.lua LICENSE; do cp "$src/$f" "$dst/"; done
echo "LibBound synced into $dst"
