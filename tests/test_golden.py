"""Golden tests: tests/golden/<caso>/<caso>.go → .goast.json → .dart.

G2D_UPDATE_GOLDEN=1 regrava os arquivos esperados (revisar o diff!).
O teste end-to-end compara `go run` com `dart run` do código gerado.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

from g2d.cli import GOLIB, PUBSPEC, transpile_package
from g2d.model import parse_dump

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOLDEN = os.path.join(ROOT, "tests", "golden")
UPDATE = os.environ.get("G2D_UPDATE_GOLDEN") == "1"
HAVE_GO = shutil.which("go") is not None
HAVE_DART = shutil.which("dart") is not None
WIN = sys.platform == "win32"

CASES = sorted(d for d in os.listdir(GOLDEN) if os.path.isdir(os.path.join(GOLDEN, d)))


def case_file(case, ext):
    return os.path.join(GOLDEN, case, case + ext)


def run(cmd, cwd=None):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", shell=WIN)
    if r.returncode != 0:
        raise AssertionError(f"{' '.join(cmd)} falhou ({r.returncode}):\n{r.stdout}\n{r.stderr}")
    return r.stdout


def check_golden(test, path, actual):
    if UPDATE:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(actual)
        return
    with open(path, encoding="utf-8") as f:
        test.assertEqual(f.read(), actual, f"golden desatualizado: {path}")


class GoldenTest(unittest.TestCase):
    @unittest.skipUnless(HAVE_GO, "go ausente")
    def test_goast_dump(self):
        for case in CASES:
            with self.subTest(case=case):
                out = run(["go", "run", ".", "dump", os.path.join(GOLDEN, case)],
                          cwd=os.path.join(ROOT, "tools", "goast"))
                check_golden(self, case_file(case, ".goast.json"), out)

    @unittest.skipUnless(HAVE_DART, "dart ausente")
    def test_dartast_dump(self):
        """Round-trip: o .dart esperado continua parseável e com a AST registrada."""
        for case in CASES:
            if not os.path.exists(case_file(case, ".dartast.json")):
                continue
            with self.subTest(case=case):
                rel = f"../../tests/golden/{case}/{case}.dart"
                out = run(["dart", "run", "bin/dartast.dart", rel], cwd=os.path.join(ROOT, "tools", "dartast"))
                check_golden(self, case_file(case, ".dartast.json"), out)

    @unittest.skipUnless(HAVE_DART, "dart ausente")
    def test_transpile(self):
        for case in CASES:
            with self.subTest(case=case):
                with open(case_file(case, ".goast.json"), encoding="utf-8") as f:
                    (pkg,) = parse_dump(json.load(f))
                check_golden(self, case_file(case, ".dart"), transpile_package(pkg))

    @unittest.skipUnless(HAVE_GO and HAVE_DART, "go/dart ausentes")
    def test_end_to_end(self):
        """dart analyze sem issues e saída idêntica à do programa Go."""
        with tempfile.TemporaryDirectory() as tmp:
            with open(os.path.join(tmp, "pubspec.yaml"), "w", encoding="utf-8") as f:
                f.write(PUBSPEC.format(golib=GOLIB.replace(os.sep, "/")))
            os.makedirs(os.path.join(tmp, "lib"))
            for case in CASES:
                shutil.copy(case_file(case, ".dart"), os.path.join(tmp, "lib", case + ".dart"))
            run(["dart", "pub", "get", "--offline"], cwd=tmp)
            run(["dart", "analyze", "--fatal-infos"], cwd=tmp)
            for case in CASES:
                with self.subTest(case=case):
                    want = run(["go", "run", case + ".go"], cwd=os.path.join(GOLDEN, case))
                    got = run(["dart", "run", os.path.join("lib", case + ".dart")], cwd=tmp)
                    self.assertEqual(want, got)


if __name__ == "__main__":
    unittest.main()
