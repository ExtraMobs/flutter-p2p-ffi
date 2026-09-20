// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param.go` (github.com/pion/sctp): the [Param] contract every
/// concrete `param_*.go` type implements, and [buildParam], the dispatch
/// function that decodes the right concrete type from a [ParamType].
///
/// `param` and `buildParam` are unexported in Go; both stay public within
/// `lib/src` (see util.dart's file-level doc comment) but are not exported
/// from `transpiled_pion_sctp.dart`.
library;

import 'dart:typed_data';

import 'param_chunk_list.dart';
import 'param_ecn_capable.dart';
import 'param_forward_tsn_supported.dart';
import 'param_heartbeat_info.dart';
import 'param_outgoing_reset_request.dart';
import 'param_random.dart';
import 'param_reconfig_response.dart';
import 'param_requested_hmac_algorithm.dart';
import 'param_state_cookie.dart';
import 'param_supported_extensions.dart';
import 'param_zero_checksum.dart';
import 'paramtype.dart';

/// Port of `ErrParamTypeUnhandled` (param.go:16).
final class ParamTypeUnhandledException implements Exception {
  const ParamTypeUnhandledException(this.typ);

  final ParamType typ;

  @override
  String toString() => 'unhandled ParamType: $typ';
}

/// Port of `param` (param.go:12-15).
abstract interface class Param {
  /// Port of `param.marshal` (param.go:13).
  Uint8List marshal();

  /// Port of `param.length` (param.go:14).
  int length();
}

/// Port of `buildParam` (param.go:19-40).
Param buildParam(ParamType typeParam, Uint8List rawParam) {
  if (typeParam == ParamType.forwardTsnSupp) {
    return ParamForwardTsnSupported()..unmarshal(rawParam);
  } else if (typeParam == ParamType.supportedExt) {
    return ParamSupportedExtensions()..unmarshal(rawParam);
  } else if (typeParam == ParamType.ecnCapable) {
    return ParamEcnCapable()..unmarshal(rawParam);
  } else if (typeParam == ParamType.random) {
    return ParamRandom()..unmarshal(rawParam);
  } else if (typeParam == ParamType.reqHmacAlgo) {
    return ParamRequestedHmacAlgorithm()..unmarshal(rawParam);
  } else if (typeParam == ParamType.chunkList) {
    return ParamChunkList()..unmarshal(rawParam);
  } else if (typeParam == ParamType.stateCookie) {
    return ParamStateCookie()..unmarshal(rawParam);
  } else if (typeParam == ParamType.heartbeatInfo) {
    return ParamHeartbeatInfo()..unmarshal(rawParam);
  } else if (typeParam == ParamType.outSsnResetReq) {
    return ParamOutgoingResetRequest()..unmarshal(rawParam);
  } else if (typeParam == ParamType.reconfigResp) {
    return ParamReconfigResponse()..unmarshal(rawParam);
  } else if (typeParam == ParamType.zeroChecksumAcceptable) {
    return ParamZeroChecksumAcceptable()..unmarshal(rawParam);
  }
  throw ParamTypeUnhandledException(typeParam);
}
