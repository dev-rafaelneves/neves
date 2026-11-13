import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../services/app_state.dart';
import '../../../theme/app_theme.dart';

class DashboardCardsSection extends StatelessWidget {
  final AppState appState;
  final bool isWide;
  final VoidCallback onCreateCard;
  final ValueChanged<CreditCardModel> onEditCard;
  final ValueChanged<CreditCardModel> onPayInvoice;
  final ValueChanged<CreditCardModel>? onOpenCardStatement;

  const DashboardCardsSection({
    super.key,
    required this.appState,
    required this.isWide,
    required this.onCreateCard,
    required this.onEditCard,
    required this.onPayInvoice,
    this.onOpenCardStatement,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ym = appState.selectedYearMonth;
    final discreet = appState.discreetMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MEUS CARTÕES DE CRÉDITO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: AppColors.primary,
              ),
            ),
            TextButton.icon(
              onPressed: onCreateCard,
              icon: const Icon(Icons.add_card_rounded, size: 18),
              label: const Text('Novo Cartão'),
            ),
          ],
        ),
        if (appState.creditCards.isEmpty)
          Material(
            color: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.credit_card_rounded,
                    size: 42,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Nenhum cartão cadastrado',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cadastre seus cartões para controlar limite disponível, fechamento de fatura e compras parceladas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: onCreateCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Cadastrar Primeiro Cartão'),
                  ),
                ],
              ),
            ),
          )
        else if (isWide)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 14) / 2;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: appState.creditCards
                    .map(
                      (card) => SizedBox(
                        width: cardWidth,
                        child: _CreditCardItem(
                          appState: appState,
                          card: card,
                          ym: ym,
                          isDark: isDark,
                          discreet: discreet,
                          onEdit: () => onEditCard(card),
                          onPayInvoice: () => onPayInvoice(card),
                          onOpenStatement: () =>
                              onOpenCardStatement?.call(card),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          )
        else
          ...appState.creditCards.map(
            (card) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CreditCardItem(
                appState: appState,
                card: card,
                ym: ym,
                isDark: isDark,
                discreet: discreet,
                onEdit: () => onEditCard(card),
                onPayInvoice: () => onPayInvoice(card),
                onOpenStatement: () => onOpenCardStatement?.call(card),
              ),
            ),
          ),
      ],
    );
  }
}

class _CreditCardItem extends StatelessWidget {
  final AppState appState;
  final CreditCardModel card;
  final String ym;
  final bool isDark;
  final bool discreet;
  final VoidCallback onEdit;
  final VoidCallback onPayInvoice;
  final VoidCallback onOpenStatement;

  const _CreditCardItem({
    required this.appState,
    required this.card,
    required this.ym,
    required this.isDark,
    required this.discreet,
    required this.onEdit,
    required this.onPayInvoice,
    required this.onOpenStatement,
  });

  @override
  Widget build(BuildContext context) {
    final used = appState.getCardUsedLimit(card.id);
    final avail = appState.getCardAvailableLimit(card);
    final invTotal = appState.getInvoiceTotal(card.id, ym);
    final invStatus = appState.getInvoiceStatus(card, ym);
    final usageRatio =
        card.creditLimit > 0 ? (used / card.creditLimit).clamp(0.0, 1.0) : 0.0;

    final statusColor = invStatus == InvoiceStatus.paid
        ? AppColors.success(context)
        : (invStatus == InvoiceStatus.closed
            ? AppColors.warning(context)
            : AppColors.primary);

    return Material(
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Fecha dia ${card.closingDay} • Vence dia ${card.dueDay}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    invStatus.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fatura de ${AppFormatters.monthLabel(ym)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      AppFormatters.currency(invTotal, discreet: discreet),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (invTotal > 0 && invStatus != InvoiceStatus.paid)
                  ElevatedButton.icon(
                    onPressed: onPayInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successStrong,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Pagar Fatura'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: usageRatio,
                minHeight: 7,
                backgroundColor:
                    isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                color: usageRatio >= 0.85 ? AppColors.rose : card.color,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ocupado: ${AppFormatters.currency(used, discreet: discreet)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Disponível: ${AppFormatters.currency(avail, discreet: discreet)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenStatement,
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('Ver Lançamentos do Cartão'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
