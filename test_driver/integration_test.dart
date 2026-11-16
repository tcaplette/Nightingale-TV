// The host side of `flutter drive` for the integration tests, for runs on a
// prebuilt app (--use-application-binary), such as a profile build of
// integration_test/library_scan_lag_live_test.dart on the TV emulator.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
