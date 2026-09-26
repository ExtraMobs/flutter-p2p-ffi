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
    registradas no Unit (o pacote é pulado)."""

    def run(self, ctx):
        for unit in ctx.units:
            try:
                unit.source = Engine(unit.pkg, plugins=ctx.plugins).emit_package()
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
        lib = os.path.join(ctx.out, "lib")
        for unit in ctx.units:
            if unit.source is None:
                continue
            unit.path = os.path.join(lib, *(unit.pkg.path + ".dart").split("/"))
            os.makedirs(os.path.dirname(unit.path), exist_ok=True)
            with open(unit.path, "w", encoding="utf-8", newline="\n") as f:
                f.write(unit.source)
        try:
            golib = os.path.relpath(GOLIB, ctx.out)
        except ValueError:  # Windows: drives diferentes
            golib = GOLIB
        with open(os.path.join(ctx.out, "pubspec.yaml"), "w", encoding="utf-8", newline="\n") as f:
            f.write(PUBSPEC.format(golib=golib.replace(os.sep, "/")))


class Pipeline:
    DEFAULT_STAGES = (LoadStage, EmitStage, FormatStage, WriteStage)

    def __init__(self, stages=None):
        self.stages = [s() for s in (stages or self.DEFAULT_STAGES)]

    def run(self, ctx):
        for stage in self.stages:
            stage.run(ctx)
        return ctx


def dart_format(source):
    """Canonicaliza via `dart format` (stdin → stdout)."""
    r = subprocess.run(
        ["dart", "format"], input=source, capture_output=True, text=True, encoding="utf-8",
        shell=sys.platform == "win32",  # dart é um .bat no Windows
    )
    if r.returncode != 0:
        raise RuntimeError(f"dart format falhou:\n{r.stderr}\n--- fonte ---\n{source}")
    return r.stdout


def transpile_package(pkg, plugins=None):
    """Atalho: um pacote → Dart formatado."""
    return dart_format(Engine(pkg, plugins=plugins).emit_package())
