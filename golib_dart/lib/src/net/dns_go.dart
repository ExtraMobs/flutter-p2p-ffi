part of '../../net.dart';

// O cliente DNS puro do Go (`dnsclient_unix.go`, `dnsclient.go`): a troca de
// mensagens por uma `Conn` (a do `Resolver.Dial`, ou a do `Dialer` padrão),
// UDP com retomada por TCP quando a resposta vem truncada, as tentativas por
// servidor e por nome da lista de busca, e os erros no formato do Go.

final GoError _errLameReferral = _errNew('lame referral');
final GoError _errCannotUnmarshalDNSMessage = _errNew(
  'cannot unmarshal DNS message',
);
final GoError _errCannotMarshalDNSMessage = _errNew(
  'cannot marshal DNS message',
);
final GoError _errServerMisbehaving = _errNew('server misbehaving');
final GoError _errInvalidDNSResponse = _errNew('invalid DNS response');
final GoError _errNoAnswerFromDNSServer = _errNew('no answer from DNS server');
final GoError _errServerTemporarilyMisbehaving = _TemporaryError(
  _gs('server misbehaving'),
);

/// `errMalformedDNSRecordsDetail`.
const _errMalformedDNSRecordsDetail =
    'DNS response contained records which contain invalid names';

final _dnsRand = Random();

/// `randInt()` (o id das consultas, o embaralhamento do SRV/MX).
int _randInt() => _dnsRand.nextInt(4294967296);

/// `randIntn(n)`.
int _randIntn(int n) => _randInt() % n;

/// Resultado de uma troca: a mensagem lida e o servidor.
typedef _DnsResult = (dns.DnsMessage, String);

/// Falha de uma etapa do cliente: o erro do Go (`*DNSError` ou outro).
final class _DnsFailure implements Exception {
  _DnsFailure(this.err);
  final GoError err;
}

DNSError _dnsErr(String err, String name, [String server = '']) =>
    DNSError(err: _gs(err), name: _gs(name), server: _gs(server));

/// `newDNSError(err, name, server)` sobre texto Dart.
DNSError _newDNSErr(GoError err, String name, [String server = '']) =>
    _newDNSError(err, _gs(name), _gs(server));

extension on Resolver {
  /// `r.dial(ctx, network, server)`: o `Dial` do Resolver ou o `Dialer`
  /// padrão.
  Future<(Conn?, GoError?)> _dialDNS(
    context.Context? ctx,
    String network,
    String server,
  ) async {
    final d = this.dial;
    final (c, err) = d != null
        ? await d(ctx, _gs(network), _gs(server))
        : await Dialer().dialContext(ctx, _gs(network), _gs(server));
    if (err != null) return (null, _mapErr(err));
    return (c, null);
  }

  /// `exchange(ctx, server, q, timeout, useTCP, ad)`.
  Future<(dns.DnsMessage?, GoError?)> _exchange(
    context.Context? ctx,
    String server,
    String name,
    int qtype,
    Duration timeout,
    bool useTCP,
    bool ad,
  ) async {
    final id = _randInt() & 0xffff;
    final req = dns.dnsNewRequest(id, name, qtype, ad: ad);
    if (req == null) return (null, _errCannotMarshalDNSMessage);
    final (udpReq, tcpReq) = req;
    for (final network in useTCP ? const ['tcp'] : const ['udp', 'tcp']) {
      final deadline = time.now().add(
        time.Duration(timeout.inMicroseconds * 1000),
      );
      final (dctx, cancel) = context.withDeadline(
        ctx ?? context.background(),
        deadline,
      );
      try {
        final (c, err) = await _dialDNS(dctx, network, server);
        if (err != null) return (null, err);
        final (d, ok) = dctx.deadline();
        if (ok && !d.isZero()) c!.setDeadline(d);
        final (dns.DnsMessage?, GoError?) rt = c is PacketConn
            ? await _dnsPacketRoundTrip(c!, id, name, qtype, udpReq)
            : await _dnsStreamRoundTrip(c!, id, name, qtype, tcpReq);
        c.close();
        final (p, rerr) = rt;
        if (rerr != null) return (null, _mapErr(rerr));
        // `p.SkipQuestion()` tem que acabar a seção: uma pergunta só.
        if (p!.questions.length != 1 || p.questionsBroken)
          return (null, _errInvalidDNSResponse);
        if (p.truncated && network == 'udp') continue;
        return (p, null);
      } finally {
        cancel();
      }
    }
    return (null, _errNoAnswerFromDNSServer);
  }

