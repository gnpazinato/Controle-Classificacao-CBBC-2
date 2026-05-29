/// Normaliza links de foto importados da planilha.
///
/// Para links públicos do Google Drive, converte o formato compartilhável
/// (`/file/d/<id>/view`, `open?id=<id>`, etc.) para uma URL direta que o
/// Flutter consegue baixar com mais previsibilidade no APK.
String? normalizePlayerPhotoUrl(String? raw) {
  final String value = raw?.trim() ?? '';
  if (value.isEmpty) return null;

  final Uri? uri = Uri.tryParse(value);
  if (uri == null) return value;

  final String host = uri.host.toLowerCase();
  if (!host.endsWith('drive.google.com') &&
      !host.endsWith('drive.usercontent.google.com')) {
    return value;
  }

  final String? fileId = googleDriveFileIdFromUrl(value);
  if (fileId == null || fileId.isEmpty) return value;

  return Uri.https('drive.google.com', '/uc', <String, String>{
    'export': 'view',
    'id': fileId,
  }).toString();
}

/// Reescreve uma URL de foto do Google Drive para o endpoint
/// `lh3.googleusercontent.com/d/<id>`, que serve a imagem com cabeçalho
/// **CORS** (`Access-Control-Allow-Origin: *`).
///
/// Necessário **na web** (viewer público da transmissão): o endpoint
/// `drive.google.com/uc` não envia CORS, então o Flutter Web não consegue
/// decodificar a imagem para o canvas (e ainda costuma retornar 403 para
/// requisições fora do navegador). URLs que não são do Drive passam intactas.
String? webPhotoUrl(String? raw) {
  final String value = raw?.trim() ?? '';
  if (value.isEmpty) return null;

  final Uri? uri = Uri.tryParse(value);
  if (uri == null) return value;

  final String host = uri.host.toLowerCase();
  // Já é um link googleusercontent (lh3...) — mantém.
  if (host.endsWith('googleusercontent.com')) return value;
  if (!host.endsWith('drive.google.com') &&
      !host.endsWith('drive.usercontent.google.com')) {
    return value;
  }

  final String? fileId = googleDriveFileIdFromUrl(value);
  if (fileId == null || fileId.isEmpty) return value;

  return 'https://lh3.googleusercontent.com/d/$fileId=w640';
}

String? googleDriveFileIdFromUrl(String raw) {
  final Uri? uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;

  final String? queryId = uri.queryParameters['id'];
  if (queryId != null && queryId.trim().isNotEmpty) return queryId.trim();

  final List<String> segments = uri.pathSegments;
  for (int i = 0; i < segments.length - 1; i++) {
    if (segments[i] == 'd') {
      final String candidate = segments[i + 1].trim();
      if (candidate.isNotEmpty) return candidate;
    }
  }

  final RegExpMatch? match =
      RegExp(r'/d/([^/?#]+)').firstMatch(uri.toString());
  return match?.group(1);
}
