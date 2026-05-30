import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants/broadcast_config.dart';
import '../models/match_state.dart';
import '../services/player_photo_url.dart';
import '../widgets/court_view.dart';

/// Página pública (`/v/<codigo>`) — espelha **somente** a quadra ao vivo:
/// chips das atletas + placar nos cantos, na mesma orientação vertical do
/// app. Sem AppBar, header ou botões. É a página que o OBS captura.
///
/// Atualiza por *polling* simples: pede o estado ao servidor a cada ~1s. Para
/// um placar espelhado, essa latência é imperceptível e é bem mais robusta
/// no Cloudflare do que manter uma conexão SSE aberta.
class PublicViewerScreen extends StatefulWidget {
  const PublicViewerScreen({super.key, required this.code});

  final String code;

  @override
  State<PublicViewerScreen> createState() => _PublicViewerScreenState();
}

enum _ViewerStatus { loading, live, ended, error }

class _PublicViewerScreenState extends State<PublicViewerScreen> {
  static const Duration _pollInterval = Duration(seconds: 1);

  final http.Client _client = http.Client();
  Timer? _timer;
  bool _fetching = false;

  _ViewerStatus _status = _ViewerStatus.loading;
  MatchState? _state;
  CourtStyle _courtStyle = CourtStyle.claro;

  @override
  void initState() {
    super.initState();
    unawaited(_poll());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final http.Response res = await _client
          .get(Uri.parse('$kBroadcastBaseUrl/api/session/${widget.code}'))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 404) {
        setState(() => _status = _ViewerStatus.ended);
        _timer?.cancel();
        return;
      }
      if (res.statusCode != 200) {
        setState(() {
          if (_state == null) _status = _ViewerStatus.error;
        });
        return;
      }
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      final Object? envelope = body['state'];
      if (envelope is! Map<String, dynamic> ||
          envelope['state'] is! Map<String, dynamic>) {
        // Sessão recém-criada ainda sem estado: aguarda o próximo ciclo.
        return;
      }
      final Map<String, dynamic> stateJson =
          envelope['state'] as Map<String, dynamic>;
      _rewritePhotosForWeb(stateJson);
      final MatchState next = MatchState.fromJson(stateJson);
      final CourtStyle style =
          CourtStyle.fromName(envelope['courtStyle'] as String?);
      setState(() {
        _state = next;
        _courtStyle = style;
        _status = _ViewerStatus.live;
      });
    } catch (_) {
      if (!mounted) return;
      // Falha de rede: se já temos estado, mantemos o último na tela.
      if (_state == null) setState(() => _status = _ViewerStatus.error);
    } finally {
      _fetching = false;
    }
  }

  /// Reescreve as fotos do Drive para o endpoint com CORS, in-place no JSON
  /// do estado, antes de montar o [MatchState]. Necessário só na web.
  void _rewritePhotosForWeb(Map<String, dynamic> stateJson) {
    for (final String teamKey in const <String>['teamA', 'teamB']) {
      final Object? team = stateJson[teamKey];
      if (team is! Map<String, dynamic>) continue;
      final Object? players = team['players'];
      if (players is! List) continue;
      for (final Object? p in players) {
        if (p is Map<String, dynamic> && p['photoUrl'] is String) {
          p['photoUrl'] = webPhotoUrl(p['photoUrl'] as String);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    final MatchState? state = _state;
    if (state != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: CourtBoard(
          state: state,
          courtStyle: _courtStyle,
          showHints: false,
        ),
      );
    }
    switch (_status) {
      case _ViewerStatus.ended:
        return const _ViewerMessage(
          icon: Icons.stop_circle_outlined,
          text: 'Transmissão encerrada.',
        );
      case _ViewerStatus.error:
        return const _ViewerMessage(
          icon: Icons.wifi_off_rounded,
          text: 'Sem conexão com a transmissão.',
        );
      case _ViewerStatus.loading:
      case _ViewerStatus.live:
        return const CircularProgressIndicator(color: Colors.white);
    }
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: Colors.white70, size: 48),
        const SizedBox(height: 12),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }
}
