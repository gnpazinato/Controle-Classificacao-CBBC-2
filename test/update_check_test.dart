import 'dart:convert';

import 'package:controle_classificacao_cbbc/services/update_check_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client Function() _clientWith(int status, Object body) {
  return () => MockClient((http.Request request) async {
        return http.Response(jsonEncode(body), status, headers: <String, String>{
          'content-type': 'application/json',
        });
      });
}

Map<String, dynamic> _release(String tag, {List<String> assets = const <String>[]}) {
  return <String, dynamic>{
    'tag_name': tag,
    'assets': <Map<String, dynamic>>[
      for (final String name in assets)
        <String, dynamic>{
          'name': name,
          'browser_download_url': 'https://github.com/x/y/releases/download/$tag/$name',
        },
    ],
  };
}

void main() {
  group('isNewerVersion', () {
    test('compara componente a componente', () {
      expect(UpdateCheckService.isNewerVersion('2.9.0', '2.8.0'), isTrue);
      expect(UpdateCheckService.isNewerVersion('3.0.0', '2.9.9'), isTrue);
      expect(UpdateCheckService.isNewerVersion('2.8.1', '2.8.0'), isTrue);
      expect(UpdateCheckService.isNewerVersion('2.8.0', '2.8.0'), isFalse);
      expect(UpdateCheckService.isNewerVersion('2.7.9', '2.8.0'), isFalse);
      // 2.10 > 2.9 (numérico, não alfabético).
      expect(UpdateCheckService.isNewerVersion('2.10.0', '2.9.0'), isTrue);
      // Tamanhos diferentes preenchem com zero.
      expect(UpdateCheckService.isNewerVersion('2.9', '2.8.5'), isTrue);
      expect(UpdateCheckService.isNewerVersion('2.9.1', '2.9'), isTrue);
    });
  });

  group('check', () {
    test('release mais nova com APK → UpdateInfo', () async {
      final UpdateCheckService service = UpdateCheckService(
        httpClientFactory: _clientWith(
          200,
          _release('v9.9.9', assets: <String>[
            'controle-classificacao-cbbc-v9.9.9.apk',
          ]),
        ),
      );
      final UpdateInfo? info = await service.check(currentVersion: '2.8.0');
      expect(info, isNotNull);
      expect(info!.version, '9.9.9');
      expect(info.apkUrl, endsWith('.apk'));
    });

    test('mesma versão instalada → null', () async {
      final UpdateCheckService service = UpdateCheckService(
        httpClientFactory: _clientWith(
          200,
          _release('v2.8.0', assets: <String>['app.apk']),
        ),
      );
      expect(await service.check(currentVersion: '2.8.0'), isNull);
    });

    test('release sem APK anexado → null', () async {
      final UpdateCheckService service = UpdateCheckService(
        httpClientFactory: _clientWith(
          200,
          _release('v9.9.9', assets: <String>['notas.txt']),
        ),
      );
      expect(await service.check(currentVersion: '2.8.0'), isNull);
    });

    test('erro HTTP ou corpo inesperado → null, sem lançar', () async {
      expect(
        await UpdateCheckService(httpClientFactory: _clientWith(404, <String, dynamic>{}))
            .check(currentVersion: '2.8.0'),
        isNull,
      );
      expect(
        await UpdateCheckService(httpClientFactory: _clientWith(200, <dynamic>[]))
            .check(currentVersion: '2.8.0'),
        isNull,
      );
    });
  });
}
