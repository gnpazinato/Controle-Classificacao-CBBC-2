// Simulação de jogo (inspeção visual): monta um lineup 5×5 com fotos
// REAIS de test/_photos, cada uma recortada pelo MESMO algoritmo do app
// (debugComputeCrop) e desenhada com o formato de chip real (recorte
// retrato + badge de classe + badge de número), sobre um fundo cor de
// quadra. Gera test/_artifacts/game_simulation.png.
//
// Cobre os 4 formatos que o usuário citou: rosto/torso de perto, de
// longe (corpo todo), close-up só rosto, e enquadramento médio.
//
// Rode com: flutter test test/_game_simulation.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:controle_classificacao_cbbc/widgets/player_portrait_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Cores do tema (cobalto / laranja) replicadas pra não acoplar ao import.
const Color _blue = Color(0xFF1F4E9C);
const Color _wood = Color(0xFFB07A4B);
const Color _woodDark = Color(0xFF9A6840);

// Mesmo path do chip real (canto chanfrado no topo-esquerda).
Path _portraitPath(double w, double h) {
  final double radius = math.min(w, h) * 0.055;
  final double notch = math.min(w, h) * 0.17;
  return Path()
    ..moveTo(notch, 0)
    ..lineTo(w - radius, 0)
    ..quadraticBezierTo(w, 0, w, radius)
    ..lineTo(w, h - radius)
    ..quadraticBezierTo(w, h, w - radius, h)
    ..lineTo(radius, h)
    ..quadraticBezierTo(0, h, 0, h - radius)
    ..lineTo(0, notch)
    ..close();
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final ui.Codec codec =
      await ui.instantiateImageCodec(bytes, targetWidth: 640);
  return (await codec.getNextFrame()).image;
}

void _text(Canvas c, String s, Offset at, Color color, double sz,
    {FontWeight w = FontWeight.w700, double maxW = 200}) {
  final ui.ParagraphBuilder pb =
      ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: sz, textAlign: TextAlign.center))
        ..pushStyle(ui.TextStyle(color: color, fontWeight: w))
        ..addText(s);
  final ui.Paragraph p = pb.build()..layout(ui.ParagraphConstraints(width: maxW));
  c.drawParagraph(p, at);
}

class _Slot {
  _Slot(this.file, this.cls, this.number, this.bonus);
  final String file;
  final String cls;
  final int number;
  final bool bonus;
}

