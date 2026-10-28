// Lección 07 · ¿Qué es un repositorio, y por qué `init`?
//
// Pregunta: las lecciones 03-06 armaron la pila a mano, en memoria, y la
// perdieron al final. Un nodo IPFS guarda sus bloques, su identidad y su
// configuración entre ejecuciones. ¿Dónde, y qué tiene que existir antes de
// que el nodo pueda arrancar?
//
// Respuesta: en un repositorio, una carpeta en disco creada una vez por
// `init` (el `ipfs init` de la línea de comandos). Guarda:
//   - la identidad: un par de claves. La clave pública, con hash, es el peer
//     ID: el nombre del nodo en la red (lección 13). La clave privada firma.
//   - la config: la configuración JSON de kubo (adónde van los bloques, en
//     qué direcciones escuchar, de qué peers hacer bootstrap, enrutamiento...).
//     Los perfiles son cambios listos sobre ella (`test`, `server`,
//     `lowpower`, `randomports`...).
//   - el datastore y el blockstore de la lección 03, ahora en disco (flatfs
//     para los bloques, leveldb o pebble para el resto), más el keystore
//     (las claves extra de la lección 11).
// Los datastores son plugins de kubo: se cargan en el servicio una vez, antes
// de abrir cualquier repositorio.
//
// Necesita: la lección 01 (el servicio). Técnicamente: los plugins (para
// armar la especificación de datastore del repositorio), una identidad (una
// clave) y una config hecha a partir de ella; abrir necesita una carpeta ya
// inicializada y que no esté en uso por otro proceso.
//
//   dart run example/es/07_repo_and_init.dart
//
// Siguiente pregunta: "¿Y qué hace el nodo con este repositorio?" →
// lección 08.
import 'dart:io';

import 'package:p2p_ffi/go/kubo/config.dart' as config;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson07_');
  final dir = '${tmp.path}/repo';
  try {
    // 1. Los plugins, una vez por proceso del servicio.
    //    Go:  plugins, _ := loader.NewPluginLoader("")
    //         plugins.Initialize(); plugins.Inject()
    final plugins = loader.PluginLoader('');
    plugins.initialize();
    plugins.inject();
    say('plugins cargados (ahora kubo conoce los datastores)');

    // 2. La identidad: una clave ed25519 nueva; el peer ID sale de ella.
    //    Go:  id, _ := config.CreateIdentity(io.Discard, []options.KeyGenerateOption{
    //             options.Key.Type("ed25519")})
    final identity = config.createIdentity(null, [options.key.type('ed25519')]);
    say('\nidentidad: peer ID ${identity.peerId}');
    say('  (la clave privada queda en la config: quien la tiene ES este peer)');

    // 3. La config a partir de la identidad, y un perfil encima.
    //    Go:  cfg, _ := config.InitWithIdentity(id)
    //         config.Profiles["test"].Transform(cfg)
    final cfg = config.initWithIdentity(identity);
    final before = (cfg.json['Addresses'] as Map)['Swarm'];
    config.profiles['test']!.transform(cfg);
    final after = (cfg.json['Addresses'] as Map)['Swarm'];
    say('\nconfig: escucha en $before por defecto');
    say('  tras el perfil `test`: $after, peers de bootstrap '
        '${(cfg.json['Bootstrap'] as List).length}');
    say('  perfiles que conoce kubo: ${config.profiles.keys.join(', ')}');

    // 4. init escribe la carpeta; open la bloquea para este proceso.
    //    Go:  fsrepo.Init(dir, cfg); r, _ := fsrepo.Open(dir)
    say('\ninicializado antes de init: ${fsrepo.isInitialized(dir)}');
    fsrepo.init(dir, cfg);
    say('inicializado después de init: ${fsrepo.isInitialized(dir)}');
    void listFolder(String when) {
      final entries = Directory(dir).listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      say('en la carpeta $when: ${entries.map((e) {
        final name = e.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        return e is Directory ? '$name/' : name;
      }).join(', ')}');
    }

    listFolder('tras init');
    final repo = fsrepo.open(dir);
    listFolder('tras open (los datastores nacen en la primera apertura)');
    final stored = repo.config();
    say('\nabierto; la config leída de vuelta del disco tiene el mismo peer '
        'ID: ${(stored.json['Identity'] as Map)['PeerID'] == identity.peerId}');
    final spec = (stored.json['Datastore'] as Map)['Spec'] as Map;
    say('  especificación del datastore: ${spec['type']} con '
        '${(spec['mounts'] as List).map((m) => (m as Map)['mountpoint']).join(', ')}');

    // 5. Una clave de la config se puede leer y cambiar con el repositorio
    //    abierto.
    //    Go:  r.SetConfigKey("Datastore.StorageMax", "1GB")
    repo.setConfigKey('Datastore.StorageMax', '1GB');
    say('  Datastore.StorageMax ahora: '
        '${repo.getConfigKey('Datastore.StorageMax')}');
    repo.close();

    say('\n== Errores comunes\n');
    final other = config.initWithIdentity(
        config.createIdentity(null, [options.key.type('ed25519')]));
    await silentlyWrong(
        'init otra vez, esperando que la config nueva '
        'reemplace la anterior',
        why: 'init sobre una carpeta que ya es repositorio no hace nada (sin '
            'error): la identidad de dentro nunca se sobrescribe',
        instead: 'cambia un repositorio existente con setConfig/setConfigKey '
            '(paso 5); una identidad nueva pide una carpeta nueva',
        wrong: () {
          fsrepo.init(dir, other);
          final r = fsrepo.open(dir);
          final id = (r.config().json['Identity'] as Map)['PeerID'];
          r.close();
          return 'peer ID en el repositorio: $id';
        },
        right: () => 'el peer ID de la config nueva: '
            '${(other.json['Identity'] as Map)['PeerID']}');
    await mistake('abrir una carpeta que nunca se inicializó',
        why: 'no hay config, ni identidad, ni datastore que abrir',
        instead: 'init una vez (pasos 2-4), open las demás',
        action: () => fsrepo.open('${tmp.path}/nothing-here'));
    await mistake('cargar los plugins dos veces en el mismo servicio',
        why: 'cada plugin de datastore se registra una sola vez en Go',
        instead: 'cárgalos una vez por servicio, justo después de '
            'P2pService.start()',
        action: () => loader.PluginLoader('')
          ..initialize()
          ..inject());
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
