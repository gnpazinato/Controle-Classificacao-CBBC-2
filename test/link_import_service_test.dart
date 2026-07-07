import 'dart:convert';
import 'dart:typed_data';

import 'package:controle_classificacao_cbbc/models/team.dart';
import 'package:controle_classificacao_cbbc/services/import_result.dart';
import 'package:controle_classificacao_cbbc/services/link_import_service.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Planilha mínima em bytes: Equipe A (1 atleta + 1 técnico) e
/// Equipe B (1 atleta).
Uint8List buildRosterXlsx() {
  final xlsx.Excel excel = xlsx.Excel.createExcel();
  excel.rename(excel.getDefaultSheet()!, 'Atletas');
  final List<List<String>> rows = <List<String>>[
    <String>[
      'clube',
      'classe',
      'atleta',
      'camisa',
      'data de nascimento',
      'genero',
      'função',
    ],
    <String>['Equipe A', '2.5', 'Gabriela Giolo', '10', '01/01/1999', 'F', ''],
    <String>['Equipe A', '', 'João da Silva', '', '', '', 'Técnico'],
    <String>['Equipe B', '3.0', 'Maria Souza', '7', '02/02/1995', 'F', ''],
  ];
  for (final List<String> row in rows) {
    excel.appendRow(
      'Atletas',
      row.map((String c) => xlsx.TextCellValue(c)).toList(growable: false),
    );
  }
  return Uint8List.fromList(excel.encode()!);
}

String driveFolderHtml(List<({String id, String name, bool folder})> entries) {
  final StringBuffer buffer = StringBuffer('<html><body><div>');
  for (final ({String id, String name, bool folder}) e in entries) {
    final String href = e.folder
        ? 'https://drive.google.com/drive/folders/${e.id}'
        : 'https://drive.google.com/file/d/${e.id}/view?usp=drive_web';
    buffer
      ..write('<div class="flip-entry" id="entry-${e.id}">')
      ..write('<a class="flip-entry-info" href="$href">')
      ..write('<div class="flip-entry-title">${e.name}</div>')
      ..write('</a></div>');
  }
  buffer.write('</div></body></html>');
  return buffer.toString();
}

const Map<String, String> _htmlHeaders = <String, String>{
  'content-type': 'text/html; charset=utf-8',
};
const Map<String, String> _jsonHeaders = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

