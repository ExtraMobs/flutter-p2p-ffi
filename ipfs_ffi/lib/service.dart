/// O serviço: o kubo roda no executável `ipfs_host`, noutro processo; o app
/// só fala com ele pela `ipfs_shm` (memória compartilhada; protocolo no
/// `WIRE.md`). Um panic do Go derruba só o serviço, e no Android o pacote o
/// para quando o app vai para o segundo plano ([IpfsService.background]):
/// as chamadas pendentes falham com [IpfsServiceException] (com o
/// [IpfsStopReason]) e o `onStop` de [IpfsService.start] recebe um
/// [IpfsStop]; quem usa o pacote decide o que fazer (limpar o log,
/// [IpfsService.restart], refazer nó e CoreAPI: os handles do serviço
/// anterior deixam de valer).
///
/// ```dart
/// await IpfsService.start(crashLog: 'crash.log', onStop: (stop) async {
///   print('${stop.reason}: ${stop.report}');
///   if (stop.reason == IpfsStopReason.crash) await IpfsService.restart();
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

export 'src/runtime.dart'
    show IpfsException, IpfsServiceException, IpfsStopReason;
export 'src/shm.dart' show ipfsShmLibraryPath;

/// Função Hello (WIRE.md): `u64` hash da tabela → vazio, ou erro.
const _fnHello = 4;

/// O que acontece com o serviço quando o app vai para o segundo plano (só
/// conta no Android, com o plugin `ipfs_ffi_flutter`).
enum IpfsBackground {
  /// O pacote para o serviço (o host sai) e avisa no `onStop` com
  /// [IpfsStopReason.background]; subir de novo fica com o app. O padrão:
  /// o Android 12+ mata um processo filho que gaste CPU com o app em segundo
  /// plano, e o app junto.
  stop,

  /// O serviço segue rodando: o plugin mantém um serviço em primeiro plano do
  /// Android (com notificação) enquanto o host estiver de pé.
  foregroundService,
}

/// O lado da plataforma (no Android, o plugin `ipfs_ffi_flutter` instala o
/// seu ao abrir o app): avisado quando o serviço sobe e quando para.
abstract interface class IpfsPlatform {
  /// O serviço subiu no modo [mode] (o app está em primeiro plano).
  Future<void> serviceStarted(IpfsBackground mode);

  /// O serviço parou (stop, queda ou segundo plano).
  Future<void> serviceStopped();
}

/// Uma parada do ipfs_host sem [IpfsService.stop]: caiu ou foi parado no
/// segundo plano ([reason]).
final class IpfsStop {
  IpfsStop._(this.reason, this.exitCode, this.report, this.crashLog, this.pid,
      this.uptime);

  /// Caiu ([IpfsStopReason.crash]) ou foi parado com o app em segundo plano
  /// ([IpfsStopReason.background]).
  final IpfsStopReason reason;

  /// O código de saída do host (2 num panic do Go).
  final int exitCode;

  /// O relatório do Go numa queda: o que o host acrescentou ao [crashLog]
  /// desde que subiu, ou o stderr dele (sem crashLog, ou se o arquivo ficou
  /// vazio). Vazio no segundo plano.
  final String report;

  /// O arquivo de crash passado ao [IpfsService.start] (null se nenhum); o
  /// host só acrescenta nele, e limpar fica a cargo de quem usa o pacote.
  final String? crashLog;

  /// O pid do host que parou.
  final int pid;

  /// Quanto tempo ele ficou de pé.
  final Duration uptime;

  /// A mesma exceção que as chamadas pendentes receberam.
  IpfsServiceException get exception => IpfsServiceException(
      switch (reason) {
        IpfsStopReason.crash => 'o ipfs_host caiu (saída $exitCode)'
            '${report.isEmpty ? '' : ': $report'}',
        IpfsStopReason.background =>
          'o serviço foi parado: o app foi para o segundo plano',
      },
      reason: reason);

  @override
  String toString() => exception.message;
}

/// O que fazer quando o ipfs_host para; ver [IpfsService.start].
typedef IpfsStopHandler = FutureOr<void> Function(IpfsStop stop);

/// O serviço desta isolate (um canal por isolate).
abstract final class IpfsService {
  static ShmChannel? _ch;
  static ({
    String hostPath,
    String? crashLog,
    int spin,
    IpfsStopHandler? onStop
  })? _params;
  static var _mode = IpfsBackground.stop; // lido de [background] ao subir
  static var _logStart = 0; // tamanho do crashLog quando o host atual subiu
  static final _up = Stopwatch();

