// `timer_forgotten.go` escrito à mão como o g2d emitiria;
// `timer_context_oracle_test.dart` compara com `go run`.
// ignore_for_file: library_prefixes
import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/fmt.dart' as fmt;
import 'package:golib_dart/time.dart' as time;

const _any = go.Elem<Object?>(16, go.zeroNull, pointers: true);

void println(String s) =>
    fmt.println(go.Slice.of([Golang.String.fromDart(s)], _any));

void main() {
  go.runMain(() async {
    time.newTimer(time.Duration(3600000000000));
    time.newTicker(time.Duration(3600000000000));
    go.spawn(() async {
      await time.sleep(time.Duration(20000000));
      println('acordou');
    });
    println('bloqueia');
    await go.chanRecv(go.Chan<Golang.Int>(0, Golang.Int()));
  });
}
