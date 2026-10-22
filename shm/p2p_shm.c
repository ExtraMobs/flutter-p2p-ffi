/* p2p_shm: ver p2p_shm.h. Os anéis seguem go/shmring/ring.go à risca:
 * head/tail com acquire/release, e seq_cst no par "publica tail / lê
 * sleeping" × "marca sleeping / lê tail", para nenhum lado dormir com
 * mensagem esperando. */
#include "p2p_shm.h"

#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
typedef SRWLOCK lock_t;
typedef CONDITION_VARIABLE cond_t;
#define lock_init(l) InitializeSRWLock(l)
#define lock_take(l) AcquireSRWLockExclusive(l)
#define lock_give(l) ReleaseSRWLockExclusive(l)
#define cond_init(c) InitializeConditionVariable(c)
#define cond_all(c) WakeAllConditionVariable(c)
static void cond_wait_ms(cond_t *c, lock_t *l, int ms) {
  SleepConditionVariableSRW(c, l, (DWORD)ms, 0);
}
#else
#include <errno.h>
#include <pthread.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>
typedef pthread_mutex_t lock_t;
typedef pthread_cond_t cond_t;
#define lock_init(l) pthread_mutex_init(l, NULL)
#define lock_take(l) pthread_mutex_lock(l)
#define lock_give(l) pthread_mutex_unlock(l)
#define cond_init(c) pthread_cond_init(c, NULL)
#define cond_all(c) pthread_cond_broadcast(c)
static void cond_wait_ms(cond_t *c, lock_t *l, int ms) {
  struct timespec t;
  clock_gettime(CLOCK_REALTIME, &t);
  t.tv_nsec += (long)ms * 1000000L;
  t.tv_sec += t.tv_nsec / 1000000000L;
  t.tv_nsec %= 1000000000L;
  pthread_cond_timedwait(c, l, &t);
}
#endif

#define MAGIC 0x49504653u
#define VERSION 1u
#define HEADER 4096u
#define CTL_BASE 64u
#define CTL_SIZE 256u
#define WRAP 0xFFFFFFFFu

static void relax(void) {
#if defined(__x86_64__) || defined(__i386__)
  __builtin_ia32_pause();
#elif defined(__aarch64__) || defined(__arm__)
  __asm__ __volatile__("yield");
#endif
}

static void yield_cpu(void) {
#ifdef _WIN32
  SwitchToThread();
#else
  sched_yield();
#endif
}

typedef struct {
  _Atomic uint64_t *head, *tail;
  _Atomic uint32_t *sleep;
  uint8_t *data;
  uint64_t size;
} ring;

static uint64_t align8(uint64_t n) { return (n + 7) & ~(uint64_t)7; }
static uint32_t *word(ring *r, uint64_t idx) {
  return (uint32_t *)(r->data + idx);
}

static void ring_open(ring *r, uint8_t *mem, int i, uint64_t size) {
  uint8_t *ctl = mem + CTL_BASE + (uint64_t)i * CTL_SIZE;
  r->head = (_Atomic uint64_t *)(ctl + 0);
  r->tail = (_Atomic uint64_t *)(ctl + 64);
  r->sleep = (_Atomic uint32_t *)(ctl + 128);
  r->data = mem + HEADER + (uint64_t)i * size;
  r->size = size;
}

static int ring_empty(ring *r) {
  return atomic_load_explicit(r->head, memory_order_acquire) ==
         atomic_load_explicit(r->tail, memory_order_seq_cst);
}

static uint8_t *ring_reserve(ring *r, uint32_t n) {
  uint64_t tail = atomic_load_explicit(r->tail, memory_order_relaxed);
  uint64_t head = atomic_load_explicit(r->head, memory_order_acquire);
  uint64_t need = align8(4 + (uint64_t)n), idx = tail % r->size, skip = 0;
  if (idx + need > r->size) skip = r->size - idx;
  if (tail + skip + need - head > r->size) return NULL;
  if (skip) {
    *word(r, idx) = WRAP;
    idx = 0;
  }
  *word(r, idx) = n;
  return r->data + idx + 4;
}

/* 1 = o consumidor dormia: tocar o sininho. */
static int ring_commit(ring *r, uint32_t n) {
  uint64_t tail = atomic_load_explicit(r->tail, memory_order_relaxed);
  uint64_t need = align8(4 + (uint64_t)n), idx = tail % r->size;
  if (idx + need > r->size) tail += r->size - idx;
  atomic_store_explicit(r->tail, tail + need, memory_order_seq_cst);
  uint32_t one = 1;
  return atomic_load_explicit(r->sleep, memory_order_seq_cst) == 1 &&
         atomic_compare_exchange_strong(r->sleep, &one, 0);
}

