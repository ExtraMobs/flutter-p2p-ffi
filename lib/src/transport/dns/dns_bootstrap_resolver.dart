// lib/src/transport/dns/dns_bootstrap_resolver.dart
//
// Platform-conditional factory for the DNS resolver used to resolve
// `/dnsaddr/`, `/dns4/`, `/dns6/`, and `/dns/` bootstrap multiaddrs before
// dialing them (see bootstrap_handler.dart). Mirrors the conditional-export
// pattern already used by network_handler.dart for io vs. web.
export 'dns_bootstrap_resolver_io.dart'
    if (dart.library.html) 'dns_bootstrap_resolver_web.dart';
