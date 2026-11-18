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

    final isPositive = balance >= 0;
    final balanceColor =
        isPositive ? AppColors.success(context) : AppColors.danger(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Card Principal: Quanto Sobra no Mês + Matemática Transparente
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.border(context),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
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
                    child: Text(
                      isPositive ? 'No azul' : 'No vermelho',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: balanceColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Hero Value com FittedBox e AnimatedSwitcher para zero overflow e fluidez
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    AppFormatters.currency(balance, discreet: discreet),
                    key: ValueKey<String>('${ym}_${discreet}_$balance'),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      color: balanceColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Entradas menos saídas de ${AppFormatters.monthLabel(ym, short: true)} (exclui itens ignorados)',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Linha 1: Entradas vs Total de Saídas
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Entradas',
                      value: AppFormatters.currency(income, discreet: discreet),
                      icon: Icons.arrow_downward_rounded,
                      color: AppColors.success(context),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        appState.setActiveTab(1, filter: 'income');
                      },
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
                      icon: Icons.arrow_upward_rounded,
                      color: AppColors.danger(context),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        appState.setActiveTab(1, filter: null);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Linha 2: Composição das Saídas (Conta Corrente vs Faturas do Mês)
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Conta Corrente',
                      value: AppFormatters.currency(
                        cashExpense,
                        discreet: discreet,
                      ),
                      icon: Icons.account_balance_rounded,
                      color: AppColors.blue,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        appState.setActiveTab(1, filter: 'cash');
                      },
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
                      icon: Icons.credit_card_rounded,
                      color: AppColors.purple,
                      onTap: cards.isNotEmpty
                          ? () {
                              HapticFeedback.selectionClick();
                              appState.setActiveTab(
                                1,
                                filter: 'card:${cards.first.id}',
                              );
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Ações Rápidas (Ergonomia 48dp + FittedBox contra quebra em 360dp)
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => TransactionFormSheet.show(
                  context,
                  appState: appState,
                  initialType: TransactionType.expense,
                ),
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Gasto',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => TransactionFormSheet.show(
                  context,
                  appState: appState,
                  initialType: TransactionType.income,
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Receita',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => UnifiedImportScreen.open(
                  context,
                  appState: appState,
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Importar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // Faturas de Cartão de Crédito do Mês
        HigSectionHeader(
          title: 'Faturas do Mês',
          trailing: TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => appState.setActiveTab(2),
            child: const Text(
              'Gerenciar Cartões',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (cards.isEmpty)
          HigGroupedCard(
            padding: const EdgeInsets.all(18),
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
                if (i > 0) const Divider(height: 1),
                _CardInvoiceRow(
                  card: cards[i],
                  invoiceTotal: appState.cardInvoiceTotal(cards[i].id, ym),
                  ownTotal: appState.cardOwnExpenseTotal(cards[i].id, ym),
                  ignoredTotal:
                      appState.cardIgnoredExpenseTotal(cards[i].id, ym),
                  itemCount: appState.cardInvoiceCount(cards[i].id, ym),
                  discreet: discreet,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    appState.setActiveTab(1, filter: 'card:${cards[i].id}');
                  },
                ),
              ],
            ],
          ),
        const SizedBox(height: 22),

        // Gastos por Categoria & Tetos Mensais
        HigSectionHeader(
          title: 'Gastos por Categoria & Tetos',
          trailing: TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => _showQuickBudgetListModal(context, appState),
            child: const Text(
              'Definir Tetos',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (appState.totalPlannedCategoryBudget() > 0) ...[
          _PlannedBudgetBanner(
            spentInBudgeted: appState.totalSpentInBudgetedCategories(ym),
            totalPlanned: appState.totalPlannedCategoryBudget(),
            discreet: discreet,
          ),
          const SizedBox(height: 10),
        ],
        if (catBreakdown.isEmpty)
          HigGroupedCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            children: [
              Column(
                children: [
                  Icon(
                    Icons.pie_chart_outline_rounded,
                    size: 36,
                    color: AppColors.textSecondary(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhuma despesa ou teto registrado neste mês.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showQuickBudgetListModal(context, appState),
                    icon: const Icon(Icons.tune_rounded, size: 17),
                    label: const Text('Definir Teto de Categoria'),
                  ),
                ],
              ),
            ],
          )
        else
          HigGroupedCard(
            children: [
              for (int i = 0; i < catBreakdown.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _CategorySummaryRow(
                  item: catBreakdown[i],
                  discreet: discreet,
                  onTap: () => _CategoryBudgetAndDetailsSheet.show(
                    context,
                    appState: appState,
                    category: catBreakdown[i].category,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  static Future<void> _showQuickBudgetListModal(
    BuildContext context,
    AppState appState,
  ) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final expCats =
                appState.categoriesByType(TransactionType.expense);
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tetos Mensais por Categoria',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toque em uma categoria para definir ou alterar seu limite mensal',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: expCats.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final cat = expCats[i];
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            onTap: () => _CategoryBudgetAndDetailsSheet.show(
                              context,
                              appState: appState,
                              category: cat,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                cat.icon,
                                color: cat.color,
                                size: 19,
                              ),
                            ),
                            title: Text(
                              cat.name,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: Text(
                              cat.hasBudget
                                  ? AppFormatters.currency(cat.monthlyBudget)
                                  : 'Sem teto →',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: cat.hasBudget
                                    ? AppColors.primary
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border(context),
            width: 0.7,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
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
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
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

class _CardInvoiceRow extends StatelessWidget {
  final CreditCardItem card;
  final double invoiceTotal;
  final double ownTotal;
  final double ignoredTotal;
  final int itemCount;
  final bool discreet;
  final VoidCallback onTap;

  const _CardInvoiceRow({
    required this.card,
    required this.invoiceTotal,
    required this.ownTotal,
    required this.ignoredTotal,
    required this.itemCount,
    required this.discreet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasIgnored = ignoredTotal.abs() > 0.005;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Linha 1: Ícone + Nome do Cartão à esquerda | Valor Total à direita
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: card.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.credit_card_rounded,
                    color: card.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  AppFormatters.currency(invoiceTotal, discreet: discreet),
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: invoiceTotal > 0
                        ? AppColors.danger(context)
                        : AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Linha 2: Vencimento + Quantidade de compras à esquerda | Ver fatura à direita
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Vence dia ${card.dueDay} • $itemCount ${itemCount == 1 ? 'compra' : 'compras'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ver fatura →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: card.color,
                    ),
                  ),
                ],
              ),
            ),

            if (hasIgnored) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    HigInfoPill(
                      icon: Icons.person_outline_rounded,
                      text:
                          'Seus gastos: ${AppFormatters.currency(ownTotal, discreet: discreet)}',
                      color: AppColors.primary,
                    ),
                    HigInfoPill(
                      icon: Icons.visibility_off_outlined,
                      text:
                          'Ignorados: ${AppFormatters.currency(ignoredTotal, discreet: discreet)}',
                      color: AppColors.orange,
                    ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border(context),
          width: 0.8,
        ),
      ),
      child: Column(
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
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${AppFormatters.currency(spentInBudgeted, discreet: discreet)} / ${AppFormatters.currency(totalPlanned, discreet: discreet)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
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
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: item.category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    item.category.icon,
                    color: item.category.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.category.name,
                        style: TextStyle(
                          fontSize: 14.5,
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
                              hasBudget ? FontWeight.w700 : FontWeight.w500,
                          color: hasBudget
                              ? barColor
                              : AppColors.textSecondary(context),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: hasBudget && item.isOverBudget
                            ? AppColors.danger(context)
                            : AppColors.textPrimary(context),
                      ),
                    ),
                    if (hasBudget)
                      Text(
                        'de ${AppFormatters.currency(item.budget, discreet: discreet)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(context),
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

class _CategoryBudgetAndDetailsSheet extends StatefulWidget {
  final AppState appState;
  final CategoryItem category;

  const _CategoryBudgetAndDetailsSheet({
    required this.appState,
    required this.category,
  });

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    required CategoryItem category,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryBudgetAndDetailsSheet(
        appState: appState,
        category: category,
      ),
    );
  }

  @override
  State<_CategoryBudgetAndDetailsSheet> createState() =>
      _CategoryBudgetAndDetailsSheetState();
}

class _CategoryBudgetAndDetailsSheetState
    extends State<_CategoryBudgetAndDetailsSheet> {
  late final TextEditingController _budgetCtrl;

  @override
  void initState() {
    super.initState();
    final currentCat = widget.appState.categoryById(widget.category.id);
    _budgetCtrl = TextEditingController(
      text: currentCat.hasBudget
          ? CentavosCurrencyFormatter.formatDouble(currentCat.monthlyBudget)
          : '',
    );
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    final val = CentavosCurrencyFormatter.parseValue(_budgetCtrl.text);
    await widget.appState.updateCategoryBudget(widget.category.id, val);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clearBudget() async {
    await widget.appState.updateCategoryBudget(widget.category.id, 0.0);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final ym = widget.appState.selectedYearMonth;
    final currentCat = widget.appState.categoryById(widget.category.id);
    final txs =
        widget.appState.transactionsForCategoryInMonth(currentCat.id, ym);

    double totalSpent = 0.0;
    for (final t in txs) {
      totalSpent += t.amount;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(18, 14, 18, 20 + inset),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: currentCat.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      currentCat.icon,
                      color: currentCat.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentCat.name,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Gasto em ${AppFormatters.monthLabel(ym, short: true)}: ${AppFormatters.currency(totalSpent)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (currentCat.hasBudget)
                    TextButton(
                      onPressed: _clearBudget,
                      child: Text(
                        'Remover teto',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.danger(context),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Campo Hero de Teto Mensal
              HigCurrencyHeroField(
                controller: _budgetCtrl,
                label: 'Teto Mensal da Categoria (Opcional)',
                accentColor: currentCat.color,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saveBudget,
                  child: const Text(
                    'Salvar Teto Mensal',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              if (txs.isNotEmpty) ...[
                const SizedBox(height: 18),
                HigSectionHeader(
                  title: 'Lançamentos do Mês (${txs.length})',
                ),
                for (final tx in txs)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    dense: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      TransactionFormSheet.show(
                        context,
                        appState: widget.appState,
                        existing: tx,
                      );
                    },
                    title: Text(
                      tx.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${AppFormatters.shortDate(tx.date)} • ${tx.paymentMethod == PaymentMethod.creditCard ? (widget.appState.cardById(tx.cardId)?.name ?? 'Cartão') : 'Conta Corrente'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    trailing: Text(
                      AppFormatters.currency(tx.amount),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger(context),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
