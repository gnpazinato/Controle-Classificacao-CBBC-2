import '../constants/player_classes.dart';

enum PlayerGender { male, female, unspecified }

PlayerGender _parseGender(String? raw) {
  if (raw == null) return PlayerGender.unspecified;
  final String value = raw.trim().toLowerCase();
  if (value.isEmpty) return PlayerGender.unspecified;
  if (value == 'm' ||
      value == 'male' ||
      value == 'masc' ||
      value == 'masculino' ||
      value == 'masculina') {
    return PlayerGender.male;
  }
  if (value == 'f' ||
      value == 'female' ||
      value == 'fem' ||
      value == 'feminino' ||
      value == 'feminina') {
    return PlayerGender.female;
  }
  return PlayerGender.unspecified;
}

String _genderToString(PlayerGender gender) {
  switch (gender) {
    case PlayerGender.male:
      return 'male';
    case PlayerGender.female:
      return 'female';
    case PlayerGender.unspecified:
      return 'unspecified';
  }
}

/// Atleta importado da planilha/PDF de referência do clube.
class Player {
  Player({
    required this.id,
    required this.clubName,
    required this.shirtNumber,
    required this.fullName,
    required this.playerClass,
    this.dateOfBirth,
    this.gender = PlayerGender.unspecified,
    this.photoUrl,
  }) : assert(playerClass == null || playerClass > 0,
            'playerClass deve ser positivo se informado');

  final String id;
  final String clubName;
  final int shirtNumber;
  final String fullName;

  /// Classe funcional (1.0 a 4.5). `null` quando o atleta veio sem
  /// classe da planilha/PDF — a usuária precisa preencher manualmente
  /// na tela de validação antes do jogo.
  final double? playerClass;
  final DateTime? dateOfBirth;
  final PlayerGender gender;

  /// Link público da foto do atleta. Normalmente vem de uma coluna da
  /// planilha apontando para Google Drive ou outra URL de imagem.
  final String? photoUrl;

  String get displayName => fullName;

  /// Última palavra do nome — usada em chips compactos em quadra.
  String get surnameForChip {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return fullName;
    return parts.last;
  }

  /// Primeiro nome — usado em chips compactos em quadra (mais
  /// reconhecível à distância que o sobrenome em listas com vários
  /// jogadores da mesma família).
  String get firstNameForChip {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return fullName;
    return parts.first;
  }

  bool get hasValidClass {
    final double? c = playerClass;
    return c != null && isAcceptedPlayerClass(c);
  }

  /// Idade em anos completos relativa a [reference]. `null` se DOB nulo.
  int? ageAt(DateTime reference) {
    final DateTime? dob = dateOfBirth;
    if (dob == null) return null;
    int age = reference.year - dob.year;
    final bool beforeBirthdayThisYear = reference.month < dob.month ||
        (reference.month == dob.month && reference.day < dob.day);
    if (beforeBirthdayThisYear) age -= 1;
    return age;
  }

  /// Sub-16 vale enquanto o atleta NÃO completou 17 anos até [reference]
  /// (data de término da competição). Ou seja: vale até a véspera do
  /// 17º aniversário, inclusive.
  bool isUnderU16(DateTime reference) {
    final int? age = ageAt(reference);
    if (age == null) return false;
    return age < 17;
  }

  /// Sub-23 vale enquanto o atleta NÃO completou 24 anos até [reference]
  /// (data de término da competição). Mesma lógica do sub-16.
  bool isUnderU23(DateTime reference) {
    final int? age = ageAt(reference);
    if (age == null) return false;
    return age < 24;
  }

  bool get isFemale => gender == PlayerGender.female;

  Player copyWith({
    String? id,
    String? clubName,
    int? shirtNumber,
    String? fullName,
    double? playerClass,
    DateTime? dateOfBirth,
    PlayerGender? gender,
    String? photoUrl,
    bool clearPhotoUrl = false,
  }) {
    return Player(
      id: id ?? this.id,
      clubName: clubName ?? this.clubName,
      shirtNumber: shirtNumber ?? this.shirtNumber,
      fullName: fullName ?? this.fullName,
      playerClass: playerClass ?? this.playerClass,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'clubName': clubName,
        'shirtNumber': shirtNumber,
        'fullName': fullName,
        'playerClass': playerClass,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'gender': _genderToString(gender),
        'photoUrl': photoUrl,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      clubName: (json['clubName'] as String?) ??
          (json['teamName'] as String? ?? ''),
      shirtNumber: json['shirtNumber'] as int,
      fullName: (json['fullName'] as String?) ?? '',
      playerClass: (json['playerClass'] as num?)?.toDouble(),
      dateOfBirth: (json['dateOfBirth'] as String?) == null
          ? null
          : DateTime.parse(json['dateOfBirth'] as String),
      gender: _parseGender(json['gender'] as String?),
      photoUrl: json['photoUrl'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Player && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Player(id: $id, $displayName, #$shirtNumber, class $playerClass)';
}
