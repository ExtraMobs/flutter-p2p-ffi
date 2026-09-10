// lib/src/transport/dns/udp_dns_client.dart
//
// Sends a DNS query over UDP to a resolver and waits for the matching
// reply. `dart:io` has no OS-resolver-discovery API, so (like most portable
// DNS clients without native OS integration) this targets a configurable
// list of resolvers, defaulting to Cloudflare and Google's public
// resolvers.
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'dns_message.dart';

/// Default fallback resolvers, tried in order.
const List<String> defaultDnsResolvers = ['1.1.1.1', '8.8.8.8'];

const int _dnsPort = 53;

/// A minimal RFC 1035 DNS client over UDP, for the record types
/// [DnsRecordType] covers.
class UdpDnsClient {
  /// Builds a client trying [resolvers] in order, each up to
  /// [attemptsPerResolver] times, waiting up to [timeout] per attempt.
  UdpDnsClient({
    List<String> resolvers = defaultDnsResolvers,
    this.timeout = const Duration(seconds: 5),
    this.attemptsPerResolver = 2,
  }) : resolvers = List.unmodifiable(resolvers);

  /// Resolver IPv4/IPv6 addresses to query, in order.
  final List<String> resolvers;

  /// Per-attempt response wait before retrying or moving to the next
  /// resolver.
  final Duration timeout;

  /// Retries per resolver before moving to the next one.
  final int attemptsPerResolver;

  final Random _rng = Random.secure();

  /// Queries every configured resolver in turn (retrying each up to
  /// [attemptsPerResolver] times on timeout) until one replies, and returns
  /// its records of [type] for [name]. Throws [TimeoutException] if no
  /// resolver replies at all, or [FormatException]/[SocketException] for
  /// malformed replies or transport errors on the last attempt.
  Future<List<DnsRecord>> lookup(String name, int type) async {
    Object? lastError;
    for (final resolver in resolvers) {
      for (var attempt = 0; attempt < attemptsPerResolver; attempt++) {
        try {
          final response = await _query(resolver, name, type);
          if (response.rcode != 0) {
            // NXDOMAIN (3) and similar are "no records", not transport
            // failures -- matches net.LookupTXT returning an empty result
            // rather than erroring for a domain with no TXT records.
            return const [];
          }
          return response.records.where((r) => r.type == type).toList();
        } on TimeoutException catch (e) {
          lastError = e;
          continue;
        } catch (e) {
          lastError = e;
          break; // don't retry non-timeout errors against the same resolver.
        }
      }
    }
    if (lastError is TimeoutException) throw lastError;
    if (lastError != null) throw lastError;
    throw TimeoutException('no DNS resolver could be reached');
  }

  Future<DnsResponse> _query(String resolver, String name, int type) async {
    final id = _rng.nextInt(0x10000);
    final query = encodeDnsQuery(id: id, name: name, type: type);

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.send(query, InternetAddress(resolver), _dnsPort);

      final completer = Completer<DnsResponse>();
      late final StreamSubscription<RawSocketEvent> sub;
      sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        DnsResponse response;
        try {
          response = decodeDnsMessage(datagram.data);
        } on FormatException {
          return; // ignore malformed/unrelated datagrams, keep waiting.
        }
        if (response.id != id) return; // not our query's reply.
        if (!completer.isCompleted) completer.complete(response);
      });

      try {
        return await completer.future.timeout(timeout);
      } finally {
        await sub.cancel();
      }
    } finally {
      socket.close();
    }
  }
}
