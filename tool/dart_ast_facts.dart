// tool/dart_ast_facts.dart
//
// Emite, em JSON, fatos sintáticos de todo arquivo .dart sob lib/, test/ e
// packages/*/lib/, extraídos via parse não resolvido do package:analyzer
// (mesma técnica de tool/generate_module_index.dart: parseString,
// throwIfDiagnostics: false, sem resolução de tipos).
//
// Este arquivo NÃO decide regra alguma — apenas descreve a árvore sintática
// em uma estrutura de dados. A lógica das 25 regras do auditor
// (tool/audit_ast_nomenclature.py) consome esse JSON e continua em Python;
// migrar essa lógica não é objetivo deste arquivo.
//
// Uso: dart run tool/dart_ast_facts.dart --root <projectRoot> --out <arquivo.json>
//
// Zero uso de RegExp: toda extração vem de nós da AST ou de operações de
// String simples (startsWith/substring), nunca de expressão regular.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart' show parseString;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart' show RecursiveAstVisitor;
import 'package:analyzer/source/line_info.dart' show LineInfo;

void main(List<String> args) {
  var root = Directory.current.path;
  String? out;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--root' && i + 1 < args.length) {
      root = args[++i];
    } else if (arg == '--out' && i + 1 < args.length) {
      out = args[++i];
    } else {
      stderr.writeln('argumento desconhecido: $arg');
      exit(1);
    }
  }
  if (out == null) {
    stderr.writeln(
      'uso: dart run tool/dart_ast_facts.dart --root <dir> --out <arquivo.json>',
    );
    exit(1);
  }

  final rootDir = Directory(root).absolute;
  if (!rootDir.existsSync()) {
    stderr.writeln('diretório raiz não encontrado: ${rootDir.path}');
    exit(1);
  }

  final files = <File>{};
  files.addAll(_dartFilesUnder(Directory('${rootDir.path}/lib')));
  files.addAll(_dartFilesUnder(Directory('${rootDir.path}/test')));
  final packagesDir = Directory('${rootDir.path}/packages');
  if (packagesDir.existsSync()) {
    for (final entry in packagesDir.listSync()) {
      if (entry is Directory) {
        files.addAll(_dartFilesUnder(Directory('${entry.path}/lib')));
      }
    }
  }

  final sortedFiles = files.toList()..sort((a, b) => a.path.compareTo(b.path));

  final filesJson = <String, dynamic>{};
  for (final file in sortedFiles) {
    final relPath = _relativePath(file.path, rootDir.path);
    late String content;
    try {
      content = file.readAsStringSync();
    } on FormatException {
      // Bytes malformados: relê permitindo caracteres inválidos, em vez de
      // abortar o lote inteiro por um arquivo.
      content = utf8.decode(file.readAsBytesSync(), allowMalformed: true);
    }
    filesJson[relPath] = _factsForFile(
      content: content,
      relPath: relPath,
      isTestFile: relPath.startsWith('test/'),
    );
  }

  final sortedKeys = filesJson.keys.toList()..sort();
  final orderedFiles = <String, dynamic>{
    for (final k in sortedKeys) k: filesJson[k],
  };

  final result = {'version': 1, 'files': orderedFiles};
  File(out).writeAsStringSync(const JsonEncoder().convert(result));
  stderr.writeln(
    'dart_ast_facts: ${sortedFiles.length} arquivos processados -> $out',
  );
}

// --------------------------------------------------------------------------
// Descoberta de arquivos
// --------------------------------------------------------------------------

List<File> _dartFilesUnder(Directory dir) {
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !_isSkippedPath(f.path))
      .toList();
}

bool _isSkippedPath(String path) {
  final segments = path.replaceAll('\\', '/').split('/');
  return segments.contains('.dart_tool') || segments.contains('build');
}

String _relativePath(String filePath, String rootPath) {
  final normFile = filePath.replaceAll('\\', '/');
  final normRoot = rootPath.replaceAll('\\', '/');
  final rootWithSlash = normRoot.endsWith('/') ? normRoot : '$normRoot/';
  if (normFile.startsWith(rootWithSlash)) {
    return normFile.substring(rootWithSlash.length);
  }
  return normFile;
}

