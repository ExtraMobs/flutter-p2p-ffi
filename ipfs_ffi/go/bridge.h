// Trampolim para o Go chamar o callback do Dart (NativeCallable.listener):
// o Go não chama ponteiro de função C direto.
#include <stdint.h>

typedef void (*ipfs_cb)(int64_t id, int32_t kind, char *data);

void ipfs_invoke(ipfs_cb f, int64_t id, int32_t kind, char *data);