  /// O que fazer com o serviço quando o app vai para o segundo plano
  /// (padrão: parar). Lida a cada [start] e [restart]: mudar com o serviço
  /// de pé vale na próxima subida.
  static IpfsBackground background = IpfsBackground.stop;

  /// O lado da plataforma; no Android, o plugin `ipfs_ffi_flutter` o instala
  /// ao abrir o app. Sem ele o pacote não sabe do segundo plano (um app sem
  /// Flutter pode chamar [appInBackground] ele mesmo).
  static IpfsPlatform? platform;

  /// Lança o ipfs_host ([hostPath]; padrão [defaultHostPath]), conecta, confere
  /// no Hello que app e host vieram do mesmo gerador e liga a API gerada a
  /// ele. [crashLog]: arquivo onde o Go acrescenta o relatório de um panic que
  /// derrube o host. [spin]: voltas da espera ativa antes de dormir no sininho.
  ///
  /// Se o host parar sem [stop] (caiu, ou o app foi para o segundo plano no
  /// modo [IpfsBackground.stop]), nada volta sozinho: as chamadas pendentes
  /// falham com [IpfsServiceException] e [onStop] (padrão: nenhum) recebe um
  /// [IpfsStop] com o motivo; ele decide se limpa o [crashLog], se chama
  /// [restart] e quando. Já rodando, é um [StateError].
  static Future<void> start(
      {String? hostPath,
      String? crashLog,
      int spin = 20000,
      IpfsStopHandler? onStop}) async {
    if (isRunning) {
      throw StateError('o IpfsService já está rodando (stop() antes)');
    }
    _params = (
      hostPath: hostPath ?? defaultHostPath(),
      crashLog: crashLog,
      spin: spin,
      onStop: onStop
    );
    await _launch();
  }

  /// Lança de novo o host com os parâmetros do último [start] (inclusive o
  /// `onStop`) e o [background] atual; para usar depois de uma parada. Sem
  /// [start] antes (ou depois de [stop]), é um [StateError]; já rodando,
  /// também.
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
    final mode = background;
    if (mode == IpfsBackground.foregroundService &&
        Platform.isAndroid &&
        platform == null) {
      throw StateError('IpfsBackground.foregroundService no Android pede o '
          'plugin ipfs_ffi_flutter no app');
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
    _mode = mode;
    $attach(ch);
    _up
      ..reset()
      ..start();
    unawaited(ch.exitCode.then((code) => _died(ch, code)));
    try {
      await platform?.serviceStarted(mode);
    } catch (_) {
      // o lado da plataforma falhou (ex.: o Android negou o serviço em
      // primeiro plano): o serviço não fica de pé pela metade
      await _stop(true);
      rethrow;
    }
  }

  /// O host [ch] saiu sem stop(): solta o canal e entrega a queda ao onStop.
  static Future<void> _died(ShmChannel ch, int code) async {
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
    final s = IpfsStop._(
        IpfsStopReason.crash, code, report, crashLog, ch.hostPid, _up.elapsed);
    _ch = null;
    $detach(s.exception);
    await ch.close();
    await platform?.serviceStopped();
    // um erro do onStop vai para a zona de quem chamou start()
    await _params?.onStop?.call(s);
  }

  /// O app foi para o segundo plano: no modo [IpfsBackground.stop] (o
  /// [background] da subida atual), para o serviço e avisa no `onStop` com
  /// [IpfsStopReason.background]; as pendentes falham com esse motivo e
  /// [restart] sobe de novo. No [IpfsBackground.foregroundService], ou sem
  /// serviço, não faz nada. O plugin `ipfs_ffi_flutter` chama sozinho.
  static Future<void> appInBackground() async {
    final ch = _ch;
    if (ch == null || !isRunning || _mode != IpfsBackground.stop) return;
    _ch = null;
    await ch.close(reason: IpfsStopReason.background);
    final s = IpfsStop._(IpfsStopReason.background, await ch.exitCode, '',
        _params?.crashLog, ch.hostPid, _up.elapsed);
    $detach(s.exception);
    await platform?.serviceStopped();
    await _params?.onStop?.call(s);
  }

  /// Para o serviço; o host sai sozinho. Os handles do serviço deixam de
  /// valer. Não chama o `onStop`.
  static Future<void> stop() => _stop(false);

  static Future<void> _stop(bool keepParams) async {
    if (!keepParams) _params = null;
    final ch = _ch;
    if (ch == null) return;
    _ch = null;
    $detach();
    await ch.close();
    await platform?.serviceStopped();
  }

  /// Se o serviço está de pé (depois de uma parada, false até o [restart]).
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
