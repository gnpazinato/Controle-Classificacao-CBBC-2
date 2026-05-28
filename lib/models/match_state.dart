import '../constants/point_limits.dart';
import '../theme/cbbc_theme.dart';
import 'player.dart';
import 'team.dart';

/// Regras de bonificação aceitas pela competição. Cada bandeira liga ou
/// desliga uma categoria que, quando presente em quadra, eleva o limite
/// efetivo da equipe até [kBonusPointCeiling].
class BonusRules {
  const BonusRules({
    this.youthU16 = false,
    this.youthU23 = false,
    this.female = false,
  });

  final bool youthU16;
  final bool youthU23;
  final bool female;

  bool get anyEnabled => youthU16 || youthU23 || female;

  bool qualifies(Player player, DateTime reference) {
    if (youthU16 && player.isUnderU16(reference)) return true;
    if (youthU23 && player.isUnderU23(reference)) return true;
    if (female && player.isFemale) return true;
    return false;
  }

  BonusRules copyWith({bool? youthU16, bool? youthU23, bool? female}) {
    return BonusRules(
      youthU16: youthU16 ?? this.youthU16,
      youthU23: youthU23 ?? this.youthU23,
      female: female ?? this.female,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'youthU16': youthU16,
        'youthU23': youthU23,
        'female': female,
      };

  factory BonusRules.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BonusRules();
    return BonusRules(
      youthU16: (json['youthU16'] as bool?) ?? false,
      youthU23: (json['youthU23'] as bool?) ?? false,
      female: (json['female'] as bool?) ?? false,
    );
  }
}

class MatchState {
  MatchState({
    required this.teamA,
    required this.teamB,
    double pointLimit = kDefaultPointLimit,
    List<String?>? teamASlots,
    List<String?>? teamBSlots,
    Set<String>? selectedTeamAIds,
    Set<String>? selectedTeamBIds,
    this.competitionName,
    BonusRules bonusRules = const BonusRules(),
    DateTime? referenceDate,
    JerseyColor? teamAJerseyColor,
    JerseyColor? teamBJerseyColor,
  })  : _pointLimit = pointLimit,
        _bonusRules = bonusRules,
        _referenceDate = referenceDate ?? DateTime.now(),
        _teamAJerseyColor = teamAJerseyColor ?? JerseyColor.white,
        _teamBJerseyColor = teamBJerseyColor ?? JerseyColor.darkBlue,
        _teamASlots = _initSlots(teamASlots, fallbackSet: selectedTeamAIds),
        _teamBSlots = _initSlots(teamBSlots, fallbackSet: selectedTeamBIds);

  static List<String?> _initSlots(
    List<String?>? slots, {
    Set<String>? fallbackSet,
  }) {
    final List<String?> result =
        List<String?>.filled(kMaxPlayersPerTeam, null, growable: false);
    if (slots != null) {
      for (int i = 0; i < slots.length && i < kMaxPlayersPerTeam; i++) {
        result[i] = slots[i];
      }
      return result;
    }
    if (fallbackSet != null) {
      int idx = 0;
      for (final String id in fallbackSet) {
        if (idx >= kMaxPlayersPerTeam) break;
        result[idx] = id;
        idx++;
      }
    }
    return result;
  }

  final Team teamA;
  final Team teamB;
  final String? competitionName;

  double _pointLimit;
  BonusRules _bonusRules;
  final DateTime _referenceDate;
  final JerseyColor _teamAJerseyColor;
  final JerseyColor _teamBJerseyColor;
  final List<String?> _teamASlots;
  final List<String?> _teamBSlots;

  double get pointLimit => _pointLimit;
  BonusRules get bonusRules => _bonusRules;
  DateTime get referenceDate => _referenceDate;
  JerseyColor get teamAJerseyColor => _teamAJerseyColor;
  JerseyColor get teamBJerseyColor => _teamBJerseyColor;

  Set<String> get selectedTeamAIds => <String>{
        for (final String? id in _teamASlots)
          if (id != null) id,
      };

  Set<String> get selectedTeamBIds => <String>{
        for (final String? id in _teamBSlots)
          if (id != null) id,
      };

  List<Player> get selectedTeamAPlayers => <Player>[
        for (final String? id in _teamASlots)
          if (id != null) _findPlayer(teamA, id),
      ];

  List<Player> get selectedTeamBPlayers => <Player>[
        for (final String? id in _teamBSlots)
          if (id != null) _findPlayer(teamB, id),
      ];

  List<Player?> get teamASlotPlayers => <Player?>[
        for (final String? id in _teamASlots)
          id == null ? null : _findPlayer(teamA, id),
      ];

  List<Player?> get teamBSlotPlayers => <Player?>[
        for (final String? id in _teamBSlots)
          id == null ? null : _findPlayer(teamB, id),
      ];

  double get totalPointsTeamA => _sumClasses(selectedTeamAPlayers);
  double get totalPointsTeamB => _sumClasses(selectedTeamBPlayers);

  bool hasBonusInCourt(List<Player> selected) {
    if (!_bonusRules.anyEnabled) return false;
    for (final Player p in selected) {
      if (_bonusRules.qualifies(p, _referenceDate)) return true;
    }
    return false;
  }

