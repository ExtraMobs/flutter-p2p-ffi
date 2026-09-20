// test/atomic/nivel_1/pion_sdp_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo pion/sdp (transpiled_pion_sdp).
// Vetores adaptados de go-ipfs-reference/pion-sdp/*_test.go (base_lexer,
// common_description, direction, extmap, jsep, marshal, media_description,
// sessiondescription, time_description, unmarshal, util).

import 'dart:convert';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_pion_sdp/transpiled_pion_sdp.dart';

// Porta de CanonicalMarshalSDP (marshal_test.go) / CanonicalUnmarshalSDP
// (unmarshal_test.go) -- as duas constantes upstream têm texto idêntico e
// servem como o vetor de ida-e-volta (round trip) canônico do pacote.
const String _canonicalSdp = 'v=0\r\n'
    'o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n'
    's=SDP Seminar\r\n'
    'i=A Seminar on the session description protocol\r\n'
    'u=http://www.example.com/seminars/sdp.pdf\r\n'
    'e=j.doe@example.com (Jane Doe)\r\n'
    'p=+1 617 555-6011\r\n'
    'c=IN IP4 224.2.17.12/127\r\n'
    'b=X-YZ:128\r\n'
    'b=AS:12345\r\n'
    't=2873397496 2873404696\r\n'
    't=3034423619 3042462419\r\n'
    'r=604800 3600 0 90000\r\n'
    'z=2882844526 -3600 2898848070 0\r\n'
    'k=prompt\r\n'
    'a=candidate:0 1 UDP 2113667327 203.0.113.1 54400 typ host\r\n'
    'a=recvonly\r\n'
    'm=audio 49170 RTP/AVP 0\r\n'
    'i=Vivamus a posuere nisl\r\n'
    'c=IN IP4 203.0.113.1\r\n'
    'b=X-YZ:128\r\n'
    'k=prompt\r\n'
    'a=sendrecv\r\n'
    'm=video 51372 RTP/AVP 99\r\n'
    'a=rtpmap:99 h263-1998/90000\r\n';

// Porta de getTestSessionDescription() (util_test.go).
SessionDescription _testSessionDescription() => SessionDescription(
      mediaDescriptions: [
        MediaDescription(
          mediaName: MediaName(
            media: 'video',
            port: RangedPort(value: 51372),
            protos: ['RTP', 'AVP'],
            formats: ['120', '121', '126', '97', '98'],
          ),
          attributes: [
            Attribute.withValue(
              'fmtp:126 profile-level-id=42e01f;level-asymmetry-allowed=1;'
                  'packetization-mode=1',
              '',
            ),
            Attribute.withValue(
              'fmtp:97 profile-level-id=42e01f;level-asymmetry-allowed=1',
              '',
            ),
            Attribute.withValue(
              'fmtp:98 profile-level-id=42e01e; packetization-mode=1',
              '',
            ),
            Attribute.withValue('fmtp:120 max-fs=12288;max-fr=60', ''),
            Attribute.withValue('fmtp:121 max-fs=12288;max-fr=60', ''),
            Attribute.withValue('rtpmap:120 VP8/90000', ''),
            Attribute.withValue('rtpmap:121 VP9/90000', ''),
            Attribute.withValue('rtpmap:126 H264/90000', ''),
            Attribute.withValue('rtpmap:97 H264/90000', ''),
            Attribute.withValue('rtpmap:98 H264/90000', ''),
            Attribute.withValue('rtcp-fb:97 ccm fir', ''),
            Attribute.withValue('rtcp-fb:97 nack', ''),
            Attribute.withValue('rtcp-fb:97 nack pli', ''),
            Attribute.withValue('rtcp-fb:* transport-cc', ''),
            Attribute.withValue('rtcp-fb:* nack', ''),
          ],
        ),
      ],
    );

