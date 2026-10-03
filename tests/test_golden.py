"""Golden tests: tests/golden/<caso>/<caso>.go → .goast.json → .dart.

Caso com `go.mod` é um módulo multi-pacote: um `<caso>.goast.json` com todos
os pacotes (`goast dump -C <caso> ./...`), um `<caso>.<pacote>.dart` por
pacote (import path relativo ao módulo, `/` → `.`) e o e2e roda `go run ./cmd`.
As libraries compartilhadas das structs anônimas canônicas (`lib/_anon/<hash>`)
ficam em `<caso>._anon.<hash>.dart`.

G2D_UPDATE_GOLDEN=1 regrava os arquivos esperados (revisar o diff!). Os testes
são numerados na ordem do pipeline (unittest ordena por nome), então o update
de uma etapa já alimenta a seguinte.
O teste end-to-end compara `go run` com `dart run` do código gerado.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

from g2d.pipeline import color_table, transpile_libraries, write_tree
from g2d.services.anon import ANON_DIR
from g2d.model import link_packages, parse_dump

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOLDEN = os.path.join(ROOT, "tests", "golden")
UPDATE = os.environ.get("G2D_UPDATE_GOLDEN") == "1"
HAVE_GO = shutil.which("go") is not None
HAVE_DART = shutil.which("dart") is not None
HAVE_NODE = shutil.which("node") is not None  # JS e Wasm rodam no Node
WASM_RUNNER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "run_wasm.mjs")
WIN = sys.platform == "win32"
# Oráculo no mesmo Go do corpus/goast (baixado pelo toolchain do go, se preciso).
os.environ.setdefault("GOTOOLCHAIN", "go1.26.5")

CASES = sorted(d for d in os.listdir(GOLDEN) if os.path.isdir(os.path.join(GOLDEN, d)))
if os.environ.get("G2D_CASES"):  # G2D_CASES=a,b: só esses casos (iteração local)
    CASES = [c for c in CASES if c in os.environ["G2D_CASES"].split(",")]


def case_file(case, ext):
    return os.path.join(GOLDEN, case, case + ext)


def is_module(case):
    return os.path.exists(os.path.join(GOLDEN, case, "go.mod"))


def case_packages(case):
    """[(pacote, .dart esperado, caminho em lib/)] do dump esperado do caso."""
    with open(case_file(case, ".goast.json"), encoding="utf-8") as f:
        pkgs = link_packages(parse_dump(json.load(f)))
    if not is_module(case):
        (pkg,) = pkgs
        return [(pkg, case_file(case, ".dart"), case + ".dart")]
    out = []
    for pkg in pkgs:
        rel = pkg.path[len(pkg.module["path"]) + 1:]
        out.append((pkg, case_file(case, "." + rel.replace("/", ".") + ".dart"), pkg.path + ".dart"))
    return out


def shared_goldens(case):
    """{import path em lib/: .dart esperado} das structs anônimas canônicas
    do caso (`<caso>._anon.<hash>.dart`)."""
    prefix = f"{case}.{ANON_DIR}."
    return {f"{ANON_DIR}/{f[len(prefix):-len('.dart')]}": os.path.join(GOLDEN, case, f)
            for f in sorted(os.listdir(os.path.join(GOLDEN, case))) if f.startswith(prefix) and f.endswith(".dart")}


def main_lib(case):
    """Library Dart com o main do caso (em lib/)."""
    return next(lib for pkg, _, lib in case_packages(case) if pkg.name == "main")


def run(cmd, cwd=None, binary=False):
    """Roda cmd; stdout em texto, ou em bytes (strings Go podem não ser UTF-8)."""
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, shell=WIN)
    if r.returncode != 0:
        err = r.stderr.decode("utf-8", "replace")
        raise AssertionError(f"{' '.join(cmd)} falhou ({r.returncode}):\n{r.stdout!r}\n{err}")
    return r.stdout if binary else r.stdout.decode("utf-8")


def check_golden(test, path, actual):
    if UPDATE:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(actual)
        return
    with open(path, encoding="utf-8") as f:
        test.assertEqual(f.read(), actual, f"golden desatualizado: {path}")


class GoldenTest(unittest.TestCase):
    @unittest.skipUnless(HAVE_GO, "go ausente")
    def test_1_goast_dump(self):
        for case in CASES:
            with self.subTest(case=case):
                target = ["-C", os.path.join(GOLDEN, case), "./..."] if is_module(case) else [os.path.join(GOLDEN, case)]
                out = run(["go", "run", ".", "dump", *target], cwd=os.path.join(ROOT, "tools", "goast"))
                check_golden(self, case_file(case, ".goast.json"), out)

    @unittest.skipUnless(HAVE_DART, "dart ausente")
    def test_3_dartast_dump(self):
        """Round-trip: o .dart esperado continua parseável e com a AST registrada."""
        for case in CASES:
            if not os.path.exists(case_file(case, ".dartast.json")):
                continue
            with self.subTest(case=case):
                rel = f"../../tests/golden/{case}/{case}.dart"
                out = run(["dart", "run", "bin/dartast.dart", rel], cwd=os.path.join(ROOT, "tools", "dartast"))
                check_golden(self, case_file(case, ".dartast.json"), out)

    @unittest.skipUnless(HAVE_DART, "dart ausente")
    def test_2_transpile(self):
        for case in CASES:
            pkgs = case_packages(case)
            colors = color_table([pkg for pkg, _, _ in pkgs])
            shared = {}
            for pkg, golden, _ in pkgs:
                with self.subTest(case=case, pkg=pkg.path):
                    libs = transpile_libraries(pkg, colors=colors)
                    check_golden(self, golden, libs.pop(pkg.path))
                    for path, source in libs.items():  # todo pacote escreve o mesmo arquivo
                        self.assertEqual(shared.setdefault(path, source), source, f"{path} difere entre pacotes")
            with self.subTest(case=case, shared=True):
                expected = shared_goldens(case)
                if UPDATE:
                    for path in set(expected) - set(shared):
                        os.remove(expected[path])
                else:
                    self.assertEqual(sorted(expected), sorted(shared), f"libraries _anon desatualizadas: {case}")
                for path, source in sorted(shared.items()):
                    check_golden(self, os.path.join(GOLDEN, case, f"{case}.{path.replace('/', '.')}.dart"), source)

    @unittest.skipUnless(HAVE_GO and HAVE_DART, "go/dart ausentes")
    def test_4_end_to_end(self):
        """dart analyze sem issues e saída idêntica à do Go em todas as
        plataformas Dart: VM, JS (dart2js/Node) e Wasm (dart2wasm/Node)."""
        with tempfile.TemporaryDirectory() as tmp:
            sources = {}
            for case in CASES:
                libs = [(lib[:-len(".dart")], golden) for _, golden, lib in case_packages(case)]
                for lib, golden in libs + sorted(shared_goldens(case).items()):
                    with open(golden, encoding="utf-8") as f:
                        text = f.read()
                    # Struct canônica: o mesmo arquivo, byte a byte, em todo caso.
                    self.assertEqual(sources.setdefault(lib, text), text, f"{lib} difere entre casos")
            write_tree(tmp, sources)
            run(["dart", "pub", "get", "--offline"], cwd=tmp)
            run(["dart", "analyze", "--fatal-infos"], cwd=tmp)
            for case in CASES:
                case_dir = os.path.join(GOLDEN, case)
                sources = ["./cmd"] if is_module(case) else sorted(f for f in os.listdir(case_dir) if f.endswith(".go"))
                want = run(["go", "run", *sources], cwd=case_dir, binary=True)
                src = os.path.join("lib", *main_lib(case).split("/"))
                with self.subTest(case=case, platform="vm"):
                    self.assertEqual(want, run(["dart", "run", src], cwd=tmp, binary=True))
                if not HAVE_NODE:
                    continue
                js = os.path.join("out", case + ".js")
                with self.subTest(case=case, platform="js"):
                    run(["dart", "compile", "js", "-O1", "-o", js, src], cwd=tmp)
                    self.assertEqual(want, run(["node", js], cwd=tmp, binary=True))
                mjs, wasm = os.path.join("out", case + ".mjs"), os.path.join("out", case + ".wasm")
                with self.subTest(case=case, platform="wasm"):
                    run(["dart", "compile", "wasm", "-o", wasm, src], cwd=tmp)
                    self.assertEqual(want, run(["node", WASM_RUNNER, mjs, wasm], cwd=tmp, binary=True))

class ShimSymbolsTest(unittest.TestCase):
    @unittest.skipUnless(HAVE_DART, "dart ausente")
    def test_shim_symbols_up_to_date(self):
        """g2d/shim_symbols.json bate com os shims (python -m g2d shims)."""
        from g2d import shims

        check_golden(self, shims.SYMBOLS_PATH, shims.render(shims.generate()))


if __name__ == "__main__":
    unittest.main()
