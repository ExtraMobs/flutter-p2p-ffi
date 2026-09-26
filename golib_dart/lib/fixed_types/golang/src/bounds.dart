// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Erro de limites com a mensagem do runtime Go (sem o prefixo
/// "runtime error: "), igual em todas as plataformas — a indexação de
/// typed data lança RangeError na VM e IndexError no JS.
final class BoundsError extends RangeError {
  BoundsError(this.goMessage) : super(goMessage);

  final String goMessage;
}

/// Índice ou contagem Go fora de ±2^53 (`IntBase.toIndex`): o int devolvido é
/// um destes sentinelas, com o sinal do valor e fora de qualquer intervalo
/// válido (exatos também no JS); o texto exato do valor fica guardado para a
/// mensagem do panic ([indexText]).
const int bigIndexPos = 18014398509481984; // 2^54
const int bigIndexNeg = -18014398509481984;
String _bigIndexText = '';

/// Sentinela de um índice fora de ±2^53, guardando o texto do valor.
int bigIndex(String text, {required bool negative}) {
  _bigIndexText = text;
  return negative ? bigIndexNeg : bigIndexPos;
}

/// O índice como o Go o escreve na mensagem do panic.
String indexText(int i) =>
    i == bigIndexPos || i == bigIndexNeg ? _bigIndexText : '$i';

/// ` with length n` / ` with capacity n` da mensagem do Go, que some quando o
/// índice é negativo (`boundsNegErrorFmt` do runtime).
String withBound(int i, String what, int n) => i < 0 ? '' : ' with $what $n';

/// `[low:high]` da mensagem do Go; low negativo sai como `[low:]`.
String lowHigh(int low, int high) =>
    low < 0 ? '[${indexText(low)}:]' : '[${indexText(low)}:${indexText(high)}]';
