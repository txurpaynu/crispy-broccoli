"""Fetch CC0 assets from Poly Haven (https://polyhaven.com, all assets CC0).

Runs on CI (the dev sandbox can't reach polyhaven.com). Writes:
  - catalog_models.json / catalog_textures.json : trimmed asset lists to choose from
  - downloads/<model_id>/... : glTF (1k textures) for each model in manifest.json
  - ../../OldBroken/Resources/Textures/<tex_id>_{diff,nor,rough}.jpg for each texture
"""
import json, os, sys, urllib.request

UA = {"User-Agent": "OldBrokenAssetFetcher/1.0"}
HERE = os.path.dirname(os.path.abspath(__file__))
TEX_OUT = os.path.join(HERE, "..", "..", "OldBroken", "Resources", "Textures")
RES = os.environ.get("PH_RES", "1k")


def get(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def get_json(url):
    return json.loads(get(url))


def save(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(get(url))


def catalog():
    for t in ("models", "textures"):
        d = get_json(f"https://api.polyhaven.com/assets?t={t}")
        slim = {k: {"name": v.get("name"), "categories": v.get("categories"), "tags": v.get("tags"),
                    "polycount": v.get("polycount"), "dimensions": v.get("dimensions")} for k, v in d.items()}
        with open(os.path.join(HERE, f"catalog_{t}.json"), "w") as f:
            json.dump(slim, f, indent=0, sort_keys=True)
        print(t, len(slim))


def fetch_model(mid):
    files = get_json(f"https://api.polyhaven.com/files/{mid}")
    g = files["gltf"].get(RES) or files["gltf"]["1k"]
    g = g["gltf"]
    base = os.path.join(HERE, "downloads", mid)
    main = os.path.join(base, os.path.basename(g["url"]))
    save(g["url"], main)
    for rel, info in (g.get("include") or {}).items():
        save(info["url"], os.path.join(base, rel))
    print("model", mid, "->", main)
    return main


def fetch_texture(tid):
    files = get_json(f"https://api.polyhaven.com/files/{tid}")
    want = {"diff": ["Diffuse", "diff"], "nor": ["nor_gl", "Normal"], "rough": ["Rough", "rough"]}
    for short, keys in want.items():
        for k in keys:
            if k in files:
                entry = files[k].get(RES) or files[k]["1k"]
                fmt = entry.get("jpg") or entry.get("png")
                ext = "jpg" if "jpg" in entry else "png"
                save(fmt["url"], os.path.join(TEX_OUT, f"{tid}_{short}.{ext}"))
                break
    print("texture", tid)


if __name__ == "__main__":
    catalog()
    man = json.load(open(os.path.join(HERE, "manifest.json")))
    models = []
    for m in man.get("models", []):
        try:
            models.append((m, fetch_model(m)))
        except Exception as e:
            print("FAILED model", m, e, file=sys.stderr)
    for t in man.get("textures", []):
        try:
            fetch_texture(t)
        except Exception as e:
            print("FAILED texture", t, e, file=sys.stderr)
    with open(os.path.join(HERE, "downloads", "list.txt") if models else os.devnull, "w") as f:
        for mid, path in models:
            f.write(f"{mid}\t{path}\n")
