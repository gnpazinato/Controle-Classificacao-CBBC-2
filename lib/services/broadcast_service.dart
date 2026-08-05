import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/broadcast_config.dart';
import 'broadcast_http_client.dart';

/// Resultado de [BroadcastService.resume].
enum BroadcastResumeResult {
  /// A sessão persistida ainda existe no servidor — mesmo link de antes.
  resumed,

  /// O servidor não reconhece mais a sessão (expirou após 24h sem uso).
  /// Quem chama deve descartar as credenciais persistidas.
  expired,

  /// Falha de rede/servidor: não dá pra saber se a sessão ainda vive.
  /// As credenciais devem ser mantidas pra tentar de novo depois.
  offline,
}

/// Cliente da transmissão pública da quadra.
///
/// Conversa com as Cloudflare Pages Functions (`/api/session…`). É
/// **offline-first**: [start] propaga erro pra UI avisar "sem internet", mas
/// [push] e [stop] falham em silêncio — o app nunca trava por causa disto.
///
/// O link é **por tablet**, não por partida: as credenciais `{id, token}`
/// ficam persistidas no [CacheService] e cada nova partida chama [resume]
/// pra continuar transmitindo no mesmo código. [start] só roda quando o
/// tablet ainda não tem sessão (ou a dele expirou no servidor).
///
/// Coalescência: cada toque na quadra chama [push]; mantemos só o **último**
/// estado e uma requisição em voo por vez, então rajadas de toques não viram
/// uma fila de POSTs.
class BroadcastService {
  BroadcastService({http.Client? client})
      : _client = client ?? createBroadcastClient();

  final http.Client _client;

  String? _sessionId;
  String? _writeToken;

  Map<String, dynamic>? _latest;

  /// Último estado efetivamente enviado — o heartbeat o reenvia pra manter
  /// a sessão viva no servidor mesmo sem toques na quadra.
  Map<String, dynamic>? _lastSent;
  bool _sending = false;
  Timer? _heartbeat;

  /// Código de 5 caracteres da sessão ativa (`null` se não está transmitindo).
  String? get sessionId => _sessionId;

  /// Token de escrita da sessão ativa — persistido pelo chamador pra que o
  /// mesmo link seja retomado nas próximas partidas ([resume]).
  String? get writeToken => _writeToken;

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
    _startHeartbeat();
    push(envelope);
  }

  /// Retoma a sessão persistida do tablet enviando o estado atual. Se o
  /// servidor a reconhecer, o link antigo volta a valer sem criar código
  /// novo. Nunca lança — devolve [BroadcastResumeResult].
  Future<BroadcastResumeResult> resume({
    required String sessionId,
    required String writeToken,
    required Map<String, dynamic> envelope,
  }) async {
    try {
      final http.Response res = await _client
          .post(
            Uri.parse('$kBroadcastBaseUrl/api/session/$sessionId'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'write_token': writeToken,
              'state': envelope,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        _sessionId = sessionId;
        _writeToken = writeToken;
        _latest = null;
        // O POST acima já entregou este envelope — registrá-lo garante que
        // o heartbeat tenha o que reenviar mesmo sem nenhum toque na
        // quadra após a retomada (senão o viewer marcaria "sem conexão").
        _lastSent = envelope;
        _startHeartbeat();
        return BroadcastResumeResult.resumed;
      }
      // 404: sessão expirada e removida. 403: o código foi reciclado por
      // outra sessão com outro token. Nos dois casos as credenciais deste
      // tablet não valem mais.
      if (res.statusCode == 404 || res.statusCode == 403) {
        return BroadcastResumeResult.expired;
      }
      return BroadcastResumeResult.offline;
    } catch (_) {
      return BroadcastResumeResult.offline;
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(kBroadcastHeartbeat, (_) {
      // Se já existe tráfego a caminho (POST em voo ou estado pendente no
      // _drain), ele mesmo renova o `updated_at` no servidor — reenviar
      // agora só arriscaria intercalar com o POST em voo e gravar estado
      // fora de ordem (o servidor não tem seq pra descartar o mais velho).
      // Ocioso, reenvia o último estado entregue pelo caminho coalescido
      // ([push] → [_drain]) — isso também recupera um push que falhou
      // offline, então não precisamos de retry dedicado.
      if (_sending || _latest != null) return;
      final Map<String, dynamic>? payload = _lastSent;
      if (payload != null) push(payload);
    });
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
    _lastSent = envelope;
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
    _lastSent = null;
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
      // Mesmo se o DELETE falhar, a sessão expira sozinha em 24h sem uso.
    }
  }

  void dispose() {
    _heartbeat?.cancel();
    _client.close();
  }

  String _messageForStatus(int status) {
    if (status == 429) {
      return 'Há transmissões ativas demais no momento. Encerre uma nos '
          'outros tablets ou aguarde as antigas expirarem.';
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
