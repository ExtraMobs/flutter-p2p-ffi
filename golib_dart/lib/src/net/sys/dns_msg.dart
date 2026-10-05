/// Mensagens DNS (RFC 1035) e o `resolv.conf`: o mínimo para o cliente TXT
/// do motor da VM (o `dart:io` não faz TXT) — consulta com EDNS0, leitura
/// da resposta com ponteiros de compressão — e para servidores falsos de
/// teste. Puro Dart, sem `dart:io`.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Tipo TXT.
const dnsTypeTxt = 16;

/// Classe IN.
const dnsClassIn = 1;

/// RCODEs usados.
const dnsRcodeSuccess = 0;
const dnsRcodeServerFailure = 2;
const dnsRcodeNameError = 3;

/// Nome em labels de fio; `null` se inválido (label vazio no meio, > 63
/// bytes, nome > 255). O ponto final é opcional.
Uint8List? encodeDnsName(String name) {
  if (name.endsWith('.')) name = name.substring(0, name.length - 1);
  final out = BytesBuilder();
  if (name.isNotEmpty) {
    for (final label in name.split('.')) {
      final b = utf8.encode(label);
      if (b.isEmpty || b.length > 63) return null;
      out
        ..addByte(b.length)
        ..add(b);
    }
  }
  out.addByte(0);
  return out.length > 255 ? null : out.takeBytes();
}

/// Consulta recursiva (RD) de [qtype] para [name] com um OPT de EDNS0
/// anunciando 1232 bytes, como o resolvedor puro do Go.
Uint8List? buildDnsQuery(int id, String name, int qtype) {
  final qname = encodeDnsName(name);
  if (qname == null) return null;
  final b = BytesBuilder()
    ..add(_u16(id))
    ..add(_u16(0x0100)) // RD
    ..add(_u16(1)) // QDCOUNT
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(1)) // ARCOUNT (OPT)
    ..add(qname)
    ..add(_u16(qtype))
    ..add(_u16(dnsClassIn))
    // OPT: nome raiz, tipo 41, classe = tamanho UDP, TTL 0, sem dados.
    ..addByte(0)
    ..add(_u16(41))
    ..add(_u16(1232))
    ..add([0, 0, 0, 0])
    ..add(_u16(0));
  return b.takeBytes();
}

List<int> _u16(int v) => [(v >> 8) & 0xff, v & 0xff];

int _rd16(Uint8List m, int o) => (m[o] << 8) | m[o + 1];

/// Pula um nome (com ponteiros) a partir de [off]; devolve o fim.
int _skipName(Uint8List m, int off) {
  while (true) {
    if (off >= m.length) throw const FormatException('nome truncado');
    final len = m[off];
    if (len == 0) return off + 1;
    if (len & 0xc0 == 0xc0) return off + 2;
    if (len & 0xc0 != 0) throw const FormatException('label inválido');
    off += 1 + len;
  }
}

/// Lê um nome (com ponteiros) em minúsculas, terminado em ponto.
String _readName(Uint8List m, int off) {
  final labels = <String>[];
  var hops = 0;
  while (true) {
    if (off >= m.length) throw const FormatException('nome truncado');
    final len = m[off];
    if (len == 0) break;
    if (len & 0xc0 == 0xc0) {
      if (++hops > 64) throw const FormatException('laço de ponteiros');
      off = ((len & 0x3f) << 8) | m[off + 1];
      continue;
    }
    if (off + 1 + len > m.length) throw const FormatException('truncado');
    labels.add(latin1.decode(Uint8List.sublistView(m, off + 1, off + 1 + len)));
    off += 1 + len;
  }
  return '${labels.join('.').toLowerCase()}.';
}

/// Pergunta de uma mensagem: id, nome (minúsculo, com ponto final), tipo,
/// e os bytes crus da seção (para ecoar numa resposta).
typedef DnsQuestion = ({int id, String name, int qtype, Uint8List raw});

