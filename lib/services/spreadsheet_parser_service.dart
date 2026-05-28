import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;

import '../constants/player_classes.dart';
import '../models/player.dart';
import '../models/team.dart';
import 'column_mapping.dart';
import 'import_result.dart';
import 'player_photo_url.dart';

/// Estrutura intermediária independente do pacote `excel`.
class SheetData {
  const SheetData({required this.name, required this.rows});

  final String name;
  final List<List<String?>> rows;
}

/// Parser de planilhas `.xlsx` no formato CBBC.
///
/// Aceita três layouts:
/// - **Aba única "Atletas"**: cabeçalho com `clube`, `classe`, `atleta`,
///   `camisa`, `data de nascimento`, `genero`, `foto`. Uma linha por atleta.
/// - **Uma aba por clube**: nome da aba = nome do clube. Cabeçalho sem
///   coluna `clube`.
/// - **Seções por clube** (uma aba só): cada bloco começa com uma linha
///   contendo só o nome do clube, seguida do cabeçalho da seção
///   (`classe`, `nascimento`, `atleta`, `Nº`). A coluna `gênero` é
///   opcional. Útil para a planilha "RELAÇÃO DE ATLETAS" da CBBC.
class SpreadsheetParserService {
  const SpreadsheetParserService();

  static const Set<String> _requiredFieldsSingleSheet = <String>{
    'club',
    'class',
    'name',
    'shirt',
    'dob',
    'gender',
  };
  static const Set<String> _requiredFieldsPerSheet = <String>{
    'class',
    'name',
    'shirt',
    'dob',
    'gender',
  };

  /// Nome de aba reconhecido como modelo "aba única" (case-insensitive).
  static const Set<String> _singleSheetNames = <String>{
    'atletas',
    'jogadores',
    'players',
  };

  ImportResult parseBytes(Uint8List bytes) {
    final List<SheetData>? sheets = _readBytes(bytes);
    if (sheets == null) {
      return ImportResult.error(
        'Não foi possível ler o arquivo .xlsx.',
        ImportIssueCategory.fileUnreadable,
      );
    }
    return parseSheets(sheets);
  }

  ImportResult parseSheets(List<SheetData> sheets) {
    final List<SheetData> nonEmpty =
        sheets.where((SheetData s) => s.rows.any(_rowHasContent)).toList();
    if (nonEmpty.isEmpty) {
      return ImportResult.error(
        'A planilha não contém dados.',
        ImportIssueCategory.emptyFile,
      );
    }

    // Data de término da competição (metadado solto no topo de qualquer
    // aba). Procura antes do parsing principal pra que seja carregada
    // mesmo se a tabela em si tiver problema.
    final DateTime? endDate = _readCompetitionEndDate(nonEmpty);

    SheetData? singleSheet;
    for (final SheetData s in nonEmpty) {
      if (_singleSheetNames.contains(s.name.trim().toLowerCase())) {
        singleSheet = s;
        break;
      }
    }

    final ImportResult base;
    if (singleSheet != null) {
      base = _parseSingleSheet(singleSheet);
    } else {
      // Se alguma aba parece estar em formato "seções por clube" (várias
      // linhas de cabeçalho separadas por linhas-título), tenta esse parser
      // antes de cair no multi-sheet tradicional.
      final List<SheetData> sectioned = nonEmpty
          .where(_looksSectionedSheet)
          .toList();
      if (sectioned.isNotEmpty) {
        base = _parseSectionedSheets(sectioned, nonEmpty);
      } else {
        base = _parseMultiSheet(nonEmpty);
      }
    }

    return ImportResult(
      teams: base.teams,
      issues: base.issues,
      competitionName: base.competitionName,
      competitionEndDate: endDate,
    );
  }

