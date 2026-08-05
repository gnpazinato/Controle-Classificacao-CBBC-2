// Simulação de chip da quadra em diferentes tamanhos (paisagem vs.
// retrato). Gera artefatos PNG em `test/_artifacts/` que podem ser
// inspecionados visualmente após qualquer mudança de layout.
//
// Por que não testar a tela inteira: o Flutter 3.32 + harness de teste
// neste app entra em StackOverflow ao montar Scaffold + Navigator + Stack
// profundo (mesmo problema do smoke_test pré-existente). Em vez disso,
// renderizamos só os componentes afetados (chip + badge de nome/placar)
// nos tamanhos que eles teriam dentro da quadra real.

import 'dart:io';
import 'dart:math' as math;
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
/// dispomos 5 chips em 3+2 igual ao `CourtBoard`, mais o badge de linha
/// única (nome + placar) no topo/base. Retorna o Widget pra
/// render+screenshot.
Widget _courtMock({
  required double courtW,
  required double courtH,
  required String labelTotal,
  required String labelLimit,
}) {
  // Mesmos valores de `lib/widgets/court_view.dart` (v2.7.0).
  const List<Offset> targetsA = <Offset>[
    Offset(0.20, 0.19),
    Offset(0.50, 0.19),
    Offset(0.80, 0.19),
    Offset(0.33, 0.37),
    Offset(0.67, 0.37),
  ];
  const List<Offset> targetsB = <Offset>[
    Offset(0.20, 0.81),
    Offset(0.50, 0.81),
    Offset(0.80, 0.81),
    Offset(0.33, 0.63),
    Offset(0.67, 0.63),
  ];
  final double slotMaxWidth = courtW * 0.22;
  final double slotMaxHeight = courtH * 0.16;
  final double badgeMargin = courtW * 0.018;

  // Mesmas fórmulas do _CourtTeamBadge.
  final double fontScore = courtW * 0.048;
  final double fontLimit = fontScore * 0.75;
  final double fontName = courtW * 0.038;
  final double padH = courtW * 0.024;
  final double padV = courtW * 0.016;
  final double radius = courtW * 0.022;
  final double gap = courtW * 0.016;

  Widget badge(
    String name,
    String t,
    String l, {
    required Key key,
    required bool alignEnd,
  }) =>
      Row(
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Container(
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
                  Flexible(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: CbbcColors.textPrimary,
                          fontSize: fontName,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        )),
                  ),
                  SizedBox(width: gap),
                  Container(
                    width: 1,
                    height: fontScore,
                    color:
                        CbbcColors.textSecondary.withValues(alpha: 0.35),
                  ),
                  SizedBox(width: gap),
                  Text(t,
                      style: TextStyle(
                        color: CbbcColors.blueDeep,
                        fontSize: fontScore,
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
            ),
          ),
        ],
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
                right: badgeMargin,
                child: badge('ESTRELA BC', labelTotal, labelLimit,
                    key: const Key('team-badge-a'), alignEnd: false),
              ),
              Positioned(
                bottom: badgeMargin,
                left: badgeMargin,
                right: badgeMargin,
                child: badge(
                    'ASSOCIAÇÃO VIDA SOBRE RODAS BC', labelTotal, labelLimit,
                    key: const Key('team-badge-b'), alignEnd: true),
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

/// Verifica o layout dos badges de nome + placar: cada um inteiro na sua
/// metade da quadra, sem invadir a área "central" de nenhum chip, e a
/// pílula (com nome longo truncado) cabendo na largura útil.
void _expectBadgeLayout(WidgetTester tester, double courtW, double courtH) {
  final Rect badgeA = _rectOf(tester, const Key('team-badge-a'));
  final Rect badgeB = _rectOf(tester, const Key('team-badge-b'));
  final double margin = courtW * 0.018;

  // Cada badge fica inteiro na metade da sua equipe.
  expect(badgeA.bottom, lessThan(courtH / 2),
      reason: 'Badge A $badgeA cruzou a linha central (h=$courtH).');
  expect(badgeB.top, greaterThan(courtH / 2),
      reason: 'Badge B $badgeB cruzou a linha central (h=$courtH).');

  // Nome longo trunca: a pílula nunca passa da largura útil.
  expect(badgeA.width, lessThanOrEqualTo(courtW - 2 * margin + 0.5));
  expect(badgeB.width, lessThanOrEqualTo(courtW - 2 * margin + 0.5));

  final List<Rect> chipRects = find
      .byType(PlayerPortraitChip)
      .evaluate()
      .map((Element e) {
        final RenderBox box = e.renderObject! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      })
      .toList(growable: false);

  // A "área central" do chip = retrato + badges agarrados; o badge de
  // equipe não pode invadir o retrato (deflate de 15% do shortest side).
  for (final Rect chip in chipRects) {
    final Rect chipCore = chip.deflate(chip.shortestSide * 0.15);
    final Rect badge = chip.center.dy < courtH / 2 ? badgeA : badgeB;
    expect(chipCore.overlaps(badge), isFalse,
        reason: 'Badge $badge sobrepõe centro do chip $chipCore '
            '(chip cheio $chip).');
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

    _expectBadgeLayout(tester, w, h);
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

    _expectBadgeLayout(tester, w, h);
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

    _expectBadgeLayout(tester, w, h);
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

    _expectBadgeLayout(tester, w, h);
    await _saveScreenshot(tester, 'quadra_large_800x1500');
  });

  test('estrela de bonificação não invade a classe do chip vizinho', () {
    // Geometria pura, espelhando as fórmulas de court_view.dart e
    // player_portrait_chip.dart (v2.7.0). Vale pra qualquer tamanho de
    // quadra porque tudo é proporcional a w (aspect fixo 1504/2816).
    const double w = 1.0;
    const double h = 2816 / 1504; // ≈ 1.872 — quadra sempre portrait
    const double chipH = h * 0.16;
    final double chipW = math.min(w * 0.22, chipH * 0.84);
    const double jersey = chipH * 0.32;
    const double classBadge = chipH * 0.30;

    // Linha de 3 (x 0.20/0.50/0.80): centros vizinhos a 0.30w.
    final double gapEntreChips = 0.30 * w - chipW;
    // Estrela: right = -jersey*0.08 → borda direita 0.08*jersey fora do
    // chip. Classe do vizinho: left = -classe*0.50 → 0.50*classe fora.
    // (Estrela e classe ocupam a mesma faixa vertical do topo do chip;
    // camisa e classe ficam em faixas distintas e não competem.)
    const double protrusoes = jersey * 0.08 + classBadge * 0.50;

    expect(protrusoes, lessThan(gapEntreChips),
        reason: 'estrela + classe ($protrusoes) não cabem no vão entre '
            'chips vizinhos ($gapEntreChips)');
  });
}