// --------------------------------------------------------------------------
// Fatos por arquivo
// --------------------------------------------------------------------------

Map<String, dynamic> _factsForFile({
  required String content,
  required String relPath,
  required bool isTestFile,
}) {
  final result = parseString(content: content, throwIfDiagnostics: false);
  final unit = result.unit;
  final lineInfo = result.lineInfo;

  final parseErrors = [
    for (final diagnostic in result.errors)
      {
        'line': lineInfo
            .getLocation(diagnostic.problemMessage.offset)
            .lineNumber,
        'message': diagnostic.problemMessage.messageText(includeUrl: false),
      },
  ];

  final imports = <Map<String, dynamic>>[];
  for (final directive in unit.directives) {
    if (directive is ImportDirective) {
      final show = <String>[];
      final hide = <String>[];
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator) {
          show.addAll(combinator.shownNames.map((n) => n.name));
        } else if (combinator is HideCombinator) {
          hide.addAll(combinator.hiddenNames.map((n) => n.name));
        }
      }
      imports.add({
        'uri': directive.uri.stringValue ?? '',
        'prefix': directive.prefix?.name,
        'show': show,
        'hide': hide,
        'line': _lineOf(lineInfo, directive.offset),
      });
    }
  }

  final declarations = _collectDeclarations(unit, content, lineInfo);

  final main = _MainVisitor(lineInfo);
  unit.accept(main);

  final facts = <String, dynamic>{
    'parseErrors': parseErrors,
    'imports': imports,
    'declarations': declarations,
    'declaredIdentifiers': main.declaredIdentifiers.toList()..sort(),
    'invocations': main.invocations,
    'assignments': main.assignments,
    'bitwiseAndHexLiterals': main.bitwiseAndHexLiterals,
  };

  if (isTestFile) {
    final testCollector = _TestCallCollector(content, lineInfo);
    unit.accept(testCollector);
    facts['tests'] = testCollector.calls;
  }

  return facts;
}

int _lineOf(LineInfo lineInfo, int offset) =>
    lineInfo.getLocation(offset).lineNumber;

// --------------------------------------------------------------------------
// Declarações (percurso estrutural explícito — nunca desce a corpos de
// função/método, então nunca confunde uma função local com uma declaração
// de topo; ver nota em declaredIdentifiers, que cobre as duas via visitor).
// --------------------------------------------------------------------------

List<Map<String, dynamic>> _collectDeclarations(
  CompilationUnit unit,
  String content,
  LineInfo lineInfo,
) {
  final decls = <Map<String, dynamic>>[];
  for (final member in unit.declarations) {
    _emitTopLevelDecl(member, decls, content, lineInfo);
  }
  return decls;
}

