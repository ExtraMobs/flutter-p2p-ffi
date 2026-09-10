// tool/generate_module_index.dart
//
// AST-based (unresolved parse, package:analyzer) audit index. Per top-level
// module under lib/src/ and test/, writes a markdown file to
// doc/architecture/{lib,test}/<module>.md listing every file, its doc
// comment (extracted from source, not authored here), and every declared
// class/mixin/function/method/field with:
//   - what it extends/implements
//   - "calls" -- names invoked/instantiated inside it (by name, NOT
//     resolved to a specific declaration -- see caveat below)
//   - "referenced by" -- other declared members elsewhere whose body
//     mentions this exact name (same by-name caveat)
//
// CAVEAT: this uses parseString (syntax only, no cross-file type
// resolution), so "calls"/"referenced by" match on identifier text, not
// resolved declarations. `handler.start()` is recorded as a call to
// "start" -- it does NOT know which of the 21+ classes with a start()
// method it resolves to. This is intentionally the lighter of two tiers:
// full resolution (AnalysisContextCollection over the whole package graph)
// would be accurate but slow to run across 470+ files. Treat "referenced
// by" as "other places this name appears as a call/access", a lead to
// check, not a proven reference -- common names (start, stop, encode...)
// will have long, mostly-irrelevant lists. When a name is declared by more
// than one type (e.g. several unrelated classes each with their own
// toProto()), every one of those declarations shares the exact same
// "referenced by" list in the output, tagged "(name shared by N
// declarations)" -- the tool cannot tell which declaration a given call
// site actually resolves to, so it shows all of them under all of them
// rather than silently picking one.
//
// The module-to-module import graph (mermaid) is unchanged from the prior
// version of this tool and stays regex-based -- import statements are
// simple string literals, a real parser buys nothing there.
//
// Usage: dart run tool/generate_module_index.dart

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart' show ParseStringResult;
import 'package:analyzer/dart/analysis/utilities.dart' show parseString;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart' show RecursiveAstVisitor;

