import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'tabs/cards_tab.dart';

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
    HapticFeedback.lightImpact();
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
  bool _isIgnored = false;
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
      _isIgnored = ex.isIgnored;
      _amountCtrl = TextEditingController(
        text: CentavosCurrencyFormatter.formatDouble(ex.amount.abs()),
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
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
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
        amount: ex.amount < 0 ? -amount : amount,
        date: _selectedDate,
        competenceMonth: effectiveCompetence,
        type: _type,
        paymentMethod: effectivePayment,
        categoryId: _selectedCategoryId,
        cardId: effectivePayment == PaymentMethod.creditCard
            ? _selectedCardId
            : null,
        isIgnored: _isIgnored,
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
        isIgnored: _isIgnored,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final ex = widget.existing;
    if (ex == null) return;
    HapticFeedback.lightImpact();

    if (ex.groupId != null) {
      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: AppColors.surface(ctx).withValues(alpha: 0.92),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
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
                        ex.isInstallment
                            ? 'Excluir Compra Parcelada (${ex.installmentIndex}/${ex.installmentTotal})'
                            : 'Excluir Lançamento Fixo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(ctx),
                          fontFeatures: AppTypography.tabular,
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
                            'Apagar somente deste mês',
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
                          color: AppColors.iosRed,
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(ctx).pop('future');
                          },
                          child: Text(
                            ex.isInstallment
                                ? 'Apagar esta e as próximas parcelas'
                                : 'Apagar este e os próximos meses',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isExpense = _type == TransactionType.expense;
    final isCreditCard =
        isExpense && _paymentMethod == PaymentMethod.creditCard;
    final accentColor = isExpense ? AppColors.iosRed : AppColors.iosGreen;
    final categories = widget.appState.categoriesByType(_type);
    final cards = widget.appState.cards;

    final typedAmount = CentavosCurrencyFormatter.parseValue(_amountCtrl.text);
    final perInstallment = (!_isEditing && isCreditCard && _installments > 1)
        ? (typedAmount / _installments)
        : typedAmount;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          decoration: BoxDecoration(
            color: AppColors.background(context).withValues(alpha: 0.94),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: AppColors.border(context),
                width: AppSpacing.hairlineBorder,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Grabber & Barra Superior Estilo Cupertino Modal
                    _SheetTopNavBar(
                      title:
                          _isEditing ? 'Editar Lançamento' : 'Novo Lançamento',
                      isEditing: _isEditing,
                      onCancel: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      onDelete: _confirmDelete,
                    ),
                    const SizedBox(height: 10),

                    // 2. Seletor Despesa vs Receita (CupertinoSlidingSegmentedControl)
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
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TransactionType.income: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Receita',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      },
                    ),
                    const SizedBox(height: 14),

                    // 3. Campo de Valor Hero com tabularFigures
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
                                      fontWeight: FontWeight.w600,
                                      color: accentColor,
                                      fontFeatures: AppTypography.tabular,
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

                    // 4. Descrição Rápida (Inset Grouped)
                    _DescriptionInputCard(
                      controller: _titleCtrl,
                      isExpense: isExpense,
                      onChanged: _onTitleChanged,
                    ),
                    const SizedBox(height: 16),

                    // 5. Forma de Pagamento (Apenas para Despesa)
                    if (isExpense) ...[
                      _PaymentMethodSelector(
                        paymentMethod: _paymentMethod,
                        selectedCardId: _selectedCardId,
                        cards: cards,
                        onManageCard: () async {
                          HapticFeedback.lightImpact();
                          final currentCard =
                              widget.appState.cardById(_selectedCardId);
                          await CardsTab.showCardModal(
                            context,
                            widget.appState,
                            existing:
                                _paymentMethod == PaymentMethod.creditCard
                                    ? currentCard
                                    : null,
                          );
                          if (mounted) {
                            setState(() {
                              if (_selectedCardId == null &&
                                  widget.appState.cards.isNotEmpty) {
                                _selectedCardId =
                                    widget.appState.cards.first.id;
                              }
                            });
                          }
                        },
                        onSelectCash: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _paymentMethod = PaymentMethod.cash;
                            _installments = 1;
                            if (!_userOverrodeInvoiceMonth) {
                              _invoiceMonth = _computeDefaultCompetenceMonth();
                            }
                          });
                        },
                        onSelectCard: (card) {
                          HapticFeedback.lightImpact();
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
                      const SizedBox(height: 16),
                    ],

                    // 6. Opções do Cartão de Crédito (1ª Fatura + Parcelas)
                    if (isCreditCard) ...[
                      _CreditCardInvoiceAndInstallmentsCard(
                        isEditing: _isEditing,
                        installments: _installments,
                        invoiceMonth: _invoiceMonth,
                        onPrevInvoiceMonth: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _userOverrodeInvoiceMonth = true;
                            _invoiceMonth =
                                AppFormatters.addMonths(_invoiceMonth, -1);
                          });
                        },
                        onNextInvoiceMonth: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _userOverrodeInvoiceMonth = true;
                            _invoiceMonth =
                                AppFormatters.addMonths(_invoiceMonth, 1);
                          });
                        },
                        onChangedInstallments: (n) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _installments = n;
                            if (_installments > 1) {
                              _isRecurring = false;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 7. Seleção Rápida de Categoria
                    const HigSectionHeader(title: 'Categoria'),
                    _CategorySelectorGrid(
                      categories: categories,
                      selectedCategoryId: _selectedCategoryId,
                      onSelectCategory: (catId) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedCategoryId = catId;
                          _userPickedCategory = true;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // 8. Data, Repetição Fixa e Toggle Ignorar (Inset Grouped)
                    _OptionsGroupedSection(
                      selectedDate: _selectedDate,
                      isEditing: _isEditing,
                      installments: _installments,
                      isCreditCard: isCreditCard,
                      isRecurring: _isRecurring,
                      isIgnored: _isIgnored,
                      hasGroupId:
                          _isEditing && widget.existing!.groupId != null,
                      applyToFuture: _applyToFuture,
                      onPickDate: _pickDate,
                      onToggleRecurring: (v) {
                        HapticFeedback.lightImpact();
                        setState(() => _isRecurring = v);
                      },
                      onToggleIgnored: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isIgnored = !_isIgnored);
                      },
                      onToggleApplyToFuture: (v) {
                        HapticFeedback.lightImpact();
                        setState(() => _applyToFuture = v);
                      },
                    ),
                    const SizedBox(height: 20),

                    // 9. Botão Principal de Confirmação
                    SizedBox(
                      height: 52,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: accentColor,
                        borderRadius: BorderRadius.circular(16),
                        onPressed: _submit,
                        child: Text(
                          _isEditing
                              ? 'Salvar Alterações'
                              : 'Adicionar Lançamento',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
      ),
    );
  }
}

