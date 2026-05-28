import 'package:flutter/material.dart';

/// Paleta institucional inspirada na identidade visual da CBBC
/// (Confederação Brasileira de Basquetebol em Cadeira de Rodas).
///
/// - azul cobalto do logo como cor primária;
/// - laranja-basquete como accent secundário;
/// - fundo Slate 50 moderno (SaaS premium);
/// - vermelho institucional para alerta de limite excedido.
abstract class CbbcColors {
  CbbcColors._();

  /// Azul cobalto principal — usado em logo, botões primários, bordas.
  static const Color blue = Color(0xFF1F66B6);

  /// Variante mais escura — borda/contraste.
  static const Color blueDeep = Color(0xFF154B82);

  /// Variante translúcida — fundos sutis (cards selecionados, bônus).
  static const Color blueSoft = Color(0xFFDCE9F5);

  /// Laranja basquete — accent secundário (bola do logo).
  static const Color orange = Color(0xFFE87B2B);

  /// Superfícies elevadas — cards são brancos puros.
  static const Color surface = Colors.white;

  /// Fundo geral da aplicação (Slate 50 — off-white moderno).
  static const Color slate50 = Color(0xFFF8FAFC);

  /// Fill de inputs e estados de hover sutil.
  static const Color slate100 = Color(0xFFF1F5F9);

  /// Bordas sutis de cards e separadores discretos.
  static const Color slate200 = Color(0xFFE2E8F0);

  /// Verde de sucesso usado no status "Arquivo carregado com sucesso".
  static const Color successGreen = Color(0xFF1B8A3A);

  /// Compat: alias para [slate50] (uso histórico, evitar em código novo).
  static const Color offWhite = slate50;

  /// Compat: alias para [slate100] (uso histórico, evitar em código novo).
  static const Color offWhiteElevated = slate100;

  /// Texto principal.
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// Texto secundário.
  static const Color textSecondary = Color(0xFF5A6068);

  /// Vermelho institucional usado no alerta "Limite de pontos excedido.".
  static const Color alertRed = Color(0xFFB3261E);

  /// Fundo levemente avermelhado quando o limite é excedido.
  static const Color alertRedSurface = Color(0xFFFDECEC);
}

/// Cores de camiseta oferecidas no setup da partida. Mantidas escuras
/// (exceto a branca) porque o número da camisa é sempre desenhado em
/// branco — fundos claros prejudicam a leitura à distância.
class JerseyColor {
  const JerseyColor._(this.id, this.label, this.fill, this.numberColor);

  final String id;
  final String label;
  final Color fill;

  /// Cor do número da camisa pintado por cima. Branca em fundos escuros;
  /// preta no fundo branco.
  final Color numberColor;

  static const JerseyColor black =
      JerseyColor._('black', 'Preto', Color(0xFF111111), Colors.white);
  static const JerseyColor white = JerseyColor._(
      'white', 'Branco', Color(0xFFFFFFFF), CbbcColors.textPrimary);
  static const JerseyColor darkBlue = JerseyColor._(
      'darkBlue', 'Azul marinho', Color(0xFF0E2547), Colors.white);
  static const JerseyColor darkRed =
      JerseyColor._('darkRed', 'Vermelho escuro', Color(0xFF8B1A1A), Colors.white);
  static const JerseyColor darkGray =
      JerseyColor._('darkGray', 'Cinza escuro', Color(0xFF3F3F3F), Colors.white);

  static const List<JerseyColor> values = <JerseyColor>[
    black,
    white,
    darkBlue,
    darkRed,
    darkGray,
  ];

  static JerseyColor fromId(String? id, {required JerseyColor fallback}) {
    if (id == null) return fallback;
    for (final JerseyColor c in values) {
      if (c.id == id) return c;
    }
    return fallback;
  }
}

/// Tema Material 3 do app, com paleta CBBC.
ThemeData buildCbbcTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: CbbcColors.blue,
    brightness: Brightness.light,
    primary: CbbcColors.blue,
    onPrimary: Colors.white,
    secondary: CbbcColors.orange,
    onSecondary: Colors.white,
    surface: CbbcColors.surface,
    onSurface: CbbcColors.textPrimary,
    error: CbbcColors.alertRed,
    onError: Colors.white,
  );

  final TextTheme baseText = ThemeData(brightness: Brightness.light).textTheme;
  final TextTheme textTheme = baseText.apply(
    bodyColor: CbbcColors.textPrimary,
    displayColor: CbbcColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: CbbcColors.slate50,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: CbbcColors.blue,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 80,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CbbcColors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CbbcColors.blueDeep,
        side: const BorderSide(color: CbbcColors.blueDeep, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CbbcColors.blueDeep,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CbbcColors.slate100,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CbbcColors.slate200, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CbbcColors.slate200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CbbcColors.blue, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CbbcColors.alertRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CbbcColors.alertRed, width: 1.6),
      ),
      labelStyle: const TextStyle(color: CbbcColors.textSecondary),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(CbbcColors.surface),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) return CbbcColors.blue;
          return Colors.transparent;
        },
      ),
      checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
      side: const BorderSide(color: CbbcColors.blueDeep, width: 1.4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return CbbcColors.slate100;
        },
      ),
      trackColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) return CbbcColors.blue;
          return CbbcColors.slate200;
        },
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) return CbbcColors.blueDeep;
          return CbbcColors.slate200;
        },
      ),
    ),
    cardTheme: CardThemeData(
      color: CbbcColors.surface,
      elevation: 1,
      shadowColor: const Color(0x14000000),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: CbbcColors.slate200, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: CbbcColors.slate200,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: CbbcColors.textPrimary,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: CbbcColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
