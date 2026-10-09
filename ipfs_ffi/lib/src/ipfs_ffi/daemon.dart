part of '../../ipfs_ffi.dart';

/// Daemon do kubo (repo em disco, rede, API RPC e gateway) rodando numa
/// isolate deste processo via [ipfsRun].
class IpfsDaemon {
  IpfsDaemon._(this.repoDir, this.api, this.done);

  final String repoDir;

  /// Base da API RPC, ex. `http://127.0.0.1:5001/api/v0/`.
  final Uri api;

  /// Código de saída do `ipfs daemon`; completa quando ele para.
  final Future<int> done;

  static var _started = false;

  /// Faz `ipfs init [initArgs]` se [repoDir] não tem repo e sobe o
  /// `ipfs daemon [daemonArgs]`, esperando a API responder.
  ///
  /// Só um daemon por processo, mesmo depois de parado: o kubo registra
  /// métricas globais e um segundo daemon derruba o processo.
  static Future<IpfsDaemon> start(
    String repoDir, {
    List<String> initArgs = const [],
    List<String> daemonArgs = const [],
    String? libPath,
    Duration timeout = const Duration(minutes: 1),
  }) async {
    if (_started) throw IpfsException('já houve um daemon neste processo');
    _started = true;
    final repo = ['--repo-dir', repoDir];
    if (!File('$repoDir/config').existsSync()) {
      final code = ipfsRun([...repo, 'init', ...initArgs], libPath: libPath);
      if (code != 0) throw IpfsException('ipfs init saiu com $code');
    }
    // O daemon grava $repoDir/api com o multiaddr da API quando está pronto.
    final apiFile = File('$repoDir/api');
    if (apiFile.existsSync()) apiFile.deleteSync();
    var exited = false;
    final done = Isolate.run(
      () => ipfsRun([...repo, 'daemon', ...daemonArgs], libPath: libPath),
    ).whenComplete(() => exited = true);
    final deadline = DateTime.now().add(timeout);
    while (!apiFile.existsSync()) {
      if (exited) throw IpfsException('ipfs daemon saiu com ${await done}');
      if (DateTime.now().isAfter(deadline)) {
        throw IpfsException('ipfs daemon não subiu em $timeout');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    // ex. /ip4/127.0.0.1/tcp/5001
    final ma = apiFile.readAsStringSync().trim().split('/');
    final host = ma[1] == 'ip6' ? '[${ma[2]}]' : ma[2];
    return IpfsDaemon._(
      repoDir,
      Uri.parse('http://$host:${ma[4]}/api/v0/'),
      done,
    );
  }

  /// Chama `POST /api/v0/<cmd>` e devolve o JSON da resposta (a última
  /// linha, nos comandos que respondem em fluxo). [file] vai como multipart,
  /// como no `ipfs add`.
  Future<Object?> rpc(
    String cmd, {
    Map<String, String> args = const {},
    List<int>? file,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        api.resolve(cmd).replace(queryParameters: args.isEmpty ? null : args),
      );
      if (file != null) {
        const boundary = 'ipfs-ffi-boundary';
        req.headers.contentType = ContentType(
          'multipart',
          'form-data',
          parameters: {'boundary': boundary},
        );
        req
          ..write('--$boundary\r\n')
          ..write(
            'Content-Disposition: form-data; name="file"; '
            'filename="file"\r\n',
          )
          ..write('Content-Type: application/octet-stream\r\n\r\n')
          ..add(file)
          ..write('\r\n--$boundary--\r\n');
      }
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        throw IpfsException('$cmd: HTTP ${res.statusCode}: $body');
      }
      final lines = const LineSplitter().convert(body.trim());
      return lines.isEmpty ? null : jsonDecode(lines.last);
    } finally {
      client.close();
    }
  }

  /// `ipfs shutdown` e espera o daemon sair.
  Future<int> stop() async {
    await rpc('shutdown');
    return done;
  }
}
