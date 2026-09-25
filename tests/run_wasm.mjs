// Roda um módulo dart2wasm no Node: node run_wasm.mjs <arquivo.mjs> <arquivo.wasm>
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const [mjs, wasm] = process.argv.slice(2);
const mod = await import(pathToFileURL(mjs).href);
const app = await mod.compile(await readFile(wasm));
const instance = await app.instantiate({});
instance.invokeMain();
