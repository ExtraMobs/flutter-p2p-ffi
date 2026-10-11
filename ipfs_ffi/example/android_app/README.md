# ipfs_ffi_android

App Flutter mínimo que valida o `ipfs_ffi` no Android (marco final do roteiro,
etapas A1–A6 em `../../TODO.md`). O pacote `ipfs_ffi` continua Dart puro; só este
app usa Flutter.

```sh
# na pasta ipfs_ffi/: as libipfs.so (x86_64 e arm64-v8a) em native/android/
dart run tool/build.dart android
# aqui: o Gradle empacota a lib de ../../native/android (jniLibs.srcDirs)
flutter run -d <emulador-ou-aparelho>
flutter test integration_test -d <emulador-ou-aparelho>
```

A tela sobe um nó online (repo no diretório de dados do app, perfis `randomports` e
`lowpower`, pubsub ligado), mostra o peer ID e os peers, adiciona e lê um texto,
fecha o nó quando o app vai para o background e reabre na volta, e mostra o
relatório de crash do Go se o processo anterior caiu.
