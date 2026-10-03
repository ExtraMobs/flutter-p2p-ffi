"""Símbolos públicos de cada shim da stdlib (`g2d/shim_symbols.json`).

O g2d não emite chamada a símbolo que o shim não tem (seria Dart inválido
em silêncio): `ImportTable` recusa com `shim-simbolo:<pkg>.<nome>` (nível de
pacote) e `shim-simbolo:<pkg>.<Tipo>.<membro>` (método ou campo de tipo de
shim). As listas saem do dartast sobre os arquivos de golib_dart/lib (Python
não parseia Dart) e são regeradas com `python -m g2d shims`; o teste de
golden confere se estão em dia.

`shims`: nomes de nível de pacote de cada shim (a library e as partes).
`members`: por shim, membros de instância públicos de cada classe pública
(campos, getters/setters, métodos), somando os herdados por `extends`/`with`
e os das interfaces (resolvidos em golib_dart/lib: a mesma library primeiro,
senão pelo nome), os das extensões públicas da library e, num
`typedef T = C`, os de C. `null` = superclasse fora de golib_dart (ex.
`dart:core`): membros desconhecidos, sem conferência.
"""

import json
import os

from g2d.config import STDLIB_SHIMS
from g2d.pipeline import run_dart

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SYMBOLS_PATH = os.path.join(ROOT, "g2d", "shim_symbols.json")
LIB = os.path.join(ROOT, "golib_dart", "lib")
SCHEMA_VERSION = 2

# Supertipos do dart:core sem membro que um nome Go alcance.
CORE_EMPTY = frozenset({"Object", "Comparable", "Exception"})


def shim_file(uri):
    """`package:golib_dart/fmt.dart` → caminho em golib_dart/lib."""
    return os.path.join(LIB, *uri.split("/", 1)[1].split("/"))


def tok(n):
    return n["token"] if n else None


def decl_name(d):
    """Nome de uma declaração de topo (classe, typedef, extensão...)."""
    if "namePart" in d:
        return d["namePart"]["typeName"]["token"]
    return tok(d.get("name"))


def declared_names(unit):
    """Nomes públicos declarados no topo de uma CompilationUnit do dartast."""
    names = set()
    for d in unit["declarations"]:
        if d["node"] == "TopLevelVariableDeclaration":
            names.update(v["name"]["token"] for v in d["variables"]["variables"])
        elif decl_name(d):
            names.add(decl_name(d))
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


def instance_members(d):
    """Membros de instância públicos de uma classe/mixin/extensão."""
    names = set()
    for m in d.get("members") or (d.get("body") or {}).get("members") or []:
        if m["node"] == "FieldDeclaration" and not m.get("staticKeyword"):
            names.update(v["name"]["token"] for v in m["fields"]["variables"])
        elif (m["node"] == "MethodDeclaration" and not m.get("operatorKeyword")
              and tok(m.get("modifierKeyword")) != "static"):
            names.add(m["name"]["token"])
    return {n for n in names if not n.startswith("_")}


def type_ref(n):
    """Nome de um NamedType (sem o prefixo de import)."""
    return n["name"]["token"] if n and n.get("node") == "NamedType" else None


def supertypes(d):
    """(herança com implementação: extends/with/on/typedef; implements)."""
    inherit, iface = [], []
    if d.get("extendsClause"):
        inherit.append(type_ref(d["extendsClause"]["superclass"]))
    if d.get("withClause"):
        inherit.extend(type_ref(t) for t in d["withClause"]["mixinTypes"])
    if d["node"] == "MixinDeclaration" and d.get("onClause"):
        inherit.extend(type_ref(t) for t in d["onClause"].get("superclassConstraints") or [])
    if d["node"] == "GenericTypeAlias":
        inherit.append(type_ref(d.get("type")))
    if d.get("implementsClause"):
        iface.extend(type_ref(t) for t in d["implementsClause"]["interfaces"])
    return inherit, iface


