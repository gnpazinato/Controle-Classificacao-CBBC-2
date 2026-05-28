import 'package:flutter/material.dart';

import '../services/import_result.dart';
import '../theme/cbbc_theme.dart';
import '../widgets/cbbc_logo_header.dart';

class MissingDataScreen extends StatelessWidget {
  const MissingDataScreen({super.key, required this.result});

  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    final Map<ImportIssueCategory, List<ImportIssue>> grouped =
        _groupBlockingIssuesByCategory(result.issues);
    final bool hasBlockingIssues = grouped.values.any((l) => l.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const CbbcAppBarTitle(text: 'Dados pendentes'),
      ),
      body: SafeArea(
        child: hasBlockingIssues
            ? _IssuesList(grouped: grouped)
            : const _EmptyState(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const Key('back-to-load-button'),
            onPressed: () =>
                Navigator.of(context).popUntil((Route<void> r) => r.isFirst),
            icon: const Icon(Icons.upload_file),
            label: const Text('Carregar outro arquivo'),
          ),
        ),
      ),
    );
  }
}

Map<ImportIssueCategory, List<ImportIssue>> _groupBlockingIssuesByCategory(
    List<ImportIssue> issues) {
  final Map<ImportIssueCategory, List<ImportIssue>> grouped =
      <ImportIssueCategory, List<ImportIssue>>{};
  for (final ImportIssue issue in issues) {
    if (issue.severity != ImportIssueSeverity.error) continue;
    grouped.putIfAbsent(issue.category, () => <ImportIssue>[]).add(issue);
  }
  return grouped;
}

class _IssuesList extends StatelessWidget {
  const _IssuesList({required this.grouped});

  final Map<ImportIssueCategory, List<ImportIssue>> grouped;

  @override
  Widget build(BuildContext context) {
    final List<ImportIssueCategory> orderedCategories =
        grouped.keys.toList()..sort((a, b) => a.index.compareTo(b.index));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Há atletas com informações faltando.',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Corrija os dados no arquivo de origem e carregue novamente.',
        ),
        const SizedBox(height: 16),
        ...orderedCategories.map((ImportIssueCategory cat) {
          final List<ImportIssue> issues = grouped[cat]!;
          return _CategoryBlock(category: cat, issues: issues);
        }),
      ],
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({required this.category, required this.issues});

  final ImportIssueCategory category;
  final List<ImportIssue> issues;

  String get _categoryTitle {
    switch (category) {
      case ImportIssueCategory.missingShirtNumber:
        return 'Atletas sem número de camisa';
      case ImportIssueCategory.missingPlayerName:
        return 'Atletas sem nome';
      case ImportIssueCategory.missingPlayerClass:
        return 'Atletas sem classe funcional';
      case ImportIssueCategory.invalidPlayerClass:
        return 'Classes funcionais inválidas';
      case ImportIssueCategory.missingDateOfBirth:
        return 'Atletas sem data de nascimento';
      case ImportIssueCategory.missingRequiredColumn:
        return 'Colunas obrigatórias ausentes';
      case ImportIssueCategory.fileUnreadable:
        return 'Arquivo não pôde ser lido';
      case ImportIssueCategory.emptyFile:
        return 'Arquivo vazio';
      case ImportIssueCategory.duplicateShirtNumber:
        return 'Outros problemas';
    }
  }

  String get _categoryHint {
    switch (category) {
      case ImportIssueCategory.missingShirtNumber:
        return 'Inclua o número da camisa de cada atleta (0-99).';
      case ImportIssueCategory.missingPlayerName:
        return 'Preencha o nome completo de cada atleta.';
      case ImportIssueCategory.missingPlayerClass:
        return 'Adicione a classe funcional (1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5).';
      case ImportIssueCategory.invalidPlayerClass:
        return 'Use apenas: 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5.';
      case ImportIssueCategory.missingDateOfBirth:
        return 'Preencha a data de nascimento (DD/MM/AAAA).';
      case ImportIssueCategory.missingRequiredColumn:
        return 'Verifique se o cabeçalho contém: clube, classe, atleta, camisa, data de nascimento, gênero.';
      case ImportIssueCategory.fileUnreadable:
        return 'O arquivo não pôde ser interpretado como .xlsx ou PDF.';
      case ImportIssueCategory.emptyFile:
        return 'O arquivo não tem linhas de dados.';
      case ImportIssueCategory.duplicateShirtNumber:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.error_outline, color: CbbcColors.alertRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_categoryTitle (${issues.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (_categoryHint.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(_categoryHint),
            ],
            const SizedBox(height: 12),
            ...issues.map((ImportIssue issue) => _IssueLine(issue: issue)),
          ],
        ),
      ),
    );
  }
}

class _IssueLine extends StatelessWidget {
  const _IssueLine({required this.issue});

  final ImportIssue issue;

  @override
  Widget build(BuildContext context) {
    final List<String> meta = <String>[];
    if (issue.sheetName != null) meta.add('Aba: ${issue.sheetName}');
    if (issue.clubName != null) meta.add('Clube: ${issue.clubName}');
    if (issue.playerLabel != null) meta.add('Atleta: ${issue.playerLabel}');
    if (issue.rowNumber != null) meta.add('Linha: ${issue.rowNumber}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('• ${issue.message}'),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text(
                meta.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.check_circle_outline,
                size: 48, color: Colors.green.shade400),
            const SizedBox(height: 16),
            const Text(
              'Nenhum problema bloqueante encontrado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
