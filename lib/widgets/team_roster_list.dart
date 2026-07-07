import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/match_state.dart';
import '../models/player.dart';
import '../models/staff_member.dart';
import '../models/team.dart';
import '../theme/cbbc_theme.dart';
import 'player_jersey_icon.dart';
import 'player_portrait_chip.dart';

/// Relação de atletas de uma equipe, com destaque nas selecionadas em
/// quadra. Extraída da tela de jogo para ser reutilizada **idêntica** na
/// página pública da transmissão.
///
/// [onPlayerTap] `null` ⇒ lista somente-leitura (viewer público).
/// [shrinkWrap] `true` ⇒ a lista dita a própria altura (linhas de altura
/// fixa, sem scroll interno) — usado dentro da coluna rolável do viewer em
/// telas estreitas. `false` ⇒ preenche a altura disponível distribuindo as
/// linhas (comportamento da tela de jogo).
class TeamRosterList extends StatelessWidget {
  const TeamRosterList({
    super.key,
    required this.state,
    required this.team,
    required this.isTeamA,
    required this.selectedIds,
    this.onPlayerTap,
    this.shrinkWrap = false,
  });

  final MatchState state;
  final Team team;
  final bool isTeamA;
  final Set<String> selectedIds;
  final ValueChanged<Player>? onPlayerTap;
  final bool shrinkWrap;

  static const double _headerHeight = 28;

  List<Player> get _sortedPlayers => <Player>[...team.players]
    ..sort((Player a, Player b) => a.shirtNumber.compareTo(b.shirtNumber));

  @override
  Widget build(BuildContext context) {
    if (shrinkWrap) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _header(),
          for (final Player p in _sortedPlayers)
            SizedBox(height: 46, child: _card(p, 46)),
        ],
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final List<Player> sortedPlayers = _sortedPlayers;
        final double listHeight = constraints.maxHeight - _headerHeight;
        final int playerCount = sortedPlayers.length;
        final double rawSlotHeight = playerCount > 0
            ? listHeight / playerCount
            : 0;
        final double slotHeight = rawSlotHeight.clamp(28.0, 56.0);

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            _header(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: sortedPlayers.length,
                itemExtent: slotHeight,
                itemBuilder: (BuildContext _, int i) =>
                    _card(sortedPlayers[i], slotHeight),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header() {
    return SizedBox(
      height: _headerHeight,
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
    );
  }

  Widget _card(Player p, double slotHeight) {
    final ValueChanged<Player>? onTap = onPlayerTap;
    final Widget card = _PlayerCard(
      player: p,
      isTeamA: isTeamA,
      jerseyColor: isTeamA ? state.teamAJerseyColor : state.teamBJerseyColor,
      isBonusEligible: state.qualifiesForBonus(p),
      selected: selectedIds.contains(p.id),
      height: slotHeight,
      onTap: onTap == null ? null : () => onTap(p),
    );
    if (!shrinkWrap) return card;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: card,
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
  final VoidCallback? onTap;

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

/// Seção "Comissão técnica" exibida abaixo da relação de atletas na página
/// pública da transmissão. Mesmo estilo de retângulos da lista de atletas,
/// mas sem camiseta nem classe: foto redonda (quando houver), nome e a
/// função embaixo.
class StaffSection extends StatelessWidget {
  const StaffSection({super.key, required this.staff});

  final List<StaffMember> staff;

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(
          height: 24,
          child: Center(
            child: Text(
              'Comissão técnica',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: CbbcColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        for (final StaffMember member in staff)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
            child: _StaffCard(member: member),
          ),
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: CbbcColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CbbcColors.slate200),
      ),
      child: Row(
        children: <Widget>[
          _StaffAvatar(photoUrl: member.photoUrl, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  member.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                if (member.role.trim().isNotEmpty)
                  Text(
                    member.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: CbbcColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto redonda do membro da comissão. Reutiliza o pipeline das atletas
/// ([PlayerPhotoPrecache.resolve]): download via `package:http` (funciona
/// no Android e no Flutter Web), cache estático e o **mesmo recorte
/// facial** dos chips — sem faixa de fundo sobrando acima da cabeça. Do
/// retângulo "rosto + ombros" calculado, o círculo usa o quadrado
/// ancorado no topo (rosto + começo dos ombros).
class _StaffAvatar extends StatefulWidget {
  const _StaffAvatar({required this.photoUrl, required this.size});

  final String? photoUrl;
  final double size;

  @override
  State<_StaffAvatar> createState() => _StaffAvatarState();
}

class _StaffAvatarState extends State<_StaffAvatar> {
  PortraitPhoto? _photo;

  @override
  void initState() {
    super.initState();
    _resolvePhoto();
  }

  @override
  void didUpdateWidget(_StaffAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) _resolvePhoto();
  }

  void _resolvePhoto() {
    final String? url = widget.photoUrl;
    if (url == null || url.trim().isEmpty) {
      _photo = null;
      return;
    }
    _photo = null;
    PlayerPhotoPrecache.resolve(url).then((PortraitPhoto? photo) {
      if (!mounted || widget.photoUrl != url) return;
      setState(() => _photo = photo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final PortraitPhoto? photo = _photo;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CbbcColors.blueSoft,
        border: Border.all(color: CbbcColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo == null
          ? Icon(
              Icons.person_rounded,
              size: widget.size * 0.62,
              color: CbbcColors.blueDeep,
            )
          : CustomPaint(
              painter: _StaffAvatarPainter(photo),
              child: const SizedBox.expand(),
            ),
    );
  }
}

class _StaffAvatarPainter extends CustomPainter {
  const _StaffAvatarPainter(this.photo);

  final PortraitPhoto photo;

  @override
  void paint(Canvas canvas, Size size) {
    // O recorte das atletas é retrato (rosto + ombros + camiseta). Para o
    // círculo 1:1, usa o quadrado do topo desse recorte: mesma largura
    // (centrada no rosto) e altura igual — rosto e começo dos ombros.
    final Rect r = photo.sourceRect;
    final double side = math.min(r.width, r.height);
    final Rect src = Rect.fromLTWH(
      r.left + (r.width - side) / 2,
      r.top,
      side,
      side,
    );
    final Paint paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    canvas.drawImageRect(photo.image, src, Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_StaffAvatarPainter oldDelegate) =>
      oldDelegate.photo != photo;
}
