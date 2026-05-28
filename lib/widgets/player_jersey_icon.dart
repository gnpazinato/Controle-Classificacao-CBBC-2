import 'package:flutter/material.dart';

import '../models/player.dart';
import '../theme/cbbc_theme.dart';

/// Ícone vetorial de uma camiseta de basquete com o número do atleta.
///
/// A cor de fundo e do número vêm de [jerseyColor] (escolhida pelo
/// usuário no setup da partida). O fallback respeita a antiga
/// convenção: branco para a Equipe A, azul CBBC para a Equipe B.
class PlayerJerseyIcon extends StatelessWidget {
  const PlayerJerseyIcon({
    super.key,
    required this.player,
    required this.isTeamA,
    this.size = 40,
    this.jerseyColor,
  });

  final Player player;
  final bool isTeamA;
  final double size;
  final JerseyColor? jerseyColor;

  @override
  Widget build(BuildContext context) {
    final JerseyColor color = jerseyColor ??
        (isTeamA ? JerseyColor.white : JerseyColor.darkBlue);
    final Color fill = color.fill;
    final Color text = color.numberColor;
    // Contorno na mesma cor do número — naturalmente contrasta com o
    // fill (numberColor já é escolhido pra ser legível sobre o fill).
    final Color border = text;

    return SizedBox(
      width: size,
      height: size,
      child: Semantics(
        label: 'Camisa ${player.shirtNumber} '
            '(${isTeamA ? 'Equipe A' : 'Equipe B'})',
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomPaint(
              painter: _JerseyPainter(
                fillColor: fill,
                borderColor: border,
                strokeWidth: size * 0.04,
              ),
            ),
            Positioned(
              left: size * 0.18,
              right: size * 0.18,
              top: size * 0.38,
              bottom: size * 0.14,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  '${player.shirtNumber}',
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JerseyPainter extends CustomPainter {
  _JerseyPainter({
    required this.fillColor,
    required this.borderColor,
    required this.strokeWidth,
  });

  final Color fillColor;
  final Color borderColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Path body = Path()
      ..moveTo(w * 0.18, h * 0.22)
      ..lineTo(w * 0.35, h * 0.10)
      ..lineTo(w * 0.42, h * 0.22)
      ..quadraticBezierTo(w * 0.50, h * 0.42, w * 0.58, h * 0.22)
      ..lineTo(w * 0.65, h * 0.10)
      ..lineTo(w * 0.82, h * 0.22)
      ..quadraticBezierTo(w * 0.83, h * 0.30, w * 0.80, h * 0.40)
      ..lineTo(w * 0.90, h * 0.92)
      ..lineTo(w * 0.10, h * 0.92)
      ..lineTo(w * 0.20, h * 0.40)
      ..quadraticBezierTo(w * 0.17, h * 0.30, w * 0.18, h * 0.22)
      ..close();

    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(body, fillPaint);

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawPath(body, borderPaint);
  }

  @override
  bool shouldRepaint(_JerseyPainter old) =>
      old.fillColor != fillColor ||
      old.borderColor != borderColor ||
      old.strokeWidth != strokeWidth;
}
