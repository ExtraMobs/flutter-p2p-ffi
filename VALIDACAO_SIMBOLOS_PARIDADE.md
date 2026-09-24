# Validação de Símbolos AST para Transpilação 1:1 e Diretrizes de Paridade

> **Documento Normativo e Inventário Literal de Símbolos** conforme [AGENTS.md](file:///B:/Syncthing/Desenvolvimento/Projetos/Pessoal/dart%20IPFS/AGENTS.md).
> Cada símbolo AST aqui tabelado foi extraído diretamente dos índices AST das árvores Go de referência em `go-ipfs-reference/*-index/` e mapeado com sua nomenclatura adaptada e seu requisito estrito de tipagem/boilerplate.

---

## 1. Princípios de Transpilação 1:1 e Diretrizes Invioláveis

1. **Paridade Estrita 1:1**: A implementação Dart deve espelhar fielmente a lógica, estruturas, constantes, métodos e tratamento de erro do Go. É expressamente vedado simplificar algoritmos, omitir campos ou relaxar limites para contornar falhas.
2. **Veto à Degradação de Código Interno**: Tipos internos (`unexported` ou pacotes `internal/`) tornam-se privados em Dart (prefixo `_`), mas **sua lógica deve ser portada com 100% de integridade** (sem stubs parciais ou mocks em produção).
3. **Respeito às Fronteiras de `go.mod` (Regra 11)**: Cada módulo Go upstream reside em um pacote dedicado sob `packages/transpiled_<modulo>/`.
4. **Auditoria AST e Testes Atômicos (Regras 18-24)**: Todo símbolo público nasce acompanhado de teste atômico 1:1 sob `test/atomic/<nivel>/`.

---

## 2. Reforço Mandatório da Regra do `packages/boilerplate/` (Regra 10)

> [!CAUTION]
> **É EXPRESSAMENTE PROIBIDO REINVENTAR FUNÇÕES JÁ EXISTENTES EM `packages/boilerplate/`**.
> A Regra 10 (`RULE_ENFORCE_BOILERPLATE_TYPES`) é erro bloqueante no auditor AST. Toda manipulação de primitivos Go, estouro de inteiros, aritmética de bits, máscaras de rede, conversão de endereços IP ou descritores **DEVE OBRIGATORIAMENTE** consumir os módulos centralizados do boilerplate.

### Catálogo de Uso Obrigatório:

| Módulo Boilerplate | Caminho de Importação | Tipos Fornecidos | Finalidade / Semântica Go Preservada |
| :--- | :--- | :--- | :--- |
| **Tipos Primitivos Go** | `package:boilerplate/fixed_types/golang.dart` | `Golang.Byte`, `Golang.Rune`, `Golang.String`,<br>`Golang.Int8` a `Golang.Int64`,<br>`Golang.Uint8` a `Golang.Uint64`, `Golang.Uintptr`,<br>`Golang.Float32`, `Golang.Float64`,<br>`Golang.Complex64`, `Golang.Complex128` | Encapsula estouro modular $2^N$, truncamento, shifts aritméticos/lógicos, divisão/resto e zero values da especificação Go. Veto a `val & 0xFF` avulso. |
| **Rede Estilo Go (`net.IP`)** | `package:boilerplate/net/golang.dart` | `Ip`, `IpNet` | Representação de 4 ou 16 bytes; preserva a propriedade de que `10.0.0.0/8` contém `::ffff:10.1.2.3` (dobra IPv4 em IPv6). Usado pelo ConnectionGater. |
| **Prefixos de Rede (`net/netip`)** | `package:boilerplate/net_netip/golang.dart` | `Addr`, `Prefix` | Comparações mascaradas estritas sem conversão automática entre famílias de IP. Usado pelo ConnLimiter do rcmgr. |
| **Descritores e Poll (`internal/poll`)** | `package:boilerplate/internal_poll/golang.dart` | `Fd`, `FdMutex`, `ErrNetClosing` | Máquina de estados de fechamento/leitura concorrente de sockets do runtime Go. |

---

## 3. Tabelas Literais de Símbolos AST 1:1 por Subsistema

### 3.1. Pion DTLS (`github.com/pion/dtls/v3`) — Marco G.5 (WebRTC Direct)
*Destino Dart:* `packages/transpiled_pion_dtls/`
*Origem Go:* `go-ipfs-reference/pion-dtls/`

| Símbolo AST Go | Tipo Go | Escopo / Pai | Símbolo Dart Adaptado 1:1 | Regras AGENTS.md | Boilerplate Mandatório (Regra 10) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `CertificateRequestInfo` | `struct` | *(top-level)* | **`CertificateRequestInfo`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AcceptableCAs` | `field` | `CertificateRequestInfo` | **`acceptableCAs`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SupportsCertificate` | `method` | `CertificateRequestInfo` | **`supportsCertificate()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ClientHelloInfo` | `struct` | *(top-level)* | **`ClientHelloInfo`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ServerName` | `field` | `ClientHelloInfo` | **`serverName`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CipherSuites` | `field` | `ClientHelloInfo` | **`cipherSuites`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `RandomBytes` | `field` | `ClientHelloInfo` | **`randomBytes`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CipherSuite` | `interface` | *(top-level)* | **`CipherSuite`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `CipherSuite` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `CipherSuite` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateType` | `method` | `CipherSuite` | **`certificateType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `HashFunc` | `method` | `CipherSuite` | **`hashFunc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AuthenticationType` | `method` | `CipherSuite` | **`authenticationType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `KeyExchangeAlgorithm` | `method` | `CipherSuite` | **`keyExchangeAlgorithm()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ECC` | `method` | `CipherSuite` | **`ecc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Init` | `method` | `CipherSuite` | **`init()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `IsInitialized` | `method` | `CipherSuite` | **`isInitialized()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Encrypt` | `method` | `CipherSuite` | **`encrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Decrypt` | `method` | `CipherSuite` | **`decrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CipherSuiteName` | `func` | *(top-level)* | **`cipherSuiteName()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CipherSuites` | `func` | *(top-level)* | **`cipherSuites()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `InsecureCipherSuites` | `func` | *(top-level)* | **`insecureCipherSuites()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Config` | `struct` | *(top-level)* | **`Config`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Certificates` | `field` | `Config` | **`certificates`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CipherSuites` | `field` | `Config` | **`cipherSuites`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CustomCipherSuites` | `field` | `Config` | **`customCipherSuites`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SignatureSchemes` | `field` | `Config` | **`signatureSchemes`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateSignatureSchemes` | `field` | `Config` | **`certificateSignatureSchemes`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SRTPProtectionProfiles` | `field` | `Config` | **`srtpProtectionProfiles`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SRTPMasterKeyIdentifier` | `field` | `Config` | **`srtpMasterKeyIdentifier`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ClientAuth` | `field` | `Config` | **`clientAuth`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ExtendedMasterSecret` | `field` | `Config` | **`extendedMasterSecret`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `FlightInterval` | `field` | `Config` | **`flightInterval`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `DisableRetransmitBackoff` | `field` | `Config` | **`disableRetransmitBackoff`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `PSK` | `field` | `Config` | **`psk`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `PSKIdentityHint` | `field` | `Config` | **`pskIdentityHint`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `InsecureSkipVerify` | `field` | `Config` | **`insecureSkipVerify`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `InsecureHashes` | `field` | `Config` | **`insecureHashes`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `VerifyPeerCertificate` | `field` | `Config` | **`verifyPeerCertificate`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `VerifyConnection` | `field` | `Config` | **`verifyConnection`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `RootCAs` | `field` | `Config` | **`rootCAs`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ClientCAs` | `field` | `Config` | **`clientCAs`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ServerName` | `field` | `Config` | **`serverName`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `LoggerFactory` | `field` | `Config` | **`loggerFactory`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MTU` | `field` | `Config` | **`mtu`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ReplayProtectionWindow` | `field` | `Config` | **`replayProtectionWindow`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `KeyLogWriter` | `field` | `Config` | **`keyLogWriter`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SessionStore` | `field` | `Config` | **`sessionStore`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SupportedProtocols` | `field` | `Config` | **`supportedProtocols`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `EllipticCurves` | `field` | `Config` | **`ellipticCurves`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `GetCertificate` | `field` | `Config` | **`getCertificate`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `GetClientCertificate` | `field` | `Config` | **`getClientCertificate`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `InsecureSkipVerifyHello` | `field` | `Config` | **`insecureSkipVerifyHello`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ConnectionIDGenerator` | `field` | `Config` | **`connectionIdGenerator`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `PaddingLengthGenerator` | `field` | `Config` | **`paddingLengthGenerator`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `HelloRandomBytesGenerator` | `field` | `Config` | **`helloRandomBytesGenerator`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ClientHelloMessageHook` | `field` | `Config` | **`clientHelloMessageHook`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ServerHelloMessageHook` | `field` | `Config` | **`serverHelloMessageHook`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateRequestMessageHook` | `field` | `Config` | **`certificateRequestMessageHook`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `OnConnectionAttempt` | `field` | `Config` | **`onConnectionAttempt`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Conn` | `struct` | *(top-level)* | **`Conn`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Handshake` | `method` | `Conn` | **`handshake()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `HandshakeContext` | `method` | `Conn` | **`handshakeContext()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Read` | `method` | `Conn` | **`read()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Write` | `method` | `Conn` | **`write()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Close` | `method` | `Conn` | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ConnectionState` | `method` | `Conn` | **`connectionState()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SelectedSRTPProtectionProfile` | `method` | `Conn` | **`selectedSrtpProtectionProfile()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `RemoteSRTPMasterKeyIdentifier` | `method` | `Conn` | **`remoteSrtpMasterKeyIdentifier()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `LocalAddr` | `method` | `Conn` | **`localAddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `RemoteAddr` | `method` | `Conn` | **`remoteAddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetDeadline` | `method` | `Conn` | **`setDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetReadDeadline` | `method` | `Conn` | **`setReadDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetWriteDeadline` | `method` | `Conn` | **`setWriteDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Dial` | `func` | *(top-level)* | **`dial()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `DialWithOptions` | `func` | *(top-level)* | **`dialWithOptions()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Client` | `func` | *(top-level)* | **`client()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ClientWithOptions` | `func` | *(top-level)* | **`clientWithOptions()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Server` | `func` | *(top-level)* | **`server()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ServerWithOptions` | `func` | *(top-level)* | **`serverWithOptions()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `RandomCIDGenerator` | `func` | *(top-level)* | **`randomCidGenerator()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `OnlySendCIDGenerator` | `func` | *(top-level)* | **`onlySendCidGenerator()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `invalidCipherSuiteError.Error` | `func` | *(top-level)* | **`error()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `invalidCipherSuiteError.Is` | `func` | *(top-level)* | **`is()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `alertError.Error` | `func` | *(top-level)* | **`error()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `alertError.IsFatalOrCloseNotify` | `func` | *(top-level)* | **`isFatalOrCloseNotify()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `alertError.Is` | `func` | *(top-level)* | **`is()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `flightVal.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `handshakeState.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `handshakeFSM.Run` | `func` | *(top-level)* | **`run()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `handshakeFSM.Done` | `func` | *(top-level)* | **`done()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Listen` | `func` | *(top-level)* | **`listen()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ListenWithOptions` | `func` | *(top-level)* | **`listenWithOptions()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewListener` | `func` | *(top-level)* | **`Listener()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewListenerWithOptions` | `func` | *(top-level)* | **`ListenerWithOptions()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `listener.Accept` | `func` | *(top-level)* | **`accept()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `listener.Close` | `func` | *(top-level)* | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `listener.Addr` | `func` | *(top-level)* | **`addr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | `net.Ip` / `netip.Addr` (`boilerplate/net` ou `net_netip`) |
| `ClientOption` | `interface` | *(top-level)* | **`ClientOption`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Option` | `interface` | *(top-level)* | **`Option`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ServerOption` | `interface` | *(top-level)* | **`ServerOption`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `WithCertificates` | `func` | *(top-level)* | **`withCertificates()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithCipherSuites` | `func` | *(top-level)* | **`withCipherSuites()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithCustomCipherSuites` | `func` | *(top-level)* | **`withCustomCipherSuites()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithSignatureSchemes` | `func` | *(top-level)* | **`withSignatureSchemes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithCertificateSignatureSchemes` | `func` | *(top-level)* | **`withCertificateSignatureSchemes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithSRTPProtectionProfiles` | `func` | *(top-level)* | **`withSrtpProtectionProfiles()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithSRTPMasterKeyIdentifier` | `func` | *(top-level)* | **`withSrtpMasterKeyIdentifier()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithExtendedMasterSecret` | `func` | *(top-level)* | **`withExtendedMasterSecret()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithFlightInterval` | `func` | *(top-level)* | **`withFlightInterval()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithDisableRetransmitBackoff` | `func` | *(top-level)* | **`withDisableRetransmitBackoff()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithPSK` | `func` | *(top-level)* | **`withPsk()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithPSKIdentityHint` | `func` | *(top-level)* | **`withPskIdentityHint()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithInsecureSkipVerify` | `func` | *(top-level)* | **`withInsecureSkipVerify()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithInsecureHashes` | `func` | *(top-level)* | **`withInsecureHashes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithVerifyPeerCertificate` | `func` | *(top-level)* | **`withVerifyPeerCertificate()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithVerifyConnection` | `func` | *(top-level)* | **`withVerifyConnection()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithRootCAs` | `func` | *(top-level)* | **`withRootCAs()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithServerName` | `func` | *(top-level)* | **`withServerName()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithLoggerFactory` | `func` | *(top-level)* | **`withLoggerFactory()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithMTU` | `func` | *(top-level)* | **`withMtu()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithReplayProtectionWindow` | `func` | *(top-level)* | **`withReplayProtectionWindow()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithKeyLogWriter` | `func` | *(top-level)* | **`withKeyLogWriter()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithSessionStore` | `func` | *(top-level)* | **`withSessionStore()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithSupportedProtocols` | `func` | *(top-level)* | **`withSupportedProtocols()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithEllipticCurves` | `func` | *(top-level)* | **`withEllipticCurves()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithGetClientCertificate` | `func` | *(top-level)* | **`withGetClientCertificate()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithConnectionIDGenerator` | `func` | *(top-level)* | **`withConnectionIdGenerator()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithPaddingLengthGenerator` | `func` | *(top-level)* | **`withPaddingLengthGenerator()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithHelloRandomBytesGenerator` | `func` | *(top-level)* | **`withHelloRandomBytesGenerator()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithClientHelloMessageHook` | `func` | *(top-level)* | **`withClientHelloMessageHook()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithClientAuth` | `func` | *(top-level)* | **`withClientAuth()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithClientCAs` | `func` | *(top-level)* | **`withClientCAs()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithGetCertificate` | `func` | *(top-level)* | **`withGetCertificate()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithInsecureSkipVerifyHello` | `func` | *(top-level)* | **`withInsecureSkipVerifyHello()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithServerHelloMessageHook` | `func` | *(top-level)* | **`withServerHelloMessageHook()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithCertificateRequestMessageHook` | `func` | *(top-level)* | **`withCertificateRequestMessageHook()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithOnConnectionAttempt` | `func` | *(top-level)* | **`withOnConnectionAttempt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Resume` | `func` | *(top-level)* | **`resume()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ResumeWithOptions` | `func` | *(top-level)* | **`resumeWithOptions()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Session` | `struct` | *(top-level)* | **`Session`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `field` | `Session` | **`id`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Secret` | `field` | `Session` | **`secret`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SessionStore` | `interface` | *(top-level)* | **`SessionStore`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Set` | `method` | `SessionStore` | **`set()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Get` | `method` | `SessionStore` | **`get()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Del` | `method` | `SessionStore` | **`del()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `State` | `struct` | *(top-level)* | **`State`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CipherSuiteID` | `field` | `State` | **`cipherSuiteId`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `PeerCertificates` | `field` | `State` | **`peerCertificates`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `IdentityHint` | `field` | `State` | **`identityHint`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SessionID` | `field` | `State` | **`sessionId`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `NegotiatedProtocol` | `field` | `State` | **`negotiatedProtocol`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MarshalBinary` | `method` | `State` | **`marshalBinary()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `UnmarshalBinary` | `method` | `State` | **`unmarshalBinary()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ExportKeyingMaterial` | `method` | `State` | **`exportKeyingMaterial()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `RemoteRandomBytes` | `method` | `State` | **`remoteRandomBytes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Aes128Ccm` | `struct` | *(top-level)* | **`Aes128Ccm`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Init` | `method` | `Aes128Ccm` | **`init()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Aes256Ccm` | `struct` | *(top-level)* | **`Aes256Ccm`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Init` | `method` | `Aes256Ccm` | **`init()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AesCcm` | `struct` | *(top-level)* | **`AesCcm`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateType` | `method` | `AesCcm` | **`certificateType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `AesCcm` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `AesCcm` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ECC` | `method` | `AesCcm` | **`ecc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `KeyExchangeAlgorithm` | `method` | `AesCcm` | **`keyExchangeAlgorithm()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `HashFunc` | `method` | `AesCcm` | **`hashFunc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AuthenticationType` | `method` | `AesCcm` | **`authenticationType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `IsInitialized` | `method` | `AesCcm` | **`isInitialized()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Init` | `method` | `AesCcm` | **`init()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Encrypt` | `method` | `AesCcm` | **`encrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Decrypt` | `method` | `AesCcm` | **`decrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewTLSEcdheEcdsaWithAes128Ccm` | `func` | *(top-level)* | **`TlsEcdheEcdsaWithAes128Ccm()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewTLSEcdheEcdsaWithAes128Ccm8` | `func` | *(top-level)* | **`TlsEcdheEcdsaWithAes128Ccm8()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TLSEcdheEcdsaWithAes128GcmSha256` | `struct` | *(top-level)* | **`TlsEcdheEcdsaWithAes128GcmSha256`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateType` | `method` | `TLSEcdheEcdsaWithAes128GcmSha256` | **`certificateType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `KeyExchangeAlgorithm` | `method` | `TLSEcdheEcdsaWithAes128GcmSha256` | **`keyExchangeAlgorithm()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ECC` | `method` | `TLSEcdheEcdsaWithAes128GcmSha256` | **`ecc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `TLSEcdheEcdsaWithAes128GcmSha256` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `TLSEcdheEcdsaWithAes128GcmSha256` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `HashFunc` | `method` | `TLSEcdheEcdsaWithAes128GcmSha256` | **`hashFunc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AuthenticationType` | `method` | `TLSEcdheEcdsaWithAes128GcmSha256` | **`authenticationType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `IsInitialized` | `method` | `TLSEcdheEcdsaWithAes128GcmSha256` | **`isInitialized()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Init` | `method` | `TLSEcdheEcdsaWithAes128GcmSha256` | **`init()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Encrypt` | `method` | `TLSEcdheEcdsaWithAes128GcmSha256` | **`encrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Decrypt` | `method` | `TLSEcdheEcdsaWithAes128GcmSha256` | **`decrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TLSEcdheEcdsaWithAes256CbcSha` | `struct` | *(top-level)* | **`TlsEcdheEcdsaWithAes256CbcSha`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateType` | `method` | `TLSEcdheEcdsaWithAes256CbcSha` | **`certificateType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `KeyExchangeAlgorithm` | `method` | `TLSEcdheEcdsaWithAes256CbcSha` | **`keyExchangeAlgorithm()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ECC` | `method` | `TLSEcdheEcdsaWithAes256CbcSha` | **`ecc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `TLSEcdheEcdsaWithAes256CbcSha` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `TLSEcdheEcdsaWithAes256CbcSha` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `HashFunc` | `method` | `TLSEcdheEcdsaWithAes256CbcSha` | **`hashFunc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AuthenticationType` | `method` | `TLSEcdheEcdsaWithAes256CbcSha` | **`authenticationType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `IsInitialized` | `method` | `TLSEcdheEcdsaWithAes256CbcSha` | **`isInitialized()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Init` | `method` | `TLSEcdheEcdsaWithAes256CbcSha` | **`init()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Encrypt` | `method` | `TLSEcdheEcdsaWithAes256CbcSha` | **`encrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Decrypt` | `method` | `TLSEcdheEcdsaWithAes256CbcSha` | **`decrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TLSEcdheEcdsaWithAes256GcmSha384` | `struct` | *(top-level)* | **`TlsEcdheEcdsaWithAes256GcmSha384`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `TLSEcdheEcdsaWithAes256GcmSha384` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `TLSEcdheEcdsaWithAes256GcmSha384` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `HashFunc` | `method` | `TLSEcdheEcdsaWithAes256GcmSha384` | **`hashFunc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Init` | `method` | `TLSEcdheEcdsaWithAes256GcmSha384` | **`init()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TLSEcdhePskWithAes128CbcSha256` | `struct` | *(top-level)* | **`TlsEcdhePskWithAes128CbcSha256`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateType` | `method` | `TLSEcdhePskWithAes128CbcSha256` | **`certificateType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `KeyExchangeAlgorithm` | `method` | `TLSEcdhePskWithAes128CbcSha256` | **`keyExchangeAlgorithm()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ECC` | `method` | `TLSEcdhePskWithAes128CbcSha256` | **`ecc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `TLSEcdhePskWithAes128CbcSha256` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `TLSEcdhePskWithAes128CbcSha256` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `HashFunc` | `method` | `TLSEcdhePskWithAes128CbcSha256` | **`hashFunc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AuthenticationType` | `method` | `TLSEcdhePskWithAes128CbcSha256` | **`authenticationType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `IsInitialized` | `method` | `TLSEcdhePskWithAes128CbcSha256` | **`isInitialized()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Init` | `method` | `TLSEcdhePskWithAes128CbcSha256` | **`init()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Encrypt` | `method` | `TLSEcdhePskWithAes128CbcSha256` | **`encrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Decrypt` | `method` | `TLSEcdhePskWithAes128CbcSha256` | **`decrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewTLSEcdhePskWithAes128CbcSha256` | `func` | *(top-level)* | **`TlsEcdhePskWithAes128CbcSha256()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TLSEcdheRsaWithAes128GcmSha256` | `struct` | *(top-level)* | **`TlsEcdheRsaWithAes128GcmSha256`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateType` | `method` | `TLSEcdheRsaWithAes128GcmSha256` | **`certificateType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `TLSEcdheRsaWithAes128GcmSha256` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `TLSEcdheRsaWithAes128GcmSha256` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TLSEcdheRsaWithAes256CbcSha` | `struct` | *(top-level)* | **`TlsEcdheRsaWithAes256CbcSha`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateType` | `method` | `TLSEcdheRsaWithAes256CbcSha` | **`certificateType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `TLSEcdheRsaWithAes256CbcSha` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `TLSEcdheRsaWithAes256CbcSha` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TLSEcdheRsaWithAes256GcmSha384` | `struct` | *(top-level)* | **`TlsEcdheRsaWithAes256GcmSha384`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateType` | `method` | `TLSEcdheRsaWithAes256GcmSha384` | **`certificateType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `TLSEcdheRsaWithAes256GcmSha384` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `TLSEcdheRsaWithAes256GcmSha384` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TLSPskWithAes128CbcSha256` | `struct` | *(top-level)* | **`TlsPskWithAes128CbcSha256`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateType` | `method` | `TLSPskWithAes128CbcSha256` | **`certificateType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `KeyExchangeAlgorithm` | `method` | `TLSPskWithAes128CbcSha256` | **`keyExchangeAlgorithm()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ECC` | `method` | `TLSPskWithAes128CbcSha256` | **`ecc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `TLSPskWithAes128CbcSha256` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `TLSPskWithAes128CbcSha256` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `HashFunc` | `method` | `TLSPskWithAes128CbcSha256` | **`hashFunc()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AuthenticationType` | `method` | `TLSPskWithAes128CbcSha256` | **`authenticationType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `IsInitialized` | `method` | `TLSPskWithAes128CbcSha256` | **`isInitialized()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Init` | `method` | `TLSPskWithAes128CbcSha256` | **`init()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Encrypt` | `method` | `TLSPskWithAes128CbcSha256` | **`encrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Decrypt` | `method` | `TLSPskWithAes128CbcSha256` | **`decrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewTLSPskWithAes128Ccm` | `func` | *(top-level)* | **`TlsPskWithAes128Ccm()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewTLSPskWithAes128Ccm8` | `func` | *(top-level)* | **`TlsPskWithAes128Ccm8()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TLSPskWithAes128GcmSha256` | `struct` | *(top-level)* | **`TlsPskWithAes128GcmSha256`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CertificateType` | `method` | `TLSPskWithAes128GcmSha256` | **`certificateType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `KeyExchangeAlgorithm` | `method` | `TLSPskWithAes128GcmSha256` | **`keyExchangeAlgorithm()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `TLSPskWithAes128GcmSha256` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `TLSPskWithAes128GcmSha256` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AuthenticationType` | `method` | `TLSPskWithAes128GcmSha256` | **`authenticationType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewTLSPskWithAes256Ccm8` | `func` | *(top-level)* | **`TlsPskWithAes256Ccm8()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `KeyExchangeAlgorithm.Has` | `func` | *(top-level)* | **`has()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Closer` | `struct` | *(top-level)* | **`Closer`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Done` | `method` | `Closer` | **`done()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Err` | `method` | `Closer` | **`err()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Close` | `method` | `Closer` | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewCloser` | `func` | *(top-level)* | **`Closer()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewCloserWithParent` | `func` | *(top-level)* | **`CloserWithParent()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AddrPacket` | `struct` | *(top-level)* | **`AddrPacket`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `PacketBuffer` | `struct` | *(top-level)* | **`PacketBuffer`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `WriteTo` | `method` | `PacketBuffer` | **`writeTo()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ReadFrom` | `method` | `PacketBuffer` | **`readFrom()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Close` | `method` | `PacketBuffer` | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetReadDeadline` | `method` | `PacketBuffer` | **`setReadDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewPacketBuffer` | `func` | *(top-level)* | **`PacketBuffer()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ListenConfig` | `struct` | *(top-level)* | **`ListenConfig`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Backlog` | `field` | `ListenConfig` | **`backlog`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AcceptFilter` | `field` | `ListenConfig` | **`acceptFilter`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `DatagramRouter` | `field` | `ListenConfig` | **`datagramRouter`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ConnectionIdentifier` | `field` | `ListenConfig` | **`connectionIdentifier`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Listen` | `method` | `ListenConfig` | **`listen()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `PacketConn` | `struct` | *(top-level)* | **`PacketConn`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ReadFrom` | `method` | `PacketConn` | **`readFrom()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WriteTo` | `method` | `PacketConn` | **`writeTo()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Close` | `method` | `PacketConn` | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `LocalAddr` | `method` | `PacketConn` | **`localAddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetDeadline` | `method` | `PacketConn` | **`setDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetReadDeadline` | `method` | `PacketConn` | **`setReadDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetWriteDeadline` | `method` | `PacketConn` | **`setWriteDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BigEndianUint24` | `func` | *(top-level)* | **`bigEndianUint24()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `PutBigEndianUint24` | `func` | *(top-level)* | **`putBigEndianUint24()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `PutBigEndianUint48` | `func` | *(top-level)* | **`putBigEndianUint48()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Max` | `func` | *(top-level)* | **`max()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AddUint48` | `func` | *(top-level)* | **`addUint48()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CCM` | `interface` | *(top-level)* | **`Ccm`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MaxLength` | `method` | `CCM` | **`maxLength()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewCCM` | `func` | *(top-level)* | **`Ccm()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ccm.NonceSize` | `func` | *(top-level)* | **`nonceSize()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ccm.Overhead` | `func` | *(top-level)* | **`overhead()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ccm.MaxLength` | `func` | *(top-level)* | **`maxLength()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MaxNonceLength` | `func` | *(top-level)* | **`maxNonceLength()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ccm.Seal` | `func` | *(top-level)* | **`seal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ccm.Open` | `func` | *(top-level)* | **`open()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CBC` | `struct` | *(top-level)* | **`CBC`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Encrypt` | `method` | `CBC` | **`encrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Decrypt` | `method` | `CBC` | **`decrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewCBC` | `func` | *(top-level)* | **`CBC()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CCM` | `struct` | *(top-level)* | **`Ccm`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Encrypt` | `method` | `CCM` | **`encrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Decrypt` | `method` | `CCM` | **`decrypt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |

### 3.2. Pion SCTP Runtime (`github.com/pion/sctp`) — Marco G.5
*Destino Dart:* `packages/transpiled_pion_sctp/` (Runtime pendente: `association.go`, `stream.go`, filas e timers)
*Origem Go:* `go-ipfs-reference/pion-sctp/`

| Símbolo AST Go | Tipo Go | Escopo / Pai | Símbolo Dart Adaptado 1:1 | Regras AGENTS.md | Boilerplate Mandatório (Regra 10) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Association` | `struct` | *(top-level)* | **`Association`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Shutdown` | `method` | `Association` | **`shutdown()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Close` | `method` | `Association` | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Abort` | `method` | `Association` | **`abort()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BytesSent` | `method` | `Association` | **`bytesSent()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BytesReceived` | `method` | `Association` | **`bytesReceived()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MTU` | `method` | `Association` | **`mtu()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CWND` | `method` | `Association` | **`cwnd()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `RWND` | `method` | `Association` | **`rWND()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SRTT` | `method` | `Association` | **`sRtt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `OpenStream` | `method` | `Association` | **`openStream()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AcceptStream` | `method` | `Association` | **`acceptStream()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BufferedAmount` | `method` | `Association` | **`bufferedAmount()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MaxMessageSize` | `method` | `Association` | **`maxMessageSize()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetMaxMessageSize` | `method` | `Association` | **`setMaxMessageSize()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Config` | `struct` | *(top-level)* | **`Config`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Name` | `field` | `Config` | **`name`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `NetConn` | `field` | `Config` | **`netConn`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MaxReceiveBufferSize` | `field` | `Config` | **`maxReceiveBufferSize`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MaxMessageSize` | `field` | `Config` | **`maxMessageSize`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `EnableZeroChecksum` | `field` | `Config` | **`enableZeroChecksum`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `LoggerFactory` | `field` | `Config` | **`loggerFactory`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `BlockWrite` | `field` | `Config` | **`blockWrite`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MTU` | `field` | `Config` | **`mtu`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `RTOMax` | `field` | `Config` | **`rTOMax`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MinCwnd` | `field` | `Config` | **`minCwnd`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `FastRtxWnd` | `field` | `Config` | **`fastRtxWnd`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CwndCAStep` | `field` | `Config` | **`cwndCAStep`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Server` | `func` | *(top-level)* | **`server()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Client` | `func` | *(top-level)* | **`client()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkAbort.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkCookieAck.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkError.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkForwardTSN.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkHeartbeat.Marshal` | `func` | *(top-level)* | **`marshal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkInit.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkInitAck.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkInitCommon.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `PayloadProtocolIdentifier.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkPayloadData.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkReconfig.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `gapAckBlock.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkSelectiveAck.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkShutdown.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkShutdownAck.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkShutdownComplete.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkHeader.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `chunkType.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | `Golang.Byte` (`package:boilerplate/fixed_types/golang.dart`) |
| `errorCauseCode.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `errorCauseHeader.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `errorCauseInvalidMandatoryParameter.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `errorCauseProtocolViolation.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `errorCauseUnrecognizedChunkType.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `errorCauseUserInitiatedAbort.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `packet.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TryMarshalUnmarshal` | `func` | *(top-level)* | **`tryMarshalUnmarshal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `reconfigResult.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `hmacAlgorithm.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `paramStateCookie.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `paramHeader.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `paramType.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Len` | `func` | *(top-level)* | **`len()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `PushBack` | `func` | *(top-level)* | **`pushBack()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `PopFront` | `func` | *(top-level)* | **`popFront()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Front` | `func` | *(top-level)* | **`front()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Back` | `func` | *(top-level)* | **`back()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `At` | `func` | *(top-level)* | **`at()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Stream` | `struct` | *(top-level)* | **`Stream`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `StreamIdentifier` | `method` | `Stream` | **`streamIdentifier()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetDefaultPayloadType` | `method` | `Stream` | **`setDefaultPayloadType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetReliabilityParams` | `method` | `Stream` | **`setReliabilityParams()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Read` | `method` | `Stream` | **`read()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ReadSCTP` | `method` | `Stream` | **`readSctp()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetReadDeadline` | `method` | `Stream` | **`setReadDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Write` | `method` | `Stream` | **`write()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WriteSCTP` | `method` | `Stream` | **`writeSctp()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetWriteDeadline` | `method` | `Stream` | **`setWriteDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetDeadline` | `method` | `Stream` | **`setDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Close` | `method` | `Stream` | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BufferedAmount` | `method` | `Stream` | **`bufferedAmount()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BufferedAmountLowThreshold` | `method` | `Stream` | **`bufferedAmountLowThreshold()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetBufferedAmountLowThreshold` | `method` | `Stream` | **`setBufferedAmountLowThreshold()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `OnBufferedAmountLow` | `method` | `Stream` | **`onBufferedAmountLow()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `State` | `method` | `Stream` | **`state()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `StreamState.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |

### 3.3. Pion ICE Lite (`github.com/pion/ice/v4`) — Marco G.5
*Destino Dart:* `packages/transpiled_pion_ice/` (Modo ICE lite com host candidates e UDP mux)
*Origem Go:* `go-ipfs-reference/pion-ice/`

| Símbolo AST Go | Tipo Go | Escopo / Pai | Símbolo Dart Adaptado 1:1 | Regras AGENTS.md | Boilerplate Mandatório (Regra 10) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `activeTCPConn.ReadFrom` | `func` | *(top-level)* | **`readFrom()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `activeTCPConn.WriteTo` | `func` | *(top-level)* | **`writeTo()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `activeTCPConn.Close` | `func` | *(top-level)* | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `activeTCPConn.LocalAddr` | `func` | *(top-level)* | **`localAddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `activeTCPConn.RemoteAddr` | `func` | *(top-level)* | **`remoteAddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `activeTCPConn.SetDeadline` | `func` | *(top-level)* | **`setDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `activeTCPConn.SetReadDeadline` | `func` | *(top-level)* | **`setReadDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `activeTCPConn.SetWriteDeadline` | `func` | *(top-level)* | **`setWriteDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `addrParseError.Error` | `func` | *(top-level)* | **`error()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ipConvertError.Error` | `func` | *(top-level)* | **`error()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Agent` | `struct` | *(top-level)* | **`Agent`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AddRemoteCandidate` | `method` | `Agent` | **`addRemoteCandidate()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetRemoteCandidates` | `method` | `Agent` | **`getRemoteCandidates()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetLocalCandidates` | `method` | `Agent` | **`getLocalCandidates()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetLocalUserCredentials` | `method` | `Agent` | **`getLocalUserCredentials()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetRemoteUserCredentials` | `method` | `Agent` | **`getRemoteUserCredentials()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Close` | `method` | `Agent` | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GracefulClose` | `method` | `Agent` | **`gracefulClose()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetSelectedCandidatePair` | `method` | `Agent` | **`getSelectedCandidatePair()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetRemoteCredentials` | `method` | `Agent` | **`setRemoteCredentials()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Restart` | `method` | `Agent` | **`restart()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `OnConnectionStateChange` | `method` | `Agent` | **`onConnectionStateChange()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `OnSelectedCandidatePairChange` | `method` | `Agent` | **`onSelectedCandidatePairChange()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `OnCandidate` | `method` | `Agent` | **`onCandidate()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetCandidatePairsStats` | `method` | `Agent` | **`getCandidatePairsStats()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetSelectedCandidatePairStats` | `method` | `Agent` | **`getSelectedCandidatePairStats()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetLocalCandidatesStats` | `method` | `Agent` | **`getLocalCandidatesStats()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetRemoteCandidatesStats` | `method` | `Agent` | **`getRemoteCandidatesStats()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GatherCandidates` | `method` | `Agent` | **`gatherCandidates()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Dial` | `method` | `Agent` | **`dial()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Accept` | `method` | `Agent` | **`accept()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewAgent` | `func` | *(top-level)* | **`Agent()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AgentConfig` | `struct` | *(top-level)* | **`AgentConfig`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Urls` | `field` | `AgentConfig` | **`urls`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `PortMin` | `field` | `AgentConfig` | **`portMin`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `PortMax` | `field` | `AgentConfig` | **`portMax`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `LocalUfrag` | `field` | `AgentConfig` | **`localUfrag`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `LocalPwd` | `field` | `AgentConfig` | **`localPwd`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MulticastDNSMode` | `field` | `AgentConfig` | **`multicastDnsMode`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MulticastDNSHostName` | `field` | `AgentConfig` | **`multicastDnsHostName`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `DisconnectedTimeout` | `field` | `AgentConfig` | **`disconnectedTimeout`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `FailedTimeout` | `field` | `AgentConfig` | **`failedTimeout`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `KeepaliveInterval` | `field` | `AgentConfig` | **`keepaliveInterval`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CheckInterval` | `field` | `AgentConfig` | **`checkInterval`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `NetworkTypes` | `field` | `AgentConfig` | **`networkTypes`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CandidateTypes` | `field` | `AgentConfig` | **`candidateTypes`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `LoggerFactory` | `field` | `AgentConfig` | **`loggerFactory`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MaxBindingRequests` | `field` | `AgentConfig` | **`maxBindingRequests`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Lite` | `field` | `AgentConfig` | **`lite`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `NAT1To1IPCandidateType` | `field` | `AgentConfig` | **`nat1To1IpCandidateType`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `NAT1To1IPs` | `field` | `AgentConfig` | **`nat1To1Ips`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `HostAcceptanceMinWait` | `field` | `AgentConfig` | **`hostAcceptanceMinWait`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SrflxAcceptanceMinWait` | `field` | `AgentConfig` | **`srflxAcceptanceMinWait`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `PrflxAcceptanceMinWait` | `field` | `AgentConfig` | **`prflxAcceptanceMinWait`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `RelayAcceptanceMinWait` | `field` | `AgentConfig` | **`relayAcceptanceMinWait`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `STUNGatherTimeout` | `field` | `AgentConfig` | **`stunGatherTimeout`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Net` | `field` | `AgentConfig` | **`net`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `InterfaceFilter` | `field` | `AgentConfig` | **`interfaceFilter`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `IPFilter` | `field` | `AgentConfig` | **`ipFilter`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `InsecureSkipVerify` | `field` | `AgentConfig` | **`insecureSkipVerify`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `TCPMux` | `field` | `AgentConfig` | **`tcpMux`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `UDPMux` | `field` | `AgentConfig` | **`udpMux`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `UDPMuxSrflx` | `field` | `AgentConfig` | **`udpMuxSrflx`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ProxyDialer` | `field` | `AgentConfig` | **`proxyDialer`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AcceptAggressiveNomination` | `field` | `AgentConfig` | **`acceptAggressiveNomination`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `IncludeLoopback` | `field` | `AgentConfig` | **`includeLoopback`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `TCPPriorityOffset` | `field` | `AgentConfig` | **`tcpPriorityOffset`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `DisableActiveTCP` | `field` | `AgentConfig` | **`disableActiveTcp`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `BindingRequestHandler` | `field` | `AgentConfig` | **`bindingRequestHandler`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `EnableUseCandidateCheckPriority` | `field` | `AgentConfig` | **`enableUseCandidateCheckPriority`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `handlerNotifier.Close` | `func` | *(top-level)* | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `handlerNotifier.EnqueueConnectionState` | `func` | *(top-level)* | **`enqueueConnectionState()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `handlerNotifier.EnqueueCandidate` | `func` | *(top-level)* | **`enqueueCandidate()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `handlerNotifier.EnqueueSelectedCandidatePair` | `func` | *(top-level)* | **`enqueueSelectedCandidatePair()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Candidate` | `interface` | *(top-level)* | **`Candidate`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Foundation` | `method` | `Candidate` | **`foundation()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ID` | `method` | `Candidate` | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Component` | `method` | `Candidate` | **`component()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetComponent` | `method` | `Candidate` | **`setComponent()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `LastReceived` | `method` | `Candidate` | **`lastReceived()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `LastSent` | `method` | `Candidate` | **`lastSent()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NetworkType` | `method` | `Candidate` | **`networkType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Address` | `method` | `Candidate` | **`address()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Port` | `method` | `Candidate` | **`port()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | `Golang.Uint16` (`package:boilerplate/fixed_types/golang.dart`) |
| `Priority` | `method` | `Candidate` | **`priority()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `RelatedAddress` | `method` | `Candidate` | **`relatedAddress()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Extensions` | `method` | `Candidate` | **`extensions()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetExtension` | `method` | `Candidate` | **`getExtension()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AddExtension` | `method` | `Candidate` | **`addExtension()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `RemoveExtension` | `method` | `Candidate` | **`removeExtension()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `Candidate` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Type` | `method` | `Candidate` | **`type()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TCPType` | `method` | `Candidate` | **`tcpType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Equal` | `method` | `Candidate` | **`equal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `DeepEqual` | `method` | `Candidate` | **`deepEqual()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Marshal` | `method` | `Candidate` | **`marshal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CandidateExtension` | `struct` | *(top-level)* | **`CandidateExtension`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Key` | `field` | `CandidateExtension` | **`key`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Value` | `field` | `CandidateExtension` | **`value`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Done` | `func` | *(top-level)* | **`done()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Err` | `func` | *(top-level)* | **`err()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Deadline` | `func` | *(top-level)* | **`deadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Value` | `func` | *(top-level)* | **`value()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.ID` | `func` | *(top-level)* | **`id()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Foundation` | `func` | *(top-level)* | **`foundation()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Address` | `func` | *(top-level)* | **`address()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Port` | `func` | *(top-level)* | **`port()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | `Golang.Uint16` (`package:boilerplate/fixed_types/golang.dart`) |
| `candidateBase.Type` | `func` | *(top-level)* | **`type()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.NetworkType` | `func` | *(top-level)* | **`networkType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Component` | `func` | *(top-level)* | **`component()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.SetComponent` | `func` | *(top-level)* | **`setComponent()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.LocalPreference` | `func` | *(top-level)* | **`localPreference()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.RelatedAddress` | `func` | *(top-level)* | **`relatedAddress()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.TCPType` | `func` | *(top-level)* | **`tcpType()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.TypePreference` | `func` | *(top-level)* | **`typePreference()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Priority` | `func` | *(top-level)* | **`priority()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Equal` | `func` | *(top-level)* | **`equal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.DeepEqual` | `func` | *(top-level)* | **`deepEqual()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.LastReceived` | `func` | *(top-level)* | **`lastReceived()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.LastSent` | `func` | *(top-level)* | **`lastSent()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Marshal` | `func` | *(top-level)* | **`marshal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.Extensions` | `func` | *(top-level)* | **`extensions()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.GetExtension` | `func` | *(top-level)* | **`getExtension()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.AddExtension` | `func` | *(top-level)* | **`addExtension()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `candidateBase.RemoveExtension` | `func` | *(top-level)* | **`removeExtension()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `UnmarshalCandidate` | `func` | *(top-level)* | **`unmarshalCandidate()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CandidateHost` | `struct` | *(top-level)* | **`CandidateHost`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CandidateHostConfig` | `struct` | *(top-level)* | **`CandidateHostConfig`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CandidateID` | `field` | `CandidateHostConfig` | **`candidateId`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Network` | `field` | `CandidateHostConfig` | **`network`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Address` | `field` | `CandidateHostConfig` | **`address`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Port` | `field` | `CandidateHostConfig` | **`port`** | Regra 2 (lowerCamelCase) | `Golang.Uint16` (`package:boilerplate/fixed_types/golang.dart`) |
| `Component` | `field` | `CandidateHostConfig` | **`component`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Priority` | `field` | `CandidateHostConfig` | **`priority`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Foundation` | `field` | `CandidateHostConfig` | **`foundation`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `TCPType` | `field` | `CandidateHostConfig` | **`tcpType`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `IsLocationTracked` | `field` | `CandidateHostConfig` | **`isLocationTracked`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `NewCandidateHost` | `func` | *(top-level)* | **`CandidateHost()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CandidatePeerReflexive` | `struct` | *(top-level)* | **`CandidatePeerReflexive`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CandidatePeerReflexiveConfig` | `struct` | *(top-level)* | **`CandidatePeerReflexiveConfig`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `CandidateID` | `field` | `CandidatePeerReflexiveConfig` | **`candidateId`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Network` | `field` | `CandidatePeerReflexiveConfig` | **`network`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Address` | `field` | `CandidatePeerReflexiveConfig` | **`address`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Port` | `field` | `CandidatePeerReflexiveConfig` | **`port`** | Regra 2 (lowerCamelCase) | `Golang.Uint16` (`package:boilerplate/fixed_types/golang.dart`) |
| `Component` | `field` | `CandidatePeerReflexiveConfig` | **`component`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Priority` | `field` | `CandidatePeerReflexiveConfig` | **`priority`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Foundation` | `field` | `CandidatePeerReflexiveConfig` | **`foundation`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `RelAddr` | `field` | `CandidatePeerReflexiveConfig` | **`relAddr`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `RelPort` | `field` | `CandidatePeerReflexiveConfig` | **`relPort`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |

### 3.4. Pion DataChannel (`github.com/pion/datachannel`) — Marco G.5
*Destino Dart:* `packages/transpiled_pion_datachannel/` (DCEP framing e canais SCTP)
*Origem Go:* `go-ipfs-reference/pion-datachannel/`

| Símbolo AST Go | Tipo Go | Escopo / Pai | Símbolo Dart Adaptado 1:1 | Regras AGENTS.md | Boilerplate Mandatório (Regra 10) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Config` | `struct` | *(top-level)* | **`Config`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ChannelType` | `field` | `Config` | **`channelType`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Negotiated` | `field` | `Config` | **`negotiated`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Priority` | `field` | `Config` | **`priority`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ReliabilityParameter` | `field` | `Config` | **`reliabilityParameter`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Label` | `field` | `Config` | **`label`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Protocol` | `field` | `Config` | **`protocol`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `LoggerFactory` | `field` | `Config` | **`loggerFactory`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `DataChannel` | `struct` | *(top-level)* | **`DataChannel`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Read` | `method` | `DataChannel` | **`read()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ReadDataChannel` | `method` | `DataChannel` | **`readDataChannel()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetReadDeadline` | `method` | `DataChannel` | **`setReadDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetWriteDeadline` | `method` | `DataChannel` | **`setWriteDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MessagesSent` | `method` | `DataChannel` | **`messagesSent()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MessagesReceived` | `method` | `DataChannel` | **`messagesReceived()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `OnOpen` | `method` | `DataChannel` | **`onOpen()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BytesSent` | `method` | `DataChannel` | **`bytesSent()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BytesReceived` | `method` | `DataChannel` | **`bytesReceived()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `StreamIdentifier` | `method` | `DataChannel` | **`streamIdentifier()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Write` | `method` | `DataChannel` | **`write()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WriteDataChannel` | `method` | `DataChannel` | **`writeDataChannel()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Close` | `method` | `DataChannel` | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BufferedAmount` | `method` | `DataChannel` | **`bufferedAmount()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BufferedAmountLowThreshold` | `method` | `DataChannel` | **`bufferedAmountLowThreshold()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetBufferedAmountLowThreshold` | `method` | `DataChannel` | **`setBufferedAmountLowThreshold()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `OnBufferedAmountLow` | `method` | `DataChannel` | **`onBufferedAmountLow()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ReadDeadliner` | `interface` | *(top-level)* | **`ReadDeadliner`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SetReadDeadline` | `method` | `ReadDeadliner` | **`setReadDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ReadWriteCloser` | `interface` | *(top-level)* | **`ReadWriteCloser`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ReadWriteCloserDeadliner` | `interface` | *(top-level)* | **`ReadWriteCloserDeadliner`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Reader` | `interface` | *(top-level)* | **`Reader`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ReadDataChannel` | `method` | `Reader` | **`readDataChannel()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WriteDeadliner` | `interface` | *(top-level)* | **`WriteDeadliner`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SetWriteDeadline` | `method` | `WriteDeadliner` | **`setWriteDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Writer` | `interface` | *(top-level)* | **`Writer`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `WriteDataChannel` | `method` | `Writer` | **`writeDataChannel()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Dial` | `func` | *(top-level)* | **`dial()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Client` | `func` | *(top-level)* | **`client()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Accept` | `func` | *(top-level)* | **`accept()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Server` | `func` | *(top-level)* | **`server()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `messageType.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TryMarshalUnmarshal` | `func` | *(top-level)* | **`tryMarshalUnmarshal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `channelAck.Marshal` | `func` | *(top-level)* | **`marshal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `channelAck.Unmarshal` | `func` | *(top-level)* | **`unmarshal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `channelAck.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ChannelType.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `channelOpen.Marshal` | `func` | *(top-level)* | **`marshal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `channelOpen.Unmarshal` | `func` | *(top-level)* | **`unmarshal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `channelOpen.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |

### 3.5. libp2p WebRTC Transport (`go-libp2p/p2p/transport/webrtc`) — Marco G.5
*Destino Dart:* `packages/transpiled_libp2p/lib/src/p2p/transport/webrtc/`
*Origem Go:* `go-ipfs-reference/go-libp2p/p2p/transport/webrtc/`

| Símbolo AST Go | Tipo Go | Escopo / Pai | Símbolo Dart Adaptado 1:1 | Regras AGENTS.md | Boilerplate Mandatório (Regra 10) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `deterministicSigner.Public` | `func` | *(top-level)* | **`public()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `deterministicSigner.Sign` | `func` | *(top-level)* | **`sign()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `failingReader.Read` | `func` | *(top-level)* | **`read()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `errConnectionTimeout.Error` | `func` | *(top-level)* | **`error()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `errConnectionTimeout.Timeout` | `func` | *(top-level)* | **`timeout()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | `Golang.Int64` (`package:boilerplate/fixed_types/golang.dart`) |
| `errConnectionTimeout.Temporary` | `func` | *(top-level)* | **`temporary()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.ConnState` | `func` | *(top-level)* | **`connState()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.Close` | `func` | *(top-level)* | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.As` | `func` | *(top-level)* | **`as()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.CloseWithError` | `func` | *(top-level)* | **`closeWithError()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.IsClosed` | `func` | *(top-level)* | **`isClosed()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.OpenStream` | `func` | *(top-level)* | **`openStream()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.AcceptStream` | `func` | *(top-level)* | **`acceptStream()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.LocalPeer` | `func` | *(top-level)* | **`localPeer()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.RemotePeer` | `func` | *(top-level)* | **`remotePeer()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.RemotePublicKey` | `func` | *(top-level)* | **`remotePublicKey()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.LocalMultiaddr` | `func` | *(top-level)* | **`localMultiaddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.RemoteMultiaddr` | `func` | *(top-level)* | **`remoteMultiaddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.Scope` | `func` | *(top-level)* | **`scope()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connection.Transport` | `func` | *(top-level)* | **`transport()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connMultiaddrs.LocalMultiaddr` | `func` | *(top-level)* | **`localMultiaddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `connMultiaddrs.RemoteMultiaddr` | `func` | *(top-level)* | **`remoteMultiaddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `listener.Accept` | `func` | *(top-level)* | **`accept()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `listener.Close` | `func` | *(top-level)* | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `listener.Addr` | `func` | *(top-level)* | **`addr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | `net.Ip` / `netip.Addr` (`boilerplate/net` ou `net_netip`) |
| `listener.Multiaddr` | `func` | *(top-level)* | **`multiaddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | `Multiaddr` (`package:transpiled_multiaddr/multiaddr.dart`) |
| `pionLogger.Debug` | `func` | *(top-level)* | **`debug()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `pionLogger.Debugf` | `func` | *(top-level)* | **`debugf()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `pionLogger.Error` | `func` | *(top-level)* | **`error()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `pionLogger.Errorf` | `func` | *(top-level)* | **`errorf()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `pionLogger.Info` | `func` | *(top-level)* | **`info()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `pionLogger.Infof` | `func` | *(top-level)* | **`infof()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `pionLogger.Warn` | `func` | *(top-level)* | **`warn()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `pionLogger.Warnf` | `func` | *(top-level)* | **`warnf()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `pionLogger.Trace` | `func` | *(top-level)* | **`trace()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `pionLogger.Tracef` | `func` | *(top-level)* | **`tracef()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `loggerFactory.NewLogger` | `func` | *(top-level)* | **`newLogger()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `stream.Close` | `func` | *(top-level)* | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `stream.Reset` | `func` | *(top-level)* | **`reset()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `stream.ResetWithError` | `func` | *(top-level)* | **`resetWithError()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `stream.SetDeadline` | `func` | *(top-level)* | **`setDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `stream.Read` | `func` | *(top-level)* | **`read()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `stream.SetReadDeadline` | `func` | *(top-level)* | **`setReadDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `stream.CloseRead` | `func` | *(top-level)* | **`closeRead()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `stream.Write` | `func` | *(top-level)* | **`write()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `stream.SetWriteDeadline` | `func` | *(top-level)* | **`setWriteDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `stream.CloseWrite` | `func` | *(top-level)* | **`closeWrite()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WebRTCTransport` | `struct` | *(top-level)* | **`WebRTCTransport`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ListenOrder` | `method` | `WebRTCTransport` | **`listenOrder()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Protocols` | `method` | `WebRTCTransport` | **`protocols()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Proxy` | `method` | `WebRTCTransport` | **`proxy()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CanDial` | `method` | `WebRTCTransport` | **`canDial()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Listen` | `method` | `WebRTCTransport` | **`listen()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Dial` | `method` | `WebRTCTransport` | **`dial()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AddCertHashes` | `method` | `WebRTCTransport` | **`addCertHashes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithDialerVersion` | `func` | *(top-level)* | **`withDialerVersion()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `New` | `func` | *(top-level)* | **`new()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `netConnWrapper.LocalAddr` | `func` | *(top-level)* | **`localAddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `netConnWrapper.RemoteAddr` | `func` | *(top-level)* | **`remoteAddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `netConnWrapper.Close` | `func` | *(top-level)* | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `IsWebRTCDirectMultiaddr` | `func` | *(top-level)* | **`isWebRTCDirectMultiaddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Message` | `struct` | *(top-level)* | **`Message`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Flag` | `field` | `Message` | **`flag`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Message` | `field` | `Message` | **`message`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ErrorCode` | `field` | `Message` | **`errorCode`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Reset` | `method` | `Message` | **`reset()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `String` | `method` | `Message` | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ProtoMessage` | `method` | `Message` | **`protoMessage()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ProtoReflect` | `method` | `Message` | **`protoReflect()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Descriptor` | `method` | `Message` | **`descriptor()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetFlag` | `method` | `Message` | **`getFlag()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetMessage` | `method` | `Message` | **`getMessage()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetErrorCode` | `method` | `Message` | **`getErrorCode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Message_Flag.Enum` | `func` | *(top-level)* | **`enum()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Message_Flag.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Message_Flag.Descriptor` | `func` | *(top-level)* | **`descriptor()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Message_Flag.Type` | `func` | *(top-level)* | **`type()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Message_Flag.Number` | `func` | *(top-level)* | **`number()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Message_Flag.UnmarshalJSON` | `func` | *(top-level)* | **`unmarshalJson()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Message_Flag.EnumDescriptor` | `func` | *(top-level)* | **`enumDescriptor()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Candidate` | `struct` | *(top-level)* | **`Candidate`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `LocalUfrag` | `field` | `Candidate` | **`localUfrag`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `RemoteUfrag` | `field` | `Candidate` | **`remoteUfrag`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `RemotePwd` | `field` | `Candidate` | **`remotePwd`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Addr` | `field` | `Candidate` | **`addr`** | Regra 2 (lowerCamelCase) | `net.Ip` / `netip.Addr` (`boilerplate/net` ou `net_netip`) |
| `UDPMux` | `struct` | *(top-level)* | **`UdpMux`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Start` | `method` | `UDPMux` | **`start()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetListenAddresses` | `method` | `UDPMux` | **`getListenAddresses()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetConn` | `method` | `UDPMux` | **`getConn()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Close` | `method` | `UDPMux` | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Accept` | `method` | `UDPMux` | **`accept()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `RemoveConnByUfrag` | `method` | `UDPMux` | **`removeConnByUfrag()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewUDPMux` | `func` | *(top-level)* | **`UdpMux()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `muxedConnection.Push` | `func` | *(top-level)* | **`push()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `muxedConnection.ReadFrom` | `func` | *(top-level)* | **`readFrom()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `muxedConnection.WriteTo` | `func` | *(top-level)* | **`writeTo()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `muxedConnection.Close` | `func` | *(top-level)* | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `muxedConnection.LocalAddr` | `func` | *(top-level)* | **`localAddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `muxedConnection.SetDeadline` | `func` | *(top-level)* | **`setDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `muxedConnection.SetReadDeadline` | `func` | *(top-level)* | **`setReadDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `muxedConnection.SetWriteDeadline` | `func` | *(top-level)* | **`setWriteDeadline()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |

### 3.6. Resource Manager (`go-libp2p/p2p/host/resource-manager`) — Fase D
*Destino Dart:* `packages/transpiled_libp2p/lib/src/p2p/host/resource_manager/`
*Origem Go:* `go-ipfs-reference/go-libp2p/p2p/host/resource-manager/`

| Símbolo AST Go | Tipo Go | Escopo / Pai | Símbolo Dart Adaptado 1:1 | Regras AGENTS.md | Boilerplate Mandatório (Regra 10) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Allowlist` | `struct` | *(top-level)* | **`Allowlist`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Add` | `method` | `Allowlist` | **`add()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Remove` | `method` | `Allowlist` | **`remove()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Allowed` | `method` | `Allowlist` | **`allowed()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AllowedPeerAndMultiaddr` | `method` | `Allowlist` | **`allowedPeerAndMultiaddr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithAllowlistedMultiaddrs` | `func` | *(top-level)* | **`withAllowlistedMultiaddrs()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ConnLimitPerSubnet` | `struct` | *(top-level)* | **`ConnLimitPerSubnet`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `PrefixLength` | `field` | `ConnLimitPerSubnet` | **`prefixLength`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ConnCount` | `field` | `ConnLimitPerSubnet` | **`connCount`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `NetworkPrefixLimit` | `struct` | *(top-level)* | **`NetworkPrefixLimit`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Network` | `field` | `NetworkPrefixLimit` | **`network`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ConnCount` | `field` | `NetworkPrefixLimit` | **`connCount`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `WithNetworkPrefixLimit` | `func` | *(top-level)* | **`withNetworkPrefixLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithLimitPerSubnet` | `func` | *(top-level)* | **`withLimitPerSubnet()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WithConnRateLimiters` | `func` | *(top-level)* | **`withConnRateLimiters()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ErrMemoryLimitExceeded` | `struct` | *(top-level)* | **`MemoryLimitExceededException`** | Regra 13 (Exception naming) | Dart nativo (`int`/`String`/`bool`) |
| `Error` | `method` | `ErrMemoryLimitExceeded` | **`error()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Unwrap` | `method` | `ErrMemoryLimitExceeded` | **`unwrap()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ErrStreamOrConnLimitExceeded` | `struct` | *(top-level)* | **`StreamOrConnLimitExceededException`** | Regra 13 (Exception naming) | Dart nativo (`int`/`String`/`bool`) |
| `Error` | `method` | `ErrStreamOrConnLimitExceeded` | **`error()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Unwrap` | `method` | `ErrStreamOrConnLimitExceeded` | **`unwrap()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ResourceManagerStat` | `struct` | *(top-level)* | **`ResourceManagerStat`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `System` | `field` | `ResourceManagerStat` | **`system`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Transient` | `field` | `ResourceManagerStat` | **`transient`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Services` | `field` | `ResourceManagerStat` | **`services`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Protocols` | `field` | `ResourceManagerStat` | **`protocols`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Peers` | `field` | `ResourceManagerStat` | **`peers`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ResourceManagerState` | `interface` | *(top-level)* | **`ResourceManagerState`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ListServices` | `method` | `ResourceManagerState` | **`listServices()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ListProtocols` | `method` | `ResourceManagerState` | **`listProtocols()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ListPeers` | `method` | `ResourceManagerState` | **`listPeers()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Stat` | `method` | `ResourceManagerState` | **`stat()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ResourceScopeLimiter` | `interface` | *(top-level)* | **`ResourceScopeLimiter`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Limit` | `method` | `ResourceScopeLimiter` | **`limit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetLimit` | `method` | `ResourceScopeLimiter` | **`setLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `resourceScope.Limit` | `func` | *(top-level)* | **`limit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `resourceScope.SetLimit` | `func` | *(top-level)* | **`setLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `protocolScope.SetLimit` | `func` | *(top-level)* | **`setLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `peerScope.SetLimit` | `func` | *(top-level)* | **`setLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `resourceManager.ListServices` | `func` | *(top-level)* | **`listServices()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `resourceManager.ListProtocols` | `func` | *(top-level)* | **`listProtocols()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `resourceManager.ListPeers` | `func` | *(top-level)* | **`listPeers()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `resourceManager.Stat` | `func` | *(top-level)* | **`stat()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `resourceManager.GetConnLimit` | `func` | *(top-level)* | **`getConnLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BaseLimit` | `struct` | *(top-level)* | **`BaseLimit`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Streams` | `field` | `BaseLimit` | **`streams`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `StreamsInbound` | `field` | `BaseLimit` | **`streamsInbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `StreamsOutbound` | `field` | `BaseLimit` | **`streamsOutbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Conns` | `field` | `BaseLimit` | **`conns`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ConnsInbound` | `field` | `BaseLimit` | **`connsInbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ConnsOutbound` | `field` | `BaseLimit` | **`connsOutbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `FD` | `field` | `BaseLimit` | **`fd`** | Regra 2 (lowerCamelCase) | `internal_poll.Fd` (`package:boilerplate/internal_poll/golang.dart`) |
| `Memory` | `field` | `BaseLimit` | **`memory`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ToResourceLimits` | `method` | `BaseLimit` | **`toResourceLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Apply` | `method` | `BaseLimit` | **`apply()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetStreamLimit` | `method` | `BaseLimit` | **`getStreamLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetStreamTotalLimit` | `method` | `BaseLimit` | **`getStreamTotalLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetConnLimit` | `method` | `BaseLimit` | **`getConnLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetConnTotalLimit` | `method` | `BaseLimit` | **`getConnTotalLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetFDLimit` | `method` | `BaseLimit` | **`getFdLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetMemoryLimit` | `method` | `BaseLimit` | **`getMemoryLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BaseLimitIncrease` | `struct` | *(top-level)* | **`BaseLimitIncrease`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Streams` | `field` | `BaseLimitIncrease` | **`streams`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `StreamsInbound` | `field` | `BaseLimitIncrease` | **`streamsInbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `StreamsOutbound` | `field` | `BaseLimitIncrease` | **`streamsOutbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Conns` | `field` | `BaseLimitIncrease` | **`conns`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ConnsInbound` | `field` | `BaseLimitIncrease` | **`connsInbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ConnsOutbound` | `field` | `BaseLimitIncrease` | **`connsOutbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Memory` | `field` | `BaseLimitIncrease` | **`memory`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `FDFraction` | `field` | `BaseLimitIncrease` | **`fdFraction`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Apply` | `method` | `BaseLimitIncrease` | **`apply()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Limit` | `interface` | *(top-level)* | **`Limit`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `GetMemoryLimit` | `method` | `Limit` | **`getMemoryLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetStreamLimit` | `method` | `Limit` | **`getStreamLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetStreamTotalLimit` | `method` | `Limit` | **`getStreamTotalLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetConnLimit` | `method` | `Limit` | **`getConnLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetConnTotalLimit` | `method` | `Limit` | **`getConnTotalLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetFDLimit` | `method` | `Limit` | **`getFdLimit()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Limiter` | `interface` | *(top-level)* | **`Limiter`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `GetSystemLimits` | `method` | `Limiter` | **`getSystemLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetTransientLimits` | `method` | `Limiter` | **`getTransientLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetAllowlistedSystemLimits` | `method` | `Limiter` | **`getAllowlistedSystemLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetAllowlistedTransientLimits` | `method` | `Limiter` | **`getAllowlistedTransientLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetServiceLimits` | `method` | `Limiter` | **`getServiceLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetServicePeerLimits` | `method` | `Limiter` | **`getServicePeerLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetProtocolLimits` | `method` | `Limiter` | **`getProtocolLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetProtocolPeerLimits` | `method` | `Limiter` | **`getProtocolPeerLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetPeerLimits` | `method` | `Limiter` | **`getPeerLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetStreamLimits` | `method` | `Limiter` | **`getStreamLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetConnLimits` | `method` | `Limiter` | **`getConnLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewDefaultLimiterFromJSON` | `func` | *(top-level)* | **`DefaultLimiterFromJson()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewLimiterFromJSON` | `func` | *(top-level)* | **`LimiterFromJson()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewFixedLimiter` | `func` | *(top-level)* | **`FixedLimiter()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `fixedLimiter.GetSystemLimits` | `func` | *(top-level)* | **`getSystemLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `fixedLimiter.GetTransientLimits` | `func` | *(top-level)* | **`getTransientLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `fixedLimiter.GetAllowlistedSystemLimits` | `func` | *(top-level)* | **`getAllowlistedSystemLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `fixedLimiter.GetAllowlistedTransientLimits` | `func` | *(top-level)* | **`getAllowlistedTransientLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `fixedLimiter.GetServiceLimits` | `func` | *(top-level)* | **`getServiceLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `fixedLimiter.GetServicePeerLimits` | `func` | *(top-level)* | **`getServicePeerLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `fixedLimiter.GetProtocolLimits` | `func` | *(top-level)* | **`getProtocolLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `fixedLimiter.GetProtocolPeerLimits` | `func` | *(top-level)* | **`getProtocolPeerLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `fixedLimiter.GetPeerLimits` | `func` | *(top-level)* | **`getPeerLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `fixedLimiter.GetStreamLimits` | `func` | *(top-level)* | **`getStreamLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `fixedLimiter.GetConnLimits` | `func` | *(top-level)* | **`getConnLimits()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ConcreteLimitConfig` | `struct` | *(top-level)* | **`ConcreteLimitConfig`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ToPartialLimitConfig` | `method` | `ConcreteLimitConfig` | **`toPartialLimitConfig()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `PartialLimitConfig` | `struct` | *(top-level)* | **`PartialLimitConfig`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `System` | `field` | `PartialLimitConfig` | **`system`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Transient` | `field` | `PartialLimitConfig` | **`transient`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AllowlistedSystem` | `field` | `PartialLimitConfig` | **`allowlistedSystem`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AllowlistedTransient` | `field` | `PartialLimitConfig` | **`allowlistedTransient`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ServiceDefault` | `field` | `PartialLimitConfig` | **`serviceDefault`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Service` | `field` | `PartialLimitConfig` | **`service`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ServicePeerDefault` | `field` | `PartialLimitConfig` | **`servicePeerDefault`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ServicePeer` | `field` | `PartialLimitConfig` | **`servicePeer`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ProtocolDefault` | `field` | `PartialLimitConfig` | **`protocolDefault`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Protocol` | `field` | `PartialLimitConfig` | **`protocol`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ProtocolPeerDefault` | `field` | `PartialLimitConfig` | **`protocolPeerDefault`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ProtocolPeer` | `field` | `PartialLimitConfig` | **`protocolPeer`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `PeerDefault` | `field` | `PartialLimitConfig` | **`peerDefault`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Peer` | `field` | `PartialLimitConfig` | **`peer`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Conn` | `field` | `PartialLimitConfig` | **`conn`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Stream` | `field` | `PartialLimitConfig` | **`stream`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MarshalJSON` | `method` | `PartialLimitConfig` | **`marshalJson()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Apply` | `method` | `PartialLimitConfig` | **`apply()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Build` | `method` | `PartialLimitConfig` | **`build()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ResourceLimits` | `struct` | *(top-level)* | **`ResourceLimits`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Streams` | `field` | `ResourceLimits` | **`streams`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `StreamsInbound` | `field` | `ResourceLimits` | **`streamsInbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `StreamsOutbound` | `field` | `ResourceLimits` | **`streamsOutbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Conns` | `field` | `ResourceLimits` | **`conns`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ConnsInbound` | `field` | `ResourceLimits` | **`connsInbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ConnsOutbound` | `field` | `ResourceLimits` | **`connsOutbound`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `FD` | `field` | `ResourceLimits` | **`fd`** | Regra 2 (lowerCamelCase) | `internal_poll.Fd` (`package:boilerplate/internal_poll/golang.dart`) |
| `Memory` | `field` | `ResourceLimits` | **`memory`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `IsDefault` | `method` | `ResourceLimits` | **`isDefault()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ToMaybeNilPtr` | `method` | `ResourceLimits` | **`toMaybeNilPtr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Apply` | `method` | `ResourceLimits` | **`apply()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Build` | `method` | `ResourceLimits` | **`build()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ScalingLimitConfig` | `struct` | *(top-level)* | **`ScalingLimitConfig`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SystemBaseLimit` | `field` | `ScalingLimitConfig` | **`systemBaseLimit`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SystemLimitIncrease` | `field` | `ScalingLimitConfig` | **`systemLimitIncrease`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `TransientBaseLimit` | `field` | `ScalingLimitConfig` | **`transientBaseLimit`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `TransientLimitIncrease` | `field` | `ScalingLimitConfig` | **`transientLimitIncrease`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AllowlistedSystemBaseLimit` | `field` | `ScalingLimitConfig` | **`allowlistedSystemBaseLimit`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AllowlistedSystemLimitIncrease` | `field` | `ScalingLimitConfig` | **`allowlistedSystemLimitIncrease`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AllowlistedTransientBaseLimit` | `field` | `ScalingLimitConfig` | **`allowlistedTransientBaseLimit`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AllowlistedTransientLimitIncrease` | `field` | `ScalingLimitConfig` | **`allowlistedTransientLimitIncrease`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ServiceBaseLimit` | `field` | `ScalingLimitConfig` | **`serviceBaseLimit`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ServiceLimitIncrease` | `field` | `ScalingLimitConfig` | **`serviceLimitIncrease`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |

### 3.7. Codecs IPLD: DAG-CBOR & CBOR (`go-ipld-prime/codec/dagcbor`)
*Destino Dart:* `packages/transpiled_ipld_prime/lib/src/codec/dagcbor/`, `cbor/`
*Origem Go:* `go-ipfs-reference/go-ipld-prime/codec/`

| Símbolo AST Go | Tipo Go | Escopo / Pai | Símbolo Dart Adaptado 1:1 | Regras AGENTS.md | Boilerplate Mandatório (Regra 10) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `EncodeOptions` | `struct` | *(top-level)* | **`EncodeOptions`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AllowLinks` | `field` | `EncodeOptions` | **`allowLinks`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MapSortMode` | `field` | `EncodeOptions` | **`mapSortMode`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Encode` | `method` | `EncodeOptions` | **`encode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Marshal` | `func` | *(top-level)* | **`marshal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `EncodedLength` | `func` | *(top-level)* | **`encodedLength()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Decode` | `func` | *(top-level)* | **`decode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Encode` | `func` | *(top-level)* | **`encode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `DecodeOptions` | `struct` | *(top-level)* | **`DecodeOptions`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AllowLinks` | `field` | `DecodeOptions` | **`allowLinks`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `RelaxedDecode` | `field` | `DecodeOptions` | **`relaxedDecode`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `DontParseBeyondEnd` | `field` | `DecodeOptions` | **`dontParseBeyondEnd`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AllocationBudget` | `field` | `DecodeOptions` | **`allocationBudget`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MaxCollectionPrealloc` | `field` | `DecodeOptions` | **`maxCollectionPrealloc`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `MaxDepth` | `field` | `DecodeOptions` | **`maxDepth`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Decode` | `method` | `DecodeOptions` | **`decode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Unmarshal` | `func` | *(top-level)* | **`unmarshal()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |

### 3.8. Codecs IPLD: DAG-JOSE & IPLD-GIT
*Destino Dart:* `packages/transpiled_go_dag_jose/`, `packages/transpiled_go_ipld_git/`

| Símbolo AST Go | Tipo Go | Escopo / Pai | Símbolo Dart Adaptado 1:1 | Regras AGENTS.md | Boilerplate Mandatório (Regra 10) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `_ErrorThunkAssembler.BeginMap` | `func` | *(top-level)* | **`beginMap()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_ErrorThunkAssembler.BeginList` | `func` | *(top-level)* | **`beginList()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_ErrorThunkAssembler.AssignNull` | `func` | *(top-level)* | **`assignNull()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_ErrorThunkAssembler.AssignBool` | `func` | *(top-level)* | **`assignBool()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_ErrorThunkAssembler.AssignInt` | `func` | *(top-level)* | **`assignInt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_ErrorThunkAssembler.AssignFloat` | `func` | *(top-level)* | **`assignFloat()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_ErrorThunkAssembler.AssignString` | `func` | *(top-level)* | **`assignString()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_ErrorThunkAssembler.AssignBytes` | `func` | *(top-level)* | **`assignBytes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_ErrorThunkAssembler.AssignLink` | `func` | *(top-level)* | **`assignLink()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_ErrorThunkAssembler.AssignNode` | `func` | *(top-level)* | **`assignNode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_ErrorThunkAssembler.Prototype` | `func` | *(top-level)* | **`prototype()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `DecodedRecipients__Itr` | `struct` | *(top-level)* | **`DecodedRecipients__Itr`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Next` | `method` | `DecodedRecipients__Itr` | **`next()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Done` | `method` | `DecodedRecipients__Itr` | **`done()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `DecodedSignatures__Itr` | `struct` | *(top-level)* | **`DecodedSignatures__Itr`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Next` | `method` | `DecodedSignatures__Itr` | **`next()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Done` | `method` | `DecodedSignatures__Itr` | **`done()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `EncodedRecipients__Itr` | `struct` | *(top-level)* | **`EncodedRecipients__Itr`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Next` | `method` | `EncodedRecipients__Itr` | **`next()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Done` | `method` | `EncodedRecipients__Itr` | **`done()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `EncodedSignatures__Itr` | `struct` | *(top-level)* | **`EncodedSignatures__Itr`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Next` | `method` | `EncodedSignatures__Itr` | **`next()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Done` | `method` | `EncodedSignatures__Itr` | **`done()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `List__Itr` | `struct` | *(top-level)* | **`List__Itr`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Next` | `method` | `List__Itr` | **`next()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Done` | `method` | `List__Itr` | **`done()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Map__Itr` | `struct` | *(top-level)* | **`Map__Itr`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Next` | `method` | `Map__Itr` | **`next()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Done` | `method` | `Map__Itr` | **`done()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any.AsInterface` | `func` | *(top-level)* | **`asInterface()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MaybeAny.IsNull` | `func` | *(top-level)* | **`isNull()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MaybeAny.IsAbsent` | `func` | *(top-level)* | **`isAbsent()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MaybeAny.Exists` | `func` | *(top-level)* | **`exists()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MaybeAny.AsNode` | `func` | *(top-level)* | **`asNode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MaybeAny.Must` | `func` | *(top-level)* | **`must()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.Kind` | `func` | *(top-level)* | **`kind()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.LookupByString` | `func` | *(top-level)* | **`lookupByString()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.LookupByNode` | `func` | *(top-level)* | **`lookupByNode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.LookupByIndex` | `func` | *(top-level)* | **`lookupByIndex()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.LookupBySegment` | `func` | *(top-level)* | **`lookupBySegment()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.MapIterator` | `func` | *(top-level)* | **`mapIterator()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__MapItr.Next` | `func` | *(top-level)* | **`next()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__MapItr.Done` | `func` | *(top-level)* | **`done()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.ListIterator` | `func` | *(top-level)* | **`listIterator()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.Length` | `func` | *(top-level)* | **`length()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.IsAbsent` | `func` | *(top-level)* | **`isAbsent()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.IsNull` | `func` | *(top-level)* | **`isNull()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.AsBool` | `func` | *(top-level)* | **`asBool()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.AsInt` | `func` | *(top-level)* | **`asInt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.AsFloat` | `func` | *(top-level)* | **`asFloat()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.AsString` | `func` | *(top-level)* | **`asString()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.AsBytes` | `func` | *(top-level)* | **`asBytes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.AsLink` | `func` | *(top-level)* | **`asLink()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.Prototype` | `func` | *(top-level)* | **`prototype()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Prototype.NewBuilder` | `func` | *(top-level)* | **`newBuilder()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Builder.Build` | `func` | *(top-level)* | **`build()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Builder.Reset` | `func` | *(top-level)* | **`reset()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.BeginMap` | `func` | *(top-level)* | **`beginMap()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.BeginList` | `func` | *(top-level)* | **`beginList()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.AssignNull` | `func` | *(top-level)* | **`assignNull()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.AssignBool` | `func` | *(top-level)* | **`assignBool()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.AssignInt` | `func` | *(top-level)* | **`assignInt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.AssignFloat` | `func` | *(top-level)* | **`assignFloat()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.AssignString` | `func` | *(top-level)* | **`assignString()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.AssignBytes` | `func` | *(top-level)* | **`assignBytes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.AssignLink` | `func` | *(top-level)* | **`assignLink()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.AssignNode` | `func` | *(top-level)* | **`assignNode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.Prototype` | `func` | *(top-level)* | **`prototype()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.AssembleEntry` | `func` | *(top-level)* | **`assembleEntry()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.AssembleKey` | `func` | *(top-level)* | **`assembleKey()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.AssembleValue` | `func` | *(top-level)* | **`assembleValue()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.Finish` | `func` | *(top-level)* | **`finish()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.KeyPrototype` | `func` | *(top-level)* | **`keyPrototype()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Assembler.ValuePrototype` | `func` | *(top-level)* | **`valuePrototype()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__KeyAssembler.BeginMap` | `func` | *(top-level)* | **`beginMap()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__KeyAssembler.BeginList` | `func` | *(top-level)* | **`beginList()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__KeyAssembler.AssignNull` | `func` | *(top-level)* | **`assignNull()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__KeyAssembler.AssignBool` | `func` | *(top-level)* | **`assignBool()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__KeyAssembler.AssignInt` | `func` | *(top-level)* | **`assignInt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__KeyAssembler.AssignFloat` | `func` | *(top-level)* | **`assignFloat()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__KeyAssembler.AssignString` | `func` | *(top-level)* | **`assignString()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__KeyAssembler.AssignBytes` | `func` | *(top-level)* | **`assignBytes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__KeyAssembler.AssignLink` | `func` | *(top-level)* | **`assignLink()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__KeyAssembler.AssignNode` | `func` | *(top-level)* | **`assignNode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__KeyAssembler.Prototype` | `func` | *(top-level)* | **`prototype()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.Type` | `func` | *(top-level)* | **`type()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Any.Representation` | `func` | *(top-level)* | **`representation()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.Kind` | `func` | *(top-level)* | **`kind()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.LookupByString` | `func` | *(top-level)* | **`lookupByString()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.LookupByNode` | `func` | *(top-level)* | **`lookupByNode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.LookupByIndex` | `func` | *(top-level)* | **`lookupByIndex()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.LookupBySegment` | `func` | *(top-level)* | **`lookupBySegment()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.MapIterator` | `func` | *(top-level)* | **`mapIterator()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.ListIterator` | `func` | *(top-level)* | **`listIterator()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.Length` | `func` | *(top-level)* | **`length()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.IsAbsent` | `func` | *(top-level)* | **`isAbsent()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.IsNull` | `func` | *(top-level)* | **`isNull()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.AsBool` | `func` | *(top-level)* | **`asBool()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.AsInt` | `func` | *(top-level)* | **`asInt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.AsFloat` | `func` | *(top-level)* | **`asFloat()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.AsString` | `func` | *(top-level)* | **`asString()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.AsBytes` | `func` | *(top-level)* | **`asBytes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.AsLink` | `func` | *(top-level)* | **`asLink()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__Repr.Prototype` | `func` | *(top-level)* | **`prototype()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprPrototype.NewBuilder` | `func` | *(top-level)* | **`newBuilder()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprBuilder.Build` | `func` | *(top-level)* | **`build()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprBuilder.Reset` | `func` | *(top-level)* | **`reset()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprAssembler.BeginMap` | `func` | *(top-level)* | **`beginMap()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprAssembler.BeginList` | `func` | *(top-level)* | **`beginList()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprAssembler.AssignNull` | `func` | *(top-level)* | **`assignNull()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprAssembler.AssignBool` | `func` | *(top-level)* | **`assignBool()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprAssembler.AssignInt` | `func` | *(top-level)* | **`assignInt()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprAssembler.AssignFloat` | `func` | *(top-level)* | **`assignFloat()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprAssembler.AssignString` | `func` | *(top-level)* | **`assignString()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprAssembler.AssignBytes` | `func` | *(top-level)* | **`assignBytes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprAssembler.AssignLink` | `func` | *(top-level)* | **`assignLink()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprAssembler.AssignNode` | `func` | *(top-level)* | **`assignNode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `_Any__ReprAssembler.Prototype` | `func` | *(top-level)* | **`prototype()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Bytes.Bytes` | `func` | *(top-level)* | **`bytes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | `Golang.Uint64` (`package:boilerplate/fixed_types/golang.dart`) |
| `_Bytes__Prototype.FromBytes` | `func` | *(top-level)* | **`fromBytes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |

### 3.9. QUIC Loss Recovery (`quic-go/internal/ackhandler`)
*Destino Dart:* `packages/transpiled_quic_go/lib/src/` (SentPacketHandler, PTO e retransmissão de flight)
*Origem Go:* `go-ipfs-reference/quic-go/internal/ackhandler/`

| Símbolo AST Go | Tipo Go | Escopo / Pai | Símbolo Dart Adaptado 1:1 | Regras AGENTS.md | Boilerplate Mandatório (Regra 10) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `IsFrameTypeAckEliciting` | `func` | *(top-level)* | **`isFrameTypeAckEliciting()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `IsFrameAckEliciting` | `func` | *(top-level)* | **`isFrameAckEliciting()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `HasAckElicitingFrames` | `func` | *(top-level)* | **`hasAckElicitingFrames()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ecnTracker.SentPacket` | `func` | *(top-level)* | **`sentPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ecnTracker.Mode` | `func` | *(top-level)* | **`mode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ecnTracker.LostPacket` | `func` | *(top-level)* | **`lostPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ecnTracker.HandleNewlyAcked` | `func` | *(top-level)* | **`handleNewlyAcked()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Frame` | `struct` | *(top-level)* | **`Frame`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Frame` | `field` | `Frame` | **`frame`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Handler` | `field` | `Frame` | **`handler`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `FrameHandler` | `interface` | *(top-level)* | **`FrameHandler`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `OnAcked` | `method` | `FrameHandler` | **`onAcked()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `OnLost` | `method` | `FrameHandler` | **`onLost()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `StreamFrame` | `struct` | *(top-level)* | **`StreamFrame`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Frame` | `field` | `StreamFrame` | **`frame`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Handler` | `field` | `StreamFrame` | **`handler`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SentPacketHandler` | `interface` | *(top-level)* | **`SentPacketHandler`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `SentPacket` | `method` | `SentPacketHandler` | **`sentPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ReceivedAck` | `method` | `SentPacketHandler` | **`receivedAck()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ReceivedPacket` | `method` | `SentPacketHandler` | **`receivedPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ReceivedBytes` | `method` | `SentPacketHandler` | **`receivedBytes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `DropPackets` | `method` | `SentPacketHandler` | **`dropPackets()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ResetForRetry` | `method` | `SentPacketHandler` | **`resetForRetry()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SendMode` | `method` | `SentPacketHandler` | **`sendMode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `TimeUntilSend` | `method` | `SentPacketHandler` | **`timeUntilSend()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetMaxDatagramSize` | `method` | `SentPacketHandler` | **`setMaxDatagramSize()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `QueueProbePacket` | `method` | `SentPacketHandler` | **`queueProbePacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ECNMode` | `method` | `SentPacketHandler` | **`ecnMode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `PeekPacketNumber` | `method` | `SentPacketHandler` | **`peekPacketNumber()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `PopPacketNumber` | `method` | `SentPacketHandler` | **`popPacketNumber()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetLossDetectionTimeout` | `method` | `SentPacketHandler` | **`getLossDetectionTimeout()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `OnLossDetectionTimeout` | `method` | `SentPacketHandler` | **`onLossDetectionTimeout()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MigratedPath` | `method` | `SentPacketHandler` | **`migratedPath()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `lostPacketTracker.Add` | `func` | *(top-level)* | **`add()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `lostPacketTracker.Delete` | `func` | *(top-level)* | **`delete()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `lostPacketTracker.All` | `func` | *(top-level)* | **`all()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `lostPacketTracker.DeleteBefore` | `func` | *(top-level)* | **`deleteBefore()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `packet.Outstanding` | `func` | *(top-level)* | **`outstanding()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `packet.IsAckEliciting` | `func` | *(top-level)* | **`isAckEliciting()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sequentialPacketNumberGenerator.Peek` | `func` | *(top-level)* | **`peek()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sequentialPacketNumberGenerator.Pop` | `func` | *(top-level)* | **`pop()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `skippingPacketNumberGenerator.Peek` | `func` | *(top-level)* | **`peek()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `skippingPacketNumberGenerator.Pop` | `func` | *(top-level)* | **`pop()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ReceivedPacketHandler` | `struct` | *(top-level)* | **`ReceivedPacketHandler`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ReceivedPacket` | `method` | `ReceivedPacketHandler` | **`receivedPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `IgnorePacketsBelow` | `method` | `ReceivedPacketHandler` | **`ignorePacketsBelow()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `DropPackets` | `method` | `ReceivedPacketHandler` | **`dropPackets()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetAlarmTimeout` | `method` | `ReceivedPacketHandler` | **`getAlarmTimeout()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetAckFrame` | `method` | `ReceivedPacketHandler` | **`getAckFrame()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `IsPotentiallyDuplicate` | `method` | `ReceivedPacketHandler` | **`isPotentiallyDuplicate()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewReceivedPacketHandler` | `func` | *(top-level)* | **`ReceivedPacketHandler()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `receivedPacketHistory.ReceivedPacket` | `func` | *(top-level)* | **`receivedPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `receivedPacketHistory.DeleteBelow` | `func` | *(top-level)* | **`deleteBelow()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `receivedPacketHistory.Backward` | `func` | *(top-level)* | **`backward()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `receivedPacketHistory.HighestMissingUpTo` | `func` | *(top-level)* | **`highestMissingUpTo()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `receivedPacketHistory.IsPotentiallyDuplicate` | `func` | *(top-level)* | **`isPotentiallyDuplicate()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `receivedPacketTracker.ReceivedPacket` | `func` | *(top-level)* | **`receivedPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `receivedPacketTracker.GetAckFrame` | `func` | *(top-level)* | **`getAckFrame()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `receivedPacketTracker.IsPotentiallyDuplicate` | `func` | *(top-level)* | **`isPotentiallyDuplicate()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `appDataReceivedPacketTracker.ReceivedPacket` | `func` | *(top-level)* | **`receivedPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `appDataReceivedPacketTracker.IgnoreBelow` | `func` | *(top-level)* | **`ignoreBelow()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `appDataReceivedPacketTracker.GetAckFrame` | `func` | *(top-level)* | **`getAckFrame()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `appDataReceivedPacketTracker.GetAlarmTimeout` | `func` | *(top-level)* | **`getAlarmTimeout()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SendMode.String` | `func` | *(top-level)* | **`string()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewSentPacketHandler` | `func` | *(top-level)* | **`SentPacketHandler()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.DropPackets` | `func` | *(top-level)* | **`dropPackets()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.ReceivedBytes` | `func` | *(top-level)* | **`receivedBytes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.ReceivedPacket` | `func` | *(top-level)* | **`receivedPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.SentPacket` | `func` | *(top-level)* | **`sentPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.ReceivedAck` | `func` | *(top-level)* | **`receivedAck()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.OnLossDetectionTimeout` | `func` | *(top-level)* | **`onLossDetectionTimeout()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.GetLossDetectionTimeout` | `func` | *(top-level)* | **`getLossDetectionTimeout()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.ECNMode` | `func` | *(top-level)* | **`ecnMode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.PeekPacketNumber` | `func` | *(top-level)* | **`peekPacketNumber()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.PopPacketNumber` | `func` | *(top-level)* | **`popPacketNumber()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.SendMode` | `func` | *(top-level)* | **`sendMode()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.TimeUntilSend` | `func` | *(top-level)* | **`timeUntilSend()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.SetMaxDatagramSize` | `func` | *(top-level)* | **`setMaxDatagramSize()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.QueueProbePacket` | `func` | *(top-level)* | **`queueProbePacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.ResetForRetry` | `func` | *(top-level)* | **`resetForRetry()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHandler.MigratedPath` | `func` | *(top-level)* | **`migratedPath()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.SkippedPacket` | `func` | *(top-level)* | **`skippedPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.SentPacket` | `func` | *(top-level)* | **`sentPacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.SentPathProbePacket` | `func` | *(top-level)* | **`sentPathProbePacket()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.Packets` | `func` | *(top-level)* | **`packets()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.PathProbes` | `func` | *(top-level)* | **`pathProbes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.FirstOutstanding` | `func` | *(top-level)* | **`firstOutstanding()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.FirstOutstandingPathProbe` | `func` | *(top-level)* | **`firstOutstandingPathProbe()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.SkippedPackets` | `func` | *(top-level)* | **`skippedPackets()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.Len` | `func` | *(top-level)* | **`len()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.NumOutstanding` | `func` | *(top-level)* | **`numOutstanding()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.Remove` | `func` | *(top-level)* | **`remove()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.RemovePathProbe` | `func` | *(top-level)* | **`removePathProbe()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.HasOutstandingPackets` | `func` | *(top-level)* | **`hasOutstandingPackets()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.HasOutstandingPathProbes` | `func` | *(top-level)* | **`hasOutstandingPathProbes()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.LowestPacketNumber` | `func` | *(top-level)* | **`lowestPacketNumber()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.DeclareLost` | `func` | *(top-level)* | **`declareLost()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `sentPacketHistory.Difference` | `func` | *(top-level)* | **`difference()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |

### 3.10. Boxo Blockstore & Reprovider (`boxo/blockstore`, `boxo/provider`)
*Destino Dart:* `packages/transpiled_boxo/lib/src/blockstore/`, `lib/src/node/`
*Origem Go:* `go-ipfs-reference/boxo/`

| Símbolo AST Go | Tipo Go | Escopo / Pai | Símbolo Dart Adaptado 1:1 | Regras AGENTS.md | Boilerplate Mandatório (Regra 10) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `AllKeysChanWithErrer` | `interface` | *(top-level)* | **`AllKeysChanWithErrer`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AllKeysChanWithErr` | `method` | `AllKeysChanWithErrer` | **`allKeysChanWithErr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Blockstore` | `interface` | *(top-level)* | **`Blockstore`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `DeleteBlock` | `method` | `Blockstore` | **`deleteBlock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Has` | `method` | `Blockstore` | **`has()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Get` | `method` | `Blockstore` | **`get()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GetSize` | `method` | `Blockstore` | **`getSize()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Put` | `method` | `Blockstore` | **`put()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `PutMany` | `method` | `Blockstore` | **`putMany()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `AllKeysChan` | `method` | `Blockstore` | **`allKeysChan()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GCBlockstore` | `interface` | *(top-level)* | **`GCBlockstore`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `GCLocker` | `interface` | *(top-level)* | **`GCLocker`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `GCLock` | `method` | `GCLocker` | **`gCLock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `PinLock` | `method` | `GCLocker` | **`pinLock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `GCRequested` | `method` | `GCLocker` | **`gCRequested()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Option` | `struct` | *(top-level)* | **`Option`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Unlocker` | `interface` | *(top-level)* | **`Unlocker`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Unlock` | `method` | `Unlocker` | **`unlock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Viewer` | `interface` | *(top-level)* | **`Viewer`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `View` | `method` | `Viewer` | **`view()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewGCBlockstore` | `func` | *(top-level)* | **`GCBlockstore()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `WriteThrough` | `func` | *(top-level)* | **`writeThrough()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NoPrefix` | `func` | *(top-level)* | **`noPrefix()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Provider` | `func` | *(top-level)* | **`provider()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewBlockstore` | `func` | *(top-level)* | **`Blockstore()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewBlockstoreNoPrefix` | `func` | *(top-level)* | **`BlockstoreNoPrefix()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `blockstore.Get` | `func` | *(top-level)* | **`get()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `blockstore.Put` | `func` | *(top-level)* | **`put()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `blockstore.PutMany` | `func` | *(top-level)* | **`putMany()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `blockstore.Has` | `func` | *(top-level)* | **`has()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `blockstore.GetSize` | `func` | *(top-level)* | **`getSize()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `blockstore.DeleteBlock` | `func` | *(top-level)* | **`deleteBlock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `blockstore.AllKeysChan` | `func` | *(top-level)* | **`allKeysChan()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `blockstore.AllKeysChanWithErr` | `func` | *(top-level)* | **`allKeysChanWithErr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewGCLocker` | `func` | *(top-level)* | **`GCLocker()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `unlocker.Unlock` | `func` | *(top-level)* | **`unlock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `gclocker.GCLock` | `func` | *(top-level)* | **`gCLock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `gclocker.PinLock` | `func` | *(top-level)* | **`pinLock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `gclocker.GCRequested` | `func` | *(top-level)* | **`gCRequested()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.BloomActive` | `func` | *(top-level)* | **`bloomActive()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.Wait` | `func` | *(top-level)* | **`wait()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.Rebuild` | `func` | *(top-level)* | **`rebuild()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.DeleteBlock` | `func` | *(top-level)* | **`deleteBlock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.Has` | `func` | *(top-level)* | **`has()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.GetSize` | `func` | *(top-level)* | **`getSize()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.View` | `func` | *(top-level)* | **`view()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.Get` | `func` | *(top-level)* | **`get()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.Put` | `func` | *(top-level)* | **`put()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.PutMany` | `func` | *(top-level)* | **`putMany()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.AllKeysChan` | `func` | *(top-level)* | **`allKeysChan()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.AllKeysChanWithErr` | `func` | *(top-level)* | **`allKeysChanWithErr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.GCLock` | `func` | *(top-level)* | **`gCLock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.PinLock` | `func` | *(top-level)* | **`pinLock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `bloomcache.GCRequested` | `func` | *(top-level)* | **`gCRequested()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BloomCacheStatus` | `interface` | *(top-level)* | **`BloomCacheStatus`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Wait` | `method` | `BloomCacheStatus` | **`wait()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `BloomActive` | `method` | `BloomCacheStatus` | **`bloomActive()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Rebuild` | `method` | `BloomCacheStatus` | **`rebuild()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CacheOpts` | `struct` | *(top-level)* | **`CacheOpts`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `HasBloomFilterSize` | `field` | `CacheOpts` | **`hasBloomFilterSize`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `HasBloomFilterHashes` | `field` | `CacheOpts` | **`hasBloomFilterHashes`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `HasTwoQueueCacheSize` | `field` | `CacheOpts` | **`hasTwoQueueCacheSize`** | Regra 2 (lowerCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `DefaultCacheOpts` | `func` | *(top-level)* | **`defaultCacheOpts()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `CachedBlockstore` | `func` | *(top-level)* | **`cachedBlockstore()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewIdStore` | `func` | *(top-level)* | **`IdStore()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `idstore.DeleteBlock` | `func` | *(top-level)* | **`deleteBlock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `idstore.Has` | `func` | *(top-level)* | **`has()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `idstore.View` | `func` | *(top-level)* | **`view()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `idstore.GetSize` | `func` | *(top-level)* | **`getSize()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `idstore.Get` | `func` | *(top-level)* | **`get()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `idstore.Put` | `func` | *(top-level)* | **`put()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `idstore.PutMany` | `func` | *(top-level)* | **`putMany()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `idstore.AllKeysChan` | `func` | *(top-level)* | **`allKeysChan()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `idstore.AllKeysChanWithErr` | `func` | *(top-level)* | **`allKeysChanWithErr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `idstore.Close` | `func` | *(top-level)* | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.DeleteBlock` | `func` | *(top-level)* | **`deleteBlock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.Has` | `func` | *(top-level)* | **`has()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.GetSize` | `func` | *(top-level)* | **`getSize()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.View` | `func` | *(top-level)* | **`view()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.Get` | `func` | *(top-level)* | **`get()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.Put` | `func` | *(top-level)* | **`put()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `keyedBlocks.Len` | `func` | *(top-level)* | **`len()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `keyedBlocks.Less` | `func` | *(top-level)* | **`less()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `keyedBlocks.Swap` | `func` | *(top-level)* | **`swap()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.PutMany` | `func` | *(top-level)* | **`putMany()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.AllKeysChan` | `func` | *(top-level)* | **`allKeysChan()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.AllKeysChanWithErr` | `func` | *(top-level)* | **`allKeysChanWithErr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.GCLock` | `func` | *(top-level)* | **`gCLock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.PinLock` | `func` | *(top-level)* | **`pinLock()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `tqcache.GCRequested` | `func` | *(top-level)* | **`gCRequested()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ValidatingBlockstore` | `struct` | *(top-level)* | **`ValidatingBlockstore`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `AllKeysChanWithErr` | `method` | `ValidatingBlockstore` | **`allKeysChanWithErr()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Get` | `method` | `ValidatingBlockstore` | **`get()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewDAGProvider` | `func` | *(top-level)* | **`DagProvider()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewNoopProvider` | `func` | *(top-level)* | **`NoopProvider()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `noopProvider.Clear` | `func` | *(top-level)* | **`clear()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `noopProvider.Close` | `func` | *(top-level)* | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `noopProvider.Provide` | `func` | *(top-level)* | **`provide()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `noopProvider.Reprovide` | `func` | *(top-level)* | **`reprovide()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `noopProvider.Stat` | `func` | *(top-level)* | **`stat()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `noopProvider.SetKeyProvider` | `func` | *(top-level)* | **`setKeyProvider()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `MultihashProvider` | `interface` | *(top-level)* | **`MultihashProvider`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `StartProviding` | `method` | `MultihashProvider` | **`startProviding()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Provider` | `interface` | *(top-level)* | **`Provider`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Provide` | `method` | `Provider` | **`provide()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Reprovider` | `interface` | *(top-level)* | **`Reprovider`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Reprovide` | `method` | `Reprovider` | **`reprovide()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `System` | `interface` | *(top-level)* | **`System`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Clear` | `method` | `System` | **`clear()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Close` | `method` | `System` | **`close()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Stat` | `method` | `System` | **`stat()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `SetKeyProvider` | `method` | `System` | **`setKeyProvider()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewBufferedProvider` | `func` | *(top-level)* | **`BufferedProvider()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewPrioritizedProvider` | `func` | *(top-level)* | **`PrioritizedProvider()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `NewConcatProvider` | `func` | *(top-level)* | **`ConcatProvider()` [construtor]** | Regra 5 (No newX, construtor/factory), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Provide` | `interface` | *(top-level)* | **`Provide`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `Provide` | `method` | `Provide` | **`provide()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `ProvideMany` | `interface` | *(top-level)* | **`ProvideMany`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |
| `ProvideMany` | `method` | `ProvideMany` | **`provideMany()`** | Regra 2 (lowerCamelCase), Regra 8 (No error tuples) | Dart nativo (`int`/`String`/`bool`) |
| `Ready` | `interface` | *(top-level)* | **`Ready`** | Regra 1 (UpperCamelCase) | Dart nativo (`int`/`String`/`bool`) |

---

## 4. Portão Obrigatório de Conclusão

Antes de concluir qualquer porte dos símbolos acima, execute rigorosamente a sequência:
```bash
dart format lib bin test packages
python tool/audit_ast_nomenclature.py --tests --severity ERROR
dart test -j 1
for d in packages/*/; do (cd "$d" && dart test -j 1); done
python tool/audit_ast_nomenclature.py --progress
python tool/audit_ast_nomenclature.py --markdown --output audit_report.md
```