const List<String> modules = [
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

String _toForwardSlashes(String path) => path.replaceAll(r'\', '/');

String? _moduleOf(String path) {
  final normalized = path.replaceAll('\\', '/');
  final idx = normalized.indexOf('lib/src/');
  if (idx == -1) return null;
  final rest = normalized.substring(idx + 'lib/src/'.length);
  final parts = rest.split('/');
  if (parts.isEmpty) return null;
  final top = parts.first;
  return modules.contains(top) ? top : null;
}

String? _testGroupOf(String path) {
  final normalized = path.replaceAll('\\', '/');
  final idx = normalized.indexOf('test/');
  if (idx == -1) return null;
  final rest = normalized.substring(idx + 'test/'.length);
  final parts = rest.split('/');
  if (parts.length < 2) return null;
  return parts.first;
}

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

String? _resolveTarget(String target, String fileDir) {
  if (target.startsWith('package:transpiled_ipfs/src/')) {
    return 'lib/src/${target.substring('package:transpiled_ipfs/src/'.length)}';
  }
  if (target.startsWith('.')) {
    return _normalizePath('$fileDir/$target');
  }
  return null;
}

final _docLine = RegExp(r'^///\s?(.*)$', multiLine: true);
String _docSummary(String content) =>
    _docLine.firstMatch(content)?.group(1)?.trim() ?? '';

/// First line of [node]'s own `///` doc comment (declaration-level, via the
/// AST -- not the file-level [_docSummary]), or '' if it has none.
String _docOf(AnnotatedNode node) {
  final tokens = node.documentationComment?.tokens;
  if (tokens == null || tokens.isEmpty) return '';
  return tokens.first.lexeme.replaceFirst(RegExp(r'^///\s?'), '').trim();
}

/// A declared member (method or public field) inside a type, or a
/// top-level function/variable.
class Member {
  Member(this.kind, this.name, {this.doc = ''});
  final String kind; // method, field, static field, function, variable
  final String name;
  final String doc;
  final Set<String> calls = {};
}

/// A declared type (class/mixin) with its members.
class TypeDecl {
  TypeDecl(this.kind, this.name, {this.doc = '', this.extendsName, this.implementsNames = const []});
  final String kind; // class, abstract class, mixin
  final String name;
  final String doc;
  final String? extendsName;
  final List<String> implementsNames;
  final List<Member> members = [];
}

class FileAudit {
  FileAudit(this.doc);
  final String doc;
  final List<TypeDecl> types = [];
  final List<Member> topLevel = []; // top-level functions/variables
}

/// Collects identifier-like names invoked/instantiated/read within an AST
/// subtree. Used for both "calls" (method bodies) and field initializers.
class _NameCollector extends RecursiveAstVisitor<void> {
  final Set<String> names = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    names.add(node.methodName.name);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    names.add(node.constructorName.type.toSource().split('<').first);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    names.add(node.propertyName.name);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    names.add(node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }
}

Set<String> _namesIn(AstNode? node) {
  if (node == null) return {};
  final collector = _NameCollector();
  node.accept(collector);
  return collector.names;
}

bool _isPublic(String name) => !name.startsWith('_');

FileAudit _auditFile(String content, String path) {
  final audit = FileAudit(_docSummary(content));
  final ParseStringResult parsed;
  try {
    parsed = parseString(content: content, path: path, throwIfDiagnostics: false);
  } catch (_) {
    return audit; // unparsable (shouldn't happen for code that compiles)
  }

  for (final decl in parsed.unit.declarations) {
    if (decl is ClassDeclaration) {
      final kind = decl.abstractKeyword != null ? 'abstract class' : 'class';
      final type = TypeDecl(
        kind,
        decl.namePart.typeName.lexeme,
        doc: _docOf(decl),
        extendsName: decl.extendsClause?.superclass.toSource(),
        implementsNames:
            decl.implementsClause?.interfaces.map((NamedType t) => t.toSource()).toList() ??
                const [],
      );
      for (final m in decl.body.members) {
        if (m is MethodDeclaration && _isPublic(m.name.lexeme)) {
          final member = Member('method', m.name.lexeme, doc: _docOf(m));
          member.calls.addAll(_namesIn(m.body));
          type.members.add(member);
        } else if (m is FieldDeclaration) {
          final kind = m.isStatic ? 'static field' : 'field';
          final doc = _docOf(m);
          for (final v in m.fields.variables) {
            if (!_isPublic(v.name.lexeme)) continue;
            final member = Member(kind, v.name.lexeme, doc: doc);
            member.calls.addAll(_namesIn(v.initializer));
            type.members.add(member);
          }
        }
      }
      audit.types.add(type);
    } else if (decl is MixinDeclaration) {
      final type = TypeDecl(
        'mixin',
        decl.name.lexeme,
        doc: _docOf(decl),
        implementsNames:
            decl.implementsClause?.interfaces.map((NamedType t) => t.toSource()).toList() ??
                const [],
      );
      for (final m in decl.body.members) {
        if (m is MethodDeclaration && _isPublic(m.name.lexeme)) {
          final member = Member('method', m.name.lexeme, doc: _docOf(m));
          member.calls.addAll(_namesIn(m.body));
          type.members.add(member);
        }
      }
      audit.types.add(type);
    } else if (decl is FunctionDeclaration && _isPublic(decl.name.lexeme)) {
      final member = Member('function', decl.name.lexeme, doc: _docOf(decl));
      member.calls.addAll(_namesIn(decl.functionExpression.body));
      audit.topLevel.add(member);
    } else if (decl is TopLevelVariableDeclaration) {
      final doc = _docOf(decl);
      for (final v in decl.variables.variables) {
        if (!_isPublic(v.name.lexeme)) continue;
        final member = Member('variable', v.name.lexeme, doc: doc);
        member.calls.addAll(_namesIn(v.initializer));
        audit.topLevel.add(member);
      }
    }
  }
  return audit;
}

void main() {
  final libSrc = Directory('lib/src');
  final testDir = Directory('test');
  if (!libSrc.existsSync()) {
    stderr.writeln('lib/src not found — run from the repo root.');
    exit(1);
  }

  final libFiles = libSrc
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  final testFiles = testDir.existsSync()
      ? testDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
      : <File>[];

  final importPattern = RegExp(
    r'''^\s*(?:export|import)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  // --- module-to-module import graph (regex, unchanged approach) ---
  final fileCount = <String, int>{};
  final edges = <String, Set<String>>{};
  final directlyTested = <String>{};

  for (final file in libFiles) {
    final mod = _moduleOf(file.path);
    if (mod == null) continue;
    fileCount[mod] = (fileCount[mod] ?? 0) + 1;
    final content = file.readAsStringSync();
    final fileDir = _toForwardSlashes(file.parent.path);
    for (final match in importPattern.allMatches(content)) {
      final target = match.group(1)!;
      if (target.startsWith('package:transpiled_')) {
        final pkgName = target.substring(
          'package:'.length,
          target.indexOf('/', 'package:'.length),
        );
        edges.putIfAbsent(mod, () => {}).add('$pkgName[pkg]');
        continue;
      }
      final targetPath = _resolveTarget(target, fileDir);
      if (targetPath == null) continue;
      final targetMod = _moduleOf(targetPath);
      if (targetMod != null && targetMod != mod) {
        edges.putIfAbsent(mod, () => {}).add(targetMod);
      }
    }
  }
  for (final file in testFiles) {
    final content = file.readAsStringSync();
    final fileDir = _toForwardSlashes(file.parent.path);
    for (final match in importPattern.allMatches(content)) {
      final target = _resolveTarget(match.group(1)!, fileDir);
      if (target != null && target.startsWith('lib/src/')) {
        directlyTested.add(target);
      }
    }
  }

  // --- AST audit per lib/src file ---
  stderr.writeln('Parsing ${libFiles.length} lib/src files...');
  final audits = <String, FileAudit>{}; // relPath -> audit
  for (final file in libFiles) {
    final mod = _moduleOf(file.path);
    if (mod == null) continue;
    final rel = _toForwardSlashes(file.path);
    final relFromLib = rel.substring(rel.indexOf('lib/src/'));
    audits[relFromLib] = _auditFile(file.readAsStringSync(), relFromLib);
  }

  // Global declared-name -> Set<(file, ownerLabel)> for by-name reverse refs.
  final declaredBy = <String, List<(String, String)>>{};
  for (final entry in audits.entries) {
    for (final t in entry.value.types) {
      for (final m in t.members) {
        declaredBy.putIfAbsent(m.name, () => []).add((entry.key, '${t.name}.${m.name}'));
      }
    }
    for (final m in entry.value.topLevel) {
      declaredBy.putIfAbsent(m.name, () => []).add((entry.key, m.name));
    }
  }

  // Build reverse index: declared name -> list of (callerFile, callerOwner).
  final referencesOf = <String, List<(String, String)>>{};
  for (final entry in audits.entries) {
    for (final t in entry.value.types) {
      for (final m in t.members) {
        for (final call in m.calls) {
          if (!declaredBy.containsKey(call)) continue;
          referencesOf.putIfAbsent(call, () => []).add((entry.key, '${t.name}.${m.name}'));
        }
      }
    }
    for (final m in entry.value.topLevel) {
      for (final call in m.calls) {
        if (!declaredBy.containsKey(call)) continue;
        referencesOf.putIfAbsent(call, () => []).add((entry.key, m.name));
      }
    }
  }

  // --- write per-module lib/ audit files ---
  final outLibDir = Directory('doc/architecture/lib');
  outLibDir.createSync(recursive: true);

  String memberLine(String file, TypeDecl? owner, Member m) {
    final refs = referencesOf[m.name] ?? const [];
    final selfLabel = owner == null ? m.name : '${owner.name}.${m.name}';
    final externalRefs = refs.where((r) => !(r.$1 == file && r.$2 == selfLabel)).toList();
    final sharedByCount = declaredBy[m.name]?.length ?? 1;
    final buf = StringBuffer('- **${m.name}** (${m.kind})');
    if (m.doc.isNotEmpty) buf.write(' — ${m.doc}');
    if (m.calls.isNotEmpty) {
      buf.write('\n  - calls: ${m.calls.join(", ")}');
    }
    if (externalRefs.isNotEmpty) {
      final ambiguity = sharedByCount > 1
          ? ' (name shared by $sharedByCount declarations -- not resolved to this one specifically, see caveat)'
          : '';
      buf.write('\n  - referenced by (by name)$ambiguity:');
      for (final r in externalRefs) {
        buf.write('\n    - `${r.$1}` (${r.$2})');
      }
    }
    return buf.toString();
  }

  for (final mod in modules) {
    final files = audits.keys.where((f) => _moduleOf(f) == mod).toList()..sort();
    if (files.isEmpty) {
      // A module that used to have files (e.g. everything moved out of it)
      // must not leave a stale doc describing content that no longer
      // exists -- the index is meant to show what's actually live.
      final stale = File('${outLibDir.path}/$mod.md');
      if (stale.existsSync()) stale.deleteSync();
      continue;
    }
    final buf = StringBuffer();
    buf.writeln('---');
    buf.writeln('module: $mod');
    buf.writeln('kind: lib/src audit');
    buf.writeln('generated: ${DateTime.now().toIso8601String()}');
    buf.writeln('---\n');
    buf.writeln('# Module `$mod` (`lib/src/$mod/`)\n');
    buf.writeln(
      '_Generated by `tool/generate_module_index.dart` via unresolved AST '
      '(`package:analyzer`). "Calls"/"referenced by" match by identifier '
      'name, not resolved type -- see the caveat at the top of the script. '
      'Do not edit by hand._\n',
    );
    final deps = (edges[mod]?.toList() ?? [])..sort();
    final depsCell = deps.isEmpty
        ? '—'
        : deps
            .map((d) => '[$d](${d.endsWith("[pkg]") ? "" : "$d.md"})')
            .join(', ');
    buf.writeln('Depends on: $depsCell\n');

    for (final f in files) {
      final audit = audits[f]!;
      buf.writeln('## `$f`\n');
      if (audit.doc.isNotEmpty) buf.writeln('${audit.doc}\n');
      buf.writeln(directlyTested.contains(f) ? '_Directly tested._\n' : '_No known direct test._\n');

      for (final t in audit.types) {
        final ext = t.extendsName != null ? ' extends ${t.extendsName}' : '';
        final impl = t.implementsNames.isNotEmpty ? ' implements ${t.implementsNames.join(", ")}' : '';
        buf.writeln('### ${t.kind} `${t.name}`$ext$impl\n');
        if (t.doc.isNotEmpty) buf.writeln('${t.doc}\n');
        if (t.members.isEmpty) {
          buf.writeln('_(no public members)_\n');
        } else {
          for (final m in t.members) {
            buf.writeln(memberLine(f, t, m));
          }
          buf.writeln('');
        }
      }
      for (final m in audit.topLevel) {
        buf.writeln('### top-level `${m.name}` (${m.kind})\n');
        buf.writeln(memberLine(f, null, m));
        buf.writeln('');
      }
    }
    File('${outLibDir.path}/$mod.md').writeAsStringSync(buf.toString());
  }

  // --- write per-group test/ files (test()/group() descriptions) ---
  final outTestDir = Directory('doc/architecture/test');
  outTestDir.createSync(recursive: true);
  final testCallPattern = RegExp(
    r'''(?:test|group)\(\s*['"]([^'"]+)['"]''',
  );
  final testGroups = <String, List<(String, List<String>)>>{};
  for (final file in testFiles) {
    final group = _testGroupOf(file.path) ?? '(root)';
    final content = file.readAsStringSync();
    final descriptions = testCallPattern.allMatches(content).map((m) => m.group(1)!).toList();
    final rel = _toForwardSlashes(file.path);
    testGroups.putIfAbsent(group, () => []).add((rel.substring(rel.indexOf('test/')), descriptions));
  }
  for (final entry in testGroups.entries) {
    final buf = StringBuffer();
    buf.writeln('---');
    buf.writeln('test-group: ${entry.key}');
    buf.writeln('generated: ${DateTime.now().toIso8601String()}');
    buf.writeln('---\n');
    buf.writeln('# `test/${entry.key}/`\n');
    for (final (file, descriptions) in entry.value..sort((a, b) => a.$1.compareTo(b.$1))) {
      buf.writeln('## `$file`\n');
      for (final d in descriptions) {
        buf.writeln('- $d');
      }
      buf.writeln('');
    }
    File('${outTestDir.path}/${entry.key.replaceAll('/', '_')}.md').writeAsStringSync(buf.toString());
  }
  // A group whose last file moved/disappeared must not leave a stale doc
  // behind -- same reasoning as the lib/ module cleanup above.
  final currentTestFiles = testGroups.keys.map((g) => '${g.replaceAll('/', '_')}.md').toSet();
  for (final f in outTestDir.listSync().whereType<File>()) {
    final name = _toForwardSlashes(f.path).split('/').last;
    if (name.endsWith('.md') && !currentTestFiles.contains(name)) {
      f.deleteSync();
    }
  }

  // --- overview / entry point ---
  final overview = StringBuffer();
  overview.writeln('# Architecture Index — Overview\n');
  overview.writeln(
    'Generated by `tool/generate_module_index.dart` on ${DateTime.now().toIso8601String()}. '
    'One file per module under [lib/](lib/) and [test/](test/), mirroring the repository\'s real structure. '
    'Do not edit these files by hand -- regenerate with `dart run tool/generate_module_index.dart` from the repo root. '
    'See [AGENTS.md](AGENTS.md) for how to use this index.\n',
  );
  overview.writeln('## Modules (`lib/src/*`)\n');
  overview.writeln('| Module | Files | Depends on |');
  overview.writeln('|---|---|---|');
  for (final m in modules) {
    if ((fileCount[m] ?? 0) == 0) continue;
    final deps = (edges[m]?.toList() ?? [])..sort();
    overview.writeln('| [$m](lib/$m.md) | ${fileCount[m]} | ${deps.isEmpty ? "—" : deps.join(", ")} |');
  }
  overview.writeln('\n## Test Groups (`test/*`)\n');
  for (final g in (testGroups.keys.toList()..sort())) {
    overview.writeln('- [test/$g](test/${g.replaceAll('/', '_')}.md) (${testGroups[g]!.length} files)');
  }
  File('doc/architecture/README.md').writeAsStringSync(overview.toString());

  stdout.writeln(
    'Wrote: doc/architecture/README.md + ${modules.where((m) => (fileCount[m] ?? 0) > 0).length} '
    'lib/ modules + ${testGroups.length} test/ groups',
  );
}
