import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:controle_classificacao_cbbc/services/battery_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReader implements BatteryReader {
  _FakeReader({required int level, required BatteryState state})
      : _level = level,
        _state = state;

  int _level;
  BatteryState _state;
  final StreamController<BatteryState> _states =
      StreamController<BatteryState>.broadcast();

  void set({int? level, BatteryState? state}) {
    if (level != null) _level = level;
    if (state != null) {
      _state = state;
      _states.add(state);
    }
  }

  @override
  Future<int> level() async => _level;

  @override
  Future<BatteryState> state() async => _state;

  @override
  Stream<BatteryState> stateChanges() => _states.stream;
}

class _BrokenReader implements BatteryReader {
  @override
  Future<int> level() async => throw UnsupportedError('sem bateria');

  @override
  Future<BatteryState> state() async => throw UnsupportedError('sem bateria');

  @override
  Stream<BatteryState> stateChanges() =>
      Stream<BatteryState>.error(UnsupportedError('sem bateria'));
}

void main() {
  test('abaixo de 30% e fora da tomada → avisa', () async {
    final _FakeReader reader =
        _FakeReader(level: 24, state: BatteryState.discharging);
    final BatteryMonitor monitor = BatteryMonitor(reader: reader);
    addTearDown(monitor.dispose);

    await monitor.refresh();
    expect(monitor.level, 24);
    expect(monitor.shouldWarn, isTrue);
  });

  test('no limiar exato (30%) não avisa; 29% avisa', () async {
    final _FakeReader reader =
        _FakeReader(level: 30, state: BatteryState.discharging);
    final BatteryMonitor monitor = BatteryMonitor(reader: reader);
    addTearDown(monitor.dispose);

    await monitor.refresh();
    expect(monitor.shouldWarn, isFalse);

    reader.set(level: 29);
    await monitor.refresh();
    expect(monitor.shouldWarn, isTrue);
  });

  test('carregando (ou carga completa) nunca avisa, mesmo abaixo de 30%',
      () async {
    final _FakeReader reader =
        _FakeReader(level: 10, state: BatteryState.charging);
    final BatteryMonitor monitor = BatteryMonitor(reader: reader);
    addTearDown(monitor.dispose);

    await monitor.refresh();
    expect(monitor.shouldWarn, isFalse);

    reader.set(state: BatteryState.full);
    await monitor.refresh();
    expect(monitor.shouldWarn, isFalse);
  });

  test('conectar na tomada desliga o aviso via stream de estado', () async {
    final _FakeReader reader =
        _FakeReader(level: 20, state: BatteryState.discharging);
    final BatteryMonitor monitor = BatteryMonitor(reader: reader);
    addTearDown(monitor.dispose);

    final List<bool> observed = <bool>[];
    monitor.addListener(() => observed.add(monitor.shouldWarn));

    monitor.start();
    await Future<void>.delayed(Duration.zero);
    expect(monitor.shouldWarn, isTrue);

    reader.set(state: BatteryState.charging);
    await Future<void>.delayed(Duration.zero);
    expect(monitor.shouldWarn, isFalse);
    expect(observed, contains(false));
  });

  test('plataforma sem leitura de bateria → nunca avisa nem lança',
      () async {
    final BatteryMonitor monitor = BatteryMonitor(reader: _BrokenReader());
    addTearDown(monitor.dispose);

    monitor.start();
    await monitor.refresh();
    expect(monitor.level, isNull);
    expect(monitor.shouldWarn, isFalse);
  });
}