  /// `tryOneName(ctx, cfg, name, qtype)`: cada servidor, `attempts` vezes.
  Future<_DnsResult> _tryOneName(
    context.Context? ctx,
    _DnsConfig cfg,
    String name,
    int qtype,
  ) async {
    if (name.length > 255)
      throw _DnsFailure(_dnsErr('cannot marshal DNS message', name));
    GoError? lastErr;
    final off = cfg.serverOffset();
    final n = cfg.servers.length;
    for (var i = 0; i < cfg.attempts; i++) {
      for (var j = 0; j < n; j++) {
        final server = cfg.servers[(off + j) % n];
        final (p, err) = await _exchange(
          ctx,
          server,
          name,
          qtype,
          cfg.timeout,
          cfg.useTCP,
          cfg.trustAD,
        );
        if (err != null) {
          final de = _newDNSErr(err, name, server);
          // Erro de socket: temporário (o mesmo campo marca o SERVFAIL).
          if (err is OpError) de.isTemporary = true;
          lastErr = de;
          continue;
        }
        var herr = _checkHeader(p!);
        if (herr == null && p.answers.records.every((r) => r.type != qtype)) {
          // `skipToAnswer`: sem registro do tipo pedido é "no such host".
          herr = p.answers.broken
              ? _errCannotUnmarshalDNSMessage
              : _errNoSuchHost;
        }
        if (herr != null) {
          if (identical(herr, _errNoSuchHost)) {
            // O nome não existe: outro servidor não vai mudar isso.
            throw _DnsFailure(_newDNSErr(_errNoSuchHost, name, server));
          }
          lastErr = _newDNSErr(herr, name, server);
          continue;
        }
        return (p, server);
      }
    }
    throw _DnsFailure(lastErr!);
  }

  /// `lookup(ctx, name, qtype, conf)`: o nome em cada sufixo de busca.
  Future<_DnsResult> _lookupDNS(
    context.Context? ctx,
    String name,
    int qtype, [
    _DnsConfig? conf,
  ]) async {
    if (!_isDomainName(name))
      throw _DnsFailure(_newDNSErr(_errNoSuchHost, name));
    conf ??= _systemDNSConfig();
    GoError? err;
    for (final fqdn in conf.nameList(name)) {
      try {
        return await _tryOneName(ctx, conf, fqdn, qtype);
      } on _DnsFailure catch (e) {
        err = e.err;
        // StrictErrors: um erro temporário para a busca.
        if (err is Error && err.temporary() && this.strictErrors) break;
      }
    }
    // O Go mostra o nome original, não o com sufixo (golang.org/issue/6324).
    if (err is DNSError) err.name = _gs(name);
    throw _DnsFailure(err ?? _newDNSErr(_errNoSuchHost, name));
  }
}

/// `dnsPacketRoundTrip`: espera até o prazo por uma resposta que case.
Future<(dns.DnsMessage?, GoError?)> _dnsPacketRoundTrip(
  Conn c,
  int id,
  String name,
  int qtype,
  Uint8List b,
) async {
  final (_, werr) = await c.write$async(_bytes(b));
  if (werr != null) return (null, werr);
  final buf = _bytes(Uint8List(dns.maxDnsPacketSize));
  while (true) {
    final (n, err) = await c.read$async(buf);
    if (err != null) return (null, err);
    final dns.DnsMessage p;
    try {
      p = dns.DnsMessage.parse(_u8(buf, n.toInt()));
    } on FormatException {
      continue; // pode ser forjada: ignora e segue esperando
    }
    if (p.questionsBroken ||
        p.questions.isEmpty ||
        !_checkResponse(id, name, qtype, p))
      continue;
    return (p, null);
  }
}