void _emitTopLevelDecl(
  CompilationUnitMember member,
  List<Map<String, dynamic>> decls,
  String content,
  LineInfo lineInfo,
) {
  switch (member) {
    case ClassDeclaration():
      final name = member.namePart.typeName.lexeme;
      final supertypes = <String>[
        if (member.extendsClause != null)
          member.extendsClause!.superclass.name.lexeme,
        ...?member.withClause?.mixinTypes.map((t) => t.name.lexeme),
        ...?member.implementsClause?.interfaces.map((t) => t.name.lexeme),
      ];
      decls.add(
        _decl(
          kind: 'class',
          name: name,
          parent: null,
          line: _lineOf(lineInfo, member.namePart.typeName.offset),
          offset: member.offset,
          end: member.end,
          metadata: member.metadata,
          content: content,
          supertypes: supertypes,
        ),
      );
      _emitPrimaryConstructorAndFields(
        member.namePart,
        name,
        decls,
        content,
        lineInfo,
      );
      for (final m in member.body.members) {
        _emitClassMember(m, name, decls, content, lineInfo);
      }
    case MixinDeclaration():
      final name = member.name.lexeme;
      final supertypes = <String>[
        ...?member.onClause?.superclassConstraints.map((t) => t.name.lexeme),
        ...?member.implementsClause?.interfaces.map((t) => t.name.lexeme),
      ];
      decls.add(
        _decl(
          kind: 'mixin',
          name: name,
          parent: null,
          line: _lineOf(lineInfo, member.name.offset),
          offset: member.offset,
          end: member.end,
          metadata: member.metadata,
          content: content,
          supertypes: supertypes,
        ),
      );
      for (final m in member.body.members) {
        _emitClassMember(m, name, decls, content, lineInfo);
      }
    case EnumDeclaration():
      final name = member.namePart.typeName.lexeme;
      final supertypes = <String>[
        ...?member.withClause?.mixinTypes.map((t) => t.name.lexeme),
        ...?member.implementsClause?.interfaces.map((t) => t.name.lexeme),
      ];
      decls.add(
        _decl(
          kind: 'enum',
          name: name,
          parent: null,
          line: _lineOf(lineInfo, member.namePart.typeName.offset),
          offset: member.offset,
          end: member.end,
          metadata: member.metadata,
          content: content,
          supertypes: supertypes,
        ),
      );
      _emitPrimaryConstructorAndFields(
        member.namePart,
        name,
        decls,
        content,
        lineInfo,
      );
      for (final c in member.body.constants) {
        decls.add(
          _decl(
            kind: 'field',
            name: c.name.lexeme,
            parent: name,
            line: _lineOf(lineInfo, c.name.offset),
            offset: c.offset,
            end: c.end,
            metadata: c.metadata,
            content: content,
          ),
        );
      }
      for (final m in member.body.members) {
        _emitClassMember(m, name, decls, content, lineInfo);
      }
    case ExtensionDeclaration():
      final nameToken = member.name;
      if (nameToken == null) return; // extensão sem nome: ignorada (spec).
      final name = nameToken.lexeme;
      final onName = _typeAnnotationName(
        member.onClause?.extendedType,
        content,
      );
      decls.add(
        _decl(
          kind: 'extension',
          name: name,
          parent: null,
          line: _lineOf(lineInfo, nameToken.offset),
          offset: member.offset,
          end: member.end,
          metadata: member.metadata,
          content: content,
          supertypes: onName == null ? const [] : [onName],
        ),
      );
      for (final m in member.body.members) {
        _emitClassMember(m, name, decls, content, lineInfo);
      }
    case ExtensionTypeDeclaration():
      final name = member.namePart.typeName.lexeme;
      final supertypes = <String>[
        ...?member.implementsClause?.interfaces.map((t) => t.name.lexeme),
      ];
      decls.add(
        _decl(
          kind: 'extension_type',
          name: name,
          parent: null,
          line: _lineOf(lineInfo, member.namePart.typeName.offset),
          offset: member.offset,
          end: member.end,
          metadata: member.metadata,
          content: content,
          supertypes: supertypes,
        ),
      );
      _emitPrimaryConstructorAndFields(
        member.namePart,
        name,
        decls,
        content,
        lineInfo,
      );
      for (final m in member.body.members) {
        _emitClassMember(m, name, decls, content, lineInfo);
      }
    case GenericTypeAlias():
      final target = content.substring(member.type.offset, member.type.end);
      decls.add(
        _decl(
          kind: 'typedef',
          name: member.name.lexeme,
          parent: null,
          line: _lineOf(lineInfo, member.name.offset),
          offset: member.offset,
          end: member.end,
          metadata: member.metadata,
          content: content,
          typedefTarget: target,
        ),
      );
    case FunctionTypeAlias():
      final start = member.typedefKeyword.end;
      final end = member.semicolon.offset;
      final target = content.substring(start, end).trim();
      decls.add(
        _decl(
          kind: 'typedef',
          name: member.name.lexeme,
          parent: null,
          line: _lineOf(lineInfo, member.name.offset),
          offset: member.offset,
          end: member.end,
          metadata: member.metadata,
          content: content,
          typedefTarget: target,
        ),
      );
    case TopLevelVariableDeclaration():
      final fieldType = member.variables.type;
      for (final v in member.variables.variables) {
        decls.add(
          _decl(
            kind: 'field',
            name: v.name.lexeme,
            parent: null,
            line: _lineOf(lineInfo, v.name.offset),
            offset: member.offset,
            end: member.end,
            metadata: member.metadata,
            content: content,
            signatureTypes: _signatureTypes(fieldType: fieldType),
          ),
        );
      }
    case FunctionDeclaration():
      final kind = member.isGetter
          ? 'getter'
          : member.isSetter
          ? 'setter'
          : 'function';
      final params =
          member.functionExpression.parameters?.parameters.toList() ??
          const <FormalParameter>[];
      decls.add(
        _decl(
          kind: kind,
          name: member.name.lexeme,
          parent: null,
          line: _lineOf(lineInfo, member.name.offset),
          offset: member.offset,
          end: member.end,
          metadata: member.metadata,
          content: content,
          returnType: _returnTypeJson(member.returnType, content),
          signatureTypes: _signatureTypes(
            returnType: member.returnType,
            parameters: params,
            typeParameters: member.functionExpression.typeParameters,
          ),
        ),
      );
    default:
    // ClassTypeAlias (`class A = B with C;`) e demais membros de topo não
    // listados na cobertura exigida: sem entrada de declaração.
  }
}

