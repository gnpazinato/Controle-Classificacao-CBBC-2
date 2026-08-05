import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/player_classes.dart';
import '../models/player.dart';
import '../models/staff_member.dart';
import '../models/team.dart';
import '../services/cache_service.dart';
import '../services/import_result.dart';
import '../services/player_photo_url.dart';
import '../services/roster_sync_service.dart';
import '../theme/cbbc_theme.dart';
import '../widgets/cbbc_logo_header.dart';
import 'match_setup_screen.dart';
import 'missing_data_screen.dart';

class ValidationSummaryScreen extends StatefulWidget {
  const ValidationSummaryScreen({
    super.key,
    required this.result,
    this.cache,
    this.sync,
  });

  final ImportResult result;
  final CacheService? cache;

  /// Serviço de sincronização/persistência do elenco. Recebe as edições
  /// manuais feitas aqui (renomear clube, excluir atleta…) ao continuar.
  final RosterSyncService? sync;

  @override
  State<ValidationSummaryScreen> createState() =>
      _ValidationSummaryScreenState();
}

class _ValidationSummaryScreenState extends State<ValidationSummaryScreen> {
  late List<Team> _teams;

  @override
  void initState() {
    super.initState();
    _teams = <Team>[...widget.result.teams];
  }

  List<ImportIssue> get _errors => widget.result.issues
      .where((ImportIssue i) => i.severity == ImportIssueSeverity.error)
      .toList();

  List<ImportIssue> get _warnings => widget.result.issues
      .where((ImportIssue i) => i.severity == ImportIssueSeverity.warning)
      .toList();

  int get _playerCount {
    int total = 0;
    for (final Team t in _teams) {
      total += t.players.length;
    }
    return total;
  }

  void _replaceTeam(Team updated) {
    final int idx = _teams.indexWhere((Team t) => t.id == updated.id);
    if (idx == -1) return;
    setState(() => _teams[idx] = updated);
  }

  void _updatePlayer(Team team, Player updated) {
    final List<Player> next = team.players
        .map((Player p) => p.id == updated.id ? updated : p)
        .toList(growable: false);
    _replaceTeam(team.copyWith(players: next));
  }

  Future<void> _confirmAndDeletePlayer(Team team, Player player) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Excluir atleta?'),
        content: Text(
          'Deseja remover ${player.displayName} (#${player.shirtNumber}) de '
          '${team.displayName}? Essa ação não pode ser desfeita.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final List<Player> next = team.players
        .where((Player p) => p.id != player.id)
        .toList(growable: false);
    _replaceTeam(team.copyWith(players: next));
  }

  Future<void> _confirmAndDeleteTeam(Team team) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Excluir equipe?'),
        content: Text(
          'Deseja remover ${team.displayName} e todos os seus '
          '${team.players.length} atleta(s)? Essa ação não pode ser desfeita.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _teams.removeWhere((Team t) => t.id == team.id));
  }