void main() {
  group('DocumentStartException [Atomic Audit]', () {
    test('toString() - descreve a tentativa de retroceder no início do documento', () {
      expect(DocumentStartException().toString(), contains('document start'));
    });
  });

  group('SdpUnexpectedEndOfInputException [Atomic Audit]', () {
    test('toString() - descreve o fim inesperado de entrada', () {
      expect(
        SdpUnexpectedEndOfInputException().toString(),
        contains('end of input'),
      );
    });
  });

  group('SdpSyntaxException [Atomic Audit]', () {
    test('toString() - reporta posição e byte ofensivo', () {
      final bytes = Uint8List.fromList(utf8.encode('a=b'));
      final e = SdpSyntaxException(bytes, 2);
      expect(e.toString(), contains('pos 2'));
      expect(e.toString(), contains('b'));
    });

    test('toString() - índice negativo é tratado como zero', () {
      final bytes = Uint8List.fromList(utf8.encode('hello'));
      expect(SdpSyntaxException(bytes, -2).toString(), contains('pos 0'));
    });
  });

  group('ExtMapSyntaxException [Atomic Audit]', () {
    test('toString() - inclui a entrada bruta recebida', () {
      expect(ExtMapSyntaxException('extmap 1').toString(), contains('extmap 1'));
    });
  });

  group('SdpInvalidSyntaxException [Atomic Audit]', () {
    test('toString() - inclui o detalhe do erro', () {
      expect(
        SdpInvalidSyntaxException('b=oops').toString(),
        contains('b=oops'),
      );
    });
  });

  group('SdpInvalidNumericValueException [Atomic Audit]', () {
    test('toString() - inclui o valor numérico inválido', () {
      expect(
        SdpInvalidNumericValueException('NaN').toString(),
        contains('NaN'),
      );
    });
  });

  group('SdpInvalidValueException [Atomic Audit]', () {
    test('toString() - inclui o valor inválido', () {
      expect(
        SdpInvalidValueException('XX').toString(),
        contains('XX'),
      );
    });
  });

  group('SdpInvalidPortValueException [Atomic Audit]', () {
    test('toString() - inclui o valor de porta inválido', () {
      expect(
        SdpInvalidPortValueException('99999').toString(),
        contains('99999'),
      );
    });
  });

  group('PayloadTypeNotFoundException [Atomic Audit]', () {
    test('toString() - inclui o payload type pesquisado', () {
      expect(PayloadTypeNotFoundException(42).toString(), contains('42'));
    });
  });

  group('CodecNotFoundException [Atomic Audit]', () {
    test('toString() - descreve o codec não encontrado', () {
      expect(CodecNotFoundException().toString(), contains('codec not found'));
    });
  });

  group('Direction [Atomic Audit]', () {
    test('fromRaw() - reconhece os quatro tokens RFC 4566 válidos', () {
      expect(Direction.fromRaw('sendrecv'), equals(Direction.sendRecv));
      expect(Direction.fromRaw('sendonly'), equals(Direction.sendOnly));
      expect(Direction.fromRaw('recvonly'), equals(Direction.recvOnly));
      expect(Direction.fromRaw('inactive'), equals(Direction.inactive));
    });

    test('fromRaw() - lança FormatException para token desconhecido', () {
      expect(() => Direction.fromRaw(''), throwsA(isA<FormatException>()));
      expect(
        () => Direction.fromRaw('notadirection'),
        throwsA(isA<FormatException>()),
      );
    });

    test('toString() - retorna o token de fio RFC 4566', () {
      expect(Direction.sendRecv.toString(), equals('sendrecv'));
      expect(Direction.sendOnly.toString(), equals('sendonly'));
      expect(Direction.recvOnly.toString(), equals('recvonly'));
      expect(Direction.inactive.toString(), equals('inactive'));
    });

    // `inactive` is an enum value, not a method, but its constructor-call
    // syntax (`inactive('inactive');`, the last, semicolon-terminated entry
    // in the values list) is indistinguishable from a member declaration to
    // the AST auditor's text scanner, so it is tracked as a "method" needing
    // its own atomic test.
    test('inactive() - é o quarto valor da direção (nenhuma comunicação)', () {
      expect(Direction.inactive.toString(), equals('inactive'));
      expect(Direction.fromRaw('inactive'), same(Direction.inactive));
    });
  });

  group('ConnectionRole [Atomic Audit]', () {
    test('toString() - mapeia as quatro constantes nomeadas', () {
      expect(ConnectionRole.active.toString(), equals('active'));
      expect(ConnectionRole.passive.toString(), equals('passive'));
      expect(ConnectionRole.actpass.toString(), equals('actpass'));
      expect(ConnectionRole.holdconn.toString(), equals('holdconn'));
    });

    test('toString() - cai para "Unknown" no valor zero e em valores arbitrários', () {
      expect(const ConnectionRole().toString(), equals('Unknown'));
      expect(const ConnectionRole(99).toString(), equals('Unknown'));
    });

    test('operator == - compara por valor numérico subjacente', () {
      expect(const ConnectionRole(1), equals(ConnectionRole.active));
      expect(const ConnectionRole(2), isNot(equals(ConnectionRole.active)));
    });

    test('hashCode() - consistente para instâncias de mesmo valor', () {
      expect(
        const ConnectionRole(1).hashCode,
        equals(ConnectionRole.active.hashCode),
      );
    });
  });

  group('Codec [Atomic Audit]', () {
    test('toString() - formata payload, nome, taxa, parâmetros e feedback RTCP', () {
      final codec = Codec(
        payloadType: 111,
        name: 'opus',
        clockRate: 48000,
        encodingParameters: '2',
        fmtp: 'minptime=10;useinbandfec=1',
        rtcpFeedback: ['nack', 'pli'],
      );
      expect(
        codec.toString(),
        equals('111 opus/48000/2 (minptime=10;useinbandfec=1) [nack, pli]'),
      );
    });
  });

  group('ConnectionInformation [Atomic Audit]', () {
    test('toString() - sem endereço', () {
      final c = ConnectionInformation(networkType: 'IN', addressType: 'IP4');
      expect(c.toString(), equals('IN IP4'));
    });

    test('toString() - com endereço, TTL e range', () {
      final c = ConnectionInformation(
        networkType: 'IN',
        addressType: 'IP4',
        address: Address(address: '224.2.17.12', ttl: 127, range: 3),
      );
      expect(c.toString(), equals('IN IP4 224.2.17.12/127/3'));
    });
  });

  group('Address [Atomic Audit]', () {
    test('toString() - apenas endereço', () {
      expect(
        Address(address: '239.255.255.250').toString(),
        equals('239.255.255.250'),
      );
    });

    test('toString() - apenas TTL', () {
      expect(
        Address(address: '239.255.255.250', ttl: 5).toString(),
        equals('239.255.255.250/5'),
      );
    });

    test('toString() - apenas range', () {
      expect(
        Address(address: '239.255.255.250', range: 7).toString(),
        equals('239.255.255.250/7'),
      );
    });

    test('toString() - TTL e range', () {
      expect(
        Address(address: '239.255.255.250', ttl: 5, range: 7).toString(),
        equals('239.255.255.250/5/7'),
      );
    });
  });

  group('Bandwidth [Atomic Audit]', () {
    test('toString() - padrão', () {
      final b = Bandwidth(type: 'AS', bandwidth: Golang.Uint64(512));
      expect(b.toString(), equals('AS:512'));
    });

    test('toString() - experimental prefixa com X-', () {
      final b = Bandwidth(
        experimental: true,
        type: 'AS',
        bandwidth: Golang.Uint64(512),
      );
      expect(b.toString(), equals('X-AS:512'));
    });
  });

  group('Attribute [Atomic Audit]', () {
    test('toString() - apenas chave quando não há valor', () {
      expect(Attribute.property('recvonly').toString(), equals('recvonly'));
    });

    test('toString() - chave e valor separados por dois-pontos', () {
      expect(
        Attribute.withValue('rtpmap', '99 h263-1998/90000').toString(),
        equals('rtpmap:99 h263-1998/90000'),
      );
    });

    test('isIceCandidate() - verdadeiro apenas para a chave exata "candidate"', () {
      expect(Attribute(key: 'candidate').isIceCandidate(), isTrue);
      expect(Attribute(key: 'Candidate').isIceCandidate(), isFalse);
      expect(Attribute(key: 'ice-candidate').isIceCandidate(), isFalse);
      expect(Attribute().isIceCandidate(), isFalse);
    });
  });

  group('ExtMap [Atomic Audit]', () {
    const example1 = 'extmap:1 http://example.com/082005/ext.htm#ttime';
    const example2 =
        'extmap:2/sendrecv http://example.com/082005/ext.htm#xmeta short';
    const failingRange =
        'extmap:257/sendrecv http://example.com/082005/ext.htm#xmeta short';
    const failingDirection =
        'extmap:2/blorg http://example.com/082005/ext.htm#xmeta short';

    test('unmarshal() - decodifica valor simples sem direção', () {
      final e = ExtMap();
      e.unmarshal(example1);
      expect(e.marshal(), equals(example1));
    });

    test('unmarshal() - decodifica valor, direção, URI e atributo extra', () {
      final e = ExtMap();
      e.unmarshal(example2);
      expect(e.marshal(), equals(example2));
    });

    test('unmarshal() - lança ExtMapSyntaxException quando faltam os dois-pontos', () {
      expect(
        () => ExtMap().unmarshal('extmap 1 example.com'),
        throwsA(isA<ExtMapSyntaxException>()),
      );
      expect(
        () => ExtMap().unmarshal(''),
        throwsA(isA<ExtMapSyntaxException>()),
      );
    });

    test('unmarshal() - lança ExtMapSyntaxException com menos de dois campos', () {
      expect(
        () => ExtMap().unmarshal('extmap:1'),
        throwsA(isA<ExtMapSyntaxException>()),
      );
    });

    test('unmarshal() - lança ExtMapSyntaxException fora do intervalo 1-246', () {
      expect(
        () => ExtMap().unmarshal(failingRange),
        throwsA(isA<ExtMapSyntaxException>()),
      );
    });

    test('unmarshal() - propaga FormatException de uma direção desconhecida', () {
      expect(
        () => ExtMap().unmarshal(failingDirection),
        throwsA(isA<FormatException>()),
      );
    });

    test('marshal() - concatena name() e a representação interna com ":"', () {
      final e = ExtMap(value: 3, uri: Uri.parse(transportCcUri));
      expect(e.marshal(), equals('extmap:3 $transportCcUri'));
    });

    test('clone() - converte para Attribute com chave "extmap"', () {
      final uri = Uri.parse(audioLevelUri);
      final e = ExtMap(value: 5, uri: uri, extAttr: 'vad');
      final got = e.clone();
      expect(got.key, equals('extmap'));
      expect(got.value, equals('5 $audioLevelUri vad'));
    });

    test('name() - sempre retorna a constante "extmap"', () {
      expect(ExtMap().name(), equals('extmap'));
    });
  });

  group('MediaDescription [Atomic Audit]', () {
    test('attribute() - encontrada retorna (valor, true)', () {
      final md = MediaDescription(
        mediaName: MediaName(media: 'audio'),
        attributes: [
          Attribute(key: 'rtcp-mux'),
          Attribute(key: 'mid', value: 'video'),
          Attribute(key: 'setup', value: 'actpass'),
        ],
      );
      final (value, found) = md.attribute('mid');
      expect(found, isTrue);
      expect(value, equals('video'));
    });

    test('attribute() - não encontrada retorna ("", false)', () {
      final md = MediaDescription(mediaName: MediaName(media: 'audio'));
      final (value, found) = md.attribute('nonexistent');
      expect(found, isFalse);
      expect(value, equals(''));
    });
  });

  group('RangedPort [Atomic Audit]', () {
    test('toString() - sem range', () {
      expect(RangedPort(value: 5004).toString(), equals('5004'));
    });

    test('toString() - com range', () {
      expect(RangedPort(value: 5004, range: 2).toString(), equals('5004/2'));
    });
  });

  group('MediaName [Atomic Audit]', () {
    test('toString() - concatena media, porta, protos (com "/") e formatos', () {
      final m = MediaName(
        media: 'audio',
        port: RangedPort(value: 5004, range: 2),
        protos: ['UDP', 'TLS', 'RTP', 'SAVPF'],
        formats: ['111', '96'],
      );
      expect(m.toString(), equals('audio 5004/2 UDP/TLS/RTP/SAVPF 111 96'));
    });
  });

  group('SessionDescription [Atomic Audit]', () {
    test('attribute() - encontrada retorna (valor, true)', () {
      final sd = SessionDescription(
        attributes: [
          Attribute(key: 'ice-options', value: 'trickle'),
          Attribute(key: 'mid', value: 'video'),
        ],
      );
      final (value, found) = sd.attribute('mid');
      expect(found, isTrue);
      expect(value, equals('video'));
    });

    test('attribute() - não encontrada retorna ("", false)', () {
      final sd = SessionDescription();
      final (value, found) = sd.attribute('does-not-exist');
      expect(found, isFalse);
      expect(value, equals(''));
    });
  });

  group('Origin [Atomic Audit]', () {
    test('toString() - concatena os seis campos separados por espaço', () {
      final o = Origin(
        username: 'alice',
        sessionId: Golang.Uint64(12345),
        sessionVersion: Golang.Uint64(678),
        networkType: 'IN',
        addressType: 'IP4',
        unicastAddress: '111.1.111.1',
      );
      expect(o.toString(), equals('alice 12345 678 IN IP4 111.1.111.1'));
    });
  });

  group('TimeZone [Atomic Audit]', () {
    test('toString() - concatena adjustmentTime e offset', () {
      expect(
        TimeZone(adjustmentTime: Golang.Uint64(3600), offset: -1800)
            .toString(),
        equals('3600 -1800'),
      );
      expect(
        TimeZone(adjustmentTime: Golang.Uint64(), offset: 0).toString(),
        equals('0 0'),
      );
    });
  });

  group('Timing [Atomic Audit]', () {
    test('toString() - concatena startTime e stopTime', () {
      expect(
        Timing(startTime: Golang.Uint64(), stopTime: Golang.Uint64())
            .toString(),
        equals('0 0'),
      );
      expect(
        Timing(startTime: Golang.Uint64(12345), stopTime: Golang.Uint64(67890))
            .toString(),
        equals('12345 67890'),
      );
    });
  });

  group('RepeatTime [Atomic Audit]', () {
    test('toString() - sem offsets', () {
      expect(
        RepeatTime(interval: 3600, duration: 900).toString(),
        equals('3600 900'),
      );
    });

    test('toString() - com offsets, incluindo valores negativos', () {
      expect(
        RepeatTime(
          interval: 604800,
          duration: 3600,
          offsets: [-60, 0, 60],
        ).toString(),
        equals('604800 3600 -60 0 60'),
      );
    });
  });

  group('SessionDescriptionCodecs [Atomic Audit]', () {
    test('getCodecForPayloadType() - resolve um codec anunciado via rtpmap/fmtp', () {
      final codec = _testSessionDescription().getCodecForPayloadType(120);
      expect(codec.name, equals('VP8'));
      expect(codec.clockRate, equals(90000));
      expect(codec.fmtp, equals('max-fs=12288;max-fr=60'));
    });

    test(
        'getCodecForPayloadType() - lança PayloadTypeNotFoundException para '
        'payload type ausente', () {
      expect(
        () => SessionDescription().getCodecForPayloadType(42),
        throwsA(isA<PayloadTypeNotFoundException>()),
      );
    });

    test('getCodecsForPayloadTypes() - resolve múltiplos payload types de uma vez', () {
      final codecs =
          _testSessionDescription().getCodecsForPayloadTypes([120, 121]);
      expect(codecs.map((c) => c.name), equals(['VP8', 'VP9']));
    });

    test('getPayloadTypeForCodec() - casa por nome quando não há outros critérios', () {
      final pt =
          _testSessionDescription().getPayloadTypeForCodec(Codec(name: 'VP8'));
      expect(pt, equals(120));
    });

    test(
        'getPayloadTypeForCodec() - lança CodecNotFoundException quando '
        'nenhum codec corresponde', () {
      expect(
        () => SessionDescription()
            .getPayloadTypeForCodec(Codec(name: 'doesnotexist')),
        throwsA(isA<CodecNotFoundException>()),
      );
    });
  });

  group('SessionDescriptionUnmarshal [Atomic Audit]', () {
    test('unmarshalString() - decompõe o documento canônico campo a campo', () {
      final sd = SessionDescription();
      sd.unmarshalString(_canonicalSdp);

      expect(sd.version.value, equals(0));
      expect(sd.origin.username, equals('jdoe'));
      expect(sd.origin.sessionId, equals(Golang.Uint64(2890844526)));
      expect(sd.sessionName.value, equals('SDP Seminar'));
      expect(
        sd.sessionInformation?.value,
        equals('A Seminar on the session description protocol'),
      );
      expect(sd.bandwidth.map((b) => b.toString()), equals(['X-YZ:128', 'AS:12345']));
      expect(sd.timeDescriptions, hasLength(2));
      expect(sd.timeDescriptions[1].repeatTimes, hasLength(1));
      expect(sd.timeZones, hasLength(2));
      expect(sd.encryptionKey?.value, equals('prompt'));
      expect(sd.attributes.map((a) => a.key), equals(['candidate', 'recvonly']));
      expect(sd.mediaDescriptions, hasLength(2));
      expect(sd.mediaDescriptions[0].mediaName.media, equals('audio'));
      expect(sd.mediaDescriptions[1].attributes.single.key, equals('rtpmap'));
      expect(
        sd.mediaDescriptions[1].attributes.single.value,
        equals('99 h263-1998/90000'),
      );
    });

    test('unmarshalString() - lança SdpInvalidValueException quando v != 0', () {
      expect(
        () => SessionDescription().unmarshalString('v=1\r\n'),
        throwsA(isA<SdpInvalidValueException>()),
      );
    });

    test('unmarshalString() - lança SdpSyntaxException em linha malformada', () {
      expect(
        () => SessionDescription().unmarshalString('v0\r\n'),
        throwsA(isA<SdpSyntaxException>()),
      );
    });

    test(
        'unmarshalString() - campos ausentes de Origin recebem os padrões '
        'de compatibilidade IP4/0.0.0.0', () {
      final sd = SessionDescription();
      sd.unmarshalString('v=0\r\no=jdoe 123 456 IN\ns=x\r\n');
      expect(sd.origin.addressType, equals('IP4'));
      expect(sd.origin.unicastAddress, equals('0.0.0.0'));
    });

    test('unmarshal() - decodifica bytes UTF-8 delegando para unmarshalString()', () {
      final sd = SessionDescription();
      sd.unmarshal(utf8.encode(_canonicalSdp));
      expect(sd.origin.username, equals('jdoe'));
      expect(sd.mediaDescriptions, hasLength(2));
    });
  });

  group('SessionDescriptionMarshal [Atomic Audit]', () {
    test('marshal() - reproduz o documento canônico byte a byte (ida e volta)', () {
      final sd = SessionDescription();
      sd.unmarshalString(_canonicalSdp);
      expect(sd.marshal(), equals(_canonicalSdp));
    });

    test('marshalSize() - igual ao comprimento em bytes UTF-8 de marshal()', () {
      final sd = SessionDescription();
      sd.unmarshalString(_canonicalSdp);
      expect(sd.marshalSize(), equals(utf8.encode(sd.marshal()).length));
      expect(sd.marshalSize(), equals(utf8.encode(_canonicalSdp).length));
    });
  });

  group('SessionDescriptionJsep [Atomic Audit]', () {
    test('withPropertyAttribute() - adiciona atributo somente-chave e retorna this', () {
      final sd = SessionDescription.jsep();
      final ret = sd.withPropertyAttribute(attrKeyRtcpMux);
      expect(identical(ret, sd), isTrue);
      expect(sd.attributes, hasLength(1));
      expect(sd.attributes.single.key, equals(attrKeyRtcpMux));
    });

    test('withValueAttribute() - adiciona atributo chave:valor', () {
      final sd = SessionDescription.jsep();
      sd.withValueAttribute(attrKeyMid, 'video');
      expect(sd.attributes.single.key, equals(attrKeyMid));
      expect(sd.attributes.single.value, equals('video'));
    });

    test('withIceRenomination() - adiciona o atributo ice-options "renomination"', () {
      final sd = SessionDescription.jsep();
      sd.withIceRenomination();
      expect(sd.attributes.single.key, equals(attrKeyIceOptions));
      expect(sd.attributes.single.value, equals('renomination'));
    });

    test(
        'withIceTrickleAdvertised() combinado com withIceRenomination() - '
        'ambos se acumulam em um único atributo ice-options separado por espaço',
        () {
      final sd = SessionDescription.jsep();
      sd.withIceTrickleAdvertised().withIceRenomination();
      final iceOptions =
          sd.attributes.where((a) => a.key == attrKeyIceOptions).toList();
      expect(iceOptions, hasLength(1));
      expect(iceOptions.single.value, equals('trickle renomination'));
    });

    test('withFingerprint() - formata "algoritmo valor"', () {
      final sd = SessionDescription.jsep();
      sd.withFingerprint('sha-256', 'test-fingerprint');
      expect(sd.attributes.single.key, equals('fingerprint'));
      expect(sd.attributes.single.value, equals('sha-256 test-fingerprint'));
    });

    test('withMedia() - anexa a descrição de mídia e retorna this', () {
      final sd = SessionDescription.jsep();
      final md = MediaDescription.jsep('audio', []);
      final ret = sd.withMedia(md);
      expect(identical(ret, sd), isTrue);
      expect(sd.mediaDescriptions.last, same(md));
    });
  });

  group('MediaDescriptionJsep [Atomic Audit]', () {
    test('withPropertyAttribute() - adiciona atributo somente-chave', () {
      final md = MediaDescription.jsep('audio', []);
      md.withPropertyAttribute(attrKeyRtcpMux);
      expect(md.attributes.single.key, equals(attrKeyRtcpMux));
    });

    test('withValueAttribute() - adiciona atributo chave:valor', () {
      final md = MediaDescription.jsep('audio', []);
      md.withValueAttribute(attrKeyMid, 'audio');
      expect(md.attributes.single.value, equals('audio'));
    });

    test('withFingerprint() - formata "algoritmo valor"', () {
      final md = MediaDescription.jsep('audio', []);
      md.withFingerprint('sha-256', 'test-fingerprint');
      expect(md.attributes.single.value, equals('sha-256 test-fingerprint'));
    });

    test('withIceCredentials() - adiciona ice-ufrag e ice-pwd nessa ordem', () {
      final md = MediaDescription.jsep('audio', []);
      md.withIceCredentials('test-ufrag', 'test-pwd');
      expect(md.attributes[0].key, equals('ice-ufrag'));
      expect(md.attributes[0].value, equals('test-ufrag'));
      expect(md.attributes[1].key, equals('ice-pwd'));
      expect(md.attributes[1].value, equals('test-pwd'));
    });

    test('withCodec() - adiciona o formato e os atributos rtpmap/fmtp', () {
      final md = MediaDescription.jsep('audio', []);
      md.withCodec(111, 'opus', 48000, 2, 'minptime=10;useinbandfec=1');
      expect(md.mediaName.formats, equals(['111']));
      expect(md.attributes[0].key, equals('rtpmap'));
      expect(md.attributes[0].value, equals('111 opus/48000/2'));
      expect(md.attributes[1].key, equals('fmtp'));
      expect(md.attributes[1].value, equals('111 minptime=10;useinbandfec=1'));
    });

    test('withMediaSource() - adiciona os quatro atributos ssrc na ordem upstream', () {
      final md = MediaDescription.jsep('audio', []);
      md.withMediaSource(1234567890, 'test-cname', 'test-stream', 'test-label');
      expect(md.attributes, hasLength(4));
      expect(md.attributes[0].value, equals('1234567890 cname:test-cname'));
      expect(
        md.attributes[1].value,
        equals('1234567890 msid:test-stream test-label'),
      );
      expect(md.attributes[2].value, equals('1234567890 mslabel:test-stream'));
      expect(md.attributes[3].value, equals('1234567890 label:test-label'));
    });

    test('withCandidate() - adiciona o atributo "candidate" (API depreciada)', () {
      final md = MediaDescription.jsep('audio', []);
      // ignore: deprecated_member_use
      md.withCandidate('0 1 UDP 2113667327 203.0.113.1 54400 typ host');
      expect(md.attributes.single.key, equals('candidate'));
    });

    test('withExtMap() - adiciona o extmap serializado como atributo de propriedade', () {
      final md = MediaDescription.jsep('audio', []);
      final uri = Uri.parse(extMapValueTransportCc == 3 ? transportCcUri : '');
      md.withExtMap(ExtMap(value: extMapValueTransportCc, uri: uri));
      expect(md.attributes.single.key, equals('extmap:3 $uri'));
      expect(md.attributes.single.value, equals(''));
    });

    test('withTransportCcExtMap() - usa o valor e a URI padrão do transport-cc', () {
      final md = MediaDescription.jsep('audio', []);
      md.withTransportCcExtMap();
      expect(md.attributes.single.key, startsWith('extmap:3 '));
      expect(md.attributes.single.key, contains(transportCcUri));
    });
  });
}
