#include "bridge.h"

void ipfs_invoke(ipfs_cb f, int64_t id, int32_t kind, char *data) { f(id, kind, data); }
