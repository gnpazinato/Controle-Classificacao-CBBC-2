// Link fixo de transmissão por tablet: as credenciais {id, write_token}
// ficam persistidas fora do estado da partida e cada nova partida retoma
// a mesma sessão (mesmo link público). Estes testes cobrem a persistência
// no CacheService e a retomada no BroadcastService (com servidor mockado).

import 'dart:convert';

import 'package:controle_classificacao_cbbc/constants/broadcast_config.dart';
import 'package:fake_async/fake_async.dart';
import 'package:controle_classificacao_cbbc/services/broadcast_service.dart';
import 'package:controle_classificacao_cbbc/services/cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CacheService — sessão de transmissão do tablet', () {
    test('salva, carrega e sobrevive ao clear() da partida', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final CacheService cache = CacheService();

      expect(await cache.loadBroadcastSession(), isNull);

      await cache.saveBroadcastSession(id: 'abc12', writeToken: 'tok-1');
      final ({String id, String writeToken})? saved =
          await cache.loadBroadcastSession();
      expect(saved, isNotNull);
      expect(saved!.id, 'abc12');
      expect(saved.writeToken, 'tok-1');

      // "Começar do zero" / trocar equipes limpa só a partida — o link
      // do tablet fica.
      await cache.clear();
      expect(await cache.loadBroadcastSession(), isNotNull);

      // "Encerrar" descarta o link.
      await cache.clearBroadcastSession();
      expect(await cache.loadBroadcastSession(), isNull);
    });
  });

  group('BroadcastService.resume', () {
    test('200 → retomada: mesma sessão, mesmo link público', () async {
      late Map<String, dynamic> sentBody;
      final MockClient mock = MockClient((http.Request req) async {
        expect(req.method, 'POST');
        expect(req.url.toString(), '$kBroadcastBaseUrl/api/session/abc12');
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 200);
      });
      final BroadcastService service = BroadcastService(client: mock);

      final BroadcastResumeResult result = await service.resume(
        sessionId: 'abc12',
        writeToken: 'tok-1',
        envelope: <String, dynamic>{'courtStyle': 'claro'},
      );

      expect(result, BroadcastResumeResult.resumed);
      expect(service.isLive, isTrue);
      expect(service.sessionId, 'abc12');
      expect(service.publicUrl, broadcastViewerUrl('abc12'));
      expect(sentBody['write_token'], 'tok-1');
      expect(sentBody['state'], <String, dynamic>{'courtStyle': 'claro'});

      service.dispose();
    });

    test('404 → expirada: não adota a sessão', () async {
      final MockClient mock = MockClient(
          (http.Request _) async => http.Response('{"error":"nf"}', 404));
      final BroadcastService service = BroadcastService(client: mock);

      final BroadcastResumeResult result = await service.resume(
        sessionId: 'abc12',
        writeToken: 'tok-1',
        envelope: <String, dynamic>{},
      );

      expect(result, BroadcastResumeResult.expired);
      expect(service.isLive, isFalse);
      expect(service.publicUrl, isNull);

      service.dispose();
    });

    test('falha de rede → offline: credenciais devem ser mantidas', () async {
      final MockClient mock = MockClient(
          (http.Request _) async => throw Exception('sem internet'));
      final BroadcastService service = BroadcastService(client: mock);

      final BroadcastResumeResult result = await service.resume(
        sessionId: 'abc12',
        writeToken: 'tok-1',
        envelope: <String, dynamic>{},
      );

      expect(result, BroadcastResumeResult.offline);
      expect(service.isLive, isFalse);

      service.dispose();
    });
  });

  group('BroadcastService — heartbeat', () {
    test('pós-resume reenvia o envelope da retomada sem nenhum toque', () {
      // Regressão: resume() não populava _lastSent, então o heartbeat
      // ficava mudo até o 1º toque e o viewer marcava "sem conexão".
      fakeAsync((FakeAsync async) {
        final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
        final MockClient mock = MockClient((http.Request req) async {
          bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response('{"ok":true}', 200);
        });
        final BroadcastService service = BroadcastService(client: mock);

        BroadcastResumeResult? result;
        service
            .resume(
              sessionId: 'abc12',
              writeToken: 'tok-1',
              envelope: <String, dynamic>{'courtStyle': 'claro'},
            )
            .then((BroadcastResumeResult r) => result = r);
        async.flushMicrotasks();
        expect(result, BroadcastResumeResult.resumed);
        expect(bodies, hasLength(1));

        async.elapse(kBroadcastHeartbeat);
        async.flushMicrotasks();
        expect(bodies, hasLength(2),
            reason: 'heartbeat deve reenviar o envelope da retomada');
        expect(bodies.last['state'],
            <String, dynamic>{'courtStyle': 'claro'});

        service.dispose();
      });
    });

    test('não intercala com um POST em voo nem regrava estado velho', () {
      // Regressão: o heartbeat chamava _send direto, fora do guard
      // _sending — podia intercalar com um push em andamento e gravar
      // estado fora de ordem no servidor (que não tem seq pra descartar).
      fakeAsync((FakeAsync async) {
        int calls = 0;
        final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
        final MockClient mock = MockClient((http.Request req) async {
          calls++;
          bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
          if (calls == 2) {
            // Segura o push do toque por 10s (dentro do timeout de 12s).
            await Future<void>.delayed(const Duration(seconds: 10));
          }
          return http.Response('{"ok":true}', 200);
        });
        final BroadcastService service = BroadcastService(client: mock);

        service.resume(
          sessionId: 'abc12',
          writeToken: 'tok-1',
          envelope: <String, dynamic>{'v': 0},
        );
        async.flushMicrotasks();
        expect(calls, 1);

        // t=25s: toque na quadra — POST fica 10s em voo (até t=35s).
        async.elapse(const Duration(seconds: 25));
        service.push(<String, dynamic>{'v': 1});
        async.flushMicrotasks();
        expect(calls, 2);

        // t=31s: o heartbeat (30s) disparou com o POST em voo → pula.
        async.elapse(const Duration(seconds: 6));
        expect(calls, 2,
            reason: 'heartbeat não pode intercalar com POST em voo');

        // t=36s: POST do toque completou; nada novo a enviar.
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(calls, 2);

        // t=61s: heartbeat ocioso reenvia o ÚLTIMO estado (v:1, não v:0).
        async.elapse(const Duration(seconds: 25));
        async.flushMicrotasks();
        expect(calls, 3);
        expect(bodies.last['state'], <String, dynamic>{'v': 1},
            reason: 'heartbeat deve reenviar o estado mais recente');

        service.dispose();
      });
    });
  });
}
