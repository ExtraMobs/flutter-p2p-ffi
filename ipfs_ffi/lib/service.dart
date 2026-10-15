/// O serviço: o kubo roda no executável `ipfs_host`, noutro processo; o app
/// só fala com ele pela `ipfs_shm` (memória compartilhada; protocolo no
/// `WIRE.md`). Um panic do Go derruba só o serviço: as chamadas pendentes
/// falham com [IpfsServiceException], o serviço volta sozinho e
/// [IpfsService.restarts] avisa o app, que refaz os objetos (nó, CoreAPI...),
/// porque os handles do serviço anterior deixam de valer.
///
/// ```dart
/// await IpfsService.start();
/// final ctx = context.background();
/// // ... a API gerada ...
/// await IpfsService.stop();
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'src/runtime.dart';
import 'src/shm.dart';
import 'src/table.dart';

export 'src/runtime.dart' show IpfsException, IpfsServiceException;
export 'src/shm.dart' show ipfsShmLibraryPath;

/// Função Hello (WIRE.md): `u64` hash da tabela → vazio, ou erro.
const _fnHello = 4;

/// O serviço desta isolate (um canal por isolate).
abstract final class IpfsService {
  static ShmChannel? _ch;
  static ({String hostPath, String? crashLog, int spin})? _params;
  static var _retry = _minRetry;
  static var _logStart = 0; // tamanho do crashLog quando o host atual subiu
  static final _restarts = StreamController<IpfsServiceException>.broadcast();

  static const _minRetry = Duration(milliseconds: 200);
  static const _maxRetry = Duration(seconds: 10);

  /// Um aviso por reinício automático, depois que o serviço novo já está de
  /// pé: a exceção traz o motivo da queda (com o relatório do Go). O app
  /// refaz aqui o que usava (`newNode`, `newCoreApi`...).
  static Stream<IpfsServiceException> get restarts => _restarts.stream;

  /// Lança o ipfs_host ([hostPath]; padrão [defaultHostPath]), conecta, confere
  /// no Hello que app e host vieram do mesmo gerador e liga a API gerada a
  /// ele. [crashLog]: arquivo onde o Go grava o relatório de um panic que
  /// derrube o host. [spin]: voltas da espera ativa antes de dormir no sininho.
  /// Se o host cair, ele volta sozinho (espera de 0,2 s a 10 s entre
  /// tentativas, crescendo enquanto ele cai logo depois de subir) e
  /// [restarts] avisa. Já rodando, é um [StateError].
  static Future<void> start(
      {String? hostPath, String? crashLog, int spin = 20000}) async {
    if (_ch case final old?) {
      if (old.deadReason == null) {
        throw StateError('o IpfsService já está rodando (stop() antes)');
      }
      _ch = null;
      $detach();
      await old.close();
    }
    _params = (
      hostPath: hostPath ?? defaultHostPath(),
      crashLog: crashLog,
      spin: spin
    );
    _retry = _minRetry;
    await _launch();
  }

  static Future<void> _launch() async {
    final p = _params!;
    if (p.crashLog case final f?) {
      final file =
          File(f); // o host acrescenta: o relatório novo vem depois daqui
      _logStart = file.existsSync() ? file.lengthSync() : 0;
    }
    final ch =
        await ShmChannel.start(p.hostPath, crashLog: p.crashLog, spin: p.spin);
    try {
      final hello = Uint8List(8)
        ..buffer.asByteData().setInt64(0, ipfsTableHash, Endian.little);
      ch.callSync(_fnHello, hello);
    } catch (_) {
      await ch.close();
      rethrow;
    }
    _ch = ch;
    $attach(ch);
    final up = Stopwatch()..start();
    unawaited(ch.exitCode.then((code) => _died(ch, code, up.elapsed)));
  }

  /// O host [ch] saiu sem stop(): relança (com espera crescente se ele caiu
  /// logo depois de subir) e avisa em [restarts].
  static Future<void> _died(ShmChannel ch, int code, Duration lived) async {
    if (!identical(_ch, ch)) return; // parado ou já trocado
    // o relatório do Go: o arquivo de crash, ou o stderr do host
    var report = '';
    if (_params?.crashLog case final f?) {
      try {
        final all = File(f).readAsBytesSync();
        report = utf8
            .decode(all.sublist(_logStart.clamp(0, all.length)),
                allowMalformed: true)
            .trim();
      } on FileSystemException {
        // sem arquivo: fica o stderr
      }
    }
    if (report.isEmpty) report = ch.hostStderr.trim();
    final reason = IpfsServiceException(
        'o ipfs_host caiu (saída $code)${report.isEmpty ? '' : ': $report'}');
    _ch = null;
    $detach();
    await ch.close();
    _retry = lived > const Duration(seconds: 30)
        ? _minRetry
        : (_retry * 2 > _maxRetry ? _maxRetry : _retry * 2);
    while (_params != null && _ch == null) {
      await Future<void>.delayed(_retry);
      if (_params == null || _ch != null) return;
      try {
        await _launch();
        _restarts.add(reason);
      } catch (_) {
        _retry = _retry * 2 > _maxRetry ? _maxRetry : _retry * 2;
      }
    }
  }

  /// Para o serviço (sem reinício); o host sai sozinho. Os handles do
  /// serviço deixam de valer.
  static Future<void> stop() async {
    _params = null;
    final ch = _ch;
    if (ch == null) return;
    _ch = null;
    $detach();
    await ch.close();
  }

  /// Se o serviço está de pé (entre uma queda e o reinício, false).
  static bool get isRunning => _ch != null && _ch!.deadReason == null;

  /// O código de saída do host atual (completa quando ele sai, inclusive por
  /// um panic); null sem serviço.
  static Future<int>? get exitCode => _ch?.exitCode;

  /// O pid do host atual; null sem serviço.
  static int? get hostPid => _ch?.hostPid;
}

/// Caminho padrão do ipfs_host: `native\ipfs_host.exe` (Windows) ou
/// `native/ipfs_host` relativo ao diretório atual; no Android, a
/// `libipfs_host.so` na pasta das libs nativas do app (`nativeLibraryDir`),
/// achada pela `libapp.so`/`libflutter.so` em `/proc/self/maps` (o APK precisa
/// extrair as libs: um executável não roda de dentro do APK).
String defaultHostPath() {
  if (Platform.isWindows) return r'native\ipfs_host.exe';
  if (!Platform.isAndroid) return 'native/ipfs_host';
  for (final line in File('/proc/self/maps').readAsLinesSync()) {
    final i = line.indexOf('/');
    if (i < 0) continue;
    final f = line.substring(i);
    if (f.endsWith('/libapp.so') || f.endsWith('/libflutter.so')) {
      return '${f.substring(0, f.lastIndexOf('/'))}/libipfs_host.so';
    }
  }
  throw IpfsServiceException('ipfs_host: a pasta das libs nativas do app não '
      'apareceu em /proc/self/maps; passe hostPath');
}
