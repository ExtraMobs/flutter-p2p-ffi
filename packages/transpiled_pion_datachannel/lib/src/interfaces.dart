// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

/// Port of `datachannel.go` interfaces (github.com/pion/datachannel).
library;

import 'dart:typed_data';

abstract interface class Reader {
  Future<(int, bool)> readDataChannel(Uint8List p);
}

abstract interface class ReadDeadliner {
  Future<void> setReadDeadline(DateTime? t);
}

abstract interface class Writer {
  Future<int> writeDataChannel(Uint8List p, bool isString);
}

abstract interface class WriteDeadliner {
  Future<void> setWriteDeadline(DateTime? t);
}

abstract interface class ReadWriteCloser implements Reader, Writer {
  Future<int> read(Uint8List p);
  Future<int> write(Uint8List p);
  Future<void> close();
}

abstract interface class ReadWriteCloserDeadliner
    implements ReadWriteCloser, ReadDeadliner, WriteDeadliner {}
