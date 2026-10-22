# p2p_ffi_android

A minimal Flutter app that validates `p2p_ffi` on Android (the final milestone of the
roadmap, steps A1–A6 in `../../TODO.md`). The `p2p_ffi` package stays pure Dart; only this
app uses Flutter.

```sh
# at the repository root: libp2p_host.so (the p2p_host) and libp2p_shm.so, x86_64 and
# arm64-v8a, in native/android/
dart run tool/build.dart android
# here: Gradle packages the libs from ../../native/android (jniLibs.srcDirs) and extracts
# them on install (useLegacyPackaging: Android only runs the host from there)
flutter run -d <emulator-or-device>
flutter test integration_test -d <emulator-or-device>
# release with only the built ABIs
flutter build apk --release --target-platform android-arm64,android-x64
```

The screen starts an online node (repo in the app's data directory, `randomports` and
`lowpower` profiles, pubsub on), shows the peer ID and the peers, adds and reads a text,
closes the node when the app goes to the background and reopens it on return, and handles
an `p2p_host` crash (kubo runs in another process): `onStop` shows Go's report, clears
`crash.log` and restarts the service and the node, without the app closing. On the first
launch it brings the host down on purpose to show this.
