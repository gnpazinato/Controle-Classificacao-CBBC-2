import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;

enum TemplateKind { singleSheet, perTeam }

/// Gera planilhas modelo `.xlsx` que o usuário pode baixar e usar como
/// ponto de partida.
///
/// Layout único exigido pelo CBBC: `clube`, `classe`, `atleta`, `camisa`,
/// `data de nascimento`, `gênero`, `função`, `foto`. O modelo "aba única"
/// usa a aba `Atletas` com todas as colunas. O modelo "uma aba por clube"
/// omite a coluna `clube` (vem do nome da aba). A coluna `função`
/// diferencia atletas da comissão técnica: qualquer texto diferente de
/// "atleta" (ex.: "Técnico") marca a linha como comissão, exigindo só o
/// nome.
///
/// **Dados anônimos**: o exemplo dentro do template usa nomes genéricos
/// (`Equipe A/B/...`, `Atleta 1/2/...`) pra que o usuário não confunda o
/// modelo com uma lista real. Idades e classes seguem distribuição
/// realista pra ele perceber se o app interpretou corretamente.
///
/// **Célula da data de término**: as duas variantes começam com uma
/// linha "Data de término da competição: DD/MM/AAAA". O parser detecta
/// esse rótulo e usa a data como referência das regras sub-16/sub-23
/// (bonificação só vale enquanto o atleta não completou 17/24 anos).
class TemplateGeneratorService {
  const TemplateGeneratorService();

  static const List<String> singleSheetHeaders = <String>[
    'clube',
    'classe',
    'atleta',
    'camisa',
    'data de nascimento',
    'genero',
    'função',
    'foto',
  ];

  static const List<String> perTeamHeaders = <String>[
    'classe',
    'atleta',
    'camisa',
    'data de nascimento',
    'genero',
    'função',
    'foto',
  ];

  /// Larguras de coluna em "characters" do Excel (1 unidade ≈ 7px no zoom
  /// padrão). Geramos com folga pra que o usuário não precise puxar
  /// cada coluna pra ver o conteúdo logo de cara.
  static const List<double> _singleSheetWidths = <double>[
    18, // clube
    10, // classe
    32, // atleta
    10, // camisa
    22, // data de nascimento
    10, // genero
    16, // função
    42, // foto
  ];

  static const List<double> _perTeamWidths = <double>[
    10, // classe
    32, // atleta
    10, // camisa
    22, // data de nascimento
    10, // genero
    16, // função
    42, // foto
  ];

  /// Exemplos de comissão técnica — linhas só com nome + função. O
  /// parser identifica pelo texto da coluna `função` (≠ "atleta") e não
  /// exige classe/camisa/nascimento.
  static const List<List<String>> _sampleStaff = <List<String>>[
    <String>['Nome do técnico', 'Técnico'],
    <String>['Nome do auxiliar', 'Auxiliar técnico'],
  ];

  static const String singleSheetTabName = 'Atletas';

  static const String competitionEndLabel =
      'Data de término da competição (DD/MM/AAAA)';

  /// Exemplo de data de término — uma semana adiante de uma data fixa,
  /// só pra preencher o template com algo parseável. O usuário edita.
  static const String _sampleEndDate = '31/12/2026';

  /// Distribuição de classes para o exemplo (soma = 35.5).
  static const List<double> _classDistribution = <double>[
    1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.0, 4.0, 4.5, 4.5, 4.5,
  ];

  static const List<int> _shirts = <int>[
    4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
  ];

  /// Nomes anônimos dos clubes — o usuário substitui pelos reais.
  static const List<String> _anonymousClubs = <String>[
    'Equipe A',
    'Equipe B',
    'Equipe C',
    'Equipe D',
  ];

  /// Gêneros pra cada slot (8 masc + 4 fem por equipe).
  static const List<String> _sampleGenders = <String>[
    'M', 'M', 'M', 'M', 'M', 'M', 'M', 'M', 'F', 'F', 'F', 'F',
  ];

  Uint8List build(TemplateKind kind) {
    switch (kind) {
      case TemplateKind.singleSheet:
        return _buildSingleSheet();
      case TemplateKind.perTeam:
        return _buildPerTeam();
    }
  }

  String filenameFor(TemplateKind kind) {
    switch (kind) {
      case TemplateKind.singleSheet:
        return 'cbbc_modelo_aba_unica.xlsx';
      case TemplateKind.perTeam:
        return 'cbbc_modelo_por_clube.xlsx';
    }
  }

  Uint8List _buildSingleSheet() {
    final xlsx.Excel excel = xlsx.Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, singleSheetTabName);

    // Linha 1: rótulo + data de término. Linha 2: vazia. Linha 3+: tabela.
    excel.appendRow(singleSheetTabName, <xlsx.CellValue?>[
      xlsx.TextCellValue(competitionEndLabel),
      xlsx.TextCellValue(_sampleEndDate),
    ]);
    excel.appendRow(singleSheetTabName, <xlsx.CellValue?>[]);

