// Roda um programa dart2js (`js <arquivo.js>`) ou dart2wasm
// (`wasm <arquivo.mjs> <arquivo.wasm>`) no Node como se fosse um navegador:
// `globalThis.process` escondido (o que `sys_js.dart` usa para achar o Node)
// e `self` definido (o global que o dart2js espera de um navegador).
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const [kind, a, b] = process.argv.slice(2);

function hideNode() {
  globalThis.self = globalThis;
  Object.defineProperty(globalThis, 'process', {
    value: undefined,
    configurable: true,
    writable: true,
  });
}

if (kind === 'js') {
  const src = await readFile(a, 'utf8');
  hideNode();
  (0, eval)(src);
} else {
  const mod = await import(pathToFileURL(a).href);
  const bytes = await readFile(b);
  hideNode();
  const app = await mod.compile(bytes);
  const instance = await app.instantiate({});
  instance.invokeMain();
}
