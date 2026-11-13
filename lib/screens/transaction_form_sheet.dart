import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ios_action_sheet.dart';

class TransactionFormSheet extends StatefulWidget {
  final AppState appState;
  final TransactionModel? initialTransaction;

  const TransactionFormSheet({
    super.key,
    required this.appState,
    this.initialTransaction,
  });

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    TransactionModel? initialTransaction,
  }) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionFormSheet(
        appState: appState,
        initialTransaction: initialTransaction,
      ),
    );
  }

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  static const _uuid = Uuid();

  late TransactionType _type;
  late TextEditingController _amountCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _tagInputCtrl;
  late DateTime _selectedDate;
  late TransactionStatus _status;
  late RecurrenceRule _recurrence;

  bool _useCreditCard = false;
  bool _isIgnored = false;
  bool _showMoreOptions = false;
  String? _selectedAccountId;
  String? _destinationAccountId;
  String? _selectedCardId;
  String? _selectedCategoryId;
  String? _selectedGoalId;
  int _installments = 1;
  List<String> _tags = [];

  bool get _isEditing => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;
    final state = widget.appState;

    _type = tx?.type ?? TransactionType.expense;
    _amountCtrl = TextEditingController(
      text: CentavosCurrencyFormatter.formatDouble(tx?.amount ?? 0.0),
    );
    _titleCtrl = TextEditingController(text: tx?.title ?? '');
    _tagInputCtrl = TextEditingController();
    _selectedDate = tx?.date ?? DateTime.now();
    _status = tx?.status ?? TransactionStatus.paid;
    _recurrence = tx?.recurrenceRule ?? RecurrenceRule.none;

    _useCreditCard = tx?.isCreditCard ?? false;
    _isIgnored = tx?.isIgnored ?? false;
    _selectedAccountId = tx?.accountId ??
        (state.accounts.isNotEmpty ? state.accounts.first.id : null);
    _destinationAccountId = tx?.destinationAccountId ??
        (state.accounts.length > 1 ? state.accounts[1].id : null);
    _selectedCardId = tx?.cardId ??
        (state.creditCards.isNotEmpty ? state.creditCards.first.id : null);

    final validCats = state.categories.where((c) => c.type == _type).toList();
    _selectedCategoryId = tx?.categoryId ??
        (validCats.isNotEmpty ? validCats.first.id : null);
    _selectedGoalId = tx?.goalId;
    _installments = tx?.installmentTotal ?? 1;
    _tags = List<String>.from(tx?.tags ?? []);
    _showMoreOptions = tx != null &&
        (tx.isIgnored ||
            tx.goalId != null ||
            tx.tags.isNotEmpty ||
            tx.recurrenceRule != RecurrenceRule.none ||
            (!tx.isCreditCard && tx.status == TransactionStatus.pending));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _tagInputCtrl.dispose();
    super.dispose();
  }

  double _parseAmount() => CentavosCurrencyFormatter.parseValue(_amountCtrl.text);

  Color get _accentColor {
    switch (_type) {
      case TransactionType.income:
        return AppColors.emerald;
      case TransactionType.expense:
        return AppColors.rose;
      case TransactionType.transfer:
        return AppColors.primary;
    }
  }

  void _onTypeChanged(TransactionType next) {
    HapticFeedback.selectionClick();
    setState(() {
      _type = next;
      if (_type != TransactionType.expense) {
        _useCreditCard = false;
      }
      final validCats =
          widget.appState.categories.where((c) => c.type == _type).toList();
      if (validCats.isNotEmpty &&
          !validCats.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = validCats.first.id;
      }
    });
  }

  Future<void> _pickCategory(List<CategoryModel> categories) async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Selecionar Categoria',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) =>
                      const Divider(indent: 64, height: 1),
                  itemBuilder: (_, idx) {
                    final cat = categories[idx];
                    final selected = cat.id == _selectedCategoryId;
                    return ListTile(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategoryId = cat.id);
                        Navigator.of(ctx).pop();
                      },
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(cat.icon, color: cat.color, size: 20),
                      ),
                      title: Text(
                        cat.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAccount({required bool isDestination}) async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isDestination ? 'Conta de Destino' : 'Selecionar Conta',
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ...state.accounts.map((acc) {
                final selected = isDestination
                    ? acc.id == _destinationAccountId
                    : acc.id == _selectedAccountId;
                return ListTile(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isDestination) {
                        _destinationAccountId = acc.id;
                      } else {
                        _selectedAccountId = acc.id;
                      }
                    });
                    Navigator.of(ctx).pop();
                  },
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: acc.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(acc.icon, color: acc.color, size: 20),
                  ),
                  title: Text(
                    acc.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    AppFormatters.currency(
                      acc.currentBalance,
                      discreet: state.discreetMode,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCreditCard() async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Selecionar Cartão de Crédito',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...state.creditCards.map((card) {
                final selected = card.id == _selectedCardId;
                return ListTile(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCardId = card.id);
                    Navigator.of(ctx).pop();
                  },
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: card.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.credit_card_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    card.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Fecha dia ${card.closingDay} • Vence dia ${card.dueDay} • Disp: ${AppFormatters.currency(state.getCardAvailableLimit(card))}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickInstallments() async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountVal = _parseAmount();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Número de Parcelas',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: 24,
                  separatorBuilder: (_, __) =>
                      const Divider(indent: 20, height: 1),
                  itemBuilder: (_, idx) {
                    final n = idx + 1;
                    final parcelVal = amountVal > 0 ? amountVal / n : 0.0;
                    final label = n == 1
                        ? '1x à vista (${AppFormatters.currency(amountVal)})'
                        : '${n}x de ${AppFormatters.currency(parcelVal)} sem juros';
                    return ListTile(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _installments = n);
                        Navigator.of(ctx).pop();
                      },
                      title: Text(
                        label,
                        style: TextStyle(
                          fontWeight: _installments == n
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: _installments == n
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amount = _parseAmount();
    final title = _titleCtrl.text.trim();
    if (amount <= 0 || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor maior que R\$ 0,00 e uma descrição.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final state = widget.appState;
    final card = _useCreditCard ? state.getCardById(_selectedCardId) : null;

    final competenceMonth = card != null
        ? card.computeCompetenceMonth(_selectedDate)
        : '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}';

    final tx = TransactionModel(
      id: widget.initialTransaction?.id ?? _uuid.v4(),
      title: title,
      amount: amount,
      type: _type,
      date: _selectedDate,
      competenceMonth: competenceMonth,
      status: _useCreditCard ? TransactionStatus.pending : _status,
      accountId: _useCreditCard ? null : _selectedAccountId,
      destinationAccountId:
          _type == TransactionType.transfer ? _destinationAccountId : null,
      cardId: _useCreditCard ? _selectedCardId : null,
      categoryId:
          _type == TransactionType.transfer ? null : _selectedCategoryId,
      goalId: _selectedGoalId,
      installmentGroupId: widget.initialTransaction?.installmentGroupId,
      installmentIndex: widget.initialTransaction?.installmentIndex ?? 1,
      installmentTotal: _isEditing
          ? (widget.initialTransaction?.installmentTotal ?? 1)
          : (_useCreditCard ? _installments : 1),
      recurrenceRule: _recurrence,
      tags: _tags,
      isIgnored: _isIgnored,
    );

    await state.addOrUpdateTransaction(
      tx,
      installments: _isEditing ? 1 : (_useCreditCard ? _installments : 1),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _confirmDelete() {
    final tx = widget.initialTransaction;
    if (tx == null) return;

    IosActionSheet.show(
      context: context,
      title: 'Excluir Lançamento',
      description: tx.isInstallment
          ? 'Este lançamento faz parte de um parcelamento (${tx.installmentIndex}/${tx.installmentTotal}). Deseja excluir todas as parcelas vinculadas?'
          : 'Esta ação removerá o lançamento e recalculará seus saldos.',
      confirmText:
          tx.isInstallment ? 'Excluir Todas as Parcelas' : 'Excluir Lançamento',
      onConfirm: () async {
        await widget.appState.deleteTransaction(
          tx,
          deleteAllInstallments: tx.isInstallment,
        );
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final state = widget.appState;
    final filteredCategories =
        state.categories.where((c) => c.type == _type).toList();
    final selectedCat = state.getCategoryById(_selectedCategoryId);
    final selectedAcc = state.getAccountById(_selectedAccountId);
    final destAcc = state.getAccountById(_destinationAccountId);
    final selectedCard =
        _useCreditCard ? state.getCardById(_selectedCardId) : null;
    final amountVal = _parseAmount();

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Top Navigation Bar Apple HIG
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.8,
                ),
              ),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      _isEditing ? 'Editar Lançamento' : 'Novo Lançamento',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (_isEditing)
                      IconButton(
                        onPressed: _confirmDelete,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger(context),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _save,
                        child: const Text(
                          'Salvar',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<TransactionType>(
                    groupValue: _type,
                    children: const {
                      TransactionType.expense: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Despesa',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TransactionType.income: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Receita',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TransactionType.transfer: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Transferência',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    },
                    onValueChanged: (v) {
                      if (v != null) _onTypeChanged(v);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Corpo do Formulário em Seções Agrupadas (Apple HIG Inset Grouped)
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset + 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Campo de Valor Hero estilo Nubank (Centavos da direita para a esquerda)
                      HigCurrencyHeroField(
                        controller: _amountCtrl,
                        label: 'Valor do Lançamento',
                        accentColor: _accentColor,
                        autofocus: !_isEditing,
                        onChanged: (_) => setState(() {}),
                        bottomAccessory: InkWell(
                          borderRadius: BorderRadius.circular(100),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkBackground
                                  : AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat(
                                    "EEE, dd 'de' MMM yyyy",
                                    'pt_BR',
                                  ).format(_selectedDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 2. Seção: Identificação & Classificação
                      const HigSectionHeader(
                        title: 'Identificação & Categoria',
                      ),
                      HigGroupedCard(
                        children: [
                          // Descrição estilo linha limpa iOS
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(
                                    Icons.edit_note_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _titleCtrl,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Descrição (ex: Supermercado, Uber...)',
                                      hintStyle: TextStyle(
                                        fontSize: 15,
                                        color: isDark
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFF94A3B8),
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_type != TransactionType.transfer &&
                              filteredCategories.isNotEmpty) ...[
                            const Divider(indent: 62, height: 1),
                            HigFormRow(
                              icon: selectedCat?.icon ?? Icons.category_rounded,
                              iconColor:
                                  selectedCat?.color ?? AppColors.primary,
                              label: 'Categoria',
                              onTap: () => _pickCategory(filteredCategories),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      selectedCat?.name ?? 'Selecionar',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 22),

                      // 3. Seção: Forma de Pagamento / Conta / Cartão
                      const HigSectionHeader(
                        title: 'Conta & Forma de Movimento',
                      ),
                      HigGroupedCard(
                        children: [
                          if (_type == TransactionType.expense &&
                              state.creditCards.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: CupertinoSlidingSegmentedControl<bool>(
                                  groupValue: _useCreditCard,
                                  children: const {
                                    false: Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 7),
                                      child: Text(
                                        'Conta / Pix / Débito',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    true: Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 7),
                                      child: Text(
                                        'Cartão de Crédito',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  },
                                  onValueChanged: (v) {
                                    if (v != null) {
                                      HapticFeedback.selectionClick();
                                      setState(() => _useCreditCard = v);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const Divider(indent: 16, height: 1),
                          ],
                          if (_useCreditCard && state.creditCards.isNotEmpty) ...[
                            HigFormRow(
                              icon: Icons.credit_card_rounded,
                              iconColor: selectedCard?.color ??
                                  AppColors.primary,
                              label: 'Cartão',
                              subtitle: selectedCard != null
                                  ? 'Fatura: ${selectedCard.computeCompetenceMonth(_selectedDate)}'
                                  : null,
                              onTap: _pickCreditCard,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      selectedCard?.name ?? 'Selecionar',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isEditing) ...[
                              const Divider(indent: 62, height: 1),
                              HigFormRow(
                                icon: Icons.view_week_rounded,
                                iconColor: AppColors.secondary,
                                label: 'Parcelamento',
                                subtitle: _installments > 1 && amountVal > 0
                                    ? '${_installments}x de ${AppFormatters.currency(amountVal / _installments)}'
                                    : 'Sem juros na fatura',
                                onTap: _pickInstallments,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _installments == 1
                                            ? '1x à vista'
                                            : '${_installments}x',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ] else ...[
                            HigFormRow(
                              icon: selectedAcc?.icon ??
                                  Icons.account_balance_rounded,
                              iconColor: selectedAcc?.color ??
                                  AppColors.primary,
                              label: _type == TransactionType.transfer
                                  ? 'Conta de Origem'
                                  : 'Conta',
                              subtitle: selectedAcc != null
                                  ? 'Saldo: ${AppFormatters.currency(selectedAcc.currentBalance, discreet: state.discreetMode)}'
                                  : null,
                              onTap: () => _pickAccount(isDestination: false),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      selectedAcc?.name ?? 'Selecionar',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                            if (_type == TransactionType.transfer) ...[
                              const Divider(indent: 62, height: 1),
                              HigFormRow(
                                icon: Icons.south_east_rounded,
                                iconColor: AppColors.success(context),
                                label: 'Conta de Destino',
                                onTap: () => _pickAccount(isDestination: true),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        destAcc?.name ?? 'Selecionar',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.success(context),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                      const SizedBox(height: 22),

                      // 4. Seção recolhível: Mais opções (Status, Recorrência, Caixinha, Ignorar, Tags)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(
                            () => _showMoreOptions = !_showMoreOptions,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'MAIS OPÇÕES',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _showMoreOptions ? 'Ocultar' : 'Mostrar',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _showMoreOptions
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showMoreOptions) ...[
                        const SizedBox(height: 4),
                        HigGroupedCard(
                        children: [
                          if (!_useCreditCard) ...[
                            HigFormRow(
                              icon: _status == TransactionStatus.paid
                                  ? Icons.check_circle_rounded
                                  : Icons.schedule_rounded,
                              iconColor: _status == TransactionStatus.paid
                                  ? AppColors.emerald
                                  : AppColors.orange,
                              label: _status == TransactionStatus.paid
                                  ? 'Efetivado / Pago'
                                  : 'Pendente / Agendado',
                              subtitle: _status == TransactionStatus.paid
                                  ? 'Impacta o saldo disponível hoje'
                                  : 'Entra na projeção do fim do mês',
                              trailing: Switch.adaptive(
                                value: _status == TransactionStatus.paid,
                                activeTrackColor: AppColors.success(context),
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _status = val
                                        ? TransactionStatus.paid
                                        : TransactionStatus.pending;
                                  });
                                },
                              ),
                            ),
                            const Divider(indent: 62, height: 1),
                          ],
                          HigFormRow(
                            icon: Icons.repeat_rounded,
                            iconColor: AppColors.blue,
                            label: 'Repetição',
                            trailing: DropdownButton<RecurrenceRule>(
                              value: _recurrence,
                              underline: const SizedBox.shrink(),
                              items: RecurrenceRule.values
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(
                                        r.label,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _recurrence = v);
                              },
                            ),
                          ),
                          if (state.goals.isNotEmpty) ...[
                            const Divider(indent: 62, height: 1),
                            HigFormRow(
                              icon: Icons.savings_rounded,
                              iconColor: AppColors.success(context),
                              label: 'Vincular Caixinha',
                              subtitle: 'Soma no saldo da caixinha',
                              trailing: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 165),
                                child: DropdownButton<String?>(
                                  value: _selectedGoalId,
                                  isExpanded: true,
                                  underline: const SizedBox.shrink(),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text(
                                        'Nenhuma',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    ...state.goals.map(
                                      (g) => DropdownMenuItem<String?>(
                                        value: g.id,
                                        child: Text(
                                          g.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.success(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _selectedGoalId = v),
                                ),
                              ),
                            ),
                          ],
                          const Divider(indent: 62, height: 1),
                          HigFormRow(
                            icon: Icons.visibility_off_rounded,
                            iconColor: AppColors.warning(context),
                            label: 'Ignorar transação',
                            subtitle:
                                'Não conta em categorias, insights, saldos e totais',
                            trailing: Switch.adaptive(
                              value: _isIgnored,
                              onChanged: (v) => setState(() => _isIgnored = v),
                            ),
                          ),
                          const Divider(indent: 62, height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: AppColors.cyan
                                            .withValues(alpha: 0.13),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: const Icon(
                                        Icons.tag_rounded,
                                        color: AppColors.cyan,
                                        size: 19,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _tagInputCtrl,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Adicionar tag (ex: viagem, casa)',
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        onSubmitted: (val) {
                                          final clean =
                                              val.trim().replaceAll('#', '');
                                          if (clean.isNotEmpty &&
                                              !_tags.contains(clean)) {
                                            setState(() {
                                              _tags.add(clean);
                                              _tagInputCtrl.clear();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        final clean = _tagInputCtrl.text
                                            .trim()
                                            .replaceAll('#', '');
                                        if (clean.isNotEmpty &&
                                            !_tags.contains(clean)) {
                                          setState(() {
                                            _tags.add(clean);
                                            _tagInputCtrl.clear();
                                          });
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.add_circle_rounded,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_tags.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 46),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: _tags
                                          .map(
                                            (tag) => Chip(
                                              label: Text(
                                                '#$tag',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              onDeleted: () => setState(
                                                () => _tags.remove(tag),
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      ],
                      const SizedBox(height: 26),

                      // Botão Principal Apple HIG
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 21),
                          label: Text(
                            _isEditing
                                ? 'Salvar Alterações'
                                : 'Confirmar Lançamento',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }
}
