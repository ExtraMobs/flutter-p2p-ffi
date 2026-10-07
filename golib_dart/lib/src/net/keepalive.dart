part of '../../net.dart';

// `KeepAliveConfig` e `TCPConn.SetKeepAliveConfig` (`tcpsock.go`,
// `tcpsock_unix.go`, `tcpsockopt_unix.go` do Go 1.26).

/// `net.KeepAliveConfig`: zero em `Idle`/`Interval`/`Count` é o padrão do
/// Go (15s, 15s, 9); negativo deixa a opção do socket como está.
final class KeepAliveConfig extends GoStruct<KeepAliveConfig> {
  KeepAliveConfig({
    bool? enable,
    time.Duration? idle,
    time.Duration? interval,
    Golang.Int? count,
  }) : enable = enable ?? false,
       idle = idle ?? time.Duration(),
       interval = interval ?? time.Duration(),
       count = count ?? Golang.Int(0);

  /// `(*KeepAliveConfig)(nil)` dentro de uma interface.
  static final KeepAliveConfig $nil = KeepAliveConfig()..$nilPtr = true;

  bool enable;
  time.Duration idle;
  time.Duration interval;
  Golang.Int count;

  @override
  String get $goType => 'net.KeepAliveConfig';
  @override
  KeepAliveConfig $copy() => KeepAliveConfig(
    enable: enable,
    idle: idle,
    interval: interval,
    count: count,
  );
  @override
  void $set(KeepAliveConfig o) {
    enable = o.enable;
    idle = o.idle;
    interval = o.interval;
    count = o.count;
  }

  @override
  List<Object?> get $fields => [enable, idle, interval, count];
  @override
  List<String> get $fieldNames => const ['Enable', 'Idle', 'Interval', 'Count'];
  @override
  List<String> get $fieldTypes => const [
    'bool',
    'time.Duration',
    'time.Duration',
    'int',
  ];
}

/// `(*TCPConn).SetKeepAliveConfig(config)`: `SO_KEEPALIVE` com `Enable`, e
/// as três opções do keepalive (mesmo com `Enable` falso, como o Go), cada
/// erro como `*OpError` de `set`.
GoError? _setKeepAliveConfig(TCPConn c, KeepAliveConfig config) {
  final err = c.setKeepAlive(config.enable);
  if (err != null) return err;
  return c._setOpt(() {
    final idle = _keepAliveSecs(config.idle.toInt(), _keepAliveIdleDefault);
    if (idle > 0) c._fd!.setKeepAliveIdle(idle);
    final intvl = _keepAliveSecs(
      config.interval.toInt(),
      _keepAliveIntervalDefault,
    );
    if (intvl > 0) c._fd!.setKeepAliveInterval(intvl);
    final count = config.count.toInt();
    final n = count == 0 ? _keepAliveCountDefault : count;
    if (n > 0) c._fd!.setKeepAliveCount(n);
  });
}
