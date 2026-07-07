import 'player.dart';
import 'staff_member.dart';

/// Clube/equipe importado da planilha de referência.
///
/// Clubes CBBC podem ter atletas masculinos, femininos ou ambos (em
/// competições mistas). Por isso o `Team` não carrega gênero — a regra
/// de bonificação feminina é avaliada por atleta em quadra.
class Team {
  Team({
    required this.id,
    required this.clubName,
    List<Player>? players,
    List<StaffMember>? staff,
  })  : players = List<Player>.unmodifiable(players ?? const <Player>[]),
        staff =
            List<StaffMember>.unmodifiable(staff ?? const <StaffMember>[]);

  final String id;
  final String clubName;
  final List<Player> players;

  /// Comissão técnica (técnico, assistente, fisioterapeuta...). Aparece
  /// só nas listas do clube — nunca em quadra.
  final List<StaffMember> staff;

  String get displayName => clubName;

  int get playerCount => players.length;

  Team copyWith({
    String? id,
    String? clubName,
    List<Player>? players,
    List<StaffMember>? staff,
  }) {
    return Team(
      id: id ?? this.id,
      clubName: clubName ?? this.clubName,
      players: players ?? this.players,
      staff: staff ?? this.staff,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'clubName': clubName,
        'players': players.map((Player p) => p.toJson()).toList(),
        'staff': staff.map((StaffMember s) => s.toJson()).toList(),
      };

  factory Team.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawPlayers =
        (json['players'] as List<dynamic>?) ?? const <dynamic>[];
    // Sessões salvas antes da v2.4.0 não têm a chave `staff`.
    final List<dynamic> rawStaff =
        (json['staff'] as List<dynamic>?) ?? const <dynamic>[];
    return Team(
      id: json['id'] as String,
      clubName: (json['clubName'] as String?) ??
          (json['teamName'] as String? ?? ''),
      players: rawPlayers
          .map((dynamic p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      staff: rawStaff
          .map((dynamic s) => StaffMember.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Team && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Team(id: $id, $displayName, players: ${players.length})';
}
