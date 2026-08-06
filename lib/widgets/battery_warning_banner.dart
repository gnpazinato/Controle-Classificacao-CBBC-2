import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/battery_monitor.dart';
import '../theme/cbbc_theme.dart';

/// Sobrepõe um aviso persistente de bateria baixa a TODAS as telas do
/// app (montado no `builder` do MaterialApp, acima do Navigator).
///
/// Aparece quando a bateria está abaixo de 30% e fora da tomada; some
/// sozinho ao conectar o carregador ou recuperar o nível. Pra não
/// atrapalhar a operação da partida, o toque alterna entre o aviso
/// completo ("Bateria 24% — coloque o tablet para carregar") e um
/// selinho compacto só com o ícone e o percentual — mas nunca some
/// enquanto a condição persistir.
///
/// Na web (viewer público em projetor/PC) o monitor nem é iniciado.
class BatteryWarningOverlay extends StatefulWidget {
  const BatteryWarningOverlay({
    super.key,
    required this.child,
    this.monitor,
  });

  final Widget child;

  /// Injetável nos testes; por padrão cria (e possui) um [BatteryMonitor].
  final BatteryMonitor? monitor;

  @override
  State<BatteryWarningOverlay> createState() => _BatteryWarningOverlayState();
}

class _BatteryWarningOverlayState extends State<BatteryWarningOverlay> {
  late final BatteryMonitor _monitor;
  bool _compact = false;

  @override
  void initState() {
    super.initState();
    _monitor = widget.monitor ?? BatteryMonitor();
    _monitor.addListener(_onBatteryChanged);
    if (!kIsWeb) _monitor.start();
  }

  @override
  void dispose() {
    _monitor.removeListener(_onBatteryChanged);
    if (widget.monitor == null) _monitor.dispose();
    super.dispose();
  }

  void _onBatteryChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool warn = _monitor.shouldWarn;
    return Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        widget.child,
        if (warn)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _BatteryPill(
                    level: _monitor.level ?? 0,
                    compact: _compact,
                    onTap: () => setState(() => _compact = !_compact),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BatteryPill extends StatelessWidget {
  const _BatteryPill({
    required this.level,
    required this.compact,
    required this.onTap,
  });

  final int level;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Abaixo de 15% o aviso escala de laranja pra vermelho.
    final bool critical = level < 15;
    final Color background =
        critical ? CbbcColors.alertRed : CbbcColors.orange;
    final String label = compact
        ? '$level%'
        : 'Bateria $level% — coloque o tablet para carregar';

    return Material(
      key: const Key('battery-warning-pill'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: background.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                critical ? Icons.battery_alert : Icons.battery_2_bar,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
