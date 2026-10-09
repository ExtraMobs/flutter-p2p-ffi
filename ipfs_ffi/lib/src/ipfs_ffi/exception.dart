part of '../../ipfs_ffi.dart';

class IpfsException implements Exception {
  IpfsException(this.message);
  final String message;
  @override
  String toString() => 'IpfsException: $message';
}
