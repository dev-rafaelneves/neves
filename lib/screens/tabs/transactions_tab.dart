import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../transaction_form_sheet.dart';
import '../unified_import_screen.dart';
import 'cards_tab.dart';

class TransactionsTab extends StatefulWidget {
  final AppState appState;

  const TransactionsTab({super.key, required this.appState});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TransactionItem> _filteredTransactions() {
    final ym = widget.appState.selectedYearMonth;
    final filter = widget.appState.extratoFilter;
    final q = _searchQuery.trim().toLowerCase();

    return widget.appState.transactionsForMonth(ym).where((tx) {
      if (filter == 'cash') {
        if (tx.type != TransactionType.expense ||
            tx.paymentMethod != PaymentMethod.cash) {
          return false;
        }
      } else if (filter == 'income') {
        if (tx.type != TransactionType.income) return false;
      } else if (filter == 'ignored') {
        if (!tx.isIgnored) return false;
      } else if (filter != null && filter.startsWith('card:')) {
        final cardId = filter.substring(5);
        if (tx.type != TransactionType.expense ||
            tx.paymentMethod != PaymentMethod.creditCard ||
            tx.cardId != cardId) {
          return false;
        }
      }

      if (q.isNotEmpty) {
        final cat = widget.appState.categoryById(tx.categoryId);
        final matchTitle = tx.title.toLowerCase().contains(q);
        final matchCat = cat.name.toLowerCase().contains(q);
        if (!matchTitle && !matchCat) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final ym = appState.selectedYearMonth;
    final discreet = appState.discreetMode;
    final activeFilter = appState.extratoFilter;
    final items = _filteredTransactions();

    CreditCardItem? selectedCard;
    if (activeFilter != null && activeFilter.startsWith('card:')) {
      selectedCard = appState.cardById(activeFilter.substring(5));
    }

    double filteredSum = 0.0;
    for (final tx in items) {
      if (tx.type == TransactionType.income) {
        filteredSum += tx.amount;
      } else {
        filteredSum -= tx.amount;
      }
    }

    return Column(
      children: [
        // Barra de Busca e Filtros Rápidos
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Busca + Botão Rápido de Importar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border(context),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 19,
                            color: AppColors.textSecondary(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: 'Buscar lançamento ou categoria...',
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => UnifiedImportScreen.open(
                        context,
                        appState: appState,
                        initialCardId: selectedCard?.id,
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 17),
                      label: const Text(
                        'Importar',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Pílulas de Filtro
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'Todos',
                      selected: activeFilter == null,
                      color: AppColors.primary,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        appState.setExtratoFilter(null);
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterPill(
                      label: 'Conta Corrente',
                      icon: Icons.account_balance_rounded,
                      selected: activeFilter == 'cash',
                      color: AppColors.blue,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        appState.setExtratoFilter('cash');
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterPill(
                      label: 'Receitas',
                      icon: Icons.arrow_downward_rounded,
                      selected: activeFilter == 'income',
                      color: AppColors.primary,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        appState.setExtratoFilter('income');
                      },
                    ),
                    for (final card in appState.cards) ...[
                      const SizedBox(width: 6),
                      _FilterPill(
                        label: card.name,
                        icon: Icons.credit_card_rounded,
                        selected: activeFilter == 'card:${card.id}',
                        color: card.color,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          appState.setExtratoFilter('card:${card.id}');
                        },
                      ),
                    ],
                    const SizedBox(width: 6),
                    _FilterPill(
                      label: 'Ignorados',
                      icon: Icons.visibility_off_outlined,
                      selected: activeFilter == 'ignored',
                      color: AppColors.orange,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        appState.setExtratoFilter('ignored');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Cabeçalho da Fatura quando filtrado por um Cartão
        if (selectedCard != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: selectedCard.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selectedCard.color.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.credit_card_rounded,
                    color: selectedCard.color,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fatura ${selectedCard.name} • ${AppFormatters.monthLabel(ym, short: true)}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          'Fecha dia ${selectedCard.closingDay} • Vence dia ${selectedCard.dueDay}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        if (appState
                                .cardIgnoredExpenseTotal(selectedCard.id, ym)
                                .abs() >
                            0.005) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Seus gastos: ${AppFormatters.currency(appState.cardOwnExpenseTotal(selectedCard.id, ym), discreet: discreet)} • Ignorados: ${AppFormatters.currency(appState.cardIgnoredExpenseTotal(selectedCard.id, ym), discreet: discreet)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppFormatters.currency(
                          appState.cardInvoiceTotal(selectedCard.id, ym),
                          discreet: discreet,
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger(context),
                        ),
                      ),
                      Text(
                        '${items.length} ${items.length == 1 ? 'compra' : 'compras'}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Editar Cartão',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => CardsTab.showCardModal(
                      context,
                      appState,
                      existing: selectedCard,
                    ),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: selectedCard.color,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${items.length} ${items.length == 1 ? 'lançamento' : 'lançamentos'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                Text(
                  'Resultado listado: ${AppFormatters.currency(filteredSum.abs(), discreet: discreet)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: filteredSum >= 0
                        ? AppColors.success(context)
                        : AppColors.danger(context),
                  ),
                ),
              ],
            ),
          ),

        // Lista de Lançamentos
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 46,
                          color: AppColors.textSecondary(context),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Nenhum lançamento encontrado neste mês.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => TransactionFormSheet.show(
                            context,
                            appState: appState,
                            initialType: activeFilter == 'income'
                                ? TransactionType.income
                                : TransactionType.expense,
                            initialCardId: selectedCard?.id,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Adicionar Lançamento'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: items.length,
                  itemBuilder: (context, idx) {
                    final tx = items[idx];
                    final cat = appState.categoryById(tx.categoryId);
                    final card = appState.cardById(tx.cardId);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TransactionTile(
                        tx: tx,
                        category: cat,
                        card: card,
                        discreet: discreet,
                        onTap: () => TransactionFormSheet.show(
                          context,
                          appState: appState,
                          existing: tx,
                        ),
                        onToggleIgnore: () async {
                          HapticFeedback.selectionClick();
                          if (tx.groupId != null) {
                            final scope = await showModalBottomSheet<String>(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => Container(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 24),
                                decoration: BoxDecoration(
                                  color: AppColors.surface(ctx),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                child: SafeArea(
                                  top: false,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tx.isIgnored
                                            ? 'Desativar Ignorar'
                                            : 'Ativar Ignorar',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop('single'),
                                          child: const Text(
                                            'Apenas neste mês',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop('group'),
                                          child: Text(
                                            tx.isInstallment
                                                ? 'Em todas as parcelas (${tx.installmentTotal}x)'
                                                : 'Em todos os meses deste lançamento',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            if (scope == null) return;
                            await appState.toggleIgnoreTransaction(
                              tx,
                              applyToGroup: scope == 'group',
                            );
                          } else {
                            await appState.toggleIgnoreTransaction(tx);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface(context),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? color : AppColors.border(context),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionItem tx;
  final CategoryItem category;
  final CreditCardItem? card;
  final bool discreet;
  final VoidCallback onTap;
  final VoidCallback onToggleIgnore;

  const _TransactionTile({
    required this.tx,
    required this.category,
    required this.card,
    required this.discreet,
    required this.onTap,
    required this.onToggleIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == TransactionType.income;
    final isCardRefund = tx.type == TransactionType.expense && tx.amount < 0;
    final isPositiveVisual = isIncome || isCardRefund;
    final amountColor = tx.isIgnored
        ? AppColors.textSecondary(context)
        : (isPositiveVisual
            ? AppColors.success(context)
            : AppColors.danger(context));

    final String paymentBadge = isIncome
        ? 'Receita'
        : (tx.paymentMethod == PaymentMethod.creditCard
            ? (card?.name ?? 'Cartão')
            : 'Conta Corrente');

    return Material(
      color: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: tx.isIgnored
              ? AppColors.orange.withValues(alpha: 0.45)
              : AppColors.border(context),
          width: 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category.color
                      .withValues(alpha: tx.isIgnored ? 0.08 : 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  category.icon,
                  color: tx.isIgnored
                      ? AppColors.textSecondary(context)
                      : category.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tx.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: tx.isIgnored
                                  ? AppColors.textSecondary(context)
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        if (isCardRefund) ...[
                          const SizedBox(width: 6),
                          _SmallTag(
                            text: 'Estorno',
                            color: AppColors.success(context),
                          ),
                        ] else if (tx.isInstallment) ...[
                          const SizedBox(width: 6),
                          _SmallTag(
                            text:
                                '${tx.installmentIndex}/${tx.installmentTotal}',
                            color: card?.color ?? AppColors.purple,
                          ),
                        ] else if (tx.isRecurring) ...[
                          const SizedBox(width: 6),
                          const _SmallTag(
                            text: 'Fixa',
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${category.name} • $paymentBadge • ${AppFormatters.dayMonth(tx.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
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
                    '${isPositiveVisual ? '+' : '-'} ${AppFormatters.currency(tx.amount.abs(), discreet: discreet)}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Botão toggle ativo/inativo 'Ignorar'
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onToggleIgnore,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tx.isIgnored
                            ? AppColors.orange
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: tx.isIgnored
                              ? AppColors.orange
                              : AppColors.border(context),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tx.isIgnored
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_off_outlined,
                            size: 11.5,
                            color: tx.isIgnored
                                ? Colors.white
                                : AppColors.textSecondary(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ignorar',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: tx.isIgnored
                                  ? Colors.white
                                  : AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  final String text;
  final Color color;

  const _SmallTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
