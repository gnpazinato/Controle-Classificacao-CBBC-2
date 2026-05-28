// Testes de layout responsivo da quadra ao vivo. O objetivo aqui é
// detectar regressões de sobreposição entre os score badges dos cantos
// e os chips das jogadoras quando o tablet roda entre paisagem e
// retrato. Também valida que o toque num chip em quadra dispara o
// callback de remoção (interatividade da quadra).
//
// Estes testes não montam o app inteiro (que falha por StackOverflow no
// Flutter 3.32 — ver smoke_test.dart). Em vez disso, montam só os
// widgets afetados (PlayerPortraitChip) com viewports tablet realistas.

import 'package:controle_classificacao_cbbc/models/player.dart';
import 'package:controle_classificacao_cbbc/theme/cbbc_theme.dart';
import 'package:controle_classificacao_cbbc/widgets/player_portrait_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Player _makePlayer({
  int shirt = 7,
  double cls = 4.0,
  String name = 'Atleta Teste',
}) {
  return Player(
    id: 'p-$shirt',
    clubName: 'Clube X',
    shirtNumber: shirt,
    fullName: name,
    playerClass: cls,
    dateOfBirth: DateTime.utc(1990, 1, 1),
    gender: PlayerGender.female,
  );
}

Widget _wrap(Widget child, {Size size = const Size(1200, 800)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

void main() {
  group('PlayerPortraitChip — interatividade', () {
    testWidgets('toque no chip dispara onTap (remoção da quadra)',
        (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 120,
          height: 100,
          child: PlayerPortraitChip(
            player: _makePlayer(),
            jerseyColor: JerseyColor.darkBlue,
            isBonusEligible: false,
            maxWidth: 120,
            maxHeight: 100,
            onTap: () => taps++,
          ),
        ),
      ));

      // Sem foto, sem network: o chip mostra silhueta de fallback.
      await tester.tap(find.byType(PlayerPortraitChip));
      expect(taps, 1);
    });

    testWidgets('sem onTap o chip é só visual (não é botão)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 120,
          height: 100,
          child: PlayerPortraitChip(
            player: _makePlayer(),
            jerseyColor: JerseyColor.white,
            isBonusEligible: false,
            maxWidth: 120,
            maxHeight: 100,
          ),
        ),
      ));

      // Nenhum InkWell quando onTap é null.
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('PlayerPortraitChip — proporcionalidade', () {
    testWidgets('badges escalam com a altura do chip (não estouram em '
        'tablet pequeno)', (WidgetTester tester) async {
      Future<Size> measureBadge({required double height}) async {
        await tester.pumpWidget(_wrap(
          SizedBox(
            width: height * 0.84,
            height: height,
            child: PlayerPortraitChip(
              player: _makePlayer(shirt: 99, cls: 4.5),
              jerseyColor: JerseyColor.darkRed,
              isBonusEligible: false,
              maxWidth: height * 0.84,
              maxHeight: height,
              onTap: () {},
            ),
          ),
        ));
        // Mede o badge de classe — primeiro Container com cor de jersey.
        // Aqui usamos o widget Text com o número da classe ("4.5") como
        // proxy: ele cresce proporcionalmente ao chip.
        final Finder badgeText = find.text('4.5');
        expect(badgeText, findsOneWidget);
        return tester.getSize(badgeText);
      }

      final Size small = await measureBadge(height: 70);
      final Size large = await measureBadge(height: 140);

      // Em um chip 2× maior o texto da classe deve ser perceptivelmente
      // maior (~2×). Tolerância folgada por causa de auto-shrink.
      expect(large.width, greaterThan(small.width * 1.6),
          reason: 'badge não escalou com chip: $small → $large');
    });
  });
}
