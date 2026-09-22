// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Esquema lógico net.Golang, importado com prefixo Golang.
///
/// Espelha os tipos de endereço do pacote `net` do stdlib Go (go1.25.7), que
/// não pertence a nenhum dos módulos `go.mod` transpilados — é exceção
/// deliberada, como o resto de `boilerplate`. Existe separado de
/// `net_netip/` porque a semântica difere onde importa: `net.IP` dobra um
/// endereço IPv4 mapeado na sua forma IPv4 antes de imprimir e de comparar, de
/// modo que `10.0.0.0/8` contém `::ffff:10.1.2.3`, enquanto
/// `netip.Prefix.contains` recusa o mesmo par. `conngater.go` depende do
/// primeiro comportamento e `conn_limiter.go` do segundo.
library;

export 'golang/ip.dart';
export 'golang/ip_net.dart';
