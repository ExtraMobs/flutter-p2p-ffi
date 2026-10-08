# resolv.conf, nsswitch.conf e hosts relidos sem olhar o mtime

- **Prioridade:** P2 · **Área:** shim (`net`)
- **Depende de:** —

## Problema

O resolvedor puro do Go confere o `/etc/resolv.conf`
(`resolverConfig.tryUpdate`), o `/etc/nsswitch.conf`
(`nsswitchConfig.tryUpdate`) e o `/etc/hosts` (`readHosts`) no máximo a cada
5 s e só os relê se o `stat` mudou (mtime; no hosts, mtime e tamanho; o
resolv.conf com `options no-reload` nunca é relido). O shim
(`golib_dart/lib/src/net/dns_conf.dart`, `dns_hosts.dart`) relê o hosts e o
resolv.conf a cada 5 s sem `stat`, e o nsswitch.conf em **toda** consulta;
`no-reload` é ignorado.

## Prova

```go
package main

import (
	"context"
	"fmt"
	"net"
	"time"
)

func main() {
	r := &net.Resolver{PreferGo: true}
	for i := 0; i < 12; i++ {
		addrs, err := r.LookupHost(context.Background(), "localhost")
		fmt.Println(addrs, err)
		time.Sleep(time.Second)
	}
}
```

```text
$ GOTOOLCHAIN=go1.26.5 go build -o reload main.go
$ strace -f -e trace=openat,newfstatat -o t ./reload; grep -E 'etc/(hosts|resolv|nsswitch)' t | sort | uniq -c
      3 newfstatat(AT_FDCWD, "/etc/hosts", ...) = 0
      2 newfstatat(AT_FDCWD, "/etc/nsswitch.conf", ...) = 0
      2 newfstatat(AT_FDCWD, "/etc/resolv.conf", ...) = 0
      1 openat(AT_FDCWD, "/etc/hosts", O_RDONLY|O_CLOEXEC) = 7
      1 openat(AT_FDCWD, "/etc/nsswitch.conf", O_RDONLY|O_CLOEXEC) = 7
      1 openat(AT_FDCWD, "/etc/resolv.conf", O_RDONLY|O_CLOEXEC) = 7

$ python -m g2d transpile dump.json -o out && dart compile exe out/lib/main.dart -o reload_dart
$ strace -f -e trace=openat,newfstatat -o t ./reload_dart; grep ... | sort | uniq -c
      3 newfstatat(AT_FDCWD, "/etc/hosts", ...) = 0
     12 newfstatat(AT_FDCWD, "/etc/nsswitch.conf", ...) = 0
      3 openat(AT_FDCWD, "/etc/hosts", O_RDONLY|O_CLOEXEC) = 7
     12 openat(AT_FDCWD, "/etc/nsswitch.conf", O_RDONLY|O_CLOEXEC) = 7
```

O Go abre cada arquivo uma vez (o mtime não muda); o Dart abre o hosts a
cada 5 s e o nsswitch.conf a cada consulta. Com o arquivo trocado sem mudar
o mtime, o Go segue com o conteúdo antigo e o Dart pega o novo.

## Critério de pronto

- `sysStatFile` na camada `sys` (VM `FileStat.statSync`, Node
  `fs.statSync`); os três arquivos com o `tryUpdate`/`readHosts` do Go,
  `no-reload` respeitado; teste com os caminhos trocados (como o
  `hostsFilePath` dos testes do Go) e o `stat` igual na VM e no Node.
