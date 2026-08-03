import 'package:controle_classificacao_cbbc/models/player.dart';
import 'package:controle_classificacao_cbbc/models/team.dart';
import 'package:controle_classificacao_cbbc/screens/match_setup_screen.dart';
import 'package:controle_classificacao_cbbc/services/import_result.dart';
import 'package:controle_classificacao_cbbc/services/spreadsheet_parser_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpreadsheetParserService — data de nascimento opcional', () {
    const SpreadsheetParserService parser = SpreadsheetParserService();

    test('planilha sem a coluna de nascimento importa normalmente', () {
      const SheetData sheet = SheetData(
        name: 'Atletas',
        rows: <List<String?>>[
          <String?>['clube', 'classe', 'atleta', 'camisa', 'genero'],
          <String?>['Equipe A', '2.5', 'Gabriela Giolo', '10', 'F'],
          <String?>['Equipe A', '3.0', 'Maria Souza', '7', 'F'],
        ],
      );
      final ImportResult result = parser.parseSheets(<SheetData>[sheet]);
      expect(result.hasBlockingIssues, isFalse,
          reason: result.issues.map((ImportIssue i) => i.message).join('\n'));
      expect(result.playerCount, 2);
      for (final Team team in result.teams) {
        for (final Player p in team.players) {
          expect(p.dateOfBirth, isNull);
        }
      }
    });

    test('célula de nascimento em branco importa o atleta sem aviso', () {
      const SheetData sheet = SheetData(
        name: 'Atletas',
        rows: <List<String?>>[
          <String?>[
            'clube',
            'classe',
            'atleta',
            'camisa',
            'data de nascimento',
            'genero',
          ],
          <String?>['Equipe A', '2.5', 'Gabriela Giolo', '10', null, 'F'],
          <String?>['Equipe A', '3.0', 'Maria Souza', '7', '02/02/1995', 'F'],
        ],
      );
      final ImportResult result = parser.parseSheets(<SheetData>[sheet]);
      expect(result.hasBlockingIssues, isFalse);
      expect(result.playerCount, 2);
      expect(
        result.issues.where((ImportIssue i) =>
            i.category == ImportIssueCategory.missingDateOfBirth),
        isEmpty,
      );
      final Team team = result.teams.single;
      expect(team.players.first.dateOfBirth, isNull);
      expect(team.players.last.dateOfBirth, isNotNull);
    });

    test('nascimento ilegível vira aviso (não erro) e o atleta entra', () {
      const SheetData sheet = SheetData(
        name: 'Atletas',
        rows: <List<String?>>[
          <String?>[
            'clube',
            'classe',
            'atleta',
            'camisa',
            'data de nascimento',
            'genero',
          ],
          <String?>['Equipe A', '2.5', 'Gabriela Giolo', '10', 'abc', 'F'],
        ],
      );
      final ImportResult result = parser.parseSheets(<SheetData>[sheet]);
      expect(result.hasBlockingIssues, isFalse);
      expect(result.playerCount, 1);
      final ImportIssue issue = result.issues.singleWhere((ImportIssue i) =>
          i.category == ImportIssueCategory.missingDateOfBirth);
      expect(issue.severity, ImportIssueSeverity.warning);
      expect(result.teams.single.players.single.dateOfBirth, isNull);
    });
  });

  group('Player sem data de nascimento nunca qualifica por idade', () {
    test('ageAt/isUnderU16/isUnderU23 retornam null/false', () {
      final Player player = Player(
        id: 'x::10',
        clubName: 'X',
        shirtNumber: 10,
        fullName: 'Sem Data',
        playerClass: 1.0,
      );
      final DateTime reference = DateTime.utc(2026, 8, 8);
      expect(player.ageAt(reference), isNull);
      expect(player.isUnderU16(reference), isFalse);
      expect(player.isUnderU23(reference), isFalse);
    });
  });

  group('MatchSetupScreen — bloqueio Sub-16/Sub-23 sem nascimento', () {
    Team teamWith({required String club, required bool withDob}) {
      return Team(
        id: club.toLowerCase(),
        clubName: club,
        players: <Player>[
          Player(
            id: '$club::10',
            clubName: club,
            shirtNumber: 10,
            fullName: 'Atleta $club',
            playerClass: 2.0,
            dateOfBirth: withDob ? DateTime.utc(2005, 5, 5) : null,
          ),
        ],
      );
    }

    testWidgets('atleta sem data bloqueia os switches e mostra o motivo',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MatchSetupScreen(
          teams: <Team>[
            teamWith(club: 'A', withDob: false),
            teamWith(club: 'B', withDob: true),
          ],
        ),
      ));
      expect(find.byKey(const Key('bonus-youth-blocked-message')),
          findsOneWidget);
      final SwitchListTile u16 = tester.widget(
          find.byKey(const Key('bonus-u16-checkbox')));
      final SwitchListTile u23 = tester.widget(
          find.byKey(const Key('bonus-u23-checkbox')));
      final SwitchListTile female = tester.widget(
          find.byKey(const Key('bonus-female-checkbox')));
      expect(u16.onChanged, isNull);
      expect(u23.onChanged, isNull);
      expect(female.onChanged, isNotNull);
    });

    testWidgets('com todas as datas preenchidas os switches ficam livres',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MatchSetupScreen(
          teams: <Team>[
            teamWith(club: 'A', withDob: true),
            teamWith(club: 'B', withDob: true),
          ],
        ),
      ));
      expect(find.byKey(const Key('bonus-youth-blocked-message')),
          findsNothing);
      final SwitchListTile u16 = tester.widget(
          find.byKey(const Key('bonus-u16-checkbox')));
      expect(u16.onChanged, isNotNull);
    });
  });
}
