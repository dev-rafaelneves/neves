import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../services/import_service.dart';
import '../../theme/app_theme.dart';
import '../unified_import_screen.dart';

class CardsTab extends StatelessWidget {
  final AppState appState;

  const CardsTab({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final cards = appState.cards;
    final ym = appState.selectedYearMonth;
    final discreet = appState.discreetMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        HigSectionHeader(
          title: 'Seus Cartões de Crédito',
          trailing: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: () => showCardModal(context, appState),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Novo Cartão',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (cards.isEmpty)
          HigGroupedCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            children: [
              Icon(
                Icons.credit_card_off_rounded,
                size: 42,
                color: AppColors.textSecondary(context),
              ),
              const SizedBox(height: 10),
              Text(
                'Nenhum cartão cadastrado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cadastre seus cartões para controlar faturas e compras parceladas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: FilledButton.icon(
                  onPressed: () => showCardModal(context, appState),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Cadastrar Cartão'),
                ),
              ),
            ],
          )
        else
          for (final card in cards) ...[
            _CreditCardDetailCard(
              card: card,
              yearMonth: ym,
              invoiceTotal: appState.cardInvoiceTotal(card.id, ym),
              paidTotal: appState.cardPaidAmount(card.id, ym),
              remainingTotal:
                  appState.cardRemainingInvoiceAmount(card.id, ym),
              isPaid: appState.isCardInvoicePaid(card.id, ym),
              ownTotal: appState.cardOwnExpenseTotal(card.id, ym),
              ignoredTotal: appState.cardIgnoredExpenseTotal(card.id, ym),
              itemCount: appState.cardInvoiceCount(card.id, ym),
              discreet: discreet,
              onViewInvoice: () {
                HapticFeedback.selectionClick();
                appState.setActiveTab(1, filter: 'card:${card.id}');
              },
              onImportInvoice: () => UnifiedImportScreen.open(
                context,
                appState: appState,
                initialDestination: ImportDestinationType.creditCard,
                initialCardId: card.id,
              ),
              onPayInvoice: () => showPayInvoiceModal(
                context,
                appState,
                card: card,
                yearMonth: ym,
              ),
              onEdit: () => showCardModal(context, appState, existing: card),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  static Future<void> showCardModal(
    BuildContext context,
    AppState appState, {
    CreditCardItem? existing,
  }) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CardEditorSheet(
        appState: appState,
        existing: existing,
      ),
    );
  }

  static Future<void> showPayInvoiceModal(
    BuildContext context,
    AppState appState, {
    required CreditCardItem card,
    required String yearMonth,
  }) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PayInvoiceSheet(
        appState: appState,
        card: card,
        yearMonth: yearMonth,
      ),
    );
  }
}

class _CreditCardDetailCard extends StatelessWidget {
  final CreditCardItem card;
  final String yearMonth;
  final double invoiceTotal;
  final double paidTotal;
  final double remainingTotal;
  final bool isPaid;
  final double ownTotal;
  final double ignoredTotal;
  final int itemCount;
  final bool discreet;
  final VoidCallback onViewInvoice;
  final VoidCallback onImportInvoice;
  final VoidCallback onPayInvoice;
  final VoidCallback onEdit;

