// Núcleo da medida do lote do callback sob demanda (0.17.0), usado pelo
// tool/bench_callback.dart e pelo integration_test/bench_test.dart do app
// Android: a função 27 do host produz itens num callback, sem nada do kubo no
// meio; para cada tamanho de item e cada lote mede itens/s, MB/s, a espera
// até o primeiro item e os sininhos (chamadas de sistema que acordam o outro
// lado) por item. Não é API pública.
import 'dart:io';
import 'dart:typed_data';

import 'runtime.dart' show $W, $callCb, $callSync;

/// A tabela da matriz [sizes] × [batches], com o serviço já iniciado, uma
/// linha por vez em [out] (o logcat do Android corta linhas longas);
/// [seconds] por ponto (mediana de 3 rodadas).
Future<void> callbackBench(void Function(String line) out,
    {double seconds = 1.0,
    List<int> batches = batches,
    List<int> sizes = sizes}) async {
  out('lote   itens/s       MB/s  1º item µs  sininhos/item  RSS MB');
  for (final size in sizes) {
    out('== itens de $size bytes');
    for (final batch in batches) {
      final m =
          await median3(await calibrate(size, batch, seconds), size, batch);
      out('${'$batch'.padLeft(4)} ${m.perSec.toStringAsFixed(0).padLeft(10)} '
          '${m.mbs.toStringAsFixed(1).padLeft(10)} '
          '${m.firstUs.toStringAsFixed(0).padLeft(11)} '
          '${m.bellsPerItem.toStringAsFixed(3).padLeft(14)} '
          '${(ProcessInfo.currentRss / (1 << 20)).toStringAsFixed(0).padLeft(7)}');
    }
  }
}

const batches = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096];
const sizes = [16, 64, 1024, 64 * 1024];

/// Itens para ~[seconds] com este lote: uma sondagem de 4 lotes (ao menos 200
/// itens) dá a vazão; entre 4 lotes e 2 milhões de itens.
Future<int> calibrate(int size, int batch, double seconds) async {
  final probe = batch * 4 < 200 ? 200 : batch * 4;
  final sw = Stopwatch()..start();
  await measure(probe, size, batch);
  final per = sw.elapsedMicroseconds / probe;
  return (seconds * 1e6 / per).clamp(batch * 4, 2000000).round();
}

/// A mediana de 3 rodadas (pelos itens/s).
Future<Result> median3(int n, int size, int batch) async {
  final rs = [for (var i = 0; i < 3; i++) await measure(n, size, batch)]
    ..sort((a, b) => a.perSec.compareTo(b.perSec));
  return rs[1];
}

typedef Result = ({
  double perSec,
  double mbs,
  double firstUs,
  double bellsPerItem
});

Future<Result> measure(int n, int size, int batch) async {
  $callSync(28); // zera os sininhos
  var first = -1, bytes = 0;
  final sw = Stopwatch()..start();
  final r = await $callCb(
      27,
      $W()
        ..u32(batch)
        ..i64(n)
        ..i64(size), (r) {
    if (first < 0) first = sw.elapsedMicroseconds;
    r.i64();
    bytes += (r.bytes() ?? Uint8List(0)).length;
    return true; // segue
  });
  sw.stop();
  final made = r.i64();
  final s = $callSync(28);
  final bells = s.i64() + s.i64();
  final secs = sw.elapsedMicroseconds / 1e6;
  if (made != n || bytes != n * size)
    throw StateError('$made/$n itens, $bytes bytes');
  return (
    perSec: n / secs,
    mbs: bytes / (1 << 20) / secs,
    firstUs: first.toDouble(),
    bellsPerItem: bells / n,
  );
}
