import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/player.dart';
import '../models/staff_member.dart';
import '../models/team.dart';
import 'import_result.dart';
import 'pdf_parser_service.dart';
import 'player_photo_url.dart';
import 'roster_photo_matcher.dart';
import 'spreadsheet_parser_service.dart';

/// Importa a relação de atletas a partir de um link público do Google
/// Drive ou do OneDrive, sem exigir login nem chave de API.
///
/// Dois formatos de link são aceitos:
/// - **Planilha** (arquivo .xlsx/.pdf ou Google Planilhas): o arquivo é
///   baixado e passa pelos mesmos parsers do upload manual.
/// - **Pasta**: a planilha é localizada na raiz da pasta e cada
///   subpasta corresponde a uma equipe; as imagens dentro delas são
///   associadas a atletas e comissão técnica pelo nome do arquivo
///   (ex.: `Gabriela.jpg` → "Gabriela Giolo").
///
/// Requisito: o link precisa estar compartilhado como "qualquer pessoa
/// com o link". Google: a listagem da pasta usa o endpoint público
/// `embeddedfolderview`; OneDrive: a API anônima
/// `api.onedrive.com/v1.0/shares/u!<token>` (links pessoais — SharePoint
/// corporativo exige login e não é suportado).
class LinkImportService {
  LinkImportService({
    http.Client Function()? httpClientFactory,
    SpreadsheetParserService? xlsxParser,
    PdfParserService? pdfParser,
  })  : _newClient = httpClientFactory ?? http.Client.new,
        _xlsxParser = xlsxParser ?? const SpreadsheetParserService(),
        _pdfParser = pdfParser ?? const PdfParserService();

  final http.Client Function() _newClient;
  final SpreadsheetParserService _xlsxParser;
  final PdfParserService _pdfParser;

  static const String _sharingHint =
      'Verifique se o compartilhamento está como "qualquer pessoa com o '
      'link" e tente novamente.';

  /// Ponto de entrada. Nunca lança: erros viram [ImportResult.error].
  Future<ImportResult> importFromLink(
    String rawUrl, {
    void Function(String stage)? onProgress,
  }) async {
    final ShareLink? link = parseShareLink(rawUrl);
    if (link == null) {
      return ImportResult.error(
        'Link não reconhecido. Cole um link compartilhado de planilha ou '
        'pasta do Google Drive ou do OneDrive.',
        ImportIssueCategory.linkUnreachable,
      );
    }

    final http.Client client = _newClient();
    try {
      switch (link.provider) {
        case ShareProvider.googleDrive:
          return await _importFromGoogle(client, link, onProgress);
        case ShareProvider.oneDrive:
          return await _importFromOneDrive(client, link, onProgress);
      }
    } on _LinkException catch (e) {
      return ImportResult.error(e.message, ImportIssueCategory.linkUnreachable);
    } catch (e) {
      return ImportResult.error(
        'Falha ao acessar o link (${e.runtimeType}). Confira a conexão '
        'com a internet. $_sharingHint',
        ImportIssueCategory.linkUnreachable,
      );
    } finally {
      client.close();
    }
  }

  // ---------------- reconhecimento do link ----------------