  bool get hasBonusInCourtTeamA => hasBonusInCourt(selectedTeamAPlayers);
  bool get hasBonusInCourtTeamB => hasBonusInCourt(selectedTeamBPlayers);

  /// `true` se o atleta atende alguma das regras de bonificação ativas
  /// (sub-16/sub-23 considerando a data de término da competição;
  /// feminina). Usado pra mostrar estrelinha ao lado do nome.
  bool qualifiesForBonus(Player player) =>
      _bonusRules.qualifies(player, _referenceDate);

  double get effectiveLimitTeamA =>
      hasBonusInCourtTeamA ? kBonusPointCeiling : _pointLimit;

  double get effectiveLimitTeamB =>
      hasBonusInCourtTeamB ? kBonusPointCeiling : _pointLimit;

  bool get isTeamAOverLimit => totalPointsTeamA > effectiveLimitTeamA;
  bool get isTeamBOverLimit => totalPointsTeamB > effectiveLimitTeamB;

  void setPointLimit(double value) {
    if (!isAcceptedPointLimit(value)) {
      throw ArgumentError('Limite de pontos não permitido: $value');
    }
    _pointLimit = value;
  }

  void setBonusRules(BonusRules rules) {
    _bonusRules = rules;
  }

  bool selectPlayer(Player player) {
    final List<String?> slots = _slotsFor(player);
    if (slots.contains(player.id)) return true;
    final int empty = slots.indexOf(null);
    if (empty == -1) return false;
    slots[empty] = player.id;
    return true;
  }

  void deselectPlayer(Player player) {
    final List<String?> slots = _slotsFor(player);
    final int idx = slots.indexOf(player.id);
    if (idx == -1) return;
    slots[idx] = null;
  }

  bool togglePlayer(Player player) {
    final List<String?> slots = _slotsFor(player);
    final int existing = slots.indexOf(player.id);
    if (existing != -1) {
      slots[existing] = null;
      return false;
    }
    final int empty = slots.indexOf(null);
    if (empty == -1) return false;
    slots[empty] = player.id;
    return true;
  }

  void clearTeamA() {
    for (int i = 0; i < _teamASlots.length; i++) {
      _teamASlots[i] = null;
    }
  }

  void clearTeamB() {
    for (int i = 0; i < _teamBSlots.length; i++) {
      _teamBSlots[i] = null;
    }
  }

  void clearAll() {
    clearTeamA();
    clearTeamB();
  }

  List<String?> _slotsFor(Player player) {
    if (teamA.players.any((Player p) => p.id == player.id)) {
      return _teamASlots;
    }
    if (teamB.players.any((Player p) => p.id == player.id)) {
      return _teamBSlots;
    }
    throw ArgumentError(
        'Atleta ${player.id} não pertence à Equipe A nem à Equipe B');
  }

  static Player _findPlayer(Team team, String id) {
    return team.players.firstWhere(
      (Player p) => p.id == id,
      orElse: () => throw StateError(
          'Atleta $id não encontrado no clube ${team.clubName}'),
    );
  }

  double _sumClasses(List<Player> players) {
    double total = 0;
    for (final Player p in players) {
      // Atletas sem classe contam como 0 — usuária precisa preencher
      // manualmente antes do jogo pra somar de verdade.
      total += p.playerClass ?? 0.0;
    }
    return total;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'competitionName': competitionName,
        'teamA': teamA.toJson(),
        'teamB': teamB.toJson(),
        'pointLimit': _pointLimit,
        'teamASlots': _teamASlots,
        'teamBSlots': _teamBSlots,
        'bonusRules': _bonusRules.toJson(),
        'referenceDate': _referenceDate.toIso8601String(),
        'teamAJerseyColor': _teamAJerseyColor.id,
        'teamBJerseyColor': _teamBJerseyColor.id,
      };

  factory MatchState.fromJson(Map<String, dynamic> json) {
    return MatchState(
      teamA: Team.fromJson(json['teamA'] as Map<String, dynamic>),
      teamB: Team.fromJson(json['teamB'] as Map<String, dynamic>),
      pointLimit:
          (json['pointLimit'] as num?)?.toDouble() ?? kDefaultPointLimit,
      teamASlots: _readSlotsJson(json['teamASlots']),
      teamBSlots: _readSlotsJson(json['teamBSlots']),
      competitionName: json['competitionName'] as String?,
      bonusRules:
          BonusRules.fromJson(json['bonusRules'] as Map<String, dynamic>?),
      referenceDate: (json['referenceDate'] as String?) == null
          ? null
          : DateTime.parse(json['referenceDate'] as String),
      teamAJerseyColor: JerseyColor.fromId(
        json['teamAJerseyColor'] as String?,
        fallback: JerseyColor.white,
      ),
      teamBJerseyColor: JerseyColor.fromId(
        json['teamBJerseyColor'] as String?,
        fallback: JerseyColor.darkBlue,
      ),
    );
  }

  static List<String?>? _readSlotsJson(Object? raw) {
    if (raw is! List<dynamic>) return null;
    return raw.map((Object? v) => v as String?).toList(growable: false);
  }
}
