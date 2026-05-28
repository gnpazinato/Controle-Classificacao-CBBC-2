/// Classes funcionais aceitas para basquetebol em cadeira de rodas
/// (mesmo padrão IWBF adotado pela CBBC).
const List<double> kAcceptedPlayerClasses = <double>[
  1.0,
  1.5,
  2.0,
  2.5,
  3.0,
  3.5,
  4.0,
  4.5,
];

const double kMinPlayerClass = 1.0;
const double kMaxPlayerClass = 4.5;

bool isAcceptedPlayerClass(double value) {
  for (final double accepted in kAcceptedPlayerClasses) {
    if ((accepted - value).abs() < 0.0001) {
      return true;
    }
  }
  return false;
}

/// Converte representação textual (`"2.5"` ou `"2,5"`) para [double].
///
/// Tolera:
/// - lixo de formatação (NBSP, zero-width, variantes Unicode de
///   vírgula/ponto, fragmentos de rich-text);
/// - classes "meias" que o Excel/LibreOffice converteu acidentalmente em
///   data (ex: usuário digitou `1.5`, o Excel interpretou como `1/5` =
///   1º de maio e gravou `2026-05-01`).
double? parsePlayerClass(String? raw) {
  if (raw == null) return null;
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // 0) Caso Excel: a célula virou data. Tenta recuperar "dia.mês".
  final double? fromDate = _classFromDateLikeString(trimmed);
  if (fromDate != null) return fromDate;

  // 1) Vírgulas (e variantes) viram ponto.
  String normalized = trimmed
      .replaceAll(',', '.')
      .replaceAll('٫', '.') // árabe decimal
      .replaceAll('‚', '.'); // single low-9 quotation mark
  // 2) Variantes Unicode de ponto viram ponto comum.
  normalized = normalized
      .replaceAll('․', '.') // one dot leader
      .replaceAll('．', '.'); // fullwidth full stop
  // 3) Mantém só dígitos e pontos.
  normalized = normalized.replaceAll(RegExp(r'[^0-9.]'), '');
  if (normalized.isEmpty) return null;
  // 4) Mais de um ponto = formato inválido.
  if (RegExp(r'\.').allMatches(normalized).length > 1) return null;
  final double? parsed = double.tryParse(normalized);
  if (parsed == null) return null;
  if (!isAcceptedPlayerClass(parsed)) return null;
  return parsed;
}

/// Se [raw] for uma data (ISO `YYYY-MM-DD` ou br `DD/MM/YYYY`), tenta
/// reconstruir a classe que o usuário tentou digitar. Por exemplo:
/// `1.5` digitado pelo usuário vira `2026-05-01` quando o Excel converte
/// para data; recuperamos `1.5` (dia=1, mês=5).
double? _classFromDateLikeString(String raw) {
  int? day;
  int? month;

  final RegExpMatch? iso =
      RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(raw);
  if (iso != null) {
    month = int.tryParse(iso.group(2)!);
    day = int.tryParse(iso.group(3)!);
  } else {
    final RegExpMatch? br =
        RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$').firstMatch(raw);
    if (br != null) {
      day = int.tryParse(br.group(1)!);
      month = int.tryParse(br.group(2)!);
    }
  }

  if (day == null || month == null) return null;
  if (day < 1 || day > 31 || month < 1 || month > 12) return null;

  // Excel grava "1.5" → 1º de maio → day=1, month=5. Reconstrói day.month.
  final double dotMonth = day + month / 10.0;
  if (isAcceptedPlayerClass(dotMonth)) return dotMonth;
  // Fallback: caso a ordem tenha sido invertida em outro locale.
  final double monthDot = month + day / 10.0;
  if (isAcceptedPlayerClass(monthDot)) return monthDot;
  return null;
}
