import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/point_limits.dart';
import '../models/match_state.dart';
import '../models/player.dart';
import '../models/staff_member.dart';
import '../models/team.dart';
import '../services/roster_sync_service.dart';
import '../theme/cbbc_theme.dart';
import '../widgets/cbbc_logo_header.dart';
import '../widgets/player_jersey_icon.dart';
import '../widgets/player_portrait_chip.dart';
import 'lineup_control_screen.dart';

/// Configuração da partida: escolhe Equipe A, Equipe B, cor da camiseta,
/// pontuação máxima, bonificações da competição e as datas de referência
/// (hoje e término da competição).
///
/// Quando o elenco veio de um link (Drive/OneDrive), esta tela é o ponto
/// de sincronização: re-importa a planilha ao entrar, ao voltar de uma
/// partida e a cada ciclo do timer do [RosterSyncService] — alterações na
/// nuvem aparecem aqui sem precisar recarregar o link na tela inicial.
class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({
    super.key,
    this.teams,
    this.competitionName,
    this.competitionEndDate,
    this.restored,
    this.sync,
  });

  final List<Team>? teams;
  final String? competitionName;
  final DateTime? competitionEndDate;
  final MatchState? restored;

  /// Fonte viva do elenco. `null` em fluxos antigos/testes — a tela
  /// funciona igual, só sem sincronização.
  final RosterSyncService? sync;

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  Team? _teamA;
  Team? _teamB;
  JerseyColor _teamAColor = JerseyColor.white;
  JerseyColor _teamBColor = JerseyColor.darkBlue;
  double _pointLimit = kDefaultPointLimit;
  BonusRules _bonus = const BonusRules();
  late DateTime _todayDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final MatchState? restored = widget.restored;
    if (restored != null) {
      _teamA = restored.teamA;
      _teamB = restored.teamB;
      _teamAColor = restored.teamAJerseyColor;
      _teamBColor = restored.teamBJerseyColor;
      _pointLimit = restored.pointLimit;
      _bonus = restored.bonusRules;
      _endDate = restored.referenceDate;
    } else {
      _endDate = widget.competitionEndDate ?? _addDays(DateTime.now(), 7);
      // Bonificação salva com os dados da competição: marcada num jogo
      // anterior, volta marcada mesmo depois de fechar o app ou desligar
      // o tablet. (Com partida restaurada, vale a do MatchState acima.)
      _bonus = widget.sync?.snapshot?.bonusRules ?? _bonus;
    }
    _todayDate = _stripTime(DateTime.now());
    _clearYouthBonusIfBlocked();
    final RosterSyncService? sync = widget.sync;
    if (sync != null) {
      sync.addListener(_onRosterChanged);
      // Alterações feitas na planilha enquanto o app estava em outra tela
      // (ou fechado) entram já na chegada — sem esperar o timer.
      unawaited(sync.syncNow());
    }
    // Aquece o cache (memória + disco) das fotos de TODOS os clubes: é o
    // que garante retratos funcionando no ginásio sem internet.
    _precacheRosterPhotos();
  }

  @override
  void dispose() {
    widget.sync?.removeListener(_onRosterChanged);
    super.dispose();
  }

  /// A planilha sincronizou (ou uma tentativa terminou): rebaixa o elenco
  /// pro dropdown e re-resolve as equipes já escolhidas pelo id — que é
  /// estável entre importações por derivar do nome do clube.
  void _onRosterChanged() {
    if (!mounted) return;
    setState(() {
      final List<Team> teams = _availableTeams;
      _teamA = _resolveTeam(_teamA, teams);
      _teamB = _resolveTeam(_teamB, teams);
      _clearYouthBonusIfBlocked();
    });
    _precacheRosterPhotos();
  }

  static Team? _resolveTeam(Team? previous, List<Team> teams) {
    if (previous == null) return null;
    for (final Team t in teams) {
      if (t.id == previous.id) return t;
    }
    // Clube sumiu da planilha: limpa a seleção em vez de apontar pra um
    // objeto que não existe mais na lista do dropdown.
    return null;
  }

  void _precacheRosterPhotos() {
    unawaited(PlayerPhotoPrecache.precacheAll(<String?>[
      for (final Team t in _availableTeams) ...<String?>[
        for (final Player p in t.players) p.photoUrl,
        for (final StaffMember s in t.staff) s.photoUrl,
      ],
    ]));
  }

  static DateTime _stripTime(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  static DateTime _addDays(DateTime d, int days) =>
      _stripTime(d.add(Duration(days: days)));

  List<Team> get _availableTeams {
    // Elenco sincronizado tem prioridade: reflete a planilha da nuvem.
    final List<Team>? synced = widget.sync?.snapshot?.teams;
    final List<Team>? raw =
        (synced != null && synced.isNotEmpty) ? synced : widget.teams;
    final List<Team> source;
    if (raw != null) {
      source = raw;
    } else {
      final MatchState? r = widget.restored;
      if (r != null) {
        source = <Team>[r.teamA, r.teamB];
      } else {
        return const <Team>[];
      }
    }
    return <Team>[...source]
      ..sort((Team a, Team b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  }

  String? get _competitionName =>
      widget.sync?.snapshot?.competitionName ??
      widget.competitionName ??
      widget.restored?.competitionName;

  bool get _teamsAreSame =>
      _teamA != null && _teamB != null && _teamA == _teamB;

  /// Atletas sem data de nascimento nas equipes escolhidas (ou em todas
  /// as equipes carregadas, enquanto nenhuma foi escolhida). Com um que
  /// seja, as bonificações Sub-16/Sub-23 ficam bloqueadas: não dá pra
  /// comprovar a idade.
  int get _playersWithoutDob {
    final List<Team> selected = <Team>[
      if (_teamA != null) _teamA!,
      if (_teamB != null && _teamB != _teamA) _teamB!,
    ];
    final List<Team> scope = selected.isNotEmpty ? selected : _availableTeams;
    int count = 0;
    for (final Team team in scope) {
      for (final Player p in team.players) {
        if (p.dateOfBirth == null) count++;
      }
    }
    return count;
  }

  void _setTeam({Team? a, Team? b, bool setA = false, bool setB = false}) {
    setState(() {
      if (setA) _teamA = a;
      if (setB) _teamB = b;
      _clearYouthBonusIfBlocked();
    });
  }

  void _clearYouthBonusIfBlocked() {
    if (_playersWithoutDob > 0 && (_bonus.youthU16 || _bonus.youthU23)) {
      _bonus = _bonus.copyWith(youthU16: false, youthU23: false);
    }
  }

  bool get _canStart =>
      _teamA != null && _teamB != null && !_teamsAreSame;

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime.utc(now.year - 2);
    final DateTime last = DateTime.utc(now.year + 5);
    final DateTime safeInitial =
        initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    onPicked(_stripTime(picked));
  }

  Future<void> _onStartPressed() async {
    if (!_canStart) return;
    _clearYouthBonusIfBlocked();
    final Team a = _teamA!;
    final Team b = _teamB!;
    final MatchState state = MatchState(
      teamA: a,
      teamB: b,
      pointLimit: _pointLimit,
      competitionName: _competitionName,
      bonusRules: _bonus,
      referenceDate: _endDate,
      teamAJerseyColor: _teamAColor,
      teamBJerseyColor: _teamBColor,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LineupControlScreen(initialState: state),
      ),
    );
    // Voltou da partida: sincroniza na hora pra qualquer alteração feita
    // na planilha durante o jogo aparecer já na montagem do próximo.
    if (mounted) unawaited(widget.sync?.syncNow());
  }

  @override
  Widget build(BuildContext context) {
    final List<Team> teams = _availableTeams;
    final String? compName = _competitionName;

    return Scaffold(
      appBar: AppBar(
        title: const CbbcAppBarTitle(text: 'Configurar partida'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (compName != null && compName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    compName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: CbbcColors.blueDeep,
                        ),
                  ),
                ),
              if (widget.sync?.hasLink ?? false)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SyncStatusBanner(sync: widget.sync!),
                ),
              _TeamCard(
                title: 'Equipe A',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TeamDropdown(
                      key: const Key('team-a-dropdown'),
                      label: 'Selecionar Equipe A',
                      value: _teamA,
                      teams: teams,
                      onChanged: (Team? value) =>
                          _setTeam(a: value, setA: true),
                    ),
                    if (_teamA != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _JerseyColorPicker(
                        keyName: 'team-a-color',
                        label: 'Cor da camiseta',
                        selected: _teamAColor,
                        onChanged: (JerseyColor c) =>
                            setState(() => _teamAColor = c),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _TeamCard(
                title: 'Equipe B',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TeamDropdown(
                      key: const Key('team-b-dropdown'),
                      label: 'Selecionar Equipe B',
                      value: _teamB,
                      teams: teams,
                      onChanged: (Team? value) =>
                          _setTeam(b: value, setB: true),
                    ),
                    if (_teamB != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _JerseyColorPicker(
                        keyName: 'team-b-color',
                        label: 'Cor da camiseta',
                        selected: _teamBColor,
                        onChanged: (JerseyColor c) =>
                            setState(() => _teamBColor = c),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PointLimitDropdown(
                value: _pointLimit,
                onChanged: (double next) =>
                    setState(() => _pointLimit = next),
              ),
              const SizedBox(height: 20),
              _BonusSection(
                rules: _bonus,
                playersWithoutDob: _playersWithoutDob,
                onChanged: (BonusRules r) {
                  setState(() => _bonus = r);
                  // Só escolhas explícitas do usuário são persistidas —
                  // o desmarque automático de _clearYouthBonusIfBlocked
                  // não apaga a preferência salva.
                  unawaited(widget.sync?.updateBonusRules(r));
                },
              ),
              const SizedBox(height: 16),
              _DatesSection(
                todayDate: _todayDate,
                endDate: _endDate,
                onPickToday: () => _pickDate(
                  initial: _todayDate,
                  onPicked: (DateTime d) => setState(() => _todayDate = d),
                ),
                onPickEnd: () => _pickDate(
                  initial: _endDate,
                  onPicked: (DateTime d) => setState(() => _endDate = d),
                ),
              ),
              if (_teamsAreSame)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Equipe A e Equipe B devem ser diferentes.',
                    key: Key('teams-equal-error'),
                    style: TextStyle(color: CbbcColors.alertRed),
                  ),
                ),
              const SizedBox(height: 24),
              if (teams.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nenhum clube carregado. Volte e importe um arquivo.',
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const Key('start-match-button'),
            onPressed: _canStart ? _onStartPressed : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar partida'),
          ),
        ),
      ),
    );
  }
}

/// Faixa discreta com o estado da sincronização com a planilha da nuvem:
/// sincronizando agora, sincronizada (com horário) ou sem conexão usando
/// os dados salvos no tablet.
class _SyncStatusBanner extends StatelessWidget {
  const _SyncStatusBanner({required this.sync});

  final RosterSyncService sync;

  /// Carimbo "dd/MM às HH:MM" — diz exatamente de quando é a versão da
  /// planilha/pasta que o tablet está usando.
  static String _stamp(DateTime d) {
    final String day = d.day.toString().padLeft(2, '0');
    final String month = d.month.toString().padLeft(2, '0');
    final String h = d.hour.toString().padLeft(2, '0');
    final String m = d.minute.toString().padLeft(2, '0');
    return '$day/$month às $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String message;
    Widget? leading;

    if (sync.isSyncing) {
      icon = Icons.sync;
      color = CbbcColors.blueDeep;
      message = 'Sincronizando com a planilha…';
      leading = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: CbbcColors.blueDeep,
        ),
      );
    } else if (sync.lastError != null) {
      icon = Icons.cloud_off_outlined;
      color = CbbcColors.orange;
      // Sem sync nesta execução, vale a data de gravação do elenco salvo
      // no tablet — é a "versão da pasta" que está em uso.
      final DateTime? ok = sync.lastSyncAt ?? sync.snapshot?.savedAt;
      message = ok == null
          ? 'Sem conexão com a planilha — usando os dados salvos no tablet.'
          : 'Sem conexão com a planilha — usando os dados de ${_stamp(ok)}.';
    } else if (sync.lastSyncAt != null) {
      icon = Icons.cloud_done_outlined;
      color = CbbcColors.successGreen;
      message = 'Planilha sincronizada em ${_stamp(sync.lastSyncAt!)}.';
    } else {
      icon = Icons.cloud_queue_outlined;
      color = CbbcColors.textSecondary;
      message = 'Aguardando a primeira sincronização com a planilha…';
    }

    return Container(
      key: const Key('roster-sync-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          leading ?? Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 6,
                  height: 18,
                  decoration: BoxDecoration(
                    color: CbbcColors.blue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: CbbcColors.blueDeep,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _TeamDropdown extends StatelessWidget {
  const _TeamDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.teams,
    required this.onChanged,
  });

  final String label;
  final Team? value;
  final List<Team> teams;
  final ValueChanged<Team?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Team>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: teams
          .map(
            (Team t) => DropdownMenuItem<Team>(
              value: t,
              child: Text(
                t.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: teams.isEmpty ? null : onChanged,
    );
  }
}

class _PointLimitDropdown extends StatelessWidget {
  const _PointLimitDropdown({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<double>(
      key: const Key('point-limit-dropdown'),
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Pontuação máxima por equipe',
      ),
      items: kAcceptedPointLimits
          .map(
            (double v) => DropdownMenuItem<double>(
              value: v,
              child: Text(v.toStringAsFixed(1)),
            ),
          )
          .toList(),
      onChanged: (double? next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _JerseyColorPicker extends StatelessWidget {
  const _JerseyColorPicker({
    required this.keyName,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String keyName;
  final String label;
  final JerseyColor selected;
  final ValueChanged<JerseyColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key(keyName),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final JerseyColor option in JerseyColor.values)
              _JerseyOption(
                color: option,
                isSelected: option.id == selected.id,
                onTap: () => onChanged(option),
              ),
          ],
        ),
      ],
    );
  }
}

class _JerseyOption extends StatelessWidget {
  const _JerseyOption({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final JerseyColor color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: color.label,
      child: InkWell(
        key: Key('jersey-option-${color.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? CbbcColors.orange : Colors.black12,
              width: isSelected ? 2.2 : 1,
            ),
          ),
          child: _JerseyPreviewIcon(color: color),
        ),
      ),
    );
  }
}

class _JerseyPreviewIcon extends StatelessWidget {
  const _JerseyPreviewIcon({required this.color});

  final JerseyColor color;

  static final Player _previewPlayer = Player(
    id: 'preview',
    clubName: '',
    shirtNumber: 10,
    fullName: '',
    playerClass: null,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: PlayerJerseyIcon(
        player: _previewPlayer,
        isTeamA: true,
        jerseyColor: color,
        size: 48,
      ),
    );
  }
}

