import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../constants/point_limits.dart';
import '../models/match_state.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/broadcast_service.dart';
import '../services/cache_service.dart';
import '../services/vibration_service.dart';
import '../theme/cbbc_theme.dart';
import '../widgets/cbbc_logo_header.dart';
import '../widgets/court_view.dart';
import '../widgets/player_jersey_icon.dart';
import '../widgets/player_portrait_chip.dart';

/// Tela principal da partida.
class LineupControlScreen extends StatefulWidget {
  const LineupControlScreen({
    super.key,
    required this.initialState,
    CacheService? cache,
    VibrationService? vibration,
  })  : _cache = cache,
        _vibration = vibration;

  final MatchState initialState;
  final CacheService? _cache;
  final VibrationService? _vibration;

  @override
  State<LineupControlScreen> createState() => _LineupControlScreenState();
}

class _LineupControlScreenState extends State<LineupControlScreen> {
  static const double _tabletBreakpoint = 720;

  late MatchState _state;
  late final CacheService _cache;
  late final VibrationService _vibration;
  final BroadcastService _broadcast = BroadcastService();

  bool _wasOverA = false;
  bool _wasOverB = false;
  bool _broadcasting = false;
  CourtStyle _courtStyle = CourtStyle.claro;
  bool _didPrecacheCourts = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _cache = widget._cache ?? CacheService();
    _vibration = widget._vibration ?? const VibrationService();
    _wasOverA = _state.isTeamAOverLimit;
    _wasOverB = _state.isTeamBOverLimit;
    unawaited(_persist());
    // Aquece o cache de fotos das duas equipes em lotes de 6 paralelos
    // (fire-and-forget). A tela já aparece com silhuetas; conforme os
    // lotes chegam, as fotos populam o cache síncrono. Quando o usuário
    // coloca uma atleta em quadra, o retrato aparece sem delay.
    unawaited(PlayerPhotoPrecache.precacheAll(<String?>[
      for (final Player p in _state.teamA.players) p.photoUrl,
      for (final Player p in _state.teamB.players) p.photoUrl,
    ]));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecacheCourts) {
      _didPrecacheCourts = true;
      // Pré-carrega as duas quadras para que o toggle troque sem flicker.
      for (final CourtStyle style in CourtStyle.values) {
        precacheImage(AssetImage(style.assetPath), context);
      }
    }
  }

  @override
  void dispose() {
    _broadcast.dispose();
    super.dispose();
  }

  void _setCourtStyle(CourtStyle next) {
    if (next == _courtStyle) return;
    setState(() => _courtStyle = next);
    _pushBroadcast();
  }

  Future<void> _persist() => _cache.saveMatchState(_state);

  /// Envelope enviado à transmissão: estado da partida + estilo da quadra
  /// (que não vive no `MatchState`, mas o viewer precisa pra desenhar igual).
  Map<String, dynamic> _broadcastEnvelope() => <String, dynamic>{
        'courtStyle': _courtStyle.name,
        'state': _state.toJson(),
      };

  /// Empurra o estado atual pra transmissão, se estiver ativa. Silencioso.
  void _pushBroadcast() {
    if (_broadcast.isLive) _broadcast.push(_broadcastEnvelope());
  }

  void _onBroadcastPressed() {
    if (_broadcast.isLive) {
      _showBroadcastDialog();
    } else {
      unawaited(_startBroadcast());
    }
  }

  Future<void> _startBroadcast() async {
    try {
      await _broadcast.start(_broadcastEnvelope());
      if (!mounted) return;
      setState(() => _broadcasting = true);
      _showBroadcastDialog();
    } on BroadcastException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Sem internet — a transmissão precisa de conexão.');
    }
  }

  Future<void> _stopBroadcast() async {
    await _broadcast.stop();
    if (!mounted) return;
    setState(() => _broadcasting = false);
  }

  void _showBroadcastDialog() {
    final String? url = _broadcast.publicUrl;
    if (url == null) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => _BroadcastDialog(
        url: url,
        onClose: () => Navigator.of(ctx).pop(),
        onStop: () {
          Navigator.of(ctx).pop();
          unawaited(_stopBroadcast());
        },
      ),
    );
  }

  void _onPlayerTap(Player player, _Side side) {
    final Set<String> bucket = side == _Side.a
        ? _state.selectedTeamAIds
        : _state.selectedTeamBIds;
    final bool wasSelected = bucket.contains(player.id);
    final bool nowSelected = _state.togglePlayer(player);
    if (!wasSelected && !nowSelected) {
      _showSnack(side == _Side.a
          ? 'Apenas 5 atletas podem ser selecionados na Equipe A.'
          : 'Apenas 5 atletas podem ser selecionados na Equipe B.');
      return;
    }
    setState(() {});
    _checkLimitCrossing();
    unawaited(_persist());
    _pushBroadcast();
  }

  void _onPointLimitChanged(double next) {
    setState(() {
      _state.setPointLimit(next);
    });
    _checkLimitCrossing();
    unawaited(_persist());
    _pushBroadcast();
  }

  void _checkLimitCrossing() {
    final bool isOverA = _state.isTeamAOverLimit;
    final bool isOverB = _state.isTeamBOverLimit;
    if (!_wasOverA && isOverA) unawaited(_vibration.shortBuzz());
    if (!_wasOverB && isOverB) unawaited(_vibration.shortBuzz());
    _wasOverA = isOverA;
    _wasOverB = isOverB;
  }

  void _clearTeamA() {
    setState(() => _state.clearTeamA());
    _checkLimitCrossing();
    unawaited(_persist());
    _pushBroadcast();
  }

  void _clearTeamB() {
    setState(() => _state.clearTeamB());
    _checkLimitCrossing();
    unawaited(_persist());
    _pushBroadcast();
  }

  void _clearAll() {
    setState(() => _state.clearAll());
    _checkLimitCrossing();
    unawaited(_persist());
    _pushBroadcast();
  }

  Future<bool> _confirmLeave() async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          key: const Key('leave-match-dialog'),
          title: const Text('Sair desta partida?'),
          content: const Text(
              'A seleção atual pode ser perdida.'),
          actions: <Widget>[
            TextButton(
              key: const Key('leave-stay-button'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Ficar'),
            ),
            FilledButton(
              key: const Key('leave-confirm-button'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );
    return answer ?? false;
  }

  Future<void> _onChangeTeams() async {
    final bool ok = await _confirmLeave();
    if (!mounted || !ok) return;
    Navigator.of(context).pop();
  }

  Future<void> _onLoadNewSpreadsheet() async {
    final bool ok = await _confirmLeave();
    if (!mounted || !ok) return;
    await _cache.clear();
    if (!mounted) return;
    Navigator.of(context).popUntil((Route<void> r) => r.isFirst);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        final NavigatorState navigator = Navigator.of(context);
        final bool ok = await _confirmLeave();
        if (!ok) return;
        navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const CbbcAppBarTitle(text: 'Quadra ao vivo'),
          actions: <Widget>[
            IconButton(
              key: const Key('broadcast-button'),
              tooltip: _broadcasting
                  ? 'Transmissão ao vivo — ver link'
                  : 'Transmitir a quadra ao vivo',
              onPressed: _onBroadcastPressed,
              icon: Icon(
                _broadcasting ? Icons.cast_connected : Icons.cast,
                color: _broadcasting ? CbbcColors.orange : Colors.white,
              ),
            ),
            _PointLimitMenu(
              current: _state.pointLimit,
              onChanged: _onPointLimitChanged,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _Header(state: _state),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext _, BoxConstraints c) {
                    if (c.maxWidth >= _tabletBreakpoint) {
                      return _TabletBody(
                        state: _state,
                        onPlayerTap: _onPlayerTap,
                        courtStyle: _courtStyle,
                        onCourtStyleChanged: _setCourtStyle,
                      );
                    }
                    return _PhoneBody(
                      state: _state,
                      onPlayerTap: _onPlayerTap,
                      courtStyle: _courtStyle,
                      onCourtStyleChanged: _setCourtStyle,
                    );
                  },
                ),
              ),
              _OperationalButtons(
                onClearTeamA: _clearTeamA,
                onClearTeamB: _clearTeamB,
                onClearAll: _clearAll,
                onChangeTeams: _onChangeTeams,
                onLoadNewSpreadsheet: _onLoadNewSpreadsheet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Side { a, b }

typedef _PlayerTapCallback = void Function(Player player, _Side side);

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final MatchState state;

  @override
  Widget build(BuildContext context) {
    final TextStyle teamStyle = Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(
                fontWeight: FontWeight.w700,
                color: CbbcColors.blueDeep) ??
        const TextStyle(fontWeight: FontWeight.w700);
    final String? compName = state.competitionName;
    // Em telas baixas (paisagem de celular pequeno), esconder o nome da
    // competição pra liberar espaço vertical pro score + quadra.
    final bool showComp = MediaQuery.of(context).size.height >= 520 &&
        compName != null &&
        compName.isNotEmpty;
    return Material(
      color: CbbcColors.surface,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: CbbcColors.slate200, width: 1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showComp)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  compName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CbbcColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    state.teamA.displayName,
                    style: teamStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('  ×  ', style: teamStyle),
                Flexible(
                  child: Text(
                    state.teamB.displayName,
                    style: teamStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ScoreCell(
                    total: state.totalPointsTeamA,
                    limit: state.effectiveLimitTeamA,
                    isOver: state.isTeamAOverLimit,
                    bonusActive: state.hasBonusInCourtTeamA,
                    keyName: 'score-team-a',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ScoreCell(
                    total: state.totalPointsTeamB,
                    limit: state.effectiveLimitTeamB,
                    isOver: state.isTeamBOverLimit,
                    bonusActive: state.hasBonusInCourtTeamB,
                    keyName: 'score-team-b',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PointLimitMenu extends StatelessWidget {
  const _PointLimitMenu({required this.current, required this.onChanged});

  final double current;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      key: const Key('lineup-point-limit-dropdown'),
      tooltip: 'Pontuação máxima por equipe',
      icon: const Icon(Icons.tune, color: Colors.white),
      onSelected: onChanged,
      itemBuilder: (BuildContext _) => <PopupMenuEntry<double>>[
        const PopupMenuItem<double>(
          enabled: false,
          child: Text(
            'Pontuação máxima',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: CbbcColors.textSecondary,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const PopupMenuDivider(),
        ...kAcceptedPointLimits.map(
          (double v) => PopupMenuItem<double>(
            value: v,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 24,
                  child: Icon(
                    v == current ? Icons.check : null,
                    color: CbbcColors.blue,
                    size: 18,
                  ),
                ),
                Text(
                  v.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: v == current
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({
    required this.total,
    required this.limit,
    required this.isOver,
    required this.bonusActive,
    required this.keyName,
  });

  final double total;
  final double limit;
  final bool isOver;
  final bool bonusActive;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final Color totalColor =
        isOver ? CbbcColors.alertRed : CbbcColors.blueDeep;
    return AnimatedContainer(
      key: Key(keyName),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isOver ? CbbcColors.alertRedSurface : CbbcColors.slate50,
        border: Border.all(
          color: isOver ? CbbcColors.alertRed : CbbcColors.slate200,
          width: isOver ? 1.6 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: isOver
            ? <BoxShadow>[
                BoxShadow(
                  color: CbbcColors.alertRed.withValues(alpha: 0.32),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                total.toStringAsFixed(1),
                style: TextStyle(
                  color: totalColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${limit.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: CbbcColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              if (bonusActive) ...<Widget>[
                const SizedBox(width: 4),
                const Icon(
                  Icons.star,
                  size: 16,
                  color: CbbcColors.orange,
                ),
              ],
            ],
          ),
          SizedBox(
            height: 14,
            child: isOver
                ? const Text(
                    'Limite excedido.',
                    style: TextStyle(
                      color: CbbcColors.alertRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _TabletBody extends StatelessWidget {
  const _TabletBody({
    required this.state,
    required this.onPlayerTap,
    required this.courtStyle,
    required this.onCourtStyleChanged,
  });

  final MatchState state;
  final _PlayerTapCallback onPlayerTap;
  final CourtStyle courtStyle;
  final ValueChanged<CourtStyle> onCourtStyleChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: _TeamPlayerList(
            key: const Key('tablet-team-a-list'),
            state: state,
            team: state.teamA,
            isTeamA: true,
            selectedIds: state.selectedTeamAIds,
            onPlayerTap: (Player p) => onPlayerTap(p, _Side.a),
          ),
        ),
        Expanded(
          flex: 5,
          child: _CourtView(
            state: state,
            courtStyle: courtStyle,
            onCourtStyleChanged: onCourtStyleChanged,
            onPlayerTap: onPlayerTap,
          ),
        ),
        Expanded(
          flex: 3,
          child: _TeamPlayerList(
            key: const Key('tablet-team-b-list'),
            state: state,
            team: state.teamB,
            isTeamA: false,
            selectedIds: state.selectedTeamBIds,
            onPlayerTap: (Player p) => onPlayerTap(p, _Side.b),
          ),
        ),
      ],
    );
  }
}

class _PhoneBody extends StatelessWidget {
  const _PhoneBody({
    required this.state,
    required this.onPlayerTap,
    required this.courtStyle,
    required this.onCourtStyleChanged,
  });

  final MatchState state;
  final _PlayerTapCallback onPlayerTap;
  final CourtStyle courtStyle;
  final ValueChanged<CourtStyle> onCourtStyleChanged;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          TabBar(
            tabs: <Widget>[
              Tab(text: state.teamA.displayName),
              const Tab(text: 'Quadra'),
              Tab(text: state.teamB.displayName),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _TeamPlayerList(
                  key: const Key('phone-team-a-list'),
                  state: state,
                  team: state.teamA,
                  isTeamA: true,
                  selectedIds: state.selectedTeamAIds,
                  onPlayerTap: (Player p) => onPlayerTap(p, _Side.a),
                ),
                _CourtView(
                  state: state,
                  courtStyle: courtStyle,
                  onCourtStyleChanged: onCourtStyleChanged,
                  onPlayerTap: onPlayerTap,
                ),
                _TeamPlayerList(
                  key: const Key('phone-team-b-list'),
                  state: state,
                  team: state.teamB,
                  isTeamA: false,
                  selectedIds: state.selectedTeamBIds,
                  onPlayerTap: (Player p) => onPlayerTap(p, _Side.b),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamPlayerList extends StatelessWidget {
  const _TeamPlayerList({
    super.key,
    required this.state,
    required this.team,
    required this.isTeamA,
    required this.selectedIds,
    required this.onPlayerTap,
  });

  final MatchState state;
  final Team team;
  final bool isTeamA;
  final Set<String> selectedIds;
  final ValueChanged<Player> onPlayerTap;

  @override
  Widget build(BuildContext context) {
    final List<Player> sortedPlayers = <Player>[...team.players]
      ..sort((Player a, Player b) =>
          a.shirtNumber.compareTo(b.shirtNumber));

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double headerHeight = 28;
        final double listHeight = constraints.maxHeight - headerHeight;
        final int playerCount = sortedPlayers.length;
        final double rawSlotHeight = playerCount > 0
            ? listHeight / playerCount
            : 0;
        final double slotHeight = rawSlotHeight.clamp(28.0, 56.0);

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            SizedBox(
              height: headerHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Center(
                  child: Text(
                    team.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: sortedPlayers.length,
                itemExtent: slotHeight,
                itemBuilder: (BuildContext _, int i) {
                  final Player p = sortedPlayers[i];
                  return _PlayerCard(
                    player: p,
                    isTeamA: isTeamA,
                    jerseyColor:
                        isTeamA ? state.teamAJerseyColor : state.teamBJerseyColor,
                    isBonusEligible: state.qualifiesForBonus(p),
                    selected: selectedIds.contains(p.id),
                    height: slotHeight,
                    onTap: () => onPlayerTap(p),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.isTeamA,
    required this.jerseyColor,
    required this.isBonusEligible,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final Player player;
  final bool isTeamA;
  final JerseyColor jerseyColor;
  final bool isBonusEligible;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double iconSize = (height * 0.78).clamp(22.0, 44.0);
    final double fontSize = (height * 0.32).clamp(11.0, 14.0);
    final double verticalPadding = (height * 0.08).clamp(2.0, 6.0);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? CbbcColors.blueSoft.withValues(alpha: 0.7)
              : CbbcColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? CbbcColors.blue : CbbcColors.slate200,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('player-card-${player.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: <Widget>[
                if (selected)
                  Positioned(
                    left: 0,
                    top: 4,
                    bottom: 4,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: CbbcColors.blue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    selected ? 9 : 6,
                    verticalPadding,
                    6,
                    verticalPadding,
                  ),
                  child: Row(
                    children: <Widget>[
                      PlayerJerseyIcon(
                        player: player,
                        isTeamA: isTeamA,
                        size: iconSize,
                        jerseyColor: jerseyColor,
                      ),
                      const SizedBox(width: 6),
                      if (isBonusEligible) ...<Widget>[
                        Icon(
                          Icons.star,
                          size: fontSize + 1,
                          color: CbbcColors.orange,
                        ),
                        const SizedBox(width: 2),
                      ],
                      Expanded(
                        child: Text(
                          player.displayName,
                          maxLines: 3,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: fontSize,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (player.playerClass?.toStringAsFixed(1) ?? '—'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: fontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourtView extends StatelessWidget {
  const _CourtView({
    required this.state,
    required this.courtStyle,
    required this.onCourtStyleChanged,
    required this.onPlayerTap,
  });

  final MatchState state;
  final CourtStyle courtStyle;
  final ValueChanged<CourtStyle> onCourtStyleChanged;
  final _PlayerTapCallback onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: CourtBoard(
                state: state,
                courtStyle: courtStyle,
                onPlayerTap: (Player p, bool isTeamA) =>
                    onPlayerTap(p, isTeamA ? _Side.a : _Side.b),
              ),
            ),
            const SizedBox(height: 10),
            _CourtStyleToggle(
              current: courtStyle,
              onChanged: onCourtStyleChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourtStyleToggle extends StatelessWidget {
  const _CourtStyleToggle({required this.current, required this.onChanged});

  final CourtStyle current;
  final ValueChanged<CourtStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Estilo da quadra',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final CourtStyle style in CourtStyle.values) ...<Widget>[
            if (style != CourtStyle.values.first) const SizedBox(width: 12),
            _CourtStyleSwatch(
              style: style,
              selected: style == current,
              onTap: () => onChanged(style),
            ),
          ],
        ],
      ),
    );
  }
}

class _CourtStyleSwatch extends StatelessWidget {
  const _CourtStyleSwatch({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final CourtStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const double size = 34;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Quadra ${style.label.toLowerCase()}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: size,
          height: size,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? CbbcColors.blue : CbbcColors.slate200,
              width: selected ? 2.4 : 1.2,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: CbbcColors.blue.withValues(alpha: 0.30),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: ClipOval(
            child: Image(
              image: AssetImage(style.assetPath),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _OperationalButtons extends StatelessWidget {
  const _OperationalButtons({
    required this.onClearTeamA,
    required this.onClearTeamB,
    required this.onClearAll,
    required this.onChangeTeams,
    required this.onLoadNewSpreadsheet,
  });

  final VoidCallback onClearTeamA;
  final VoidCallback onClearTeamB;
  final VoidCallback onClearAll;
  final VoidCallback onChangeTeams;
  final VoidCallback onLoadNewSpreadsheet;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CbbcColors.surface,
      elevation: 6,
      shadowColor: const Color(0x22000000),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext _, BoxConstraints c) {
            // Em telas estreitas (celular) compactamos texto + padding,
            // mas mantemos tap-target acima de 40dp e ícones padronizados
            // pra que cada botão seja reconhecível mesmo com label curto.
            final bool compact = c.maxWidth < 720;
            final ButtonStyle compactStyle = OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 10,
                vertical: compact ? 6 : 10,
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: compact ? 6 : 10,
                runSpacing: compact ? 6 : 10,
                children: <Widget>[
                  OutlinedButton.icon(
                    key: const Key('clear-team-a-button'),
                    onPressed: onClearTeamA,
                    style: compact ? compactStyle : null,
                    icon: const Icon(Icons.backspace_outlined, size: 16),
                    label: Text(compact ? 'Limpar A' : 'Limpar Equipe A'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('clear-team-b-button'),
                    onPressed: onClearTeamB,
                    style: compact ? compactStyle : null,
                    icon: const Icon(Icons.backspace_outlined, size: 16),
                    label: Text(compact ? 'Limpar B' : 'Limpar Equipe B'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('clear-all-button'),
                    onPressed: onClearAll,
                    style: compact ? compactStyle : null,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: const Text('Limpar tudo'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('change-teams-button'),
                    onPressed: onChangeTeams,
                    style: compact ? compactStyle : null,
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: Text(compact ? 'Trocar' : 'Trocar equipes'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('load-new-spreadsheet-button'),
                    onPressed: onLoadNewSpreadsheet,
                    style: compact ? compactStyle : null,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: Text(
                        compact ? 'Outro arquivo' : 'Carregar outro arquivo'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Janelinha (pop-up) com o QR code + link da transmissão. Não altera o
/// layout da partida — abre por cima e fecha sem deixar rastro. O botão
/// discreto da AppBar reabre quando quiser.
class _BroadcastDialog extends StatelessWidget {
  const _BroadcastDialog({
    required this.url,
    required this.onClose,
    required this.onStop,
  });

  final String url;
  final VoidCallback onClose;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('broadcast-dialog'),
      title: const Text('Transmissão ao vivo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'Aponte a câmera no QR code ou copie o link. A página pública '
            'mostra apenas a quadra ao vivo.',
            style: TextStyle(fontSize: 13, color: CbbcColors.textSecondary),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CbbcColors.slate200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            key: const Key('broadcast-copy-link'),
            onTap: () => _copy(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: CbbcColors.slate50,
                border: Border.all(color: CbbcColors.slate200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      url,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy_rounded,
                      size: 18, color: CbbcColors.blue),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('broadcast-stop-button'),
          onPressed: onStop,
          style: TextButton.styleFrom(foregroundColor: CbbcColors.alertRed),
          child: const Text('Encerrar'),
        ),
        FilledButton(
          key: const Key('broadcast-close-button'),
          onPressed: onClose,
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  void _copy(BuildContext context) {
    unawaited(Clipboard.setData(ClipboardData(text: url)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copiado.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
