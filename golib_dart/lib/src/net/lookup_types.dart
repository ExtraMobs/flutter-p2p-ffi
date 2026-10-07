part of '../../net.dart';

// Registros que o `Resolver` devolve (`dnsclient.go`): `SRV`, `MX` e `NS`,
// e a ordem do Go para eles (RFC 2782 e RFC 5321).

/// `net.SRV`.
final class SRV extends GoStruct<SRV> {
  SRV({
    Golang.String? target,
    Golang.Uint16? port,
    Golang.Uint16? priority,
    Golang.Uint16? weight,
  }) : target = target ?? Golang.String(),
       port = port ?? Golang.Uint16(0),
       priority = priority ?? Golang.Uint16(0),
       weight = weight ?? Golang.Uint16(0);

  /// `(*SRV)(nil)` dentro de uma interface.
  static final SRV $nil = SRV()..$nilPtr = true;

  Golang.String target;
  Golang.Uint16 port;
  Golang.Uint16 priority;
  Golang.Uint16 weight;

  @override
  String get $goType => 'net.SRV';
  @override
  SRV $copy() =>
      SRV(target: target, port: port, priority: priority, weight: weight);
  @override
  void $set(SRV o) {
    target = o.target;
    port = o.port;
    priority = o.priority;
    weight = o.weight;
  }

  @override
  List<Object?> get $fields => [target, port, priority, weight];
  @override
  List<String> get $fieldNames => const [
    'Target',
    'Port',
    'Priority',
    'Weight',
  ];
  @override
  List<String> get $fieldTypes => const [
    'string',
    'uint16',
    'uint16',
    'uint16',
  ];
}

/// `net.MX`.
final class MX extends GoStruct<MX> {
  MX({Golang.String? host, Golang.Uint16? pref})
    : host = host ?? Golang.String(),
      pref = pref ?? Golang.Uint16(0);

  /// `(*MX)(nil)` dentro de uma interface.
  static final MX $nil = MX()..$nilPtr = true;

  Golang.String host;
  Golang.Uint16 pref;

  @override
  String get $goType => 'net.MX';
  @override
  MX $copy() => MX(host: host, pref: pref);
  @override
  void $set(MX o) {
    host = o.host;
    pref = o.pref;
  }

  @override
  List<Object?> get $fields => [host, pref];
  @override
  List<String> get $fieldNames => const ['Host', 'Pref'];
  @override
  List<String> get $fieldTypes => const ['string', 'uint16'];
}

/// `net.NS`.
final class NS extends GoStruct<NS> {
  NS({Golang.String? host}) : host = host ?? Golang.String();

  /// `(*NS)(nil)` dentro de uma interface.
  static final NS $nil = NS()..$nilPtr = true;

  Golang.String host;

  @override
  String get $goType => 'net.NS';
  @override
  NS $copy() => NS(host: host);
  @override
  void $set(NS o) => host = o.host;

  @override
  List<Object?> get $fields => [host];
  @override
  List<String> get $fieldNames => const ['Host'];
  @override
  List<String> get $fieldTypes => const ['string'];
}

const _srvElem = Elem<SRV?>(8, zeroNull, pointers: true);
const _mxElem = Elem<MX?>(8, zeroNull, pointers: true);
const _nsElem = Elem<NS?>(8, zeroNull, pointers: true);

/// `byPriorityWeight.sort()`: prioridade crescente e, dentro de cada
/// prioridade, embaralhado pelo peso (RFC 2782).
void _sortSRV(List<SRV> addrs) {
  _sortStable(addrs, (a, b) {
    final r = a.priority.toInt().compareTo(b.priority.toInt());
    return r != 0 ? r : a.weight.toInt().compareTo(b.weight.toInt());
  });
  var i = 0;
  for (var j = 1; j < addrs.length; j++) {
    if (addrs[i].priority.toInt() != addrs[j].priority.toInt()) {
      _shuffleByWeight(addrs, i, j);
      i = j;
    }
  }
  _shuffleByWeight(addrs, i, addrs.length);
}

/// `shuffleByWeight` sobre `addrs[from:to]`.
void _shuffleByWeight(List<SRV> addrs, int from, int to) {
  var sum = 0;
  for (var i = from; i < to; i++) {
    sum += addrs[i].weight.toInt();
  }
  while (sum > 0 && to - from > 1) {
    var s = 0;
    final n = _randIntn(sum);
    for (var i = from; i < to; i++) {
      s += addrs[i].weight.toInt();
      if (s > n) {
        if (i > from) {
          final t = addrs[from];
          addrs[from] = addrs[i];
          addrs[i] = t;
        }
        break;
      }
    }
    sum -= addrs[from].weight.toInt();
    from++;
  }
}

/// `byPref.sort()`: embaralha e ordena pela preferência (RFC 5321).
void _sortMX(List<MX> s) {
  for (var i = 0; i < s.length; i++) {
    final j = _randIntn(i + 1);
    final t = s[i];
    s[i] = s[j];
    s[j] = t;
  }
  _sortStable(s, (a, b) => a.pref.toInt().compareTo(b.pref.toInt()));
}

/// Ordenação estável (o `slices.SortFunc` do Go é por inserção até 12
/// elementos; acima disso a ordem dos iguais não é garantida no Go).
void _sortStable<T>(List<T> xs, int Function(T, T) cmp) {
  for (var i = 1; i < xs.length; i++) {
    final x = xs[i];
    var j = i - 1;
    while (j >= 0 && cmp(xs[j], x) > 0) {
      xs[j + 1] = xs[j];
      j--;
    }
    xs[j + 1] = x;
  }
}