void main() {
  group('parseShareLink', () {
    test('arquivo do Drive (/file/d/<id>/view)', () {
      final ShareLink? link = LinkImportService.parseShareLink(
          'https://drive.google.com/file/d/ABC123/view?usp=sharing');
      expect(link, isNotNull);
      expect(link!.provider, ShareProvider.googleDrive);
      expect(link.kind, ShareKind.file);
      expect(link.googleId, 'ABC123');
      expect(link.isGoogleSheet, isFalse);
    });

    test('Google Planilhas (docs.google.com/spreadsheets)', () {
      final ShareLink? link = LinkImportService.parseShareLink(
          'https://docs.google.com/spreadsheets/d/SHEET42/edit#gid=0');
      expect(link, isNotNull);
      expect(link!.kind, ShareKind.file);
      expect(link.googleId, 'SHEET42');
      expect(link.isGoogleSheet, isTrue);
    });

    test('pasta do Drive (/drive/folders/<id>)', () {
      final ShareLink? link = LinkImportService.parseShareLink(
          'https://drive.google.com/drive/folders/FOLDER9?usp=drive_link');
      expect(link, isNotNull);
      expect(link!.kind, ShareKind.folder);
      expect(link.googleId, 'FOLDER9');
    });

    test('pasta do Drive com /u/0/ e sem esquema', () {
      final ShareLink? link = LinkImportService.parseShareLink(
          'drive.google.com/drive/u/0/folders/FOLDER77');
      expect(link, isNotNull);
      expect(link!.kind, ShareKind.folder);
      expect(link.googleId, 'FOLDER77');
    });

    test('OneDrive (1drv.ms e onedrive.live.com)', () {
      final ShareLink? short =
          LinkImportService.parseShareLink('https://1drv.ms/f/s!AbCdEf');
      expect(short, isNotNull);
      expect(short!.provider, ShareProvider.oneDrive);

      final ShareLink? long = LinkImportService.parseShareLink(
          'https://onedrive.live.com/?id=ROOT&cid=X');
      expect(long, isNotNull);
      expect(long!.provider, ShareProvider.oneDrive);
    });

    test('link desconhecido → null', () {
      expect(LinkImportService.parseShareLink('https://example.com/a.xlsx'),
          isNull);
      expect(LinkImportService.parseShareLink(''), isNull);
    });
  });

  group('oneDriveShareToken', () {
    test('usa base64url sem padding com prefixo u!', () {
      final String token =
          LinkImportService.oneDriveShareToken('https://1drv.ms/f/s!AbCdEf');
      expect(token, startsWith('u!'));
      expect(token.contains('='), isFalse);
      expect(token.contains('+'), isFalse);
      expect(token.contains('/'), isFalse);
    });
  });

  group('parseEmbeddedFolderHtml', () {
    test('extrai arquivos e subpastas com id e nome', () {
      final String html = driveFolderHtml(
          <({String id, String name, bool folder})>[
            (id: 'S1', name: 'planilha.xlsx', folder: false),
            (id: 'F1', name: 'Equipe A', folder: true),
            (id: 'I1', name: 'Foto &amp; Cia.jpg', folder: false),
          ]);
      final List<DriveFolderEntry> entries =
          LinkImportService.parseEmbeddedFolderHtml(html);
      expect(entries, hasLength(3));
      expect(entries[0].id, 'S1');
      expect(entries[0].isFolder, isFalse);
      expect(entries[1].name, 'Equipe A');
      expect(entries[1].isFolder, isTrue);
      expect(entries[2].name, 'Foto & Cia.jpg');
    });
  });

  group('importFromLink — Google Drive', () {
    test('pasta completa: planilha na raiz + fotos por equipe', () async {
      final Uint8List sheetBytes = buildRosterXlsx();

      final MockClient client = MockClient((http.Request request) async {
        final Uri url = request.url;
        if (url.host == 'drive.google.com' &&
            url.path == '/embeddedfolderview') {
          final String? id = url.queryParameters['id'];
          if (id == 'ROOT') {
            return http.Response(
              driveFolderHtml(<({String id, String name, bool folder})>[
                (id: 'SHEET', name: 'relacao.xlsx', folder: false),
                (id: 'FA', name: 'Equipe A', folder: true),
                (id: 'FB', name: 'Equipe B', folder: true),
              ]),
              200,
              headers: _htmlHeaders,
            );
          }
          if (id == 'FA') {
            return http.Response(
              driveFolderHtml(<({String id, String name, bool folder})>[
                (id: 'IMG_GABI', name: 'Gabriela.jpg', folder: false),
                (id: 'IMG_JOAO', name: 'João da Silva.png', folder: false),
                (id: 'IMG_X', name: 'mascote.png', folder: false),
                (id: 'DOC_X', name: 'leia-me.txt', folder: false),
              ]),
              200,
              headers: _htmlHeaders,
            );
          }
          if (id == 'FB') {
            return http.Response(
              driveFolderHtml(<({String id, String name, bool folder})>[
                (id: 'IMG_MARIA', name: 'Maria Souza.jpg', folder: false),
              ]),
              200,
              headers: _htmlHeaders,
            );
          }
        }
        if (url.host == 'drive.google.com' &&
            url.path == '/uc' &&
            url.queryParameters['id'] == 'SHEET') {
          return http.Response.bytes(sheetBytes, 200);
        }
        return http.Response('not found', 404);
      });

      final LinkImportService service =
          LinkImportService(httpClientFactory: () => client);
      final List<String> stages = <String>[];
      final ImportResult result = await service.importFromLink(
        'https://drive.google.com/drive/folders/ROOT?usp=sharing',
        onProgress: stages.add,
      );

      expect(result.hasBlockingIssues, isFalse,
          reason: result.issues.map((ImportIssue i) => i.message).join('\n'));
      expect(result.teams, hasLength(2));

      final Team teamA =
          result.teams.firstWhere((Team t) => t.clubName == 'Equipe A');
      final Team teamB =
          result.teams.firstWhere((Team t) => t.clubName == 'Equipe B');

      // Foto da atleta pelo primeiro nome do arquivo.
      expect(teamA.players.single.photoUrl,
          'https://drive.google.com/uc?export=view&id=IMG_GABI');
      // Foto do técnico (comissão) pelo nome completo.
      expect(teamA.staff.single.fullName, 'João da Silva');
      expect(teamA.staff.single.photoUrl,
          'https://drive.google.com/uc?export=view&id=IMG_JOAO');
      expect(teamB.players.single.photoUrl,
          'https://drive.google.com/uc?export=view&id=IMG_MARIA');

      // "mascote.png" não casa com ninguém → aviso não-bloqueante.
      final Iterable<ImportIssue> photoWarnings = result.issues.where(
          (ImportIssue i) => i.category == ImportIssueCategory.photoMatching);
      expect(photoWarnings, hasLength(1));
      expect(photoWarnings.single.message, contains('mascote.png'));
      expect(photoWarnings.single.severity, ImportIssueSeverity.warning);

      expect(stages, isNotEmpty);
    });

    test('link direto de Google Planilhas exporta como xlsx', () async {
      final Uint8List sheetBytes = buildRosterXlsx();
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.host == 'docs.google.com' &&
            request.url.path == '/spreadsheets/d/SHEET42/export') {
          expect(request.url.queryParameters['format'], 'xlsx');
          return http.Response.bytes(sheetBytes, 200);
        }
        return http.Response('not found', 404);
      });

      final LinkImportService service =
          LinkImportService(httpClientFactory: () => client);
      final ImportResult result = await service.importFromLink(
          'https://docs.google.com/spreadsheets/d/SHEET42/edit#gid=0');

      expect(result.hasBlockingIssues, isFalse);
      expect(result.teams, hasLength(2));
      expect(result.staffCount, 1);
    });

    test('pasta sem planilha na raiz → erro claro', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          driveFolderHtml(<({String id, String name, bool folder})>[
            (id: 'FA', name: 'Equipe A', folder: true),
          ]),
          200,
          headers: _htmlHeaders,
        );
      });

      final LinkImportService service =
          LinkImportService(httpClientFactory: () => client);
      final ImportResult result = await service.importFromLink(
          'https://drive.google.com/drive/folders/ROOT');

      expect(result.hasBlockingIssues, isTrue);
      expect(result.issues.single.category,
          ImportIssueCategory.linkUnreachable);
      expect(result.issues.single.message, contains('Nenhuma planilha'));
    });

    test('link não reconhecido → erro sem lançar exceção', () async {
      final LinkImportService service = LinkImportService(
          httpClientFactory: () =>
              MockClient((_) async => http.Response('x', 500)));
      final ImportResult result =
          await service.importFromLink('https://example.com/whatever');
      expect(result.hasBlockingIssues, isTrue);
      expect(
          result.issues.single.category, ImportIssueCategory.linkUnreachable);
    });
  });

  group('importFromLink — OneDrive', () {
    test('pasta compartilhada com fotos por equipe', () async {
      final Uint8List sheetBytes = buildRosterXlsx();

      final MockClient client = MockClient((http.Request request) async {
        final String path = Uri.decodeFull(request.url.path);
        if (request.url.host != 'api.onedrive.com') {
          return http.Response('wrong host', 404);
        }
        if (path.endsWith('/root') &&
            request.url.queryParameters['expand'] == 'children') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'name': 'Supercopa',
              'folder': <String, dynamic>{'childCount': 3},
              'children': <Map<String, dynamic>>[
                <String, dynamic>{
                  'name': 'relacao.xlsx',
                  'file': <String, dynamic>{},
                },
                <String, dynamic>{
                  'name': 'Equipe A',
                  'folder': <String, dynamic>{},
                },
                <String, dynamic>{
                  'name': 'Equipe B',
                  'folder': <String, dynamic>{},
                },
              ],
            }),
            200,
            headers: _jsonHeaders,
          );
        }
        if (path.endsWith('/root:/relacao.xlsx:/content')) {
          return http.Response.bytes(sheetBytes, 200);
        }
        if (path.endsWith('/root:/Equipe A:/children')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'name': 'Gabriela Giolo.jpg',
                  'file': <String, dynamic>{},
                },
              ],
            }),
            200,
            headers: _jsonHeaders,
          );
        }
        if (path.endsWith('/root:/Equipe B:/children')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[],
            }),
            200,
            headers: _jsonHeaders,
          );
        }
        return http.Response('not found: $path', 404);
      });

      final LinkImportService service =
          LinkImportService(httpClientFactory: () => client);
      final ImportResult result =
          await service.importFromLink('https://1drv.ms/f/s!AbCdEf');

      expect(result.hasBlockingIssues, isFalse,
          reason: result.issues.map((ImportIssue i) => i.message).join('\n'));

      final Team teamA =
          result.teams.firstWhere((Team t) => t.clubName == 'Equipe A');
      expect(teamA.players.single.photoUrl, isNotNull);
      expect(teamA.players.single.photoUrl, contains('api.onedrive.com'));
      expect(teamA.players.single.photoUrl, contains('Equipe%20A'));
      expect(teamA.players.single.photoUrl, endsWith(':/content'));
    });

    test('link de planilha única (arquivo compartilhado)', () async {
      final Uint8List sheetBytes = buildRosterXlsx();
      final MockClient client = MockClient((http.Request request) async {
        final String path = Uri.decodeFull(request.url.path);
        if (path.endsWith('/root') &&
            request.url.queryParameters['expand'] == 'children') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'name': 'relacao.xlsx',
              'file': <String, dynamic>{},
            }),
            200,
            headers: _jsonHeaders,
          );
        }
        if (path.endsWith('/root/content')) {
          return http.Response.bytes(sheetBytes, 200);
        }
        return http.Response('not found', 404);
      });

      final LinkImportService service =
          LinkImportService(httpClientFactory: () => client);
      final ImportResult result = await service
          .importFromLink('https://onedrive.live.com/?id=ABC&cid=DEF');

      expect(result.hasBlockingIssues, isFalse);
      expect(result.teams, hasLength(2));
      expect(result.playerCount, 2);
      expect(result.staffCount, 1);
    });

    test('acesso negado (403) → mensagem de compartilhamento', () async {
      final MockClient client = MockClient(
          (http.Request request) async => http.Response('denied', 403));
      final LinkImportService service =
          LinkImportService(httpClientFactory: () => client);
      final ImportResult result =
          await service.importFromLink('https://1drv.ms/f/s!Xyz');
      expect(result.hasBlockingIssues, isTrue);
      expect(result.issues.single.message, contains('qualquer pessoa'));
    });
  });
}
