import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../transaction_form_sheet.dart';
import '../unified_import_screen.dart';
import 'cards_settings_tab.dart';

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
                  Text(
                    'QUANTO SOBRA NO MÊS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
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
              Text(
                AppFormatters.currency(balance, discreet: discreet),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  color: balanceColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Entradas menos gastos à vista e faturas de ${AppFormatters.monthLabel(ym, short: true)}',
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

              // Linha 2: Composição das Saídas (À Vista vs Faturas do Mês)
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Saídas à Vista (Pix)',
                      value: AppFormatters.currency(
                        cashExpense,
                        discreet: discreet,
                      ),
                      icon: Icons.bolt_rounded,
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

        // Ações Rápidas
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                label: const Text(
                  'Gasto',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                label: const Text(
                  'Receita',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => UnifiedImportScreen.open(
                  context,
                  appState: appState,
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text(
                  'Importar',
                  style: TextStyle(fontWeight: FontWeight.w700),
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
                  itemCount: appState.cardInvoiceCount(cards[i].id, ym),
                  discreet: discreet,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    appState.setActiveTab(1, filter: 'card:${cards[i].id}');
                  },
                  onQuickAdd: () => TransactionFormSheet.show(
                    context,
                    appState: appState,
                    initialType: TransactionType.expense,
                    initialCardId: cards[i].id,
                  ),
                  onEditCard: () => CardsSettingsTab.showCardModal(
                    context,
                    appState,
                    existing: cards[i],
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 22),

        // Gastos por Categoria no Mês
        const HigSectionHeader(title: 'Gastos por Categoria no Mês'),
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
                    'Nenhuma despesa registrada neste mês.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(context),
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
                if (i > 0) const Divider(height: 1),
                _CategorySummaryRow(
                  item: catBreakdown[i],
                  discreet: discreet,
                ),
              ],
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
  final int itemCount;
  final bool discreet;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;
  final VoidCallback onEditCard;

  const _CardInvoiceRow({
    required this.card,
    required this.invoiceTotal,
    required this.itemCount,
    required this.discreet,
    required this.onTap,
    required this.onQuickAdd,
    required this.onEditCard,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: card.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.credit_card_rounded,
                color: card.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fecha dia ${card.closingDay} • Vence dia ${card.dueDay} • $itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatters.currency(invoiceTotal, discreet: discreet),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: invoiceTotal > 0
                        ? AppColors.danger(context)
                        : AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ver fatura →',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: card.color,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Editar cartão',
              visualDensity: VisualDensity.compact,
              onPressed: onEditCard,
              icon: Icon(
                Icons.edit_outlined,
                color: AppColors.textSecondary(context),
                size: 20,
              ),
            ),
            IconButton(
              tooltip: 'Lançar neste cartão',
              visualDensity: VisualDensity.compact,
              onPressed: onQuickAdd,
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: card.color,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySummaryRow extends StatelessWidget {
  final CategoryExpenseSummary item;
  final bool discreet;

  const _CategorySummaryRow({
    required this.item,
    required this.discreet,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (item.percentage * 100).round();
    return Padding(
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
                    Text(
                      '${item.count} ${item.count == 1 ? 'lançamento' : 'lançamentos'} • $pct% das saídas',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                AppFormatters.currency(item.amount, discreet: discreet),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: item.percentage,
              minHeight: 6,
              backgroundColor: item.category.color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(item.category.color),
            ),
          ),
        ],
      ),
    );
  }
}
