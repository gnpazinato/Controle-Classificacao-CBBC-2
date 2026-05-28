// Simulação de chip da quadra em diferentes tamanhos (paisagem vs.
// retrato). Gera artefatos PNG em `test/_artifacts/` que podem ser
// inspecionados visualmente após qualquer mudança de layout.
//
// Por que não testar a tela inteira: o Flutter 3.32 + harness de teste
// neste app entra em StackOverflow ao montar Scaffold + Navigator + Stack
// profundo (mesmo problema do smoke_test pré-existente). Em vez disso,
// renderizamos só os componentes afetados (chip + score badge) nos
// tamanhos que eles teriam dentro da quadra real, em paisagem e retrato.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:controle_classificacao_cbbc/models/player.dart';
import 'package:controle_classificacao_cbbc/theme/cbbc_theme.dart';
import 'package:controle_classificacao_cbbc/widgets/player_portrait_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Player _player({
  required int shirt,
  required double cls,
  required String name,
  PlayerGender gender = PlayerGender.female,
}) {
  return Player(
    id: 'p::$shirt',
    clubName: 'X',
    shirtNumber: shirt,
    fullName: name,
    playerClass: cls,
    dateOfBirth: DateTime.utc(1990, 1, 1),
    gender: gender,
  );
}

/// Reproduz a geometria de slots da quadra: tomamos `courtW × courtH` e
/// dispomos 5 chips em 3+2 igual a `_CourtView`, mais um score badge no
/// canto. Retorna o Widget pra render+screenshot.
Widget _courtMock({
  required double courtW,
  required double courtH,
  required String labelTotal,
  required String labelLimit,
}) {
  // Mesmos valores de `lib/screens/lineup_control_screen.dart`.
  const List<Offset> targetsA = <Offset>[
    Offset(0.22, 0.13),
    Offset(0.50, 0.13),
    Offset(0.78, 0.13),
    Offset(0.36, 0.37),
    Offset(0.64, 0.37),
  ];
  const List<Offset> targetsB = <Offset>[
    Offset(0.22, 0.87),
    Offset(0.50, 0.87),
    Offset(0.78, 0.87),
    Offset(0.36, 0.63),
    Offset(0.64, 0.63),
  ];
  final double slotMaxWidth = courtW * 0.22;
  final double slotMaxHeight = courtH * 0.16;
  final double badgeAnchor = courtW;
  final double badgeMargin = badgeAnchor * 0.018;

  // Mesma fórmula do _CourtScoreBadge novo.
  final double fontTotal = (badgeAnchor * 0.034).clamp(11.0, 22.0);
  final double fontLimit = fontTotal * 0.78;
  final double padH = (badgeAnchor * 0.022).clamp(6.0, 14.0);
  final double padV = (badgeAnchor * 0.014).clamp(3.0, 8.0);
  final double radius = (badgeAnchor * 0.022).clamp(7.0, 12.0);

  Widget badge(String t, String l, {required Key key}) => Container(
        key: key,
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.40),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(t,
                style: TextStyle(
                  color: CbbcColors.blueDeep,
                  fontSize: fontTotal,
                  fontWeight: FontWeight.w900,
                  height: 1,
                )),
            Text(' / $l',
                style: TextStyle(
                  color: CbbcColors.textSecondary,
                  fontSize: fontLimit,
                  fontWeight: FontWeight.w600,
                  height: 1,
                )),
          ],
        ),
      );

  final List<Player> teamA = <Player>[
    _player(shirt: 21, cls: 2.0, name: 'GABRIELA'),
    _player(shirt: 17, cls: 1.0, name: 'CRISTIANE'),
    _player(shirt: 19, cls: 1.0, name: 'BRENDA'),
    _player(shirt: 29, cls: 4.5, name: 'LETICIA'),
    _player(shirt: 22, cls: 4.0, name: 'GEISA'),
  ];
  final List<Player> teamB = <Player>[
    _player(shirt: 5, cls: 2.0, name: 'PAULA'),
    _player(shirt: 4, cls: 3.5, name: 'IVANILDE'),
    _player(shirt: 41, cls: 3.5, name: 'PAOLA'),
    _player(shirt: 21, cls: 3.0, name: 'VALDIRENE'),
    _player(shirt: 9, cls: 2.0, name: 'BRUNA'),
  ];

  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(size: Size(courtW, courtH)),
      child: Material(
        color: const Color(0xFFE8DCC4),
        child: RepaintBoundary(
          key: const Key('screenshot-root'),
          child: SizedBox(
          width: courtW,
          height: courtH,
          child: Stack(
            children: <Widget>[
              for (int i = 0; i < 5; i++)
                Positioned(
                  left: courtW * targetsA[i].dx,
                  top: courtH * targetsA[i].dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: PlayerPortraitChip(
                      player: teamA[i],
                      jerseyColor: JerseyColor.white,
                      isBonusEligible: i == 0,
                      maxWidth: slotMaxWidth,
                      maxHeight: slotMaxHeight,
                      onTap: () {},
                    ),
                  ),
                ),
              for (int i = 0; i < 5; i++)
                Positioned(
                  left: courtW * targetsB[i].dx,
                  top: courtH * targetsB[i].dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: PlayerPortraitChip(
                      player: teamB[i],
                      jerseyColor: JerseyColor.darkBlue,
                      isBonusEligible: i == 0,
                      maxWidth: slotMaxWidth,
                      maxHeight: slotMaxHeight,
                      onTap: () {},
                    ),
                  ),
                ),
              Positioned(
                top: badgeMargin,
                left: badgeMargin,
                child: badge(labelTotal, labelLimit,
                    key: const Key('score-corner-top-left')),
              ),
              Positioned(
                bottom: badgeMargin,
                right: badgeMargin,
                child: badge(labelTotal, labelLimit,
                    key: const Key('score-corner-bottom-right')),
              ),
            ],
          ),
        ),
        ),
      ),
    ),
  );
}