class ClassIndex:
    """Tipos declarados em golib_dart/lib, por library (arquivo + partes)."""

    TYPES = ("ClassDeclaration", "MixinDeclaration", "ExtensionTypeDeclaration", "GenericTypeAlias")

    def __init__(self, units, libraries):
        self.libs = {}  # library → {nome: declaração}
        self.ext = {}  # library → {tipo estendido: membros das extensões públicas}
        self.by_name = {}  # nome → [(library, declaração)]
        for lib, files in sorted(libraries.items()):
            decls, ext = {}, {}
            for f in files:
                for d in units[f]["declarations"]:
                    if d["node"] in self.TYPES:
                        decls[decl_name(d)] = d
                        self.by_name.setdefault(decl_name(d), []).append((lib, d))
                    elif d["node"] == "ExtensionDeclaration" and not (tok(d.get("name")) or "_").startswith("_"):
                        on = type_ref((d.get("onClause") or {}).get("extendedType") or d.get("extendedType"))
                        ext.setdefault(on, set()).update(instance_members(d))
            self.libs[lib], self.ext[lib] = decls, ext

    def resolve(self, lib, name):
        """Declarações com esse nome: a da library, senão as de todas as
        libraries (a união nunca recusa um membro que existe)."""
        if name in self.libs[lib]:
            return [(lib, self.libs[lib][name])]
        return self.by_name.get(name, [])

    def members(self, lib, name, seen=frozenset()):
        """Membros públicos de instância (com os herdados), ou None se um
        supertipo com implementação não é de golib_dart."""
        if (lib, name) in seen:
            return set()
        seen = seen | {(lib, name)}
        out = set()
        for lib2, d in self.resolve(lib, name):
            out |= instance_members(d) | self.ext[lib2].get(name, set())
            inherit, iface = supertypes(d)
            for s in inherit + iface:
                if s is None or s in CORE_EMPTY:
                    continue
                sub = self.members(lib2, s, seen) if self.resolve(lib2, s) else None
                if sub is None:
                    if s in inherit:
                        return None
                    continue  # interface de fora: a classe concreta declara os membros
                out |= sub
        return out


def libraries(units):
    """{library: [arquivo, partes...]} dos arquivos que não são `part of`."""
    return {f: [f, *part_files(f, unit)] for f, unit in units.items()
            if not any(d["node"] == "PartOfDirective" for d in unit["directives"])}


def all_dart_files():
    return sorted(os.path.join(d, f) for d, _, fs in os.walk(LIB) for f in fs if f.endswith(".dart"))


def generate():
    """Roda o dartast sobre golib_dart/lib e devolve o documento de símbolos."""
    units = dump_units(all_dart_files())
    libs = libraries(units)
    index = ClassIndex(units, libs)
    shims, members = {}, {}
    for p in sorted(STDLIB_SHIMS):
        lib = shim_file(STDLIB_SHIMS[p])
        shims[p] = sorted(set().union(*(declared_names(units[f]) for f in libs[lib])))
        classes = {}
        for name, d in sorted(index.libs[lib].items()):
            if name.startswith("_") or (d["node"] == "GenericTypeAlias" and not type_ref(d.get("type"))):
                continue  # privado, ou typedef de função
            m = index.members(lib, name)
            classes[name] = None if m is None else sorted(m)
        members[p] = classes
    return {"schemaVersion": SCHEMA_VERSION, "shims": shims, "members": members}


def render(doc):
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


def read():
    with open(SYMBOLS_PATH, encoding="utf-8") as f:
        doc = json.load(f)
    if doc.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError(f"{SYMBOLS_PATH}: schemaVersion {doc.get('schemaVersion')!r}; rode `python -m g2d shims`")
    return doc


def load():
    """{pacote: {nome Dart}} do arquivo gerado."""
    return {p: set(names) for p, names in read()["shims"].items()}


def load_members():
    """{pacote: {classe Dart: {membro} ou None (desconhecidos)}}."""
    return {p: {c: None if m is None else set(m) for c, m in classes.items()}
            for p, classes in read()["members"].items()}
