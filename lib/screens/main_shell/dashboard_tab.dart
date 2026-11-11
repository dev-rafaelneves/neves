import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_insight_card.dart';
import '../../widgets/ios_action_sheet.dart';
import '../../widgets/month_selector_bar.dart';
import '../statement_import_screen.dart';

class DashboardTab extends StatefulWidget {
  final AppState appState;

  const DashboardTab({super.key, required this.appState});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  static const _uuid = Uuid();
  int _selectedSegment = 0; // 0: Visão Geral, 1: Contas & Invest., 2: Cartões

  Future<void> _showAccountModal({Account? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final balanceCtrl = TextEditingController(
      text: CentavosCurrencyFormatter.formatDouble(
        existing?.currentBalance ?? 0.0,
      ),
    );
    AccountType selectedType = existing?.type ?? AccountType.checking;
    final int selectedColor = existing?.colorValue ?? 0xFF059669;
    bool includeNetWorth = existing?.includeInNetWorth ?? true;

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
                        if (existing != null)
                          IconButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              IosActionSheet.show(
                                context: this.context,
                                title: 'Excluir ${existing.name}',
                                description:
                                    'Deseja remover esta conta da sua carteira?',
                                onConfirm: () =>
                                    widget.appState.deleteAccount(existing.id),
                              );
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.rose,
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 12),
                    HigCurrencyHeroField(
                      controller: balanceCtrl,
                      label: existing != null
                          ? 'Saldo Atual da Conta'
                          : 'Saldo Inicial',
                      accentColor: selectedType == AccountType.investment
                          ? AppColors.emerald
                          : AppColors.indigoPrimary,
                      autofocus: existing == null,
                    ),
                    const SizedBox(height: 20),
                    const HigSectionHeader(title: 'Dados da Conta'),
                    HigGroupedCard(
                      children: [
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
                                  color: AppColors.indigoPrimary
                                      .withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(
                                  Icons.account_balance_rounded,
                                  color: AppColors.indigoPrimary,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: nameCtrl,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Nome (ex: Itaú, Nubank, XP Invest...)',
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(indent: 62, height: 1),
                        HigFormRow(
                          icon: selectedType.defaultIcon,
                          iconColor: selectedType == AccountType.investment
                              ? AppColors.emerald
                              : AppColors.indigoPrimary,
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
                                        color: AppColors.indigoPrimary,
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
                          iconColor: AppColors.emerald,
                          label: 'Somar no Patrimônio',
                          subtitle: 'Inclui esta conta no cálculo de Net Worth',
                          trailing: Switch.adaptive(
                            value: includeNetWorth,
                            activeTrackColor: AppColors.indigoPrimary,
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
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          final bal = CentavosCurrencyFormatter.parseValue(
                            balanceCtrl.text,
                          );

                          if (existing != null) {
                            final delta = bal - existing.currentBalance;
                            await widget.appState.saveAccount(
                              existing.copyWith(
                                name: name,
                                type: selectedType,
                                initialBalance:
                                    existing.initialBalance + delta,
                                currentBalance: bal,
                                colorValue: selectedColor,
                                includeInNetWorth: includeNetWorth,
                              ),
                            );
                          } else {
                            await widget.appState.saveAccount(
                              Account(
                                id: _uuid.v4(),
                                name: name,
                                type: selectedType,
                                initialBalance: bal,
                                currentBalance: bal,
                                colorValue:
                                    selectedType == AccountType.investment
                                        ? 0xFF10B981
                                        : selectedColor,
                                iconName:
                                    selectedType == AccountType.investment
                                        ? 'trending_up'
                                        : 'account_balance',
                                includeInNetWorth: includeNetWorth,
                              ),
                            );
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.indigoPrimary,
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

  Future<void> _showCardModal({CreditCardModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final limitCtrl = TextEditingController(
      text: CentavosCurrencyFormatter.formatDouble(
        existing?.creditLimit ?? 5000.0,
      ),
    );
    int closingDay = existing?.closingDay ?? 5;
    int dueDay = existing?.dueDay ?? 12;
    int colorVal = existing?.colorValue ?? 0xFF059669;

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
          builder: (context, setModalState) {
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
                        if (existing != null)
                          IconButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              IosActionSheet.show(
                                context: this.context,
                                title: 'Excluir ${existing.name}',
                                description:
                                    'Deseja remover este cartão de crédito?',
                                onConfirm: () => widget.appState
                                    .deleteCreditCard(existing.id),
                              );
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.rose,
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
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
                                  color: Color(colorVal).withValues(alpha: 0.14),
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
                                  textCapitalization:
                                      TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Nome do Cartão (ex: Nubank, Itaú...)',
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(indent: 62, height: 1),
                        HigFormRow(
                          icon: Icons.event_busy_rounded,
                          iconColor: AppColors.orange,
                          label: 'Dia de Fechamento',
                          subtitle: 'Compras a partir deste dia vão p/ próxima fatura',
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
                                        color: AppColors.indigoPrimary,
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
                          iconColor: AppColors.emerald,
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
                                        color: AppColors.indigoPrimary,
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
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          final limit = CentavosCurrencyFormatter.parseValue(
                            limitCtrl.text,
                          );
                          await widget.appState.saveCreditCard(
                            CreditCardModel(
                              id: existing?.id ?? _uuid.v4(),
                              name: name,
                              creditLimit: limit > 0 ? limit : 5000.0,
                              closingDay: closingDay,
                              dueDay: dueDay,
                              colorValue: colorVal,
                            ),
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.indigoPrimary,
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

  Future<void> _showPayInvoiceDialog(CreditCardModel card) async {
    final state = widget.appState;
    final ym = state.selectedYearMonth;
    final total = state.getInvoiceTotal(card.id, ym);
    final amountCtrl = TextEditingController(
      text: CentavosCurrencyFormatter.formatDouble(total),
    );
    String? accountId =
        state.accounts.isNotEmpty ? state.accounts.first.id : null;

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
                    'Competência: $ym',
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
                    accentColor: AppColors.emerald,
                  ),
                  const SizedBox(height: 16),
                  if (state.accounts.isNotEmpty)
                    HigGroupedCard(
                      children: [
                        HigFormRow(
                          icon: Icons.account_balance_rounded,
                          iconColor: AppColors.indigoPrimary,
                          label: 'Debitar da Conta',
                          trailing: DropdownButton<String>(
                            value: accountId,
                            underline: const SizedBox.shrink(),
                            items: state.accounts
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(
                                      a.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.indigoPrimary,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setModalState(() => accountId = v),
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
                        await state.payCreditCardInvoice(
                          card: card,
                          yearMonth: ym,
                          sourceAccountId: accountId!,
                          customAmount: val > 0 ? val : total,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    final now = DateTime.now();
    final dateStr = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(now);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 74,
          backgroundColor: isDark
              ? AppColors.darkBackground.withValues(alpha: 0.92)
              : AppColors.lightBackground.withValues(alpha: 0.92),
          centerTitle: false,
          titleSpacing: 20,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StatementImportScreen(appState: state),
                    ),
                  );
                },
                tooltip: 'Importar Extrato OFX/CSV/PDF',
                icon: const Icon(Icons.upload_file_rounded, size: 22),
              ),
              IconButton(
                key: const ValueKey('btn_discreet_mode'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  state.toggleDiscreetMode();
                },
                tooltip: state.discreetMode
                    ? 'Mostrar Valores'
                    : 'Modo Discreto (Ocultar Valores)',
                icon: Icon(
                  state.discreetMode
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 22,
                  color: state.discreetMode
                      ? AppColors.indigoPrimary
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
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
                    // Seletor de Mês + Regime Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MonthSelectorBar(appState: state),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.indigoPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            state.budgetRegime == BudgetRegime.competence
                                ? 'Competência'
                                : 'Data Compra',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.indigoPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Segmented Control estilo iOS HIG
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _selectedSegment,
                        children: const {
                          0: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Visão Geral',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          1: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Contas & Invest.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          2: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Cartões',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        },
                        onValueChanged: (v) {
                          if (v != null) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedSegment = v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_selectedSegment == 0) _buildOverviewSection(context),
                    if (_selectedSegment == 1) _buildAccountsSection(context),
                    if (_selectedSegment == 2) _buildCardsSection(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    final ym = state.selectedYearMonth;
    final discreet = state.discreetMode;

    final income = state.totalIncomeForMonth(ym);
    final expense = state.totalExpenseForMonth(ym);
    final projectedBalance = state.projectedEndOfMonthBalance(ym);
    final savingsRate =
        income > 0 ? ((income - expense) / income * 100) : 0.0;
    final catBreakdown = state.categoryExpenseBreakdown(ym);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card Principal de Fluxo de Caixa e Patrimônio Líquido
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF065F46)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.indigoPrimary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'SALDO DISPONÍVEL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Patrimônio: ${AppFormatters.currency(state.netWorth, discreet: discreet)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                AppFormatters.currency(
                  state.liquidAccountsBalance,
                  discreet: discreet,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Saldo Projetado no Fim do Mês: ${AppFormatters.currency(projectedBalance, discreet: discreet)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 14,
                                color: Color(0xFF34D399),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Receitas',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(income, discreet: discreet),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 14,
                                color: Color(0xFFFB7185),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Despesas',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(expense, discreet: discreet),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Poupança',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          discreet
                              ? '••%'
                              : '${savingsRate.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: savingsRate >= 20
                                ? const Color(0xFF34D399)
                                : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Gráfico de Despesas por Categoria (fl_chart)
        Material(
          color: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Despesas por Categoria',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                if (catBreakdown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Nenhuma despesa registrada em $ym.\nToque em "+ Lançar" para adicionar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 36,
                            sectionsSpace: 2,
                            sections: catBreakdown.entries.map((e) {
                              final pct = expense > 0
                                  ? (e.value / expense * 100)
                                  : 0.0;
                              return PieChartSectionData(
                                color: e.key.color,
                                value: e.value,
                                radius: 22,
                                showTitle: false,
                                badgeWidget: pct >= 15
                                    ? null
                                    : const SizedBox.shrink(),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: catBreakdown.entries.take(5).map((e) {
                            final pct = expense > 0
                                ? (e.value / expense * 100)
                                : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: e.key.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      e.key.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    discreet
                                        ? '••%'
                                        : '${pct.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Consultor Financeiro IA (Gemini BYOK)
        AiInsightCard(appState: state),
      ],
    );
  }

  Widget _buildAccountsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    final discreet = state.discreetMode;

    final liquidAccs = state.accounts
        .where((a) => a.type != AccountType.investment)
        .toList();
    final investAccs = state.accounts
        .where((a) => a.type == AccountType.investment)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CONTAS CORRENTES & CARTEIRA',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: AppColors.indigoPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAccountModal(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova Conta'),
            ),
          ],
        ),
        ...liquidAccs.map(
          (acc) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: isDark ? AppColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: ListTile(
                onTap: () => _showAccountModal(existing: acc),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: acc.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(acc.icon, color: acc.color, size: 22),
                ),
                title: Text(
                  acc.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  acc.type.label,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  AppFormatters.currency(
                    acc.currentBalance,
                    discreet: discreet,
                  ),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: acc.currentBalance >= 0
                        ? (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary)
                        : AppColors.rose,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'INVESTIMENTOS & PATRIMÔNIO LÍQUIDO',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: AppColors.emerald,
          ),
        ),
        const SizedBox(height: 8),
        ...investAccs.map(
          (acc) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: isDark ? AppColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: ListTile(
                onTap: () => _showAccountModal(existing: acc),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.emerald,
                    size: 22,
                  ),
                ),
                title: Text(
                  acc.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                subtitle: const Text(
                  'Toque para atualizar saldo da carteira',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  AppFormatters.currency(
                    acc.currentBalance,
                    discreet: discreet,
                  ),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emerald,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    final ym = state.selectedYearMonth;
    final discreet = state.discreetMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MEUS CARTÕES DE CRÉDITO',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: AppColors.indigoPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showCardModal(),
              icon: const Icon(Icons.add_card_rounded, size: 18),
              label: const Text('Novo Cartão'),
            ),
          ],
        ),
        if (state.creditCards.isEmpty)
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
                    color: AppColors.indigoPrimary,
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
                    onPressed: () => _showCardModal(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.indigoPrimary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Cadastrar Primeiro Cartão'),
                  ),
                ],
              ),
            ),
          )
        else
          ...state.creditCards.map((card) {
            final used = state.getCardUsedLimit(card.id);
            final avail = state.getCardAvailableLimit(card);
            final invTotal = state.getInvoiceTotal(card.id, ym);
            final invStatus = state.getInvoiceStatus(card, ym);
            final usageRatio = card.creditLimit > 0
                ? (used / card.creditLimit).clamp(0.0, 1.0)
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                              color: (invStatus == InvoiceStatus.paid
                                      ? AppColors.emerald
                                      : (invStatus == InvoiceStatus.closed
                                          ? AppColors.orange
                                          : AppColors.indigoPrimary))
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              invStatus.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: invStatus == InvoiceStatus.paid
                                    ? AppColors.emerald
                                    : (invStatus == InvoiceStatus.closed
                                        ? AppColors.orange
                                        : AppColors.indigoPrimary),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showCardModal(existing: card),
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
                                'Fatura de $ym',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              Text(
                                AppFormatters.currency(
                                  invTotal,
                                  discreet: discreet,
                                ),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          if (invTotal > 0 && invStatus != InvoiceStatus.paid)
                            ElevatedButton.icon(
                              onPressed: () => _showPayInvoiceDialog(card),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emerald,
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
                          backgroundColor: isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                          color: usageRatio >= 0.85
                              ? AppColors.rose
                              : card.color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ocupado: ${AppFormatters.currency(used, discreet: discreet)}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          Text(
                            'Disponível: ${AppFormatters.currency(avail, discreet: discreet)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
