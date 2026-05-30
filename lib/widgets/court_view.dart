import 'package:flutter/material.dart';

import '../models/match_state.dart';
import '../models/player.dart';
import '../theme/cbbc_theme.dart';
import 'player_portrait_chip.dart';

/// Estilo da quadra escolhido pelo usuário durante a partida.
///
/// Ambos os assets atuais são landscape (1700 × 910) e precisam de
/// `quarterTurns: 1` para caber no container portrait da tela. O campo
/// `quarterTurns` fica configurável caso uma futura arte chegue já em
/// orientação portrait.
enum CourtStyle {
  claro('Clara', 'assets/images/quadra1.png', 1),
  escuro('Escura', 'assets/images/quadra2.png', 1);

  const CourtStyle(this.label, this.assetPath, this.quarterTurns);

  final String label;
  final String assetPath;
  final int quarterTurns;

  /// Lookup tolerante a `null`/valor desconhecido — usado para reconstruir
  /// o estilo a partir do payload da transmissão.
  static CourtStyle fromName(String? name) {
    for (final CourtStyle style in CourtStyle.values) {
      if (style.name == name) return style;
    }
    return CourtStyle.claro;
  }
}

/// Tabuleiro da quadra com os chips das atletas e o placar nos cantos.
///
/// Extraído da tela de jogo para poder ser reutilizado **idêntico** na
/// página pública de transmissão. Quando [onPlayerTap] é `null`, os chips
/// ficam apenas para visualização (sem toque) — é como o viewer público o
/// consome. [showHints] controla as dicas "Toque nos atletas…" que só fazem
/// sentido na tela operacional.
class CourtBoard extends StatelessWidget {
  const CourtBoard({
    super.key,
    required this.state,
    required this.courtStyle,
    this.onPlayerTap,
    this.showHints = true,
  });

  final MatchState state;
  final CourtStyle courtStyle;

  /// `null` ⇒ tabuleiro somente-leitura (viewer público).
  final void Function(Player player, bool isTeamA)? onPlayerTap;
  final bool showHints;

  static const double _aspectRatio = 1504 / 2816;

  // Formação 3+2: linha de frente com 3 atletas perto do garrafão, linha
  // de fundo com 2 atletas mais afastados, garantindo folga no meio campo
  // entre as duas equipes.
  static const List<Offset> _teamATargets = <Offset>[
    Offset(0.22, 0.13),
    Offset(0.50, 0.13),
    Offset(0.78, 0.13),
    Offset(0.36, 0.37),
    Offset(0.64, 0.37),
  ];