  Future<void> _editTeamName(Team team) async {
    final TextEditingController controller =
        TextEditingController(text: team.clubName);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Editar nome da equipe'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome da equipe',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == team.clubName) return;
    _replaceTeam(team.copyWith(clubName: newName));
  }

  @override
  Widget build(BuildContext context) {
    final List<ImportIssue> errors = _errors;
    final List<ImportIssue> warnings = _warnings;

    return Scaffold(
      appBar: AppBar(
        title: const CbbcAppBarTitle(text: 'Resumo da importação'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _Header(
              competitionName: widget.result.competitionName,
              competitionEndDate: widget.result.competitionEndDate,
              clubCount: _teams.length,
              playerCount: _playerCount,
              hasBlockingIssues: errors.isNotEmpty,
            ),
            const SizedBox(height: 16),
            if (errors.isNotEmpty)
              _IssueBlock(
                title: 'Erros que impedem iniciar a partida',
                color: CbbcColors.alertRedSurface,
                borderColor: CbbcColors.alertRed,
                icon: Icons.error_outline,
                issues: errors,
                trailing: FilledButton.tonalIcon(
                  key: const Key('view-issues-button'),
                  onPressed: () => _openMissingData(context),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Ver detalhes'),
                ),
              ),
            if (warnings.isNotEmpty)
              _IssueBlock(
                title: 'Avisos',
                color: const Color(0xFFFFF7E0),
                borderColor: CbbcColors.orange,
                icon: Icons.warning_amber_outlined,
                issues: warnings,
              ),
            const SizedBox(height: 8),
            ..._teamTiles(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Carregar outro arquivo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('continue-button'),
                  onPressed: errors.isEmpty && _teams.length >= 2
                      ? _continue
                      : null,
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _teamTiles() {
    if (_teams.isEmpty) return const <Widget>[];

    final List<Team> sorted = <Team>[..._teams]
      ..sort((Team a, Team b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    return <Widget>[
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Clubes encontrados',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      ...sorted.map(_teamCard),
    ];
  }

  Widget _teamCard(Team team) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // Remove o divisor padrão e padronizamos o padding interno.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: Key('team-tile-${team.id}'),
            tilePadding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            childrenPadding: EdgeInsets.zero,
            title: Text(
              team.displayName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              team.staff.isEmpty
                  ? '${team.players.length} atleta(s)'
                  : '${team.players.length} atleta(s) · '
                      '${team.staff.length} na comissão técnica',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  key: Key('team-rename-${team.id}'),
                  tooltip: 'Renomear equipe',
                  icon: const Icon(Icons.edit_outlined,
                      color: CbbcColors.blueDeep, size: 22),
                  onPressed: () => _editTeamName(team),
                ),
                IconButton(
                  key: Key('team-delete-${team.id}'),
                  tooltip: 'Excluir equipe',
                  icon: const Icon(Icons.delete_outline,
                      color: CbbcColors.alertRed, size: 22),
                  onPressed: () => _confirmAndDeleteTeam(team),
                ),
                const Icon(Icons.expand_more, color: CbbcColors.blueDeep),
              ],
            ),
            children: _playerRows(team),
          ),
        ),
      ),
    );
  }

  List<Widget> _playerRows(Team team) {
    if (team.players.isEmpty && team.staff.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.all(12),
          child: Text('Nenhum atleta neste clube.'),
        ),
      ];
    }
    final List<Player> sorted = <Player>[...team.players]
      ..sort((Player a, Player b) => a.shirtNumber.compareTo(b.shirtNumber));
    return <Widget>[
      const Divider(height: 1),
      if (sorted.isNotEmpty) ...<Widget>[
        const _PlayerRowHeader(),
        const Divider(height: 1),
        for (final Player p in sorted)
          _EditablePlayerRow(
            key: ValueKey<String>('player-row-${p.id}'),
            player: p,
            siblings: team.players,
            onChanged: (Player updated) => _updatePlayer(team, updated),
            onDelete: () => _confirmAndDeletePlayer(team, p),
          ),
      ],
      // Comissão técnica no fim da lista: só nome + função, sem os
      // campos de atleta (classe, nascimento, camisa...).
      if (team.staff.isNotEmpty) ...<Widget>[
        const Divider(height: 1),
        const _StaffSectionLabel(),
        for (final StaffMember s in team.staff)
          _StaffRow(
            key: ValueKey<String>('staff-row-${s.id}'),
            member: s,
            onChanged: (StaffMember updated) => _updateStaff(team, updated),
          ),
        const SizedBox(height: 8),
      ],
    ];
  }

  void _updateStaff(Team team, StaffMember updated) {
    final List<StaffMember> next = team.staff
        .map((StaffMember s) => s.id == updated.id ? updated : s)
        .toList(growable: false);
    _replaceTeam(team.copyWith(staff: next));
  }

  Future<void> _openMissingData(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MissingDataScreen(result: widget.result),
      ),
    );
  }

  Future<void> _continue() async {
    // Persiste as edições manuais no elenco salvo do tablet. No modo
    // link, a próxima sincronização com a planilha sobrescreve — a
    // nuvem é a fonte da verdade.
    await widget.sync?.updateTeams(_teams);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MatchSetupScreen(
          teams: _teams,
          competitionName: widget.result.competitionName,
          competitionEndDate: widget.result.competitionEndDate,
          sync: widget.sync,
        ),
      ),
    );
  }
}

