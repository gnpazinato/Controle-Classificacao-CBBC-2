import 'package:controle_classificacao_cbbc/models/match_state.dart';
import 'package:controle_classificacao_cbbc/models/player.dart';
import 'package:controle_classificacao_cbbc/models/roster_snapshot.dart';
import 'package:controle_classificacao_cbbc/models/team.dart';
import 'package:controle_classificacao_cbbc/services/cache_service.dart';
import 'package:controle_classificacao_cbbc/services/import_result.dart';
import 'package:controle_classificacao_cbbc/services/link_import_service.dart';
import 'package:controle_classificacao_cbbc/services/roster_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Team _team(String id, String name, {int players = 2}) {
  return Team(
    id: id,
    clubName: name,
    players: <Player>[
      for (int i = 1; i <= players; i++)
        Player(
          id: '$id::$i',
          clubName: name,
          shirtNumber: i,
          fullName: 'Atleta $i de $name',
          playerClass: 1.0,
        ),
    ],
  );
}

/// Importador fake: devolve resultados enfileirados, na ordem.
class _FakeLinkImporter extends LinkImportService {
  _FakeLinkImporter(this.results);

  final List<ImportResult> results;
  final List<String> calls = <String>[];

  @override
  Future<ImportResult> importFromLink(
    String rawUrl, {
    void Function(String stage)? onProgress,
  }) async {
    calls.add(rawUrl);
    if (results.isEmpty) {
      return ImportResult.error('fim', ImportIssueCategory.linkUnreachable);
    }
    return results.removeAt(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String kLink = 'https://drive.google.com/drive/folders/ABC';

  group('RosterSnapshot no CacheService', () {
    test('sobrevive a round-trip e ao clear() da sessão de partida',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final CacheService cache = CacheService();

      expect(await cache.loadRoster(), isNull);

      final RosterSnapshot snapshot = RosterSnapshot(
        teams: <Team>[_team('aguias', 'Águias'), _team('tigres', 'Tigres')],
        competitionName: 'Copa CBBC 2026',
        competitionEndDate: DateTime.utc(2026, 9, 20),
        sourceLink: kLink,
        savedAt: DateTime.utc(2026, 8, 5, 12),
      );
      await cache.saveRoster(snapshot);

      // "Começar do zero" numa partida limpa só o MatchState — o elenco
      // da competição fica.
      await cache.clear();

      final RosterSnapshot? loaded = await cache.loadRoster();
      expect(loaded, isNotNull);
      expect(loaded!.teams.length, 2);
      expect(loaded.teams.first.clubName, 'Águias');
      expect(loaded.teams.first.players.length, 2);
      expect(loaded.competitionName, 'Copa CBBC 2026');
      expect(loaded.competitionEndDate, DateTime.utc(2026, 9, 20));
      expect(loaded.sourceLink, kLink);
      expect(loaded.playerCount, 4);

      await cache.clearRoster();
      expect(await cache.loadRoster(), isNull);
    });

    test('snapshot sem equipes é tratado como inexistente', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final CacheService cache = CacheService();
      await cache.saveRoster(const RosterSnapshot(teams: <Team>[]));
      expect(await cache.loadRoster(), isNull);
    });

    test('bonificação sobrevive ao round-trip; snapshot antigo fica null',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final CacheService cache = CacheService();

      // Snapshot gravado por versão anterior (sem o campo): null, não
      // "tudo desmarcado".
      await cache.saveRoster(RosterSnapshot(
        teams: <Team>[_team('aguias', 'Águias')],
      ));
      expect((await cache.loadRoster())!.bonusRules, isNull);

      await cache.saveRoster(RosterSnapshot(
        teams: <Team>[_team('aguias', 'Águias')],
        bonusRules: const BonusRules(youthU23: true),
      ));
      final RosterSnapshot? loaded = await cache.loadRoster();
      expect(loaded!.bonusRules, isNotNull);
      expect(loaded.bonusRules!.youthU23, isTrue);
      expect(loaded.bonusRules!.youthU16, isFalse);
      expect(loaded.bonusRules!.female, isFalse);
    });
  });

  group('RosterSyncService', () {
    test('syncNow substitui o elenco inteiro e persiste', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final CacheService cache = CacheService();
      final _FakeLinkImporter importer = _FakeLinkImporter(<ImportResult>[
        ImportResult(
          teams: <Team>[
            _team('aguias', 'Águias', players: 3), // atleta novo
            _team('tigres', 'Tigres'),
            _team('leoes', 'Leões'), // equipe nova na planilha
          ],
          issues: const <ImportIssue>[],
          competitionName: 'Copa CBBC 2026',
        ),
      ]);
      final RosterSyncService sync =
          RosterSyncService(importer: importer, cache: cache);
      addTearDown(sync.dispose);

      await sync.adopt(RosterSnapshot(
        teams: <Team>[_team('aguias', 'Águias'), _team('tigres', 'Tigres')],
        sourceLink: kLink,
        savedAt: DateTime.utc(2026, 8, 5),
      ));
      expect(sync.hasLink, isTrue);

      final bool updated = await sync.syncNow();
      expect(updated, isTrue);
      expect(importer.calls, <String>[kLink]);
      expect(sync.snapshot!.teams.length, 3);
      expect(
        sync.snapshot!.teams.map((Team t) => t.clubName),
        containsAll(<String>['Águias', 'Tigres', 'Leões']),
      );
      // Atleta novo incluído na equipe existente.
      expect(sync.snapshot!.teams.first.players.length, 3);
      expect(sync.lastSyncAt, isNotNull);
      expect(sync.lastError, isNull);

      // Persistiu: outra instância do cache lê o elenco novo.
      final RosterSnapshot? onDisk = await cache.loadRoster();
      expect(onDisk!.teams.length, 3);
      expect(onDisk.sourceLink, kLink);
    });

    test('falha de rede mantém os dados salvos e registra o erro',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final CacheService cache = CacheService();
      final _FakeLinkImporter importer = _FakeLinkImporter(<ImportResult>[
        ImportResult.error(
            'sem internet', ImportIssueCategory.linkUnreachable),
        ImportResult(
          teams: <Team>[_team('aguias', 'Águias')],
          issues: const <ImportIssue>[],
        ),
      ]);
      final RosterSyncService sync =
          RosterSyncService(importer: importer, cache: cache);
      addTearDown(sync.dispose);

      final RosterSnapshot original = RosterSnapshot(
        teams: <Team>[_team('aguias', 'Águias'), _team('tigres', 'Tigres')],
        sourceLink: kLink,
      );
      await sync.adopt(original);

      // 1ª tentativa: offline → elenco intacto, erro registrado.
      expect(await sync.syncNow(), isFalse);
      expect(sync.snapshot!.teams.length, 2);
      expect(sync.lastError, contains('sem internet'));
      expect(sync.lastSyncAt, isNull);

      // Internet voltou: próxima tentativa limpa o erro e atualiza.
      expect(await sync.syncNow(), isTrue);
      expect(sync.snapshot!.teams.length, 1);
      expect(sync.lastError, isNull);
      expect(sync.lastSyncAt, isNotNull);
    });

    test('sem link de origem não há o que sincronizar', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final _FakeLinkImporter importer = _FakeLinkImporter(<ImportResult>[]);
      final RosterSyncService sync = RosterSyncService(
          importer: importer, cache: CacheService());
      addTearDown(sync.dispose);

      await sync.adopt(RosterSnapshot(teams: <Team>[_team('aguias', 'Águias')]));
      expect(sync.hasLink, isFalse);
      expect(await sync.syncNow(), isFalse);
      expect(importer.calls, isEmpty);
    });

    test('updateTeams grava edições manuais no elenco persistido',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final CacheService cache = CacheService();
      final RosterSyncService sync = RosterSyncService(
          importer: _FakeLinkImporter(<ImportResult>[]), cache: cache);
      addTearDown(sync.dispose);

      await sync.adopt(RosterSnapshot(
        teams: <Team>[_team('aguias', 'Águias'), _team('tigres', 'Tigres')],
      ));
      await sync.updateTeams(<Team>[_team('aguias', 'Águias Renomeadas')]);

      expect(sync.snapshot!.teams.single.clubName, 'Águias Renomeadas');
      final RosterSnapshot? onDisk = await cache.loadRoster();
      expect(onDisk!.teams.single.clubName, 'Águias Renomeadas');
    });

    test('updateBonusRules persiste e o re-sync da planilha preserva',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final CacheService cache = CacheService();
      final _FakeLinkImporter importer = _FakeLinkImporter(<ImportResult>[
        ImportResult(
          teams: <Team>[_team('aguias', 'Águias')],
          issues: const <ImportIssue>[],
        ),
      ]);
      final RosterSyncService sync =
          RosterSyncService(importer: importer, cache: cache);
      addTearDown(sync.dispose);

      await sync.adopt(RosterSnapshot(
        teams: <Team>[_team('aguias', 'Águias')],
        sourceLink: kLink,
      ));
      await sync.updateBonusRules(
          const BonusRules(youthU16: true, youthU23: true));

      // Persistiu: é o que restaura a seleção depois de fechar o app ou
      // desligar o tablet entre jogos.
      RosterSnapshot? onDisk = await cache.loadRoster();
      expect(onDisk!.bonusRules!.youthU16, isTrue);
      expect(onDisk.bonusRules!.youthU23, isTrue);

      // O re-sync monta um snapshot novo a partir da planilha — a
      // bonificação (configuração local) não pode ser perdida.
      expect(await sync.syncNow(), isTrue);
      expect(sync.snapshot!.bonusRules!.youthU16, isTrue);
      onDisk = await cache.loadRoster();
      expect(onDisk!.bonusRules!.youthU23, isTrue);
    });

    test('clear() descarta o elenco salvo', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final CacheService cache = CacheService();
      final RosterSyncService sync = RosterSyncService(
          importer: _FakeLinkImporter(<ImportResult>[]), cache: cache);
      addTearDown(sync.dispose);

      await sync.adopt(RosterSnapshot(
        teams: <Team>[_team('aguias', 'Águias')],
        sourceLink: kLink,
      ));
      expect(await cache.loadRoster(), isNotNull);

      await sync.clear();
      expect(sync.snapshot, isNull);
      expect(await cache.loadRoster(), isNull);
    });
  });
}
