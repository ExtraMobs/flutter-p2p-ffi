// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of the `Config` struct declared in `association.go:267-286`
/// (github.com/pion/sctp) -- there is no dedicated `config.go` upstream;
/// `Config` lives directly in `association.go`, so this port keeps it in its
/// own file only because `packages/transpiled_pion_sctp/lib/src/config.dart`
/// already existed as a file boundary here (unlike `stream.dart`'s merge of
/// `StreamState`, splitting `Config` out does not lose any Go file mapping,
/// since `association.go` itself has its own `association.dart`
/// counterpart).
///
/// `Config` is exported in Go (capitalized) and re-exported here.
///
/// `NetConn` is Go's stdlib `net.Conn` (association.go:13,166,269), not any
/// `pion/transport` type; the sole members `Association` calls on it --
/// `Read`, `Write`, `Close` -- are exactly the shape
/// `transpiled_pion_transport_v4`'s [NetConn] interface already ports (for
/// `pion/stun`'s `Net.Dial` return value), so this port reuses it rather
/// than inventing a duplicate "stdlib net.Conn" interface -- see that
/// interface's own doc comment for which members were intentionally left
/// out (none of which `Association` calls either).
library;

import 'package:transpiled_pion_logging/transpiled_pion_logging.dart'
    show DefaultLoggerFactory, LoggerFactory;
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    show NetConn;

/// Port of `Config` (association.go:267-286).
final class Config {
  Config({
    this.name = '',
    this.netConn,
    this.maxReceiveBufferSize = 0,
    this.maxMessageSize = 0,
    this.enableZeroChecksum = false,
    LoggerFactory? loggerFactory,
    this.blockWrite = false,
    this.mtu = 0,
    this.rtoMax = 0,
    this.minCwnd = 0,
    this.fastRtxWnd = 0,
    this.cwndCaStep = 0,
  }) : loggerFactory = loggerFactory ?? DefaultLoggerFactory();

  /// Port of `Config.Name` (association.go:268).
  String name;

  /// Port of `Config.NetConn` (association.go:269). See this file's doc
  /// comment for the `net.Conn` adaptation.
  NetConn? netConn;

  /// Port of `Config.MaxReceiveBufferSize` (association.go:270).
  int maxReceiveBufferSize;

  /// Port of `Config.MaxMessageSize` (association.go:271).
  int maxMessageSize;

  /// Port of `Config.EnableZeroChecksum` (association.go:272).
  bool enableZeroChecksum;

  /// Port of `Config.LoggerFactory` (association.go:273).
  LoggerFactory loggerFactory;

  /// Port of `Config.BlockWrite` (association.go:274).
  bool blockWrite;

  /// Port of `Config.MTU` (association.go:275).
  int mtu;

  /// Port of `Config.RTOMax` (association.go:279): the maximum
  /// retransmission timeout, in milliseconds.
  double rtoMax;

  /// Port of `Config.MinCwnd` (association.go:281): minimum congestion
  /// window.
  int minCwnd;

  /// Port of `Config.FastRtxWnd` (association.go:283): send window for fast
  /// retransmit.
  int fastRtxWnd;

  /// Port of `Config.CwndCAStep` (association.go:285): step of congestion
  /// window increase at Congestion Avoidance.
  int cwndCaStep;
}
