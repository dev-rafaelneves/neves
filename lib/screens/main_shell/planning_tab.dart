import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ios_action_sheet.dart';
import '../../widgets/month_selector_bar.dart';

class PlanningTab extends StatefulWidget {
  final AppState appState;

  const PlanningTab({super.key, required this.appState});

  @override
  State<PlanningTab> createState() => _PlanningTabState();
}

class _PlanningTabState extends State<PlanningTab> {
  static const _uuid = Uuid();
  int _selectedSegment = 0; // 0: Teto Categorias, 1: Caixinhas

  Future<void> _showSetBudgetDialog(CategoryModel category) async {
    final state = widget.appState;
    final ym = state.selectedYearMonth;
    final existing = state.getBudgetForCategory(category.id, ym);
    final ctrl = TextEditingController(
      text: CentavosCurrencyFormatter.formatDouble(
        existing?.limitAmount ?? 0.0,
      ),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
                'Teto Mensal • ${category.name}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Competência ${AppFormatters.monthLabel(ym)}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 14),
              HigCurrencyHeroField(
                controller: ctrl,
                label: 'Limite Mensal Planejado (R\$ 0,00 p/ remover)',
                accentColor: category.color,
                autofocus: true,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final val = CentavosCurrencyFormatter.parseValue(ctrl.text);
                    await state.saveBudget(
                      categoryId: category.id,
                      yearMonth: ym,
                      limitAmount: val,
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
                    'Salvar Teto Mensal',
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
  }

  Future<void> _showGoalModal({GoalModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final targetCtrl = TextEditingController(
      text: CentavosCurrencyFormatter.formatDouble(
        existing?.targetAmount ?? 5000.0,
      ),
    );
    final currentCtrl = TextEditingController(
      text: CentavosCurrencyFormatter.formatDouble(
        existing?.currentAmount ?? 0.0,
      ),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
                      existing != null ? 'Editar Caixinha' : 'Nova Caixinha',
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
                            context: context,
                            title: 'Excluir ${existing.name}',
                            onConfirm: () =>
                                widget.appState.deleteGoal(existing.id),
                          );
                        },
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger(context),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),
                HigCurrencyHeroField(
                  controller: targetCtrl,
                  label: 'Meta Final da Caixinha',
                  accentColor: AppColors.success(context),
                  autofocus: existing == null,
                ),
                const SizedBox(height: 20),
                const HigSectionHeader(title: 'Identificação & Saldo Guardado'),
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
                              color: AppColors.emerald.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              Icons.savings_rounded,
                              color: AppColors.success(context),
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: nameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                hintText:
                                    'Nome (ex: Reserva de Emergência, Viagem...)',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(indent: 62, height: 1),
                    HigFormRow(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: AppColors.indigoPrimary,
                      label: 'Já Guardado (R\$)',
                      trailing: SizedBox(
                        width: 130,
                        child: TextField(
                          controller: currentCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            const CentavosCurrencyFormatter(),
                          ],
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success(context),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
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
                      final target = CentavosCurrencyFormatter.parseValue(
                        targetCtrl.text,
                      );
                      final current = CentavosCurrencyFormatter.parseValue(
                        currentCtrl.text,
                      );
                      await widget.appState.saveGoal(
                        GoalModel(
                          id: existing?.id ?? _uuid.v4(),
                          name: name,
                          targetAmount: target > 0 ? target : 1000.0,
                          currentAmount: current,
                          colorValue: existing?.colorValue ?? 0xFF10B981,
                          iconName: existing?.iconName ?? 'savings',
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
                      'Salvar Caixinha',
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
  }

  Future<void> _showQuickDepositDialog(GoalModel goal) async {
    final ctrl = TextEditingController(text: '0,00');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
                'Guardar em ${goal.name}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              HigCurrencyHeroField(
                controller: ctrl,
                label: 'Valor do Aporte',
                accentColor: AppColors.success(context),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final delta = CentavosCurrencyFormatter.parseValue(
                      ctrl.text,
                    );
                    if (delta > 0) {
                      await widget.appState.addContributionToGoal(goal, delta);
                    }
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
                  icon: const Icon(Icons.savings_rounded, size: 20),
                  label: const Text(
                    'Confirmar Aporte',
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;

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
            'Planejamento',
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
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _selectedSegment,
                        children: const {
                          0: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Teto Categoria',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          1: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Caixinhas',
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
                    if (_selectedSegment == 0) _buildCategoryBudgets(context),
                    if (_selectedSegment == 1) _buildGoalsSection(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBudgets(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    final ym = state.selectedYearMonth;
    final discreet = state.discreetMode;

    final expenseCategories = state.categories
        .where((c) => c.type == TransactionType.expense)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toque em qualquer categoria para definir um teto mensal de gastos. Você receberá alertas em 80% e 100%.',
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...expenseCategories.map((cat) {
          final spent = state.getCategorySpent(cat.id, ym);
          final budget = state.getBudgetForCategory(cat.id, ym);
          final limit = budget?.limitAmount ?? 0.0;
          final ratio = limit > 0 ? (spent / limit) : 0.0;

          Color barColor = AppColors.emerald;
          if (ratio >= 1.0) {
            barColor = AppColors.rose;
          } else if (ratio >= 0.8) {
            barColor = AppColors.orange;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
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
                onTap: () => _showSetBudgetDialog(cat),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: cat.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(cat.icon, color: cat.color, size: 19),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppFormatters.currency(spent, discreet: discreet),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                limit > 0
                                    ? 'de ${AppFormatters.currency(limit, discreet: discreet)}'
                                    : 'Definir Teto >',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: limit > 0
                                      ? barColor
                                      : AppColors.indigoPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (limit > 0) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE2E8F0),
                            color: barColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGoalsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    final discreet = state.discreetMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MINHAS CAIXINHAS & METAS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: AppColors.success(context),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showGoalModal(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova Caixinha'),
            ),
          ],
        ),
        ...state.goals.map((goal) {
          final pct = (goal.progress * 100).toStringAsFixed(0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
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
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            goal.icon,
                            color: AppColors.success(context),
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goal.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                ),
                              ),
                              Text(
                                '${AppFormatters.currency(goal.currentAmount, discreet: discreet)} de ${AppFormatters.currency(goal.targetAmount, discreet: discreet)} ($pct%)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showQuickDepositDialog(goal),
                          tooltip: 'Guardar Dinheiro',
                          icon: Icon(
                            Icons.add_circle_rounded,
                            color: AppColors.success(context),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showGoalModal(existing: goal),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: goal.progress,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? AppColors.darkBorder
                            : const Color(0xFFE2E8F0),
                        color: AppColors.success(context),
                      ),
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
