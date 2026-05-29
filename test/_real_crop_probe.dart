// Probe de inspeção (NÃO é teste de regressão): carrega as fotos reais em
// test/_photos/*.jpg, decodifica com o mesmo targetWidth do app (640),
// roda o crop e gera test/_artifacts/real_crop_probe.png — original (com
// retângulo laranja do crop) + resultado no chip, lado a lado.
//
// Rode com: flutter test test/_real_crop_probe.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:controle_classificacao_cbbc/widgets/player_portrait_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decode(Uint8List bytes) async {
  final ui.Codec codec =
      await ui.instantiateImageCodec(bytes, targetWidth: 640);
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}

void _paintText(Canvas canvas, String text, Offset at, Color color, double sz) {
  final ui.ParagraphBuilder pb = ui.ParagraphBuilder(ui.ParagraphStyle(
    fontSize: sz,
    textAlign: TextAlign.left,
  ))
    ..pushStyle(ui.TextStyle(color: color))
    ..addText(text);
  final ui.Paragraph p = pb.build()
    ..layout(const ui.ParagraphConstraints(width: 340));
  canvas.drawParagraph(p, at);
}

void main() {
  testWidgets('real crop probe', (WidgetTester tester) async {
    final Directory probeDir = Directory('test/_photos');
    if (!probeDir.existsSync() ||
        probeDir.listSync().whereType<File>().every(
            (File f) => !f.path.endsWith('.jpg'))) {
      markTestSkipped('test/_photos/*.jpg ausente — probe local apenas.');
      return;
    }

    await tester.runAsync(() async {
      final Directory dir = Directory('test/_photos');
      final List<File> files = dir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.jpg'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

      const double cellW = 360;
      const double cellH = 300;
      const double origW = 200; // largura do painel "original"
      const double cropW = 110; // largura do painel "resultado"
      const int cols = 4;
      final int rows = (files.length + cols - 1) ~/ cols;
      final double w = (cols * cellW).toDouble();
      final double h = (rows * cellH).toDouble();

      final ui.PictureRecorder rec = ui.PictureRecorder();
      final Canvas canvas = Canvas(rec);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
          Paint()..color = const Color(0xFF101418));

      for (int i = 0; i < files.length; i++) {
        final File f = files[i];
        final ui.Image img = await _decode(f.readAsBytesSync());
        final Rect crop = await PlayerPortraitChip.debugComputeCrop(img);
        final String name = f.uri.pathSegments.last.replaceAll('.jpg', '');

        final double fl = crop.left / img.width;
        final double ft = crop.top / img.height;
        final double fw = crop.width / img.width;
        final double fh = crop.height / img.height;
        // ignore: avoid_print
        print('CROP ${name.padRight(20)} '
            'img=${img.width}x${img.height} '
            'left=${fl.toStringAsFixed(2)} top=${ft.toStringAsFixed(2)} '
            'w=${fw.toStringAsFixed(2)} h=${fh.toStringAsFixed(2)}'
            '${fh > 0.95 ? "  <CLOSEUP>" : ""}');

        final double cx = (i % cols) * cellW + 8;
        final double cy = (i ~/ cols) * cellH + 6;

        _paintText(canvas, name, Offset(cx, cy), Colors.white, 13);

        // Painel original com retângulo do crop.
        const double availH = cellH - 36;
        final double s = (origW / img.width).clamp(0.0, availH / img.height);
        final double dw = img.width * s;
        final double dh = img.height * s;
        final double ox = cx;
        final double oy = cy + 24;
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(ox, oy, dw, dh),
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.drawRect(
          Rect.fromLTWH(
              ox + crop.left * s, oy + crop.top * s, crop.width * s, crop.height * s),
          Paint()
            ..color = const Color(0xFFFF6D00)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );

        // Painel resultado (como apareceria no chip), aspect 0.82.
        final double rx = cx + origW + 16;
        final double ry = cy + 24;
        const double rh = availH;
        const double rw = rh * 0.82 < cropW ? rh * 0.82 : cropW;
        canvas.drawImageRect(
          img,
          crop,
          Rect.fromLTWH(rx, ry, rw, rh),
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.drawRect(
          Rect.fromLTWH(rx, ry, rw, rh),
          Paint()
            ..color = const Color(0xFF888888)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }

      final ui.Picture pic = rec.endRecording();
      final ui.Image out = await pic.toImage(w.toInt(), h.toInt());
      final ByteData? png =
          await out.toByteData(format: ui.ImageByteFormat.png);
      final Directory ad = Directory('test/_artifacts');
      if (!ad.existsSync()) ad.createSync(recursive: true);
      File('test/_artifacts/real_crop_probe.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
