import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Design Tokens oficiais inspirados no Apple Human Interface Guidelines (HIG),
/// Apple Wallet, Copilot Money e Revolut.
class AppColors {
  // Light Mode (iOS System Grouped Background)
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSecondarySurface = Color(0xFFF2F2F7);
  static const Color lightBorder = Color(0xFFE5E5EA);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF8E8E93);

  // Dark Mode (OLED Pure Black + Secondary System Background)
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSecondarySurface = Color(0xFF2C2C2E);
  static const Color darkBorder = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93);

  // Cores Semânticas Financeiras (Padrão iOS HIG)
  static const Color iosGreen = Color(0xFF34C759); // Receitas / Positivo
  static const Color iosRed = Color(0xFFFF3B30); // Despesas / Estouro
  static const Color iosBlue = Color(0xFF007AFF); // Destaque (Royal Blue)
  static const Color iosIndigo = Color(0xFF5856D6); // Índigo / Cartões
  static const Color iosOrange = Color(0xFFFF9500); // Alerta 80% / Ignorados
  static const Color iosTeal = Color(0xFF30B0C7);
  static const Color iosAmber = Color(0xFFFFCC00);

  // Tokens semânticos compatíveis com toda a aplicação
  static const Color primary = iosGreen;
  static const Color primaryLight = Color(0xFF30D158);
  static const Color primarySoft = Color(0xFFE8F8ED);
  static const Color emerald = iosGreen;
  static const Color orange = iosOrange;
  static const Color rose = iosRed;
  static const Color blue = iosBlue;
  static const Color purple = iosIndigo;
  static const Color cyan = iosTeal;
  static const Color amber = iosAmber;
  static const Color indigo = iosIndigo;

  static const List<Color> presetPalette = [
    Color(0xFF5856D6), // Índigo (iOS)
    Color(0xFFFF9500), // Laranja (iOS)
    Color(0xFF007AFF), // Azul Royal (iOS)
    Color(0xFF34C759), // Verde (iOS)
    Color(0xFFFF3B30), // Vermelho (iOS)
    Color(0xFF30B0C7), // Ciano (iOS)
    Color(0xFFAF52DE), // Roxo (iOS)
    Color(0xFF636366), // Grafite (iOS)
  ];

  // Contraste calibrado para Light e Dark OLED
  static const Color successStrong = Color(0xFF248A3D);
  static const Color dangerStrong = Color(0xFFD70015);
  static const Color warningStrong = Color(0xFFC93400);

  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  static Color background(BuildContext c) =>
      isDark(c) ? darkBackground : lightBackground;
  static Color surface(BuildContext c) =>
      isDark(c) ? darkSurface : lightSurface;
  static Color secondarySurface(BuildContext c) =>
      isDark(c) ? darkSecondarySurface : lightSecondarySurface;
  static Color border(BuildContext c) => isDark(c) ? darkBorder : lightBorder;
  static Color textPrimary(BuildContext c) =>
      isDark(c) ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(BuildContext c) =>
      isDark(c) ? darkTextSecondary : lightTextSecondary;

  static Color success(BuildContext c) => isDark(c) ? iosGreen : iosGreen;
  static Color danger(BuildContext c) => isDark(c) ? iosRed : iosRed;
  static Color warning(BuildContext c) => isDark(c) ? iosOrange : warningStrong;
  static Color accent(BuildContext c) => iosBlue;
}

/// Espaçamentos e Raios padronizados (Apple HIG Inset Grouped)
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 28.0;

  static const double cardRadius = 18.0;
  static const double heroRadius = 20.0;
  static const double squircleRadius = 10.0;
  static const double hairlineBorder = 0.5;
}

/// Tipografia Financeira com `FontFeature.tabularFigures()` obrigatório para números
class AppTypography {
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextStyle heroBalance(BuildContext context, Color color) => TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: color,
        fontFeatures: tabular,
      );

  static TextStyle metricValue(BuildContext context, {Color? color}) =>
      TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color ?? AppColors.textPrimary(context),
        fontFeatures: tabular,
      );

  static TextStyle listAmount(BuildContext context, Color color) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color,
        fontFeatures: tabular,
      );

  static TextStyle captionTabular(BuildContext context, {Color? color}) =>
      TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textSecondary(context),
        fontFeatures: tabular,
      );
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

/// Container de ícone estilo SF Symbols em squircle com 12% de opacidade.
class HigIconSquircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  const HigIconSquircle({
    super.key,
    required this.icon,
    required this.color,
    this.size = 34,
    this.iconSize = 18,
    this.radius = AppSpacing.squircleRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: color,
      ),
    );
  }
}

/// Superfície translúcida com efeito de vidro fosco (Frosted Glass iOS).
class HigFrostedSurface extends StatelessWidget {
  final Widget child;
  final Border? border;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const HigFrostedSurface({
    super.key,
    required this.child,
    this.border,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bgColor = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.82)
        : AppColors.lightSurface.withValues(alpha: 0.85);

    Widget content = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: borderRadius,
          border: border,
        ),
        child: child,
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }
    return ClipRect(child: content);
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
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Bloco agrupado estilo `CupertinoListSection.insetGrouped` sem sombras pesadas
/// e com borda hairline de 0.5px.
class HigGroupedCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const HigGroupedCard({
    super.key,
    required this.children,
    this.padding,
    this.borderRadius = AppSpacing.cardRadius,
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(
          color: AppColors.border(context),
          width: AppSpacing.hairlineBorder,
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
        borderRadius: BorderRadius.circular(AppSpacing.heroRadius),
        border: Border.all(
          color: AppColors.border(context),
          width: AppSpacing.hairlineBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
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
                  fontFeatures: AppTypography.tabular,
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
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: accentColor,
                      fontFeatures: AppTypography.tabular,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0,00',
                      hintStyle: TextStyle(
                        color: accentColor.withValues(alpha: 0.35),
                        fontFeatures: AppTypography.tabular,
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

/// Barra de progresso com microinteração suave (Apple HIG) para tetos e categorias.
class HigAnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double minHeight;

  const HigAnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.minHeight = 6,
  });

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: target),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: animatedValue,
            minHeight: minHeight,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
      },
    );
  }
}

/// Pílula semântica à prova de overflow com `tabularFigures` para valores financeiros.
class HigInfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const HigInfoPill({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ),
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
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.iosBlue,
      colorScheme: const ColorScheme.light(
        primary: AppColors.iosBlue,
        secondary: AppColors.iosIndigo,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.iosRed,
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
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: -0.2,
            color:
                isSelected ? AppColors.iosBlue : AppColors.lightTextSecondary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(
            color: AppColors.lightBorder,
            width: AppSpacing.hairlineBorder,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: AppSpacing.hairlineBorder,
        space: 1,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: AppColors.iosBlue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBackground,
        barBackgroundColor: Color(0xD9F2F2F7),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.iosBlue,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.iosBlue,
        secondary: AppColors.iosIndigo,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.iosRed,
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
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: -0.2,
            color: isSelected ? AppColors.iosBlue : AppColors.darkTextSecondary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(
            color: AppColors.darkBorder,
            width: AppSpacing.hairlineBorder,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: AppSpacing.hairlineBorder,
        space: 1,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: AppColors.iosBlue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        barBackgroundColor: Color(0xD91C1C1E),
      ),
    );
  }
}
