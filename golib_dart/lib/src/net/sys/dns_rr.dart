/// Mensagens DNS do cliente puro do Go (`net/dnsclient_unix.go` sobre
/// `golang.org/x/net/dns/dnsmessage`): a consulta (`newRequest`, com EDNS0
/// de 1232 bytes e o bit AD opcional) e a leitura da resposta com todos os
/// registros que o `net` usa (A, AAAA, CNAME, NS, PTR, MX, SRV, TXT, OPT).
/// Puro Dart, sem `dart:io`.
///
/// Os nomes são texto com um caractere por byte (latin1), terminados em
/// ponto e com a caixa do fio, como o `dnsmessage.Name.String()`.
library;

import 'dart:convert';
import 'dart:typed_data';

const rrTypeA = 1;
const rrTypeNS = 2;
const rrTypeCNAME = 5;
const rrTypePTR = 12;
const rrTypeMX = 15;
const rrTypeTXT = 16;
const rrTypeAAAA = 28;
const rrTypeSRV = 33;
const rrTypeOPT = 41;

const rcodeSuccess = 0;
const rcodeServerFailure = 2;
const rcodeNameError = 3;

/// Maior pacote DNS que o Go aceita (`maxDNSPacketSize`).
const maxDnsPacketSize = 1232;

/// `newRequest(q, ad)`: a consulta por UDP e a mesma com o prefixo de 2
/// bytes do TCP; `null` se o nome não vira labels (`errCannotMarshalDNSMessage`).
(Uint8List, Uint8List)? dnsNewRequest(
  int id,
  String name,
  int qtype, {
  bool ad = false,
}) {
  final qname = _packName(name);
  if (qname == null) return null;
  var bits = 0x0100; // RD
  if (ad) bits |= 0x0020;
  final b = BytesBuilder()
    ..add([0, 0])
    ..add(_u16(id))
    ..add(_u16(bits))
    ..add(_u16(1))
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(1)) // ARCOUNT: o OPT
    ..add(qname)
    ..add(_u16(qtype))
    ..add(_u16(1)) // ClassINET
    // OPT: nome raiz, tipo 41, classe = tamanho UDP, TTL 0, sem dados.
    ..addByte(0)
    ..add(_u16(rrTypeOPT))
    ..add(_u16(maxDnsPacketSize))
    ..add([0, 0, 0, 0])
    ..add(_u16(0));
  final tcp = b.takeBytes();
  final l = tcp.length - 2;
  tcp[0] = (l >> 8) & 0xff;
  tcp[1] = l & 0xff;
  return (Uint8List.sublistView(tcp, 2), tcp);
}

/// `Name.pack` sem compressão: o nome tem que terminar em ponto; label vazio
/// ou com 64 bytes ou mais é erro.
Uint8List? _packName(String name) {
  final bytes = latin1.encode(name);
  if (bytes.length > 255 || bytes.isEmpty || bytes.last != 0x2e) return null;
  if (bytes.length == 1) return Uint8List.fromList([0]);
  final out = BytesBuilder();
  var begin = 0;
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] != 0x2e) continue;
    final n = i - begin;
    if (n >= 64 || n == 0) return null;
    out
      ..addByte(n)
      ..add(Uint8List.sublistView(bytes, begin, i));
    begin = i + 1;
  }
  out.addByte(0);
  return out.takeBytes();
}

List<int> _u16(int v) => [(v >> 8) & 0xff, v & 0xff];

int _rd16(Uint8List m, int o) {
  if (o + 2 > m.length) throw const FormatException('insufficient data');
  return (m[o] << 8) | m[o + 1];
}

int _rd32(Uint8List m, int o) => (_rd16(m, o) << 16) | _rd16(m, o + 2);

/// `Name.unpack`: (nome, fim no fio). Rejeita label com ponto, ponteiro
/// demais, bits reservados e nome acima de 255 bytes.
(String, int) _unpackName(Uint8List m, int off) {
  var cur = off, newOff = off, ptr = 0;
  final out = StringBuffer();
  var len = 0;
  while (true) {
    if (cur >= m.length) throw const FormatException('insufficient data');
    final c = m[cur++];
    switch (c & 0xc0) {
      case 0x00:
        if (c == 0) {
          if (len == 0) {
            out.write('.');
            len = 1;
          }
          if (len > 254) throw const FormatException('name too long');
          if (ptr == 0) newOff = cur;
          return (out.toString(), newOff);
        }
        final end = cur + c;
        if (end > m.length) throw const FormatException('insufficient data');
        for (var i = cur; i < end; i++) {
          if (m[i] == 0x2e) throw const FormatException('invalid name');
        }
        out
          ..write(latin1.decode(Uint8List.sublistView(m, cur, end)))
          ..write('.');
        len += c + 1;
        cur = end;
      case 0xc0:
        if (cur >= m.length) throw const FormatException('invalid pointer');
        final c1 = m[cur++];
        if (ptr == 0) newOff = cur;
        if (++ptr > 10) throw const FormatException('too many pointers');
        cur = ((c ^ 0xc0) << 8) | c1;
      default:
        throw const FormatException('segment prefix is reserved');
    }
  }
}

/// `equalASCIIName`: iguais sem diferenciar a caixa ASCII.
bool dnsEqualAsciiName(String a, String b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    var x = a.codeUnitAt(i), y = b.codeUnitAt(i);
    if (x >= 0x41 && x <= 0x5a) x += 0x20;
    if (y >= 0x41 && y <= 0x5a) y += 0x20;
    if (x != y) return false;
  }
  return true;
}

/// Pergunta lida (nome com a caixa do fio).
typedef DnsQuestionRR = ({String name, int type, int cls});

