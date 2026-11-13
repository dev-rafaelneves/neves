import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';
import '../../../services/app_state.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/ios_action_sheet.dart';

const _uuid = Uuid();

Future<void> showAccountModal({
  required BuildContext context,
  required AppState appState,
  required VoidCallback onSaved,
  Account? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final balanceCtrl = TextEditingController(
    text: CentavosCurrencyFormatter.formatDouble(
      existing?.currentBalance ?? 0.0,
    ),
  );
  AccountType selectedType = existing?.type ?? AccountType.checking;
  final int selectedColor = existing?.colorValue ?? 0xFF059669;
  bool includeNetWorth = existing?.includeInNetWorth ?? true;
  String? errorMsg;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> handleSaveAccount() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              HapticFeedback.heavyImpact();
              setModalState(() {
                errorMsg =
                    'Informe o nome da conta (ou escolha uma sugestão abaixo).';
              });
              return;
            }
            final bal = CentavosCurrencyFormatter.parseValue(
              balanceCtrl.text,
            );

            if (existing != null) {
              final delta = bal - existing.currentBalance;
              await appState.saveAccount(
                existing.copyWith(
                  name: name,
                  type: selectedType,
                  initialBalance: existing.initialBalance + delta,
                  currentBalance: bal,
                  colorValue: selectedColor,
                  includeInNetWorth: includeNetWorth,
                ),
              );
            } else {
              await appState.saveAccount(
                Account(
                  id: _uuid.v4(),
                  name: name,
                  type: selectedType,
                  initialBalance: bal,
                  currentBalance: bal,
                  colorValue: selectedType == AccountType.investment
                      ? 0xFF10B981
                      : selectedColor,
                  iconName: selectedType == AccountType.investment
                      ? 'trending_up'
                      : 'account_balance',
                  includeInNetWorth: includeNetWorth,
                ),
              );
            }
            onSaved();
            if (ctx.mounted) Navigator.of(ctx).pop();
          }

          return Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 24),
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.darkBackground : AppColors.lightBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      Text(
                        existing != null ? 'Editar Conta' : 'Nova Conta',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (existing != null)
                            IconButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                IosActionSheet.show(
                                  context: context,
                                  title: 'Excluir ${existing.name}',
                                  description:
                                      'Deseja remover esta conta da sua carteira?',
                                  onConfirm: () =>
                                      appState.deleteAccount(existing.id),
                                );
                              },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.danger(context),
                              ),
                            ),
                          TextButton(
                            onPressed: handleSaveAccount,
                            child: const Text(
                              'Salvar',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    _ModalErrorBanner(message: errorMsg!),
                  ],
                  const SizedBox(height: 12),
                  HigCurrencyHeroField(
                    controller: balanceCtrl,
                    label: existing != null
                        ? 'Saldo Atual da Conta'
                        : 'Saldo Inicial',
                    accentColor: selectedType == AccountType.investment
                        ? AppColors.emerald
                        : AppColors.primary,
                  ),
                  const SizedBox(height: 20),
                  const HigSectionHeader(title: 'Dados da Conta'),
                  HigGroupedCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primary.withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_rounded,
                                    color: AppColors.primary,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: nameCtrl,
                                    autofocus: existing == null,
                                    textCapitalization: TextCapitalization.words,
                                    onChanged: (_) {
                                      if (errorMsg != null) {
                                        setModalState(() => errorMsg = null);
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Nome da Conta (ex: Nubank, Itaú...)',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                'Nubank',
                                'Itaú',
                                'Inter',
                                'Bradesco',
                                'XP Investimentos',
                                'Carteira',
                              ].map((suggestion) {
                                return ActionChip(
                                  label: Text(
                                    suggestion,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    setModalState(() {
                                      nameCtrl.text = suggestion;
                                      errorMsg = null;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                      const Divider(indent: 62, height: 1),
                      HigFormRow(
                        icon: selectedType.defaultIcon,
                        iconColor: selectedType == AccountType.investment
                            ? AppColors.emerald
                            : AppColors.primary,
                        label: 'Tipo de Conta',
                        trailing: DropdownButton<AccountType>(
                          value: selectedType,
                          underline: const SizedBox.shrink(),
                          items: AccountType.values
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t.label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => selectedType = v);
                            }
                          },
                        ),
                      ),
                      const Divider(indent: 62, height: 1),
                      HigFormRow(
                        icon: Icons.pie_chart_rounded,
                        iconColor: AppColors.success(context),
                        label: 'Somar no Patrimônio',
                        subtitle: 'Inclui esta conta no cálculo de Net Worth',
                        trailing: Switch.adaptive(
                          value: includeNetWorth,
                          activeTrackColor: AppColors.primary,
                          onChanged: (v) =>
                              setModalState(() => includeNetWorth = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: handleSaveAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text(
                        'Salvar Conta',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> showCardModal({
  required BuildContext context,
  required AppState appState,
  required VoidCallback onSaved,
  CreditCardModel? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final limitCtrl = TextEditingController(
    text: CentavosCurrencyFormatter.formatDouble(
      existing?.creditLimit ?? 5000.0,
    ),
  );
  int closingDay = existing?.closingDay ?? 5;
  int dueDay = existing?.dueDay ?? 12;
  int colorVal = existing?.colorValue ?? 0xFF059669;
  String? errorMsg;

  final colors = [
    0xFF059669,
    0xFF0D9488,
    0xFF0F172A,
    0xFF10B981,
    0xFFF97316,
    0xFFF43F5E,
  ];

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> handleSaveCard() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              HapticFeedback.heavyImpact();
              setModalState(() {
                errorMsg =
                    'Informe o nome do cartão (ou toque em uma opção rápida abaixo, ex: Nubank).';
              });
              return;
            }
            final limit = CentavosCurrencyFormatter.parseValue(
              limitCtrl.text,
            );
            await appState.saveCreditCard(
              CreditCardModel(
                id: existing?.id ?? _uuid.v4(),
                name: name,
                creditLimit: limit > 0 ? limit : 5000.0,
                closingDay: closingDay,
                dueDay: dueDay,
                colorValue: colorVal,
              ),
            );
            onSaved();
            if (ctx.mounted) Navigator.of(ctx).pop();
          }

          return Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 24),
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.darkBackground : AppColors.lightBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      Text(
                        existing != null
                            ? 'Editar Cartão'
                            : 'Novo Cartão de Crédito',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (existing != null)
                            IconButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                IosActionSheet.show(
                                  context: context,
                                  title: 'Excluir ${existing.name}',
                                  description:
                                      'Deseja remover este cartão de crédito?',
                                  onConfirm: () =>
                                      appState.deleteCreditCard(existing.id),
                                );
                              },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.danger(context),
                              ),
                            ),
                          TextButton(
                            onPressed: handleSaveCard,
                            child: const Text(
                              'Salvar',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    _ModalErrorBanner(message: errorMsg!),
                  ],
                  const SizedBox(height: 12),
                  HigCurrencyHeroField(
                    controller: limitCtrl,
                    label: 'Limite Total do Cartão',
                    accentColor: Color(colorVal),
                  ),
                  const SizedBox(height: 20),
                  const HigSectionHeader(title: 'Configuração da Fatura'),
                  HigGroupedCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color:
                                        Color(colorVal).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    Icons.credit_card_rounded,
                                    color: Color(colorVal),
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: nameCtrl,
                                    autofocus: existing == null,
                                    textCapitalization: TextCapitalization.words,
                                    onChanged: (_) {
                                      if (errorMsg != null) {
                                        setModalState(() => errorMsg = null);
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Nome do Cartão (ex: Nubank, Itaú...)',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                'Nubank',
                                'Itaú',
                                'Inter',
                                'Bradesco',
                                'C6 Bank',
                                'XP Visa',
                              ].map((suggestion) {
                                return ActionChip(
                                  label: Text(
                                    suggestion,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    setModalState(() {
                                      nameCtrl.text = suggestion;
                                      errorMsg = null;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                      const Divider(indent: 62, height: 1),
                      HigFormRow(
                        icon: Icons.event_busy_rounded,
                        iconColor: AppColors.warning(context),
                        label: 'Dia de Fechamento',
                        subtitle:
                            'Compras a partir deste dia vão p/ próxima fatura',
                        trailing: DropdownButton<int>(
                          value: closingDay,
                          underline: const SizedBox.shrink(),
                          items: List.generate(28, (i) => i + 1)
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(
                                    'Dia $d',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setModalState(() => closingDay = v ?? 5),
                        ),
                      ),
                      const Divider(indent: 62, height: 1),
                      HigFormRow(
                        icon: Icons.event_available_rounded,
                        iconColor: AppColors.success(context),
                        label: 'Dia de Vencimento',
                        subtitle: 'Data limite para pagamento da fatura',
                        trailing: DropdownButton<int>(
                          value: dueDay,
                          underline: const SizedBox.shrink(),
                          items: List.generate(28, (i) => i + 1)
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(
                                    'Dia $d',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setModalState(() => dueDay = v ?? 12),
                        ),
                      ),
                      const Divider(indent: 62, height: 1),
                      HigFormRow(
                        icon: Icons.palette_outlined,
                        iconColor: Color(colorVal),
                        label: 'Cor do Cartão',
                        trailing: Wrap(
                          spacing: 8,
                          children: colors.map((c) {
                            final selected = colorVal == c;
                            return GestureDetector(
                              onTap: () => setModalState(() => colorVal = c),
                              child: CircleAvatar(
                                radius: 13,
                                backgroundColor: Color(c),
                                child: selected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: handleSaveCard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text(
                        'Salvar Cartão',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> showPayInvoiceDialog({
  required BuildContext context,
  required AppState appState,
  required CreditCardModel card,
}) async {
  final ym = appState.selectedYearMonth;
  final total = appState.getInvoiceTotal(card.id, ym);
  final amountCtrl = TextEditingController(
    text: CentavosCurrencyFormatter.formatDouble(total),
  );
  String? accountId =
      appState.accounts.isNotEmpty ? appState.accounts.first.id : null;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 24),
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.darkBackground : AppColors.lightBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 14),
                Text(
                  'Pagar Fatura • ${card.name}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Competência: ${AppFormatters.monthLabel(ym)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                HigCurrencyHeroField(
                  controller: amountCtrl,
                  label: 'Valor do Pagamento (Total ou Parcial)',
                  accentColor: AppColors.success(context),
                ),
                const SizedBox(height: 16),
                if (appState.accounts.isNotEmpty)
                  HigGroupedCard(
                    children: [
                      HigFormRow(
                        icon: Icons.account_balance_rounded,
                        iconColor: AppColors.primary,
                        label: 'Debitar da Conta',
                        trailing: DropdownButton<String>(
                          value: accountId,
                          underline: const SizedBox.shrink(),
                          items: appState.accounts
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(
                                    a.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setModalState(() => accountId = v),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (accountId == null) return;
                      final val = CentavosCurrencyFormatter.parseValue(
                        amountCtrl.text,
                      );
                      await appState.payCreditCardInvoice(
                        card: card,
                        yearMonth: ym,
                        sourceAccountId: accountId!,
                        customAmount: val > 0 ? val : total,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successStrong,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text(
                      'Confirmar Pagamento da Fatura',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _ModalErrorBanner extends StatelessWidget {
  final String message;

  const _ModalErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.rose.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger(context),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.danger(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
