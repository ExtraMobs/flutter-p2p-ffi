# Pendências do ipfs_ffi

## Feito: exports diretos para assinaturas simples (0.5.0)

Toda chamada passava pelo export único `IpfsCall` com JSON (~27 µs no Windows,
mesmo para um `bool`). Desde a 0.5.0 o gerador emite um `//export IpfsD<n>` com
tipos C para cada função **síncrona** só com número, `bool`, string e handle (26
das raízes: os getters da `CoreAPI`, `fsrepo.isInitialized/open`, `files.toFile`,
`os.stat`...); o resto continua no `IpfsCall`. A API Dart não mudou. Medido com
`dart run tool/bench.dart` (20 mil chamadas depois do aquecimento):

| Chamada | Windows antes | Windows depois | linux depois |
|---|---|---|---|
| `api.unixfs()` (handle → handle) | 24–26 µs | 4,2–4,4 µs | 1,5 µs |
| `fsrepo.isInitialized` (string → bool, consulta o disco) | 73–78 µs | 49–50 µs | 3,7 µs |
| `ctx.err()` (à mão, continua em JSON: controle) | 19 µs | 20 µs | 5,9 µs |

Se um dia pesar: o `context.dart` escrito à mão ainda usa JSON (`background`,
`withCancel`, `err`) e pode ganhar exports diretos à mão no mesmo molde.

## Feito: relatório de crash (0.5.0)

Um panic numa goroutine interna do kubo (fora de uma chamada) não é recuperável no
processo: derruba o app. O `guard` cobre a chamada e todas as goroutines do próprio
ipfs_ffi (`try`/`goTry` em `go/runtime.go`: a do `IpfsCall` assíncrono, a das funções
do kubo com `chan<-` geradas e a do `chanSink` das opções), onde o panic vira
`IpfsException`; as do kubo e das dependências não têm como. `os.create(caminho)` +
`debug.setCrashOutput(f, debug.CrashOptions())` fazem o Go gravar o relatório
(`panic: ...` e o stack das goroutines) nesse arquivo; o app o lê no próximo início.

## Pendente: o resto da comunicação por JSON

Desde a 0.5.0, 26 das 91 funções usam export direto sem JSON; os bytes já atravessam
como buffer C (0.3.0). Ainda passam por JSON: 19 síncronas (bytes em parâmetro ou
resultado, tipos-valor como `Cid`, structs como `Identity`/`Config`/`Link`, opções
funcionais), as 39 `Future` e 7 `Stream` (argumentos e resultado pelo listener) e o
`context.dart` escrito à mão. Passos, em custo crescente:

1. **Exports diretos para bytes e tipos-valor**: bytes como ponteiro+tamanho, CID/path/
   peer ID/multiaddr/ipns.Name como string C. Tira ~10 das 19 síncronas do JSON.
2. **Medir as assíncronas**: quanto de um `resolvePath`/`add` é JSON e quanto é o salto
   do `NativeCallable.listener` e o trabalho do kubo. Se o JSON for fração pequena,
   trocar o formato rende pouco.
3. **Formato binário gerado no lugar do JSON** (structs, listas, mapas, opções,
   resultados assíncronos, eventos de stream), com codificador e decodificador gerados
   nos dois lados. Trabalho do tamanho da F2; decidir com os números do passo 2.

## Marco final: Android (0.7.0 no emulador; aparelho real em 2026-10-11, dados móveis e Wi-Fi)

O mesmo nó mínimo num app Android, com a API Dart gerada sem mudança. Validado em
2026-10-11 no emulador `sdk_gphone16k_x86_64` (Android 17 / API 37, páginas de 16 KB),
com NDK 30.0.16248370 e o app Flutter de validação em `example/android_app`, e num aparelho
real: Xiaomi (Android 16, arm64-v8a), nos dados móveis (`ccmni*`, IPv4
100.x atrás do NAT da operadora + IPv6) e no Wi-Fi de casa (`wlan0`, 192.168.1.x).

