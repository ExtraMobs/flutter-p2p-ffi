// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Esquema lógico internal_poll.Golang, importado com prefixo Golang.
///
/// Adaptação da semântica de tempo de vida e concorrência que o `net.Conn` do
/// Go oferece e o `Socket` do `dart:io` não: fechar durante uma escrita em voo.
/// Espelha `internal/poll` do stdlib Go, que não pertence a nenhum dos módulos
/// `go.mod` transpilados — é exceção deliberada, como o resto de `boilerplate`.
library;

export 'golang/errors.dart';
export 'golang/fd.dart';
export 'golang/fd_mutex.dart';