void _drawChip(Canvas canvas, ui.Image img, Rect crop, _Slot slot,
    Rect box) {
  canvas.save();
  canvas.translate(box.left, box.top);
  final Path path = _portraitPath(box.width, box.height);

  // Sombra.
  canvas.drawPath(
    path.shift(const Offset(0, 3)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  // Foto recortada dentro do clip retrato.
  canvas.save();
  canvas.clipPath(path);
  canvas.drawImageRect(img, crop, Rect.fromLTWH(0, 0, box.width, box.height),
      Paint()..filterQuality = FilterQuality.high);
  canvas.restore();

  final double badge = box.height * 0.28;
  // Badge de classe (pill) no topo-esquerda com overhang.
  final Rect pill = Rect.fromLTWH(
      -badge * 0.5 * 0.5, box.height * 0.05, badge * 1.15, badge);
  final RRect pillR = RRect.fromRectAndRadius(pill, Radius.circular(badge * 0.34));
  canvas.drawRRect(pillR, Paint()..color = _blue);
  canvas.drawRRect(
      pillR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1);
  _text(canvas, slot.cls, Offset(pill.left, pill.top + badge * 0.22),
      Colors.white, badge * 0.5, maxW: pill.width);

  // Badge de número (círculo) embaixo-direita.
  final double nb = box.height * 0.28;
  final Offset nc =
      Offset(box.width - nb * 0.55 * 0.45 - nb / 2 + nb * 0.45, box.height * 0.88 - nb / 2);
  final Rect ncRect = Rect.fromCenter(center: nc, width: nb, height: nb);
  canvas.drawOval(ncRect, Paint()..color = _blue);
  canvas.drawOval(
      ncRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
  _text(canvas, '${slot.number}', Offset(nc.dx - nb / 2, nc.dy - nb * 0.28),
      Colors.white, nb * 0.5, w: FontWeight.w900, maxW: nb);

  // Estrela de bonificação.
  if (slot.bonus) {
    final Offset sc = Offset(box.width - nb * 0.1, -nb * 0.05);
    canvas.drawCircle(sc, nb * 0.4, Paint()..color = const Color(0xFFF57C00));
    canvas.drawCircle(
        sc,
        nb * 0.4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    _text(canvas, '★', Offset(sc.dx - nb * 0.4, sc.dy - nb * 0.32),
        Colors.white, nb * 0.42, maxW: nb * 0.8);
  }

  canvas.restore();
}

void main() {
  testWidgets('game simulation — lineup 5x5 com fotos reais',
      (WidgetTester tester) async {
    // Time de cima: as 5 fotos da APP que ESTAVAM quebradas (de longe).
    final List<_Slot> teamTop = <_Slot>[
      _Slot('adrienne', '4.0', 11, false),
      _Slot('app_cristiane', '1.0', 17, false),
      _Slot('app_gabriela', '2.0', 21, true),
      _Slot('app_brenda', '1.0', 19, false),
      _Slot('app_geisa', '4.0', 22, false),
    ];
    // Time de baixo: mix de formatos (médio, longe c/ cadeira, close-up).
    final List<_Slot> teamBot = <_Slot>[
      _Slot('irefes_paola', '3.5', 41, false),
      _Slot('adesul_oara', '4.0', 10, false),
      _Slot('irefes_bruna', '2.0', 9, false),
      _Slot('root_perla', '2.0', 6, false),
      _Slot('root_cleonete', '2.0', 4, false),
    ];

    if (!File('test/_photos/adrienne.jpg').existsSync()) {
      markTestSkipped('test/_photos ausente — simulação local apenas.');
      return;
    }

    await tester.runAsync(() async {
      final Map<String, ui.Image> imgs = <String, ui.Image>{};
      final Map<String, Rect> crops = <String, Rect>{};
      for (final _Slot s in <_Slot>[...teamTop, ...teamBot]) {
        final ui.Image im =
            await _decode(File('test/_photos/${s.file}.jpg').readAsBytesSync());
        imgs[s.file] = im;
        crops[s.file] = await PlayerPortraitChip.debugComputeCrop(im);
      }

      const double w = 980;
      const double h = 720;
      final ui.PictureRecorder rec = ui.PictureRecorder();
      final Canvas canvas = Canvas(rec);
      // Fundo cor de quadra.
      final Paint wood = Paint()
        ..shader = ui.Gradient.linear(
            const Offset(0, 0), const Offset(0, h), <Color>[_wood, _woodDark]);
      canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), wood);
      // Linha central.
      canvas.drawLine(const Offset(0, h / 2), const Offset(w, h / 2),
          Paint()..color = Colors.white.withValues(alpha: 0.6)..strokeWidth = 2);
      canvas.drawCircle(const Offset(w / 2, h / 2), 70,
          Paint()..color = Colors.white.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 2);

      const double chipW = 150;
      const double chipH = 178;
      const double gap = (w - 5 * chipW) / 6;
      void row(List<_Slot> team, double y) {
        for (int i = 0; i < team.length; i++) {
          final _Slot s = team[i];
          final double x = gap + i * (chipW + gap);
          _drawChip(canvas, imgs[s.file]!, crops[s.file]!, s,
              Rect.fromLTWH(x, y, chipW, chipH));
        }
      }

      row(teamTop, 40);
      row(teamBot, h - chipH - 40);

      final ui.Image out =
          await rec.endRecording().toImage(w.toInt(), h.toInt());
      final ByteData? png =
          await out.toByteData(format: ui.ImageByteFormat.png);
      final Directory ad = Directory('test/_artifacts');
      if (!ad.existsSync()) ad.createSync(recursive: true);
      File('test/_artifacts/game_simulation.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