    excel.appendRow(
      singleSheetTabName,
      singleSheetHeaders
          .map((String h) => xlsx.TextCellValue(h))
          .toList(growable: false),
    );
    String? currentClub;
    for (final _SampleRow row in _expandSampleRows()) {
      if (currentClub != null && currentClub != row.club) {
        _appendStaffRows(excel, singleSheetTabName, club: currentClub);
      }
      currentClub = row.club;
      excel.appendRow(singleSheetTabName, <xlsx.CellValue?>[
        xlsx.TextCellValue(row.club),
        xlsx.TextCellValue(_formatPlayerClass(row.playerClass)),
        xlsx.TextCellValue(row.fullName),
        xlsx.IntCellValue(row.shirt),
        xlsx.TextCellValue(_formatDob(row.dob)),
        xlsx.TextCellValue(row.gender),
        xlsx.TextCellValue('Atleta'),
        xlsx.TextCellValue(''),
      ]);
    }
    if (currentClub != null) {
      _appendStaffRows(excel, singleSheetTabName, club: currentClub);
    }
    _applyColumnWidths(excel, singleSheetTabName, _singleSheetWidths);
    return _encode(excel);
  }

  /// Linhas de exemplo da comissão técnica (nome + função; demais
  /// colunas vazias). Com [club] nulo, omite a coluna do clube (modelo
  /// "uma aba por clube").
  void _appendStaffRows(xlsx.Excel excel, String sheetName, {String? club}) {
    for (final List<String> staff in _sampleStaff) {
      excel.appendRow(sheetName, <xlsx.CellValue?>[
        if (club != null) xlsx.TextCellValue(club),
        xlsx.TextCellValue(''),
        xlsx.TextCellValue(staff[0]),
        xlsx.TextCellValue(''),
        xlsx.TextCellValue(''),
        xlsx.TextCellValue(''),
        xlsx.TextCellValue(staff[1]),
        xlsx.TextCellValue(''),
      ]);
    }
  }

  Uint8List _buildPerTeam() {
    final xlsx.Excel excel = xlsx.Excel.createExcel();
    final String? defaultSheet = excel.getDefaultSheet();

    final Map<String, List<_SampleRow>> rowsByClub =
        <String, List<_SampleRow>>{};
    for (final _SampleRow r in _expandSampleRows()) {
      rowsByClub.putIfAbsent(r.club, () => <_SampleRow>[]).add(r);
    }

    bool firstSheet = true;
    for (final String club in rowsByClub.keys) {
      // Só a primeira aba leva o rótulo da data de término (todas
      // apontam pra mesma competição). O parser olha qualquer aba.
      if (firstSheet) {
        excel.appendRow(club, <xlsx.CellValue?>[
          xlsx.TextCellValue(competitionEndLabel),
          xlsx.TextCellValue(_sampleEndDate),
        ]);
        excel.appendRow(club, <xlsx.CellValue?>[]);
        firstSheet = false;
      }
      excel.appendRow(
        club,
        perTeamHeaders
            .map((String h) => xlsx.TextCellValue(h))
            .toList(growable: false),
      );
      for (final _SampleRow row in rowsByClub[club]!) {
        excel.appendRow(club, <xlsx.CellValue?>[
          xlsx.TextCellValue(_formatPlayerClass(row.playerClass)),
          xlsx.TextCellValue(row.fullName),
          xlsx.IntCellValue(row.shirt),
          xlsx.TextCellValue(_formatDob(row.dob)),
          xlsx.TextCellValue(row.gender),
          xlsx.TextCellValue('Atleta'),
          xlsx.TextCellValue(''),
        ]);
      }
      _appendStaffRows(excel, club);
      _applyColumnWidths(excel, club, _perTeamWidths);
    }

    if (defaultSheet != null && !rowsByClub.containsKey(defaultSheet)) {
      excel.delete(defaultSheet);
    }

    return _encode(excel);
  }

  /// Aplica largura explícita + flag de auto-fit em cada coluna da aba.
  /// Largura explícita é o que praticamente todo cliente honra; o
  /// auto-fit é um hint adicional pra apps que o suportam.
  void _applyColumnWidths(
    xlsx.Excel excel,
    String sheetName,
    List<double> widths,
  ) {
    final xlsx.Sheet sheet = excel.sheets[sheetName]!;
    for (int i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
      sheet.setColumnAutoFit(i);
    }
  }

  Uint8List _encode(xlsx.Excel excel) {
    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Falha ao codificar o modelo .xlsx.');
    }
    return Uint8List.fromList(bytes);
  }

  static String _formatPlayerClass(double value) {
    final String fixed = value.toStringAsFixed(1);
    return fixed.replaceAll('.', ',');
  }

  /// `1995-04-15` -> `15/04/1995`.
  static String _formatDob(String iso) {
    final List<String> parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Iterable<_SampleRow> _expandSampleRows() sync* {
    for (int t = 0; t < _anonymousClubs.length; t++) {
      final String clubName = _anonymousClubs[t];
      for (int i = 0; i < 12; i++) {
        yield _SampleRow(
          club: clubName,
          fullName: 'Nome completo atleta ${i + 1}',
          gender: _sampleGenders[i],
          shirt: _shirts[i],
          playerClass: _classDistribution[i],
          dob: _dobFor(t, i),
        );
      }
    }
  }

  static String _dobFor(int teamIndex, int playerIndex) {
    const List<int> years = <int>[
      1988, 1990, 1992, 1994, 1996, 1998,
      2000, 2002, 2004, 2007, 2009, 2011,
    ];
    final int year = years[playerIndex];
    final int day = ((teamIndex * 7 + playerIndex * 3) % 27) + 1;
    final int month = ((teamIndex * 3 + playerIndex * 5) % 12) + 1;
    final String d = day.toString().padLeft(2, '0');
    final String m = month.toString().padLeft(2, '0');
    return '$year-$m-$d';
  }
}

class _SampleRow {
  const _SampleRow({
    required this.club,
    required this.fullName,
    required this.gender,
    required this.shirt,
    required this.playerClass,
    required this.dob,
  });

  final String club;
  final String fullName;
  final String gender;
  final int shirt;
  final double playerClass;
  final String dob;
}
