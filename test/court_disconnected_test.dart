// Quadra "zerada" do viewer quando o tablet perde a conexão: com
// `disconnected: true` o CourtBoard não desenha nenhum chip nem badge e
// mostra o aviso central. Montado sem Scaffold/Navigator (ver
// court_simulation_test.dart sobre o StackOverflow do harness); pode
// falhar no Codespace Alpine/musl — validação definitiva no CI ubuntu.

import 'package:controle_classificacao_cbbc/models/match_state.dart';
import 'package:controle_classificacao_cbbc/models/player.dart';
import 'package:controle_classificacao_cbbc/models/team.dart';
import 'package:controle_classificacao_cbbc/widgets/court_view.dart';
import 'package:controle_classificacao_cbbc/widgets/player_portrait_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Player _player(String id, int shirt) => Player(
      id: id,
      clubName: 'X',
      shirtNumber: shirt,
      fullName: 'Atleta $shirt',
      playerClass: 1.0,
      dateOfBirth: DateTime.utc(1990, 1, 1),
      gender: PlayerGender.female,
    );

MatchState _stateComAtletasEmQuadra() {
  final Team teamA = Team(
    id: 'a',
    clubName: 'Estrela BC',
    players: <Player>[_player('a1', 4), _player('a2', 7)],
  );
  final Team teamB = Team(
    id: 'b',
    clubName: 'Associação Vida Sobre Rodas BC',
    players: <Player>[_player('b1', 5)],
  );
  return MatchState(
    teamA: teamA,
    teamB: teamB,
    teamASlots: <String?>['a1', 'a2'],
    teamBSlots: <String?>['b1'],
  );
}

Widget _wrap(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(600, 1124)),
      child: Material(
        child: Center(
          child: SizedBox(width: 500, height: 936, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('conectado: chips e badges de equipe visíveis, sem aviso',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(CourtBoard(
      state: _stateComAtletasEmQuadra(),
      courtStyle: CourtStyle.claro,
      showHints: false,
    )));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PlayerPortraitChip), findsNWidgets(3));
    expect(find.byKey(const Key('team-badge-a')), findsOneWidget);
    expect(find.byKey(const Key('team-badge-b')), findsOneWidget);
    expect(find.text('Estrela BC'), findsOneWidget);
    expect(find.text('Sem conexão com o tablet'), findsNothing);
  });

  testWidgets('disconnected: quadra zerada com o aviso central',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(CourtBoard(
      state: _stateComAtletasEmQuadra(),
      courtStyle: CourtStyle.claro,
      showHints: false,
      disconnected: true,
    )));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Sem conexão com o tablet'), findsOneWidget);
    expect(find.byKey(const Key('court-disconnected')), findsOneWidget);
    expect(find.byType(PlayerPortraitChip), findsNothing);
    expect(find.byKey(const Key('team-badge-a')), findsNothing);
    expect(find.byKey(const Key('team-badge-b')), findsNothing);
  });
}