/// Um registro: cabeçalho e onde estão os dados no fio; os acessores lêem o
/// corpo e lançam [FormatException] se ele estiver malformado.
final class DnsRR {
  DnsRR._(
    this._m,
    this.name,
    this.type,
    this.cls,
    this.ttl,
    this._off,
    this._len,
  );

  final Uint8List _m;
  final String name;
  final int type;
  final int cls;
  final int ttl;
  final int _off;
  final int _len;

  Uint8List _fixed(int n) {
    if (_off + n > _m.length) throw const FormatException('insufficient data');
    return Uint8List.fromList(_m.sublist(_off, _off + n));
  }

  /// `AResource`.
  Uint8List get a => _fixed(4);

  /// `AAAAResource`.
  Uint8List get aaaa => _fixed(16);

  /// `CNAMEResource`, `NSResource`, `PTRResource`: o nome do corpo.
  String get target => _unpackName(_m, _off).$1;

  /// `MXResource`: (preferência, host).
  (int, String) get mx => (_rd16(_m, _off), _unpackName(_m, _off + 2).$1);

  /// `SRVResource`: (prioridade, peso, porta, alvo).
  (int, int, int, String) get srv => (
    _rd16(_m, _off),
    _rd16(_m, _off + 2),
    _rd16(_m, _off + 4),
    _unpackName(_m, _off + 6).$1,
  );

  /// `TXTResource`: as character-strings (bytes crus).
  List<Uint8List> get txt {
    final out = <Uint8List>[];
    var off = _off, n = 0;
    while (n < _len) {
      if (off >= _m.length) throw const FormatException('insufficient data');
      final l = _m[off];
      if (off + 1 + l > _m.length) {
        throw const FormatException('insufficient data');
      }
      if (_len - n < l + 1) throw const FormatException('insufficient data');
      out.add(Uint8List.fromList(_m.sublist(off + 1, off + 1 + l)));
      off += 1 + l;
      n += l + 1;
    }
    return out;
  }

  /// `ResourceHeader.ExtendedRCode(rcode)` de um OPT.
  int extendedRcode(int rcode) =>
      (ttl & 0x00ff0000) == 0 ? ((ttl >> 24) << 4) | rcode : rcode;
}

/// Uma seção lida: os registros até o primeiro malformado, e se houve um.
final class DnsSection {
  DnsSection._(this.records, this.broken);
  final List<DnsRR> records;

  /// Depois de [records] vem um registro que não se lê (o `AnswerHeader`
  /// do Go devolveria erro nele).
  final bool broken;
}

/// Mensagem lida por inteiro (o `dnsmessage.Parser` do Go lê sob demanda; o
/// que ele acusaria num registro malformado aparece aqui como
/// [DnsSection.broken] na posição dele).
final class DnsMessage {
  DnsMessage._(
    this.id,
    this.bits,
    this.questions,
    this.questionsBroken,
    this.answers,
    this.authorities,
    this.additionals,
  );

  final int id;
  final int bits;
  final List<DnsQuestionRR> questions;
  final bool questionsBroken;
  final DnsSection answers;
  final DnsSection authorities;
  final DnsSection additionals;

  bool get response => bits & 0x8000 != 0;
  bool get authoritative => bits & 0x0400 != 0;
  bool get truncated => bits & 0x0200 != 0;
  bool get recursionAvailable => bits & 0x0080 != 0;
  int get rcode => bits & 0x000f;

  /// `p.Start(m)`: [FormatException] se o cabeçalho não se lê. As seções que
  /// não se lêem ficam marcadas, sem lançar.
  static DnsMessage parse(Uint8List m) {
    if (m.length < 12) throw const FormatException('unpacking header');
    final qd = _rd16(m, 4), an = _rd16(m, 6), ns = _rd16(m, 8);
    final ar = _rd16(m, 10);
    var off = 12;
    final qs = <DnsQuestionRR>[];
    var qBroken = false;
    try {
      for (var i = 0; i < qd; i++) {
        final (name, end) = _unpackName(m, off);
        qs.add((name: name, type: _rd16(m, end), cls: _rd16(m, end + 2)));
        off = end + 4;
      }
    } on FormatException {
      qBroken = true;
    }
    DnsSection section(int count) {
      final out = <DnsRR>[];
      if (qBroken) return DnsSection._(out, true);
      try {
        for (var i = 0; i < count; i++) {
          final (name, end) = _unpackName(m, off);
          final type = _rd16(m, end), cls = _rd16(m, end + 2);
          final ttl = _rd32(m, end + 4), len = _rd16(m, end + 8);
          final body = end + 10;
          if (body + len > m.length) {
            throw const FormatException('insufficient data');
          }
          out.add(DnsRR._(m, name, type, cls, ttl, body, len));
          off = body + len;
        }
      } on FormatException {
        qBroken = true; // as seções seguintes também não se lêem
        return DnsSection._(out, true);
      }
      return DnsSection._(out, false);
    }

    final answers = section(an);
    final authorities = section(ns);
    final additionals = section(ar);
    return DnsMessage._(
      _rd16(m, 0),
      _rd16(m, 2),
      qs,
      qs.length < qd,
      answers,
      authorities,
      additionals,
    );
  }

  /// `extractExtendedRCode`: (rcode estendido pelo OPT, há registro
  /// adicional).
  (int, bool) extendedRcode() {
    if (answers.broken || authorities.broken) return (rcode, false);
    var hasAdd = false;
    for (final r in additionals.records) {
      hasAdd = true;
      if (r.type == rrTypeOPT) return (r.extendedRcode(rcode), true);
    }
    return (rcode, hasAdd);
  }
}
