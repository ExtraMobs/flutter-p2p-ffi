"""Símbolos públicos de cada shim da stdlib (`g2d/shim_symbols.json`).

O g2d não emite chamada a símbolo que o shim não tem (seria Dart inválido
em silêncio): `ImportTable` recusa com `shim-simbolo:<pkg>.<nome>`. A lista
sai do dartast sobre os arquivos dos shims (Python não parseia Dart) e é
regerada com `python -m g2d shims`; o teste de golden confere se está em dia.
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


def generate():
    """Roda o dartast sobre os shims e devolve o documento de símbolos."""
    pkgs = sorted(STDLIB_SHIMS)
    files = [os.path.relpath(shim_file(STDLIB_SHIMS[p]), os.path.join(ROOT, "tools", "dartast")) for p in pkgs]
    out = run_dart(["run", "bin/dartast.dart", *files], cwd=os.path.join(ROOT, "tools", "dartast"),
                   capture_output=True, text=True, encoding="utf-8", check=True).stdout
    doc = json.loads(out)
    return {"schemaVersion": SCHEMA_VERSION,
            "shims": {p: sorted(declared_names(f["unit"])) for p, f in zip(pkgs, doc["files"])}}


def render(doc):
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


def load():
    """{pacote: {nome Dart}} do arquivo gerado."""
    with open(SYMBOLS_PATH, encoding="utf-8") as f:
        doc = json.load(f)
    if doc.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError(f"{SYMBOLS_PATH}: schemaVersion {doc.get('schemaVersion')!r}; rode `python -m g2d shims`")
    return {p: set(names) for p, names in doc["shims"].items()}