void _emitClassMember(
  ClassMember member,
  String parentName,
  List<Map<String, dynamic>> decls,
  String content,
  LineInfo lineInfo,
) {
  switch (member) {
    case ConstructorDeclaration():
      final nameToken = member.name;
      final name = nameToken?.lexeme ?? parentName;
      // typeName (não typeName2, ainda @experimental) sempre aponta para o
      // nome do tipo (`A` em `A() {}`/`A.named() {}`) nesta sintaxe comum;
      // cai no nome do próprio construtor quando presente.
      final anchorOffset = nameToken?.offset ?? member.typeName!.offset;
      decls.add(
        _decl(
          kind: 'constructor',
          name: name,
          parent: parentName,
          line: _lineOf(lineInfo, anchorOffset),
          offset: member.offset,
          end: member.end,
          metadata: member.metadata,
          content: content,
        ),
      );
    case MethodDeclaration():
      final kind = member.isGetter
          ? 'getter'
          : member.isSetter
          ? 'setter'
          : member.isOperator
          ? 'operator'
          : 'method';
      final name = member.isOperator
          ? 'operator ${member.name.lexeme}'
          : member.name.lexeme;
      final params =
          member.parameters?.parameters.toList() ?? const <FormalParameter>[];
      decls.add(
        _decl(
          kind: kind,
          name: name,
          parent: parentName,
          line: _lineOf(lineInfo, member.name.offset),
          offset: member.offset,
          end: member.end,
          metadata: member.metadata,
          content: content,
          returnType: _returnTypeJson(member.returnType, content),
          signatureTypes: _signatureTypes(
            returnType: member.returnType,
            parameters: params,
            typeParameters: member.typeParameters,
          ),
        ),
      );
    case FieldDeclaration():
      final fieldType = member.fields.type;
      for (final v in member.fields.variables) {
        decls.add(
          _decl(
            kind: 'field',
            name: v.name.lexeme,
            parent: parentName,
            line: _lineOf(lineInfo, v.name.offset),
            offset: member.offset,
            end: member.end,
            metadata: member.metadata,
            content: content,
            signatureTypes: _signatureTypes(fieldType: fieldType),
          ),
        );
      }
    default:
    // PrimaryConstructorBody e outros membros sem símbolo próprio nomeado.
  }
}