String _formatDob(DateTime? dob) {
  if (dob == null) return '—';
  final String day = dob.day.toString().padLeft(2, '0');
  final String month = dob.month.toString().padLeft(2, '0');
  return '$day/$month/${dob.year}';
}

class _StaffSectionLabel extends StatelessWidget {
  const _StaffSectionLabel();

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: CbbcColors.textSecondary, letterSpacing: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Row(
        children: <Widget>[
          const Icon(Icons.badge_outlined,
              size: 14, color: CbbcColors.textSecondary),
          const SizedBox(width: 6),
          Text('COMISSÃO TÉCNICA', style: style),
        ],
      ),
    );
  }
}

/// Linha da comissão técnica no mesmo padrão visual das linhas de
/// atleta: um retângulo com o nome ocupando o espaço restante e um
/// retângulo com a função encostado na lateral direita.
class _StaffRow extends StatefulWidget {
  const _StaffRow({super.key, required this.member, required this.onChanged});

  final StaffMember member;
  final ValueChanged<StaffMember> onChanged;

  @override
  State<_StaffRow> createState() => _StaffRowState();
}

class _StaffRowState extends State<_StaffRow> {
  static const double _kRoleFieldWidth = 150;

  late TextEditingController _nameCtrl;
  late TextEditingController _roleCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.member.fullName);
    _roleCtrl = TextEditingController(text: widget.member.role);
  }

  @override
  void didUpdateWidget(_StaffRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_nameCtrl.text != widget.member.fullName) {
      _nameCtrl.text = widget.member.fullName;
    }
    if (_roleCtrl.text != widget.member.role) {
      _roleCtrl.text = widget.member.role;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == widget.member.fullName) return;
    widget.onChanged(widget.member.copyWith(fullName: trimmed));
  }

  void _onRoleChanged(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == widget.member.role) return;
    widget.onChanged(widget.member.copyWith(role: trimmed));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: TextField(
              key: Key('staff-name-input-${widget.member.id}'),
              controller: _nameCtrl,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(),
              ),
              onChanged: _onNameChanged,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _kRoleFieldWidth,
            child: TextField(
              key: Key('staff-role-input-${widget.member.id}'),
              controller: _roleCtrl,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CbbcColors.blueDeep,
              ),
              onChanged: _onRoleChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerRowHeader extends StatelessWidget {
  const _PlayerRowHeader();

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: CbbcColors.textSecondary, letterSpacing: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(
        children: <Widget>[
          SizedBox(width: 48, child: Text('CAMISA', style: style)),
          const SizedBox(width: 8),
          Expanded(child: Text('NOME', style: style)),
          const SizedBox(width: 8),
          SizedBox(width: 108, child: Text('NASCIMENTO', style: style)),
          const SizedBox(width: 8),
          SizedBox(width: 78, child: Text('GÊNERO', style: style)),
          const SizedBox(width: 8),
          SizedBox(width: 64, child: Text('CLASSE', style: style)),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _EditablePlayerRow extends StatefulWidget {
  const _EditablePlayerRow({
    super.key,
    required this.player,
    required this.siblings,
    required this.onChanged,
    required this.onDelete,
  });

  final Player player;
  final List<Player> siblings;
  final ValueChanged<Player> onChanged;
  final VoidCallback onDelete;

  @override
  State<_EditablePlayerRow> createState() => _EditablePlayerRowState();
}

class _EditablePlayerRowState extends State<_EditablePlayerRow> {
  late TextEditingController _shirtCtrl;
  late TextEditingController _nameCtrl;
  String? _shirtError;

  @override
  void initState() {
    super.initState();
    _shirtCtrl =
        TextEditingController(text: widget.player.shirtNumber.toString());
    _nameCtrl = TextEditingController(text: widget.player.fullName);
  }

  @override
  void didUpdateWidget(_EditablePlayerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shirtError == null) {
      final String s = widget.player.shirtNumber.toString();
      if (_shirtCtrl.text != s) _shirtCtrl.text = s;
    }
    if (_nameCtrl.text != widget.player.fullName) {
      _nameCtrl.text = widget.player.fullName;
    }
  }

  @override
  void dispose() {
    _shirtCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onShirtChanged(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() => _shirtError = 'Obrigatório');
      return;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0 || parsed > 99) {
      setState(() => _shirtError = '0–99');
      return;
    }
    if (parsed == widget.player.shirtNumber) {
      setState(() => _shirtError = null);
      return;
    }
    final bool duplicate = widget.siblings.any(
        (Player p) => p.id != widget.player.id && p.shirtNumber == parsed);
    if (duplicate) {
      setState(() => _shirtError = '#$parsed em uso');
      return;
    }
    setState(() => _shirtError = null);
    widget.onChanged(widget.player.copyWith(shirtNumber: parsed));
  }

  void _onNameChanged(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == widget.player.fullName) return;
    widget.onChanged(widget.player.copyWith(fullName: trimmed));
  }

  Future<void> _editPhotoUrl() async {
    final TextEditingController controller =
        TextEditingController(text: widget.player.photoUrl ?? '');
    final String? raw = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Link da foto'),
          content: TextField(
            key: Key('photo-url-dialog-${widget.player.id}'),
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL pública da foto',
              hintText: 'Link do Google Drive ou URL da imagem',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Remover'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || raw == null) return;
    final String? normalized = normalizePlayerPhotoUrl(raw);
    if (normalized == null) {
      widget.onChanged(widget.player.copyWith(clearPhotoUrl: true));
      return;
    }
    widget.onChanged(widget.player.copyWith(photoUrl: normalized));
  }

  Future<void> _pickDob() async {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime.utc(now.year - 80);
    final DateTime last = DateTime.utc(now.year);
    final DateTime initial = widget.player.dateOfBirth ??
        DateTime.utc(now.year - 25, now.month, now.day);
    final DateTime safe = initial.isBefore(first)
        ? first
        : (initial.isAfter(last) ? last : initial);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: safe,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    widget.onChanged(widget.player
        .copyWith(dateOfBirth: DateTime.utc(picked.year, picked.month, picked.day)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 48,
            child: TextField(
              key: Key('shirt-input-${widget.player.id}'),
              controller: _shirtCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 8),
                border: const OutlineInputBorder(),
                errorText: _shirtError,
                errorMaxLines: 1,
                errorStyle: const TextStyle(fontSize: 10, height: 0.6),
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
              onChanged: _onShirtChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: Key('name-input-${widget.player.id}'),
              controller: _nameCtrl,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: Key('photo-url-${widget.player.id}'),
                  tooltip: widget.player.photoUrl == null
                      ? 'Adicionar foto'
                      : 'Editar foto',
                  icon: Icon(
                    widget.player.photoUrl == null
                        ? Icons.add_photo_alternate_outlined
                        : Icons.image_outlined,
                    color: widget.player.photoUrl == null
                        ? CbbcColors.textSecondary
                        : CbbcColors.blueDeep,
                    size: 19,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: _editPhotoUrl,
                ),
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 34, minHeight: 34),
              ),
              onChanged: _onNameChanged,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: InkWell(
              key: Key('dob-input-${widget.player.id}'),
              onTap: _pickDob,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _formatDob(widget.player.dateOfBirth),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: DropdownButtonFormField<PlayerGender>(
              key: Key('gender-dropdown-${widget.player.id}'),
              value: widget.player.gender,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<PlayerGender>>[
                DropdownMenuItem<PlayerGender>(
                  value: PlayerGender.unspecified,
                  child: Text('—', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem<PlayerGender>(
                  value: PlayerGender.male,
                  child: Text('Masc', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem<PlayerGender>(
                  value: PlayerGender.female,
                  child: Text('Fem', style: TextStyle(fontSize: 13)),
                ),
              ],
              onChanged: (PlayerGender? next) {
                if (next == null) return;
                widget.onChanged(widget.player.copyWith(gender: next));
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: DropdownButtonFormField<double>(
              key: Key('class-dropdown-${widget.player.id}'),
              value: widget.player.playerClass,
              isDense: true,
              isExpanded: true,
              hint: const Text(
                '—',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                border: const OutlineInputBorder(),
                fillColor: widget.player.playerClass == null
                    ? CbbcColors.alertRedSurface
                    : null,
                filled: widget.player.playerClass == null,
              ),
              items: kAcceptedPlayerClasses
                  .map((double v) => DropdownMenuItem<double>(
                        value: v,
                        child: Text(v.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(growable: false),
              onChanged: (double? next) {
                if (next == null) return;
                widget.onChanged(widget.player.copyWith(playerClass: next));
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: Key('player-delete-${widget.player.id}'),
            tooltip: 'Excluir atleta',
            icon: const Icon(Icons.close, color: CbbcColors.alertRed, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.competitionName,
    required this.competitionEndDate,
    required this.clubCount,
    required this.playerCount,
    required this.hasBlockingIssues,
  });

  final String? competitionName;
  final DateTime? competitionEndDate;
  final int clubCount;
  final int playerCount;
  final bool hasBlockingIssues;

  static String _fmtDate(DateTime d) {
    final String day = d.day.toString().padLeft(2, '0');
    final String month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color statusColor =
        hasBlockingIssues ? CbbcColors.alertRed : CbbcColors.successGreen;
    final Color statusBg = hasBlockingIssues
        ? CbbcColors.alertRedSurface
        : CbbcColors.successGreen.withValues(alpha: 0.10);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (competitionName != null && competitionName!.isNotEmpty) ...<Widget>[
              Text(
                competitionName!,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: CbbcColors.blueDeep,
                ),
              ),
              const SizedBox(height: 2),
            ],
            if (competitionEndDate != null) ...<Widget>[
              Text(
                'Término: ${_fmtDate(competitionEndDate!)}',
                style: text.bodySmall
                    ?.copyWith(color: CbbcColors.textSecondary),
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatBadge(
                    icon: Icons.groups_outlined,
                    value: clubCount.toString(),
                    label: 'Clubes',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatBadge(
                    icon: Icons.sports_basketball_outlined,
                    value: playerCount.toString(),
                    label: 'Atletas',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    hasBlockingIssues
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasBlockingIssues
                          ? 'O arquivo tem erros — corrija antes de continuar.'
                          : 'Arquivo carregado com sucesso.',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CbbcColors.blueSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CbbcColors.blue.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: CbbcColors.surface,
            ),
            child: Icon(icon, color: CbbcColors.blue, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: CbbcColors.blueDeep,
                    height: 1.0,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: CbbcColors.textSecondary,
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

class _IssueBlock extends StatelessWidget {
  const _IssueBlock({
    required this.title,
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.issues,
    this.trailing,
  });

  final String title;
  final Color color;
  final Color borderColor;
  final IconData icon;
  final List<ImportIssue> issues;
  final Widget? trailing;

  static const int _previewCount = 5;

  @override
  Widget build(BuildContext context) {
    final List<ImportIssue> preview = issues.length > _previewCount
        ? issues.sublist(0, _previewCount)
        : issues;
    final int remaining = issues.length - preview.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
          top: BorderSide(color: borderColor.withValues(alpha: 0.25)),
          right: BorderSide(color: borderColor.withValues(alpha: 0.25)),
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.25)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: borderColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '$title (${issues.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: borderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...preview.map((ImportIssue issue) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('•  ${issue.message}'),
              )),
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '… e mais $remaining',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          if (trailing != null) ...<Widget>[
            const SizedBox(height: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
