// ignore_for_file: library_prefixes
/// Port of `github.com/pion/dtls/v3/pkg/protocol` (revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md) -- the DTLS wire format package.
///
/// Split across `lib/src/pkg/protocol/*.dart` via `part`/`part of`, one Dart
/// file per Go file, mirroring `pkg/protocol/*.go` sharing one Go-package
/// private namespace (AGENTS.md "Estrutura", padrão de
/// `packages/transpiled_pion_sdp`). This library is not re-exported by the
/// package's top barrel (`lib/transpiled_pion_dtls.dart`, owned by a
/// concurrent agent porting `pkg/crypto/*` and `internal/ciphersuite`); the
/// barrel should add `export 'src/pkg/protocol/protocol.dart';` (see
/// progress notes).
library;

import 'dart:typed_data';

part 'content.dart';
part 'application_data.dart';
part 'change_cipher_spec.dart';
part 'compression_method.dart';
part 'errors.dart';
part 'version.dart';
