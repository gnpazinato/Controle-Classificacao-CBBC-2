// Detecção de transmissão congelada no viewer: `broadcastAgeIsStale` é
// função pura (sem widgets), então roda em qualquer host — inclusive no
// Codespace Alpine/musl onde widget tests com MaterialApp estouram a pilha.

import 'package:controle_classificacao_cbbc/constants/broadcast_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('broadcastAgeIsStale', () {
    test('null/ausente/tipo inesperado nunca é stale (Function antiga sem '
        'age_ms)', () {
      expect(broadcastAgeIsStale(null), isFalse);
      expect(broadcastAgeIsStale('90001'), isFalse);
      expect(broadcastAgeIsStale(true), isFalse);
      expect(broadcastAgeIsStale(<String, dynamic>{}), isFalse);
    });

    test('limiar estrito em kViewerStaleAfter (90s)', () {
      final int limiarMs = kViewerStaleAfter.inMilliseconds;
      expect(limiarMs, 90000);
      expect(broadcastAgeIsStale(0), isFalse);
      expect(broadcastAgeIsStale(limiarMs - 1), isFalse);
      expect(broadcastAgeIsStale(limiarMs), isFalse);
      expect(broadcastAgeIsStale(limiarMs + 1), isTrue);
      // O JSON pode decodificar como double — também precisa funcionar.
      expect(broadcastAgeIsStale(90000.5), isTrue);
      expect(broadcastAgeIsStale(89999.5), isFalse);
    });

    test('heartbeat de 30s permite 3 perdas antes do stale', () {
      expect(kViewerStaleAfter.inSeconds ~/ kBroadcastHeartbeat.inSeconds, 3);
    });
  });
}