  static ShareLink? parseShareLink(String raw) {
    String value = raw.trim();
    if (value.isEmpty) return null;
    if (!value.contains('://')) value = 'https://$value';
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    final String host = uri.host.toLowerCase();

    // -------- OneDrive --------
    if (host == '1drv.ms' ||
        host.endsWith('onedrive.live.com') ||
        host.endsWith('sharepoint.com')) {
      return ShareLink(
        provider: ShareProvider.oneDrive,
        kind: ShareKind.unknown,
        shareUrl: value,
      );
    }

    // -------- Google --------
    final bool googleHost = host.endsWith('drive.google.com') ||
        host.endsWith('docs.google.com') ||
        host.endsWith('drive.usercontent.google.com');
    if (!googleHost) return null;

    final List<String> segments = uri.pathSegments;
    final String? resourceKey = uri.queryParameters['resourcekey'];

    // Google Planilhas: docs.google.com/spreadsheets/d/<id>
    final int sheetsIdx = segments.indexOf('spreadsheets');
    if (sheetsIdx != -1 &&
        segments.length > sheetsIdx + 2 &&
        segments[sheetsIdx + 1] == 'd') {
      return ShareLink(
        provider: ShareProvider.googleDrive,
        kind: ShareKind.file,
        googleId: segments[sheetsIdx + 2],
        isGoogleSheet: true,
        resourceKey: resourceKey,
        shareUrl: value,
      );
    }

    // Pasta: /drive/folders/<id>, /drive/u/0/folders/<id>,
    // /embeddedfolderview?id=, /folderview?id=
    final int foldersIdx = segments.indexOf('folders');
    if (foldersIdx != -1 && foldersIdx + 1 < segments.length) {
      return ShareLink(
        provider: ShareProvider.googleDrive,
        kind: ShareKind.folder,
        googleId: segments[foldersIdx + 1],
        resourceKey: resourceKey,
        shareUrl: value,
      );
    }
    if (segments.contains('embeddedfolderview') ||
        segments.contains('folderview')) {
      final String? id = uri.queryParameters['id'];
      if (id != null && id.isNotEmpty) {
        return ShareLink(
          provider: ShareProvider.googleDrive,
          kind: ShareKind.folder,
          googleId: id,
          resourceKey: resourceKey,
          shareUrl: value,
        );
      }
    }

    // Arquivo: /file/d/<id>, open?id=, uc?id=
    final String? fileId = googleDriveFileIdFromUrl(value);
    if (fileId != null && fileId.isNotEmpty) {
      return ShareLink(
        provider: ShareProvider.googleDrive,
        kind: ShareKind.file,
        googleId: fileId,
        resourceKey: resourceKey,
        shareUrl: value,
      );
    }
    return null;
  }

  // ---------------- Google Drive ----------------

  Future<ImportResult> _importFromGoogle(
    http.Client client,
    ShareLink link,
    void Function(String)? onProgress,
  ) async {
    if (link.kind == ShareKind.file) {
      onProgress?.call('Baixando a planilha…');
      final Uint8List bytes = await _downloadGoogleFile(
        client,
        link.googleId!,
        isGoogleSheet: link.isGoogleSheet,
        resourceKey: link.resourceKey,
      );
      return _parseSpreadsheetBytes(bytes);
    }

    // Pasta: raiz com a planilha + uma subpasta de fotos por equipe.
    onProgress?.call('Lendo a pasta…');
    final List<DriveFolderEntry> rootEntries = await _listGoogleFolder(
      client,
      link.googleId!,
      resourceKey: link.resourceKey,
    );

    final DriveFolderEntry? sheetEntry = _pickSpreadsheetEntry(rootEntries);
    if (sheetEntry == null) {
      throw _LinkException(
        'Nenhuma planilha (.xlsx) encontrada na raiz da pasta. Coloque o '
        'arquivo de referência na raiz e as fotos em subpastas com o nome '
        'de cada equipe.',
      );
    }

    onProgress?.call('Baixando a planilha…');
    final Uint8List bytes = await _downloadGoogleFile(
      client,
      sheetEntry.id,
      isGoogleSheet: sheetEntry.isGoogleSheet,
      resourceKey: sheetEntry.resourceKey,
    );
    final ImportResult base = _parseSpreadsheetBytes(bytes,
        preferPdf: sheetEntry.name.toLowerCase().endsWith('.pdf'));
    if (base.teams.isEmpty) return base;

    // Fotos: uma subpasta por equipe.
    final Map<String, List<FolderImage>> photosByFolder =
        <String, List<FolderImage>>{};
    for (final DriveFolderEntry entry in rootEntries) {
      if (!entry.isFolder) continue;
      onProgress?.call('Buscando fotos: ${entry.name}…');
      try {
        final List<DriveFolderEntry> children = await _listGoogleFolder(
            client, entry.id,
            resourceKey: entry.resourceKey);
        photosByFolder[entry.name] = children
            .where((DriveFolderEntry c) =>
                !c.isFolder && isSupportedImageFile(c.name))
            .map((DriveFolderEntry c) => FolderImage(
                  fileName: c.name,
                  url: 'https://drive.google.com/uc?export=view&id=${c.id}',
                ))
            .toList(growable: false);
      } on _LinkException {
        // Subpasta inacessível não bloqueia a importação.
        photosByFolder[entry.name] = const <FolderImage>[];
      }
    }

    onProgress?.call('Associando fotos…');
    return _applyFolderPhotos(base, photosByFolder);
  }

