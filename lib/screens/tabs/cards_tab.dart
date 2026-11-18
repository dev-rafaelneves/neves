import 'dart:ui';
import 'package:flutter/cupertino.dart';
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        120,
      ),
      children: [
        HigSectionHeader(
          title: 'Seus Cartões de Crédito',
          trailing: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              showCardModal(context, appState);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.iosBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.add,
                    size: 14,
                    color: AppColors.iosBlue,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Novo Cartão',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.iosBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (cards.isEmpty)
          _EmptyCardsState(
            onAddCard: () {
              HapticFeedback.lightImpact();
              showCardModal(context, appState);
            },
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
                HapticFeedback.lightImpact();
                appState.setActiveTab(1, filter: 'card:${card.id}');
              },
              onImportInvoice: () {
                HapticFeedback.lightImpact();
                UnifiedImportScreen.open(
                  context,
                  appState: appState,
                  initialDestination: ImportDestinationType.creditCard,
                  initialCardId: card.id,
                );
              },
              onPayInvoice: () {
                HapticFeedback.lightImpact();
                showPayInvoiceModal(
                  context,
                  appState,
                  card: card,
                  yearMonth: ym,
                );
              },
              onEdit: () {
                HapticFeedback.lightImpact();
                showCardModal(context, appState, existing: card);
              },
            ),
            const SizedBox(height: 14),
          ],
      ],
    );
  }

  static Future<void> showCardModal(
    BuildContext context,
    AppState appState, {
    CreditCardItem? existing,
  }) async {
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
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

/// 1. Estado Vazio Estilo Apple Wallet
class _EmptyCardsState extends StatelessWidget {
  final VoidCallback onAddCard;

  const _EmptyCardsState({required this.onAddCard});

  @override
  Widget build(BuildContext context) {
    return HigGroupedCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      children: [
        Column(
          children: [
            const HigIconSquircle(
              icon: CupertinoIcons.creditcard_fill,
              color: AppColors.iosIndigo,
              size: 48,
              iconSize: 24,
              radius: 14,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhum cartão cadastrado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
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
            const SizedBox(height: 16),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              color: AppColors.iosBlue,
              borderRadius: BorderRadius.circular(14),
              onPressed: onAddCard,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.add, size: 17, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Cadastrar Cartão',
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
    );
  }
}

/// 2. Card Detalhado do Cartão de Crédito Estilo Apple Wallet / Copilot Money
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

    final amountColor = isPaid
        ? AppColors.success(context)
        : (remainingTotal > 0
            ? AppColors.danger(context)
            : AppColors.textPrimary(context));

    return HigGroupedCard(
      borderRadius: AppSpacing.heroRadius,
      padding: const EdgeInsets.all(18),
      children: [
        // Linha 1: Squircle 12% + Nome + Datas à esquerda | Botão Editar à direita
        Row(
          children: [
            HigIconSquircle(
              icon: CupertinoIcons.creditcard_fill,
              color: card.color,
              size: 42,
              iconSize: 21,
              radius: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
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
            GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.border(context),
                    width: AppSpacing.hairlineBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.slider_horizontal_3,
                      size: 13.5,
                      color: AppColors.textPrimary(context),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Editar',
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
        const SizedBox(height: 14),
        Divider(
          height: 1,
          thickness: AppSpacing.hairlineBorder,
          color: AppColors.border(context),
        ),
        const SizedBox(height: 14),

        // Linha 2: Resumo da Fatura do Mês com tabularFigures
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
                      fontWeight: FontWeight.w600,
                      color: isPaid
                          ? AppColors.success(context)
                          : AppColors.textSecondary(context),
                      fontFeatures: AppTypography.tabular,
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
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: amountColor,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ),
              ],
            ),
            if (hasPaid || hasIgnored) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (hasPaid) ...[
                    HigInfoPill(
                      icon: CupertinoIcons.bag_fill,
                      text:
                          'Compras: ${AppFormatters.currency(invoiceTotal, discreet: discreet)}',
                      color: AppColors.textSecondary(context),
                    ),
                    HigInfoPill(
                      icon: CupertinoIcons.checkmark_circle_fill,
                      text:
                          'Pago/Antecipado: ${AppFormatters.currency(paidTotal, discreet: discreet)}',
                      color: AppColors.success(context),
                    ),
                  ],
                  if (hasIgnored) ...[
                    HigInfoPill(
                      icon: CupertinoIcons.person_fill,
                      text:
                          'Seus gastos: ${AppFormatters.currency(ownTotal, discreet: discreet)}',
                      color: AppColors.iosGreen,
                    ),
                    HigInfoPill(
                      icon: CupertinoIcons.eye_slash_fill,
                      text:
                          'Ignorados: ${AppFormatters.currency(ignoredTotal, discreet: discreet)}',
                      color: AppColors.iosOrange,
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 14),

            // 3 Botões de Ação Minimalistas com Squircles 12%
            Row(
              children: [
                Expanded(
                  child: _CardActionPillButton(
                    label: 'Pagar Fatura',
                    icon: CupertinoIcons.checkmark_seal_fill,
                    color: AppColors.iosGreen,
                    onTap: onPayInvoice,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CardActionPillButton(
                    label: 'Importar',
                    icon: CupertinoIcons.tray_arrow_down_fill,
                    color: AppColors.iosBlue,
                    onTap: onImportInvoice,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CardActionPillButton(
                    label: 'Ver Fatura',
                    icon: CupertinoIcons.doc_text_fill,
                    color: card.color,
                    onTap: onViewInvoice,
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

class _CardActionPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CardActionPillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.secondarySurface(context).withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border(context),
            width: AppSpacing.hairlineBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HigIconSquircle(
              icon: icon,
              color: color,
              size: 24,
              iconSize: 13,
              radius: 7,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3. Modal Translúcido de Criação / Edição de Cartão
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
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
    await widget.appState.deleteCard(ex.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final ex = widget.existing;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 22 + inset),
          decoration: BoxDecoration(
            color: AppColors.surface(context).withValues(alpha: 0.94),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary(context)
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ex == null ? 'Novo Cartão' : 'Editar Cartão',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (ex != null)
                        Tooltip(
                          message: 'Excluir Cartão',
                          child: GestureDetector(
                            onTap: _delete,
                            behavior: HitTestBehavior.opaque,
                            child: const HigIconSquircle(
                              icon: CupertinoIcons.trash,
                              color: AppColors.iosRed,
                              size: 34,
                              iconSize: 17,
                              radius: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondarySurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _errorText != null
                            ? AppColors.iosRed
                            : AppColors.border(context),
                        width: AppSpacing.hairlineBorder,
                      ),
                    ),
                    child: TextField(
                      controller: _nameCtrl,
                      autofocus: ex == null,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Nome do Cartão (ex: Nubank, Itaú)',
                        errorText: _errorText,
                        border: InputBorder.none,
                        isDense: true,
                      ),
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
                  const SizedBox(height: 16),
                  Text(
                    'COR DO CARTÃO',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: AppColors.presetPalette.map((color) {
                      final val = color.toARGB32();
                      final selected = _colorVal == val;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _colorVal = val);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
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
                                  CupertinoIcons.checkmark_alt,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: AppColors.iosBlue,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _save,
                      child: const Text(
                        'Salvar Cartão',
                        style: TextStyle(
                          fontSize: 15.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border(context),
          width: AppSpacing.hairlineBorder,
        ),
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onChanged(day <= 1 ? 31 : day - 1);
                },
                behavior: HitTestBehavior.opaque,
                child: const HigIconSquircle(
                  icon: CupertinoIcons.minus,
                  color: AppColors.iosBlue,
                  size: 28,
                  iconSize: 14,
                  radius: 8,
                ),
              ),
              Text(
                'Dia $day',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onChanged(day >= 31 ? 1 : day + 1);
                },
                behavior: HitTestBehavior.opaque,
                child: const HigIconSquircle(
                  icon: CupertinoIcons.add,
                  color: AppColors.iosBlue,
                  size: 28,
                  iconSize: 14,
                  radius: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 4. Modal Translúcido de Pagamento Antecipado / Quitação Total da Fatura
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

    HapticFeedback.lightImpact();
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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 22 + inset),
          decoration: BoxDecoration(
            color: AppColors.surface(context).withValues(alpha: 0.94),
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
            child: SingleChildScrollView(
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
                        color: AppColors.textSecondary(context)
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      HigIconSquircle(
                        icon: CupertinoIcons.creditcard_fill,
                        color: widget.card.color,
                        size: 38,
                        iconSize: 19,
                        radius: 10,
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
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Competência ${AppFormatters.monthLabel(widget.yearMonth, short: true)} • Total compras: ${AppFormatters.currency(_purchasesTotal)}',
                              style: AppTypography.captionTabular(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Resumo Rápido de Saldo da Fatura com tabularFigures
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.secondarySurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.border(context),
                        width: AppSpacing.hairlineBorder,
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
                            const SizedBox(height: 2),
                            Text(
                              AppFormatters.currency(_alreadyPaid),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success(context),
                                fontFeatures: AppTypography.tabular,
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
                            const SizedBox(height: 2),
                            Text(
                              AppFormatters.currency(remaining),
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: remaining > 0.005
                                    ? AppColors.danger(context)
                                    : AppColors.success(context),
                                fontFeatures: AppTypography.tabular,
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
                    accentColor: AppColors.iosGreen,
                    onChanged: (_) {
                      setState(() => _errorText = null);
                    },
                    bottomAccessory: remaining > 0.005 && !isFullSelected
                        ? CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _amountCtrl.text =
                                    CentavosCurrencyFormatter.formatDouble(
                                  remaining,
                                );
                              });
                            },
                            child: Text(
                              'Preencher restante total (${AppFormatters.currency(remaining)})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.iosBlue,
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
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 50,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: AppColors.iosGreen,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () => _submitPayment(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isFullSelected
                                    ? 'Quitar Fatura Total (${AppFormatters.currency(typedVal)})'
                                    : 'Registrar Pagamento Antecipado',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
