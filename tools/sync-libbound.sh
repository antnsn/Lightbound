#!/usr/bin/env bash
# Copies ../LibBound into Libs/LibBound so the addon runs in game and in wowbench while LibBound
# is developed next to it. Libs/LibBound is not tracked: release zips embed LibBound through
# wowbench pack ([[pack.embed]] in wowbench.toml).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
src="$here/../LibBound"
dst="$here/Libs/LibBound"
rm -rf "$dst"; mkdir -p "$dst"
cp "$src/LibBound.xml" "$src/LICENSE" "$src"/*.lua "$dst/" # every LibBound file, so a new one needs no change here
# the minimap button's libraries (LibBound.xml loads them)
for d in CallbackHandler-1.0 LibDataBroker-1.1 LibDBIcon-1.0; do
	mkdir -p "$dst/Libs/$d"; cp "$src/Libs/$d/"*.lua "$dst/Libs/$d/"
done
echo "LibBound synced into $dst"
