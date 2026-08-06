import 'dart:convert';

import 'package:controle_classificacao_cbbc/constants/app_version.dart';
import 'package:controle_classificacao_cbbc/screens/load_spreadsheet_screen.dart';
import 'package:controle_classificacao_cbbc/services/update_check_service.dart';
import 'package:controle_classificacao_cbbc/utils/app_route_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conta as checagens sem ir à rede — pra validar QUANDO a tela checa.
class _CountingChecker extends UpdateCheckService {
  int calls = 0;

  @override
  Future<UpdateInfo?> check({String currentVersion = kAppVersion}) async {
    calls++;
    return null;
  }
}

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

  testWidgets('tela inicial re-checa atualização ao VOLTAR pra ela',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final _CountingChecker checker = _CountingChecker();

    await tester.pumpWidget(MaterialApp(
      navigatorObservers: <NavigatorObserver>[appRouteObserver],
      home: LoadSpreadsheetScreen(updateChecker: checker),
    ));
    await tester.pump();
    expect(checker.calls, 1, reason: 'checagem inicial no initState');

    // Navega pra outra tela (como entrar numa partida) e volta.
    final NavigatorState navigator =
        tester.state(find.byType(Navigator).first);
    navigator.push(MaterialPageRoute<void>(
      builder: (BuildContext _) => const Scaffold(body: SizedBox()),
    ));
    await tester.pumpAndSettle();
    expect(checker.calls, 1, reason: 'sair da home não re-checa');

    navigator.pop();
    await tester.pumpAndSettle();
    expect(checker.calls, 2,
        reason: 'voltar pra home dispara nova checagem (didPopNext)');
  });
}
