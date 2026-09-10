// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  test('network enum text matches go-libp2p', () {
    expect(Direction.inbound.text, 'Inbound');
    expect(Connectedness.limited.text, 'Limited');
    expect(Reachability.private_.text, 'Private');
    expect(messageSizeMax, 1 << 22);
  });

  test('connection metadata mirrors network contracts', () {
    final opened = DateTime.utc(2026, 1, 2);
    final stats = Stats(
      direction: Direction.outbound,
      opened: opened,
      limited: true,
      extra: {'source': 'test'},
    );
    final conn = ConnStats(
      direction: stats.direction,
      opened: stats.opened,
      limited: stats.limited,
      extra: stats.extra,
      numStreams: 3,
    );
    const delay = AddrDelay(Multiaddr.empty, Duration(milliseconds: 5));
    expect(conn.direction, Direction.outbound);
    expect(conn.opened, opened);
    expect(conn.limited, isTrue);
    expect(conn.extra['source'], 'test');
    expect(conn.numStreams, 3);
    expect(delay.addr, Multiaddr.empty);
    expect(delay.delay, const Duration(milliseconds: 5));
  });
}