| Etapa | O quê | Status |
|---|---|---|
| **A1. Build por ABI** | `dart run tool/build.dart android`: `GOOS=android`, clang do NDK (`--target=<arch>-linux-android24`), `-extldflags=-Wl,-z,max-page-size=16384`, `-checklinkname=0` (o `wlynxg/anet` usa linkname em `net.zoneCache`), e o `go-multiaddr/net` e o `zeroconf` trocados pelo anet (`-modfile` gerado, ver Netlink abaixo) → `native/android/<abi>/libipfs.so` | ✅ x86_64 79,4 MB, arm64-v8a 56,1 MB; `LOAD Align 0x4000`; exports conferidos |
| **A2. Carregar a lib** | `ipfsLibraryPath` = `libipfs.so` no Android; o Gradle do app empacota direto de `native/android` (`jniLibs.srcDirs`; só as ABIs do `--target-platform`, por `packaging.jniLibs.excludes`), `minSdk` 24, `INTERNET` no release | ✅ app abre a lib e sobe o nó |
| **A3. Nó no app** | `lib/checks.dart`: add/get, pins+GC, progresso, IPNS/chaves/dag, CAR, dois nós (bitswap, provide/findProviders, pubsub), ciclos, custo da ponte; rodam no `integration_test/ipfs_test.dart` e sozinhas ao abrir o app, que junta tudo num log com "copiar" (e no logcat; linhas longas saem cortadas lá, a caixa do app tem tudo) | ✅ 7/7 no emulador e no aparelho |
| **A4. Rede móvel** | roteamento do `Routing.Type` (perfis `randomports` + `lowpower`, com a lista padrão de endereços do kubo de volta: TCP + QUIC/WebTransport/WebRTC em UDP na porta sorteada); DNS por HTTPS no repo do app; anet (endereços locais e mDNS) e `MulticastLock` no app; verificações de rede no app (interfaces, peers entrada × saída, endereços, DNSLink + bloco da rede e, com 2 min online, transportes, conexões de entrada e na rede local, endereços de relay) | ✅ emulador: 94–245 peers, `/ipns/ipfs.tech` em 163 ms. Aparelho, 11/11: só com TCP, 8–23 peers (dados) e 92 (Wi-Fi), nenhum relay; com UDP, 54–124 peers (metade ou mais por QUIC) e reserva em 2 relays; com o anet o nó anuncia o IP do Wi-Fi (192.168.1.x) ou o da operadora (100.x, IPv6 2804:…). Rede local: um nó no PC achou o celular por mDNS em 3 s e conectou direto nos dois sentidos. Dados móveis: o PC conectou pelo relay em ~2,6 s; com o UPnP do PC ligado, a conexão virou direta em ~7 s (inversão: o celular discou para o PC), com o UPnP desligado ficou no relay (sem hole punching: o NAT da operadora parece simétrico, a porta pública muda por destino). `/ipns/ipfs.tech` em 0,16–1,3 s |
| **A5. Ciclo de vida** | o app fecha o nó em `paused` e reabre em `resumed`; `debug.setCrashOutput` em `<dados do app>/crash.log`, mostrado no próximo início | ✅ background → volta reabre o nó (mesmo peer); 10 ciclos no teste (emulador e aparelho); crash de teste: na primeira abertura o app derruba o próprio processo (panic numa goroutine do Go) e, na seguinte, mostra o relatório do Go e o log da execução que caiu. ✅ emulador e aparelho |
| **A6. Custo** | APK, memória, ponte | ✅ APK release (arm64+x64) 167,9 MB; por aparelho ≈ 72 MB (arm64) / ≈ 97 MB (x86_64), quase tudo a `libipfs.so`; memória com o nó online há 60 s: PSS 192,6 MB, RSS 310 MB; ponte: `api.unixfs()` 5,7–8,1 µs, `fsrepo.isInitialized` 10,6–15 µs, `ctx.err()` (JSON) 14–27 µs. Aparelho (APK arm64 72,1 MB): PSS 286,6–298,2 MB, RSS 442–446 MB com o nó online há ~1 min depois das verificações; ponte 2,7 / 7,8 / 11,5 µs. ⏳ consumo de bateria e de dados ao longo do tempo |

