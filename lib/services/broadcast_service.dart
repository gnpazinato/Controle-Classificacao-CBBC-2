import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/broadcast_config.dart';

/// Cliente da transmissão pública da quadra.
///
/// Conversa com as Cloudflare Pages Functions (`/api/session…`). É
/// **offline-first**: [start] propaga erro pra UI avisar "sem internet", mas
/// [push] e [stop] falham em silêncio — o app nunca trava por causa disto.
///
/// Coalescência: cada toque na quadra chama [push]; mantemos só o **último**
/// estado e uma requisição em voo por vez, então rajadas de toques não viram
/// uma fila de POSTs.
class BroadcastService {
  BroadcastService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String? _sessionId;
  String? _writeToken;

  Map<String, dynamic>? _latest;
  bool _sending = false;
  Timer? _heartbeat;

  /// Código de 5 caracteres da sessão ativa (`null` se não está transmitindo).
  String? get sessionId => _sessionId;

  bool get isLive => _sessionId != null;

  /// Link público completo (`null` se não está transmitindo).
  String? get publicUrl =>
      _sessionId == null ? null : broadcastViewerUrl(_sessionId!);

  /// Cria a sessão no servidor e envia o primeiro estado. Lança em caso de
  /// falha de rede (sem internet) — quem chama deve tratar e avisar o usuário.
  Future<void> start(Map<String, dynamic> envelope) async {
    final http.Response res = await _client
        .post(Uri.parse('$kBroadcastBaseUrl/api/session'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw BroadcastException(_messageForStatus(res.statusCode));
    }
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    _sessionId = body['id'] as String?;
    _writeToken = body['write_token'] as String?;
    if (_sessionId == null || _writeToken == null) {
      throw const BroadcastException('Resposta inválida do servidor.');
    }
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(kBroadcastHeartbeat, (_) {
      if (_latest != null) unawaited(_send(_latest!));
    });
    push(envelope);
  }

  /// Enfileira o último estado para envio (fire-and-forget, silencioso).
  void push(Map<String, dynamic> envelope) {
    if (_sessionId == null) return;
    _latest = envelope;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_sending) return;
    while (_latest != null && _sessionId != null) {
      final Map<String, dynamic> payload = _latest!;
      _latest = null;
      _sending = true;
      try {
        await _send(payload);
      } catch (_) {
        // Offline / falha transitória: ignora. O próximo toque (ou o
        // heartbeat) tenta de novo com o estado mais recente.
      } finally {
        _sending = false;
      }
    }
  }

  Future<void> _send(Map<String, dynamic> envelope) async {
    final String? id = _sessionId;
    final String? token = _writeToken;
    if (id == null || token == null) return;
    await _client
        .post(
          Uri.parse('$kBroadcastBaseUrl/api/session/$id'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'write_token': token,
            'state': envelope,
          }),
        )
        .timeout(const Duration(seconds: 12));
  }

  /// Encerra a sessão no servidor e zera o estado local. Silencioso.
  Future<void> stop() async {
    final String? id = _sessionId;
    final String? token = _writeToken;
    _heartbeat?.cancel();
    _heartbeat = null;
    _sessionId = null;
    _writeToken = null;
    _latest = null;
    if (id == null || token == null) return;
    try {
      await _client
          .delete(
            Uri.parse('$kBroadcastBaseUrl/api/session/$id'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{'write_token': token}),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // Mesmo se o DELETE falhar, a sessão expira sozinha em 1h de inatividade.
    }
  }

  void dispose() {
    _heartbeat?.cancel();
    _client.close();
  }

  String _messageForStatus(int status) {
    if (status == 429) {
      return 'Já há 3 transmissões ativas. Encerre uma antes de iniciar outra.';
    }
    return 'Não foi possível iniciar a transmissão (erro $status).';
  }
}

class BroadcastException implements Exception {
  const BroadcastException(this.message);
  final String message;
  @override
  String toString() => message;
}
