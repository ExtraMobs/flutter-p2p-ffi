// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Shim de `net/netip` (stdlib Go). Origem: boilerplate `net_netip/golang.dart`.
///
/// Espelha `net/netip` do stdlib Go (go1.25.7), que não pertence a nenhum dos
/// módulos `go.mod` transpilados — é exceção deliberada, como o resto de
/// `boilerplate`. Existe porque `conn_limiter.go`, `conn_rate_limiter.go` e
/// `x/rate/limiter.go` fazem aritmética de prefixo de sub-rede, e sem um tipo
/// comum cada um deles reimplementaria máscara de /56 e /48 à mão.
library;

export '../src/net/netip/addr.dart';
export '../src/net/netip/prefix.dart';