/// `dnsStreamRoundTrip`: mensagem com o prefixo de 2 bytes.
Future<(dns.DnsMessage?, GoError?)> _dnsStreamRoundTrip(
  Conn c,
  int id,
  String name,
  int qtype,
  Uint8List b,
) async {
  final (_, werr) = await c.write$async(_bytes(b));
  if (werr != null) return (null, werr);
  var buf = _bytes(Uint8List(1280));
  final (_, e1) = await io.readFull$async(c, buf.slice(0, 2));
  if (e1 != null) return (null, e1);
  final l = (buf[0].toInt() << 8) | buf[1].toInt();
  if (l > buf.length) buf = _bytes(Uint8List(l));
  final (n, e2) = await io.readFull$async(c, buf.slice(0, l));
  if (e2 != null) return (null, e2);
  final dns.DnsMessage p;
  try {
    p = dns.DnsMessage.parse(_u8(buf, n.toInt()));
  } on FormatException {
    return (null, _errCannotUnmarshalDNSMessage);
  }
  if (p.questionsBroken || p.questions.isEmpty)
    return (null, _errCannotUnmarshalDNSMessage);
  if (!_checkResponse(id, name, qtype, p))
    return (null, _errInvalidDNSResponse);
  return (p, null);
}

/// `checkResponse`.
bool _checkResponse(int id, String name, int qtype, dns.DnsMessage p) {
  final q = p.questions.first;
  return p.response &&
      p.id == id &&
      q.type == qtype &&
      q.cls == 1 &&
      dns.dnsEqualAsciiName(name, q.name);
}

/// `checkHeader`.
GoError? _checkHeader(dns.DnsMessage p) {
  final (rcode, hasAdd) = p.extendedRcode();
  if (rcode == dns.rcodeNameError) return _errNoSuchHost;
  final first = p.answers.records.isNotEmpty;
  if (!first && p.answers.broken) return _errCannotUnmarshalDNSMessage;
  if (rcode == dns.rcodeSuccess &&
      !p.authoritative &&
      !p.recursionAvailable &&
      !first &&
      !hasAdd) {
    return _errLameReferral;
  }
  if (rcode != dns.rcodeSuccess) {
    return rcode == dns.rcodeServerFailure
        ? _errServerTemporarilyMisbehaving
        : _errServerMisbehaving;
  }
  return null;
}

/// Os registros de resposta do tipo [qtype] (`AnswerHeader` + `SkipAnswer`),
/// ou o `*DNSError` "cannot unmarshal" se a seção quebra antes do fim.
List<dns.DnsRR> _answersOf(
  dns.DnsMessage p,
  int qtype,
  String name,
  String server,
) {
  if (p.answers.broken)
    throw _DnsFailure(_dnsErr('cannot unmarshal DNS message', name, server));
  return [
    for (final r in p.answers.records)
      if (r.type == qtype) r,
  ];
}

/// `isDomainName(s)`: nome em formato de apresentação (LDH e `_`).
bool _isDomainName(String s) {
  if (s == '.') return true;
  final l = s.length;
  if (l == 0 || l > 254 || l == 254 && !s.endsWith('.')) return false;
  var last = 0x2e;
  var nonNumeric = false;
  var partlen = 0;
  for (final c in s.codeUnits) {
    if (c >= 0x61 && c <= 0x7a || c >= 0x41 && c <= 0x5a || c == 0x5f) {
      nonNumeric = true;
      partlen++;
    } else if (c >= 0x30 && c <= 0x39) {
      partlen++;
    } else if (c == 0x2d) {
      if (last == 0x2e) return false;
      partlen++;
      nonNumeric = true;
    } else if (c == 0x2e) {
      if (last == 0x2e || last == 0x2d) return false;
      if (partlen > 63 || partlen == 0) return false;
      partlen = 0;
    } else {
      return false;
    }
    last = c;
  }
  if (last == 0x2d || partlen > 63) return false;
  return nonNumeric;
}

/// `reverseaddr(addr)`: o nome `in-addr.arpa.`/`ip6.arpa.` do IP.
String _reverseaddr(String addr) {
  final ip = parseIP(_gs(addr));
  if (ip.length == 0) throw _DnsFailure(_dnsErr('unrecognized address', addr));
  final b = _bytesOf(ip.to16());
  if (ip.to4().length != 0)
    return '${b[15]}.${b[14]}.${b[13]}.${b[12]}.in-addr.arpa.';
  final out = StringBuffer();
  for (var i = 15; i >= 0; i--) {
    out
      ..write(_hexDigit[b[i] & 0xf])
      ..write('.')
      ..write(_hexDigit[b[i] >> 4])
      ..write('.');
  }
  out.write('ip6.arpa.');
  return out.toString();
}
