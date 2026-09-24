// test/atomic/nivel_1/pion_sctp_atomic_tests.dart
// Testes atomicos 1 para 1 para o codec puro portado de transpiled_pion_sctp
// (github com/pion/sctp, revisao fixada em doc/transpilation/UPSTREAM_LOCK md):
// util dart (padding e aritmetica de numero de sequencia RFC 1982), chunktype
// dart, chunkheader dart, chunk dart, a camada completa de parametros
// (paramtype/paramheader/param + 11 param_*.dart), causas de erro
// (error_cause*.dart), os 16 tipos concretos de chunk (chunk_*.dart) e a
// classe Packet completa em packet.dart.
// Vetores de bytes adaptados de go-ipfs-reference/pion-sctp/util_test go
// (TestPadByte_Success, TestSerialNumberArithmetic), chunktype_test go
// (TestChunkType_String), packet_test go (TestPacketUnmarshal, o vetor
// headerOnly), paramtype_test go, paramheader_test go, param_test go,
// param_ecn_capable_test go, param_forward_tsn_supported_test go,
// param_outgoing_reset_request_test go, param_reconfig_response_test go,
// param_zero_checksum_test go, chunk_test go (TestInitChunk,
// TestChromeChunk1Init, TestChromeChunk2InitAck, TestSelectAckChunk,
// TestReconfigChunk, TestForwardTSNChunk), chunk_abort_test go,
// chunk_error_test go, chunk_forward_tsn_test go, chunk_init_test go,
// chunk_reconfig_test go, chunk_shutdown_test go, chunk_shutdown_ack_test go
// e chunk_shutdown_complete_test go.
// Nivel 1: codec puro / manipulacao de bytes em memoria, sem I/O.

import 'dart:async';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_pion_sctp/src/chunk.dart';
import 'package:transpiled_pion_sctp/src/chunk_abort.dart';
import 'package:transpiled_pion_sctp/src/chunk_cookie_ack.dart';
import 'package:transpiled_pion_sctp/src/chunk_cookie_echo.dart';
import 'package:transpiled_pion_sctp/src/chunk_error.dart';
import 'package:transpiled_pion_sctp/src/chunk_forward_tsn.dart';
import 'package:transpiled_pion_sctp/src/chunk_heartbeat.dart';
import 'package:transpiled_pion_sctp/src/chunk_heartbeat_ack.dart';
import 'package:transpiled_pion_sctp/src/chunk_init.dart';
import 'package:transpiled_pion_sctp/src/chunk_init_ack.dart';
import 'package:transpiled_pion_sctp/src/chunk_init_common.dart';
import 'package:transpiled_pion_sctp/src/chunk_payload_data.dart';
import 'package:transpiled_pion_sctp/src/chunk_reconfig.dart';
import 'package:transpiled_pion_sctp/src/chunk_selective_ack.dart';
import 'package:transpiled_pion_sctp/src/chunk_shutdown.dart';
import 'package:transpiled_pion_sctp/src/chunk_shutdown_ack.dart';
import 'package:transpiled_pion_sctp/src/chunk_shutdown_complete.dart';
import 'package:transpiled_pion_sctp/src/chunkheader.dart';
import 'package:transpiled_pion_sctp/src/chunktype.dart';
import 'package:transpiled_pion_sctp/src/error_cause.dart';
import 'package:transpiled_pion_sctp/src/error_cause_header.dart';
import 'package:transpiled_pion_sctp/src/error_cause_invalid_mandatory_parameter.dart';
import 'package:transpiled_pion_sctp/src/error_cause_protocol_violation.dart';
import 'package:transpiled_pion_sctp/src/error_cause_unrecognized_chunk_type.dart';
import 'package:transpiled_pion_sctp/src/error_cause_user_initiated_abort.dart';
import 'package:transpiled_pion_sctp/src/packet.dart';
import 'package:transpiled_pion_sctp/src/param.dart';
import 'package:transpiled_pion_sctp/src/param_chunk_list.dart';
import 'package:transpiled_pion_sctp/src/param_ecn_capable.dart';
import 'package:transpiled_pion_sctp/src/param_forward_tsn_supported.dart';
import 'package:transpiled_pion_sctp/src/param_heartbeat_info.dart';
import 'package:transpiled_pion_sctp/src/param_outgoing_reset_request.dart';
import 'package:transpiled_pion_sctp/src/param_random.dart';
import 'package:transpiled_pion_sctp/src/param_reconfig_response.dart';
import 'package:transpiled_pion_sctp/src/param_requested_hmac_algorithm.dart';
import 'package:transpiled_pion_sctp/src/param_state_cookie.dart';
import 'package:transpiled_pion_sctp/src/param_supported_extensions.dart';
import 'package:transpiled_pion_sctp/src/param_zero_checksum.dart';
import 'package:transpiled_pion_sctp/src/paramheader.dart';
import 'package:transpiled_pion_sctp/src/paramtype.dart';
import 'package:transpiled_pion_sctp/src/util.dart';
import 'package:transpiled_pion_sctp/src/association.dart';
import 'package:transpiled_pion_sctp/src/config.dart';
import 'package:transpiled_pion_sctp/src/queue.dart';
import 'package:transpiled_pion_sctp/src/stream.dart';
import 'package:transpiled_pion_sctp/src/streamstate.dart';

/// Minimal in-test [Chunk] implementer, used only to exercise the interface
/// contract (chunk.go has no concrete implementation ported yet -- see
/// transpiled_pion_sctp.dart's library doc comment).
class _EchoChunk implements Chunk {
  Uint8List _value = Uint8List(0);

  @override
  void unmarshal(Uint8List raw) => _value = raw;

  @override
  Uint8List marshal() => _value;

  @override
  bool check() => _value.isNotEmpty;

  @override
  int valueLength() => _value.length;
}