  static const List<Offset> _teamBTargets = <Offset>[
    Offset(0.22, 0.87),
    Offset(0.50, 0.87),
    Offset(0.78, 0.87),
    Offset(0.36, 0.63),
    Offset(0.64, 0.63),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Player?> teamA = state.teamASlotPlayers;
    final List<Player?> teamB = state.teamBSlotPlayers;
    final bool teamAEmpty = teamA.every((Player? p) => p == null);
    final bool teamBEmpty = teamB.every((Player? p) => p == null);
    final bool hasAnyPlayerOnCourt = !teamAEmpty || !teamBEmpty;

    final Widget courtImage = RotatedBox(
      quarterTurns: courtStyle.quarterTurns,
      child: Image(
        image: AssetImage(courtStyle.assetPath),
        fit: BoxFit.cover,
      ),
    );

    return AspectRatio(
      key: const Key('court-view'),
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
              // Tudo aqui dentro escala com w/h da quadra. Sem clamps
              // absolutos pra que tablets variados (8" portrait, 11"
              // landscape) gerem o mesmo desenho proporcional.
              final double slotMaxWidth = w * 0.22;
              final double slotMaxHeight = h * 0.16;
              // Badge dos cantos: ancorado na **largura** da quadra
              // (não na altura). A quadra é sempre portrait, então w é
              // a dimensão estreita e dita o quão grande os chips
              // ficam — alinhar o badge a w faz com que ele mantenha
              // a mesma relação visual com o chip independente da
              // orientação do tablet.
              final double badgeAnchor = w;
              final double badgeMargin = badgeAnchor * 0.018;
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Auto Broadcast Dim: só aplica Opacity quando há
                  // atletas em quadra, evitando pass de composição à toa.
                  if (hasAnyPlayerOnCourt)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.76,
                        child: courtImage,
                      ),
                    )
                  else
                    Positioned.fill(child: courtImage),
                  if (hasAnyPlayerOnCourt)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                  if (showHints && teamAEmpty)
                    Align(
                      alignment: const Alignment(0, -0.55),
                      child: _CourtHint(
                        text:
                            'Toque nos atletas da ${state.teamA.displayName}',
                      ),
                    ),
                  if (showHints && teamBEmpty)
                    Align(
                      alignment: const Alignment(0, 0.55),
                      child: _CourtHint(
                        text:
                            'Toque nos atletas da ${state.teamB.displayName}',
                      ),
                    ),
                  // Chips em quadra. Key estável por atleta evita que a
                  // remoção de uma jogadora reaproveite o slot de outra
                  // (causa do "flash" de várias fotos ao tirar atleta).
                  for (int i = 0; i < 5; i++)
                    if (teamA[i] != null)
                      _CourtPlayerSlot(
                        key: ValueKey<String>('court-a-${teamA[i]!.id}'),
                        player: teamA[i]!,
                        jerseyColor: state.teamAJerseyColor,
                        isBonusEligible: state.qualifiesForBonus(teamA[i]!),
                        target: _teamATargets[i],
                        width: w,
                        height: h,
                        slotMaxWidth: slotMaxWidth,
                        slotMaxHeight: slotMaxHeight,
                        onTap: onPlayerTap == null
                            ? null
                            : () => onPlayerTap!(teamA[i]!, true),
                      ),
                  for (int i = 0; i < 5; i++)
                    if (teamB[i] != null)
                      _CourtPlayerSlot(
                        key: ValueKey<String>('court-b-${teamB[i]!.id}'),
                        player: teamB[i]!,
                        jerseyColor: state.teamBJerseyColor,
                        isBonusEligible: state.qualifiesForBonus(teamB[i]!),
                        target: _teamBTargets[i],
                        width: w,
                        height: h,
                        slotMaxWidth: slotMaxWidth,
                        slotMaxHeight: slotMaxHeight,
                        onTap: onPlayerTap == null
                            ? null
                            : () => onPlayerTap!(teamB[i]!, false),
                      ),
                  // Placar espelho — canto superior esquerdo (Equipe A)
                  // e inferior direito (Equipe B). Renderizado por último
                  // pra ficar acima dos chips quando houver sobreposição.
                  Positioned(
                    top: badgeMargin,
                    left: badgeMargin,
                    child: _CourtScoreBadge(
                      total: state.totalPointsTeamA,
                      limit: state.effectiveLimitTeamA,
                      isOver: state.isTeamAOverLimit,
                      bonusActive: state.hasBonusInCourtTeamA,
                      anchor: badgeAnchor,
                    ),
                  ),
                  Positioned(
                    bottom: badgeMargin,
                    right: badgeMargin,
                    child: _CourtScoreBadge(
                      total: state.totalPointsTeamB,
                      limit: state.effectiveLimitTeamB,
                      isOver: state.isTeamBOverLimit,
                      bonusActive: state.hasBonusInCourtTeamB,
                      anchor: badgeAnchor,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CourtScoreBadge extends StatelessWidget {
  const _CourtScoreBadge({
    required this.total,
    required this.limit,
    required this.isOver,
    required this.bonusActive,
    required this.anchor,
  });

  final double total;
  final double limit;
  final bool isOver;
  final bool bonusActive;

  /// Dimensão de referência (menor lado da quadra). Tudo aqui é definido
  /// como % desse ancoramento, então o badge encolhe junto com a quadra
  /// em telas pequenas e cresce em tablets grandes.
  final double anchor;

  @override
  Widget build(BuildContext context) {
    final Color totalColor =
        isOver ? CbbcColors.alertRed : CbbcColors.blueDeep;
    // Dimensões proporcionais à largura da quadra. Calibrado para que o
    // badge nunca invada a área dos chips dos cantos (front line em
    // x ≈ 0.22; chip metade-largura ≈ 0.11 → badge limitado a ~0.10 da
    // largura da quadra).
    final double fontTotal = (anchor * 0.034).clamp(11.0, 22.0);
    final double fontLimit = fontTotal * 0.78;
    final double padH = (anchor * 0.022).clamp(6.0, 14.0);
    final double padV = (anchor * 0.014).clamp(3.0, 8.0);
    final double iconSize = fontTotal * 0.95;
    final double radius = (anchor * 0.022).clamp(7.0, 12.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.97),
            const Color(0xFFF1F5F9).withValues(alpha: 0.97),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          // Sombra "botão flutuante" — mesmo padrão dos chips.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          if (isOver)
            BoxShadow(
              color: CbbcColors.alertRed.withValues(alpha: 0.45),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            total.toStringAsFixed(1),
            style: TextStyle(
              color: totalColor,
              fontSize: fontTotal,
              fontWeight: FontWeight.w900,
              height: 1,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
          Text(
            ' / ${limit.toStringAsFixed(1)}',
            style: TextStyle(
              color: CbbcColors.textSecondary,
              fontSize: fontLimit,
              fontWeight: FontWeight.w600,
              height: 1,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
          if (bonusActive) ...<Widget>[
            SizedBox(width: padH * 0.4),
            Icon(
              Icons.star,
              size: iconSize,
              color: CbbcColors.orange,
            ),
          ],
        ],
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
    super.key,
    required this.player,
    required this.jerseyColor,
    required this.isBonusEligible,
    required this.target,
    required this.width,
    required this.height,
    required this.slotMaxWidth,
    required this.slotMaxHeight,
    required this.onTap,
  });

  final Player player;
  final JerseyColor jerseyColor;
  final bool isBonusEligible;
  final Offset target;
  final double width;
  final double height;
  final double slotMaxWidth;
  final double slotMaxHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: width * target.dx,
      top: height * target.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: PlayerPortraitChip(
          player: player,
          jerseyColor: jerseyColor,
          isBonusEligible: isBonusEligible,
          maxWidth: slotMaxWidth,
          maxHeight: slotMaxHeight,
          onTap: onTap,
        ),
      ),
    );
  }
}