  Future<Uint8List> _downloadGoogleFile(
    http.Client client,
    String id, {
    bool isGoogleSheet = false,
    String? resourceKey,
  }) async {
    final List<Uri> attempts = <Uri>[];
    if (isGoogleSheet) {
      attempts.add(Uri.https('docs.google.com', '/spreadsheets/d/$id/export',
          <String, String>{'format': 'xlsx'}));
    } else {
      attempts.add(Uri.https('drive.google.com', '/uc', <String, String>{
        'export': 'download',
        'id': id,
        if (resourceKey != null) 'resourcekey': resourceKey,
      }));
      attempts.add(Uri.https(
          'drive.usercontent.google.com', '/download', <String, String>{
        'id': id,
        'export': 'download',
        'confirm': 't',
        if (resourceKey != null) 'resourcekey': resourceKey,
      }));
    }

    for (final Uri uri in attempts) {
      final http.Response response = await client.get(uri);
      if (response.statusCode != 200) continue;
      final Uint8List bytes = response.bodyBytes;
      if (_looksLikeXlsx(bytes) || _looksLikePdf(bytes)) return bytes;
      // Resposta HTML = página de login ou aviso do Drive → tenta a
      // próxima rota.
    }
    throw _LinkException(
      'Não consegui baixar o arquivo do Google Drive. $_sharingHint',
    );
  }

  /// Lista uma pasta pública do Drive pelo endpoint `embeddedfolderview`
  /// (não requer chave de API).
  Future<List<DriveFolderEntry>> _listGoogleFolder(
    http.Client client,
    String folderId, {
    String? resourceKey,
  }) async {
    final Uri uri =
        Uri.https('drive.google.com', '/embeddedfolderview', <String, String>{
      'id': folderId,
      if (resourceKey != null) 'resourcekey': resourceKey,
    });
    final http.Response response = await client.get(uri);
    if (response.statusCode != 200) {
      throw _LinkException(
        'O Google Drive recusou a listagem da pasta '
        '(HTTP ${response.statusCode}). $_sharingHint',
      );
    }
    final String html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final List<DriveFolderEntry> entries = parseEmbeddedFolderHtml(html);
    if (entries.isEmpty && !html.contains('flip-entry')) {
      // Sem nenhuma entrada e sem a estrutura da grade: provavelmente a
      // página de login ou um aviso de acesso negado.
      if (html.contains('accounts.google.com') ||
          html.contains('ServiceLogin')) {
        throw _LinkException(
          'A pasta do Google Drive não está pública. $_sharingHint',
        );
      }
    }
    return entries;
  }

  /// Interpreta o HTML do `embeddedfolderview`. Visível para testes.
  static List<DriveFolderEntry> parseEmbeddedFolderHtml(String html) {
    final List<DriveFolderEntry> entries = <DriveFolderEntry>[];
    final List<String> chunks = html.split('class="flip-entry"');
    for (int i = 1; i < chunks.length; i++) {
      final String chunk = chunks[i];
      final RegExpMatch? hrefMatch =
          RegExp(r'href="([^"]+)"').firstMatch(chunk);
      final RegExpMatch? titleMatch =
          RegExp(r'flip-entry-title[^>]*>([^<]*)<').firstMatch(chunk);
      if (hrefMatch == null || titleMatch == null) continue;
      final String href = _unescapeHtml(hrefMatch.group(1)!);
      final String title = _unescapeHtml(titleMatch.group(1)!).trim();
      if (title.isEmpty) continue;

      final bool isFolder =
          href.contains('/folders/') || href.contains('folderview');
      final bool isGoogleSheet = href.contains('/spreadsheets/');
      String? id;
      if (isFolder) {
        final RegExpMatch? m = RegExp(r'/folders/([^/?#]+)').firstMatch(href);
        id = m?.group(1) ?? Uri.tryParse(href)?.queryParameters['id'];
      } else {
        id = googleDriveFileIdFromUrl(href);
      }
      if (id == null || id.isEmpty) continue;
      entries.add(DriveFolderEntry(
        id: id,
        name: title,
        isFolder: isFolder,
        isGoogleSheet: isGoogleSheet,
        resourceKey: Uri.tryParse(href)?.queryParameters['resourcekey'],
      ));
    }
    return entries;
  }