  const _CreditCardDetailCard({
    required this.card,
    required this.yearMonth,
    required this.invoiceTotal,
    required this.paidTotal,
    required this.remainingTotal,
    required this.isPaid,
    required this.ownTotal,
    required this.ignoredTotal,
    required this.itemCount,
    required this.discreet,
    required this.onViewInvoice,
    required this.onImportInvoice,
    required this.onPayInvoice,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasIgnored = ignoredTotal.abs() > 0.005;
    final hasPaid = paidTotal > 0.005;

    return HigGroupedCard(
      padding: const EdgeInsets.all(16),
      children: [
        // Linha 1: Ícone + Nome + Datas à esquerda | Botão Editar à direita
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: card.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.credit_card_rounded,
                color: card.color,
                size: 22,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fecha dia ${card.closingDay} • Vence dia ${card.dueDay}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text(
                'Editar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Linha 2: Resumo da Fatura do Mês + Ações em largura total (à prova de 360dp + 1.25x)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    isPaid
                        ? 'Fatura de ${AppFormatters.monthLabel(yearMonth, short: true)} • PAGA'
                        : 'Fatura Atual (${AppFormatters.monthLabel(yearMonth, short: true)} • $itemCount ${itemCount == 1 ? 'compra' : 'compras'})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPaid
                          ? AppColors.success(context)
                          : AppColors.textSecondary(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AppFormatters.currency(
                      remainingTotal,
                      discreet: discreet,
                    ),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isPaid
                          ? AppColors.success(context)
                          : (remainingTotal > 0
                              ? AppColors.danger(context)
                              : AppColors.textPrimary(context)),
                    ),
                  ),
                ),
              ],
            ),
            if (hasPaid || hasIgnored) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (hasPaid) ...[
                    HigInfoPill(
                      icon: Icons.shopping_bag_outlined,
                      text:
                          'Compras: ${AppFormatters.currency(invoiceTotal, discreet: discreet)}',
                      color: AppColors.textSecondary(context),
                    ),
                    HigInfoPill(
                      icon: Icons.check_circle_outline_rounded,
                      text:
                          'Pago/Antecipado: ${AppFormatters.currency(paidTotal, discreet: discreet)}',
                      color: AppColors.success(context),
                    ),
                  ],
                  if (hasIgnored) ...[
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
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onPayInvoice,
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Pagar Fatura',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onImportInvoice,
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Importar',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onViewInvoice,
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Ver Fatura',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CardEditorSheet extends StatefulWidget {
  final AppState appState;
  final CreditCardItem? existing;

  const _CardEditorSheet({
    required this.appState,
    this.existing,
  });

  @override
  State<_CardEditorSheet> createState() => _CardEditorSheetState();
}

class _CardEditorSheetState extends State<_CardEditorSheet> {
  late final TextEditingController _nameCtrl;
  late int _closingDay;
  late int _dueDay;
  late int _colorVal;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _closingDay = ex?.closingDay ?? 25;
    _dueDay = ex?.dueDay ?? 5;
    _colorVal = ex?.colorValue ?? AppColors.presetPalette.first.toARGB32();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Digite o nome do cartão.');
      return;
    }
    await widget.appState.saveCard(
      id: widget.existing?.id,
      name: name,
      colorValue: _colorVal,
      closingDay: _closingDay,
      dueDay: _dueDay,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ex = widget.existing;
    if (ex == null) return;
    await widget.appState.deleteCard(ex.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final ex = widget.existing;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ex == null ? 'Novo Cartão' : 'Editar Cartão',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (ex != null)
                    IconButton(
                      tooltip: 'Excluir Cartão',
                      onPressed: _delete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.danger(context),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                autofocus: ex == null,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Nome do Cartão (ex: Nubank, Itaú)',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DaySelectorBox(
                      label: 'Dia de Fechamento',
                      day: _closingDay,
                      onChanged: (d) => setState(() => _closingDay = d),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DaySelectorBox(
                      label: 'Dia de Vencimento',
                      day: _dueDay,
                      onChanged: (d) => setState(() => _dueDay = d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Cor do Cartão',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppColors.presetPalette.map((color) {
                  final val = color.toARGB32();
                  final selected = _colorVal == val;
                  return GestureDetector(
                    onTap: () => setState(() => _colorVal = val),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: AppColors.textPrimary(context),
                                width: 2.5,
                              )
                            : null,
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text(
                    'Salvar Cartão',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySelectorBox extends StatelessWidget {
  final String label;
  final int day;
  final ValueChanged<int> onChanged;

  const _DaySelectorBox({
    required this.label,
    required this.day,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onChanged(day <= 1 ? 31 : day - 1);
                },
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
              ),
              Text(
                'Dia $day',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onChanged(day >= 31 ? 1 : day + 1);
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayInvoiceSheet extends StatefulWidget {
  final AppState appState;
  final CreditCardItem card;
  final String yearMonth;

  const _PayInvoiceSheet({
    required this.appState,
    required this.card,
    required this.yearMonth,
  });

  @override
  State<_PayInvoiceSheet> createState() => _PayInvoiceSheetState();
}

class _PayInvoiceSheetState extends State<_PayInvoiceSheet> {
  late final TextEditingController _amountCtrl;
  String? _errorText;

  double get _purchasesTotal =>
      widget.appState.cardInvoiceTotal(widget.card.id, widget.yearMonth);
  double get _alreadyPaid =>
      widget.appState.cardPaidAmount(widget.card.id, widget.yearMonth);
  double get _remainingAmount => widget.appState
      .cardRemainingInvoiceAmount(widget.card.id, widget.yearMonth);

  @override
  void initState() {
    super.initState();
    final initialVal = _remainingAmount > 0 ? _remainingAmount : 0.0;
    _amountCtrl = TextEditingController(
      text: initialVal > 0
          ? CentavosCurrencyFormatter.formatDouble(initialVal)
          : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPayment({double? overrideAmount}) async {
    final val = overrideAmount ??
        CentavosCurrencyFormatter.parseValue(_amountCtrl.text);
    if (val <= 0) {
      setState(() => _errorText = 'Informe um valor maior que R\$ 0,00.');
      return;
    }

    final isFull =
        _remainingAmount > 0 && (val >= _remainingAmount - 0.009);

    HapticFeedback.mediumImpact();
    await widget.appState.registerCardInvoicePayment(
      cardId: widget.card.id,
      competenceMonth: widget.yearMonth,
      amount: val,
      isFullPayment: isFull,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final typedVal = CentavosCurrencyFormatter.parseValue(_amountCtrl.text);
    final remaining = _remainingAmount;
    final isFullSelected =
        remaining > 0 && (typedVal >= remaining - 0.009);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 22 + inset),
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.card.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.credit_card_rounded,
                      color: widget.card.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pagar Fatura • ${widget.card.name}',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Competência ${AppFormatters.monthLabel(widget.yearMonth, short: true)} • Total compras: ${AppFormatters.currency(_purchasesTotal)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Resumo Rápido de Saldo da Fatura
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.isDark(context)
                      ? AppColors.darkBackground
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border(context),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Já Pago / Antecipado',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        Text(
                          AppFormatters.currency(_alreadyPaid),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success(context),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Restante a Pagar no Banco',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        Text(
                          AppFormatters.currency(remaining),
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: remaining > 0.005
                                ? AppColors.danger(context)
                                : AppColors.success(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              HigCurrencyHeroField(
                controller: _amountCtrl,
                label: isFullSelected
                    ? 'Valor para Quitar Fatura Total'
                    : 'Valor do Pagamento Antecipado / Parcial',
                accentColor: AppColors.primary,
                onChanged: (_) {
                  setState(() => _errorText = null);
                },
                bottomAccessory: remaining > 0.005 && !isFullSelected
                    ? TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _amountCtrl.text =
                                CentavosCurrencyFormatter.formatDouble(
                              remaining,
                            );
                          });
                        },
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: Text(
                          'Preencher restante total (${AppFormatters.currency(remaining)})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
              const SizedBox(height: 16),

              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _submitPayment(),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    isFullSelected
                        ? 'Quitar Fatura Total (${AppFormatters.currency(typedVal)})'
                        : 'Registrar Pagamento Antecipado',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
