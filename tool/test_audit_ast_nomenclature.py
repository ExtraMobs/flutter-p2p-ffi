#!/usr/bin/env python3
"""
tool/test_audit_ast_nomenclature.py

Teste autônomo (sem pytest) para tool/audit_ast_nomenclature.py. Roda como:

    python tool/test_audit_ast_nomenclature.py

Sai com código 0 em sucesso, e levanta AssertionError (código != 0) na
primeira falha. Duas partes:

  1. Os helpers de string puros (sem `re`) contra uma tabela fixa de
     entradas/saídas -- essas expectativas foram calculadas rodando as
     expressões regulares ORIGINAIS uma vez sobre cada entrada (ver
     tool/audit_ast_nomenclature.py, seção "Helpers de string puros" para a
     regex equivalente de cada helper), não rederivadas da nova implementação.
  2. Um miniprojeto Dart temporário, processado pela ferramenta real
     tool/dart_ast_facts.dart (cwd = raiz real do repositório, para resolver
     package:analyzer via o pubspec/.dart_tool daqui), e auditado por um
     AstNomenclatureAuditor apontado para o diretório temporário com Go
     pulado (skip_go=True).
"""

import subprocess
import sys
import tempfile
from pathlib import Path

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

sys.path.insert(0, str(Path(__file__).resolve().parent))

import audit_ast_nomenclature as m  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent

failures = []


def check(label, condition):
    if not condition:
        failures.append(label)
        print(f"FALHOU: {label}")
    else:
        print(f"ok: {label}")


# ---------------------------------------------------------------------------
# Parte 1: helpers de string contra tabela fixa (valores computados rodando
# a regex original uma vez sobre cada entrada -- ver docstrings das funções
# correspondentes em audit_ast_nomenclature.py para a regex de referência).
# ---------------------------------------------------------------------------

def test_split_words():
    cases = [
        ('idFromP2pAddr', ['id', 'From', 'P2p', 'Addr']),
        ('HTTPServer', ['HTTP', 'Server']),
        ('P2P', ['P2P']),
        ('tempAddrTTL', ['temp', 'Addr', 'TTL']),
        ('ABCdef', ['AB', 'Cdef']),
        ('simple', ['simple']),
        ('IpfsNode', ['Ipfs', 'Node']),
        ('snake_case_name', ['snake', 'case', 'name']),
    ]
    for input_, expected in cases:
        check(f"split_words({input_!r})", m.split_words(input_) == expected)


def test_check_all_caps_block():
    cases = [
        ('IpfsNode', None),
        ('IPFSNode', 'IPFSN'),  # [A-Z]{2,} greedily eats the whole "IPFSN" run (the "e" in Node never gets a chance)
        ('idFromP2PAddr', 'PA'),  # [A-Z]{2,} matches "PA" (the two adjacent uppercase letters) before the [A-Z]\d+[A-Z] branch is ever tried
        ('idFromP2pAddr', None),
        ('simple', None),
        ('A1B2C3', 'A1B'),  # no 2+ ADJACENT uppercase letters, so falls through to [A-Z]\d+[A-Z]
    ]
    for input_, expected in cases:
        check(f"check_all_caps_block({input_!r})", m.check_all_caps_block(input_) == expected)


def test_is_screaming_snake_case():
    cases = [
        ('MAX_PACKET_SIZE', True),
        ('maxPacketSize', False),
        ('FOO', False),
        ('FOO_BAR', True),
        ('FOO__BAR', False),
        ('_FOO_BAR', False),
        ('FOO_', False),
        ('123_456', True),
    ]
    for input_, expected in cases:
        check(f"is_screaming_snake_case({input_!r})", m.is_screaming_snake_case(input_) == expected)


def test_has_new_prefix():
    cases = [('newFoo', True), ('new', False), ('newx', False), ('NewFoo', False), ('newFooBar', True)]
    for input_, expected in cases:
        check(f"has_new_prefix({input_!r})", m.has_new_prefix(input_) == expected)


def test_strip_error_suffix():
    cases = [
        ('ErrTooShort', 'ErrTooShort'),  # no trailing Error/Err/Failure suffix
        ('TooShortError', 'TooShort'),
        ('SomeErr', 'Some'),
        ('SomeFailure', 'Some'),
        ('Plain', 'Plain'),
    ]
    for input_, expected in cases:
        check(f"strip_error_suffix({input_!r})", m.strip_error_suffix(input_) == expected)


def test_is_mock_like_name():
    cases = [
        ('MockClient', True), ('ClientMock', True), ('DummyX', True),
        ('StubY', True), ('FakeZ', True), ('PlaceholderW', True),
        ('RealClient', False),
    ]
    for input_, expected in cases:
        check(f"is_mock_like_name({input_!r})", m.is_mock_like_name(input_) == expected)