  // ---------------- OneDrive ----------------

  /// Token anônimo da API de compartilhamento: `u!` + base64url do link.
  static String oneDriveShareToken(String shareUrl) {
    final String encoded = base64Url.encode(utf8.encode(shareUrl));
    return 'u!${encoded.replaceAll('=', '')}';
  }

  Future<ImportResult> _importFromOneDrive(
    http.Client client,
    ShareLink link,
    void Function(String)? onProgress,
  ) async {
    final String token = oneDriveShareToken(link.shareUrl);
    final String base = 'https://api.onedrive.com/v1.0/shares/$token';

    onProgress?.call('Conectando ao OneDrive…');
    final Map<String, dynamic> root =
        await _oneDriveJson(client, Uri.parse('$base/root?expand=children'));

    // Link de arquivo único (planilha compartilhada direto).
    if (root.containsKey('file')) {
      onProgress?.call('Baixando a planilha…');
      final Uint8List bytes =
          await _oneDriveBytes(client, Uri.parse('$base/root/content'));
      return _parseSpreadsheetBytes(bytes,
          preferPdf: (root['name'] as String? ?? '')
              .toLowerCase()
              .endsWith('.pdf'));
    }

    // Pasta compartilhada.
    onProgress?.call('Lendo a pasta…');
    final List<Map<String, dynamic>> children = await _oneDriveChildren(
      client,
      root,
      Uri.parse('$base/root/children'),
    );

    Map<String, dynamic>? sheetChild;
    for (final Map<String, dynamic> child in children) {
      final String name = (child['name'] as String? ?? '').toLowerCase();
      if (child.containsKey('folder')) continue;
      if (name.endsWith('.xlsx') ||
          name.endsWith('.xlsm') ||
          name.endsWith('.xls')) {
        sheetChild = child;
        break;
      }
      if (sheetChild == null && name.endsWith('.pdf')) sheetChild = child;
    }
    if (sheetChild == null) {
      throw _LinkException(
        'Nenhuma planilha (.xlsx) encontrada na raiz da pasta do OneDrive. '
        'Coloque o arquivo de referência na raiz e as fotos em subpastas '
        'com o nome de cada equipe.',
      );
    }

    onProgress?.call('Baixando a planilha…');
    final String sheetName = sheetChild['name'] as String;
    final Uint8List bytes = await _oneDriveBytes(
      client,
      Uri.parse('$base/root:/${Uri.encodeComponent(sheetName)}:/content'),
    );
    final ImportResult parsed = _parseSpreadsheetBytes(bytes,
        preferPdf: sheetName.toLowerCase().endsWith('.pdf'));
    if (parsed.teams.isEmpty) return parsed;

    final Map<String, List<FolderImage>> photosByFolder =
        <String, List<FolderImage>>{};
    for (final Map<String, dynamic> child in children) {
      if (!child.containsKey('folder')) continue;
      final String folderName = child['name'] as String? ?? '';
      if (folderName.isEmpty) continue;
      onProgress?.call('Buscando fotos: $folderName…');
      try {
        final List<Map<String, dynamic>> items = await _oneDriveChildren(
          client,
          null,
          Uri.parse(
              '$base/root:/${Uri.encodeComponent(folderName)}:/children'),
        );
        photosByFolder[folderName] = items
            .where((Map<String, dynamic> item) =>
                !item.containsKey('folder') &&
                isSupportedImageFile(item['name'] as String? ?? ''))
            .map((Map<String, dynamic> item) {
          final String fileName = item['name'] as String;
          // URL estável e anônima; redireciona para o conteúdo a cada
          // acesso (o `@content.downloadUrl` expira rápido demais).
          final String url = '$base/root:/'
              '${Uri.encodeComponent(folderName)}/'
              '${Uri.encodeComponent(fileName)}:/content';
          return FolderImage(fileName: fileName, url: url);
        }).toList(growable: false);
      } on _LinkException {
        photosByFolder[folderName] = const <FolderImage>[];
      }
    }

    onProgress?.call('Associando fotos…');
    return _applyFolderPhotos(parsed, photosByFolder);
  }