class _DatesSection extends StatelessWidget {
  const _DatesSection({
    required this.todayDate,
    required this.endDate,
    required this.onPickToday,
    required this.onPickEnd,
  });

  final DateTime todayDate;
  final DateTime endDate;
  final VoidCallback onPickToday;
  final VoidCallback onPickEnd;

  static String _fmt(DateTime d) {
    final String day = d.day.toString().padLeft(2, '0');
    final String month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CbbcColors.offWhiteElevated,
        border: Border.all(color: const Color(0x22000000)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Datas de referência',
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: CbbcColors.blueDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Conferida com o tablet — se estiver errada, toque para corrigir.',
            style: text.bodySmall?.copyWith(color: CbbcColors.textSecondary),
          ),
          const SizedBox(height: 8),
          _DateRow(
            keyName: 'today-date-row',
            label: 'Data de hoje',
            value: _fmt(todayDate),
            onTap: onPickToday,
          ),
          const SizedBox(height: 6),
          _DateRow(
            keyName: 'end-date-row',
            label: 'Data de término da competição',
            value: _fmt(endDate),
            onTap: onPickEnd,
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.keyName,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key(keyName),
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '$label: $value',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.edit, size: 18, color: CbbcColors.blueDeep),
          ],
        ),
      ),
    );
  }
}