static const uint8_t *ring_peek(ring *r, uint32_t *n) {
  for (;;) {
    uint64_t head = atomic_load_explicit(r->head, memory_order_relaxed);
    if (head == atomic_load_explicit(r->tail, memory_order_acquire))
      return NULL;
    uint64_t idx = head % r->size;
    uint32_t len = *word(r, idx);
    if (len == WRAP) {
      atomic_store_explicit(r->head, head + r->size - idx,
                            memory_order_release);
      continue;
    }
    *n = len;
    return r->data + idx + 4;
  }
}

static void ring_advance(ring *r) {
  uint64_t head = atomic_load_explicit(r->head, memory_order_relaxed);
  uint32_t len = *word(r, head % r->size);
  atomic_store_explicit(r->head, head + align8(4 + (uint64_t)len),
                        memory_order_release);
}

/* 1 = pode dormir; 0 = chegou mensagem nesse meio-tempo. */
static int ring_prepare_sleep(ring *r) {
  atomic_store_explicit(r->sleep, 1, memory_order_seq_cst);
  if (!ring_empty(r)) {
    uint32_t one = 1;
    atomic_compare_exchange_strong(r->sleep, &one, 0);
    return 0;
  }
  return 1;
}

typedef struct {
  uint8_t *mem;
  uint64_t memsize;
  ring req, resp;
  int spin;
  shm_wake_cb cb;
  _Atomic int alive, armed, closing;
  lock_t prod, m;
  cond_t data, consumed;
#ifdef _WIN32
  HANDLE reqpipe, resppipe, mapping, thread;
#else
  int fd;
  pthread_t thread;
#endif
} chan;

static char *dupmsg(const char *what) {
  char buf[256];
#ifdef _WIN32
  snprintf(buf, sizeof buf, "p2p_shm: %s (erro %lu)", what,
           (unsigned long)GetLastError());
#else
  snprintf(buf, sizeof buf, "p2p_shm: %s (%s)", what, strerror(errno));
#endif
  char *s = malloc(strlen(buf) + 1);
  if (s) strcpy(s, buf);
  return s;
}

static void ring_bell(chan *c) {
  char b = 1;
#ifdef _WIN32
  DWORD w;
  WriteFile(c->reqpipe, &b, 1, &w, NULL);
#else
  (void)!write(c->fd, &b, 1);
#endif
}

/* Bloqueia até o host tocar o sininho; 0 = o canal fechou. */
static int bell_wait(chan *c) {
  char buf[64];
#ifdef _WIN32
  DWORD r;
  return ReadFile(c->resppipe, buf, sizeof buf, &r, NULL) && r > 0;
#else
  ssize_t r;
  do r = read(c->fd, buf, sizeof buf);
  while (r < 0 && errno == EINTR);
  return r > 0;
#endif
}

static void die(chan *c) {
  atomic_store(&c->alive, 0);
  lock_take(&c->m);
  cond_all(&c->data);
  cond_all(&c->consumed);
  lock_give(&c->m);
  if (!atomic_load(&c->closing)) c->cb(-1);
}

/* A thread que acorda o Dart: espera resposta (gira, depois dorme no
 * sininho), avisa quem espera síncrono e posta um aviso ao Dart por vez. */
