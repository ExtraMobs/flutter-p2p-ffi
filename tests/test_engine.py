"""Motor do g2d: registros, injeção de comportamentos e plugins."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

from g2d.behaviors.plugins import DEFAULT_PLUGINS, CollectionsPlugin
from g2d.engine import Engine
from g2d.engine.behavior import NOT_HANDLED, BuiltinBehavior, ExprBehavior, Plugin
from g2d.engine.precedence import POSTFIX
from g2d.engine.registry import ChainRegistry, HandlerRegistry
from g2d.model import Unsupported, link_packages, parse_dump
from g2d.services.naming import Naming

GOLDEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "golden")
GOAST = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools", "goast")


def load(case):
    with open(os.path.join(GOLDEN, case, case + ".goast.json"), encoding="utf-8") as f:
        (pkg,) = parse_dump(json.load(f))
    return pkg


def dump_source(src):
    """Pacote de um fonte Go avulso, via goast (modo loose)."""
    with tempfile.TemporaryDirectory() as tmp:
        with open(os.path.join(tmp, "main.go"), "w", encoding="utf-8") as f:
            f.write(src)
        out = subprocess.run(["go", "run", ".", "dump", tmp], cwd=GOAST, capture_output=True,
                             text=True, encoding="utf-8", check=True).stdout
    (pkg,) = parse_dump(json.loads(out))
    return pkg


class Fixed:
    def __init__(self, value):
        self.value = value

    def emit(self, *args):
        return self.value


class RegistryTest(unittest.TestCase):
    def test_last_registered_wins(self):
        r = HandlerRegistry()
        r.register("k", Fixed("antigo"))
        r.register("k", Fixed("novo"))
        self.assertEqual(r.dispatch("k"), "novo")

    def test_not_handled_falls_back(self):
        r = HandlerRegistry()
        r.register("k", Fixed("base"))
        r.register("k", Fixed(NOT_HANDLED))
        self.assertEqual(r.dispatch("k"), "base")
        self.assertIs(r.dispatch("outra"), NOT_HANDLED)

    def test_chain_prefers_last_accepting(self):
        class Accepts:
            def __init__(self, ok, tag):
                self.ok, self.tag = ok, tag

            def accepts(self, *_):
                return self.ok

        c = ChainRegistry()
        c.register(Accepts(True, "primeiro"))
        c.register(Accepts(False, "recusa"))
        c.register(Accepts(True, "último"))
        self.assertEqual(c.find().tag, "último")


class LenAsCall(BuiltinBehavior):
    """Substitui `len`: sempre trata."""

    name = "len"

    def emit(self, n, args):
        return f"lenOf({self.expr(args[0])})", POSTFIX


class PrintlnAsPrint(ExprBehavior):
    """Especializa CallExpr só para fmt.Println; o resto cai no padrão."""

    kinds = ("CallExpr",)

    def emit(self, n):
        fun = n["fun"]
        if not (fun["node"] == "SelectorExpr" and fun["sel"]["name"] == "Println"):
            return NOT_HANDLED
        return f"print([{', '.join(self.expr(a) for a in n['args'] or [])}])", POSTFIX


class TestPlugin(Plugin):
    def install(self, engine):
        engine.register_builtin(LenAsCall)
        engine.register_expr(PrintlnAsPrint)


class InjectionTest(unittest.TestCase):
    def test_default_is_unchanged(self):
        out = Engine(load("hello")).emit_package()
        self.assertIn("fmt.println(", out)

    def test_plugin_replaces_and_specializes(self):
        out = Engine(load("basics"), plugins=[*DEFAULT_PLUGINS, TestPlugin()]).emit_package()
        self.assertIn("lenOf(", out)  # builtin substituído
        self.assertIn("print([", out)  # CallExpr especializado para Println
        self.assertNotIn("fmt.println(", out)
        self.assertIn("_divmod(", out)  # demais chamadas: comportamento padrão

    def test_behavior_comes_from_plugin(self):
        plugins = [p for p in DEFAULT_PLUGINS if not isinstance(p, CollectionsPlugin)]
        with self.assertRaises(Unsupported):
            Engine(load("collections"), plugins=plugins).emit_package()

    def test_service_can_be_replaced(self):
        class LoudNaming(Naming):
            def temp(self):
                self.scope.temps += 1
                return f"$tmp{self.scope.temps}"

        engine = Engine(load("basics"))
        engine.services.replace(LoudNaming(engine))
        out = engine.emit_package()
        self.assertIn("$tmp1", out)
        self.assertNotIn("$t1 ", out)


@unittest.skipUnless(shutil.which("go"), "go ausente")
class UnsupportedTest(unittest.TestCase):
    """Código estável e posição real (a auditoria agrupa e localiza por eles)."""

    def emit_error(self, src):
        with self.assertRaises(Unsupported) as cm:
            Engine(dump_source(src)).emit_package()
        e = cm.exception
        return e.code, (e.pos["file"], e.pos["line"], e.pos["column"]) if e.pos else None

    def test_node_position(self):
        src = 'package main\n\nfunc main() {\n\tm := map[string]int{}\n\tm[g()] += 1\n}\n\nfunc g() string { return "" }\n'
        self.assertEqual(self.emit_error(src), ("opassign-impuro", ("main.go", 5, 2)))

    def test_falls_back_to_declaration(self):
        src = 'package main\n\nimport "unicode/utf16"\n\nvar E = utf16.IsSurrogate(120)\n\nfunc main() { _ = E }\n'
        self.assertEqual(self.emit_error(src), ("shim-ausente:unicode/utf16", ("main.go", 5, 5)))

    def test_doc_comment_is_not_the_position(self):
        src = 'package main\n\nimport "unicode/utf16"\n\n// F documenta.\nfunc F() bool { return utf16.IsSurrogate(120) }\n\nfunc main() {}\n'
        self.assertEqual(self.emit_error(src), ("shim-ausente:unicode/utf16", ("main.go", 6, 6)))  # nome de F

    def test_error_inside_closure_in_loop(self):
        """O erro real sobe; antes o escopo trocado pela closure virava IndexError."""
        src = ('package main\n\nimport "unicode/utf16"\n\nfunc main() {\n\tfor _, s := range []string{"a"} {\n'
               '\t\tf := func() bool { return utf16.IsSurrogate(rune(len(s))) }\n\t\t_ = f\n\t}\n}\n')
        self.assertEqual(self.emit_error(src), ("shim-ausente:unicode/utf16", ("main.go", 5, 6)))  # decl de main

    def test_anon_struct_unexported_from_other_package(self):
        """`struct{ n int }` de outro pacote é outro tipo (o pacote do campo
        entra na identidade): a classe local seria errada, então é recusada.
        A exportada vira a classe canônica compartilhada."""
        files = {
            "go.mod": "module repro.local/mp\n\ngo 1.26\n",
            "a/a.go": "package a\n\nfunc N() struct{ n int } { return struct{ n int }{1} }\n\n"
                      "func X() struct{ X int } { return struct{ X int }{1} }\n\n"
                      "type priv int\n\nfunc P() struct{ X priv } { return struct{ X priv }{1} }\n",
            "cmd2/main.go": 'package main\n\nimport "repro.local/mp/a"\n\nfunc main() {\n\tv := a.P()\n\t_ = v\n}\n',
            "cmd/main.go": 'package main\n\nimport "repro.local/mp/a"\n\nfunc main() {\n\tv := a.N()\n\t_ = v\n}\n\n'
                           "func x() int { return a.X().X }\n",
        }
        with tempfile.TemporaryDirectory() as tmp:
            for name, src in files.items():
                os.makedirs(os.path.dirname(os.path.join(tmp, name)), exist_ok=True)
                with open(os.path.join(tmp, name), "w", encoding="utf-8") as f:
                    f.write(src)
            out = subprocess.run(["go", "run", ".", "dump", "-C", tmp, "./..."], cwd=GOAST, capture_output=True,
                                 text=True, encoding="utf-8", check=True).stdout
        pkgs = {p.path: p for p in link_packages(parse_dump(json.loads(out)))}
        a = Engine(pkgs["repro.local/mp/a"]).emit_package()
        self.assertIn("_anon$", a)  # o dono emite a local
        self.assertIn("Struct$", a)
        with self.assertRaises(Unsupported) as cm:
            Engine(pkgs["repro.local/mp/cmd"]).emit_package()
        self.assertEqual(cm.exception.code, "anonima:nao-exportada-de-outro-pacote")
        self.assertEqual(cm.exception.pos["line"], 5)  # decl de main
        with self.assertRaises(Unsupported) as cm:  # tipo nomeado não exportado no campo
            Engine(pkgs["repro.local/mp/cmd2"]).emit_package()
        self.assertEqual(cm.exception.code, "anonima:nao-exportada-de-outro-pacote")

    def test_bodyless_func(self):
        src = "package main\n\nfunc fastrand() uint64\n\nfunc main() {}\n"
        self.assertEqual(self.emit_error(src), ("func-sem-corpo", ("main.go", 3, 6)))

    def test_opassign_impure_target(self):
        """`m[f()] += 1` leria e escreveria chamando f duas vezes: recusado."""
        src = ('package main\n\nfunc f() string { return "a" }\n\n'
               'func main() {\n\tm := map[string]int{}\n\tm[f()] += 1\n}\n')
        self.assertEqual(self.emit_error(src), ("opassign-impuro", ("main.go", 7, 2)))

    def test_missing_shim_symbol(self):
        """Símbolo que o shim não tem é recusado (antes: chamada Dart inexistente)."""
        src = 'package main\n\nimport "math"\n\nfunc main() { _ = math.Hypot(3, 4) }\n'
        self.assertEqual(self.emit_error(src)[0], "shim-simbolo:math.hypot")

    def test_missing_shim_member(self):
        """Método/campo que a classe do shim não tem é recusado (antes:
        `t.format(...)` e dart analyze acusava undefined_method): chamada
        direta, via ponteiro, method value, method expression, promovido
        por embedding, `defer` e `go`."""
        head = 'package main\n\nimport "time"\n\ntype S struct{ time.Time }\n\nfunc main() {\n\tt := time.Unix(0, 0)\n\t_ = t\n'
        cases = {
            '_ = t.Format("2006")': 10,
            'p := &t\n\t_ = p.Format("2006")': 11,
            'f := t.Format\n\t_ = f': 10,
            '_ = time.Time.Format': 10,
            'var s S\n\t_ = s.Format("2006")': 11,
            'defer t.Format("2006")': 10,
            'go t.Format("2006")': 10,
        }
        for body, line in cases.items():
            with self.subTest(body=body):
                code, pos = self.emit_error(head + "\t" + body + "\n}\n")
                self.assertEqual(code, "shim-simbolo:time.Time.format")
                self.assertEqual(pos[1], line)

    def test_shim_members_present(self):
        """Membros que o shim tem passam: herdados da base (`Duration` sobre
        `Int64Base`), promovidos, via ponteiro, campos, tipo não exportado
        com classe pública (`binary.BigEndian`), alias Go (`os.PathError` é
        `fs.PathError`) e métodos chamados via interface da stdlib."""
        src = ('package main\n\nimport (\n\t"encoding/binary"\n\t"fmt"\n\t"io"\n\t"os"\n\t"strings"\n\t"sync"\n\t"sync/atomic"\n\t"time"\n)\n\n'
               'type S struct{ time.Time }\n\n'
               'func main() {\n\tt := time.Unix(0, 0)\n\tp := &t\n\tvar s S\n'
               '\tfmt.Println(t.Unix(), p.Unix(), s.Unix(), s.Time.Unix(), time.Second.Seconds(), t.String())\n'
               '\tf := t.Unix\n\tfmt.Println(f(), binary.BigEndian.Uint32([]byte{0, 0, 0, 1}))\n'
               '\te := &os.PathError{Op: "x"}\n\tfmt.Println(e.Op, e.Error())\n'
               '\tvar st fmt.Stringer = t\n\tvar w io.Writer = os.Stdout\n\tw.Write([]byte(st.String()))\n'
               '\tvar b strings.Builder\n\tb.WriteString("x")\n\tfmt.Println(b.String(), b.Len())\n'
               '\tvar ap atomic.Pointer[int]\n\tvar ai atomic.Int64\n\tvar m sync.Map\n'
               '\tm.Store(1, 2)\n\tfmt.Println(ap.Load(), ai.Add(1))\n}\n')
        Engine(dump_source(src)).emit_package()

    def test_fmt_verbs_refused_at_transpile_time(self):
        """Verbo que o shim fmt não formata vira Unsupported na transpilação
        (antes: UnimplementedError só em runtime, audit verde)."""
        cases = {
            'fmt.Printf("%#v", main)': "fmt-verbo:%#v-func",
            'x := 1; fmt.Printf("%#v", &x)': "fmt-verbo:%#v-ponteiro",
            'fmt.Printf("%#v", []func(){})': "fmt-verbo:%#v-func",
            'type T struct{ C chan int }; fmt.Printf("%#v", T{})': "fmt-verbo:%#v-chan",
            'fmt.Printf("%x", 1.5)': "fmt-verbo:%x-float",
            'c := complex(1, 2); fmt.Printf("%d", c)': "fmt-verbo:%d-complex",
            'fmt.Printf("%T", []int{1})': "fmt-verbo:%T-composto",
            'fmt.Printf("%d", main)': "fmt-verbo:%d-func",
            'fmt.Printf("%d", 1, []int{2})': "fmt-verbo:extra-composto",
            'fmt.Sprintf("%[2]d %#[1]v", main, 2)': "fmt-verbo:%#v-func",
        }
        for body, code in cases.items():
            with self.subTest(body=body):
                src = f'package main\n\nimport "fmt"\n\nfunc main() {{ {body} }}\n'
                got, pos = self.emit_error(src)
                self.assertEqual(got, code)
                self.assertEqual(pos[1], 5)

    def test_fmt_verbs_accepted(self):
        src = ('package main\n\nimport "fmt"\n\ntype P struct{ X int }\n\nfunc main() {\n'
               '\tvar a any = 1.5\n\tf := "%x"\n\targs := []any{1}\n'
               '\tfmt.Printf("%+v %[1]v %x %d\\n", P{1}, a, 2)\n\tfmt.Printf(f, a)\n\tfmt.Printf("%d", args...)\n'
               '\t_ = fmt.Errorf("%w", fmt.Errorf("x"))\n'
               '\tg := 2.5\n\tfmt.Printf("%#.3g %#e %#q %#+q\\n", g, g, \'x\', \'y\')\n}\n')
        Engine(dump_source(src)).emit_package()

    def test_async_refused_contexts(self):
        """Cor async (M4) onde o Dart não tem como suspender: recusa explícita."""
        recv = "func recv(c chan int) int { return <-c }\n\n"
        cases = {
            # valor func async numa classe de formato fixo: parâmetro de shim
            # (o sort chama de forma síncrona) e parâmetro derivado de genérico
            'import "sort"\n\n' + recv + "func main() { c := make(chan int)\n"
            "\tsort.Slice([]int{1}, func(i, j int) bool { return recv(c) > 0 }) }\n": ("async:valor-func", 8),
            recv + "func apply[T any](x T, f func(T) T) T { return f(x) }\n\n"
            "func main() { _ = apply(make(chan int), func(c chan int) chan int { recv(c); return c }) }\n":
                ("async:valor-func", 7),
            # String() é chamado pelo fmt de forma síncrona
            "type T struct{ c chan int }\n\nfunc (t T) String() string { return string(rune(<-t.c)) }\n\n"
            "func main() {}\n": ("async:contexto-sincrono", 5),
            recv + "type T struct{ c chan int }\n\nfunc (t T) Error() string { recv(t.c); return \"\" }\n\n"
            "func main() {}\n": ("async:contexto-sincrono", 7),
        }
        for body, (code, line) in cases.items():
            with self.subTest(body=body):
                got, pos = self.emit_error("package main\n\n" + body)
                self.assertEqual((got, pos[1]), (code, line))

    def test_import_spec_position(self):
        src = 'package main\n\nimport _ "embed"\n\nfunc main() {}\n'
        self.assertEqual(self.emit_error(src), ("go:embed", ("main.go", 3, 8)))

    def test_main_without_graph(self):
        """main transpilado sem as dependências no dump: init incompleto
        vira erro explícito, não Dart que pula inicialização."""
        with open(os.path.join(GOLDEN, "multiinit", "multiinit.goast.json"), encoding="utf-8") as f:
            pkgs = parse_dump(json.load(f))
        (main,) = link_packages([p for p in pkgs if p.name == "main"])
        with self.assertRaises(Unsupported) as cm:
            Engine(main).emit_package()
        self.assertEqual(cm.exception.code, "init-grafo-incompleto")
        self.assertEqual(cm.exception.pos["line"], 8)  # import de .../a


if __name__ == "__main__":
    unittest.main()
