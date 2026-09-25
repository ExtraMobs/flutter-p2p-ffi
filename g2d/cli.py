"""CLI do g2d.

  python -m g2d transpile <dump.json> -o <dir>   # Dart em <dir>/lib/<pkg>.dart
  python -m g2d graph <alvo Go> [-C dir]         # pacotes em ordem topológica
"""

import argparse
import sys

from g2d.graph import go_list, topo_order
from g2d.pipeline import GOLIB, PUBSPEC, Pipeline, RunContext, dart_format, transpile_package


__all__ = ["GOLIB", "PUBSPEC", "dart_format", "main", "transpile_package"]


def cmd_transpile(args):
    ctx = Pipeline().run(RunContext(dump=args.dump, out=args.out))
    failed = 0
    for unit in ctx.units:
        if unit.error is not None:
            print(f"{unit.pkg.path}: {unit.error}", file=sys.stderr)
            failed += 1
        else:
            print(unit.path)
    return 1 if failed else 0


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
