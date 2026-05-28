import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/point_limits.dart';
import '../models/match_state.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/cache_service.dart';
import '../services/vibration_service.dart';
import '../theme/cbbc_theme.dart';
import '../widgets/cbbc_logo_header.dart';
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

  bool _wasOverA = false;
  bool _wasOverB = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _cache = widget._cache ?? CacheService();
    _vibration = widget._vibration ?? const VibrationService();
    _wasOverA = _state.isTeamAOverLimit;
    _wasOverB = _state.isTeamBOverLimit;
    unawaited(_persist());
  }

  Future<void> _persist() => _cache.saveMatchState(_state);

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
  }

  void _onPointLimitChanged(double next) {
    setState(() {
      _state.setPointLimit(next);
    });
    _checkLimitCrossing();
    unawaited(_persist());
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
  }

  void _clearTeamB() {
    setState(() => _state.clearTeamB());
    _checkLimitCrossing();
    unawaited(_persist());
  }

  void _clearAll() {
    setState(() => _state.clearAll());
    _checkLimitCrossing();
    unawaited(_persist());
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
                      );
                    }
                    return _PhoneBody(
                      state: _state,
                      onPlayerTap: _onPlayerTap,
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
  const _TabletBody({required this.state, required this.onPlayerTap});

  final MatchState state;
  final _PlayerTapCallback onPlayerTap;

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
          flex: 4,
          child: _CourtView(state: state),
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
  const _PhoneBody({required this.state, required this.onPlayerTap});

  final MatchState state;
  final _PlayerTapCallback onPlayerTap;

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
                _CourtView(state: state),
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

const String kCourtAsset = 'assets/images/wbk-court2.png';

class _CourtView extends StatelessWidget {
  const _CourtView({required this.state});

  final MatchState state;

  static const double _aspectRatio = 1504 / 2816;

  static const List<Offset> _teamATargets = <Offset>[
    Offset(0.28, 0.08),
    Offset(0.72, 0.08),
    Offset(0.28, 0.26),
    Offset(0.72, 0.26),
    Offset(0.50, 0.42),
  ];

  static const List<Offset> _teamBTargets = <Offset>[
    Offset(0.28, 0.92),
    Offset(0.72, 0.92),
    Offset(0.28, 0.74),
    Offset(0.72, 0.74),
    Offset(0.50, 0.58),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Player?> teamA = state.teamASlotPlayers;
    final List<Player?> teamB = state.teamBSlotPlayers;
    final bool teamAEmpty = teamA.every((Player? p) => p == null);
    final bool teamBEmpty = teamB.every((Player? p) => p == null);
    final bool hasAnyPlayerOnCourt = !teamAEmpty || !teamBEmpty;

    return Center(
      key: const Key('court-view'),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CbbcColors.slate200, width: 1.5),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: LayoutBuilder(
              builder: (BuildContext _, BoxConstraints c) {
                final double w = c.maxWidth;
                final double h = c.maxHeight;
                // Slots ~13% maiores para protagonismo dos chips em transmissão.
                final double slotMaxWidth = (w * 0.27).clamp(66.0, 118.0);
                final double slotMaxHeight = (h * 0.15).clamp(58.0, 104.0);
                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Auto Broadcast Dim: só aplica Opacity quando há
                    // atletas em quadra, evitando pass de composição à toa.
                    if (hasAnyPlayerOnCourt)
                      const Positioned.fill(
                        child: Opacity(
                          opacity: 0.76,
                          child: RotatedBox(
                            quarterTurns: 1,
                            child: Image(
                              image: AssetImage(kCourtAsset),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    else
                      const Positioned.fill(
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Image(
                            image: AssetImage(kCourtAsset),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    if (hasAnyPlayerOnCourt)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                    if (teamAEmpty)
                      Align(
                        alignment: const Alignment(0, -0.55),
                        child: _CourtHint(
                          text: 'Toque nos atletas da ${state.teamA.displayName}',
                        ),
                      ),
                    if (teamBEmpty)
                      Align(
                        alignment: const Alignment(0, 0.55),
                        child: _CourtHint(
                          text: 'Toque nos atletas da ${state.teamB.displayName}',
                        ),
                      ),
                    for (int i = 0; i < 5; i++)
                      if (teamA[i] != null)
                        _CourtPlayerSlot(
                          player: teamA[i]!,
                          jerseyColor: state.teamAJerseyColor,
                          isBonusEligible: state.qualifiesForBonus(teamA[i]!),
                          target: _teamATargets[i],
                          width: w,
                          height: h,
                          slotMaxWidth: slotMaxWidth,
                          slotMaxHeight: slotMaxHeight,
                        ),
                    for (int i = 0; i < 5; i++)
                      if (teamB[i] != null)
                        _CourtPlayerSlot(
                          player: teamB[i]!,
                          jerseyColor: state.teamBJerseyColor,
                          isBonusEligible: state.qualifiesForBonus(teamB[i]!),
                          target: _teamBTargets[i],
                          width: w,
                          height: h,
                          slotMaxWidth: slotMaxWidth,
                          slotMaxHeight: slotMaxHeight,
                        ),
                  ],
                );
              },
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CourtHint extends StatelessWidget {
  const _CourtHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: CbbcColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CourtPlayerSlot extends StatelessWidget {
  const _CourtPlayerSlot({
    required this.player,
    required this.jerseyColor,
    required this.isBonusEligible,
    required this.target,
    required this.width,
    required this.height,
    required this.slotMaxWidth,
    required this.slotMaxHeight,
  });

  final Player player;
  final JerseyColor jerseyColor;
  final bool isBonusEligible;
  final Offset target;
  final double width;
  final double height;
  final double slotMaxWidth;
  final double slotMaxHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: width * target.dx,
      top: height * target.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: _CourtPlayerChip(
          player: player,
          jerseyColor: jerseyColor,
          isBonusEligible: isBonusEligible,
          maxWidth: slotMaxWidth,
          maxHeight: slotMaxHeight,
        ),
      ),
    );
  }
}

class _CourtPlayerChip extends StatelessWidget {
  const _CourtPlayerChip({
    required this.player,
    required this.jerseyColor,
    required this.isBonusEligible,
    required this.maxWidth,
    required this.maxHeight,
  });

  final Player player;
  final JerseyColor jerseyColor;
  final bool isBonusEligible;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return PlayerPortraitChip(
      player: player,
      jerseyColor: jerseyColor,
      isBonusEligible: isBonusEligible,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
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
