// O driver do `flutter drive` para rodar um integration_test em profile/release
// (o `flutter test` só roda em debug), ex.:
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/bench_test.dart -d <aparelho>
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
