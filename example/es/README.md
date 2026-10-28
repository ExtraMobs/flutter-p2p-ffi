# Aprender p2p_ffi, una pregunta a la vez

[English](../README.md) · [Português](../pt/README.md) · **Español**

Un curso para quien programa en Dart y nunca usó IPFS. Cada lección es un
archivo ejecutable que responde una pregunta, dice qué necesita (las lecciones
anteriores y, técnicamente, qué piezas tienen que existir por debajo), ejecuta
los errores comunes a propósito para mostrar el error real, y termina con la
siguiente pregunta que plantea. Léelas en orden, o ve directo a la pregunta
que tengas.

```bash
dart run tool/build.dart windows   # o linux; una vez, compila el p2p_host
dart run example/es/01_dart_and_go.dart
```

Las lecciones escriben con `say()` (en [`lesson.dart`](lesson.dart)): cada
línea va al log de `dart:developer`, con el nombre del archivo de la lección
(filtrable en DevTools y en la consola de depuración del IDE), y a la terminal.

Los nombres de archivos e identificadores quedan en inglés, iguales en los tres
idiomas; solo se traducen los comentarios y la salida.

## La pila, de abajo hacia arriba

Cada lección añade una capa; cada capa necesita las de debajo.

```
 tu app (Dart)
   │  P2pService: el proceso p2p_host, por memoria compartida ......... 01
   ▼
 CID: el nombre de unos bytes, calculado a partir de ellos ............. 02
 datastore → blockstore: dónde se guardan los bloques .................. 03
 exchange: dónde conseguir un bloque que no está aquí (offline/bitswap)  04, 16
 blockservice = blockstore + exchange
 DAGService: bloques como nodos con enlaces; chunker + importer ........ 03-04
 CAR: un DAG en un solo archivo ........................................ 05-06
 repositorio + nodo (kubo): la pila lista, en disco .................... 07-12
 host libp2p: identidad, direcciones, conexiones ....................... 13-14
 enrutamiento (DHT): quién tiene un CID, dónde está un peer ............ 15
 bitswap sobre el host + enrutamiento: traer un CID de otros ........... 16
```

## Las preguntas

### Parte A · contenido, sin nodo

| # | Pregunta | Lección |
|---|---|---|
| 01 | ¿Cómo habla Dart con Go? ¿Dónde se ejecuta el código Go? | [`01_dart_and_go.dart`](01_dart_and_go.dart) |
| 02 | ¿Qué es un CID, y por qué puedo confiar en lo que vuelve para él? | [`02_what_is_a_cid.dart`](02_what_is_a_cid.dart) |
| 03 | ¿Cómo se convierte un archivo en bloques? ¿Por qué el mismo archivo tiene otro CID en otro sitio? | [`03_file_to_blocks.dart`](03_file_to_blocks.dart) |
| 04 | ¿Cómo lo leo de vuelta? ¿Y si falta un bloque? | [`04_blocks_to_file.dart`](04_blocks_to_file.dart) |
| 05 | ¿Cómo llevo bloques sin red? (archivos CAR) | [`05_car_files.dart`](05_car_files.dart) |
| 06 | ¿CARv1 o v2, el índice, raíces, una parte, juntar? | [`06_car_more.dart`](06_car_more.dart) |

### Parte B · el nodo kubo, en disco (lo siguiente)

| # | Pregunta |
|---|---|
| 07 | ¿Qué es un repositorio, y por qué `init`? |
| 08 | ¿Qué arma el nodo por mí? |
| 09 | ¿Por qué desaparecen mis bloques? (pins y GC) |
| 10 | ¿Cómo trabajo con carpetas que cambian? (MFS) |
| 11 | ¿Cómo doy un nombre fijo a algo que cambia? (claves e IPNS) |
| 12 | ¿Cómo uso los comandos `ipfs` que ya conozco? |

### Parte C · la red (próximamente)

| # | Pregunta |
|---|---|
| 13 | ¿Quién soy en la red? (claves, peer ID, multiaddr, transportes) |
| 14 | ¿Cómo hablan dos peers? (conectar, ping, un protocolo propio, mDNS) |
| 15 | ¿Cómo encuentro quién tiene un contenido? (DHT) |
| 16 | ¿Qué necesita boxo para descargar un CID? |
| 17 | ¿Cómo entro en la red IPFS pública? |
| 18 | ¿Cómo envío mensajes en tiempo real? (pubsub) |

### Parte D · usar bien el puente (próximamente)

| # | Pregunta |
|---|---|
| 19 | ¿Cómo pongo un plazo y cancelo? ¿Qué errores pueden llegar? |
| 20 | ¿Cuándo tengo que liberar memoria? (handles) |
| 21 | ¿Cómo llama Go a mi código Dart? (callbacks) |

## Respuestas rápidas

- **"Mi CID es distinto del que dio otra herramienta."** El CID depende de cómo
  se cortó y envolvió el archivo (tamaño del trozo, CIDv0 o v1, hojas raw):
  lección 03, paso 4.
- **"Dos CIDs parecen distintos pero nombran lo mismo."** Bases de texto
  distintas, o v0 y v1: compara con `equals()`, lección 02.
- **"`block was not found locally (offline)`."** El bloque no está en el
  blockstore y el exchange no puede traerlo: lección 04.
- **"Mi CAR tiene los bloques pero no la raíz."** Se escribió a partir de
  `allKeysChan()`, que pierde el codec: lección 05, errores comunes.
- **"No aparece nada en la terminal con `dev.log`."** `dart run` no imprime el
  log de `dart:developer`; las lecciones también imprimen (ver `say()` arriba).
