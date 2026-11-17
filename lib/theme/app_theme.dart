import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AppColors {
  // Light Mode (Apple HIG)
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark Mode (Slate Palette)
  static const Color darkBackground = Color(0xFF020617);
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkBorder = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Accents
  static const Color primary = Color(0xFF059669); // emerald-600
  static const Color primaryLight = Color(0xFF10B981); // emerald-500
  static const Color primarySoft = Color(0xFFECFDF5);
  static const Color emerald = Color(0xFF10B981);
  static const Color orange = Color(0xFFF97316);
  static const Color rose = Color(0xFFF43F5E);
  static const Color blue = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color amber = Color(0xFFF59E0B);
  static const Color indigo = Color(0xFF6366F1);

  static const List<Color> presetPalette = [
    Color(0xFF8B5CF6), // Roxo (Nubank style)
    Color(0xFFF97316), // Laranja (Itaú/Inter style)
    Color(0xFF3B82F6), // Azul
    Color(0xFF059669), // Esmeralda
    Color(0xFFF43F5E), // Rosa/Vermelho
    Color(0xFF06B6D4), // Ciano
    Color(0xFFF59E0B), // Âmbar
    Color(0xFF475569), // Grafite/Black
  ];

  // Contraste AA para textos semânticos
  static const Color successStrong = Color(0xFF047857);
  static const Color dangerStrong = Color(0xFFE11D48);
  static const Color warningStrong = Color(0xFFC2410C);

  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  static Color success(BuildContext c) => isDark(c) ? emerald : successStrong;
  static Color danger(BuildContext c) => isDark(c) ? rose : dangerStrong;
  static Color warning(BuildContext c) => isDark(c) ? orange : warningStrong;
  static Color textPrimary(BuildContext c) =>
      isDark(c) ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(BuildContext c) =>
      isDark(c) ? darkTextSecondary : lightTextSecondary;
  static Color surface(BuildContext c) =>
      isDark(c) ? darkSurface : lightSurface;
  static Color border(BuildContext c) => isDark(c) ? darkBorder : lightBorder;
}

/// Formatador de moeda em centavos (digitação da direita para a esquerda).
class CentavosCurrencyFormatter extends TextInputFormatter {
  final int maxDigits;

  const CentavosCurrencyFormatter({this.maxDigits = 12});

  static String formatFromCents(int cents) {
    final value = cents / 100.0;
    final fmt = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: '',
      decimalDigits: 2,
    );
    return fmt.format(value).trim();
  }

  static String formatDouble(double value) {
    final cents = (value * 100).round();
    return formatFromCents(cents);
  }

  static double parseValue(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0.0;
    final cents = int.tryParse(digits) ?? 0;
    return cents / 100.0;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length > maxDigits) {
      digitsOnly = digitsOnly.substring(0, maxDigits);
    }

    final int cents = digitsOnly.isEmpty ? 0 : (int.tryParse(digitsOnly) ?? 0);
    final String formatted = formatFromCents(cents);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AppFormatters {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static String currency(double value, {bool discreet = false}) {
    if (discreet) return 'R\$ ••••';
    return _currency.format(value);
  }

  static String yearMonthFromDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }

  static String addMonths(String ym, int deltaMonths) {
    final parts = ym.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final dt = DateTime(y, m + deltaMonths, 1);
    return yearMonthFromDate(dt);
  }

  static String monthLabel(String ym, {bool short = false}) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return ym;
    final dt = DateTime(y, m, 1);
    if (short) {
      final s = DateFormat('MMM/yy', 'pt_BR').format(dt).replaceAll('.', '');
      return s[0].toUpperCase() + s.substring(1);
    }
    final raw = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(dt);
    return raw[0].toUpperCase() + raw.substring(1);
  }

  static String shortDate(DateTime dt) {
    return DateFormat('dd/MM/yyyy', 'pt_BR').format(dt);
  }

  static String dayMonth(DateTime dt) {
    return DateFormat('dd MMM', 'pt_BR').format(dt).replaceAll('.', '');
  }
}

class HigSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double bottomPadding;

  const HigSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.bottomPadding = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 6, right: 6, bottom: bottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textSecondary(context),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class HigGroupedCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const HigGroupedCard({
    super.key,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    return Material(
      color: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.border(context),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

class HigCurrencyHeroField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color accentColor;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final Widget? bottomAccessory;

  const HigCurrencyHeroField({
    super.key,
    required this.controller,
    required this.label,
    this.accentColor = AppColors.primary,
    this.autofocus = false,
    this.onChanged,
    this.bottomAccessory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border(context),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'R\$',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: accentColor.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: IntrinsicWidth(
                  child: TextField(
                    controller: controller,
                    autofocus: autofocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      const CentavosCurrencyFormatter(),
                    ],
                    textAlign: TextAlign.center,
                    onChanged: onChanged,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      color: accentColor,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0,00',
                      hintStyle: TextStyle(
                        color: accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (bottomAccessory != null) ...[
            const SizedBox(height: 10),
            bottomAccessory!,
          ],
        ],
      ),
    );
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.rose,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.lightBorder, width: 0.8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF1F5F9),
        thickness: 1,
        space: 1,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: AppColors.primary,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.primaryLight,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        secondary: AppColors.primary,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.rose,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.darkBorder, width: 0.8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: AppColors.primaryLight,
        brightness: Brightness.dark,
      ),
    );
  }
}
