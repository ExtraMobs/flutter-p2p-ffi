part of '../../../sync/atomic.dart';

// --- funções sobre *T ---

/// `atomic.AddInt32(addr, delta)`.
Golang.Int32 addInt32(Ptr<Golang.Int32>? addr, Golang.Int32 delta) =>
    addr!.value = addr.value + delta;

/// `atomic.AddInt64(addr, delta)`.
Golang.Int64 addInt64(Ptr<Golang.Int64>? addr, Golang.Int64 delta) =>
    addr!.value = addr.value + delta;

/// `atomic.AddUint32(addr, delta)`.
Golang.Uint32 addUint32(Ptr<Golang.Uint32>? addr, Golang.Uint32 delta) =>
    addr!.value = addr.value + delta;

/// `atomic.AddUint64(addr, delta)`.
Golang.Uint64 addUint64(Ptr<Golang.Uint64>? addr, Golang.Uint64 delta) =>
    addr!.value = addr.value + delta;

/// `atomic.LoadInt32(addr)`.
Golang.Int32 loadInt32(Ptr<Golang.Int32>? addr) => addr!.value;

/// `atomic.LoadInt64(addr)`.
Golang.Int64 loadInt64(Ptr<Golang.Int64>? addr) => addr!.value;

/// `atomic.LoadUint32(addr)`.
Golang.Uint32 loadUint32(Ptr<Golang.Uint32>? addr) => addr!.value;

/// `atomic.LoadUint64(addr)`.
Golang.Uint64 loadUint64(Ptr<Golang.Uint64>? addr) => addr!.value;

/// `atomic.StoreInt32(addr, v)`.
void storeInt32(Ptr<Golang.Int32>? addr, Golang.Int32 v) => addr!.value = v;

/// `atomic.StoreInt64(addr, v)`.
void storeInt64(Ptr<Golang.Int64>? addr, Golang.Int64 v) => addr!.value = v;

/// `atomic.StoreUint32(addr, v)`.
void storeUint32(Ptr<Golang.Uint32>? addr, Golang.Uint32 v) => addr!.value = v;

/// `atomic.StoreUint64(addr, v)`.
void storeUint64(Ptr<Golang.Uint64>? addr, Golang.Uint64 v) => addr!.value = v;

T _swap<T>(Ptr<T>? addr, T n) {
  final old = addr!.value;
  addr.value = n;
  return old;
}

bool _cas<T>(Ptr<T>? addr, T old, T n) {
  if (addr!.value != old) return false;
  addr.value = n;
  return true;
}

/// `atomic.SwapInt32(addr, new)`.
Golang.Int32 swapInt32(Ptr<Golang.Int32>? addr, Golang.Int32 n) =>
    _swap(addr, n);

/// `atomic.SwapInt64(addr, new)`.
Golang.Int64 swapInt64(Ptr<Golang.Int64>? addr, Golang.Int64 n) =>
    _swap(addr, n);

/// `atomic.SwapUint32(addr, new)`.
Golang.Uint32 swapUint32(Ptr<Golang.Uint32>? addr, Golang.Uint32 n) =>
    _swap(addr, n);

/// `atomic.SwapUint64(addr, new)`.
Golang.Uint64 swapUint64(Ptr<Golang.Uint64>? addr, Golang.Uint64 n) =>
    _swap(addr, n);

/// `atomic.CompareAndSwapInt32(addr, old, new)`.
bool compareAndSwapInt32(
  Ptr<Golang.Int32>? addr,
  Golang.Int32 old,
  Golang.Int32 n,
) => _cas(addr, old, n);

/// `atomic.CompareAndSwapInt64(addr, old, new)`.
bool compareAndSwapInt64(
  Ptr<Golang.Int64>? addr,
  Golang.Int64 old,
  Golang.Int64 n,
) => _cas(addr, old, n);

/// `atomic.CompareAndSwapUint32(addr, old, new)`.
bool compareAndSwapUint32(
  Ptr<Golang.Uint32>? addr,
  Golang.Uint32 old,
  Golang.Uint32 n,
) => _cas(addr, old, n);

/// `atomic.CompareAndSwapUint64(addr, old, new)`.
bool compareAndSwapUint64(
  Ptr<Golang.Uint64>? addr,
  Golang.Uint64 old,
  Golang.Uint64 n,
) => _cas(addr, old, n);