/// 1. Grabber & Barra Superior do Modal
class _SheetTopNavBar extends StatelessWidget {
  final String title;
  final bool isEditing;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _SheetTopNavBar({
    required this.title,
    required this.isEditing,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary(context).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              minimumSize: Size.zero,
              onPressed: onCancel,
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.iosBlue,
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppColors.textPrimary(context),
              ),
            ),
            if (isEditing)
              Tooltip(
                message: 'Excluir',
                child: GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: const HigIconSquircle(
                    icon: CupertinoIcons.trash,
                    color: AppColors.iosRed,
                    size: 34,
                    iconSize: 17,
                    radius: 10,
                  ),
                ),
              )
            else
              const SizedBox(width: 58),
          ],
        ),
      ],
    );
  }
}

/// 4. Card Agrupado de Descrição
class _DescriptionInputCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isExpense;
  final ValueChanged<String> onChanged;

  const _DescriptionInputCard({
    required this.controller,
    required this.isExpense,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return HigGroupedCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      children: [
        Row(
          children: [
            const HigIconSquircle(
              icon: CupertinoIcons.pencil,
              color: AppColors.iosBlue,
              size: 32,
              iconSize: 16,
              radius: 9,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: isExpense
                      ? 'Descrição (ex: Mercado, Uber, Luz...)'
                      : 'Descrição (ex: Salário, Pix recebido...)',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 5. Seletor de Forma de Pagamento (Conta Corrente vs Cartões)
class _PaymentMethodSelector extends StatelessWidget {
  final PaymentMethod paymentMethod;
  final String? selectedCardId;
  final List<CreditCardItem> cards;
  final VoidCallback onManageCard;
  final VoidCallback onSelectCash;
  final ValueChanged<CreditCardItem> onSelectCard;

  const _PaymentMethodSelector({
    required this.paymentMethod,
    required this.selectedCardId,
    required this.cards,
    required this.onManageCard,
    required this.onSelectCash,
    required this.onSelectCard,
  });

  @override
  Widget build(BuildContext context) {
    final isCardSelected =
        paymentMethod == PaymentMethod.creditCard && selectedCardId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HigSectionHeader(
          title: 'Como pagou?',
          trailing: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: Size.zero,
            onPressed: onManageCard,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCardSelected
                      ? CupertinoIcons.slider_horizontal_3
                      : CupertinoIcons.add_circled,
                  size: 14,
                  color: AppColors.iosBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  isCardSelected ? 'Editar Cartão' : 'Novo Cartão',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.iosBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PaymentChoiceChip(
              label: 'Conta Corrente',
              icon: CupertinoIcons.building_2_fill,
              color: AppColors.iosBlue,
              selected: paymentMethod == PaymentMethod.cash,
              onTap: onSelectCash,
            ),
            for (final card in cards)
              _PaymentChoiceChip(
                label: card.name,
                icon: CupertinoIcons.creditcard_fill,
                color: card.color,
                selected: paymentMethod == PaymentMethod.creditCard &&
                    selectedCardId == card.id,
                onTap: () => onSelectCard(card),
              ),
          ],
        ),
      ],
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? color : AppColors.border(context),
            width: selected ? 1.4 : AppSpacing.hairlineBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HigIconSquircle(
              icon: icon,
              color: color,
              size: 26,
              iconSize: 14,
              radius: 7,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 6. Opções do Cartão de Crédito (1ª Fatura + Parcelas com tabularFigures)
class _CreditCardInvoiceAndInstallmentsCard extends StatelessWidget {
  final bool isEditing;
  final int installments;
  final String invoiceMonth;
  final VoidCallback onPrevInvoiceMonth;
  final VoidCallback onNextInvoiceMonth;
  final ValueChanged<int> onChangedInstallments;

  const _CreditCardInvoiceAndInstallmentsCard({
    required this.isEditing,
    required this.installments,
    required this.invoiceMonth,
    required this.onPrevInvoiceMonth,
    required this.onNextInvoiceMonth,
    required this.onChangedInstallments,
  });

  @override
  Widget build(BuildContext context) {
    return HigGroupedCard(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              const HigIconSquircle(
                icon: CupertinoIcons.doc_text_fill,
                color: AppColors.iosIndigo,
                size: 34,
                iconSize: 17,
                radius: 9,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !isEditing && installments > 1
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
              GestureDetector(
                onTap: onPrevInvoiceMonth,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(CupertinoIcons.chevron_left, size: 17),
                ),
              ),
              Text(
                AppFormatters.monthLabel(invoiceMonth, short: true),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              GestureDetector(
                onTap: onNextInvoiceMonth,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(CupertinoIcons.chevron_right, size: 17),
                ),
              ),
            ],
          ),
        ),
        if (!isEditing) ...[
          Divider(
            height: 1,
            thickness: AppSpacing.hairlineBorder,
            indent: 58,
            color: AppColors.border(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      value: installments,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      items: List.generate(24, (i) => i + 1)
                          .map(
                            (n) => DropdownMenuItem(
                              value: n,
                              child: Text(
                                n == 1 ? '1x (À vista)' : '${n}x sem juros',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: AppTypography.tabular,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) onChangedInstallments(v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [1, 2, 3, 4, 6, 10, 12].map((n) {
                      final selected = installments == n;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => onChangedInstallments(n),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.iosIndigo
                                  : AppColors.secondarySurface(context),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppColors.iosIndigo
                                    : AppColors.border(context),
                                width: AppSpacing.hairlineBorder,
                              ),
                            ),
                            child: Text(
                              n == 1 ? '1x' : '${n}x',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary(context),
                                fontFeatures: AppTypography.tabular,
                              ),
                            ),
                          ),
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
    );
  }
}

/// 7. Grade de Seleção Rápida de Categoria com Squircles 12%
class _CategorySelectorGrid extends StatelessWidget {
  final List<CategoryItem> categories;
  final String selectedCategoryId;
  final ValueChanged<String> onSelectCategory;

  const _CategorySelectorGrid({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final selected = selectedCategoryId == cat.id;
        return GestureDetector(
          onTap: () => onSelectCategory(cat.id),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? cat.color.withValues(alpha: 0.15)
                  : AppColors.surface(context),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? cat.color : AppColors.border(context),
                width: selected ? 1.4 : AppSpacing.hairlineBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HigIconSquircle(
                  icon: cat.icon,
                  color: cat.color,
                  size: 26,
                  iconSize: 14,
                  radius: 7,
                ),
                const SizedBox(width: 7),
                Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 8. Bloco Agrupado de Data, Repetição Fixa e Toggle Ignorar
class _OptionsGroupedSection extends StatelessWidget {
  final DateTime selectedDate;
  final bool isEditing;
  final int installments;
  final bool isCreditCard;
  final bool isRecurring;
  final bool isIgnored;
  final bool hasGroupId;
  final bool applyToFuture;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onToggleRecurring;
  final VoidCallback onToggleIgnored;
  final ValueChanged<bool> onToggleApplyToFuture;

  const _OptionsGroupedSection({
    required this.selectedDate,
    required this.isEditing,
    required this.installments,
    required this.isCreditCard,
    required this.isRecurring,
    required this.isIgnored,
    required this.hasGroupId,
    required this.applyToFuture,
    required this.onPickDate,
    required this.onToggleRecurring,
    required this.onToggleIgnored,
    required this.onToggleApplyToFuture,
  });

  @override
  Widget build(BuildContext context) {
    return HigGroupedCard(
      children: [
        GestureDetector(
          onTap: onPickDate,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                const HigIconSquircle(
                  icon: CupertinoIcons.calendar,
                  color: AppColors.iosBlue,
                  size: 32,
                  iconSize: 16,
                  radius: 9,
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
                  AppFormatters.shortDate(selectedDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.iosBlue,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isEditing && installments == 1) ...[
          Divider(
            height: 1,
            thickness: AppSpacing.hairlineBorder,
            indent: 58,
            color: AppColors.border(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const HigIconSquircle(
                  icon: CupertinoIcons.repeat,
                  color: AppColors.iosGreen,
                  size: 32,
                  iconSize: 16,
                  radius: 9,
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
                CupertinoSwitch(
                  value: isRecurring,
                  activeTrackColor: AppColors.iosGreen,
                  onChanged: onToggleRecurring,
                ),
              ],
            ),
          ),
        ],
        Divider(
          height: 1,
          thickness: AppSpacing.hairlineBorder,
          indent: 58,
          color: AppColors.border(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              HigIconSquircle(
                icon: isIgnored
                    ? CupertinoIcons.eye_slash_fill
                    : CupertinoIcons.eye_slash,
                color: isIgnored
                    ? AppColors.iosOrange
                    : AppColors.textSecondary(context),
                size: 32,
                iconSize: 16,
                radius: 9,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ignorar do meu resumo',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      isCreditCard
                          ? 'Continua na fatura do cartão, mas não entra nas suas despesas/categorias'
                          : 'Não soma nas suas despesas, receitas ou gráficos',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onToggleIgnored,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isIgnored
                        ? AppColors.iosOrange
                        : AppColors.iosOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isIgnored
                          ? AppColors.iosOrange
                          : AppColors.border(context),
                      width: AppSpacing.hairlineBorder,
                    ),
                  ),
                  child: Text(
                    'Ignorar',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isIgnored
                          ? Colors.white
                          : AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasGroupId) ...[
          Divider(
            height: 1,
            thickness: AppSpacing.hairlineBorder,
            indent: 58,
            color: AppColors.border(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const HigIconSquircle(
                  icon: CupertinoIcons.arrow_2_circlepath,
                  color: AppColors.iosBlue,
                  size: 32,
                  iconSize: 16,
                  radius: 9,
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
                CupertinoSwitch(
                  value: applyToFuture,
                  activeTrackColor: AppColors.iosGreen,
                  onChanged: onToggleApplyToFuture,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
