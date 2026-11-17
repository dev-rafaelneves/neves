import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'tabs/cards_settings_tab.dart';

class TransactionFormSheet extends StatefulWidget {
  final AppState appState;
  final TransactionItem? existing;
  final TransactionType? initialType;
  final String? initialCardId;

  const TransactionFormSheet({
    super.key,
    required this.appState,
    this.existing,
    this.initialType,
    this.initialCardId,
  });

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    TransactionItem? existing,
    TransactionType? initialType,
    String? initialCardId,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionFormSheet(
        appState: appState,
        existing: existing,
        initialType: initialType,
        initialCardId: initialCardId,
      ),
    );
  }

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _titleCtrl;

  late TransactionType _type;
  late PaymentMethod _paymentMethod;
  String? _selectedCardId;
  late String _selectedCategoryId;
  late DateTime _selectedDate;
  late String _invoiceMonth; // 'YYYY-MM'
  bool _userOverrodeInvoiceMonth = false;
  bool _userPickedCategory = false;

  int _installments = 1;
  bool _isRecurring = false;
  bool _applyToFuture = false;
  String? _errorText;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _type = ex.type;
      _paymentMethod = ex.paymentMethod;
      _selectedCardId = ex.cardId ??
          (widget.appState.cards.isNotEmpty
              ? widget.appState.cards.first.id
              : null);
      _selectedCategoryId = ex.categoryId;
      _selectedDate = ex.date;
      _invoiceMonth = ex.competenceMonth;
      _userOverrodeInvoiceMonth = true;
      _userPickedCategory = true;
      _installments = ex.installmentTotal;
      _isRecurring = ex.isRecurring;
      _amountCtrl = TextEditingController(
        text: CentavosCurrencyFormatter.formatDouble(ex.amount),
      );
      _titleCtrl = TextEditingController(text: ex.title);
    } else {
      _type = widget.initialType ?? TransactionType.expense;
      if (widget.initialCardId != null) {
        _paymentMethod = PaymentMethod.creditCard;
        _selectedCardId = widget.initialCardId;
      } else {
        _paymentMethod = PaymentMethod.cash;
        _selectedCardId = widget.appState.cards.isNotEmpty
            ? widget.appState.cards.first.id
            : null;
      }

      final cats = widget.appState.categoriesByType(_type);
      _selectedCategoryId =
          cats.isNotEmpty ? cats.first.id : 'cat_other_exp';

      final now = DateTime.now();
      final currentYm = AppFormatters.yearMonthFromDate(now);
      if (widget.appState.selectedYearMonth == currentYm) {
        _selectedDate = now;
      } else {
        final parts = widget.appState.selectedYearMonth.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final maxDay = DateTime(y, m + 1, 0).day;
        _selectedDate = DateTime(y, m, now.day.clamp(1, maxDay));
      }

      _invoiceMonth = _computeDefaultCompetenceMonth();
      _amountCtrl = TextEditingController();
      _titleCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  String _computeDefaultCompetenceMonth() {
    if (_type == TransactionType.expense &&
        _paymentMethod == PaymentMethod.creditCard &&
        _selectedCardId != null) {
      final card = widget.appState.cardById(_selectedCardId);
      if (card != null) {
        return card.suggestInvoiceMonth(_selectedDate);
      }
    }
    return AppFormatters.yearMonthFromDate(_selectedDate);
  }

  void _onTitleChanged(String text) {
    if (_userPickedCategory || _isEditing) return;
    final lower = text.toLowerCase();
    String? suggestedId;
    if (_type == TransactionType.expense) {
      if (lower.contains('mercado') ||
          lower.contains('ifood') ||
          lower.contains('padaria') ||
          lower.contains('almoço') ||
          lower.contains('jantar') ||
          lower.contains('restaurante') ||
          lower.contains('lanche') ||
          lower.contains('açougue')) {
        suggestedId = 'cat_food';
      } else if (lower.contains('uber') ||
          lower.contains('99') ||
          lower.contains('gasolina') ||
          lower.contains('combust') ||
          lower.contains('estacionamento') ||
          lower.contains('pedágio') ||
          lower.contains('onibus') ||
          lower.contains('metrô')) {
        suggestedId = 'cat_transport';
      } else if (lower.contains('aluguel') ||
          lower.contains('condom') ||
          lower.contains('luz') ||
          lower.contains('energia') ||
          lower.contains('água') ||
          lower.contains('internet') ||
          lower.contains('gás')) {
        suggestedId = 'cat_home';
      } else if (lower.contains('farmácia') ||
          lower.contains('remédio') ||
          lower.contains('médico') ||
          lower.contains('exame') ||
          lower.contains('consulta') ||
          lower.contains('dentista')) {
        suggestedId = 'cat_health';
      } else if (lower.contains('netflix') ||
          lower.contains('spotify') ||
          lower.contains('icloud') ||
          lower.contains('amazon prime') ||
          lower.contains('youtube') ||
          lower.contains('assinatura')) {
        suggestedId = 'cat_subs';
      } else if (lower.contains('cinema') ||
          lower.contains('bar') ||
          lower.contains('show') ||
          lower.contains('viagem') ||
          lower.contains('passeio')) {
        suggestedId = 'cat_leisure';
      } else if (lower.contains('roupa') ||
          lower.contains('shopee') ||
          lower.contains('mercado livre') ||
          lower.contains('amazon') ||
          lower.contains('presente')) {
        suggestedId = 'cat_shopping';
      }
    } else {
      if (lower.contains('salário') ||
          lower.contains('adiantamento') ||
          lower.contains(' décimo') ||
          lower.contains('13')) {
        suggestedId = 'cat_salary';
      } else if (lower.contains('dividendo') ||
          lower.contains('rendimento') ||
          lower.contains('juros')) {
        suggestedId = 'cat_invest_inc';
      } else if (lower.contains('freela') ||
          lower.contains('pix') ||
          lower.contains('venda')) {
        suggestedId = 'cat_extra';
      }
    }

    if (suggestedId != null &&
        widget.appState.categories.any((c) => c.id == suggestedId)) {
      setState(() => _selectedCategoryId = suggestedId!);
    }
  }

  void _switchType(TransactionType newType) {
    if (_type == newType) return;
    HapticFeedback.selectionClick();
    setState(() {
      _type = newType;
      if (_type == TransactionType.income) {
        _paymentMethod = PaymentMethod.cash;
        _installments = 1;
      }
      final cats = widget.appState.categoriesByType(_type);
      if (cats.isNotEmpty && !cats.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = cats.first.id;
      }
      if (!_userOverrodeInvoiceMonth) {
        _invoiceMonth = _computeDefaultCompetenceMonth();
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        if (!_userOverrodeInvoiceMonth) {
          _invoiceMonth = _computeDefaultCompetenceMonth();
        }
      });
    }
  }

  Future<void> _submit() async {
    final amount = CentavosCurrencyFormatter.parseValue(_amountCtrl.text);
    if (amount <= 0) {
      setState(() => _errorText = 'Informe um valor maior que R\$ 0,00.');
      return;
    }

    final cat = widget.appState.categoryById(_selectedCategoryId);
    final finalTitle =
        _titleCtrl.text.trim().isEmpty ? cat.name : _titleCtrl.text.trim();

    if (_type == TransactionType.expense &&
        _paymentMethod == PaymentMethod.creditCard &&
        _selectedCardId == null) {
      setState(() => _errorText = 'Cadastre ou selecione um cartão de crédito.');
      return;
    }

    HapticFeedback.lightImpact();

    final ex = widget.existing;
    if (ex != null) {
      final effectivePayment =
          _type == TransactionType.income ? PaymentMethod.cash : _paymentMethod;
      final effectiveCompetence =
          effectivePayment == PaymentMethod.creditCard
              ? _invoiceMonth
              : AppFormatters.yearMonthFromDate(_selectedDate);

      final updated = ex.copyWith(
        title: finalTitle,
        amount: amount,
        date: _selectedDate,
        competenceMonth: effectiveCompetence,
        type: _type,
        paymentMethod: effectivePayment,
        categoryId: _selectedCategoryId,
        cardId: effectivePayment == PaymentMethod.creditCard
            ? _selectedCardId
            : null,
      );
      await widget.appState.updateTransaction(
        updated,
        applyToFutureInGroup: _applyToFuture,
      );
    } else {
      final effectivePayment =
          _type == TransactionType.income ? PaymentMethod.cash : _paymentMethod;
      final firstCompetence = effectivePayment == PaymentMethod.creditCard
          ? _invoiceMonth
          : AppFormatters.yearMonthFromDate(_selectedDate);

      await widget.appState.createTransaction(
        title: finalTitle,
        totalAmount: amount,
        date: _selectedDate,
        type: _type,
        paymentMethod: effectivePayment,
        categoryId: _selectedCategoryId,
        cardId: _selectedCardId,
        firstCompetenceMonth: firstCompetence,
        installments:
            effectivePayment == PaymentMethod.creditCard ? _installments : 1,
        isRecurring: _installments == 1 && _isRecurring,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final ex = widget.existing;
    if (ex == null) return;

    if (ex.groupId != null) {
      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.surface(ctx),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ex.isInstallment
                        ? 'Excluir Compra Parcelada (${ex.installmentIndex}/${ex.installmentTotal})'
                        : 'Excluir Lançamento Fixo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop('single'),
                      child: const Text('Apagar somente deste mês'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rose,
                      ),
                      onPressed: () => Navigator.of(ctx).pop('future'),
                      child: Text(
                        ex.isInstallment
                            ? 'Apagar esta e as próximas parcelas'
                            : 'Apagar este e os próximos meses',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (action == null) return;
      await widget.appState.deleteTransaction(
        ex,
        deleteFutureInGroup: action == 'future',
      );
      if (mounted) Navigator.of(context).pop();
    } else {
      await widget.appState.deleteTransaction(ex);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isExpense = _type == TransactionType.expense;
    final isCreditCard =
        isExpense && _paymentMethod == PaymentMethod.creditCard;
    final accentColor = isExpense ? AppColors.rose : AppColors.primary;
    final categories = widget.appState.categoriesByType(_type);
    final cards = widget.appState.cards;

    final typedAmount = CentavosCurrencyFormatter.parseValue(_amountCtrl.text);
    final perInstallment = (!_isEditing && isCreditCard && _installments > 1)
        ? (typedAmount / _installments)
        : typedAmount;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle e Cabeçalho
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    Text(
                      _isEditing ? 'Editar Lançamento' : 'Novo Lançamento',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (_isEditing)
                      IconButton(
                        tooltip: 'Excluir',
                        onPressed: _confirmDelete,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger(context),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),

                // Seletor Despesa vs Receita
                CupertinoSlidingSegmentedControl<TransactionType>(
                  groupValue: _type,
                  onValueChanged: (v) {
                    if (v != null) _switchType(v);
                  },
                  children: const {
                    TransactionType.expense: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Despesa',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TransactionType.income: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Receita',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  },
                ),
                const SizedBox(height: 14),

                // Campo de Valor Hero
                HigCurrencyHeroField(
                  controller: _amountCtrl,
                  autofocus: !_isEditing,
                  label: (!_isEditing && isCreditCard && _installments > 1)
                      ? 'Valor Total da Compra'
                      : (_isEditing && widget.existing!.isInstallment
                          ? 'Valor da Parcela (${widget.existing!.installmentIndex}/${widget.existing!.installmentTotal})'
                          : 'Valor do Lançamento'),
                  accentColor: accentColor,
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    } else {
                      setState(() {});
                    }
                  },
                  bottomAccessory:
                      (!_isEditing && isCreditCard && _installments > 1)
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                '$_installments x de ${AppFormatters.currency(perInstallment)} • 1ª em ${AppFormatters.monthLabel(_invoiceMonth, short: true)}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            )
                          : null,
                ),

                if (_errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorText!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger(context),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Descrição rápida
                HigGroupedCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      onChanged: _onTitleChanged,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        icon: Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.textSecondary(context),
                        ),
                        hintText: isExpense
                            ? 'Descrição (ex: Mercado, Uber, Luz...)'
                            : 'Descrição (ex: Salário, Pix recebido...)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Forma de Pagamento (Apenas para Despesa)
                if (isExpense) ...[
                  HigSectionHeader(
                    title: 'Como pagou?',
                    trailing: TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () async {
                        final currentCard =
                            widget.appState.cardById(_selectedCardId);
                        await CardsSettingsTab.showCardModal(
                          context,
                          widget.appState,
                          existing: _paymentMethod == PaymentMethod.creditCard
                              ? currentCard
                              : null,
                        );
                        if (mounted) {
                          setState(() {
                            if (_selectedCardId == null &&
                                widget.appState.cards.isNotEmpty) {
                              _selectedCardId = widget.appState.cards.first.id;
                            }
                          });
                        }
                      },
                      icon: Icon(
                        _paymentMethod == PaymentMethod.creditCard &&
                                _selectedCardId != null
                            ? Icons.edit_outlined
                            : Icons.add_card_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _paymentMethod == PaymentMethod.creditCard &&
                                _selectedCardId != null
                            ? 'Editar Cartão'
                            : 'Novo Cartão',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PaymentChoiceChip(
                        label: 'À Vista (Pix / Débito)',
                        icon: Icons.bolt_rounded,
                        color: AppColors.primary,
                        selected: _paymentMethod == PaymentMethod.cash,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _paymentMethod = PaymentMethod.cash;
                            _installments = 1;
                            if (!_userOverrodeInvoiceMonth) {
                              _invoiceMonth = _computeDefaultCompetenceMonth();
                            }
                          });
                        },
                      ),
                      for (final card in cards)
                        _PaymentChoiceChip(
                          label: card.name,
                          icon: Icons.credit_card_rounded,
                          color: card.color,
                          selected:
                              _paymentMethod == PaymentMethod.creditCard &&
                                  _selectedCardId == card.id,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _paymentMethod = PaymentMethod.creditCard;
                              _selectedCardId = card.id;
                              if (!_userOverrodeInvoiceMonth) {
                                _invoiceMonth =
                                    card.suggestInvoiceMonth(_selectedDate);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Opções do Cartão de Crédito (1ª Fatura + Parcelas)
                if (isCreditCard) ...[
                  HigGroupedCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.purple.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                size: 19,
                                color: AppColors.purple,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    !_isEditing && _installments > 1
                                        ? 'Mês da 1ª Fatura'
                                        : 'Fatura do Cartão',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                  Text(
                                    'Ajuste se o banco fechou em outro dia',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _userOverrodeInvoiceMonth = true;
                                  _invoiceMonth =
                                      AppFormatters.addMonths(_invoiceMonth, -1);
                                });
                              },
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Text(
                              AppFormatters.monthLabel(
                                _invoiceMonth,
                                short: true,
                              ),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _userOverrodeInvoiceMonth = true;
                                  _invoiceMonth =
                                      AppFormatters.addMonths(_invoiceMonth, 1);
                                });
                              },
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                      if (!_isEditing) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Parcelamento',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                  DropdownButton<int>(
                                    value: _installments,
                                    isDense: true,
                                    underline: const SizedBox.shrink(),
                                    items: List.generate(24, (i) => i + 1)
                                        .map(
                                          (n) => DropdownMenuItem(
                                            value: n,
                                            child: Text(
                                              n == 1
                                                  ? '1x (À vista)'
                                                  : '${n}x sem juros',
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v == null) return;
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _installments = v;
                                        if (_installments > 1) {
                                          _isRecurring = false;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [1, 2, 3, 4, 6, 10, 12].map((n) {
                                    final selected = _installments == n;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(n == 1 ? '1x' : '${n}x'),
                                        selected: selected,
                                        showCheckmark: false,
                                        onSelected: (_) {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _installments = n;
                                            if (_installments > 1) {
                                              _isRecurring = false;
                                            }
                                          });
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Seleção Rápida de Categoria
                const HigSectionHeader(title: 'Categoria'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    final selected = _selectedCategoryId == cat.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedCategoryId = cat.id;
                          _userPickedCategory = true;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? cat.color.withValues(alpha: 0.18)
                              : AppColors.surface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? cat.color
                                : AppColors.border(context),
                            width: selected ? 1.5 : 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 17, color: cat.color),
                            const SizedBox(width: 6),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Data & Repetição Mensal Fixa
                HigGroupedCard(
                  children: [
                    InkWell(
                      onTap: _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 19,
                              color: AppColors.textSecondary(context),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Data',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              AppFormatters.shortDate(_selectedDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_isEditing && _installments == 1) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              size: 20,
                              color: AppColors.textSecondary(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Repetir todo mês (Fixa)',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Para aluguel, internet, assinatura ou salário',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _isRecurring,
                              activeColor: AppColors.primary,
                              onChanged: (v) {
                                HapticFeedback.selectionClick();
                                setState(() => _isRecurring = v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_isEditing && widget.existing!.groupId != null) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.sync_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Aplicar também aos próximos meses/parcelas',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: _applyToFuture,
                              activeColor: AppColors.primary,
                              onChanged: (v) =>
                                  setState(() => _applyToFuture = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),

                // Botão Salvar
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _submit,
                    child: Text(
                      _isEditing ? 'Salvar Alterações' : 'Adicionar Lançamento',
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
    );
  }
}

class _PaymentChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentChoiceChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.border(context),
            width: selected ? 1.6 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