def test_is_concurrency_word():
    cases = [('Chan', True), ('Mutex', True), ('WaitGroup', True), ('GoChannel', True),
             ('ChanFoo', False), ('FooMutex', False)]
    for input_, expected in cases:
        check(f"is_concurrency_word({input_!r})", m.is_concurrency_word(input_) == expected)


def test_strip_bracket_segments():
    cases = [
        ('AddrsManager [Atomic Audit - foo]', 'AddrsManager'),
        ('a [b] c [d]', 'a  c'),
        ('no brackets here', 'no brackets here'),
    ]
    for input_, expected in cases:
        check(f"strip_bracket_segments({input_!r})", m.strip_bracket_segments(input_) == expected)


def test_strip_test_name_brackets():
    cases = [
        ('operator []', 'operator []'),
        ('operator []=', 'operator []='),
        ('[skip] something', 'something'),
        ('no brackets here', 'no brackets here'),
    ]
    for input_, expected in cases:
        check(f"strip_test_name_brackets({input_!r})", m.strip_test_name_brackets(input_) == expected)


def test_match_qualified_prefix():
    check("match_qualified_prefix('Foo.bar')", m.match_qualified_prefix('Foo.bar') == ('Foo', 4))
    check("match_qualified_prefix('arquivo.go:88')", m.match_qualified_prefix('arquivo.go:88') == ('arquivo', 8))
    check("match_qualified_prefix('no dot here')", m.match_qualified_prefix('no dot here') is None)


def test_strip_leading_test_keyword():
    cases = [
        ('getter foo', 'foo'),
        ('get x', 'x'),
        ('GET x', 'x'),
        ('getterX', 'getterX'),  # no whitespace after keyword -> unchanged
        ('method z desc', 'z desc'),
    ]
    for input_, expected in cases:
        check(f"strip_leading_test_keyword({input_!r})", m.strip_leading_test_keyword(input_) == expected)


def test_find_operator_member():
    cases = [
        ('operator ==', 'operator =='),
        ('operator[]', 'operator[]'),  # \s* allows zero spaces; re.sub(r'\s+',' ',...) never INSERTS a space where none existed
        ('operator []=', 'operator []='),
        ('no operator token here', None),
    ]
    for input_, expected in cases:
        check(f"find_operator_member({input_!r})", m.find_operator_member(input_) == expected)


def test_strip_parens_and_after():
    cases = [
        ('foo() bar baz', 'foo'),
        ('no parens', 'no parens'),
        ('unterminated( paren', 'unterminated( paren'),
    ]
    for input_, expected in cases:
        check(f"strip_parens_and_after({input_!r})", m.strip_parens_and_after(input_) == expected)


def test_is_weak_matcher():
    cases = [
        ('isNotNull', True), ('returnsNormally', True), ('isA<Foo>()', True),
        ('isA<Foo>( )', True), ('equals(1)', False), ('isTrue', False),
    ]
    for input_, expected in cases:
        check(f"is_weak_matcher({input_!r})", m.is_weak_matcher(input_) == expected)


# ---------------------------------------------------------------------------
# Parte 2: miniprojeto Dart real, processado pela ferramenta de fatos real.
# ---------------------------------------------------------------------------

DEMO_LIB = '''\
library demo;

sealed class Shape {}

extension type Meters(int value) {}

// Literal com indexação de mapa dentro de interpolação de string --
// regressão: o extrator antigo (varredura de texto) podia se confundir com
// as chaves aqui dentro. O extrator novo usa a AST, então não pode.
const oddString = '${{1: 2}[1]}';

class AfterOddString {}

class _Priv {
  _Priv();
}

class WidgetHolder {
  _Priv
      exposed = _Priv();
}

(int, Exception?) risky() {
  return (1, null);
}

void doPrintInString() {
  final s = 'print(x)';
  if (s.isNotEmpty) {
    return;
  }
}

void doRealPrint() {
  print(1);
}
'''

DEMO_TEST = '''\
import 'package:test/test.dart';

void main() {
  group('Demo [Atomic Audit]', () {
    test('weakCheckedThing() - tautological only', () {
      expect(true, isTrue);
    });

    test('realCheckedThing() - has a real assertion', () {
      final result = 1 + 1;
      expect(result, equals(2));
    });
  });
}
'''


def build_mini_project(tmp: Path) -> Path:
    demo_pkg = tmp / 'packages' / 'transpiled_demo' / 'lib'
    demo_pkg.mkdir(parents=True, exist_ok=True)
    (demo_pkg / 'demo.dart').write_text(DEMO_LIB, encoding='utf-8')

    test_dir = tmp / 'test' / 'atomic' / 'nivel_1'
    test_dir.mkdir(parents=True, exist_ok=True)
    (test_dir / 'demo_atomic_tests.dart').write_text(DEMO_TEST, encoding='utf-8')

    return tmp


