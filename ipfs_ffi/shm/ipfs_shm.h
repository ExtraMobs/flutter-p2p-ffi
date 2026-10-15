/* ipfs_shm: o lado do app do canal com o ipfs_host (marco 0.9.0). Mapeia a
 * região compartilhada que o host cria, escreve pedidos no anel 0, lê
 * respostas do anel 1 e espera "girando um pouco, depois dormindo" no
 * sininho (Unix socket no linux/Android, dois pipes no Windows). Sem Go:
 * um panic do Go nunca roda neste processo. Layout: go/shmring/ring.go. */
#ifndef IPFS_SHM_H
#define IPFS_SHM_H

#include <stdint.h>

#ifdef _WIN32
#define SHM_API __declspec(dllexport)
#else
#define SHM_API __attribute__((visibility("default")))
#endif

/* Chamado de outra thread (NativeCallable.listener): 1 = há respostas para
 * drenar; -1 = o host caiu (o canal fechou). */
typedef void (*shm_wake_cb)(int64_t);

/* Conecta no host em [endpoint] (caminho do Unix socket, ou o nome base dos
 * pipes no Windows). [spin]: voltas antes de dormir. NULL com *err (solte
 * com shm_free) se falhar. */
SHM_API void *shm_connect(const char *endpoint, int32_t spin, shm_wake_cb cb,
                          char **err);

/* Pedidos (app → host). shm_reserve espera espaço (gira e cede a CPU) e
 * devolve onde escrever o corpo de [n] bytes, ou NULL se o host caiu ou [n]
 * não cabe; shm_commit publica e toca o sininho se o host dormia. Entre os
 * dois, um lock deixa só um produtor por vez. */
SHM_API uint8_t *shm_reserve(void *h, uint32_t n);
SHM_API void shm_commit(void *h, uint32_t n);

/* Respostas (host → app), de um consumidor só por vez. shm_peek devolve o
 * corpo da próxima (e *n) ou NULL se vazio; shm_advance a libera. */
SHM_API const uint8_t *shm_peek(void *h, uint32_t *n);
SHM_API void shm_advance(void *h);

/* Espera haver resposta (chamada síncrona): gira, depois dorme. 1 = há
 * resposta; 0 = o host caiu. */
SHM_API int32_t shm_wait(void *h);

/* O Dart drenou depois de um cb(1): rearma o aviso. 1 = chegou mais
 * coisa nesse meio-tempo e o Dart segue drenando (o aviso fica desarmado). */
SHM_API int32_t shm_rearm(void *h);

SHM_API int32_t shm_alive(void *h);
SHM_API int32_t shm_max_message(void *h);

/* Fecha o canal (o host sai) e solta tudo. */
SHM_API void shm_close(void *h);
/* Memória do mesmo runtime C da ipfs_shm (o Dart aloca com shm_malloc). */
SHM_API void *shm_malloc(uint64_t n);
SHM_API void shm_free(void *p);

#endif