Achados:
- Release: `flutter build apk --release --target-platform android-arm64` (72,1 MB, para
  aparelho) ou `android-arm64,android-x64` (sem isso o Flutter também põe as libs dele de
  armeabi-v7a, e o app instalaria num aparelho de 32 bits sem a `libipfs.so`). O Gradle do
  app só empacota a `libipfs.so` das ABIs pedidas.
- Ponteiros com tag: no arm64 do Android o alocador marca o byte mais alto do ponteiro
  (`0xB4…`), e o endereço do buffer de bytes, como `int` do Dart, chegava negativo ao Go
  (`json: cannot unmarshal number -5476376614457254512 into Go struct field cbuf.$p of type
  uintptr`): todo `add`/`get` falhava no aparelho, nunca no emulador. Os endereços cruzam
  agora como `int64` (`go/runtime.go`).
- DNS: o Android não tem `/etc/resolv.conf`, e o resolvedor do Go cai em `[::1]:53`
  (`lookup _dnslink.ipfs.tech. on [::1]:53: ... connection refused`). O app grava
  `DNS.Resolvers` `{".": "https://cloudflare-dns.com/dns-query"}` no repo novo. Quem usa a
  lib no Android precisa fazer o mesmo (ou a lib passa a configurar o resolvedor do Go).
- Netlink: desde o Android 11 o app não pode fazer `bind()` em socket netlink nem pedir
  `RTM_GETLINK`, e o `net.Interfaces`/`net.InterfaceAddrs` do Go falham (`route ip+net:
  netlinkrib: permission denied`; golang/go#40569): o libp2p cai no plano B de anunciar só
  127.0.0.1/::1 (`addrs_manager.go`) e o mDNS não acha interface. O `wlynxg/anet` (já no
  grafo pelo pion) refaz isso com `RTM_GETADDR` sem `bind()` e `ioctl`. No build do Android
  o `tool/build.dart` copia o `go-multiaddr` e o `zeroconf` do cache de módulos para
  `.dart_tool/android_mod/`, troca as chamadas pelo anet (o build para se o trecho mudar) e
  compila com um `-modfile` gerado com os `replace` (o Go recusa `-overlay` em arquivos do
  cache de módulos). O caminho dessas cópias fica no buildinfo da `.so`. Não coberto:
  UPnP/NAT-PMP (`go-netroute` usa netlink de rota) e outros ~10 pontos menores do grafo.
- Relay (circuit v2), medido com relay, nó privado e discador locais: a conexão dura até
  **2 min** ou 128 KiB (padrão do go-libp2p; o kubo sempre monta um limite, mesmo com a
  config) e **pubsub e bitswap não passam por ela** (conexão "limitada"): o relay só serve
  para montar uma conexão direta (inversão ou hole punching). O ConnMgr do discador não a
  derruba (sobreviveu ao corte de 226 para 27 peers); o `Peering` do kubo conecta pelo
  circuito, mas não refez a conexão em 130 s depois do limite. A queda em ~30 s vista com um
  relay público segue sem causa (o relay é de terceiros). Dois celulares atrás de NAT
  simétrico, portanto, não trocam dados: precisam de IPv6 (não testado), de um relay sem
  limite (fora do kubo: um relay do go-libp2p com `Limit: nil`) ou de um peer alcançável.
- APK arm64 no emulador x86_64 (tradução arm64→x86 do berberis) cai com SIGILL: o
  `golang.org/x/sys/cpu` não lê o `/proc/self/auxv` lá e cai no `mrs ID_AA64ISAR0_EL1`, que o
  kernel de um arm64 real emula e o tradutor não. No emulador use o build x86_64.
- Com `Routing.Type` none (`libp2p.nilRouterOption`) o kubo 0.43 não fecha o datastore do
  `provider-keystore` no `close` (o hook pula o provider Noop): reabrir o mesmo repo no mesmo
  processo falha com "resource temporarily unavailable". Com roteamento real não acontece.
- Quem baixa um bloco também passa a anunciá-lo (estratégia padrão do provide): numa busca
  por provedores, procure o peer esperado entre vários (`numProviders(5)`), não o primeiro.
- Limites que seguem: um nó por processo (plugins e métricas globais do kubo); iOS fora do
  escopo; a `.so` grande (cortar plugins/transportes não usados é o próximo passo se pesar).
