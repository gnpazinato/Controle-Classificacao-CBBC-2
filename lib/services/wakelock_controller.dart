import 'package:wakelock_plus/wakelock_plus.dart';

/// Wrapper mockável para `wakelock_plus`.
class WakelockController {
  const WakelockController();

  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
