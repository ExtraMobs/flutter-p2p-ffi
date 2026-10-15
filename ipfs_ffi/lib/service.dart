/// O serviço: o kubo roda no executável `ipfs_host`, noutro processo; o app
/// só fala com ele pela `ipfs_shm` (memória compartilhada; protocolo no
/// `WIRE.md`). Um panic do Go derruba só o serviço: as chamadas pendentes
/// falham com [IpfsServiceException] e o app o relança com [IpfsService.start].
///
/// ```dart
/// await IpfsService.start();
/// final ctx = context.background();
/// // ... a API gerada ...
/// await IpfsService.stop();
/// ```
library;

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

  /// Lança o ipfs_host ([hostPath]; padrão [defaultHostPath]), conecta, confere
  /// no Hello que app e host vieram do mesmo gerador e liga a API gerada a
  /// ele. [crashLog]: arquivo onde o Go grava o relatório de um panic que
  /// derrube o host. [spin]: voltas da espera ativa antes de dormir no sininho.
  /// Com o serviço anterior morto, o relança; vivo, é um [StateError].
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
    final ch = await ShmChannel.start(hostPath ?? defaultHostPath(),
        crashLog: crashLog, spin: spin);
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
  }

  /// Fecha o canal; o host sai sozinho. Os handles do serviço deixam de valer.
  static Future<void> stop() async {
    final ch = _ch;
    if (ch == null) return;
    _ch = null;
    $detach();
    await ch.close();
  }

  /// Se o serviço foi iniciado e não caiu.
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
