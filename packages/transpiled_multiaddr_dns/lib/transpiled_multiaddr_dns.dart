// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `multiformats/go-multiaddr-dns`.
library;

export 'src/dns_resolver.dart'
    show BasicResolver, MockResolver, Resolver, dnsMatches, fqdn, isFqdn;
