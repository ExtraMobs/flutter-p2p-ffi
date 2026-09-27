/// Shim do pacote Go `unicode`: predicados e conversões de caixa sobre as
/// tabelas Unicode reais do Go (`Categories`, `Scripts`, `Properties`,
/// `CaseRanges`), incluindo `RangeTable`/`Range16`/`Range32` como structs de
/// shim (`go.GoStruct`, como `bytes.Buffer`) para aceitar tanto os literais
/// compostos quanto o acesso a campo que o g2d emite para tipos nomeados de
/// qualquer pacote (`services/types.py` não distingue shim de pacote do
/// grafo). As tabelas em `src/unicode/tables.g.dart` são geradas por
/// `tool/gen_unicode*.go` a partir do `unicode` do Go instalado; o teste
/// `test/unicode_tables_test.dart` confere as duas coisas: o arquivo gerado
/// está em dia, e os predicados/conversões batem com o oráculo Go varrendo
/// 0..0x10FFFF.
// ignore_for_file: library_prefixes
library;

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;

part 'src/unicode/range_table.dart';
part 'src/unicode/predicates.dart';
part 'src/unicode/tables.g.dart';
