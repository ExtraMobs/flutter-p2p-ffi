import 'dart:io';

/// Whether the device has a global IPv6 address (2000::/3 on some
/// interface): the current network (mobile data or Wi-Fi) provides public
/// IPv6. Over IPv6 two peers behind carrier-grade NAT connect directly; over
/// IPv4 symmetric NAT leaves only the relay (README, Android section). Works
/// on any platform; on Android the interfaces come from getifaddrs, which the
/// app may read (only netlink is blocked).
///
/// Having the address does not prove that traffic gets through: it is what
/// the system received from the network, without a connection test.
Future<bool> hasIpv6() async {
  final ifaces = await NetworkInterface.list(
      includeLoopback: false, type: InternetAddressType.IPv6);
  return ifaces.any((i) => i.addresses.any(isGlobalIpv6));
}

/// Global unicast IPv6 address (2000::/3): excludes loopback, link-local
/// (fe80::/10), private (fc00::/7) and multicast.
bool isGlobalIpv6(InternetAddress a) =>
    a.type == InternetAddressType.IPv6 && (a.rawAddress[0] & 0xE0) == 0x20;
