import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A disposable, localhost-only Kubo process for VM interop tests.
///
/// The repository is always created by this class and is deleted by
/// [dispose]. It never uses IPFS Desktop's repository.
class LocalKuboHarness {
  LocalKuboHarness._({required this.executable, required this.repository});

  /// Starts an isolated Kubo process, or throws [KuboExecutableNotFound].
  static Future<LocalKuboHarness> start({
    String? executable,
    String routingType = 'none',
    bool clearBootstrap = true,
  }) async {
    final resolved = await findExecutable(executable: executable);
    if (resolved == null) {
      throw KuboExecutableNotFound();
    }

    final repository = await _createRepository();
    final harness = LocalKuboHarness._(
      executable: resolved,
      repository: repository,
    );
    try {
      await harness._start(routingType, clearBootstrap);
      return harness;
    } catch (_) {
      await harness.dispose();
      rethrow;
    }
  }

  /// Resolves [IPFS_EXECUTABLE] (compile-time or process environment) or PATH.
  static Future<String?> findExecutable({String? executable}) async {
    final compileTime = const String.fromEnvironment('IPFS_EXECUTABLE');
    final candidate = executable ??
        (compileTime.isNotEmpty
            ? compileTime
            : Platform.environment['IPFS_EXECUTABLE']);
    if (candidate != null && candidate.isNotEmpty) {
      if (await File(candidate).exists()) return candidate;
      // A command name is also valid when it is available through PATH.
      if (await _onPath(candidate)) return candidate;
      return null;
    }

    for (final name in Platform.isWindows ? ['ipfs.exe', 'ipfs'] : ['ipfs']) {
      final path = await _pathOf(name);
      if (path != null) return path;
    }
    return null;
  }

  /// The resolved Kubo executable.
  final String executable;

  /// The isolated repository used by this process.
  final Directory repository;

  /// Port used by Kubo's API endpoint.
  late final int apiPort;

  /// Port used by Kubo's TCP swarm listener.
  late final int swarmPort;

  /// Port used by Kubo's gateway (not used for P2P assertions).
  late final int gatewayPort;

  Process? _process;
  bool _disposed = false;
  final StringBuffer _stdout = StringBuffer();
  final StringBuffer _stderr = StringBuffer();

  /// Captured Kubo daemon stdout, useful when a readiness check fails.
  String get stdoutLog => _stdout.toString();

  /// Captured Kubo daemon stderr, useful when a readiness check fails.
  String get stderrLog => _stderr.toString();

  /// Kubo's peer ID, available after [start] completes.
  String get peerId => _peerId;
  late final String _peerId;

  /// The direct TCP multiaddr to this local Kubo.
  String get swarmAddress => '/ip4/127.0.0.1/tcp/$swarmPort/p2p/$peerId';

  /// Returns the running Kubo version.
  Future<String> version() async =>
      '${(await _run(['version', '--number'])).stdout}'.trim();

  /// Adds one raw block to this isolated Kubo repository.
  Future<String> putRawBlock(List<int> bytes) async {
    final input = File(
      '${repository.path}${Platform.pathSeparator}bitswap-fixture.bin',
    );
    await input.writeAsBytes(bytes, flush: true);
    try {
      final result = await _run([
        'block',
        'put',
        '--format=raw',
        '--mhtype=sha2-256',
        input.path,
      ]);
      return '${result.stdout}'.trim();
    } finally {
      if (await input.exists()) await input.delete();
    }
  }

  /// Connects this Kubo daemon to a remote multiaddr via `ipfs swarm connect`.
  Future<void> swarmConnect(String multiaddr) async {
    await _run(['swarm', 'connect', multiaddr]);
  }

  /// Retrieves a raw block from the swarm via `ipfs block get`.
  Future<Uint8List> getRawBlock(String cid) async {
    final result = await _run(['block', 'get', cid], stdoutEncoding: null);
    final stdout = result.stdout;
    if (stdout is Uint8List) return stdout;
    if (stdout is List<int>) return Uint8List.fromList(stdout);
    if (stdout is String) return Uint8List.fromList(stdout.codeUnits);
    throw StateError('Unexpected stdout type: ${stdout.runtimeType}');
  }

