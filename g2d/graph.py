"""Grafo de pacotes Go (via `go list -deps -json`) em ordem topológica."""

import heapq
import json
import os
import subprocess
from graphlib import TopologicalSorter

# Contexto de build fixo do g2d (determinismo; o Dart gerado não usa cgo
# nem código específico de SO/arquitetura). `purego,noasm`: as versões Go
# puras dos pacotes que têm assembly (o Dart não roda assembly).
BUILD_ENV = {"CGO_ENABLED": "0", "GOOS": "linux", "GOARCH": "amd64", "GOFLAGS": "-tags=purego,noasm"}


def build_env():
    """Ambiente do processo com o contexto de build do g2d."""
    return {**os.environ, **BUILD_ENV}


def go_list(target, cwd=None):
    """Roda `go list -deps -json <target>` e devolve {import path: info}.

    info = {"imports": [...], "standard": bool, "module": str | None}.
    """
    out = subprocess.run(
        ["go", "list", "-deps", "-json", target],
        cwd=cwd, env=build_env(), capture_output=True, text=True, encoding="utf-8", check=True,
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


def is_std(path):
    """Pacote da stdlib: primeiro segmento do import path sem ponto (a regra
    do goast; `C` e `unsafe` também caem aqui)."""
    return "." not in path.split("/", 1)[0]


def topo_order(pkgs):
    """Import paths na ordem de inicialização do Go (spec ≥ 1.21): a cada
    passo, o menor import path cujos imports já vieram todos. Dependências
    primeiro e determinística. Imports fora do grafo (ex. "C", "unsafe") são
    ignorados.
    """
    ts = TopologicalSorter()
    for path in sorted(pkgs):
        ts.add(path, *sorted(d for d in pkgs[path]["imports"] if d in pkgs))
    ts.prepare()
    ready = list(ts.get_ready())
    heapq.heapify(ready)
    order = []
    while ready:
        path = heapq.heappop(ready)
        order.append(path)
        ts.done(path)
        for p in ts.get_ready():
            heapq.heappush(ready, p)
    return order


def init_deps(path, imports):
    """Pacotes do grafo que o programa de `path` inicializa antes dele, na
    ordem do Go. `imports`: {import path: [imports diretos]} dos pacotes
    carregados. None se falta algum pacote do grafo (dump incompleto)."""
    closure, stack = set(), [path]
    while stack:
        for d in imports.get(stack.pop(), ()):
            if not is_std(d) and d not in closure:
                if d not in imports:
                    return None
                closure.add(d)
                stack.append(d)
    return topo_order({p: {"imports": imports[p]} for p in closure})
