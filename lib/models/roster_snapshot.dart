import 'team.dart';

/// "Elenco da competição": todas as equipes importadas, mais os metadados
/// necessários pra restaurar e re-sincronizar depois — inclusive sem
/// internet.
///
/// É o que fica gravado no tablet quando a importação dá certo. Difere do
/// `MatchState` (sessão de UMA partida, só 2 equipes): aqui vive a lista
/// completa de clubes carregada da planilha, o link de origem (quando a
/// importação foi por link) e a data do último salvamento.
class RosterSnapshot {
  const RosterSnapshot({
    required this.teams,
    this.competitionName,
    this.competitionEndDate,
    this.sourceLink,
    this.savedAt,
  });

  final List<Team> teams;
  final String? competitionName;
  final DateTime? competitionEndDate;

  /// Link público (Drive/OneDrive) que originou a importação. `null`
  /// quando os dados vieram de arquivo local — nesse caso não há o que
  /// sincronizar, só restaurar.
  final String? sourceLink;

  /// Momento em que este snapshot foi gravado no tablet.
  final DateTime? savedAt;

  int get playerCount {
    int total = 0;
    for (final Team t in teams) {
      total += t.players.length;
    }
    return total;
  }

  RosterSnapshot copyWith({
    List<Team>? teams,
    String? competitionName,
    DateTime? competitionEndDate,
    String? sourceLink,
    DateTime? savedAt,
  }) {
    return RosterSnapshot(
      teams: teams ?? this.teams,
      competitionName: competitionName ?? this.competitionName,
      competitionEndDate: competitionEndDate ?? this.competitionEndDate,
      sourceLink: sourceLink ?? this.sourceLink,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'teams': teams.map((Team t) => t.toJson()).toList(),
        'competitionName': competitionName,
        'competitionEndDate': competitionEndDate?.toIso8601String(),
        'sourceLink': sourceLink,
        'savedAt': savedAt?.toIso8601String(),
      };

  factory RosterSnapshot.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawTeams =
        (json['teams'] as List<dynamic>?) ?? const <dynamic>[];
    return RosterSnapshot(
      teams: rawTeams
          .map((dynamic t) => Team.fromJson(t as Map<String, dynamic>))
          .toList(),
      competitionName: json['competitionName'] as String?,
      competitionEndDate: (json['competitionEndDate'] as String?) == null
          ? null
          : DateTime.tryParse(json['competitionEndDate'] as String),
      sourceLink: json['sourceLink'] as String?,
      savedAt: (json['savedAt'] as String?) == null
          ? null
          : DateTime.tryParse(json['savedAt'] as String),
    );
  }
}