Future<void> _saveScreenshot(WidgetTester tester, String name) async {
  // toImage requer o test do binding em "frames" — sem isso o teste
  // bloqueia esperando pelo gpu pipeline. Roda dentro de runAsync pra
  // permitir IO real (writeAsBytesSync) durante o teste.
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary = tester.renderObject<
        RenderRepaintBoundary>(find.byKey(const Key('screenshot-root')));
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final Directory dir = Directory('test/_artifacts');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

/// Mede um widget por chave e retorna seu retângulo global.
Rect _rectOf(WidgetTester tester, Key key) {
  final RenderBox box =
      tester.renderObject<RenderBox>(find.byKey(key));
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Verifica que os badges dos cantos não sobrepõem a área "central" dos
/// chips das extremidades. Usado para garantir layout responsivo em
/// vários tamanhos.
void _expectNoOverlapAtCorner(WidgetTester tester, double courtW) {
  final Rect topLeftBadge =
      _rectOf(tester, const Key('score-corner-top-left'));
  final Rect bottomRightBadge =
      _rectOf(tester, const Key('score-corner-bottom-right'));

  final List<Rect> chipRects = find
      .byType(PlayerPortraitChip)
      .evaluate()
      .map((Element e) {
        final RenderBox box = e.renderObject! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      })
      .toList(growable: false);

  // Chip de extremidade esquerda na linha de frente: o de menor x.dx na
  // metade superior. Mesma ideia pra direito-fundo.
  Rect? leftFrontChip;
  Rect? rightBackChip;
  for (final Rect r in chipRects) {
    if (r.center.dx < courtW / 2 && r.top < courtW) {
      if (leftFrontChip == null || r.left < leftFrontChip.left) {
        leftFrontChip = r;
      }
    }
    if (r.center.dx > courtW / 2) {
      if (rightBackChip == null || r.right > rightBackChip.right) {
        rightBackChip = r;
      }
    }
  }

  void check(String label, Rect badge, Rect chip) {
    // A "área central" do chip = retrato + badges agarrados; vamos exigir
    // que o badge dos cantos não invada o retrato (deflate de 15 % do
    // shortest side).
    final Rect chipCore = chip.deflate(chip.shortestSide * 0.15);
    expect(chipCore.overlaps(badge), isFalse,
        reason: '$label $badge sobrepõe centro do chip extremo '
            '$chipCore (chip cheio $chip).');
  }

  if (leftFrontChip != null) {
    check('Badge superior-esquerdo', topLeftBadge, leftFrontChip);
  }
  if (rightBackChip != null) {
    check('Badge inferior-direito', bottomRightBadge, rightBackChip);
  }
}

void main() {
  testWidgets('quadra portrait — 600x1124 (tablet portrait padrão)',
      (WidgetTester tester) async {
    const double w = 600;
    const double h = 1124;
    await tester.binding.setSurfaceSize(const Size(w, h));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_courtMock(
      courtW: w,
      courtH: h,
      labelTotal: '12.0',
      labelLimit: '14.0',
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    _expectNoOverlapAtCorner(tester, w);
    await _saveScreenshot(tester, 'quadra_portrait_600x1124');
  });

  testWidgets('quadra landscape — 400x750 (área dentro de tablet landscape)',
      (WidgetTester tester) async {
    const double w = 400;
    const double h = 750;
    await tester.binding.setSurfaceSize(const Size(w, h));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_courtMock(
      courtW: w,
      courtH: h,
      labelTotal: '12.5',
      labelLimit: '14.0',
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    _expectNoOverlapAtCorner(tester, w);
    await _saveScreenshot(tester, 'quadra_landscape_400x750');
  });

  testWidgets('quadra muito pequena — 320x600 (celular)',
      (WidgetTester tester) async {
    const double w = 320;
    const double h = 600;
    await tester.binding.setSurfaceSize(const Size(w, h));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_courtMock(
      courtW: w,
      courtH: h,
      labelTotal: '8.5',
      labelLimit: '14.0',
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    _expectNoOverlapAtCorner(tester, w);
    await _saveScreenshot(tester, 'quadra_phone_320x600');
  });

  testWidgets('quadra grande — 800x1500 (tablet 12" portrait)',
      (WidgetTester tester) async {
    const double w = 800;
    const double h = 1500;
    await tester.binding.setSurfaceSize(const Size(w, h));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_courtMock(
      courtW: w,
      courtH: h,
      labelTotal: '15.5',
      labelLimit: '15.0',
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    _expectNoOverlapAtCorner(tester, w);
    await _saveScreenshot(tester, 'quadra_large_800x1500');
  });
}
