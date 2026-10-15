/// O serviço: o kubo roda no executável `ipfs_host`, noutro processo; o app
/// só fala com ele pela `ipfs_shm` (memória compartilhada; protocolo no
/// `WIRE.md`). Um panic do Go derruba só o serviço: as chamadas pendentes
/// falham com [IpfsServiceException] e o `onCrash` de [IpfsService.start]
/// recebe o relatório; quem usa o pacote decide o que fazer (limpar o log,
/// [IpfsService.restart], refazer nó e CoreAPI: os handles do serviço
/// anterior deixam de valer).
///
/// ```dart
/// await IpfsService.start(crashLog: 'crash.log', onCrash: (crash) async {
///   print(crash.report);
///   await IpfsService.restart();
/// });
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

/// Uma queda do ipfs_host (saiu sem [IpfsService.stop]).
final class IpfsCrash {
  IpfsCrash._(this.exitCode, this.report, this.crashLog, this.pid, this.uptime);

  /// O código de saída do host (2 num panic do Go).
  final int exitCode;

  /// O relatório do Go: o que o host acrescentou ao [crashLog] desde que
  /// subiu, ou o stderr dele (sem crashLog, ou se o arquivo ficou vazio).
  final String report;

  /// O arquivo de crash passado ao [IpfsService.start] (null se nenhum); o
  /// host só acrescenta nele, e limpar fica a cargo de quem usa o pacote.
  final String? crashLog;

  /// O pid do host que caiu.
  final int pid;

  /// Quanto tempo ele ficou de pé.
  final Duration uptime;

  /// A mesma exceção que as chamadas pendentes receberam.
  IpfsServiceException get exception => IpfsServiceException(
      'o ipfs_host caiu (saída $exitCode)${report.isEmpty ? '' : ': $report'}');

  @override
  String toString() => exception.message;
}

/// O que fazer quando o ipfs_host cai; ver [IpfsService.start].
typedef IpfsCrashHandler = FutureOr<void> Function(IpfsCrash crash);

/// O serviço desta isolate (um canal por isolate).
abstract final class IpfsService {
  static ShmChannel? _ch;
  static ({
    String hostPath,
    String? crashLog,
    int spin,
    IpfsCrashHandler? onCrash
  })? _params;
  static var _logStart = 0; // tamanho do crashLog quando o host atual subiu

  /// Lança o ipfs_host ([hostPath]; padrão [defaultHostPath]), conecta, confere
  /// no Hello que app e host vieram do mesmo gerador e liga a API gerada a
  /// ele. [crashLog]: arquivo onde o Go acrescenta o relatório de um panic que
  /// derrube o host. [spin]: voltas da espera ativa antes de dormir no sininho.
  ///
  /// Se o host cair sem [stop], nada volta sozinho: as chamadas pendentes
  /// falham com [IpfsServiceException] e [onCrash] (padrão: nenhum) recebe um
  /// [IpfsCrash] com o relatório; ele decide se limpa o [crashLog], se chama
  /// [restart] e quando. Já rodando, é um [StateError].
  static Future<void> start(
      {String? hostPath,
      String? crashLog,
      int spin = 20000,
      IpfsCrashHandler? onCrash}) async {
    if (isRunning) {
      throw StateError('o IpfsService já está rodando (stop() antes)');
    }
    _params = (
      hostPath: hostPath ?? defaultHostPath(),
      crashLog: crashLog,
      spin: spin,
      onCrash: onCrash
    );
    await _launch();
  }

  /// Lança de novo o host com os parâmetros do último [start] (inclusive o
  /// `onCrash`); para usar depois de uma queda. Sem [start] antes (ou depois
  /// de [stop]), é um [StateError]; já rodando, também.
  static Future<void> restart() async {
    if (_params == null) {
      throw StateError('o IpfsService não foi iniciado (start() antes)');
    }
    if (isRunning) {
      throw StateError('o IpfsService já está rodando (stop() antes)');
    }
    await _launch();
  }

  static Future<void> _launch() async {
    if (_ch case final old?) {
      _ch = null;
      $detach();
      await old.close();
    }
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

  /// O host [ch] saiu sem stop(): solta o canal e entrega a queda ao onCrash.
  static Future<void> _died(ShmChannel ch, int code, Duration lived) async {
    if (!identical(_ch, ch)) return; // parado ou já trocado
    final crashLog = _params?.crashLog;
    var report = '';
    if (crashLog != null) {
      try {
        final all = File(crashLog).readAsBytesSync();
        report = utf8
            .decode(all.sublist(_logStart.clamp(0, all.length)),
                allowMalformed: true)
            .trim();
      } on FileSystemException {
        // sem arquivo: fica o stderr
      }
    }
    if (report.isEmpty) report = ch.hostStderr.trim();
    final crash = IpfsCrash._(code, report, crashLog, ch.hostPid, lived);
    _ch = null;
    $detach();
    await ch.close();
    // um erro do onCrash vai para a zona de quem chamou start()
    await _params?.onCrash?.call(crash);
  }

  /// Para o serviço; o host sai sozinho. Os handles do serviço deixam de valer.
  static Future<void> stop() async {
    _params = null;
    final ch = _ch;
    if (ch == null) return;
    _ch = null;
    $detach();
    await ch.close();
  }

  /// Se o serviço está de pé (depois de uma queda, false até o [restart]).
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
