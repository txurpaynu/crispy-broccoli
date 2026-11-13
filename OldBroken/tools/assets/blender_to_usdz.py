"""Blender (headless) script: convert each downloaded glTF to USDZ for SceneKit,
and write its bounding box so the game can place it at real-world scale.
Usage: blender -b --python blender_to_usdz.py -- <list.txt> <out_dir>
"""
import bpy, sys, os, json
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
listfile, out_dir = args[0], args[1]
os.makedirs(out_dir, exist_ok=True)
info = {}
for line in open(listfile):
    mid, path = line.strip().split("\t")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    mn = Vector((1e9, 1e9, 1e9)); mx = Vector((-1e9, -1e9, -1e9))
    tris = 0
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
        tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    out = os.path.join(out_dir, f"{mid}.usdz")
    bpy.ops.wm.usd_export(filepath=out, export_materials=True, generate_preview_surface=True,
                          export_textures=True, relative_paths=True)
    # Blender is Z-up; USD export converts to Y-up. Report size as (x, y=height, z=depth).
    info[mid] = {"size": [mx.x - mn.x, mx.z - mn.z, mx.y - mn.y], "tris": tris, "bytes": os.path.getsize(out)}
    print("converted", mid, info[mid])
mj = os.path.join(out_dir, "models.json")
merged = json.load(open(mj)) if os.path.exists(mj) else {}
merged.update(info)
json.dump(merged, open(mj, "w"), indent=1)