  Future<Map<String, dynamic>> _oneDriveJson(
      http.Client client, Uri uri) async {
    final http.Response response = await client.get(uri);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw _LinkException(
        'O OneDrive recusou o acesso (HTTP ${response.statusCode}). '
        'Links corporativos (SharePoint) exigem login e não são '
        'suportados. $_sharingHint',
      );
    }
    if (response.statusCode != 200) {
      throw _LinkException(
        'O OneDrive respondeu HTTP ${response.statusCode}. $_sharingHint',
      );
    }
    final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw _LinkException('Resposta inesperada do OneDrive. $_sharingHint');
    }
    return decoded;
  }

  Future<Uint8List> _oneDriveBytes(http.Client client, Uri uri) async {
    final http.Response response = await client.get(uri);
    if (response.statusCode != 200 ||
        !(_looksLikeXlsx(response.bodyBytes) ||
            _looksLikePdf(response.bodyBytes))) {
      throw _LinkException(
        'Não consegui baixar a planilha do OneDrive. $_sharingHint',
      );
    }
    return response.bodyBytes;
  }

  /// Extrai a lista de filhos de um item, seguindo a paginação
  /// (`@odata.nextLink`) quando presente.
  Future<List<Map<String, dynamic>>> _oneDriveChildren(
    http.Client client,
    Map<String, dynamic>? preloaded,
    Uri childrenUri,
  ) async {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    Map<String, dynamic> page;
    String? next;

    if (preloaded != null && preloaded['children'] is List<dynamic>) {
      for (final dynamic child in preloaded['children'] as List<dynamic>) {
        if (child is Map<String, dynamic>) out.add(child);
      }
      next = preloaded['children@odata.nextLink'] as String?;
      if (next == null) return out;
      page = await _oneDriveJson(client, Uri.parse(next));
    } else {
      page = await _oneDriveJson(client, childrenUri);
    }

    int guard = 0;
    while (true) {
      final dynamic value = page['value'];
      if (value is List<dynamic>) {
        for (final dynamic child in value) {
          if (child is Map<String, dynamic>) out.add(child);
        }
      }
      next = page['@odata.nextLink'] as String?;
      if (next == null || ++guard > 20) break;
      page = await _oneDriveJson(client, Uri.parse(next));
    }
    return out;
  }

  // ---------------- comum ----------------

  ImportResult _parseSpreadsheetBytes(Uint8List bytes,
      {bool preferPdf = false}) {
    if (preferPdf || _looksLikePdf(bytes)) {
      return _pdfParser.parseBytes(bytes);
    }
    return _xlsxParser.parseBytes(bytes);
  }

  DriveFolderEntry? _pickSpreadsheetEntry(List<DriveFolderEntry> entries) {
    DriveFolderEntry? googleSheet;
    DriveFolderEntry? pdf;
    for (final DriveFolderEntry entry in entries) {
      if (entry.isFolder) continue;
      final String lower = entry.name.toLowerCase();
      if (lower.endsWith('.xlsx') ||
          lower.endsWith('.xlsm') ||
          lower.endsWith('.xls')) {
        return entry;
      }
      if (entry.isGoogleSheet) googleSheet ??= entry;
      if (lower.endsWith('.pdf')) pdf ??= entry;
    }
    return googleSheet ?? pdf;
  }

  /// Preenche `photoUrl` de atletas e comissão a partir das subpastas.
  /// Fotos explícitas vindas da coluna `foto` da planilha têm prioridade.
  ImportResult _applyFolderPhotos(
    ImportResult base,
    Map<String, List<FolderImage>> photosByFolder,
  ) {
    final List<ImportIssue> issues = <ImportIssue>[...base.issues];
    final List<Team> teams = <Team>[];

    for (final Team team in base.teams) {
      final String? folderName =
          matchFolderToClub(team.clubName, photosByFolder.keys);
      if (folderName == null) {
        if (photosByFolder.isNotEmpty) {
          issues.add(ImportIssue(
            category: ImportIssueCategory.photoMatching,
            severity: ImportIssueSeverity.warning,
            message:
                'Nenhuma pasta de fotos encontrada para "${team.clubName}".',
            clubName: team.clubName,
          ));
        }
        teams.add(team);
        continue;
      }

      final List<FolderImage> images = photosByFolder[folderName]!;
      final List<String> names = <String>[
        for (final Player p in team.players) p.fullName,
        for (final StaffMember s in team.staff) s.fullName,
      ];
      final Map<int, FolderImage> matches = matchImagesToNames(names, images);

      final List<Player> players = <Player>[];
      for (int i = 0; i < team.players.length; i++) {
        final Player p = team.players[i];
        final FolderImage? match = matches[i];
        players.add(match != null && (p.photoUrl == null || p.photoUrl!.isEmpty)
            ? p.copyWith(photoUrl: match.url)
            : p);
      }
      final List<StaffMember> staff = <StaffMember>[];
      for (int i = 0; i < team.staff.length; i++) {
        final StaffMember s = team.staff[i];
        final FolderImage? match = matches[team.players.length + i];
        staff.add(match != null && (s.photoUrl == null || s.photoUrl!.isEmpty)
            ? s.copyWith(photoUrl: match.url)
            : s);
      }
      teams.add(team.copyWith(players: players, staff: staff));

      final Set<String> usedUrls =
          matches.values.map((FolderImage f) => f.url).toSet();
      final List<String> leftover = images
          .where((FolderImage f) => !usedUrls.contains(f.url))
          .map((FolderImage f) => f.fileName)
          .toList(growable: false);
      if (leftover.isNotEmpty) {
        final String preview = leftover.take(5).join(', ');
        final String suffix =
            leftover.length > 5 ? ' e mais ${leftover.length - 5}' : '';
        issues.add(ImportIssue(
          category: ImportIssueCategory.photoMatching,
          severity: ImportIssueSeverity.warning,
          message: 'Fotos sem correspondência na pasta "$folderName": '
              '$preview$suffix.',
          clubName: team.clubName,
        ));
      }
    }

    return base.copyWith(teams: teams, issues: issues);
  }

  static bool _looksLikeXlsx(Uint8List bytes) {
    return bytes.length > 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);
  }

  static bool _looksLikePdf(Uint8List bytes) {
    return bytes.length > 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  static String _unescapeHtml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'");
  }
}

