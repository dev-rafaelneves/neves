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
}

class _CreditCardDetailCard extends StatelessWidget {
  final CreditCardItem card;
  final String yearMonth;
  final double invoiceTotal;
  final double ownTotal;
  final double ignoredTotal;
  final int itemCount;
  final bool discreet;
  final VoidCallback onViewInvoice;
  final VoidCallback onImportInvoice;
  final VoidCallback onEdit;

  const _CreditCardDetailCard({
    required this.card,
    required this.yearMonth,
    required this.invoiceTotal,
    required this.ownTotal,
    required this.ignoredTotal,
    required this.itemCount,
    required this.discreet,
    required this.onViewInvoice,
    required this.onImportInvoice,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasIgnored = ignoredTotal.abs() > 0.005;

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

        // Linha 2: Resumo da Fatura do Mês
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fatura de ${AppFormatters.monthLabel(yearMonth, short: true)} ($itemCount ${itemCount == 1 ? 'compra' : 'compras'})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormatters.currency(invoiceTotal, discreet: discreet),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: invoiceTotal > 0
                        ? AppColors.danger(context)
                        : AppColors.textPrimary(context),
                  ),
                ),
                if (hasIgnored) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Seus gastos: ${AppFormatters.currency(ownTotal, discreet: discreet)} • Ignorados: ${AppFormatters.currency(ignoredTotal, discreet: discreet)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: onImportInvoice,
                  child: const Text(
                    'Importar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: onViewInvoice,
                  child: const Text(
                    'Ver Fatura',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
