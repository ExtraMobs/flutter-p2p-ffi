part of '../../time.dart';

/// `*time.Location`: porta parcial de `time/zoneinfo.go` do Go 1.26 — sem o
/// banco de dados de fusos do sistema (`tzdata`/`zoneinfo.zip`), só fuso
/// fixo (um nome e um offset constantes, como `FixedZone` sempre produziu).
/// `utc` é o offset zero; **`local` é um valor separado mas com o mesmo
/// nome/offset nesta primeira versão** (⚠️ `docs/mapping-spec.md`): sem
/// acesso ao relógio do SO/TZ, todo horário "local" do shim é UTC, mas
/// continua sendo um `*Location` diferente do de `utc` (como no Go, onde
/// `Local` e `UTC` são ponteiros distintos mesmo quando coincidem em
/// offset). `LoadLocation`/o `TZ` do ambiente não têm shim (ficam
/// `Unsupported` `shim-simbolo:time.LoadLocation`).
final class Location extends GoStruct<Location> implements Stringer {
  Location._(this._name, this._offset);

  /// `(*Location)(nil)` dentro de uma interface.
  static final Location $nil = Location._('UTC', 0)..$nilPtr = true;

  String _name;

  /// Segundos a leste de UTC.
  int _offset;

  @override
  String get $goType => 'time.Location';

  @override
  List<String> get $ptrMethods => const ['String'];

  @override
  Location $copy() => Location._(_name, _offset);

  @override
  void $set(Location o) {
    _name = o._name;
    _offset = o._offset;
  }

  // Campos do Go (`name`, `zone`, `tx`...) não são descritos: `Location`
  // só aparece por ponteiro, e `==` é identidade (como o `*Location`).
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);

  /// `(name string, offset int)` em vigor: sempre o mesmo, fuso fixo.
  (String, int) _lookup() => (_name, _offset);

  /// `String()`: o nome dado a `FixedZone`, `"UTC"` para [utc]/[local].
  @override
  Golang.String string() => Golang.String.fromDart(_name);
}

// Nomes privados para o uso interno do shim: os métodos `Time.UTC`/
// `Time.Local` viram, pela mesma regra de nomes do g2d, `utc`/`local` —
// iguais às variáveis exportadas abaixo. Um `t.utc()` referenciaria a si
// mesmo (o método) em vez da variável de nível de pacote, então o resto do
// shim usa estes dois nomes.
// Objetos distintos: `Local`/`UTC` têm identidades próprias.
final _utcSentinel = Location._('UTC', 0);
final _localSentinel = Location._('UTC', 0);

/// `time.UTC`. `Time.loc == null` também significa UTC (como no Go,
/// `loc==nil` nunca é `&utcLoc`): este objeto serve para comparações
/// explícitas do código gerado (`loc == time.UTC`) e como sentinela interno
/// de `_setLoc`.
final Location utc = _utcSentinel;

/// `time.Local`. ⚠️ Igual a [utc] em nome e offset nesta primeira versão,
/// mas um `*Location` diferente (identidade própria).
final Location local = _localSentinel;

/// `time.FixedZone(name, offset)`: sempre um fuso de verdade (sem tabela de
/// transições, então não há DST).
Location fixedZone(Golang.String name, Golang.Int offset) =>
    Location._(name.toDart(), offset.toInt());