#ifdef _WIN32
static DWORD WINAPI waker(LPVOID arg) {
#else
static void *waker(void *arg) {
#endif
  chan *c = arg;
  while (atomic_load(&c->alive)) {
    int got = 0;
    for (int i = 0; i < c->spin && !got; i++) {
      if (!ring_empty(&c->resp)) got = 1;
      else relax();
    }
    /* sem resposta no giro: dorme; se ela chegou nesse meio tempo, entrega
     * (com spin 0, voltar ao laço aqui girava para sempre sem entregar) */
    if (!got && ring_prepare_sleep(&c->resp)) {
      if (!bell_wait(c)) break;
      atomic_store(c->resp.sleep, 0);
      continue;
    }
    lock_take(&c->m);
    cond_all(&c->data);
    lock_give(&c->m);
    if (atomic_exchange(&c->armed, 0) == 1) c->cb(1);
    lock_take(&c->m);
    while (atomic_load(&c->alive) && !ring_empty(&c->resp) &&
           atomic_load(&c->armed) == 0)
      cond_wait_ms(&c->consumed, &c->m, 100);
    lock_give(&c->m);
  }
  die(c);
  return 0;
}

#ifndef _WIN32
static int connect_unix(chan *c, const char *path, char **err) {
  c->fd = socket(AF_UNIX, SOCK_STREAM, 0);
  struct sockaddr_un a;
  memset(&a, 0, sizeof a);
  a.sun_family = AF_UNIX;
  if (strlen(path) >= sizeof a.sun_path) {
    *err = dupmsg("socket path too long");
    return 0;
  }
  strcpy(a.sun_path, path);
  if (c->fd < 0 || connect(c->fd, (struct sockaddr *)&a, sizeof a) != 0) {
    *err = dupmsg("connect");
    return 0;
  }
  /* aperto de mão: u64 tamanho + o memfd por SCM_RIGHTS */
  uint64_t size = 0;
  struct iovec iov = {&size, sizeof size};
  char cbuf[CMSG_SPACE(sizeof(int))];
  struct msghdr msg;
  memset(&msg, 0, sizeof msg);
  msg.msg_iov = &iov;
  msg.msg_iovlen = 1;
  msg.msg_control = cbuf;
  msg.msg_controllen = sizeof cbuf;
  if (recvmsg(c->fd, &msg, MSG_WAITALL) != (ssize_t)sizeof size) {
    *err = dupmsg("handshake");
    return 0;
  }
  struct cmsghdr *cm = CMSG_FIRSTHDR(&msg);
  if (!cm || cm->cmsg_level != SOL_SOCKET || cm->cmsg_type != SCM_RIGHTS) {
    *err = dupmsg("the host did not send the region");
    return 0;
  }
  int memfd;
  memcpy(&memfd, CMSG_DATA(cm), sizeof memfd);
  void *mem = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, 0);
  close(memfd);
  if (mem == MAP_FAILED) {
    *err = dupmsg("mmap");
    return 0;
  }
  c->mem = mem;
  c->memsize = size;
  return 1;
}
#else
static HANDLE open_pipe(const char *base, const char *suffix, DWORD access) {
  char name[512];
  snprintf(name, sizeof name, "%s-%s", base, suffix);
  return CreateFileA(name, access, 0, NULL, OPEN_EXISTING, 0, NULL);
}

static int connect_win(chan *c, const char *base, char **err) {
  c->reqpipe = open_pipe(base, "req", GENERIC_WRITE);
  c->resppipe = open_pipe(base, "resp", GENERIC_READ);
  if (c->reqpipe == INVALID_HANDLE_VALUE ||
      c->resppipe == INVALID_HANDLE_VALUE) {
    *err = dupmsg("abrir os pipes");
    return 0;
  }
  /* aperto de mão: u64 tamanho, u16 n, n bytes do nome do mapeamento */
  uint8_t hs[8 + 2 + 256];
  DWORD got = 0, r;
  while (got < 10) {
    if (!ReadFile(c->resppipe, hs + got, 10 - got, &r, NULL) || !r) {
      *err = dupmsg("handshake");
      return 0;
    }
    got += r;
  }
  uint64_t size;
  uint16_t n;
  memcpy(&size, hs, 8);
  memcpy(&n, hs + 8, 2);
  if (n > 255) {
    *err = dupmsg("invalid mapping name");
    return 0;
  }
  for (got = 0; got < n; got += r)
    if (!ReadFile(c->resppipe, hs + 10 + got, n - got, &r, NULL) || !r) {
      *err = dupmsg("handshake");
      return 0;
    }
  char name[257];
  memcpy(name, hs + 10, n);
  name[n] = 0;
  c->mapping = OpenFileMappingA(FILE_MAP_ALL_ACCESS, FALSE, name);
  void *mem = c->mapping ? MapViewOfFile(c->mapping, FILE_MAP_ALL_ACCESS, 0,
                                         0, (SIZE_T)size)
                         : NULL;
  if (!mem) {
    *err = dupmsg("open the region");
    return 0;
  }
  c->mem = mem;
  c->memsize = size;
  return 1;
}
#endif

static void release(chan *c) {
#ifdef _WIN32
  if (c->mem) UnmapViewOfFile(c->mem);
  if (c->mapping) CloseHandle(c->mapping);
  if (c->reqpipe && c->reqpipe != INVALID_HANDLE_VALUE)
    CloseHandle(c->reqpipe);
  if (c->resppipe && c->resppipe != INVALID_HANDLE_VALUE)
    CloseHandle(c->resppipe);
#else
  if (c->mem) munmap(c->mem, c->memsize);
  if (c->fd >= 0) close(c->fd);
#endif
  free(c);
}

