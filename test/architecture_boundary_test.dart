// test/architecture_boundary_test.dart
//
// Mechanical enforcement of the lib/src/ module boundaries from the core-
// module-split refactor plan: a module listed as "forbidden" for a given
// directory must never be imported (or exported) from a file under it.
// This is the exit gate the plan describes for each phase -- it grows as
// later phases audit more layers (protocols in Phase 3, transport/routing
// in Phase 4, routing/services in Phase 5); see doc/architecture/README.md
// for the current import graph these rules are checked against.
//
// Import resolution mirrors tool/generate_module_index.dart's lightweight
// regex approach (both 'package:transpiled_ipfs/src/...' and relative imports),
// duplicated here rather than shared since each file is a short, standalone
// script/test with no common library to import from.
import 'dart:io';

import 'package:test/test.dart';

const _libSrcModules = [
  'core',
  'network',
  'platform',
  'proto',
  'protocols',
  'routing',
  'services',
  'storage',
  'transport',
  'utils',
];

final _importPattern = RegExp(
  r'''^\s*(?:export|import)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

String _forwardSlashes(String path) => path.replaceAll(r'\', '/');

String _normalizePath(String path) {
  final parts = path.split('/');
  final result = <String>[];
  for (final part in parts) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      if (result.isNotEmpty) result.removeLast();
    } else {
      result.add(part);
    }
  }
  return result.join('/');
}

String? _resolveToLibSrcPath(String target, String fileDir) {
  if (target.startsWith('package:transpiled_ipfs/src/')) {
    return 'lib/src/${target.substring('package:transpiled_ipfs/src/'.length)}';
  }
  if (target.startsWith('.')) {
    return _normalizePath('$fileDir/$target');
  }
  return null;
}

String? _moduleOf(String libSrcPath) {
  final idx = libSrcPath.indexOf('lib/src/');
  if (idx == -1) return null;
  final rest = libSrcPath.substring(idx + 'lib/src/'.length);
  final top = rest.split('/').first;
  return _libSrcModules.contains(top) ? top : null;
}

/// Every module a file under [dir] imports or exports from lib/src/,
/// excluding its own module.
List<String> _violationsIn(
  String dir,
  Set<String> forbidden, {
  bool Function(String forwardSlashPath)? exclude,
}) {
  final violations = <String>[];
  final files = Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => exclude == null || !exclude(_forwardSlashes(f.path)));

  for (final file in files) {
    final path = _forwardSlashes(file.path);
    final fileDir = _forwardSlashes(file.parent.path);
    final content = file.readAsStringSync();
    for (final match in _importPattern.allMatches(content)) {
      final resolved = _resolveToLibSrcPath(match.group(1)!, fileDir);
      if (resolved == null) continue;
      final targetModule = _moduleOf(resolved);
      if (targetModule != null && forbidden.contains(targetModule)) {
        violations.add('$path -> $targetModule/ (${match.group(1)})');
      }
    }
  }
  return violations;
}

void _expectNoImportsFrom(
  String label,
  String dir,
  Set<String> forbidden, {
  bool Function(String forwardSlashPath)? exclude,
}) {
  final violations = _violationsIn(dir, forbidden, exclude: exclude);
  expect(
    violations,
    isEmpty,
    reason:
        '$label must not depend on ${forbidden.join(", ")}, but found:\n'
        '${violations.join("\n")}',
  );
}

void main() {
  group('architecture boundaries (foundation layer, Phase 2)', () {
    test('platform has no lib/src dependencies', () {
      _expectNoImportsFrom(
        'lib/src/platform',
        'lib/src/platform',
        _libSrcModules.toSet(),
      );
    });

    test('utils only depends on core and platform', () {
      _expectNoImportsFrom('lib/src/utils', 'lib/src/utils', {
        'network',
        'protocols',
        'routing',
        'services',
        'storage',
        'transport',
        'proto',
      });
    });

    test(
      'core (outside the ipfs_node/ and builders/ composition root) '
      'does not reach into higher layers',
      () {
        _expectNoImportsFrom(
          'lib/src/core (excluding the composition root)',
          'lib/src/core',
          {'network', 'protocols', 'routing', 'services', 'transport'},
          exclude: (path) =>
              path.contains('/core/ipfs_node/') ||
              path.contains('/core/builders/'),
        );
      },
    );

    test('transport does not depend on the protocol/routing/service layers', () {
      _expectNoImportsFrom('lib/src/transport', 'lib/src/transport', {
        'protocols',
        'routing',
        'services',
      });
    });

    test('network does not depend on the protocol/routing/service layers', () {
      _expectNoImportsFrom('lib/src/network', 'lib/src/network', {
        'protocols',
        'routing',
        'services',
      });
    });
  });

  group('architecture boundaries (protocol layer, Phase 3)', () {
    test(
      'protocols/* only cross-import each other via the documented pairs '
      '(graphsync->bitswap, ipns->dht)',
      () {
        // protocol subdirectory -> the other protocols/<x>/ it may import.
        // Anything not listed here must not import from any other
        // protocols/<x>/ at all.
        const allowed = {
          'graphsync': {'bitswap'},
          'ipns': {'dht'},
        };

        final violations = <String>[];
        for (final entry in Directory('lib/src/protocols').listSync()) {
          if (entry is! Directory) continue;
          final protocol = _forwardSlashes(entry.path).split('/').last;
          final files = entry
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'));

          for (final file in files) {
            final path = _forwardSlashes(file.path);
            final fileDir = _forwardSlashes(file.parent.path);
            final content = file.readAsStringSync();
            for (final match in _importPattern.allMatches(content)) {
              final resolved = _resolveToLibSrcPath(match.group(1)!, fileDir);
              if (resolved == null) continue;
              final segments = resolved.split('/');
              final protocolsIdx = segments.indexOf('protocols');
              if (protocolsIdx == -1 || protocolsIdx + 1 >= segments.length) {
                continue;
              }
              final targetProtocol = segments[protocolsIdx + 1];
              if (targetProtocol == protocol) continue; // importing itself
              if (!targetProtocol.endsWith('.dart') &&
                  !(allowed[protocol]?.contains(targetProtocol) ?? false)) {
                violations.add(
                  '$path -> protocols/$targetProtocol/ (${match.group(1)})',
                );
              }
            }
          }
        }
        expect(
          violations,
          isEmpty,
          reason:
              'Unexpected cross-protocol import (only graphsync->bitswap and '
              'ipns->dht are documented as intentional):\n${violations.join("\n")}',
        );
      },
    );
  });
}
