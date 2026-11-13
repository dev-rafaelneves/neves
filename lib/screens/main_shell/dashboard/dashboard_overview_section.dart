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
      income: income,
      expense: expense,
      projectedBalance: projectedBalance,
      savingsRate: savingsRate,
      discreet: discreet,
    );

    final categoryCard = _buildCategoryCard(
      context,
      isDark: isDark,
      ym: ym,
      expense: expense,
      discreet: discreet,
      catBreakdown: catBreakdown,
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

  Widget _buildHeroCard({
    required double income,
    required double expense,
    required double projectedBalance,
    required double savingsRate,
    required bool discreet,
  }) {
    return Semantics(
      container: true,
      label: discreet
          ? 'Resumo financeiro em modo discreto'
          : 'Saldo disponível ${AppFormatters.currency(appState.liquidAccountsBalance)}, patrimônio ${AppFormatters.currency(appState.netWorth)}, saldo projetado ${AppFormatters.currency(projectedBalance)}, receitas ${AppFormatters.currency(income)}, despesas ${AppFormatters.currency(expense)}, poupança ${savingsRate.toStringAsFixed(0)} por cento',
      child: ExcludeSemantics(
        child: Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                ],
              ),
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
                        value: AppFormatters.currency(income, discreet: discreet),
                      ),
                    ),
                    Expanded(
                      child: _HeroMetricColumn(
                        icon: Icons.arrow_downward_rounded,
                        iconColor: const Color(0xFFFB7185),
                        label: 'Despesas',
                        value: AppFormatters.currency(expense, discreet: discreet),
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
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required bool isDark,
    required String ym,
    required double expense,
    required bool discreet,
    required Map<CategoryModel, double> catBreakdown,
  }) {
    return Material(
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 14),
            if (catBreakdown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Nenhuma despesa registrada em ${AppFormatters.monthLabel(ym)}.\nToque em "+ Lançar" para adicionar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
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
                    label: discreet
                        ? 'Gráfico de despesas por categoria em modo discreto'
                        : 'Gráfico de despesas por categoria: ${catBreakdown.entries.take(5).map((e) => '${e.key.name} ${(expense > 0 ? e.value / expense * 100 : 0).toStringAsFixed(0)} por cento').join(', ')}',
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: 130,
                        height: 130,
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 36,
                            sectionsSpace: 2,
                            sections: catBreakdown.entries.map((e) {
                              final pct =
                                  expense > 0 ? (e.value / expense * 100) : 0.0;
                              return PieChartSectionData(
                                color: e.key.color,
                                value: e.value,
                                radius: 22,
                                showTitle: false,
                                badgeWidget: pct >= 15
                                    ? null
                                    : const SizedBox.shrink(),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...(showAllCategories
                                ? catBreakdown.entries
                                : catBreakdown.entries.take(5))
                            .map((e) {
                          final pct =
                              expense > 0 ? (e.value / expense * 100) : 0.0;
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onOpenCategoryStatement?.call(e.key);
                            },
                            child: Padding(
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
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    discreet
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
                        if (catBreakdown.length > 5)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: onToggleShowAllCategories,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                              ),
                              child: Text(
                                showAllCategories
                                    ? 'Mostrar menos'
                                    : 'Ver todas (${catBreakdown.length})',
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