SHM_API void *shm_connect(const char *endpoint, int32_t spin, shm_wake_cb cb,
                          char **err) {
  *err = NULL;
  chan *c = calloc(1, sizeof *c);
  if (!c) return NULL;
#ifdef _WIN32
  int ok = connect_win(c, endpoint, err);
#else
  c->fd = -1;
  int ok = connect_unix(c, endpoint, err);
#endif
  uint32_t magic, version;
  uint64_t size;
  if (ok) {
    memcpy(&magic, c->mem, 4);
    memcpy(&version, c->mem + 4, 4);
    memcpy(&size, c->mem + 8, 8);
    if (magic != MAGIC || version != VERSION ||
        HEADER + 2 * size > c->memsize) {
      *err = dupmsg("region with a different version or layout");
      ok = 0;
    }
  }
  if (!ok) {
    release(c);
    return NULL;
  }
  ring_open(&c->req, c->mem, 0, size);
  ring_open(&c->resp, c->mem, 1, size);
  c->spin = spin;
  c->cb = cb;
  atomic_store(&c->alive, 1);
  atomic_store(&c->armed, 1);
  lock_init(&c->prod);
  lock_init(&c->m);
  cond_init(&c->data);
  cond_init(&c->consumed);
#ifdef _WIN32
  c->thread = CreateThread(NULL, 0, waker, c, 0, NULL);
#else
  pthread_create(&c->thread, NULL, waker, c);
#endif
  return c;
}

SHM_API int32_t shm_max_message(void *h) {
  return (int32_t)(((chan *)h)->req.size / 2 - 4);
}

SHM_API uint8_t *shm_reserve(void *h, uint32_t n) {
  chan *c = h;
  if (n > (uint32_t)shm_max_message(h)) return NULL;
  lock_take(&c->prod);
  for (int i = 0;; i++) {
    uint8_t *p = ring_reserve(&c->req, n);
    if (p) return p; /* o lock fica com quem reservou até o commit */
    if (!atomic_load(&c->alive)) break;
    if (i < c->spin) relax();
    else yield_cpu();
  }
  lock_give(&c->prod);
  return NULL;
}

SHM_API void shm_commit(void *h, uint32_t n) {
  chan *c = h;
  int wake = ring_commit(&c->req, n);
  lock_give(&c->prod);
  if (wake) ring_bell(c);
}

SHM_API const uint8_t *shm_peek(void *h, uint32_t *n) {
  return ring_peek(&((chan *)h)->resp, n);
}

SHM_API void shm_advance(void *h) {
  chan *c = h;
  ring_advance(&c->resp);
  if (ring_empty(&c->resp)) {
    lock_take(&c->m);
    cond_all(&c->consumed);
    lock_give(&c->m);
  }
}

SHM_API int32_t shm_wait(void *h) {
  chan *c = h;
  for (int i = 0; i < c->spin; i++) {
    if (!ring_empty(&c->resp)) return 1;
    relax();
  }
  lock_take(&c->m);
  while (ring_empty(&c->resp) && atomic_load(&c->alive))
    cond_wait_ms(&c->data, &c->m, 50);
  lock_give(&c->m);
  return !ring_empty(&c->resp);
}

SHM_API int32_t shm_rearm(void *h) {
  chan *c = h;
  atomic_store(&c->armed, 1);
  if (!ring_empty(&c->resp) && atomic_exchange(&c->armed, 0) == 1) return 1;
  lock_take(&c->m);
  cond_all(&c->consumed);
  lock_give(&c->m);
  return 0;
}

SHM_API int32_t shm_alive(void *h) { return atomic_load(&((chan *)h)->alive); }

SHM_API void shm_close(void *h) {
  chan *c = h;
  atomic_store(&c->closing, 1);
  atomic_store(&c->alive, 0);
#ifdef _WIN32
  CancelSynchronousIo(c->thread);
  CloseHandle(c->reqpipe);
  c->reqpipe = INVALID_HANDLE_VALUE;
  WaitForSingleObject(c->thread, INFINITE);
  CloseHandle(c->thread);
#else
  shutdown(c->fd, SHUT_RDWR);
  pthread_join(c->thread, NULL);
#endif
  release(c);
}

SHM_API void shm_free(void *p) { free(p); }

SHM_API void *shm_malloc(uint64_t n) { return malloc((size_t)n); }
