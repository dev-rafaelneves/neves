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

  /// Quando definido, filtra os lançamentos por categoria.
  final String? categoryFilterId;
  final VoidCallback? onClearCategoryFilter;

  const TransactionsTab({
    super.key,
    required this.appState,
    this.cardFilterId,
    this.onClearCardFilter,
    this.categoryFilterId,
    this.onClearCategoryFilter,
  });

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  String _searchQuery = '';
  String _activeFilter = 'all'; // all | expense | income | pending | card
  String? _selectedTag;
  final Set<String> _hiddenIds = {};
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearAllFilters() {
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _activeFilter = 'all';
      _selectedTag = null;
    });
    widget.onClearCardFilter?.call();
    widget.onClearCategoryFilter?.call();
  }

  void _showUndoSnack(String message, Future<void> Function() onUndo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Desfazer', onPressed: onUndo),
      ),
    );
  }

  Future<bool> _confirmSwipe(DismissDirection dir, TransactionModel tx) async {
    if (dir == DismissDirection.startToEnd) {
      final wasIgnored = tx.isIgnored;
      final includeFuture =
          await toggleIgnoreTransaction(context, widget.appState, tx);
      if (includeFuture != null && mounted) {
        _showUndoSnack(
          wasIgnored ? 'Lançamento reativado' : 'Lançamento ignorado',
          () => widget.appState.setTransactionIgnored(
            tx,
            wasIgnored,
            includeFutureInstallments: includeFuture,
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _onDeleted(TransactionModel tx) async {
    setState(() => _hiddenIds.add(tx.id));
    await widget.appState.deleteTransaction(tx);
    if (!mounted) return;
    setState(() => _hiddenIds.remove(tx.id));
    _showUndoSnack(
      'Lançamento excluído',
      () => widget.appState.addOrUpdateTransaction(tx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    final ym = state.selectedYearMonth;
    final discreet = state.discreetMode;

    var list = state.transactionsForMonth(ym, includeIgnored: true);
    final filterCard = state.getCardById(widget.cardFilterId);
    final filterCategory = state.getCategoryById(widget.categoryFilterId);
    list = list.where((t) => !_hiddenIds.contains(t.id)).toList();
    if (filterCard != null) {
      list = list.where((t) => t.cardId == filterCard.id).toList();
    }
    if (filterCategory != null) {
      list = list.where((t) => t.categoryId == filterCategory.id).toList();
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
            'Lançamentos',
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
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.sizeOf(context).width >= 840 ? 720 : 480,
                ),
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
                    if (filterCategory != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: filterCategory.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              filterCategory.icon,
                              size: 18,
                              color: filterCategory.color,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Categoria: ${filterCategory.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onClearCategoryFilter,
                              child: const Text('Limpar'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Campo de busca
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar por descrição ou #tag...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                tooltip: 'Limpar busca',
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
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

                    if (list.isEmpty) ...[
                      Builder(
                        builder: (context) {
                          final hasFilters = filterCard != null ||
                              filterCategory != null ||
                              _searchQuery.trim().isNotEmpty ||
                              _activeFilter != 'all' ||
                              _selectedTag != null;
                          return Material(
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
                                      hasFilters
                                          ? Icons.filter_alt_off_rounded
                                          : Icons.receipt_long_rounded,
                                      size: 40,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      hasFilters
                                          ? 'Nenhum lançamento encontrado com esses filtros'
                                          : 'Nenhum lançamento em ${AppFormatters.monthLabel(ym)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      hasFilters
                                          ? 'Tente outro termo ou limpe os filtros ativos.'
                                          : 'Toque abaixo para registrar sua primeira despesa ou receita do mês.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (hasFilters)
                                      OutlinedButton.icon(
                                        onPressed: _clearAllFilters,
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Limpar filtros'),
                                      )
                                    else
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            TransactionFormSheet.show(
                                          context,
                                          appState: state,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.add_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Novo lançamento',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      _buildSummaryBar(
                        context,
                        list: list,
                        discreet: discreet,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      ..._buildGroupedItems(
                        context,
                        state: state,
                        list: list,
                        discreet: discreet,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _netTotal(List<TransactionModel> txs) {
    double sum = 0.0;
    for (final t in txs) {
      if (t.isIgnored || t.isInvoicePayment) continue;
      if (t.type == TransactionType.income) {
        sum += t.amount;
      } else if (t.type == TransactionType.expense) {
        sum -= t.amount;
      }
    }
    return sum;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'Hoje';
    if (day == yesterday) return 'Ontem';
    final raw = DateFormat("EEE, dd 'de' MMM", 'pt_BR').format(day);
    return raw[0].toUpperCase() + raw.substring(1);
  }

  Widget _buildSummaryBar(
    BuildContext context, {
    required List<TransactionModel> list,
    required bool discreet,
    required bool isDark,
  }) {
    final activeCount = list.where((t) => !t.isIgnored).length;
    final ignoredCount = list.length - activeCount;
    final net = _netTotal(list);
    final sign = net > 0 ? '+' : (net < 0 ? '-' : '');
    final totalColor = net > 0
        ? AppColors.success(context)
        : (net < 0 ? AppColors.danger(context) : AppColors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              ignoredCount > 0
                  ? '$activeCount ativos • $ignoredCount ignorados'
                  : '$activeCount ${activeCount == 1 ? 'lançamento' : 'lançamentos'}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${AppFormatters.currency(net.abs(), discreet: discreet)}',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: totalColor,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedItems(
    BuildContext context, {
    required AppState state,
    required List<TransactionModel> list,
    required bool discreet,
    required bool isDark,
  }) {
    final groups = <DateTime, List<TransactionModel>>{};
    for (final tx in list) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      groups.putIfAbsent(day, () => []).add(tx);
    }
    final sortedDays = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final day in sortedDays) {
      final items = groups[day]!;
      final dayNet = _netTotal(items);
      final sign = dayNet > 0 ? '+' : (dayNet < 0 ? '-' : '');
      final dayLabel = _dayLabel(day);

      widgets.add(
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8, left: 4, right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                Text(
                  '$sign${AppFormatters.currency(dayNet.abs(), discreet: discreet)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: dayNet > 0
                        ? AppColors.success(context)
                        : (dayNet < 0
                            ? AppColors.danger(context)
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      for (final tx in items) {
        widgets.add(
          _buildTransactionCard(
            context,
            state: state,
            tx: tx,
            discreet: discreet,
            isDark: isDark,
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildTransactionCard(
    BuildContext context, {
    required AppState state,
    required TransactionModel tx,
    required bool discreet,
    required bool isDark,
  }) {
    final cat = state.getCategoryById(tx.categoryId);
    final card = state.getCardById(tx.cardId);
    final acc = state.getAccountById(tx.accountId);
    final isPaid = tx.status == TransactionStatus.paid;
    final typeWord = tx.type == TransactionType.income
        ? 'receita'
        : (tx.type == TransactionType.expense ? 'despesa' : 'transferência');
    final statusWord = tx.isCreditCard
        ? 'no cartão ${card?.name ?? ''}'
        : (isPaid ? 'pago' : 'pendente');
    final semanticLabel = discreet
        ? '${tx.title}, valor oculto, $typeWord, ${DateFormat('dd/MM').format(tx.date)}'
        : '${tx.title}, ${AppFormatters.currency(tx.amount)}, $typeWord, ${DateFormat('dd/MM').format(tx.date)}, ${cat?.name ?? 'Transferência'}, $statusWord${tx.isIgnored ? ', ignorada' : ''}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('tx_${tx.id}'),
        direction: tx.isInvoicePayment
            ? DismissDirection.startToEnd
            : DismissDirection.horizontal,
        confirmDismiss: (dir) => _confirmSwipe(dir, tx),
        onDismissed: (_) => _onDeleted(tx),
        background: _swipeBackground(
          color: AppColors.warningStrong,
          icon: tx.isIgnored
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
          label: tx.isIgnored ? 'Reativar' : 'Ignorar',
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _swipeBackground(
          color: AppColors.dangerStrong,
          icon: Icons.delete_outline_rounded,
          label: 'Excluir',
          alignment: Alignment.centerRight,
        ),
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: Opacity(
            opacity: tx.isIgnored ? 0.45 : 1.0,
            child: Material(
              color: isDark ? AppColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                          color: (cat?.color ?? AppColors.primary)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          cat?.icon ?? Icons.swap_horiz_rounded,
                          color: cat?.color ?? AppColors.primary,
                          size: 21,
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${tx.installmentIndex}/${tx.installmentTotal}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
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
                                    : AppColors.lightTextSecondary,
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
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
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
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${tx.type == TransactionType.income ? '+' : (tx.type == TransactionType.expense ? '-' : '')} ${AppFormatters.currency(tx.amount, discreet: discreet)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: tx.type == TransactionType.income
                                  ? AppColors.success(context)
                                  : (tx.type == TransactionType.expense
                                      ? AppColors.danger(context)
                                      : AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              toggleIgnoreTransaction(context, state, tx);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
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
                                      fontSize: 12,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (isPaid
                                          ? AppColors.emerald
                                          : AppColors.orange)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPaid ? 'Pago' : 'Pendente',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isPaid
                                        ? AppColors.success(context)
                                        : AppColors.warning(context),
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
        ),
      ),
    );
  }

  Widget _swipeBackground({
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
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
