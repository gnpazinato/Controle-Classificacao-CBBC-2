import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/match_state.dart';
import '../models/roster_snapshot.dart';
import '../models/team.dart';
import 'cache_service.dart';
import 'import_result.dart';
import 'link_import_service.dart';

/// Mantém o elenco da competição vivo e sincronizado com a planilha da
/// nuvem enquanto o app estiver aberto.
///
/// Regras de funcionamento:
/// - O snapshot atual fica sempre persistido no tablet ([CacheService]),
///   então o app funciona offline com os últimos dados que conseguiu.
/// - Quando o snapshot veio de um link (Drive/OneDrive), um timer
///   periódico re-importa a planilha em segundo plano. Falhou (sem
///   internet, Drive fora do ar)? Mantém os dados salvos e tenta de novo
///   no próximo ciclo — internet instável não derruba nada.
/// - [syncNow] força uma sincronização imediata — usado ao entrar/voltar
///   pra tela de seleção de equipes, pra alteração na planilha aparecer
///   na hora, sem precisar recarregar o link na tela inicial.
/// - A sincronização NUNCA mexe numa partida em andamento: o
///   `MatchState` guarda cópia própria das duas equipes; os dados novos
///   aparecem quando o usuário volta pra montar o próximo jogo.
class RosterSyncService extends ChangeNotifier {
  RosterSyncService({
    LinkImportService? importer,
    CacheService? cache,
    this.syncInterval = const Duration(seconds: 15),
  })  : _importer = importer ?? LinkImportService(),
        _cache = cache ?? CacheService();

  final LinkImportService _importer;
  final CacheService _cache;

  /// Intervalo do re-sync automático em segundo plano. 15s equilibra
  /// atualização rápida com o custo de rebaixar a planilha (e listar as
  /// pastas de fotos) a cada ciclo nos endpoints públicos do Drive.
  final Duration syncInterval;

  RosterSnapshot? _snapshot;
  Timer? _timer;
  bool _syncing = false;
  DateTime? _lastSyncAt;
  String? _lastError;

  RosterSnapshot? get snapshot => _snapshot;
  bool get isSyncing => _syncing;

  /// Última sincronização COM SUCESSO nesta execução do app.
  DateTime? get lastSyncAt => _lastSyncAt;

  /// Mensagem da última tentativa que falhou; `null` se a última deu certo.
  String? get lastError => _lastError;

  /// `true` quando há um link de origem — ou seja, há o que sincronizar.
  bool get hasLink {
    final String? link = _snapshot?.sourceLink;
    return link != null && link.trim().isNotEmpty;
  }

  /// Assume [snapshot] como elenco atual (importação recém-feita ou
  /// restaurado do cache), persiste e liga o timer de re-sync se houver
  /// link de origem.
  Future<void> adopt(RosterSnapshot snapshot, {bool persist = true}) async {
    _snapshot = snapshot;
    _ensureTimer();
    notifyListeners();
    if (persist) await _cache.saveRoster(snapshot);
  }

  /// Substitui só as equipes (edições manuais da tela de validação:
  /// renomear clube, excluir atleta, corrigir classe…) e persiste.
  /// Atenção: a próxima sincronização com a planilha sobrescreve essas
  /// edições — a planilha da nuvem é a fonte da verdade no modo link.
  Future<void> updateTeams(List<Team> teams) async {
    final RosterSnapshot? current = _snapshot;
    if (current == null) return;
    _snapshot = current.copyWith(teams: teams, savedAt: DateTime.now());
    notifyListeners();
    await _cache.saveRoster(_snapshot!);
  }

  /// Persiste a bonificação escolhida pra competição junto com o elenco:
  /// marcada uma vez na tela de configuração, sobrevive a fechamento do
  /// app e desligamento do tablet, até o usuário escolher "Começar do
  /// zero" ou importar uma competição nova.
  Future<void> updateBonusRules(BonusRules rules) async {
    final RosterSnapshot? current = _snapshot;
    if (current == null) return;
    _snapshot = current.copyWith(bonusRules: rules, savedAt: DateTime.now());
    notifyListeners();
    await _cache.saveRoster(_snapshot!);
  }

  /// Re-importa a planilha do link agora. Devolve `true` se o elenco foi
  /// atualizado. Silencioso em caso de falha: guarda o erro em
  /// [lastError] e mantém os dados salvos.
  Future<bool> syncNow() async {
    final String? link = _snapshot?.sourceLink;
    if (link == null || link.trim().isEmpty || _syncing) return false;
    _syncing = true;
    notifyListeners();
    try {
      final ImportResult result = await _importer.importFromLink(link);
      if (result.teams.isEmpty || result.hasBlockingIssues) {
        _lastError = result.issues.isNotEmpty
            ? result.issues.first.message
            : 'A planilha voltou vazia.';
        return false;
      }
      final RosterSnapshot old = _snapshot!;
      _snapshot = RosterSnapshot(
        teams: result.teams,
        competitionName: result.competitionName ?? old.competitionName,
        competitionEndDate:
            result.competitionEndDate ?? old.competitionEndDate,
        sourceLink: link,
        savedAt: DateTime.now(),
        // A bonificação é configuração local do tablet, não vem da
        // planilha — o re-sync não pode apagá-la.
        bonusRules: old.bonusRules,
      );
      _lastSyncAt = DateTime.now();
      _lastError = null;
      await _cache.saveRoster(_snapshot!);
      return true;
    } catch (e) {
      // importFromLink não lança, mas blindamos o timer mesmo assim.
      _lastError = 'Falha inesperada na sincronização (${e.runtimeType}).';
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Descarta o elenco salvo ("Começar do zero") e para o re-sync.
  Future<void> clear() async {
    _timer?.cancel();
    _timer = null;
    _snapshot = null;
    _lastError = null;
    await _cache.clearRoster();
    notifyListeners();
  }

  void _ensureTimer() {
    if (!hasLink) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(syncInterval, (_) {
      unawaited(syncNow());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
