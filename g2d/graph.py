"""Grafo de pacotes Go (via `go list -deps -json`) em ordem topológica."""

import json
import subprocess
from graphlib import TopologicalSorter


def go_list(target, cwd=None):
    """Roda `go list -deps -json <target>` e devolve {import path: info}.

    info = {"imports": [...], "standard": bool, "module": str | None}.
    """
    out = subprocess.run(
        ["go", "list", "-deps", "-json", target],
        cwd=cwd, capture_output=True, text=True, encoding="utf-8", check=True,
    ).stdout
    return parse_go_list(out)


def parse_go_list(text):
    """`go list -json` emite objetos JSON concatenados (não um array)."""
    dec = json.JSONDecoder()
    pkgs, i = {}, 0
    while True:
        while i < len(text) and text[i].isspace():
            i += 1
        if i >= len(text):
            return pkgs
        obj, i = dec.raw_decode(text, i)
        pkgs[obj["ImportPath"]] = {
            "imports": obj.get("Imports") or [],
            "standard": bool(obj.get("Standard")),
            "module": (obj.get("Module") or {}).get("Path"),
        }


def topo_order(pkgs):
    """Import paths em ordem topológica (dependências primeiro).

    Desempate alfabético entre pacotes prontos ao mesmo tempo: a ordem é
    determinística. Imports fora do grafo (ex. "C", "unsafe") são ignorados.
    """
    ts = TopologicalSorter()
    for path in sorted(pkgs):
        ts.add(path, *sorted(d for d in pkgs[path]["imports"] if d in pkgs))
    ts.prepare()
    order = []
    while ts.is_active():
        ready = sorted(ts.get_ready())
        order.extend(ready)
        ts.done(*ready)
    return order
