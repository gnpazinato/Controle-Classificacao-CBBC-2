import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../constants/player_classes.dart';
import '../models/player.dart';
import '../models/staff_member.dart';
import '../models/team.dart';
import 'column_mapping.dart';
import 'import_result.dart';
import 'player_photo_url.dart';

/// Parser de PDFs com tabela de atletas (texto extraível).
///
/// Estratégia:
/// 1. Extrai texto bruto do PDF página a página.
/// 2. Para cada página, quebra em linhas. Encontra a linha-cabeçalho
///    procurando tokens reconhecidos (clube/classe/atleta/...) — usa o
///    mesmo `canonicalField` da planilha.
/// 3. Determina, pela posição das palavras-chave na linha-cabeçalho, as
///    "colunas" virtuais (índices de caractere).
/// 4. Para cada linha de dados, fatia pelos índices das colunas.
///
/// Quando o PDF não contém o nome do clube nas linhas (só no cabeçalho
/// da página), usa-se o texto antes da linha-cabeçalho como nome do
/// clube. Útil para PDFs no formato "Clube X" + tabela.
class PdfParserService {
  const PdfParserService();

  ImportResult parseBytes(Uint8List bytes) {
    final PdfDocument doc;
    try {
      doc = PdfDocument(inputBytes: bytes);
    } catch (_) {
      return ImportResult.error(
        'Não foi possível ler o arquivo PDF.',
        ImportIssueCategory.fileUnreadable,
      );
    }

    try {
      final List<ImportIssue> issues = <ImportIssue>[];
      final Map<String, _ClubBucket> buckets = <String, _ClubBucket>{};
      String? competitionName;

      final PdfTextExtractor extractor = PdfTextExtractor(doc);
      final int pages = doc.pages.count;
      bool anyHeaderFound = false;

      for (int p = 0; p < pages; p++) {
        final String pageText = extractor.extractText(startPageIndex: p);
        if (pageText.trim().isEmpty) continue;

        final _PageParse parsed = _parsePage(
          pageText: pageText,
          pageNumber: p + 1,
          buckets: buckets,
          issues: issues,
          competitionName: competitionName,
        );
        if (parsed.foundHeader) anyHeaderFound = true;
        competitionName ??= parsed.competitionName;
      }

      if (!anyHeaderFound) {
        return ImportResult.error(
          'Não encontrei cabeçalho com as colunas esperadas '
          '(clube, classe, atleta, camisa, gênero) '
          'em nenhuma página do PDF.',
          ImportIssueCategory.missingRequiredColumn,
        );
      }

      final List<Team> teams = buckets.values
          .map((_ClubBucket b) => Team(
              id: b.id,
              clubName: b.name,
              players: b.players,
              staff: b.staff))
          .toList();

      _detectDuplicateShirtNumbers(teams, issues);

      return ImportResult(
        teams: teams,
        issues: issues,
        competitionName: competitionName,
      );
    } finally {
      doc.dispose();
    }
  }

