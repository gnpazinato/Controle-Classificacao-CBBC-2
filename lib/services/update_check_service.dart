import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_version.dart';

/// Nova versão encontrada no GitHub Releases.
class UpdateInfo {
  const UpdateInfo({required this.version, required this.apkUrl});

  /// Versão disponível (ex.: `2.9.0`).
  final String version;

  /// Link direto do `.apk` anexado à release — abre no navegador do
  /// tablet e o Android baixa e instala por cima (mesma assinatura).
  final String apkUrl;
}

/// Consulta a release mais recente do repositório no GitHub e compara com
/// a versão instalada ([kAppVersion]). É o que alimenta o aviso
/// "Nova versão disponível" da tela inicial.
///
/// A API pública de releases não exige autenticação em repositório
/// público; uma consulta por abertura de tela fica muito abaixo do limite
/// anônimo (60/h por IP). Sem internet ou com resposta inesperada, o
/// aviso simplesmente não aparece — nunca bloqueia o uso do app.
class UpdateCheckService {
  UpdateCheckService({http.Client Function()? httpClientFactory})
      : _newClient = httpClientFactory ?? http.Client.new;

  final http.Client Function() _newClient;

  static const String latestReleaseApi =
      'https://api.github.com/repos/gnpazinato/Controle-Classificacao-CBBC-2/'
      'releases/latest';

  Future<UpdateInfo?> check({String currentVersion = kAppVersion}) async {
    // Na web (viewer público) não há APK pra instalar.
    if (kIsWeb) return null;
    final http.Client client = _newClient();
    try {
      final http.Response response = await client
          .get(
            Uri.parse(latestReleaseApi),
            headers: const <String, String>{
              'Accept': 'application/vnd.github+json',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;

      final String tag = (decoded['tag_name'] as String? ?? '').trim();
      final String version = tag.startsWith('v') ? tag.substring(1) : tag;
      if (version.isEmpty || !isNewerVersion(version, currentVersion)) {
        return null;
      }

      final List<dynamic> assets =
          (decoded['assets'] as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final String name = (asset['name'] as String? ?? '').toLowerCase();
        final String? url = asset['browser_download_url'] as String?;
        if (name.endsWith('.apk') && url != null && url.isNotEmpty) {
          return UpdateInfo(version: version, apkUrl: url);
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// `true` se [candidate] (`X.Y.Z`) é mais novo que [current].
  /// Componentes não numéricos contam como 0; tamanhos diferentes são
  /// comparados preenchendo com 0 (2.9 < 2.9.1).
  static bool isNewerVersion(String candidate, String current) {
    final List<int> a = _parts(candidate);
    final List<int> b = _parts(current);
    final int len = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      final int x = i < a.length ? a[i] : 0;
      final int y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static List<int> _parts(String version) {
    return version
        .trim()
        .split('.')
        .map((String p) => int.tryParse(p.trim()) ?? 0)
        .toList(growable: false);
  }
}
