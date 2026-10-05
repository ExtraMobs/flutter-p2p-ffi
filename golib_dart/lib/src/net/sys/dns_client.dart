/// Cliente DNS mínimo para TXT sobre o próprio motor (UDP, com retomada por
/// TCP quando a resposta vem truncada): o laço `lookup`/`tryOneName` do
/// resolvedor puro do Go (`net/dnsclient_unix.go`), só para TXT. A VM usa
/// isto porque o `dart:io` não consulta TXT; o Node tem `dns.resolveTxt`.
library;

import 'dart:math';
import 'dart:typed_data';

import 'common.dart';
import 'dns_msg.dart';
import 'resolv_conf.dart';

final _rand = Random();

/// O que o cliente precisa do motor (passado por quem o usa, para não
/// depender de qual implementação está ativa).
typedef DnsTransport = ({
  Future<SysUdpConn> Function(SysAddr local) listenUdp,
  Future<SysTcpConn> Function(SysAddr remote, DateTime deadline) dialTcp,
});

/// `LookupTXT(name)` contra [conf] (ou só [server], se dado).
Future<List<String>> dnsLookupTxt(
  String name,
  ResolvConf conf,
  DnsTransport io, {
  SysAddr? server,
}) async {
  final servers = server != null ? [(server.ip, server.port)] : conf.servers;
  final names = server != null && !name.endsWith('.')
      ? ['$name.']
      : conf.nameList(name);
  SysDnsError? lastErr;
  for (final fqdn in names) {
    try {
      return await _tryOneName(fqdn, conf, servers, io);
    } on SysDnsError catch (e) {
      lastErr = e;
    }
  }
  // O Go mostra o nome original, não o com sufixo de busca.
  final e = lastErr ?? SysDnsError.notFound(name);
  return Future.error(
    SysDnsError(
      name,
      e.message,
      server: e.server,
      isNotFound: e.isNotFound,
      isTimeout: e.isTimeout,
      isTemporary: e.isTemporary,
    ),
  );
}

Future<List<String>> _tryOneName(
  String fqdn,
  ResolvConf conf,
  List<(Uint8List, int)> servers,
  DnsTransport io,
) async {
  if (encodeDnsName(fqdn) == null) throw SysDnsError.notFound(fqdn);
  SysDnsError? lastErr;
  for (var attempt = 0; attempt < conf.attempts; attempt++) {
    for (final (ip, port) in servers) {
      final srv = SysAddr(ip, port).toString();
      final DnsResponse r;
      try {
        r = await _exchange(SysAddr(ip, port), fqdn, conf.timeout, io);
      } on SysTimeout {
        lastErr = SysDnsError(
          fqdn,
          'i/o timeout',
          server: srv,
          isTimeout: true,
          isTemporary: true,
        );
        continue;
      } on SysException catch (e) {
        lastErr = SysDnsError(fqdn, '$e', server: srv, isTemporary: true);
        continue;
      } on FormatException {
        lastErr = SysDnsError(fqdn, 'server misbehaving', server: srv);
        continue;
      }
      // `checkHeader` do Go.
      if (r.rcode == dnsRcodeNameError) {
        // O nome não existe: outro servidor não vai mudar isso.
        throw SysDnsError.notFound(fqdn, server: srv);
      }
      if (r.rcode == dnsRcodeServerFailure) {
        lastErr = SysDnsError(
          fqdn,
          'server misbehaving',
          server: srv,
          isTemporary: true,
        );
        continue;
      }
      if (r.rcode != dnsRcodeSuccess) {
        lastErr = SysDnsError(fqdn, 'server misbehaving', server: srv);
        continue;
      }
      if (!r.authoritative && !r.recursionAvailable && r.answerCount == 0) {
        lastErr = SysDnsError(fqdn, 'lame referral', server: srv);
        continue;
      }
      // `skipToAnswer`: sem registro do tipo é "no such host".
      if (r.txt.isEmpty) throw SysDnsError.notFound(fqdn, server: srv);
      return r.txt;
    }
  }
  throw lastErr ?? SysDnsError.notFound(fqdn);
}

Future<DnsResponse> _exchange(
  SysAddr server,
  String fqdn,
  Duration timeout,
  DnsTransport io,
) async {
  final deadline = DateTime.now().add(timeout);
  final id = _rand.nextInt(0x10000);
  final query = buildDnsQuery(id, fqdn, dnsTypeTxt)!;
  final want = fqdn.toLowerCase();
  bool matches(DnsResponse r) =>
      r.isResponse && r.id == id && r.question == want && r.qtype == dnsTypeTxt;

  final udp = await io.listenUdp(
    SysAddr(Uint8List(ipTo4(server.ip) != null ? 4 : 16), 0),
  );
  DnsResponse? resp;
  try {
    udp.readDeadline = deadline;
    udp.writeDeadline = deadline;
    await udp.writeTo(query, server);
    final buf = Uint8List(1232);
    while (resp == null) {
      final (n, from) = await udp.readFrom(buf);
      if (from.port != server.port) continue;
      final DnsResponse r;
      try {
        r = DnsResponse.parse(Uint8List.sublistView(buf, 0, n));
      } on FormatException {
        continue; // O Go ignora a resposta malformada e segue esperando.
      }
      if (matches(r)) resp = r;
    }
  } finally {
    udp.close();
  }
  if (!resp.truncated) return resp;

  // Truncada: refaz por TCP (prefixo de 2 bytes com o tamanho).
  final tcp = await io.dialTcp(server, deadline);
  try {
    tcp.readDeadline = deadline;
    tcp.writeDeadline = deadline;
    final framed = Uint8List(query.length + 2)
      ..[0] = query.length >> 8
      ..[1] = query.length & 0xff
      ..setRange(2, query.length + 2, query);
    await tcp.write(framed);
    final len = await _readFull(tcp, 2);
    final msg = await _readFull(tcp, (len[0] << 8) | len[1]);
    final r = DnsResponse.parse(msg);
    if (!matches(r)) throw const FormatException('resposta trocada');
    return r;
  } finally {
    tcp.close();
  }
}

Future<Uint8List> _readFull(SysTcpConn c, int n) async {
  final out = Uint8List(n);
  var got = 0;
  while (got < n) {
    final chunk = Uint8List(n - got);
    final k = await c.read(chunk);
    if (k == 0) throw const FormatException('EOF no meio da resposta');
    out.setRange(got, got + k, chunk);
    got += k;
  }
  return out;
}
