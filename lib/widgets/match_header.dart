import 'package:flutter/material.dart';

import '../models/match_state.dart';
import '../theme/cbbc_theme.dart';

/// Cabeçalho da partida: nome da competição, "Equipe A × Equipe B" e os
/// dois placares de classificação. Extraído da tela de jogo para ser
/// reutilizado **idêntico** na página pública da transmissão.
class MatchHeader extends StatelessWidget {
  const MatchHeader({super.key, required this.state});

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
