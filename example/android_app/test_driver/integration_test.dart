// The `flutter drive` driver to run an integration_test in profile/release
// (`flutter test` only runs in debug), e.g.:
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/bench_test.dart -d <device>
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
