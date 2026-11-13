import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/models.dart';
import '../../../services/app_state.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/ai_insight_card.dart';

class DashboardOverviewSection extends StatelessWidget {
  final AppState appState;
  final bool isWide;
  final bool showAllCategories;
  final VoidCallback onToggleShowAllCategories;
  final ValueChanged<CategoryModel>? onOpenCategoryStatement;

  const DashboardOverviewSection({
    super.key,
    required this.appState,
    required this.isWide,
    required this.showAllCategories,
    required this.onToggleShowAllCategories,
    this.onOpenCategoryStatement,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ym = appState.selectedYearMonth;
    final discreet = appState.discreetMode;

    final income = appState.totalIncomeForMonth(ym);
    final expense = appState.totalExpenseForMonth(ym);
    final projectedBalance = appState.projectedEndOfMonthBalance(ym);
    final savingsRate = income > 0 ? ((income - expense) / income * 100) : 0.0;
    final catBreakdown = appState.categoryExpenseBreakdown(ym);

    final heroCard = _buildHeroCard(
      context,
      income: income,
      expense: expense,
      projectedBalance: projectedBalance,
      savingsRate: savingsRate,
      discreet: discreet,
    );

    final categoryCard = _CategoryPieCard(
      isDark: isDark,
      ym: ym,
      expense: expense,
      discreet: discreet,
      catBreakdown: catBreakdown,
      showAllCategories: showAllCategories,
      onToggleShowAllCategories: onToggleShowAllCategories,
      onOpenCategoryStatement: onOpenCategoryStatement,
    );

    final aiCard = AiInsightCard(appState: appState);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                heroCard,
                const SizedBox(height: 16),
                aiCard,
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: categoryCard),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heroCard,
        const SizedBox(height: 16),
        categoryCard,
        const SizedBox(height: 16),
        aiCard,
      ],
    );
  }

  void _showHeroHelpDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Indicadores do Resumo',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo Disponível',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            SizedBox(height: 2),
            Text(
              'Soma do saldo atual das suas contas correntes, carteiras e poupanças.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              'Patrimônio',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            SizedBox(height: 2),
            Text(
              'Saldo líquido somado a investimentos e Caixinhas, descontando faturas de cartão em aberto.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              'Saldo Projetado no Fim do Mês',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            SizedBox(height: 2),
            Text(
              'Saldo disponível considerando receitas e despesas pendentes do mês.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required double income,
    required double expense,
    required double projectedBalance,
    required double savingsRate,
    required bool discreet,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF064E3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SALDO DISPONÍVEL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Patrimônio: ${AppFormatters.currency(appState.netWorth, discreet: discreet)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showHeroHelpDialog(context),
                child: Semantics(
                  button: true,
                  label: 'Entender indicadores do resumo',
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 18,
                      color: Color(0xE6FFFFFF),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Semantics(
            container: true,
            label: discreet
                ? 'Resumo financeiro em modo discreto'
                : 'Saldo disponível ${AppFormatters.currency(appState.liquidAccountsBalance)}, patrimônio ${AppFormatters.currency(appState.netWorth)}, saldo projetado ${AppFormatters.currency(projectedBalance)}, receitas ${AppFormatters.currency(income)}, despesas ${AppFormatters.currency(expense)}, poupança ${savingsRate.toStringAsFixed(0)} por cento',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    AppFormatters.currency(
                      appState.liquidAccountsBalance,
                      discreet: discreet,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saldo Projetado no Fim do Mês: ${AppFormatters.currency(projectedBalance, discreet: discreet)}',
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _HeroMetricColumn(
                            icon: Icons.arrow_upward_rounded,
                            iconColor: const Color(0xFF34D399),
                            label: 'Receitas',
                            value: AppFormatters.currency(
                              income,
                              discreet: discreet,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _HeroMetricColumn(
                            icon: Icons.arrow_downward_rounded,
                            iconColor: const Color(0xFFFB7185),
                            label: 'Despesas',
                            value: AppFormatters.currency(
                              expense,
                              discreet: discreet,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Poupança',
                              style: TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              discreet
                                  ? '••%'
                                  : '${savingsRate.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: savingsRate > 0
                                    ? const Color(0xFF34D399)
                                    : Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPieCard extends StatefulWidget {
  final bool isDark;
  final String ym;
  final double expense;
  final bool discreet;
  final Map<CategoryModel, double> catBreakdown;
  final bool showAllCategories;
  final VoidCallback onToggleShowAllCategories;
  final ValueChanged<CategoryModel>? onOpenCategoryStatement;

  const _CategoryPieCard({
    required this.isDark,
    required this.ym,
    required this.expense,
    required this.discreet,
    required this.catBreakdown,
    required this.showAllCategories,
    required this.onToggleShowAllCategories,
    this.onOpenCategoryStatement,
  });

  @override
  State<_CategoryPieCard> createState() => _CategoryPieCardState();
}

class _CategoryPieCardState extends State<_CategoryPieCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.catBreakdown.entries.toList();
    final safeTouched =
        (_touchedIndex >= 0 && _touchedIndex < entries.length) ? _touchedIndex : -1;
    final touchedEntry = safeTouched >= 0 ? entries[safeTouched] : null;
    final touchedPct = touchedEntry != null && widget.expense > 0
        ? (touchedEntry.value / widget.expense * 100)
        : 0.0;

    return Material(
      color: widget.isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Despesas por Categoria',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: widget.isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 14),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Nenhuma despesa registrada em ${AppFormatters.monthLabel(widget.ym)}.\nToque em "+ Lançar" para adicionar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: widget.discreet
                        ? 'Gráfico de despesas por categoria em modo discreto'
                        : 'Gráfico de despesas por categoria: ${entries.take(5).map((e) => '${e.key.name} ${(widget.expense > 0 ? e.value / widget.expense * 100 : 0).toStringAsFixed(0)} por cento').join(', ')}',
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: 134,
                        height: 134,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback: (event, response) {
                                    if (!event.isInterestedForInteractions ||
                                        response == null ||
                                        response.touchedSection == null) {
                                      return;
                                    }
                                    final idx = response
                                        .touchedSection!.touchedSectionIndex;
                                    if (idx != _touchedIndex) {
                                      HapticFeedback.selectionClick();
                                      setState(() => _touchedIndex = idx);
                                    }
                                  },
                                ),
                                centerSpaceRadius: 36,
                                sectionsSpace: 2,
                                sections: List.generate(entries.length, (i) {
                                  final e = entries[i];
                                  final isTouched = i == safeTouched;
                                  return PieChartSectionData(
                                    color: e.key.color,
                                    value: e.value,
                                    radius: isTouched ? 26 : 21,
                                    showTitle: false,
                                  );
                                }),
                              ),
                            ),
                            if (touchedEntry != null)
                              SizedBox(
                                width: 64,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.discreet
                                          ? '••%'
                                          : '${touchedPct.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: touchedEntry.key.color,
                                      ),
                                    ),
                                    Text(
                                      touchedEntry.key.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: widget.isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...(widget.showAllCategories
                                ? entries
                                : entries.take(5))
                            .map((e) {
                          final pct = widget.expense > 0
                              ? (e.value / widget.expense * 100)
                              : 0.0;
                          final isHighlighted =
                              touchedEntry?.key.id == e.key.id;
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onOpenCategoryStatement?.call(e.key);
                            },
                            child: Container(
                              decoration: isHighlighted
                                  ? BoxDecoration(
                                      color: e.key.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              padding: const EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: e.key.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      e.key.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isHighlighted
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.discreet
                                        ? '••%'
                                        : '${AppFormatters.compactCurrency(e.value)} (${pct.toStringAsFixed(0)}%)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (entries.length > 5)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: widget.onToggleShowAllCategories,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                              ),
                              child: Text(
                                widget.showAllCategories
                                    ? 'Mostrar menos'
                                    : 'Ver todas (${entries.length})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetricColumn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _HeroMetricColumn({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
