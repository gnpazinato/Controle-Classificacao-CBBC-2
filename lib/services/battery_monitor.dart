import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

/// Fonte de leitura da bateria — abstraída pra permitir fakes nos testes
/// sem tocar no plugin de plataforma.
abstract class BatteryReader {
  Future<int> level();
  Future<BatteryState> state();
  Stream<BatteryState> stateChanges();
}

class PluginBatteryReader implements BatteryReader {
  final Battery _battery = Battery();

  @override
  Future<int> level() => _battery.batteryLevel;

  @override
  Future<BatteryState> state() => _battery.batteryState;

  @override
  Stream<BatteryState> stateChanges() => _battery.onBatteryStateChanged;
}

/// Vigia a bateria do tablet e liga o aviso "coloque para carregar"
/// quando o nível fica abaixo de [warnBelow] SEM estar na tomada.
///
/// O app roda em modo imersivo (barra de status escondida) durante a
/// partida — o comissário não vê o indicador do Android e o tablet pode
/// morrer no meio do jogo. Este monitor alimenta o banner persistente
/// desenhado por cima de todas as telas.
///
/// Atualiza por dois caminhos: evento de tomada (conectou/desconectou,
/// via stream do sistema) e um poll do nível a cada [pollInterval].
/// Plataforma sem suporte (ex.: web/desktop sem bateria) → nunca avisa.
class BatteryMonitor extends ChangeNotifier {
  BatteryMonitor({
    BatteryReader? reader,
    this.warnBelow = 30,
    this.pollInterval = const Duration(seconds: 60),
  }) : _reader = reader ?? PluginBatteryReader();

  final BatteryReader _reader;

  /// Limiar do aviso, em % (exclusivo: 29% avisa, 30% não).
  final int warnBelow;
  final Duration pollInterval;

  int? _level;
  BatteryState _state = BatteryState.unknown;
  Timer? _timer;
  StreamSubscription<BatteryState>? _stateSub;
  bool _started = false;

  /// Último nível lido (0–100). `null` antes da primeira leitura ou em
  /// plataforma sem suporte.
  int? get level => _level;

  bool get isCharging =>
      _state == BatteryState.charging || _state == BatteryState.full;

  /// `true` = mostrar o aviso persistente de carregar o tablet.
  bool get shouldWarn {
    final int? current = _level;
    return current != null && current < warnBelow && !isCharging;
  }

  void start() {
    if (_started) return;
    _started = true;
    unawaited(refresh());
    _timer = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    try {
      _stateSub = _reader.stateChanges().listen(
        (BatteryState next) {
          // Conectou/desconectou da tomada: notifica na hora (o banner
          // some/aparece imediatamente) e relê o nível em seguida.
          if (next != _state) {
            _state = next;
            notifyListeners();
          }
          unawaited(refresh());
        },
        onError: (Object _) {},
      );
    } catch (_) {
      // Plataforma sem stream de estado — segue só com o poll.
    }
  }

  /// Relê nível e estado; notifica só quando algo mudou.
  Future<void> refresh() async {
    try {
      final int nextLevel = await _reader.level();
      final BatteryState nextState = await _reader.state();
      final bool changed = nextLevel != _level || nextState != _state;
      _level = nextLevel;
      _state = nextState;
      if (changed) notifyListeners();
    } catch (_) {
      // Sem leitura de bateria nesta plataforma: mantém _level null e o
      // aviso desligado.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    unawaited(_stateSub?.cancel());
    _stateSub = null;
    super.dispose();
  }
}
