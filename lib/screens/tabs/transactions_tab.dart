import 'dart:ui';
import 'package:flutter/cupertino.dart';
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

  Future<void> _handleToggleIgnore(
    BuildContext context,
    TransactionItem tx,
  ) async {
    HapticFeedback.lightImpact();
    if (tx.groupId != null) {
      final scope = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.surface(ctx).withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: AppColors.border(ctx),
                    width: AppSpacing.hairlineBorder,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary(ctx)
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    Text(
                      tx.isIgnored ? 'Desativar Ignorar' : 'Ativar Ignorar',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 46,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: AppColors.secondarySurface(ctx),
                        borderRadius: BorderRadius.circular(14),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(ctx).pop('single');
                        },
                        child: Text(
                          'Apenas neste mês',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(ctx),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 46,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: AppColors.iosBlue,
                        borderRadius: BorderRadius.circular(14),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(ctx).pop('group');
                        },
                        child: Text(
                          tx.isInstallment
                              ? 'Em todas as parcelas (${tx.installmentTotal}x)'
                              : 'Em todos os meses deste lançamento',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFeatures: AppTypography.tabular,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (scope == null) return;
      await widget.appState.toggleIgnoreTransaction(
        tx,
        applyToGroup: scope == 'group',
      );
    } else {
      await widget.appState.toggleIgnoreTransaction(tx);
    }
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
      if (tx.isInvoicePayment) {
        if (selectedCard != null) {
          filteredSum += tx.amount;
        }
        continue;
      }
      if (tx.type == TransactionType.income) {
        filteredSum += tx.amount;
      } else {
        filteredSum -= tx.amount;
      }
    }

    return Column(
      children: [
        // 1. Cabeçalho de Busca Estilo iOS + Pílulas de Filtro Rápidas
        _ExtratoSearchAndFiltersHeader(
          searchController: _searchCtrl,
          searchQuery: _searchQuery,
          activeFilter: activeFilter,
          cards: appState.cards,
          onSearchChanged: (v) => setState(() => _searchQuery = v),
          onClearSearch: () {
            HapticFeedback.lightImpact();
            _searchCtrl.clear();
            setState(() => _searchQuery = '');
          },
          onImportTap: () {
            HapticFeedback.lightImpact();
            UnifiedImportScreen.open(
              context,
              appState: appState,
              initialCardId: selectedCard?.id,
            );
          },
          onSelectFilter: (filter) {
            HapticFeedback.lightImpact();
            appState.setExtratoFilter(filter);
          },
        ),

        // 2. Cabeçalho da Fatura quando filtrado por um Cartão ou Resumo da Lista
        if (selectedCard != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _SelectedCardInvoiceBanner(
              appState: appState,
              card: selectedCard,
              yearMonth: ym,
              discreet: discreet,
            ),
          )
        else if (items.isNotEmpty)
          _FilteredSummaryBar(
            count: items.length,
            filteredSum: filteredSum,
            discreet: discreet,
          ),

        // 3. Lista de Lançamentos (ou Estado Vazio Minimalista)
        Expanded(
          child: items.isEmpty
              ? _EmptyTransactionsState(
                  onAddTap: () {
                    HapticFeedback.lightImpact();
                    TransactionFormSheet.show(
                      context,
                      appState: appState,
                      initialType: activeFilter == 'income'
                          ? TransactionType.income
                          : TransactionType.expense,
                      initialCardId: selectedCard?.id,
                    );
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
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
                        onTap: () {
                          HapticFeedback.lightImpact();
                          TransactionFormSheet.show(
                            context,
                            appState: appState,
                            existing: tx,
                          );
                        },
                        onToggleIgnore: () => _handleToggleIgnore(context, tx),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 1. Barra de Busca Estilo iOS + Botão Importar + Pílulas de Filtro
class _ExtratoSearchAndFiltersHeader extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String? activeFilter;
  final List<CreditCardItem> cards;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onImportTap;
  final ValueChanged<String?> onSelectFilter;

  const _ExtratoSearchAndFiltersHeader({
    required this.searchController,
    required this.searchQuery,
    required this.activeFilter,
    required this.cards,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onImportTap,
    required this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      width: AppSpacing.hairlineBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.search,
                        size: 17,
                        color: AppColors.textSecondary(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: 'Buscar lançamento ou categoria...',
                          ),
                        ),
                      ),
                      if (searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: onClearSearch,
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 17,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onImportTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.border(context),
                      width: AppSpacing.hairlineBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HigIconSquircle(
                        icon: CupertinoIcons.tray_arrow_down_fill,
                        color: AppColors.iosBlue,
                        size: 24,
                        iconSize: 13,
                        radius: 7,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Importar',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterPill(
                  label: 'Todos',
                  selected: activeFilter == null,
                  color: AppColors.iosBlue,
                  onTap: () => onSelectFilter(null),
                ),
                const SizedBox(width: 6),
                _FilterPill(
                  label: 'Conta Corrente',
                  icon: CupertinoIcons.building_2_fill,
                  selected: activeFilter == 'cash',
                  color: AppColors.iosBlue,
                  onTap: () => onSelectFilter('cash'),
                ),
                const SizedBox(width: 6),
                _FilterPill(
                  label: 'Receitas',
                  icon: CupertinoIcons.arrow_down_left,
                  selected: activeFilter == 'income',
                  color: AppColors.iosGreen,
                  onTap: () => onSelectFilter('income'),
                ),
                for (final card in cards) ...[
                  const SizedBox(width: 6),
                  _FilterPill(
                    label: card.name,
                    icon: CupertinoIcons.creditcard_fill,
                    selected: activeFilter == 'card:${card.id}',
                    color: card.color,
                    onTap: () => onSelectFilter('card:${card.id}'),
                  ),
                ],
                const SizedBox(width: 6),
                _FilterPill(
                  label: 'Ignorados',
                  icon: CupertinoIcons.eye_slash_fill,
                  selected: activeFilter == 'ignored',
                  color: AppColors.iosOrange,
                  onTap: () => onSelectFilter('ignored'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. Banner de Resumo da Fatura quando um Cartão está selecionado no filtro
class _SelectedCardInvoiceBanner extends StatelessWidget {
  final AppState appState;
  final CreditCardItem card;
  final String yearMonth;
  final bool discreet;

  const _SelectedCardInvoiceBanner({
    required this.appState,
    required this.card,
    required this.yearMonth,
    required this.discreet,
  });

  @override
  Widget build(BuildContext context) {
    final paidAmount = appState.cardPaidAmount(card.id, yearMonth);
    final ignoredAmount = appState.cardIgnoredExpenseTotal(card.id, yearMonth);
    final ownAmount = appState.cardOwnExpenseTotal(card.id, yearMonth);
    final invoiceTotal = appState.cardInvoiceTotal(card.id, yearMonth);
    final remainingAmount =
        appState.cardRemainingInvoiceAmount(card.id, yearMonth);
    final isPaid = appState.isCardInvoicePaid(card.id, yearMonth);
    final purchaseCount = appState.cardInvoiceCount(card.id, yearMonth);

    return HigGroupedCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        Row(
          children: [
            HigIconSquircle(
              icon: CupertinoIcons.creditcard_fill,
              color: card.color,
              size: 40,
              iconSize: 20,
              radius: 11,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fatura ${card.name} • ${AppFormatters.monthLabel(yearMonth, short: true)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fecha dia ${card.closingDay} • Vence dia ${card.dueDay}',
                    style: AppTypography.captionTabular(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isPaid
                      ? 'Fatura Paga'
                      : AppFormatters.currency(
                          remainingAmount,
                          discreet: discreet,
                        ),
                  style: AppTypography.listAmount(
                    context,
                    isPaid
                        ? AppColors.success(context)
                        : AppColors.danger(context),
                  ),
                ),
                Text(
                  '$purchaseCount ${purchaseCount == 1 ? 'compra' : 'compras'}',
                  style: AppTypography.captionTabular(context),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Pagar Fatura',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  CardsTab.showPayInvoiceModal(
                    context,
                    appState,
                    card: card,
                    yearMonth: yearMonth,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: HigIconSquircle(
                    icon: CupertinoIcons.checkmark_seal_fill,
                    color: AppColors.iosGreen,
                    size: 34,
                    iconSize: 17,
                    radius: 10,
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'Editar Cartão',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  CardsTab.showCardModal(
                    context,
                    appState,
                    existing: card,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: HigIconSquircle(
                    icon: CupertinoIcons.slider_horizontal_3,
                    color: card.color,
                    size: 34,
                    iconSize: 17,
                    radius: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (paidAmount.abs() > 0.005 || ignoredAmount.abs() > 0.005) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (paidAmount.abs() > 0.005) ...[
                HigInfoPill(
                  icon: CupertinoIcons.bag_fill,
                  text:
                      'Compras: ${AppFormatters.currency(invoiceTotal, discreet: discreet)}',
                  color: card.color,
                ),
                HigInfoPill(
                  icon: CupertinoIcons.checkmark_circle_fill,
                  text:
                      'Pago/Antecipado: ${AppFormatters.currency(paidAmount, discreet: discreet)}',
                  color: AppColors.success(context),
                ),
              ],
              if (ignoredAmount.abs() > 0.005) ...[
                HigInfoPill(
                  icon: CupertinoIcons.person_fill,
                  text:
                      'Seus gastos: ${AppFormatters.currency(ownAmount, discreet: discreet)}',
                  color: AppColors.iosGreen,
                ),
                HigInfoPill(
                  icon: CupertinoIcons.eye_slash_fill,
                  text:
                      'Ignorados: ${AppFormatters.currency(ignoredAmount, discreet: discreet)}',
                  color: AppColors.iosOrange,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// 3. Barra de Contagem e Resultado Líquido do Filtro Atual
class _FilteredSummaryBar extends StatelessWidget {
  final int count;
  final double filteredSum;
  final bool discreet;

  const _FilteredSummaryBar({
    required this.count,
    required this.filteredSum,
    required this.discreet,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count ${count == 1 ? 'lançamento' : 'lançamentos'}',
            style: AppTypography.captionTabular(context),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Resultado: ${AppFormatters.currency(filteredSum.abs(), discreet: discreet)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filteredSum >= 0
                    ? AppColors.success(context)
                    : AppColors.danger(context),
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 4. Estado Vazio Minimalista Apple HIG
class _EmptyTransactionsState extends StatelessWidget {
  final VoidCallback onAddTap;

  const _EmptyTransactionsState({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: HigGroupedCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HigIconSquircle(
                  icon: CupertinoIcons.doc_text_fill,
                  color: AppColors.iosBlue,
                  size: 48,
                  iconSize: 24,
                  radius: 14,
                ),
                const SizedBox(height: 12),
                Text(
                  'Nenhum lançamento encontrado neste mês.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 14),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  color: AppColors.iosBlue,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: onAddTap,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.add,
                        size: 17,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Adicionar Lançamento',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

/// 5. Pílula de Filtro Estilo iOS
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface(context),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? color : AppColors.border(context),
            width: AppSpacing.hairlineBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13.5,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color:
                    selected ? Colors.white : AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 6. Card de Lançamento Individual estilo Copilot Money / Apple Wallet
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
    final isInvPayment = tx.isInvoicePayment;
    final isCardRefund =
        !isInvPayment && tx.type == TransactionType.expense && tx.amount < 0;
    final isPositiveVisual = isIncome || isCardRefund || isInvPayment;
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

    final Color iconColor = tx.isIgnored
        ? AppColors.textSecondary(context)
        : (isInvPayment ? AppColors.success(context) : category.color);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tx.isIgnored
                ? AppColors.iosOrange.withValues(alpha: 0.45)
                : (isInvPayment
                    ? AppColors.success(context).withValues(alpha: 0.4)
                    : AppColors.border(context)),
            width: AppSpacing.hairlineBorder,
          ),
        ),
        child: Row(
          children: [
            HigIconSquircle(
              icon: isInvPayment
                  ? CupertinoIcons.checkmark_seal_fill
                  : category.icon,
              color: iconColor,
              size: 40,
              iconSize: 19,
              radius: 11,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: tx.isIgnored
                                ? AppColors.textSecondary(context)
                                : AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      if (isInvPayment) ...[
                        const SizedBox(width: 6),
                        _SmallTag(
                          text: 'Pagamento Fatura',
                          color: AppColors.success(context),
                        ),
                      ] else if (isCardRefund) ...[
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
                          color: card?.color ?? AppColors.iosIndigo,
                        ),
                      ] else if (tx.isRecurring) ...[
                        const SizedBox(width: 6),
                        const _SmallTag(
                          text: 'Fixa',
                          color: AppColors.iosGreen,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isInvPayment
                        ? 'Abatimento na fatura • $paymentBadge • ${AppFormatters.dayMonth(tx.date)}'
                        : '${category.name} • $paymentBadge • ${AppFormatters.dayMonth(tx.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.captionTabular(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 122),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${isPositiveVisual ? '+' : '-'} ${AppFormatters.currency(tx.amount.abs(), discreet: discreet)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: amountColor,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ),
                ),
                if (!isInvPayment) ...[
                  const SizedBox(height: 5),
                  Semantics(
                    button: true,
                    toggled: tx.isIgnored,
                    label: tx.isIgnored ? 'Ignorar ativo' : 'Ignorar inativo',
                    child: GestureDetector(
                      onTap: onToggleIgnore,
                      behavior: HitTestBehavior.opaque,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 30,
                          minWidth: 72,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: tx.isIgnored
                                ? AppColors.iosOrange
                                : AppColors.iosOrange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: tx.isIgnored
                                  ? AppColors.iosOrange
                                  : AppColors.border(context),
                              width: AppSpacing.hairlineBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                tx.isIgnored
                                    ? CupertinoIcons.eye_slash_fill
                                    : CupertinoIcons.eye_slash,
                                size: 12,
                                color: tx.isIgnored
                                    ? Colors.white
                                    : AppColors.textSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ignorar',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tx.isIgnored
                                      ? Colors.white
                                      : AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
          fontFeatures: AppTypography.tabular,
        ),
      ),
    );
  }
}