  /// Adds a UnixFS file without using the HTTP gateway and returns its root
  /// Cid. Kubo receives the file path directly, so the file is never loaded
  /// into Dart memory.
  Future<String> addFile(File file) async {
    if (!await file.exists()) {
      throw ArgumentError.value(file.path, 'file', 'does not exist');
    }
    final result = await _run([
      'add',
      '--quieter',
      '--pin=false',
      '--cid-version=1',
      file.path,
    ]);
    final lines = '${result.stdout}'
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) throw StateError('Kubo add returned no Cid');
    return lines.last;
  }

  /// Returns Kubo's UnixFS root statistics parsed from `dag stat`.
  Future<Map<String, dynamic>> stat(String cid) async {
    final result = await _run(['dag', 'stat', '--progress=false', cid]);
    final stats = <String, dynamic>{'Cid': cid};
    for (final line in '${result.stdout}'.split(RegExp(r'\r?\n'))) {
      final separator = line.indexOf(':');
      if (separator < 1) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      stats[key] = int.tryParse(value) ?? value;
    }
    if (stats.length == 1) {
      throw StateError('Kubo dag stat returned no statistics');
    }
    return stats;
  }

  /// Returns all unique descendants reported by Kubo's recursive refs command.
  Future<List<String>> refsRecursive(String cid) async {
    final result = await _run(['refs', '--recursive', '--unique', cid]);
    return '${result.stdout}'
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  /// Exports a UnixFS DAG to CAR using Kubo's `dag export` command.
  ///
  /// CAR bytes are copied directly from the Kubo process to [output], keeping
  /// large fixtures out of memory. The output is created below
  /// `.tmp-validation` by default.
  Future<File> exportCar(String cid, {File? output}) async {
    final car = output ??
        File('${validationRoot().path}${Platform.pathSeparator}kubo-$cid.car');
    await car.parent.create(recursive: true);
    final process = await Process.start(
      executable,
      ['dag', 'export', cid],
      environment: {'IPFS_PATH': repository.path},
      includeParentEnvironment: true,
      runInShell: false,
    );
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final copyFuture = process.stdout.pipe(car.openWrite());
    final exitCode = await process.exitCode;
    await copyFuture;
    final stderr = await stderrFuture;
    if (exitCode != 0) {
      if (await car.exists()) await car.delete();
      throw ProcessException(
        executable,
        ['dag', 'export', cid],
        stderr.trim(),
        exitCode,
      );
    }
    return car;
  }

  /// Imports a CAR into this isolated Kubo repository without pinning roots.
  Future<void> importCar(File car) async {
    if (!await car.exists()) {
      throw ArgumentError.value(car.path, 'car', 'does not exist');
    }
    await _run(['dag', 'import', '--pin-roots=false', car.path]);
  }

  /// Announces [cid] through this isolated node's configured DHT.
  Future<void> provide(String cid) async {
    await _run(['routing', 'provide', cid]);
  }

  /// Resolves providers through Kubo for interop diagnostics.
  Future<String> findProviders(String cid, {int count = 1}) async =>
      '${(await _run(['routing', 'findprovs', '-n', '$count', cid])).stdout}'.trim();

  /// Returns Kubo's live swarm and Bitswap diagnostics after a failed proof.
  Future<String> diagnostics() async {
    final peers = await _run(['swarm', 'peers', '--streams']);
    final bitswap = await _run(['bitswap', 'stat']);
    return 'swarm peers --streams:\n${peers.stdout}\nbitswap stat:\n${bitswap.stdout}';
  }

  Future<void> _start(String routingType, bool clearBootstrap) async {
    apiPort = await _freePort();
    swarmPort = await _freePort();
    gatewayPort = await _freePort();

    await _run(['init']);
    await _run(['config', 'Addresses.API', '/ip4/127.0.0.1/tcp/$apiPort']);
    await _run([
      'config',
      'Addresses.Gateway',
      '/ip4/127.0.0.1/tcp/$gatewayPort',
    ]);
    await _run([
      'config',
      'Addresses.Swarm',
      '--json',
      jsonEncode(['/ip4/127.0.0.1/tcp/$swarmPort']),
    ]);
    if (clearBootstrap) {
      await _run(['config', 'Bootstrap', '--json', '[]']);
    }
    await _run(['config', 'Discovery.MDNS.Enabled', '--json', 'false']);
    await _run(['config', 'Routing.Type', routingType]);

    final process = await Process.start(
      executable,
      ['daemon'],
      environment: {
        'IPFS_PATH': repository.path,
        'IPFS_TELEMETRY': 'off',
      },
      includeParentEnvironment: true,
      runInShell: false,
    );
    _process = process;
    // Drain both streams so a verbose daemon cannot block on a full pipe.
    process.stdout.transform(utf8.decoder).listen(_stdout.write);
    process.stderr.transform(utf8.decoder).listen(_stderr.write);

    final deadline = DateTime.now().add(const Duration(seconds: 30));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        _peerId = await _apiPeerId();
        if (_peerId.isEmpty) throw StateError('Kubo returned an empty peer ID');
        return;
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    throw StateError('Kubo API did not become ready: $lastError');
  }

  Future<String> _apiPeerId() async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:$apiPort/api/v0/id'),
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Kubo id returned ${response.statusCode}');
      }
      final body = await utf8.decoder.bind(response).join();
      return (jsonDecode(body) as Map<String, dynamic>)['ID'] as String;
    } finally {
      client.close(force: true);
    }
  }

  Future<ProcessResult> _run(
    List<String> args, {
    Encoding? stdoutEncoding = systemEncoding,
  }) async {
    final result = await Process.run(
      executable,
      args,
      environment: {'IPFS_PATH': repository.path},
      includeParentEnvironment: true,
      runInShell: false,
      stdoutEncoding: stdoutEncoding,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        args,
        '${result.stderr}'.trim(),
        result.exitCode,
      );
    }
    return result;
  }

  /// Stops Kubo and removes its temporary repository. Safe to call repeatedly.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final process = _process;
    if (process != null) {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode
            .timeout(const Duration(seconds: 2), onTimeout: () => -1);
      }
    }
    if (await repository.exists()) {
      await repository.delete(recursive: true);
    }
  }

  /// Alias for [dispose], useful with resource-oriented test helpers.
  Future<void> close() => dispose();

  static Future<Directory> _createRepository() async {
    final validation = validationRoot();
    await validation.create(recursive: true);
    return validation.createTemp('kubo-');
  }

  /// Returns the repository-local validation directory, creating no files.
  /// Falls back to the system temporary directory outside a repository.
  static Directory validationRoot() {
    final workspace = _workspaceRoot();
    return workspace == null
        ? Directory.systemTemp
        : Directory(
            '${workspace.path}${Platform.pathSeparator}.tmp-validation');
  }

  static Directory? _workspaceRoot() {
    var current = Directory.current;
    while (true) {
      if (Directory('${current.path}${Platform.pathSeparator}.git')
          .existsSync()) {
        return current;
      }
      final parent = current.parent;
      if (parent.path == current.path) return null;
      current = parent;
    }
  }

  static Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  static Future<bool> _onPath(String command) async =>
      await _pathOf(command) != null;

  static Future<String?> _pathOf(String command) async {
    final result = await Process.run(
      Platform.isWindows ? 'where.exe' : 'which',
      [command],
      runInShell: false,
    );
    if (result.exitCode != 0) return null;
    final first = '${result.stdout}'
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    return first.isEmpty ? null : first;
  }
}

/// Thrown when no Kubo executable can be found for an interop test.
class KuboExecutableNotFound extends StateError {
  /// Creates the missing-executable error.
  KuboExecutableNotFound()
      : super(
            'Kubo executable not found; set IPFS_EXECUTABLE or add ipfs to PATH');
}
