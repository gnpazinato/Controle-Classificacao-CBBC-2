import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants/broadcast_config.dart';
import '../models/match_state.dart';
import '../models/team.dart';
import '../services/player_photo_url.dart';
import '../theme/cbbc_theme.dart';
import '../widgets/court_view.dart';
import '../widgets/match_header.dart';
import '../widgets/team_roster_list.dart';

/// Página pública (`/v/<codigo>`) — espelha a tela da partida do tablet:
/// cabeçalho com placar, quadra ao vivo no centro e, nas laterais, a
/// relação completa de atletas (com as que estão em quadra destacadas,
/// igual no tablet) e a comissão técnica de cada equipe. Sem nenhum botão
/// operacional. É a página que o OBS captura.
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
  static const double _wideBreakpoint = 720;

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

  /// Reescreve as fotos do Drive (atletas e comissão técnica) para o
  /// endpoint com CORS, in-place no JSON do estado, antes de montar o
  /// [MatchState]. Necessário só na web.
  void _rewritePhotosForWeb(Map<String, dynamic> stateJson) {
    for (final String teamKey in const <String>['teamA', 'teamB']) {
      final Object? team = stateJson[teamKey];
      if (team is! Map<String, dynamic>) continue;
      for (final String listKey in const <String>['players', 'staff']) {
        final Object? members = team[listKey];
        if (members is! List) continue;
        for (final Object? m in members) {
          if (m is Map<String, dynamic> && m['photoUrl'] is String) {
            m['photoUrl'] = webPhotoUrl(m['photoUrl'] as String);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MatchState? state = _state;
    if (state == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: _buildStatus()),
      );
    }
    return Scaffold(
      backgroundColor: CbbcColors.offWhite,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext _, BoxConstraints c) {
            if (c.maxWidth >= _wideBreakpoint) {
              return _WideViewerBody(state: state, courtStyle: _courtStyle);
            }
            return _NarrowViewerBody(state: state, courtStyle: _courtStyle);
          },
        ),
      ),
    );
  }

  Widget _buildStatus() {
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

/// Layout de tela larga (desktop/OBS/tablet deitado): mesmo desenho da
/// tela do tablet — listas nas laterais, quadra no centro — e a comissão
/// técnica de cada equipe embaixo da respectiva lista.
class _WideViewerBody extends StatelessWidget {
  const _WideViewerBody({required this.state, required this.courtStyle});

  final MatchState state;
  final CourtStyle courtStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        MatchHeader(state: state),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _ViewerTeamPanel(
                  state: state,
                  team: state.teamA,
                  isTeamA: true,
                  selectedIds: state.selectedTeamAIds,
                ),
              ),
              Expanded(
                flex: 5,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: CourtBoard(
                      state: state,
                      courtStyle: courtStyle,
                      showHints: false,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: _ViewerTeamPanel(
                  state: state,
                  team: state.teamB,
                  isTeamA: false,
                  selectedIds: state.selectedTeamBIds,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Coluna lateral de uma equipe: relação de atletas ocupando o espaço
/// disponível e, embaixo, a comissão técnica (limitada a ~1/3 da altura,
/// com rolagem própria se não couber).
class _ViewerTeamPanel extends StatelessWidget {
  const _ViewerTeamPanel({
    required this.state,
    required this.team,
    required this.isTeamA,
    required this.selectedIds,
  });

  final MatchState state;
  final Team team;
  final bool isTeamA;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext _, BoxConstraints c) {
        return Column(
          children: <Widget>[
            Expanded(
              child: TeamRosterList(
                state: state,
                team: team,
                isTeamA: isTeamA,
                selectedIds: selectedIds,
              ),
            ),
            if (team.staff.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: c.maxHeight * 0.34),
                child: SingleChildScrollView(
                  child: StaffSection(staff: team.staff),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Layout de tela estreita (celular em pé): tudo numa coluna rolável —
/// quadra, relação da Equipe A com sua comissão, depois a Equipe B.
class _NarrowViewerBody extends StatelessWidget {
  const _NarrowViewerBody({required this.state, required this.courtStyle});

  final MatchState state;
  final CourtStyle courtStyle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          MatchHeader(state: state),
          Padding(
            padding: const EdgeInsets.all(10),
            child: CourtBoard(
              state: state,
              courtStyle: courtStyle,
              showHints: false,
            ),
          ),
          TeamRosterList(
            state: state,
            team: state.teamA,
            isTeamA: true,
            selectedIds: state.selectedTeamAIds,
            shrinkWrap: true,
          ),
          if (state.teamA.staff.isNotEmpty)
            StaffSection(staff: state.teamA.staff),
          const SizedBox(height: 12),
          TeamRosterList(
            state: state,
            team: state.teamB,
            isTeamA: false,
            selectedIds: state.selectedTeamBIds,
            shrinkWrap: true,
          ),
          if (state.teamB.staff.isNotEmpty)
            StaffSection(staff: state.teamB.staff),
          const SizedBox(height: 16),
        ],
      ),
    );
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