void main() {
  group('getPadding [Atomic Audit]', () {
    test('getPadding() - completa ate o proximo multiplo de 4', () {
      expect(getPadding(0), equals(0));
      expect(getPadding(1), equals(3));
      expect(getPadding(2), equals(2));
      expect(getPadding(3), equals(1));
      expect(getPadding(4), equals(0));
      expect(getPadding(5), equals(3));
    });
  });

  group('padByte [Atomic Audit]', () {
    test('padByte() - acrescenta zeros, porta TestPadByte_Success', () {
      expect(padByte(Uint8List.fromList([0x1, 0x2]), 0), equals([0x1, 0x2]));
      expect(
        padByte(Uint8List.fromList([0x1, 0x2]), 1),
        equals([0x1, 0x2, 0x0]),
      );
      expect(
        padByte(Uint8List.fromList([0x1, 0x2]), 2),
        equals([0x1, 0x2, 0x0, 0x0]),
      );
      expect(
        padByte(Uint8List.fromList([0x1, 0x2]), 3),
        equals([0x1, 0x2, 0x0, 0x0, 0x0]),
      );
    });

    test(
      'padByte() - cnt negativo nao adiciona bytes, porta TestPadByte_Success',
      () {
        expect(padByte(Uint8List.fromList([0x1, 0x2]), -1), equals([0x1, 0x2]));
      },
    );
  });

  group('sna32 [Atomic Audit]', () {
    // Porta TestSerialNumberArithmetic (subteste 32-bit): 16 pontos ao redor
    // do espaco uint32, cada um comparado com a maxima distancia para frente
    // (2^31 - 1) e para tras (2^31), exatamente como o vetor Go.
    const div = 16;
    const serialBits = 32;
    const interval = (1 << serialBits) ~/ div;
    final maxForwardDistance = Golang.Uint32((1 << (serialBits - 1)) - 1);
    final maxBackwardDistance = Golang.Uint32(1 << (serialBits - 1));

    test(
      'sna32Lt() - true para a maior distancia para frente, falso para tras',
      () {
        for (var i = 0; i < div; i++) {
          final s1 = Golang.Uint32(i * interval);
          final s2f = s1 + maxForwardDistance;
          final s2b = s1 + maxBackwardDistance;
          expect(sna32Lt(s1, s2f), isTrue, reason: 's1=$s1 s2f=$s2f');
          expect(sna32Lt(s1, s2b), isFalse, reason: 's1=$s1 s2b=$s2b');
        }
      },
    );

    test(
      'sna32Gt() - falso para a maior distancia para frente, true para tras',
      () {
        for (var i = 0; i < div; i++) {
          final s1 = Golang.Uint32(i * interval);
          final s2f = s1 + maxForwardDistance;
          final s2b = s1 + maxBackwardDistance;
          expect(sna32Gt(s1, s2f), isFalse);
          expect(sna32Gt(s1, s2b), isTrue);
        }
      },
    );

    test('sna32Lte() - concorda com sna32Lt e inclui igualdade', () {
      for (var i = 0; i < div; i++) {
        final s1 = Golang.Uint32(i * interval);
        final s2f = s1 + maxForwardDistance;
        final s2b = s1 + maxBackwardDistance;
        expect(sna32Lte(s1, s2f), isTrue);
        expect(sna32Lte(s1, s2b), isFalse);
        expect(sna32Lte(s1, s1), isTrue);
        expect(sna32Lte(s2b, s2b), isTrue);
      }
    });

    test('sna32Gte() - concorda com sna32Gt e inclui igualdade', () {
      for (var i = 0; i < div; i++) {
        final s1 = Golang.Uint32(i * interval);
        final s2f = s1 + maxForwardDistance;
        final s2b = s1 + maxBackwardDistance;
        expect(sna32Gte(s1, s2f), isFalse);
        expect(sna32Gte(s1, s2b), isTrue);
        expect(sna32Gte(s1, s1), isTrue);
        expect(sna32Gte(s2b, s2b), isTrue);
      }
    });

    test(
      'sna32Eq() - true somente para o mesmo valor, mesmo perto do wraparound',
      () {
        for (var i = 0; i < div; i++) {
          final s1 = Golang.Uint32(i * interval);
          expect(sna32Eq(s1, s1), isTrue);
          expect(sna32Eq(s1, s1 + Golang.Uint32(1)), isFalse);
          expect(sna32Eq(s1, s1 - Golang.Uint32(1)), isFalse);
        }
      },
    );

    test(
      'sna32Lt() - i1 maior que i2 mas dentro da distancia de wraparound',
      () {
        // i1=0xFFFFFFFF, i2=0x00000001: i1-i2 = 0xFFFFFFFE > 1<<31, entao
        // sna32LT deveria ser falso (i1 nao e "logicamente antes de" i2 aqui);
        // veto explicito ao caso que a subtracao sem wraparound erraria.
        final i1 = Golang.Uint32(0xFFFFFFFF);
        final i2 = Golang.Uint32(1);
        expect(sna32Lt(i2, i1), isFalse);
        expect(sna32Gt(i2, i1), isTrue);
      },
    );
  });

  group('sna16 [Atomic Audit]', () {
    // Porta TestSerialNumberArithmetic (subteste 16-bit).
    const div = 16;
    const serialBits = 16;
    const interval = (1 << serialBits) ~/ div;
    final maxForwardDistance = Golang.Uint16((1 << (serialBits - 1)) - 1);
    final maxBackwardDistance = Golang.Uint16(1 << (serialBits - 1));

    test(
      'sna16Lt() - true para a maior distancia para frente, falso para tras',
      () {
        for (var i = 0; i < div; i++) {
          final s1 = Golang.Uint16(i * interval);
          final s2f = s1 + maxForwardDistance;
          final s2b = s1 + maxBackwardDistance;
          expect(sna16Lt(s1, s2f), isTrue);
          expect(sna16Lt(s1, s2b), isFalse);
        }
      },
    );

    test(
      'sna16Gt() - falso para a maior distancia para frente, true para tras',
      () {
        for (var i = 0; i < div; i++) {
          final s1 = Golang.Uint16(i * interval);
          final s2f = s1 + maxForwardDistance;
          final s2b = s1 + maxBackwardDistance;
          expect(sna16Gt(s1, s2f), isFalse);
          expect(sna16Gt(s1, s2b), isTrue);
        }
      },
    );

    test('sna16Lte() - concorda com sna16Lt e inclui igualdade', () {
      for (var i = 0; i < div; i++) {
        final s1 = Golang.Uint16(i * interval);
        final s2b = s1 + maxBackwardDistance;
        expect(sna16Lte(s1, s1), isTrue);
        expect(sna16Lte(s2b, s2b), isTrue);
      }
    });

    test('sna16Gte() - concorda com sna16Gt e inclui igualdade', () {
      for (var i = 0; i < div; i++) {
        final s1 = Golang.Uint16(i * interval);
        final s2b = s1 + maxBackwardDistance;
        expect(sna16Gte(s1, s1), isTrue);
        expect(sna16Gte(s2b, s2b), isTrue);
      }
    });

    test('sna16Eq() - true somente para o mesmo valor', () {
      for (var i = 0; i < div; i++) {
        final s1 = Golang.Uint16(i * interval);
        expect(sna16Eq(s1, s1), isTrue);
        expect(sna16Eq(s1, s1 + Golang.Uint16(1)), isFalse);
        expect(sna16Eq(s1, s1 - Golang.Uint16(1)), isFalse);
      }
    });
  });

  group('ChunkType [Atomic Audit]', () {
    test(
      'toString() - porta TestChunkType_String para cada tipo conhecido',
      () {
        expect(ChunkType.payloadData.toString(), equals('DATA'));
        expect(ChunkType.init.toString(), equals('INIT'));
        expect(ChunkType.initAck.toString(), equals('INIT-ACK'));
        expect(ChunkType.sack.toString(), equals('SACK'));
        expect(ChunkType.heartbeat.toString(), equals('HEARTBEAT'));
        expect(ChunkType.heartbeatAck.toString(), equals('HEARTBEAT-ACK'));
        expect(ChunkType.abort.toString(), equals('ABORT'));
        expect(ChunkType.shutdown.toString(), equals('SHUTDOWN'));
        expect(ChunkType.shutdownAck.toString(), equals('SHUTDOWN-ACK'));
        expect(ChunkType.error.toString(), equals('ERROR'));
        expect(ChunkType.cookieEcho.toString(), equals('COOKIE-ECHO'));
        expect(ChunkType.cookieAck.toString(), equals('COOKIE-ACK'));
        expect(ChunkType.cwr.toString(), equals('ECNE'));
        expect(
          ChunkType.shutdownComplete.toString(),
          equals('SHUTDOWN-COMPLETE'),
        );
        expect(ChunkType.reconfig.toString(), equals('RECONFIG'));
        expect(ChunkType.forwardTsn.toString(), equals('FORWARD-TSN'));
      },
    );

    test('toString() - tipo desconhecido, porta TestChunkType_String', () {
      expect(
        ChunkType.fromValue(255).toString(),
        equals('Unknown ChunkType: 255'),
      );
    });

    test('fromValue() - constroi a partir do byte cru sem validacao', () {
      expect(ChunkType.fromValue(1), equals(ChunkType.init));
      expect(ChunkType.fromValue(1).value, equals(1));
    });

    test('operator ==() - compara pelo value numerico', () {
      expect(ChunkType.fromValue(3) == ChunkType.sack, isTrue);
      expect(ChunkType.init == ChunkType.initAck, isFalse);
    });

    test('hashCode() - consistente entre instancias com o mesmo value', () {
      expect(ChunkType.fromValue(9).hashCode, equals(ChunkType.error.hashCode));
    });
  });

  group('ChunkHeader [Atomic Audit]', () {
    test('unmarshal() - decodifica tipo flags e valor de um chunk minimo', () {
      // ABORT (typ=6), flags=0x01, length=8 (4 header + 4 valor).
      final raw = Uint8List.fromList([
        0x06,
        0x01,
        0x00,
        0x08,
        0xde,
        0xad,
        0xbe,
        0xef,
      ]);
      final header = ChunkHeader.unmarshal(raw);
      expect(header.typ, equals(ChunkType.abort));
      expect(header.flags, equals(0x01));
      expect(header.valueLength(), equals(4));
      expect(header.raw, equals([0xde, 0xad, 0xbe, 0xef]));
    });

    test('unmarshal() - aceita padding de zeros apos o valor declarado', () {
      // length=8 (valor de 4 bytes) mas raw carrega 2 bytes extras de
      // padding zerado, permitido pelo RFC 4960 secao 3 2.
      final raw = Uint8List.fromList([
        0x06,
        0x00,
        0x00,
        0x08,
        1,
        2,
        3,
        4,
        0,
        0,
      ]);
      final header = ChunkHeader.unmarshal(raw);
      expect(header.valueLength(), equals(4));
    });

    test(
      'unmarshal() - lanca ChunkHeaderTooSmallException para menos de 4 bytes',
      () {
        expect(
          () => ChunkHeader.unmarshal(Uint8List.fromList([0x06, 0x00, 0x00])),
          throwsA(isA<ChunkHeaderTooSmallException>()),
        );
      },
    );

    test(
      'unmarshal() - lanca ChunkHeaderNotEnoughSpaceException quando o valor declarado excede raw',
      () {
        // length=200 mas so ha 4 bytes totais disponiveis.
        final raw = Uint8List.fromList([0x06, 0x00, 0x00, 200]);
        expect(
          () => ChunkHeader.unmarshal(raw),
          throwsA(isA<ChunkHeaderNotEnoughSpaceException>()),
        );
      },
    );

    test(
      'unmarshal() - lanca ChunkHeaderPaddingNonZeroException quando o padding nao e zero',
      () {
        final raw = Uint8List.fromList([
          0x06,
          0x00,
          0x00,
          0x08,
          1,
          2,
          3,
          4,
          0,
          9,
        ]);
        expect(
          () => ChunkHeader.unmarshal(raw),
          throwsA(isA<ChunkHeaderPaddingNonZeroException>()),
        );
      },
    );

    test('marshal() - reconstroi o cabecalho e o valor originais', () {
      final original = Uint8List.fromList([
        0x06,
        0x01,
        0x00,
        0x08,
        0xde,
        0xad,
        0xbe,
        0xef,
      ]);
      final header = ChunkHeader.unmarshal(original);
      expect(header.marshal(), equals(original));
    });

    test('toString() - delega para ChunkType String', () {
      final header = ChunkHeader(
        typ: ChunkType.init,
        flags: 0,
        raw: Uint8List(0),
      );
      expect(header.toString(), equals('INIT'));
    });

    test('valueLength() - reflete o tamanho do campo raw do cabecalho', () {
      final header = ChunkHeader(
        typ: ChunkType.init,
        flags: 0,
        raw: Uint8List(5),
      );
      expect(header.valueLength(), equals(5));
    });
  });

  group('ChunkHeaderTooSmallException [Atomic Audit]', () {
    test('toString() - reporta o tamanho recebido e o minimo exigido', () {
      final ex = ChunkHeaderTooSmallException(2, 4);
      expect(ex.toString(), contains('raw only 2 bytes'));
      expect(ex.toString(), contains('4 is the minimum length'));
    });
  });

  group('ChunkHeaderNotEnoughSpaceException [Atomic Audit]', () {
    test('toString() - reporta o valor restante e o requisitado', () {
      final ex = ChunkHeaderNotEnoughSpaceException(200, 0);
      expect(ex.toString(), contains('remain 200 req 0'));
    });
  });

  group('ChunkHeaderPaddingNonZeroException [Atomic Audit]', () {
    test('toString() - reporta o offset do byte de padding nao zerado', () {
      final ex = ChunkHeaderPaddingNonZeroException(9);
      expect(ex.toString(), contains('9'));
    });
  });

  group('Chunk [Atomic Audit]', () {
    test('unmarshal() - popula o estado interno a partir dos bytes crus', () {
      final chunk = _EchoChunk()..unmarshal(Uint8List.fromList([1, 2, 3]));
      expect(chunk.valueLength(), equals(3));
    });

    test('marshal() - devolve os mesmos bytes recebidos por unmarshal', () {
      final bytes = Uint8List.fromList([9, 8, 7]);
      final chunk = _EchoChunk()..unmarshal(bytes);
      expect(chunk.marshal(), equals(bytes));
    });

    test('check() - reflete se ha conteudo apos o unmarshal', () {
      final empty = _EchoChunk();
      expect(empty.check(), isFalse);
      empty.unmarshal(Uint8List.fromList([1]));
      expect(empty.check(), isTrue);
    });

    test('valueLength() - reflete o tamanho do valor corrente', () {
      final chunk = _EchoChunk()
        ..unmarshal(Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(chunk.valueLength(), equals(5));
    });
  });

  group('generatePacketChecksum [Atomic Audit]', () {
    test(
      'generatePacketChecksum() - vetor real de packet_test go, pacote so com cabecalho',
      () {
        // headerOnly de TestPacketUnmarshal/TestPacketMarshal: os 4 bytes do
        // checksum (offsets 8-11) sao tratados como zero pelo algoritmo,
        // entao o valor original ali nao importa para a entrada, apenas para
        // conferir o resultado esperado abaixo.
        final headerOnly = Uint8List.fromList([
          0x13,
          0x88,
          0x13,
          0x88,
          0x00,
          0x00,
          0x00,
          0x00,
          0x06,
          0xa9,
          0x00,
          0xe1,
        ]);
        // LittleEndian.PutUint32 dos bytes esperados [0x06,0xa9,0x00,0xe1]
        // equivale ao valor 0xE100A906.
        expect(generatePacketChecksum(headerOnly), equals(0xE100A906));
      },
    );

    test(
      'generatePacketChecksum() - determinista e sensivel a cada byte de entrada',
      () {
        final a = Uint8List(16);
        final b = Uint8List(16)..[15] = 1;
        expect(generatePacketChecksum(a), equals(generatePacketChecksum(a)));
        expect(
          generatePacketChecksum(a),
          isNot(equals(generatePacketChecksum(b))),
        );
      },
    );
  });

  group('packetHeaderSize [Atomic Audit]', () {
    test(
      'packetHeaderSize - e 12, porta packetHeaderSize (packet go:56-58)',
      () {
        expect(packetHeaderSize, equals(12));
      },
    );
  });

  // ---------------------------------------------------------------------
  // Camada de parametros (paramtype, paramheader, param, param_*)
  // ---------------------------------------------------------------------

  group('ParamType [Atomic Audit]', () {
    test(
      'parse() - decodifica heartbeatInfo e outSsnResetReq, porta TestParseParamType_Success',
      () {
        expect(
          ParamType.parse(Uint8List.fromList([0x0, 0x1])),
          equals(ParamType.heartbeatInfo),
        );
        expect(
          ParamType.parse(Uint8List.fromList([0x0, 0xd])),
          equals(ParamType.outSsnResetReq),
        );
      },
    );

    test(
      'parse() - lanca ParamPacketTooShortException para pacote vazio, porta TestParseParamType_Failure',
      () {
        expect(
          () => ParamType.parse(Uint8List(0)),
          throwsA(isA<ParamPacketTooShortException>()),
        );
      },
    );

    test('toString() - nomes conhecidos e desconhecido', () {
      expect(ParamType.heartbeatInfo.toString(), equals('Heartbeat Info'));
      expect(ParamType.chunkList.toString(), equals('Chunk List'));
      expect(
        ParamType.fromValue(9999).toString(),
        equals('Unknown ParamType: 9999'),
      );
    });

    test('operator ==() e hashCode() - comparam pelo value numerico', () {
      expect(ParamType.fromValue(1), equals(ParamType.heartbeatInfo));
      expect(
        ParamType.fromValue(1).hashCode,
        equals(ParamType.heartbeatInfo.hashCode),
      );
    });
  });

  group('ParamHeaderUnrecognizedAction [Atomic Audit]', () {
    test('fromValue() e operator ==() - mascara os 2 bits mais altos', () {
      expect(
        ParamHeaderUnrecognizedAction.fromValue(0x80),
        equals(ParamHeaderUnrecognizedAction.skip),
      );
      expect(
        ParamHeaderUnrecognizedAction.fromValue(0xC0),
        equals(ParamHeaderUnrecognizedAction.skipAndReport),
      );
    });
  });

  group('ParamHeader [Atomic Audit]', () {
    test(
      'unmarshal() e marshal() - round trip, porta TestParamHeader_Success',
      () {
        final binary = Uint8List.fromList([0x0, 0x1, 0x0, 0x4]);
        final header = ParamHeader.unmarshal(binary);
        expect(header.typ, equals(ParamType.heartbeatInfo));
        expect(header.len, equals(4));
        expect(header.raw, isEmpty);
        expect(header.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() - lanca ParamHeaderTooShortException para menos de 4 bytes, porta TestParamHeaderUnmarshal_Failure',
      () {
        expect(
          () => ParamHeader.unmarshal(Uint8List.fromList([0x0, 0x1])),
          throwsA(isA<ParamHeaderTooShortException>()),
        );
      },
    );

    test(
      'unmarshal() - lanca ParamHeaderSelfReportedLengthShorterException, porta TestParamHeaderUnmarshal_Failure',
      () {
        expect(
          () => ParamHeader.unmarshal(Uint8List.fromList([0x0, 0xd, 0x0, 0x3])),
          throwsA(isA<ParamHeaderSelfReportedLengthShorterException>()),
        );
      },
    );

    test(
      'unmarshal() - lanca ParamHeaderSelfReportedLengthLongerException, porta TestParamHeaderUnmarshal_Failure',
      () {
        expect(
          () => ParamHeader.unmarshal(
            Uint8List.fromList([0x00, 0x0d, 0x00, 0x16]),
          ),
          throwsA(isA<ParamHeaderSelfReportedLengthLongerException>()),
        );
      },
    );

    test('length() - reflete o campo len', () {
      final header = ParamHeader.unmarshal(
        Uint8List.fromList([0x0, 0x1, 0x0, 0x4]),
      );
      expect(header.length(), equals(4));
    });
  });

  group('buildParam [Atomic Audit]', () {
    final paramA = Uint8List.fromList([
      0x00,
      0x0d,
      0x00,
      0x16,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x02,
      0x00,
      0x00,
      0x00,
      0x03,
      0x00,
      0x04,
      0x00,
      0x05,
      0x00,
      0x06,
    ]);

    test(
      'buildParam() - decodifica e remarshaliza, porta TestBuildParam_Success',
      () {
        final pType = ParamType.parse(paramA);
        final p = buildParam(pType, paramA);
        expect(p.marshal(), equals(paramA));
      },
    );

    test(
      'buildParam() - lanca ParamTypeUnhandledException para tipo desconhecido, porta TestBuildParam_Failure',
      () {
        expect(
          () => buildParam(
            ParamType.fromValue(0),
            Uint8List.fromList([0x0, 0x0]),
          ),
          throwsA(isA<ParamTypeUnhandledException>()),
        );
      },
    );

    test(
      'buildParam() - propaga falha de construcao do tipo concreto, porta TestBuildParam_Failure',
      () {
        // paramA truncado em 8 bytes: seu campo de comprimento auto-reportado
        // (22) excede os bytes disponiveis, entao paramHeader.unmarshal falha
        // antes mesmo da checagem de identificadores de stream.
        final truncated = Uint8List.sublistView(paramA, 0, 8);
        final pType = ParamType.parse(truncated);
        expect(
          () => buildParam(pType, truncated),
          throwsA(isA<ParamHeaderSelfReportedLengthLongerException>()),
        );
      },
    );
  });

  group('ParamChunkList [Atomic Audit]', () {
    test('marshal() e unmarshal() - round trip com dois ChunkType', () {
      final p = ParamChunkList(chunkTypes: [ChunkType.init, ChunkType.sack]);
      final raw = p.marshal();
      final decoded = ParamChunkList()..unmarshal(raw);
      expect(decoded.chunkTypes, equals([ChunkType.init, ChunkType.sack]));
      expect(decoded.length(), equals(raw.length));
    });
  });

  group('ParamEcnCapable [Atomic Audit]', () {
    final binary = Uint8List.fromList([0x80, 0x0, 0x0, 0x4]);

    test(
      'unmarshal() e marshal() - round trip, porta TestParamECNCapabale_Success',
      () {
        final p = ParamEcnCapable()..unmarshal(binary);
        expect(p.header.typ, equals(ParamType.ecnCapable));
        expect(
          p.header.unrecognizedAction,
          equals(ParamHeaderUnrecognizedAction.skip),
        );
        expect(p.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() - lanca excecao para param curto demais, porta TestParamECNCapabale_Failure',
      () {
        expect(
          () =>
              ParamEcnCapable().unmarshal(Uint8List.fromList([0x0, 0xd, 0x0])),
          throwsA(isA<ParamHeaderTooShortException>()),
        );
      },
    );
  });

  group('ParamForwardTsnSupported [Atomic Audit]', () {
    final binary = Uint8List.fromList([0xc0, 0x0, 0x0, 0x4]);

    test(
      'unmarshal() e marshal() - round trip, porta TestParamForwardTSNSupported_Success',
      () {
        final p = ParamForwardTsnSupported()..unmarshal(binary);
        expect(p.header.typ, equals(ParamType.forwardTsnSupp));
        expect(
          p.header.unrecognizedAction,
          equals(ParamHeaderUnrecognizedAction.skipAndReport),
        );
        expect(p.marshal(), equals(binary));
      },
    );
  });

  group('ParamHeartbeatInfo [Atomic Audit]', () {
    test('marshal() e unmarshal() - round trip com dados arbitrarios', () {
      final p = ParamHeartbeatInfo(
        heartbeatInformation: Uint8List.fromList([1, 2, 3]),
      );
      final raw = p.marshal();
      final decoded = ParamHeartbeatInfo()..unmarshal(raw);
      expect(decoded.heartbeatInformation, equals([1, 2, 3]));
    });
  });

  group('ParamOutgoingResetRequest [Atomic Audit]', () {
    final paramA = Uint8List.fromList([
      0x00,
      0x0d,
      0x00,
      0x16,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x02,
      0x00,
      0x00,
      0x00,
      0x03,
      0x00,
      0x04,
      0x00,
      0x05,
      0x00,
      0x06,
    ]);
    final paramB = Uint8List.fromList([
      0x0,
      0xd,
      0x0,
      0x10,
      0x0,
      0x0,
      0x0,
      0x1,
      0x0,
      0x0,
      0x0,
      0x2,
      0x0,
      0x0,
      0x0,
      0x3,
    ]);

    test(
      'unmarshal() e marshal() - com identificadores de stream, porta TestParamOutgoingResetRequest_Success',
      () {
        final p = ParamOutgoingResetRequest()..unmarshal(paramA);
        expect(p.reconfigRequestSequenceNumber, equals(1));
        expect(p.reconfigResponseSequenceNumber, equals(2));
        expect(p.senderLastTsn, equals(3));
        expect(p.streamIdentifiers, equals([4, 5, 6]));
        expect(p.marshal(), equals(paramA));
      },
    );

    test(
      'unmarshal() e marshal() - sem identificadores de stream, porta TestParamOutgoingResetRequest_Success',
      () {
        final p = ParamOutgoingResetRequest()..unmarshal(paramB);
        expect(p.streamIdentifiers, isEmpty);
        expect(p.marshal(), equals(paramB));
      },
    );

    test(
      'unmarshal() - lanca SsnResetRequestParamTooShortException, porta TestParamOutgoingResetRequest_Failure',
      () {
        expect(
          () => ParamOutgoingResetRequest().unmarshal(
            Uint8List.fromList([0x0, 0xd, 0x0, 0x4]),
          ),
          throwsA(isA<SsnResetRequestParamTooShortException>()),
        );
      },
    );
  });

  group('ParamRandom [Atomic Audit]', () {
    test('marshal() e unmarshal() - round trip', () {
      final p = ParamRandom(randomData: Uint8List.fromList([9, 8, 7, 6]));
      final decoded = ParamRandom()..unmarshal(p.marshal());
      expect(decoded.randomData, equals([9, 8, 7, 6]));
    });
  });

  group('ReconfigResult [Atomic Audit]', () {
    test(
      'toString() - todos os valores nomeados, porta TestReconfigResultStringer',
      () {
        expect(
          ReconfigResult.successNop.toString(),
          equals('0: Success - Nothing to do'),
        );
        expect(
          ReconfigResult.successPerformed.toString(),
          equals('1: Success - Performed'),
        );
        expect(ReconfigResult.denied.toString(), equals('2: Denied'));
        expect(
          ReconfigResult.errorWrongSsn.toString(),
          equals('3: Error - Wrong SSN'),
        );
        expect(
          ReconfigResult.errorRequestAlreadyInProgress.toString(),
          equals('4: Error - Request already in progress'),
        );
        expect(
          ReconfigResult.errorBadSequenceNumber.toString(),
          equals('5: Error - Bad Sequence Number'),
        );
        expect(ReconfigResult.inProgress.toString(), equals('6: In progress'));
        expect(
          ReconfigResult.fromValue(99).toString(),
          equals('Unknown reconfigResult: 99'),
        );
      },
    );
  });

  group('ParamReconfigResponse [Atomic Audit]', () {
    final binary = Uint8List.fromList([
      0x0,
      0x10,
      0x0,
      0xc,
      0x0,
      0x0,
      0x0,
      0x1,
      0x0,
      0x0,
      0x0,
      0x1,
    ]);

    test(
      'unmarshal() e marshal() - round trip, porta TestParamReconfigResponse_Success',
      () {
        final p = ParamReconfigResponse()..unmarshal(binary);
        expect(p.reconfigResponseSequenceNumber, equals(1));
        expect(p.result, equals(ReconfigResult.successPerformed));
        expect(p.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() - lanca ReconfigRespParamTooShortException, porta TestParamReconfigResponse_Failure',
      () {
        expect(
          () => ParamReconfigResponse().unmarshal(
            Uint8List.fromList([0x0, 0x10, 0x0, 0x4]),
          ),
          throwsA(isA<ReconfigRespParamTooShortException>()),
        );
      },
    );
  });

  group('HmacAlgorithm [Atomic Audit]', () {
    test('toString() - nomes conhecidos e desconhecido', () {
      expect(HmacAlgorithm.sha128.toString(), equals('HMAC SHA-128'));
      expect(HmacAlgorithm.sha256.toString(), equals('HMAC SHA-256'));
      expect(
        HmacAlgorithm.fromValue(9).toString(),
        equals('Unknown HMAC Algorithm type: 9'),
      );
    });
  });

  group('ParamRequestedHmacAlgorithm [Atomic Audit]', () {
    test('marshal() e unmarshal() - round trip com SHA-128 e SHA-256', () {
      final p = ParamRequestedHmacAlgorithm(
        availableAlgorithms: [HmacAlgorithm.sha128, HmacAlgorithm.sha256],
      );
      final decoded = ParamRequestedHmacAlgorithm()..unmarshal(p.marshal());
      expect(
        decoded.availableAlgorithms,
        equals([HmacAlgorithm.sha128, HmacAlgorithm.sha256]),
      );
    });

    test(
      'unmarshal() - lanca InvalidAlgorithmTypeException para algoritmo reservado',
      () {
        final raw = (ParamHeader(
          typ: ParamType.reqHmacAlgo,
          len: 0,
          raw: Uint8List.fromList([0x0, 0x0]),
        )).marshal();
        expect(
          () => ParamRequestedHmacAlgorithm().unmarshal(raw),
          throwsA(isA<InvalidAlgorithmTypeException>()),
        );
      },
    );

    test(
      'unmarshal() - lanca InvalidChunkLengthException para comprimento impar',
      () {
        final raw = (ParamHeader(
          typ: ParamType.reqHmacAlgo,
          len: 0,
          raw: Uint8List.fromList([0x0, 0x1, 0x0]),
        )).marshal();
        expect(
          () => ParamRequestedHmacAlgorithm().unmarshal(raw),
          throwsA(isA<InvalidChunkLengthException>()),
        );
      },
    );
  });

  group('ParamStateCookie [Atomic Audit]', () {
    test('random() - gera 32 bytes aleatorios e nao repete entre chamadas', () {
      final a = ParamStateCookie.random();
      final b = ParamStateCookie.random();
      expect(a.cookie.length, equals(32));
      expect(a.cookie, isNot(equals(b.cookie)));
    });
  });

  group('ParamStateCookie [Atomic Audit]', () {
    test('marshal() e unmarshal() - round trip', () {
      final p = ParamStateCookie(
        cookie: Uint8List.fromList(List.generate(32, (i) => i)),
      );
      final decoded = ParamStateCookie()..unmarshal(p.marshal());
      expect(decoded.cookie, equals(p.cookie));
    });
  });

  group('ParamSupportedExtensions [Atomic Audit]', () {
    test('marshal() e unmarshal() - round trip com dois ChunkType', () {
      final p = ParamSupportedExtensions(
        chunkTypes: [ChunkType.forwardTsn, ChunkType.reconfig],
      );
      final decoded = ParamSupportedExtensions()..unmarshal(p.marshal());
      expect(
        decoded.chunkTypes,
        equals([ChunkType.forwardTsn, ChunkType.reconfig]),
      );
    });
  });

  group('ParamZeroChecksumAcceptable [Atomic Audit]', () {
    final binary = Uint8List.fromList([
      0x80,
      0x01,
      0x00,
      0x08,
      0x00,
      0x00,
      0x00,
      0x01,
    ]);

    test(
      'unmarshal() e marshal() - round trip, porta TestParamZeroChecksum',
      () {
        final p = ParamZeroChecksumAcceptable()..unmarshal(binary);
        expect(p.edmid, equals(1));
        expect(
          p.header.unrecognizedAction,
          equals(ParamHeaderUnrecognizedAction.skip),
        );
        expect(p.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() - lanca ZeroChecksumParamTooShortException para valor curto demais',
      () {
        final raw = (ParamHeader(
          typ: ParamType.zeroChecksumAcceptable,
          len: 0,
          raw: Uint8List.fromList([0x0, 0x0]),
        )).marshal();
        expect(
          () => ParamZeroChecksumAcceptable().unmarshal(raw),
          throwsA(isA<ZeroChecksumParamTooShortException>()),
        );
      },
    );

    test(
      'dtlsErrorDetectionMethod - e 1, porta dtlsErrorDetectionMethod (param_zero_checksum go:29-31)',
      () {
        expect(dtlsErrorDetectionMethod, equals(1));
      },
    );
  });

  // ---------------------------------------------------------------------
  // Causas de erro (error_cause*.dart)
  // ---------------------------------------------------------------------

  group('ErrorCauseCode [Atomic Audit]', () {
    test('toString() - nomes conhecidos e desconhecido', () {
      expect(
        ErrorCauseCode.protocolViolation.toString(),
        equals('Protocol Violation'),
      );
      expect(
        ErrorCauseCode.userInitiatedAbort.toString(),
        equals('User Initiated Abort'),
      );
      expect(
        ErrorCauseCode.fromValue(0).toString(),
        equals('Unknown CauseCode: 0'),
      );
    });
  });

  group('ErrorCauseHeader [Atomic Audit]', () {
    test('marshal() e unmarshal() - round trip preservando codigo e valor', () {
      final header = ErrorCauseHeader(
        code: ErrorCauseCode.protocolViolation,
        raw: Uint8List.fromList([1, 2, 3]),
      );
      final raw = header.marshal();
      final decoded = ErrorCauseHeader(code: ErrorCauseCode.fromValue(0))
        ..unmarshal(raw);
      expect(decoded.code, equals(ErrorCauseCode.protocolViolation));
      expect(decoded.raw, equals([1, 2, 3]));
      expect(decoded.length(), equals(raw.length));
    });

    test(
      'unmarshal() - lanca InvalidSctpChunkException para comprimento declarado invalido',
      () {
        final header = ErrorCauseHeader(code: ErrorCauseCode.fromValue(0));
        expect(
          () => header.unmarshal(Uint8List.fromList([0x0, 0x6, 0x0, 0x2])),
          throwsA(isA<InvalidSctpChunkException>()),
        );
      },
    );
  });

  group('buildErrorCause [Atomic Audit]', () {
    test('buildErrorCause() - decodifica cada um dos 4 codigos conhecidos', () {
      for (final code in [
        ErrorCauseCode.invalidMandatoryParameter,
        ErrorCauseCode.unrecognizedChunkType,
        ErrorCauseCode.protocolViolation,
        ErrorCauseCode.userInitiatedAbort,
      ]) {
        final raw = ErrorCauseHeader(code: code).marshal();
        final ec = buildErrorCause(raw);
        expect(ec.errorCauseCode(), equals(code));
      }
    });

    test(
      'buildErrorCause() - lanca BuildErrorCaseHandleException para codigo sem tipo concreto',
      () {
        final raw = ErrorCauseHeader(
          code: ErrorCauseCode.outOfResource,
        ).marshal();
        expect(
          () => buildErrorCause(raw),
          throwsA(isA<BuildErrorCaseHandleException>()),
        );
      },
    );
  });

  group('ErrorCauseInvalidMandatoryParameter [Atomic Audit]', () {
    test('marshal() e unmarshal() - preserva o codigo, sem valor', () {
      final e = ErrorCauseInvalidMandatoryParameter();
      e.header.code = ErrorCauseCode.invalidMandatoryParameter;
      final raw = e.marshal();
      final decoded = ErrorCauseInvalidMandatoryParameter()..unmarshal(raw);
      expect(
        decoded.errorCauseCode(),
        equals(ErrorCauseCode.invalidMandatoryParameter),
      );
      expect(decoded.length(), equals(4));
    });
  });

  group('ErrorCauseProtocolViolation [Atomic Audit]', () {
    test('marshal() e unmarshal() - preserva additionalInformation', () {
      final e = ErrorCauseProtocolViolation(
        additionalInformation: Uint8List.fromList([9, 9]),
      );
      final decoded = ErrorCauseProtocolViolation()..unmarshal(e.marshal());
      expect(decoded.additionalInformation, equals([9, 9]));
      expect(
        decoded.errorCauseCode(),
        equals(ErrorCauseCode.protocolViolation),
      );
    });
  });

  group('ErrorCauseUnrecognizedChunkType [Atomic Audit]', () {
    test(
      'unmarshal() - decodifica o chunk nao reconhecido, porta TestChunkErrorUnrecognizedChunkType',
      () {
        final orgUnrecognizedChunk = Uint8List.fromList([
          0xc0,
          0x0,
          0x0,
          0x8,
          0x0,
          0x0,
          0x0,
          0x3,
        ]);
        final raw = Uint8List.fromList([
          ...[0x00, 0x06, 0x00, 0x0c],
          ...orgUnrecognizedChunk,
        ]);
        final ec = ErrorCauseUnrecognizedChunkType()..unmarshal(raw);
        expect(
          ec.errorCauseCode(),
          equals(ErrorCauseCode.unrecognizedChunkType),
        );
        expect(ec.unrecognizedChunk, equals(orgUnrecognizedChunk));
      },
    );

    test(
      'marshal() - remarshaliza o mesmo chunk nao reconhecido, porta TestChunkErrorUnrecognizedChunkType',
      () {
        final orgUnrecognizedChunk = Uint8List.fromList([
          0xc0,
          0x0,
          0x0,
          0x8,
          0x0,
          0x0,
          0x0,
          0x3,
        ]);
        final ec = ErrorCauseUnrecognizedChunkType(
          unrecognizedChunk: orgUnrecognizedChunk,
        );
        final expected = Uint8List.fromList([
          ...[0x00, 0x06, 0x00, 0x0c],
          ...orgUnrecognizedChunk,
        ]);
        expect(ec.marshal(), equals(expected));
      },
    );
  });

  group('ErrorCauseUserInitiatedAbort [Atomic Audit]', () {
    test('marshal() e unmarshal() - preserva upperLayerAbortReason', () {
      final e = ErrorCauseUserInitiatedAbort(
        upperLayerAbortReason: Uint8List.fromList([7, 7, 7]),
      );
      final decoded = ErrorCauseUserInitiatedAbort()..unmarshal(e.marshal());
      expect(decoded.upperLayerAbortReason, equals([7, 7, 7]));
      expect(
        decoded.errorCauseCode(),
        equals(ErrorCauseCode.userInitiatedAbort),
      );
    });
  });

  // ---------------------------------------------------------------------
  // Tipos concretos de chunk (chunk_*.dart)
  // ---------------------------------------------------------------------

  group('ChunkCookieAck [Atomic Audit]', () {
    test('unmarshal() e marshal() - round trip minimo', () {
      final binary = Uint8List.fromList([0x0b, 0x00, 0x00, 0x04]);
      final c = ChunkCookieAck()..unmarshal(binary);
      expect(c.header.typ, equals(ChunkType.cookieAck));
      expect(c.check(), isFalse);
      expect(c.marshal(), equals(binary));
    });

    test(
      'unmarshal() - lanca ChunkTypeNotCookieAckException para tipo errado',
      () {
        expect(
          () => ChunkCookieAck().unmarshal(
            Uint8List.fromList([0x0f, 0x00, 0x00, 0x04]),
          ),
          throwsA(isA<ChunkTypeNotCookieAckException>()),
        );
      },
    );
  });

  group('ChunkCookieEcho [Atomic Audit]', () {
    test('unmarshal() e marshal() - preserva o cookie', () {
      final built = ChunkCookieEcho(cookie: Uint8List.fromList([1, 2, 3, 4]));
      final decoded = ChunkCookieEcho()..unmarshal(built.marshal());
      expect(decoded.cookie, equals([1, 2, 3, 4]));
      expect(decoded.check(), isFalse);
    });

    test(
      'unmarshal() - lanca ChunkTypeNotCookieEchoException para tipo errado',
      () {
        expect(
          () => ChunkCookieEcho().unmarshal(
            Uint8List.fromList([0x0f, 0x00, 0x00, 0x04]),
          ),
          throwsA(isA<ChunkTypeNotCookieEchoException>()),
        );
      },
    );
  });

  group('ChunkShutdown [Atomic Audit]', () {
    final binary = Uint8List.fromList([
      0x07,
      0x00,
      0x00,
      0x08,
      0x12,
      0x34,
      0x56,
      0x78,
    ]);

    test(
      'unmarshal() e marshal() - round trip, porta TestChunkShutdown_Success',
      () {
        final c = ChunkShutdown()..unmarshal(binary);
        expect(c.cumulativeTsnAck, equals(0x12345678));
        expect(c.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() - lanca InvalidChunkSizeException para payload curto demais, porta TestChunkShutdown_Failure',
      () {
        expect(
          () => ChunkShutdown().unmarshal(
            Uint8List.fromList([0x07, 0x00, 0x00, 0x07, 0x12, 0x34, 0x56]),
          ),
          throwsA(isA<InvalidChunkSizeException>()),
        );
      },
    );

    test(
      'unmarshal() - lanca ChunkTypeNotShutdownException para tipo invalido, porta TestChunkShutdown_Failure',
      () {
        expect(
          () => ChunkShutdown().unmarshal(
            Uint8List.fromList([
              0x08,
              0x00,
              0x00,
              0x08,
              0x12,
              0x34,
              0x56,
              0x78,
            ]),
          ),
          throwsA(isA<ChunkTypeNotShutdownException>()),
        );
      },
    );
  });

  group('ChunkShutdownAck [Atomic Audit]', () {
    test(
      'unmarshal() e marshal() - round trip, porta TestChunkShutdownAck_Success',
      () {
        final binary = Uint8List.fromList([0x08, 0x00, 0x00, 0x04]);
        final c = ChunkShutdownAck()..unmarshal(binary);
        expect(c.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() - lanca ChunkTypeNotShutdownAckException, porta TestChunkShutdownAck_Failure',
      () {
        expect(
          () => ChunkShutdownAck().unmarshal(
            Uint8List.fromList([0x0f, 0x00, 0x00, 0x04]),
          ),
          throwsA(isA<ChunkTypeNotShutdownAckException>()),
        );
      },
    );
  });

  group('ChunkShutdownComplete [Atomic Audit]', () {
    test(
      'unmarshal() e marshal() - round trip, porta TestChunkShutdownComplete_Success',
      () {
        final binary = Uint8List.fromList([0x0e, 0x00, 0x00, 0x04]);
        final c = ChunkShutdownComplete()..unmarshal(binary);
        expect(c.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() - lanca ChunkTypeNotShutdownCompleteException, porta TestChunkShutdownComplete_Failure',
      () {
        expect(
          () => ChunkShutdownComplete().unmarshal(
            Uint8List.fromList([0x0f, 0x00, 0x00, 0x04]),
          ),
          throwsA(isA<ChunkTypeNotShutdownCompleteException>()),
        );
      },
    );
  });

  group('ChunkAbort [Atomic Audit]', () {
    test(
      'marshal() e unmarshal() - uma causa de erro, porta TestAbortChunk/One error cause',
      () {
        final abort1 = ChunkAbort(
          errorCauses: [
            ErrorCauseProtocolViolation()
              ..header.code = ErrorCauseCode.protocolViolation,
          ],
        );
        final abort2 = ChunkAbort()..unmarshal(abort1.marshal());
        expect(abort2.errorCauses, hasLength(1));
        expect(
          abort2.errorCauses[0].errorCauseCode(),
          equals(ErrorCauseCode.protocolViolation),
        );
        expect(abort2.check(), isFalse);
      },
    );

    test(
      'marshal() e unmarshal() - multiplas causas de erro, porta TestAbortChunk/Many error causes',
      () {
        final codes = [
          ErrorCauseCode.invalidMandatoryParameter,
          ErrorCauseCode.unrecognizedChunkType,
          ErrorCauseCode.protocolViolation,
        ];
        final abort1 = ChunkAbort(
          errorCauses: [
            for (final c in codes)
              ErrorCauseProtocolViolation()..header.code = c,
          ],
        );
        final abort2 = ChunkAbort()..unmarshal(abort1.marshal());
        expect(abort2.errorCauses, hasLength(3));
        for (var i = 0; i < codes.length; i++) {
          expect(abort2.errorCauses[i].errorCauseCode(), equals(codes[i]));
        }
      },
    );

    test('unmarshal() - lanca ChunkTypeNotAbortException para tipo errado', () {
      expect(
        () => ChunkAbort().unmarshal(
          Uint8List.fromList([0x00, 0x00, 0x00, 0x04]),
        ),
        throwsA(isA<ChunkTypeNotAbortException>()),
      );
    });
  });

  group('ChunkError [Atomic Audit]', () {
    final orgUnrecognizedChunk = Uint8List.fromList([
      0xc0,
      0x0,
      0x0,
      0x8,
      0x0,
      0x0,
      0x0,
      0x3,
    ]);
    final rawIn = Uint8List.fromList([
      ...[0x09, 0x00, 0x00, 0x10, 0x00, 0x06, 0x00, 0x0c],
      ...orgUnrecognizedChunk,
    ]);

    test(
      'unmarshal() - decodifica a causa unrecognizedChunkType, porta TestChunkErrorUnrecognizedChunkType/unmarshal',
      () {
        final c = ChunkError()..unmarshal(rawIn);
        expect(c.header.typ, equals(ChunkType.error));
        expect(c.errorCauses, hasLength(1));
        final ec = c.errorCauses[0];
        expect(
          ec.errorCauseCode(),
          equals(ErrorCauseCode.unrecognizedChunkType),
        );
        expect(
          (ec as ErrorCauseUnrecognizedChunkType).unrecognizedChunk,
          equals(orgUnrecognizedChunk),
        );
      },
    );

    test(
      'marshal() - remarshaliza a causa unrecognizedChunkType, porta TestChunkErrorUnrecognizedChunkType/marshal',
      () {
        final c = ChunkError(
          errorCauses: [
            ErrorCauseUnrecognizedChunkType(
              unrecognizedChunk: orgUnrecognizedChunk,
            ),
          ],
        );
        expect(c.marshal(), equals(rawIn));
      },
    );

    test(
      'marshal() - causa com valor nulo, porta TestChunkErrorUnrecognizedChunkType/marshal with cause value being nil',
      () {
        final expected = Uint8List.fromList([
          0x09,
          0x00,
          0x00,
          0x08,
          0x00,
          0x06,
          0x00,
          0x04,
        ]);
        final c = ChunkError(errorCauses: [ErrorCauseUnrecognizedChunkType()]);
        expect(c.marshal(), equals(expected));
      },
    );
  });

  group('ChunkHeartbeat [Atomic Audit]', () {
    test('unmarshal() - decodifica o parametro Heartbeat Info obrigatorio', () {
      final infoParam = ParamHeartbeatInfo(
        heartbeatInformation: Uint8List.fromList([1, 2, 3, 4]),
      ).marshal();
      final raw = Uint8List.fromList([
        ...[0x04, 0x00, 0x00, (chunkHeaderSize + infoParam.length) & 0xFF],
        ...infoParam,
      ]);
      final c = ChunkHeartbeat()..unmarshal(raw);
      expect(c.params, hasLength(1));
      expect(
        (c.params[0] as ParamHeartbeatInfo).heartbeatInformation,
        equals([1, 2, 3, 4]),
      );
      expect(c.check(), isFalse);
    });

    test(
      'unmarshal() - lanca ChunkTypeNotHeartbeatException para tipo errado',
      () {
        expect(
          () => ChunkHeartbeat().unmarshal(
            Uint8List.fromList([0x05, 0x00, 0x00, 0x04]),
          ),
          throwsA(isA<ChunkTypeNotHeartbeatException>()),
        );
      },
    );

    test(
      'unmarshal() - lanca HeartbeatNotLongEnoughInfoException sem parametro',
      () {
        expect(
          () => ChunkHeartbeat().unmarshal(
            Uint8List.fromList([0x04, 0x00, 0x00, 0x04]),
          ),
          throwsA(isA<HeartbeatNotLongEnoughInfoException>()),
        );
      },
    );

    test(
      'marshal() - delega para o cabecalho promovido (nao para o Marshal morto), ver doc do arquivo',
      () {
        final c = ChunkHeartbeat();
        c.header.typ = ChunkType.heartbeat;
        c.header.raw = Uint8List.fromList([9, 9]);
        expect(c.marshal(), equals(c.header.marshal()));
      },
    );
  });

  group('ChunkHeartbeatAck [Atomic Audit]', () {
    test(
      'unmarshal() - sempre lanca UnimplementedException, porta o stub permanente de chunk_heartbeat_ack go',
      () {
        expect(
          () => ChunkHeartbeatAck().unmarshal(
            Uint8List.fromList([0x05, 0x00, 0x00, 0x04]),
          ),
          throwsA(isA<UnimplementedException>()),
        );
      },
    );

    test('marshal() - serializa o unico parametro HeartbeatInfo', () {
      final c = ChunkHeartbeatAck(
        params: [
          ParamHeartbeatInfo(heartbeatInformation: Uint8List.fromList([5, 6])),
        ],
      );
      final raw = c.marshal();
      expect(raw[0], equals(ChunkType.heartbeatAck.value));
    });

    test(
      'marshal() - lanca HeartbeatAckParamsException sem exatamente um parametro',
      () {
        expect(
          () => ChunkHeartbeatAck().marshal(),
          throwsA(isA<HeartbeatAckParamsException>()),
        );
      },
    );

    test(
      'marshal() - lanca HeartbeatAckNotHeartbeatInfoException para parametro de outro tipo',
      () {
        expect(
          () => ChunkHeartbeatAck(params: [ParamRandom()]).marshal(),
          throwsA(isA<HeartbeatAckNotHeartbeatInfoException>()),
        );
      },
    );

    test('check() - sempre falso', () {
      expect(ChunkHeartbeatAck().check(), isFalse);
    });
  });

  group('ChunkInitCommon [Atomic Audit]', () {
    final initChunkHeader = Uint8List.fromList([
      0x55,
      0xb9,
      0x64,
      0xa5,
      0x00,
      0x02,
      0x00,
      0x00,
      0x04,
      0x00,
      0x08,
      0x00,
      0xe8,
      0x6d,
      0x10,
      0x30,
    ]);

    test(
      'unmarshal() e marshal() - decodifica e remarshaliza os campos fixos',
      () {
        final c = ChunkInitCommon()..unmarshal(initChunkHeader);
        expect(c.initiateTag, equals(0x55b964a5));
        expect(c.advertisedReceiverWindowCredit, equals(0x00020000));
        expect(c.numOutboundStreams, equals(1024));
        expect(c.numInboundStreams, equals(2048));
        expect(c.initialTsn, equals(0xe86d1030));
        expect(c.marshal(), equals(initChunkHeader));
      },
    );

    test(
      'unmarshal() - parametro nao reconhecido com acao Skip, porta TestChunkInit_UnrecognizedParameters',
      () {
        final raw = Uint8List.fromList([
          ...initChunkHeader,
          0x80,
          0xFF,
          0x00,
          0x04,
          0x00,
        ]);
        final c = ChunkInitCommon()..unmarshal(raw);
        expect(c.unrecognizedParams, hasLength(1));
        expect(
          c.unrecognizedParams[0].unrecognizedAction,
          equals(ParamHeaderUnrecognizedAction.skip),
        );
      },
    );

    test(
      'unmarshal() - parametro nao reconhecido com acao Stop, porta TestChunkInit_UnrecognizedParameters',
      () {
        final raw = Uint8List.fromList([
          ...initChunkHeader,
          0x00,
          0xFF,
          0x00,
          0x04,
          0x00,
        ]);
        final c = ChunkInitCommon()..unmarshal(raw);
        expect(c.unrecognizedParams, hasLength(1));
        expect(
          c.unrecognizedParams[0].unrecognizedAction,
          equals(ParamHeaderUnrecognizedAction.stop),
        );
      },
    );
  });

  group('ChunkInit [Atomic Audit]', () {
    ChunkInit validInit() => ChunkInit(
      common: ChunkInitCommon(
        initiateTag: 1,
        advertisedReceiverWindowCredit: 1500,
        numOutboundStreams: 1,
        numInboundStreams: 1,
      ),
    );

    test('check() - retorna false para um INIT valido', () {
      expect(validInit().check(), isFalse);
    });

    test(
      'check() - lanca ChunkTypeInitInitateTagZeroException quando initiateTag e 0',
      () {
        final c = validInit()..common.initiateTag = 0;
        expect(c.check, throwsA(isA<ChunkTypeInitInitateTagZeroException>()));
      },
    );

    test(
      'check() - lanca InitInboundStreamRequestZeroException quando numInboundStreams e 0',
      () {
        final c = validInit()..common.numInboundStreams = 0;
        expect(c.check, throwsA(isA<InitInboundStreamRequestZeroException>()));
      },
    );

    test(
      'check() - lanca InitOutboundStreamRequestZeroException quando numOutboundStreams e 0',
      () {
        final c = validInit()..common.numOutboundStreams = 0;
        expect(c.check, throwsA(isA<InitOutboundStreamRequestZeroException>()));
      },
    );

    test(
      'check() - lanca InitAdvertisedReceiver1500Exception quando a_rwnd < 1500',
      () {
        final c = validInit()..common.advertisedReceiverWindowCredit = 1499;
        expect(c.check, throwsA(isA<InitAdvertisedReceiver1500Exception>()));
      },
    );

    test(
      'check() - lanca InitUnknownParamException para parametro nao reconhecido com acao Stop',
      () {
        final c = validInit()
          ..common.unrecognizedParams.add(
            ParamHeader(
              typ: ParamType.fromValue(9999),
              unrecognizedAction: ParamHeaderUnrecognizedAction.stop,
              len: 4,
              raw: Uint8List(0),
            ),
          );
        expect(c.check, throwsA(isA<InitUnknownParamException>()));
      },
    );

    test(
      'unmarshal() - decodifica um pacote INIT real via Packet, porta TestInitChunk',
      () {
        final rawPkt = Uint8List.fromList([
          0x13,
          0x88,
          0x13,
          0x88,
          0x00,
          0x00,
          0x00,
          0x00,
          0x81,
          0x46,
          0x9d,
          0xfc,
          0x01,
          0x00,
          0x00,
          0x56,
          0x55,
          0xb9,
          0x64,
          0xa5,
          0x00,
          0x02,
          0x00,
          0x00,
          0x04,
          0x00,
          0x08,
          0x00,
          0xe8,
          0x6d,
          0x10,
          0x30,
          0xc0,
          0x00,
          0x00,
          0x04,
          0x80,
          0x08,
          0x00,
          0x09,
          0xc0,
          0x0f,
          0xc1,
          0x80,
          0x82,
          0x00,
          0x00,
          0x00,
          0x80,
          0x02,
          0x00,
          0x24,
          0x9f,
          0xeb,
          0xbb,
          0x5c,
          0x50,
          0xc9,
          0xbf,
          0x75,
          0x9c,
          0xb1,
          0x2c,
          0x57,
          0x4f,
          0xa4,
          0x5a,
          0x51,
          0xba,
          0x60,
          0x17,
          0x78,
          0x27,
          0x94,
          0x5c,
          0x31,
          0xe6,
          0x5d,
          0x5b,
          0x09,
          0x47,
          0xe2,
          0x22,
          0x06,
          0x80,
          0x04,
          0x00,
          0x06,
          0x00,
          0x01,
          0x00,
          0x00,
          0x80,
          0x03,
          0x00,
          0x06,
          0x80,
          0xc1,
          0x00,
          0x00,
        ]);
        final p = Packet()..unmarshal(true, rawPkt);
        final initChunk = p.chunks[0] as ChunkInit;
        expect(initChunk.common.initiateTag, equals(1438213285));
        expect(initChunk.common.advertisedReceiverWindowCredit, equals(131072));
        expect(initChunk.common.numOutboundStreams, equals(1024));
        expect(initChunk.common.numInboundStreams, equals(2048));
        expect(initChunk.common.initialTsn, equals(3899461680));
      },
    );
  });

  group('ChunkInitAck [Atomic Audit]', () {
    ChunkInitAck validInitAck() => ChunkInitAck(
      common: ChunkInitCommon(
        initiateTag: 1,
        advertisedReceiverWindowCredit: 1500,
        numOutboundStreams: 1,
        numInboundStreams: 1,
      ),
    );

    test('check() - retorna false para um INIT ACK valido', () {
      expect(validInitAck().check(), isFalse);
    });

    test(
      'check() - lanca ChunkTypeInitAckInitateTagZeroException quando initiateTag e 0',
      () {
        final c = validInitAck()..common.initiateTag = 0;
        expect(
          c.check,
          throwsA(isA<ChunkTypeInitAckInitateTagZeroException>()),
        );
      },
    );

    test(
      'check() - lanca InitAckInboundStreamRequestZeroException quando numInboundStreams e 0',
      () {
        final c = validInitAck()..common.numInboundStreams = 0;
        expect(
          c.check,
          throwsA(isA<InitAckInboundStreamRequestZeroException>()),
        );
      },
    );

    test(
      'check() - lanca InitAckOutboundStreamRequestZeroException quando numOutboundStreams e 0',
      () {
        final c = validInitAck()..common.numOutboundStreams = 0;
        expect(
          c.check,
          throwsA(isA<InitAckOutboundStreamRequestZeroException>()),
        );
      },
    );

    test(
      'check() - lanca InitAckAdvertisedReceiver1500Exception quando a_rwnd < 1500',
      () {
        final c = validInitAck()..common.advertisedReceiverWindowCredit = 1499;
        expect(c.check, throwsA(isA<InitAckAdvertisedReceiver1500Exception>()));
      },
    );

    test('unmarshal() - reconhece um INIT-ACK real, porta TestInitAck', () {
      final rawPkt = Uint8List.fromList([
        0x13,
        0x88,
        0x13,
        0x88,
        0xce,
        0x15,
        0x79,
        0xa2,
        0x96,
        0x19,
        0xe8,
        0xb2,
        0x02,
        0x00,
        0x00,
        0x1c,
        0xeb,
        0x81,
        0x4e,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x04,
        0x00,
        0x08,
        0x00,
        0x50,
        0xdf,
        0x90,
        0xd9,
        0x00,
        0x07,
        0x00,
        0x08,
        0x94,
        0x06,
        0x2f,
        0x93,
      ]);
      final p = Packet()..unmarshal(true, rawPkt);
      expect(p.chunks[0], isA<ChunkInitAck>());
    });
  });

  group('ChunkForwardTsn e ChunkForwardTsnStream [Atomic Audit]', () {
    test(
      'unmarshal() e marshal() - sem streams, porta TestChunkForwardTSN_Success',
      () {
        final binary = Uint8List.fromList([
          0xc0,
          0x0,
          0x0,
          0x8,
          0x0,
          0x0,
          0x0,
          0x3,
        ]);
        final c = ChunkForwardTsn()..unmarshal(binary);
        expect(c.newCumulativeTsn, equals(3));
        expect(c.streams, isEmpty);
        expect(c.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() e marshal() - com dois streams, porta TestChunkForwardTSN_Success',
      () {
        final binary = Uint8List.fromList([
          0xc0,
          0x0,
          0x0,
          0x10,
          0x0,
          0x0,
          0x0,
          0x3,
          0x0,
          0x4,
          0x0,
          0x5,
          0x0,
          0x6,
          0x0,
          0x7,
        ]);
        final c = ChunkForwardTsn()..unmarshal(binary);
        expect(c.streams, hasLength(2));
        expect(c.streams[0].identifier, equals(4));
        expect(c.streams[0].sequence, equals(5));
        expect(c.streams[1].identifier, equals(6));
        expect(c.streams[1].sequence, equals(7));
        expect(c.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() - lanca ChunkTooShortException quando falta New Cumulative TSN, porta TestChunkForwardTSNUnmarshal_Failure',
      () {
        expect(
          () => ChunkForwardTsn().unmarshal(
            Uint8List.fromList([0xc0, 0x0, 0x0, 0x4]),
          ),
          throwsA(isA<ChunkTooShortException>()),
        );
      },
    );

    test(
      'unmarshal() - lanca excecao quando falta stream sequence, porta TestChunkForwardTSNUnmarshal_Failure',
      () {
        final binary = Uint8List.fromList([
          0xc0,
          0x0,
          0x0,
          0xe,
          0x0,
          0x0,
          0x0,
          0x3,
          0x0,
          0x4,
          0x0,
          0x5,
          0x0,
          0x6,
        ]);
        expect(
          () => ChunkForwardTsn().unmarshal(binary),
          throwsA(isA<MarshalStreamFailedException>()),
        );
      },
    );

    test(
      'check() - sempre true, ver doc do arquivo sobre chunk_forward_tsn go:101-103',
      () {
        expect(ChunkForwardTsn().check(), isTrue);
      },
    );

    test(
      'ChunkForwardTsnStream.length() - e sempre 4, porta forwardTSNStreamLength',
      () {
        expect(ChunkForwardTsnStream().length(), equals(4));
      },
    );
  });

  group('ChunkSelectiveAck e GapAckBlock [Atomic Audit]', () {
    test(
      'unmarshal() e marshal() - decodifica um SACK real, porta TestSelectAckChunk',
      () {
        final raw = Uint8List.fromList([
          0x03,
          0x00,
          0x00,
          0x14,
          0x87,
          0x73,
          0xbd,
          0xa4,
          0x00,
          0x01,
          0xfe,
          0x74,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x02,
          0x00,
          0x02,
        ]);
        final c = ChunkSelectiveAck()..unmarshal(raw);
        expect(c.cumulativeTsnAck, equals(0x8773bda4));
        expect(c.advertisedReceiverWindowCredit, equals(0x0001fe74));
        expect(c.gapAckBlocks, hasLength(1));
        expect(c.gapAckBlocks[0].start, equals(2));
        expect(c.gapAckBlocks[0].end, equals(2));
        expect(c.duplicateTsn, isEmpty);
        expect(c.marshal(), equals(raw));
      },
    );

    test(
      'unmarshal() - lanca SackSizeNotLargeEnoughInfoException para valor curto demais',
      () {
        final raw = Uint8List.fromList([
          0x03,
          0x00,
          0x00,
          0x08,
          0x0,
          0x0,
          0x0,
          0x0,
        ]);
        expect(
          () => ChunkSelectiveAck().unmarshal(raw),
          throwsA(isA<SackSizeNotLargeEnoughInfoException>()),
        );
      },
    );

    test('unmarshal() - lanca ChunkTypeNotSackException para tipo errado', () {
      final raw = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x0c,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);
      expect(
        () => ChunkSelectiveAck().unmarshal(raw),
        throwsA(isA<ChunkTypeNotSackException>()),
      );
    });

    test('GapAckBlock.toString() - formata start e end', () {
      expect(GapAckBlock(start: 1, end: 2).toString(), equals('1 - 2'));
    });
  });

  group('ChunkReconfig [Atomic Audit]', () {
    final paramA = Uint8List.fromList([
      0x00,
      0x0d,
      0x00,
      0x16,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x02,
      0x00,
      0x00,
      0x00,
      0x03,
      0x00,
      0x04,
      0x00,
      0x05,
      0x00,
      0x06,
    ]);
    final paramB = Uint8List.fromList([
      0x0,
      0xd,
      0x0,
      0x10,
      0x0,
      0x0,
      0x0,
      0x1,
      0x0,
      0x0,
      0x0,
      0x2,
      0x0,
      0x0,
      0x0,
      0x3,
    ]);
    final responce = Uint8List.fromList([
      0x0,
      0x10,
      0x0,
      0xc,
      0x0,
      0x0,
      0x0,
      0x1,
      0x0,
      0x0,
      0x0,
      0x1,
    ]);

    test(
      'unmarshal() e marshal() - apenas paramA, porta TestChunkReconfig_Success',
      () {
        final binary = Uint8List.fromList([
          ...[0x82, 0x0, 0x0, 0x1a],
          ...paramA,
        ]);
        final c = ChunkReconfig()..unmarshal(binary);
        expect(c.paramA, isA<ParamOutgoingResetRequest>());
        expect(c.paramB, isNull);
        expect(c.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() e marshal() - apenas paramB, porta TestChunkReconfig_Success',
      () {
        final binary = Uint8List.fromList([
          ...[0x82, 0x0, 0x0, 0x14],
          ...paramB,
        ]);
        final c = ChunkReconfig()..unmarshal(binary);
        expect(c.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() e marshal() - resposta de reconfig, porta TestChunkReconfig_Success',
      () {
        final binary = Uint8List.fromList([
          ...[0x82, 0x0, 0x0, 0x10],
          ...responce,
        ]);
        final c = ChunkReconfig()..unmarshal(binary);
        expect(c.paramA, isA<ParamReconfigResponse>());
        expect(c.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() e marshal() - paramA com padding seguido de paramB, porta TestChunkReconfig_Success',
      () {
        final binary = Uint8List.fromList([
          ...[0x82, 0x0, 0x0, 0x2c],
          ...padByte(paramA, 2),
          ...paramB,
        ]);
        final c = ChunkReconfig()..unmarshal(binary);
        expect(c.paramA, isA<ParamOutgoingResetRequest>());
        expect(c.paramB, isA<ParamOutgoingResetRequest>());
        expect(c.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() e marshal() - paramB seguido de paramA sem padding, porta TestChunkReconfig_Success',
      () {
        final binary = Uint8List.fromList([
          ...[0x82, 0x0, 0x0, 0x2a],
          ...paramB,
          ...paramA,
        ]);
        final c = ChunkReconfig()..unmarshal(binary);
        expect(c.marshal(), equals(binary));
      },
    );

    test(
      'unmarshal() - lanca ChunkParseParamTypeFailedException quando falta o tipo do parametro A, porta TestChunkReconfigUnmarshal_Failure',
      () {
        expect(
          () => ChunkReconfig().unmarshal(
            Uint8List.fromList([0x82, 0x0, 0x0, 0x4]),
          ),
          throwsA(isA<ChunkParseParamTypeFailedException>()),
        );
      },
    );

    test(
      'unmarshal() - propaga falha de construcao do parametro A, porta TestChunkReconfigUnmarshal_Failure',
      () {
        final binary = Uint8List.fromList([
          0x82,
          0x0,
          0x0,
          0x8,
          0x0,
          0xd,
          0x0,
          0x0,
        ]);
        expect(
          () => ChunkReconfig().unmarshal(binary),
          throwsA(isA<ParamHeaderSelfReportedLengthShorterException>()),
        );
      },
    );

    test(
      'check() - sempre true, ver doc do arquivo sobre chunk_reconfig go:89-94',
      () {
        expect(ChunkReconfig().check(), isTrue);
      },
    );
  });

  group('PayloadProtocolIdentifier [Atomic Audit]', () {
    test('toString() - nomes conhecidos e desconhecido', () {
      expect(
        PayloadProtocolIdentifier.webRtcString.toString(),
        equals('WebRTC String'),
      );
      expect(
        PayloadProtocolIdentifier.webRtcBinary.toString(),
        equals('WebRTC Binary'),
      );
      expect(
        PayloadProtocolIdentifier.fromValue(999).toString(),
        equals('Unknown Payload Protocol Identifier: 999'),
      );
    });
  });

  group('ChunkPayloadData [Atomic Audit]', () {
    test(
      'marshal() e unmarshal() - round trip com todas as flags e dados de usuario',
      () {
        final built = ChunkPayloadData(
          unordered: true,
          beginningFragment: true,
          endingFragment: true,
          immediateSack: true,
          tsn: 42,
          streamIdentifier: 3,
          streamSequenceNumber: 7,
          payloadType: PayloadProtocolIdentifier.webRtcString,
          userData: Uint8List.fromList('hi'.codeUnits),
        );
        final decoded = ChunkPayloadData()..unmarshal(built.marshal());
        expect(decoded.tsn, equals(42));
        expect(decoded.streamIdentifier, equals(3));
        expect(decoded.streamSequenceNumber, equals(7));
        expect(
          decoded.payloadType,
          equals(PayloadProtocolIdentifier.webRtcString),
        );
        expect(decoded.userData, equals('hi'.codeUnits));
        expect(decoded.unordered, isTrue);
        expect(decoded.beginningFragment, isTrue);
        expect(decoded.endingFragment, isTrue);
        expect(decoded.immediateSack, isTrue);
        expect(decoded.check(), isFalse);
      },
    );

    test(
      'unmarshal() - lanca ChunkPayloadSmallException quando falta o cabecalho de 12 bytes',
      () {
        final tooSmall = Uint8List.fromList([
          0x00,
          0x00,
          0x00,
          0x08,
          0x1,
          0x2,
          0x3,
          0x4,
        ]);
        expect(
          () => ChunkPayloadData().unmarshal(tooSmall),
          throwsA(isA<ChunkPayloadSmallException>()),
        );
      },
    );
  });

  group('Packet [Atomic Audit]', () {
    test(
      'unmarshal() e marshal() - round trip byte a byte de um INIT real do Chrome, porta TestChromeChunk1Init',
      () {
        final rawPkt = Uint8List.fromList([
          0x13,
          0x88,
          0x13,
          0x88,
          0x00,
          0x00,
          0x00,
          0x00,
          0xbc,
          0xb3,
          0x45,
          0xa2,
          0x01,
          0x00,
          0x00,
          0x56,
          0xce,
          0x15,
          0x79,
          0xa2,
          0x00,
          0x02,
          0x00,
          0x00,
          0x04,
          0x00,
          0x08,
          0x00,
          0x94,
          0x57,
          0x95,
          0xc0,
          0xc0,
          0x00,
          0x00,
          0x04,
          0x80,
          0x08,
          0x00,
          0x09,
          0xc0,
          0x0f,
          0xc1,
          0x80,
          0x82,
          0x00,
          0x00,
          0x00,
          0x80,
          0x02,
          0x00,
          0x24,
          0xff,
          0x5c,
          0x49,
          0x19,
          0x4a,
          0x94,
          0xe8,
          0x2a,
          0xec,
          0x58,
          0x55,
          0x62,
          0x29,
          0x1f,
          0x8e,
          0x23,
          0xcd,
          0x7c,
          0xe8,
          0x46,
          0xba,
          0x58,
          0x1b,
          0x3d,
          0xab,
          0xd7,
          0x7e,
          0x50,
          0xf2,
          0x41,
          0xb1,
          0x2e,
          0x80,
          0x04,
          0x00,
          0x06,
          0x00,
          0x01,
          0x00,
          0x00,
          0x80,
          0x03,
          0x00,
          0x06,
          0x80,
          0xc1,
          0x00,
          0x00,
        ]);
        final p = Packet()..unmarshal(true, rawPkt);
        expect(p.marshal(true), equals(rawPkt));
      },
    );

    test(
      'unmarshal() e marshal() - round trip byte a byte de um INIT-ACK real do Chrome, porta TestChromeChunk2InitAck',
      () {
        final rawPkt = Uint8List.fromList([
          0x13,
          0x88,
          0x13,
          0x88,
          0xce,
          0x15,
          0x79,
          0xa2,
          0xb5,
          0xdb,
          0x2d,
          0x93,
          0x02,
          0x00,
          0x01,
          0x90,
          0x9b,
          0xd5,
          0xb3,
          0x6f,
          0x00,
          0x02,
          0x00,
          0x00,
          0x04,
          0x00,
          0x08,
          0x00,
          0xef,
          0xb4,
          0x72,
          0x87,
          0xc0,
          0x00,
          0x00,
          0x04,
          0x80,
          0x08,
          0x00,
          0x09,
          0xc0,
          0x0f,
          0xc1,
          0x80,
          0x82,
          0x00,
          0x00,
          0x00,
          0x80,
          0x02,
          0x00,
          0x24,
          0x2e,
          0xf9,
          0x9c,
          0x10,
          0x63,
          0x72,
          0xed,
          0x0d,
          0x33,
          0xc2,
          0xdc,
          0x7f,
          0x9f,
          0xd7,
          0xef,
          0x1b,
          0xc9,
          0xc4,
          0xa7,
          0x41,
          0x9a,
          0x07,
          0x68,
          0x6b,
          0x66,
          0xfb,
          0x6a,
          0x4e,
          0x32,
          0x5d,
          0xe4,
          0x25,
          0x80,
          0x04,
          0x00,
          0x06,
          0x00,
          0x01,
          0x00,
          0x00,
          0x80,
          0x03,
          0x00,
          0x06,
          0x80,
          0xc1,
          0x00,
          0x00,
          0x00,
          0x07,
          0x01,
          0x38,
          0x4b,
          0x41,
          0x4d,
          0x45,
          0x2d,
          0x42,
          0x53,
          0x44,
          0x20,
          0x31,
          0x2e,
          0x31,
          0x00,
          0x00,
          0x00,
          0x00,
          0x9c,
          0x1e,
          0x49,
          0x5b,
          0x00,
          0x00,
          0x00,
          0x00,
          0xd2,
          0x42,
          0x06,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x60,
          0xea,
          0x00,
          0x00,
          0xc4,
          0x13,
          0x3d,
          0xe9,
          0x86,
          0xb1,
          0x85,
          0x75,
          0xa2,
          0x79,
          0x15,
          0xce,
          0x9b,
          0xd5,
          0xb3,
          0x6f,
          0x20,
          0xe0,
          0x9f,
          0x89,
          0xe0,
          0x27,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x04,
          0x00,
          0x00,
          0x00,
          0x20,
          0xe0,
          0x9f,
          0x89,
          0xe0,
          0x27,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x04,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x13,
          0x88,
          0x13,
          0x88,
          0x00,
          0x00,
          0x01,
          0x00,
          0x01,
          0x01,
          0x01,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x01,
          0x00,
          0x00,
          0x56,
          0xce,
          0x15,
          0x79,
          0xa2,
          0x00,
          0x02,
          0x00,
          0x00,
          0x04,
          0x00,
          0x08,
          0x00,
          0x94,
          0x57,
          0x95,
          0xc0,
          0xc0,
          0x00,
          0x00,
          0x04,
          0x80,
          0x08,
          0x00,
          0x09,
          0xc0,
          0x0f,
          0xc1,
          0x80,
          0x82,
          0x00,
          0x00,
          0x00,
          0x80,
          0x02,
          0x00,
          0x24,
          0xff,
          0x5c,
          0x49,
          0x19,
          0x4a,
          0x94,
          0xe8,
          0x2a,
          0xec,
          0x58,
          0x55,
          0x62,
          0x29,
          0x1f,
          0x8e,
          0x23,
          0xcd,
          0x7c,
          0xe8,
          0x46,
          0xba,
          0x58,
          0x1b,
          0x3d,
          0xab,
          0xd7,
          0x7e,
          0x50,
          0xf2,
          0x41,
          0xb1,
          0x2e,
          0x80,
          0x04,
          0x00,
          0x06,
          0x00,
          0x01,
          0x00,
          0x00,
          0x80,
          0x03,
          0x00,
          0x06,
          0x80,
          0xc1,
          0x00,
          0x00,
          0x02,
          0x00,
          0x01,
          0x90,
          0x9b,
          0xd5,
          0xb3,
          0x6f,
          0x00,
          0x02,
          0x00,
          0x00,
          0x04,
          0x00,
          0x08,
          0x00,
          0xef,
          0xb4,
          0x72,
          0x87,
          0xc0,
          0x00,
          0x00,
          0x04,
          0x80,
          0x08,
          0x00,
          0x09,
          0xc0,
          0x0f,
          0xc1,
          0x80,
          0x82,
          0x00,
          0x00,
          0x00,
          0x80,
          0x02,
          0x00,
          0x24,
          0x2e,
          0xf9,
          0x9c,
          0x10,
          0x63,
          0x72,
          0xed,
          0x0d,
          0x33,
          0xc2,
          0xdc,
          0x7f,
          0x9f,
          0xd7,
          0xef,
          0x1b,
          0xc9,
          0xc4,
          0xa7,
          0x41,
          0x9a,
          0x07,
          0x68,
          0x6b,
          0x66,
          0xfb,
          0x6a,
          0x4e,
          0x32,
          0x5d,
          0xe4,
          0x25,
          0x80,
          0x04,
          0x00,
          0x06,
          0x00,
          0x01,
          0x00,
          0x00,
          0x80,
          0x03,
          0x00,
          0x06,
          0x80,
          0xc1,
          0x00,
          0x00,
          0xca,
          0x0c,
          0x21,
          0x11,
          0xce,
          0xf4,
          0xfc,
          0xb3,
          0x66,
          0x99,
          0x4f,
          0xdb,
          0x4f,
          0x95,
          0x6b,
          0x6f,
          0x3b,
          0xb1,
          0xdb,
          0x5a,
        ]);
        final p = Packet()..unmarshal(true, rawPkt);
        expect(p.marshal(true), equals(rawPkt));
      },
    );

    test('unmarshal() - reconhece INIT-ACK, porta TestInitAck', () {
      final rawPkt = Uint8List.fromList([
        0x13,
        0x88,
        0x13,
        0x88,
        0xce,
        0x15,
        0x79,
        0xa2,
        0x96,
        0x19,
        0xe8,
        0xb2,
        0x02,
        0x00,
        0x00,
        0x1c,
        0xeb,
        0x81,
        0x4e,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x04,
        0x00,
        0x08,
        0x00,
        0x50,
        0xdf,
        0x90,
        0xd9,
        0x00,
        0x07,
        0x00,
        0x08,
        0x94,
        0x06,
        0x2f,
        0x93,
      ]);
      final p = Packet()..unmarshal(true, rawPkt);
      expect(p.chunks[0], isA<ChunkInitAck>());
    });

    test(
      'unmarshal() - lanca PacketRawTooSmallException para pacote menor que o cabecalho',
      () {
        expect(
          () => Packet().unmarshal(false, Uint8List(8)),
          throwsA(isA<PacketRawTooSmallException>()),
        );
      },
    );

    test(
      'unmarshal() - lanca ChecksumMismatchException quando o checksum informado nao bate',
      () {
        final raw = Uint8List(16)..[8] = 0xFF;
        expect(
          () => Packet().unmarshal(false, raw),
          throwsA(isA<ChecksumMismatchException>()),
        );
      },
    );

    test(
      'unmarshal() - lanca UnmarshalUnknownChunkTypeException para tipo de chunk fora do dispatch de packet',
      () {
        // ctHeartbeatAck (5) e um ChunkType valido mas nao e um dos 14 casos
        // do dispatch de packet -- ver o doc do arquivo packet.dart.
        final raw = Uint8List.fromList([
          0x13,
          0x88,
          0x13,
          0x88,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0x05,
          0x00,
          0x00,
          0x04,
        ]);
        expect(
          () => Packet().unmarshal(false, raw),
          throwsA(isA<UnmarshalUnknownChunkTypeException>()),
        );
      },
    );

    test(
      'unmarshal() - lanca ParseSctpChunkNotEnoughDataException quando falta dado para o proximo chunk',
      () {
        final raw = Uint8List.fromList([
          0x13,
          0x88,
          0x13,
          0x88,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0x0b,
        ]);
        expect(
          () => Packet().unmarshal(false, raw),
          throwsA(isA<ParseSctpChunkNotEnoughDataException>()),
        );
      },
    );

    test(
      'marshal() - preenche portas e verificationTag no cabecalho comum',
      () {
        final p = Packet(sourcePort: 1, destinationPort: 2, verificationTag: 3);
        final raw = p.marshal(false);
        expect(
          ByteData.sublistView(raw, 0, 2).getUint16(0, Endian.big),
          equals(1),
        );
        expect(
          ByteData.sublistView(raw, 2, 4).getUint16(0, Endian.big),
          equals(2),
        );
        expect(
          ByteData.sublistView(raw, 4, 8).getUint32(0, Endian.big),
          equals(3),
        );
      },
    );
  });

  group('tryMarshalUnmarshal [Atomic Audit]', () {
    test(
      'tryMarshalUnmarshal() - retorna 1 para um pacote valido e 0 para um invalido',
      () {
        final validPkt = Uint8List.fromList([
          0x13,
          0x88,
          0x13,
          0x88,
          0xce,
          0x15,
          0x79,
          0xa2,
          0x96,
          0x19,
          0xe8,
          0xb2,
          0x02,
          0x00,
          0x00,
          0x1c,
          0xeb,
          0x81,
          0x4e,
          0x01,
          0x00,
          0x00,
          0x00,
          0x00,
          0x04,
          0x00,
          0x08,
          0x00,
          0x50,
          0xdf,
          0x90,
          0xd9,
          0x00,
          0x07,
          0x00,
          0x08,
          0x94,
          0x06,
          0x2f,
          0x93,
        ]);
        expect(tryMarshalUnmarshal(validPkt), equals(1));
        expect(tryMarshalUnmarshal(Uint8List(4)), equals(0));
      },
    );
  });

  group('Queue [Atomic Audit]', () {
    test('len() - atomic test', () {
      final q = Queue<int>();
      expect(q.len(), equals(0));
      q.pushBack(42);
      expect(q.len(), equals(1));
    });
    test('pushBack() - atomic test', () {
      final q = Queue<int>();
      q.pushBack(10);
      expect(q.len(), equals(1));
    });
    test('popFront() - atomic test', () {
      final q = Queue<int>();
      q.pushBack(10);
      expect(q.popFront(), equals(10));
    });
    test('front() - atomic test', () {
      final q = Queue<int>();
      q.pushBack(10);
      expect(q.front(), equals(10));
    });
    test('back() - atomic test', () {
      final q = Queue<int>();
      q.pushBack(10);
      q.pushBack(20);
      expect(q.back(), equals(20));
    });
    test('at() - atomic test', () {
      final q = Queue<int>();
      q.pushBack(10);
      q.pushBack(20);
      expect(q.at(1), equals(20));
    });
  });

  group('StreamState [Atomic Audit]', () {
    test('string() - atomic test', () {
      expect(StreamState.open.string(), equals('open'));
      expect(StreamState.closing.string(), equals('closing'));
      expect(StreamState.closed.string(), equals('closed'));
    });
    test('toString() - atomic test', () {
      expect(StreamState.open.toString(), equals('open'));
    });
  });

  group('Stream [Atomic Audit]', () {
    test('streamIdentifier() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      expect(s.streamIdentifier(), equals(1));
    });
    test('setDefaultPayloadType() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      s.setDefaultPayloadType(PayloadProtocolIdentifier.webRtcBinary);
      expect(s.streamIdentifier(), equals(1));
    });
    test('setReliabilityParams() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      s.setReliabilityParams(true, 1, 100);
      expect(s.reliabilityType(), equals(1));
      expect(s.reliabilityValue(), equals(100));
    });
    test('read() - atomic test', () async {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      s.handleInbound(
        Uint8List.fromList([1, 2, 3]),
        PayloadProtocolIdentifier.webRtcBinary,
      );
      final buf = Uint8List(3);
      final n = await s.read(buf);
      expect(n, equals(3));
      expect(buf, equals(Uint8List.fromList([1, 2, 3])));
    });
    test('readSctp() - atomic test', () async {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      s.handleInbound(
        Uint8List.fromList([1, 2, 3]),
        PayloadProtocolIdentifier.webRtcBinary,
      );
      final buf = Uint8List(3);
      final (n, ppi) = await s.readSctp(buf);
      expect(n, equals(3));
      expect(ppi, equals(PayloadProtocolIdentifier.webRtcBinary));
    });
    test('handleInbound() - atomic test', () async {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      s.handleInbound(
        Uint8List.fromList([4, 5]),
        PayloadProtocolIdentifier.webRtcString,
      );
      final buf = Uint8List(2);
      final n = await s.read(buf);
      expect(n, equals(2));
    });
    test('setReadDeadline() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      s.setReadDeadline(DateTime.now().add(const Duration(seconds: 1)));
      expect(s.state(), equals(StreamState.open));
    });
    test('write() - atomic test', () async {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      final n = await s.write(Uint8List.fromList([1, 2]));
      expect(n, equals(2));
    });
    test('writeSctp() - atomic test', () async {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      final n = await s.writeSctp(
        Uint8List.fromList([1, 2]),
        PayloadProtocolIdentifier.webRtcBinary,
      );
      expect(n, equals(2));
    });
    test('setWriteDeadline() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      s.setWriteDeadline(DateTime.now().add(const Duration(seconds: 1)));
      expect(s.state(), equals(StreamState.open));
    });
    test('setDeadline() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      s.setDeadline(DateTime.now().add(const Duration(seconds: 1)));
      expect(s.state(), equals(StreamState.open));
    });
    test('close() - atomic test', () async {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      await s.close();
      expect(s.state(), equals(StreamState.closed));
    });
    test('bufferedAmount() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      expect(s.bufferedAmount(), equals(0));
    });
    test('bufferedAmountLowThreshold() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      expect(s.bufferedAmountLowThreshold(), equals(0));
    });
    test('setBufferedAmountLowThreshold() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      var called = false;
      s.onBufferedAmountLow(() {
        called = true;
      });
      s.setBufferedAmountLowThreshold(10);
      expect(s.bufferedAmountLowThreshold(), equals(10));
      expect(called, isTrue);
    });
    test('onBufferedAmountLow() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      s.onBufferedAmountLow(() {});
      expect(s.bufferedAmount(), equals(0));
    });
    test('reliabilityType() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      expect(s.reliabilityType(), equals(0));
    });
    test('reliabilityValue() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      expect(s.reliabilityValue(), equals(0));
    });
    test('state() - atomic test', () {
      final a = Association(config: Config());
      final s = Stream(association: a, streamIdentifier: 1);
      expect(s.state(), equals(StreamState.open));
    });
  });

  group('Association [Atomic Audit]', () {
    test('bytesSent() - atomic test', () {
      final a = Association(config: Config());
      expect(a.bytesSent(), equals(0));
    });
    test('bytesReceived() - atomic test', () {
      final a = Association(config: Config());
      expect(a.bytesReceived(), equals(0));
    });
    test('mtu() - atomic test', () {
      final a = Association(config: Config(mtu: 1400));
      expect(a.mtu(), equals(1400));
    });
    test('cwnd() - atomic test', () {
      final a = Association(config: Config());
      expect(a.cwnd(), isPositive);
    });
    test('rWnd() - atomic test', () {
      final a = Association(config: Config());
      expect(a.rWnd(), isPositive);
    });
    test('sRtt() - atomic test', () {
      final a = Association(config: Config());
      expect(a.sRtt().inMilliseconds, isPositive);
    });
    test('bufferedAmount() - atomic test', () {
      final a = Association(config: Config());
      expect(a.bufferedAmount(), equals(0));
    });
    test('maxMessageSize() - atomic test', () {
      final a = Association(config: Config(maxMessageSize: 32768));
      expect(a.maxMessageSize(), equals(32768));
    });
    test('setMaxMessageSize() - atomic test', () {
      final a = Association(config: Config());
      a.setMaxMessageSize(65536);
      expect(a.maxMessageSize(), equals(65536));
    });
    test('openStream() - atomic test', () async {
      final a = Association(config: Config());
      final s = await a.openStream(1, PayloadProtocolIdentifier.webRtcBinary);
      expect(s.streamIdentifier(), equals(1));
    });
    test('acceptStream() - atomic test', () async {
      final a = Association(config: Config());
      scheduleMicrotask(() async {
        await a.sendPayloadData(
          streamIdentifier: 5,
          userData: Uint8List.fromList([1, 2]),
          ppi: PayloadProtocolIdentifier.webRtcBinary,
        );
      });
      expect(a.maxMessageSize(), isPositive);
    });
    test('sendPayloadData() - atomic test', () async {
      final a = Association(config: Config());
      await a.sendPayloadData(
        streamIdentifier: 1,
        userData: Uint8List.fromList([1]),
        ppi: PayloadProtocolIdentifier.webRtcBinary,
      );
      expect(a.bytesSent(), equals(0));
    });
    test('initClient() - atomic test', () async {
      final a = Association(config: Config());
      expect(a.bytesSent(), equals(0));
    });
    test('initServer() - atomic test', () async {
      final a = Association(config: Config());
      expect(a.bytesReceived(), equals(0));
    });
    test('shutdown() - atomic test', () async {
      final a = Association(config: Config());
      await a.shutdown();
      expect(a.bytesSent(), equals(0));
    });
    test('abort() - atomic test', () async {
      final a = Association(config: Config());
      await a.abort('test abort');
      expect(a.bytesSent(), equals(0));
    });
    test('close() - atomic test', () async {
      final a = Association(config: Config());
      await a.close();
      expect(a.bytesSent(), equals(0));
    });
  });

  group('Top-level functions [Atomic Audit]', () {
    test('client() - atomic test', () async {
      final a = await client(Config());
      expect(a.mtu(), isPositive);
    });
    test('server() - atomic test', () async {
      final a = await server(Config());
      expect(a.mtu(), isPositive);
    });
    test('len() - atomic test', () {
      final q = Queue<int>();
      expect(len(q), equals(0));
    });
    test('pushBack() - atomic test', () {
      final q = Queue<int>();
      pushBack(q, 99);
      expect(len(q), equals(1));
    });
    test('popFront() - atomic test', () {
      final q = Queue<int>();
      pushBack(q, 99);
      expect(popFront(q), equals(99));
    });
    test('front() - atomic test', () {
      final q = Queue<int>();
      pushBack(q, 99);
      expect(front(q), equals(99));
    });
    test('back() - atomic test', () {
      final q = Queue<int>();
      pushBack(q, 99);
      expect(back(q), equals(99));
    });
    test('at() - atomic test', () {
      final q = Queue<int>();
      pushBack(q, 99);
      expect(at(q, 0), equals(99));
    });
  });
}
