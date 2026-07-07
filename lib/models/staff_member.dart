/// Membro da comissão técnica importado da planilha (linha cuja coluna
/// "função" traz algo diferente de "atleta" — técnico, assistente,
/// fisioterapeuta, mecânico etc.).
///
/// Diferente do [Player], não carrega classe, camisa nem nascimento:
/// aparece apenas na lista do clube (resumo da importação) e nunca entra
/// em quadra.
class StaffMember {
  StaffMember({
    required this.id,
    required this.clubName,
    required this.fullName,
    required this.role,
    this.photoUrl,
  });

  final String id;
  final String clubName;
  final String fullName;

  /// Texto da coluna "função" como veio da planilha (ex.: "Técnico").
  final String role;

  /// Link público da foto — preenchido quando a importação por pasta do
  /// Drive/OneDrive encontra um arquivo com o nome do membro.
  final String? photoUrl;

  String get displayName => fullName;

  StaffMember copyWith({
    String? id,
    String? clubName,
    String? fullName,
    String? role,
    String? photoUrl,
  }) {
    return StaffMember(
      id: id ?? this.id,
      clubName: clubName ?? this.clubName,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'clubName': clubName,
        'fullName': fullName,
        'role': role,
        'photoUrl': photoUrl,
      };

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] as String,
      clubName: (json['clubName'] as String?) ?? '',
      fullName: (json['fullName'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
      photoUrl: json['photoUrl'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StaffMember && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StaffMember(id: $id, $fullName, $role)';
}