  /// Procura por uma célula com o rótulo "Data de término da competição"
  /// (ou variações) em qualquer aba. A data é a primeira célula não-vazia
  /// na mesma linha após o rótulo, ou na linha imediatamente abaixo.
  DateTime? _readCompetitionEndDate(List<SheetData> sheets) {
    for (final SheetData sheet in sheets) {
      for (int r = 0; r < sheet.rows.length; r++) {
        final List<String?> row = sheet.rows[r];
        for (int c = 0; c < row.length; c++) {
          final String? cell = row[c];
          if (cell == null) continue;
          if (!isCompetitionEndDateLabel(cell)) continue;

          // Tenta o resto da mesma linha (à direita do rótulo).
          for (int c2 = c + 1; c2 < row.length; c2++) {
            final String? candidate = row[c2];
            if (candidate == null) continue;
            final String trimmed = candidate.trim();
            if (trimmed.isEmpty) continue;
            final DateTime? parsed = parseDateOfBirth(trimmed);
            if (parsed != null) return parsed;
          }
          // Fallback: célula imediatamente abaixo do rótulo.
          if (r + 1 < sheet.rows.length) {
            final List<String?> below = sheet.rows[r + 1];
            if (c < below.length) {
              final String? candidate = below[c];
              if (candidate != null) {
                final DateTime? parsed = parseDateOfBirth(candidate.trim());
                if (parsed != null) return parsed;
              }
            }
          }
        }
      }
    }
    return null;
  }

  // -------- modo aba única --------

  ImportResult _parseSingleSheet(SheetData sheet) {
    final _HeaderInfo? header = _readHeader(sheet);
    if (header == null) {
      return ImportResult.error(
        'A aba "${sheet.name}" não tem cabeçalho válido.',
        ImportIssueCategory.missingRequiredColumn,
      );
    }

    final List<ImportIssue> issues = <ImportIssue>[];
    final List<String> missing = <String>[];
    for (final String required in _requiredFieldsSingleSheet) {
      if (!header.fieldIndex.containsKey(required)) {
        missing.add(required);
      }
    }
    if (missing.isNotEmpty) {
      issues.add(ImportIssue(
        category: ImportIssueCategory.missingRequiredColumn,
        severity: ImportIssueSeverity.error,
        message:
            'Colunas obrigatórias ausentes: ${missing.map(_fieldLabel).join(", ")}',
        sheetName: sheet.name,
      ));
      return ImportResult(teams: const <Team>[], issues: issues);
    }

    final Map<String, _ClubBucket> buckets = <String, _ClubBucket>{};
    String? competitionName;

    for (int i = header.firstDataRow; i < sheet.rows.length; i++) {
      final List<String?> row = sheet.rows[i];
      if (!_rowHasContent(row)) continue;

      final String clubName =
          (_readCell(row, header.fieldIndex['club']) ?? '').trim();
      if (clubName.isEmpty) {
        issues.add(ImportIssue(
          category: ImportIssueCategory.missingRequiredColumn,
          severity: ImportIssueSeverity.error,
          message: 'Linha sem nome do clube.',
          sheetName: sheet.name,
          rowNumber: i + 1,
        ));
        continue;
      }

      competitionName ??=
          _readOptionalString(row, header.fieldIndex['competition']);

      final String clubId = clubIdFromName(clubName);
      final _ClubBucket bucket = buckets.putIfAbsent(
        clubId,
        () => _ClubBucket(id: clubId, name: clubName),
      );
      final Player? player = _buildPlayer(
        row: row,
        header: header,
        sheetName: sheet.name,
        rowNumber: i + 1,
        clubId: clubId,
        clubName: clubName,
        issues: issues,
      );
      if (player != null) bucket.players.add(player);
    }

    final List<Team> teams = buckets.values
        .map((_ClubBucket b) =>
            Team(id: b.id, clubName: b.name, players: b.players))
        .toList();

    _detectDuplicateShirtNumbers(teams, issues, sheet.name);

    return ImportResult(
      teams: teams,
      issues: issues,
      competitionName: competitionName,
    );
  }

  // -------- modo uma aba por clube --------

