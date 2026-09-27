import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('process')
external _Process? get _process;

extension type _Process(JSObject _) implements JSObject {
  external _Stdout? get stdout;
}

extension type _Stdout(JSObject _) implements JSObject {
  external void write(JSUint8Array data);

  /// Mesmo `write` do Node, com o `callback` de "este pedaço já foi
  /// escrito" que `write` aceita — usado só para descarregar antes de sair.
  @JS('write')
  external void writeFlush(
    JSUint8Array data,
    JSFunction<void Function(JSAny?)> callback,
  );
}

extension type _Stderr(JSObject _) implements JSObject {
  external void write(JSString data);
}

extension type _ProcessExit(JSObject _) implements JSObject {
  external _Stderr? get stderr;
  external void exit(JSNumber code);
}

bool _selfEnsured = false;

/// `dart2js` só sabe agendar microtasks/timers olhando globais de
/// browser/worker (`self.scheduleImmediate`, `self.setTimeout`...); sem
/// `self`, o primeiro `await` do programa quebra com `ReferenceError: self
/// is not defined` — Node não define `self` (`dart compile wasm` não passa
/// por isto: o runtime do Wasm agenda diferente). [runMain] chama isto
/// antes de qualquer coisa (todo programa gerado entra por ele agora, nem
/// que seja só pro `await` do [flushOutput] final); [ensureAsyncScheduling]
/// de novo em [goroutineBlocked]/`spawn` é só defesa pra quem não passar por
/// `runMain` (ex.: os fixtures deste pacote).
void ensureAsyncScheduling() {
  if (_selfEnsured) return;
  _selfEnsured = true;
  if (_process != null) {
    globalContext.setProperty('self'.toJS, globalContext);
  }
}

final _pending = <int>[];

/// Node: bytes exatos em `process.stdout`. Navegador: `print` por linha
/// completa (o console só aceita texto; bytes inválidos viram U+FFFD).
void writeStdout(List<int> bytes) {
  final out = _process?.stdout;
  if (out != null) {
    out.write(Uint8List.fromList(bytes).toJS);
    return;
  }
  _pending.addAll(bytes);
  var nl = _pending.indexOf(0x0a);
  while (nl >= 0) {
    print(utf8.decode(_pending.sublist(0, nl), allowMalformed: true));
    _pending.removeRange(0, nl + 1);
    nl = _pending.indexOf(0x0a);
  }
}

/// Mensagem em stderr (Node) ou no console.
void writeStderr(String text) {
  final p = _process;
  final err = p == null ? null : _ProcessExit(p).stderr;
  if (err != null) {
    err.write(text.toJS);
  } else {
    print(text);
  }
}

/// Node: espera o `write` mais recente do stdout ser de fato escrito antes
/// de `process.exit` (mesmo bug do `dart:io`, ver `output_io.dart`) — um
/// pedaço vazio com callback é o jeito padrão de pedir só a confirmação de
/// "descarregado" sem escrever nada a mais. Navegador: `print` já é síncrono
/// (não há processo, nem I/O assíncrono a descarregar).
Future<void> flushOutput() async {
  final out = _process?.stdout;
  if (out == null) return;
  final completer = Completer<void>();
  void onFlushed(JSAny? _) {
    if (!completer.isCompleted) completer.complete();
  }

  out.writeFlush(Uint8List(0).toJS, onFlushed.toJS);
  await completer.future;
}

/// Node: `process.exit`; navegador: não há processo, lança.
Never exitProcess(int code) {
  final p = _process;
  if (p != null) {
    _ProcessExit(p).exit(code.toJS);
    // `process.exit()` devolve o controle pro chamador antes de o processo
    // morrer de fato (fora do controle do JS); chamado de dentro de uma
    // função `async` (`spawn`, `fatal` disparado por um Timer...), sobra
    // margem pra dart2js dar mais um passo do laço de eventos antes da
    // morte efetiva. Um `throw` aqui viraria uma exceção nova (e ruído no
    // stderr) nesse intervalo; girar não — o processo morre antes de isto
    // ser observável.
    while (true) {}
  }
  throw StateError('exit($code)');
}
