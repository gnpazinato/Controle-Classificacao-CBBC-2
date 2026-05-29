// Teste visual do crop automático de fotos: gera "fotos" sintéticas
// (cabeça + ombros) cobrindo os cenários onde o algoritmo precisa decidir
// — fundo branco/colorido, rosto distante/close-up, cabelo encostando no
// topo — e produz uma grade com a foto original (com o retângulo do crop
// sobreposto) e o resultado renderizado. Salva em
// `test/_artifacts/portrait_crop_cases.png` para inspeção manual.
//
// O algoritmo em si vive em [_PortraitFrameState._computeSourceRect],
// exposto via [PlayerPortraitChip.debugComputeCrop].

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:controle_classificacao_cbbc/widgets/player_portrait_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Descreve uma "foto" sintética: como desenhar a cabeça e ombros sobre
/// um fundo, em coordenadas relativas 0..1.
class _SyntheticCase {
  const _SyntheticCase({
    required this.label,
    required this.bgColor,
    required this.headCenter,
    required this.headRadius,
    required this.shoulderWidth,
    required this.skinColor,
    required this.shirtColor,
    required this.hairColor,
  });

  final String label;
  final Color bgColor;
  final Offset headCenter; // 0..1 da imagem
  final double headRadius; // 0..1 (fração da altura)
  final double shoulderWidth; // 0..1
  final Color skinColor;
  final Color shirtColor;
  final Color hairColor;
}

Future<ui.Image> _renderSynthetic(_SyntheticCase c, int w, int h) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Paint bg = Paint()..color = c.bgColor;
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), bg);

  final double headCx = c.headCenter.dx * w;
  final double headCy = c.headCenter.dy * h;
  final double headR = c.headRadius * h;
  final double shoulderW = c.shoulderWidth * w;

  // Ombros: trapézio largo começando no pescoço.
  final Paint shirt = Paint()..color = c.shirtColor;
  final Path torso = Path()
    ..moveTo(headCx - shoulderW / 2, h.toDouble())
    ..lineTo(headCx - shoulderW / 2, headCy + headR * 0.9)
    ..quadraticBezierTo(
      headCx - headR * 0.55,
      headCy + headR * 0.6,
      headCx - headR * 0.45,
      headCy + headR * 0.35,
    )
    ..lineTo(headCx + headR * 0.45, headCy + headR * 0.35)
    ..quadraticBezierTo(
      headCx + headR * 0.55,
      headCy + headR * 0.6,
      headCx + shoulderW / 2,
      headCy + headR * 0.9,
    )
    ..lineTo(headCx + shoulderW / 2, h.toDouble())
    ..close();
  canvas.drawPath(torso, shirt);

  // Cabelo (calota superior).
  final Paint hair = Paint()..color = c.hairColor;
  canvas.drawCircle(Offset(headCx, headCy - headR * 0.05), headR * 1.02, hair);

  // Rosto (oval, recortado dentro do cabelo).
  final Paint skin = Paint()..color = c.skinColor;
  final Rect faceRect = Rect.fromCenter(
    center: Offset(headCx, headCy + headR * 0.15),
    width: headR * 1.55,
    height: headR * 1.85,
  );
  canvas.drawOval(faceRect, skin);

  // Olhos + boca pra criar variação de cor "real".
  final Paint feature = Paint()..color = const Color(0xFF2A1A14);
  canvas.drawCircle(
    Offset(headCx - headR * 0.32, headCy + headR * 0.08),
    headR * 0.10,
    feature,
  );
  canvas.drawCircle(
    Offset(headCx + headR * 0.32, headCy + headR * 0.08),
    headR * 0.10,
    feature,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(headCx, headCy + headR * 0.55),
        width: headR * 0.65,
        height: headR * 0.10,
      ),
      Radius.circular(headR * 0.05),
    ),
    feature,
  );

  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(w, h);
}

