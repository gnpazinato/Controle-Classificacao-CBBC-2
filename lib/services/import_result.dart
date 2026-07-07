import '../models/team.dart';

/// Severidade do problema detectado na importação.
enum ImportIssueSeverity { error, warning }

/// Categoria do problema — usada pra agrupar mensagens na UI.
enum ImportIssueCategory {
  fileUnreadable,
  emptyFile,
  missingRequiredColumn,
  missingShirtNumber,
  missingPlayerName,
  invalidPlayerClass,
  missingPlayerClass,
  missingDateOfBirth,
  duplicateShirtNumber,
  linkUnreachable,
  photoMatching,
}

class ImportIssue {
  const ImportIssue({
    required this.category,
    required this.severity,
    required this.message,
    this.sheetName,
    this.rowNumber,
    this.clubName,
    this.playerLabel,
  });

  final ImportIssueCategory category;
  final ImportIssueSeverity severity;
  final String message;
  final String? sheetName;
  final int? rowNumber;
  final String? clubName;
  final String? playerLabel;

  bool get isBlocking => severity == ImportIssueSeverity.error;

  @override
  String toString() => '[$severity:$category] $message';
}

class ImportResult {
  const ImportResult({
    required this.teams,
    required this.issues,
    this.competitionName,
    this.competitionEndDate,
  });

  factory ImportResult.error(String message, ImportIssueCategory category) {
    return ImportResult(
      teams: const <Team>[],
      issues: <ImportIssue>[
        ImportIssue(
          category: category,
          severity: ImportIssueSeverity.error,
          message: message,
        ),
      ],
    );
  }

  final List<Team> teams;
  final List<ImportIssue> issues;
  final String? competitionName;

  /// Data de término da competição, extraída de uma célula no topo do
  /// arquivo (rótulo "Data de término da competição: DD/MM/AAAA"). `null`
  /// se a planilha não trouxer essa informação — usuária preenche
  /// manualmente na tela de configuração da partida.
  final DateTime? competitionEndDate;

  bool get hasBlockingIssues =>
      issues.any((ImportIssue i) => i.severity == ImportIssueSeverity.error);

  int get playerCount {
    int total = 0;
    for (final Team t in teams) {
      total += t.players.length;
    }
    return total;
  }

  int get staffCount {
    int total = 0;
    for (final Team t in teams) {
      total += t.staff.length;
    }
    return total;
  }

  /// Cópia com times substituídos (usada pela importação por link para
  /// anexar fotos casadas da pasta sem tocar nos issues do parser).
  ImportResult copyWith({
    List<Team>? teams,
    List<ImportIssue>? issues,
    String? competitionName,
    DateTime? competitionEndDate,
  }) {
    return ImportResult(
      teams: teams ?? this.teams,
      issues: issues ?? this.issues,
      competitionName: competitionName ?? this.competitionName,
      competitionEndDate: competitionEndDate ?? this.competitionEndDate,
    );
  }
}
