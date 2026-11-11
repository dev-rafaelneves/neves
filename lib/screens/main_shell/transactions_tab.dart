import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ignore_transaction_action.dart';
import '../../widgets/month_selector_bar.dart';
import '../transaction_form_sheet.dart';

class TransactionsTab extends StatefulWidget {
  final AppState appState;

  /// Quando definido, o extrato mostra apenas compras e pagamentos desse cartão.
  final String? cardFilterId;
  final VoidCallback? onClearCardFilter;

  const TransactionsTab({
    super.key,
    required this.appState,
    this.cardFilterId,
    this.onClearCardFilter,
  });

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  String _searchQuery = '';
  String _activeFilter = 'all'; // all | expense | income | pending | card
  String? _selectedTag;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    final ym = state.selectedYearMonth;
    final discreet = state.discreetMode;

    var list = state.transactionsForMonth(ym, includeIgnored: true);
    final filterCard = state.getCardById(widget.cardFilterId);
    if (filterCard != null) {
      list = list.where((t) => t.cardId == filterCard.id).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.tags.any((tag) => tag.toLowerCase().contains(q)))
          .toList();
    }
    if (_activeFilter == 'expense') {
      list = list.where((t) => t.type == TransactionType.expense).toList();
    } else if (_activeFilter == 'income') {
      list = list.where((t) => t.type == TransactionType.income).toList();
    } else if (_activeFilter == 'pending') {
      list = list.where((t) => t.status == TransactionStatus.pending).toList();
    } else if (_activeFilter == 'card') {
      list = list.where((t) => t.isCreditCard).toList();
    }
    if (_selectedTag != null) {
      list = list.where((t) => t.tags.contains(_selectedTag)).toList();
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 68,
          backgroundColor: isDark
              ? AppColors.darkBackground.withValues(alpha: 0.92)
              : AppColors.lightBackground.withValues(alpha: 0.92),
          centerTitle: false,
          titleSpacing: 20,
          title: Text(
            'Extrato',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: MonthSelectorBar(appState: state)),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (filterCard != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: filterCard.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.credit_card_rounded, size: 18, color: filterCard.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cartão ${filterCard.name}: compras e pagamentos',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onClearCardFilter,
                              child: const Text('Limpar'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Campo de busca
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar por descrição ou #tag...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor:
                            isDark ? AppColors.darkSurface : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Chips de Filtro Rápido
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Todos', 'all'),
                          const SizedBox(width: 6),
                          _buildFilterChip('Despesas', 'expense'),
                          const SizedBox(width: 6),
                          _buildFilterChip('Receitas', 'income'),
                          const SizedBox(width: 6),
                          _buildFilterChip('Pendentes', 'pending'),
                          const SizedBox(width: 6),
                          _buildFilterChip('Cartão', 'card'),
                          for (final tag in state.allUsedTags) ...[
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: Text('#$tag'),
                              selected: _selectedTag == tag,
                              onSelected: (sel) => setState(
                                () => _selectedTag = sel ? tag : null,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (list.isEmpty)
                      Material(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 40,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Nenhum lançamento encontrado',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...list.map((tx) {
                        final cat = state.getCategoryById(tx.categoryId);
                        final card = state.getCardById(tx.cardId);
                        final acc = state.getAccountById(tx.accountId);
                        final isPaid = tx.status == TransactionStatus.paid;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Opacity(
                            opacity: tx.isIgnored ? 0.45 : 1.0,
                            child: Material(
                            color:
                                isDark ? AppColors.darkSurface : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => TransactionFormSheet.show(
                                context,
                                appState: state,
                                initialTransaction: tx,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: (cat?.color ??
                                                AppColors.indigoPrimary)
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Icon(
                                        cat?.icon ?? Icons.swap_horiz_rounded,
                                        color: cat?.color ??
                                            AppColors.indigoPrimary,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  tx.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14.5,
                                                    decoration: tx.isIgnored
                                                        ? TextDecoration.lineThrough
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                              if (tx.isInstallment) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors
                                                        .indigoPrimary
                                                        .withValues(
                                                            alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    '${tx.installmentIndex}/${tx.installmentTotal}',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors
                                                          .indigoPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${DateFormat('dd/MM').format(tx.date)} • ${cat?.name ?? 'Transferência'} • ${card != null ? '💳 ${card.name}' : (acc?.name ?? '')}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors
                                                      .lightTextSecondary,
                                            ),
                                          ),
                                          if (tx.tags.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 4,
                                              children: tx.tags
                                                  .map(
                                                    (tag) => Text(
                                                      '#$tag',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .indigoPrimary,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${tx.type == TransactionType.income ? '+' : (tx.type == TransactionType.expense ? '-' : '')} ${AppFormatters.currency(tx.amount, discreet: discreet)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14.5,
                                            color: tx.type ==
                                                    TransactionType.income
                                                ? AppColors.emerald
                                                : (tx.type ==
                                                        TransactionType.expense
                                                    ? AppColors.rose
                                                    : AppColors.indigoPrimary),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            toggleIgnoreTransaction(context, state, tx);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 4, top: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  tx.isIgnored
                                                      ? Icons.visibility_rounded
                                                      : Icons.visibility_off_rounded,
                                                  size: 13,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  tx.isIgnored ? 'Reativar' : 'Ignorar',
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (!tx.isCreditCard)
                                          InkWell(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              state.toggleTransactionPaid(tx);
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: (isPaid
                                                        ? AppColors.emerald
                                                        : AppColors.orange)
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isPaid ? 'Pago' : 'Pendente',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isPaid
                                                      ? AppColors.emerald
                                                      : AppColors.orange,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String key) {
    return ChoiceChip(
      label: Text(label),
      selected: _activeFilter == key,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _activeFilter = key);
      },
      visualDensity: VisualDensity.compact,
    );
  }
}
