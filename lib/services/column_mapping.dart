/// Mapeamento de cabeçalhos aceitos (PT-BR + EN) para os campos canônicos
/// usados pelos parsers de planilha e PDF.
///
/// Cada chave é um cabeçalho normalizado (lower-case, sem acento, espaços
/// virando `_`) e o valor é o nome canônico do campo.
const Map<String, String> kHeaderAliases = <String, String>{
  // clube
  'clube': 'club',
  'club': 'club',
  'equipe': 'club',
  'time': 'club',
  'team': 'club',
  'team_name': 'club',
  'club_name': 'club',
  'nome_do_clube': 'club',

  // classe
  'classe': 'class',
  'class': 'class',
  'classificacao': 'class',
  'classificacao_funcional': 'class',
  'class_funcional': 'class',
  'player_class': 'class',

  // atleta (nome completo)
  'atleta': 'name',
  'nome': 'name',
  'jogador': 'name',
  'jogadora': 'name',
  'nome_completo': 'name',
  'name': 'name',
  'player_name': 'name',
  'full_name': 'name',
  'athlete': 'name',

  // camisa
  'camisa': 'shirt',
  'numero': 'shirt',
  'no': 'shirt',
  'n': 'shirt',
  'numero_camisa': 'shirt',
  'numero_da_camisa': 'shirt',
  'shirt': 'shirt',
  'shirt_number': 'shirt',
  'jersey': 'shirt',

  // data de nascimento
  'data_de_nascimento': 'dob',
  'data_nascimento': 'dob',
  'nascimento': 'dob',
  'dn': 'dob',
  'dob': 'dob',
  'date_of_birth': 'dob',
  'birth': 'dob',

  // gênero
  'genero': 'gender',
  'sexo': 'gender',
  'gender': 'gender',

  // foto do atleta
  'foto': 'photo',
  'link_foto': 'photo',
  'link_da_foto': 'photo',
  'url_foto': 'photo',
  'url_da_foto': 'photo',
  'foto_url': 'photo',
  'photo': 'photo',
  'photo_url': 'photo',
  'image': 'photo',
  'image_url': 'photo',
  'google_drive': 'photo',
  'drive': 'photo',

  // competição (opcional)
  'competicao': 'competition',
  'competition': 'competition',
  'competition_name': 'competition',
  'nome_da_competicao': 'competition',
};

/// Rótulos reconhecidos pra célula "Data de término da competição" no
/// topo da planilha. Tratado fora de [canonicalField] porque é um
/// metadado solto, não uma coluna de tabela.
const Set<String> _kCompetitionEndDateLabels = <String>{
  'data_de_termino_da_competicao',
  'data_de_termino',
  'termino_da_competicao',
  'fim_da_competicao',
  'competition_end_date',
  'end_date',
};

bool isCompetitionEndDateLabel(String raw) {
  final String key = normalizeHeaderToken(raw);
  if (key.isEmpty) return false;
  if (_kCompetitionEndDateLabels.contains(key)) return true;
  // Permite sufixos comuns como "(DD/MM/AAAA)" ou ":" sem quebrar.
  for (final String label in _kCompetitionEndDateLabels) {
    if (key.startsWith('${label}_') || key == label) return true;
  }
  return false;
}

/// Normaliza cabeçalho para chave: lower-case + sem acento + `[a-z0-9_]`.
String normalizeHeaderToken(String raw) {
  final String lower = raw.trim().toLowerCase();
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < lower.length; i++) {
    final String c = lower[i];
    final String stripped = _stripAccent(c);
    final int code = stripped.codeUnitAt(0);
    final bool isLower = code >= 0x61 && code <= 0x7A;
    final bool isDigit = code >= 0x30 && code <= 0x39;
    if (isLower || isDigit) {
      buffer.write(stripped);
    } else if (c == ' ' || c == '-' || c == '_' || c == '/') {
      if (buffer.isNotEmpty &&
          buffer.toString()[buffer.length - 1] != '_') {
        buffer.write('_');
      }
    }
  }
  String result = buffer.toString();
  if (result.endsWith('_')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

const Map<String, String> _accentMap = <String, String>{
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

String _stripAccent(String c) => _accentMap[c] ?? c;

/// Retorna o nome canônico do campo (`club`, `class`, `name`, `shirt`,
/// `dob`, `gender`, `photo`, `competition`) ou `null` se o cabeçalho não for
/// reconhecido.
String? canonicalField(String rawHeader) {
  final String key = normalizeHeaderToken(rawHeader);
  if (key.isEmpty) return null;
  return kHeaderAliases[key];
}

/// Tenta interpretar a data nas formas mais comuns:
/// `YYYY-MM-DD`, `DD/MM/YYYY`, `DD-MM-YYYY`, `DD.MM.YYYY`.
DateTime? parseDateOfBirth(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final DateTime? iso = DateTime.tryParse(trimmed);
  if (iso != null) return DateTime.utc(iso.year, iso.month, iso.day);
  final RegExp dmy = RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$');
  final RegExpMatch? m = dmy.firstMatch(trimmed);
  if (m != null) {
    final int day = int.parse(m.group(1)!);
    final int month = int.parse(m.group(2)!);
    int year = int.parse(m.group(3)!);
    if (year < 100) {
      year += year >= 30 ? 1900 : 2000;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      return DateTime.utc(year, month, day);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Aceita número da camisa em `int` ou string. Retorna `null` se inválido
/// ou fora da faixa 0..99.
int? parseShirtNumber(String? raw) {
  if (raw == null) return null;
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final double? asDouble = double.tryParse(trimmed.replaceAll(',', '.'));
  if (asDouble == null) return null;
  if (asDouble < 0 || asDouble > 99) return null;
  final int asInt = asDouble.toInt();
  if (asInt != asDouble) return null;
  return asInt;
}

/// ID determinístico pra um clube a partir do nome.
String clubIdFromName(String name) {
  final StringBuffer buffer = StringBuffer('club-');
  final String normalized = normalizeHeaderToken(name);
  buffer.write(normalized.isEmpty ? 'unknown' : normalized);
  return buffer.toString();
}