  ImportResult _parseMultiSheet(List<SheetData> sheets) {
    final List<ImportIssue> issues = <ImportIssue>[];
    final List<Team> teams = <Team>[];
    String? competitionName;

    for (final SheetData sheet in sheets) {
      final _HeaderInfo? header = _readHeader(sheet);
      if (header == null) {
        issues.add(ImportIssue(
          category: ImportIssueCategory.missingRequiredColumn,
          severity: ImportIssueSeverity.error,
          message: 'A aba "${sheet.name}" não tem cabeçalho válido.',
          sheetName: sheet.name,
        ));
        continue;
      }

      final List<String> missing = <String>[];
      for (final String required in _requiredFieldsPerSheet) {
        if (!header.fieldIndex.containsKey(required)) {
          missing.add(required);
        }
      }
      if (missing.isNotEmpty) {
        issues.add(ImportIssue(
          category: ImportIssueCategory.missingRequiredColumn,
          severity: ImportIssueSeverity.error,
          message:
              'Colunas obrigatórias ausentes: ${missing.map(_fieldLabel).join(", ")}',
          sheetName: sheet.name,
        ));
        continue;
      }

      final String clubName = sheet.name.trim();
      final String clubId = clubIdFromName(clubName);
      final _ClubBucket bucket = _ClubBucket(id: clubId, name: clubName);

      for (int i = header.firstDataRow; i < sheet.rows.length; i++) {
        final List<String?> row = sheet.rows[i];
        if (!_rowHasContent(row)) continue;

        competitionName ??=
            _readOptionalString(row, header.fieldIndex['competition']);

        final Player? player = _buildPlayer(
          row: row,
          header: header,
          sheetName: sheet.name,
          rowNumber: i + 1,
          clubId: clubId,
          clubName: clubName,
          issues: issues,
        );
        if (player != null) bucket.players.add(player);
      }

      if (bucket.players.isNotEmpty) {
        teams.add(Team(
          id: bucket.id,
          clubName: bucket.name,
          players: bucket.players,
        ));
      }
    }

    _detectDuplicateShirtNumbers(teams, issues, null);

    return ImportResult(
      teams: teams,
      issues: issues,
      competitionName: competitionName,
    );
  }

  // -------- modo "seções por clube" (uma aba, vários blocos) --------

  static const int _kMinFieldsForHeaderRow = 2;

  bool _looksSectionedSheet(SheetData sheet) {
    int headerRows = 0;
    bool sawClubColumn = false;
    for (final List<String?> row in sheet.rows) {
      final int fields = _countCanonicalFields(row);
      if (fields >= _kMinFieldsForHeaderRow) {
        headerRows++;
        if (_rowHasField(row, 'club')) sawClubColumn = true;
      }
    }
    // Precisa de pelo menos 2 cabeçalhos repetidos E nenhum deles trazer
    // a coluna `clube` (porque aí o clube vem da linha-título do bloco).
    return headerRows >= 2 && !sawClubColumn;
  }

  ImportResult _parseSectionedSheets(
    List<SheetData> sectionedSheets,
    List<SheetData> allSheets,
  ) {
    final List<ImportIssue> issues = <ImportIssue>[];
    final Map<String, _ClubBucket> buckets = <String, _ClubBucket>{};
    String? competitionName;
    final Set<String> sectionedNames = sectionedSheets
        .map((SheetData s) => s.name)
        .toSet();

    for (final SheetData sheet in sectionedSheets) {
      _parseOneSectionedSheet(
        sheet: sheet,
        buckets: buckets,
        issues: issues,
        onCompetitionName: (String name) => competitionName ??= name,
      );
    }

    // Abas restantes que não estão em modo seccionado seguem o fluxo
    // tradicional "uma aba = um clube".
    final List<SheetData> remaining = allSheets
        .where((SheetData s) => !sectionedNames.contains(s.name))
        .toList();
    if (remaining.isNotEmpty) {
      final ImportResult multi = _parseMultiSheet(remaining);
      for (final Team t in multi.teams) {
        final _ClubBucket bucket = buckets.putIfAbsent(
          t.id,
          () => _ClubBucket(id: t.id, name: t.clubName),
        );
        bucket.players.addAll(t.players);
      }
      issues.addAll(multi.issues);
      competitionName ??= multi.competitionName;
    }

    final List<Team> teams = buckets.values
        .map((_ClubBucket b) =>
            Team(id: b.id, clubName: b.name, players: b.players))
        .toList();

    _detectDuplicateShirtNumbers(teams, issues, null);

    if (teams.isEmpty && issues.where((ImportIssue i) => i.isBlocking).isEmpty) {
      issues.add(const ImportIssue(
        category: ImportIssueCategory.missingRequiredColumn,
        severity: ImportIssueSeverity.error,
        message: 'Não foi possível identificar atletas na planilha.',
      ));
    }

    return ImportResult(
      teams: teams,
      issues: issues,
      competitionName: competitionName,
    );
  }

