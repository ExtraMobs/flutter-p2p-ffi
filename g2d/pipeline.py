"""Pipeline do g2d: estágios encadeados sobre um contexto de execução.

    dump goast → LoadStage → EmitStage (Engine) → FormatStage (dart format) → WriteStage

Cada estágio é uma classe (`Stage`); um pipeline customizado troca, remove ou
acrescenta estágios (ex.: validar com `dart analyze`, gerar relatórios).
"""

import os
import subprocess
import sys
from abc import ABC, abstractmethod
from dataclasses import dataclass, field

from g2d.analysis.color import ColorTable
from g2d.engine import Engine
from g2d.model import Unsupported, link_packages, load_dump


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
    de pacotes carregados juntos (`color_table`)."""

    def run(self, ctx):
        colors = color_table([u.pkg for u in ctx.units], ctx.plugins)
        for unit in ctx.units:
            try:
                unit.source = Engine(unit.pkg, plugins=ctx.plugins, colors=colors).emit_package()
            except Unsupported as e:
                unit.error = e


class FormatStage(Stage):
    """Canonicaliza com `dart format` (determinismo)."""

    def run(self, ctx):
        for unit in ctx.units:
            if unit.source is not None:
                unit.source = dart_format(unit.source)


class WriteStage(Stage):
    """Escreve `<out>/lib/<import path>.dart` e o pubspec do mono-repo."""

    def run(self, ctx):
        units = [u for u in ctx.units if u.source is not None]
        paths = write_tree(ctx.out, {u.pkg.path: u.source for u in units})
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
    cor `async` atravessa pacotes (chamadas e implementações de interface)."""
    return ColorTable([Engine(p, plugins=plugins).color_summary() for p in pkgs])


def transpile_package(pkg, plugins=None, colors=None):
    """Atalho: um pacote → Dart formatado (`colors`: a ColorTable do grafo;
    sem ela, a cor é a do pacote sozinho)."""
    return dart_format(Engine(pkg, plugins=plugins, colors=colors).emit_package())
