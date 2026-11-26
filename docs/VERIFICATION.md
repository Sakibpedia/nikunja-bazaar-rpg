# Verification — Nikunja Bazaar RPG

Godot 4.3 stable, Windows. All commands exited 0.

| Suite | Result |
|---|---|
| `CityTest.tscn` | `[CITY2D] PASS` — 1,500 buildings, **362 real roads**, 76 named-road points, 31 amenities, 30 roadside shops, 16 plaza stalls |
| `EconomyTest.tscn` | `[ECON] PASS` — 15 nights, 3 quests each, stock, pricing, staff, upgrades, XP/levels, skills, quests, save/reload |
| `run_all.ps1` | `[DAY] ALL 15 NIGHTS PASS` — every night built 46 stalls, spawned customers, hit targets, completed quests and finished successfully |

## Urban fidelity loop

1. Queried OpenStreetMap (Overpass API) for Nikunja, Khilkhet, Dhaka (23.8202–23.8402 N, 90.4078–90.4278 E).
2. Converted 362 highways and 6,535 building polygons into `assets/maps/nikunja.json` and a self-rendered raster `nikunja_osm.png`.
3. Placed shops along named roads (Kuril Flyover, Airport Road, Sector Roads 1–16, etc.) and found a genuine open block for the market plaza.
4. Fixed the first plaza search failure on the denser Nikunja data by widening the radius search and scaling stall spacing to the open area.
5. Fixed the save-path leak that made test progress appear in screenshots.

## RPG loop

- Added XP, levels, skill points, three skills, faction standings, three quests per night, quest giver, VIP haggling duel and RPG panels.
- Verified skill allocation, quest rewards, level-ups and persistence in the economy suite.
- Captured seven real gameplay frames: menu, market, management, RPG skills, quests, duel and night summary.

## Rendering

A 600-building subset is drawn while all 1,500 remain in the collision grid, keeping the game stable on integrated GPUs. All seven screenshot modes rendered without crashes.

Made by S M Nazmuz Sakib. Map data © OpenStreetMap contributors (ODbL 1.0).