  void _parseOneSectionedSheet({
    required SheetData sheet,
    required Map<String, _ClubBucket> buckets,
    required List<ImportIssue> issues,
    required void Function(String) onCompetitionName,
  }) {
    String? pendingTitle;
    String? currentClub;
    _HeaderInfo? currentHeader;

    for (int i = 0; i < sheet.rows.length; i++) {
      final List<String?> row = sheet.rows[i];
      if (!_rowHasContent(row)) {
        pendingTitle = null;
        continue;
      }

      // Cabeçalho de seção?
      final Map<String, int>? headerMap = _readHeaderMap(row);
      if (headerMap != null) {
        currentHeader = _HeaderInfo(fieldIndex: headerMap, firstDataRow: i + 1);
        if (pendingTitle != null) {
          currentClub = pendingTitle;
          pendingTitle = null;
        }
        continue;
      }

      // Linha-título (uma só célula com texto, não-canônica)?
      final String? title = _detectSectionTitle(row);
      if (title != null) {
        pendingTitle = title;
        continue;
      }

      // Linha de dados — exige header + clube vigentes.
      if (currentHeader == null) continue;
      if (currentClub == null) {
        // Sem título acima — pula silenciosamente (linhas de rodapé, etc).
        continue;
      }

      final String clubName = currentClub;
      final String? maybeCompetition =
          _readOptionalString(row, currentHeader.fieldIndex['competition']);
      if (maybeCompetition != null) onCompetitionName(maybeCompetition);

      final String clubId = clubIdFromName(clubName);
      final _ClubBucket bucket = buckets.putIfAbsent(
        clubId,
        () => _ClubBucket(id: clubId, name: clubName),
      );
      final Player? player = _buildPlayer(
        row: row,
        header: currentHeader,
        sheetName: sheet.name,
        rowNumber: i + 1,
        clubId: clubId,
        clubName: clubName,
        issues: issues,
      );
      if (player != null) bucket.players.add(player);
    }
  }

  /// Cabeçalho de seção precisa ter pelo menos 2 campos canônicos E
  /// cobrir as colunas essenciais (`class`, `name`, `shirt`).
  Map<String, int>? _readHeaderMap(List<String?> row) {
    final Map<String, int> map = <String, int>{};
    for (int c = 0; c < row.length; c++) {
      final String? raw = row[c];
      if (raw == null) continue;
      final String? field = canonicalField(raw);
      if (field == null) continue;
      map.putIfAbsent(field, () => c);
    }
    if (map.length < _kMinFieldsForHeaderRow) return null;
    if (!map.containsKey('class')) return null;
    if (!map.containsKey('name')) return null;
    if (!map.containsKey('shirt')) return null;
    return map;
  }

  String? _detectSectionTitle(List<String?> row) {
    String? title;
    for (final String? cell in row) {
      if (cell == null) continue;
      final String trimmed = cell.trim();
      if (trimmed.isEmpty) continue;
      if (title != null) return null; // mais de uma célula com texto
      title = trimmed;
    }
    if (title == null) return null;
    if (canonicalField(title) != null) return null;
    // Evita pegar o título do arquivo ("RELAÇÃO DE ATLETAS") como clube.
    final String upper = title.toUpperCase();
    if (upper.startsWith('RELA') && upper.contains('ATLETA')) return null;
    if (upper == 'ATLETAS' || upper == 'JOGADORES' || upper == 'PLAYERS') {
      return null;
    }
    return title;
  }

  int _countCanonicalFields(List<String?> row) {
    int count = 0;
    for (final String? cell in row) {
      if (cell == null) continue;
      if (canonicalField(cell) != null) count++;
    }
    return count;
  }

  bool _rowHasField(List<String?> row, String field) {
    for (final String? cell in row) {
      if (cell == null) continue;
      if (canonicalField(cell) == field) return true;
    }
    return false;
  }

  // -------- helpers --------

