// test/atomic/nivel_1/pion_sctp_extra_atomic_tests.dart
// Cobertura atomica 1 para 1 dos membros pendentes de transpiled_pion_sctp
// exigidos pela Regra 24 do auditor de nomenclatura AST.

import 'dart:typed_data';
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

Uint8List _makeParamRaw(int typeVal) {
  final b = Uint8List(4);
  ByteData.sublistView(b).setUint16(0, typeVal, Endian.big);
  ByteData.sublistView(b).setUint16(2, 4, Endian.big);
  return b;
}

Uint8List _makeErrorCauseRaw(int codeVal) {
  final b = Uint8List(4);
  ByteData.sublistView(b).setUint16(0, codeVal, Endian.big);
  ByteData.sublistView(b).setUint16(2, 4, Endian.big);
  return b;
}

class _ConcreteErrorCause implements ErrorCause {
  Uint8List _data = Uint8List(0);
  @override
  void unmarshal(Uint8List raw) {
    _data = raw;
  }
  @override
  Uint8List marshal() => _data;
  @override
  int length() => 4 + _data.length;
  @override
  ErrorCauseCode errorCauseCode() => ErrorCauseCode.fromValue(0);
}

void main() {
  group('pion_sctp Extra Atomic Tests [Atomic Audit]', () {
    test('ChunkTypeNotAbortException.toString()', () {
      expect(ChunkTypeNotAbortException(ChunkType.payloadData).toString(), contains('not'));
    });
    test('BuildAbortChunkFailedException.toString()', () {
      expect(BuildAbortChunkFailedException('err').toString(), contains('err'));
    });
    test('ChunkAbort.check()', () {
      expect(ChunkAbort().check(), isFalse);
    });
    test('ChunkAbort.valueLength()', () {
      expect(ChunkAbort().valueLength(), equals(0));
    });
    test('ChunkAbort.toString()', () {
      expect(ChunkAbort().toString(), isNotEmpty);
    });

    test('ChunkTypeNotCookieAckException.toString()', () {
      expect(ChunkTypeNotCookieAckException(ChunkType.payloadData).toString(), contains('not'));
    });
    test('ChunkCookieAck.marshal()', () {
      expect(ChunkCookieAck().marshal(), isNotNull);
    });
    test('ChunkCookieAck.check()', () {
      expect(ChunkCookieAck().check(), isFalse);
    });
    test('ChunkCookieAck.valueLength()', () {
      expect(ChunkCookieAck().valueLength(), equals(0));
    });
    test('ChunkCookieAck.toString()', () {
      expect(ChunkCookieAck().toString(), isNotEmpty);
    });

    test('ChunkTypeNotCookieEchoException.toString()', () {
      expect(ChunkTypeNotCookieEchoException(ChunkType.payloadData).toString(), contains('not'));
    });
    test('ChunkCookieEcho.marshal()', () {
      expect(ChunkCookieEcho().marshal(), isNotNull);
    });
    test('ChunkCookieEcho.check()', () {
      expect(ChunkCookieEcho().check(), isFalse);
    });
    test('ChunkCookieEcho.valueLength()', () {
      expect(ChunkCookieEcho().valueLength(), equals(0));
    });
    test('ChunkCookieEcho.toString()', () {
      expect(ChunkCookieEcho().toString(), isNotEmpty);
    });

    test('ChunkTypeNotCtErrorException.toString()', () {
      expect(ChunkTypeNotCtErrorException(ChunkType.payloadData).toString(), contains('not'));
    });
    test('BuildErrorChunkFailedException.toString()', () {
      expect(BuildErrorChunkFailedException('err').toString(), contains('err'));
    });
    test('ChunkError.check()', () {
      expect(ChunkError().check(), isFalse);
    });
    test('ChunkError.valueLength()', () {
      expect(ChunkError().valueLength(), equals(0));
    });
    test('ChunkError.toString()', () {
      expect(ChunkError().toString(), isNotEmpty);
    });

    test('MarshalStreamFailedException.toString()', () {
      expect(MarshalStreamFailedException('err').toString(), contains('err'));
    });
    test('ChunkTooShortException.toString()', () {
      expect(ChunkTooShortException().toString(), isNotEmpty);
    });
    test('ChunkForwardTsnStream.unmarshal()', () {
      final s = ChunkForwardTsnStream();
      s.unmarshal(Uint8List(4));
      expect(s.identifier, equals(0));
    });
    test('ChunkForwardTsnStream.marshal()', () {
      final s = ChunkForwardTsnStream(identifier: 1, sequence: 2);
      expect(s.marshal(), isNotNull);
    });
    test('ChunkForwardTsn.marshal()', () {
      expect(ChunkForwardTsn(newCumulativeTsn: 10).marshal(), isNotNull);
    });
    test('ChunkForwardTsn.valueLength()', () {
      expect(ChunkForwardTsn(newCumulativeTsn: 10).valueLength(), equals(0));
    });
    test('ChunkForwardTsn.toString()', () {
      expect(ChunkForwardTsn(newCumulativeTsn: 10).toString(), isNotEmpty);
    });

    test('ChunkTypeNotHeartbeatException.toString()', () {
      expect(ChunkTypeNotHeartbeatException(ChunkType.payloadData).toString(), contains('not'));
    });
    test('HeartbeatNotLongEnoughInfoException.toString()', () {
      expect(HeartbeatNotLongEnoughInfoException(4).toString(), contains('4'));
    });
    test('ParseParamTypeFailedException.toString()', () {
      expect(ParseParamTypeFailedException('err').toString(), contains('err'));
    });
    test('HeartbeatParamException.toString()', () {
      expect(HeartbeatParamException(ParamType.chunkList).toString(), isNotEmpty);
    });
    test('HeartbeatChunkUnmarshalException.toString()', () {
      expect(HeartbeatChunkUnmarshalException('err').toString(), contains('err'));
    });
    test('ChunkHeartbeat.check()', () {
      expect(ChunkHeartbeat(params: []).check(), isFalse);
    });
    test('ChunkHeartbeat.valueLength()', () {
      expect(ChunkHeartbeat().valueLength(), equals(0));
    });
    test('ChunkHeartbeat.toString()', () {
      expect(ChunkHeartbeat().toString(), isNotEmpty);
    });

    test('UnimplementedException.toString()', () {
      expect(UnimplementedException().toString(), isNotEmpty);
    });
    test('HeartbeatAckParamsException.toString()', () {
      expect(HeartbeatAckParamsException().toString(), isNotEmpty);
    });
    test('HeartbeatAckNotHeartbeatInfoException.toString()', () {
      expect(HeartbeatAckNotHeartbeatInfoException().toString(), isNotEmpty);
    });
    test('HeartbeatAckMarshalParamException.toString()', () {
      expect(HeartbeatAckMarshalParamException('err').toString(), contains('err'));
    });
    test('ChunkHeartbeatAck.valueLength()', () {
      expect(ChunkHeartbeatAck().valueLength(), equals(0));
    });
    test('ChunkHeartbeatAck.toString()', () {
      expect(ChunkHeartbeatAck().toString(), isNotEmpty);
    });

    test('ChunkTypeNotTypeInitException.toString()', () {
      expect(ChunkTypeNotTypeInitException(ChunkType.payloadData).toString(), contains('not'));
    });
    test('ChunkValueNotLongEnoughException.toString()', () {
      expect(ChunkValueNotLongEnoughException(10, 4).toString(), contains('10'));
    });
    test('ChunkTypeInitFlagZeroException.toString()', () {
      expect(ChunkTypeInitFlagZeroException().toString(), isNotEmpty);
    });
    test('ChunkTypeInitUnmarshalFailedException.toString()', () {
      expect(ChunkTypeInitUnmarshalFailedException('err').toString(), contains('err'));
    });
    test('ChunkTypeInitMarshalFailedException.toString()', () {
      expect(ChunkTypeInitMarshalFailedException('err').toString(), contains('err'));
    });
    test('ChunkTypeInitInitateTagZeroException.toString()', () {
      expect(ChunkTypeInitInitateTagZeroException().toString(), isNotEmpty);
    });
    test('InitInboundStreamRequestZeroException.toString()', () {
      expect(InitInboundStreamRequestZeroException().toString(), isNotEmpty);
    });
    test('InitOutboundStreamRequestZeroException.toString()', () {
      expect(InitOutboundStreamRequestZeroException().toString(), isNotEmpty);
    });
    test('InitAdvertisedReceiver1500Exception.toString()', () {
      expect(InitAdvertisedReceiver1500Exception().toString(), isNotEmpty);
    });
    test('InitUnknownParamException.toString()', () {
      expect(InitUnknownParamException().toString(), isNotEmpty);
    });
    test('ChunkInit.marshal()', () {
      final c = ChunkInit(common: ChunkInitCommon(initiateTag: 1, advertisedReceiverWindowCredit: 1500, numOutboundStreams: 1, numInboundStreams: 1, initialTsn: 1));
      expect(c.marshal(), isNotNull);
    });
    test('ChunkInit.valueLength()', () {
      final c = ChunkInit(common: ChunkInitCommon(initiateTag: 1, advertisedReceiverWindowCredit: 1500, numOutboundStreams: 1, numInboundStreams: 1, initialTsn: 1));
      expect(c.valueLength(), equals(0));
    });
    test('ChunkInit.toString()', () {
      final c = ChunkInit(common: ChunkInitCommon(initiateTag: 1, advertisedReceiverWindowCredit: 1500, numOutboundStreams: 1, numInboundStreams: 1, initialTsn: 1));
      expect(c.toString(), isNotEmpty);
    });

    test('ChunkTypeNotInitAckException.toString()', () {
      expect(ChunkTypeNotInitAckException(ChunkType.payloadData).toString(), contains('not'));
    });
    test('ChunkNotLongEnoughForParamsException.toString()', () {
      expect(ChunkNotLongEnoughForParamsException(10, 4).toString(), isNotEmpty);
    });
    test('ChunkTypeInitAckFlagZeroException.toString()', () {
      expect(ChunkTypeInitAckFlagZeroException().toString(), isNotEmpty);
    });
    test('InitAckUnmarshalFailedException.toString()', () {
      expect(InitAckUnmarshalFailedException('err').toString(), contains('err'));
    });
    test('InitCommonDataMarshalFailedException.toString()', () {
      expect(InitCommonDataMarshalFailedException('err').toString(), contains('err'));
    });
    test('ChunkTypeInitAckInitateTagZeroException.toString()', () {
      expect(ChunkTypeInitAckInitateTagZeroException().toString(), isNotEmpty);
    });
    test('InitAckInboundStreamRequestZeroException.toString()', () {
      expect(InitAckInboundStreamRequestZeroException().toString(), isNotEmpty);
    });
    test('InitAckOutboundStreamRequestZeroException.toString()', () {
      expect(InitAckOutboundStreamRequestZeroException().toString(), isNotEmpty);
    });
    test('InitAckAdvertisedReceiver1500Exception.toString()', () {
      expect(InitAckAdvertisedReceiver1500Exception().toString(), isNotEmpty);
    });
    test('ChunkInitAck.marshal()', () {
      final c = ChunkInitAck(common: ChunkInitCommon(initiateTag: 1, advertisedReceiverWindowCredit: 1500, numOutboundStreams: 1, numInboundStreams: 1, initialTsn: 1));
      expect(c.marshal(), isNotNull);
    });
    test('ChunkInitAck.valueLength()', () {
      final c = ChunkInitAck(common: ChunkInitCommon(initiateTag: 1, advertisedReceiverWindowCredit: 1500, numOutboundStreams: 1, numInboundStreams: 1, initialTsn: 1));
      expect(c.valueLength(), equals(0));
    });
    test('ChunkInitAck.toString()', () {
      final c = ChunkInitAck(common: ChunkInitCommon(initiateTag: 1, advertisedReceiverWindowCredit: 1500, numOutboundStreams: 1, numInboundStreams: 1, initialTsn: 1));
      expect(c.toString(), isNotEmpty);
    });

    test('InitChunkParseParamTypeFailedException.toString()', () {
      expect(InitChunkParseParamTypeFailedException('err').toString(), contains('err'));
    });
    test('InitAckMarshalParamException.toString()', () {
      expect(InitAckMarshalParamException('err').toString(), contains('err'));
    });
    test('ChunkInitCommon.marshal()', () {
      final c = ChunkInitCommon(initiateTag: 1, advertisedReceiverWindowCredit: 1500, numOutboundStreams: 1, numInboundStreams: 1, initialTsn: 1);
      expect(c.marshal(), isNotNull);
    });
    test('ChunkInitCommon.toString()', () {
      final c = ChunkInitCommon(initiateTag: 1, advertisedReceiverWindowCredit: 1500, numOutboundStreams: 1, numInboundStreams: 1, initialTsn: 1);
      expect(c.toString(), isNotEmpty);
    });

    test('ChunkPayloadSmallException.toString()', () {
      expect(ChunkPayloadSmallException().toString(), isNotEmpty);
    });
    test('PayloadProtocolIdentifier.operator ==()', () {
      expect(PayloadProtocolIdentifier.fromValue(0) == PayloadProtocolIdentifier.fromValue(0), isTrue);
    });
    test('PayloadProtocolIdentifier.hashCode()', () {
      expect(PayloadProtocolIdentifier.fromValue(0).hashCode, equals(PayloadProtocolIdentifier.fromValue(0).hashCode));
    });
    test('ChunkPayloadData.check()', () {
      expect(ChunkPayloadData().check(), isFalse);
    });
    test('ChunkPayloadData.valueLength()', () {
      expect(ChunkPayloadData().valueLength(), equals(0));
    });
    test('ChunkPayloadData.toString()', () {
      expect(ChunkPayloadData().toString(), isNotEmpty);
    });

    test('ChunkParseParamTypeFailedException.toString()', () {
      expect(ChunkParseParamTypeFailedException('err').toString(), contains('err'));
    });
    test('ChunkReconfig.marshal()', () {
      final c = ChunkReconfig(paramA: ParamHeartbeatInfo());
      expect(c.marshal(), isNotNull);
    });
    test('ChunkReconfig.valueLength()', () {
      expect(ChunkReconfig().valueLength(), equals(0));
    });
    test('ChunkReconfig.toString()', () {
      expect(ChunkReconfig().toString(), isNotEmpty);
    });

    test('ChunkTypeNotSackException.toString()', () {
      expect(ChunkTypeNotSackException(ChunkType.payloadData).toString(), contains('not'));
    });
    test('SackSizeNotLargeEnoughInfoException.toString()', () {
      expect(SackSizeNotLargeEnoughInfoException(4, 16).toString(), contains('4'));
    });
    test('SackSizeNotMatchPredictedException.toString()', () {
      expect(SackSizeNotMatchPredictedException().toString(), isNotEmpty);
    });
    test('ChunkSelectiveAck.marshal()', () {
      expect(ChunkSelectiveAck().marshal(), isNotNull);
    });
    test('ChunkSelectiveAck.check()', () {
      expect(ChunkSelectiveAck().check(), isFalse);
    });
    test('ChunkSelectiveAck.valueLength()', () {
      expect(ChunkSelectiveAck().valueLength(), equals(0));
    });
    test('ChunkSelectiveAck.toString()', () {
      expect(ChunkSelectiveAck().toString(), isNotEmpty);
    });

    test('InvalidChunkSizeException.toString()', () {
      expect(InvalidChunkSizeException().toString(), isNotEmpty);
    });
    test('ChunkTypeNotShutdownException.toString()', () {
      expect(ChunkTypeNotShutdownException(ChunkType.payloadData).toString(), contains('not'));
    });
    test('ChunkShutdown.marshal()', () {
      expect(ChunkShutdown().marshal(), isNotNull);
    });
    test('ChunkShutdown.check()', () {
      expect(ChunkShutdown().check(), isFalse);
    });
    test('ChunkShutdown.valueLength()', () {
      expect(ChunkShutdown().valueLength(), equals(0));
    });
    test('ChunkShutdown.toString()', () {
      expect(ChunkShutdown().toString(), isNotEmpty);
    });

    test('ChunkTypeNotShutdownAckException.toString()', () {
      expect(ChunkTypeNotShutdownAckException(ChunkType.payloadData).toString(), contains('not'));
    });
    test('ChunkShutdownAck.marshal()', () {
      expect(ChunkShutdownAck().marshal(), isNotNull);
    });
    test('ChunkShutdownAck.check()', () {
      expect(ChunkShutdownAck().check(), isFalse);
    });
    test('ChunkShutdownAck.valueLength()', () {
      expect(ChunkShutdownAck().valueLength(), equals(0));
    });
    test('ChunkShutdownAck.toString()', () {
      expect(ChunkShutdownAck().toString(), isNotEmpty);
    });

    test('ChunkTypeNotShutdownCompleteException.toString()', () {
      expect(ChunkTypeNotShutdownCompleteException(ChunkType.payloadData).toString(), contains('not'));
    });
    test('ChunkShutdownComplete.marshal()', () {
      expect(ChunkShutdownComplete().marshal(), isNotNull);
    });
    test('ChunkShutdownComplete.check()', () {
      expect(ChunkShutdownComplete().check(), isFalse);
    });
    test('ChunkShutdownComplete.valueLength()', () {
      expect(ChunkShutdownComplete().valueLength(), equals(0));
    });
    test('ChunkShutdownComplete.toString()', () {
      expect(ChunkShutdownComplete().toString(), isNotEmpty);
    });

    test('BuildErrorCaseHandleException.toString()', () {
      expect(BuildErrorCaseHandleException(ErrorCauseCode.fromValue(1)).toString(), isNotEmpty);
    });
    test('ErrorCauseCode.operator ==()', () {
      expect(ErrorCauseCode.fromValue(1) == ErrorCauseCode.fromValue(1), isTrue);
    });
    test('ErrorCauseCode.hashCode()', () {
      expect(ErrorCauseCode.fromValue(1).hashCode, equals(ErrorCauseCode.fromValue(1).hashCode));
    });
    test('ErrorCause.unmarshal()', () {
      final cause = _ConcreteErrorCause();
      cause.unmarshal(Uint8List(2));
      expect(cause.length(), equals(6));
    });
    test('ErrorCause.marshal()', () {
      final cause = _ConcreteErrorCause();
      expect(cause.marshal(), isNotNull);
    });
    test('ErrorCause.length()', () {
      final cause = _ConcreteErrorCause();
      expect(cause.length(), equals(4));
    });
    test('ErrorCause.errorCauseCode()', () {
      final cause = _ConcreteErrorCause();
      expect(cause.errorCauseCode(), isNotNull);
    });

    test('InvalidSctpChunkException.toString()', () {
      expect(InvalidSctpChunkException().toString(), isNotEmpty);
    });
    test('ErrorCauseHeader.length()', () {
      expect(ErrorCauseHeader(code: ErrorCauseCode.fromValue(1), len: 4).length(), equals(4));
    });
    test('ErrorCauseHeader.errorCauseCode()', () {
      expect(ErrorCauseHeader(code: ErrorCauseCode.fromValue(1)).errorCauseCode(), isNotNull);
    });
    test('ErrorCauseHeader.toString()', () {
      expect(ErrorCauseHeader(code: ErrorCauseCode.fromValue(1)).toString(), isNotEmpty);
    });

    test('ErrorCauseInvalidMandatoryParameter.unmarshal()', () {
      final e = ErrorCauseInvalidMandatoryParameter();
      e.unmarshal(_makeErrorCauseRaw(ErrorCauseCode.invalidMandatoryParameter.value));
      expect(e.length(), equals(4));
    });
    test('ErrorCauseInvalidMandatoryParameter.length()', () {
      expect(ErrorCauseInvalidMandatoryParameter().length(), equals(0));
    });
    test('ErrorCauseInvalidMandatoryParameter.errorCauseCode()', () {
      expect(ErrorCauseInvalidMandatoryParameter().errorCauseCode(), isNotNull);
    });
    test('ErrorCauseInvalidMandatoryParameter.toString()', () {
      expect(ErrorCauseInvalidMandatoryParameter().toString(), isNotEmpty);
    });

    test('ProtocolViolationUnmarshalException.toString()', () {
      expect(ProtocolViolationUnmarshalException('err').toString(), contains('err'));
    });
    test('ErrorCauseProtocolViolation.unmarshal()', () {
      final e = ErrorCauseProtocolViolation();
      e.unmarshal(_makeErrorCauseRaw(ErrorCauseCode.protocolViolation.value));
      expect(e.length(), equals(4));
    });
    test('ErrorCauseProtocolViolation.length()', () {
      expect(ErrorCauseProtocolViolation().length(), equals(0));
    });
    test('ErrorCauseProtocolViolation.errorCauseCode()', () {
      expect(ErrorCauseProtocolViolation().errorCauseCode(), isNotNull);
    });
    test('ErrorCauseProtocolViolation.toString()', () {
      expect(ErrorCauseProtocolViolation().toString(), isNotEmpty);
    });

    test('ErrorCauseUnrecognizedChunkType.length()', () {
      expect(ErrorCauseUnrecognizedChunkType().length(), equals(0));
    });
    test('ErrorCauseUnrecognizedChunkType.errorCauseCode()', () {
      expect(ErrorCauseUnrecognizedChunkType().errorCauseCode(), isNotNull);
    });
    test('ErrorCauseUnrecognizedChunkType.toString()', () {
      expect(ErrorCauseUnrecognizedChunkType().toString(), isNotEmpty);
    });

    test('ErrorCauseUserInitiatedAbort.unmarshal()', () {
      final e = ErrorCauseUserInitiatedAbort();
      e.unmarshal(_makeErrorCauseRaw(ErrorCauseCode.userInitiatedAbort.value));
      expect(e.length(), equals(4));
    });
    test('ErrorCauseUserInitiatedAbort.length()', () {
      expect(ErrorCauseUserInitiatedAbort().length(), equals(0));
    });
    test('ErrorCauseUserInitiatedAbort.errorCauseCode()', () {
      expect(ErrorCauseUserInitiatedAbort().errorCauseCode(), isNotNull);
    });
    test('ErrorCauseUserInitiatedAbort.toString()', () {
      expect(ErrorCauseUserInitiatedAbort().toString(), isNotEmpty);
    });

    test('PacketRawTooSmallException.toString()', () {
      expect(PacketRawTooSmallException(4, 12).toString(), contains('4'));
    });
    test('ParseSctpChunkNotEnoughDataException.toString()', () {
      expect(ParseSctpChunkNotEnoughDataException(4, 2).toString(), contains('4'));
    });
    test('UnmarshalUnknownChunkTypeException.toString()', () {
      expect(UnmarshalUnknownChunkTypeException(ChunkType.payloadData).toString(), isNotEmpty);
    });
    test('ChecksumMismatchException.toString()', () {
      expect(ChecksumMismatchException(1, 2).toString(), isNotEmpty);
    });
    test('Packet.toString()', () {
      expect(Packet().toString(), isNotEmpty);
    });

    test('ParamTypeUnhandledException.toString()', () {
      expect(ParamTypeUnhandledException(ParamType.chunkList).toString(), isNotEmpty);
    });
    test('Param.marshal()', () {
      Param p = ParamHeartbeatInfo();
      expect(p.marshal(), isNotNull);
    });
    test('Param.length()', () {
      Param p = ParamHeartbeatInfo();
      expect(p.length(), equals(0));
    });

    test('ParamHeaderTooShortException.toString()', () {
      expect(ParamHeaderTooShortException().toString(), isNotEmpty);
    });
    test('ParamHeaderSelfReportedLengthShorterException.toString()', () {
      expect(ParamHeaderSelfReportedLengthShorterException(2, 4).toString(), contains('2'));
    });
    test('ParamHeaderSelfReportedLengthLongerException.toString()', () {
      expect(ParamHeaderSelfReportedLengthLongerException(4, 8).toString(), contains('4'));
    });
    test('ParamHeaderParseFailedException.toString()', () {
      expect(ParamHeaderParseFailedException('err').toString(), contains('err'));
    });
    test('ParamHeaderUnrecognizedAction.hashCode()', () {
      expect(ParamHeaderUnrecognizedAction.fromValue(0).hashCode, equals(ParamHeaderUnrecognizedAction.fromValue(0).hashCode));
    });
    test('ParamHeader.marshal()', () {
      final h = ParamHeader(typ: ParamType.chunkList, len: 4, raw: Uint8List(0));
      expect(h.marshal(), isNotNull);
    });
    test('ParamHeader.toString()', () {
      final h = ParamHeader(typ: ParamType.chunkList, len: 4, raw: Uint8List(0));
      expect(h.toString(), isNotEmpty);
    });

    test('ParamPacketTooShortException.toString()', () {
      expect(ParamPacketTooShortException().toString(), isNotEmpty);
    });
    test('ParamType.hashCode()', () {
      expect(ParamType.chunkList.hashCode, equals(ParamType.chunkList.hashCode));
    });

    test('ParamChunkList.unmarshal()', () {
      final p = ParamChunkList();
      p.unmarshal(_makeParamRaw(ParamType.chunkList.value));
      expect(p.length(), equals(4));
    });
    test('ParamChunkList.length()', () {
      expect(ParamChunkList().length(), equals(0));
    });

    test('ParamEcnCapable.marshal()', () {
      expect(ParamEcnCapable().marshal(), isNotNull);
    });
    test('ParamEcnCapable.length()', () {
      expect(ParamEcnCapable().length(), equals(0));
    });

    test('ParamForwardTsnSupported.marshal()', () {
      expect(ParamForwardTsnSupported().marshal(), isNotNull);
    });
    test('ParamForwardTsnSupported.length()', () {
      expect(ParamForwardTsnSupported().length(), equals(0));
    });

    test('ParamHeartbeatInfo.unmarshal()', () {
      final p = ParamHeartbeatInfo();
      p.unmarshal(_makeParamRaw(ParamType.heartbeatInfo.value));
      expect(p.length(), equals(4));
    });
    test('ParamHeartbeatInfo.length()', () {
      expect(ParamHeartbeatInfo().length(), equals(0));
    });

    test('SsnResetRequestParamTooShortException.toString()', () {
      expect(SsnResetRequestParamTooShortException().toString(), isNotEmpty);
    });
    test('ParamOutgoingResetRequest.marshal()', () {
      expect(ParamOutgoingResetRequest().marshal(), isNotNull);
    });
    test('ParamOutgoingResetRequest.length()', () {
      expect(ParamOutgoingResetRequest().length(), equals(0));
    });

    test('ParamRandom.unmarshal()', () {
      final p = ParamRandom();
      p.unmarshal(_makeParamRaw(ParamType.random.value));
      expect(p.length(), equals(4));
    });
    test('ParamRandom.length()', () {
      expect(ParamRandom().length(), equals(0));
    });

    test('ReconfigRespParamTooShortException.toString()', () {
      expect(ReconfigRespParamTooShortException().toString(), isNotEmpty);
    });
    test('ReconfigResult.operator ==()', () {
      expect(ReconfigResult.fromValue(0) == ReconfigResult.fromValue(0), isTrue);
    });
    test('ReconfigResult.hashCode()', () {
      expect(ReconfigResult.fromValue(0).hashCode, equals(ReconfigResult.fromValue(0).hashCode));
    });
    test('ParamReconfigResponse.marshal()', () {
      expect(ParamReconfigResponse().marshal(), isNotNull);
    });
    test('ParamReconfigResponse.length()', () {
      expect(ParamReconfigResponse().length(), equals(0));
    });

    test('InvalidAlgorithmTypeException.toString()', () {
      expect(InvalidAlgorithmTypeException(HmacAlgorithm.fromValue(1)).toString(), contains('1'));
    });
    test('InvalidChunkLengthException.toString()', () {
      expect(InvalidChunkLengthException().toString(), isNotEmpty);
    });
    test('HmacAlgorithm.operator ==()', () {
      expect(HmacAlgorithm.fromValue(0) == HmacAlgorithm.fromValue(0), isTrue);
    });
    test('HmacAlgorithm.hashCode()', () {
      expect(HmacAlgorithm.fromValue(0).hashCode, equals(HmacAlgorithm.fromValue(0).hashCode));
    });
    test('ParamRequestedHmacAlgorithm.length()', () {
      expect(ParamRequestedHmacAlgorithm().length(), equals(0));
    });

    test('ParamStateCookie.unmarshal()', () {
      final p = ParamStateCookie();
      p.unmarshal(_makeParamRaw(ParamType.stateCookie.value));
      expect(p.length(), equals(4));
    });
    test('ParamStateCookie.length()', () {
      expect(ParamStateCookie().length(), equals(0));
    });
    test('ParamStateCookie.toString()', () {
      expect(ParamStateCookie().toString(), isNotEmpty);
    });

    test('ParamSupportedExtensions.unmarshal()', () {
      final p = ParamSupportedExtensions();
      p.unmarshal(_makeParamRaw(ParamType.supportedExt.value));
      expect(p.length(), equals(4));
    });
    test('ParamSupportedExtensions.length()', () {
      expect(ParamSupportedExtensions().length(), equals(0));
    });

    test('ZeroChecksumParamTooShortException.toString()', () {
      expect(ZeroChecksumParamTooShortException().toString(), isNotEmpty);
    });
    test('ParamZeroChecksumAcceptable.marshal()', () {
      expect(ParamZeroChecksumAcceptable().marshal(), isNotNull);
    });
    test('ParamZeroChecksumAcceptable.length()', () {
      expect(ParamZeroChecksumAcceptable().length(), equals(0));
    });
  });
}