const List<_SyntheticCase> _cases = <_SyntheticCase>[
  _SyntheticCase(
    label: 'A. Fundo branco — rosto distante',
    bgColor: Color(0xFFFFFFFF),
    headCenter: Offset(0.50, 0.30),
    headRadius: 0.10,
    shoulderWidth: 0.45,
    skinColor: Color(0xFFE2B091),
    shirtColor: Color(0xFF1565C0),
    hairColor: Color(0xFF2B1410),
  ),
  _SyntheticCase(
    label: 'B. Fundo branco — rosto médio',
    bgColor: Color(0xFFFFFFFF),
    headCenter: Offset(0.50, 0.34),
    headRadius: 0.16,
    shoulderWidth: 0.65,
    skinColor: Color(0xFFCB9B82),
    shirtColor: Color(0xFFE65100),
    hairColor: Color(0xFF1A0D08),
  ),
  _SyntheticCase(
    label: 'C. Fundo branco — close-up',
    bgColor: Color(0xFFFFFFFF),
    headCenter: Offset(0.50, 0.42),
    headRadius: 0.30,
    shoulderWidth: 0.95,
    skinColor: Color(0xFFB87E5F),
    shirtColor: Color(0xFF2E7D32),
    hairColor: Color(0xFF120A06),
  ),
  _SyntheticCase(
    label: 'D. Fundo verde — rosto médio (não-branco)',
    bgColor: Color(0xFFB5D9A0),
    headCenter: Offset(0.50, 0.34),
    headRadius: 0.17,
    shoulderWidth: 0.70,
    skinColor: Color(0xFFD9AA8B),
    shirtColor: Color(0xFFEF6C00),
    hairColor: Color(0xFF1A0F0A),
  ),
  _SyntheticCase(
    label: 'E. Cabelo escuro encostado no topo',
    bgColor: Color(0xFFFFFFFF),
    headCenter: Offset(0.48, 0.14),
    headRadius: 0.14,
    shoulderWidth: 0.55,
    skinColor: Color(0xFFB97B5C),
    shirtColor: Color(0xFF6A1B9A),
    hairColor: Color(0xFF080404),
  ),
  _SyntheticCase(
    label: 'F. Fundo cinza claro — rosto pequeno descentralizado',
    bgColor: Color(0xFFEFEFEF),
    headCenter: Offset(0.42, 0.32),
    headRadius: 0.11,
    shoulderWidth: 0.50,
    skinColor: Color(0xFFC99578),
    shirtColor: Color(0xFFC62828),
    hairColor: Color(0xFF26120A),
  ),
];

/// Renderiza, lado a lado: foto original com retângulo do crop sobreposto
/// + a "cropped view" como apareceria dentro do chip.
class _CasePanel extends StatelessWidget {
  const _CasePanel({
    required this.image,
    required this.crop,
    required this.label,
  });

  final ui.Image image;
  final Rect crop;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 18,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              SizedBox(
                width: 180,
                height: 220,
                child: CustomPaint(
                  painter: _OriginalWithCropPainter(image: image, crop: crop),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 132,
                height: 220,
                child: CustomPaint(
                  painter: _CroppedPainter(image: image, crop: crop),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OriginalWithCropPainter extends CustomPainter {
  _OriginalWithCropPainter({required this.image, required this.crop});

  final ui.Image image;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect dest = Offset.zero & size;
    final Paint p = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dest,
      p,
    );
    // Sobrepõe retângulo do crop em escala correta.
    final double sx = size.width / image.width;
    final double sy = size.height / image.height;
    final Rect overlay = Rect.fromLTWH(
      crop.left * sx,
      crop.top * sy,
      crop.width * sx,
      crop.height * sy,
    );
    final Paint stroke = Paint()
      ..color = const Color(0xFFE65100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawRect(overlay, stroke);
  }

  @override
  bool shouldRepaint(_OriginalWithCropPainter old) =>
      old.image != image || old.crop != crop;
}

class _CroppedPainter extends CustomPainter {
  _CroppedPainter({required this.image, required this.crop});

  final ui.Image image;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect dest = Offset.zero & size;
    final Paint p = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(image, crop, dest, p);
    // Moldura cinza pra deixar claro o limite do chip.
    final Paint stroke = Paint()
      ..color = const Color(0xFF888888)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(dest, stroke);
  }

  @override
  bool shouldRepaint(_CroppedPainter old) =>
      old.image != image || old.crop != crop;
}

Future<void> _saveScreenshot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary = tester.renderObject<
        RenderRepaintBoundary>(find.byKey(const Key('crop-grid')));
    final ui.Image image = await boundary.toImage(pixelRatio: 1.5);
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final Directory dir = Directory('test/_artifacts');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

void main() {
  testWidgets('portrait crop — grade de casos sintéticos',
      (WidgetTester tester) async {
    // Gera todas as imagens primeiro (fora do build, pra não bloquear o
    // pipeline de teste com chamadas async pesadas).
    final List<_CasePanel> panels = <_CasePanel>[];
    await tester.runAsync(() async {
      for (final _SyntheticCase c in _cases) {
        final ui.Image img = await _renderSynthetic(c, 480, 600);
        final Rect crop = await PlayerPortraitChip.debugComputeCrop(img);
        panels.add(_CasePanel(image: img, crop: crop, label: c.label));
      }
    });

    const double w = 720;
    const double h = 1700;
    await tester.binding.setSurfaceSize(const Size(w, h));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(w, h)),
          child: Material(
            color: const Color(0xFFF1F5F9),
            child: RepaintBoundary(
              key: const Key('crop-grid'),
              child: SizedBox(
                width: w,
                height: h,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Crop automático — original (com retângulo laranja) × resultado no chip',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 360 / 260,
                        physics: const NeverScrollableScrollPhysics(),
                        children: panels,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    await _saveScreenshot(tester, 'portrait_crop_cases');
  });
}