  Player? _buildPlayer({
    required List<String?> row,
    required _HeaderInfo header,
    required String sheetName,
    required int rowNumber,
    required String clubId,
    required String clubName,
    required List<ImportIssue> issues,
  }) {
    final String? shirtRaw =
        _readOptionalString(row, header.fieldIndex['shirt']);
    final String name =
        (_readOptionalString(row, header.fieldIndex['name']) ?? '').trim();
    final String classRaw =
        (_readOptionalString(row, header.fieldIndex['class']) ?? '').trim();
    final String dobRaw =
        (_readOptionalString(row, header.fieldIndex['dob']) ?? '').trim();
    final String? genderRaw =
        _readOptionalString(row, header.fieldIndex['gender']);
    final String? photoRaw =
        _readOptionalString(row, header.fieldIndex['photo']);

    final String playerLabel = name.isEmpty ? '(sem nome)' : name;
    bool valid = true;

    if (name.isEmpty) {
      issues.add(ImportIssue(
        category: ImportIssueCategory.missingPlayerName,
        severity: ImportIssueSeverity.error,
        message: 'Atleta sem nome completo.',
        sheetName: sheetName,
        rowNumber: rowNumber,
        clubName: clubName,
        playerLabel: playerLabel,
      ));
      valid = false;
    }

    final int? shirtNumber = parseShirtNumber(shirtRaw);
    if (shirtNumber == null) {
      issues.add(ImportIssue(
        category: ImportIssueCategory.missingShirtNumber,
        severity: ImportIssueSeverity.error,
        message: 'Atleta sem número de camisa (use 0-99).',
        sheetName: sheetName,
        rowNumber: rowNumber,
        clubName: clubName,
        playerLabel: playerLabel,
      ));
      valid = false;
    }

    // Classe é OPCIONAL na importação: se vier vazia ou inválida, o atleta
    // entra com classe `null` e aparece na tela de validação com o campo
    // destacado pra usuária preencher manualmente antes do jogo.
    double? playerClass;
    if (classRaw.isEmpty) {
      issues.add(ImportIssue(
        category: ImportIssueCategory.missingPlayerClass,
        severity: ImportIssueSeverity.warning,
        message:
            'Classe funcional não informada para $playerLabel — preencha manualmente no app.',
        sheetName: sheetName,
        rowNumber: rowNumber,
        clubName: clubName,
        playerLabel: playerLabel,
      ));
    } else {
      final double? parsed = parsePlayerClass(classRaw);
      if (parsed == null) {
        final String accepted = kAcceptedPlayerClasses
            .map((double c) => c.toStringAsFixed(1))
            .join(', ');
        issues.add(ImportIssue(
          category: ImportIssueCategory.invalidPlayerClass,
          severity: ImportIssueSeverity.warning,
          message:
              'Classe "$classRaw" não reconhecida para $playerLabel — ajuste manualmente no app. Aceitas: $accepted.',
          sheetName: sheetName,
          rowNumber: rowNumber,
          clubName: clubName,
          playerLabel: playerLabel,
        ));
      } else {
        playerClass = parsed;
      }
    }

    final DateTime? dob = parseDateOfBirth(dobRaw);
    if (dob == null) {
      issues.add(ImportIssue(
        category: ImportIssueCategory.missingDateOfBirth,
        severity: ImportIssueSeverity.error,
        message: 'Data de nascimento ausente ou inválida (use DD/MM/AAAA).',
        sheetName: sheetName,
        rowNumber: rowNumber,
        clubName: clubName,
        playerLabel: playerLabel,
      ));
      valid = false;
    }

    if (!valid) return null;

    return Player(
      id: '$clubId::${shirtNumber!}',
      clubName: clubName,
      shirtNumber: shirtNumber,
      fullName: name,
      playerClass: playerClass,
      dateOfBirth: dob,
      gender: _genderFromString(genderRaw),
      photoUrl: normalizePlayerPhotoUrl(photoRaw),
    );
  }

  void _detectDuplicateShirtNumbers(
    List<Team> teams,
    List<ImportIssue> issues,
    String? sheetName,
  ) {
    for (final Team team in teams) {
      final Map<int, int> count = <int, int>{};
      for (final Player p in team.players) {
        count[p.shirtNumber] = (count[p.shirtNumber] ?? 0) + 1;
      }
      count.forEach((int number, int n) {
        if (n > 1) {
          issues.add(ImportIssue(
            category: ImportIssueCategory.duplicateShirtNumber,
            severity: ImportIssueSeverity.warning,
            message:
                'Camisa #$number aparece $n vezes em ${team.clubName}.',
            sheetName: sheetName,
            clubName: team.clubName,
          ));
        }
      });
    }
  }

  PlayerGender _genderFromString(String? raw) {
    if (raw == null) return PlayerGender.unspecified;
    final String value = raw.trim().toLowerCase();
    if (value.isEmpty) return PlayerGender.unspecified;
    if (value == 'm' ||
        value == 'masc' ||
        value == 'masculino' ||
        value == 'masculina' ||
        value == 'male') {
      return PlayerGender.male;
    }
    if (value == 'f' ||
        value == 'fem' ||
        value == 'feminino' ||
        value == 'feminina' ||
        value == 'female') {
      return PlayerGender.female;
    }
    return PlayerGender.unspecified;
  }

