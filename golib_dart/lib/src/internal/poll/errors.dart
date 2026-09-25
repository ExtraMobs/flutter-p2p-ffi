// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages

/// Erro devolvido quando um descritor de rede é usado depois de fechado.
///
/// Port de `internal/poll.ErrNetClosing`. O texto é preservado literalmente por
/// exigência explícita do upstream, que documenta o motivo:
///
/// > Keep this string consistent because of issue #4373: since historically
/// > programs have not been able to detect this error, they look for the string.
///
/// É o equivalente do que `net.ErrClosed` expõe ao chamador, e o sinal que o
/// `Socket` do `dart:io` não tem como produzir: lá, fechar durante uma escrita
/// pendente lança `StateError('StreamSink is bound to a stream')`, que descreve
/// um detalhe interno do sink em vez do fato de a conexão ter sido fechada.
final class NetClosingException implements Exception {
  const NetClosingException();

  @override
  String toString() => 'use of closed network connection';
}

/// Erro devolvido quando um descritor de arquivo é usado depois de fechado.
///
/// Port de `internal/poll.ErrFileClosing`.
final class FileClosingException implements Exception {
  const FileClosingException();

  @override
  String toString() => 'use of closed file';
}

/// Erro devolvido quando um prazo expira.
///
/// Port de `internal/poll.ErrDeadlineExceeded`. O `RawSocket` do `dart:io` não
/// tem API de prazo — confirmado no source do SDK, que não declara nada como
/// `setWriteDeadline` —, então prazos, quando existirem, são construídos sobre
/// temporizadores e sinalizam a expiração com este erro.
final class DeadlineExceededException implements Exception {
  const DeadlineExceededException();

  @override
  String toString() => 'i/o timeout';
}

/// Seleciona o sentinela conforme o descritor seja arquivo ou rede.
///
/// Port de `internal/poll.errClosing`.
Exception errClosing({required bool isFile}) =>
    isFile ? const FileClosingException() : const NetClosingException();
