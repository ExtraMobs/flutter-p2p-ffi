"""Símbolos públicos de cada shim da stdlib (`g2d/shim_symbols.json`).

O g2d não emite chamada a símbolo que o shim não tem (seria Dart inválido
em silêncio): `ImportTable` recusa com `shim-simbolo:<pkg>.<nome>`. A lista
sai do dartast sobre os arquivos dos shims e das partes (`part`) deles
(Python não parseia Dart) e é regerada com `python -m g2d shims`; o teste de
golden confere se está em dia.
"""

import json
import os

from g2d.config import STDLIB_SHIMS
from g2d.pipeline import run_dart

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SYMBOLS_PATH = os.path.join(ROOT, "g2d", "shim_symbols.json")
SCHEMA_VERSION = 1


def shim_file(uri):
    """`package:golib_dart/fmt.dart` → caminho em golib_dart/lib."""
    return os.path.join(ROOT, "golib_dart", "lib", *uri.split("/", 1)[1].split("/"))


def declared_names(unit):
    """Nomes públicos declarados no topo de uma CompilationUnit do dartast."""
    names = set()
    for d in unit["declarations"]:
        if d["node"] == "TopLevelVariableDeclaration":
            names.update(v["name"]["token"] for v in d["variables"]["variables"])
        elif "namePart" in d:
            names.add(d["namePart"]["typeName"]["token"])
        elif "name" in d:
            names.add(d["name"]["token"])
    return {n for n in names if not n.startswith("_")}


def part_files(path, unit):
    """Arquivos `part` de uma library (URIs relativas ao arquivo dela)."""
    return [os.path.normpath(os.path.join(os.path.dirname(path), d["uri"]["literal"]["token"].strip("'\"")))
            for d in unit["directives"] if d["node"] == "PartDirective"]


def dump_units(paths):
    """{arquivo: CompilationUnit do dartast}, numa chamada só."""
    if not paths:
        return {}
    dartast = os.path.join(ROOT, "tools", "dartast")
    out = run_dart(["run", "bin/dartast.dart", *(os.path.relpath(p, dartast) for p in paths)], cwd=dartast,
                   capture_output=True, text=True, encoding="utf-8", check=True).stdout
    return {p: f["unit"] for p, f in zip(paths, json.loads(out)["files"])}


def generate():
    """Roda o dartast sobre os shims e as partes deles e devolve o documento
    de símbolos."""
    pkgs = sorted(STDLIB_SHIMS)
    libs = {p: shim_file(STDLIB_SHIMS[p]) for p in pkgs}
    units = dump_units(list(libs.values()))
    parts = {p: part_files(libs[p], units[libs[p]]) for p in pkgs}
    units.update(dump_units([f for p in pkgs for f in parts[p]]))
    return {"schemaVersion": SCHEMA_VERSION,
            "shims": {p: sorted(set().union(*(declared_names(units[f]) for f in [libs[p], *parts[p]])))
                      for p in pkgs}}


def render(doc):
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


def load():
    """{pacote: {nome Dart}} do arquivo gerado."""
    with open(SYMBOLS_PATH, encoding="utf-8") as f:
        doc = json.load(f)
    if doc.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError(f"{SYMBOLS_PATH}: schemaVersion {doc.get('schemaVersion')!r}; rode `python -m g2d shims`")
    return {p: set(names) for p, names in doc["shims"].items()}
