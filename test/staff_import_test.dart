import 'package:controle_classificacao_cbbc/models/staff_member.dart';
import 'package:controle_classificacao_cbbc/models/team.dart';
import 'package:controle_classificacao_cbbc/screens/validation_summary_screen.dart';
import 'package:controle_classificacao_cbbc/services/column_mapping.dart';
import 'package:controle_classificacao_cbbc/services/import_result.dart';
import 'package:controle_classificacao_cbbc/services/spreadsheet_parser_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isStaffRole', () {
    test('vazio/nulo/atleta continuam sendo atleta', () {
      expect(isStaffRole(null), isFalse);
      expect(isStaffRole(''), isFalse);
      expect(isStaffRole('  '), isFalse);
      expect(isStaffRole('Atleta'), isFalse);
      expect(isStaffRole('ATLETA'), isFalse);
      expect(isStaffRole('jogadora'), isFalse);
      expect(isStaffRole('Player'), isFalse);
    });

    test('qualquer outra função marca comissão técnica', () {
      expect(isStaffRole('Técnico'), isTrue);
      expect(isStaffRole('tecnico'), isTrue);
      expect(isStaffRole('Auxiliar técnico'), isTrue);
      expect(isStaffRole('Fisioterapeuta'), isTrue);
      expect(isStaffRole('Mecânico'), isTrue);
    });
  });

  group('SpreadsheetParserService — coluna função', () {
    SheetData sheetWithStaff() {
      return const SheetData(
        name: 'Atletas',
        rows: <List<String?>>[
          <String?>[
            'clube',
            'classe',
            'atleta',
            'camisa',
            'data de nascimento',
            'genero',
            'função',
          ],
          <String?>[
            'Equipe A',
            '2.5',
            'Gabriela Giolo',
            '10',
            '01/01/1999',
            'F',
            'Atleta',
          ],
          // Comissão: só nome + função — sem camisa/classe/nascimento.
          <String?>['Equipe A', null, 'João da Silva', null, null, null, 'Técnico'],
          <String?>['Equipe A', null, 'Ana Prado', null, null, null, 'Fisioterapeuta'],
          <String?>[
            'Equipe B',
            '3.0',
            'Maria Souza',
            '7',
            '02/02/1995',
            'F',
            null,
          ],
        ],
      );
    }

    test('linhas com função ≠ atleta viram comissão técnica sem erros', () {
      const SpreadsheetParserService parser = SpreadsheetParserService();
      final ImportResult result =
          parser.parseSheets(<SheetData>[sheetWithStaff()]);

      expect(result.hasBlockingIssues, isFalse,
          reason: result.issues.map((ImportIssue i) => i.message).join('\n'));

      final Team teamA =
          result.teams.firstWhere((Team t) => t.clubName == 'Equipe A');
      final Team teamB =
          result.teams.firstWhere((Team t) => t.clubName == 'Equipe B');

      expect(teamA.players, hasLength(1));
      expect(teamA.staff, hasLength(2));
      expect(teamA.staff.first.fullName, 'João da Silva');
      expect(teamA.staff.first.role, 'Técnico');
      expect(teamA.staff.last.role, 'Fisioterapeuta');

      // Função vazia → atleta normal.
      expect(teamB.players, hasLength(1));
      expect(teamB.staff, isEmpty);

      expect(result.playerCount, 2);
      expect(result.staffCount, 2);
    });

    test('comissão não entra na checagem de camisas duplicadas', () {
      const SpreadsheetParserService parser = SpreadsheetParserService();
      final ImportResult result =
          parser.parseSheets(<SheetData>[sheetWithStaff()]);
      final Iterable<ImportIssue> duplicated = result.issues.where(
          (ImportIssue i) =>
              i.category == ImportIssueCategory.duplicateShirtNumber);
      expect(duplicated, isEmpty);
    });
  });

  group('Team JSON com comissão', () {
    test('roundtrip preserva staff', () {
      final Team team = Team(
        id: 'club-x',
        clubName: 'X',
        staff: <StaffMember>[
          StaffMember(
            id: 'club-x::staff::joao',
            clubName: 'X',
            fullName: 'João',
            role: 'Técnico',
            photoUrl: 'https://example.com/j.jpg',
          ),
        ],
      );
      final Team restored = Team.fromJson(team.toJson());
      expect(restored.staff, hasLength(1));
      expect(restored.staff.single.fullName, 'João');
      expect(restored.staff.single.role, 'Técnico');
      expect(restored.staff.single.photoUrl, 'https://example.com/j.jpg');
    });

    test('JSON antigo (sem chave staff) carrega com lista vazia', () {
      final Team restored = Team.fromJson(<String, dynamic>{
        'id': 'club-y',
        'clubName': 'Y',
        'players': <dynamic>[],
      });
      expect(restored.staff, isEmpty);
    });
  });

  testWidgets('resumo lista a comissão no fim da lista do clube',
      (WidgetTester tester) async {
    final ImportResult result = ImportResult(
      teams: <Team>[
        Team(
          id: 'club-equipe_a',
          clubName: 'Equipe A',
          staff: <StaffMember>[
            StaffMember(
              id: 'club-equipe_a::staff::joao_da_silva',
              clubName: 'Equipe A',
              fullName: 'João da Silva',
              role: 'Técnico',
            ),
          ],
        ),
      ],
      issues: const <ImportIssue>[],
    );

    await tester.pumpWidget(MaterialApp(
      home: ValidationSummaryScreen(result: result),
    ));
    await tester.pump();

    expect(find.text('0 atleta(s) · 1 na comissão técnica'), findsOneWidget);

    // Expande o card do clube pra revelar as linhas.
    await tester.tap(find.byKey(const Key('team-tile-club-equipe_a')));
    await tester.pumpAndSettle();

    expect(find.text('COMISSÃO TÉCNICA'), findsOneWidget);
    expect(find.text('João da Silva'), findsOneWidget);
    expect(find.text('Técnico'), findsOneWidget);
  });
}