/// Emite o construtor primário (`E(int value)` / `E.named(int value)`) e o(s)
/// campo(s) de representação declarados por ele. Cobre tanto extension types
/// quanto o recurso mais novo de construtor primário em classes/enums —
/// mesmo código, mesma regra: um `FieldFormalParameter` (`this.x`) refere-se a
/// um campo já declarado em outro lugar e não gera novo registro; um
/// parâmetro declarativo "nu" declara o campo e gera um.
void _emitPrimaryConstructorAndFields(
  ClassNamePart namePart,
  String ownerName,
  List<Map<String, dynamic>> decls,
  String content,
  LineInfo lineInfo,
) {
  if (namePart is! PrimaryConstructorDeclaration) return;
  final ctorNameToken = namePart.constructorName?.name;
  final ctorName = ctorNameToken?.lexeme ?? ownerName;
  decls.add(
    _decl(
      kind: 'constructor',
      name: ctorName,
      parent: ownerName,
      line: _lineOf(lineInfo, (ctorNameToken ?? namePart.typeName).offset),
      offset: namePart.offset,
      end: namePart.end,
      metadata: const [],
      content: content,
    ),
  );
  for (final param in namePart.formalParameters.parameters) {
    if (param is FieldFormalParameter) continue;
    final nameToken = param.name;
    if (nameToken == null) continue;
    decls.add(
      _decl(
        kind: 'field',
        name: nameToken.lexeme,
        parent: ownerName,
        line: _lineOf(lineInfo, nameToken.offset),
        offset: param.offset,
        end: param.end,
        metadata: const [],
        content: content,
        signatureTypes: _signatureTypes(fieldType: param.type),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Construção de um registro de declaração + metadados de anotação
// --------------------------------------------------------------------------

Map<String, dynamic> _decl({
  required String kind,
  required String name,
  required String? parent,
  required int line,
  required int offset,
  required int end,
  required Iterable<Annotation> metadata,
  required String content,
  List<String> supertypes = const [],
  Map<String, dynamic>? returnType,
  List<String> signatureTypes = const [],
  String? typedefTarget,
}) {
  var deprecated = false;
  var deprecationMessage = '';
  final annotations = <Map<String, dynamic>>[];
  for (final annotation in metadata) {
    final annotationName = content.substring(
      annotation.name.offset,
      annotation.name.end,
    );
    annotations.add({
      'name': annotationName,
      'offset': annotation.offset,
      'end': annotation.end,
    });
    if (annotationName == 'Deprecated' || annotationName == 'deprecated') {
      deprecated = true;
      final args = annotation.arguments?.arguments;
      if (args != null && args.isNotEmpty) {
        final first = args.first;
        final literalValue = first is StringLiteral ? first.stringValue : null;
        deprecationMessage =
            literalValue ?? content.substring(first.offset, first.end);
      }
    }
  }

  final map = <String, dynamic>{
    'kind': kind,
    'name': name,
    'parent': parent,
    'line': line,
    'offset': offset,
    'end': end,
    'deprecated': deprecated,
    'deprecationMessage': deprecationMessage,
    'annotations': annotations,
    'supertypes': supertypes,
    'returnType': returnType,
    'signatureTypes': signatureTypes,
  };
  if (typedefTarget != null) map['typedefTarget'] = typedefTarget;
  return map;
}

String? _typeAnnotationName(TypeAnnotation? type, String content) {
  if (type == null) return null;
  if (type is NamedType) return type.name.lexeme;
  return content.substring(type.offset, type.end);
}

Map<String, dynamic>? _returnTypeJson(
  TypeAnnotation? returnType,
  String content,
) {
  if (returnType == null) return null;
  return {
    'text': content.substring(returnType.offset, returnType.end),
    'isRecord': returnType is RecordTypeAnnotation,
    'names': _namedTypeNames(returnType),
  };
}

/// Todo NamedType alcançável dentro de [node], recursivamente, na ordem em
/// que aparecem no código-fonte (record fields, argumentos de tipo, tipos de
/// função aninhados — tudo que o parser produzir abaixo de [node]).
List<String> _namedTypeNames(AstNode? node) {
  if (node == null) return const [];
  final collector = _NamedTypeCollector();
  node.accept(collector);
  return collector.names;
}

class _NamedTypeCollector extends RecursiveAstVisitor<void> {
  final List<String> names = [];

  @override
  void visitNamedType(NamedType node) {
    names.add(node.name.lexeme);
    super.visitNamedType(node);
  }
}

/// NamedTypes de tipo de retorno, tipo de campo/variável, tipos de parâmetro
/// (incluindo o retorno de parâmetros function-typed e a assinatura de um
/// nível de aninhamento do seu próprio parâmetro) e bounds de type
/// parameters — usado para achar membros públicos que expõem tipos `_Priv`.
List<String> _signatureTypes({
  TypeAnnotation? returnType,
  TypeAnnotation? fieldType,
  List<FormalParameter> parameters = const [],
  TypeParameterList? typeParameters,
}) {
  final names = <String>[];
  void add(AstNode? node) {
    if (node != null) names.addAll(_namedTypeNames(node));
  }

  add(returnType);
  add(fieldType);
  for (final param in parameters) {
    add(param.type);
    final suffix = param.functionTypedSuffix;
    if (suffix != null) {
      for (final inner in suffix.formalParameters.parameters) {
        add(inner.type);
      }
    }
  }
  if (typeParameters != null) {
    for (final tp in typeParameters.typeParameters) {
      add(tp.bound);
    }
  }
  return names;
}

// --------------------------------------------------------------------------
// Visitor único para o arquivo inteiro: declaredIdentifiers, invocations de
// print/exit, assignments em exitCode e literais hex em `&`. Roda sobre toda
// a árvore (inclusive corpos de função), então também vê nomes locais que a
// passagem estrutural de declarações (acima) nunca visita.
// --------------------------------------------------------------------------

class _MainVisitor extends RecursiveAstVisitor<void> {
  _MainVisitor(this._lineInfo);

  final LineInfo _lineInfo;

  final Set<String> declaredIdentifiers = {};
  final List<Map<String, dynamic>> invocations = [];
  final List<Map<String, dynamic>> assignments = [];
  final List<Map<String, dynamic>> bitwiseAndHexLiterals = [];

  int _line(int offset) => _lineOf(_lineInfo, offset);

  // -- declaredIdentifiers --------------------------------------------

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    declaredIdentifiers.add(node.name.lexeme);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    declaredIdentifiers.add(node.name.lexeme);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    declaredIdentifiers.add(node.name.lexeme);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final nameToken = node.name;
    if (nameToken != null) declaredIdentifiers.add(nameToken.lexeme);
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitRegularFormalParameter(RegularFormalParameter node) {
    final nameToken = node.name;
    if (nameToken != null) declaredIdentifiers.add(nameToken.lexeme);
    super.visitRegularFormalParameter(node);
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    // Ao contrário de RegularFormalParameter, aqui `name` nunca é nulo.
    declaredIdentifiers.add(node.name.lexeme);
    super.visitFieldFormalParameter(node);
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    declaredIdentifiers.add(node.name.lexeme);
    super.visitSuperFormalParameter(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    declaredIdentifiers.add(node.name.lexeme);
    super.visitDeclaredIdentifier(node);
  }

  @override
  void visitCatchClauseParameter(CatchClauseParameter node) {
    declaredIdentifiers.add(node.name.lexeme);
    super.visitCatchClauseParameter(node);
  }

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    declaredIdentifiers.add(node.name.lexeme);
    super.visitDeclaredVariablePattern(node);
  }

  // -- invocations (print/exit) ---------------------------------------

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && !node.isCascaded) {
      final name = node.methodName.name;
      if (name == 'print' || name == 'exit') {
        invocations.add({'name': name, 'line': _line(node.offset)});
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final function = node.function;
    if (function is SimpleIdentifier &&
        (function.name == 'print' || function.name == 'exit')) {
      invocations.add({'name': function.name, 'line': _line(node.offset)});
    }
    super.visitFunctionExpressionInvocation(node);
  }

  // -- assignments a exitCode ------------------------------------------

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final lhs = node.leftHandSide;
    final targetsExitCode = switch (lhs) {
      SimpleIdentifier(name: 'exitCode') => true,
      PrefixedIdentifier(identifier: SimpleIdentifier(name: 'exitCode')) =>
        true,
      PropertyAccess(propertyName: SimpleIdentifier(name: 'exitCode')) => true,
      _ => false,
    };
    if (targetsExitCode) {
      assignments.add({'target': 'exitCode', 'line': _line(node.offset)});
    }
    super.visitAssignmentExpression(node);
  }

  // -- `&` com literal hexadecimal --------------------------------------

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.operator.lexeme == '&') {
      final left = node.leftOperand;
      final right = node.rightOperand;
      String? hexLexeme;
      if (left is IntegerLiteral && _isHexLexeme(left.literal.lexeme)) {
        hexLexeme = left.literal.lexeme;
      } else if (right is IntegerLiteral &&
          _isHexLexeme(right.literal.lexeme)) {
        hexLexeme = right.literal.lexeme;
      }
      if (hexLexeme != null) {
        bitwiseAndHexLiterals.add({
          'lexeme': hexLexeme,
          'line': _line(node.offset),
        });
      }
    }
    super.visitBinaryExpression(node);
  }
}

bool _isHexLexeme(String lexeme) =>
    lexeme.startsWith('0x') || lexeme.startsWith('0X');

// --------------------------------------------------------------------------
// Chamadas de teste (group/test), só para arquivos sob test/.
// --------------------------------------------------------------------------

class _TestCallCollector extends RecursiveAstVisitor<void> {
  _TestCallCollector(this._content, this._lineInfo);

  final String _content;
  final LineInfo _lineInfo;
  final List<String?> _groupStack = [];
  final List<Map<String, dynamic>> calls = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final isGroupOrTest =
        node.target == null &&
        !node.isCascaded &&
        (node.methodName.name == 'group' || node.methodName.name == 'test');
    if (!isGroupOrTest) {
      super.visitMethodInvocation(node);
      return;
    }

    final kind = node.methodName.name;
    final positional = _positionalArgs(node.argumentList);
    final name = positional.isNotEmpty
        ? _stringLiteralValue(positional.first)
        : null;

    final call = <String, dynamic>{
      'kind': kind,
      'name': name,
      'groups': List<String?>.from(_groupStack),
      'line': _lineOf(_lineInfo, node.offset),
    };

    if (kind == 'test') {
      FunctionBody? body;
      if (positional.length > 1 && positional[1] is FunctionExpression) {
        body = (positional[1] as FunctionExpression).body;
      }
      call['body'] = body == null
          ? null
          : _bodyFacts(body, _content, _lineInfo);
      calls.add(call);
      super.visitMethodInvocation(node);
      return;
    }

    // kind == 'group': empilha o nome enquanto os filhos são percorridos,
    // para que testes/grupos aninhados vejam o grupo corrente.
    calls.add(call);
    _groupStack.add(name);
    super.visitMethodInvocation(node);
    _groupStack.removeLast();
  }
}

