// Regenerates lib/src/embedded_data.dart from go-libp2p-asn-util's
// `sorted-network-list.bin` (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md; also recorded there: source sha256
// 858da2ac9b97728971753f7d858e6a946178a9456a2dbaf5787781e4ebe2186e).
//
// Go embeds the file directly (`//go:embed`); Dart libraries can't embed
// arbitrary binary assets and load at runtime from `lib/` reliably across
// every platform this project targets (including web), so this port
// instead bakes the bytes into a generated Dart source file as a base64
// string, decoded once into a `Uint8List` on first use. Re-run this
// script only if go-libp2p-asn-util's dataset revision changes.
//
// Usage: dart run tool/generate_embedded.dart <path-to-sorted-network-list.bin>
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final input = args.isNotEmpty
      ? args[0]
      : '../../go-ipfs-reference/go-libp2p-asn-util/sorted-network-list.bin';
  final bytes = File(input).readAsBytesSync();
  final b64 = base64Encode(bytes);

  final out = StringBuffer()
    ..writeln("part of '../transpiled_libp2p_asn_util.dart';")
    ..writeln()
    ..writeln('// GENERATED FILE -- do not edit by hand.')
    ..writeln('// Produced by tool/generate_embedded.dart from')
    ..writeln('// go-libp2p-asn-util\'s `sorted-network-list.bin`')
    ..writeln('// (revision fixed in doc/transpilation/UPSTREAM_LOCK.md).')
    ..writeln('//')
    ..writeln('// Source byte length: ${bytes.length}')
    ..writeln('// Source sha256:')
    ..writeln('//   ${sha256Hex(bytes)}')
    ..writeln()
    ..writeln('/// Base64-encoded contents of the embedded dataset (see the')
    ..writeln('/// header comment above for provenance and hash).')
    ..writeln('const String sortedNetworkListBase64 =')
    ..writeln("    '$b64';");

  File('lib/src/embedded_data.dart').writeAsStringSync(out.toString());
  stderr.writeln(
    'Wrote lib/src/embedded_data.dart (${bytes.length} source bytes, '
    '${b64.length} base64 chars).',
  );
}

/// Minimal SHA-256 (no dependency on package:crypto for a one-shot
/// dev-time generator script) -- used only to stamp the generated file's
/// doc comment with a verifiable hash of its source.
String sha256Hex(List<int> data) {
  // Delegate to `sha256sum`-equivalent via dart:io is unavailable without
  // a package; instead shell out to the platform's sha256 tool, which is
  // present in this project's dev environment (git bash / coreutils).
  final tmp = File(
    '${Directory.systemTemp.path}/asn_embed_${DateTime.now().microsecondsSinceEpoch}.bin',
  );
  tmp.writeAsBytesSync(data);
  try {
    final result = Process.runSync('sha256sum', [tmp.path]);
    if (result.exitCode == 0) {
      return (result.stdout as String).split(' ').first.trim();
    }
  } catch (_) {
    // Fall through to the placeholder below on platforms without
    // sha256sum; the hash is documentation, not something checked in
    // code.
  } finally {
    if (tmp.existsSync()) tmp.deleteSync();
  }
  return '(unavailable -- see doc/transpilation/UPSTREAM_LOCK.md)';
}
