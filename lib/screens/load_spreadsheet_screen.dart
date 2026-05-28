import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../constants/app_version.dart';
import '../models/match_state.dart';
import '../services/cache_service.dart';
import '../services/import_result.dart';
import '../services/pdf_parser_service.dart';
import '../services/spreadsheet_parser_service.dart';
import '../services/template_generator_service.dart';
import '../theme/cbbc_theme.dart';
import '../utils/template_saver.dart' as platform_saver;
import '../widgets/cbbc_logo_header.dart';
import 'match_setup_screen.dart';
import 'missing_data_screen.dart';
import 'validation_summary_screen.dart';

typedef FilePickerFn = Future<_PickedFile?> Function();

typedef TemplateSaveFn = Future<String?> Function(
    String filename, Uint8List bytes);

class _PickedFile {
  const _PickedFile({required this.bytes, required this.extension});
  final Uint8List bytes;
  final String extension;
}

/// Tela inicial — escolhe planilha ou PDF e oferece restaurar a sessão.
class LoadSpreadsheetScreen extends StatefulWidget {
  const LoadSpreadsheetScreen({
    super.key,
    SpreadsheetParserService? xlsxParser,
    PdfParserService? pdfParser,
    CacheService? cache,
    FilePickerFn? filePicker,
    TemplateGeneratorService? templates,
    TemplateSaveFn? saveTemplate,
  })  : _xlsxParser = xlsxParser,
        _pdfParser = pdfParser,
        _cache = cache,
        _filePicker = filePicker,
        _templates = templates,
        _saveTemplate = saveTemplate;

  final SpreadsheetParserService? _xlsxParser;
  final PdfParserService? _pdfParser;
  final CacheService? _cache;
  final FilePickerFn? _filePicker;
  final TemplateGeneratorService? _templates;
  final TemplateSaveFn? _saveTemplate;

  @override
  State<LoadSpreadsheetScreen> createState() => _LoadSpreadsheetScreenState();
}

class _LoadSpreadsheetScreenState extends State<LoadSpreadsheetScreen> {
  late final SpreadsheetParserService _xlsxParser;
  late final PdfParserService _pdfParser;
  late final CacheService _cache;
  late final FilePickerFn _pickFile;
  late final TemplateGeneratorService _templates;
  late final TemplateSaveFn _saveTemplate;

  bool _busy = false;
  bool _hasPromptedRestore = false;

  @override
  void initState() {
    super.initState();
    _xlsxParser = widget._xlsxParser ?? const SpreadsheetParserService();
    _pdfParser = widget._pdfParser ?? const PdfParserService();
    _cache = widget._cache ?? CacheService();
    _pickFile = widget._filePicker ?? _defaultFilePicker;
    _templates = widget._templates ?? const TemplateGeneratorService();
    _saveTemplate = widget._saveTemplate ?? platform_saver.defaultSaveTemplate;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferRestore());
  }

  Future<_PickedFile?> _defaultFilePicker() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['xlsx', 'pdf'],
      withData: true,
    );
    if (picked == null) return null;
    final PlatformFile file = picked.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return null;
    final String ext = (file.extension ?? '').toLowerCase();
    return _PickedFile(bytes: bytes, extension: ext);
  }

  Future<void> _maybeOfferRestore() async {
    if (_hasPromptedRestore) return;
    _hasPromptedRestore = true;
    final bool hasSession = await _cache.hasMatchState();
    if (!mounted || !hasSession) return;
    final bool? restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sessão anterior encontrada'),
          content: const Text(
            'Deseja restaurar a sessão anterior ou começar do zero?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Começar do zero'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restaurar sessão'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (restore == true) {
      final MatchState? state = await _cache.loadMatchState();
      if (!mounted) return;
      if (state == null) {
        _showSnack('Sessão salva não pôde ser restaurada.');
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MatchSetupScreen(restored: state),
        ),
      );
    } else {
      await _cache.clear();
    }
  }

  Future<void> _onLoadPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final _PickedFile? picked = await _pickFile();
      if (picked == null) return;
      final ImportResult result;
      if (picked.extension == 'pdf') {
        result = _pdfParser.parseBytes(picked.bytes);
      } else {
        result = _xlsxParser.parseBytes(picked.bytes);
      }
      if (!mounted) return;
      if (result.hasBlockingIssues && result.teams.isEmpty) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MissingDataScreen(result: result),
          ),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ValidationSummaryScreen(
            result: result,
            cache: _cache,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onDownloadTemplatePressed(TemplateKind kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final Uint8List bytes = _templates.build(kind);
      final String filename = _templates.filenameFor(kind);
      final String? savedAt = await _saveTemplate(filename, bytes);
      if (!mounted) return;
      if (savedAt == null) return;
      _showSnack('Modelo salvo em $savedAt');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Não foi possível salvar o modelo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const CbbcBrandHeader(
                subtitle: 'Basquetebol em cadeira de rodas — controle de pontos por equipe',
              ),
              const SizedBox(height: 8),
              const Text(
                'Carregue a planilha ou PDF de referência dos atletas para iniciar uma partida.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _UploadCard(
                busy: _busy,
                onTap: _busy ? null : _onLoadPressed,
              ),
              const SizedBox(height: 14),
              _TemplatesCard(
                busy: _busy,
                onSingleSheet: () =>
                    _onDownloadTemplatePressed(TemplateKind.singleSheet),
                onPerTeam: () =>
                    _onDownloadTemplatePressed(TemplateKind.perTeam),
              ),
              if (_busy) ...<Widget>[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _OfflineFooter(),
              const SizedBox(height: 4),
              Text(
                'Versão $kAppVersion',
                key: const Key('app-version-label'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CbbcColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CbbcColors.blueSoft.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('load-spreadsheet-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: busy
                  ? CbbcColors.slate200
                  : CbbcColors.blue.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: CbbcColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 30,
                  color: CbbcColors.blue,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Carregar planilha (.xlsx) ou PDF',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CbbcColors.blueDeep,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Toque para escolher o arquivo de referência dos atletas.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CbbcColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplatesCard extends StatelessWidget {
  const _TemplatesCard({
    required this.busy,
    required this.onSingleSheet,
    required this.onPerTeam,
  });

  final bool busy;
  final VoidCallback onSingleSheet;
  final VoidCallback onPerTeam;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: CbbcColors.blueDeep,
                ),
                const SizedBox(width: 6),
                Text(
                  'Modelos de referência',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: CbbcColors.blueDeep,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('download-template-single-sheet'),
                    onPressed: busy ? null : onSingleSheet,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Aba única'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('download-template-per-team'),
                    onPressed: busy ? null : onPerTeam,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Por clube'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineFooter extends StatelessWidget {
  const _OfflineFooter();

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: CbbcColors.textSecondary,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(
          Icons.cloud_queue_outlined,
          size: 14,
          color: CbbcColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Dados offline. Fotos usam internet quando houver link.',
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ],
    );
  }
}
