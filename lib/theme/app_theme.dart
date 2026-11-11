import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AppColors {
  // Light Mode (Apple HIG - espelhado do BioStats)
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A); // slate-900
  static const Color lightTextSecondary = Color(0xFF64748B); // slate-500

  // Dark Mode (Slate Palette - espelhado do BioStats)
  static const Color darkBackground = Color(0xFF020617); // slate-950
  static const Color darkSurface = Color(0xFF0F172A); // slate-900
  static const Color darkBorder = Color(0xFF1E293B); // slate-800
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // slate-50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // slate-400

  // Accents (Paleta Verde Financeiro Apple HIG)
  static const Color indigoPrimary = Color(0xFF059669); // emerald-600 (Verde Principal)
  static const Color indigoLight = Color(0xFF10B981); // emerald-500 (Verde Claro)
  static const Color indigoSoft = Color(0xFFECFDF5); // emerald-50 (Verde Suave)
  static const Color emerald = Color(0xFF10B981); // emerald-500
  static const Color orange = Color(0xFFF97316); // orange-500
  static const Color rose = Color(0xFFF43F5E); // rose-500
  static const Color blue = Color(0xFF3B82F6); // blue-500
  static const Color violet = Color(0xFF0D9488); // teal-600 (Verde-Azulado Secundário)
  static const Color cyan = Color(0xFF06B6D4); // cyan-500
  static const Color amber = Color(0xFFF59E0B); // amber-500
}

/// Formatador estilo Nubank / Bancos Brasileiros:
/// Digita da direita para a esquerda em centavos:
/// '' -> '0,00' -> digita '5' -> '0,05' -> digita '0' -> '0,50' -> digita '0' -> '5,00' -> '1.250,00'
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

  static String compactCurrency(double value, {bool discreet = false}) {
    if (discreet) return 'R\$ •••';
    if (value.abs() >= 1000000) {
      return 'R\$ ${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 10000) {
      return 'R\$ ${(value / 1000).toStringAsFixed(1)}k';
    }
    return _currency.format(value);
  }
}

/// Cabeçalho de seção estilo Apple HIG (espelhado do SectionHeader do BioStats)
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(left: 14, right: 6, bottom: bottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Card agrupado estilo Apple HIG Inset Grouped Table
class HigGroupedCard extends StatelessWidget {
  final List<Widget> children;

  const HigGroupedCard({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Linha de formulário estilo Apple HIG (Ícone + Rótulo à esquerda, Controle/Valor à direita)
class HigFormRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const HigFormRow({
    super.key,
    required this.icon,
    this.iconColor = AppColors.indigoPrimary,
    required this.label,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1.0,
              child: trailing,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, child: content);
    }
    return content;
  }
}

/// Campo de Valor Monetário Hero estilo Nubank + QuickWeightDialog do BioStats
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
    this.accentColor = AppColors.indigoPrimary,
    this.autofocus = false,
    this.onChanged,
    this.bottomAccessory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
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
                      fontSize: 40,
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
            const SizedBox(height: 12),
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
      primaryColor: AppColors.indigoPrimary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.indigoPrimary,
        secondary: AppColors.indigoLight,
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
        primaryColor: AppColors.indigoPrimary,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.indigoLight,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.indigoLight,
        secondary: AppColors.indigoPrimary,
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
        primaryColor: AppColors.indigoLight,
        brightness: Brightness.dark,
      ),
    );
  }
}
