part of '../../fmt.dart';

/// Entradas do map na ordem do `internal/fmtsort` (estável nos empates).
List<MapEntry<Object?, Object?>> _sortedEntries(GoMap m) {
  final all = m.entries.toList();
  final order = List.generate(all.length, (i) => i)
    ..sort((x, y) {
      final c = m.identity ? 0 : _compareKeys(all[x].key, all[y].key);
      return c != 0 ? c : x - y;
    });
  return [for (final i in order) all[i]];
}

/// `%#v`: sintaxe Go do valor (`printValue` com `sharpV` do Go) para nil,
/// ponteiros, structs, slices, arrays e maps. Devolve false para o que o
/// `printArg` comum já trata igual (bool, inteiros, floats, strings,
/// complexos).
///
/// O valor Dart de slice/map/array sem nome e dos campos não diz o tipo Go:
/// `name` é o nome Go do tipo do lugar onde o valor está (o operando
/// embrulhado em [TypeTag], ou `$fieldTypes` da struct, ou o elemento do
/// nome do pai) e `under` o nome do subjacente de um tipo nomeado. Sem nome
/// onde ele faz falta, lança [UnimplementedError] (nunca imprime outro tipo).
/// Ponteiro não nil aninhado imprime o endereço no Go (não reproduzível):
/// também lança.
extension _SharpV on _Printer {
  bool _printSharp(Object arg, int depth, String? name, String? under) {
    switch (arg) {
      case PtrView(:final $p) when $p is NilPtr:
        _b.add(utf8.encode('(${arg.$goType})(nil)'));
      case GoValue v when v.$nilPtr:
        _b.add(utf8.encode('(${_Printer._typeName(v)})(nil)'));
      case NilPtr():
        _sharpNil(name);
      case Addr(target: null):
        _sharpNil(name);
      case Addr(:final target) when depth == 0 && target is GoStruct:
        _b.addByte(0x26);
        _sharpStruct(target, depth);
      case Addr() || Ptr() || Function():
        throw UnimplementedError('fmt: %#v de ponteiro/func (endereço)');
      case GoStruct s:
        if (depth == 0 && !s.$isValue) {
          _b.addByte(0x26); // &T{...}
        } else if (!s.$isValue && name != s.$goType) {
          // Ponteiro aninhado (ou campo de interface): o Go imprime o endereço.
          throw UnimplementedError('fmt: %#v de ponteiro aninhado (endereço)');
        }
        _sharpStruct(s, depth);
      case Slice s:
        final (tn, base) = _sharpName(s, name, under);
        if (depth == 0 && s is Slice<Golang.Uint8> && tn == '[]uint8') {
          _b.add(utf8.encode('[]byte'));
          if (s.isNil) {
            _b.add(_ascii('(nil)'));
          } else {
            _b.addByte(0x7b);
            var first = true;
            for (final x in s.items) {
              if (!first) _b.add(_ascii(', '));
              first = false;
              _b.add(_ascii('0x${x.toInt().toRadixString(16)}'));
            }
            _b.addByte(0x7d);
          }
        } else {
          _sharpList(s.items, tn, _sharpElem(base), depth, nil: s.isNil);
        }
      case GoArray a:
        final (tn, base) = _sharpName(a, name, under);
        _sharpList(a.items, tn, _sharpElem(base), depth);
      case GoMap m:
        final (tn, base) = _sharpName(m, name, under);
        _b.add(utf8.encode(tn));
        if (m.isNil) {
          _b.add(_ascii('(nil)'));
        } else {
          final (kn, vn) = _sharpMapNames(base);
          _b.addByte(0x7b);
          final entries = _sortedEntries(m);
          for (var i = 0; i < entries.length; i++) {
            if (i > 0) _b.add(_ascii(', '));
            _printArg(entries[i].key, 0x76, depth + 1, kn);
            _b.addByte(0x3a);
            _printArg(entries[i].value, 0x76, depth + 1, vn);
          }
          _b.addByte(0x7d);
        }
      default:
        return false;
    }
    return true;
  }

