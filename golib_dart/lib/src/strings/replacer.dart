part of '../../strings.dart';

/// Nó de uma trie de busca por prioridade (porta de `trieNode` em
/// `strings/replace.go`, só o algoritmo genérico do Go: correto para
/// qualquer entrada, sem as otimizações de par único/byte-a-byte que o Go
/// escolhe conforme os argumentos).
class _TrieNode {
  Golang.String value = Golang.String();
  int priority = 0;
  Golang.String prefix = Golang.String();
  _TrieNode? next;
  List<_TrieNode?>? table;

  void add(
    Golang.String key,
    Golang.String val,
    int priority,
    _GenericReplacer r,
  ) {
    if (key.length == 0) {
      if (this.priority == 0) {
        value = val;
        this.priority = priority;
      }
      return;
    }
    if (prefix.length != 0) {
      var n = 0;
      while (n < prefix.length && n < key.length && prefix[n] == key[n]) {
        n++;
      }
      if (n == prefix.length) {
        next!.add(key.slice(n), val, priority, r);
      } else if (n == 0) {
        final _TrieNode prefixNode;
        if (prefix.length == 1) {
          prefixNode = next!;
        } else {
          prefixNode = _TrieNode()
            ..prefix = prefix.slice(1)
            ..next = next;
        }
        final keyNode = _TrieNode();
        table = List<_TrieNode?>.filled(r.tableSize, null);
        table![r.mapping[prefix[0]]] = prefixNode;
        table![r.mapping[key[0]]] = keyNode;
        prefix = Golang.String();
        next = null;
        keyNode.add(key.slice(1), val, priority, r);
      } else {
        final nextNode = _TrieNode()
          ..prefix = prefix.slice(n)
          ..next = next;
        prefix = prefix.slice(0, n);
        next = nextNode;
        nextNode.add(key.slice(n), val, priority, r);
      }
    } else if (table != null) {
      final m = r.mapping[key[0]];
      table![m] ??= _TrieNode();
      table![m]!.add(key.slice(1), val, priority, r);
    } else {
      prefix = key;
      next = _TrieNode()..add(Golang.String(), val, priority, r);
    }
  }
}

/// Porta de `genericReplacer` (`strings/replace.go`): a única implementação
/// que este shim usa, mesmo quando o Go escolheria `byteReplacer` ou
/// `singleStringReplacer` — resultado idêntico, só sem a otimização.
class _GenericReplacer {
  final _TrieNode root = _TrieNode();
  int tableSize = 0;
  final List<int> mapping = List<int>.filled(256, 0);

  _GenericReplacer(List<Golang.String> oldnew) {
    for (var i = 0; i < oldnew.length; i += 2) {
      final key = oldnew[i];
      for (var j = 0; j < key.length; j++) {
        mapping[key[j]] = 1;
      }
    }
    for (final b in mapping) {
      tableSize += b;
    }
    var idx = 0;
    for (var i = 0; i < 256; i++) {
      if (mapping[i] == 0) {
        mapping[i] = tableSize;
      } else {
        mapping[i] = idx;
        idx++;
      }
    }
    root.table = List<_TrieNode?>.filled(tableSize, null);
    for (var i = 0; i < oldnew.length; i += 2) {
      root.add(oldnew[i], oldnew[i + 1], oldnew.length - i, this);
    }
  }

  (Golang.String, int, bool) lookup(Golang.String s, bool ignoreRoot) {
    var bestPriority = 0;
    var val = Golang.String();
    var keylen = 0;
    var found = false;
    _TrieNode? node = root;
    var n = 0;
    while (node != null) {
      if (node.priority > bestPriority &&
          !(ignoreRoot && identical(node, root))) {
        bestPriority = node.priority;
        val = node.value;
        keylen = n;
        found = true;
      }
      if (s.length == 0) break;
      if (node.table != null) {
        final index = mapping[s[0]];
        if (index == tableSize) break;
        node = node.table![index];
        s = s.slice(1);
        n++;
      } else if (node.prefix.length != 0 && hasPrefix(s, node.prefix)) {
        n += node.prefix.length;
        s = s.slice(node.prefix.length);
        node = node.next;
      } else {
        break;
      }
    }
    return (val, keylen, found);
  }

  /// `WriteString(w, s)`.
  (Golang.Int, GoError?) writeString(io.Writer w, Golang.String s) {
    var n = 0, last = 0, i = 0;
    var prevMatchEmpty = false;
    while (i <= s.length) {
      final (val, keylen, match) = lookup(s.slice(i), prevMatchEmpty);
      prevMatchEmpty = match && keylen == 0;
      if (match) {
        var (wn, err) = io.writeString(w, s.slice(last, i));
        n += wn.toInt();
        if (err != null) return (Golang.Int(n), err);
        (wn, err) = io.writeString(w, val);
        n += wn.toInt();
        if (err != null) return (Golang.Int(n), err);
        i += keylen;
        last = i;
        continue;
      }
      i++;
    }
    if (last != s.length) {
      final (wn, err) = io.writeString(w, s.slice(last));
      n += wn.toInt();
      if (err != null) return (Golang.Int(n), err);
    }
    return (Golang.Int(n), null);
  }

  /// `Replace(s)`.
  Golang.String replace(Golang.String s) {
    final buf = Builder();
    writeString(buf, s);
    return buf.string();
  }
}

/// `strings.Replacer`: struct de shim usada por ponteiro (`*Replacer`, do
/// `NewReplacer`). O zero value (`var r Replacer`) é um replacer sem pares
/// — não faz nada, como no Go (`build()` do Go cai no `byteReplacer`
/// identidade; aqui é o `_GenericReplacer` vazio, mesmo resultado). Não é
/// comparável no Go de verdade (`oldnew []string`), então `$fields` nunca é
/// exercitado por `==`.
final class Replacer extends GoStruct<Replacer> {
  Replacer();

  /// `(*Replacer)(nil)` dentro de uma interface.
  static final Replacer $nil = Replacer()..$nilPtr = true;

  _GenericReplacer _r = _GenericReplacer(const []);

  @override
  String get $goType => 'strings.Replacer';

  @override
  List<String> get $ptrMethods => const ['Replace', 'WriteString'];

  @override
  Replacer $copy() => Replacer().._r = _r;

  @override
  void $set(Replacer o) {
    _r = o._r;
  }

  @override
  List<Object?> get $fields => [_r];

  @override
  List<String> get $fieldNames => const ['r'];

  /// `Replace(s)`.
  Golang.String replace(Golang.String s) => _r.replace(s);

  /// `WriteString(w, s)`.
  (Golang.Int, GoError?) writeString(io.Writer? w, Golang.String s) =>
      _r.writeString(w!, s);
}

/// `strings.NewReplacer(oldnew...)`: pânico com número ímpar de argumentos.
Replacer? newReplacer(Slice<Golang.String> oldnew) {
  if (oldnew.length % 2 == 1) {
    throw Panic(
      Golang.String.fromDart('strings.NewReplacer: odd argument count'),
    );
  }
  return Replacer().._r = _GenericReplacer([for (final s in oldnew.items) s]);
}
