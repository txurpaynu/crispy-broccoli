"""Designs the two facility floors as character grids (1 cell = 1 m) and checks connectivity.
Writes ../../OldBroken/Data/facility_map.json, which FacilityMap.swift loads."""
import json
from collections import deque

def make(w, h):
    return [["#"] * w for _ in range(h)]

def carve(g, x0, z0, x1, z1, ch="."):
    for z in range(z0, z1 + 1):
        for x in range(x0, x1 + 1):
            g[z][x] = ch

ground = make(40, 26)
rooms_g = {
    "halden_office": (1, 1, 6, 5), "office_b": (8, 1, 14, 5), "meeting": (16, 1, 23, 5),
    "dev": (25, 1, 38, 12), "corridor": (1, 7, 23, 8), "corridor2": (17, 7, 18, 24),
    "server": (1, 10, 7, 16), "lab": (9, 10, 15, 16), "storage": (20, 10, 23, 16),
    "lobby": (1, 18, 15, 24), "stair": (20, 18, 23, 24), "restricted": (25, 14, 38, 24),
}
for r in rooms_g.values(): carve(ground, *r)
# doors: id -> (x, z)
doors_g = {
    "halden": (3, 6), "office_b": (11, 6), "meeting": (20, 6), "dev": (24, 7),
    "lab_n": (12, 9), "server": (8, 13), "lab_e": (16, 13), "storage": (19, 12),
    "lobby_inner": (16, 20), "stair": (19, 21), "restricted": (31, 13),
    "entrance": (8, 25), "dock": (35, 25),
}
basement = make(30, 20)
rooms_b = {
    "landing": (1, 1, 5, 4), "archive": (7, 1, 14, 4), "bcorridor": (1, 6, 28, 7),
    "generator": (1, 9, 8, 18), "robolab": (10, 9, 28, 18),
}
for r in rooms_b.values(): carve(basement, *r)
doors_b = {"landing": (3, 5), "archive": (10, 5), "generator": (4, 8), "robolab": (19, 8)}
for (x, z) in doors_g.values(): ground[z][x] = "D"
ground[25][34] = ground[25][36] = "D"   # the loading dock is three cells wide
for (x, z) in doors_b.values(): basement[z][x] = "D"

def reach(g, start, blocked=set()):
    seen = {start}; q = deque([start])
    while q:
        x, z = q.popleft()
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, z + dz)
            if 0 <= n[1] < len(g) and 0 <= n[0] < len(g[0]) and n not in seen and g[n[1]][n[0]] in ".D" and n not in blocked:
                seen.add(n); q.append(n)
    return seen

r = reach(ground, (8, 24))
for name, (x0, z0, x1, z1) in rooms_g.items():
    assert (x0, z0) in r, ("unreachable", name)
rb = reach(basement, (2, 2))
for name, (x0, z0, x1, z1) in rooms_b.items():
    assert (x0, z0) in rb, ("unreachable b", name)
# escape route without lobby_inner and entrance: basement->stair->corridor2->corridor->dev->restricted->dock
blocked = {doors_g["lobby_inner"], doors_g["entrance"]}
r2 = reach(ground, (21, 21), blocked)
assert doors_g["dock"] in r2

for row in ground: print("".join(row))
print()
for row in basement: print("".join(row))
out = {
    "ground": ["".join(r) for r in ground], "basement": ["".join(r) for r in basement],
    "rooms": {**{k: [*v, 0] for k, v in rooms_g.items()}, **{k: [*v, 1] for k, v in rooms_b.items()}},
    "doors": {**{k: [*v, 0] for k, v in doors_g.items()}, **{k: [*v, 1] for k, v in doors_b.items()}},
}
json.dump(out, open("../../OldBroken/Data/facility_map.json", "w"), indent=1)
