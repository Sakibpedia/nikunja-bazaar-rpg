#!/usr/bin/env python3
"""Convert the real Nikunja, Dhaka OSM extract into compact game map data.

Input : assets/maps/nikunja_overpass.json (Overpass API, ODbL)
Output: assets/maps/nikunja.json + assets/maps/nikunja_osm.png

    python tools/build_nikunja_map.py
"""
import json, math, pathlib
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[1]
MAPS = ROOT / "assets" / "maps"
SRC = MAPS / "nikunja_overpass.json"
OUT = MAPS / "nikunja.json"
PNG = MAPS / "nikunja_osm.png"

CENTER_LAT, CENTER_LON = 23.8302567, 90.4178733
MX = 111320.0 * math.cos(math.radians(CENTER_LAT))
MY = 110540.0

WIDTH = {
    "motorway": 16, "motorway_link": 10, "trunk": 13, "trunk_link": 9,
    "primary": 11, "primary_link": 8, "secondary": 9, "tertiary": 7,
    "residential": 4.5, "living_street": 3.6, "service": 2.8,
    "unclassified": 4, "pedestrian": 3, "footway": 1.2, "path": 1.2,
    "construction": 4, "cycleway": 1.5,
}


def xy(lat, lon):
    return [(lon - CENTER_LON) * MX, -(lat - CENTER_LAT) * MY]


def main():
    raw = json.loads(SRC.read_text(encoding="utf-8"))
    roads, buildings, amenities = [], [], []
    for e in raw["elements"]:
        tags = e.get("tags", {})
        geom = e.get("geometry", [])
        if e["type"] == "way" and "highway" in tags and len(geom) > 1:
            pts = [[round(v, 2) for v in xy(p["lat"], p["lon"])] for p in geom]
            roads.append({"pts": pts, "w": WIDTH.get(tags["highway"], 3.0),
                "kind": tags["highway"], "name": tags.get("name", "")})
        elif e["type"] == "way" and "building" in tags and len(geom) > 2:
            pts = [[round(v, 2) for v in xy(p["lat"], p["lon"])] for p in geom]
            try:
                levels = int(tags.get("building:levels", 0)) or max(2, int(float(tags.get("height", 9)) / 3))
            except (ValueError, TypeError):
                levels = 4
            buildings.append({"pts": pts, "floors": max(2, min(20, levels)),
                "kind": tags["building"], "name": tags.get("name", "")})
        elif e["type"] == "node" and "amenity" in tags:
            p = xy(e["lat"], e["lon"])
            amenities.append({"p": [round(v, 2) for v in p],
                "kind": tags["amenity"], "name": tags.get("name", "")})

    out = {"attribution": "OpenStreetMap contributors (ODbL 1.0) - Nikunja, Khilkhet, Dhaka",
        "center": [CENTER_LAT, CENTER_LON], "roads": roads,
        "buildings": buildings, "amenities": amenities}
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    # Self-made raster from the same OSM geometry (no external tile download).
    size, scale = 2048, 1.7
    img = Image.new("RGB", (size, size), (12, 20, 20))
    d = ImageDraw.Draw(img)
    def to_px(p):
        return (size / 2 + p[0] * scale, size / 2 + p[1] * scale)
    for b in buildings:
        d.polygon([to_px(p) for p in b["pts"]], fill=(58, 52, 44))
    for r in roads:
        pts = [to_px(p) for p in r["pts"]]
        d.line(pts, fill=(28, 32, 32), width=max(2, int(r["w"] * scale)))
        d.line(pts, fill=(96, 100, 96), width=1)
    for a in amenities:
        x, y = to_px(a["p"])
        d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(226, 176, 88))
    img.save(PNG, optimize=True)

    names = sorted({r["name"] for r in roads if r["name"]})
    print("roads", len(roads), "buildings", len(buildings), "amenities", len(amenities))
    print("named roads", len(names))
    print("map json KB", OUT.stat().st_size // 1024, "png KB", PNG.stat().st_size // 1024)


if __name__ == "__main__":
    main()