def run_mini_project_checks():
    with tempfile.TemporaryDirectory(prefix='audit_mini_') as tmp_str:
        tmp = Path(tmp_str)
        build_mini_project(tmp)

        facts_path = tmp / 'facts.json'
        dart_exe = m._find_executable('dart')
        result = subprocess.run(
            [dart_exe, 'run', 'tool/dart_ast_facts.dart', '--root', str(tmp), '--out', str(facts_path)],
            cwd=str(REPO_ROOT), capture_output=True, text=True,
        )
        check("dart_ast_facts.dart executa com sucesso no miniprojeto",
              result.returncode == 0 and facts_path.exists())
        if result.returncode != 0:
            print(result.stdout)
            print(result.stderr)
            return

        auditor = m.AstNomenclatureAuditor(tmp, dart_facts_path=facts_path, skip_go=True)
        auditor.load_all()
        auditor.audit_rules()

        # -- extração de declarações --------------------------------------
        check("sealed class 'Shape' extraída",
              any(s.kind == 'class' and s.name == 'Shape' for s in auditor.dart_symbols))
        check("extension type 'Meters' extraída",
              any(s.kind == 'extension_type' and s.name == 'Meters' for s in auditor.dart_symbols))
        check("declaração após o literal com indexação de mapa não se perde",
              any(s.kind == 'class' and s.name == 'AfterOddString' for s in auditor.dart_symbols))

        # -- RULE_NO_GO_STYLE_ERROR_TUPLES ---------------------------------
        tuple_violations = [v for v in auditor.violations
                             if v['rule'] == 'RULE_NO_GO_STYLE_ERROR_TUPLES' and v['symbol'] == 'risky']
        check("(int, Exception?) risky() aciona RULE_NO_GO_STYLE_ERROR_TUPLES",
              len(tuple_violations) == 1)

        # -- RULE_EXPOSED_NON_PUBLIC_MEMBERS --------------------------------
        exposed_violations = [v for v in auditor.violations
                               if v['rule'] == 'RULE_EXPOSED_NON_PUBLIC_MEMBERS' and v['symbol'] == 'exposed']
        check("campo público 'exposed' com tipo '_Priv' quebrado em duas linhas aciona RULE_EXPOSED_NON_PUBLIC_MEMBERS",
              len(exposed_violations) == 1)

        # -- RULE_NO_PRINT_IN_LIBRARIES: string 'print(x)' não conta, print(1) conta
        print_violations = [v for v in auditor.violations if v['rule'] == 'RULE_NO_PRINT_IN_LIBRARIES']
        check("'print(x)' dentro de uma string não aciona RULE_NO_PRINT_IN_LIBRARIES sozinho, "
              "mas print(1) real aciona exatamente uma vez",
              len(print_violations) == 1 and print_violations[0]['file'].endswith('demo.dart'))
        if print_violations:
            demo_dart_line = DEMO_LIB.splitlines().index('  print(1);') + 1
            check("a violação de print aponta para a linha do print(1) real, não da string",
                  print_violations[0]['line'] == demo_dart_line)

        # -- Regra 24: testes atômicos -------------------------------------
        # Ambos os testes estão dentro do group('Demo [Atomic Audit]'), então
        # a classe ativa 'Demo' entra na chave (mesma regra do auditor
        # anterior: 'Classe.membro' quando há um group cujo primeiro caractere
        # é maiúsculo e não é uma palavra-chave de topo).
        all_tested, _files, _quality = auditor.scan_all_atomic_tests()
        check("test com corpo 'expect(true, isTrue)' (tautológico) NÃO conta como testado",
              'weakCheckedThing' not in all_tested and 'Demo.weakCheckedThing' not in all_tested)
        check("test com asserção real conta como testado",
              'Demo.realCheckedThing' in all_tested)


def main():
    test_split_words()
    test_check_all_caps_block()
    test_is_screaming_snake_case()
    test_has_new_prefix()
    test_strip_error_suffix()
    test_is_mock_like_name()
    test_is_concurrency_word()
    test_strip_bracket_segments()
    test_strip_test_name_brackets()
    test_match_qualified_prefix()
    test_strip_leading_test_keyword()
    test_find_operator_member()
    test_strip_parens_and_after()
    test_is_weak_matcher()

    run_mini_project_checks()

    if failures:
        print(f"\n{len(failures)} FALHA(S):")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print("\nTodos os testes passaram.")
    sys.exit(0)


if __name__ == '__main__':
    main()
