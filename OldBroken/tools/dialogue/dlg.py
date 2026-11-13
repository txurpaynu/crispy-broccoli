"""Tiny DSL for writing dialogue JSON. Shared by every chapter script."""
import json
nodes = []
def N(id, text, e=None, next=None, choices=None, fx=None, ev=None, speaker="VEXLEY", red=None):
    n = {"id": id, "speaker": speaker, "text": text}
    if e: n["expression"] = e
    if next: n["next"] = next
    if choices: n["choices"] = choices
    if fx: n["effects"] = fx
    if ev: n["events"] = ev
    if red: n["redirects"] = red
    nodes.append(n)
def C(text, next=None, fx=None, cond=None):
    c = {"text": text}
    if next: c["next"] = next
    if fx: c["effects"] = fx
    if cond: c["condition"] = cond
    return c
def chain(prefix, lines, end_next=None, end_fx=None, end_ev=None, speaker="VEXLEY"):
    """lines: list of (expr, text). Returns first id."""
    for i, (e, t) in enumerate(lines):
        last = i == len(lines) - 1
        N(f"{prefix}_{i}" if i else prefix, t, e,
          next=(end_next if last else f"{prefix}_{i+1}"),
          fx=(end_fx if last else None), ev=(end_ev if last else None), speaker=speaker)
    return prefix
def save(path):
    ids = [n["id"] for n in nodes]
    dup = {i for i in ids if ids.count(i) > 1}
    assert not dup, dup
    known = set(ids)
    for n in nodes:
        for t in [n.get("next")] + [c.get("next") for c in n.get("choices", [])] + [r["to"] for r in n.get("redirects", [])]:
            assert t is None or t in known, (n["id"], t)
    json.dump(nodes, open(path, "w"), indent=1, ensure_ascii=False)
    print(path, len(nodes))
