# ipfs_ffi_android

App Flutter mínimo que valida o `ipfs_ffi` no Android (marco final do roteiro,
etapas A1–A6 em `../../TODO.md`). O pacote `ipfs_ffi` continua Dart puro; só este
app usa Flutter.

```sh
# na raiz do repositório: libipfs_host.so (o ipfs_host) e libipfs_shm.so, x86_64 e
# arm64-v8a, em native/android/
dart run tool/build.dart android
# aqui: o Gradle empacota as libs de ../../native/android (jniLibs.srcDirs) e as
# extrai na instalação (useLegacyPackaging: o Android só executa o host de lá)
flutter run -d <emulador-ou-aparelho>
flutter test integration_test -d <emulador-ou-aparelho>
# release só com as ABIs compiladas
flutter build apk --release --target-platform android-arm64,android-x64
```

A tela sobe um nó online (repo no diretório de dados do app, perfis `randomports` e
`lowpower`, pubsub ligado), mostra o peer ID e os peers, adiciona e lê um texto,
fecha o nó quando o app vai para o background e reabre na volta, e trata a queda
do `ipfs_host` (o kubo roda noutro processo): o `onStop` mostra o relatório do Go,
limpa o `crash.log` e relança o serviço e o nó, sem o app fechar. Na primeira
abertura ele derruba o host de propósito para mostrar isso.
