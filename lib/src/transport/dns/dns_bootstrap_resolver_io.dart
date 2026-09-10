// lib/src/transport/dns/dns_bootstrap_resolver_io.dart
import 'package:transpiled_multiaddr_dns/transpiled_multiaddr_dns.dart'
    show BasicResolver;

import 'system_resolver.dart';

/// The native (`dart:io`) DNS resolver, backed by real UDP sockets.
BasicResolver? createDnsResolver() => SystemResolver();