enum ShareProvider { googleDrive, oneDrive }

enum ShareKind { file, folder, unknown }

/// Link reconhecido, com o mínimo necessário pra buscar o conteúdo.
class ShareLink {
  const ShareLink({
    required this.provider,
    required this.kind,
    required this.shareUrl,
    this.googleId,
    this.isGoogleSheet = false,
    this.resourceKey,
  });

  final ShareProvider provider;

  /// Para OneDrive o tipo real (arquivo ou pasta) só é conhecido após a
  /// primeira chamada à API — fica [ShareKind.unknown] aqui.
  final ShareKind kind;
  final String shareUrl;

  /// ID do arquivo/pasta no Google Drive (nulo para OneDrive).
  final String? googleId;
  final bool isGoogleSheet;

  /// `resourcekey` presente em links antigos do Drive.
  final String? resourceKey;
}

/// Entrada de uma pasta do Google Drive (arquivo ou subpasta).
class DriveFolderEntry {
  const DriveFolderEntry({
    required this.id,
    required this.name,
    required this.isFolder,
    this.isGoogleSheet = false,
    this.resourceKey,
  });

  final String id;
  final String name;
  final bool isFolder;
  final bool isGoogleSheet;
  final String? resourceKey;
}

class _LinkException implements Exception {
  _LinkException(this.message);
  final String message;

  @override
  String toString() => message;
}
