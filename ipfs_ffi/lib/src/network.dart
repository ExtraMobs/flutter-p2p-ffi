import 'dart:io';

/// Se o aparelho tem IPv6 global (endereço 2000::/3 numa interface): a rede
/// atual (dados móveis ou Wi-Fi) entrega IPv6 público. Por IPv6 dois peers
/// atrás de NAT de operadora se conectam direto; por IPv4 o NAT simétrico
/// deixa só o relay (README, seção Android). Funciona em qualquer plataforma; no
/// Android as interfaces vêm do getifaddrs, que o app pode ler (só o netlink é
/// bloqueado).
///
/// Ter o endereço não prova que o tráfego passa: é o que o sistema recebeu da
/// rede, sem teste de conexão.
Future<bool> hasIpv6() async {
  final ifaces = await NetworkInterface.list(
      includeLoopback: false, type: InternetAddressType.IPv6);
  return ifaces.any((i) => i.addresses.any(isGlobalIpv6));
}

/// Endereço IPv6 global unicast (2000::/3): fora loopback, link-local
/// (fe80::/10), privado (fc00::/7) e multicast.
bool isGlobalIpv6(InternetAddress a) =>
    a.type == InternetAddressType.IPv6 && (a.rawAddress[0] & 0xE0) == 0x20;