  String _fieldLabel(String field) {
    switch (field) {
      case 'club':
        return 'clube';
      case 'class':
        return 'classe';
      case 'name':
        return 'atleta';
      case 'shirt':
        return 'camisa';
      case 'dob':
        return 'data de nascimento';
      case 'gender':
        return 'gênero';
      case 'competition':
        return 'competição';
      default:
        return field;
    }
  }

  String? _readCell(List<String?> row, int? index) {
    if (index == null) return null;
    if (index < 0 || index >= row.length) return null;
    return row[index];
  }

  String? _readOptionalString(List<String?> row, int? index) {
    final String? raw = _readCell(row, index);
    if (raw == null) return null;
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _rowHasContent(List<String?> row) {
    for (final String? cell in row) {
      if (cell != null && cell.trim().isNotEmpty) return true;
    }
    return false;
  }

  _HeaderInfo? _readHeader(SheetData sheet) {
    for (int i = 0; i < sheet.rows.length; i++) {
      final List<String?> row = sheet.rows[i];
      if (!_rowHasContent(row)) continue;
      final Map<String, int> map = <String, int>{};
      for (int c = 0; c < row.length; c++) {
        final String? raw = row[c];
        if (raw == null) continue;
        final String? field = canonicalField(raw);
        if (field == null) continue;
        map.putIfAbsent(field, () => c);
      }
      if (map.isEmpty) continue;
      return _HeaderInfo(fieldIndex: map, firstDataRow: i + 1);
    }
    return null;
  }

  List<SheetData>? _readBytes(Uint8List bytes) {
    xlsx.Excel decoded;
    try {
      decoded = xlsx.Excel.decodeBytes(bytes);
    } catch (_) {
      return null;
    }

    final List<SheetData> result = <SheetData>[];
    decoded.tables.forEach((String name, xlsx.Sheet sheet) {
      final List<List<String?>> rows = <List<String?>>[];
      for (final List<xlsx.Data?> rawRow in sheet.rows) {
        rows.add(rawRow.map(_cellToString).toList(growable: false));
      }
      result.add(SheetData(name: name, rows: rows));
    });
    return result;
  }

  String? _cellToString(xlsx.Data? cell) {
    if (cell == null) return null;
    final dynamic value = cell.value;
    if (value == null) return null;

    if (value is xlsx.DateCellValue) {
      return _formatYmd(value.year, value.month, value.day);
    }
    if (value is xlsx.DateTimeCellValue) {
      return _formatYmd(value.year, value.month, value.day);
    }

    try {
      final dynamic inner = (value as dynamic).value;
      if (inner == null) return null;
      if (inner is String) return inner;
      if (inner is num || inner is bool) return inner.toString();
      if (inner is DateTime) {
        return _formatYmd(inner.year, inner.month, inner.day);
      }
      // CellText (rich text) — tenta múltiplas estratégias de extração.
      final String? rich = _extractRichText(inner);
      if (rich != null) return rich;
      return inner.toString();
    } catch (_) {
      return value.toString();
    }
  }

  /// Tenta extrair texto plano de um objeto que pode ser `CellText`,
  /// uma lista de spans, ou outra estrutura de rich-text do pacote
  /// `excel`. Usa reflexão dinâmica pra não acoplar à API específica.
  String? _extractRichText(dynamic obj) {
    // .text direto
    try {
      final dynamic text = (obj as dynamic).text;
      if (text is String && text.isNotEmpty) return text;
    } catch (_) {}
    // .value (recursivo)
    try {
      final dynamic nested = (obj as dynamic).value;
      if (nested is String) return nested;
      if (nested != null && nested != obj) {
        final String? deeper = _extractRichText(nested);
        if (deeper != null) return deeper;
      }
    } catch (_) {}
    // .spans — concatena cada span
    try {
      final dynamic spans = (obj as dynamic).spans;
      if (spans is Iterable) {
        final StringBuffer buf = StringBuffer();
        for (final dynamic span in spans) {
          try {
            final dynamic spanText = (span as dynamic).text;
            if (spanText is String) buf.write(spanText);
          } catch (_) {
            buf.write(span.toString());
          }
        }
        final String out = buf.toString();
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}
    return null;
  }

  String _formatYmd(int year, int month, int day) =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

class _HeaderInfo {
  const _HeaderInfo({required this.fieldIndex, required this.firstDataRow});
  final Map<String, int> fieldIndex;
  final int firstDataRow;
}

class _ClubBucket {
  _ClubBucket({required this.id, required this.name});
  final String id;
  final String name;
  final List<Player> players = <Player>[];
}