  _PageParse _parsePage({
    required String pageText,
    required int pageNumber,
    required Map<String, _ClubBucket> buckets,
    required List<ImportIssue> issues,
    required String? competitionName,
  }) {
    final List<String> lines = pageText
        .split(RegExp(r'\r?\n'))
        .map((String l) => l.replaceAll('\t', '  '))
        .where((String l) => l.trim().isNotEmpty)
        .toList();

    int? headerIndex;
    _HeaderLayout? layout;
    for (int i = 0; i < lines.length; i++) {
      final _HeaderLayout? candidate = _tryParseHeader(lines[i]);
      if (candidate != null) {
        headerIndex = i;
        layout = candidate;
        break;
      }
    }

    if (headerIndex == null || layout == null) {
      return const _PageParse(foundHeader: false);
    }

    // Tenta extrair nome do clube das linhas antes do cabeçalho.
    String? defaultClub;
    for (int i = headerIndex - 1; i >= 0; i--) {
      final String l = lines[i].trim();
      if (l.isEmpty) continue;
      final RegExpMatch? m =
          RegExp(r'(?:clube|club|equipe|time)\s*[:\-]\s*(.+)$',
                  caseSensitive: false)
              .firstMatch(l);
      if (m != null) {
        defaultClub = m.group(1)!.trim();
        break;
      }
      // Linha sem prefixo: usa como nome do clube (heurística).
      if (i == headerIndex - 1 && l.length < 80) {
        defaultClub = l;
      }
    }

    String? localCompetition = competitionName;
    for (int i = 0; i < headerIndex; i++) {
      final RegExpMatch? m =
          RegExp(r'(?:competi[cç][aã]o|competition)\s*[:\-]\s*(.+)$',
                  caseSensitive: false)
              .firstMatch(lines[i]);
      if (m != null) {
        localCompetition ??= m.group(1)!.trim();
        break;
      }
    }

    for (int i = headerIndex + 1; i < lines.length; i++) {
      final Map<String, String> cells = layout.split(lines[i]);
      if (cells.values.every((String v) => v.trim().isEmpty)) continue;

      final String clubName = (cells['club'] ?? defaultClub ?? '').trim();
      if (clubName.isEmpty) continue;

      final String name = (cells['name'] ?? '').trim();
      final String classRaw = (cells['class'] ?? '').trim();
      final String shirtRaw = (cells['shirt'] ?? '').trim();
      final String dobRaw = (cells['dob'] ?? '').trim();
      final String genderRaw = (cells['gender'] ?? '').trim();
      final String photoRaw = (cells['photo'] ?? '').trim();
      final String roleRaw = (cells['role'] ?? '').trim();

      if (name.isEmpty && classRaw.isEmpty && shirtRaw.isEmpty) continue;

      final String clubId = clubIdFromName(clubName);
      final _ClubBucket bucket = buckets.putIfAbsent(
        clubId,
        () => _ClubBucket(id: clubId, name: clubName),
      );

      // Linhas com "função" de comissão técnica não passam pela
      // validação de atleta — só precisam do nome.
      if (isStaffRole(roleRaw)) {
        if (name.isNotEmpty) {
          bucket.staff.add(StaffMember(
            id: '$clubId::staff::${normalizeHeaderToken(name)}',
            clubName: clubName,
            fullName: name,
            role: roleRaw,
            photoUrl: normalizePlayerPhotoUrl(photoRaw),
          ));
        }
        continue;
      }

      final String playerLabel = name.isEmpty ? '(sem nome)' : name;
      bool valid = true;

      final int? shirtNumber = parseShirtNumber(shirtRaw);
      if (shirtNumber == null) {
        issues.add(ImportIssue(
          category: ImportIssueCategory.missingShirtNumber,
          severity: ImportIssueSeverity.error,
          message: 'Atleta sem número de camisa válido.',
          rowNumber: i + 1,
          clubName: clubName,
          playerLabel: playerLabel,
          sheetName: 'PDF página $pageNumber',
        ));
        valid = false;
      }

      double? playerClass;
      if (classRaw.isEmpty) {
        issues.add(ImportIssue(
          category: ImportIssueCategory.missingPlayerClass,
          severity: ImportIssueSeverity.warning,
          message:
              'Classe funcional não informada para $playerLabel — preencha manualmente no app.',
          rowNumber: i + 1,
          clubName: clubName,
          playerLabel: playerLabel,
          sheetName: 'PDF página $pageNumber',
        ));
      } else {
        playerClass = parsePlayerClass(classRaw);
        if (playerClass == null) {
          final String accepted = kAcceptedPlayerClasses
              .map((double c) => c.toStringAsFixed(1))
              .join(', ');
          issues.add(ImportIssue(
            category: ImportIssueCategory.invalidPlayerClass,
            severity: ImportIssueSeverity.warning,
            message:
                'Classe "$classRaw" não reconhecida para $playerLabel — ajuste manualmente no app. Aceitas: $accepted.',
            rowNumber: i + 1,
            clubName: clubName,
            playerLabel: playerLabel,
            sheetName: 'PDF página $pageNumber',
          ));
        }
      }

      // Data de nascimento é OPCIONAL — mesma regra do parser de
      // planilha: só avisa quando o valor existe mas é ininteligível.
      final DateTime? dob = parseDateOfBirth(dobRaw);
      if (dobRaw.isNotEmpty && dob == null) {
        issues.add(ImportIssue(
          category: ImportIssueCategory.missingDateOfBirth,
          severity: ImportIssueSeverity.warning,
          message:
              'Data de nascimento "$dobRaw" inválida para $playerLabel — atleta importado sem data.',
          rowNumber: i + 1,
          clubName: clubName,
          playerLabel: playerLabel,
          sheetName: 'PDF página $pageNumber',
        ));
      }

      if (name.isEmpty) {
        issues.add(ImportIssue(
          category: ImportIssueCategory.missingPlayerName,
          severity: ImportIssueSeverity.error,
          message: 'Atleta sem nome.',
          rowNumber: i + 1,
          clubName: clubName,
          playerLabel: playerLabel,
          sheetName: 'PDF página $pageNumber',
        ));
        valid = false;
      }

      if (!valid) continue;

      bucket.players.add(Player(
        id: '$clubId::${shirtNumber!}',
        clubName: clubName,
        shirtNumber: shirtNumber,
        fullName: name,
        playerClass: playerClass,
        dateOfBirth: dob,
        gender: _genderFromString(genderRaw),
        photoUrl: normalizePlayerPhotoUrl(photoRaw),
      ));
    }

    return _PageParse(foundHeader: true, competitionName: localCompetition);
  }