// Todo argumento posicional É um Expression (ExpressionImpl mistura
// ArgumentImpl); só NamedArgument não implementa Expression — então filtrar
// por tipo já exclui os argumentos nomeados sem precisar do nome antigo
// (NamedExpression) desta API.
List<Expression> _positionalArgs(ArgumentList args) =>
    args.arguments.whereType<Expression>().toList();

String? _stringLiteralValue(Expression e) =>
    e is StringLiteral ? e.stringValue : null;

Map<String, dynamic> _bodyFacts(
  FunctionBody body,
  String content,
  LineInfo lineInfo,
) {
  var empty = false;
  var onlyFail = false;
  if (body is BlockFunctionBody) {
    final statements = body.block.statements;
    empty = statements.isEmpty;
    if (statements.length == 1) {
      final statement = statements.first;
      if (statement is ExpressionStatement) {
        final expr = statement.expression;
        if (expr is MethodInvocation &&
            expr.target == null &&
            expr.methodName.name == 'fail') {
          onlyFail = true;
        }
      }
    }
  }

  final collector = _BodyDetailCollector(content);
  body.accept(collector);

  return {
    'empty': empty,
    'onlyFail': onlyFail,
    'throwsA': collector.throwsAFound,
    'assertions': collector.assertions,
    'constructedIdentifiers': collector.constructedIdentifiers,
  };
}

