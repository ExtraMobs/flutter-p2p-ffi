part of '../../io.dart';

// Porta de `io/multi.go`, com as duas formas (D2) de cada método.

final class _EofReader with ReaderSync implements Reader, Golang.GoTyped {
  const _EofReader();

  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p) => (Golang.Int(0), eof);

  @override
  String get $goType => 'io.eofReader';

  @override
  List<String> get $methods => const ['Read'];
}

const _eofReader = _EofReader();

/// `io.MultiReader(readers...)`: concatenação lógica, lidas em sequência.
Reader multiReader(Slice<Reader?> readers) =>
    _MultiReader(readers.items.toList());

final class _MultiReader implements Reader, WriterTo, Golang.GoTyped {
  _MultiReader(this._readers);

  List<Reader?> _readers;

  /// Achata um multiReader aninhado sozinho na lista (Issue 13558 do Go);
  /// true se achatou (o laço recomeça).
  bool _flatten() {
    if (_readers.length == 1 && _readers[0] is _MultiReader) {
      _readers = (_readers[0]! as _MultiReader)._readers;
      return true;
    }
    return false;
  }

  /// Conta a leitura do primeiro leitor; o resultado do `Read`, ou null
  /// para tentar o próximo.
  (Golang.Int, GoError?)? _step(Golang.Int n, GoError? err) {
    if (identical(err, eof)) {
      _readers[0] = _eofReader; // GC mais cedo (Issue 18232 do Go)
      _readers = _readers.sublist(1);
    }
    if (n.toInt() > 0 || !identical(err, eof)) {
      if (identical(err, eof) && _readers.isNotEmpty) err = null;
      return (n, err);
    }
    return null;
  }

  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p) {
    while (_readers.isNotEmpty) {
      if (_flatten()) continue;
      final (n, err) = _readers[0]!.read(p);
      final out = _step(n, err);
      if (out != null) return out;
    }
    return (Golang.Int(0), eof);
  }

  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> p) async {
    while (_readers.isNotEmpty) {
      if (_flatten()) continue;
      final (n, err) = await _readers[0]!.read$async(p);
      final out = _step(n, err);
      if (out != null) return out;
    }
    return (Golang.Int(0), eof);
  }

  static Slice<Golang.Uint8> _buf() =>
      Slice<Golang.Uint8>.make(1024 * 32, 1024 * 32, _byte);

  @override
  (Golang.Int64, GoError?) writeTo(Writer? w) => _writeToWithBuffer(w, _buf());

  @override
  Future<(Golang.Int64, GoError?)> writeTo$async(Writer? w) =>
      _writeToWithBuffer$async(w, _buf());

  (Golang.Int64, GoError?) _writeToWithBuffer(
    Writer? w,
    Slice<Golang.Uint8> buf,
  ) {
    var sum = 0;
    for (var i = 0; i < _readers.length; i++) {
      final r = _readers[i];
      final (Golang.Int64 n, GoError? err) = r is _MultiReader
          ? r._writeToWithBuffer(w, buf)
          : _copyBuffer(w, r, buf);
      sum += n.toInt();
      if (err != null) {
        _readers = _readers.sublist(i);
        return (Golang.Int64(sum), err);
      }
      _readers[i] = null; // GC mais cedo
    }
    _readers = [];
    return (Golang.Int64(sum), null);
  }

  Future<(Golang.Int64, GoError?)> _writeToWithBuffer$async(
    Writer? w,
    Slice<Golang.Uint8> buf,
  ) async {
    var sum = 0;
    for (var i = 0; i < _readers.length; i++) {
      final r = _readers[i];
      final (Golang.Int64 n, GoError? err) = r is _MultiReader
          ? await r._writeToWithBuffer$async(w, buf)
          : await _copyBuffer$async(w, r, buf);
      sum += n.toInt();
      if (err != null) {
        _readers = _readers.sublist(i);
        return (Golang.Int64(sum), err);
      }
      _readers[i] = null; // GC mais cedo
    }
    _readers = [];
    return (Golang.Int64(sum), null);
  }

  @override
  String get $goType => 'io.multiReader';

  @override
  List<String> get $methods => const ['Read', 'WriteTo'];
}

/// `io.MultiWriter(writers...)`: cada escrita vai para todos, na ordem.
Writer multiWriter(Slice<Writer?> writers) {
  final all = <Writer?>[];
  for (final w in writers.items) {
    if (w is _MultiWriter) {
      all.addAll(w._writers);
    } else {
      all.add(w);
    }
  }
  return _MultiWriter(all);
}

final class _MultiWriter implements Writer, StringWriter, Golang.GoTyped {
  _MultiWriter(this._writers);

  final List<Writer?> _writers;

  /// O resultado de uma escrita num dos writers; null se todos seguem.
  static (Golang.Int, GoError?)? _check(Golang.Int n, GoError? err, int len) {
    if (err != null) return (n, err);
    if (n.toInt() != len) return (n, errShortWrite);
    return null;
  }

  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> p) {
    for (final w in _writers) {
      final (n, err) = w!.write(p);
      if (_check(n, err, p.length) case final out?) return out;
    }
    return (Golang.Int(p.length), null);
  }

  @override
  Future<(Golang.Int, GoError?)> write$async(Slice<Golang.Uint8> p) async {
    for (final w in _writers) {
      final (n, err) = await w!.write$async(p);
      if (_check(n, err, p.length) case final out?) return out;
    }
    return (Golang.Int(p.length), null);
  }

  @override
  (Golang.Int, GoError?) writeString(Golang.String s) {
    Slice<Golang.Uint8>? p;
    for (final w in _writers) {
      final Object? o = w;
      final Golang.Int n;
      final GoError? err;
      if (o case final StringWriter sw when goHasMethod(sw, 'WriteString')) {
        (n, err) = sw.writeString(s);
      } else {
        p ??= bytesOf(s, _byte);
        (n, err) = w!.write(p);
      }
      if (_check(n, err, s.length) case final out?) return out;
    }
    return (Golang.Int(s.length), null);
  }

  @override
  Future<(Golang.Int, GoError?)> writeString$async(Golang.String s) async {
    Slice<Golang.Uint8>? p;
    for (final w in _writers) {
      final Object? o = w;
      final Golang.Int n;
      final GoError? err;
      if (o case final StringWriter sw when goHasMethod(sw, 'WriteString')) {
        (n, err) = await sw.writeString$async(s);
      } else {
        p ??= bytesOf(s, _byte);
        (n, err) = await w!.write$async(p);
      }
      if (_check(n, err, s.length) case final out?) return out;
    }
    return (Golang.Int(s.length), null);
  }

  @override
  String get $goType => 'io.multiWriter';

  @override
  List<String> get $methods => const ['Write', 'WriteString'];
}