  /// nil de interface, ponteiro, func ou chan: `error(nil)`, `(*main.P)(nil)`.
  void _sharpNil(String? name) {
    if (name == null) {
      throw UnimplementedError('fmt: %#v de nil sem o nome do tipo');
    }
    final paren =
        name.startsWith('*') ||
        name.startsWith('func') ||
        name.startsWith('chan');
    _b.add(utf8.encode(paren ? '($name)(nil)' : '$name(nil)'));
  }

  void _sharpStruct(GoStruct s, int depth) {
    _b.add(utf8.encode(s.$goType));
    _b.addByte(0x7b);
    final fields = s.$fields;
    final names = s.$fieldNames;
    final types = s.$fieldTypes;
    for (var i = 0; i < fields.length; i++) {
      if (i > 0) _b.add(_ascii(', '));
      _b.add(utf8.encode(names[i]));
      _b.addByte(0x3a);
      _printArg(
        fields[i],
        0x76,
        depth + 1,
        types.length == fields.length ? types[i] : null,
      );
    }
    _b.addByte(0x7d);
  }

  void _sharpList(
    Iterable<Object?> items,
    String tn,
    String? elem,
    int depth, {
    bool nil = false,
  }) {
    _b.add(utf8.encode(tn));
    if (nil) {
      _b.add(_ascii('(nil)'));
      return;
    }
    _b.addByte(0x7b);
    var first = true;
    for (final e in items) {
      if (!first) _b.add(_ascii(', '));
      first = false;
      _printArg(e, 0x76, depth + 1, elem);
    }
    _b.addByte(0x7d);
  }

  /// (nome do tipo, nome do subjacente de onde saem os dos elementos).
  (String, String?) _sharpName(Object v, String? name, String? under) {
    if (under != null && name != null) return (name, under);
    final named = v is Golang.GoTyped && !(v is GoArray && v.$goType[0] == '[');
    if (named) return (v.$goType, null);
    final structural =
        name != null &&
        switch (v) {
          Slice() => name.startsWith('[]'),
          GoArray() => name.startsWith('[') && !name.startsWith('[]'),
          _ => name.startsWith('map['),
        };
    if (structural) return (name, name);
    final inferred = _sharpInfer(v);
    if (inferred != null) return (inferred, inferred);
    throw UnimplementedError('fmt: %#v sem o nome do tipo de ${v.runtimeType}');
  }

  /// Nome do tipo de um slice/array sem nome dentro de uma interface (sem
  /// [TypeTag]): o do elemento, pelo zero value do descritor. Elemento
  /// ponteiro/interface (zero nil) e maps não têm como: null.
  String? _sharpInfer(Object? v) {
    switch (v) {
      case Slice():
        final e = _sharpInferElem(v.elem.zero());
        return e == null ? null : '[]$e';
      case GoArray():
        final e = _sharpInferElem(v.elem.zero());
        return e == null ? null : '[${v.length}]$e';
      default:
        return null;
    }
  }

  String? _sharpInferElem(Object? x) => switch (x) {
    null => null,
    Golang.GoTyped t when !(t is GoArray && t.$goType[0] == '[') => t.$goType,
    Slice() || GoArray() => _sharpInfer(x),
    _ => null,
  };

  /// `[]X` e `[N]X` → X.
  String? _sharpElem(String? t) {
    if (t == null || !t.startsWith('[')) return null;
    return t.substring(t.indexOf(']') + 1);
  }

  /// `map[K]V` → (K, V), com colchetes aninhados em K.
  (String?, String?) _sharpMapNames(String? t) {
    if (t == null || !t.startsWith('map[')) return (null, null);
    var depth = 0;
    for (var i = 3; i < t.length; i++) {
      if (t[i] == '[') depth++;
      if (t[i] == ']' && --depth == 0) {
        return (t.substring(4, i), t.substring(i + 1));
      }
    }
    return (null, null);
  }
}