class _BodyDetailCollector extends RecursiveAstVisitor<void> {
  _BodyDetailCollector(this._content);

  final String _content;

  bool throwsAFound = false;
  final List<Map<String, dynamic>> assertions = [];
  final List<String> constructedIdentifiers = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'throwsA') throwsAFound = true;
    if (node.target == null &&
        (node.methodName.name == 'expect' ||
            node.methodName.name == 'expectLater')) {
      final args = _positionalArgs(node.argumentList);
      final actual = args.isNotEmpty ? args[0] : null;
      final matcher = args.length > 1 ? args[1] : null;
      assertions.add({
        'callee': node.methodName.name,
        'actualKind': _actualKind(actual),
        'actual': actual == null
            ? ''
            : _content.substring(actual.offset, actual.end),
        'matcher': matcher == null
            ? ''
            : _collapseWhitespace(
                _content.substring(matcher.offset, matcher.end),
              ),
      });
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssertStatement(AssertStatement node) {
    assertions.add({
      'callee': 'assert',
      'actualKind': _actualKind(node.condition),
      'actual': _content.substring(node.condition.offset, node.condition.end),
      'matcher': '',
    });
    super.visitAssertStatement(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer; // (não initializer2, @experimental)
    if (initializer != null && _looksConstructed(initializer)) {
      constructedIdentifiers.add(node.name.lexeme);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final lhs = node.leftHandSide;
    if (node.operator.lexeme == '=' &&
        lhs is SimpleIdentifier &&
        _looksConstructed(node.rightHandSide)) {
      constructedIdentifiers.add(lhs.name);
    }
    super.visitAssignmentExpression(node);
  }
}

String _actualKind(Expression? e) {
  if (e == null) return 'none';
  if (e is BooleanLiteral ||
      e is NullLiteral ||
      e is IntegerLiteral ||
      e is DoubleLiteral ||
      e is SimpleStringLiteral) {
    return 'literal';
  }
  if (e is PrefixExpression &&
      e.operator.lexeme == '-' &&
      (e.operand is IntegerLiteral || e.operand is DoubleLiteral)) {
    return 'literal';
  }
  if (e is SimpleIdentifier) return 'identifier';
  return 'other';
}

/// `InstanceCreationExpression`/`ConstructorInvocation` (o `new Foo()` desta
/// versão do analyzer usa o segundo nó, não o primeiro — ver comentário no
/// relatório final) ou uma chamada cujo texto do callee comece com letra
/// maiúscula (`Foo(...)`, `pkg.Foo(...)`, `Foo.bar(...)`).
bool _looksConstructed(Expression e) {
  // ConstructorInvocation é o nó real que esta versão do analyzer produz
  // para `new Foo()`/`const Foo()`; InstanceCreationExpression (API v1) é
  // mantido no teste por segurança.
  // ignore: experimental_member_use
  if (e is InstanceCreationExpression || e is ConstructorInvocation)
    return true;
  if (e is MethodInvocation) {
    if (_isUpperStart(e.methodName.name)) return true;
    final target = e.target;
    if (target is SimpleIdentifier && _isUpperStart(target.name)) return true;
    if (target is PrefixedIdentifier && _isUpperStart(target.identifier.name)) {
      return true;
    }
    return false;
  }
  if (e is FunctionExpressionInvocation) {
    final function = e.function;
    if (function is SimpleIdentifier && _isUpperStart(function.name))
      return true;
    if (function is PrefixedIdentifier &&
        _isUpperStart(function.identifier.name)) {
      return true;
    }
  }
  return false;
}

bool _isUpperStart(String s) {
  if (s.isEmpty) return false;
  final first = s[0];
  return first != first.toLowerCase() && first == first.toUpperCase();
}

String _collapseWhitespace(String s) {
  final buffer = StringBuffer();
  var lastWasSpace = false;
  for (final codeUnit in s.codeUnits) {
    final isSpace =
        codeUnit == 0x20 ||
        codeUnit == 0x09 ||
        codeUnit == 0x0A ||
        codeUnit == 0x0D;
    if (isSpace) {
      if (!lastWasSpace) buffer.writeCharCode(0x20);
      lastWasSpace = true;
    } else {
      buffer.writeCharCode(codeUnit);
      lastWasSpace = false;
    }
  }
  return buffer.toString().trim();
}
