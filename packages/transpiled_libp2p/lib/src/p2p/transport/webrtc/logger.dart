// SPDX-FileCopyrightText: 2023 The Go-Libp2p Authors
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'package:logging/logging.dart' as logging_pkg;

/// PionLogger adapts pion's logger to go-libp2p's semantics.
class PionLogger {
  PionLogger([this.name = 'webrtc-transport-pion']);
  final String name;

  void debug(String s) {}
  void debugf(String s, [List<dynamic>? args]) {}
  void error(String s) {}
  void errorf(String s, [List<dynamic>? args]) {}
  void info(String s) {}
  void infof(String s, [List<dynamic>? args]) {}
  void warn(String s) {}
  void warnf(String s, [List<dynamic>? args]) {}
  void trace(String s) {}
  void tracef(String s, [List<dynamic>? args]) {}
}

/// LoggerFactory creates Pion loggers.
class LoggerFactory {
  PionLogger newLogger(String scope) => PionLogger(scope);
}
