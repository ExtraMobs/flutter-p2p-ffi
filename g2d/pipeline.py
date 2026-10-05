"""Pipeline do g2d: estágios encadeados sobre um contexto de execução.

    dump goast → LoadStage → EmitStage (Engine) → FormatStage (dart format) → WriteStage

Cada estágio é uma classe (`Stage`); um pipeline customizado troca, remove ou
acrescenta estágios (ex.: validar com `dart analyze`, gerar relatórios).
"""

import dataclasses
import os
import subprocess
import sys
from abc import ABC, abstractmethod
from dataclasses import dataclass, field

from g2d.analysis.color import ColorTable
from g2d.analysis.ifacecross import IfaceTable
from g2d.engine import Engine
from g2d.model import Unsupported, link_packages, load_dump
from g2d.services.anon import anon_path
from g2d.services.reflection import reflective_pkg


GOLIB = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "golib_dart")

PUBSPEC = """\
# Gerado pelo g2d. NÃO EDITE.
name: out
publish_to: none

environment:
  sdk: ^3.13.0

dependencies:
  golib_dart:
    path: {golib}
"""


@dataclass
class Unit:
    """Um pacote Go em trânsito pelo pipeline."""

    pkg: object
    source: str = None  # Dart gerado
    error: Exception = None
    path: str = None  # arquivo escrito


@dataclass
class RunContext:
    dump: str = None
    out: str = None
    plugins: list = None  # None = DEFAULT_PLUGINS
    units: list = field(default_factory=list)
    shared: dict = field(default_factory=dict)  # import path → Dart (structs anônimas canônicas)


class Stage(ABC):
    @abstractmethod
    def run(self, ctx):
        ...


class LoadStage(Stage):
    """Lê o dump do goast (um Unit por pacote)."""

    def run(self, ctx):
        ctx.units = [Unit(pkg) for pkg in link_packages(load_dump(ctx.dump))]


class EmitStage(Stage):
    """Transpila cada pacote com o Engine; construções não suportadas ficam
    registradas no Unit (o pacote é pulado). A cor `async` é a do conjunto
    de pacotes carregados juntos (`color_table`). As libraries das structs
    anônimas canônicas que ele usa vão para `ctx.shared`."""

    def run(self, ctx):
        colors = color_table([u.pkg for u in ctx.units], ctx.plugins)
        for unit in ctx.units:
            try:
                libs = emit_libraries(unit.pkg, plugins=ctx.plugins, colors=colors)
            except Unsupported as e:
                unit.error = e
                continue
            unit.source = libs.pop(unit.pkg.path)
            ctx.shared.update(libs)


class FormatStage(Stage):
    """Canonicaliza com `dart format` (determinismo)."""

    def run(self, ctx):
        for unit in ctx.units:
            if unit.source is not None:
                unit.source = dart_format(unit.source)
        ctx.shared = {p: dart_format(src) for p, src in sorted(ctx.shared.items())}


class WriteStage(Stage):
    """Escreve `<out>/lib/<import path>.dart` e o pubspec do mono-repo."""

    def run(self, ctx):
        units = [u for u in ctx.units if u.source is not None]
        paths = write_tree(ctx.out, {**ctx.shared, **{u.pkg.path: u.source for u in units}})
        for u in units:
            u.path = paths[u.pkg.path]


class Pipeline:
    DEFAULT_STAGES = (LoadStage, EmitStage, FormatStage, WriteStage)

    def __init__(self, stages=None):
        self.stages = [s() for s in (stages or self.DEFAULT_STAGES)]

    def run(self, ctx):
        for stage in self.stages:
            stage.run(ctx)
        return ctx


def run_dart(args, **kw):
    """`dart <args>` (no Windows o `dart` é um .bat: precisa do shell)."""
    return subprocess.run(["dart", *args], shell=sys.platform == "win32", **kw)


def write_tree(out, sources):
    """Mono-repo Dart: `<out>/lib/<import path>.dart` de cada fonte e o pubspec
    apontando para o golib_dart. Devolve {import path: arquivo escrito}."""
    lib = os.path.join(out, "lib")
    os.makedirs(out, exist_ok=True)  # mesmo sem nenhum pacote
    paths = {}
    for path, source in sources.items():
        dst = paths[path] = os.path.join(lib, *(path + ".dart").split("/"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "w", encoding="utf-8", newline="\n") as f:
            f.write(source)
    try:
        golib = os.path.relpath(GOLIB, out)
    except ValueError:  # Windows: drives diferentes
        golib = GOLIB
    with open(os.path.join(out, "pubspec.yaml"), "w", encoding="utf-8", newline="\n") as f:
        f.write(PUBSPEC.format(golib=golib.replace(os.sep, "/")))
    return paths


def dart_format(source):
    """Canonicaliza via `dart format` (stdin → stdout)."""
    r = run_dart(["format"], input=source, capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0:
        raise RuntimeError(f"dart format falhou:\n{r.stderr}\n--- fonte ---\n{source}")
    return r.stdout


def color_table(pkgs, plugins=None):
    """ColorTable (g2d/analysis/color.py) de pacotes transpilados juntos: a
    cor `async` atravessa pacotes (chamadas e implementações de interface),
    com a IfaceTable do grafo (`implements` entre pacotes, D8)."""
    engines = [Engine(p, plugins=plugins) for p in pkgs]
    table = ColorTable([e.color_summary() for e in engines])
    table.set_ifaces(IfaceTable([e.iface_summary() for e in engines]))
    table.reflective = any(reflective_pkg(p) for p in pkgs)
    return table


def emit_libraries(pkg, plugins=None, colors=None, errors=None):
    """{import path: Dart não formatado}: a library do pacote e as das structs
    anônimas canônicas que ela usa (e as que essas usam). `errors` liga o modo
    coleta do Engine (auditoria)."""
    engine = Engine(pkg, plugins=plugins, colors=colors)
    engine.errors = errors
    out = {pkg.path: engine.emit_package()}
    pending = [engine]
    while pending:
        e = pending.pop(0)
        for h, idx in sorted(e.services["anon"].used.items()):
            path = anon_path(h)
            if path in out:
                continue
            synthetic = dataclasses.replace(e.pkg, path=path, name="anon", files=[], imports=[], implements=[],
                                            init_order=[], init_deps=None)
            sub = Engine(synthetic, plugins=plugins, colors=colors)
            sub.errors = errors
            out[path] = sub.anon_library.emit(idx, h)
            pending.append(sub)
    return out


def transpile_libraries(pkg, plugins=None, colors=None):
    """Atalho: um pacote → {import path: Dart formatado} (o dele e as
    libraries compartilhadas das structs anônimas canônicas)."""
    return {p: dart_format(src) for p, src in emit_libraries(pkg, plugins, colors).items()}


def transpile_package(pkg, plugins=None, colors=None):
    """Atalho: um pacote → Dart formatado, só a library dele (`colors`: a
    ColorTable do grafo; sem ela, a cor é a do pacote sozinho)."""
    return dart_format(Engine(pkg, plugins=plugins, colors=colors).emit_package())
