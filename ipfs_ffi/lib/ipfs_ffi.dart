/// Binding dart:ffi da lib nativa gerada por `tool/build.dart`
/// (`native/libipfs.so` no linux, `native/ipfs.dll` no Windows).
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

part 'src/ipfs_ffi/native.dart';
part 'src/ipfs_ffi/memory.dart';
part 'src/ipfs_ffi/exception.dart';
part 'src/ipfs_ffi/node.dart';
part 'src/ipfs_ffi/run.dart';
part 'src/ipfs_ffi/daemon.dart';
