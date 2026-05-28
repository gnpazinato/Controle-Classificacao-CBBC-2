import 'package:vibration/vibration.dart';

/// Disparador de vibração leve usado pela tela de partida quando uma
/// equipe cruza o limite de pontos.
class VibrationService {
  const VibrationService();

  Future<void> shortBuzz() async {
    try {
      final bool hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate(duration: 1500);
      }
    } catch (_) {
      // Plugin indisponível (web, test env) — silencioso por design.
    }
  }
}
