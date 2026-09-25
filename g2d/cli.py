"""CLI do g2d.

  python -m g2d transpile <dump.json> -o <dir>   # Dart em <dir>/lib/<pkg>.dart
  python -m g2d graph <alvo Go> [-C dir]         # pacotes em ordem topológica
"""

import argparse
import os
import subprocess
import sys

from g2d.emit import Emitter
from g2d.graph import go_list, topo_order
from g2d.model import Unsupported, load_dump

GOLIB = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "golib_dart")


def dart_format(source):
    """Canonicaliza via `dart format` (stdin → stdout)."""
    r = subprocess.run(
        ["dart", "format"], input=source, capture_output=True, text=True, encoding="utf-8",
        shell=sys.platform == "win32",  # dart é um .bat no Windows
    )
    if r.returncode != 0:
        raise RuntimeError(f"dart format falhou:\n{r.stderr}\n--- fonte ---\n{source}")
    return r.stdout


def transpile_package(pkg):
    return dart_format(Emitter(pkg).package())


def lib_path(pkg_path):
    return pkg_path + ".dart"


def cmd_transpile(args):
    lib = os.path.join(args.out, "lib")
    failed = 0
    for pkg in load_dump(args.dump):
        try:
            code = transpile_package(pkg)
        except Unsupported as e:
            print(f"{pkg.path}: {e}", file=sys.stderr)
            failed += 1
            continue
        dest = os.path.join(lib, *lib_path(pkg.path).split("/"))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8", newline="\n") as f:
            f.write(code)
        print(dest)
    try:
        golib = os.path.relpath(GOLIB, args.out)
    except ValueError:  # Windows: drives diferentes
        golib = GOLIB
    golib = golib.replace(os.sep, "/")
    with open(os.path.join(args.out, "pubspec.yaml"), "w", encoding="utf-8", newline="\n") as f:
        f.write(PUBSPEC.format(golib=golib))
    return 1 if failed else 0


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


def cmd_graph(args):
    """Pacotes a transpilar (stdlib fica de fora: vira shim)."""
    pkgs = go_list(args.target, cwd=args.C)
    for path in topo_order(pkgs):
        if not pkgs[path]["standard"]:
            print(path)
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(prog="g2d", description="Transpilador Go → Dart.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("transpile", help="dump do goast → Dart")
    t.add_argument("dump")
    t.add_argument("-o", "--out", default="out")
    t.set_defaults(fn=cmd_transpile)
    g = sub.add_parser("graph", help="ordem topológica dos pacotes (go list -deps)")
    g.add_argument("target")
    g.add_argument("-C", help="diretório do módulo Go")
    g.set_defaults(fn=cmd_graph)
    args = ap.parse_args(argv)
    return args.fn(args)
