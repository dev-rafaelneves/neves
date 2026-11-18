import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../transaction_form_sheet.dart';
import '../unified_import_screen.dart';

class SummaryTab extends StatelessWidget {
  final AppState appState;

  const SummaryTab({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final ym = appState.selectedYearMonth;
    final discreet = appState.discreetMode;

    final income = appState.monthIncome(ym);
    final cashExpense = appState.monthCashExpense(ym);
    final cardExpense = appState.monthCardExpense(ym);
    final totalExpense = cashExpense + cardExpense;
    final balance = income - totalExpense;

    final cards = appState.cards;
    final catBreakdown = appState.expensesByCategory(ym);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        120,
      ),
      children: [
        // 1. Hero Header: Quanto Sobra no Mês + Composição 2x2 estilo Copilot Money / Apple Wallet
        _BalanceHeader(
          yearMonth: ym,
          balance: balance,
          income: income,
          totalExpense: totalExpense,
          cashExpense: cashExpense,
          cardExpense: cardExpense,
          discreet: discreet,
          onTapIncome: () {
            HapticFeedback.lightImpact();
            appState.setActiveTab(1, filter: 'income');
          },
          onTapTotalExpense: () {
            HapticFeedback.lightImpact();
            appState.setActiveTab(1, filter: null);
          },
          onTapCashExpense: () {
            HapticFeedback.lightImpact();
            appState.setActiveTab(1, filter: 'cash');
          },
          onTapCardExpense: cards.isNotEmpty
              ? () {
                  HapticFeedback.lightImpact();
                  appState.setActiveTab(1, filter: 'card:${cards.first.id}');
                }
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),

        // 2. Ações Rápidas Minimalistas (Gasto, Receita, Importar)
        _QuickActionsBar(
          onNewExpense: () {
            HapticFeedback.lightImpact();
            TransactionFormSheet.show(
              context,
              appState: appState,
              initialType: TransactionType.expense,
            );
          },
          onNewIncome: () {
            HapticFeedback.lightImpact();
            TransactionFormSheet.show(
              context,
              appState: appState,
              initialType: TransactionType.income,
            );
          },
          onImport: () {
            HapticFeedback.lightImpact();
            UnifiedImportScreen.open(
              context,
              appState: appState,
            );
          },
        ),
        const SizedBox(height: AppSpacing.xxl),

        // 3. Faturas de Cartão de Crédito do Mês (Inset Grouped)
        HigSectionHeader(
          title: 'Faturas do Mês',
          trailing: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: Size.zero,
            onPressed: () {
              HapticFeedback.lightImpact();
              appState.setActiveTab(2);
            },
            child: const Text(
              'Gerenciar Cartões',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.iosBlue,
              ),
            ),
          ),
        ),
        if (cards.isEmpty)
          HigGroupedCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                'Nenhum cartão cadastrado.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          )
        else
          HigGroupedCard(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: AppSpacing.hairlineBorder,
                    indent: 58,
                    color: AppColors.border(context),
                  ),
                _CardInvoiceRow(
                  card: cards[i],
                  invoiceTotal: appState.cardInvoiceTotal(cards[i].id, ym),
                  paidTotal: appState.cardPaidAmount(cards[i].id, ym),
                  remainingTotal:
                      appState.cardRemainingInvoiceAmount(cards[i].id, ym),
                  isPaid: appState.isCardInvoicePaid(cards[i].id, ym),
                  ownTotal: appState.cardOwnExpenseTotal(cards[i].id, ym),
                  ignoredTotal:
                      appState.cardIgnoredExpenseTotal(cards[i].id, ym),
                  itemCount: appState.cardInvoiceCount(cards[i].id, ym),
                  discreet: discreet,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    appState.setActiveTab(1, filter: 'card:${cards[i].id}');
                  },
                ),
              ],
            ],
          ),
        const SizedBox(height: AppSpacing.xxl),

        // 4. Gastos por Categoria & Tetos Mensais (Inset Grouped)
        HigSectionHeader(
          title: 'Gastos por Categoria & Tetos',
          trailing: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: Size.zero,
            onPressed: () {
              HapticFeedback.lightImpact();
              appState.setActiveTab(3);
            },
            child: const Text(
              'Definir Tetos',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.iosBlue,
              ),
            ),
          ),
        ),
        if (appState.totalPlannedCategoryBudget() > 0) ...[
          _PlannedBudgetBanner(
            spentInBudgeted: appState.totalSpentInBudgetedCategories(ym),
            totalPlanned: appState.totalPlannedCategoryBudget(),
            discreet: discreet,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (catBreakdown.isEmpty)
          HigGroupedCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            children: [
              Column(
                children: [
                  const HigIconSquircle(
                    icon: CupertinoIcons.chart_pie_fill,
                    color: AppColors.iosBlue,
                    size: 44,
                    iconSize: 22,
                    radius: 13,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhuma despesa ou teto registrado neste mês.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.iosBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      appState.setActiveTab(3);
                    },
                    child: const Text(
                      'Definir Teto de Categoria',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.iosBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          HigGroupedCard(
            children: [
              for (int i = 0; i < catBreakdown.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: AppSpacing.hairlineBorder,
                    indent: 58,
                    color: AppColors.border(context),
                  ),
                _CategorySummaryRow(
                  item: catBreakdown[i],
                  discreet: discreet,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    appState.setActiveTab(3);
                  },
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// 1. Cabeçalho Hero do Saldo Líquido + Matriz 2x2 de Composição Mensal
class _BalanceHeader extends StatelessWidget {
  final String yearMonth;
  final double balance;
  final double income;
  final double totalExpense;
  final double cashExpense;
  final double cardExpense;
  final bool discreet;
  final VoidCallback onTapIncome;
  final VoidCallback onTapTotalExpense;
  final VoidCallback onTapCashExpense;
  final VoidCallback? onTapCardExpense;

  const _BalanceHeader({
    required this.yearMonth,
    required this.balance,
    required this.income,
    required this.totalExpense,
    required this.cashExpense,
    required this.cardExpense,
    required this.discreet,
    required this.onTapIncome,
    required this.onTapTotalExpense,
    required this.onTapCashExpense,
    required this.onTapCardExpense,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    final balanceColor =
        isPositive ? AppColors.success(context) : AppColors.danger(context);

    return HigGroupedCard(
      borderRadius: AppSpacing.heroRadius,
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'QUANTO SOBRA NO MÊS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: balanceColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive
                        ? CupertinoIcons.checkmark_alt_circle_fill
                        : CupertinoIcons.exclamationmark_circle_fill,
                    size: 13,
                    color: balanceColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPositive ? 'No azul' : 'No vermelho',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: balanceColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Valor do saldo principal em destaque absoluto com tabularFigures
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              AppFormatters.currency(balance, discreet: discreet),
              key: ValueKey<String>('${yearMonth}_${discreet}_$balance'),
              style: AppTypography.heroBalance(context, balanceColor),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Entradas menos saídas de ${AppFormatters.monthLabel(yearMonth, short: true)} (exclui itens ignorados)',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 18),
        Divider(
          height: 1,
          thickness: AppSpacing.hairlineBorder,
          color: AppColors.border(context),
        ),
        const SizedBox(height: 16),

        // Linha 1: Entradas vs Total de Saídas
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Entradas',
                value: AppFormatters.currency(income, discreet: discreet),
                icon: CupertinoIcons.arrow_down_left,
                color: AppColors.iosGreen,
                onTap: onTapIncome,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Total de Saídas',
                value: AppFormatters.currency(
                  totalExpense,
                  discreet: discreet,
                ),
                icon: CupertinoIcons.arrow_up_right,
                color: AppColors.iosRed,
                onTap: onTapTotalExpense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Linha 2: Composição das Saídas (Conta Corrente vs Faturas de Cartão)
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Conta Corrente',
                value: AppFormatters.currency(
                  cashExpense,
                  discreet: discreet,
                ),
                icon: CupertinoIcons.building_2_fill,
                color: AppColors.iosBlue,
                onTap: onTapCashExpense,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Faturas de Cartão',
                value: AppFormatters.currency(
                  cardExpense,
                  discreet: discreet,
                ),
                icon: CupertinoIcons.creditcard_fill,
                color: AppColors.iosIndigo,
                onTap: onTapCardExpense,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSecondarySurface.withValues(alpha: 0.45)
              : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border(context),
            width: AppSpacing.hairlineBorder,
          ),
        ),
        child: Row(
          children: [
            HigIconSquircle(
              icon: icon,
              color: color,
              size: 32,
              iconSize: 16,
              radius: 9,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.metricValue(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. Barra de Ações Rápidas estilo Apple Wallet / Revolut
class _QuickActionsBar extends StatelessWidget {
  final VoidCallback onNewExpense;
  final VoidCallback onNewIncome;
  final VoidCallback onImport;

  const _QuickActionsBar({
    required this.onNewExpense,
    required this.onNewIncome,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionPillButton(
            label: 'Gasto',
            icon: CupertinoIcons.minus_circle_fill,
            color: AppColors.iosRed,
            onTap: onNewExpense,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionPillButton(
            label: 'Receita',
            icon: CupertinoIcons.plus_circle_fill,
            color: AppColors.iosGreen,
            onTap: onNewIncome,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionPillButton(
            label: 'Importar',
            icon: CupertinoIcons.tray_arrow_down_fill,
            color: AppColors.iosBlue,
            onTap: onImport,
          ),
        ),
      ],
    );
  }
}

class _QuickActionPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionPillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border(context),
            width: AppSpacing.hairlineBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HigIconSquircle(
              icon: icon,
              color: color,
              size: 28,
              iconSize: 15,
              radius: 8,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3. Linha de Fatura de Cartão de Crédito estilo Apple Wallet
class _CardInvoiceRow extends StatelessWidget {
  final CreditCardItem card;
  final double invoiceTotal;
  final double paidTotal;
  final double remainingTotal;
  final bool isPaid;
  final double ownTotal;
  final double ignoredTotal;
  final int itemCount;
  final bool discreet;
  final VoidCallback onTap;

  const _CardInvoiceRow({
    required this.card,
    required this.invoiceTotal,
    required this.paidTotal,
    required this.remainingTotal,
    required this.isPaid,
    required this.ownTotal,
    required this.ignoredTotal,
    required this.itemCount,
    required this.discreet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasIgnored = ignoredTotal.abs() > 0.005;
    final hasPaid = paidTotal > 0.005;

    final amountColor = isPaid
        ? AppColors.success(context)
        : (remainingTotal > 0
            ? AppColors.danger(context)
            : AppColors.textSecondary(context));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                HigIconSquircle(
                  icon: CupertinoIcons.creditcard_fill,
                  color: card.color,
                  size: 36,
                  iconSize: 18,
                  radius: 10,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isPaid
                      ? 'Fatura Paga'
                      : AppFormatters.currency(
                          remainingTotal,
                          discreet: discreet,
                        ),
                  style: AppTypography.listAmount(context, amountColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Vence dia ${card.dueDay} • $itemCount ${itemCount == 1 ? 'compra' : 'compras'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.captionTabular(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver fatura',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: card.color,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 12,
                        color: card.color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasPaid || hasIgnored) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (hasPaid) ...[
                      HigInfoPill(
                        icon: CupertinoIcons.bag_fill,
                        text:
                            'Compras: ${AppFormatters.currency(invoiceTotal, discreet: discreet)}',
                        color: AppColors.textSecondary(context),
                      ),
                      HigInfoPill(
                        icon: CupertinoIcons.checkmark_circle_fill,
                        text:
                            'Pago/Antecipado: ${AppFormatters.currency(paidTotal, discreet: discreet)}',
                        color: AppColors.success(context),
                      ),
                    ],
                    if (hasIgnored) ...[
                      HigInfoPill(
                        icon: CupertinoIcons.person_fill,
                        text:
                            'Seus gastos: ${AppFormatters.currency(ownTotal, discreet: discreet)}',
                        color: AppColors.iosGreen,
                      ),
                      HigInfoPill(
                        icon: CupertinoIcons.eye_slash_fill,
                        text:
                            'Ignorados: ${AppFormatters.currency(ignoredTotal, discreet: discreet)}',
                        color: AppColors.iosOrange,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 4. Resumo Geral dos Tetos Planejados
class _PlannedBudgetBanner extends StatelessWidget {
  final double spentInBudgeted;
  final double totalPlanned;
  final bool discreet;

  const _PlannedBudgetBanner({
    required this.spentInBudgeted,
    required this.totalPlanned,
    required this.discreet,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalPlanned > 0
        ? (spentInBudgeted / totalPlanned).clamp(0.0, 1.0)
        : 0.0;
    final diff = totalPlanned - spentInBudgeted;
    final isOver = diff < -0.005;
    final isWarn = !isOver && ratio >= 0.80;

    final Color statusColor = isOver
        ? AppColors.danger(context)
        : (isWarn ? AppColors.warning(context) : AppColors.success(context));

    return HigGroupedCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Total nas Categorias com Teto',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${AppFormatters.currency(spentInBudgeted, discreet: discreet)} / ${AppFormatters.currency(totalPlanned, discreet: discreet)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        HigAnimatedProgressBar(
          value: ratio,
          color: statusColor,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            isOver
                ? 'Acima do planejado em ${AppFormatters.currency(diff.abs(), discreet: discreet)}'
                : 'Disponível nos tetos: ${AppFormatters.currency(diff, discreet: discreet)}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: statusColor,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ),
      ],
    );
  }
}

/// 5. Linha de Categoria & Barra de Teto estilo Copilot Money
class _CategorySummaryRow extends StatelessWidget {
  final CategoryExpenseSummary item;
  final bool discreet;
  final VoidCallback onTap;

  const _CategorySummaryRow({
    required this.item,
    required this.discreet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = item.hasBudget;
    final pctOfExpenses = (item.percentage * 100).round();
    final budgetPct = item.rawBudgetPercent.round();

    final Color barColor;
    final String subtitleText;
    if (hasBudget) {
      if (item.isOverBudget) {
        barColor = AppColors.danger(context);
        subtitleText =
            'Estourou ${AppFormatters.currency(item.remainingBudget.abs(), discreet: discreet)} ($budgetPct% do teto)';
      } else if (item.isWarningBudget) {
        barColor = AppColors.warning(context);
        subtitleText =
            'Atenção • Disponível: ${AppFormatters.currency(item.remainingBudget, discreet: discreet)} ($budgetPct%)';
      } else {
        barColor = AppColors.success(context);
        subtitleText =
            'Disponível: ${AppFormatters.currency(item.remainingBudget, discreet: discreet)} ($budgetPct% do teto)';
      }
    } else {
      barColor = item.category.color;
      subtitleText =
          '${item.count} ${item.count == 1 ? 'lançamento' : 'lançamentos'} • $pctOfExpenses% das saídas • Definir teto';
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          children: [
            Row(
              children: [
                HigIconSquircle(
                  icon: item.category.icon,
                  color: item.category.color,
                  size: 36,
                  iconSize: 18,
                  radius: 10,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.category.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              hasBudget ? FontWeight.w600 : FontWeight.w500,
                          color: hasBudget
                              ? barColor
                              : AppColors.textSecondary(context),
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppFormatters.currency(item.amount, discreet: discreet),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: hasBudget && item.isOverBudget
                            ? AppColors.danger(context)
                            : AppColors.textPrimary(context),
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                    if (hasBudget)
                      Text(
                        'de ${AppFormatters.currency(item.budget, discreet: discreet)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary(context),
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            HigAnimatedProgressBar(
              value: hasBudget ? item.budgetRatio : item.percentage,
              color: barColor,
            ),
          ],
        ),
      ),
    );
  }
}