/// A primeira pergunta de [m], ou `null` se a mensagem não tem uma legível.
DnsQuestion? parseDnsQuestion(Uint8List m) {
  try {
    if (m.length < 12 || _rd16(m, 4) < 1) return null;
    final end = _skipName(m, 12) + 4;
    if (end > m.length) return null;
    return (
      id: _rd16(m, 0),
      name: _readName(m, 12),
      qtype: _rd16(m, end - 4),
      raw: Uint8List.fromList(m.sublist(12, end)),
    );
  } on FormatException {
    return null;
  }
}

/// Resposta a [q] (servidor falso de teste): registros TXT em [txt] (cada um
/// uma lista de character-strings), com [rcode], `TC` e `RA` escolhidos.
Uint8List buildDnsResponse(
  DnsQuestion q, {
  int rcode = dnsRcodeSuccess,
  List<List<String>> txt = const [],
  bool truncated = false,
  bool recursionAvailable = true,
}) {
  var flags = 0x8000 | 0x0100 | rcode; // QR, RD
  if (truncated) flags |= 0x0200;
  if (recursionAvailable) flags |= 0x0080;
  final b = BytesBuilder()
    ..add(_u16(q.id))
    ..add(_u16(flags))
    ..add(_u16(1))
    ..add(_u16(truncated ? 0 : txt.length))
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(q.raw);
  if (!truncated) {
    for (final rec in txt) {
      final data = BytesBuilder();
      for (final s in rec) {
        final bytes = utf8.encode(s);
        data
          ..addByte(bytes.length)
          ..add(bytes);
      }
      final rdata = data.takeBytes();
      b
        ..add([0xc0, 12]) // ponteiro para o nome da pergunta
        ..add(_u16(dnsTypeTxt))
        ..add(_u16(dnsClassIn))
        ..add([0, 0, 0, 60])
        ..add(_u16(rdata.length))
        ..add(rdata);
    }
  }
  return b.takeBytes();
}

/// Resposta lida: cabeçalho e os TXT (character-strings concatenadas por
/// registro, como o `LookupTXT` do Go).
final class DnsResponse {
  DnsResponse._(
    this.id,
    this.flags,
    this.question,
    this.qtype,
    this.answerCount,
    this.txt,
  );

  final int id;
  final int flags;
  final String question;
  final int qtype;
  final int answerCount;
  final List<String> txt;

  bool get isResponse => flags & 0x8000 != 0;
  bool get truncated => flags & 0x0200 != 0;
  bool get authoritative => flags & 0x0400 != 0;
  bool get recursionAvailable => flags & 0x0080 != 0;
  int get rcode => flags & 0x000f;

  /// Lê [m]; lança [FormatException] se malformada.
  static DnsResponse parse(Uint8List m) {
    if (m.length < 12) throw const FormatException('cabeçalho truncado');
    final qd = _rd16(m, 4), an = _rd16(m, 6);
    var off = 12;
    var qname = '';
    var qtype = 0;
    for (var i = 0; i < qd; i++) {
      if (i == 0) qname = _readName(m, off);
      off = _skipName(m, off);
      if (i == 0) qtype = _rd16(m, off);
      off += 4;
    }
    final txt = <String>[];
    for (var i = 0; i < an; i++) {
      off = _skipName(m, off);
      if (off + 10 > m.length) throw const FormatException('RR truncado');
      final type = _rd16(m, off);
      final len = _rd16(m, off + 8);
      off += 10;
      if (off + len > m.length) throw const FormatException('RDATA truncado');
      if (type == dnsTypeTxt) {
        final bytes = BytesBuilder();
        var p = off;
        while (p < off + len) {
          final n = m[p];
          if (p + 1 + n > off + len) {
            throw const FormatException('TXT truncado');
          }
          bytes.add(Uint8List.sublistView(m, p + 1, p + 1 + n));
          p += 1 + n;
        }
        txt.add(utf8.decode(bytes.takeBytes(), allowMalformed: true));
      }
      off += len;
    }
    return DnsResponse._(_rd16(m, 0), _rd16(m, 2), qname, qtype, an, txt);
  }
}