class _BonusSection extends StatelessWidget {
  const _BonusSection({
    required this.rules,
    required this.playersWithoutDob,
    required this.onChanged,
  });

  final BonusRules rules;

  /// Quantos atletas do escopo atual estão sem data de nascimento.
  /// Acima de zero, os switches Sub-16/Sub-23 ficam desabilitados.
  final int playersWithoutDob;

  final ValueChanged<BonusRules> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool youthBlocked = playersWithoutDob > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: CbbcColors.blueSoft.withValues(alpha: 0.55),
        border: Border.all(color: CbbcColors.blue.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.star, color: CbbcColors.orange, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bonificações da competição',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: CbbcColors.blueDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Quando houver atleta da categoria marcada em quadra, a equipe '
            'pode chegar até 15.0 pontos sem alerta.',
            style: text.bodySmall?.copyWith(color: CbbcColors.textSecondary),
          ),
          const SizedBox(height: 4),
          if (youthBlocked)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                'Sub-16 e Sub-23 indisponíveis: $playersWithoutDob '
                'atleta(s) sem data de nascimento na importação.',
                key: const Key('bonus-youth-blocked-message'),
                style: text.bodySmall?.copyWith(
                  color: CbbcColors.alertRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _BonusSwitch(
            keyName: 'bonus-u16-checkbox',
            title: 'Sub-16',
            hint:
                'Para ter bonificação, o atleta não pode completar 17 anos durante a competição.',
            value: rules.youthU16,
            onChanged: youthBlocked
                ? null
                : (bool v) => onChanged(rules.copyWith(youthU16: v)),
          ),
          _BonusSwitch(
            keyName: 'bonus-u23-checkbox',
            title: 'Sub-23',
            hint:
                'Para ter bonificação, o atleta não pode completar 24 anos durante a competição.',
            value: rules.youthU23,
            onChanged: youthBlocked
                ? null
                : (bool v) => onChanged(rules.copyWith(youthU23: v)),
          ),
          _BonusSwitch(
            keyName: 'bonus-female-checkbox',
            title: 'Atleta feminina',
            hint:
                'Selecione caso a competição seja masculina e tenha bonificação para atletas femininas.',
            value: rules.female,
            onChanged: (bool v) => onChanged(rules.copyWith(female: v)),
          ),
        ],
      ),
    );
  }
}

class _BonusSwitch extends StatelessWidget {
  const _BonusSwitch({
    required this.keyName,
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String keyName;
  final String title;
  final String hint;
  final bool value;

  /// `null` desabilita o switch (bonificação indisponível).
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: Key(keyName),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: CbbcColors.blueDeep,
        ),
      ),
      subtitle: Text(
        hint,
        style: const TextStyle(
          fontSize: 12,
          color: CbbcColors.textSecondary,
          height: 1.25,
        ),
      ),
    );
  }
}