  _HeaderLayout? _tryParseHeader(String line) {
    final List<_TokenHit> hits = <_TokenHit>[];
    // Quebra em "palavras" preservando posição inicial.
    final RegExp wordRe = RegExp(r'\S[\S ]*?(?=\s{2,}|$)');
    for (final RegExpMatch m in wordRe.allMatches(line)) {
      final String text = m.group(0)!.trim();
      final String? field = canonicalField(text);
      if (field != null) {
        hits.add(_TokenHit(field: field, startCol: m.start));
      }
    }
    // Mínimo razoável: precisa pelo menos de name + class + shirt.
    // Data de nascimento é opcional na importação.
    final Set<String> fields = hits.map((_TokenHit h) => h.field).toSet();
    if (!fields.contains('name') ||
        !fields.contains('class') ||
        !fields.contains('shirt')) {
      return null;
    }
    hits.sort((_TokenHit a, _TokenHit b) => a.startCol.compareTo(b.startCol));
    return _HeaderLayout(hits: hits);
  }

  void _detectDuplicateShirtNumbers(
    List<Team> teams,
    List<ImportIssue> issues,
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
    if (value.startsWith('m')) return PlayerGender.male;
    if (value.startsWith('f')) return PlayerGender.female;
    return PlayerGender.unspecified;
  }
}

class _PageParse {
  const _PageParse({required this.foundHeader, this.competitionName});
  final bool foundHeader;
  final String? competitionName;
}

class _TokenHit {
  const _TokenHit({required this.field, required this.startCol});
  final String field;
  final int startCol;
}

/// Layout do cabeçalho — guarda onde começa cada coluna no texto plano.
/// Para fatiar a linha, usa-se [startCol] do próximo token como ponto
/// final da coluna anterior.
class _HeaderLayout {
  _HeaderLayout({required this.hits});
  final List<_TokenHit> hits;

  Map<String, String> split(String line) {
    final Map<String, String> out = <String, String>{};
    for (int i = 0; i < hits.length; i++) {
      final int start = hits[i].startCol;
      final int end = i + 1 < hits.length ? hits[i + 1].startCol : line.length;
      if (start >= line.length) {
        out[hits[i].field] = '';
        continue;
      }
      final int safeEnd = end > line.length ? line.length : end;
      out[hits[i].field] = line.substring(start, safeEnd).trim();
    }
    return out;
  }
}

class _ClubBucket {
  _ClubBucket({required this.id, required this.name});
  final String id;
  final String name;
  final List<Player> players = <Player>[];
  final List<StaffMember> staff = <StaffMember>[];
}
